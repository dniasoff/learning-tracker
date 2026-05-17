import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DailyPlanRepository', () {
    late DailyPlanRepository repo;
    late int buildCount;

    DailyTask mkTask(String ref, {int stage = 1}) => DailyTask(
      curriculumId: CurriculumId.mishnayos,
      contentItemSefariaRef: ref,
      stageOrder: stage,
      stageDefinitionId: 100 + stage,
      priority: DailyTaskPriority.newLearning,
      isOverdue: false,
      reason: 'New learning',
      stageName: 'Learning',
      trackId: 1,
      trackLabel: 'Personal',
    );

    setUp(() {
      final db = createTestDatabase();
      repo = DailyPlanRepository(db);
      buildCount = 0;
    });

    test(
      'runs buildPlan once per local day — second read serves snapshot',
      () async {
        final now = DateTime.utc(2026, 4, 19, 10, 0);

        Future<List<DailyTask>> build() async {
          buildCount++;
          return [
            mkTask('Mishnah Berachot 1:1'),
            mkTask('Mishnah Berachot 1:2'),
          ];
        }

        final first = await repo.getOrSnapshotPlan(
          profileId: 1,
          now: now,
          buildPlan: build,
        );
        expect(buildCount, 1);
        expect(first.isNew, isTrue);
        expect(first.tasks.map((t) => t.contentItemSefariaRef).toList(), [
          'Mishnah Berachot 1:1',
          'Mishnah Berachot 1:2',
        ]);

        // Second read on the same local day must not call build again.
        final second = await repo.getOrSnapshotPlan(
          profileId: 1,
          now: now.add(const Duration(hours: 5)),
          buildPlan: build,
        );
        expect(buildCount, 1);
        expect(second.isNew, isFalse);
        expect(second.tasks.map((t) => t.contentItemSefariaRef).toList(), [
          'Mishnah Berachot 1:1',
          'Mishnah Berachot 1:2',
        ]);
      },
    );

    test('completions do not change the snapshot', () async {
      final now = DateTime.utc(2026, 4, 19, 10, 0);

      var plan = [mkTask('Item 1'), mkTask('Item 2'), mkTask('Item 3')];
      Future<List<DailyTask>> build() async {
        buildCount++;
        return plan;
      }

      final first = await repo.getOrSnapshotPlan(
        profileId: 1,
        now: now,
        buildPlan: build,
      );
      expect(first.tasks.length, 3);

      // Simulate the scheduler changing its mind (e.g., a completion would
      // shrink the list). We still expect the snapshot to be served.
      plan = [mkTask('Item 99')];

      final second = await repo.getOrSnapshotPlan(
        profileId: 1,
        now: now,
        buildPlan: build,
      );
      expect(
        buildCount,
        1,
        reason: 'buildPlan should not have been called again',
      );
      expect(second.tasks.map((t) => t.contentItemSefariaRef).toList(), [
        'Item 1',
        'Item 2',
        'Item 3',
      ]);
    });

    test('next local day gets a fresh snapshot', () async {
      final today = DateTime.utc(2026, 4, 19, 10, 0);
      final tomorrow = DateTime.utc(2026, 4, 20, 10, 0);

      var plan = [mkTask('Item A')];
      Future<List<DailyTask>> build() async {
        buildCount++;
        return plan;
      }

      await repo.getOrSnapshotPlan(profileId: 1, now: today, buildPlan: build);
      expect(buildCount, 1);

      plan = [mkTask('Item B')];

      final next = await repo.getOrSnapshotPlan(
        profileId: 1,
        now: tomorrow,
        buildPlan: build,
      );
      expect(buildCount, 2, reason: 'new day must trigger a fresh build');
      expect(next.tasks.single.contentItemSefariaRef, 'Item B');
    });

    test('different profiles maintain independent snapshots', () async {
      final now = DateTime.utc(2026, 4, 19, 10, 0);

      Future<List<DailyTask>> buildFor(String ref) async {
        buildCount++;
        return [mkTask(ref)];
      }

      final p1 = await repo.getOrSnapshotPlan(
        profileId: 1,
        now: now,
        buildPlan: () => buildFor('P1 item'),
      );
      final p2 = await repo.getOrSnapshotPlan(
        profileId: 2,
        now: now,
        buildPlan: () => buildFor('P2 item'),
      );
      expect(buildCount, 2);
      expect(p1.tasks.single.contentItemSefariaRef, 'P1 item');
      expect(p2.tasks.single.contentItemSefariaRef, 'P2 item');
    });

    test('preserves priority ordering from the built plan', () async {
      final now = DateTime.utc(2026, 4, 19, 10, 0);

      final plan = <DailyTask>[
        const DailyTask(
          curriculumId: CurriculumId.mishnayos,
          contentItemSefariaRef: 'overdue item',
          stageOrder: 2,
          stageDefinitionId: 102,
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
          reason: 'Chazara overdue by 1 day(s)',
          stageName: 'Chazara 1',
          trackId: 1,
          trackLabel: 'Personal',
        ),
        mkTask('new item'),
      ];

      final result = await repo.getOrSnapshotPlan(
        profileId: 1,
        now: now,
        buildPlan: () async => plan,
      );
      expect(result.tasks.first.priority, DailyTaskPriority.overdueChazara);
      expect(result.tasks.first.isOverdue, true);
      expect(result.tasks.last.priority, DailyTaskPriority.newLearning);
    });
  });
}
