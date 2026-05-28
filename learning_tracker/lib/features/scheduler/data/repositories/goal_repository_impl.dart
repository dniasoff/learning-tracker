import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';

/// Implementation of [GoalRepository] using Drift database and sync engine.
class GoalRepositoryImpl implements GoalRepository {
  final UserDatabase _database;
  final SyncWriteFacade? _syncEngine;
  final int _profileId;

  GoalRepositoryImpl({
    required UserDatabase database,
    SyncWriteFacade? syncEngine,
    int profileId = 0,
  }) : _database = database,
       _syncEngine = syncEngine,
       _profileId = profileId;

  @override
  Future<GoalEntity> createGoal({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
    required double targetPercent,
    PaceTarget? paceTarget,
    String description = '',
    String dateType = 'gregorian',
    String? paceGranularity,
  }) async {
    return await _database.transaction(() async {
      final now = DateTimeFactory.nowUtc();
      final (goalType, targetDate, paceValue, pacePeriod) =
          _decomposePaceTarget(paceTarget);

      final id = await _database.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          targetPercent: drift.Value(targetPercent),
          targetDate: drift.Value(targetDate),
          description: drift.Value(description),
          dateType: drift.Value(dateType),
          goalType: drift.Value(goalType),
          paceValue: drift.Value(paceValue),
          pacePeriod: drift.Value(pacePeriod),
          paceGranularity: drift.Value(paceGranularity),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goal = await _database.goalDao.getGoalById(id);
      if (goal == null) {
        throw StateError('Failed to retrieve created goal');
      }

      final entity = _toEntity(goal);

      // Push to Firestore
      await _syncGoal(entity);

      return entity;
    });
  }

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async {
    final goals = await _database.goalDao.getGoalsByCurriculumAndProfile(
      curriculumId.storageKey,
      _profileId,
    );
    return goals.map(_toEntity).toList();
  }

  @override
  Future<GoalEntity> updateGoal({
    required int goalId,
    double? targetPercent,
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? description,
    PaceGranularity? paceGranularity,
    bool clearLearningUnit = false,
  }) async {
    return await _database.transaction(() async {
      final existing = await _database.goalDao.getGoalById(goalId);
      if (existing == null) {
        throw ArgumentError('Goal not found: $goalId');
      }

      final now = DateTimeFactory.nowUtc();

      // Resolve the learning unit string from typed enum or fallback to existing.
      final resolvedLearningUnit = clearLearningUnit
          ? null
          : (paceGranularity != null
                ? paceGranularity.storageKey
                : existing.paceGranularity);

      // Decompose paceTarget if explicitly set; keep existing values otherwise.
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
        // No change to goal-mode fields.
        resolvedGoalType = existing.goalType;
        resolvedTargetDate = existing.targetDate;
        resolvedPaceValue = existing.paceValue;
        resolvedPacePeriod = existing.pacePeriod;
      }

      await _database.goalDao.updateGoal(
        GoalsCompanion(
          id: drift.Value(goalId),
          profileId: drift.Value(existing.profileId),
          curriculumId: drift.Value(existing.curriculumId),
          trackId: drift.Value(existing.trackId),
          targetPercent: drift.Value(targetPercent ?? existing.targetPercent),
          targetDate: drift.Value(resolvedTargetDate?.toUtc()),
          description: drift.Value(description ?? existing.description),
          goalType: drift.Value(resolvedGoalType),
          paceValue: drift.Value(resolvedPaceValue),
          pacePeriod: drift.Value(resolvedPacePeriod),
          paceGranularity: drift.Value(resolvedLearningUnit),
          createdAt: drift.Value(existing.createdAt),
          updatedAt: drift.Value(now),
        ),
      );

      final updated = await _database.goalDao.getGoalById(goalId);
      if (updated == null) {
        throw StateError('Failed to retrieve updated goal');
      }

      final entity = _toEntity(updated);
      await _syncGoal(entity);

      return entity;
    });
  }

  @override
  Future<void> deleteGoal(int goalId) async {
    // Retrieve the entity before deleting so we can sync the deletion
    final existing = await _database.goalDao.getGoalById(goalId);
    await _database.goalDao.deleteGoal(goalId);

    // Sync deletion to Firestore
    if (existing != null) {
      final entity = _toEntity(existing);
      await _syncDeleteGoal(entity);
    }
  }

  /// Decomposes a [PaceTarget] into the four raw DB columns
  /// (goalType, targetDate, paceValue, pacePeriod).
  (String goalType, DateTime? targetDate, int? paceValue, String? pacePeriod)
  _decomposePaceTarget(PaceTarget? paceTarget) {
    switch (paceTarget) {
      case DeadlineTarget(:final dueDate):
        return ('deadline', dueDate.toUtc(), null, null);
      case PacePeriodTarget(:final rate, :final period):
        return ('pace', null, rate, period);
      case null:
        return ('none', null, null, null);
    }
  }

  GoalEntity _toEntity(Goal goal) {
    final rawUnit = goal.paceGranularity;
    final granularity = PaceGranularity.fromStorageKey(rawUnit);
    return GoalEntity(
      id: goal.id,
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == goal.curriculumId,
      ),
      trackId: goal.trackId,
      targetPercent: goal.targetPercent,
      targetDate: goal.targetDate?.toUtc(),
      description: goal.description,
      dateType: goal.dateType,
      goalType: goal.goalType,
      paceValue: goal.paceValue,
      pacePeriod: goal.pacePeriod,
      paceGranularity: granularity,
      rawLearningUnit: granularity == null ? rawUnit : null,
      createdAt: goal.createdAt.toUtc(),
      updatedAt: goal.updatedAt.toUtc(),
    );
  }

  Future<void> _syncGoal(GoalEntity entity) async {
    if (_syncEngine == null) return;

    // Route to the `goals` subcollection, NOT `settings`. The pull-side
    // listener (`SyncEngine._onGoalsUpdate`) subscribes to `goals` directly,
    // so a goal pushed via `pushSettings` lands somewhere the listener never
    // looks and silently never replicates (fixed 2026-05-19).
    //
    // `id` (not `_id`) is what `FirestoreGateway.pushGoal` reads to pick the
    // deterministic doc id — passing `_id` falls through to `collection.add`
    // and creates a new duplicate doc per save.
    final data = entity.toFirestore();
    data['id'] = entity.firestoreId;
    await _syncEngine.pushGoal(data);
  }

  Future<void> _syncDeleteGoal(GoalEntity entity) async {
    if (_syncEngine == null) return;

    // Hard delete in Firestore via the dedicated goal_delete queue type —
    // mirrors the existing profile_program_delete / learner_profile_delete
    // pattern so the cloud row goes away when the local row does.
    await _syncEngine.deleteGoal({
      'firestore_id': entity.firestoreId,
      'curriculum_id': entity.curriculumId.storageKey,
    });
  }
}
