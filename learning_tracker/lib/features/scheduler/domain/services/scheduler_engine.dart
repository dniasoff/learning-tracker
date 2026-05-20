import 'dart:math';

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';

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
  /// Max overdue chazarah tasks shown per day. Spreads a large backlog
  /// (e.g. after a device restore with old completion timestamps) over many
  /// days instead of dumping all of them on day 1. The remainder stays in
  /// the overdue queue and surfaces tomorrow.
  static const int kMaxOverdueChazarahPerDay = 20;

  /// Unix-milliseconds timestamp for the sentinel date used by
  /// [BulkPriorCompletionService] to mark items that were "learned before this
  /// app" without a real study date (`DateTime.utc(2000, 1, 1)`).
  ///
  /// The engine treats stage-1 completions recorded at this timestamp as if the
  /// item has not yet been learned — so it surfaces as a new-learning task
  /// rather than disappearing silently from the schedule.
  ///
  /// We compare via [DateTime.millisecondsSinceEpoch] rather than direct
  /// `==` because Drift may return a local-timezone [DateTime] when the
  /// underlying column stores an integer epoch, causing UTC-vs-local
  /// inequality even for the same instant.
  static final int kBulkPriorSentinelMs = DateTime.utc(
    2000,
    1,
    1,
  ).millisecondsSinceEpoch;

  /// Sentinel [DateTime] instance for callers that need it (e.g. tests).
  static final DateTime kBulkPriorSentinel = DateTime.utc(2000, 1, 1);

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

      // Items bulk-marked "prior" with the sentinel date (DateTime.utc(2000,1,1))
      // at stage 1 have not actually been studied in this app. Treat them as
      // new-learning candidates so deadline and self-paced tracks both surface
      // them instead of silently dropping them from the schedule.
      final firstStageCompletedAt = itemCompletions[firstStageOrder];
      if (firstStageCompletedAt != null &&
          firstStageCompletedAt.millisecondsSinceEpoch ==
              kBulkPriorSentinelMs &&
          itemCompletions.length == 1) {
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

    // Phase 3: Task Assembly
    final chazaraCount = overdueTasks.length + scheduledTasks.length;
    final firstStage = sortedStages.first;

    final List<DailyTask> newTasks;
    if (_useSnapshotSchedule(config)) {
      // Snapshot-aware path for self-paced tracks:
      //   - overdue = refs ever shown in a prior-day snapshot that are not
      //     completed at the first stage
      //   - today's new = next pacePerDay (leaf or coarse) units from
      //     CURRENT orderedRefs that haven't been shown before and aren't
      //     completed. When the goal's paceGranularity names a coarse level
      //     (e.g. 'perek' on Mishnayos, 'daf' on Bavli), today's batch is
      //     ALL leaves under the next N coarse units — so "1 perek/day"
      //     emits a whole perek, not one mishna.
      // Reorder mid-stream and multi-day app gaps are both handled because
      // the repository back-fills synthetic snapshots before the engine
      // runs and populates `priorlyShownRefs`.
      //
      // isStudyDay guard (DNI-346): on non-study days, the snapshot path must
      // return an empty task list rather than emitting carry-over or new items.
      if (!config.isStudyDay) {
        return const [];
      }

      final pace = config.pacePerDay!.ceil();
      final priorlyShown = config.priorlyShownRefs;

      // Carry-over overdue from prior-day snapshots. Preserve original
      // orderedRefs order so the list is stable across runs.
      //
      // Bug fix (DNI-346): only classify a ref as overdueChazara when it has
      // at least one completion record. A brand-new never-completed item that
      // happens to appear in priorlyShown (e.g. a back-filled synthetic
      // snapshot) must surface as dueNewLearning, not overdueChazara.
      for (final ref in orderedRefs) {
        if (!priorlyShown.contains(ref)) continue;
        final itemCompletions = completionMap[ref];
        final hasAnyCompletion =
            itemCompletions != null && itemCompletions.isNotEmpty;
        final doneAtFirstStage = _isGenuinelyCompletedAtStage(
          itemCompletions,
          firstStageOrder,
        );
        if (doneAtFirstStage) continue;

        if (hasAnyCompletion) {
          // Previously learned item — show as overdue chazara.
          overdueTasks.add(
            DailyTask(
              curriculumId: config.curriculumId,
              contentItemSefariaRef: ref,
              stageOrder: firstStageOrder,
              stageDefinitionId: firstStage.id,
              priority: DailyTaskPriority.overdueChazara,
              isOverdue: true,
              reason: 'Missed earlier',
              stageName: firstStage.stageName,
              trackId: config.trackId,
              trackLabel: config.trackLabel,
              estimatedEffortMinutes: 5,
            ),
          );
        } else {
          // Never completed — classify as overdueNewLearning, not overdueChazara.
          // The item was shown in a prior-day snapshot but never studied; it
          // is NOT chazara (there is nothing to review — it hasn't been learned).
          overdueTasks.add(
            DailyTask(
              curriculumId: config.curriculumId,
              contentItemSefariaRef: ref,
              stageOrder: firstStageOrder,
              stageDefinitionId: firstStage.id,
              priority: DailyTaskPriority.overdueNewLearning,
              isOverdue: true,
              reason: 'Not yet started',
              stageName: firstStage.stageName,
              trackId: config.trackId,
              trackLabel: config.trackLabel,
              estimatedEffortMinutes: 5,
            ),
          );
        }
      }

      // Today's new batch
      final List<String> todaysNewRefs;
      if (_isCoarseMode(config)) {
        todaysNewRefs = _pickCoarseBatch(
          orderedRefs: orderedRefs,
          contentItems: contentItems,
          priorlyShown: priorlyShown,
          completionMap: completionMap,
          firstStageOrder: firstStageOrder,
          coarseUnitsPerDay: pace,
        );
      } else {
        todaysNewRefs = <String>[];
        for (final ref in orderedRefs) {
          if (priorlyShown.contains(ref)) continue;
          final done = _isGenuinelyCompletedAtStage(
            completionMap[ref],
            firstStageOrder,
          );
          if (done) continue;
          todaysNewRefs.add(ref);
          if (todaysNewRefs.length >= pace) break;
        }
      }
      newTasks = todaysNewRefs
          .map(
            (ref) => DailyTask(
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
            ),
          )
          .toList();
    } else {
      // Legacy path: adaptive pacing with no per-day snapshot anchoring.
      // Used by every track that doesn't have both pacePerDay AND
      // trackStartedAt set (e.g. program-driven tracks, tracks with no
      // goal, tests that don't opt in).
      final newItemsPerDay = _calculateNewItemsPerDay(
        config,
        newLearningRefs.length,
        chazaraCount,
      );
      newTasks = newLearningRefs.take(newItemsPerDay).map((ref) {
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
    }

    // Cap overdue chazarah per day so a large backlog doesn't dump on day 1.
    final cappedOverdue = overdueTasks.length > kMaxOverdueChazarahPerDay
        ? overdueTasks.sublist(0, kMaxOverdueChazarahPerDay)
        : overdueTasks;

    // Review-only day: suppress new learning tasks
    if (!config.isStudyDay) {
      return [...cappedOverdue, ...scheduledTasks];
    }

    // Combine with priority ordering
    return [...cappedOverdue, ...scheduledTasks, ...newTasks];
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

    // Collect refs that have completed the first stage, sorted by completion date (most recent first).
    // Sentinel-dated completions (bulk-prior mark) are excluded — those items
    // have not actually been studied and must not enter the rolling window.
    final completedRefs = <MapEntry<String, DateTime>>[];
    for (final ref in orderedRefs) {
      final itemCompletions = completionMap[ref];
      if (_isGenuinelyCompletedAtStage(itemCompletions, firstStageOrder)) {
        completedRefs.add(MapEntry(ref, itemCompletions![firstStageOrder]!));
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
  /// Returns the raw deadline-derived rate capped at [remainingNewItems].
  /// Returns 0 when there are no remaining items or the base rate is ≤ 0
  /// (e.g. deadline already passed). The chazara workload does NOT reduce
  /// the new-learning obligation — chazara is extra work on top of the
  /// pace the deadline demands.
  ///
  /// Whether to use the snapshot-anchored self-paced new-learning path.
  /// True when both pacePerDay and trackStartedAt are set on the config —
  /// i.e. the caller has plumbed a self-paced goal. Program tracks land
  /// on the legacy adaptive-pacing branch.
  bool _useSnapshotSchedule(ScheduleConfig config) {
    return config.pacePerDay != null && config.trackStartedAt != null;
  }

  /// True when the goal's paceGranularity names a level **above** the
  /// curriculum's leaf — meaning pacePerDay counts coarse units (perek /
  /// daf / siman) rather than individual leaves. When false (leaf mode,
  /// or no paceGranularity set), pacePerDay is interpreted as a count of
  /// leaf items.
  bool _isCoarseMode(ScheduleConfig config) {
    final unit = config.paceGranularity;
    if (unit == null) return false;
    final leafEn = CurriculumLabels.leaf(config.curriculumId).en.toLowerCase();
    return unit.toLowerCase() != leafEn;
  }

  /// Pick today's new-learning leaves as **all** leaves under the next
  /// [coarseUnitsPerDay] coarse units (perek / daf / siman) that have
  /// not yet been introduced (no leaf in [priorlyShown]).
  ///
  /// Within a chosen coarse unit, leaves already completed at the first
  /// stage are dropped — we only re-emit refs the user still needs to
  /// learn. This means a partially-completed perek does not re-emit its
  /// completed mishnas; the user picks up where they left off.
  ///
  /// A coarse unit is treated as "introduced" (and skipped) the moment
  /// any of its leaves is in [priorlyShown]. The remaining leaves of
  /// such a unit live in overdue carry-over, not in today's batch.
  List<String> _pickCoarseBatch({
    required List<String> orderedRefs,
    required List<SchedulerContentItem> contentItems,
    required Set<String> priorlyShown,
    required Map<String, Map<int, DateTime>> completionMap,
    required int firstStageOrder,
    required int coarseUnitsPerDay,
  }) {
    final byRef = {for (final c in contentItems) c.sefariaRef: c};

    // Walk orderedRefs once to build a deduplicated, order-preserving
    // list of coarse-unit keys and the leaves under each.
    final coarseOrder = <String>[];
    final coarseLeaves = <String, List<String>>{};
    for (final ref in orderedRefs) {
      final item = byRef[ref];
      final key = item?.coarseUnitKey ?? ref;
      final leaves = coarseLeaves.putIfAbsent(key, () {
        coarseOrder.add(key);
        return <String>[];
      });
      leaves.add(ref);
    }

    final picked = <String>[];
    var unitsTaken = 0;
    for (final key in coarseOrder) {
      if (unitsTaken >= coarseUnitsPerDay) break;
      final leaves = coarseLeaves[key]!;
      final anyShown = leaves.any(priorlyShown.contains);
      if (anyShown) continue;
      final remaining = leaves.where((r) {
        final done = _isGenuinelyCompletedAtStage(
          completionMap[r],
          firstStageOrder,
        );
        return !done;
      }).toList();
      if (remaining.isEmpty) continue;
      picked.addAll(remaining);
      unitsTaken += 1;
    }
    return picked;
  }

  /// Public accessor for the same orderedRefs computation the engine uses
  /// internally. Used by the daily-plan back-fill step in
  /// `_buildFreshPlan` so synthetic snapshots are anchored to the same
  /// ordering the engine produces.
  Future<List<String>> getOrderedRefs(CurriculumId curriculumId) async {
    final contentItems = await _contentRepository.getLeafItems(curriculumId);
    final customOrder = await _learningOrderRepository.getOrder(curriculumId);
    return _buildOrderedRefs(contentItems, customOrder);
  }

  /// Same ordering as [getOrderedRefs] but returns the full
  /// [SchedulerContentItem]s. Used by the back-fill builder so synthetic
  /// snapshots can group leaves by coarse unit (perek / daf / siman) when
  /// the goal's paceGranularity calls for it.
  Future<List<SchedulerContentItem>> getOrderedLeafItems(
    CurriculumId curriculumId,
  ) async {
    final contentItems = await _contentRepository.getLeafItems(curriculumId);
    final customOrder = await _learningOrderRepository.getOrder(curriculumId);
    final orderedRefs = _buildOrderedRefs(contentItems, customOrder);
    final byRef = {for (final c in contentItems) c.sefariaRef: c};
    return [
      for (final ref in orderedRefs)
        if (byRef[ref] != null) byRef[ref]!,
    ];
  }

  /// Calculate new items per day for the legacy (non-snapshot) adaptive path.
  ///
  /// **Zero-floor handling (DNI-346):** the old code applied a proportional
  /// chazara-load reduction and then forced the result up to at least 1 with
  /// `max(1, baseRate)`. This collapsed a 500-item-backlog user (who needs
  /// 5/day to hit their deadline) down to 1/day whenever chazara was heavy.
  ///
  /// The correct behaviour:
  /// - [baseRate] is derived from deadline or pace math alone — chazara items
  ///   are additional study work that does **not** shrink the new-learning
  ///   requirement.
  /// - If [chazaraCount] ≥ some high threshold, we still deliver the full
  ///   [baseRate] so the user stays on track.
  /// - The zero-floor (return 0) fires only when [remainingNewItems] is 0 —
  ///   there is nothing left to learn.
  /// - The minimum-1 floor fires only when [baseRate] > 0 and the study-day
  ///   math would produce a positive (non-zero) obligation — this ensures
  ///   at least one item of forward progress on any non-zero obligation day.
  ///
  /// The **boundary case** ("deep backlog locks new learning to 1/day"):
  /// a user with 10 remaining items over 100 study days gets
  /// `ceil(10/100) = 1` from the deadline formula. That 1 is the correct
  /// answer — it is not collapsed from a higher value.
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
        // Prefer an exact count of study days through the deadline window
        // (see [ScheduleConfig.studyDaysInDeadlineWindow]).
        final int studyDaysRemaining;
        final exact = config.studyDaysInDeadlineWindow;
        if (exact != null && exact > 0) {
          studyDaysRemaining = exact;
        } else {
          final approx = (daysRemaining * config.studyDaysPerWeek / 7).ceil();
          studyDaysRemaining = approx > 0 ? approx : 1;
        }
        if (studyDaysRemaining <= 0) {
          baseRate = (remainingNewItems * 0.1).ceil();
        } else {
          baseRate = (remainingNewItems / studyDaysRemaining).ceil();
        }
      }
    }

    // Explicit zero-floor: if baseRate is 0 (e.g. past deadline with very
    // few items and extremely conservative 10% rule rounded to 0), return 0.
    // Do NOT apply a forced-minimum of 1 here — that was the old bug.
    if (baseRate <= 0) return 0;

    // Chazara tasks are shown in addition to new learning, not instead of it.
    // The chazara load does not reduce the new-learning obligation — the user
    // still needs to reach their deadline. We do not apply a proportional
    // chazara penalty to baseRate.
    //
    // Cap by remaining items so we never emit more tasks than exist.
    return min(baseRate, remainingNewItems);
  }

  /// Returns `true` when [itemCompletions] contains a **genuine** completion
  /// at [stageOrder] — i.e. one that is not the bulk-prior sentinel date.
  ///
  /// Sentinel completions (`DateTime.utc(2000, 1, 1)`) indicate that the item
  /// was "marked prior" in bulk before this app was used. They must not be
  /// counted as real first-stage completions when deciding whether to surface
  /// new-learning tasks for that item.
  ///
  /// Comparison uses [DateTime.millisecondsSinceEpoch] to avoid UTC-vs-local
  /// inequality introduced by Drift reading integer epoch columns as local time.
  bool _isGenuinelyCompletedAtStage(
    Map<int, DateTime>? itemCompletions,
    int stageOrder,
  ) {
    if (itemCompletions == null) return false;
    final completedAt = itemCompletions[stageOrder];
    if (completedAt == null) return false;
    return completedAt.millisecondsSinceEpoch != kBulkPriorSentinelMs;
  }
}
