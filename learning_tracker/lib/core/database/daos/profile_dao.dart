import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'profile_dao.g.dart';

// ---------------------------------------------------------------------------
// Backwards-compatibility aliases — callers that imported Profile /
// ProfilesCompanion from profile_dao.dart continue to compile.
// The underlying generated types are LearnerProfile / LearnerProfilesCompanion.
// ---------------------------------------------------------------------------
typedef Profile = LearnerProfile;
typedef ProfilesCompanion = LearnerProfilesCompanion;

/// DAO for the learner_profiles table (was: profiles table).
@DriftAccessor(tables: [LearnerProfiles])
class ProfileDao extends DatabaseAccessor<UserDatabase>
    with _$ProfileDaoMixin {
  ProfileDao(super.db);

  /// Get all profiles for an account.
  Future<List<LearnerProfile>> getProfilesByAccount(int accountId) =>
      (select(learnerProfiles)
            ..where((t) => t.accountId.equals(accountId)))
          .get();

  /// Get a single profile by ID.
  Future<LearnerProfile?> getProfileById(int id) =>
      (select(learnerProfiles)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Count profiles for an account.
  Future<int> countProfilesForAccount(int accountId) async {
    final count = countAll();
    final query = selectOnly(learnerProfiles)
      ..addColumns([count])
      ..where(learnerProfiles.accountId.equals(accountId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Insert a new profile. Returns the profile ID.
  Future<int> insertProfile(LearnerProfilesCompanion entry) =>
      into(learnerProfiles).insert(entry);

  /// Update an existing profile.
  Future<bool> updateProfile(LearnerProfilesCompanion entry) =>
      update(learnerProfiles).replace(entry);

  /// Delete a profile by ID.
  Future<int> deleteProfile(int id) =>
      (delete(learnerProfiles)..where((t) => t.id.equals(id))).go();

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
  Stream<List<LearnerProfile>> watchProfilesByAccount(int accountId) =>
      (select(learnerProfiles)
            ..where((t) => t.accountId.equals(accountId)))
          .watch();
}
