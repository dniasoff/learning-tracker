/// Scheduler engine integration using its current repository interfaces.
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

class _Content implements SchedulerContentRepository {
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async => [
    for (var i = 0; i < 4; i++)
      SchedulerContentItem(sefariaRef: 'item-$i', sortOrder: i),
  ];
}

class _Stages implements SchedulerStageRepository {
  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async => const [
    SchedulerStage(id: -1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
    SchedulerStage(id: -1, stageOrder: 2, stageName: 'Review', delayDays: 1),
  ];
}

class _Completions implements SchedulerCompletionRepository {
  final List<SchedulerCompletion> values = [];

  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async =>
      values;
}

class _Order implements SchedulerLearningOrderRepository {
  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => const [];
}

void main() {
  test('generates new work, then review work after a completion', () async {
    final completions = _Completions();
    final engine = SchedulerEngine(
      contentRepository: _Content(),
      completionRepository: completions,
      stageRepository: _Stages(),
      learningOrderRepository: _Order(),
    );
    final dayOne = DateTime.utc(2026, 3, 15);
    final config = () => ScheduleConfig(
      curriculumId: CurriculumId.mishnayos,
      trackLabel: 'Mishnayos',
      goalDeadline: dayOne.add(const Duration(days: 5)),
      currentDate: dayOne,
      pacePerDay: 4,
      trackStartedAt: dayOne,
    );

    final initial = await engine.generateDailyTasks(config());
    expect(initial, hasLength(4));
    expect(
      initial.every((task) => task.curriculumId == CurriculumId.mishnayos),
      isTrue,
    );
    expect(
      initial.every((task) => task.priority == DailyTaskPriority.newLearning),
      isTrue,
    );

    completions.values.add(
      SchedulerCompletion(
        sefariaRef: 'item-0',
        stageOrder: 1,
        trackType: 'personal',
        completedAt: dayOne,
      ),
    );
    final next = await engine.generateDailyTasks(
      config().copyWith(currentDate: dayOne.add(const Duration(days: 1))),
    );

    expect(next, hasLength(4));
    expect(
      next.where((task) => task.priority == DailyTaskPriority.scheduledChazara),
      hasLength(1),
    );
    expect(
      next
          .singleWhere(
            (task) => task.priority == DailyTaskPriority.scheduledChazara,
          )
          .contentItemSefariaRef,
      'item-0',
    );
    expect(
      next.where((task) => task.priority == DailyTaskPriority.newLearning),
      hasLength(3),
    );
    expect(
      next.map((task) => task.contentItemSefariaRef),
      containsAll(['item-0', 'item-1', 'item-2', 'item-3']),
    );
  });
}
