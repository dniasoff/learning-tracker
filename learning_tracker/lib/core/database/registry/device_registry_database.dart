import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/registry/tables/device_accounts.dart';
import 'package:learning_tracker/core/database/registry/tables/device_state.dart';
import 'package:learning_tracker/core/domain/value_objects/account_tier.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';

part 'device_registry_database.g.dart';

/// Typed [AccountTier] accessor for Drift-generated [DeviceAccount] row.
///
/// The serialised [DeviceAccount.tier] field uses the `'cloudBorn'` /
/// `'localBorn'` storage keys. This extension converts them to the typed
/// [AccountTier] enum so callers use `account.accountTier.isCloud` instead
/// of `account.tier == 'cloudBorn'` (W5.11 primitive-obsession sweep).
extension DeviceAccountX on DeviceAccount {
  /// Typed account tier parsed from the [tier] storage key.
  ///
  /// Falls back to [AccountTier.local] for any unrecognised value, via
  /// [AccountTier.tryFromStorageKey] rather than a try/catch around
  /// [AccountTier.fromStorageKey] — EH-4 forbids catching [ArgumentError]
  /// (an [Error] subtype; Errors are programming-bug signals meant to crash
  /// loudly, not be swallowed as control flow).
  AccountTier get accountTier =>
      AccountTier.tryFromStorageKey(tier) ?? AccountTier.local;
}

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
  ///
  /// If the removed account is the current `lastActiveAccountId`, the pointer
  /// is cleared so the next launch does NOT silently auto-activate an arbitrary
  /// fallback account against a dangling pointer (D10). Covers every removal
  /// caller (remove-cloud / delete-local / delete-cloud / dedupe).
  ///
  /// The delete and the pointer-clear are wrapped in a single
  /// `transaction()` (DB-2): without it, a process death between the two
  /// awaited writes commits the delete but never runs the clear, leaving
  /// `lastActiveAccountId` dangling at a row that no longer exists.
  Future<int> removeAccount(String accountId) => transaction(() async {
    final deleted = await (delete(
      deviceAccounts,
    )..where((t) => t.accountId.equals(accountId))).go();
    if (await getLastActiveAccountId() == accountId) {
      await setLastActiveAccountId(null);
    }
    return deleted;
  });

  /// Update the lastUsedAt timestamp for an account.
  Future<void> updateLastUsed(String accountId, DateTime time) =>
      (update(deviceAccounts)..where((t) => t.accountId.equals(accountId)))
          .write(DeviceAccountsCompanion(lastUsedAt: Value(time)));

  /// Update tier + firebaseUid after a local→cloud upgrade.
  Future<void> updateAccountTier(
    String accountId,
    String tier, {
    String? firebaseUid,
    String? email,
  }) => (update(deviceAccounts)..where((t) => t.accountId.equals(accountId)))
      .write(
        DeviceAccountsCompanion(
          tier: Value(tier),
          firebaseUid: Value(firebaseUid),
          // When a credential-less offline account upgrades, replace its
          // synthetic @offline.local email with the real one. Absent =
          // unchanged.
          email: email == null ? const Value.absent() : Value(email),
        ),
      );

  Future<int> _accountCount() async {
    final count = countAll();
    final query = selectOnly(deviceAccounts)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Merge duplicate-email registry rows down to one per email.
  ///
  /// Duplicates arise when a user deletes their cloud account server-side
  /// and re-signs-up with the same email — Firebase Auth issues a new uid,
  /// so [findByFirebaseUid] returns null and the sign-in path historically
  /// inserted a second registry row for the same email (the "two cards in
  /// the account picker" symptom).
  ///
  /// **DEC-34 (multi-session model):** Under DEC-34, distinct accounts
  /// (distinct emails) all remain authenticated simultaneously. This helper
  /// is NOT about different users — it targets duplicate rows for the SAME
  /// email (same user, different Firebase UID due to account deletion +
  /// re-signup). De-duping same-email duplicates is still correct and
  /// necessary; it does not conflict with the multi-session model. Kept.
  ///
  /// For each email group, keeps the row with the most-recent `lastUsedAt`
  /// and removes the others. Does NOT delete the orphan DB files on disk —
  /// that's a separate concern (the files become unreachable from the
  /// picker but remain recoverable if needed).
  ///
  /// Returns the number of rows removed.
  ///
  /// The whole merge runs inside a single enclosing `transaction()` (DB-2):
  /// [removeAccount] opens its own (nested/savepoint) transaction per row,
  /// but without an outer transaction a crash after merging some email
  /// groups and before others would leave a partially-deduped registry —
  /// some duplicate emails cleaned up, others not.
  Future<int> dedupeByEmail() async {
    final accounts = await getAllAccounts();
    final byEmail = <String, List<DeviceAccount>>{};
    for (final a in accounts) {
      final key = a.email.trim().toLowerCase();
      if (key.isEmpty) continue; // tolerate malformed legacy rows
      byEmail.putIfAbsent(key, () => <DeviceAccount>[]).add(a);
    }
    return transaction(() async {
      var removed = 0;
      for (final group in byEmail.values) {
        if (group.length <= 1) continue;
        // Keep the most-recently-used; remove the rest from the registry.
        group.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
        for (var i = 1; i < group.length; i++) {
          removed += await removeAccount(group[i].accountId);
        }
      }
      return removed;
    });
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
