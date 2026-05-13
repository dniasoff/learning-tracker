import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;
  late GoalRepositoryImpl repo;
  late int trackId;
  late int bavliTrackId;

  setUp(() async {
    db = createTestDatabase();
    repo = GoalRepositoryImpl(database: db);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackType: 'personal',
            activatedAt: DateTime.now(),
          ),
        );
    trackId = trackRow.id;

    final bavliTrackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackType: 'personal',
            activatedAt: DateTime.now(),
          ),
        );
    bavliTrackId = bavliTrackRow.id;
  });

  tearDown(() async {
    await db.close();
  });

  group('GoalRepositoryImpl', () {
    test('createGoal creates and returns a goal entity', () async {
      final targetDate = DateTime(2026, 12, 31);
      final goal = await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 100.0,
        targetDate: targetDate,
        description: 'Finish mishnayos',
        dateType: 'gregorian',
      );

      expect(goal.id, isPositive);
      expect(goal.curriculumId, CurriculumId.mishnayos);
      expect(goal.targetPercent, 100.0);
      expect(goal.description, 'Finish mishnayos');
    });

    test('getGoals returns goals for specific curriculum', () async {
      await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 50.0,
      );
      await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.bavli,
        trackId: bavliTrackId,
        targetPercent: 25.0,
      );

      final mishnayosGoals = await repo.getGoals(CurriculumId.mishnayos);
      expect(mishnayosGoals, hasLength(1));
      expect(mishnayosGoals.first.targetPercent, 50.0);

      final bavliGoals = await repo.getGoals(CurriculumId.bavli);
      expect(bavliGoals, hasLength(1));
    });

    test('updateGoal modifies existing goal', () async {
      final goal = await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 50.0,
      );

      final updated = await repo.updateGoal(
        goalId: goal.id!,
        targetPercent: 75.0,
        description: 'Updated goal',
      );

      expect(updated.targetPercent, 75.0);
      expect(updated.description, 'Updated goal');
    });

    test('deleteGoal removes the goal', () async {
      final goal = await repo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        targetPercent: 100.0,
      );

      await repo.deleteGoal(goal.id!);

      final goals = await repo.getGoals(CurriculumId.mishnayos);
      expect(goals, isEmpty);
    });

    test('getGoals returns empty list when no goals', () async {
      final goals = await repo.getGoals(CurriculumId.mishnayos);
      expect(goals, isEmpty);
    });

    group('pace goal fields', () {
      test('createGoal with pace fields persists correctly', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          goalType: 'pace',
          paceValue: 1,
          pacePeriod: 'per_day',
        );

        expect(goal.goalType, 'pace');
        expect(goal.paceValue, 1);
        expect(goal.pacePeriod, 'per_day');
        expect(goal.targetDate, isNull);
      });

      test('createGoal defaults to deadline goalType', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
        );

        expect(goal.goalType, 'deadline');
        expect(goal.paceValue, isNull);
        expect(goal.pacePeriod, isNull);
      });

      test('updateGoal changes pace fields', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          goalType: 'pace',
          paceValue: 1,
          pacePeriod: 'per_day',
        );

        final updated = await repo.updateGoal(
          goalId: goal.id!,
          paceValue: 5,
          pacePeriod: 'per_week',
        );

        expect(updated.paceValue, 5);
        expect(updated.pacePeriod, 'per_week');
      });

      test('updateGoal with clearPace nulls out pace fields', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          goalType: 'pace',
          paceValue: 1,
          pacePeriod: 'per_day',
        );

        final updated = await repo.updateGoal(
          goalId: goal.id!,
          goalType: 'deadline',
          clearPace: true,
        );

        expect(updated.goalType, 'deadline');
        expect(updated.paceValue, isNull);
        expect(updated.pacePeriod, isNull);
      });

      test('updateGoal preserves pace fields when not clearing', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          goalType: 'pace',
          paceValue: 3,
          pacePeriod: 'per_week',
        );

        final updated = await repo.updateGoal(
          goalId: goal.id!,
          description: 'Updated description',
        );

        expect(updated.goalType, 'pace');
        expect(updated.paceValue, 3);
        expect(updated.pacePeriod, 'per_week');
        expect(updated.description, 'Updated description');
      });
    });
  });
}
