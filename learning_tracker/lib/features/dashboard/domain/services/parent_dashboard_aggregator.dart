import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

part 'parent_dashboard_aggregator.freezed.dart';

/// Aggregated analytics data for the parent dashboard.
@freezed
abstract class ParentDashboardData with _$ParentDashboardData {
  const factory ParentDashboardData({
    required List<ParentCurriculumSummary> curricula,
    required int globalPoints,
    required int currentStreak,
    required int maxStreak,
    required List<RecentCompletion> recentCompletions,
    required EngagementMetrics engagement,
  }) = _ParentDashboardData;
}

/// Per-curriculum summary for the parent dashboard.
@freezed
abstract class ParentCurriculumSummary with _$ParentCurriculumSummary {
  const factory ParentCurriculumSummary({
    required CurriculumId curriculum,
    required double completionPercentage,
    required PaceStatusType paceStatus,
    required int points,
  }) = _ParentCurriculumSummary;
}

/// A recent completion event for display.
@freezed
abstract class RecentCompletion with _$RecentCompletion {
  const factory RecentCompletion({
    required String sefariaRef,
    required String curriculumId,
    required DateTime completedAt,
    required int points,
  }) = _RecentCompletion;
}

/// Engagement metrics for the parent dashboard.
@freezed
abstract class EngagementMetrics with _$EngagementMetrics {
  const factory EngagementMetrics({
    required int daysActiveThisWeek,
    required double averageDailyCompletions,
  }) = _EngagementMetrics;
}

/// A [LocalDayClock] fixed to a single instant.
///
/// Used by [ParentDashboardAggregator.compute] to derive the streak
/// sub-computation's "today" from its own `now` argument, so the whole
/// snapshot — including streak — is determined by one instant instead of
/// two independent clock reads (AUD-dashboard-07).
class _InstantLocalDayClock implements LocalDayClock {
  const _InstantLocalDayClock(this._instant);

  final DateTime _instant;

  @override
  DateTime nowUtc() => _instant.toUtc();

  @override
  DateTime today() {
    final local = _instant.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// Read-only aggregator that computes parent dashboard analytics from existing data.
///
/// Scoped to a single profile so the parent view always reflects the
/// currently viewed child, never a mix across profiles on the account.
class ParentDashboardAggregator {
  final UserDatabase _db;
  final int _profileId;
  final StageDefinitionRepository? _stageRepository;
  final LocalDayClock _clock;

  /// [clock] defaults to the real system clock; inject a [FakeLocalDayClock]
  /// (or any other [LocalDayClock]) in tests so both the default `now` used
  /// by [compute] and its streak sub-computation are fully hermetic (AUD-dashboard-07).
  ParentDashboardAggregator(
    this._db, {
    int profileId = 0,
    StageDefinitionRepository? stageRepository,
    LocalDayClock clock = const SystemLocalDayClock(),
  }) : _profileId = profileId,
       _stageRepository = stageRepository,
       _clock = clock;

  /// Compute the full dashboard data snapshot.
  ///
  /// [now] defaults to [clock]'s current instant; pass explicitly for
  /// testability. The streak sub-computation derives its "today" from this
  /// same [now] (via a clock fixed to it), rather than reading [_clock]
  /// independently a second time inside `StreakStateProvider` — so a single
  /// [now] value fully determines the entire snapshot, including streak,
  /// closing the day-boundary race where an independent clock read could
  /// otherwise see a different "today" than the rest of the snapshot.
  Future<ParentDashboardData> compute({DateTime? now}) async {
    now ??= _clock.nowUtc().toLocal();
    final streakProvider = StreakStateProvider(
      db: _db,
      clock: _InstantLocalDayClock(now),
    );
    final completions = await _db.completionDao.getCompletionsByProfile(
      _profileId,
    );
    final streak = await streakProvider.read(profileId: _profileId);
    final activeCurriculaKeys = await _db.activeCurriculumDao
        .getActiveCurriculaByProfile(_profileId);

    final activeCurricula = activeCurriculaKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          return matches.isNotEmpty ? matches.first : null;
        })
        .whereType<CurriculumId>()
        .toList();

    // Global points
    final globalPoints = completions.fold<int>(0, (sum, c) => sum + c.points);

    // Per-curriculum summaries
    final curriculaSummaries = <ParentCurriculumSummary>[];
    for (final curriculum in activeCurricula) {
      final summary = await _computeCurriculumSummary(
        curriculum,
        completions
            .where((c) => c.curriculumId == curriculum.storageKey)
            .toList(),
        now,
      );
      curriculaSummaries.add(summary);
    }

    // Recent completions (last 7 days, using local time for consistency)
    final nowLocal = now.toLocal();
    final sevenDaysAgoLocal = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
    ).subtract(const Duration(days: 7));
    final recent =
        completions
            .where((c) => c.completedAt.toLocal().isAfter(sevenDaysAgoLocal))
            .map(
              (c) => RecentCompletion(
                sefariaRef: c.sefariaRef,
                curriculumId: c.curriculumId,
                completedAt: c.completedAt,
                points: c.points,
              ),
            )
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    // Engagement metrics
    final engagement = _computeEngagement(completions, now);

    return ParentDashboardData(
      curricula: curriculaSummaries,
      globalPoints: globalPoints,
      currentStreak: streak.currentStreak,
      maxStreak: streak.maxStreak,
      recentCompletions: recent,
      engagement: engagement,
    );
  }

  /// Compute completion percentage for a curriculum.
  ///
  /// ### Layer 3 migration (trackAchievement tier)
  ///
  /// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) via the
  /// tier-filtered DAO so that lifetimeOnly imports are excluded from the
  /// parent dashboard metric.
  ///
  /// Also aligns with the canonical `every(requiredStageOrder in doneStages)`
  /// formula from [TrackCompletionService], replacing the old
  /// `stageSet.length >= totalStages` check which incorrectly matched items
  /// with completions spread across different stages rather than the required set.
  Future<double> computeCompletionPercentage(CurriculumId curriculum) async {
    final stages = _stageRepository != null
        ? await _stageRepository.getStagesForCurriculum(curriculum)
        : const <domain_stage.StageDefinition>[];
    if (stages.isEmpty) return 0.0;

    // Layer 3: use trackAchievement tier (excludes lifetimeOnly).
    final completions = await _db.completionDao.getCompletionsByTier(
      profileId: _profileId,
      tier: CompletionTierFilter.trackAchievement,
      curriculumId: curriculum,
    );
    if (completions.isEmpty) return 0.0;

    final totalItems = await _db.learningOrderDao.countByCurriculum(
      curriculum.storageKey,
    );
    if (totalItems == 0) return 0.0;

    // Canonical formula: item is "done" when every required stageOrder has
    // a completion. Uses stageOrder values (same as stageId in completion_events).
    final requiredStageOrders = stages.map((s) => s.stageOrder).toSet();
    final completedStagesByRef = <String, Set<int>>{};
    for (final c in completions) {
      completedStagesByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
    }

    var fullyCompleted = 0;
    for (final doneStages in completedStagesByRef.values) {
      if (requiredStageOrders.every(doneStages.contains)) fullyCompleted++;
    }

    return (fullyCompleted / totalItems).clamp(0.0, 1.0);
  }

  Future<ParentCurriculumSummary> _computeCurriculumSummary(
    CurriculumId curriculum,
    List<Completion> completions,
    DateTime now,
  ) async {
    final completionPct = await computeCompletionPercentage(curriculum);
    final points = completions.fold<int>(0, (sum, c) => sum + c.points);
    final paceStatus = await _computePaceStatus(curriculum, completions, now);

    return ParentCurriculumSummary(
      curriculum: curriculum,
      completionPercentage: completionPct,
      paceStatus: paceStatus,
      points: points,
    );
  }

  Future<PaceStatusType> _computePaceStatus(
    CurriculumId curriculum,
    List<Completion> completions,
    DateTime now,
  ) async {
    final goals = await _db.goalDao.getGoalsByCurriculumAndProfile(
      curriculum.storageKey,
      _profileId,
    );
    if (goals.isEmpty) return PaceStatusType.onPace;

    final goal = goals.first;

    // Daily counts via shared helper (eliminates duplicate normalisation logic).
    final dailyCounts = ComputePaceStatusUseCase.buildDailyCounts(
      completions.map((c) => c.completedAt),
    );

    // Count unique content items completed.
    final uniqueRefs = completions.map((c) => c.sefariaRef).toSet();

    // Use actual total from curriculum content.
    final totalItems = await _db.learningOrderDao.countByCurriculum(
      curriculum.storageKey,
    );
    final totalEstimate = totalItems > 0 ? totalItems : 100;

    // Reconstruct PaceTarget from the raw Drift Goal row.
    final PaceTarget? paceTarget;
    if (goal.goalType == 'deadline' && goal.targetDate != null) {
      paceTarget = DeadlineTarget(goal.targetDate!.toUtc());
    } else if (goal.goalType == 'pace' &&
        goal.paceValue != null &&
        goal.pacePeriod != null) {
      paceTarget = PacePeriodTarget(
        rate: goal.paceValue!,
        period: goal.pacePeriod!,
      );
    } else {
      paceTarget = null;
    }

    // Delegate to the shared use-case (same algorithm as dashboardPaceStatus).
    const useCase = ComputePaceStatusUseCase();
    final paceStatus = useCase.execute(
      PaceStatusInput(
        paceTarget: paceTarget,
        completedItems: uniqueRefs.length,
        dailyCompletionCounts: dailyCounts,
        totalItems: totalEstimate,
        today: now,
      ),
    );
    return paceStatus?.status ?? PaceStatusType.onPace;
  }

  /// Compute engagement metrics from all completions.
  static EngagementMetrics computeEngagement(
    List<Completion> completions,
    DateTime now,
  ) {
    return _computeEngagementStatic(completions, now);
  }

  EngagementMetrics _computeEngagement(
    List<Completion> completions,
    DateTime now,
  ) {
    return _computeEngagementStatic(completions, now);
  }

  static EngagementMetrics _computeEngagementStatic(
    List<Completion> completions,
    DateTime now,
  ) {
    // Days active this week (Mon-Sun containing today)
    final localNow = now.toLocal();
    final weekStart = localNow.subtract(Duration(days: localNow.weekday - 1));
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final activeDays = <DateTime>{};

    for (final c in completions) {
      final localDate = c.completedAt.toLocal();
      final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);
      if (!dateOnly.isBefore(weekStartDate)) {
        activeDays.add(dateOnly);
      }
    }

    // Average daily completions over last 7 days
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentCount = completions
        .where((c) => c.completedAt.isAfter(sevenDaysAgo))
        .length;
    final avgDaily = recentCount / 7.0;

    return EngagementMetrics(
      daysActiveThisWeek: activeDays.length,
      averageDailyCompletions: avgDaily,
    );
  }
}
