/// Firestore implementation for curriculum tracks — the repository that
/// absorbs TWO Drift DAOs into one (`docs/firestore-rewrite-map.md`).
/// Follows the shape `FirestoreStageDefinitionRepository`/
/// `FirestoreGoalRepository` established; see this file's own doc comments
/// for what is genuinely new.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

/// Firestore-backed curriculum-track repository: `users/{uid}/
/// learner_profiles/{profileId}/curriculum_tracks/{curriculumId}`
/// (`docs/firestore-rewrite-map.md`, `firestore.rules` `match
/// /curriculum_tracks/{trackId}`).
///
/// **Not wired into the app's production provider yet** — but
/// `FirestoreCurriculumTrackRepositoryAdapter`
/// (`lib/features/tracks/setup/data/repositories/
/// curriculum_track_repository_impl.dart`) exists and does read this class.
/// That adapter itself is not constructed by any real provider (it appears
/// nowhere in `lib/` outside its own definition and its tests), so no
/// screen reaches this repository through it yet. The existing Drift-backed
/// `TrackDao`/`ActiveCurriculumDao` are untouched and still serve the app.
///
/// **No interface** — same reasoning as `FirestoreBookmarkRepository`'s doc
/// comment: the Drift implementations are being deleted outright, not kept
/// alongside this one.
///
/// ## Two DAOs collapse into one repository
///
/// `TrackDao` owns the track lifecycle (activate / retire / archive /
/// restore-or-create / pace-reset / reorder-amnesty stamp); `ActiveCurriculumDao`
/// is a thin by-profile "which curricula are active" wrapper OVER `TrackDao`
/// — every one of its query methods is `WHERE state = 'active'` against the
/// exact same table, and its two mutating methods
/// (`deactivateByProfile`/`archiveByProfile`) are themselves just
/// `TrackDao.deleteTrackAndData`/`archiveTrack` wrapped in a "don't drop
/// below one active curriculum" guard. In Firestore both DAOs' data lives
/// on the SAME document (`state` is a field, not a separate table), so the
/// split has no structural reason to survive: this repository is
/// `ActiveCurriculumDao`'s guard logic layered directly onto `TrackDao`'s
/// state-transition methods, both scoped by the constructor-level
/// [profileId] the way every repository here already is (no more
/// `int profileId` parameter threaded through every call, no more
/// `activateByProfile`/`activate` legacy-profile-0 method pairs — AD-24
/// already made [profileId] a required String ULID everywhere).
///
/// [retireTrack] and [archiveTrack] below are exactly this merge: each is
/// `TrackDao`'s own state-transition body PLUS `ActiveCurriculumDao`'s
/// "would this drop the profile to zero active curricula" guard, run as one
/// atomic-from-the-caller's-perspective operation instead of two DAOs
/// calling into each other.
///
/// ## Deletion is NOT this repository's job
///
/// `TrackDao.deleteTrackAndData`/`purgeHistory` doesn't exist here at all —
/// not trimmed-and-noted, just absent. Both used to soft/hard-delete 10-11
/// Drift tables in one transaction; in Firestore that sweep is already
/// implemented server-side, in the `deleteCurriculumTrack` Cloud Function
/// (`functions/src/deletes.ts`), which sweeps the six sibling collections
/// (`goals`, `stage_definitions`, `study_day_configs`, `curriculum_scopes`,
/// `learning_order`, `profile_programs`) plus this track document itself via
/// `BulkWriter`/`recursiveDelete`. `firestore.rules` backs this up
/// structurally: `curriculum_tracks` is `allow delete: if false` — there is
/// no rules-legal way for ANY client method on this class to remove this
/// document. Callers that need "delete and wipe history" call the Cloud
/// Function, not this repository.
///
/// ## `state == 'deleted'` does not survive into Firestore
///
/// See [CurriculumTrackEntity.state]'s doc comment for the full reasoning —
/// short version: Drift's soft-delete tombstone existed to propagate a
/// deletion through the (now-deleted) LWW sync engine; the Cloud Function
/// above hard-deletes the document instead, so a purged track's signal is
/// [getTrack] returning `null`, never a fourth state value. This repository
/// never constructs, writes, or exposes a `'deleted'` state.
///
/// ## `reorder-amnesty stamp` — rules gap closed, code gap remains
///
/// `TrackDao.stampReorderAt` (`lastReorderAt`) used to have **no Firestore
/// field to carry it**: `firestore.rules`' `curriculum_tracks` `.hasOnly()`
/// whitelist (mirrored 1:1 in `tutor_writes.ts`'s
/// `CURRICULUM_TRACK_ALLOWED_FIELDS`) omitted `last_reorder_at` entirely, and
/// because `hasOnly()` is all-or-nothing, writing that field would have made
/// `permission-denied` reject the ENTIRE document write, for the legitimate
/// owner, on every track write this repository makes.
///
/// **That rules gap is now closed.** Both `firestore.rules`' whitelist and
/// `tutor_writes.ts`'s mirrored `CURRICULUM_TRACK_ALLOWED_FIELDS` include
/// `last_reorder_at` today, so a client write from this repository CAN
/// legally carry the stamp without endangering the rest of the document.
///
/// **This repository was never updated to use that opening, though.** There
/// is still no method here that writes `last_reorder_at` — `TrackDao
/// .stampReorderAt` has no counterpart in this class, so the field goes
/// unwritten regardless of what the rules now permit. And even once such a
/// method exists, `daily_task_projection_service.dart` still reads
/// `lastReorderAt` from **Drift** (`db.trackDao.getActiveTracksForProfile`),
/// not from Firestore, so a write from here would not yet reach that
/// consumer either. Porting the reorder-amnesty feature needs (1) a write
/// method on this class and (2) rewiring the projection service's read
/// side — the `firestore.rules`/`tutor_writes.ts` blocker that used to make
/// this impossible outright is gone; what remains is a code/wiring gap, not
/// a rules-imposed one.
///
/// ## `purged` / `purged_at` are in the whitelist but likewise unused here
///
/// Both existed as `TrackDao.purgeHistory`'s tombstone-before-hard-delete
/// payload, pushed through the (deleted) sync engine's outbox so other
/// devices could see a purge before the local hard-delete round-tripped.
/// With deletion routed through `deleteCurriculumTrack` (a synchronous
/// Cloud Function every device calls directly, no outbox relay needed),
/// there is no remaining reason for a CLIENT to ever write these — left in
/// the rules whitelist for backward-reads of any pre-rewrite document only.
class FirestoreCurriculumTrackRepository {
  FirestoreCurriculumTrackRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final AppLogger _logger;

  CollectionReference<Map<String, dynamic>> get _tracks => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('curriculum_tracks');

  DocumentReference<Map<String, dynamic>> _doc(CurriculumId curriculumId) =>
      _tracks.doc(
        DocIds.curriculumTrackDocId({'curriculum_id': curriculumId.storageKey}),
      );

  CurriculumTrackEntity? _decode(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    return curriculumTrackFromFirestore(data);
  }

  /// Returns the track for [curriculumId], or `null` if it has never been
  /// activated (or was purged — see the class doc comment's "`state ==
  /// 'deleted'`" section).
  Future<CurriculumTrackEntity?> getTrack(CurriculumId curriculumId) async {
    final snapshot = await _doc(curriculumId).get();
    return _decode(snapshot);
  }

  /// Live updates for [curriculumId]'s track. Resubscribes with bounded
  /// exponential backoff if the underlying listener errors
  /// (`resilientDocStream`).
  Stream<CurriculumTrackEntity?> watchTrack(CurriculumId curriculumId) {
    return resilientDocStream<CurriculumTrackEntity?>(
      openStream: () => _doc(curriculumId).snapshots(),
      decode: _decode,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_curriculum_track_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    );
  }

  /// Mirrors `TrackDao.isTrackActive` / `ActiveCurriculumDao.isActiveForProfile`
  /// — both were the same query under two names.
  Future<bool> isActive(CurriculumId curriculumId) async {
    final track = await getTrack(curriculumId);
    return track?.isActive ?? false;
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row
  /// fail the whole read — same "one bad document should not blank the
  /// list" treatment every multi-document read in this rewrite applies.
  List<CurriculumTrackEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <CurriculumTrackEntity>[];
    for (final doc in docs) {
      try {
        results.add(curriculumTrackFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_curriculum_tracks_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Every track for this profile (any state). Unfiltered — no `where()`/
  /// `orderBy()`, so no composite index needed.
  Future<List<CurriculumTrackEntity>> getAllTracks() async {
    final snapshot = await _tracks.get();
    return _decodeAll(snapshot.docs);
  }

  /// Live updates for every track for this profile (`resilientQueryStream`
  /// — one bad document is skipped, not the whole list).
  Stream<List<CurriculumTrackEntity>> watchAllTracks() {
    return resilientQueryStream<CurriculumTrackEntity>(
      openStream: () => _tracks.snapshots(),
      decode: (doc) => curriculumTrackFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_curriculum_tracks_watch_error',
        exception: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Single-field equality filter on `state` — no composite index needed
  /// (unlike `FirestoreStageDefinitionRepository`'s `curriculum_id` +
  /// `stage_order` query, this never adds an `orderBy` on a different
  /// field; sorting happens client-side below instead, the same
  /// index-avoidance choice `FirestoreGoalRepository` makes for a different
  /// reason — see that class's doc comment).
  Query<Map<String, dynamic>> get _activeQuery =>
      _tracks.where('state', isEqualTo: CurriculumTrackState.active.storageKey);

  static int _byCurriculumId(
    CurriculumTrackEntity a,
    CurriculumTrackEntity b,
  ) => a.curriculumId.storageKey.compareTo(b.curriculumId.storageKey);

  /// Every ACTIVE track for this profile, sorted by `curriculumId` —
  /// mirrors `TrackDao.getActiveTracksForProfile`'s
  /// `orderBy(curriculumId asc)`, done client-side (see [_activeQuery]'s
  /// doc comment for why).
  Future<List<CurriculumTrackEntity>> getActiveTracks() async {
    final snapshot = await _activeQuery.get();
    return _decodeAll(snapshot.docs)..sort(_byCurriculumId);
  }

  /// Live updates for [getActiveTracks], sorted the same way.
  Stream<List<CurriculumTrackEntity>> watchActiveTracks() {
    return resilientQueryStream<CurriculumTrackEntity>(
      openStream: () => _activeQuery.snapshots(),
      decode: (doc) => curriculumTrackFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_curriculum_tracks_active_watch_error',
        exception: error,
        stackTrace: stackTrace,
      ),
    ).map(
      (tracks) => List<CurriculumTrackEntity>.of(tracks)..sort(_byCurriculumId),
    );
  }

  /// Mirrors `ActiveCurriculumDao.getActiveCurriculaByProfile` — just the
  /// curriculum-id projection of [getActiveTracks]. One track per
  /// curriculum (W3.22) so no dedup is needed (the Drift version's
  /// `.toSet()` was defensive against a pre-W3.22 multi-track-per-curriculum
  /// shape that no longer exists).
  Future<List<String>> getActiveCurriculumIds() async =>
      (await getActiveTracks()).map((t) => t.curriculumId.storageKey).toList();

  /// Mirrors `ActiveCurriculumDao.watchActiveCurriculaByProfile`.
  Stream<List<String>> watchActiveCurriculumIds() => watchActiveTracks().map(
    (tracks) => tracks.map((t) => t.curriculumId.storageKey).toList(),
  );

  /// Mirrors `TrackDao.countActiveTracksForProfile`.
  Future<int> countActiveTracks() async => (await getActiveTracks()).length;

  /// Activates [curriculumId]'s track — creating it if it has never
  /// existed, or reactivating it from any non-active state (retired or
  /// archived). Idempotent: a no-op re-fetch if already active.
  ///
  /// Collapses THREE near-duplicate Drift entry points into one honest
  /// method: `TrackDao.activateTrack` (insert-or-reactivate),
  /// `TrackDao.restoreOrCreate` (identical insert-or-reactivate logic, just
  /// also returning the Drift row id — meaningless here, there is no
  /// integer id), and `TrackDao.initializeDefaultTracks`
  /// (insert-if-truly-absent only, deliberately does NOT reactivate a
  /// retired/archived row — the one genuinely different behavior of the
  /// three). That narrower "never reactivate" semantics is not preserved as
  /// a separate method: nothing under `lib/features/` calls any of the
  /// three yet (this repository isn't wired in), and a future caller that
  /// specifically needs "only create if truly absent, never reactivate" can
  /// check [getTrack] first and branch — cheaper than carrying a second
  /// activation method for a distinction with no current caller.
  ///
  /// Does not touch [CurriculumTrackEntity.paceResetDate] on reactivation
  /// (mirrors `TrackDao.activateTrack`'s reactivation branch, which never
  /// includes `paceResetDate` in its update) — a `SetOptions(merge: true)`
  /// write that never mentions `pace_reset_date` leaves any prior value on
  /// the document untouched.
  Future<CurriculumTrackEntity> activateTrack(CurriculumId curriculumId) async {
    final existing = await getTrack(curriculumId);
    if (existing != null && existing.isActive) return existing;

    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final entity = CurriculumTrackEntity(
      curriculumId: curriculumId,
      state: CurriculumTrackState.active.storageKey,
      stateChangedAt: now,
      activatedAt: now,
      paceResetDate: existing?.paceResetDate,
    );
    await _doc(curriculumId).set(entity.toFirestore(), SetOptions(merge: true));
    return entity;
  }

  /// Retires [curriculumId]'s track (soft-deactivation, reversible via
  /// [activateTrack]). No-op if the track is not currently active (mirrors
  /// `TrackDao.retireTrack`'s own `existing.state == active` guard).
  ///
  /// Absorbs `ActiveCurriculumDao.deactivateByProfile`'s "don't drop this
  /// profile to zero active curricula" guard directly into this method —
  /// see the class doc comment's "Two DAOs collapse into one repository"
  /// section for why. Throws [StateError] if [curriculumId] is this
  /// profile's only active track. `ActiveCurriculumDao`'s own guard threw
  /// `DaoInvariantError(DaoErrorCode.lastActiveCurriculum)` — that stable
  /// error-code type lives in `lib/core/database/` (Drift-adjacent) and is
  /// deliberately NOT imported here; a plain [StateError] carries the same
  /// information without pulling Drift-era code into a Firestore
  /// repository that has no other reason to depend on it. (Mirrors
  /// `ActiveCurriculumDao.archiveByProfile`, which already used a plain
  /// `StateError` for the identical guard rather than the DAO-specific
  /// type.)
  Future<void> retireTrack(CurriculumId curriculumId) async {
    final existing = await getTrack(curriculumId);
    if (existing == null || !existing.isActive) return;

    await _assertNotLastActive();

    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    await _doc(curriculumId).set({
      'state': CurriculumTrackState.retired.storageKey,
      'state_changed_at': FirestoreCodec.encodeDateTime(now),
    }, SetOptions(merge: true));
  }

  /// Archives [curriculumId]'s track — unlike [retireTrack], config data
  /// living in sibling collections (goals/stage_definitions/etc.) was never
  /// touched by the Drift `archiveTrack` either; both `state` values are
  /// "hidden, sibling data untouched", the whole distinction Drift's
  /// `archiveTrack` doc comment draws is against `deleteTrackAndData`,
  /// which has no counterpart on this class at all (see the class doc
  /// comment's "Deletion is NOT this repository's job").
  ///
  /// Unconditional — unlike [retireTrack], there is no "already archived"
  /// or "must currently be active" guard on the state transition itself
  /// (mirrors `TrackDao.archiveTrack`, which has none either). Still runs
  /// the same "don't drop this profile to zero active curricula" guard as
  /// [retireTrack] beforehand (mirrors `ActiveCurriculumDao
  /// .archiveByProfile`) — see [retireTrack]'s doc comment for why that
  /// guard is a plain [StateError] here rather than `DaoInvariantError`.
  Future<void> archiveTrack(CurriculumId curriculumId) async {
    await _assertNotLastActive();

    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    await _doc(curriculumId).set({
      'state': CurriculumTrackState.archived.storageKey,
      'state_changed_at': FirestoreCodec.encodeDateTime(now),
    }, SetOptions(merge: true));
  }

  /// See [retireTrack]/[archiveTrack]'s doc comments.
  Future<void> _assertNotLastActive() async {
    final activeIds = await getActiveCurriculumIds();
    if (activeIds.length <= 1) {
      throw StateError(
        'Cannot deactivate or archive the last active curriculum for this '
        'profile',
      );
    }
  }

  /// Resets the pace baseline for [curriculumId] (Recovery Action). Sets
  /// `paceResetDate` to now. Does not touch completions or chazara data —
  /// mirrors `TrackDao.resetPace`.
  Future<void> resetPace(CurriculumId curriculumId) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    await _doc(curriculumId).set({
      'pace_reset_date': FirestoreCodec.encodeDateTime(now),
    }, SetOptions(merge: true));
  }

  /// Stamps the reorder timestamp for [curriculumId] (Reorder Amnesty).
  /// Sets `last_reorder_at` to now. Mirrors `TrackDao.stampReorderAt`.
  Future<void> stampReorderAt(CurriculumId curriculumId) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    await _doc(curriculumId).set({
      'last_reorder_at': FirestoreCodec.encodeDateTime(now),
    }, SetOptions(merge: true));
  }
}
