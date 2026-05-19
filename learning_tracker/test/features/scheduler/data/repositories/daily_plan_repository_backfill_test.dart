/// Wave 3 replacement for the old backfillMissingSnapshots tests.
///
/// backfillMissingSnapshots and backfillStudyDaySnapshots have been deleted
/// (architecture §11 step 4 — the schedule function spans missed days
/// intrinsically; backfill is dead).
///
/// This file now tests the DailyPlanRepository cache contract that
/// remains valid after the cutover: getOrSnapshotPlan and rebuildPlan
/// continue to work correctly for the chazara snapshot cache path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DailyPlanRepository — cache contract after Wave 3 cutover', () {
    late DailyPlanRepository repo;
    late UserDatabase db;

    DailyTask mkTask(String ref) => DailyTask(
      curriculumId: CurriculumId.mishnayos,
      contentItemSefariaRef: ref,
      stageOrder: 1,
      stageDefinitionId: 101,
      priority: DailyTaskPriority.newLearning,
      isOverdue: false,
      reason: 'New learning',
      stageName: 'Learning',
      trackId: 1,
      trackLabel: 'Personal',
    );

    setUp(() {
      db = createTestDatabase();
      repo = DailyPlanRepository(db);
    });

    tearDown(() => db.close());

    test(
      'getOrSnapshotPlan runs buildPlan once — second read serves cache',
      () async {
        final now = DateTime.utc(2026, 4, 19, 10, 0);
        var buildCount = 0;

        Future<List<DailyTask>> build() async {
          buildCount++;
          return [mkTask('ref_a'), mkTask('ref_b')];
        }

        final first = await repo.getOrSnapshotPlan(
          profileId: 1,
          now: now,
          buildPlan: build,
        );
        expect(buildCount, 1);
        expect(first.isNew, isTrue);

        final second = await repo.getOrSnapshotPlan(
          profileId: 1,
          now: now.add(const Duration(hours: 3)),
          buildPlan: build,
        );
        expect(buildCount, 1, reason: 'second read must serve the cache');
        expect(second.isNew, isFalse);
        expect(second.tasks.map((t) => t.contentItemSefariaRef).toList(), [
          'ref_a',
          'ref_b',
        ]);
      },
    );

    test('rebuildPlan clears the cache and regenerates', () async {
      final now = DateTime.utc(2026, 4, 19, 10, 0);

      // Seed the cache.
      await repo.getOrSnapshotPlan(
        profileId: 1,
        now: now,
        buildPlan: () async => [mkTask('old_ref')],
      );

      // Rebuild with a different plan.
      final rebuilt = await repo.rebuildPlan(
        profileId: 1,
        now: now,
        buildPlan: () async => [mkTask('new_ref')],
      );
      expect(rebuilt.map((t) => t.contentItemSefariaRef).toList(), ['new_ref']);

      // Subsequent read from cache returns the rebuilt plan.
      var subsequentBuildCalled = false;
      final subsequent = await repo.getOrSnapshotPlan(
        profileId: 1,
        now: now,
        buildPlan: () async {
          subsequentBuildCalled = true;
          return [mkTask('should_not_appear')];
        },
      );
      expect(subsequentBuildCalled, isFalse);
      expect(subsequent.tasks.single.contentItemSefariaRef, 'new_ref');
    });

    test(
      'getPriorlyShownRefsForTrack returns refs from prior snapshot rows',
      () async {
        // Verify the DAO method still works for chazara — write a snapshot
        // row directly, then retrieve it as a prior ref.
        final yesterday = DateTime.utc(2026, 4, 18);
        final today = DateTime.utc(2026, 4, 19);

        await repo.getOrSnapshotPlan(
          profileId: 1,
          now: yesterday,
          buildPlan: () async => [mkTask('chazara_ref')],
        );

        final priorRefs = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: 1,
          excludeDate: today,
        );
        expect(
          priorRefs,
          contains('chazara_ref'),
          reason: 'chazara ref from yesterday appears in prior refs',
        );
      },
    );

    test(
      'daily_plans table is a disposable cache — wiping it is safe',
      () async {
        // Architecture §6: losing the cache (reinstall, wipe) costs nothing.
        // The projection rebuilds from synced inputs without daily_plans.
        final now = DateTime.utc(2026, 4, 19, 10, 0);

        await repo.getOrSnapshotPlan(
          profileId: 1,
          now: now,
          buildPlan: () async => [mkTask('ref_a')],
        );

        // Wipe daily_plans (simulating reinstall).
        await db.delete(db.dailyPlans).go();

        // Verify: table is empty after wipe.
        final rows = await db.select(db.dailyPlans).get();
        expect(rows, isEmpty, reason: 'daily_plans is fully cleared');

        // The next getOrSnapshotPlan will rebuild from scratch (isNew=true).
        var buildCalled = false;
        final result = await repo.getOrSnapshotPlan(
          profileId: 1,
          now: now,
          buildPlan: () async {
            buildCalled = true;
            return [mkTask('ref_rebuilt')];
          },
        );
        expect(
          buildCalled,
          isTrue,
          reason: 'cache miss after wipe → buildPlan called',
        );
        expect(result.isNew, isTrue);
        expect(result.tasks.single.contentItemSefariaRef, 'ref_rebuilt');
      },
    );
  });
}
