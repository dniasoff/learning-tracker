import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/profiles.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'profile_dao.g.dart';

/// DAO for the profiles table.
@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<UserDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  /// Get all profiles for an account.
  Future<List<Profile>> getProfilesByAccount(int accountId) =>
      (select(profiles)..where((t) => t.accountId.equals(accountId))).get();

  /// Get a single profile by ID.
  Future<Profile?> getProfileById(int id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Count profiles for an account.
  Future<int> countProfilesForAccount(int accountId) async {
    final count = countAll();
    final query = selectOnly(profiles)
      ..addColumns([count])
      ..where(profiles.accountId.equals(accountId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Insert a new profile. Returns the profile ID.
  Future<int> insertProfile(ProfilesCompanion entry) =>
      into(profiles).insert(entry);

  /// Update an existing profile.
  Future<bool> updateProfile(ProfilesCompanion entry) =>
      update(profiles).replace(entry);

  /// Delete a profile by ID.
  Future<int> deleteProfile(int id) =>
      (delete(profiles)..where((t) => t.id.equals(id))).go();

  /// Check if a profile with the given name (case-insensitive, trimmed)
  /// already exists for the account. Optionally excludes a profile by ID
  /// (for rename self-match).
  Future<bool> profileExistsByName(
    int accountId,
    String displayName, {
    int? excludeId,
  }) async {
    final allProfiles = await getProfilesByAccount(accountId);
    final normalized = displayName.trim().toLowerCase();
    return allProfiles.any(
      (p) =>
          p.displayName.trim().toLowerCase() == normalized &&
          (excludeId == null || p.id != excludeId),
    );
  }

  /// Watch all profiles for an account.
  Stream<List<Profile>> watchProfilesByAccount(int accountId) =>
      (select(profiles)..where((t) => t.accountId.equals(accountId))).watch();
}
