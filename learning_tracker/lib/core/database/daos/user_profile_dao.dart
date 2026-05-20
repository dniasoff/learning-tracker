import 'package:drift/drift.dart';
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

  static UserTier fromDb(String value) => switch (value) {
    'cloudBorn' => UserTier.cloudBorn,
    'localBorn' => UserTier.localBorn,
    _ => throw StateError('Unknown tier: $value'),
  };
}

/// Typed [UserTier] accessor for Drift-generated [Account] row.
///
/// Falls back to [UserTier.localBorn] for any unrecognised value.
extension AccountX on Account {
  /// Typed account tier parsed from the [tier] storage key.
  UserTier get accountTier {
    try {
      return UserTierX.fromDb(tier);
    } on StateError {
      return UserTier.localBorn;
    }
  }
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
  }) async {
    await transaction(() async {
      await (update(accounts)..where((t) => t.id.equals(profileId))).write(
        AccountsCompanion(
          tier: Value(UserTier.cloudBorn.dbValue),
          firebaseUid: Value(firebaseUid),
          passwordHash: const Value(null),
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
  Future<void> upsertProfile({
    required String firebaseUid,
    required String displayName,
    required String userMode,
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
          userMode: userMode,
          createdAt: updatedAt,
          updatedAt: updatedAt,
        ),
      );
    } else if (updatedAt.isAfter(existing.updatedAt)) {
      await (update(accounts)..where((t) => t.id.equals(existing.id))).write(
        AccountsCompanion(
          displayName: Value(displayName),
          userMode: Value(userMode),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }
}
