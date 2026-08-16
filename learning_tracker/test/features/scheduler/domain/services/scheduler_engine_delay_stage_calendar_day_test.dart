// Regression test for AUD-scheduler-13.
//
// `_processDelayStage` computed `daysUntilDue` from raw (unnormalized)
// timestamps: `dueDate.difference(config.currentDate).inDays`. `Duration
// .inDays` truncates toward zero, so when the previous stage's completion
// time-of-day is LATER than the current query's time-of-day, a genuinely
// 1+ calendar-day-overdue item can compute `daysUntilDue == 0` (elapsed
// wall-clock time is <24h even though the calendar-day gap is >=1) and
// land in `scheduledTasks` ("due today") instead of `overdueTasks`.
//
// Fix: normalize both `previousCompletedAt` and `config.currentDate` to
// calendar-date-only (`LocalDayUtils.extractLocalDate`) before the
// due-date arithmetic, matching the pattern already used in
// `_buildProjectionTasks` (scheduler_providers.dart).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

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

  group('SchedulerEngine — delay-stage calendar-day normalization', () {
    test('a delay-stage item with a true 1-calendar-day gap but a '
        'later-in-the-day previous completion lands in overdueTasks, '
        'not scheduledTasks', () async {
      contentRepo.items = [
        const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
      ];

      // Stage 1: learn (delay 0). Stage 2: Chazara 1, due 1 day after
      // stage 1 completion.
      stageRepo.stages = [
        const SchedulerStage(
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        const SchedulerStage(
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
      ];

      // Stage 1 completed 2026-03-13 at 20:00, current query at 2026-03-15
      // 02:00 — a 30-hour (1 day + 6 hour) wall-clock gap.
      //
      // Deliberately constructed with the LOCAL (non-UTC) `DateTime(...)`
      // constructor rather than `DateTime.utc(...)`: `LocalDayUtils
      // .extractLocalDate` calls `.toLocal()` on its argument, which is a
      // documented no-op for a DateTime that is already local
      // (`isUtc == false` returns `this` unchanged). Using local literals
      // here makes the calendar-day math fully deterministic regardless
      // of the machine's system timezone (dev sandbox vs CI), while
      // `.add`/`.difference` still operate on the same real elapsed
      // duration either way — so the pre-fix bug reproduces identically.
      //
      // Due calendar date (delayDays=1) is therefore 03-14. The current
      // query date is 03-15 — i.e. the item is genuinely ONE calendar
      // day overdue (03-15 is one day past the 03-14 due date). But the
      // raw wall-clock difference between dueDate (03-14 20:00) and "now"
      // (03-15 02:00) is a NEGATIVE 6-hour duration whose truncating
      // `.inDays` is 0, not -1 — causing the engine to (pre-fix) classify
      // this as "due today" rather than "overdue by 1 day".
      completionRepo.completions = [
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: DateTime(2026, 3, 13, 20),
        ),
      ];

      final config = ScheduleConfig(
        curriculumId: CurriculumId.mishnayos,
        trackLabel: 'Test Track',
        currentDate: DateTime(2026, 3, 15, 2),
      );

      final tasks = await engine.generateDailyTasks(config);

      final overdue = tasks.where(
        (t) =>
            t.contentItemSefariaRef == 'ref_0' &&
            t.priority == DailyTaskPriority.overdueChazara,
      );
      final scheduled = tasks.where(
        (t) =>
            t.contentItemSefariaRef == 'ref_0' &&
            t.priority == DailyTaskPriority.scheduledChazara,
      );

      expect(
        overdue.length,
        1,
        reason:
            'ref_0 is genuinely 1 calendar day overdue for Chazara 1 '
            '(due 03-14, queried on 03-15) and must appear in '
            'overdueTasks even though the raw wall-clock gap between '
            'the completion timestamp and "now" is <24h due to '
            'time-of-day skew.',
      );
      expect(scheduled.length, 0);
    });
  });
}
