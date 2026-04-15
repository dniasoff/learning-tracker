import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'user_profile_dao.g.dart';

/// Tier enum mirrors the `tier` column values.
enum UserTier { cloudBorn, localBorn }

extension UserTierX on UserTier {
  String get dbValue => name;

  static UserTier fromDb(String value) => switch (value) {
    'cloudBorn' => UserTier.cloudBorn,
    'localBorn' => UserTier.localBorn,
    _ => throw StateError('Unknown tier: $value'),
  };
}

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<UserDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  Future<List<UserProfile>> getAllUserProfiles() => select(userProfiles).get();

  Future<UserProfile?> getUserProfileById(int id) =>
      (select(userProfiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<UserProfile?> getUserProfileByFirebaseUid(String firebaseUid) =>
      (select(
        userProfiles,
      )..where((t) => t.firebaseUid.equals(firebaseUid))).getSingleOrNull();

  /// Find the local-born account matching an email. Returns null if no
  /// local-born row exists with that email (cloud-born rows are ignored).
  Future<UserProfile?> findLocalBornByEmail(String email) =>
      (select(userProfiles)..where(
            (t) =>
                t.email.equals(email) &
                t.tier.equals(UserTier.localBorn.dbValue),
          ))
          .getSingleOrNull();

  /// Find the cloud-born account matching a Firebase UID.
  Future<UserProfile?> findCloudBornByFirebaseUid(String firebaseUid) =>
      (select(userProfiles)..where(
            (t) =>
                t.firebaseUid.equals(firebaseUid) &
                t.tier.equals(UserTier.cloudBorn.dbValue),
          ))
          .getSingleOrNull();

  Future<List<UserProfile>> findByTier(UserTier tier) =>
      (select(userProfiles)..where((t) => t.tier.equals(tier.dbValue))).get();

  Future<int> insertUserProfile(UserProfilesCompanion entry) =>
      into(userProfiles).insert(entry);

  Future<bool> updateUserProfile(UserProfilesCompanion entry) =>
      update(userProfiles).replace(entry);

  Future<int> deleteUserProfile(int id) =>
      (delete(userProfiles)..where((t) => t.id.equals(id))).go();

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
      await (update(userProfiles)..where((t) => t.id.equals(profileId))).write(
        UserProfilesCompanion(
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
        UserProfilesCompanion.insert(
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
      await (update(
        userProfiles,
      )..where((t) => t.id.equals(existing.id))).write(
        UserProfilesCompanion(
          displayName: Value(displayName),
          userMode: Value(userMode),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }
}
