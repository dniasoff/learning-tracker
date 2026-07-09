import 'dart:io';

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';

/// Thrown by [AccountLifecycleService.removeCloudFromDevice] when the
/// account's local DB still has outbox rows that have not reached Firestore.
///
/// The outbox is the only copy of a queued mutation until it is pushed;
/// deleting the local DB file while [pendingCount] is nonzero would
/// permanently destroy that data even though the Account Picker's
/// confirmation dialog promises "your cloud data is safe" unconditionally.
/// See AUD-account-01.
class UndrainedOutboxException extends ConflictException {
  const UndrainedOutboxException(this.pendingCount)
    : super('$pendingCount change(s) have not been backed up to the cloud yet');

  /// Number of outbox rows across every profile under the account that have
  /// not yet been pushed to Firestore.
  final int pendingCount;
}

/// Service handling account removal and deletion for all tiers.
///
/// Three operations with increasing destructiveness:
/// - [removeCloudFromDevice]: light — local cleanup only, cloud intact
/// - [deleteLocalAccount]: heavy — permanent local wipe, no undo
/// - [deleteCloudAccount]: heaviest — wipe Firestore + Auth + local
class AccountLifecycleService {
  AccountLifecycleService({
    required DeviceRegistryDatabase registry,
    required String databasesPath,
    AuthRepository? authRepository,
    FirestoreGateway? gateway,
  }) : _registry = registry,
       _dbPath = databasesPath,
       _authRepository = authRepository,
       _gateway = gateway;

  final DeviceRegistryDatabase _registry;
  final String _dbPath;
  final AuthRepository? _authRepository;
  final FirestoreGateway? _gateway;

  // ─── 21.13: Remove cloud-born account from device ──────────

  /// Light removal: deletes local DB file + registry entry.
  /// Firestore data and Firebase Auth are NOT touched — user can
  /// sign back in on any device and recover everything.
  ///
  /// Throws [UndrainedOutboxException] if any profile under this account
  /// still has outbox rows that have not reached Firestore — deleting the
  /// DB file now would destroy that data permanently, contradicting the
  /// "your cloud data is safe" promise shown at the confirmation prompt.
  Future<void> removeCloudFromDevice(String accountId) async {
    final account = await _registry.findById(accountId);
    if (account == null) return;
    if (!account.accountTier.isCloud) {
      throw StateError(
        'removeCloudFromDevice requires a cloud-born account. '
        'Use deleteLocalAccount for local-born.',
      );
    }

    final pending = await pendingOutboxDepth(accountId);
    if (pending > 0) {
      throw UndrainedOutboxException(pending);
    }

    // If we're removing the Firebase user whose token is currently
    // cached, clear it — otherwise the picker would still show the
    // removed account as having a "valid session" via currentUser
    // on the next launch. Swallow failures so this works in unit
    // tests without a real app.
    try {
      final currentUser = _authRepository?.currentUser;
      if (currentUser != null && currentUser.uid == account.firebaseUid) {
        await _authRepository?.signOut();
      }
    } catch (_) {
      // Auth not initialized (tests, or Firebase init failed at
      // startup). Nothing to clean up on the auth side.
    }

    _deleteDbFile(account.dbFileName);
    await _registry.removeAccount(accountId);
  }

  // ─── 21.14: Delete local-born account ──────────────────────

  /// Heavy deletion: deletes the local DB file + registry entry.
  /// Permanent — no cloud copy exists, data is gone forever.
  Future<void> deleteLocalAccount(String accountId) async {
    final account = await _registry.findById(accountId);
    if (account == null) return;
    if (!account.accountTier.isLocal) {
      throw StateError(
        'deleteLocalAccount requires a local-born account. '
        'Use removeCloudFromDevice or deleteCloudAccount for cloud-born.',
      );
    }

    _deleteDbFile(account.dbFileName);
    await _registry.removeAccount(accountId);
  }

  // ─── 21.15: Delete cloud-born account (full wipe) ──────────

  /// Full GDPR-style deletion. Execution order is critical:
  /// 1. Delete Firestore subcollections under /users/{uid}
  /// 2. Delete Firebase Auth user
  /// 3. Delete local DB file
  /// 4. Remove from registry
  ///
  /// NEVER deletes local before cloud succeeds — if network
  /// fails mid-way, local data is preserved and the user can
  /// retry. The Cloud Function (21.16) is the safety net for
  /// partial Firestore deletion.
  ///
  /// Requires recent authentication — caller must re-auth the
  /// user before calling this.
  Future<void> deleteCloudAccount(String accountId) async {
    final account = await _registry.findById(accountId);
    if (account == null) return;
    if (!account.accountTier.isCloud || account.firebaseUid == null) {
      throw StateError('deleteCloudAccount requires a cloud-born account');
    }

    final uid = account.firebaseUid!;

    // Step 1: delete Firestore data via gateway (client-side best-effort)
    if (_gateway != null) {
      await _gateway.deleteUserData(uid);
    }

    // Step 2: delete Firebase Auth user — triggers Cloud Function
    final currentUser = _authRepository?.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await _authRepository?.deleteCurrentFirebaseUser();
    }

    // Step 3: local cleanup (only after cloud succeeds)
    _deleteDbFile(account.dbFileName);
    await _registry.removeAccount(accountId);
  }

  // ─── AUD-account-01: pre-delete outbox guard ───────────────────

  /// Total number of undrained outbox rows across every profile under
  /// [accountId]'s local DB, or 0 if the account or its DB file cannot be
  /// found (nothing to lose).
  ///
  /// The outbox table is per-account (one row per profile column), so a
  /// single unfiltered count over the account's own DB file already sums
  /// every profile it holds — there is no need to enumerate profile ids
  /// first.
  Future<int> pendingOutboxDepth(String accountId) async {
    final account = await _registry.findById(accountId);
    if (account == null) return 0;

    final driftFile = _resolveDbFile(account.dbFileName);
    if (driftFile == null) return 0;

    final db = UserDatabase(NativeDatabase(driftFile));
    try {
      return await db.outboxDao.totalDepth();
    } finally {
      await db.close();
    }
  }

  /// Resolves [dbFileName] to the drift_flutter on-disk file, or null if
  /// neither the `.sqlite`-suffixed nor the bare-name file exists.
  ///
  /// drift_flutter 0.2.8 stores driftDatabase(name: 'foo.db') as
  /// 'foo.db.sqlite' on the filesystem (see drift_flutter/src/native.dart
  /// line 51: `'$name.sqlite'`). Try the .sqlite-suffixed path first; fall
  /// back to the bare name so registry entries written before this fix are
  /// also handled.
  File? _resolveDbFile(String dbFileName) {
    final driftFile = File('$_dbPath/$dbFileName.sqlite');
    if (driftFile.existsSync()) return driftFile;
    final bareFile = File('$_dbPath/$dbFileName');
    if (bareFile.existsSync()) return bareFile;
    return null;
  }

  void _deleteDbFile(String dbFileName) {
    final file = _resolveDbFile(dbFileName);
    file?.deleteSync();
  }
}
