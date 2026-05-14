// Extra coverage for SchedulerEngine — weekly and rolling schedule types.
// These code paths (_processWeeklyStage, _processRollingStage) were not
// exercised by the existing scheduler_engine_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

// ---------------------------------------------------------------------------
// In-memory test doubles (same pattern as scheduler_engine_test.dart)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ScheduleConfig baseConfig({required DateTime currentDate, int trackId = 1}) =>
    ScheduleConfig(
      curriculumId: CurriculumId.mishnayos,
      trackId: trackId,
      trackLabel: 'Personal',
      currentDate: currentDate,
      isStudyDay: true,
    );

SchedulerCompletion completion({
  required String ref,
  required int stageOrder,
  required DateTime completedAt,
}) => SchedulerCompletion(
  sefariaRef: ref,
  stageOrder: stageOrder,
  trackType: 'personal',
  completedAt: completedAt,
);

void main() {
  late FakeContentRepo contentRepo;
  late FakeCompletionRepo completionRepo;
  late FakeStageRepo stageRepo;
  late FakeLearningOrderRepo learningOrderRepo;
  late SchedulerEngine engine;

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

  // =========================================================================
  // Weekly schedule type
  // =========================================================================

  group('SchedulerEngine — weekly schedule type', () {
    // Monday = 1 in Dart DateTime.weekday (ISO weekday)
    final monday = DateTime.utc(2026, 3, 16); // a Monday

    test('schedules a weekly-stage item on the correct day of week', () async {
      contentRepo.items = [
        const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
      ];

      // Stage 1: learn (delay). Stage 2: weekly on Mondays.
      stageRepo.stages = [
        const SchedulerStage(
          id: 1,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        const SchedulerStage(
          id: 2,
          stageOrder: 2,
          stageName: 'Weekly Review',
          delayDays: 0,
          scheduleType: ScheduleType.weekly,
          daysOfWeek: [DateTime.monday], // Monday = 1
        ),
      ];

      // Stage 1 was completed yesterday → stage 2 not yet completed.
      completionRepo.completions = [
        completion(
          ref: 'ref_0',
          stageOrder: 1,
          completedAt: monday.subtract(const Duration(days: 1)),
        ),
      ];

      final tasks = await engine.generateDailyTasks(
        baseConfig(currentDate: monday),
      );

      // Expect one chazara task for the weekly stage.
      final weeklyTasks = tasks.where((t) => t.stageOrder == 2).toList();
      expect(weeklyTasks, hasLength(1));
      expect(weeklyTasks.first.contentItemSefariaRef, 'ref_0');
    });

    test(
      'does NOT schedule a weekly-stage item on a non-matching day',
      () async {
        final tuesday = DateTime.utc(2026, 3, 17); // a Tuesday

        contentRepo.items = [
          const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
        ];

        stageRepo.stages = [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
          const SchedulerStage(
            id: 2,
            stageOrder: 2,
            stageName: 'Weekly Review',
            delayDays: 0,
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [DateTime.monday], // Monday only
          ),
        ];

        completionRepo.completions = [
          completion(
            ref: 'ref_0',
            stageOrder: 1,
            completedAt: monday.subtract(const Duration(days: 2)),
          ),
        ];

        final tasks = await engine.generateDailyTasks(
          baseConfig(currentDate: tuesday),
        );

        final weeklyTasks = tasks.where((t) => t.stageOrder == 2).toList();
        expect(weeklyTasks, isEmpty);
      },
    );

    test(
      'does not schedule a weekly-stage item already completed at that stage',
      () async {
        contentRepo.items = [
          const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
        ];

        stageRepo.stages = [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
          const SchedulerStage(
            id: 2,
            stageOrder: 2,
            stageName: 'Weekly Review',
            delayDays: 0,
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [DateTime.monday],
          ),
        ];

        // Both stages completed.
        completionRepo.completions = [
          completion(
            ref: 'ref_0',
            stageOrder: 1,
            completedAt: monday.subtract(const Duration(days: 2)),
          ),
          completion(
            ref: 'ref_0',
            stageOrder: 2,
            completedAt: monday.subtract(const Duration(days: 1)),
          ),
        ];

        final tasks = await engine.generateDailyTasks(
          baseConfig(currentDate: monday),
        );

        expect(tasks.where((t) => t.stageOrder == 2), isEmpty);
      },
    );

    test(
      'does not schedule a weekly-stage item when daysOfWeek is empty',
      () async {
        contentRepo.items = [
          const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
        ];

        stageRepo.stages = [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
          const SchedulerStage(
            id: 2,
            stageOrder: 2,
            stageName: 'Weekly Review',
            delayDays: 0,
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [], // empty
          ),
        ];

        completionRepo.completions = [
          completion(
            ref: 'ref_0',
            stageOrder: 1,
            completedAt: monday.subtract(const Duration(days: 1)),
          ),
        ];

        final tasks = await engine.generateDailyTasks(
          baseConfig(currentDate: monday),
        );

        expect(tasks.where((t) => t.stageOrder == 2), isEmpty);
      },
    );
  });

  // =========================================================================
  // Rolling schedule type
  // =========================================================================

  group('SchedulerEngine — rolling schedule type', () {
    final today = DateTime.utc(2026, 3, 15);

    test('rolling stage schedules items within the rolling window', () async {
      // 5 content items.
      contentRepo.items = List.generate(
        5,
        (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
      );

      stageRepo.stages = [
        const SchedulerStage(
          id: 1,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        const SchedulerStage(
          id: 2,
          stageOrder: 2,
          stageName: 'Rolling Review',
          delayDays: 0,
          scheduleType: ScheduleType.rolling,
          rollingWindowSize: 3,
        ),
      ];

      // Stage 1 completed for all 5 items. Stage 2 not yet done.
      completionRepo.completions = List.generate(
        5,
        (i) => completion(
          ref: 'ref_$i',
          stageOrder: 1,
          completedAt: today.subtract(Duration(days: i)),
        ),
      );

      final tasks = await engine.generateDailyTasks(
        baseConfig(currentDate: today),
      );

      // Rolling window = 3 → only the 3 most recently completed items
      // should be scheduled for stage 2.
      final rollingTasks = tasks.where((t) => t.stageOrder == 2).toList();
      expect(rollingTasks.length, 3);
    });

    test(
      'rolling stage excludes items already completed at that stage',
      () async {
        contentRepo.items = [
          const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
          const SchedulerContentItem(sefariaRef: 'ref_1', sortOrder: 1),
          const SchedulerContentItem(sefariaRef: 'ref_2', sortOrder: 2),
        ];

        stageRepo.stages = [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
          const SchedulerStage(
            id: 2,
            stageOrder: 2,
            stageName: 'Rolling Review',
            delayDays: 0,
            scheduleType: ScheduleType.rolling,
            rollingWindowSize: 3,
          ),
        ];

        // All 3 items completed at stage 1.
        // ref_0 also completed at stage 2.
        completionRepo.completions = [
          completion(ref: 'ref_0', stageOrder: 1, completedAt: today),
          completion(
            ref: 'ref_0',
            stageOrder: 2,
            completedAt: today,
          ), // already done
          completion(
            ref: 'ref_1',
            stageOrder: 1,
            completedAt: today.subtract(const Duration(days: 1)),
          ),
          completion(
            ref: 'ref_2',
            stageOrder: 1,
            completedAt: today.subtract(const Duration(days: 2)),
          ),
        ];

        final tasks = await engine.generateDailyTasks(
          baseConfig(currentDate: today),
        );

        final rollingTasks = tasks.where((t) => t.stageOrder == 2).toList();
        // ref_0 is already done → only ref_1 and ref_2 should appear.
        expect(rollingTasks.length, 2);
        expect(rollingTasks.map((t) => t.contentItemSefariaRef).toSet(), {
          'ref_1',
          'ref_2',
        });
      },
    );

    test(
      'rolling stage produces no tasks when there are no stage-1 completions',
      () async {
        contentRepo.items = [
          const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
        ];

        stageRepo.stages = [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
          const SchedulerStage(
            id: 2,
            stageOrder: 2,
            stageName: 'Rolling Review',
            delayDays: 0,
            scheduleType: ScheduleType.rolling,
            rollingWindowSize: 5,
          ),
        ];

        // No completions at all.
        completionRepo.completions = [];

        final tasks = await engine.generateDailyTasks(
          baseConfig(currentDate: today),
        );

        expect(tasks.where((t) => t.stageOrder == 2), isEmpty);
      },
    );
  });

  // =========================================================================
  // Mixed: delay + weekly + rolling stages
  // =========================================================================

  group('SchedulerEngine — mixed schedule types', () {
    final monday = DateTime.utc(2026, 3, 16);

    test(
      'all three schedule types coexist and produce their respective tasks',
      () async {
        contentRepo.items = [
          const SchedulerContentItem(sefariaRef: 'ref_A', sortOrder: 0),
          const SchedulerContentItem(sefariaRef: 'ref_B', sortOrder: 1),
        ];

        stageRepo.stages = [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
          // Delay stage — due 1 day after stage 1.
          const SchedulerStage(
            id: 2,
            stageOrder: 2,
            stageName: 'Delay Chazara',
            delayDays: 1,
          ),
          // Weekly stage — due on Mondays.
          const SchedulerStage(
            id: 3,
            stageOrder: 3,
            stageName: 'Weekly Review',
            delayDays: 0,
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [DateTime.monday],
          ),
          // Rolling stage — window of 2.
          const SchedulerStage(
            id: 4,
            stageOrder: 4,
            stageName: 'Rolling Review',
            delayDays: 0,
            scheduleType: ScheduleType.rolling,
            rollingWindowSize: 2,
          ),
        ];

        // ref_A and ref_B: stage 1 completed. ref_A: stage 2 completed.
        completionRepo.completions = [
          completion(
            ref: 'ref_A',
            stageOrder: 1,
            completedAt: monday.subtract(const Duration(days: 2)),
          ),
          completion(
            ref: 'ref_A',
            stageOrder: 2,
            completedAt: monday.subtract(const Duration(days: 1)),
          ),
          completion(
            ref: 'ref_B',
            stageOrder: 1,
            completedAt: monday.subtract(const Duration(days: 1)),
          ),
        ];

        final tasks = await engine.generateDailyTasks(
          baseConfig(currentDate: monday),
        );

        // Delay: ref_B is 1 day past stage 1 completion → stage 2 due.
        expect(
          tasks.any(
            (t) => t.stageOrder == 2 && t.contentItemSefariaRef == 'ref_B',
          ),
          isTrue,
        );

        // Weekly stage (stage 3): ref_A and ref_B haven't done stage 3 yet,
        // stage 2 done for ref_A. We need previous stage completed for weekly.
        // ref_A: stage 2 done → stage 3 weekly due.
        expect(tasks.any((t) => t.stageOrder == 3), isTrue);

        // Rolling (stage 4): window = 2, both items not done at stage 4.
        final rollingTasks = tasks.where((t) => t.stageOrder == 4).toList();
        expect(rollingTasks, hasLength(2));
      },
    );
  });
}
