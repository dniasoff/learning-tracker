// Extra coverage for ChartDataService.getTargetLine — not exercised by the
// baseline test, which only covers getDailyCompletions and getDailyPoints.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late ChartDataService service;
  late int trackId;
  const profileId = 1;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    service = ChartDataService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  var refCounter = 0;

  Future<void> insertCompletion({
    required DateTime completedAt,
    String curriculumId = 'mishnayos',
    int points = 10,
    int stageId = 1,
  }) => seedCompletion(
    db,
    CompletionsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: 'Berakhot.${++refCounter}',
      stageId: stageId,
      trackType: 'personal',
      trackId: trackId,
      completedAt: completedAt,
      points: Value(points),
    ),
  ).then((_) {});

  // =========================================================================
  // getTargetLine — returns null when no goal
  // =========================================================================

  group('ChartDataService.getTargetLine — no goal', () {
    test('returns null when there are no goals for the curriculum', () async {
      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 31),
      );
      expect(result, isNull);
    });
  });

  // =========================================================================
  // getTargetLine — returns null when goal has no targetDate
  // =========================================================================

  group('ChartDataService.getTargetLine — goal without targetDate', () {
    test('returns null when the goal has no targetDate', () async {
      final now = DateTime.utc(2026, 1, 1);
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
          // targetDate intentionally not provided → null
        ),
      );

      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
      );
      expect(result, isNull);
    });
  });

  // =========================================================================
  // getTargetLine — returns null when totalDays <= 0
  // =========================================================================

  group('ChartDataService.getTargetLine — degenerate goal', () {
    test('returns null when targetDate equals createdAt (0 days)', () async {
      final d = DateTime.utc(2026, 3, 1);
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: d,
          updatedAt: d,
          targetDate: Value(d), // same day → 0 total days
        ),
      );

      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: d,
        endDate: d.add(const Duration(days: 10)),
      );
      expect(result, isNull);
    });
  });

  // =========================================================================
  // getTargetLine — valid goal with completions
  // =========================================================================

  group('ChartDataService.getTargetLine — with valid goal', () {
    test(
      'returns a target line with one point per day in the date range',
      () async {
        final goalCreated = DateTime.utc(2026, 1, 1);
        final goalEnd = DateTime.utc(2026, 1, 11); // 10 days span
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackId: trackId,
            createdAt: goalCreated,
            updatedAt: goalCreated,
            targetDate: Value(goalEnd),
          ),
        );

        // Insert 5 completions within the goal window.
        for (var i = 1; i <= 5; i++) {
          await insertCompletion(completedAt: DateTime.utc(2026, 1, i));
        }

        final startDate = DateTime.utc(2026, 1, 1);
        final endDate = DateTime.utc(2026, 1, 5);
        final result = await service.getTargetLine(
          curriculumId: 'mishnayos',
          startDate: startDate,
          endDate: endDate,
        );

        expect(result, isNotNull);
        // One point per day for 5 days inclusive.
        expect(result!.length, 5);
      },
    );

    test('expectedTotal increases monotonically over time', () async {
      final goalCreated = DateTime.utc(2026, 1, 1);
      final goalEnd = DateTime.utc(2026, 1, 21); // 20 days
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: goalCreated,
          updatedAt: goalCreated,
          targetDate: Value(goalEnd),
        ),
      );

      for (var i = 1; i <= 10; i++) {
        await insertCompletion(completedAt: DateTime.utc(2026, 1, i));
      }

      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 10),
      );

      expect(result, isNotNull);
      for (var i = 1; i < result!.length; i++) {
        expect(
          result[i].expectedTotal,
          greaterThanOrEqualTo(result[i - 1].expectedTotal),
        );
      }
    });

    test('baselineCount excludes completions before goal.createdAt', () async {
      // Insert 3 completions before the goal was created.
      for (var i = 1; i <= 3; i++) {
        await insertCompletion(completedAt: DateTime.utc(2025, 12, i));
      }

      final goalCreated = DateTime.utc(2026, 1, 1);
      final goalEnd = DateTime.utc(2026, 1, 11);
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: goalCreated,
          updatedAt: goalCreated,
          targetDate: Value(goalEnd),
        ),
      );

      // 2 completions within the goal window
      for (var i = 1; i <= 2; i++) {
        await insertCompletion(completedAt: DateTime.utc(2026, 1, i));
      }

      final result = await service.getTargetLine(
        curriculumId: 'mishnayos',
        startDate: goalCreated,
        endDate: goalEnd,
      );

      expect(result, isNotNull);
      // First point (at start date) should reflect the baseline offset.
      // Baseline = 3 (pre-goal completions). At t=0, fraction=0, so
      // expectedTotal = baselineCount + totalCompletions * 0 = 3.
      expect(result!.first.expectedTotal, greaterThanOrEqualTo(3.0));
    });
  });
}
