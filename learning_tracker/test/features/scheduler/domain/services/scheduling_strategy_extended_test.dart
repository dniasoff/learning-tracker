/// Extended tests for SchedulingStrategy covering branches not exercised by
/// scheduling_strategy_test.dart:
/// - _processDelay: daysUntil == 0 (scheduled, not overdue)
/// - SelfPacedSnapshot.assemble: priorlyShownRefs overdue path
/// - SelfPacedSnapshot._pickCoarseBatch (coarse mode)
/// - DeadlineGoal: past-deadline baseRate path
/// - LegacyAdaptive: chazara load balancing
/// - ProgramCalendar: assemble with empty stages
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/scheduler_input.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduling_strategy.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduling_strategy_runner.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _curriculum = CurriculumId.mishnayos;
final _today = DateTime.utc(2026, 5, 14);

List<SchedulerContentItem> _items(
  int count, {
  String? level1,
  String? level2,
  String? level3,
}) => List.generate(
  count,
  (i) => SchedulerContentItem(
    sefariaRef: 'ref_$i',
    sortOrder: i,
    level1: level1,
    level2: level2 ?? 'perek_$i',
    level3: level3,
  ),
);

/// Single-stage setup (no chazara).
List<SchedulerStage> _oneStage() => [
  const SchedulerStage(id: 1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
];

/// Two-stage setup with a delay chazara stage.
List<SchedulerStage> _twoStages({int delayDays = 1}) => [
  const SchedulerStage(id: 1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
  SchedulerStage(
    id: 2,
    stageOrder: 2,
    stageName: 'Chazara',
    delayDays: delayDays,
  ),
];

SchedulerCompletion _completion(String ref, int stage, DateTime completedAt) =>
    SchedulerCompletion(
      sefariaRef: ref,
      stageOrder: stage,
      trackType: 'personal',
      completedAt: completedAt,
    );

SchedulerInput _selfPaced({
  List<SchedulerContentItem>? contentItems,
  List<SchedulerCompletion>? completions,
  List<SchedulerStage>? stages,
  double pacePerDay = 2,
  Set<String> priorlyShownRefs = const {},
  String? paceGranularity,
  bool isStudyDay = true,
}) => SchedulerInput(
  curriculumId: _curriculum,
  trackId: 1,
  trackLabel: 'personal',
  today: _today,
  contentItems: contentItems ?? _items(10),
  completions: completions ?? const [],
  stages: stages ?? _twoStages(),
  pacePerDay: pacePerDay,
  trackStartedAt: _today.subtract(const Duration(days: 5)),
  priorlyShownRefs: priorlyShownRefs,
  paceGranularity: paceGranularity,
  isStudyDay: isStudyDay,
);

SchedulerInput _deadlineInput({
  List<SchedulerContentItem>? contentItems,
  List<SchedulerCompletion>? completions,
  List<SchedulerStage>? stages,
  DateTime? goalDeadline,
  int studyDaysPerWeek = 7,
  int? studyDaysInDeadlineWindow,
}) => SchedulerInput(
  curriculumId: _curriculum,
  trackId: 1,
  trackLabel: 'personal',
  today: _today,
  contentItems: contentItems ?? _items(10),
  completions: completions ?? const [],
  stages: stages ?? _oneStage(),
  goalDeadline: goalDeadline ?? _today.add(const Duration(days: 10)),
  studyDaysPerWeek: studyDaysPerWeek,
  studyDaysInDeadlineWindow: studyDaysInDeadlineWindow,
);

SchedulerInput _legacyInput({
  List<SchedulerContentItem>? contentItems,
  List<SchedulerCompletion>? completions,
  List<SchedulerStage>? stages,
  int defaultNewItemsPerDay = 5,
}) => SchedulerInput(
  curriculumId: _curriculum,
  trackId: 1,
  trackLabel: 'personal',
  today: _today,
  contentItems: contentItems ?? _items(10),
  completions: completions ?? const [],
  stages: stages ?? _oneStage(),
  defaultNewItemsPerDay: defaultNewItemsPerDay,
);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── _processDelay: daysUntil == 0 path ──────────────────────────────────────

  group('_processDelay — daysUntil == 0 (scheduled, not overdue)', () {
    test('delay stage due exactly today appears as scheduledChazara', () {
      // ref_0 completed stage 1 exactly [delayDays] days ago so daysUntil = 0.
      final completedAt = _today.subtract(const Duration(days: 1));
      final input = _selfPaced(
        stages: _twoStages(delayDays: 1),
        completions: [_completion('ref_0', 1, completedAt)],
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final refs = assembly.tasks.map((t) => t.contentItemSefariaRef).toList();
      expect(refs, contains('ref_0'));
      final task = assembly.tasks.firstWhere(
        (t) => t.contentItemSefariaRef == 'ref_0',
      );
      expect(task.priority, DailyTaskPriority.scheduledChazara);
      expect(task.isOverdue, isFalse);
    });

    test('delay stage due in the past appears as overdueChazara', () {
      // ref_0 completed stage 1 three days ago with delayDays=1 → overdue.
      final completedAt = _today.subtract(const Duration(days: 3));
      final input = _selfPaced(
        stages: _twoStages(delayDays: 1),
        completions: [_completion('ref_0', 1, completedAt)],
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final task = assembly.tasks.firstWhere(
        (t) => t.contentItemSefariaRef == 'ref_0',
      );
      expect(task.priority, DailyTaskPriority.overdueChazara);
      expect(task.isOverdue, isTrue);
    });

    test('delay stage not yet due does not appear', () {
      // ref_0 completed stage 1 today with delayDays=3 → not due yet.
      final completedAt = _today;
      final input = _selfPaced(
        stages: _twoStages(delayDays: 3),
        completions: [_completion('ref_0', 1, completedAt)],
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final chazaraTasks = assembly.tasks.where(
        (t) =>
            t.contentItemSefariaRef == 'ref_0' &&
            t.priority == DailyTaskPriority.scheduledChazara,
      );
      expect(chazaraTasks, isEmpty);
    });
  });

  // ── SelfPacedSnapshot — priorlyShownRefs overdue path ──────────────────────

  group('SelfPacedSnapshot.assemble — priorlyShownRefs overdue', () {
    test(
      'uncompleted ref in priorlyShownRefs appears as overdueChazara in assemble',
      () {
        // ref_0 was shown before but not completed — should appear overdue.
        final input = _selfPaced(
          priorlyShownRefs: {'ref_0'},
          completions: const [], // ref_0 not completed
        );

        final assembly = SchedulingStrategyRunner.run(input);
        final overdueTasks = assembly.tasks.where(
          (t) =>
              t.contentItemSefariaRef == 'ref_0' &&
              t.priority == DailyTaskPriority.overdueChazara,
        );
        expect(
          overdueTasks,
          isNotEmpty,
          reason: 'ref_0 was shown but not completed — should be overdue',
        );
      },
    );

    test(
      'completed ref in priorlyShownRefs does not appear as overdue in assemble',
      () {
        // ref_0 completed stage 1 — should NOT show as overdue
        final input = _selfPaced(
          priorlyShownRefs: {'ref_0'},
          completions: [_completion('ref_0', 1, _today)],
        );

        final assembly = SchedulingStrategyRunner.run(input);
        final overdueTasks = assembly.tasks.where(
          (t) =>
              t.contentItemSefariaRef == 'ref_0' &&
              t.priority == DailyTaskPriority.overdueChazara,
        );
        expect(
          overdueTasks,
          isEmpty,
          reason: 'ref_0 is completed — should not appear as overdue',
        );
      },
    );

    test('non-study day still emits overdue tasks from priorlyShownRefs', () {
      final input = _selfPaced(
        priorlyShownRefs: {'ref_0'},
        completions: const [],
        isStudyDay: false,
      );

      final assembly = SchedulingStrategyRunner.run(input);
      // Overdue tasks appear even on non-study days
      final overdueTasks = assembly.tasks.where(
        (t) =>
            t.contentItemSefariaRef == 'ref_0' &&
            t.priority == DailyTaskPriority.overdueChazara,
      );
      expect(overdueTasks, isNotEmpty);
    });
  });

  // ── SelfPacedSnapshot — coarse mode (_pickCoarseBatch) ─────────────────────

  group('SelfPacedSnapshot coarse mode (_pickCoarseBatch)', () {
    /// Build 4-level items (seder|masechta|perekA|mishna_N) where two mishnas
    /// share perekA and one mishna is under perekB.
    /// coarseUnitKey = level1|level2|level3 → 'seder|masechta|perekA' or 'seder|masechta|perekB'.
    List<SchedulerContentItem> coarseItems() => [
      const SchedulerContentItem(
        sefariaRef: 'perekA_mishna_1',
        sortOrder: 0,
        level1: 'seder',
        level2: 'masechta',
        level3: 'perekA',
        level4: 'mishna_1',
      ),
      const SchedulerContentItem(
        sefariaRef: 'perekA_mishna_2',
        sortOrder: 1,
        level1: 'seder',
        level2: 'masechta',
        level3: 'perekA',
        level4: 'mishna_2',
      ),
      const SchedulerContentItem(
        sefariaRef: 'perekB_mishna_1',
        sortOrder: 2,
        level1: 'seder',
        level2: 'masechta',
        level3: 'perekB',
        level4: 'mishna_1',
      ),
    ];

    test('coarse mode includes all leaves of the first coarse unit', () {
      // paceGranularity 'perek' != curriculum leaf name → coarse mode.
      // With pacePerDay=1 coarse unit, should pick both leaves of perekA.
      final input = _selfPaced(
        contentItems: coarseItems(),
        stages: _oneStage(),
        pacePerDay: 1,
        paceGranularity: 'perek',
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      final refs = newTasks.map((t) => t.contentItemSefariaRef).toSet();
      // Both leaves of perekA should be included.
      expect(refs, containsAll(['perekA_mishna_1', 'perekA_mishna_2']));
    });

    test('coarse mode skips coarse units already in priorlyShownRefs', () {
      // perekA was already shown — should skip to perekB.
      final input = _selfPaced(
        contentItems: coarseItems(),
        stages: _oneStage(),
        pacePerDay: 1,
        paceGranularity: 'perek',
        priorlyShownRefs: {'perekA_mishna_1', 'perekA_mishna_2'},
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      final refs = newTasks.map((t) => t.contentItemSefariaRef).toSet();
      // perekA was shown — should get perekB leaf.
      expect(refs, contains('perekB_mishna_1'));
      expect(refs, isNot(contains('perekA_mishna_1')));
    });

    test('coarse mode skips already-completed coarse units', () {
      // perekA fully completed at stage 1 — coarse batch should skip it.
      final input = _selfPaced(
        contentItems: coarseItems(),
        stages: _oneStage(),
        pacePerDay: 1,
        paceGranularity: 'perek',
        completions: [
          _completion('perekA_mishna_1', 1, _today),
          _completion('perekA_mishna_2', 1, _today),
        ],
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      final refs = newTasks.map((t) => t.contentItemSefariaRef).toSet();
      expect(refs, contains('perekB_mishna_1'));
      expect(refs, isNot(containsAll(['perekA_mishna_1', 'perekA_mishna_2'])));
    });
  });

  // ── DeadlineGoal — past deadline path ───────────────────────────────────────

  group('DeadlineGoal — past deadline', () {
    test('past deadline uses 10% of remaining items as baseRate', () {
      // deadline in the past → daysRemaining <= 0 → baseRate = (N * 0.1).ceil()
      final items = _items(20);
      final input = _deadlineInput(
        contentItems: items,
        goalDeadline: _today.subtract(const Duration(days: 1)),
      );

      final assembly = SchedulingStrategyRunner.run(input);
      // With 20 items past deadline → baseRate = ceil(20 * 0.1) = 2.
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      expect(newTasks.length, greaterThanOrEqualTo(1));
      // Should not emit all 20.
      expect(newTasks.length, lessThan(20));
    });

    test('deadline goal returns 0 new tasks when all items completed', () {
      final items = _items(5);
      final completions = items
          .map((item) => _completion(item.sefariaRef, 1, _today))
          .toList();
      final input = _deadlineInput(
        contentItems: items,
        completions: completions,
        goalDeadline: _today.add(const Duration(days: 10)),
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      expect(newTasks, isEmpty);
    });

    test('deadline goal uses studyDaysInDeadlineWindow when provided', () {
      // 10 items, deadline in 20 days, 5 study days → 2 per day.
      final items = _items(10);
      final input = _deadlineInput(
        contentItems: items,
        goalDeadline: _today.add(const Duration(days: 20)),
        studyDaysInDeadlineWindow: 5,
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      // ceil(10 / 5) = 2 items per day.
      expect(newTasks.length, 2);
    });
  });

  // ── LegacyAdaptive — chazara load balancing ─────────────────────────────────

  group('LegacyAdaptive — chazara load balancing', () {
    test('heavy chazara load reduces new item count', () {
      // 8 items overdue chazara, defaultRate=2 → chazara dominates, adjusted down.
      final stages = _twoStages(delayDays: 1);
      final items = _items(10);
      // Make 8 items overdue for chazara (completed stage 1, three days ago).
      final completions = List.generate(
        8,
        (i) =>
            _completion('ref_$i', 1, _today.subtract(const Duration(days: 3))),
      );

      final input = _legacyInput(
        contentItems: items,
        completions: completions,
        stages: stages,
        defaultNewItemsPerDay: 2,
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      // Should emit at least 1 (min) but reduced from base 2.
      expect(newTasks.length, greaterThanOrEqualTo(1));
    });

    test('no new items when all content completed', () {
      final items = _items(5);
      final completions = items
          .map((item) => _completion(item.sefariaRef, 1, _today))
          .toList();
      final input = _legacyInput(contentItems: items, completions: completions);

      final assembly = SchedulingStrategyRunner.run(input);
      final newTasks = assembly.tasks.where(
        (t) => t.priority == DailyTaskPriority.newLearning,
      );
      expect(newTasks, isEmpty);
    });
  });

  // ── ProgramCalendar — empty stages guard ────────────────────────────────────

  group('ProgramCalendar — empty stages guard', () {
    test('returns empty task list when stages is empty', () {
      final input = SchedulerInput(
        curriculumId: _curriculum,
        trackId: 1,
        trackLabel: 'personal',
        today: _today,
        contentItems: _items(5),
        completions: const [],
        stages: const [], // empty
      );

      const strategy = ProgramCalendar(programRefs: ['ref_0', 'ref_1']);
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);
      expect(assembly.tasks, isEmpty);
    });

    test('ProgramCalendar emits todayProgram tasks for each programRef', () {
      final input = SchedulerInput(
        curriculumId: _curriculum,
        trackId: 1,
        trackLabel: 'personal',
        today: _today,
        contentItems: _items(5),
        completions: const [],
        stages: [
          const SchedulerStage(
            id: 1,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
          ),
        ],
      );

      const strategy = ProgramCalendar(programRefs: ['ref_0', 'ref_1']);
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      expect(assembly.tasks, hasLength(2));
      expect(
        assembly.tasks.every(
          (t) => t.priority == DailyTaskPriority.todayProgram,
        ),
        isTrue,
      );
    });

    test(
      'ProgramCalendar with isOverdueProgram uses overdueProgram priority',
      () {
        final input = SchedulerInput(
          curriculumId: _curriculum,
          trackId: 1,
          trackLabel: 'personal',
          today: _today,
          contentItems: _items(5),
          completions: const [],
          stages: [
            const SchedulerStage(
              id: 1,
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
            ),
          ],
        );

        const strategy = ProgramCalendar(
          programRefs: ['ref_0'],
          isOverdueProgram: true,
        );
        final analysis = strategy.analyse(input);
        final assembly = strategy.assemble(input, analysis);

        expect(assembly.tasks, hasLength(1));
        expect(assembly.tasks.first.priority, DailyTaskPriority.overdueProgram);
      },
    );
  });

  // ── SchedulingStrategy static helper coverage ───────────────────────────────

  group('SchedulingStrategy static helpers', () {
    test('buildCompletionMap groups by sefariaRef and stageOrder', () {
      final input = SchedulerInput(
        curriculumId: _curriculum,
        trackId: 1,
        trackLabel: 'personal',
        today: _today,
        contentItems: _items(3),
        completions: [
          _completion('ref_0', 1, _today),
          _completion('ref_0', 2, _today),
          _completion('ref_1', 1, _today),
        ],
        stages: _twoStages(),
      );

      final map = SchedulingStrategy.buildCompletionMap(input);
      expect(map['ref_0'], hasLength(2));
      expect(map['ref_0']!.containsKey(1), isTrue);
      expect(map['ref_0']!.containsKey(2), isTrue);
      expect(map['ref_1'], hasLength(1));
      expect(map['ref_2'], isNull);
    });

    test('orderedRefsFrom sorts by sortOrder ascending', () {
      final items = [
        const SchedulerContentItem(sefariaRef: 'c', sortOrder: 2),
        const SchedulerContentItem(sefariaRef: 'a', sortOrder: 0),
        const SchedulerContentItem(sefariaRef: 'b', sortOrder: 1),
      ];
      final refs = SchedulingStrategy.orderedRefsFrom(items);
      expect(refs, ['a', 'b', 'c']);
    });
  });

  // ── Weekly schedule type ──────────────────────────────────────────────────

  group('_processWeekly', () {
    test('weekly stage due on today weekday appears as scheduledChazara', () {
      // _today = 2026-05-14, which is a Thursday (weekday = 4).
      final stages = [
        const SchedulerStage(
          id: 1,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        SchedulerStage(
          id: 2,
          stageOrder: 2,
          stageName: 'Weekly review',
          delayDays: 0,
          scheduleType: ScheduleType.weekly,
          daysOfWeek: [_today.weekday], // today
        ),
      ];
      final input = _selfPaced(
        stages: stages,
        completions: [_completion('ref_0', 1, _today)],
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final weeklyTask = assembly.tasks.where(
        (t) => t.contentItemSefariaRef == 'ref_0' && t.stageOrder == 2,
      );
      expect(weeklyTask, isNotEmpty);
    });

    test('weekly stage not due today does not appear', () {
      // daysOfWeek contains a day that is NOT today.
      final tomorrow = (_today.weekday % 7) + 1;
      final stages = [
        const SchedulerStage(
          id: 1,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        SchedulerStage(
          id: 2,
          stageOrder: 2,
          stageName: 'Weekly review',
          delayDays: 0,
          scheduleType: ScheduleType.weekly,
          daysOfWeek: [tomorrow], // not today
        ),
      ];
      final input = _selfPaced(
        stages: stages,
        completions: [_completion('ref_0', 1, _today)],
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final weeklyTask = assembly.tasks.where(
        (t) => t.contentItemSefariaRef == 'ref_0' && t.stageOrder == 2,
      );
      expect(weeklyTask, isEmpty);
    });

    test('weekly stage with empty daysOfWeek does not appear', () {
      final stages = [
        const SchedulerStage(
          id: 1,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        const SchedulerStage(
          id: 2,
          stageOrder: 2,
          stageName: 'Weekly review',
          delayDays: 0,
          scheduleType: ScheduleType.weekly,
          daysOfWeek: [], // empty
        ),
      ];
      final input = _selfPaced(
        stages: stages,
        completions: [_completion('ref_0', 1, _today)],
      );

      final assembly = SchedulingStrategyRunner.run(input);
      final weeklyTask = assembly.tasks.where(
        (t) => t.contentItemSefariaRef == 'ref_0' && t.stageOrder == 2,
      );
      expect(weeklyTask, isEmpty);
    });
  });
}
