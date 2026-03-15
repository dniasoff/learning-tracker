import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

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
  test(
    'computation completes in under 500ms with 5,000 content items and 10,000 completions',
    () async {
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
        const SchedulerStage(
          id: 1,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        const SchedulerStage(
          id: 2,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
        const SchedulerStage(
          id: 3,
          stageOrder: 3,
          stageName: 'Chazara 2',
          delayDays: 7,
        ),
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
        goalDeadline: now.add(const Duration(days: 60)),
        currentDate: now,
      );

      final stopwatch = Stopwatch()..start();
      final tasks = await engine.generateDailyTasks(config);
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason:
            'Scheduler took ${stopwatch.elapsedMilliseconds}ms, must be <500ms',
      );
      expect(tasks, isNotEmpty);
    },
  );
}
