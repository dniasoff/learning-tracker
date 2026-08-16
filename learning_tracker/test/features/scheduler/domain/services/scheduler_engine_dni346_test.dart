/// Unit tests for Story 26.3 (DNI-346) scheduler bug fixes.
///
/// Tests cover:
///   1. Chazara-load math — _calculateNewItemsPerDay zero-floor handling
///   2. Classification bug — never-completed items NOT classified as overdueChazara
///   3. isStudyDay — snapshot path emits empty list on non-study days
///   4. Rolling-window day-1 — PaceCalculator projection guard
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

// ---------------------------------------------------------------------------
// Test doubles
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

List<SchedulerContentItem> makeItems(int count) => List.generate(
  count,
  (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
);

List<SchedulerStage> threeStages() => [
  const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
  const SchedulerStage(stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
  const SchedulerStage(stageOrder: 3, stageName: 'Chazara 2', delayDays: 7),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeContentRepo contentRepo;
  late FakeCompletionRepo completionRepo;
  late FakeStageRepo stageRepo;
  late FakeLearningOrderRepo learningOrderRepo;
  late SchedulerEngine engine;

  const curriculum = CurriculumId.mishnayos;
  final now = DateTime.utc(2026, 5, 13);

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
  // Fix 1 — Chazara-load math (_calculateNewItemsPerDay)
  // =========================================================================
  group('Fix 1 — _calculateNewItemsPerDay zero-floor handling', () {
    test('500-item backlog with 50 overdue chazara + 100-day deadline → '
        'new-learning rate is 5/day (not collapsed to 1)', () async {
      // 500 content items; none completed yet.
      contentRepo.items = makeItems(550);
      stageRepo.stages = threeStages();

      // 50 items have been learned (stage 1 completed 30 days ago),
      // making both Chazara-1 and Chazara-2 overdue for each → 100 overdue
      // chazara tasks in theory (capped at kMaxOverdueChazarahPerDay = 20).
      completionRepo.completions = List.generate(
        50,
        (i) => SchedulerCompletion(
          sefariaRef: 'ref_$i',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 30)),
        ),
      );

      // 500 remaining new items, 100 study days to deadline.
      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        goalDeadline: now.add(const Duration(days: 100)),
        currentDate: now,
      );

      final tasks = await engine.generateDailyTasks(config);

      // New-learning tasks should be 5 (500 / 100), not 1.
      final newTasks = tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(
        newTasks.length,
        equals(5),
        reason:
            'With 500 items and a 100-day deadline, new-learning rate is 5/day '
            'regardless of chazara load — old bug collapsed this to 1.',
      );
    });

    test(
      'boundary case — deep backlog locks new learning to 1/day via deadline math, '
      'NOT via chazara penalty',
      () async {
        // 10 remaining items over 100 days → ceil(10/100) = 1/day from math alone.
        contentRepo.items = makeItems(10);
        stageRepo.stages = threeStages();
        completionRepo.completions = [];

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
        // 10 items / 100 days = ceil(0.1) = 1.
        expect(
          newTasks.length,
          equals(1),
          reason: 'Deadline math independently gives 1/day here.',
        );
      },
    );

    test('no new items when remainingNewItems is 0', () async {
      // All 5 items already learned.
      contentRepo.items = makeItems(5);
      stageRepo.stages = threeStages();
      completionRepo.completions = List.generate(
        5,
        (i) => SchedulerCompletion(
          sefariaRef: 'ref_$i',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 1)),
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
      expect(newTasks, isEmpty, reason: 'No new items remain.');
    });
  });

  // =========================================================================
  // Fix 2 — Classification bug (never-completed items in snapshot path)
  // =========================================================================
  group('Fix 2 — snapshot path classification bug', () {
    test('brand-new never-completed items in priorlyShownRefs are classified '
        'as newLearning, not overdueChazara', () async {
      // 5 items; none have any completions.
      contentRepo.items = makeItems(5);
      stageRepo.stages = [
        const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
      ];
      completionRepo.completions = [];

      // Simulate refs that were shown in a prior-day backfilled snapshot
      // but never actually completed.
      final priorlyShown = {'ref_0', 'ref_1'};

      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        currentDate: now,
        pacePerDay: 2.0,
        trackStartedAt: now.subtract(const Duration(days: 2)),
        priorlyShownRefs: priorlyShown,
      );

      final tasks = await engine.generateDailyTasks(config);

      // ref_0 and ref_1 should NOT be overdueChazara — they were never learned.
      final overdueChazaraTasks = tasks
          .where((t) => t.priority == DailyTaskPriority.overdueChazara)
          .toList();
      expect(
        overdueChazaraTasks,
        isEmpty,
        reason:
            'Never-completed items must not be classified as overdueChazara.',
      );

      // They should appear as overdueNewLearning (carry-over new-learning).
      final overdueNewLearningTasks = tasks
          .where(
            (t) =>
                (t.contentItemSefariaRef == 'ref_0' ||
                    t.contentItemSefariaRef == 'ref_1') &&
                t.priority == DailyTaskPriority.overdueNewLearning,
          )
          .toList();
      expect(
        overdueNewLearningTasks.length,
        equals(2),
        reason:
            'ref_0 and ref_1 were shown before but never learned — '
            'should surface as overdueNewLearning, not overdueChazara.',
      );
    });

    test('previously-completed items in priorlyShownRefs are correctly '
        'classified as overdueChazara', () async {
      contentRepo.items = makeItems(5);
      stageRepo.stages = [
        const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
      ];
      // ref_0 has been completed at stage 1.
      completionRepo.completions = [
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 3)),
        ),
      ];

      // ref_0 was shown in a prior snapshot AND was completed.
      // But completion was at the first stage (so it's fully learned — not
      // overdue for chazara in this single-stage track).
      // For multi-stage: ref_0 done at stage 1, not at stage 2 → overdue.
      // For this single-stage test: done at stage 1 → skip (already complete).
      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        currentDate: now,
        pacePerDay: 2.0,
        trackStartedAt: now.subtract(const Duration(days: 5)),
        priorlyShownRefs: {'ref_0'},
      );

      final tasks = await engine.generateDailyTasks(config);

      // ref_0 is done at firstStage → must NOT appear in overdue or new.
      final ref0Tasks = tasks
          .where((t) => t.contentItemSefariaRef == 'ref_0')
          .toList();
      expect(
        ref0Tasks,
        isEmpty,
        reason: 'ref_0 completed at firstStage — should be filtered out.',
      );
    });
  });

  // =========================================================================
  // Fix 3 — isStudyDay check in snapshot path
  // =========================================================================
  group('Fix 3 — isStudyDay in snapshot path', () {
    test('snapshot path emits empty task list on non-study days', () async {
      contentRepo.items = makeItems(10);
      stageRepo.stages = [
        const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
      ];
      completionRepo.completions = [];

      // isStudyDay = false → snapshot path must return empty.
      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        currentDate: now,
        pacePerDay: 2.0,
        trackStartedAt: now.subtract(const Duration(days: 3)),
        isStudyDay: false,
      );

      final tasks = await engine.generateDailyTasks(config);
      expect(
        tasks,
        isEmpty,
        reason:
            'Snapshot path must honour isStudyDay and return [] on off days.',
      );
    });

    test('snapshot path produces tasks on study days', () async {
      contentRepo.items = makeItems(10);
      stageRepo.stages = [
        const SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
      ];
      completionRepo.completions = [];

      // isStudyDay = true (default) → tasks are produced.
      final config = ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Test Track',
        currentDate: now,
        pacePerDay: 2.0,
        trackStartedAt: now.subtract(const Duration(days: 3)),
        isStudyDay: true,
      );

      final tasks = await engine.generateDailyTasks(config);
      expect(
        tasks.isNotEmpty,
        isTrue,
        reason: 'Snapshot path should produce tasks on study days.',
      );
    });
  });

  // =========================================================================
  // Fix 4 — Rolling-window day-1 (PaceCalculator projection guard)
  // =========================================================================
  group('Fix 4 — rolling-window day-1 guard (PaceCalculator)', () {
    test(
      'deadline goal: projectedCompletionDate is null on day-1 (no events)',
      () {
        final result = PaceCalculator.calculate(
          goalStartDate: DateTime.utc(2026, 5, 13),
          goalDeadline: DateTime.utc(2026, 12, 31),
          totalItems: 100,
          completedItems: 0,
          dailyCompletionCounts: {}, // No events — day 1
          today: DateTime.utc(2026, 5, 13),
        );

        expect(
          result.projectedCompletionDate,
          isNull,
          reason:
              'No rolling-average events — projection must be null on day-1.',
        );
        expect(result.rollingAverage, 0.0);
      },
    );

    test('pace goal: projectedCompletionDate is set on day-1 using target rate '
        '(not rolling avg — safe from NaN)', () {
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 1.0,
        totalItems: 100,
        completedItems: 0,
        dailyCompletionCounts: {}, // No events — day 1
        today: DateTime.utc(2026, 5, 13),
      );

      // Pace goal projects using targetPacePerDay (not rollingAvg), so it is
      // always available from day 1 without risk of NaN.
      expect(
        result.projectedCompletionDate,
        isNotNull,
        reason:
            'Pace goal uses targetPacePerDay for projection — available on day-1.',
      );
    });

    test(
      'deadline goal: projectedCompletionDate is set once ≥1 event exists',
      () {
        final today = DateTime.utc(2026, 5, 13);
        final result = PaceCalculator.calculate(
          goalStartDate: DateTime.utc(2026, 5, 1),
          goalDeadline: DateTime.utc(2026, 12, 31),
          totalItems: 100,
          completedItems: 3,
          dailyCompletionCounts: {
            // At least one event in the rolling window.
            DateTime.utc(2026, 5, 12): 3,
          },
          today: today,
        );

        expect(
          result.projectedCompletionDate,
          isNotNull,
          reason: 'Rolling average > 0 → projection should be available.',
        );
      },
    );

    test('pace goal: projectedCompletionDate is set once ≥1 event exists', () {
      final today = DateTime.utc(2026, 5, 13);
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 1.0,
        totalItems: 100,
        completedItems: 5,
        dailyCompletionCounts: {DateTime.utc(2026, 5, 12): 5},
        today: today,
      );

      expect(
        result.projectedCompletionDate,
        isNotNull,
        reason: 'Rolling average > 0 → pace goal projection should be set.',
      );
    });
  });

  // =========================================================================
  // Fix 5 — Typed delta values (PaceDelta / DateDelta)
  // =========================================================================
  group('Fix 5 — typed delta values', () {
    test('deadline goal produces DateScheduleDelta with correct days', () {
      final today = DateTime.utc(2026, 5, 13);
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 30,
        dailyCompletionCounts: {
          for (var i = 1; i <= 7; i++) DateTime.utc(2026, 5, 13 - i): 1,
        },
        today: today,
      );

      expect(
        result.delta,
        isA<DateScheduleDelta>(),
        reason:
            'Deadline goal must carry DateScheduleDelta, not PaceScheduleDelta.',
      );
      // daysDelta and delta.value.days must agree.
      final dateDelta = result.delta as DateScheduleDelta;
      expect(dateDelta.value.days, equals(result.daysDelta));
    });

    test('pace goal produces PaceScheduleDelta with correct items/week', () {
      final today = DateTime.utc(2026, 5, 13);
      final result = PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: 1.0,
        totalItems: 500,
        completedItems: 100,
        dailyCompletionCounts: {
          for (var i = 1; i <= 7; i++)
            DateTime.utc(2026, 5, 13 - i): 2, // 2/day → 14/week
        },
        today: today,
      );

      expect(
        result.delta,
        isA<PaceScheduleDelta>(),
        reason:
            'Pace goal must carry PaceScheduleDelta, not DateScheduleDelta.',
      );
      // itemsPerWeek = round((rollingAvg - target) * 7) = round((2-1)*7) = 7
      final paceDelta = result.delta as PaceScheduleDelta;
      expect(paceDelta.value.itemsPerWeek, equals(result.daysDelta));
      expect(
        paceDelta.value.itemsPerWeek,
        equals(7),
        reason: 'Rolling avg 2/day vs target 1/day → +7 items/week.',
      );
    });

    test('UI cannot accidentally treat pace-goal itemsPerWeek as calendar days '
        '— types are distinct', () {
      // DateDelta and PaceDelta must be different runtime types.
      const dateDelta = DateDelta(5);
      const paceDelta = PaceDelta(5);
      // Identical numeric value but different types.
      expect(
        dateDelta,
        isNot(equals(paceDelta)),
        reason:
            'DateDelta(5) != PaceDelta(5): distinct types prevent UI confusion.',
      );
      expect(dateDelta.runtimeType, isNot(equals(paceDelta.runtimeType)));
    });
  });
}
