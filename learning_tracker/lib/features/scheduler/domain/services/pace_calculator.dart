import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Callback invoked when pace drops to [PaceStatusType.behind].
///
/// [daysBehind] is the absolute number of days behind (always positive).
// TODO(Epic-12): Wire this callback into the notification system (DNI notification story).
typedef PaceBehindCallback = void Function(int daysBehind);

/// Pure computation for pace tracking.
///
/// Calculates whether the user is ahead, behind, or on-pace for a goal,
/// plus projected completion date using a rolling 7-day average.
class PaceCalculator {
  /// Calculate pace status for a goal.
  ///
  /// [goalStartDate] — when the goal was created / tracking started
  /// [goalDeadline] — target completion date
  /// [totalItems] — total items to complete for the goal
  /// [completedItems] — items completed so far (personal track only)
  /// [dailyCompletionCounts] — map of date → count for recent days
  ///   (at least 7 days of history for rolling average)
  /// [today] — current date (UTC)
  /// [onPaceBehind] — optional callback fired when status is behind.
  // TODO(Epic-12): Epic 12 notification system should pass an [onPaceBehind]
  //  callback to trigger "falling behind" notifications.
  static PaceStatus calculate({
    required DateTime goalStartDate,
    required DateTime goalDeadline,
    required int totalItems,
    required int completedItems,
    required Map<DateTime, int> dailyCompletionCounts,
    required DateTime today,
    PaceBehindCallback? onPaceBehind,
  }) {
    // Calculate expected items by today using linear interpolation
    final totalDays = goalDeadline.difference(goalStartDate).inDays;
    final elapsedDays = today.difference(goalStartDate).inDays;

    if (totalDays <= 0) {
      // Deadline is at or before start — treat as behind if not done
      final status = completedItems >= totalItems
          ? PaceStatusType.ahead
          : PaceStatusType.behind;
      final result = PaceStatus(
        status: status,
        daysDelta: 0,
        delta: const DateScheduleDelta(DateDelta(0)),
        projectedCompletionDate: null,
        rollingAverage: _rolling7DayAverage(dailyCompletionCounts, today),
      );
      if (result.status == PaceStatusType.behind) {
        onPaceBehind?.call(result.daysDelta.abs());
      }
      return result;
    }

    final expectedItemsPerDay = totalItems / totalDays;
    final expectedByToday = (expectedItemsPerDay * elapsedDays).clamp(
      0,
      totalItems,
    );

    // Days delta: how many days ahead or behind
    // If completed > expected, user is ahead; calculate how many days of work
    // the surplus represents
    final rawItemsDelta = completedItems - expectedByToday;
    final rawDaysDelta = expectedItemsPerDay > 0
        ? rawItemsDelta / expectedItemsPerDay
        : 0.0;

    // Use floor for ahead (don't over-report partial days ahead) and
    // negative-ceil for behind (any fractional behind counts as behind).
    int daysDelta;
    if (rawDaysDelta > 0) {
      daysDelta = rawDaysDelta.floor();
    } else if (rawDaysDelta < 0) {
      daysDelta = -(-rawDaysDelta).ceil();
    } else {
      daysDelta = 0;
    }

    PaceStatusType status;
    if (daysDelta > 0) {
      status = PaceStatusType.ahead;
    } else if (daysDelta < 0) {
      status = PaceStatusType.behind;
    } else {
      status = PaceStatusType.onPace;
    }

    // Rolling 7-day average
    final rollingAvg = _rolling7DayAverage(dailyCompletionCounts, today);

    // Projected completion date — guard against day-1 (no events yet):
    // only project when rollingAvg > 0 so we never emit NaN / Infinity.
    DateTime? projectedDate;
    if (rollingAvg > 0) {
      final remainingItems = totalItems - completedItems;
      if (remainingItems <= 0) {
        projectedDate = today; // Already done
      } else {
        final daysNeeded = (remainingItems / rollingAvg).ceil();
        projectedDate = today.add(Duration(days: daysNeeded));
      }
    }
    // If rollingAvg == 0, projectedDate stays null (cannot project)

    final result = PaceStatus(
      status: status,
      daysDelta: daysDelta,
      delta: DateScheduleDelta(DateDelta(daysDelta)),
      projectedCompletionDate: projectedDate,
      rollingAverage: rollingAvg,
    );

    if (result.status == PaceStatusType.behind) {
      onPaceBehind?.call(result.daysDelta.abs());
    }

    return result;
  }

  /// Calculate pace status for a pace-based goal (no deadline).
  ///
  /// [targetPacePerDay] — target items per day (already converted from per_week)
  /// [totalItems] — total items to complete for the goal
  /// [completedItems] — items completed so far
  /// [dailyCompletionCounts] — map of date → count for recent days
  /// [today] — current date (UTC)
  static PaceStatus calculateForPaceGoal({
    required double targetPacePerDay,
    required int totalItems,
    required int completedItems,
    required Map<DateTime, int> dailyCompletionCounts,
    required DateTime today,
  }) {
    final rollingAvg = _rolling7DayAverage(dailyCompletionCounts, today);
    final remainingItems = (totalItems - completedItems).clamp(0, totalItems);

    // Determine status by comparing rolling average to target pace
    PaceStatusType status;
    if ((rollingAvg - targetPacePerDay).abs() <= 0.1) {
      status = PaceStatusType.onPace;
    } else if (rollingAvg > targetPacePerDay) {
      status = PaceStatusType.ahead;
    } else {
      status = PaceStatusType.behind;
    }

    // Weekly item surplus/deficit (not calendar days — see PaceStatus.daysDelta)
    final daysDelta = ((rollingAvg - targetPacePerDay) * 7).round();

    // Projected completion date using target pace.
    // Projection uses the fixed target rate (not rollingAvg) so it is always
    // available from day 1 — rolling avg is used for status, not projection.
    DateTime? projectedDate;
    if (targetPacePerDay > 0 && remainingItems > 0) {
      final daysNeeded = (remainingItems / targetPacePerDay).ceil();
      projectedDate = today.add(Duration(days: daysNeeded));
    } else if (remainingItems <= 0) {
      projectedDate = today;
    }

    return PaceStatus(
      status: status,
      daysDelta: daysDelta,
      delta: PaceScheduleDelta(PaceDelta(daysDelta)),
      projectedCompletionDate: projectedDate,
      rollingAverage: rollingAvg,
    );
  }

  /// Convert a pace value and unit to a daily rate.
  ///
  /// For 'per_day', returns the value directly.
  /// For 'per_week', divides by 7.
  static double paceToDaily(int paceValue, String pacePeriod) {
    if (pacePeriod == 'per_week') {
      return paceValue / 7.0;
    }
    return paceValue.toDouble();
  }

  /// Compute the rolling 7-day average of daily completions.
  ///
  /// Looks at the 7 days ending yesterday (today's work is in progress).
  static double _rolling7DayAverage(
    Map<DateTime, int> dailyCompletionCounts,
    DateTime today,
  ) {
    var total = 0;
    for (var i = 1; i <= 7; i++) {
      final date = DateTime.utc(today.year, today.month, today.day - i);
      final normalized = DateTime.utc(date.year, date.month, date.day);
      total += dailyCompletionCounts[normalized] ?? 0;
    }
    return total / 7.0;
  }
}
