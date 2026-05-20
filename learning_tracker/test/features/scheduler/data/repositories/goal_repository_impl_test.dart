import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;
  late GoalRepositoryImpl repo;
  late int trackId;
  late int bavliTrackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    await seedProfileZero(db);
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
        paceTarget: DeadlineTarget(targetDate),
        description: 'Finish mishnayos',
        dateType: 'gregorian',
      );

      expect(goal.id, isPositive);
      expect(goal.curriculumId, CurriculumId.mishnayos);
      expect(goal.targetPercent, 100.0);
      expect(goal.description, 'Finish mishnayos');
      expect(goal.goalType, 'deadline');
      expect(goal.targetDate, isNotNull);
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

    group('pace goal fields — W3.44 PaceTarget sealed VO', () {
      test('createGoal with PacePeriodTarget persists correctly', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: PacePeriodTarget(rate: 1, period: 'per_day'),
        );

        expect(goal.goalType, 'pace');
        expect(goal.paceValue, 1);
        expect(goal.pacePeriod, 'per_day');
        expect(goal.targetDate, isNull);
        // paceTarget getter reflects sealed VO
        expect(goal.paceTarget, isA<PacePeriodTarget>());
        expect((goal.paceTarget as PacePeriodTarget).rate, 1);
        expect((goal.paceTarget as PacePeriodTarget).period, 'per_day');
      });

      test('createGoal with DeadlineTarget persists correctly', () async {
        final due = DateTime(2026, 12, 31).toUtc();
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: DeadlineTarget(due),
        );

        expect(goal.goalType, 'deadline');
        expect(goal.targetDate, isNotNull);
        expect(goal.paceValue, isNull);
        expect(goal.pacePeriod, isNull);
        expect(goal.paceTarget, isA<DeadlineTarget>());
      });

      test('createGoal with null paceTarget defaults to goalType=none', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
        );

        expect(goal.goalType, 'none');
        expect(goal.paceValue, isNull);
        expect(goal.pacePeriod, isNull);
        expect(goal.paceTarget, isNull);
      });

      test('updateGoal with PacePeriodTarget changes pace fields', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: PacePeriodTarget(rate: 1, period: 'per_day'),
        );

        final updated = await repo.updateGoal(
          goalId: goal.id!,
          paceTarget: PacePeriodTarget(rate: 5, period: 'per_week'),
        );

        expect(updated.paceValue, 5);
        expect(updated.pacePeriod, 'per_week');
        expect(updated.paceTarget, isA<PacePeriodTarget>());
      });

      test('updateGoal with clearPaceTarget nulls out goal mode', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: PacePeriodTarget(rate: 1, period: 'per_day'),
        );

        final updated = await repo.updateGoal(
          goalId: goal.id!,
          clearPaceTarget: true,
        );

        expect(updated.goalType, 'none');
        expect(updated.paceValue, isNull);
        expect(updated.pacePeriod, isNull);
        expect(updated.paceTarget, isNull);
      });

      test('updateGoal preserves pace fields when paceTarget not provided', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
          paceTarget: PacePeriodTarget(rate: 3, period: 'per_week'),
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

      test('paceTarget getter returns null for goalType=none', () async {
        final goal = await repo.createGoal(
          profileId: 0,
          curriculumId: CurriculumId.bavli,
          trackId: bavliTrackId,
          targetPercent: 100.0,
        );
        // goalType=none → paceTarget getter returns null
        expect(goal.paceTarget, isNull);
      });
    });
  });
}
