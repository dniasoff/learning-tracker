import 'dart:math';

import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

/// Pure computation service that generates daily task recommendations.
///
/// Three-phase algorithm:
/// 1. Data Loading — fetch content, completions, stages, learning order
/// 2. Analysis — build completion map, categorize items
/// 3. Task Assembly — priority ordering + adaptive pacing
///
/// Supports three schedule types:
/// - Delay: item due X days after previous stage completion
/// - Weekly: review on specific days of the week
/// - Rolling: always review the last N items
class SchedulerEngine {
  const SchedulerEngine({
    required SchedulerContentRepository contentRepository,
    required SchedulerCompletionRepository completionRepository,
    required SchedulerStageRepository stageRepository,
    required SchedulerLearningOrderRepository learningOrderRepository,
  }) : _contentRepository = contentRepository,
       _completionRepository = completionRepository,
       _stageRepository = stageRepository,
       _learningOrderRepository = learningOrderRepository;

  final SchedulerContentRepository _contentRepository;
  final SchedulerCompletionRepository _completionRepository;
  final SchedulerStageRepository _stageRepository;
  final SchedulerLearningOrderRepository _learningOrderRepository;

  /// Generate daily tasks for the given schedule configuration.
  ///
  /// Returns tasks sorted by priority: overdue chazara > scheduled chazara > new learning.
  Future<List<DailyTask>> generateDailyTasks(ScheduleConfig config) async {
    // Phase 1: Data Loading
    final contentItems = await _contentRepository.getLeafItems(
      config.curriculumId,
    );
    final allCompletions = await _completionRepository.getCompletions(
      config.curriculumId,
    );
    final stages = await _stageRepository.getStages(config.curriculumId);
    final customOrder = await _learningOrderRepository.getOrder(
      config.curriculumId,
    );

    if (stages.isEmpty || contentItems.isEmpty) return [];

    // Track scoping is now handled at the repository level (Story 20.2/20.5).
    // No client-side filtering needed.
    final completions = allCompletions;

    // Phase 2: Analysis
    // Build completion map: sefariaRef -> {stageOrder -> completedAt}
    final completionMap = <String, Map<int, DateTime>>{};
    for (final c in completions) {
      completionMap.putIfAbsent(
        c.sefariaRef,
        () => <int, DateTime>{},
      )[c.stageOrder] = c.completedAt;
    }

    // Sort stages by stageOrder
    final sortedStages = List.of(stages)
      ..sort((a, b) => a.stageOrder.compareTo(b.stageOrder));

    final firstStageOrder = sortedStages.first.stageOrder;

    // Build ordered list of sefariaRefs respecting custom learning order
    final orderedRefs = _buildOrderedRefs(contentItems, customOrder);

    // Categorize items
    final overdueTasks = <DailyTask>[];
    final scheduledTasks = <DailyTask>[];
    final newLearningRefs = <String>[];

    for (final ref in orderedRefs) {
      final itemCompletions = completionMap[ref];

      if (itemCompletions == null || itemCompletions.isEmpty) {
        // Never started — candidate for new learning
        newLearningRefs.add(ref);
        continue;
      }

      // Check each stage for chazara due
      for (final stage in sortedStages) {
        if (stage.stageOrder == firstStageOrder) {
          continue;
        }

        switch (stage.scheduleType) {
          case ScheduleType.delay:
            _processDelayStage(
              stage: stage,
              sortedStages: sortedStages,
              itemCompletions: itemCompletions,
              config: config,
              ref: ref,
              overdueTasks: overdueTasks,
              scheduledTasks: scheduledTasks,
            );
          case ScheduleType.weekly:
            _processWeeklyStage(
              stage: stage,
              sortedStages: sortedStages,
              itemCompletions: itemCompletions,
              config: config,
              ref: ref,
              scheduledTasks: scheduledTasks,
            );
          case ScheduleType.rolling:
            // Rolling stages handled separately below
            break;
        }
      }
    }

    // Process rolling stages: always include the last N completed items
    for (final stage in sortedStages) {
      if (stage.scheduleType == ScheduleType.rolling &&
          stage.rollingWindowSize != null) {
        _processRollingStage(
          stage: stage,
          sortedStages: sortedStages,
          completionMap: completionMap,
          orderedRefs: orderedRefs,
          config: config,
          scheduledTasks: scheduledTasks,
        );
      }
    }

    // Phase 3: Task Assembly with adaptive pacing
    final chazaraCount = overdueTasks.length + scheduledTasks.length;
    final newItemsPerDay = _calculateNewItemsPerDay(
      config,
      newLearningRefs.length,
      chazaraCount,
    );

    final firstStage = sortedStages.first;
    final newTasks = newLearningRefs.take(newItemsPerDay).map((ref) {
      return DailyTask(
        curriculumId: config.curriculumId,
        contentItemSefariaRef: ref,
        stageOrder: firstStageOrder,
        stageDefinitionId: firstStage.id,
        priority: DailyTaskPriority.newLearning,
        isOverdue: false,
        reason: 'New learning',
        stageName: firstStage.stageName,
        trackId: config.trackId,
        trackLabel: config.trackLabel,
        estimatedEffortMinutes: 5,
      );
    }).toList();

    // Review-only day: suppress new learning tasks
    if (!config.isStudyDay) {
      return [...overdueTasks, ...scheduledTasks];
    }

    // Combine with priority ordering
    return [...overdueTasks, ...scheduledTasks, ...newTasks];
  }

  /// Process a delay-based stage for a single item.
  void _processDelayStage({
    required SchedulerStage stage,
    required List<SchedulerStage> sortedStages,
    required Map<int, DateTime> itemCompletions,
    required ScheduleConfig config,
    required String ref,
    required List<DailyTask> overdueTasks,
    required List<DailyTask> scheduledTasks,
  }) {
    final previousStage = sortedStages
        .where((s) => s.stageOrder < stage.stageOrder)
        .reduce((a, b) => a.stageOrder > b.stageOrder ? a : b);

    final previousCompletedAt = itemCompletions[previousStage.stageOrder];
    final currentCompletedAt = itemCompletions[stage.stageOrder];

    if (previousCompletedAt != null && currentCompletedAt == null) {
      final dueDate = previousCompletedAt.add(Duration(days: stage.delayDays));
      final daysUntilDue = dueDate.difference(config.currentDate).inDays;

      if (daysUntilDue < 0) {
        overdueTasks.add(
          DailyTask(
            curriculumId: config.curriculumId,
            contentItemSefariaRef: ref,
            stageOrder: stage.stageOrder,
            stageDefinitionId: stage.id,
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
            reason: '${stage.stageName} overdue by ${-daysUntilDue} day(s)',
            stageName: stage.stageName,
            trackId: config.trackId,
            trackLabel: config.trackLabel,
            estimatedEffortMinutes: 3,
          ),
        );
      } else if (daysUntilDue == 0) {
        scheduledTasks.add(
          DailyTask(
            curriculumId: config.curriculumId,
            contentItemSefariaRef: ref,
            stageOrder: stage.stageOrder,
            stageDefinitionId: stage.id,
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
            reason: '${stage.stageName} due today',
            stageName: stage.stageName,
            trackId: config.trackId,
            trackLabel: config.trackLabel,
            estimatedEffortMinutes: 3,
          ),
        );
      }
    }
  }

  /// Process a weekly stage for a single item.
  ///
  /// Items that have completed the previous stage but not this stage
  /// are due on the specified days of the week.
  void _processWeeklyStage({
    required SchedulerStage stage,
    required List<SchedulerStage> sortedStages,
    required Map<int, DateTime> itemCompletions,
    required ScheduleConfig config,
    required String ref,
    required List<DailyTask> scheduledTasks,
  }) {
    if (stage.daysOfWeek == null || stage.daysOfWeek!.isEmpty) return;

    final previousStage = sortedStages
        .where((s) => s.stageOrder < stage.stageOrder)
        .reduce((a, b) => a.stageOrder > b.stageOrder ? a : b);

    final previousCompletedAt = itemCompletions[previousStage.stageOrder];
    final currentCompletedAt = itemCompletions[stage.stageOrder];

    if (previousCompletedAt != null && currentCompletedAt == null) {
      // Check if today is one of the scheduled days (1=Mon..7=Sun)
      final todayDow = config.currentDate.weekday; // 1=Mon..7=Sun
      if (stage.daysOfWeek!.contains(todayDow)) {
        scheduledTasks.add(
          DailyTask(
            curriculumId: config.curriculumId,
            contentItemSefariaRef: ref,
            stageOrder: stage.stageOrder,
            stageDefinitionId: stage.id,
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
            reason: '${stage.stageName} scheduled for today',
            stageName: stage.stageName,
            trackId: config.trackId,
            trackLabel: config.trackLabel,
            estimatedEffortMinutes: 3,
          ),
        );
      }
    }
  }

  /// Process a rolling window stage.
  ///
  /// Finds the most recently completed N items (by first-stage completion)
  /// that haven't completed this stage yet, and schedules them.
  void _processRollingStage({
    required SchedulerStage stage,
    required List<SchedulerStage> sortedStages,
    required Map<String, Map<int, DateTime>> completionMap,
    required List<String> orderedRefs,
    required ScheduleConfig config,
    required List<DailyTask> scheduledTasks,
  }) {
    final windowSize = stage.rollingWindowSize!;
    final firstStageOrder = sortedStages.first.stageOrder;

    // Collect refs that have completed the first stage, sorted by completion date (most recent first)
    final completedRefs = <MapEntry<String, DateTime>>[];
    for (final ref in orderedRefs) {
      final itemCompletions = completionMap[ref];
      if (itemCompletions != null &&
          itemCompletions.containsKey(firstStageOrder)) {
        completedRefs.add(MapEntry(ref, itemCompletions[firstStageOrder]!));
      }
    }

    // Sort by first-stage completion date descending (most recent first)
    completedRefs.sort((a, b) => b.value.compareTo(a.value));

    // Take the last N, filter out those already completed for this stage
    final windowRefs = completedRefs.take(windowSize);
    for (final entry in windowRefs) {
      final ref = entry.key;
      final itemCompletions = completionMap[ref]!;
      if (!itemCompletions.containsKey(stage.stageOrder)) {
        scheduledTasks.add(
          DailyTask(
            curriculumId: config.curriculumId,
            contentItemSefariaRef: ref,
            stageOrder: stage.stageOrder,
            stageDefinitionId: stage.id,
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
            reason: '${stage.stageName} (rolling window)',
            stageName: stage.stageName,
            trackId: config.trackId,
            trackLabel: config.trackLabel,
            estimatedEffortMinutes: 3,
          ),
        );
      }
    }
  }

  /// Build ordered list of sefariaRefs respecting custom learning order.
  List<String> _buildOrderedRefs(
    List<SchedulerContentItem> contentItems,
    List<SchedulerOrderItem> customOrder,
  ) {
    if (customOrder.isNotEmpty) {
      final customOrderMap = {
        for (final item in customOrder) item.sefariaRef: item.userSortOrder,
      };
      final contentSet = {for (final c in contentItems) c.sefariaRef};

      // Items with custom order first, then remaining by content sortOrder
      final customRefs =
          customOrder.where((o) => contentSet.contains(o.sefariaRef)).toList()
            ..sort((a, b) => a.userSortOrder.compareTo(b.userSortOrder));

      final remainingItems =
          contentItems
              .where((c) => !customOrderMap.containsKey(c.sefariaRef))
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return [
        ...customRefs.map((o) => o.sefariaRef),
        ...remainingItems.map((c) => c.sefariaRef),
      ];
    }

    final sorted = List.of(contentItems)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted.map((c) => c.sefariaRef).toList();
  }

  /// Calculate new items per day with adaptive pacing.
  ///
  /// When chazara load is heavy (exceeds half of daily capacity),
  /// new items are reduced proportionally. Always returns at least 1
  /// to ensure forward progress.
  int _calculateNewItemsPerDay(
    ScheduleConfig config,
    int remainingNewItems,
    int chazaraCount,
  ) {
    if (remainingNewItems == 0) return 0;

    int baseRate;

    if (config.pacePerDay != null) {
      // Pace-based goal: use configured pace directly
      baseRate = config.pacePerDay!.ceil();
    } else if (config.goalDeadline == null) {
      baseRate = config.defaultNewItemsPerDay;
    } else {
      final daysRemaining = config.goalDeadline!
          .difference(config.currentDate)
          .inDays;

      if (daysRemaining <= 0) {
        // Past deadline — push harder
        baseRate = (remainingNewItems * 0.1).ceil();
      } else {
        // Spread remaining items across study days only
        final studyDaysRemaining = (daysRemaining * config.studyDaysPerWeek / 7)
            .ceil();
        if (studyDaysRemaining <= 0) {
          baseRate = (remainingNewItems * 0.1).ceil();
        } else {
          baseRate = (remainingNewItems / studyDaysRemaining).ceil();
        }
      }
    }

    // Chazara load balancing: when chazara tasks exceed half of daily
    // capacity (baseRate + chazaraCount), reduce new items proportionally.
    final dailyCapacity = baseRate + chazaraCount;
    if (dailyCapacity > 0 && chazaraCount > dailyCapacity ~/ 2) {
      final chazaraRatio = chazaraCount / dailyCapacity;
      baseRate = (baseRate * (1.0 - chazaraRatio)).ceil();
    }

    // Always at least 1 new item for forward progress
    return max(1, baseRate);
  }
}
