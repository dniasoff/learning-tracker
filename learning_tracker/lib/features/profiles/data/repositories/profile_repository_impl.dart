import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
// P2-2: this file lives under `data/repositories/` — the directory
// `check_dependency_direction.dart` (audit check 102) exempts from the
// "no lib/features/** → lib/data/** import" rule — so it is the one place
// allowed to import DocIds at all. P2-10: within this file, only
// `_resolveProfileUlid` (below) ever calls `DocIds.mintProfileUlid()` — see
// that function's own doc comment. See `ProfileRepository.createProfile`'s
// doc comment for why every OTHER caller (screens, `profile_providers.dart`)
// never mints one itself.
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
// AUD-profiles-02: TutorWriteException must propagate out of pushLearnerProfile
// (see below) instead of being swallowed by the offline-first catch-all — only
// the barrel import is permitted across the feature boundary (Rule 2).
import 'package:learning_tracker/features/tutoring/tutoring.dart';

final _log = AppLogger.instance;

/// Resolves [ulid] to a value guaranteed non-null. **This is the ONE call
/// site in the codebase that ever calls [DocIds.mintProfileUlid] — every
/// place that used to call the minter directly (`ProfileRepositoryImpl`'s
/// `createProfile`/`ensureDefaultProfile`, `FirestoreProfileRepositoryAdapter`'s
/// same two methods) now routes through this function instead.** A prior
/// version of this file made that claim about "exactly one site mints" while
/// four separate lines each called `DocIds.mintProfileUlid()` directly —
/// true only in the sense that production traffic always resolves through
/// the adapter first (see [FirestoreProfileRepositoryAdapter.createProfile]),
/// never a literal fact about the source text a reader could grep for. This
/// function makes the grep and the claim agree: `grep -rn
/// 'DocIds.mintProfileUlid()' lib/` now returns exactly one line, here.
///
/// [ProfileRepositoryImpl] still cannot make its own [ulid] parameter
/// `required` — it deliberately keeps implementing the full
/// [ProfileRepository] interface (not just the adapter-wrapped path) so a
/// caller can use it standalone as a local-only repository, no Firestore
/// adapter involved (`profile_edit_delete_actions_test.dart`'s
/// AUD-profiles-02 test does exactly this, overriding
/// `profileRepositoryProvider` with a bare `ProfileRepositoryImpl` to prove
/// `TutorWriteException` propagation without any Firestore machinery in the
/// way) — and [ProfileRepository.createProfile]/`.ensureDefaultProfile`
/// declare [ulid] optional for every OTHER caller (screens can never supply
/// one; check 102 forbids them importing [DocIds]). Dart's override rules
/// forbid narrowing an inherited optional named parameter to required
/// (verified directly: `dart analyze` on a minimal repro reports
/// `invalid_override`), so as long as [ProfileRepositoryImpl] implements
/// [ProfileRepository], its `ulid` parameter must stay `String?` too. This
/// function is the compile-time-cheapest way to guarantee only one place
/// ever manufactures a fresh value regardless.
String _resolveProfileUlid(String? ulid) => ulid ?? DocIds.mintProfileUlid();

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

  /// Same lookup as [getProfileById], but returns `null` instead of
  /// throwing when the row exists with a legacy `ulid IS NULL` (pre-P2-2) —
  /// [ProfileModel.fromDriftRow]'s [StateError] is the right signal for a
  /// genuine read (see its own doc comment: wipe and reseed), but the wrong
  /// one for "is there a ulid to heal onto" (T-40). Used only by
  /// [FirestoreProfileRepositoryAdapter]'s post-creation/activation heal
  /// decisions, which must degrade to "nothing to heal" rather than crash
  /// on a legacy row.
  Future<ProfileModel?> tryGetProfileById(int id) async {
    final row = await _db.profileDao.getProfileById(id);
    if (row == null || row.ulid == null) return null;
    return ProfileModel.fromDriftRow(row);
  }

  @override
  Future<ProfileModel> createProfile({
    required int accountId,
    required String displayName,
    required String mode,
    int avatarIndex = 0,
    String? ulid,
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
    // P2-2: eager, unconditional mint — every profile gets a Firestore
    // identity at creation, atomically with the Drift insert below, never
    // left null for a later edit to lazily backfill. [ulid] is normally
    // already minted by the caller (`FirestoreProfileRepositoryAdapter`);
    // [_resolveProfileUlid]'s own fallback only fires for a caller that
    // bypasses the adapter (e.g. a test constructing this class directly).
    final resolvedUlid = _resolveProfileUlid(ulid);
    final id = await _db.profileDao.insertProfile(
      LearnerProfilesCompanion.insert(
        accountId: accountId,
        displayName: trimmedName,
        mode: mode,
        avatarIndex: Value(avatarIndex),
        createdAt: now,
        updatedAt: now,
        ulid: Value(resolvedUlid),
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
      ulid: resolvedUlid,
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
    String? ulid,
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
    // P2-2: eager, unconditional mint — see the matching comment in
    // [createProfile]. Only reached on the self-heal path (the fast-path
    // return above never gets here), so nothing is wasted minting on a
    // no-op call.
    final resolvedUlid = _resolveProfileUlid(ulid);

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
          ulid: Value(resolvedUlid),
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
            ulid: resolvedUlid,
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

  /// No-op: this Drift-only implementation has no Firestore mirror to heal
  /// — see the class doc comment ("Local-born accounts pass null and the
  /// repo stays local-only"). [FirestoreProfileRepositoryAdapter] overrides
  /// this with the real T-40 activation heal.
  @override
  Future<void> ensureRemoteProfile(int id) async {}
}

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
/// both: this class mints the profile's Firestore identity EAGERLY (P2-2
/// — before [_drift]'s insert, not after it) and threads it through, so
/// the write to [_drift] (unchanged behavior otherwise — the local row,
/// and its existing legacy `_syncEngine` push, are exactly as before)
/// lands WITH its `ulid` already set, then this class ensures the matching
/// Firestore `learner_profiles` document exists and activates it via
/// [activeProfileDocIdProvider]. This is explicitly temporary: it goes
/// away the moment [ProfileRepository] (and every caller keyed off
/// `ProfileModel.id`) is converted to the ULID identity end-to-end — at
/// that point [_drift] and the Drift-only creation path it wraps are
/// deleted outright, not merged into this class.
///
/// ## Pairing the two identities: the `ulid` column, not a session cache
///
/// A profile needs BOTH identities live at once so [activeProfileDocIdProvider]
/// can carry the ULID while every existing Drift-keyed screen/provider/
/// query keeps working unchanged during the transition. That pairing is
/// stored durably on the Drift row itself — `learner_profiles.ulid`
/// (schema v38, `ProfileModel.ulid`, `learner_profiles.dart`'s `ulid`
/// column doc comment) — not in an in-memory cache, so it survives a
/// restart and is visible to any caller that already reads a
/// [ProfileModel] (e.g. [SelectedProfileId.select] in
/// `profile_providers.dart`, which reads `ulid` back to set
/// [activeProfileDocIdProvider] on every profile switch, not just a
/// same-session one). A prior version of this adapter used a session-only
/// `Map<int, String>` cache instead; that was rejected (see git history) —
/// it made every pre-existing/older-session profile permanently
/// unresolvable, which is not a bridge the next stage (rewiring every
/// remaining feature) can stand on.
///
/// ## Identity policy (P2-2): eager and unconditional — never lazy
///
/// Every profile is minted a Firestore identity BEFORE its Drift row is
/// ever inserted — [createProfile] and the self-heal branch of
/// [ensureDefaultProfile] mint via `_resolveProfileUlid` (this file's
/// top-level function, the one place `DocIds.mintProfileUlid()` is ever
/// called) first, then pass the same value into [_drift]'s insert, so the
/// row and its `ulid`
/// come into existence atomically. There is no longer a lazy, on-edit
/// backfill path: [updateProfile] does not mint. A profile created before
/// this policy shipped (schema v38, pre-P2-2) can still have `ulid IS
/// NULL` — greenfield: that is not healed by this adapter; the remedy is
/// wiping and reseeding the device, not a migration this class performs.
///
/// **`ulid == null` on a row created under this policy should never
/// happen** — every method below still returns/operates on [ProfileModel]s
/// exactly as [_drift] does, and a `null` `ulid` now means either a
/// pre-P2-2 legacy row or (transiently) that a caller bypassed the eager
/// mint contract; callers must never treat it as the profile being invalid
/// or absent.
///
/// ## Non-fatal on Firestore failure, but identity activates regardless
///
/// [_drift]'s `createProfile`/`ensureDefaultProfile` already treat a cloud
/// push failure as non-fatal (logged, swallowed) so profile creation stays
/// offline-first; [_ensureFirestoreProfile] follows the same shape for the
/// remote `learner_profiles` document write — but unlike the old
/// mint-then-activate design, [activeProfileDocIdProvider] is now set
/// whenever a cloud account is active, REGARDLESS of whether that specific
/// remote write succeeds: the identity is already real and local (eagerly
/// minted, on the Drift row) the moment this runs, so there is nothing to
/// gate activation on. [activeProfileDocIdProvider] stays unset only for
/// the genuinely not-ready case — a still-local-born account
/// (`firestoreLearnerProfileRepositoryProvider` resolves `null`, no active
/// cloud account yet) — see `docs/`'s offline-account-model notes.
///
/// ## A profile created while offline still gets its remote document (T-40)
///
/// [_ensureFirestoreProfile] itself only ever runs at [createProfile]/
/// [ensureDefaultProfile] — i.e. once, at the instant a cloud outage would
/// have caused the failure in the first place, with no retry of its own.
/// The actual heal is [ensureRemoteProfile]: a SEPARATE call site fired on
/// every profile ACTIVATION (`lib/app/router/app_shell.dart`'s
/// `ref.listen(selectedProfileIdProvider, …)` — every cold-start re-select
/// AND every manual profile switch, since both set that provider), not only
/// at creation. It re-reads the Drift row (cheap, local, always available)
/// and re-runs the SAME idempotent merge write
/// ([FirestoreLearnerProfileRepository.ensureProfile], never
/// `created_at`-clobbering — see that method's own doc comment) every time
/// the profile activates, so a document that was still missing after
/// creation gets created the very next time its profile is selected with
/// the network back — including the next app launch. This replaces a design
/// that briefly shipped (`0d5d9125`) claiming [_ensureFirestoreProfile]
/// alone would "heal it the next time it runs" — false, since nothing ever
/// called it again for an already-created profile; see
/// `docs/planning/firestore-cutover-log.md`'s P2-8 entry for the correction.
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

  // P2-10: was a verbose async pass-through whose only content was a
  // comment explaining what it no longer does (no lazy ulid backfill on
  // edit — see the class doc comment's "Identity policy" and "A profile
  // created while offline still gets its remote document" sections, which
  // already cover this ground). Collapsed to match the plain forwarding
  // style [getProfilesByAccount]/[getProfileById]/[countProfilesForAccount]/
  // [deleteProfile] already use above — [_drift] does the only real work.
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
  Future<void> deleteProfile(int id, {bool allowLast = false}) =>
      _drift.deleteProfile(id, allowLast: allowLast);
  // firestore.rules denies client-side delete on learner_profiles (see
  // FirestoreLearnerProfileRepository's class doc comment, "No delete
  // method") — nothing here deletes the Firestore document; the Drift row
  // (and its `ulid` column) is simply gone once this returns, same as
  // before this adapter existed.

  @override
  Future<ProfileModel> createProfile({
    required int accountId,
    required String displayName,
    required String mode,
    int avatarIndex = 0,
    String? ulid,
  }) async {
    // P2-2: mint BEFORE the Drift insert — this is the only PRODUCTION
    // caller of `_resolveProfileUlid` that ever actually needs its fallback
    // to fire (see that function's own doc comment for why it, not this
    // call site, is the literal one place `DocIds.mintProfileUlid()`
    // appears in `lib/`) — and thread the same value through to [_drift],
    // so the local row and the eventual Firestore document always agree on
    // the id. A caller-supplied [ulid] (tests only, in production this is
    // always omitted here) is honored rather than re-minted, so two
    // independent identities are never produced for the same creation.
    final resolvedUlid = _resolveProfileUlid(ulid);
    final model = await _drift.createProfile(
      accountId: accountId,
      displayName: displayName,
      mode: mode,
      avatarIndex: avatarIndex,
      ulid: resolvedUlid,
    );
    await _ensureFirestoreProfile(model);
    return model;
  }

  @override
  Future<int> ensureDefaultProfile({
    required int accountId,
    required String defaultDisplayName,
    String? ulid,
  }) async {
    // T-40: ONE decision, made from the row [_drift] actually returns — not
    // a separate pre-read of `getProfilesByAccount` that could disagree
    // with [_drift]'s own re-read a moment later. That double-decision
    // (fixed here) could strand a profile permanently: if the two reads
    // disagreed, [_drift] could mint and insert a new row while this
    // adapter — deciding from its OWN stale read — believed no creation
    // happened and skipped the heal entirely. Minting eagerly and
    // unconditionally costs nothing to waste (`_resolveProfileUlid`'s
    // fallback is a pure local generator, no I/O — see [createProfile]'s
    // comment); the
    // fast (no-op) path inside [_drift.ensureDefaultProfile] simply ignores
    // it. [_drift.tryGetProfileById] never throws for a legacy pre-P2-2
    // `ulid IS NULL` row — see its own doc comment — so the fast path
    // landing on such a row (never backfilled here, "Identity policy")
    // safely skips the heal instead of crashing.
    final resolvedUlid = _resolveProfileUlid(ulid);
    final id = await _drift.ensureDefaultProfile(
      accountId: accountId,
      defaultDisplayName: defaultDisplayName,
      ulid: resolvedUlid,
    );
    final model = await _drift.tryGetProfileById(id);
    if (model != null) await _ensureFirestoreProfile(model);
    return id;
  }

  /// Activation-time heal (T-40): the replacement for the lazy backfill
  /// P2-2 deleted. [_ensureFirestoreProfile] alone (called only from
  /// [createProfile]/[ensureDefaultProfile]) fires exactly once, at the
  /// instant a network outage would have caused the original failure — with
  /// no retry, a profile created offline got a local ULID and permanently
  /// no remote document. This method is the real retry: called every time
  /// [id]'s profile is ACTIVATED (`lib/app/router/app_shell.dart`'s
  /// `ref.listen(selectedProfileIdProvider, …)`), not only at creation, so
  /// the SAME idempotent merge write runs again on every cold start and
  /// every manual profile switch until it succeeds. No-op (never throws)
  /// when [id] has no matching row or no `ulid` yet to heal onto — see
  /// [ProfileRepositoryImpl.tryGetProfileById].
  @override
  Future<void> ensureRemoteProfile(int id) async {
    try {
      final model = await _drift.tryGetProfileById(id);
      if (model == null) return;
      await _ensureFirestoreProfile(model);
    } catch (e, st) {
      // Defensive: _ensureFirestoreProfile already swallows the Firestore
      // write's own failures (see its doc comment); this catches anything
      // else (e.g. a Drift read racing a close) so a fire-and-forget caller
      // (`app_shell.dart` calls this via `unawaited(...)`) can never surface
      // an unhandled Future error.
      _log.warning(
        event: 'profile_repo_ensure_remote_profile_failed',
        fields: {'profileId': id},
        exception: e,
        stackTrace: st,
      );
    }
  }

  /// Idempotent create-if-missing write for [model]'s Firestore
  /// `learner_profiles/{ulid}` document, then activates it via
  /// [activeProfileDocIdProvider]. Called from THREE places: [createProfile],
  /// [ensureDefaultProfile]'s self-heal branch, and — T-40 — every profile
  /// activation via the public [ensureRemoteProfile] above. Always goes
  /// through [FirestoreLearnerProfileRepository.ensureProfile] (never the
  /// deleted `createProfile`): that method's write never re-sends
  /// `created_at` once a document exists, so calling this on every
  /// activation cannot clobber a real creation timestamp with "now" — see
  /// its own doc comment for the mechanism. This method NEVER mints;
  /// [model.ulid] is always already set (eager mint, see
  /// [createProfile]/[ensureDefaultProfile] above).
  ///
  /// Non-fatal on a Firestore failure — profiles are offline-first by
  /// explicit contract (`tutor_invites.ts:59-60`), so a remote outage must
  /// never block profile creation, and a genuine account-resolution failure
  /// (e.g. [AccountNotAuthenticatedException], which
  /// `firestoreLearnerProfileRepositoryProvider` propagates as an
  /// `AsyncError` rather than swallowing into `null` — see
  /// `repository_providers.dart`'s library doc comment) must not escape
  /// either, so the provider read below sits INSIDE the `try`, not before
  /// it. [activeProfileDocIdProvider] is still set whenever a cloud account
  /// is active, REGARDLESS of whether this specific write succeeds — see
  /// the class doc comment, "Non-fatal on Firestore failure, but identity
  /// activates regardless." It is left unset only in the genuinely
  /// not-ready case (no active cloud account at all yet — the early
  /// `return` below, which is not a failure and must not be caught).
  Future<void> _ensureFirestoreProfile(ProfileModel model) async {
    try {
      final firestoreRepo = await _ref.read(
        firestoreLearnerProfileRepositoryProvider.future,
      );
      if (firestoreRepo == null) return; // no active cloud account yet
      await firestoreRepo.ensureProfile(
        profileId: model.ulid,
        displayName: model.displayName,
        mode: model.profileMode,
        avatar: model.avatarIndex.toString(),
      );
    } catch (e, st) {
      // Non-fatal: mirrors _drift's own cloud-push failure handling above —
      // the local (Drift) profile already exists and is usable; this just
      // means the remote resolve/write failed, e.g. a network outage or an
      // auth-resolution error. The identity is still activated below; T-40's
      // real retry is [ensureRemoteProfile], fired on the profile's next
      // activation, not "the next time this exact method happens to run".
      _log.warning(
        event: 'profile_repo_firestore_ensure_failed',
        fields: {'profileId': model.id},
        exception: e,
        stackTrace: st,
      );
    }
    _ref.read(activeProfileDocIdProvider.notifier).set(model.ulid);
  }
}
