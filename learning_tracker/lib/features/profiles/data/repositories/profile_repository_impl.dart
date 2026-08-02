import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
// AUD-profiles-02: TutorWriteException must propagate out of pushLearnerProfile
// (see below) instead of being swallowed by the offline-first catch-all — only
// the barrel import is permitted across the feature boundary (Rule 2).
import 'package:learning_tracker/features/tutoring/tutoring.dart';

final _log = AppLogger.instance;

/// Implementation of [ProfileRepository] using Drift database.
///
/// When a [SyncWriteFacade] is provided (cloud-born accounts), create / update /
/// delete operations are mirrored to Firestore so learner profiles survive
/// re-install and sync across devices. Local-born accounts pass null and
/// the repo stays local-only.
class ProfileRepositoryImpl implements ProfileRepository {
  final UserDatabase _db;
  final SyncWriteFacade? _syncEngine;

  ProfileRepositoryImpl(this._db, {SyncWriteFacade? syncEngine})
    : _syncEngine = syncEngine;

  static const int maxProfilesPerAccount = 10;
  static const _codec = LearnerProfileCodec();

  Map<String, dynamic> _toFirestorePayload(ProfileModel profile) =>
      _codec.encode(
        LearnerProfileRow(
          profileId: profile.id,
          accountId: profile.accountId,
          displayName: profile.displayName,
          mode: profile.mode,
          avatarIndex: profile.avatarIndex,
          createdAt: profile.createdAt,
          updatedAt: profile.updatedAt,
        ),
      );

  @override
  Future<List<ProfileModel>> getProfilesByAccount(int accountId) async {
    final rows = await _db.profileDao.getProfilesByAccount(accountId);
    return rows.map(ProfileModel.fromDriftRow).toList();
  }

  @override
  Future<ProfileModel?> getProfileById(int id) async {
    final row = await _db.profileDao.getProfileById(id);
    return row != null ? ProfileModel.fromDriftRow(row) : null;
  }

  @override
  Future<ProfileModel> createProfile({
    required int accountId,
    required String displayName,
    required String mode,
    int avatarIndex = 0,
  }) async {
    final trimmedName = displayName.trim();

    final count = await _db.profileDao.countProfilesForAccount(accountId);
    if (count >= maxProfilesPerAccount) {
      throw MaxProfilesExceededException(accountId);
    }

    // Case-insensitive duplicate name check
    final nameExists = await _db.profileDao.profileExistsByName(
      accountId,
      trimmedName,
    );
    if (nameExists) {
      throw DuplicateProfileNameException(trimmedName);
    }

    _log.info(event: 'profile_repo_create_start', fields: {'mode': mode});
    final now = DateTimeFactory.nowUtc();
    final id = await _db.profileDao.insertProfile(
      LearnerProfilesCompanion.insert(
        accountId: accountId,
        displayName: trimmedName,
        mode: mode,
        avatarIndex: Value(avatarIndex),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final model = ProfileModel(
      id: id,
      accountId: accountId,
      displayName: trimmedName,
      mode: mode,
      avatarIndex: avatarIndex,
      createdAt: now,
      updatedAt: now,
    );

    _log.info(
      event: 'profile_repo_create_done',
      fields: {'profileId': model.id},
    );
    // Profile creation must succeed offline-first even if cloud push fails —
    // but only when the failure is actually retryable. AUD-profiles-02: when
    // a tutor session is active, `_syncEngine` is a `TutoredWriteRouter`
    // (sync_providers.dart) that turns this into a one-shot, non-retryable
    // Cloud Function RPC; swallowing that failure the same way as a durable
    // outbox push silently strands the caller with no error. Let
    // `TutorWriteException` propagate; keep swallowing genuine
    // offline-first push failures on the durable (outbox) path.
    try {
      await _syncEngine?.pushLearnerProfile(_toFirestorePayload(model));
    } on TutorWriteException {
      rethrow;
    } catch (e, st) {
      // Non-fatal: cloud push failure is non-fatal; local write already
      // succeeded (offline-first). AUD-profiles-16 (EH-3): still log it —
      // silently discarding it left no telemetry trail to diagnose a real
      // failure pattern (e.g. outbox writes silently failing on a subset of
      // devices).
      _log.warning(
        event: 'profile_repo_create_cloud_push_failed',
        fields: {'profileId': model.id},
        exception: e,
        stackTrace: st,
      );
    }
    return model;
  }

  @override
  Future<ProfileModel> updateProfile({
    required int id,
    String? displayName,
    String? mode,
    int? avatarIndex,
  }) async {
    final existing = await _db.profileDao.getProfileById(id);
    if (existing == null) {
      throw StateError('Profile $id not found');
    }

    // Case-insensitive duplicate name check (excluding self)
    if (displayName != null) {
      final trimmedName = displayName.trim();
      final nameExists = await _db.profileDao.profileExistsByName(
        existing.accountId,
        trimmedName,
        excludeId: id,
      );
      if (nameExists) {
        throw DuplicateProfileNameException(trimmedName);
      }
    }

    final trimmedDisplayName = displayName?.trim();
    final now = DateTimeFactory.nowUtc();
    await (_db.update(
      _db.learnerProfiles,
    )..where((t) => t.id.equals(id))).write(
      LearnerProfilesCompanion(
        displayName: trimmedDisplayName != null
            ? Value(trimmedDisplayName)
            : const Value.absent(),
        mode: mode != null ? Value(mode) : const Value.absent(),
        avatarIndex: avatarIndex != null
            ? Value(avatarIndex)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    final updated = await _db.profileDao.getProfileById(id);
    final model = ProfileModel.fromDriftRow(updated!);
    // AUD-profiles-02: see the createProfile push above — a tutor-routed
    // push failure (`TutorWriteException`) must reach the caller (editProfileFlow
    // catches it and shows a snackbar) instead of being swallowed here as if
    // the durable offline-first outbox had queued a retry.
    try {
      await _syncEngine?.pushLearnerProfile(_toFirestorePayload(model));
    } on TutorWriteException {
      rethrow;
    } catch (e, st) {
      // Non-fatal: cloud push failure is non-fatal; local write already
      // succeeded (offline-first). AUD-profiles-16 (EH-3): still log it —
      // silently discarding it left no telemetry trail to diagnose a real
      // failure pattern (e.g. outbox writes silently failing on a subset of
      // devices).
      _log.warning(
        event: 'profile_repo_update_cloud_push_failed',
        fields: {'profileId': model.id},
        exception: e,
        stackTrace: st,
      );
    }
    return model;
  }

  @override
  Future<void> deleteProfile(int id, {bool allowLast = false}) async {
    _log.info(
      event: 'profile_repo_delete_start',
      fields: {'profileId': id, 'allowLast': allowLast},
    );
    // Guard: by default we refuse to leave the account with zero profiles —
    // the picker would have nothing to show. Callers can opt in via
    // `allowLast: true` after a strong confirmation; the empty-state UI in
    // ProfilePicker will route the user to add a fresh profile.
    if (!allowLast) {
      // Read the account from the profile we're about to delete so the
      // last-profile guard scopes to the right account (DNI-342).
      final existing = await _db.profileDao.getProfileById(id);
      if (existing != null) {
        final count = await countProfilesForAccount(existing.accountId);
        if (count <= 1) {
          throw const LastProfileException();
        }
      }
    }

    await _db.transaction(() async {
      // Cascade delete all associated data.
      // W3.20: `completions` and `streaks` tables dropped — their data is now
      // in `completion_events` and `streak_events` which cascade-delete via FK.
      await (_db.delete(
        _db.bookmarks,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(_db.goals)..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.stageDefinitions,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.learningOrder,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.pointConfigs,
      )..where((t) => t.profileId.equals(id))).go();
      // curriculum_scopes and study_day_configs hold a non-nullable (RESTRICT)
      // FK to curriculum_tracks, so they MUST be cleared BEFORE the tracks
      // themselves. Deleting curriculum_tracks first fails with
      // SqliteException(787) FOREIGN KEY constraint, which rolls back the whole
      // transaction — the profile is never deleted and the user just sees the
      // confirm dialog dismiss with nothing happening.
      await (_db.delete(
        _db.curriculumScopes,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.studyDayConfigs,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.curriculumTracks,
      )..where((t) => t.profileId.equals(id))).go();
      // learning_ledger.trackId is ON DELETE SET NULL, so its order relative to
      // curriculum_tracks does not matter.
      await (_db.delete(
        _db.learningLedger,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.profilePrograms,
      )..where((t) => t.profileId.equals(id))).go();
      // Canonical event logs + pending-command queue + derived plans.
      // completion_events / streak_events also cascade off the
      // learner_profiles delete, but clear them explicitly so the wipe does
      // not depend on FK-cascade ordering. `outbox` has no FK — without this
      // its pending pushes for the deleted profile would survive.
      await (_db.delete(
        _db.completionEvents,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.streakEvents,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.dailyPlans,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(_db.outbox)..where((t) => t.profileId.equals(id))).go();
      // Finally delete the profile itself
      await _db.profileDao.deleteProfile(id);
    });
    _log.info(
      event: 'profile_repo_delete_db_complete',
      fields: {'profileId': id},
    );

    await _syncEngine?.deleteLearnerProfile(id);
    _log.info(
      event: 'profile_repo_delete_sync_notified',
      fields: {'profileId': id},
    );
  }

  @override
  Future<int> countProfilesForAccount(int accountId) =>
      _db.profileDao.countProfilesForAccount(accountId);

  @override
  Future<int> ensureDefaultProfile({
    required int accountId,
    required String defaultDisplayName,
  }) async {
    // Fast path: account already owns a profile — nothing to heal.
    final existing = await _db.profileDao.getProfilesByAccount(accountId);
    if (existing.isNotEmpty) return existing.first.id;

    _log.warning(
      event: 'profile_self_heal_start',
      fields: {'accountId': accountId},
    );

    final now = DateTimeFactory.nowUtc();
    final trimmedName = defaultDisplayName.trim();
    final displayName = trimmedName.isEmpty ? 'Me' : trimmedName;

    // Single transaction: create the profile, then re-parent any orphaned
    // `profile_id = 0` rows that were written before a profile existed (e.g. a
    // track created on a profile-less account). These tables have no FK on
    // `learner_profiles`, so `profile_id = 0` rows are physically present and
    // must be adopted by the new profile rather than left stranded. The
    // FK-enforced tables (stage_definitions, goals, completion_events, …) can
    // never hold a `profile_id = 0` row, so they need no re-parenting.
    final newProfileId = await _db.transaction<int>(() async {
      final id = await _db.profileDao.insertProfile(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: displayName,
          mode: ProfileMode.adult.storageKey,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await (_db.update(_db.curriculumTracks)
            ..where((t) => t.profileId.equals(0)))
          .write(CurriculumTracksCompanion(profileId: Value(id)));
      await (_db.update(_db.pointConfigs)..where((t) => t.profileId.equals(0)))
          .write(PointConfigsCompanion(profileId: Value(id)));
      await (_db.update(_db.studyDayConfigs)
            ..where((t) => t.profileId.equals(0)))
          .write(StudyDayConfigsCompanion(profileId: Value(id)));
      await (_db.update(_db.profilePrograms)
            ..where((t) => t.profileId.equals(0)))
          .write(ProfileProgramsCompanion(profileId: Value(id)));
      await (_db.update(_db.dailyPlans)..where((t) => t.profileId.equals(0)))
          .write(DailyPlansCompanion(profileId: Value(id)));

      return id;
    });

    _log.info(
      event: 'profile_self_heal_done',
      fields: {'accountId': accountId, 'profileId': newProfileId},
    );

    // Mirror to the cloud so the healed profile survives re-install / sync.
    // Offline-first: a push failure is non-fatal — the local write stands.
    // AUD-profiles-02: still let a TutorWriteException propagate (see
    // createProfile above) rather than swallow it as a durable-outbox retry.
    try {
      await _syncEngine?.pushLearnerProfile(
        _toFirestorePayload(
          ProfileModel(
            id: newProfileId,
            accountId: accountId,
            displayName: displayName,
            mode: ProfileMode.adult.storageKey,
            avatarIndex: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
    } on TutorWriteException {
      rethrow;
    } catch (e, st) {
      // Non-fatal: cloud push failure is non-fatal; local write already
      // succeeded. AUD-profiles-16 (EH-3): still log it — silently
      // discarding it left no telemetry trail to diagnose a real failure
      // pattern (e.g. outbox writes silently failing on a subset of
      // devices).
      _log.warning(
        event: 'profile_self_heal_cloud_push_failed',
        fields: {'accountId': accountId, 'profileId': newProfileId},
        exception: e,
        stackTrace: st,
      );
    }

    return newProfileId;
  }
}

/// Session-scoped map of Drift `learner_profiles.id` (int) → Firestore
/// `learner_profiles/{profileId}` doc-id (ULID string), populated by
/// [FirestoreProfileRepositoryAdapter] the moment it mints a Firestore
/// identity for a profile.
///
/// ## Why a map, not a Drift column
///
/// A newly-created profile needs BOTH identities live at once so
/// [activeProfileDocIdProvider] can carry the ULID while every existing
/// Drift-keyed screen/provider/query keeps working unchanged during the
/// transition (every profile-scoped query in the app is still `WHERE
/// profile_id = <int>`). The two honest ways to make that pairing durable
/// are (a) a Drift schema migration adding a nullable `ulid` column to
/// `learner_profiles` — the exact pattern already used for
/// `learning_ledger`/`points_ledger`/`reward_redemptions` (`user_database.dart`
/// schema v27) — or (b) keep the pairing in memory for the running session.
/// (a) is real, bounded work (new column, `schemaVersion` bump, a guarded
/// `onUpgrade` step, a new `test/migration/vNN_to_vNN+1_test.dart`, and a
/// `build_runner` regen that touches every generated Drift file in the
/// repo) — out of scope for wiring *creation*, and deliberately not
/// attempted here (see this task's report). (b) is what this class is:
/// it makes a freshly-created profile's ULID resolvable for the rest of
/// this app session (immediately after creation, and on every subsequent
/// [SelectedProfileId.select] of that same profile —
/// `profile_providers.dart`) without touching `lib/core/database/**`.
///
/// **Known gap, not silently papered over:** a profile created in an
/// EARLIER app session (including every profile that existed before this
/// adapter shipped) has no entry here after a cold start — the same
/// profile that resolves fine here mid-session resolves to `null` again
/// after a restart, exactly like [activeProfileDocIdProvider] resolves to
/// `null` for every profile today. That is the sequencing fact (a) above
/// exists to close, not something this cache can paper over.
// keepAlive: must survive the same route changes/unrelated rebuilds
// SelectedProfileId (profile_providers.dart) already requires of itself —
// losing this mid-session would silently blank activeProfileDocIdProvider
// on the next profile switch.
class ProfileUlidSessionCache extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() => const {};

  /// Records that Drift profile [profileId] now has Firestore identity
  /// [ulid].
  void put(int profileId, String ulid) => state = {...state, profileId: ulid};

  /// Returns the Firestore ULID recorded for [profileId] this session, or
  /// `null` when none is known (not yet minted, or minted in a session
  /// that has since ended — see the class doc comment).
  String? ulidFor(int profileId) => state[profileId];

  /// Drops any cached pairing for [profileId] (e.g. on profile delete) so a
  /// stale ULID is never handed back for an id `learner_profiles` no longer
  /// contains.
  void remove(int profileId) {
    if (!state.containsKey(profileId)) return;
    final next = {...state}..remove(profileId);
    state = next;
  }
}

/// keepAlive: mirrors [ProfileUlidSessionCache]'s own reasoning — the
/// pairing must survive the same rebuilds `SelectedProfileId` does.
final profileUlidSessionCacheProvider =
    NotifierProvider<ProfileUlidSessionCache, Map<int, String>>(
      ProfileUlidSessionCache.new,
    );

/// Firestore-backed [ProfileRepository] adapter — wraps a
/// [ProfileRepositoryImpl] instance rather than replacing it (dual-write,
/// TEMPORARY — see the class doc comment for what removes it), following
/// the reference pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// establishes. Read that class's doc comment first; this one only calls
/// out what is DIFFERENT for profiles.
///
/// ## Dual-write, not cutover — and why
///
/// Every OTHER Firestore adapter in this codebase (bookmarks, etc.) fully
/// replaces its Drift-era sibling: the interface is entity-shaped, so
/// swapping the backing store is invisible to callers. Profiles cannot do
/// that yet — [ProfileRepository]'s whole interface is `int`-keyed
/// (`ProfileModel.id`), and that int is threaded through a great many
/// profile-scoped screens/providers/queries this task is not asked to
/// convert. So this adapter does NOT swap Drift for Firestore; it does
/// both: every write still goes through [_drift] first (unchanged
/// behavior — the local row, and its existing legacy `_syncEngine` push,
/// are exactly as before), and this class ADDITIONALLY mints a Firestore
/// `learner_profiles` document for a genuinely NEW profile and activates
/// it via [activeProfileDocIdProvider]. This is explicitly temporary: it
/// goes away the moment [ProfileRepository] (and every caller keyed off
/// `ProfileModel.id`) is converted to the ULID identity end-to-end — at
/// that point [_drift] and the Drift-only creation path it wraps are
/// deleted outright, not merged into this class.
///
/// ## `null`/non-fatal on Firestore failure — matches [_drift]'s own
/// convention
///
/// [_drift]'s `createProfile`/`ensureDefaultProfile` already treat a cloud
/// push failure as non-fatal (logged, swallowed) so profile creation stays
/// offline-first; this class's Firestore mint attempt (
/// [_mintAndActivateFirestoreProfile]) follows the exact same shape,
/// including for the expected, common case of a still-local-born account
/// (`firestoreLearnerProfileRepositoryProvider` resolves `null` — no
/// active cloud account yet) — see `docs/`'s offline-account-model notes.
/// [activeProfileDocIdProvider] simply stays unset in that case, exactly
/// its documented `null` == "not ready yet" contract.
class FirestoreProfileRepositoryAdapter implements ProfileRepository {
  FirestoreProfileRepositoryAdapter({
    required Ref ref,
    required ProfileRepositoryImpl driftRepository,
  }) : _ref = ref,
       _drift = driftRepository;

  final Ref _ref;
  final ProfileRepositoryImpl _drift;

  @override
  Future<List<ProfileModel>> getProfilesByAccount(int accountId) =>
      _drift.getProfilesByAccount(accountId);

  @override
  Future<ProfileModel?> getProfileById(int id) => _drift.getProfileById(id);

  @override
  Future<int> countProfilesForAccount(int accountId) =>
      _drift.countProfilesForAccount(accountId);

  @override
  Future<ProfileModel> updateProfile({
    required int id,
    String? displayName,
    String? mode,
    int? avatarIndex,
  }) => _drift.updateProfile(
    id: id,
    displayName: displayName,
    mode: mode,
    avatarIndex: avatarIndex,
  );

  @override
  Future<void> deleteProfile(int id, {bool allowLast = false}) async {
    await _drift.deleteProfile(id, allowLast: allowLast);
    // Hygiene only: firestore.rules denies client-side delete on
    // learner_profiles (see FirestoreLearnerProfileRepository's class doc
    // comment, "No delete method") — nothing here deletes the Firestore
    // document. This just stops a stale ULID from being handed back for a
    // Drift id that no longer exists.
    _ref.read(profileUlidSessionCacheProvider.notifier).remove(id);
  }

  @override
  Future<ProfileModel> createProfile({
    required int accountId,
    required String displayName,
    required String mode,
    int avatarIndex = 0,
  }) async {
    final model = await _drift.createProfile(
      accountId: accountId,
      displayName: displayName,
      mode: mode,
      avatarIndex: avatarIndex,
    );
    await _mintAndActivateFirestoreProfile(model);
    return model;
  }

  @override
  Future<int> ensureDefaultProfile({
    required int accountId,
    required String defaultDisplayName,
  }) async {
    // [_drift.ensureDefaultProfile]'s own contract (see its doc comment):
    // a no-op fast path when the account already owns ≥1 profile, a real
    // create when it owns zero. Checked BEFORE calling it — the return
    // value alone (just an int id) cannot distinguish the two branches,
    // and minting a Firestore doc on every fast-path call would create a
    // duplicate `learner_profiles` document each time this runs (e.g.
    // every cold start) for an already-existing profile.
    final existingBefore = await _drift.getProfilesByAccount(accountId);
    final id = await _drift.ensureDefaultProfile(
      accountId: accountId,
      defaultDisplayName: defaultDisplayName,
    );
    if (existingBefore.isEmpty) {
      final model = await _drift.getProfileById(id);
      if (model != null) await _mintAndActivateFirestoreProfile(model);
    }
    return id;
  }

  /// Mints a fresh Firestore `learner_profiles` document for the just-
  /// created [model], records the (Drift id → ULID) pairing in
  /// [profileUlidSessionCacheProvider], and activates it via
  /// [activeProfileDocIdProvider]. Non-fatal on any failure — see the
  /// class doc comment.
  Future<void> _mintAndActivateFirestoreProfile(ProfileModel model) async {
    try {
      final firestoreRepo = await _ref.read(
        firestoreLearnerProfileRepositoryProvider.future,
      );
      if (firestoreRepo == null) return; // no active cloud account yet
      final entity = await firestoreRepo.createProfile(
        displayName: model.displayName,
        mode: model.profileMode,
        avatar: model.avatarIndex.toString(),
      );
      _ref
          .read(profileUlidSessionCacheProvider.notifier)
          .put(model.id, entity.profileId);
      _ref.read(activeProfileDocIdProvider.notifier).set(entity.profileId);
    } catch (e, st) {
      // Non-fatal: mirrors _drift's own cloud-push failure handling above —
      // the local (Drift) profile already exists and is usable; this just
      // means no Firestore identity exists for it yet.
      _log.warning(
        event: 'profile_repo_firestore_mint_failed',
        fields: {'profileId': model.id},
        exception: e,
        stackTrace: st,
      );
    }
  }
}
