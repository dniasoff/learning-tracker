/// Calculates suggested point thresholds for initial rewards during onboarding.
///
/// Based on curriculum size (total items) and daily pace, suggests milestone
/// thresholds that are achievable and evenly spaced.
class SuggestedThresholdsService {
  /// Calculate suggested point thresholds for rewards.
  ///
  /// [totalItems] is the total number of curriculum items across all selected
  /// curricula.
  /// [dailyPace] is the expected items per day (from goal setup).
  /// [pointsPerItem] defaults to 10 (stage 1 default).
  ///
  /// Returns a list of 3 suggested thresholds representing roughly
  /// 1 week, 1 month, and 3 months of effort.
  static List<int> calculate({
    required int totalItems,
    required int dailyPace,
    int pointsPerItem = 10,
  }) {
    if (totalItems <= 0 || dailyPace <= 0) {
      return [100, 500, 1000];
    }

    final dailyPoints = dailyPace * pointsPerItem;

    // ~1 week, ~1 month, ~3 months of steady learning
    final week = (dailyPoints * 7).roundToNearestMultiple(50);
    final month = (dailyPoints * 30).roundToNearestMultiple(100);
    final quarter = (dailyPoints * 90).roundToNearestMultiple(100);

    // Ensure they are distinct and ascending
    final thresholds = <int>{week, month, quarter}.toList()..sort();

    // If duplicates collapsed, fill in with sensible defaults
    while (thresholds.length < 3) {
      thresholds.add((thresholds.last * 2).roundToNearestMultiple(100));
    }

    return thresholds.take(3).toList();
  }
}

extension on int {
  /// Round to nearest multiple, with a minimum of [multiple].
  int roundToNearestMultiple(int multiple) {
    if (this <= multiple) return multiple;
    return ((this + multiple ~/ 2) ~/ multiple) * multiple;
  }
}
