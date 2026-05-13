import 'dart:math';

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/scheduler_analysis.dart';
import 'package:learning_tracker/features/scheduler/domain/models/scheduler_input.dart';
import 'package:learning_tracker/features/scheduler/domain/models/task_assembly.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

/// Sealed base for all scheduling strategies.
///
/// Each case knows how to:
/// 1. Derive a [SchedulerAnalysis] from a [SchedulerInput].
/// 2. Assemble a [TaskAssembly] from that analysis.
///
/// Strategies are pure: they perform no I/O and hold no mutable state.
/// All data required for scheduling is pre-loaded into [SchedulerInput].
sealed class SchedulingStrategy {
  const SchedulingStrategy();

  /// Name used in [TaskAssembly.strategyName] for logging / debugging.
  String get name;

  /// Analyse [input] and produce a [SchedulerAnalysis].
  SchedulerAnalysis analyse(SchedulerInput input);

  /// Assemble [TaskAssembly] from a pre-computed [SchedulerAnalysis] and
  /// the originating [SchedulerInput].
  TaskAssembly assemble(SchedulerInput input, SchedulerAnalysis analysis);

  // ───── Shared helpers (available to all subclasses) ─────────────────────

  /// Build completion map: sefariaRef → { stageOrder → completedAt }.
  static Map<String, Map<int, DateTime>> buildCompletionMap(
    SchedulerInput input,
  ) {
    final map = <String, Map<int, DateTime>>{};
    for (final c in input.completions) {
      map.putIfAbsent(c.sefariaRef, () => {})[c.stageOrder] = c.completedAt;
    }
    return map;
  }

  /// Sort [input.stages] ascending by stageOrder.
  static List<SchedulerStage> sortedStages(SchedulerInput input) {
    return List.of(input.stages)
      ..sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
  }

  /// Build ordered refs from content items, respecting custom sort order.
  /// For this strategy-pattern overlay the custom learning order is baked
  /// into [SchedulerInput.contentItems] (already pre-sorted by the caller).
  static List<String> orderedRefsFrom(List<SchedulerContentItem> items) {
    final sorted = List.of(items)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted.map((c) => c.sefariaRef).toList();
  }

  /// Collect delay/weekly overdue + scheduled chazara tasks from [orderedRefs].
  static ({List<DailyTask> overdue, List<DailyTask> scheduled}) collectChazara({
    required SchedulerInput input,
    required List<String> orderedRefs,
    required Map<String, Map<int, DateTime>> completionMap,
    required List<SchedulerStage> stages,
    required int firstStageOrder,
  }) {
    final overdue = <DailyTask>[];
    final scheduled = <DailyTask>[];

    for (final ref in orderedRefs) {
      final itemCompletions = completionMap[ref];
      if (itemCompletions == null || itemCompletions.isEmpty) continue;

      for (final stage in stages) {
        if (stage.stageOrder == firstStageOrder) continue;

        switch (stage.scheduleType) {
          case ScheduleType.delay:
            _processDelay(
              stage: stage,
              stages: stages,
              itemCompletions: itemCompletions,
              input: input,
              ref: ref,
              overdue: overdue,
              scheduled: scheduled,
            );
          case ScheduleType.weekly:
            _processWeekly(
              stage: stage,
              stages: stages,
              itemCompletions: itemCompletions,
              input: input,
              ref: ref,
              scheduled: scheduled,
            );
          case ScheduleType.rolling:
            break; // handled separately via processRolling()
        }
      }
    }

    return (overdue: overdue, scheduled: scheduled);
  }

  /// Collect rolling-window chazara tasks.
  static void processRolling({
    required SchedulerInput input,
    required List<SchedulerStage> stages,
    required Map<String, Map<int, DateTime>> completionMap,
    required List<String> orderedRefs,
    required int firstStageOrder,
    required List<DailyTask> scheduled,
  }) {
    for (final stage in stages) {
      if (stage.scheduleType != ScheduleType.rolling ||
          stage.rollingWindowSize == null)
        continue;

      final windowSize = stage.rollingWindowSize!;
      final completed = <MapEntry<String, DateTime>>[];
      for (final ref in orderedRefs) {
        final c = completionMap[ref];
        if (c != null && c.containsKey(firstStageOrder)) {
          completed.add(MapEntry(ref, c[firstStageOrder]!));
        }
      }
      completed.sort((a, b) => b.value.compareTo(a.value));

      for (final entry in completed.take(windowSize)) {
        final itemC = completionMap[entry.key]!;
        if (!itemC.containsKey(stage.stageOrder)) {
          scheduled.add(
            DailyTask(
              curriculumId: input.curriculumId,
              contentItemSefariaRef: entry.key,
              stageOrder: stage.stageOrder,
              stageDefinitionId: stage.id,
              priority: DailyTaskPriority.scheduledChazara,
              isOverdue: false,
              reason: '${stage.stageName} (rolling window)',
              stageName: stage.stageName,
              trackId: input.trackId,
              trackLabel: input.trackLabel,
              estimatedEffortMinutes: 3,
            ),
          );
        }
      }
    }
  }

  // ───── Private helpers ───────────────────────────────────────────────────

  static void _processDelay({
    required SchedulerStage stage,
    required List<SchedulerStage> stages,
    required Map<int, DateTime> itemCompletions,
    required SchedulerInput input,
    required String ref,
    required List<DailyTask> overdue,
    required List<DailyTask> scheduled,
  }) {
    final prev = stages
        .where((s) => s.stageOrder < stage.stageOrder)
        .reduce((a, b) => a.stageOrder > b.stageOrder ? a : b);

    final prevDone = itemCompletions[prev.stageOrder];
    final thisDone = itemCompletions[stage.stageOrder];
    if (prevDone == null || thisDone != null) return;

    final due = prevDone.add(Duration(days: stage.delayDays));
    final daysUntil = due.difference(input.today).inDays;

    if (daysUntil < 0) {
      overdue.add(
        DailyTask(
          curriculumId: input.curriculumId,
          contentItemSefariaRef: ref,
          stageOrder: stage.stageOrder,
          stageDefinitionId: stage.id,
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
          reason: '${stage.stageName} overdue by ${-daysUntil} day(s)',
          stageName: stage.stageName,
          trackId: input.trackId,
          trackLabel: input.trackLabel,
          estimatedEffortMinutes: 3,
        ),
      );
    } else if (daysUntil == 0) {
      scheduled.add(
        DailyTask(
          curriculumId: input.curriculumId,
          contentItemSefariaRef: ref,
          stageOrder: stage.stageOrder,
          stageDefinitionId: stage.id,
          priority: DailyTaskPriority.scheduledChazara,
          isOverdue: false,
          reason: '${stage.stageName} due today',
          stageName: stage.stageName,
          trackId: input.trackId,
          trackLabel: input.trackLabel,
          estimatedEffortMinutes: 3,
        ),
      );
    }
  }

  static void _processWeekly({
    required SchedulerStage stage,
    required List<SchedulerStage> stages,
    required Map<int, DateTime> itemCompletions,
    required SchedulerInput input,
    required String ref,
    required List<DailyTask> scheduled,
  }) {
    if (stage.daysOfWeek == null || stage.daysOfWeek!.isEmpty) return;

    final prev = stages
        .where((s) => s.stageOrder < stage.stageOrder)
        .reduce((a, b) => a.stageOrder > b.stageOrder ? a : b);

    final prevDone = itemCompletions[prev.stageOrder];
    final thisDone = itemCompletions[stage.stageOrder];
    if (prevDone == null || thisDone != null) return;

    final todayDow = input.today.weekday; // 1=Mon..7=Sun
    if (stage.daysOfWeek!.contains(todayDow)) {
      scheduled.add(
        DailyTask(
          curriculumId: input.curriculumId,
          contentItemSefariaRef: ref,
          stageOrder: stage.stageOrder,
          stageDefinitionId: stage.id,
          priority: DailyTaskPriority.scheduledChazara,
          isOverdue: false,
          reason: '${stage.stageName} scheduled for today',
          stageName: stage.stageName,
          trackId: input.trackId,
          trackLabel: input.trackLabel,
          estimatedEffortMinutes: 3,
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Case 1: Self-paced snapshot
// ═══════════════════════════════════════════════════════════════════════════

/// Self-paced strategy: daily task count is fixed by [SchedulerInput.pacePerDay].
///
/// Uses the snapshot-based approach: prior-day snapshots determine what
/// items are overdue; today's batch is the next [pacePerDay] unseen items.
/// Activated when `pacePerDay != null && trackStartedAt != null`.
final class SelfPacedSnapshot extends SchedulingStrategy {
  const SelfPacedSnapshot();

  @override
  String get name => 'SelfPacedSnapshot';

  @override
  SchedulerAnalysis analyse(SchedulerInput input) {
    final stages = SchedulingStrategy.sortedStages(input);
    final firstStageOrder = stages.first.stageOrder;
    final completionMap = SchedulingStrategy.buildCompletionMap(input);
    final orderedRefs = SchedulingStrategy.orderedRefsFrom(input.contentItems);

    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: chazara.scheduled,
    );

    final chazaraCount = chazara.overdue.length + chazara.scheduled.length;
    final pace = input.pacePerDay!.ceil();

    // New-learning refs = unseen items not yet completed at first stage.
    // The snapshot engine identifies "overdue" from priorlyShownRefs; the
    // analysis only captures genuinely new refs here (not yet shown).
    final priorlyShown = input.priorlyShownRefs;
    final newLearningRefs = <String>[];
    for (final ref in orderedRefs) {
      if (priorlyShown.contains(ref)) continue;
      final done = completionMap[ref]?.containsKey(firstStageOrder) ?? false;
      if (done) continue;
      newLearningRefs.add(ref);
    }

    return SchedulerAnalysis(
      completionMap: completionMap,
      sortedStages: stages,
      orderedItems: input.contentItems,
      orderedRefs: orderedRefs,
      newLearningRefs: newLearningRefs,
      newItemsPerDay: pace,
      chazaraLoadCount: chazaraCount,
      isStudyDay: input.isStudyDay,
      firstStageOrder: firstStageOrder,
    );
  }

  @override
  TaskAssembly assemble(SchedulerInput input, SchedulerAnalysis analysis) {
    final stages = analysis.sortedStages;
    final firstStage = stages.first;
    final firstStageOrder = analysis.firstStageOrder;
    final completionMap = analysis.completionMap;
    final orderedRefs = analysis.orderedRefs;
    final priorlyShown = input.priorlyShownRefs;

    final overdueTasks = <DailyTask>[];
    final scheduledTasks = <DailyTask>[];

    // Carry-over overdue from prior-day snapshots.
    for (final ref in orderedRefs) {
      if (!priorlyShown.contains(ref)) continue;
      final done = completionMap[ref]?.containsKey(firstStageOrder) ?? false;
      if (done) continue;
      overdueTasks.add(
        DailyTask(
          curriculumId: input.curriculumId,
          contentItemSefariaRef: ref,
          stageOrder: firstStageOrder,
          stageDefinitionId: firstStage.id,
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
          reason: 'Missed earlier',
          stageName: firstStage.stageName,
          trackId: input.trackId,
          trackLabel: input.trackLabel,
          estimatedEffortMinutes: 5,
        ),
      );
    }

    // Re-collect delay/weekly/rolling chazara.
    // Note: delay-overdue comes from chazara.overdue (stage 2+), while the
    // snapshot-overdue above covers uncompleted first-stage items from prior
    // snapshots. Both are surfaced as overdueChazara.
    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    overdueTasks.addAll(chazara.overdue);
    scheduledTasks.addAll(chazara.scheduled);
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: scheduledTasks,
    );

    // Today's new batch.
    final isCoarse = _isCoarseMode(input);
    final List<DailyTask> newTasks;
    if (isCoarse) {
      final refs = _pickCoarseBatch(
        input: input,
        orderedRefs: orderedRefs,
        completionMap: completionMap,
        firstStageOrder: firstStageOrder,
        coarseUnitsPerDay: analysis.newItemsPerDay,
      );
      newTasks = refs
          .map(
            (ref) => DailyTask(
              curriculumId: input.curriculumId,
              contentItemSefariaRef: ref,
              stageOrder: firstStageOrder,
              stageDefinitionId: firstStage.id,
              priority: DailyTaskPriority.newLearning,
              isOverdue: false,
              reason: 'New learning',
              stageName: firstStage.stageName,
              trackId: input.trackId,
              trackLabel: input.trackLabel,
              estimatedEffortMinutes: 5,
            ),
          )
          .toList();
    } else {
      newTasks = analysis.newLearningRefs
          .take(analysis.newItemsPerDay)
          .map(
            (ref) => DailyTask(
              curriculumId: input.curriculumId,
              contentItemSefariaRef: ref,
              stageOrder: firstStageOrder,
              stageDefinitionId: firstStage.id,
              priority: DailyTaskPriority.newLearning,
              isOverdue: false,
              reason: 'New learning',
              stageName: firstStage.stageName,
              trackId: input.trackId,
              trackLabel: input.trackLabel,
              estimatedEffortMinutes: 5,
            ),
          )
          .toList();
    }

    const maxOverdue = 20;
    final cappedOverdue = overdueTasks.length > maxOverdue
        ? overdueTasks.sublist(0, maxOverdue)
        : overdueTasks;

    final tasks = analysis.isStudyDay
        ? [...cappedOverdue, ...scheduledTasks, ...newTasks]
        : [...cappedOverdue, ...scheduledTasks];

    tasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return TaskAssembly(tasks: tasks, strategyName: name);
  }

  bool _isCoarseMode(SchedulerInput input) {
    final unit = input.paceGranularity;
    if (unit == null) return false;
    final leafEn = CurriculumLabels.leaf(input.curriculumId).en.toLowerCase();
    return unit.toLowerCase() != leafEn;
  }

  List<String> _pickCoarseBatch({
    required SchedulerInput input,
    required List<String> orderedRefs,
    required Map<String, Map<int, DateTime>> completionMap,
    required int firstStageOrder,
    required int coarseUnitsPerDay,
  }) {
    final byRef = {for (final c in input.contentItems) c.sefariaRef: c};
    final priorlyShown = input.priorlyShownRefs;

    final coarseOrder = <String>[];
    final coarseLeaves = <String, List<String>>{};
    for (final ref in orderedRefs) {
      final item = byRef[ref];
      final key = item?.coarseUnitKey ?? ref;
      coarseLeaves
          .putIfAbsent(key, () {
            coarseOrder.add(key);
            return <String>[];
          })
          .add(ref);
    }

    final picked = <String>[];
    var unitsTaken = 0;
    for (final key in coarseOrder) {
      if (unitsTaken >= coarseUnitsPerDay) break;
      final leaves = coarseLeaves[key]!;
      if (leaves.any(priorlyShown.contains)) continue;
      final remaining = leaves.where((r) {
        final done = completionMap[r]?.containsKey(firstStageOrder) ?? false;
        return !done;
      }).toList();
      if (remaining.isEmpty) continue;
      picked.addAll(remaining);
      unitsTaken += 1;
    }
    return picked;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Case 2: Deadline goal
// ═══════════════════════════════════════════════════════════════════════════

/// Deadline-goal strategy: daily new-item count is computed from remaining
/// items divided by remaining study days until [SchedulerInput.goalDeadline].
///
/// Activated when `goalDeadline != null && pacePerDay == null`.
final class DeadlineGoal extends SchedulingStrategy {
  const DeadlineGoal();

  @override
  String get name => 'DeadlineGoal';

  @override
  SchedulerAnalysis analyse(SchedulerInput input) {
    final stages = SchedulingStrategy.sortedStages(input);
    final firstStageOrder = stages.first.stageOrder;
    final completionMap = SchedulingStrategy.buildCompletionMap(input);
    final orderedRefs = SchedulingStrategy.orderedRefsFrom(input.contentItems);

    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: chazara.scheduled,
    );

    final chazaraCount = chazara.overdue.length + chazara.scheduled.length;

    final newLearningRefs = orderedRefs.where((ref) {
      final c = completionMap[ref];
      return c == null || c.isEmpty;
    }).toList();

    final newItemsPerDay = _calculateNewItemsPerDay(
      input: input,
      remainingNewItems: newLearningRefs.length,
      chazaraCount: chazaraCount,
    );

    return SchedulerAnalysis(
      completionMap: completionMap,
      sortedStages: stages,
      orderedItems: input.contentItems,
      orderedRefs: orderedRefs,
      newLearningRefs: newLearningRefs,
      newItemsPerDay: newItemsPerDay,
      chazaraLoadCount: chazaraCount,
      isStudyDay: input.isStudyDay,
      firstStageOrder: firstStageOrder,
    );
  }

  @override
  TaskAssembly assemble(SchedulerInput input, SchedulerAnalysis analysis) {
    final stages = analysis.sortedStages;
    final firstStage = stages.first;
    final firstStageOrder = analysis.firstStageOrder;
    final completionMap = analysis.completionMap;
    final orderedRefs = analysis.orderedRefs;

    final overdueTasks = <DailyTask>[];
    final scheduledTasks = <DailyTask>[];

    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    overdueTasks.addAll(chazara.overdue);
    scheduledTasks.addAll(chazara.scheduled);
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: scheduledTasks,
    );

    final newTasks = analysis.newLearningRefs
        .take(analysis.newItemsPerDay)
        .map(
          (ref) => DailyTask(
            curriculumId: input.curriculumId,
            contentItemSefariaRef: ref,
            stageOrder: firstStageOrder,
            stageDefinitionId: firstStage.id,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New learning',
            stageName: firstStage.stageName,
            trackId: input.trackId,
            trackLabel: input.trackLabel,
            estimatedEffortMinutes: 5,
          ),
        )
        .toList();

    const maxOverdue = 20;
    final cappedOverdue = overdueTasks.length > maxOverdue
        ? overdueTasks.sublist(0, maxOverdue)
        : overdueTasks;

    final tasks = analysis.isStudyDay
        ? [...cappedOverdue, ...scheduledTasks, ...newTasks]
        : [...cappedOverdue, ...scheduledTasks];

    tasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return TaskAssembly(tasks: tasks, strategyName: name);
  }

  int _calculateNewItemsPerDay({
    required SchedulerInput input,
    required int remainingNewItems,
    required int chazaraCount,
  }) {
    if (remainingNewItems == 0) return 0;

    final deadline = input.goalDeadline!;
    final daysRemaining = deadline.difference(input.today).inDays;

    final int baseRate;
    if (daysRemaining <= 0) {
      baseRate = (remainingNewItems * 0.1).ceil();
    } else {
      final int studyDaysRemaining;
      final exact = input.studyDaysInDeadlineWindow;
      if (exact != null && exact > 0) {
        studyDaysRemaining = exact;
      } else {
        final approx = (daysRemaining * input.studyDaysPerWeek / 7).ceil();
        studyDaysRemaining = approx > 0 ? approx : 1;
      }
      baseRate = (remainingNewItems / studyDaysRemaining).ceil();
    }

    // Chazara load balancing.
    final dailyCapacity = baseRate + chazaraCount;
    var adjusted = baseRate;
    if (dailyCapacity > 0 && chazaraCount > dailyCapacity ~/ 2) {
      final chazaraRatio = chazaraCount / dailyCapacity;
      adjusted = (baseRate * (1.0 - chazaraRatio)).ceil();
    }

    return max(1, adjusted);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Case 3: Legacy adaptive
// ═══════════════════════════════════════════════════════════════════════════

/// Legacy adaptive strategy: uses [SchedulerInput.defaultNewItemsPerDay]
/// when neither pacePerDay nor goalDeadline is set.
///
/// This is the baseline path for tracks without any explicit goal — the
/// engine simply emits [defaultNewItemsPerDay] new items, balanced against
/// the current chazara load.
final class LegacyAdaptive extends SchedulingStrategy {
  const LegacyAdaptive();

  @override
  String get name => 'LegacyAdaptive';

  @override
  SchedulerAnalysis analyse(SchedulerInput input) {
    final stages = SchedulingStrategy.sortedStages(input);
    final firstStageOrder = stages.first.stageOrder;
    final completionMap = SchedulingStrategy.buildCompletionMap(input);
    final orderedRefs = SchedulingStrategy.orderedRefsFrom(input.contentItems);

    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: chazara.scheduled,
    );

    final chazaraCount = chazara.overdue.length + chazara.scheduled.length;

    final newLearningRefs = orderedRefs.where((ref) {
      final c = completionMap[ref];
      return c == null || c.isEmpty;
    }).toList();

    final newItemsPerDay = _calculateNewItemsPerDay(
      defaultRate: input.defaultNewItemsPerDay,
      remainingNewItems: newLearningRefs.length,
      chazaraCount: chazaraCount,
    );

    return SchedulerAnalysis(
      completionMap: completionMap,
      sortedStages: stages,
      orderedItems: input.contentItems,
      orderedRefs: orderedRefs,
      newLearningRefs: newLearningRefs,
      newItemsPerDay: newItemsPerDay,
      chazaraLoadCount: chazaraCount,
      isStudyDay: input.isStudyDay,
      firstStageOrder: firstStageOrder,
    );
  }

  @override
  TaskAssembly assemble(SchedulerInput input, SchedulerAnalysis analysis) {
    final stages = analysis.sortedStages;
    final firstStage = stages.first;
    final firstStageOrder = analysis.firstStageOrder;
    final completionMap = analysis.completionMap;
    final orderedRefs = analysis.orderedRefs;

    final overdueTasks = <DailyTask>[];
    final scheduledTasks = <DailyTask>[];

    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    overdueTasks.addAll(chazara.overdue);
    scheduledTasks.addAll(chazara.scheduled);
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: scheduledTasks,
    );

    final newTasks = analysis.newLearningRefs
        .take(analysis.newItemsPerDay)
        .map(
          (ref) => DailyTask(
            curriculumId: input.curriculumId,
            contentItemSefariaRef: ref,
            stageOrder: firstStageOrder,
            stageDefinitionId: firstStage.id,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New learning',
            stageName: firstStage.stageName,
            trackId: input.trackId,
            trackLabel: input.trackLabel,
            estimatedEffortMinutes: 5,
          ),
        )
        .toList();

    const maxOverdue = 20;
    final cappedOverdue = overdueTasks.length > maxOverdue
        ? overdueTasks.sublist(0, maxOverdue)
        : overdueTasks;

    final tasks = analysis.isStudyDay
        ? [...cappedOverdue, ...scheduledTasks, ...newTasks]
        : [...cappedOverdue, ...scheduledTasks];

    tasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return TaskAssembly(tasks: tasks, strategyName: name);
  }

  int _calculateNewItemsPerDay({
    required int defaultRate,
    required int remainingNewItems,
    required int chazaraCount,
  }) {
    if (remainingNewItems == 0) return 0;

    var baseRate = defaultRate;

    final dailyCapacity = baseRate + chazaraCount;
    if (dailyCapacity > 0 && chazaraCount > dailyCapacity ~/ 2) {
      final chazaraRatio = chazaraCount / dailyCapacity;
      baseRate = (baseRate * (1.0 - chazaraRatio)).ceil();
    }

    return max(1, baseRate);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Case 4: Program calendar
// ═══════════════════════════════════════════════════════════════════════════

/// Program-calendar strategy: daily tasks are dictated by an external
/// calendar program (e.g. Daf Yomi, Mishna Yomit).
///
/// In this strategy the new-learning items are provided externally (the
/// calendar ref list is resolved by the provider layer and supplied as
/// [SchedulerInput.contentItems] pre-filtered to today's program entries).
/// The analysis phase still collects chazara; assembly emits the program
/// items with [DailyTaskPriority.todayProgram] or
/// [DailyTaskPriority.overdueProgram] as indicated by [isOverdueProgram].
final class ProgramCalendar extends SchedulingStrategy {
  const ProgramCalendar({
    required this.programRefs,
    this.isOverdueProgram = false,
  });

  /// Resolved sefaria refs for today's program assignment.
  final List<String> programRefs;

  /// True when these refs are for a missed prior day (overdue).
  final bool isOverdueProgram;

  @override
  String get name => 'ProgramCalendar';

  @override
  SchedulerAnalysis analyse(SchedulerInput input) {
    final stages = SchedulingStrategy.sortedStages(input);
    final firstStageOrder = stages.isEmpty ? 1 : stages.first.stageOrder;
    final completionMap = SchedulingStrategy.buildCompletionMap(input);
    final orderedRefs = SchedulingStrategy.orderedRefsFrom(input.contentItems);

    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: chazara.scheduled,
    );

    final chazaraCount = chazara.overdue.length + chazara.scheduled.length;

    return SchedulerAnalysis(
      completionMap: completionMap,
      sortedStages: stages,
      orderedItems: input.contentItems,
      orderedRefs: orderedRefs,
      newLearningRefs: programRefs,
      newItemsPerDay: programRefs.length,
      chazaraLoadCount: chazaraCount,
      isStudyDay: input.isStudyDay,
      firstStageOrder: firstStageOrder,
    );
  }

  @override
  TaskAssembly assemble(SchedulerInput input, SchedulerAnalysis analysis) {
    final stages = analysis.sortedStages;
    if (stages.isEmpty) {
      return TaskAssembly(tasks: const [], strategyName: name);
    }
    final firstStage = stages.first;
    final firstStageOrder = analysis.firstStageOrder;
    final completionMap = analysis.completionMap;
    final orderedRefs = analysis.orderedRefs;

    final overdueTasks = <DailyTask>[];
    final scheduledTasks = <DailyTask>[];

    final chazara = SchedulingStrategy.collectChazara(
      input: input,
      orderedRefs: orderedRefs,
      completionMap: completionMap,
      stages: stages,
      firstStageOrder: firstStageOrder,
    );
    overdueTasks.addAll(chazara.overdue);
    scheduledTasks.addAll(chazara.scheduled);
    SchedulingStrategy.processRolling(
      input: input,
      stages: stages,
      completionMap: completionMap,
      orderedRefs: orderedRefs,
      firstStageOrder: firstStageOrder,
      scheduled: scheduledTasks,
    );

    final priority = isOverdueProgram
        ? DailyTaskPriority.overdueProgram
        : DailyTaskPriority.todayProgram;
    final reason = isOverdueProgram
        ? 'Program day pending from previous days'
        : 'Program assignment for today';

    final programTasks = programRefs
        .map(
          (ref) => DailyTask(
            curriculumId: input.curriculumId,
            contentItemSefariaRef: ref,
            stageOrder: firstStageOrder,
            stageDefinitionId: firstStage.id,
            priority: priority,
            isOverdue: isOverdueProgram,
            reason: reason,
            stageName: firstStage.stageName,
            trackId: input.trackId,
            trackLabel: input.trackLabel,
            estimatedEffortMinutes: 5,
          ),
        )
        .toList();

    const maxOverdue = 20;
    final cappedOverdue = overdueTasks.length > maxOverdue
        ? overdueTasks.sublist(0, maxOverdue)
        : overdueTasks;

    final tasks = [...cappedOverdue, ...scheduledTasks, ...programTasks];
    tasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return TaskAssembly(tasks: tasks, strategyName: name);
  }
}
