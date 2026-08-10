import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';
import 'package:learning_tracker/core/database/tables/accounts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'user_profile_dao.g.dart';

// ---------------------------------------------------------------------------
// Backwards-compatibility aliases — callers that imported UserProfile /
// UserProfilesCompanion from user_profile_dao.dart continue to compile.
// The underlying generated types are Account / AccountsCompanion (schema v1).
// ---------------------------------------------------------------------------
typedef UserProfile = Account;
typedef UserProfilesCompanion = AccountsCompanion;

/// Tier enum mirrors the `tier` column values.
enum UserTier { cloudBorn, localBorn }

extension UserTierX on UserTier {
  String get dbValue => name;

  bool get isCloud => this == UserTier.cloudBorn;
  bool get isLocal => this == UserTier.localBorn;

  // AUD-core-database-14 (EH-5): stable code, not a pre-formatted English
  // message. value carried as debugDetail for logs only.
  static UserTier fromDb(String value) => switch (value) {
    'cloudBorn' => UserTier.cloudBorn,
    'localBorn' => UserTier.localBorn,
    _ => throw DaoInvariantError(DaoErrorCode.unknownAccountTier, value),
  };
}

/// Typed [UserTier] accessor for Drift-generated [Account] row.
extension AccountX on Account {
  /// Typed account tier parsed from the [tier] storage key.
  ///
  /// AUD-core-database-07 (EH-4): does NOT catch [UserTierX.fromDb]'s
  /// [DaoInvariantError] for an unrecognized value. That error is a
  /// programming-error signal (local DB corruption or a missed enum-value
  /// migration), not normal control flow — swallowing it and silently
  /// returning
  /// [UserTier.localBorn] previously made a `cloudBorn` account whose
  /// stored `tier` string ever drifted (bad migration, hand-edited row,
  /// future enum rename) silently behave as local-born everywhere
  /// accountTier is read (sync gating, balance-row eligibility per "Adults
  /// never have balance rows"), with nothing logged. Let it propagate.
  UserTier get accountTier => UserTierX.fromDb(tier);
}

/// DAO for the accounts table (was: user_profiles table).
@DriftAccessor(tables: [Accounts])
class UserProfileDao extends DatabaseAccessor<UserDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  Future<List<Account>> getAllUserProfiles() => select(accounts).get();

  Future<Account?> getUserProfileById(int id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Account?> getUserProfileByFirebaseUid(String firebaseUid) => (select(
    accounts,
  )..where((t) => t.firebaseUid.equals(firebaseUid))).getSingleOrNull();

  /// Find the local-born account matching an email. Returns null if no
  /// local-born row exists with that email (cloud-born rows are ignored).
  Future<Account?> findLocalBornByEmail(String email) =>
      (select(accounts)..where(
            (t) =>
                t.email.equals(email) &
                t.tier.equals(UserTier.localBorn.dbValue),
          ))
          .getSingleOrNull();

  /// Find the cloud-born account matching a Firebase UID.
  Future<Account?> findCloudBornByFirebaseUid(String firebaseUid) =>
      (select(accounts)..where(
            (t) =>
                t.firebaseUid.equals(firebaseUid) &
                t.tier.equals(UserTier.cloudBorn.dbValue),
          ))
          .getSingleOrNull();

  Future<List<Account>> findByTier(UserTier tier) =>
      (select(accounts)..where((t) => t.tier.equals(tier.dbValue))).get();

  Future<int> insertUserProfile(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateUserProfile(AccountsCompanion entry) =>
      update(accounts).replace(entry);

  /// Clears the local password hash for [profileId] without touching any other
  /// column. Used by the "discard local" account-merge choice. This is a
  /// TARGETED write — `updateUserProfile`/`replace` requires a complete row and
  /// would throw `InvalidDataException` for a partial (id + passwordHash only)
  /// companion, crashing the collision-resolution flow.
  Future<void> clearPasswordHash(int profileId) async {
    await (update(accounts)..where((t) => t.id.equals(profileId))).write(
      const AccountsCompanion(passwordHash: Value(null)),
    );
  }

  Future<int> deleteUserProfile(int id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  /// Atomic tier flip for the local → cloud upgrade flow (Epic 20 story 20.9).
  ///
  /// Updates tier, firebaseUid, and clears passwordHash in a single
  /// transaction so no intermediate invalid state can be observed.
  Future<void> upgradeLocalToCloud({
    required int profileId,
    required String firebaseUid,
    required DateTime updatedAt,
    String? email,
  }) async {
    await transaction(() async {
      await (update(accounts)..where((t) => t.id.equals(profileId))).write(
        AccountsCompanion(
          tier: Value(UserTier.cloudBorn.dbValue),
          firebaseUid: Value(firebaseUid),
          passwordHash: const Value(null),
          // Credential-less offline accounts upgrade with a real email the
          // user supplies now; replace the synthetic one. Absent = unchanged.
          email: email == null ? const Value.absent() : Value(email),
          updatedAt: Value(updatedAt),
        ),
      );
    });
  }

  /// Upsert a cloud-born profile by Firebase UID (LWW per v2 §4.1 settings).
  ///
  /// When [email] is not provided on insert, a placeholder derived from
  /// [firebaseUid] is stored. The real email will be populated by the
  /// cloud-born signup flow (Epic 20 story 20.6) once that lands.
  ///
  /// WS9.flows: [userMode] parameter removed — mode belongs to
  /// [learner_profiles.mode], not to an account.
  Future<void> upsertProfile({
    required String firebaseUid,
    required String displayName,
    required DateTime updatedAt,
    String? email,
  }) async {
    final existing = await getUserProfileByFirebaseUid(firebaseUid);

    if (existing == null) {
      await insertUserProfile(
        AccountsCompanion.insert(
          email: email ?? '$firebaseUid@cloud.placeholder',
          firebaseUid: Value(firebaseUid),
          tier: UserTier.cloudBorn.dbValue,
          displayName: displayName,
          createdAt: updatedAt,
          updatedAt: updatedAt,
        ),
      );
    } else if (updatedAt.isAfter(existing.updatedAt)) {
      await (update(accounts)..where((t) => t.id.equals(existing.id))).write(
        AccountsCompanion(
          displayName: Value(displayName),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }
}
