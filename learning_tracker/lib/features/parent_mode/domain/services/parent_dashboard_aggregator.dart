import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';

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
/// Does not create new data models — aggregates completions, streaks, points, and pace.
class ParentDashboardAggregator {
  final AppDatabase _db;

  ParentDashboardAggregator(this._db);

  /// Compute the full dashboard data snapshot.
  Future<ParentDashboardData> compute() async {
    final completions = await _db.completionDao.getAllCompletions();
    final streak = await _db.streakDao.getStreak();
    final activeCurriculaKeys = await _db.activeCurriculumDao
        .getActiveCurricula();

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
      );
      curriculaSummaries.add(summary);
    }

    // Recent completions (last 7 days)
    final now = DateTime.now().toUtc();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recent =
        completions
            .where((c) => c.completedAt.isAfter(sevenDaysAgo))
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
      currentStreak: streak?.currentStreak ?? 0,
      maxStreak: streak?.maxStreak ?? 0,
      recentCompletions: recent,
      engagement: engagement,
    );
  }

  /// Compute completion percentage for a curriculum.
  Future<double> computeCompletionPercentage(CurriculumId curriculum) async {
    final completions = await _db.completionDao.getCompletionsByCurriculum(
      curriculum.storageKey,
    );
    final stages = await _db.stageDao.getStageDefinitionsByCurriculum(
      curriculum.storageKey,
    );
    if (stages.isEmpty || completions.isEmpty) return 0.0;

    final totalStages = stages.length;
    final completionsByRef = <String, Set<int>>{};
    for (final c in completions) {
      completionsByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
    }

    var fullyCompleted = 0;
    for (final stageSet in completionsByRef.values) {
      if (stageSet.length >= totalStages) fullyCompleted++;
    }

    return completionsByRef.isNotEmpty
        ? fullyCompleted / completionsByRef.length
        : 0.0;
  }

  Future<CurriculumSummary> _computeCurriculumSummary(
    CurriculumId curriculum,
    List<Completion> completions,
  ) async {
    final completionPct = await computeCompletionPercentage(curriculum);
    final points = completions.fold<int>(0, (sum, c) => sum + c.points);
    final paceStatus = await _computePaceStatus(curriculum, completions);

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
  ) async {
    final goals = await _db.goalDao.getGoalsByCurriculum(curriculum.storageKey);
    if (goals.isEmpty) return PaceStatusType.onPace;

    final goal = goals.first;
    // targetDate is nullable — cannot compute pace without a deadline
    if (goal.targetDate == null) return PaceStatusType.onPace;

    final now = DateTime.now().toUtc();

    // Build daily completion counts
    final dailyCounts = <DateTime, int>{};
    for (final c in completions) {
      final localDate = DateUtils.extractLocalDate(c.completedAt);
      final normalized = DateTime.utc(
        localDate.year,
        localDate.month,
        localDate.day,
      );
      dailyCounts[normalized] = (dailyCounts[normalized] ?? 0) + 1;
    }

    // Count unique content items completed
    final uniqueRefs = completions.map((c) => c.sefariaRef).toSet();

    // Use targetPercent to estimate total items needed.
    // Since we don't have content count here, use completion count
    // relative to what's been touched as an approximation.
    final totalEstimate = uniqueRefs.isNotEmpty
        ? (uniqueRefs.length / (goal.targetPercent / 100)).ceil()
        : 100; // Default if no completions yet

    final pace = PaceCalculator.calculate(
      goalStartDate: goal.createdAt,
      goalDeadline: goal.targetDate!,
      totalItems: totalEstimate,
      completedItems: uniqueRefs.length,
      dailyCompletionCounts: dailyCounts,
      today: now,
    );

    return pace.status;
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
