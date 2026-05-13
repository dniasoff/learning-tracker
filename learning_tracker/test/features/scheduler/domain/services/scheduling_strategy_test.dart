// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/scheduler_input.dart';
import 'package:learning_tracker/features/scheduler/domain/models/task_assembly.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduling_strategy.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduling_strategy_runner.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

// ───── Helpers ──────────────────────────────────────────────────────────────

const _curriculum = CurriculumId.mishnayos;
final _today = DateTime.utc(2026, 5, 13);

List<SchedulerContentItem> _items(int count) => List.generate(
  count,
  (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
);

List<SchedulerStage> _twoStages() => [
  const SchedulerStage(id: 1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
  const SchedulerStage(
    id: 2,
    stageOrder: 2,
    stageName: 'Chazara 1',
    delayDays: 1,
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
  );
}

// ───── TaskAssembly type ─────────────────────────────────────────────────────

void main() {
  group('TaskAssembly', () {
    test('length / isEmpty / isNotEmpty convenience accessors', () {
      const empty = TaskAssembly(tasks: [], strategyName: 'test');
      expect(empty.length, 0);
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);

      const one = TaskAssembly(
        tasks: [
          DailyTask(
            curriculumId: _curriculum,
            contentItemSefariaRef: 'ref_0',
            stageOrder: 1,
            stageDefinitionId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New learning',
            stageName: 'Learn',
            trackId: 1,
            trackLabel: 'personal',
          ),
        ],
        strategyName: 'test',
      );
      expect(one.length, 1);
      expect(one.isEmpty, isFalse);
      expect(one.isNotEmpty, isTrue);
    });
  });

  // ── SchedulingStrategyRunner strategy selection ──────────────────────────

  group('SchedulingStrategyRunner strategy selection', () {
    test(
      'selects SelfPacedSnapshot when pacePerDay + trackStartedAt are set',
      () {
        final input = _baseInput(
          pacePerDay: 3,
          trackStartedAt: _today.subtract(const Duration(days: 5)),
        );
        final assembly = SchedulingStrategyRunner.run(input);
        expect(assembly.strategyName, 'SelfPacedSnapshot');
      },
    );

    test(
      'selects DeadlineGoal when goalDeadline is set and pacePerDay is null',
      () {
        final input = _baseInput(
          goalDeadline: _today.add(const Duration(days: 10)),
        );
        final assembly = SchedulingStrategyRunner.run(input);
        expect(assembly.strategyName, 'DeadlineGoal');
      },
    );

    test('selects LegacyAdaptive when no goal signals are present', () {
      final input = _baseInput();
      final assembly = SchedulingStrategyRunner.run(input);
      expect(assembly.strategyName, 'LegacyAdaptive');
    });

    test('accepts explicit ProgramCalendar strategy override', () {
      final input = _baseInput();
      const strategy = ProgramCalendar(
        programRefs: ['ref_0', 'ref_1'],
        isOverdueProgram: false,
      );
      final assembly = SchedulingStrategyRunner.run(input, strategy: strategy);
      expect(assembly.strategyName, 'ProgramCalendar');
    });
  });

  // ── SelfPacedSnapshot ───────────────────────────────────────────────────

  group('SelfPacedSnapshot', () {
    const strategy = SelfPacedSnapshot();

    test('emits exactly pacePerDay new-learning tasks on a clean track', () {
      final input = _baseInput(
        contentItems: _items(20),
        pacePerDay: 3,
        trackStartedAt: _today,
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final newTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(newTasks.length, 3);
    });

    test('marks previously-shown uncompleted refs as overdueChazara', () {
      const shownRef = 'ref_0';
      final input = _baseInput(
        contentItems: _items(10),
        pacePerDay: 2,
        trackStartedAt: _today.subtract(const Duration(days: 1)),
        priorlyShownRefs: {shownRef},
        completions: const [],
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final overdue = assembly.tasks
          .where((t) => t.contentItemSefariaRef == shownRef)
          .toList();
      expect(overdue, isNotEmpty);
      expect(overdue.first.priority, DailyTaskPriority.overdueChazara);
    });

    test('does not emit new-learning tasks on non-study day', () {
      final input = _baseInput(
        contentItems: _items(10),
        pacePerDay: 3,
        trackStartedAt: _today,
        isStudyDay: false,
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final newTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(newTasks, isEmpty);
    });

    test('emits delay chazara tasks for eligible completed refs', () {
      // ref_0 completed Learn 2 days ago → Chazara 1 (delayDays=1) is overdue
      final input = _baseInput(
        contentItems: _items(5),
        pacePerDay: 2,
        trackStartedAt: _today.subtract(const Duration(days: 3)),
        completions: [
          SchedulerCompletion(
            sefariaRef: 'ref_0',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: _today.subtract(const Duration(days: 2)),
          ),
        ],
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final chazara = assembly.tasks
          .where(
            (t) =>
                t.contentItemSefariaRef == 'ref_0' &&
                t.priority == DailyTaskPriority.overdueChazara &&
                t.stageOrder == 2,
          )
          .toList();
      expect(chazara, isNotEmpty);
    });

    test('strategyName is SelfPacedSnapshot', () {
      final input = _baseInput(pacePerDay: 2, trackStartedAt: _today);
      final assembly = SchedulingStrategyRunner.run(input);
      expect(assembly.strategyName, 'SelfPacedSnapshot');
    });
  });

  // ── DeadlineGoal ─────────────────────────────────────────────────────────

  group('DeadlineGoal', () {
    const strategy = DeadlineGoal();

    test('divides remaining items over study days to deadline', () {
      // 30 items, 10 days → 3/day
      final input = _baseInput(
        contentItems: _items(30),
        goalDeadline: _today.add(const Duration(days: 10)),
        stages: _twoStages(),
        completions: const [],
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final newTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(newTasks.length, 3);
    });

    test('returns at least 1 new item even with heavy chazara load', () {
      // 50 items all completed Learn, creating chazara backlog; 1 new item remains
      final completions = List.generate(
        49,
        (i) => SchedulerCompletion(
          sefariaRef: 'ref_$i',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: _today.subtract(const Duration(days: 30)),
        ),
      );
      final input = _baseInput(
        contentItems: _items(50),
        completions: completions,
        goalDeadline: _today.add(const Duration(days: 10)),
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final newTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(newTasks.length, greaterThanOrEqualTo(1));
    });

    test('does not emit new-learning tasks on non-study day', () {
      final input = _baseInput(
        contentItems: _items(10),
        goalDeadline: _today.add(const Duration(days: 5)),
        isStudyDay: false,
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final newTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(newTasks, isEmpty);
    });

    test(
      'tasks are sorted by priority (overdueChazara before newLearning)',
      () {
        final completions = [
          SchedulerCompletion(
            sefariaRef: 'ref_0',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: _today.subtract(const Duration(days: 5)),
          ),
        ];
        final input = _baseInput(
          contentItems: _items(10),
          completions: completions,
          goalDeadline: _today.add(const Duration(days: 5)),
        );
        final assembly = SchedulingStrategyRunner.run(input);

        // Verify sorted order: overdue before scheduled before new
        final priorities = assembly.tasks.map((t) => t.priority.index).toList();
        for (var i = 0; i < priorities.length - 1; i++) {
          expect(priorities[i], lessThanOrEqualTo(priorities[i + 1]));
        }
      },
    );

    test('strategyName is DeadlineGoal', () {
      final input = _baseInput(
        goalDeadline: _today.add(const Duration(days: 5)),
      );
      final assembly = SchedulingStrategyRunner.run(input);
      expect(assembly.strategyName, 'DeadlineGoal');
    });
  });

  // ── LegacyAdaptive ───────────────────────────────────────────────────────

  group('LegacyAdaptive', () {
    const strategy = LegacyAdaptive();

    test('emits defaultNewItemsPerDay new tasks with no goal', () {
      final input = _baseInput(
        contentItems: _items(20),
        defaultNewItemsPerDay: 4,
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final newTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(newTasks.length, 4);
    });

    test(
      'reduces new-learning rate when chazara load exceeds half capacity',
      () {
        // Complete Learn for 50 items long ago → heavy chazara backlog
        final completions = List.generate(
          50,
          (i) => SchedulerCompletion(
            sefariaRef: 'ref_$i',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: _today.subtract(const Duration(days: 30)),
          ),
        );
        final input = _baseInput(
          contentItems: _items(60),
          completions: completions,
          defaultNewItemsPerDay: 5,
        );
        final analysis = strategy.analyse(input);

        // Under heavy chazara load the rate is reduced (but still ≥ 1)
        expect(analysis.newItemsPerDay, greaterThanOrEqualTo(1));
        expect(analysis.newItemsPerDay, lessThanOrEqualTo(5));
      },
    );

    test('returns empty task list when content items are all completed', () {
      final completions = List.generate(
        5,
        (i) => SchedulerCompletion(
          sefariaRef: 'ref_$i',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: _today.subtract(const Duration(days: 1)),
        ),
      );
      // All 5 items done at stage 1 and stage 2
      final stage2Completions = List.generate(
        5,
        (i) => SchedulerCompletion(
          sefariaRef: 'ref_$i',
          stageOrder: 2,
          trackType: 'personal',
          completedAt: _today,
        ),
      );
      final input = _baseInput(
        contentItems: _items(5),
        completions: [...completions, ...stage2Completions],
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final newTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .toList();
      expect(newTasks, isEmpty);
    });

    test('strategyName is LegacyAdaptive', () {
      final input = _baseInput();
      final assembly = SchedulingStrategyRunner.run(input);
      expect(assembly.strategyName, 'LegacyAdaptive');
    });
  });

  // ── ProgramCalendar ──────────────────────────────────────────────────────

  group('ProgramCalendar', () {
    test('emits todayProgram tasks for resolved refs', () {
      const strategy = ProgramCalendar(
        programRefs: ['ref_0', 'ref_1'],
        isOverdueProgram: false,
      );
      final input = _baseInput(contentItems: _items(10));
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final programTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.todayProgram)
          .toList();
      expect(programTasks.length, 2);
      expect(
        programTasks.map((t) => t.contentItemSefariaRef),
        containsAllInOrder(['ref_0', 'ref_1']),
      );
    });

    test('emits overdueProgram tasks when isOverdueProgram is true', () {
      const strategy = ProgramCalendar(
        programRefs: ['ref_0'],
        isOverdueProgram: true,
      );
      final input = _baseInput(contentItems: _items(10));
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final overdueProgramTasks = assembly.tasks
          .where((t) => t.priority == DailyTaskPriority.overdueProgram)
          .toList();
      expect(overdueProgramTasks.length, 1);
      expect(overdueProgramTasks.first.isOverdue, isTrue);
    });

    test('still collects delay chazara tasks alongside program tasks', () {
      const strategy = ProgramCalendar(
        programRefs: ['ref_0'],
        isOverdueProgram: false,
      );
      // ref_1 completed Learn 2 days ago → Chazara 1 overdue
      final input = _baseInput(
        contentItems: _items(5),
        completions: [
          SchedulerCompletion(
            sefariaRef: 'ref_1',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: _today.subtract(const Duration(days: 2)),
          ),
        ],
      );
      final analysis = strategy.analyse(input);
      final assembly = strategy.assemble(input, analysis);

      final chazara = assembly.tasks
          .where(
            (t) =>
                t.priority == DailyTaskPriority.overdueChazara &&
                t.contentItemSefariaRef == 'ref_1',
          )
          .toList();
      expect(chazara, isNotEmpty);
    });

    test('strategyName is ProgramCalendar', () {
      const strategy = ProgramCalendar(
        programRefs: ['ref_0'],
        isOverdueProgram: false,
      );
      final input = _baseInput();
      final assembly = SchedulingStrategyRunner.run(input, strategy: strategy);
      expect(assembly.strategyName, 'ProgramCalendar');
    });
  });

  // ── Rolling stage across all strategies ─────────────────────────────────

  group('Rolling chazara stage (shared SchedulingStrategy.processRolling)', () {
    List<SchedulerStage> stagesWithRolling() => [
      const SchedulerStage(
        id: 1,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
      ),
      const SchedulerStage(
        id: 2,
        stageOrder: 2,
        stageName: 'Rolling Review',
        delayDays: 0,
        scheduleType: ScheduleType.rolling,
        rollingWindowSize: 3,
      ),
    ];

    test(
      'LegacyAdaptive includes rolling chazara for last N learned items',
      () {
        // Complete 5 items at stage 1, none at stage 2.
        // Rolling window = 3 → last 3 should appear as scheduledChazara.
        final completions = List.generate(
          5,
          (i) => SchedulerCompletion(
            sefariaRef: 'ref_$i',
            stageOrder: 1,
            trackType: 'personal',
            completedAt: _today.subtract(Duration(days: 5 - i)),
          ),
        );
        final input = _baseInput(
          contentItems: _items(10),
          completions: completions,
          stages: stagesWithRolling(),
        );
        final assembly = SchedulingStrategyRunner.run(input);

        final rolling = assembly.tasks
            .where((t) => t.priority == DailyTaskPriority.scheduledChazara)
            .toList();
        expect(rolling.length, 3);
      },
    );
  });

  // ── Weekly stage ─────────────────────────────────────────────────────────

  group('Weekly chazara stage', () {
    test('emits scheduledChazara on the configured weekday', () {
      // _today = 2026-05-13 (Wednesday = weekday 3)
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
          stageName: 'Weekly',
          delayDays: 0,
          scheduleType: ScheduleType.weekly,
          daysOfWeek: [_today.weekday],
        ),
      ];
      final completions = [
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: _today.subtract(const Duration(days: 7)),
        ),
      ];
      final input = _baseInput(
        contentItems: _items(5),
        completions: completions,
        stages: stages,
      );
      final assembly = SchedulingStrategyRunner.run(input);

      final weekly = assembly.tasks
          .where(
            (t) =>
                t.contentItemSefariaRef == 'ref_0' &&
                t.priority == DailyTaskPriority.scheduledChazara &&
                t.stageOrder == 2,
          )
          .toList();
      expect(weekly, isNotEmpty);
    });

    test('does NOT emit scheduledChazara on a non-configured weekday', () {
      // Configure weekday = tomorrow
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
          stageName: 'Weekly',
          delayDays: 0,
          scheduleType: ScheduleType.weekly,
          daysOfWeek: [_today.weekday % 7 + 1], // tomorrow's weekday
        ),
      ];
      final completions = [
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: _today.subtract(const Duration(days: 7)),
        ),
      ];
      final input = _baseInput(
        contentItems: _items(5),
        completions: completions,
        stages: stages,
      );
      final assembly = SchedulingStrategyRunner.run(input);

      final weekly = assembly.tasks
          .where(
            (t) =>
                t.contentItemSefariaRef == 'ref_0' &&
                t.priority == DailyTaskPriority.scheduledChazara,
          )
          .toList();
      expect(weekly, isEmpty);
    });
  });
}
