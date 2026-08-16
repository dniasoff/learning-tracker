import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

// In-memory test doubles
class FakeContentRepo implements SchedulerContentRepository {
  List<SchedulerContentItem> items = [];
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      items;
}

class FakeCompletionRepo implements SchedulerCompletionRepository {
  List<SchedulerCompletion> completions = [];
  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async =>
      completions;
}

class FakeStageRepo implements SchedulerStageRepository {
  List<SchedulerStage> stages = [];
  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async => stages;
}

class FakeLearningOrderRepo implements SchedulerLearningOrderRepository {
  List<SchedulerOrderItem> order = [];
  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => order;
}

void main() {
  late FakeContentRepo contentRepo;
  late FakeCompletionRepo completionRepo;
  late FakeStageRepo stageRepo;
  late FakeLearningOrderRepo learningOrderRepo;
  late SchedulerEngine engine;

  final now = DateTime.utc(2026, 3, 15);
  const curriculum = CurriculumId.mishnayos;

  // Helper: create N content items
  List<SchedulerContentItem> makeItems(int count) {
    return List.generate(
      count,
      (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
    );
  }

  // Helper: default 3-stage setup
  List<SchedulerStage> threeStages() => [
    const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
    const SchedulerStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
    const SchedulerStage(stageOrder: 3, stageName: 'Chazara 2', delayDays: 7),
  ];

  setUp(() {
    contentRepo = FakeContentRepo();
    completionRepo = FakeCompletionRepo();
    stageRepo = FakeStageRepo();
    learningOrderRepo = FakeLearningOrderRepo();
    engine = SchedulerEngine(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      stageRepository: stageRepo,
      learningOrderRepository: learningOrderRepo,
    );
  });

  group('SchedulerEngine', () {
    test(
      'with empty completions and a deadline returns correct new-learning items per day',
      () async {
        contentRepo.items = makeItems(30);
        stageRepo.stages = threeStages();

        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          goalDeadline: now.add(const Duration(days: 10)),
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);

        // 30 items / 10 days = 3 per day
        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        expect(newTasks.length, 3);
        expect(newTasks.first.stageOrder, 1);
        expect(newTasks.first.reason, 'New learning');
      },
    );

    test(
      'generates chazara tasks for items whose delay_days have elapsed since previous stage completion',
      () async {
        contentRepo.items = makeItems(5);
        stageRepo.stages = threeStages();

        // ref_0 completed Learn yesterday
        completionRepo.completions = [
          SchedulerCompletion(
            sefariaRef: 'ref_0',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 1)),
          ),
        ];

        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);

        // Chazara 1 has delayDays=1, so ref_0 should be due today
        final chazaraTasks = tasks
            .where(
              (t) =>
                  t.contentItemSefariaRef == 'ref_0' &&
                  t.priority == DailyTaskPriority.scheduledChazara,
            )
            .toList();
        expect(chazaraTasks.length, 1);
        expect(chazaraTasks.first.stageOrder, 2);
      },
    );

    test(
      'with heavy chazara load still includes at least 1 new-learning item',
      () async {
        contentRepo.items = makeItems(100);
        stageRepo.stages = threeStages();

        // Create many overdue chazara items
        completionRepo.completions = List.generate(
          50,
          (i) => SchedulerCompletion(
            sefariaRef: 'ref_$i',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 30)),
          ),
        );

        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);

        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        expect(newTasks.length, greaterThanOrEqualTo(1));
      },
    );

    test(
      'with behind-schedule state increases daily task count proportionally',
      () async {
        contentRepo.items = makeItems(100);
        stageRepo.stages = threeStages();

        // Only 2 days left, 50 items remaining
        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          goalDeadline: now.add(const Duration(days: 2)),
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);

        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        // 100 items / 2 days = 50 per day
        expect(newTasks.length, 50);
      },
    );

    test(
      'with ahead-of-schedule state reduces daily task count (minimum 1)',
      () async {
        contentRepo.items = makeItems(5);
        stageRepo.stages = threeStages();

        // 100 days left, only 5 items
        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          goalDeadline: now.add(const Duration(days: 100)),
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);

        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        // 5 items / 100 days = ceil(0.05) = 1
        expect(newTasks.length, 1);
      },
    );

    test(
      'with no deadline returns chazara-only tasks plus default new-learning rate',
      () async {
        contentRepo.items = makeItems(20);
        stageRepo.stages = threeStages();

        // Some items have chazara due
        completionRepo.completions = [
          SchedulerCompletion(
            sefariaRef: 'ref_0',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 2)),
          ),
        ];

        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          currentDate: now,
          defaultNewItemsPerDay: 3,
        );

        final tasks = await engine.generateDailyTasks(config);

        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        // defaultNewItemsPerDay = 3, but ref_0 is already learned, so 3 from remaining 19
        expect(newTasks.length, 3);
      },
    );

    test('correctly handles N arbitrary stages (5-stage cycle)', () async {
      contentRepo.items = makeItems(10);
      stageRepo.stages = [
        const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
        const SchedulerStage(
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
        const SchedulerStage(
          stageOrder: 3,
          stageName: 'Chazara 2',
          delayDays: 7,
        ),
        const SchedulerStage(
          stageOrder: 4,
          stageName: 'Chazara 3',
          delayDays: 30,
        ),
        const SchedulerStage(
          stageOrder: 5,
          stageName: 'Chazara 4',
          delayDays: 90,
        ),
      ];

      // ref_0: completed through stage 3 (Chazara 2), 31 days ago
      completionRepo.completions = [
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 100)),
        ),
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 2,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 95)),
        ),
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 3,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 31)),
        ),
      ];

      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        currentDate: now,
      );

      final tasks = await engine.generateDailyTasks(config);

      // Chazara 3 (delayDays=30) should be overdue (31 days since stage 3)
      final chazara3 = tasks.where(
        (t) => t.contentItemSefariaRef == 'ref_0' && t.stageOrder == 4,
      );
      expect(chazara3.length, 1);
      expect(chazara3.first.priority, DailyTaskPriority.overdueChazara);
    });

    test(
      'track scoping handled at repository level — all completions used by engine',
      () async {
        contentRepo.items = makeItems(5);
        stageRepo.stages = threeStages();

        // Both completions are used since filtering is now at the repo level
        completionRepo.completions = [
          SchedulerCompletion(
            sefariaRef: 'ref_0',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 1)),
          ),
          SchedulerCompletion(
            sefariaRef: 'ref_1',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 1)),
          ),
        ];

        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);

        // ref_0 should have chazara due (completion counted)
        final ref0Chazara = tasks.where(
          (t) =>
              t.contentItemSefariaRef == 'ref_0' &&
              (t.priority == DailyTaskPriority.scheduledChazara ||
                  t.priority == DailyTaskPriority.overdueChazara),
        );
        expect(ref0Chazara.length, 1);

        // ref_1 should also have chazara due
        final ref1Chazara = tasks.where(
          (t) =>
              t.contentItemSefariaRef == 'ref_1' &&
              (t.priority == DailyTaskPriority.scheduledChazara ||
                  t.priority == DailyTaskPriority.overdueChazara),
        );
        expect(ref1Chazara.length, 1);
      },
    );

    test(
      'respects custom learning_order — next new-learning item follows custom sequence',
      () async {
        contentRepo.items = makeItems(5);
        stageRepo.stages = threeStages();

        // Custom order: ref_4, ref_2, ref_0 (reversed from natural sort)
        learningOrderRepo.order = [
          const SchedulerOrderItem(sefariaRef: 'ref_4', userSortOrder: 1),
          const SchedulerOrderItem(sefariaRef: 'ref_2', userSortOrder: 2),
          const SchedulerOrderItem(sefariaRef: 'ref_0', userSortOrder: 3),
        ];

        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          currentDate: now,
          defaultNewItemsPerDay: 2,
        );

        final tasks = await engine.generateDailyTasks(config);

        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        // First two should be ref_4 and ref_2 (custom order)
        expect(newTasks[0].contentItemSefariaRef, 'ref_4');
        expect(newTasks[1].contentItemSefariaRef, 'ref_2');
      },
    );

    test(
      'DailyTask output includes priority ranking: overdue > scheduled > new',
      () async {
        contentRepo.items = makeItems(10);
        stageRepo.stages = threeStages();

        completionRepo.completions = [
          // ref_0: Learn completed 10 days ago → Chazara 1 overdue
          SchedulerCompletion(
            sefariaRef: 'ref_0',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 10)),
          ),
          // ref_1: Learn completed 1 day ago → Chazara 1 due today
          SchedulerCompletion(
            sefariaRef: 'ref_1',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 1)),
          ),
        ];

        final config = ScheduleConfig(
          curriculumId: curriculum,
          trackLabel: 'Test Track',
          currentDate: now,
        );

        final tasks = await engine.generateDailyTasks(config);

        // Verify ordering
        expect(tasks.first.priority, DailyTaskPriority.overdueChazara);

        final priorities = tasks.map((t) => t.priority).toList();
        final overdueEnd = priorities.lastIndexOf(
          DailyTaskPriority.overdueChazara,
        );
        final scheduledStart = priorities.indexOf(
          DailyTaskPriority.scheduledChazara,
        );
        final scheduledEnd = priorities.lastIndexOf(
          DailyTaskPriority.scheduledChazara,
        );
        final newStart = priorities.indexOf(DailyTaskPriority.newLearning);

        if (scheduledStart >= 0) {
          expect(overdueEnd, lessThan(scheduledStart));
        }
        if (newStart >= 0 && scheduledEnd >= 0) {
          expect(scheduledEnd, lessThan(newStart));
        }
      },
    );

    test('returns empty list when no stages defined', () async {
      contentRepo.items = makeItems(10);
      stageRepo.stages = [];

      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        currentDate: now,
      );

      final tasks = await engine.generateDailyTasks(config);
      expect(tasks, isEmpty);
    });

    test('returns empty list when no content items', () async {
      contentRepo.items = [];
      stageRepo.stages = threeStages();

      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        currentDate: now,
      );

      final tasks = await engine.generateDailyTasks(config);
      expect(tasks, isEmpty);
    });
  });
}
