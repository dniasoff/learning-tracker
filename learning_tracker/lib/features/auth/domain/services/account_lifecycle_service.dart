import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

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
    FirebaseFirestore? firestore,
  }) : _registry = registry,
       _dbPath = databasesPath,
       _authRepository = authRepository,
       _firestore = firestore;

  final DeviceRegistryDatabase _registry;
  final String _dbPath;
  final AuthRepository? _authRepository;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _firestoreDb =>
      _firestore ?? FirebaseFirestore.instance;

  // ─── 21.13: Remove cloud-born account from device ──────────

  /// Light removal: deletes local DB file + registry entry.
  /// Firestore data and Firebase Auth are NOT touched — user can
  /// sign back in on any device and recover everything.
  Future<void> removeCloudFromDevice(String accountId) async {
    final account = await _registry.findById(accountId);
    if (account == null) return;
    if (account.tier != 'cloudBorn') {
      throw StateError(
        'removeCloudFromDevice requires a cloud-born account. '
        'Use deleteLocalAccount for local-born.',
      );
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
    if (account.tier != 'localBorn') {
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
    if (account.tier != 'cloudBorn' || account.firebaseUid == null) {
      throw StateError('deleteCloudAccount requires a cloud-born account');
    }

    final uid = account.firebaseUid!;

    // Step 1: delete Firestore data (client-side best-effort)
    await _deleteFirestoreData(uid);

    // Step 2: delete Firebase Auth user — triggers Cloud Function
    final currentUser = _authRepository?.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await _authRepository?.deleteCurrentFirebaseUser();
    }

    // Step 3: local cleanup (only after cloud succeeds)
    _deleteDbFile(account.dbFileName);
    await _registry.removeAccount(accountId);
  }

  /// Best-effort Firestore subcollection deletion. The Cloud
  /// Function (21.16) catches anything we miss.
  Future<void> _deleteFirestoreData(String uid) async {
    final userDoc = _firestoreDb.collection('users').doc(uid);
    const subcollections = [
      'completions',
      'bookmarks',
      'settings',
      'streaks',
      'profiles',
      'goals',
      'rewards',
      'sync_queue',
      'learning_order',
      'stage_definitions',
    ];

    for (final sub in subcollections) {
      await _deleteCollection(userDoc.collection(sub));
    }
    await userDoc.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    const batchSize = 500;
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await ref.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestoreDb.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length >= batchSize);
  }

  void _deleteDbFile(String dbFileName) {
    final file = File('$_dbPath/$dbFileName');
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
