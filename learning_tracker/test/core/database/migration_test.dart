import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  group('Schema migration v15 to v16', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('goals table has goal_type, pace_value, pace_unit columns', () async {
      // Insert a goal using the current schema (v16)
      final now = DateTime.now().toUtc();
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'bavli',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goals = await db.goalDao.getAllGoals();
      expect(goals, hasLength(1));

      final goal = goals.first;
      // Verify default values for new columns
      expect(goal.goalType, 'deadline');
      expect(goal.paceValue, isNull);
      expect(goal.paceUnit, isNull);
    });

    test('goal with pace fields persists correctly', () async {
      final now = DateTime.now().toUtc();
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'bavli',
          goalType: const Value('pace'),
          paceValue: const Value(1),
          paceUnit: const Value('per_day'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goals = await db.goalDao.getAllGoals();
      expect(goals, hasLength(1));

      final goal = goals.first;
      expect(goal.goalType, 'pace');
      expect(goal.paceValue, 1);
      expect(goal.paceUnit, 'per_day');
    });

    test('goal with per_week pace unit persists correctly', () async {
      final now = DateTime.now().toUtc();
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          goalType: const Value('pace'),
          paceValue: const Value(5),
          paceUnit: const Value('per_week'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goals = await db.goalDao.getAllGoals();
      final goal = goals.first;
      expect(goal.goalType, 'pace');
      expect(goal.paceValue, 5);
      expect(goal.paceUnit, 'per_week');
    });

    test('deadline goal has null pace fields by default', () async {
      final now = DateTime.now().toUtc();
      final targetDate = DateTime.utc(2026, 12, 31);
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          targetDate: Value(targetDate),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goals = await db.goalDao.getAllGoals();
      final goal = goals.first;
      expect(goal.goalType, 'deadline');
      expect(goal.targetDate, isNotNull);
      expect(goal.paceValue, isNull);
      expect(goal.paceUnit, isNull);
    });
  });
}
