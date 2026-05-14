// Extra coverage for SchedulingStrategy — exercises paths not covered by
// scheduling_strategy_test.dart:
//   - _processDelay: daysUntil == 0 (chazara due exactly today)
//   - SelfPacedSnapshot: coarse mode (_isCoarseMode / _pickCoarseBatch)
//   - SelfPacedSnapshot: priorlyShownRefs overdue carry-over
//   - DeadlineGoal: studyDaysInDeadlineWindow path, past-deadline path
//   - LegacyAdaptive: non-study-day (no new tasks), maxOverdue cap
//   - ProgramCalendar: empty-stages guard
// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/scheduler_input.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduling_strategy.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduling_strategy_runner.dart';

// ───── Helpers ───────────────────────────────────────────────────────────────

const _curriculum = CurriculumId.mishnayos;
final _today = DateTime.utc(2026, 5, 13);

List<SchedulerContentItem> _items(int count) => List.generate(
  count,
  (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
);

List<SchedulerStage> _twoStages({int delay2 = 1}) => [
  const SchedulerStage(id: 1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
  SchedulerStage(
    id: 2,
    stageOrder: 2,
    stageName: 'Chazara 1',
    delayDays: delay2,
  ),
];

SchedulerInput _baseInput({
  List<SchedulerContentItem>? contentItems,
  List<SchedulerCompletion>? completions,
  List<SchedulerStage>? stages,
  double? pacePerDay,
  DateTime? trackStartedAt,
  DateTime? goalDeadline,
  bool isStudyDay = true,
  Set<String> priorlyShownRefs = const {},
  String? paceGranularity,
  int defaultNewItemsPerDay = 5,
  int studyDaysPerWeek = 7,
  int? studyDaysInDeadlineWindow,
}) {
  return SchedulerInput(
    curriculumId: _curriculum,
    trackId: 1,
    trackLabel: 'personal',
    today: _today,
    contentItems: contentItems ?? _items(10),
    completions: completions ?? const [],
    stages: stages ?? _twoStages(),
    pacePerDay: pacePerDay,
    trackStartedAt: trackStartedAt,
    goalDeadline: goalDeadline,
    isStudyDay: isStudyDay,
    priorlyShownRefs: priorlyShownRefs,
    paceGranularity: paceGranularity,
    defaultNewItemsPerDay: defaultNewItemsPerDay,
    studyDaysPerWeek: studyDaysPerWeek,
    studyDaysInDeadlineWindow: studyDaysInDeadlineWindow,
  );
}

SchedulerCompletion _comp(String ref, int stageOrder, {int daysAgo = 0}) =>
    SchedulerCompletion(
      sefariaRef: ref,
      stageOrder: stageOrder,
      trackType: 'personal',
      completedAt: _today.subtract(Duration(days: daysAgo)),
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // =========================================================================
  // _processDelay: daysUntil == 0 (chazara due exactly today, not overdue)
  // =========================================================================

  group('_processDelay — chazara due exactly today (daysUntil == 0)', () {
    test('schedules chazara as scheduledChazara on exact due day', () {
      // Stage 2 delay = 1. Complete Learn 1 day ago → due today.
      final input = _baseInput(
        contentItems: _items(3),
        completions: [_comp('ref_0', 1, daysAgo: 1)],
        stages: _twoStages(delay2: 1),
      );

      final assembly = SchedulingStrategyRunner.run(input);

      expect(
        assembly.tasks.any(
          (t) =>
              t.contentItemSefariaRef == 'ref_0' &&
              t.stageOrder == 2 &&
              t.priority == DailyTaskPriority.scheduledChazara &&
              !t.isOverdue,
        ),
        isTrue,
        reason: 'Chazara due exactly today should be scheduledChazara',
      );
    });
  });

  // =========================================================================
  // SelfPacedSnapshot: priorlyShownRefs overdue carry-over
  // =========================================================================

  group('SelfPacedSnapshot — priorlyShownRefs overdue carry-over', () {
    test(
      'items in priorlyShownRefs that are not completed appear as overdueChazara',
      () {
        // Self-paced requires pacePerDay + trackStartedAt.
        final input = _baseInput(
          contentItems: _items(5),
          completions: const [], // ref_0 not completed
          stages: [
            const SchedulerStage(
              id: 1,
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
            ),
          ],
          pacePerDay: 2.0,
          trackStartedAt: _today.subtract(const Duration(days: 7)),
          priorlyShownRefs: {'ref_0', 'ref_1'}, // shown before but not done
        );

        final assembly = SchedulingStrategyRunner.run(input);

        // ref_0 and ref_1 were shown before but not completed → overdueChazara
        final overdue = assembly.tasks
            .where((t) => t.priority == DailyTaskPriority.overdueChazara)
            .toList();
        expect(overdue, isNotEmpty);
        expect(
          overdue.any((t) => t.contentItemSefariaRef == 'ref_0'),
          isTrue,
        );
        expect(
          overdue.any((t) => t.contentItemSefariaRef == 'ref_1'),
          isTrue,
        );
      },
    );

    test(
      'completed priorlyShownRefs items do NOT appear as overdueChazara',
      () {
        final input = _baseInput(
          contentItems: _items(5),
          completions: [_comp('ref_0', 1)], // ref_0 completed at stage 1
          stages: [
            const SchedulerStage(
              id: 1,
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
            ),
          ],
          pacePerDay: 2.0,
          trackStartedAt: _today.subtract(const Duration(days: 7)),
          priorlyShownRefs: {'ref_0'},
        );

        final assembly = SchedulingStrategyRunner.run(input);

        // ref_0 is completed so it should not be overdueChazara
        expect(
          assembly.tasks.any(
            (t) =>
                t.contentItemSefariaRef == 'ref_0' &&
                t.priority == DailyTaskPriority.overdueChazara,
          ),
          isFalse,
        );
      },
    );
  });

  // =========================================================================
  // SelfPacedSnapshot: coarse mode (_isCoarseMode / _pickCoarseBatch)
  // =========================================================================

  group('SelfPacedSnapshot — coarse mode', () {
    test(
      'coarse paceGranularity=perek schedules items from the coarse unit',
      () {
        // Items with coarseUnitKey grouping. We create content items where
        // the first part of the sefariaRef groups them by perek.
        // Since SchedulerContentItem.coarseUnitKey defaults to sefariaRef,
        // we can't easily test multi-leaf coarse grouping without a custom
        // subclass. The test verifies that the coarse path does not throw
        // and returns newLearning tasks.
        final items = List.generate(
          6,
          (i) => SchedulerContentItem(
            sefariaRef: 'Berakhot 1:${i + 1}',
            sortOrder: i,
          ),
        );

        final input = _baseInput(
          contentItems: items,
          completions: const [],
          stages: [
            const SchedulerStage(
              id: 1,
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
            ),
          ],
          pacePerDay: 2.0,
          paceGranularity: 'perek', // coarse — differs from leaf ('mishna')
          trackStartedAt: _today.subtract(const Duration(days: 1)),
        );

        // The runner selects SelfPacedSnapshot because pacePerDay+trackStartedAt
        // are both set.
        final assembly = SchedulingStrategyRunner.run(input);

        // Coarse mode picks whole units. With each leaf as its own coarseUnitKey
        // this degenerates to picking 2 individual leaves (pacePerDay=2).
        expect(
          assembly.tasks.where(
            (t) => t.priority == DailyTaskPriority.newLearning,
          ),
          isNotEmpty,
        );
      },
    );
  });

  // =========================================================================
  // DeadlineGoal: studyDaysInDeadlineWindow and past-deadline paths
  // =========================================================================

  group('DeadlineGoal — studyDaysInDeadlineWindow', () {
    test('uses exact studyDaysInDeadlineWindow for pacing', () {
      final deadline = _today.add(const Duration(days: 30));
      final input = _baseInput(
        contentItems: _items(30),
        stages: [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
        ],
        goalDeadline: deadline,
        studyDaysInDeadlineWindow: 15, // exact count provided
        studyDaysPerWeek: 5,
      );

      final assembly = SchedulingStrategyRunner.run(input);
      // 30 items / 15 study days = 2 items per day
      expect(
        assembly.tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .length,
        2,
      );
    });

    test('past deadline uses 10% emergency rate', () {
      // Deadline in the past → daysRemaining ≤ 0 → 10% of remaining.
      final deadline = _today.subtract(const Duration(days: 1));
      final input = _baseInput(
        contentItems: _items(10),
        stages: [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
        ],
        goalDeadline: deadline,
      );

      final assembly = SchedulingStrategyRunner.run(input);
      // 10 items * 0.1 = 1.0 → ceil = 1
      expect(
        assembly.tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .length,
        1,
      );
    });
  });

  // =========================================================================
  // LegacyAdaptive: non-study day and chazara load balancing
  // =========================================================================

  group('LegacyAdaptive — non-study day', () {
    test('does NOT emit newLearning tasks on a non-study day', () {
      final input = _baseInput(
        contentItems: _items(5),
        isStudyDay: false,
        // No pacePerDay/trackStartedAt → LegacyAdaptive
      );

      final assembly = SchedulingStrategyRunner.run(input);

      expect(
        assembly.tasks.where((t) => t.priority == DailyTaskPriority.newLearning),
        isEmpty,
      );
    });
  });

  group('LegacyAdaptive — maxOverdue cap', () {
    test('caps overdue tasks at 20 when more than 20 are overdue', () {
      // Insert 25 completions at stage 1, each overdue for stage 2.
      final items = List.generate(
        25,
        (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
      );
      final completions = List.generate(
        25,
        (i) => _comp('ref_$i', 1, daysAgo: 10), // 10 days ago, delay=1 → overdue
      );

      final input = _baseInput(
        contentItems: items,
        completions: completions,
        stages: _twoStages(delay2: 1),
      );

      final assembly = SchedulingStrategyRunner.run(input);

      final overdue = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.overdueChazara)
          .toList();
      expect(overdue.length, lessThanOrEqualTo(20));
    });
  });

  // =========================================================================
  // ProgramCalendar — empty stages guard
  // =========================================================================

  group('ProgramCalendar — empty stages', () {
    test('returns empty TaskAssembly when stages list is empty', () {
      const strategy = ProgramCalendar(programRefs: ['ref_0', 'ref_1']);
      final input = _baseInput(
        stages: [], // no stages
        contentItems: _items(3),
      );

      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      expect(assembly.tasks, isEmpty);
      expect(assembly.strategyName, 'ProgramCalendar');
    });
  });
}
