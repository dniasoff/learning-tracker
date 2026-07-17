/// Unit tests for the pure reorder-amnesty cutoff functions
/// (architecture §10.1; AUD-scheduler-09).
///
/// AG-5 mirror of `lib/features/scheduler/domain/projection/amnesty_cutoff.dart`.
/// These are the real functions the production amnesty filter in
/// `scheduler_providers.dart` calls — `reorder_amnesty_test.dart`'s
/// Scenario-A tests exercise the same functions through that production
/// call path; this file characterises the pure functions directly and in
/// isolation.
///
/// Local-instant construction (`DateTime(y, m, d, h, ...)` rather than a UTC
/// instant fed through `.toLocal()`) keeps these assertions deterministic
/// regardless of the machine's timezone: a non-UTC [DateTime]'s `.toLocal()`
/// is a no-op, so the (year, month, day) read back out of
/// [amnestyDayCutoffUtc] is always exactly what was constructed here — no
/// dependency on which zone the test happens to run in.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';

void main() {
  group('amnestyDayCutoffUtc', () {
    test('normalizes a mid-day local instant to UTC midnight of that day', () {
      final localInstant = DateTime(2026, 5, 20, 15, 30);
      expect(
        amnestyDayCutoffUtc(localInstant),
        equals(DateTime.utc(2026, 5, 20)),
      );
    });

    test('is idempotent on an instant already at local midnight', () {
      final localMidnight = DateTime(2026, 5, 20);
      expect(
        amnestyDayCutoffUtc(localMidnight),
        equals(DateTime.utc(2026, 5, 20)),
      );
    });

    test('the result is always UTC with zeroed time components', () {
      final cutoff = amnestyDayCutoffUtc(DateTime(2026, 5, 20, 23, 59, 59));
      expect(cutoff.isUtc, isTrue);
      expect(cutoff.hour, equals(0));
      expect(cutoff.minute, equals(0));
      expect(cutoff.second, equals(0));
      expect(cutoff.millisecond, equals(0));
    });

    test('two instants on the same local day collapse to the same cutoff '
        '(the mid-day-reorder regression this function fixes)', () {
      final earlyMorning = DateTime(2026, 5, 20, 0, 0, 1);
      final lateNight = DateTime(2026, 5, 20, 23, 59, 59);
      expect(
        amnestyDayCutoffUtc(earlyMorning),
        equals(amnestyDayCutoffUtc(lateNight)),
      );
    });

    test(
      'instants either side of a local day boundary map to different cutoffs',
      () {
        final justBeforeMidnight = DateTime(2026, 5, 20, 23, 59, 59);
        final justAfterMidnight = DateTime(2026, 5, 21, 0, 0, 0);
        expect(
          amnestyDayCutoffUtc(justBeforeMidnight),
          equals(DateTime.utc(2026, 5, 20)),
        );
        expect(
          amnestyDayCutoffUtc(justAfterMidnight),
          equals(DateTime.utc(2026, 5, 21)),
        );
        expect(
          amnestyDayCutoffUtc(justBeforeMidnight),
          isNot(equals(amnestyDayCutoffUtc(justAfterMidnight))),
        );
      },
    );
  });

  group('clampAmnestyCutoffToAnchor', () {
    test('clamps a raw cutoff after the anchor down to the anchor', () {
      final anchor = DateTime.utc(2026, 5, 21);
      final rawCutoff = DateTime.utc(2026, 5, 25); // after anchor
      expect(clampAmnestyCutoffToAnchor(rawCutoff, anchor), equals(anchor));
    });

    test('leaves a raw cutoff on/before the anchor unchanged', () {
      final anchor = DateTime.utc(2026, 5, 21);
      final rawCutoff = DateTime.utc(2026, 5, 18); // before anchor
      expect(clampAmnestyCutoffToAnchor(rawCutoff, anchor), equals(rawCutoff));
    });

    test(
      'a raw cutoff exactly equal to the anchor is unchanged (not clamped)',
      () {
        final anchor = DateTime.utc(2026, 5, 21);
        expect(clampAmnestyCutoffToAnchor(anchor, anchor), equals(anchor));
      },
    );

    test('program back-date field repro: lastReorderAt=today clamped to a '
        'past anchor preserves the entire back-date window', () {
      // Field repro from AUD-scheduler-09 / architecture §10.1: a program
      // track added "4 days behind" has trackingStartDate = today-4 but
      // lastReorderAt = creation day (today). Without the clamp, the raw
      // cutoff (= today) would strip every back-dated day.
      final today = DateTime.utc(2026, 5, 25);
      final anchor = today.subtract(const Duration(days: 4));
      final rawCutoff = amnestyDayCutoffUtc(DateTime(2026, 5, 25));
      final clamped = clampAmnestyCutoffToAnchor(rawCutoff, anchor);
      expect(clamped, equals(anchor));
      expect(clamped.isAfter(anchor.subtract(const Duration(days: 1))), isTrue);
    });
  });
}
