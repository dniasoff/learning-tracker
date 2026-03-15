import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

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
  static PaceStatus calculate({
    required DateTime goalStartDate,
    required DateTime goalDeadline,
    required int totalItems,
    required int completedItems,
    required Map<DateTime, int> dailyCompletionCounts,
    required DateTime today,
  }) {
    // Calculate expected items by today using linear interpolation
    final totalDays = goalDeadline.difference(goalStartDate).inDays;
    final elapsedDays = today.difference(goalStartDate).inDays;

    if (totalDays <= 0) {
      // Deadline is at or before start — treat as behind if not done
      final status = completedItems >= totalItems
          ? PaceStatusType.ahead
          : PaceStatusType.behind;
      return PaceStatus(
        status: status,
        daysDelta: 0,
        projectedCompletionDate: null,
        rollingAverage: _rolling7DayAverage(dailyCompletionCounts, today),
      );
    }

    final expectedItemsPerDay = totalItems / totalDays;
    final expectedByToday = (expectedItemsPerDay * elapsedDays).clamp(
      0,
      totalItems,
    );

    // Days delta: how many days ahead or behind
    // If completed > expected, user is ahead; calculate how many days of work
    // the surplus represents
    final itemsDelta = completedItems - expectedByToday;
    final daysDelta = expectedItemsPerDay > 0
        ? (itemsDelta / expectedItemsPerDay).round()
        : 0;

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

    // Projected completion date
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

    return PaceStatus(
      status: status,
      daysDelta: daysDelta,
      projectedCompletionDate: projectedDate,
      rollingAverage: rollingAvg,
    );
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
