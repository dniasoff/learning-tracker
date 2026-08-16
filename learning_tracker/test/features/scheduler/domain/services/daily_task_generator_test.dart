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
    for (var i = 0; i < 4; i++)
      SchedulerContentItem(sefariaRef: '${id.storageKey}-$i', sortOrder: i),
  ];
}

class _Stages implements SchedulerStageRepository {
  _Stages(this.reviewDelay);

  final int reviewDelay;

  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async =>
      const [
        SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
        SchedulerStage(stageOrder: 2, stageName: 'Review', delayDays: 1),
      ].map((stage) {
        if (stage.stageOrder == 2) {
          return stage.copyWith(delayDays: reviewDelay);
        }
        return stage;
      }).toList();
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

DailyTaskGenerator _generator(_Completions completions, {int reviewDelay = 1}) {
  return DailyTaskGenerator(
    engine: SchedulerEngine(
      contentRepository: _Content(),
      completionRepository: completions,
      stageRepository: _Stages(reviewDelay),
      learningOrderRepository: _Order(),
    ),
  );
}

void main() {
  const curriculum = CurriculumId.mishnayos;
  final date = DateTime.utc(2026, 4, 20);

  test('empty curriculum input returns no tasks', () async {
    final generator = _generator(_Completions());
    expect(await generator.generateAll([], date), isEmpty);
  });

  test(
    'generates tasks without a Drift database or integer track id',
    () async {
      final generator = _generator(_Completions());
      final tasks = await generator.generate(
        curriculum,
        date,
        trackLabel: 'Mishnayos',
      );

      expect(tasks, hasLength(4));
      expect(tasks.every((task) => task.curriculumId == curriculum), isTrue);
      expect(tasks.map((task) => task.contentItemSefariaRef), [
        'mishnayos-0',
        'mishnayos-1',
        'mishnayos-2',
        'mishnayos-3',
      ]);
    },
  );

  test('skipped refs are removed after generation', () async {
    final generator = _generator(_Completions());
    final all = await generator.generate(
      curriculum,
      date,
      trackLabel: 'Mishnayos',
    );
    final skipped = all.first.contentItemSefariaRef;

    final filtered = await generator.generate(
      curriculum,
      date,
      trackLabel: 'Mishnayos',
      skippedRefs: {skipped},
    );

    expect(
      filtered.any((task) => task.contentItemSefariaRef == skipped),
      isFalse,
    );
  });

  test('a non-study day suppresses new learning', () async {
    final completions = _Completions();
    completions.values.add(
      SchedulerCompletion(
        sefariaRef: 'mishnayos-0',
        stageOrder: 1,
        trackType: 'personal',
        completedAt: date.subtract(const Duration(days: 2)),
      ),
    );
    final generator = _generator(completions);
    final tasks = await generator.generate(
      curriculum,
      date,
      trackLabel: 'Mishnayos',
      isStudyDay: false,
    );

    expect(tasks, hasLength(1));
    expect(tasks.single.contentItemSefariaRef, 'mishnayos-0');
    expect(tasks.single.priority, DailyTaskPriority.overdueChazara);
    expect(tasks.single.isOverdue, isTrue);
    expect(
      tasks.where((task) => task.priority == DailyTaskPriority.newLearning),
      isEmpty,
    );
  });

  test(
    'recomputes completion-driven review work on the following day',
    () async {
      final completions = _Completions();
      final generator = _generator(completions);
      completions.values.add(
        SchedulerCompletion(
          sefariaRef: 'mishnayos-0',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: date,
        ),
      );

      final today = await generator.generate(
        curriculum,
        date,
        trackLabel: 'Mishnayos',
      );
      expect(
        today.any(
          (task) =>
              task.contentItemSefariaRef == 'mishnayos-0' &&
              task.priority == DailyTaskPriority.scheduledChazara,
        ),
        isFalse,
      );

      final tomorrow = await generator.generate(
        curriculum,
        date.add(const Duration(days: 1)),
        trackLabel: 'Mishnayos',
      );
      expect(
        tomorrow.any(
          (task) =>
              task.contentItemSefariaRef == 'mishnayos-0' &&
              task.priority == DailyTaskPriority.scheduledChazara,
        ),
        isTrue,
      );
    },
  );

  test(
    'delayDays zero schedules review immediately after completion',
    () async {
      final completions = _Completions()
        ..values.add(
          SchedulerCompletion(
            sefariaRef: 'mishnayos-0',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: date,
          ),
        );
      final tasks = await _generator(
        completions,
        reviewDelay: 0,
      ).generate(curriculum, date, trackLabel: 'Mishnayos');

      expect(
        tasks.any(
          (task) =>
              task.contentItemSefariaRef == 'mishnayos-0' &&
              task.priority == DailyTaskPriority.scheduledChazara,
        ),
        isTrue,
      );
    },
  );
}
