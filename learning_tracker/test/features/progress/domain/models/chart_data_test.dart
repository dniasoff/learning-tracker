// Tests for ChartTimeRange.displayName — covers lines 42-45 (uncovered).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';

void main() {
  group('ChartTimeRange.displayName', () {
    test('last7Days returns "7 Days"', () {
      expect(ChartTimeRange.last7Days.displayName, '7 Days');
    });

    test('last30Days returns "30 Days"', () {
      expect(ChartTimeRange.last30Days.displayName, '30 Days');
    });

    test('allTime returns "All Time"', () {
      expect(ChartTimeRange.allTime.displayName, 'All Time');
    });

    test('all values have non-empty displayName', () {
      for (final range in ChartTimeRange.values) {
        expect(range.displayName, isNotEmpty);
      }
    });
  });
}
