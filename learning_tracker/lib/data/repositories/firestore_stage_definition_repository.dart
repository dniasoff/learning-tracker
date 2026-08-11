/// Firestore implementation for stage definitions — the SECOND reference
/// repository for the Firestore rewrite (`docs/firestore-rewrite-map.md`),
/// chosen specifically because it needs
/// `where('curriculum_id', isEqualTo: …).orderBy('stage_order')` — a genuine
/// composite index, and a decode path across MULTIPLE documents per query
/// (unlike `FirestoreBookmarkRepository`, which only ever reads one
/// document at a time). See the class doc comment for what to copy.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

/// Default stage definitions (לימוד, חזרה א׳, חזרה ב׳) — same three stages
/// `StageDefinitionRepositoryImpl` (Drift) seeds, so a curriculum newly
/// activated against this repository looks identical to one activated
/// against the Drift path.
const _defaultStages = [
  (stageOrder: 1, stageName: kLimudStageName, delayDays: 0),
  (stageOrder: 2, stageName: 'חזרה א׳', delayDays: 1),
  (stageOrder: 3, stageName: 'חזרה ב׳', delayDays: 7),
];

/// Firestore-backed stage-definitions repository: `users/{uid}/
/// learner_profiles/{profileId}/stage_definitions/{curriculumId}_
/// {stageOrder}` (`docs/firestore-rewrite-map.md`, `firestore.rules`
/// `match /stage_definitions/{stageId}`).
///
/// **Not wired into the app's production provider yet** — unlike
/// `FirestoreBookmarkRepository`, which IS wired via
/// `FirestoreBookmarkRepositoryAdapter`/`bookmarkRepositoryProvider` (see
/// that class's own doc comment). A `FirestoreStageDefinitionRepositoryAdapter`
/// (`lib/features/tracks/stages/data/repositories/
/// stage_definition_repository_impl.dart`) exists and does construct this
/// class, but `stageDefinitionRepositoryProvider`
/// (`lib/features/tracks/stages/presentation/providers/stage_providers.dart`)
/// still returns the Drift-backed `StageDefinitionRepositoryImpl` from that
/// same file — no screen reaches this class today.
///
/// **No interface** — same reasoning as `FirestoreBookmarkRepository`'s doc
/// comment: the Drift implementation is being deleted outright, not kept
/// alongside this one, so there is no second implementation to be
/// substitutable with, and `implements` would only get in the way of the
/// streaming methods that are the actual point of this rewrite.
///
/// ## What this adds to the Bookmarks pattern
///
/// `FirestoreBookmarkRepository` established: resolved-handle constructor,
/// `DocIds`-only doc-ids, entity-owned codec, merge writes, streams as
/// ordinary methods, `resilientDocStream` for a single document. This
/// repository keeps all of that and adds the QUERY side:
///
/// 1. **Composite index required.** [getStagesForCurriculum] /
///    [watchStagesForCurriculum] filter on `curriculum_id` (equality) and
///    order by `stage_order` (a different field) — Firestore requires a
///    composite index for that combination; single-field auto-indexes do
///    not cover it. Added to `firestore.indexes.json`
///    (`collectionGroup: "stage_definitions"`, fields
///    `curriculum_id` ASC + `stage_order` ASC). Get this wrong and it only
///    fails at **runtime in production** — `dart analyze`/tests cannot
///    catch a missing index, `fake_cloud_firestore` does not enforce
///    indexes at all.
/// 2. **[resilientQueryStream], not [resilientDocStream].** A query can
///    return many documents; [resilientQueryStream] decodes each
///    independently so ONE malformed row is skipped (and surfaced via
///    `addError`) rather than blanking the entire list — see that
///    function's doc comment for the full reasoning.
/// 3. **The one-shot `Future` reads get the same per-document leniency as
///    the stream.** [_decodeAll] applies the identical "skip a malformed
///    document, do not fail the whole read" treatment to
///    [getStagesForCurriculum] and [getAllStageDefinitions] — a one-shot
///    read should not be LESS resilient than the streaming one just because
///    [resilientQueryStream] only wraps stream-shaped reads.
///
/// ## Trimmed from the Drift-era interface — not reimplemented
///
/// `StageDefinitionRepository` (the abstract class
/// `StageDefinitionRepositoryImpl` implements) carried several members with
/// no honest Firestore mapping. Rather than force this class to redeclare
/// all of them (the exact `implements`-shaped busywork dropping the
/// interface avoids), the ones with no real meaning here are simply absent:
///
/// - **`getStagesByTrack(int trackId)` and `deleteStagesForTrack(int
///   trackId)` do not exist on this class.** Both took ONLY a Drift-local
///   `int trackId` — no `curriculumId` — and AD-25 retired the per-device
///   track id for this collection entirely (`curriculum_id` is the sole
///   canonical stable track key; see `docs/firestore-rewrite-map.md`).
///   There is no way to resolve which curriculum a bare `trackId` int
///   refers to without reaching into Drift, which this repository
///   deliberately does not do. `deleteStagesForTrack` had a second,
///   independent reason it could never work even with a `curriculumId`:
///   `firestore.rules` denies `delete` on this collection outright (`allow
///   delete: if false`). A caller that needs a curriculum's stages should
///   call [getStagesForCurriculum] directly.
/// - **`pushStagesForTrack` does not exist on this class.** It was a
///   push-pipeline-era "flush the local write to Firestore" step;
///   [initializeDefaults]/[resetToDefaults] already write straight to
///   Firestore, so there is no separate push step left to perform.
/// - **[initializeDefaults]/[resetToDefaults] take only a [CurriculumId]**
///   — the Drift interface's `profileId`/`trackId` parameters are gone
///   rather than kept-but-ignored: this repository is already profile-scoped
///   (constructor-level [profileId]), and "one track per curriculum per
///   profile" is an invariant the Drift implementation itself states twice
///   (`stage_definition_repository_impl.dart`), so `curriculum_id` alone was
///   always the real key.
///
/// ## Kept, still flagged — NOT silently guessed at
///
/// - **[hasCompletionsForStage] throws [UnimplementedError].**
///   `FirestoreCompletionRepository` (`firestore_completion_repository.dart`)
///   now exists and has exactly the query this needs — its own
///   `hasCompletionsForStage({curriculumId, stageOrder})`, built for this
///   purpose. This method still can't delegate to it: `stageId` here is an
///   `int`, a Drift-only concept — a real Firestore stage has no integer
///   row id (see [kFirestoreUnmappedStageId]'s doc comment) — and this
///   repository has no way to translate that `int` into the
///   `(curriculumId, stageOrder)` pair the completions repository needs.
///   Bridging the two requires changing this method's own signature (the
///   `StageDefinitionRepository` interface), which has not happened yet.
/// - **[resetToDefaults] does not actually "remove all" stages.** Its
///   Drift-era doc comment said "Removes all stages and restores the 3
///   defaults", but `firestore.rules` denies `delete` on
///   `stage_definitions` unconditionally — there is no rules-legal way to
///   remove a document from this collection from a client at all. This
///   implementation overwrites the 3 default doc-ids (`stage_order` 1/2/3)
///   with default content instead. In the overwhelmingly common case
///   (exactly 3 stages per curriculum, matching every comment in the Drift
///   implementation) this is observably identical to "remove all, restore
///   3" — but if a caller had ever added a 4th+ custom stage at a higher
///   `stage_order`, that extra document survives, un-deleted. Flagged, not
///   silently diverged from.
class FirestoreStageDefinitionRepository {
  FirestoreStageDefinitionRepository({
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

  CollectionReference<Map<String, dynamic>> get _stages => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('stage_definitions');

  DocumentReference<Map<String, dynamic>> _doc({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) => _stages.doc(
    DocIds.stageDefinitionDocId({
      'curriculum_id': curriculumId.storageKey,
      'stage_order': stageOrder,
    }),
  );

  /// The composite-index-requiring query behind [getStagesForCurriculum]
  /// and [watchStagesForCurriculum] — see the class doc comment (point 1).
  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _stages
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy('stage_order');

  /// Returns all stages for [curriculumId], ordered by `stageOrder`.
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row
  /// fail the WHOLE read — the same "one bad document should not blank the
  /// list" reasoning as [resilientQueryStream] (class doc comment, point
  /// 2), applied here to the one-shot `Future`-returning reads too so they
  /// are not LESS resilient than the streaming method.
  List<StageDefinition> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <StageDefinition>[];
    for (final doc in docs) {
      try {
        results.add(stageDefinitionFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_stage_definitions_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Live updates for [curriculumId]'s ordered stage list. Resubscribes
  /// with bounded exponential backoff if the underlying listener errors
  /// (`resilientQueryStream`) — see the class doc comment (point 2) for how
  /// a per-document decode failure is handled differently from
  /// `FirestoreBookmarkRepository.watchBookmark`.
  Stream<List<StageDefinition>> watchStagesForCurriculum(
    CurriculumId curriculumId,
  ) {
    return resilientQueryStream<StageDefinition>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => stageDefinitionFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_stage_definitions_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    );
  }

  /// Seeds default stages (Learn, Chazara 1, Chazara 2) if none exist for
  /// [curriculumId] yet. Idempotent — no-op if stages already exist.
  Future<void> initializeDefaults(CurriculumId curriculumId) async {
    final existing = await getStagesForCurriculum(curriculumId);
    if (existing.isNotEmpty) return;
    await _writeDefaults(curriculumId);
  }

  /// Restores the 3 default stages for [curriculumId]. See the class doc
  /// comment's "Kept, still flagged" section for exactly what this does and
  /// does not achieve — it cannot delete a 4th+ custom stage.
  Future<void> resetToDefaults(CurriculumId curriculumId) async {
    await _writeDefaults(curriculumId);
  }

  Future<void> _writeDefaults(CurriculumId curriculumId) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final batch = _firestore.batch();
    for (final d in _defaultStages) {
      final stage = StageDefinition(
        id: kFirestoreUnmappedStageId,
        curriculumId: curriculumId,
        stageOrder: d.stageOrder,
        stageName: d.stageName,
        delayDays: d.delayDays,
        isDefault: true,
      );
      batch.set(
        _doc(curriculumId: curriculumId, stageOrder: d.stageOrder),
        stage.toFirestore(updatedAt: now),
      );
    }
    await batch.commit().orQueuedOffline;
  }

  /// Returns true if any completions reference [stageId].
  ///
  /// See the class doc comment's "Kept, still flagged" section.
  Future<bool> hasCompletionsForStage(int stageId) {
    throw UnimplementedError(
      'hasCompletionsForStage: no Firestore completions repository exists '
      'yet — building one is out of this repository\'s scope. stageId is '
      'also a Drift-only concept: a real Firestore stage has no integer '
      'row id (see kFirestoreUnmappedStageId). Whoever builds the '
      'Firestore completions repository should own this method, keyed by '
      '(curriculumId, stageOrder) or the stage doc-id string, not an int.',
    );
  }

  /// Returns every stage definition in this profile's whole
  /// `stage_definitions` subcollection (cross-curriculum). Unfiltered — no
  /// `where()`/`orderBy()`, so no composite index needed.
  Future<List<StageDefinition>> getAllStageDefinitions() async {
    final snapshot = await _stages.get();
    return _decodeAll(snapshot.docs);
  }
}
