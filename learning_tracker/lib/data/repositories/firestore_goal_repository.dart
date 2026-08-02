/// Firestore implementation for goals — Epic B (`docs/
/// firestore-rewrite-map.md`), built to the shape
/// `lib/data/repositories/firestore_stage_definition_repository.dart`
/// establishes as the reference. See that file's class doc comment for the
/// pattern this copies (resolved-handle constructor, `DocIds`-only doc-ids,
/// entity-owned codec, merge writes, one-shot-read decode leniency). This
/// doc comment only calls out what is DIFFERENT for `goals`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

/// Firestore-backed goal repository: `users/{uid}/learner_profiles/
/// {profileId}/goals/{goalId}` (`docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /goals/{goalId}`). Multiple goals per
/// curriculum are allowed (e.g. "finish Seder Zeraim by Pesach, all
/// Mishnayos by bar mitzvah") — `goals` is deliberately NOT unique per
/// curriculum, unlike `bookmarks`/`stage_definitions`.
///
/// **Not wired into the app yet** — same status as the reference
/// repositories; the existing Drift-backed `GoalRepositoryImpl`
/// (`lib/features/scheduler/data/repositories/`) is untouched and keeps
/// serving the app until the rewiring stage.
///
/// **No interface** — same reasoning as the reference repositories: the
/// Drift implementation is being deleted outright, not kept alongside this
/// one.
///
/// ## Doc-id: reuses `GoalEntity.firestoreId`, routed through `DocIds`
///
/// [GoalEntity] already carries its own stable doc-id formula —
/// [GoalEntity.firestoreId] — built from `curriculumId` + `createdAt` only,
/// deliberately excluding `targetPercent`/`trackId`/`id` so an ordinary
/// edit never computes a different id (see that getter's doc comment,
/// AUD-scheduler-16). `DocIds.goalDocId` independently mirrors the live
/// gateway's `pushGoal` byte-for-byte: prefer `data['id']`, then
/// `data['goal_id']`, else fall back to `DocIds.fallbackGoalDocId`
/// (`curriculum_targetPercent_createdAt` — NOTE this fallback embeds
/// `targetPercent`, unlike [GoalEntity.firestoreId]). `pushGoal`'s own doc
/// comment confirms the fallback is a defensive backstop for an
/// (unreachable in practice) caller that omits `id`/`goal_id` entirely —
/// "every real producer already injects data['id']". This repository is
/// that producer: [_doc] always supplies `'id': goal.firestoreId`, so
/// `DocIds.goalDocId` always resolves to [GoalEntity.firestoreId] directly
/// and [DocIds.fallbackGoalDocId]'s `targetPercent`-embedding path is never
/// actually exercised — which matters, because if it WERE exercised on
/// every write, editing a goal's `targetPercent` (a routine, expected edit)
/// would silently orphan the old Firestore document and create a new one
/// instead of updating it. Doc-ids still route through `DocIds` per the
/// "never hand-rolled" rule; they just resolve to the entity's own stable
/// id rather than reaching the fallback formula.
///
/// ## No Firestore `orderBy` for [getGoals]/[watchGoals] — sorted client-side
///
/// The Drift DAO orders `getGoalsByCurriculumAndProfile` by `target_date`
/// ASC (SQLite places `NULL` first). `target_date` is **nullable** — it is
/// only set for `goalType == 'deadline'` goals; `'pace'`/`'none'` goals
/// never carry one. A Firestore `.orderBy('target_date')` on a field some
/// documents entirely lack would silently EXCLUDE every pace/none goal
/// from the query result (Firestore drops documents missing the ordered
/// field, it does not sort them to an end) — a landmine that would blank
/// half of a curriculum's goal list with no error. This repository instead
/// only equality-filters on `curriculum_id` (a single-field filter needs no
/// composite index) and sorts the decoded list client-side —
/// `_byTargetDate`, mirroring SQLite's null-first ASC ordering exactly.
///
/// ## Trimmed from the Drift-era `GoalRepository` interface — not reimplemented
///
/// - **`createGoal`'s `profileId`/`trackId` parameters do not exist on this
///   class.** `profileId` is redundant with the constructor-level
///   [profileId] (path-scoped, same as every other Firestore repository
///   here). `trackId` is the Drift-era per-device `int` AD-25 retired for
///   this migration; `GoalEntity.toFirestore()` already only writes
///   `track_id` when the entity's own `trackId` field is non-null, and this
///   repository never sets that field on any entity it constructs — so no
///   `track_id` is ever written, keeping the MCF-11
///   autoincrement-id-in-payload ratchet unmoved.
/// - **`deleteGoal` does not exist on this class.** `firestore.rules`
///   denies `delete` on `goals` outright (`allow delete: if false` —
///   same as `stage_definitions`), so there is no rules-legal way for an
///   owner to remove a goal document from a client at all. Mirrors
///   `FirestoreStageDefinitionRepository` dropping `deleteStagesForTrack`
///   for the identical reason. (The Drift-era sync engine's own
///   `FirestoreGatewayImpl.deleteGoal`/`SyncWriteFacade.deleteGoal` path is
///   therefore already dead against real rules enforcement today — not
///   something this rewrite introduces.)
/// - **`GoalProfileMismatchException` is never thrown here.** It existed
///   because the Drift DAO's `getGoalById`/`updateGoal`/`deleteGoal` are
///   NOT scoped by profile — any caller with a raw `goalId` int could
///   address any profile's row, so `GoalRepositoryImpl` added a
///   repository-layer guard as the last line of defense
///   (AUD-scheduler-03). That addressing surface does not exist here: this
///   repository's [_goals] collection reference is *itself* rooted at
///   `users/{uid}/learner_profiles/{profileId}/goals`, so there is no way
///   to construct a request that reaches another profile's goal through
///   this class in the first place — the invariant is now structural, not
///   a runtime check.
/// - **`updateGoal` takes the current [GoalEntity], not an `int goalId`.**
///   There is no local autoincrement id to look up by; callers already
///   hold the entity (from [getGoals]/[watchGoals]) they are editing. The
///   returned/written entity keeps the original `curriculumId`/`createdAt`
///   pair, so [GoalEntity.firestoreId] — and therefore the target document
///   — is unchanged by the update, exactly like the Drift path's
///   `id`-keyed update.
class FirestoreGoalRepository {
  FirestoreGoalRepository({
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

  CollectionReference<Map<String, dynamic>> get _goals => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('goals');

  /// See the class doc comment ("Doc-id") for why this always resolves to
  /// [GoalEntity.firestoreId] rather than [DocIds.fallbackGoalDocId].
  DocumentReference<Map<String, dynamic>> _doc(GoalEntity goal) =>
      _goals.doc(DocIds.goalDocId({'id': goal.firestoreId}));

  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _goals.where('curriculum_id', isEqualTo: curriculumId.storageKey);

  /// Null-first ascending comparator, mirroring SQLite's
  /// `ORDER BY target_date ASC` (NULLs sort first) — see the class doc
  /// comment for why this is done client-side rather than via a Firestore
  /// `orderBy`.
  static int _byTargetDate(GoalEntity a, GoalEntity b) {
    final aDate = a.targetDate;
    final bDate = b.targetDate;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return -1;
    if (bDate == null) return 1;
    return aDate.compareTo(bDate);
  }

  /// Returns all goals for [curriculumId], sorted by `targetDate`
  /// (null-first, ascending) — see the class doc comment.
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row
  /// fail the whole read — same "one bad document should not blank the
  /// list" treatment `FirestoreStageDefinitionRepository._decodeAll`
  /// applies.
  List<GoalEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <GoalEntity>[];
    for (final doc in docs) {
      try {
        results.add(GoalEntity.fromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_goals_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    results.sort(_byTargetDate);
    return results;
  }

  /// Live updates for [curriculumId]'s goal list, sorted the same way as
  /// [getGoals]. Resubscribes with bounded exponential backoff if the
  /// underlying listener errors (`resilientQueryStream`).
  Stream<List<GoalEntity>> watchGoals(CurriculumId curriculumId) {
    return resilientQueryStream<GoalEntity>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => GoalEntity.fromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_goals_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    ).map((goals) => List<GoalEntity>.of(goals)..sort(_byTargetDate));
  }

  /// Decomposes a [PaceTarget] into the four raw fields
  /// (goalType, targetDate, paceValue, pacePeriod) — mirrors
  /// `GoalRepositoryImpl._decomposePaceTarget` exactly.
  static (String, DateTime?, int?, String?) _decomposePaceTarget(
    PaceTarget? paceTarget,
  ) {
    switch (paceTarget) {
      case DeadlineTarget(:final dueDate):
        return ('deadline', dueDate.toUtc(), null, null);
      case PacePeriodTarget(:final rate, :final period):
        return ('pace', null, rate, period);
      case null:
        return ('none', null, null, null);
    }
  }

  /// Creates a new goal for [curriculumId]. [paceTarget] is the sealed
  /// discriminant carrying deadline- or pace-mode data (`null` for
  /// `goalType == 'none'`) — see [PaceTarget]'s subtypes.
  Future<GoalEntity> createGoal({
    required CurriculumId curriculumId,
    required double targetPercent,
    PaceTarget? paceTarget,
    String description = '',
    String dateType = 'gregorian',
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final (goalType, targetDate, paceValue, pacePeriod) = _decomposePaceTarget(
      paceTarget,
    );
    final entity = GoalEntity(
      curriculumId: curriculumId,
      targetPercent: targetPercent,
      targetDate: targetDate,
      description: description,
      dateType: dateType,
      goalType: goalType,
      paceValue: paceValue,
      pacePeriod: pacePeriod,
      paceGranularity: paceGranularity,
      rawLearningUnit: paceGranularity == null ? rawLearningUnit : null,
      createdAt: now,
      updatedAt: now,
    );
    await _doc(entity).set(entity.toFirestore(), SetOptions(merge: true));
    return entity;
  }

  /// Updates [goal] and writes the result back to the SAME document (its
  /// `curriculumId`/`createdAt` — and therefore
  /// [GoalEntity.firestoreId] — are unchanged by an update; see the class
  /// doc comment). Pass [paceTarget] to change the goal's deadline/pace
  /// mode, or [clearPaceTarget] == `true` to remove it entirely
  /// (`goalType` becomes `'none'`). Omitting both leaves the existing
  /// mode untouched. [clearLearningUnit] == `true` removes the learning
  /// unit entirely; omitting [paceGranularity]/[rawLearningUnit] leaves the
  /// existing unit untouched.
  Future<GoalEntity> updateGoal({
    required GoalEntity goal,
    double? targetPercent,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? description,
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
    bool clearLearningUnit = false,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps

    final String resolvedGoalType;
    final DateTime? resolvedTargetDate;
    final int? resolvedPaceValue;
    final String? resolvedPacePeriod;
    if (clearPaceTarget) {
      resolvedGoalType = 'none';
      resolvedTargetDate = null;
      resolvedPaceValue = null;
      resolvedPacePeriod = null;
    } else if (paceTarget != null) {
      final decomposed = _decomposePaceTarget(paceTarget);
      resolvedGoalType = decomposed.$1;
      resolvedTargetDate = decomposed.$2;
      resolvedPaceValue = decomposed.$3;
      resolvedPacePeriod = decomposed.$4;
    } else {
      resolvedGoalType = goal.goalType;
      resolvedTargetDate = goal.targetDate;
      resolvedPaceValue = goal.paceValue;
      resolvedPacePeriod = goal.pacePeriod;
    }

    final PaceGranularity? resolvedGranularity;
    final String? resolvedRawUnit;
    if (clearLearningUnit) {
      resolvedGranularity = null;
      resolvedRawUnit = null;
    } else if (paceGranularity != null) {
      resolvedGranularity = paceGranularity;
      resolvedRawUnit = null;
    } else if (rawLearningUnit != null) {
      resolvedGranularity = PaceGranularity.fromStorageKey(rawLearningUnit);
      resolvedRawUnit = resolvedGranularity == null ? rawLearningUnit : null;
    } else {
      resolvedGranularity = goal.paceGranularity;
      resolvedRawUnit = goal.rawLearningUnit;
    }

    final updated = goal.copyWith(
      targetPercent: targetPercent ?? goal.targetPercent,
      targetDate: resolvedTargetDate,
      description: description ?? goal.description,
      goalType: resolvedGoalType,
      paceValue: resolvedPaceValue,
      pacePeriod: resolvedPacePeriod,
      paceGranularity: resolvedGranularity,
      rawLearningUnit: resolvedRawUnit,
      updatedAt: now,
    );

    await _doc(updated).set(updated.toFirestore(), SetOptions(merge: true));
    return updated;
  }
}
