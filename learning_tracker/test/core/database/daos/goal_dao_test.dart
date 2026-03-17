import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  final now = DateTime(2024, 6, 15);

  Future<int> insertTestGoal({
    String curriculumId = 'bavli',
    String description = 'Finish Berakhot',
    double targetPercent = 100.0,
    DateTime? targetDate,
  }) {
    return database.goalDao.insertGoal(
      GoalsCompanion.insert(
        curriculumId: curriculumId,
        description: Value(description),
        targetPercent: Value(targetPercent),
        targetDate: Value(targetDate),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('GoalDao', () {
    test('getAllGoals returns empty list initially', () async {
      final goals = await database.goalDao.getAllGoals();
      expect(goals, isEmpty);
    });

    test('insertGoal and getGoalById', () async {
      final id = await insertTestGoal();

      final goal = await database.goalDao.getGoalById(id);
      expect(goal, isNotNull);
      expect(goal!.curriculumId, 'bavli');
      expect(goal.description, 'Finish Berakhot');
      expect(goal.targetPercent, 100.0);
    });

    test('getGoalsByCurriculum filters and orders by targetDate', () async {
      await insertTestGoal(
        targetDate: DateTime(2025, 1, 1),
        description: 'Later goal',
      );
      await insertTestGoal(
        targetDate: DateTime(2024, 7, 1),
        description: 'Earlier goal',
      );
      await insertTestGoal(
        curriculumId: 'yerushalmi',
        description: 'Other curriculum',
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(2));
      expect(goals.first.description, 'Earlier goal');
    });

    test('updateGoal modifies existing goal', () async {
      final id = await insertTestGoal();

      await database.goalDao.updateGoal(
        GoalsCompanion(
          id: Value(id),
          curriculumId: const Value('bavli'),
          description: const Value('Updated goal'),
          targetPercent: const Value(50.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final goal = await database.goalDao.getGoalById(id);
      expect(goal!.description, 'Updated goal');
      expect(goal.targetPercent, 50.0);
    });

    test('deleteGoal removes the goal', () async {
      final id = await insertTestGoal();

      final deleted = await database.goalDao.deleteGoal(id);
      expect(deleted, 1);

      final goal = await database.goalDao.getGoalById(id);
      expect(goal, isNull);
    });

    test('deleteGoalsByCurriculum removes all goals for curriculum', () async {
      await insertTestGoal(description: 'Goal 1');
      await insertTestGoal(description: 'Goal 2');
      await insertTestGoal(
        curriculumId: 'yerushalmi',
        description: 'Other',
      );

      final deleted = await database.goalDao.deleteGoalsByCurriculum('bavli');
      expect(deleted, 2);

      final all = await database.goalDao.getAllGoals();
      expect(all, hasLength(1));
      expect(all.first.curriculumId, 'yerushalmi');
    });

    test('upsertGoal inserts when no existing goal', () async {
      await database.goalDao.upsertGoal(
        curriculumId: 'bavli',
        description: 'New goal',
        targetPercent: 75.0,
        targetDate: DateTime(2025, 1, 1),
        createdAt: now,
        updatedAt: now,
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(1));
      expect(goals.first.description, 'New goal');
      expect(goals.first.targetPercent, 75.0);
    });

    test('upsertGoal updates when newer timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.goalDao.upsertGoal(
        curriculumId: 'bavli',
        description: 'My goal',
        targetPercent: 50.0,
        targetDate: null,
        createdAt: older,
        updatedAt: older,
      );

      await database.goalDao.upsertGoal(
        curriculumId: 'bavli',
        description: 'My goal',
        targetPercent: 75.0,
        targetDate: DateTime(2025, 1, 1),
        createdAt: older,
        updatedAt: newer,
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(1));
      expect(goals.first.targetPercent, 75.0);
    });

    test('upsertGoal does not update when older timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.goalDao.upsertGoal(
        curriculumId: 'bavli',
        description: 'My goal',
        targetPercent: 75.0,
        targetDate: null,
        createdAt: older,
        updatedAt: newer,
      );

      await database.goalDao.upsertGoal(
        curriculumId: 'bavli',
        description: 'My goal',
        targetPercent: 50.0,
        targetDate: null,
        createdAt: older,
        updatedAt: older,
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(1));
      expect(goals.first.targetPercent, 75.0);
    });
  });
}
