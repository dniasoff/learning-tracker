import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/pace_derivation.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';

/// Input bundle for [ComputePaceStatusUseCase].
///
/// All heavy lifting (fetching from DB, deriving study-day counts) is done
/// by the *caller* before constructing this object. The use-case itself is
/// pure: no IO, easily unit-tested.
class PaceStatusInput {
  const PaceStatusInput({
    required this.goal,
    required this.completedItems,
    required this.dailyCompletionCounts,
    required this.totalItems,
    required this.today,
    this.studyDaysInWindow,
    this.studyDaysPerWeek,
  });

  /// The goal row to compute pace for.
  final Goal goal;

  /// Number of distinct completed sefariaRefs for this curriculum + track.
  final int completedItems;

  /// Map of UTC day → completion count for rolling-average computation.
  final Map<DateTime, int> dailyCompletionCounts;

  /// Total leaf items in the curriculum scope (from `scopedItemCountProvider`).
  final int totalItems;

  /// Current date/time used for pace projection (injected for testability).
  final DateTime today;

  /// Number of study days between today and the deadline (inclusive).
  /// Required when the goal has a `targetDate` but no stored `paceValue`.
  final int? studyDaysInWindow;

  /// Number of study days per calendar week for the track.
  /// Required when the goal has a `targetDate` but no stored `paceValue`.
  final int? studyDaysPerWeek;
}

/// Pure use-case: converts a [Goal] row + completion counts into a
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
  /// - Goal type is 'deadline' but no `targetDate` is set.
  PaceStatus? execute(PaceStatusInput input) {
    final goal = input.goal;

    // ---------------------------------------------------------------
    // Pace-based goal
    // ---------------------------------------------------------------
    if (goal.goalType == 'pace' &&
        goal.paceValue != null &&
        goal.pacePeriod != null) {
      final dailyRate = PaceCalculator.paceToDaily(
        goal.paceValue!,
        goal.pacePeriod!,
      );
      return PaceCalculator.calculateForPaceGoal(
        targetPacePerDay: dailyRate,
        totalItems: input.totalItems,
        completedItems: input.completedItems,
        dailyCompletionCounts: input.dailyCompletionCounts,
        today: input.today,
      );
    }

    // ---------------------------------------------------------------
    // Deadline-based goal
    //
    // A deadline goal ALWAYS yields a projection: prefer the explicit
    // pace the wizard stored, otherwise derive one from the deadline +
    // scope + study-day density. `calculateForPaceGoal` projects
    // deterministically from the target pace (no completion history
    // needed), so "No projection" can never appear for a track that
    // has a deadline — unlike `PaceCalculator.calculate`, whose
    // rolling-average projection is null on day one.
    // ---------------------------------------------------------------
    if (goal.targetDate == null) return null;

    var paceValue = goal.paceValue;
    var pacePeriod = goal.pacePeriod;
    if (paceValue == null || pacePeriod == null) {
      final studyDaysInWindow = input.studyDaysInWindow ?? 0;
      final studyDaysPerWeek = input.studyDaysPerWeek ?? 5;
      final derived = derivePaceFromDeadline(
        totalScopeItems: input.totalItems,
        studyDaysInWindow: studyDaysInWindow,
        studyDaysPerWeek: studyDaysPerWeek,
      );
      paceValue = derived.paceValue;
      pacePeriod = derived.pacePeriod;
    }

    final dailyRate = PaceCalculator.paceToDaily(paceValue, pacePeriod);
    return PaceCalculator.calculateForPaceGoal(
      targetPacePerDay: dailyRate,
      totalItems: input.totalItems,
      completedItems: input.completedItems,
      dailyCompletionCounts: input.dailyCompletionCounts,
      today: input.today,
    );
  }

  /// Helper: builds a UTC-normalised daily count map from raw completion rows.
  ///
  /// Exposed as a static helper so callers (provider or parent aggregator)
  /// can share the same normalisation logic.
  static Map<DateTime, int> buildDailyCounts(
    Iterable<DateTime> completedAts,
  ) {
    final counts = <DateTime, int>{};
    for (final completedAt in completedAts) {
      final local = DateUtils.extractLocalDate(completedAt);
      final utcDay = DateTime.utc(local.year, local.month, local.day);
      counts[utcDay] = (counts[utcDay] ?? 0) + 1;
    }
    return counts;
  }
}
