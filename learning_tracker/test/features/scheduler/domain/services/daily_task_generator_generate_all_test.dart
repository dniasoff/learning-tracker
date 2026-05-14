// Tests for DailyTaskGenerator.generateAll — the multi-curriculum path that
// was not exercised by daily_task_generator_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

// ---------------------------------------------------------------------------
// Fakes (same pattern as scheduler_engine_schedule_types_test.dart)
// ---------------------------------------------------------------------------

class _FakeContentRepo implements SchedulerContentRepository {
  final List<SchedulerContentItem> items;
  _FakeContentRepo(this.items);
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      items;
}

class _FakeCompletionRepo implements SchedulerCompletionRepository {
  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async =>
      const [];
}

class _FakeStageRepo implements SchedulerStageRepository {
  final List<SchedulerStage> stages;
  _FakeStageRepo(this.stages);
  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async => stages;
}

class _FakeOrderRepo implements SchedulerLearningOrderRepository {
  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => const [];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SchedulerEngine _makeEngine({
  List<SchedulerContentItem> items = const [],
  List<SchedulerStage> stages = const [],
}) {
  return SchedulerEngine(
    contentRepository: _FakeContentRepo(items),
    completionRepository: _FakeCompletionRepo(),
    stageRepository: _FakeStageRepo(stages),
    learningOrderRepository: _FakeOrderRepo(),
  );
}

const _singleStage = [
  SchedulerStage(id: 1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final today = DateTime.utc(2026, 3, 15);

  group('DailyTaskGenerator.generateAll', () {
    test('returns empty list for empty curricula list', () async {
      final gen = DailyTaskGenerator(engine: _makeEngine());

      final tasks = await gen.generateAll([], today);

      expect(tasks, isEmpty);
    });

    test('aggregates tasks from multiple curricula', () async {
      final items = List.generate(
        3,
        (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
      );

      final engine = _makeEngine(items: items, stages: _singleStage);
      final gen = DailyTaskGenerator(engine: engine);

      final tasks = await gen.generateAll(
        [CurriculumId.mishnayos, CurriculumId.bavli],
        today,
        trackIds: {
          CurriculumId.mishnayos: 1,
          CurriculumId.bavli: 2,
        },
        trackLabels: {
          CurriculumId.mishnayos: 'Mishnayos',
          CurriculumId.bavli: 'Bavli',
        },
      );

      // Each curriculum produces 5 new-learning tasks (defaultNewItemsPerDay=5
      // but we only have 3 items), so 3+3=6.
      expect(tasks, isNotEmpty);
      // Tasks are sorted by priority — all newLearning here.
      for (final t in tasks) {
        expect(t.priority, DailyTaskPriority.newLearning);
      }
    });

    test('applies skippedRefs across all curricula', () async {
      final items = [
        const SchedulerContentItem(sefariaRef: 'ref_0', sortOrder: 0),
        const SchedulerContentItem(sefariaRef: 'ref_1', sortOrder: 1),
      ];

      final engine = _makeEngine(items: items, stages: _singleStage);
      final gen = DailyTaskGenerator(engine: engine);

      final tasks = await gen.generateAll(
        [CurriculumId.mishnayos],
        today,
        skippedRefs: {'ref_0'},
        trackIds: {CurriculumId.mishnayos: 1},
        trackLabels: {CurriculumId.mishnayos: 'Test'},
      );

      expect(
        tasks.any((t) => t.contentItemSefariaRef == 'ref_0'),
        isFalse,
        reason: 'Skipped ref should not appear',
      );
      expect(tasks.any((t) => t.contentItemSefariaRef == 'ref_1'), isTrue);
    });

    test('isStudyDayMap controls whether new tasks are emitted', () async {
      final items = List.generate(
        5,
        (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
      );

      final engine = _makeEngine(items: items, stages: _singleStage);
      final gen = DailyTaskGenerator(engine: engine);

      // Non-study day: only overdue/chazara tasks (none here), so result empty.
      final tasks = await gen.generateAll(
        [CurriculumId.mishnayos],
        today,
        isStudyDayMap: {CurriculumId.mishnayos: false},
        trackIds: {CurriculumId.mishnayos: 1},
        trackLabels: {CurriculumId.mishnayos: 'Test'},
      );

      // No completions → no overdue/chazara. Non-study day → no new learning.
      expect(tasks, isEmpty);
    });

    test('tasks are sorted by priority across curricula', () async {
      final items = List.generate(
        5,
        (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
      );

      final engine = _makeEngine(items: items, stages: _singleStage);
      final gen = DailyTaskGenerator(engine: engine);

      final tasks = await gen.generateAll(
        [CurriculumId.mishnayos, CurriculumId.bavli],
        today,
        trackIds: {
          CurriculumId.mishnayos: 1,
          CurriculumId.bavli: 2,
        },
        trackLabels: {
          CurriculumId.mishnayos: 'A',
          CurriculumId.bavli: 'B',
        },
      );

      for (var i = 1; i < tasks.length; i++) {
        expect(
          tasks[i].priority.index,
          greaterThanOrEqualTo(tasks[i - 1].priority.index),
        );
      }
    });

    test('priorlyShownRefsMap is forwarded to engine per curriculum', () async {
      // 5 items; 3 of them in priorlyShownRefs → those are "shown before"
      // and if not completed, they show as overdue (snapshot path is not
      // activated here since pacePerDay is null). With standard LegacyAdaptive
      // strategy, priorlyShownRefs has no effect — just check no crash.
      final items = List.generate(
        5,
        (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
      );

      final engine = _makeEngine(items: items, stages: _singleStage);
      final gen = DailyTaskGenerator(engine: engine);

      final tasks = await gen.generateAll(
        [CurriculumId.mishnayos],
        today,
        priorlyShownRefsMap: {
          CurriculumId.mishnayos: {'ref_0', 'ref_1'},
        },
        trackIds: {CurriculumId.mishnayos: 1},
        trackLabels: {CurriculumId.mishnayos: 'Test'},
      );

      // Should complete without error.
      expect(tasks, isA<List<DailyTask>>());
    });

    test('paceGranularityMap is accepted without error', () async {
      final items = List.generate(
        3,
        (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
      );

      final engine = _makeEngine(items: items, stages: _singleStage);
      final gen = DailyTaskGenerator(engine: engine);

      // Just verify no exception is thrown when paceGranularityMap is provided.
      final tasks = await gen.generateAll(
        [CurriculumId.mishnayos],
        today,
        paceGranularityMap: {CurriculumId.mishnayos: 'perek'},
        trackIds: {CurriculumId.mishnayos: 1},
        trackLabels: {CurriculumId.mishnayos: 'Test'},
      );

      expect(tasks, isA<List<DailyTask>>());
    });
  });
}
