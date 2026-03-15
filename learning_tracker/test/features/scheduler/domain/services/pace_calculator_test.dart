import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';

void main() {
  group('PaceCalculator', () {
    final today = DateTime.utc(2026, 3, 15);

    /// Helper: build daily counts for the 7 days before [today].
    Map<DateTime, int> buildCounts(int perDay) {
      final counts = <DateTime, int>{};
      for (var i = 1; i <= 7; i++) {
        counts[DateTime.utc(2026, 3, 15 - i)] = perDay;
      }
      return counts;
    }

    test('returns onPace when completions match expected progress', () {
      // 100 items over 100 days, 50 days elapsed, 50 completed
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 50,
        dailyCompletionCounts: buildCounts(1),
        today: today,
      );

      expect(result.status, PaceStatusType.onPace);
      expect(result.daysDelta, 0);
    });

    test('returns ahead when completions exceed expected', () {
      // 100 items over 100 days, 50 days in, 70 completed → 20 items ahead
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 70,
        dailyCompletionCounts: buildCounts(2),
        today: today,
      );

      expect(result.status, PaceStatusType.ahead);
      expect(result.daysDelta, greaterThan(0));
    });

    test('returns behind when completions lag behind expected', () {
      // 100 items over 100 days, 50 days in, 30 completed → 20 items behind
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 30,
        dailyCompletionCounts: buildCounts(1),
        today: today,
      );

      expect(result.status, PaceStatusType.behind);
      expect(result.daysDelta, lessThan(0));
    });

    test('projectedCompletionDate is null when no completions in 7 days', () {
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 50,
        dailyCompletionCounts: {},
        today: today,
      );

      expect(result.projectedCompletionDate, isNull);
      expect(result.rollingAverage, 0.0);
    });

    test('zero completions returns behind with null projection', () {
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 0,
        dailyCompletionCounts: {},
        today: today,
      );

      expect(result.status, PaceStatusType.behind);
      expect(result.projectedCompletionDate, isNull);
    });

    test(
      'already completed goal returns ahead with today as projected date',
      () {
        final result = PaceCalculator.calculate(
          goalStartDate: DateTime.utc(2026, 1, 24),
          goalDeadline: DateTime.utc(2026, 5, 4),
          totalItems: 100,
          completedItems: 100,
          dailyCompletionCounts: buildCounts(2),
          today: today,
        );

        expect(result.status, PaceStatusType.ahead);
        expect(result.projectedCompletionDate, today);
      },
    );

    test('fractional behind is rounded up (no dead zone)', () {
      // If a user is even slightly behind, status should be behind, not onPace.
      // 100 items over 100 days, 50 days in, 49 completed → 1 item behind
      // rawDaysDelta = -1/1 = -1.0 → daysDelta = -1
      // But let's test a fractional case: 99 items behind by less than 1 day
      // 10 items over 10 days, 5 days in, expected = 5, actual = 4
      // rawDaysDelta = -1/1 = -1 → behind by 1
      // Try: 10 items / 20 days = 0.5/day, 5 days in, expected=2.5, actual=2
      // rawDaysDelta = -0.5/0.5 = -1 → behind by 1
      // Better: 3 items / 10 days = 0.3/day, 5 days in, expected=1.5, actual=1
      // rawDaysDelta = -0.5/0.3 = -1.67 → ceil → -2
      // We need a case where .round() would give 0 but ceil gives -1:
      // rawDaysDelta between -0.5 and 0: e.g. -0.3
      // 10 items / 100 days = 0.1/day, 50 days in, expected=5, actual=4.7→ can't do fractional
      // 100 items / 100 days = 1/day, 50 days in, expected=50, actual=50 → onPace
      // Actually: rawDaysDelta = (completed - expected) / itemsPerDay
      // Need (completed - expected) between -0.5*itemsPerDay and 0 (exclusive).
      // With 30 items over 100 days: 0.3/day, 50 days in, expected=15, completed=14
      // rawDaysDelta = -1/0.3 = -3.33 → not a dead zone case
      // With 200 items over 100 days: 2/day, 50 days in, expected=100, completed=99
      // rawDaysDelta = -1/2 = -0.5 → round()=0 (dead zone!), but ceil → -1
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24), // 50 days before today
        goalDeadline: DateTime.utc(2026, 5, 4), // 100 days total
        totalItems: 200,
        completedItems: 99,
        dailyCompletionCounts: buildCounts(2),
        today: today,
      );

      // With .round(), rawDaysDelta=-0.5 rounds to 0 → onPace (wrong!)
      // With our fix, -0.5 → ceil(0.5) = 1 → daysDelta = -1 → behind
      expect(result.status, PaceStatusType.behind);
      expect(result.daysDelta, -1);
    });

    test('onPaceBehind callback is invoked when status is behind', () {
      int? callbackDays;

      PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 30,
        dailyCompletionCounts: buildCounts(1),
        today: today,
        onPaceBehind: (days) => callbackDays = days,
      );

      expect(callbackDays, isNotNull);
      expect(callbackDays, greaterThan(0));
    });

    test('onPaceBehind callback is NOT invoked when on pace or ahead', () {
      var called = false;

      PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 70,
        dailyCompletionCounts: buildCounts(2),
        today: today,
        onPaceBehind: (_) => called = true,
      );

      expect(called, false);
    });

    test('rolling average is computed from 7 days before today', () {
      // 3 completions per day for 7 days → average = 3.0
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 1, 24),
        goalDeadline: DateTime.utc(2026, 5, 4),
        totalItems: 100,
        completedItems: 50,
        dailyCompletionCounts: buildCounts(3),
        today: today,
      );

      expect(result.rollingAverage, 3.0);
    });

    test('deadline at or before start treats incomplete as behind', () {
      final result = PaceCalculator.calculate(
        goalStartDate: DateTime.utc(2026, 3, 15),
        goalDeadline: DateTime.utc(2026, 3, 15),
        totalItems: 10,
        completedItems: 5,
        dailyCompletionCounts: {},
        today: today,
      );

      expect(result.status, PaceStatusType.behind);
    });
  });
}
