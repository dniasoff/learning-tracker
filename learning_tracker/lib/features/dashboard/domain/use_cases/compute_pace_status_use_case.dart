import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/pace_derivation.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';

/// Input bundle for [ComputePaceStatusUseCase].
///
/// All heavy lifting (fetching from DB, deriving study-day counts) is done
/// by the *caller* before constructing this object. The use-case itself is
/// pure: no IO, easily unit-tested.
class PaceStatusInput {
  const PaceStatusInput({
    required this.paceTarget,
    required this.completedItems,
    required this.dailyCompletionCounts,
    required this.totalItems,
    required this.today,
    this.studyDaysInWindow,
    this.studyDaysPerWeek,
  });

  /// The sealed goal-mode discriminant (from [GoalEntity.paceTarget] or
  /// reconstructed from the raw Drift [Goal] row).
  ///
  /// `null` → no goal set; the use-case returns `null` immediately.
  final PaceTarget? paceTarget;

  /// Number of distinct completed sefariaRefs for this curriculum + track.
  final int completedItems;

  /// Map of UTC day → completion count for rolling-average computation.
  final Map<DateTime, int> dailyCompletionCounts;

  /// Total leaf items in the curriculum scope (from `scopedItemCountProvider`).
  final int totalItems;

  /// Current date/time used for pace projection (injected for testability).
  final DateTime today;

  /// Number of study days between today and the deadline (inclusive).
  /// Required for [DeadlineTarget] goals.
  final int? studyDaysInWindow;

  /// Number of study days per calendar week for the track.
  /// Required for [DeadlineTarget] goals.
  final int? studyDaysPerWeek;
}

/// Pure use-case: converts a [PaceTarget] + completion counts into a
/// [PaceStatus], or `null` when no projection is possible.
///
/// ## B3 note
/// Deadline goals ALWAYS yield a projection via [PaceCalculator.calculateForPaceGoal].
/// When the goal was back-dated (enrolment date < today), the overdue catch-up
/// tasks already appear in the scheduler — see `programSchedule()` anchor path.
/// The pace projection here is orthogonal: it shows how far behind the user is,
/// which is correct for a back-dated start.
class ComputePaceStatusUseCase {
  const ComputePaceStatusUseCase();

  /// Computes the pace status for [input].
  ///
  /// Returns `null` when:
  /// - [PaceStatusInput.paceTarget] is `null` (no goal set).
  /// - Goal is a [DeadlineTarget] but study-day data is unavailable.
  PaceStatus? execute(PaceStatusInput input) {
    switch (input.paceTarget) {
      // ---------------------------------------------------------------
      // Pace-based goal
      // ---------------------------------------------------------------
      case PacePeriodTarget(:final rate, :final period):
        final dailyRate = PaceCalculator.paceToDaily(rate, period);
        return PaceCalculator.calculateForPaceGoal(
          targetPacePerDay: dailyRate,
          totalItems: input.totalItems,
          completedItems: input.completedItems,
          dailyCompletionCounts: input.dailyCompletionCounts,
          today: input.today,
        );

      // ---------------------------------------------------------------
      // Deadline-based goal
      //
      // A deadline goal ALWAYS yields a projection: derive a pace from
      // the deadline + scope + study-day density and hand off to
      // `calculateForPaceGoal`. Unlike `PaceCalculator.calculate` (which
      // is null on day one), `calculateForPaceGoal` projects
      // deterministically — so "No projection" can never appear for a
      // track with a deadline.
      // ---------------------------------------------------------------
      case DeadlineTarget():
        final studyDaysInWindow = input.studyDaysInWindow ?? 0;
        final studyDaysPerWeek = input.studyDaysPerWeek ?? 5;
        final derived = derivePaceFromDeadline(
          totalScopeItems: input.totalItems,
          studyDaysInWindow: studyDaysInWindow,
          studyDaysPerWeek: studyDaysPerWeek,
        );
        final dailyRate = PaceCalculator.paceToDaily(
          derived.paceValue,
          derived.pacePeriod,
        );
        return PaceCalculator.calculateForPaceGoal(
          targetPacePerDay: dailyRate,
          totalItems: input.totalItems,
          completedItems: input.completedItems,
          dailyCompletionCounts: input.dailyCompletionCounts,
          today: input.today,
        );

      case null:
        return null;
    }
  }

  /// Helper: builds a UTC-normalised daily count map from raw completion rows.
  ///
  /// Exposed as a static helper so callers (provider or parent aggregator)
  /// can share the same normalisation logic.
  static Map<DateTime, int> buildDailyCounts(Iterable<DateTime> completedAts) {
    final counts = <DateTime, int>{};
    for (final completedAt in completedAts) {
      final local = DateUtils.extractLocalDate(completedAt);
      final utcDay = DateTime.utc(local.year, local.month, local.day);
      counts[utcDay] = (counts[utcDay] ?? 0) + 1;
    }
    return counts;
  }
}
