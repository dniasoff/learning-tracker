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
class ProfileDao extends DatabaseAccessor<UserDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  /// Get all profiles for an account.
  Future<List<LearnerProfile>> getProfilesByAccount(int accountId) => (select(
    learnerProfiles,
  )..where((t) => t.accountId.equals(accountId))).get();

  /// Get a single profile by ID.
  Future<LearnerProfile?> getProfileById(int id) => (select(
    learnerProfiles,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

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
  Stream<List<LearnerProfile>> watchProfilesByAccount(int accountId) => (select(
    learnerProfiles,
  )..where((t) => t.accountId.equals(accountId))).watch();

  // ── T1.isolation — outbox guard ─────────────────────────────────────────

  /// Returns `true` when [profileId] belongs to a tutored-mirror row that
  /// must NEVER push data into the tutor's own outbox.
  ///
  /// Fast path: queries a single row by PK.  Used by [OutboxProcessor] to
  /// skip drain for tutored profiles, guaranteeing read-only mirror isolation.
  Future<bool> isProfileTutored(int profileId) async {
    final row = await (select(
      learnerProfiles,
    )..where((t) => t.id.equals(profileId))).getSingleOrNull();
    return row?.isTutored ?? false;
  }

  // ── Tutored mirror helpers (T1.profile) ─────────────────────────────────

  /// Return the existing tutored-mirror profile row for the given
  /// (parentUid, remoteChildProfileId, grantId) triple, or null when none
  /// exists yet.
  Future<LearnerProfile?> getTutoredProfile({
    required String parentUid,
    required String remoteChildProfileId,
    required String grantId,
  }) =>
      (select(learnerProfiles)..where(
            (t) =>
                t.isTutored.equals(true) &
                t.tutorParentUid.equals(parentUid) &
                t.tutorRemoteProfileId.equals(remoteChildProfileId) &
                t.tutorGrantId.equals(grantId),
          ))
          .getSingleOrNull();

  /// Upsert the synthetic local profile for a tutored child.
  ///
  /// Re-entry is idempotent: if a row with the same
  /// (parentUid, remoteChildProfileId, grantId) already exists, the display
  /// name and mode are refreshed and the same local id is returned — no
  /// duplicate rows are ever created.
  Future<int> upsertTutoredProfile({
    required int accountId,
    required String parentUid,
    required String remoteChildProfileId,
    required String grantId,
    required String displayName,
    required String mode,
    required DateTime now,
  }) async {
    final existing = await getTutoredProfile(
      parentUid: parentUid,
      remoteChildProfileId: remoteChildProfileId,
      grantId: grantId,
    );
    if (existing != null) {
      // Refresh display name / mode in case they changed since last entry.
      await (update(
        learnerProfiles,
      )..where((t) => t.id.equals(existing.id))).write(
        LearnerProfilesCompanion(
          displayName: Value(displayName),
          mode: Value(mode),
          updatedAt: Value(now),
        ),
      );
      return existing.id;
    }
    return into(learnerProfiles).insert(
      LearnerProfilesCompanion.insert(
        accountId: accountId,
        displayName: displayName,
        mode: mode,
        createdAt: now,
        updatedAt: now,
        isTutored: const Value(true),
        tutorParentUid: Value(parentUid),
        tutorRemoteProfileId: Value(remoteChildProfileId),
        tutorGrantId: Value(grantId),
      ),
    );
  }

  // ── Mirror wipe helpers (T5.lifecycle) ──────────────────────────────────

  /// Delete the tutored-mirror profile row for [grantId].
  ///
  /// The FK `ON DELETE CASCADE` on every child table (completions,
  /// streak_events, learning_ledger, bookmarks, goals, etc.) means a single
  /// row delete here purges all mirrored data. Returns the number of rows
  /// deleted (0 or 1).
  Future<int> deleteTutoredMirrorByGrantId(String grantId) =>
      (delete(learnerProfiles)..where(
            (t) => t.isTutored.equals(true) & t.tutorGrantId.equals(grantId),
          ))
          .go();

  /// Delete ALL tutored-mirror rows for the current account (used on sign-out).
  ///
  /// Returns the number of deleted rows (≥ 0).
  Future<int> deleteAllTutoredMirrors(int accountId) =>
      (delete(learnerProfiles)..where(
            (t) => t.accountId.equals(accountId) & t.isTutored.equals(true),
          ))
          .go();
}
