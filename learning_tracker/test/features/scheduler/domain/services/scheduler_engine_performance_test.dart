import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

/// See the AUD-t-scheduler-06 comment at the assertion site for the full
/// rationale: ~260x the measured ~17-19ms local baseline, wide enough to
/// absorb CI-runner contention while still catching a real algorithmic
/// (e.g. quadratic) regression.
const _quadraticRegressionThresholdMs = 5000;

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
  test('computation does not regress to quadratic-or-worse complexity with '
      '5,000 content items and 10,000 completions', () async {
    final contentRepo = FakeContentRepo();
    final completionRepo = FakeCompletionRepo();
    final stageRepo = FakeStageRepo();
    final learningOrderRepo = FakeLearningOrderRepo();

    final engine = SchedulerEngine(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      stageRepository: stageRepo,
      learningOrderRepository: learningOrderRepo,
    );

    // 5,000 content items
    contentRepo.items = List.generate(
      5000,
      (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
    );

    // 3 stages
    stageRepo.stages = [
      const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
      const SchedulerStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
      const SchedulerStage(stageOrder: 3, stageName: 'Chazara 2', delayDays: 7),
    ];

    final now = DateTime.utc(2026, 3, 15);

    // 10,000 completions across 2,500 items (4 completions each on average)
    completionRepo.completions = List.generate(10000, (i) {
      final itemIndex = i % 2500;
      final stageOrder = (i ~/ 2500) + 1;
      return SchedulerCompletion(
        sefariaRef: 'ref_$itemIndex',
        stageOrder: stageOrder.clamp(1, 3),
        trackType: 'personal',
        completedAt: now.subtract(Duration(days: 30 - (i % 30))),
      );
    });

    final config = ScheduleConfig(
      curriculumId: CurriculumId.mishnayos,
      trackLabel: 'Test Track',
      goalDeadline: now.add(const Duration(days: 60)),
      currentDate: now,
    );

    final stopwatch = Stopwatch()..start();
    final tasks = await engine.generateDailyTasks(config);
    stopwatch.stop();

    // AUD-t-scheduler-06 (TQ-6 hermetic tests / Nygard "erratic test"):
    // this assertion reads the wall clock, which is inherently
    // non-hermetic in a unit suite that runs alongside every other test
    // file with no isolation from host CPU speed or CI-runner
    // contention. It cannot be made fully hermetic without dropping the
    // wall-clock check entirely (which would leave a genuine algorithmic
    // regression, e.g. an accidental O(n^2) reintroduction, undetected),
    // so instead the threshold carries a large safety margin over the
    // measured baseline rather than a tight one:
    //   - Measured locally (8 runs): 17-19ms.
    // _quadraticRegressionThresholdMs is ~260x that baseline -- enough
    // headroom to absorb CI-runner contention and parallel-isolate
    // scheduling noise without a false-negative rerun, while still
    // failing fast on a real complexity regression: a nested-loop bug
    // that turned this from linear into quadratic-in-input-size work
    // would push runtime from ~18ms into the seconds-to-minutes range
    // for this fixture's size, not linger just under the cap.
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(_quadraticRegressionThresholdMs),
      reason:
          'Scheduler took ${stopwatch.elapsedMilliseconds}ms, must be '
          '<${_quadraticRegressionThresholdMs}ms (measured baseline is '
          '~17-19ms; see AUD-t-scheduler-06 comment above for the '
          'margin rationale)',
    );
    expect(tasks, isNotEmpty);
  });
}
