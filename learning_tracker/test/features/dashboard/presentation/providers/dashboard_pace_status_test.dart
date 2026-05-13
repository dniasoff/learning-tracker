// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';

/// Unit tests for the pace math used by [dashboardPaceStatusProvider].
///
/// These tests exercise [PaceCalculator] directly — the provider itself wires
/// totalItems from [scopedItemCountProvider] (fixed in DNI-345), so this file
/// validates the correctness of the resulting calculation, not the Riverpod
/// plumbing.
void main() {
  group('dashboardPaceStatusProvider — real total-items math (DNI-345)', () {
    // Reference date: 300 days into a 500-day deadline goal.
    // Goal started 2025-07-17; "today" = 2026-05-13 (300 days after start).
    final goalStart = DateTime.utc(2025, 7, 17);
    final today = DateTime.utc(2026, 5, 13); // 300 days after start

    // 500-day goal: start 2025-07-17, deadline 2026-11-28 (exactly 500 days).
    final deadline500 = goalStart.add(const Duration(days: 500));

    // 7-day rolling window with 2 completions/day (some activity).
    Map<DateTime, int> rollingCounts(int perDay) {
      final counts = <DateTime, int>{};
      for (var i = 1; i <= 7; i++) {
        counts[DateTime.utc(today.year, today.month, today.day - i)] = perDay;
      }
      return counts;
    }

    test(
      'AC: 200 completions out of 1000 items at day 300 of 500 is "behind"',
      () {
        // Setup:
        //   totalItems   = 1000  (from real content tree via scopedItemCountProvider)
        //   goalDays     = 500
        //   elapsedDays  = 300
        //   expectedByNow = 1000 * (300/500) = 600
        //   completedItems = 200  → 400 items behind schedule
        //   itemsPerDay   = 1000 / 500 = 2.0
        //   rawDaysDelta  = (200 − 600) / 2.0 = −200 days
        //   daysDelta     = −200  (ceil of −200 = −200)
        final result = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: deadline500,
          totalItems: 1000,
          completedItems: 200,
          dailyCompletionCounts: rollingCounts(2),
          today: today,
        );

        expect(
          result.status,
          PaceStatusType.behind,
          reason: '200 of 600 expected items done → learner is behind',
        );
        // daysDelta must be negative
        expect(result.daysDelta, lessThan(0));
        // And the exact magnitude: −200 days
        expect(result.daysDelta, -200);
      },
    );

    test(
      'old placeholder math (completions + 100) would have produced wrong status',
      () {
        // With the old code: totalItems = 200 + 100 = 300
        // elapsedDays=300, totalDays=500, expectedByNow = 300*(300/500) = 180
        // completedItems=200 > 180 → wrongly reports "ahead"
        final buggyResult = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: deadline500,
          totalItems: 300, // old placeholder: 200 completions + 100
          completedItems: 200,
          dailyCompletionCounts: rollingCounts(2),
          today: today,
        );
        expect(
          buggyResult.status,
          isNot(PaceStatusType.behind),
          reason:
              'Placeholder totalItems=300 conceals that the learner is behind',
        );

        // With the real totalItems=1000 the correct status is "behind"
        final fixedResult = PaceCalculator.calculate(
          goalStartDate: goalStart,
          goalDeadline: deadline500,
          totalItems: 1000, // real content tree count
          completedItems: 200,
          dailyCompletionCounts: rollingCounts(2),
          today: today,
        );
        expect(fixedResult.status, PaceStatusType.behind);
        expect(fixedResult.daysDelta, -200);
      },
    );

    test('on-pace when completions match linear expectation', () {
      // At day 250 of 500, expected = 500 out of 1000 → exactly on pace
      final start = DateTime.utc(2025, 7, 17);
      final deadline = start.add(const Duration(days: 500));
      final day250 = start.add(const Duration(days: 250));

      Map<DateTime, int> counts250(int perDay) {
        final c = <DateTime, int>{};
        for (var i = 1; i <= 7; i++) {
          c[DateTime.utc(day250.year, day250.month, day250.day - i)] = perDay;
        }
        return c;
      }

      final result = PaceCalculator.calculate(
        goalStartDate: start,
        goalDeadline: deadline,
        totalItems: 1000,
        completedItems: 500,
        dailyCompletionCounts: counts250(2),
        today: day250,
      );

      expect(result.status, PaceStatusType.onPace);
      expect(result.daysDelta, 0);
    });

    test('ahead when completions exceed linear expectation', () {
      // At day 100 of 500, expected = 200; learner has 400 → ahead by 100 days
      final start = DateTime.utc(2025, 7, 17);
      final deadline = start.add(const Duration(days: 500));
      final day100 = start.add(const Duration(days: 100));

      Map<DateTime, int> counts100(int perDay) {
        final c = <DateTime, int>{};
        for (var i = 1; i <= 7; i++) {
          c[DateTime.utc(day100.year, day100.month, day100.day - i)] = perDay;
        }
        return c;
      }

      final result = PaceCalculator.calculate(
        goalStartDate: start,
        goalDeadline: deadline,
        totalItems: 1000,
        completedItems: 400,
        dailyCompletionCounts: counts100(4),
        today: day100,
      );

      expect(result.status, PaceStatusType.ahead);
      expect(result.daysDelta, greaterThan(0));
      expect(result.daysDelta, 100); // (400−200)/2 = 100 days
    });
  });
}
