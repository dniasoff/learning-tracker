import 'package:learning_tracker/core/database/drift_db_file.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';

/// Service handling account removal from a device.
///
/// [removeCloudFromDevice] is the sole operation: a light local cleanup
/// (delete the local DB file + registry entry) that leaves Firestore and
/// Firebase Auth untouched — the user can sign back in on any device and
/// recover everything.
class AccountLifecycleService {
  AccountLifecycleService({
    required DeviceRegistryDatabase registry,
    required String databasesPath,
    AuthRepository? authRepository,
  }) : _registry = registry,
       _dbPath = databasesPath,
       _authRepository = authRepository;

  final DeviceRegistryDatabase _registry;
  final String _dbPath;
  final AuthRepository? _authRepository;

  // ─── 21.13: Remove cloud-born account from device ──────────

  /// Light removal: deletes local DB file + registry entry.
  /// Firestore data and Firebase Auth are NOT touched — user can
  /// sign back in on any device and recover everything.
  ///
  /// Known gap: the Drift-outbox guard that used to block removal while
  /// writes were undrained has been removed because the Drift outbox no
  /// longer exists. The closest equivalent risk today is the Firestore
  /// SDK's own local offline-write queue — a queued write can still be
  /// stranded if the account is removed from the device before it flushes.
  /// This is NOT currently checked; `FirebaseFirestore.waitForPendingWrites()`
  /// is the primitive to use if that guard is rebuilt later.
  Future<void> removeCloudFromDevice(String accountId) async {
    final account = await _registry.findById(accountId);
    if (account == null) return;
    if (!account.accountTier.isCloud) {
      throw StateError(
        'removeCloudFromDevice requires a cloud-born account.',
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

  // AUD-account-09: the .sqlite-suffix delete-with-fallback logic used to
  // live here as a private method; it now lives in
  // core/database/drift_db_file.dart.
  void _deleteDbFile(String dbFileName) =>
      deleteDriftDbFile(_dbPath, dbFileName);
}
