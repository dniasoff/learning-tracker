/// Result of a goal progress calculation.
class GoalProgress {
  /// Percentage of target completed (0.0 to 100.0+).
  final double percentComplete;

  /// Days remaining until deadline. Null if no deadline set.
  final int? daysRemaining;

  /// Items per day needed to meet the goal. Null if no deadline set.
  final double? itemsPerDay;

  /// Total items in the curriculum.
  final int totalItems;

  /// Number of items completed.
  final int completedItems;

  /// Number of items still needed to reach the target.
  final int remainingItems;

  const GoalProgress({
    required this.percentComplete,
    this.daysRemaining,
    this.itemsPerDay,
    required this.totalItems,
    required this.completedItems,
    required this.remainingItems,
  });
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
