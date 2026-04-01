import 'package:learning_tracker/core/database/user/user_database.dart';

/// Trend direction for test scores.
enum ScoreTrend { improving, declining, stable, insufficient }

/// Result of score trend analysis.
class ScoreTrendResult {
  const ScoreTrendResult({
    required this.trend,
    required this.scores,
    this.message,
  });

  final ScoreTrend trend;
  final List<int> scores;
  final String? message;
}

/// Service for analyzing test scores and generating motivational messages.
class TestScoreService {
  const TestScoreService();

  /// Analyzes the trend of recent scores.
  ///
  /// Requires at least 2 scores for meaningful analysis.
  ScoreTrendResult analyzeTrend(List<TestScore> recentScores) {
    final scores = recentScores
        .map((s) => s.scorePercentage)
        .toList()
        .reversed
        .toList();

    if (scores.length < 2) {
      return ScoreTrendResult(trend: ScoreTrend.insufficient, scores: scores);
    }

    // Check if consistently improving
    var improving = true;
    var declining = true;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] <= scores[i - 1]) improving = false;
      if (scores[i] >= scores[i - 1]) declining = false;
    }

    if (improving) {
      final scoreStr = scores.map((s) => '$s%').join(' → ');
      return ScoreTrendResult(
        trend: ScoreTrend.improving,
        scores: scores,
        message:
            "Your last ${scores.length} scores: $scoreStr — you're on fire!",
      );
    }

    if (declining) {
      final scoreStr = scores.map((s) => '$s%').join(' → ');
      return ScoreTrendResult(
        trend: ScoreTrend.declining,
        scores: scores,
        message:
            'Your last ${scores.length} scores: $scoreStr — keep pushing, you can turn this around!',
      );
    }

    return ScoreTrendResult(trend: ScoreTrend.stable, scores: scores);
  }

  /// Validates a score percentage is in range [0, 100].
  bool isValidScore(int percentage) => percentage >= 0 && percentage <= 100;
}
