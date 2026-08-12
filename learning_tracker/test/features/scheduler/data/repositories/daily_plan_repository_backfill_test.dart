/// Characterisation tests for the post-Drift daily-plan cache.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

void main() {
  DailyTask task(String ref) => DailyTask(
    curriculumId: CurriculumId.mishnayos,
    contentItemSefariaRef: ref,
    stageOrder: 1,
    stageDefinitionId: 101,
    priority: DailyTaskPriority.newLearning,
    isOverdue: false,
    reason: 'New learning',
    stageName: 'Learning',
    trackLabel: 'Mishnayos',
  );

  test('a cache miss builds and a second read serves the snapshot', () async {
    final repo = DailyPlanRepository();
    var calls = 0;
    final first = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: DateTime.utc(2026, 4, 19, 12),
      buildPlan: () async {
        calls++;
        return [task('ref_a'), task('ref_b')];
      },
    );
    final second = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      // Keep both instants on the same local day; cache keys use local dates.
      now: DateTime.utc(2026, 4, 19, 18),
      buildPlan: () async {
        calls++;
        return [task('unexpected')];
      },
    );

    expect(first.isNew, isTrue);
    expect(second.isNew, isFalse);
    expect(second.tasks.map((t) => t.contentItemSefariaRef), [
      'ref_a',
      'ref_b',
    ]);
    expect(calls, 1);
  });

  test(
    'legacy prior-ref DAO query is not part of the session-cache contract',
    () {},
    skip:
        'The Drift daily_plans DAO was removed; prior refs are resolved by the scheduler inputs.',
  );

  test(
    'legacy table wipe is not part of the session-cache contract',
    () {},
    skip:
        'DailyPlanRepository now owns an in-memory cache; there is no Firestore or table wipe equivalent.',
  );
}
