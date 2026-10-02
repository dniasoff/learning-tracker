/// Firestore implementation for curriculum tracks —
/// `users/{uid}/learner_profiles/{profileId}/curriculum_tracks/
/// {curriculumId}`, the AD-38 governed entity `mainTrack`.
///
/// Reads are direct; every write is ONE governed action handed to
/// `LearningCommands.applyGovernedChange` through the injected
/// [OwnerGovernedWriter] (Story 1.14, DNI-476): a field-level merge of the
/// changed fields with `last_change_id` and a co-written `change_log`
/// entry. This class never writes or deletes a document itself.
///
/// ## Two Drift DAOs collapse into one repository
///
/// `TrackDao` (lifecycle) and `ActiveCurriculumDao` (a "which curricula are
/// active" wrapper over the same table) map onto the single
/// `curriculum_tracks` doc. [retireTrack] and [archiveTrack] keep
/// `ActiveCurriculumDao`'s "never drop the profile to zero active
/// curricula" guard ([StateError]).
///
/// ## Removal is a tombstone (AD-38 track lifecycle)
///
/// "Remove track" sets `ended_at` on this doc through
/// `LearningCommands.removeTrack` (one action that also tombstones the
/// curriculum's live sub-tracks); "Re-add" clears it. While a track has
/// `ended_at`, every read here treats it as absent, and the engine reads
/// the curriculum's other governed docs as ended (`LearnerStateEngine`).
/// Learning events and the points ledger are never touched. Client
/// `delete` is denied by the rules.
///
/// ## Retired fields
///
/// `updated_at` / `synced_at` are retired from governed docs, and so are
/// `pace_reset_date` (Reset pace is retired, prd-deviations #14) and
/// `last_reorder_at` (the AD-35 amnesty instant is the latest
/// `mainTrackOrder` / `mainTrackProgram` change-log entry): none is
/// written. The legacy lifecycle stamps `state_changed_at` and
/// `activated_at` the decoder requires are still written.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_intents.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

/// Firestore-backed curriculum-track repository (see the library doc
/// comment).
class FirestoreCurriculumTrackRepository {
  FirestoreCurriculumTrackRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    OwnerGovernedWriter? writer,
    AppLogger? logger,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _writer = writer,
       _logger = logger ?? AppLogger.instance,
       _clock = clock ?? DateTimeFactory.nowUtc;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final OwnerGovernedWriter? _writer;
  final AppLogger _logger;
  final DateTime Function() _clock;

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

  /// Whether a track doc is removed (`ended_at` set, AD-38).
  static bool _isEnded(Map<String, dynamic> data) =>
      data[GovernedKeys.endedAt] != null;

  CurriculumTrackEntity? _decode(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null || _isEnded(data)) return null;
    return curriculumTrackFromFirestore(data);
  }

  /// Returns the track for [curriculumId], or `null` if it has never been
  /// activated or was removed (`ended_at`, see the library doc comment).
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

  /// Resolves once the server has settled [curriculumId]'s track doc — the
  /// first snapshot with no pending local writes that is not from the
  /// cache: true when the server holds it live (present, no `ended_at`),
  /// false when it is absent or ended (e.g. a queued write the server
  /// refused was rolled back) or the listener fails. Waits while offline.
  Future<bool> whenServerLive(CurriculumId curriculumId) async {
    try {
      await for (final snapshot in _doc(
        curriculumId,
      ).snapshots(includeMetadataChanges: true)) {
        final meta = snapshot.metadata;
        if (meta.hasPendingWrites || meta.isFromCache) continue;
        final data = snapshot.data();
        return data != null && !_isEnded(data);
      }
    } on Object catch (error, stackTrace) {
      _logger.warning(
        event: 'firestore_curriculum_track_confirm_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      );
    }
    return false;
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
      if (_isEnded(doc.data())) continue;
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

  /// A live track doc decoded, or null for a removed one.
  static CurriculumTrackEntity? _decodeLive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => _isEnded(doc.data()) ? null : curriculumTrackFromFirestore(doc.data());

  /// Every track for this profile (any state). Unfiltered — no `where()`/
  /// `orderBy()`, so no composite index needed.
  Future<List<CurriculumTrackEntity>> getAllTracks() async {
    final snapshot = await _tracks.get();
    return _decodeAll(snapshot.docs);
  }

  /// Live updates for every track for this profile (`resilientQueryStream`
  /// — one bad document is skipped, not the whole list).
  Stream<List<CurriculumTrackEntity>> watchAllTracks() {
    return resilientQueryStream<CurriculumTrackEntity?>(
      openStream: () => _tracks.snapshots(),
      decode: _decodeLive,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_curriculum_tracks_watch_error',
        exception: error,
        stackTrace: stackTrace,
      ),
    ).map((tracks) => tracks.whereType<CurriculumTrackEntity>().toList());
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
    return resilientQueryStream<CurriculumTrackEntity?>(
      openStream: () => _activeQuery.snapshots(),
      decode: _decodeLive,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_curriculum_tracks_active_watch_error',
        exception: error,
        stackTrace: stackTrace,
      ),
    ).map(
      (tracks) =>
          tracks.whereType<CurriculumTrackEntity>().toList()
            ..sort(_byCurriculumId),
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

  /// Activates [curriculumId]'s track: creates it, reactivates it from a
  /// retired or archived state, or re-adds a removed one (see
  /// [planActivateTrack]) — one logged `mainTrack` change. Idempotent: a
  /// live active track is returned unchanged with nothing written.
  Future<CurriculumTrackEntity> activateTrack(CurriculumId curriculumId) async {
    final existing = await getTrack(curriculumId);
    if (existing != null && existing.isActive) return existing;
    final activation = await planActivateTrack(curriculumId);
    await _apply([activation.change]);
    return activation.entity;
  }

  /// The `mainTrack` change [activateTrack] writes, the entity it yields,
  /// and whether it re-adds a removed track. Used by the one-action Add
  /// track flow (DNI-476 T5).
  ///
  /// * No doc, or a live one: `state = active` with fresh
  ///   `state_changed_at` / `activated_at` stamps.
  /// * A removed doc (`ended_at` set) is a **re-add** (AD-38, ruling B13):
  ///   the change only clears `ended_at` ([OwnerGovernedIntents.reAddTrack])
  ///   so the prior config and lifecycle stamps are kept. Only when the
  ///   track was removed from a retired or archived state does it also
  ///   set `state = active` (stamping `state_changed_at`); `activated_at`
  ///   is never rewritten on a re-add.
  Future<
    ({GovernedEntityChange change, CurriculumTrackEntity entity, bool reAdded})
  >
  planActivateTrack(CurriculumId curriculumId) async {
    final snapshot = await _doc(curriculumId).get();
    final data = snapshot.data();
    final now = _clock();
    if (data != null && _isEnded(data)) {
      final prior = curriculumTrackFromFirestore(data);
      if (prior.isActive) {
        return (
          change: OwnerGovernedIntents.reAddTrack(curriculumId.storageKey),
          entity: prior,
          reAdded: true,
        );
      }
      return (
        change: _change(curriculumId, {
          'state': CurriculumTrackState.active.storageKey,
          'state_changed_at': FirestoreCodec.encodeDateTime(now),
          GovernedKeys.endedAt: null,
        }),
        entity: CurriculumTrackEntity(
          curriculumId: curriculumId,
          state: CurriculumTrackState.active.storageKey,
          stateChangedAt: now,
          activatedAt: prior.activatedAt,
          paceResetDate: prior.paceResetDate,
          lastReorderAt: prior.lastReorderAt,
          progressSchemaVersion: prior.progressSchemaVersion,
          progressComputedAt: prior.progressComputedAt,
          progressModel: prior.progressModel,
          programProgress: prior.programProgress,
          selfPacedProgress: prior.selfPacedProgress,
        ),
        reAdded: true,
      );
    }
    final entity = CurriculumTrackEntity(
      curriculumId: curriculumId,
      state: CurriculumTrackState.active.storageKey,
      stateChangedAt: now,
      activatedAt: now,
      paceResetDate: data == null
          ? null
          : FirestoreCodec.parseDateTime(data['pace_reset_date']),
    );
    final change = _change(curriculumId, {
      'state': CurriculumTrackState.active.storageKey,
      'state_changed_at': FirestoreCodec.encodeDateTime(now),
      'activated_at': FirestoreCodec.encodeDateTime(now),
      GovernedKeys.endedAt: null,
    });
    return (change: change, entity: entity, reAdded: false);
  }

  /// Retires [curriculumId]'s track (soft-deactivation, reversible via
  /// [activateTrack]). No-op if the track is not currently active. Throws
  /// [StateError] if [curriculumId] is this profile's only active track.
  Future<void> retireTrack(CurriculumId curriculumId) async {
    final existing = await getTrack(curriculumId);
    if (existing == null || !existing.isActive) return;

    await _assertNotLastActive();
    await _setState(curriculumId, CurriculumTrackState.retired);
  }

  /// Archives [curriculumId]'s track — hidden, its sibling config kept.
  /// Unconditional on the current state; throws [StateError] if
  /// [curriculumId] is this profile's only active track.
  Future<void> archiveTrack(CurriculumId curriculumId) async {
    await _assertNotLastActive();
    await _setState(curriculumId, CurriculumTrackState.archived);
  }

  Future<void> _setState(
    CurriculumId curriculumId,
    CurriculumTrackState state,
  ) => _apply([
    _change(curriculumId, {
      'state': state.storageKey,
      'state_changed_at': FirestoreCodec.encodeDateTime(_clock()),
    }),
  ]);

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

  /// AD-38 "Remove track": `LearningCommands.removeTrack` — ONE action
  /// setting `ended_at` on this doc plus one `subTrack` tombstone per
  /// non-ended sub-track of the curriculum (shared `action_id`). Learning
  /// events and the points ledger are never touched. Throws [StateError]
  /// when [curriculumId] is this profile's only active track, and
  /// [GovernedWriteRejectedException] when the commands refuse the write.
  Future<void> removeTrack(CurriculumId curriculumId) async {
    final existing = await getTrack(curriculumId);
    if (existing != null && existing.isActive) await _assertNotLastActive();
    requireOwnerSuccess(
      await _requireWriter().removeTrack(curriculumId.storageKey),
    );
  }

  /// AD-38 "Re-add": `LearningCommands.reAddTrack` — clears `ended_at`
  /// through a logged change, so the track returns with its prior config,
  /// progress and history.
  Future<void> reAddTrack(CurriculumId curriculumId) async {
    requireOwnerSuccess(
      await _requireWriter().reAddTrack(curriculumId.storageKey),
    );
  }

  OwnerGovernedWriter _requireWriter() {
    final writer = _writer;
    if (writer == null) throw const GovernedWriterNotReadyException();
    return writer;
  }

  GovernedEntityChange _change(
    CurriculumId curriculumId,
    Map<String, Object?> fields,
  ) => OwnerGovernedIntents.mainTrackDocs(
    entity: GovernedEntity.mainTrack,
    curriculumId: curriculumId.storageKey,
    docs: {
      DocIds.curriculumTrackDocId({'curriculum_id': curriculumId.storageKey}):
          fields,
    },
  );

  Future<void> _apply(List<GovernedEntityChange> changes) =>
      applyOwnerAction(_requireWriter(), GovernedAction(changes));
}
