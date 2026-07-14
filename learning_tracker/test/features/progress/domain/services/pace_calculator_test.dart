import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';

void main() {
  // Helper: create a local-day midnight DateTime.
  DateTime day(int year, int month, int d) => DateTime(year, month, d);

  // Reference dates — all expressed as local-day midnights.
  final today = day(2026, 5, 20);

  group('ProgressPaceCalculator', () {
    // -------------------------------------------------------------------------
    // Test 1 — Day 1 grace window
    // -------------------------------------------------------------------------
    test(
      'day 1 (today == trackStart): always graceWindow regardless of bulk',
      () {
        final calc = ProgressPaceCalculator.compute(
          totalItems: 1000,
          bulkBaseline: 1000, // fully done in bulk
          liveProgress: 0,
          trackStartDate: today,
          targetDate: today.add(const Duration(days: 365)),
          today: today,
        );

        expect(calc.isInGraceWindow, isTrue);
        expect(calc.paceStatus, ProgressPaceStatus.graceWindow);
        // Elapsed days = 0 → no velocity signal
        expect(calc.actualVelocity, 0.0);
        // Required velocity = (1000-1000)/365 = 0
        expect(calc.requiredVelocity, 0.0);
      },
    );

    // -------------------------------------------------------------------------
    // Test 2 — Day 1 (elapsed == kPaceGraceWindowDays) still in grace window
    // -------------------------------------------------------------------------
    test('day 1 (elapsed == kPaceGraceWindowDays): still graceWindow', () {
      // trackStart = 1 day ago → elapsed = 1 = kPaceGraceWindowDays
      final trackStart = today.subtract(const Duration(days: 1));

      final calc = ProgressPaceCalculator.compute(
        totalItems: 200,
        bulkBaseline: 0,
        liveProgress: 0,
        trackStartDate: trackStart,
        targetDate: today.add(const Duration(days: 99)), // 100 day track total
        today: today,
      );

      expect(
        calc.isInGraceWindow,
        isTrue,
        reason:
            'elapsed (1) == kPaceGraceWindowDays ($kPaceGraceWindowDays), '
            'should still be in grace window',
      );
      expect(calc.paceStatus, ProgressPaceStatus.graceWindow);
    });

    // -------------------------------------------------------------------------
    // Test 3 — Day 4 ahead
    // -------------------------------------------------------------------------
    test(
      'day 4 ahead: liveProgress exceeds expectedProgressToday by more than requiredVelocity',
      () {
        // trackStart = 4 days ago, target = 100 days from trackStart
        // totalItems=1000, bulkBaseline=500 → need to complete 500 items in 100 days
        // requiredVelocity = 500 / 100 = 5.0 items/day
        // expectedProgressToday = 5.0 * 4 = 20.0
        // liveProgress = 40 → paceVariance = 40 - 20 = 20
        // paceVariance (20) > requiredVelocity (5) → ahead
        final trackStart = today.subtract(const Duration(days: 4));
        final targetDate = trackStart.add(const Duration(days: 100));

        final calc = ProgressPaceCalculator.compute(
          totalItems: 1000,
          bulkBaseline: 500,
          liveProgress: 40,
          trackStartDate: trackStart,
          targetDate: targetDate,
          today: today,
        );

        expect(calc.requiredVelocity, closeTo(5.0, 0.001));
        expect(calc.expectedProgressToday, closeTo(20.0, 0.001));
        expect(calc.paceVariance, closeTo(20.0, 0.001));
        expect(
          calc.isInGraceWindow,
          isFalse,
          reason:
              'elapsed days (4) > kPaceGraceWindowDays ($kPaceGraceWindowDays)',
        );
        expect(calc.paceStatus, ProgressPaceStatus.ahead);
        expect(
          calc.paceVarianceInDays,
          closeTo(4.0, 0.001),
          reason: 'paceVarianceInDays = paceVariance / requiredVelocity = 20/5',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Test 4 — Day 4 behind
    // -------------------------------------------------------------------------
    test('day 4 behind: no live progress after grace window → behind', () {
      // Same setup as test 3 but liveProgress = 0.
      // expectedProgressToday = 5.0 * 4 = 20
      // paceVariance = 0 - 20 = -20
      // paceVariance (-20) < -requiredVelocity (-5) → behind
      final trackStart = today.subtract(const Duration(days: 4));
      final targetDate = trackStart.add(const Duration(days: 100));

      final calc = ProgressPaceCalculator.compute(
        totalItems: 1000,
        bulkBaseline: 500,
        liveProgress: 0,
        trackStartDate: trackStart,
        targetDate: targetDate,
        today: today,
      );

      expect(calc.isInGraceWindow, isFalse);
      expect(calc.paceVariance, closeTo(-20.0, 0.001));
      expect(calc.paceStatus, ProgressPaceStatus.behind);
      expect(calc.paceVarianceInDays, isNegative);
    });

    // -------------------------------------------------------------------------
    // Test 5 — Zero-divide safety: targetDate == trackStartDate
    // -------------------------------------------------------------------------
    test(
      'zero-divide safety: targetDate == trackStartDate → requiredVelocity = 0, no exception',
      () {
        expect(
          () => ProgressPaceCalculator.compute(
            totalItems: 500,
            bulkBaseline: 0,
            liveProgress: 0,
            trackStartDate: today,
            targetDate: today, // degenerate: same day
            today: today,
          ),
          returnsNormally,
        );

        final calc = ProgressPaceCalculator.compute(
          totalItems: 500,
          bulkBaseline: 0,
          liveProgress: 0,
          trackStartDate: today,
          targetDate: today,
          today: today,
        );

        expect(calc.requiredVelocity, 0.0);
        expect(
          calc.paceVarianceInDays,
          0.0,
          reason:
              'requiredVelocity == 0 → paceVarianceInDays must be 0 not NaN',
        );
        expect(calc.paceStatus, ProgressPaceStatus.graceWindow);
      },
    );

    // -------------------------------------------------------------------------
    // Test 6 — The Mishnayos bug case
    // -------------------------------------------------------------------------
    test('Mishnayos bug: bulk baseline == totalItems, liveProgress == 0 → '
        'no phantom ahead/behind, graceWindow because today == trackStart', () {
      // Simulates: user bulk-marks all 1336 mishnayos on setup day (sentinel
      // date 2000-01-01). trackStart = today, liveProgress = 0.
      // bulkBaseline should absorb all items so requiredVelocity = 0.
      // Elapsed days = 0 → graceWindow. paceVariance should be 0.
      final calc = ProgressPaceCalculator.compute(
        totalItems: 1336,
        bulkBaseline: 1336,
        liveProgress: 0,
        trackStartDate: today,
        targetDate: today.add(const Duration(days: 365)),
        today: today,
      );

      expect(
        calc.requiredVelocity,
        0.0,
        reason: 'totalItems - bulkBaseline = 0, so nothing left to pace',
      );
      expect(calc.paceVariance, 0.0);
      expect(
        calc.paceStatus,
        ProgressPaceStatus.graceWindow,
        reason: 'day 0 is always in grace window',
      );
      // Must NOT be ahead or behind — bulk completions are not live velocity
      expect(calc.paceStatus, isNot(ProgressPaceStatus.ahead));
      expect(calc.paceStatus, isNot(ProgressPaceStatus.behind));
    });

    // -------------------------------------------------------------------------
    // Test 7 — bulkBaseline exceeds totalItems (over-marked prior learning)
    // -------------------------------------------------------------------------
    test('bulkBaseline > totalItems: requiredVelocity clamps to 0, no phantom '
        'ahead/behind', () {
      // Simulates a curriculum content set shrinking after the user already
      // bulk-marked more items than now exist (totalItems=50 < bulkBaseline=80).
      // Without the clamp at pace_calculator.dart:150, requiredVelocity would
      // go negative: (50-80)/100 = -0.3.
      final trackStart = today.subtract(const Duration(days: 10));
      final targetDate = trackStart.add(const Duration(days: 100));

      final calc = ProgressPaceCalculator.compute(
        totalItems: 50,
        bulkBaseline: 80,
        liveProgress: 0,
        trackStartDate: trackStart,
        targetDate: targetDate,
        today: today,
      );

      expect(
        calc.requiredVelocity,
        0.0,
        reason:
            'totalItems - bulkBaseline is negative (50-80=-30); must clamp '
            'to 0, not go negative',
      );
      expect(calc.isInGraceWindow, isFalse);
      // Must NOT be ahead or behind — an over-marked bulk baseline must not
      // produce a phantom pace signal.
      expect(calc.paceStatus, isNot(ProgressPaceStatus.ahead));
      expect(calc.paceStatus, isNot(ProgressPaceStatus.behind));
    });

    // -------------------------------------------------------------------------
    // Additional edge case — onTrack boundary
    // -------------------------------------------------------------------------
    test(
      'exactly on pace: paceVariance == 0 → onTrack (outside grace window)',
      () {
        // trackStart = 10 days ago, required = 2.0/day
        // expectedProgressToday = 2.0 * 10 = 20, liveProgress = 20 → paceVariance = 0
        // |0| < requiredVelocity (2.0) → onTrack
        final trackStart = today.subtract(const Duration(days: 10));
        final targetDate = trackStart.add(const Duration(days: 100));

        final calc = ProgressPaceCalculator.compute(
          totalItems: 200,
          bulkBaseline: 0,
          liveProgress: 20,
          trackStartDate: trackStart,
          targetDate: targetDate,
          today: today,
        );

        expect(calc.requiredVelocity, closeTo(2.0, 0.001));
        expect(calc.paceVariance, closeTo(0.0, 0.001));
        expect(calc.isInGraceWindow, isFalse);
        expect(calc.paceStatus, ProgressPaceStatus.onTrack);
      },
    );

    // -------------------------------------------------------------------------
    // Additional edge case — within 1-day margin (onTrack, not ahead)
    // -------------------------------------------------------------------------
    test('just slightly ahead (within 1 day margin) → onTrack, not ahead', () {
      // requiredVelocity = 200/100 = 2.0/day
      // elapsed = 10, expectedProgressToday = 20.0
      // liveProgress = 21 → paceVariance = 1.0
      // paceVariance (1.0) < requiredVelocity (2.0) → onTrack
      final trackStart = today.subtract(const Duration(days: 10));
      final targetDate = trackStart.add(const Duration(days: 100));

      final calc = ProgressPaceCalculator.compute(
        totalItems: 200,
        bulkBaseline: 0,
        liveProgress: 21,
        trackStartDate: trackStart,
        targetDate: targetDate,
        today: today,
      );

      expect(calc.paceVariance, closeTo(1.0, 0.001));
      expect(
        calc.paceStatus,
        ProgressPaceStatus.onTrack,
        reason:
            'paceVariance (1.0) < requiredVelocity (2.0): within 1-day tolerance',
      );
    });

    // -------------------------------------------------------------------------
    // Equality and hashCode
    // -------------------------------------------------------------------------
    test('two instances with identical inputs are equal', () {
      ProgressPaceCalculator make() => ProgressPaceCalculator.compute(
        totalItems: 100,
        bulkBaseline: 10,
        liveProgress: 5,
        trackStartDate: today.subtract(const Duration(days: 5)),
        targetDate: today.add(const Duration(days: 95)),
        today: today,
      );

      final a = make();
      final b = make();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
