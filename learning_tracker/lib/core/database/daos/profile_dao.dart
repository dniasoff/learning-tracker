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

/// Thrown by [ProfileDao.upsertFromSync] when the row it was asked to
/// insert has no local counterpart yet AND no `ulid` to give the new row
/// (T-41).
///
/// The legacy int-keyed sync engine's `learner_profiles` wire format
/// (`LearnerProfileCodec`, `lib/core/sync/codec/learner_profile_codec.dart`)
/// has never carried a `ulid` field, in either `encode()` or `decode()` — it
/// predates the ULID identity entirely. So when this device pulls a profile
/// it has never locally seen before (typically: a profile created on a
/// SIBLING device, first observed here on this device's own sync pull),
/// there is no identity on the wire to carry onto the new local row.
///
/// Two tempting fixes were rejected on purpose:
///  - **Insert with `ulid` left unset.** `ProfileModel.fromDriftRow` (P2-3)
///    throws a hard `StateError` the next time ANYTHING reads this row —
///    at whatever unrelated screen happens to touch it next, far from this
///    call site and with no context linking the crash back to a sync pull.
///  - **Mint a fresh ULID here.** The profile already has a real identity —
///    whichever ULID its owning device minted for it under the eager-mint
///    policy (P2-2). Minting a second one here would hand this device's
///    copy of the SAME profile a different identity than the rest of the
///    world uses for it — exactly the "two identities for one profile"
///    defect class this whole phase exists to close, not a fix for it.
///
/// So this path refuses instead: fail loudly, here, with a message that
/// names the actual cause, rather than manufacture a row that becomes a
/// landmine for a random later reader. `LearnerProfileMerger.merge`
/// (`lib/core/sync/merge/learner_profile_merger.dart`) wraps every row in
/// `on Exception catch` — the same per-row isolation it already uses for a
/// malformed or FK-violating remote row — so this exception fails only the
/// one offending row (logged via `sync_learner_profile_merge_row_failed`),
/// not the whole sync pull. Because `DriftMergeStore.upsert` runs inside
/// that same per-row `runInTransaction` block, throwing here also rolls
/// back anything `DriftMergeStore._resolveLocalAccountId` may have already
/// written (e.g. a placeholder `accounts` row) for this same row — no
/// partial state survives a refused insert.
///
/// A profile in this shape is not lost: the old int-keyed sync engine dies
/// wholesale in Phase 4, and every profile this device creates ITSELF
/// already carries a real ULID from the moment it exists (P2-2's eager
/// mint) — this refusal only ever fires for a profile-identity value this
/// device never legitimately had a way to represent in the first place.
class ProfileSyncMissingUlidException implements Exception {
  const ProfileSyncMissingUlidException(this.remoteProfileId);

  /// The `learner_profiles.id` the sync pull tried to insert.
  final int remoteProfileId;

  @override
  String toString() =>
      'ProfileSyncMissingUlidException: remote learner_profiles id '
      '$remoteProfileId has no local row yet, and the legacy int-keyed sync '
      'payload carries no ulid to give a new one — refusing to insert an '
      'unidentified profile row (T-41). This profile must already exist '
      'locally (created here, or restored) for this sync pull to update it.';
}

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

  /// Count every own (non-tutored) profile in this per-account user DB,
  /// unscoped by account id.
  ///
  /// The user database file is per-account (one `accounts` row per file), so
  /// "any own profile exists here" ⇔ "the active account has ≥1 profile" — no
  /// need to resolve the int account id. Used by `AuthGuard` to treat an
  /// already-set-up account as onboarded even when the device-global
  /// `kOnboardingComplete` flag is false (e.g. cleared on an account switch).
  /// Lightest possible query — a COUNT, never a full fetch.
  Future<int> countOwnProfiles() async {
    final count = countAll();
    final query = selectOnly(learnerProfiles)
      ..addColumns([count])
      ..where(learnerProfiles.isTutored.equals(false));
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

  /// Upsert a profile row from a remote sync payload, keyed by [id] (the
  /// remote-assigned `learner_profiles.id` — profile ids are shared,
  /// server-assigned identifiers, not per-device autoincrement values).
  ///
  /// AUD-core-sync-22 (DB-1): extracted from DriftMergeStore, which
  /// previously wrote `_db.into(_db.learnerProfiles)` /
  /// `_db.update(_db.learnerProfiles)` directly instead of routing through
  /// this DAO, despite its own class doc claiming every write goes through
  /// one. [accountId] must already be resolved to a LOCAL `accounts.id`
  /// before calling (DriftMergeStore's `_resolveLocalAccountId` — the
  /// remote's `account_id` almost never matches the local autoincrement id).
  ///
  /// **Update only — this path can no longer INSERT (T-41).** When a local
  /// row for [id] already exists, this updates only the fields a remote
  /// sync payload can legitimately change ([displayName], [mode],
  /// [avatarIndex], [updatedAt]); [accountId]/[createdAt] are left
  /// untouched, matching the prior inline behavior — and `ulid` is never
  /// touched either way, so whatever identity the existing row already
  /// carries survives a sync update unchanged.
  ///
  /// When NO local row exists for [id], this throws
  /// [ProfileSyncMissingUlidException] instead of inserting one — see that
  /// class's doc comment for why. Before T-41, this branch inserted a full
  /// row with no `ulid`, which read back fine at the time but crashed the
  /// next time anything mapped it to the domain model
  /// (`ProfileModel.fromDriftRow`'s `StateError`, added by P2-3) — at
  /// whatever unrelated call site happened to read it next.
  Future<void> upsertFromSync({
    required int id,
    required int accountId,
    required String displayName,
    required String mode,
    required int avatarIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final existing = await getProfileById(id);
    if (existing == null) {
      throw ProfileSyncMissingUlidException(id);
    }
    await (update(learnerProfiles)..where((t) => t.id.equals(id))).write(
      LearnerProfilesCompanion(
        displayName: Value(displayName),
        mode: Value(mode),
        avatarIndex: Value(avatarIndex),
        updatedAt: Value(updatedAt),
      ),
    );
  }

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
        // P2-2 (T-31 decoupled line item): the mirror RECORDS the remote
        // child's own Firestore profile id as its `ulid` — it never mints a
        // fresh one. A fresh mint here would create a second identity for
        // the same child, which is exactly the defect this column exists
        // to prevent.
        ulid: Value(remoteChildProfileId),
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
