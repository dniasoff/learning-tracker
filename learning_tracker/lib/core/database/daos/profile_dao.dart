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
  ///
  /// Excludes tutored-mirror rows (`isTutored == true`): those are read-only
  /// copies of a talmid's data and are surfaced separately, never as one of
  /// the account's own profiles.
  Future<List<LearnerProfile>> getProfilesByAccount(int accountId) =>
      (select(learnerProfiles)..where(
            (t) => t.accountId.equals(accountId) & t.isTutored.equals(false),
          ))
          .get();

  /// Get a single profile by ID.
  Future<LearnerProfile?> getProfileById(int id) => (select(
    learnerProfiles,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Every `learner_profiles.id` on this device, unscoped by account.
  ///
  /// AUD-core-sync-34: extracted from three append-only sync mergers
  /// (LearningLedgerMerger, PointsLedgerMerger, RewardRedemptionMerger),
  /// which each independently ran the identical full-table scan to guard a
  /// `profileId` FK before inserting — three copies that would silently
  /// diverge if the guard logic ever needs to change (e.g. excluding
  /// soft-deleted profiles). Deliberately unscoped/unfiltered (matches the
  /// three call sites' prior inline behavior) — the guard only needs to know
  /// whether a row exists locally at all, not which account it belongs to.
  Future<Set<int>> existingProfileIds() async {
    final rows = await select(learnerProfiles).get();
    return rows.map((p) => p.id).toSet();
  }

  /// Count profiles for an account (own profiles only — tutored mirrors
  /// excluded).
  Future<int> countProfilesForAccount(int accountId) async {
    final count = countAll();
    final query = selectOnly(learnerProfiles)
      ..addColumns([count])
      ..where(
        learnerProfiles.accountId.equals(accountId) &
            learnerProfiles.isTutored.equals(false),
      );
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
  ///
  /// Excludes tutored-mirror rows (`isTutored == true`): those are surfaced in
  /// the dedicated talmid section, never as one of the account's own profiles.
  Stream<List<LearnerProfile>> watchProfilesByAccount(int accountId) =>
      (select(learnerProfiles)..where(
            (t) => t.accountId.equals(accountId) & t.isTutored.equals(false),
          ))
          .watch();

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

  /// AUD-core-database-01: the 6 profile-scoped tables that do NOT carry an
  /// `ON DELETE CASCADE` FK on `profileId` — see `tool/schema_check.dart`'s
  /// `_fkCascadeExemptTables` for the authoritative list and the reasoning.
  /// `ProfileRepositoryImpl.deleteProfile` already clears these explicitly
  /// before removing a *own* `learner_profiles` row; the tutored-mirror wipe
  /// path (below) must do the same or a revoked tutoring grant leaves the
  /// child's mirrored curriculum/schedule data on the tutor's device forever.
  ///
  /// Ordering matters: `point_configs`/`study_day_configs` hold a
  /// non-nullable FK to `curriculum_tracks` (PRAGMA foreign_keys = ON), so
  /// they must be cleared BEFORE `curriculum_tracks` itself — mirrors the
  /// order in `ProfileRepositoryImpl.deleteProfile`.
  Future<void> _wipeNonCascadingMirrorRows(int profileId) async {
    await (db.delete(
      db.pointConfigs,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.studyDayConfigs,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.curriculumTracks,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.profilePrograms,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.dailyPlans,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.outbox,
    )..where((t) => t.profileId.equals(profileId))).go();
  }

  /// Delete the tutored-mirror profile row for [grantId].
  ///
  /// The FK `ON DELETE CASCADE` on most child tables (completions,
  /// streak_events, learning_ledger, bookmarks, goals, etc.) means the
  /// `learner_profiles` row delete purges most mirrored data automatically.
  /// AUD-core-database-01: 6 tables (curriculum_tracks, daily_plans, outbox,
  /// point_configs, profile_programs, study_day_configs) have NO such FK, so
  /// [_wipeNonCascadingMirrorRows] clears them explicitly first — in the same
  /// transaction, so a mid-wipe crash never leaves a half-purged mirror.
  /// Returns the number of `learner_profiles` rows deleted (0 or 1).
  Future<int> deleteTutoredMirrorByGrantId(String grantId) =>
      db.transaction<int>(() async {
        final row =
            await (select(learnerProfiles)..where(
                  (t) =>
                      t.isTutored.equals(true) & t.tutorGrantId.equals(grantId),
                ))
                .getSingleOrNull();
        if (row == null) return 0;
        await _wipeNonCascadingMirrorRows(row.id);
        return (delete(
          learnerProfiles,
        )..where((t) => t.id.equals(row.id))).go();
      });

  /// Returns ALL tutored-mirror rows for [accountId] (own profiles excluded).
  ///
  /// Used to collect grant IDs before a bulk delete so callers can fire
  /// per-grant callbacks after the rows are gone.
  Future<List<LearnerProfile>> getTutoredMirrorsForAccount(int accountId) =>
      (select(learnerProfiles)..where(
            (t) => t.accountId.equals(accountId) & t.isTutored.equals(true),
          ))
          .get();

  /// Delete ALL tutored-mirror rows for the current account (used on sign-out).
  ///
  /// AUD-core-database-01: see [deleteTutoredMirrorByGrantId] — the same 6
  /// non-cascading tables are cleared for every wiped mirror, in the same
  /// transaction as the bulk `learner_profiles` delete.
  /// Returns the number of deleted rows (≥ 0).
  Future<int> deleteAllTutoredMirrors(int accountId) =>
      db.transaction<int>(() async {
        final rows = await getTutoredMirrorsForAccount(accountId);
        for (final row in rows) {
          await _wipeNonCascadingMirrorRows(row.id);
        }
        return (delete(learnerProfiles)..where(
              (t) => t.accountId.equals(accountId) & t.isTutored.equals(true),
            ))
            .go();
      });
}
