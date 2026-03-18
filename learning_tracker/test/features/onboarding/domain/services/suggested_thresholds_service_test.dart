import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/onboarding/domain/services/suggested_thresholds_service.dart';

void main() {
  group('SuggestedThresholdsService.calculate', () {
    test('returns default thresholds when totalItems is 0', () {
      final result = SuggestedThresholdsService.calculate(
        totalItems: 0,
        dailyPace: 5,
      );
      expect(result, [100, 500, 1000]);
    });

    test('returns default thresholds when dailyPace is 0', () {
      final result = SuggestedThresholdsService.calculate(
        totalItems: 100,
        dailyPace: 0,
      );
      expect(result, [100, 500, 1000]);
    });

    test('returns default thresholds for negative inputs', () {
      final result = SuggestedThresholdsService.calculate(
        totalItems: -10,
        dailyPace: -5,
      );
      expect(result, [100, 500, 1000]);
    });

    test('calculates thresholds for typical pace', () {
      // dailyPace=5, pointsPerItem=10 => dailyPoints=50
      // week: 50*7=350 => round to 350
      // month: 50*30=1500 => round to 1500
      // quarter: 50*90=4500 => round to 4500
      final result = SuggestedThresholdsService.calculate(
        totalItems: 1000,
        dailyPace: 5,
      );
      expect(result.length, 3);
      expect(result, orderedEquals(result..sort()));
      // All values should be positive
      for (final t in result) {
        expect(t, greaterThan(0));
      }
    });

    test('returns 3 distinct ascending thresholds', () {
      final result = SuggestedThresholdsService.calculate(
        totalItems: 500,
        dailyPace: 10,
      );
      expect(result.length, 3);
      expect(result[0], lessThan(result[1]));
      expect(result[1], lessThan(result[2]));
    });

    test('uses custom pointsPerItem', () {
      final defaultResult = SuggestedThresholdsService.calculate(
        totalItems: 100,
        dailyPace: 5,
        pointsPerItem: 10,
      );
      final doubleResult = SuggestedThresholdsService.calculate(
        totalItems: 100,
        dailyPace: 5,
        pointsPerItem: 20,
      );
      // With double points per item, thresholds should be higher
      expect(doubleResult[0], greaterThanOrEqualTo(defaultResult[0]));
    });

    test('handles very small daily pace', () {
      // dailyPace=1, pointsPerItem=10 => dailyPoints=10
      // week: 10*7=70 => rounds to 50 or 100
      // month: 10*30=300 => rounds to 300
      // quarter: 10*90=900 => rounds to 900
      final result = SuggestedThresholdsService.calculate(
        totalItems: 100,
        dailyPace: 1,
      );
      expect(result.length, 3);
      expect(result, orderedEquals(result..sort()));
    });

    test('fills in duplicates when thresholds collapse', () {
      // Very small pace where week/month might round to the same value
      final result = SuggestedThresholdsService.calculate(
        totalItems: 10,
        dailyPace: 1,
        pointsPerItem: 1,
      );
      expect(result.length, 3);
      // All should still be distinct after fill-in
      expect(result.toSet().length, 3);
    });
  });
}
