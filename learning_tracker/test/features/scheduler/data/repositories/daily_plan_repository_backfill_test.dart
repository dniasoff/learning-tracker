import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DailyPlanRepository.backfillMissingSnapshots', () {
    late DailyPlanRepository repo;
    late UserDatabase db;

    DailyTask mkTask(String ref) => DailyTask(
      curriculumId: CurriculumId.mishnayos,
      contentItemSefariaRef: ref,
      stageOrder: 1,
      stageDefinitionId: 101,
      priority: DailyTaskPriority.newLearning,
      isOverdue: true,
      reason: 'Backfilled',
      stageName: 'Learning',
      trackId: 1,
      trackLabel: 'Personal',
    );

    setUp(() {
      db = createTestDatabase();
      repo = DailyPlanRepository(db);
    });

    test(
      'activated 3 days ago with no priors writes 3 synthetic snapshots',
      () async {
        final activatedAt = DateTime.utc(2026, 4, 16, 8, 0);
        final now = DateTime.utc(2026, 4, 19, 9, 0);

        // Builder returns 5 refs per day, indexed by dayIndex.
        final builderCalls = <int>[];
        await repo.backfillMissingSnapshots(
          profileId: 1,
          trackId: 1,
          activatedAt: activatedAt,
          currentDate: now,
          buildSnapshotForDay: ({required dayIndex, required planDate}) async {
            builderCalls.add(dayIndex);
            return List.generate(5, (i) => mkTask('ref_${dayIndex * 5 + i}'));
          },
        );

        // 3 missing days (16, 17, 18 — day 19 is today, not back-filled).
        expect(builderCalls, [0, 1, 2]);

        // Snapshots exist for each prior day.
        for (var d = 0; d < 3; d++) {
          final exists = await db.dailyPlanDao.hasPlanForTrackOnDay(
            trackId: 1,
            planDate: DateTime(2026, 4, 16 + d),
          );
          expect(exists, isTrue, reason: 'day $d snapshot must exist');
        }

        // All 15 refs from the back-fill are now in priorlyShownRefs.
        final priorly = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: 1,
          excludeDate: DateTime(2026, 4, 19),
        );
        expect(priorly, hasLength(15));
      },
    );

    test('only fills missing days when a partial gap exists', () async {
      final activatedAt = DateTime.utc(2026, 4, 16, 8, 0);
      final now = DateTime.utc(2026, 4, 19, 9, 0);

      // Pre-populate day 17 (a real snapshot already exists for that day).
      await repo.getOrSnapshotPlan(
        profileId: 1,
        now: DateTime.utc(2026, 4, 17, 8, 0),
        buildPlan: () async => [mkTask('REAL_DAY1_a'), mkTask('REAL_DAY1_b')],
      );

      final builderCalls = <int>[];
      await repo.backfillMissingSnapshots(
        profileId: 1,
        trackId: 1,
        activatedAt: activatedAt,
        currentDate: now,
        buildSnapshotForDay: ({required dayIndex, required planDate}) async {
          builderCalls.add(dayIndex);
          return [mkTask('SYNTH_d${dayIndex}_a')];
        },
      );

      // Day 1 (April 17) already has a real snapshot, must be skipped.
      // Days 0 (April 16) and 2 (April 18) are still missing.
      expect(builderCalls, [0, 2]);
    });

    test('activated today is a no-op', () async {
      final now = DateTime.utc(2026, 4, 19, 9, 0);
      final activatedAt = DateTime.utc(2026, 4, 19, 1, 0);

      var called = false;
      await repo.backfillMissingSnapshots(
        profileId: 1,
        trackId: 1,
        activatedAt: activatedAt,
        currentDate: now,
        buildSnapshotForDay: ({required dayIndex, required planDate}) async {
          called = true;
          return [];
        },
      );
      expect(called, isFalse);
    });

    test('idempotent: second call writes nothing extra', () async {
      final activatedAt = DateTime.utc(2026, 4, 17, 8, 0);
      final now = DateTime.utc(2026, 4, 19, 9, 0);

      Future<List<DailyTask>> build({
        required int dayIndex,
        required DateTime planDate,
      }) async {
        return [mkTask('d${dayIndex}_only')];
      }

      await repo.backfillMissingSnapshots(
        profileId: 1,
        trackId: 1,
        activatedAt: activatedAt,
        currentDate: now,
        buildSnapshotForDay: build,
      );
      final priorlyAfterFirst = await db.dailyPlanDao
          .getPriorlyShownRefsForTrack(
            trackId: 1,
            excludeDate: DateTime(2026, 4, 19),
          );

      await repo.backfillMissingSnapshots(
        profileId: 1,
        trackId: 1,
        activatedAt: activatedAt,
        currentDate: now,
        buildSnapshotForDay: build,
      );
      final priorlyAfterSecond = await db.dailyPlanDao
          .getPriorlyShownRefsForTrack(
            trackId: 1,
            excludeDate: DateTime(2026, 4, 19),
          );

      expect(priorlyAfterSecond, priorlyAfterFirst);
    });
  });
}
