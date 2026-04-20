import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [GoalRepository] using Drift database and sync engine.
class GoalRepositoryImpl implements GoalRepository {
  final UserDatabase _database;
  final SyncEngine? _syncEngine;
  final int _profileId;

  GoalRepositoryImpl({
    required UserDatabase database,
    SyncEngine? syncEngine,
    int profileId = 0,
  }) : _database = database,
       _syncEngine = syncEngine,
       _profileId = profileId;

  @override
  Future<GoalEntity> createGoal({
    required CurriculumId curriculumId,
    required int trackId,
    required double targetPercent,
    DateTime? targetDate,
    String description = '',
    String dateType = 'gregorian',
    String goalType = 'deadline',
    int? paceValue,
    String? paceUnit,
    String? learningUnit,
  }) async {
    return await _database.transaction(() async {
      final now = DateTimeFactory.nowUtc();

      final id = await _database.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: drift.Value(_profileId),
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          targetPercent: drift.Value(targetPercent),
          targetDate: drift.Value(targetDate?.toUtc()),
          description: drift.Value(description),
          dateType: drift.Value(dateType),
          goalType: drift.Value(goalType),
          paceValue: drift.Value(paceValue),
          paceUnit: drift.Value(paceUnit),
          learningUnit: drift.Value(learningUnit),
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
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? description,
    String? goalType,
    int? paceValue,
    String? paceUnit,
    bool clearPace = false,
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
          profileId: drift.Value(existing.profileId),
          curriculumId: drift.Value(existing.curriculumId),
          trackId: drift.Value(existing.trackId),
          targetPercent: drift.Value(targetPercent ?? existing.targetPercent),
          targetDate: clearTargetDate
              ? const drift.Value(null)
              : drift.Value(targetDate?.toUtc() ?? existing.targetDate),
          description: drift.Value(description ?? existing.description),
          goalType: drift.Value(goalType ?? existing.goalType),
          paceValue: clearPace
              ? const drift.Value(null)
              : drift.Value(paceValue ?? existing.paceValue),
          paceUnit: clearPace
              ? const drift.Value(null)
              : drift.Value(paceUnit ?? existing.paceUnit),
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

  GoalEntity _toEntity(Goal goal) {
    return GoalEntity(
      id: goal.id,
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == goal.curriculumId,
      ),
      targetPercent: goal.targetPercent,
      targetDate: goal.targetDate?.toUtc(),
      description: goal.description,
      dateType: goal.dateType,
      goalType: goal.goalType,
      paceValue: goal.paceValue,
      paceUnit: goal.paceUnit,
      learningUnit: goal.learningUnit,
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

  Future<void> _syncDeleteGoal(GoalEntity entity) async {
    if (_syncEngine == null) return;

    // Mark as deleted in Firestore via the settings collection
    final data = <String, dynamic>{
      '_type': 'goal',
      '_id': entity.firestoreId,
      '_deleted': true,
      'curriculumId': entity.curriculumId.storageKey,
    };
    await _syncEngine.pushSettings(data);
  }
}
