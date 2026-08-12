/// Extended Firestore-era scheduler generator characterisation tests.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:test/test.dart';

class _Content implements SchedulerContentRepository {
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async => [
    for (var i = 0; i < 5; i++)
      SchedulerContentItem(
        sefariaRef: '${id.storageKey}-$i',
        sortOrder: i,
        level1: 'Seder',
        level2: 'Masechta',
        level3: 'Perek ${i ~/ 2}',
        level4: 'Mishna $i',
      ),
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
  final Map<CurriculumId, List<SchedulerCompletion>> values = {};

  void add(CurriculumId curriculumId, SchedulerCompletion completion) {
    values.putIfAbsent(curriculumId, () => []).add(completion);
  }

  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async =>
      values[id] ?? const [];
}

class _Order implements SchedulerLearningOrderRepository {
  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => const [];
}

DailyTaskGenerator _generator(_Completions completions) => DailyTaskGenerator(
  engine: SchedulerEngine(
    contentRepository: _Content(),
    completionRepository: completions,
    stageRepository: _Stages(),
    learningOrderRepository: _Order(),
  ),
);

void main() {
  final date = DateTime.utc(2026, 4, 20);

  test('generateAll combines curricula and sorts by priority', () async {
    final completions = _Completions();
    completions.add(
      CurriculumId.mishnayos,
      SchedulerCompletion(
        sefariaRef: 'mishnayos-0',
        stageOrder: 1,
        trackType: 'personal',
        completedAt: date.subtract(const Duration(days: 2)),
      ),
    );
    final tasks = await _generator(completions).generateAll(
      [CurriculumId.mishnayos, CurriculumId.bavli],
      date,
      trackLabels: const {
        CurriculumId.mishnayos: 'Mishnayos',
        CurriculumId.bavli: 'Bavli',
      },
    );

    expect(tasks, hasLength(10));
    expect(tasks.first.contentItemSefariaRef, 'mishnayos-0');
    expect(tasks.first.priority, DailyTaskPriority.overdueChazara);
    expect(
      tasks.where((task) => task.priority == DailyTaskPriority.newLearning),
      hasLength(9),
    );
    expect(tasks.map((task) => task.curriculumId).toSet(), {
      CurriculumId.mishnayos,
      CurriculumId.bavli,
    });
    for (var i = 1; i < tasks.length; i++) {
      expect(
        tasks[i - 1].priority.index,
        lessThanOrEqualTo(tasks[i].priority.index),
      );
    }
  });

  test('priorly shown refs are forwarded to the engine', () async {
    final tasks = await _generator(_Completions()).generateAll(
      [CurriculumId.mishnayos],
      date,
      trackLabels: const {CurriculumId.mishnayos: 'Mishnayos'},
      pacePerDayMap: const {CurriculumId.mishnayos: 1},
      trackStartedAtMap: {
        CurriculumId.mishnayos: date.subtract(const Duration(days: 1)),
      },
      priorlyShownRefsMap: const {
        CurriculumId.mishnayos: {'mishnayos-0'},
      },
    );

    expect(tasks, hasLength(2));
    expect(tasks.first.contentItemSefariaRef, 'mishnayos-0');
    expect(tasks.first.priority, DailyTaskPriority.overdueNewLearning);
    expect(tasks.last.contentItemSefariaRef, 'mishnayos-1');
    expect(tasks.last.priority, DailyTaskPriority.newLearning);
  });

  test('pace granularity schedules a whole coarse unit', () async {
    final tasks = await _generator(_Completions()).generateAll(
      [CurriculumId.mishnayos],
      date,
      trackLabels: const {CurriculumId.mishnayos: 'Mishnayos'},
      pacePerDayMap: const {CurriculumId.mishnayos: 1},
      trackStartedAtMap: {CurriculumId.mishnayos: date},
      paceGranularityMap: const {CurriculumId.mishnayos: 'perek'},
    );

    expect(tasks, hasLength(2));
    expect(tasks.map((task) => task.contentItemSefariaRef).toSet(), {
      'mishnayos-0',
      'mishnayos-1',
    });
    expect(
      tasks.every((task) => task.priority == DailyTaskPriority.newLearning),
      isTrue,
    );
  });
}
