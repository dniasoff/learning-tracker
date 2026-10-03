/// Firestore implementation for goals — `users/{uid}/learner_profiles/
/// {profileId}/goals/{goalId}`, the AD-38 governed entity `goal`.
///
/// Reads are direct queries; every write is ONE governed action handed to
/// `LearningCommands.applyGovernedChange` through the injected
/// [OwnerGovernedWriter] (Story 1.14, DNI-476). This class never writes or
/// deletes a document itself.
///
/// ## AD-43 fixed ids, not one doc per created goal
///
/// A curriculum has at most one deadline goal, `goals/{curriculumId}_deadline`
/// (`target_date`, a `YYYY-MM-DD` civil date) and one pace goal,
/// `goals/{curriculumId}_pace` (`pace_value`, `pace_unit`,
/// `pace_granularity`). A second create is structurally an update of the
/// same doc: logged, and last-write-wins per field by server commit order
/// (AD-38), so two devices creating the same goal offline converge on one
/// doc. [GoalEntity.firestoreId] is no longer the doc id.
///
/// The app's single "current goal" per curriculum maps onto that pair:
/// setting a goal of one kind upserts that kind's doc and, in the SAME
/// action, ends the other kind's live doc; a `'none'` goal ends both. The
/// two goal entities then share one `action_id`.
///
/// ## Removal is a tombstone
///
/// [deleteGoal] sets `ended_at` through a logged change; client `delete` is
/// denied by the rules (AD-38). Reads skip ended docs.
///
/// ## Fields
///
/// Only the changed fields are written (field-level `set(merge: true)`):
/// the AD-52 keys plus the legacy display keys the rules and the
/// `ownerOversizedGovernedWrite` callable's field specs still accept
/// (`description`, `date_type`, and `created_at` when a goal doc is created
/// or revived), so a goal in an oversized (online-only) action is accepted
/// exactly as one under the budget. R16 (DNI-484): `updated_at` /
/// `synced_at` are retired from governed docs and `target_percent` is
/// retired by AD-43 (a deadline always covers the whole corpus); none is
/// part of the API, the entity or the write.
///
/// ## Calendar programs
///
/// A goal on a calendar-program curriculum is rejected by
/// `applyGovernedChange` before anything is written (AD-43 / AD-45); the
/// write then throws [GovernedWriteRejectedException].
///
/// ## No Firestore `orderBy` — sorted client-side
///
/// `target_date` is absent on pace goals, and a Firestore `orderBy` on a
/// field some documents lack silently excludes them. The query only
/// equality-filters on `curriculum_id` and sorts client-side
/// ([_byTargetDate], null first, then ascending).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_intents.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

/// Firestore-backed goal repository (see the library doc comment).
class FirestoreGoalRepository {
  FirestoreGoalRepository({
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

  CollectionReference<Map<String, dynamic>> get _goals => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('goals');

  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _goals.where('curriculum_id', isEqualTo: curriculumId.storageKey);

  /// Null-first ascending comparator on `targetDate` (see the library doc
  /// comment for why this is done client-side).
  static int _byTargetDate(GoalEntity a, GoalEntity b) {
    final aDate = a.targetDate;
    final bDate = b.targetDate;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return -1;
    if (bDate == null) return 1;
    return aDate.compareTo(bDate);
  }

  static bool _isLive(Map<String, dynamic> data) =>
      data[GovernedKeys.endedAt] == null;

  /// The live goals of [curriculumId], sorted by `targetDate` (null first,
  /// then ascending). Ended goals are skipped.
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every live document in [docs], skipping (and logging) any
  /// single document whose decode fails so one bad document never blanks
  /// the list.
  List<GoalEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <GoalEntity>[];
    for (final doc in docs) {
      final data = doc.data();
      if (!_isLive(data)) continue;
      try {
        results.add(GoalEntity.fromFirestore(data));
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

  /// Live updates of [getGoals]. Resubscribes with bounded exponential
  /// backoff if the underlying listener errors (`resilientQueryStream`).
  Stream<List<GoalEntity>> watchGoals(CurriculumId curriculumId) {
    return resilientQueryStream<GoalEntity?>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) {
        final data = doc.data();
        return _isLive(data) ? GoalEntity.fromFirestore(data) : null;
      },
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_goals_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    ).map(
      (goals) => goals.whereType<GoalEntity>().toList()..sort(_byTargetDate),
    );
  }

  /// Decomposes a [PaceTarget] into (goalType, targetDate, paceValue,
  /// pacePeriod).
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

  /// Sets [curriculumId]'s goal: one governed action (see the library doc
  /// comment). [paceTarget] is the deadline or pace mode, `null` for a
  /// `'none'` goal (which only ends the live goals). Returns the entity as
  /// the app models it.
  Future<GoalEntity> createGoal({
    required CurriculumId curriculumId,
    PaceTarget? paceTarget,
    String description = '',
    String dateType = 'gregorian',
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
  }) async {
    final entity = buildNewGoal(
      curriculumId: curriculumId,
      now: _clock(),
      paceTarget: paceTarget,
      description: description,
      dateType: dateType,
      paceGranularity: paceGranularity,
      rawLearningUnit: rawLearningUnit,
    );
    await _apply(await planSetGoal(entity));
    return entity;
  }

  /// The goal [createGoal] sets, computed without writing: the single
  /// creation rule the owner path and the tutor path (Story 1.24, DNI-486:
  /// `tutorUpsertGoal`) share. [now] stamps `createdAt`.
  static GoalEntity buildNewGoal({
    required CurriculumId curriculumId,
    required DateTime now,
    PaceTarget? paceTarget,
    String description = '',
    String dateType = 'gregorian',
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
  }) {
    final (goalType, targetDate, paceValue, pacePeriod) = _decomposePaceTarget(
      paceTarget,
    );
    return GoalEntity(
      curriculumId: curriculumId,
      targetDate: targetDate,
      description: description,
      dateType: dateType,
      goalType: goalType,
      paceValue: paceValue,
      pacePeriod: pacePeriod,
      paceGranularity: paceGranularity,
      rawLearningUnit: paceGranularity == null ? rawLearningUnit : null,
      createdAt: now,
    );
  }

  /// The goal [updateGoal] sets, computed without writing: the single
  /// update rule the owner path and the tutor path (Story 1.24, DNI-486:
  /// `tutorUpsertGoal`) share.
  static GoalEntity resolveGoalUpdate({
    required GoalEntity goal,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? description,
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
    bool clearLearningUnit = false,
  }) {
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
      targetDate: resolvedTargetDate,
      description: description ?? goal.description,
      goalType: resolvedGoalType,
      paceValue: resolvedPaceValue,
      pacePeriod: resolvedPacePeriod,
      paceGranularity: resolvedGranularity,
      rawLearningUnit: resolvedRawUnit,
    );
    return updated;
  }

  /// Updates [goal]. Pass [paceTarget] to change the goal's mode, or
  /// [clearPaceTarget] == `true` to make it a `'none'` goal; omitting both
  /// keeps the mode. [clearLearningUnit] == `true` removes the learning
  /// unit; omitting [paceGranularity] / [rawLearningUnit] keeps it.
  ///
  /// A mode change ends the old kind's doc and sets the new kind's doc in
  /// one action; otherwise only the changed fields of the same doc are
  /// written.
  Future<GoalEntity> updateGoal({
    required GoalEntity goal,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? description,
    PaceGranularity? paceGranularity,
    String? rawLearningUnit,
    bool clearLearningUnit = false,
  }) async {
    final updated = resolveGoalUpdate(
      goal: goal,
      paceTarget: paceTarget,
      clearPaceTarget: clearPaceTarget,
      description: description,
      paceGranularity: paceGranularity,
      rawLearningUnit: rawLearningUnit,
      clearLearningUnit: clearLearningUnit,
    );
    await _apply(await planSetGoal(updated));
    return updated;
  }

  /// Ends [goal]'s doc: an `ended_at` tombstone through a logged change,
  /// never a delete. A `'none'` goal has no doc, so nothing is written.
  Future<void> deleteGoal(GoalEntity goal) async {
    final kind = GoalKind.byStorage[goal.goalType];
    if (kind == null) return;
    await _apply([
      OwnerGovernedIntents.endGoal(
        curriculumId: goal.curriculumId.storageKey,
        kind: kind,
        at: _clock(),
      ),
    ]);
  }

  /// The governed entity changes that make [goal] its curriculum's goal:
  /// upsert of [goal]'s kind (nothing for `'none'`) plus an `ended_at`
  /// tombstone of every other live goal doc of the curriculum. Used by the
  /// one-action Add track flow (DNI-476 T5) as well as the writes above.
  Future<List<GovernedEntityChange>> planSetGoal(GoalEntity goal) async {
    final curriculumId = goal.curriculumId.storageKey;
    final kind = GoalKind.byStorage[goal.goalType];
    final live = await _liveDocs(goal.curriculumId);
    final changes = <GovernedEntityChange>[];
    if (kind != null) {
      final docId = goalDocId(curriculumId, kind);
      changes.add(
        OwnerGovernedIntents.setGoal(
          curriculumId: curriculumId,
          kind: kind,
          fields: {
            ..._fieldsOf(goal, kind),
            if (!live.contains(docId))
              'created_at': goal.createdAt.toUtc().toIso8601String(),
          },
        ),
      );
    }
    for (final other in GoalKind.values) {
      if (other == kind) continue;
      if (!live.contains(goalDocId(curriculumId, other))) continue;
      changes.add(
        OwnerGovernedIntents.endGoal(
          curriculumId: curriculumId,
          kind: other,
          at: _clock(),
        ),
      );
    }
    return changes;
  }

  /// The ids of [curriculumId]'s live goal docs.
  Future<Set<String>> _liveDocs(CurriculumId curriculumId) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return {
      for (final doc in snapshot.docs)
        if (_isLive(doc.data())) doc.id,
    };
  }

  /// The AD-43 doc id of [goal]'s kind (`{curriculumId}_deadline` or
  /// `{curriculumId}_pace`); null for a `'none'` goal, which has no doc.
  static String? goalDocIdOf(GoalEntity goal) {
    final kind = GoalKind.byStorage[goal.goalType];
    return kind == null ? null : goalDocId(goal.curriculumId.storageKey, kind);
  }

  /// The storage fields a tutor's governed `tutorUpsertGoal` sets for
  /// [goal] at [goalDocIdOf] (Story 1.24, DNI-486): the same AD-52 fields
  /// the owner path writes, plus `goal_type` / `curriculum_id` (the
  /// callable validates the final doc against its fixed id) and, when
  /// [create], `created_at`. Empty for a `'none'` goal.
  static Map<String, dynamic> tutorUpsertFields(
    GoalEntity goal, {
    bool create = false,
  }) {
    final kind = GoalKind.byStorage[goal.goalType];
    if (kind == null) return const {};
    return {
      'curriculum_id': goal.curriculumId.storageKey,
      'goal_type': kind.storage,
      ..._fieldsOf(goal, kind),
      if (create) 'created_at': goal.createdAt.toUtc().toIso8601String(),
    };
  }

  /// The storage fields of [goal] as a goal of [kind].
  static Map<String, Object?> _fieldsOf(GoalEntity goal, GoalKind kind) {
    final shared = <String, Object?>{
      'description': goal.description,
      'date_type': goal.dateType,
    };
    switch (kind) {
      case GoalKind.deadline:
        final due = goal.targetDate;
        return {
          ...shared,
          if (due != null) 'target_date': FirestoreCodec.encodeCivilDate(due),
        };
      case GoalKind.pace:
        return {
          ...shared,
          'pace_value': goal.paceValue,
          'pace_unit': goal.pacePeriod,
          'pace_granularity': goal.paceGranularityKey,
        };
    }
  }

  Future<void> _apply(List<GovernedEntityChange> changes) async {
    if (changes.isEmpty) return;
    final writer = _writer;
    if (writer == null) throw const GovernedWriterNotReadyException();
    await applyOwnerAction(writer, GovernedAction(changes));
  }
}
