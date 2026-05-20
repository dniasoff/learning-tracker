import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Summary stats for a single curriculum on the dashboard.
class CurriculumSummary {
  const CurriculumSummary({
    required this.curriculumId,
    required this.completionPercentage,
    required this.paceStatus,
    required this.nextDueItem,
    required this.todayTaskCount,
    required this.lastCompletionAt,
  });

  final CurriculumId curriculumId;

  /// Overall completion percentage (0.0–1.0).
  final double completionPercentage;

  /// Pace indicator (null if no goal).
  final PaceStatus? paceStatus;

  /// Display label for the next due item, or null if none.
  final String? nextDueItem;

  /// Number of tasks due today for this curriculum.
  final int todayTaskCount;

  /// Timestamp of the most recent completion, or null if none.
  final DateTime? lastCompletionAt;
}

/// Dashboard-level aggregated stats across all active curricula.
class DashboardStats {
  const DashboardStats({
    required this.curriculumSummaries,
    required this.totalTasksToday,
    required this.activeCurriculaCount,
  });

  final List<CurriculumSummary> curriculumSummaries;
  final int totalTasksToday;
  final int activeCurriculaCount;

  /// The curriculum with the most recent completion (for "Continue learning").
  CurriculumSummary? get mostRecentlyActive {
    CurriculumSummary? best;
    for (final s in curriculumSummaries) {
      if (s.lastCompletionAt == null) continue;
      if (best == null || s.lastCompletionAt!.isAfter(best.lastCompletionAt!)) {
        best = s;
      }
    }
    return best;
  }
}

/// Aggregates dashboard stats across all active curricula.
///
/// Lives in `lib/core/services/` per P6 — depends only on domain models,
/// not on feature module internals. Callers supply pre-fetched data.
class CrossCurriculumAggregator {
  /// Build dashboard stats from pre-fetched per-curriculum data.
  ///
  /// [completionPercentages] maps each curriculum to its overall completion %.
  /// [paceStatuses] maps each curriculum to its pace status (null if no goal).
  /// [todayTaskCounts] maps each curriculum to its today task count.
  /// [nextDueItems] maps each curriculum to its next due item label.
  /// [lastCompletions] maps each curriculum to its most recent completion time.
  DashboardStats aggregate({
    required List<CurriculumId> activeCurricula,
    required Map<CurriculumId, double> completionPercentages,
    required Map<CurriculumId, PaceStatus?> paceStatuses,
    required Map<CurriculumId, int> todayTaskCounts,
    required Map<CurriculumId, String?> nextDueItems,
    required Map<CurriculumId, DateTime?> lastCompletions,
  }) {
    final summaries = <CurriculumSummary>[];
    var totalTasks = 0;

    for (final curriculum in activeCurricula) {
      final taskCount = todayTaskCounts[curriculum] ?? 0;
      totalTasks += taskCount;
      summaries.add(
        CurriculumSummary(
          curriculumId: curriculum,
          completionPercentage: completionPercentages[curriculum] ?? 0.0,
          paceStatus: paceStatuses[curriculum],
          nextDueItem: nextDueItems[curriculum],
          todayTaskCount: taskCount,
          lastCompletionAt: lastCompletions[curriculum],
        ),
      );
    }

    return DashboardStats(
      curriculumSummaries: summaries,
      totalTasksToday: totalTasks,
      activeCurriculaCount: activeCurricula.length,
    );
  }
}
