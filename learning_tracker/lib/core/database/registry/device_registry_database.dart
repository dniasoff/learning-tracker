import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/registry/tables/device_accounts.dart';
import 'package:learning_tracker/core/database/registry/tables/device_state.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';

part 'device_registry_database.g.dart';

/// Maximum number of accounts allowed on a single device.
const kMaxDeviceAccounts = 5;

/// Thrown when attempting to add a 6th account.
class MaxAccountsReachedException extends ValidationException {
  const MaxAccountsReachedException()
    : super('Device already has $kMaxDeviceAccounts accounts');
}

/// Tiny Drift database that tracks all accounts on this device.
///
/// Separate from any account's [UserDatabase] — different lifecycle,
/// different file, different migration path. Opens at app startup
/// BEFORE any user DB.
@DriftDatabase(tables: [DeviceAccounts, DeviceState])
class DeviceRegistryDatabase extends _$DeviceRegistryDatabase {
  DeviceRegistryDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // ───── DeviceAccounts queries ─────────────────────────────────

  /// All accounts ordered by most recently used first.
  Future<List<DeviceAccount>> getAllAccounts() => (select(
    deviceAccounts,
  )..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])).get();

  /// Watch the account list (for Riverpod stream).
  Stream<List<DeviceAccount>> watchAllAccounts() => (select(
    deviceAccounts,
  )..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])).watch();

  /// Find by email (case-insensitive). Used by sign-in routing.
  ///
  /// Historically, duplicate rows could exist for a given email during
  /// transitional multi-account migrations. Prefer the most recently used
  /// account instead of throwing "Bad state: Too many elements".
  Future<DeviceAccount?> findByEmail(String email) async {
    final rows =
        await (select(deviceAccounts)
              ..where((t) => t.email.lower().equals(email.trim().toLowerCase()))
              ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Find by Firebase UID. Used for cloud-born session matching.
  ///
  /// Mirrors [findByEmail] behavior to tolerate duplicate rows safely.
  Future<DeviceAccount?> findByFirebaseUid(String uid) async {
    final rows =
        await (select(deviceAccounts)
              ..where((t) => t.firebaseUid.equals(uid))
              ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Find by account ID.
  Future<DeviceAccount?> findById(String accountId) => (select(
    deviceAccounts,
  )..where((t) => t.accountId.equals(accountId))).getSingleOrNull();

  /// Add a new account. Throws [MaxAccountsReachedException] if
  /// the device already has [kMaxDeviceAccounts] accounts.
  Future<void> addAccount(DeviceAccountsCompanion account) async {
    final count = await _accountCount();
    if (count >= kMaxDeviceAccounts) {
      throw const MaxAccountsReachedException();
    }
    await into(deviceAccounts).insert(account);
  }

  /// Remove an account from the registry (does NOT delete the DB file).
  Future<int> removeAccount(String accountId) => (delete(
    deviceAccounts,
  )..where((t) => t.accountId.equals(accountId))).go();

  /// Update the lastUsedAt timestamp for an account.
  Future<void> updateLastUsed(String accountId, DateTime time) =>
      (update(deviceAccounts)..where((t) => t.accountId.equals(accountId)))
          .write(DeviceAccountsCompanion(lastUsedAt: Value(time)));

  /// Update tier + firebaseUid after a local→cloud upgrade.
  Future<void> updateAccountTier(
    String accountId,
    String tier, {
    String? firebaseUid,
  }) => (update(deviceAccounts)..where((t) => t.accountId.equals(accountId)))
      .write(
        DeviceAccountsCompanion(
          tier: Value(tier),
          firebaseUid: Value(firebaseUid),
        ),
      );

  Future<int> _accountCount() async {
    final count = countAll();
    final query = selectOnly(deviceAccounts)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ───── DeviceState queries ────────────────────────────────────

  static const _kLastActiveAccountId = 'lastActiveAccountId';

  /// Get the last active account ID (or null if not set / cleared).
  Future<String?> getLastActiveAccountId() async {
    final row = await (select(
      deviceState,
    )..where((t) => t.key.equals(_kLastActiveAccountId))).getSingleOrNull();
    return row?.value;
  }

  /// Set the last active account ID. Pass null to clear.
  Future<void> setLastActiveAccountId(String? accountId) async {
    await into(deviceState).insertOnConflictUpdate(
      DeviceStateCompanion.insert(
        key: _kLastActiveAccountId,
        value: Value(accountId),
      ),
    );
  }
}
