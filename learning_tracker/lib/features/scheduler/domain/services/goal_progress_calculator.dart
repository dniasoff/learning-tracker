import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_progress_calculator.freezed.dart';

/// Result of a goal progress calculation.
@freezed
abstract class GoalProgress with _$GoalProgress {
  const factory GoalProgress({
    /// Percentage of target completed (0.0 to 100.0+).
    required double percentComplete,

    /// Days remaining until deadline. Null if no deadline set.
    int? daysRemaining,

    /// Items per day needed to meet the goal. Null if no deadline set.
    double? itemsPerDay,

    /// Total items in the curriculum.
    required int totalItems,

    /// Number of items completed.
    required int completedItems,

    /// Number of items still needed to reach the target.
    required int remainingItems,
  }) = _GoalProgress;
}

/// Computes goal progress metrics.
///
/// Pure computation — no side effects or database access.
class GoalProgressCalculator {
  /// Calculate progress for a goal given current completions.
  ///
  /// [targetPercent] — target completion percentage (e.g., 100.0)
  /// [targetDate] — deadline (null for no-deadline mode)
  /// [currentDate] — current date (UTC)
  /// [totalItems] — total items in the curriculum
  /// [completedItems] — number of unique items completed
  static GoalProgress calculate({
    required double targetPercent,
    required DateTime? targetDate,
    required DateTime currentDate,
    required int totalItems,
    required int completedItems,
  }) {
    if (totalItems == 0) {
      return GoalProgress(
        percentComplete: 0,
        daysRemaining: targetDate?.difference(currentDate).inDays,
        itemsPerDay: null,
        totalItems: 0,
        completedItems: 0,
        remainingItems: 0,
      );
    }

    final percentComplete = (completedItems / totalItems) * 100.0;
    final targetItems = (totalItems * targetPercent / 100.0).ceil();
    final remainingItems = (targetItems - completedItems).clamp(0, totalItems);

    int? daysRemaining;
    double? itemsPerDay;

    if (targetDate != null) {
      daysRemaining = targetDate.difference(currentDate).inDays;
      if (daysRemaining > 0 && remainingItems > 0) {
        itemsPerDay = remainingItems / daysRemaining;
      } else if (remainingItems > 0) {
        // Deadline passed or is today but items remain
        itemsPerDay = remainingItems.toDouble();
      } else {
        itemsPerDay = 0;
      }
    }
    // No deadline → daysRemaining and itemsPerDay stay null

    return GoalProgress(
      percentComplete: percentComplete,
      daysRemaining: daysRemaining,
      itemsPerDay: itemsPerDay,
      totalItems: totalItems,
      completedItems: completedItems,
      remainingItems: remainingItems,
    );
  }
}
