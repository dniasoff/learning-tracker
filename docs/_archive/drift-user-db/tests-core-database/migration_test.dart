import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/test_database.dart';

// AUD-t-cross-25: this group used to be titled "Schema migration v15 to
// v16", implying it drives UserDatabase's real MigrationStrategy. It never
// did — `createTestDatabase()` builds a fresh database via `onCreate` at the
// *current* schemaVersion, and `user_database.dart`'s `onUpgrade` has no
// `if (from < 16)` step for this test to reach (the earliest guard today is
// `if (from < 25)`). What this group actually verifies — and continues to
// verify below, unchanged — is real, current-schema behavior: the `goalType`
// column's `withDefault(Constant('deadline'))` and the nullable
// `paceValue`/`pacePeriod` columns declared in
// `lib/core/database/tables/goals.dart`, exercised through the production
// `GoalDao.insertGoal` path. Renamed to say what it tests instead of a
// migration version that doesn't exist.
void main() {
  group(
    'Goals table: goal_type / pace_value / pace_period columns (current schema)',
    () {
      late UserDatabase db;
      late int trackId;

      setUp(() async {
        db = createTestDatabase();
        await seedProfile(db);
        trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'goals table has goal_type, pace_value, pace_unit columns',
        () async {
          // Insert a goal using the current schema.
          final now = DateTime.utc(2026, 1, 1);
          await db.goalDao.insertGoal(
            GoalsCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackId: trackId,
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
          expect(goal.pacePeriod, isNull);
        },
      );

      test('goal with pace fields persists correctly', () async {
        final now = DateTime.utc(2026, 1, 1);
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackId: trackId,
            goalType: const Value('pace'),
            paceValue: const Value(1),
            pacePeriod: const Value('per_day'),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final goals = await db.goalDao.getAllGoals();
        expect(goals, hasLength(1));

        final goal = goals.first;
        expect(goal.goalType, 'pace');
        expect(goal.paceValue, 1);
        expect(goal.pacePeriod, 'per_day');
      });

      test('goal with per_week pace unit persists correctly', () async {
        final now = DateTime.utc(2026, 1, 1);
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackId: trackId,
            goalType: const Value('pace'),
            paceValue: const Value(5),
            pacePeriod: const Value('per_week'),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final goals = await db.goalDao.getAllGoals();
        final goal = goals.first;
        expect(goal.goalType, 'pace');
        expect(goal.paceValue, 5);
        expect(goal.pacePeriod, 'per_week');
      });

      test('deadline goal has null pace fields by default', () async {
        final now = DateTime.utc(2026, 1, 1);
        final targetDate = DateTime.utc(2026, 12, 31);
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackId: trackId,
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
        expect(goal.pacePeriod, isNull);
      });
    },
  );
}
