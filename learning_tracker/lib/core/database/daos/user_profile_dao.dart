import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/user_profiles.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  Future<List<UserProfile>> getAllUserProfiles() => select(userProfiles).get();

  Future<UserProfile?> getUserProfileById(int id) =>
      (select(userProfiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<UserProfile?> getUserProfileByFirebaseUid(String firebaseUid) =>
      (select(
        userProfiles,
      )..where((t) => t.firebaseUid.equals(firebaseUid))).getSingleOrNull();

  Future<int> insertUserProfile(UserProfilesCompanion entry) =>
      into(userProfiles).insert(entry);

  Future<bool> updateUserProfile(UserProfilesCompanion entry) =>
      update(userProfiles).replace(entry);

  Future<int> deleteUserProfile(int id) =>
      (delete(userProfiles)..where((t) => t.id.equals(id))).go();
}
