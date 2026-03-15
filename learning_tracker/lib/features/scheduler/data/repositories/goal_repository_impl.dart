import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [GoalRepository] using Drift database and sync engine.
class GoalRepositoryImpl implements GoalRepository {
  final AppDatabase _database;
  final SyncEngine? _syncEngine;

  GoalRepositoryImpl({required AppDatabase database, SyncEngine? syncEngine})
    : _database = database,
      _syncEngine = syncEngine;

  @override
  Future<GoalEntity> createGoal({
    required CurriculumId curriculumId,
    required double targetPercent,
    DateTime? targetDate,
    String description = '',
  }) async {
    return await _database.transaction(() async {
      final now = DateTimeFactory.nowUtc();

      final id = await _database.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: curriculumId.storageKey,
          targetPercent: drift.Value(targetPercent),
          targetDate: drift.Value(targetDate?.toUtc()),
          description: drift.Value(description),
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
    final goals = await _database.goalDao.getGoalsByCurriculum(
      curriculumId.storageKey,
    );
    return goals.map(_toEntity).toList();
  }

  @override
  Future<GoalEntity> updateGoal({
    required int goalId,
    double? targetPercent,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? description,
  }) async {
    return await _database.transaction(() async {
      final existing = await _database.goalDao.getGoalById(goalId);
      if (existing == null) {
        throw ArgumentError('Goal not found: $goalId');
      }

      final now = DateTimeFactory.nowUtc();

      await _database.goalDao.updateGoal(
        GoalsCompanion(
          id: drift.Value(goalId),
          curriculumId: drift.Value(existing.curriculumId),
          targetPercent: drift.Value(targetPercent ?? existing.targetPercent),
          targetDate: clearTargetDate
              ? const drift.Value(null)
              : drift.Value(targetDate?.toUtc() ?? existing.targetDate),
          description: drift.Value(description ?? existing.description),
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
    await _database.goalDao.deleteGoal(goalId);
  }

  GoalEntity _toEntity(Goal goal) {
    return GoalEntity(
      id: goal.id,
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == goal.curriculumId,
      ),
      targetPercent: goal.targetPercent,
      targetDate: goal.targetDate?.toUtc(),
      description: goal.description,
      createdAt: goal.createdAt.toUtc(),
      updatedAt: goal.updatedAt.toUtc(),
    );
  }

  Future<void> _syncGoal(GoalEntity entity) async {
    if (_syncEngine == null) return;

    // Goals are synced via the settings collection per the tech notes
    final data = entity.toFirestore();
    data['_type'] = 'goal';
    data['_id'] = entity.firestoreId;
    await _syncEngine.pushSettings(data);
  }
}
