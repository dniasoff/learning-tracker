import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart'
    show DateTimeFactory;
import 'package:learning_tracker/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';

/// Aggregated analytics data for the parent dashboard.
class ParentDashboardData {
  final List<CurriculumSummary> curricula;
  final int globalPoints;
  final int currentStreak;
  final int maxStreak;
  final List<RecentCompletion> recentCompletions;
  final EngagementMetrics engagement;

  const ParentDashboardData({
    required this.curricula,
    required this.globalPoints,
    required this.currentStreak,
    required this.maxStreak,
    required this.recentCompletions,
    required this.engagement,
  });
}

/// Per-curriculum summary for the parent dashboard.
class CurriculumSummary {
  final CurriculumId curriculum;
  final double completionPercentage;
  final PaceStatusType paceStatus;
  final int points;

  const CurriculumSummary({
    required this.curriculum,
    required this.completionPercentage,
    required this.paceStatus,
    required this.points,
  });
}

/// A recent completion event for display.
class RecentCompletion {
  final String sefariaRef;
  final String curriculumId;
  final DateTime completedAt;
  final int points;

  const RecentCompletion({
    required this.sefariaRef,
    required this.curriculumId,
    required this.completedAt,
    required this.points,
  });
}

/// Engagement metrics for the parent dashboard.
class EngagementMetrics {
  final int daysActiveThisWeek;
  final double averageDailyCompletions;

  const EngagementMetrics({
    required this.daysActiveThisWeek,
    required this.averageDailyCompletions,
  });
}

/// Read-only aggregator that computes parent dashboard analytics from existing data.
///
/// Scoped to a single profile so the parent view always reflects the
/// currently viewed child, never a mix across profiles on the account.
class ParentDashboardAggregator {
  final UserDatabase _db;
  final int _profileId;
  final StageDefinitionRepository? _stageRepository;
  late final StreakStateProvider _streakProvider;

  ParentDashboardAggregator(
    this._db, {
    int profileId = 0,
    StageDefinitionRepository? stageRepository,
  }) : _profileId = profileId,
       _stageRepository = stageRepository {
    _streakProvider = StreakStateProvider(
      db: _db,
      clock: const SystemLocalDayClock(),
    );
  }

  /// Compute the full dashboard data snapshot.
  ///
  /// [now] defaults to the current time; pass explicitly for testability.
  Future<ParentDashboardData> compute({DateTime? now}) async {
    now ??= DateTimeFactory.nowLocal();
    final completions = await _db.completionDao.getCompletionsByProfile(
      _profileId,
    );
    final streak = await _streakProvider.read(profileId: _profileId);
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
    final curriculaSummaries = <CurriculumSummary>[];
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
  Future<double> computeCompletionPercentage(CurriculumId curriculum) async {
    final completions = await _db.completionDao
        .getCompletionsByCurriculumAndProfile(
          curriculum.storageKey,
          _profileId,
        );
    final stages = _stageRepository != null
        ? await _stageRepository.getStagesForCurriculum(curriculum)
        : const <domain_stage.StageDefinition>[];
    if (stages.isEmpty || completions.isEmpty) return 0.0;

    final totalStages = stages.length;
    final completionsByRef = <String, Set<int>>{};
    for (final c in completions) {
      completionsByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
    }

    final totalItems = await _db.learningOrderDao.countByCurriculum(
      curriculum.storageKey,
    );
    if (totalItems == 0) return 0.0;

    var fullyCompleted = 0;
    for (final stageSet in completionsByRef.values) {
      if (stageSet.length >= totalStages) fullyCompleted++;
    }

    return fullyCompleted / totalItems;
  }

  Future<CurriculumSummary> _computeCurriculumSummary(
    CurriculumId curriculum,
    List<Completion> completions,
    DateTime now,
  ) async {
    final completionPct = await computeCompletionPercentage(curriculum);
    final points = completions.fold<int>(0, (sum, c) => sum + c.points);
    final paceStatus = await _computePaceStatus(curriculum, completions, now);

    return CurriculumSummary(
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
