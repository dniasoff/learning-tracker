import 'dart:math';

import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';

/// Pure computation service that generates daily task recommendations.
///
/// Three-phase algorithm:
/// 1. Data Loading — fetch content, completions, stages, learning order
/// 2. Analysis — build completion map, categorize items
/// 3. Task Assembly — priority ordering + adaptive pacing
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

    // Filter to personal track only
    final completions = allCompletions
        .where((c) => c.trackType == 'personal')
        .toList();

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
          // First stage (Learn) — skip if already completed
          continue;
        }

        final previousStage = sortedStages
            .where((s) => s.stageOrder < stage.stageOrder)
            .reduce((a, b) => a.stageOrder > b.stageOrder ? a : b);

        final previousCompletedAt = itemCompletions[previousStage.stageOrder];
        final currentCompletedAt = itemCompletions[stage.stageOrder];

        if (previousCompletedAt != null && currentCompletedAt == null) {
          // Previous stage done, this stage not done — check if due
          final dueDate = previousCompletedAt.add(
            Duration(days: stage.delayDays),
          );
          final daysUntilDue = dueDate.difference(config.currentDate).inDays;

          if (daysUntilDue < 0) {
            overdueTasks.add(
              DailyTask(
                contentItemSefariaRef: ref,
                stageOrder: stage.stageOrder,
                priority: DailyTaskPriority.overdueChazara,
                reason: '${stage.stageName} overdue by ${-daysUntilDue} day(s)',
              ),
            );
          } else if (daysUntilDue == 0) {
            scheduledTasks.add(
              DailyTask(
                contentItemSefariaRef: ref,
                stageOrder: stage.stageOrder,
                priority: DailyTaskPriority.scheduledChazara,
                reason: '${stage.stageName} due today',
              ),
            );
          }
        }
      }
    }

    // Phase 3: Task Assembly with adaptive pacing
    final chazaraCount = overdueTasks.length + scheduledTasks.length;
    final newItemsPerDay = _calculateNewItemsPerDay(
      config,
      newLearningRefs.length,
      chazaraCount,
    );

    final newTasks = newLearningRefs.take(newItemsPerDay).map((ref) {
      return DailyTask(
        contentItemSefariaRef: ref,
        stageOrder: firstStageOrder,
        priority: DailyTaskPriority.newLearning,
        reason: 'New learning',
      );
    }).toList();

    // Combine with priority ordering
    return [...overdueTasks, ...scheduledTasks, ...newTasks];
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
  int _calculateNewItemsPerDay(
    ScheduleConfig config,
    int remainingNewItems,
    int chazaraCount,
  ) {
    if (remainingNewItems == 0) return 0;

    if (config.goalDeadline == null) {
      // No deadline: use default rate, ensure at least 1 if chazara is heavy
      return max(1, config.defaultNewItemsPerDay);
    }

    final daysRemaining = config.goalDeadline!
        .difference(config.currentDate)
        .inDays;

    if (daysRemaining <= 0) {
      // Past deadline — push harder
      return max(1, (remainingNewItems * 0.1).ceil());
    }

    // Base rate: spread remaining items evenly
    final baseRate = (remainingNewItems / daysRemaining).ceil();

    // Ensure at least 1 new item even with heavy chazara
    return max(1, baseRate);
  }
}
