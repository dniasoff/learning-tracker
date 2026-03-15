/// Status of a user's learning pace relative to their goal.
enum PaceStatusType { ahead, onPace, behind }

/// Result of a pace calculation for a curriculum goal.
class PaceStatus {
  /// Whether the user is ahead, on-pace, or behind.
  final PaceStatusType status;

  /// Number of days ahead (positive) or behind (negative).
  /// Zero for on-pace.
  final int daysDelta;

  /// Projected completion date based on rolling 7-day average.
  /// Null if no completions in the last 7 days (cannot project).
  final DateTime? projectedCompletionDate;

  /// Rolling 7-day average of daily completions.
  final double rollingAverage;

  const PaceStatus({
    required this.status,
    required this.daysDelta,
    this.projectedCompletionDate,
    required this.rollingAverage,
  });
}
