/// Data models for progress charts.
library;

/// A single day's completion count for bar/line charts.
class DailyCompletionData {
  final DateTime date;
  final int count;

  const DailyCompletionData({required this.date, required this.count});
}

/// A single bucket's per-stage breakdown for the two-colour Limudim &
/// Chazaros stacked bar chart on the Recent Activity screen.
///
/// - [limudCount] is the count of stage-1 completions (initial learning).
/// - [chazaraCount] is the count of stage ≥ 2 completions (review rounds).
///
/// [date] is the bucket start (midnight, local), consistent with
/// [DailyCompletionData.date].
class DailyLimudChazaraData {
  final DateTime date;
  final int limudCount;
  final int chazaraCount;

  const DailyLimudChazaraData({
    required this.date,
    required this.limudCount,
    required this.chazaraCount,
  });

  /// Total completions in the bucket (limud + chazara).
  int get total => limudCount + chazaraCount;
}

/// Cumulative progress at a point in time.
class CumulativeProgressPoint {
  final DateTime date;
  final int total;

  const CumulativeProgressPoint({required this.date, required this.total});
}

/// Target line point for cumulative chart overlay.
class TargetLinePoint {
  final DateTime date;
  final double expectedTotal;

  const TargetLinePoint({required this.date, required this.expectedTotal});
}

/// Daily points earned for the points-over-time chart.
class DailyPointsData {
  final DateTime date;
  final int points;

  const DailyPointsData({required this.date, required this.points});
}

/// Time range filter for charts.
enum ChartTimeRange {
  last7Days,
  last30Days,
  allTime;

  String get displayName => switch (this) {
    ChartTimeRange.last7Days => '7 Days',
    ChartTimeRange.last30Days => '30 Days',
    ChartTimeRange.allTime => 'All Time',
  };
}

/// Scope filter for charts.
enum ChartScope { crossCurriculum, perCurriculum }
