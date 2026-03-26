import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

void main() {
  group('DateTimeFactory', () {
    test('nowUtc returns current time in UTC', () {
      final now = DateTimeFactory.nowUtc();
      expect(now.isUtc, isTrue);

      // Verify it's close to actual current time (within 1 second)
      final actualNow = DateTime.now().toUtc();
      final diff = now.difference(actualNow).abs();
      expect(diff.inSeconds, lessThan(1));
    });

    test('utc factory creates UTC DateTime', () {
      final dt = DateTimeFactory.utc(2026, 2, 9, 12, 30, 45);
      expect(dt.isUtc, isTrue);
      expect(dt.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 9);
      expect(dt.hour, 12);
      expect(dt.minute, 30);
      expect(dt.second, 45);
    });

    test('utc factory uses default values for optional parameters', () {
      final dt = DateTimeFactory.utc(2026);
      expect(dt.isUtc, isTrue);
      expect(dt.year, 2026);
      expect(dt.month, 1);
      expect(dt.day, 1);
      expect(dt.hour, 0);
      expect(dt.minute, 0);
      expect(dt.second, 0);
    });

    test('toUtc converts local DateTime to UTC', () {
      final local = DateTime(2026, 2, 9, 12, 0, 0);
      expect(local.isUtc, isFalse);

      final utc = DateTimeFactory.toUtc(local);
      expect(utc.isUtc, isTrue);
    });

    test('toUtc preserves UTC DateTime', () {
      final utc = DateTime.utc(2026, 2, 9, 12, 0, 0);
      expect(utc.isUtc, isTrue);

      final converted = DateTimeFactory.toUtc(utc);
      expect(converted.isUtc, isTrue);
      expect(converted, equals(utc));
    });
  });

  group('DateUtils - Local Date Extraction', () {
    test('extractLocalDate returns date-only DateTime', () {
      final utc = DateTime.utc(2026, 2, 9, 23, 30, 45);
      final localDate = DateUtils.extractLocalDate(utc);

      // Should be date-only (time components zeroed)
      expect(localDate.hour, 0);
      expect(localDate.minute, 0);
      expect(localDate.second, 0);
      expect(localDate.millisecond, 0);
      expect(localDate.microsecond, 0);
    });

    test('extractLocalDate converts to local timezone', () {
      // Create UTC time that might be different local date
      final utc = DateTime.utc(2026, 2, 10, 2, 0, 0); // 2am UTC on Feb 10
      final localDate = DateUtils.extractLocalDate(utc);

      // Convert manually to verify
      final expectedLocal = utc.toLocal();
      expect(localDate.year, expectedLocal.year);
      expect(localDate.month, expectedLocal.month);
      expect(localDate.day, expectedLocal.day);
    });

    test('extractLocalDate handles timezone offset near midnight', () {
      // UTC time: Feb 10 at 02:00 UTC
      // In UTC-5, this is Feb 9 at 21:00 (9pm)
      final utc = DateTime.utc(2026, 2, 10, 2, 0, 0);
      final localDate = DateUtils.extractLocalDate(utc);

      final local = utc.toLocal();
      expect(localDate.year, local.year);
      expect(localDate.month, local.month);
      expect(localDate.day, local.day);
    });
  });

  group('DateUtils - Same Local Day', () {
    test('isSameLocalDay returns true for same local date', () {
      final utc1 = DateTime.utc(2026, 2, 9, 10, 0, 0);
      final utc2 = DateTime.utc(2026, 2, 9, 14, 0, 0);

      expect(DateUtils.isSameLocalDay(utc1, utc2), isTrue);
    });

    test('isSameLocalDay returns false for different local dates', () {
      final utc1 = DateTime.utc(2026, 2, 9, 10, 0, 0);
      final utc2 = DateTime.utc(2026, 2, 10, 10, 0, 0);

      expect(DateUtils.isSameLocalDay(utc1, utc2), isFalse);
    });

    test('isSameLocalDay handles timezone offset correctly', () {
      // Two UTC times that might be same local day depending on timezone
      // Both represent times on the same local calendar day
      final utc1 = DateTime.utc(2026, 2, 9, 14, 0, 0);
      final utc2 = DateTime.utc(2026, 2, 9, 23, 0, 0);

      final sameDay = DateUtils.isSameLocalDay(utc1, utc2);

      // Verify by checking local dates
      final local1 = utc1.toLocal();
      final local2 = utc2.toLocal();
      final expectedSameDay =
          local1.year == local2.year &&
          local1.month == local2.month &&
          local1.day == local2.day;

      expect(sameDay, expectedSameDay);
    });

    test(
      'isSameLocalDay returns false for UTC times that cross local midnight',
      () {
        // These times should be on different local dates if timezone offset
        // causes them to cross midnight boundary
        final utc1 = DateTime.utc(2026, 2, 9, 4, 0, 0); // Early morning UTC
        final utc2 = DateTime.utc(2026, 2, 10, 4, 0, 0); // Next day same time

        expect(DateUtils.isSameLocalDay(utc1, utc2), isFalse);
      },
    );
  });

  group('DateUtils - Start/End of Local Day', () {
    test('startOfLocalDay returns 00:00:00 local time as UTC', () {
      final utc = DateTime.utc(2026, 2, 9, 15, 30, 45);
      final startOfDay = DateUtils.startOfLocalDay(utc);

      // Convert back to local to verify
      final local = startOfDay.toLocal();
      expect(local.hour, 0);
      expect(local.minute, 0);
      expect(local.second, 0);
      expect(local.millisecond, 0);
      expect(local.microsecond, 0);

      // Should be UTC
      expect(startOfDay.isUtc, isTrue);
    });

    test('endOfLocalDay returns 23:59:59.999 local time as UTC', () {
      final utc = DateTime.utc(2026, 2, 9, 15, 30, 45);
      final endOfDay = DateUtils.endOfLocalDay(utc);

      // Convert back to local to verify
      final local = endOfDay.toLocal();
      expect(local.hour, 23);
      expect(local.minute, 59);
      expect(local.second, 59);
      expect(local.millisecond, 999);
      expect(local.microsecond, 999);

      // Should be UTC
      expect(endOfDay.isUtc, isTrue);
    });

    test('startOfLocalDay and endOfLocalDay span same local day', () {
      final utc = DateTime.utc(2026, 2, 9, 15, 30, 45);
      final start = DateUtils.startOfLocalDay(utc);
      final end = DateUtils.endOfLocalDay(utc);

      expect(DateUtils.isSameLocalDay(start, end), isTrue);
    });

    test('startOfLocalDay is before endOfLocalDay', () {
      final utc = DateTime.utc(2026, 2, 9, 15, 30, 45);
      final start = DateUtils.startOfLocalDay(utc);
      final end = DateUtils.endOfLocalDay(utc);

      expect(start.isBefore(end), isTrue);
    });
  });

  group('DateUtils - Streak Day Boundary (P5)', () {
    test('two completions on same local date count as same day', () {
      // Simulate two completions on same local calendar day
      // Use times well within the same UTC day to avoid timezone boundary issues
      final completion1 = DateTime.utc(2026, 2, 9, 14, 0, 0);
      final completion2 = DateTime.utc(2026, 2, 9, 18, 0, 0);

      final localDate1 = DateUtils.extractLocalDate(completion1);
      final localDate2 = DateUtils.extractLocalDate(completion2);

      expect(localDate1, equals(localDate2));
      expect(DateUtils.isSameLocalDay(completion1, completion2), isTrue);
    });

    test('completion near midnight maps to correct local date', () {
      // UTC completion at 23:00 maps to correct local date
      final utcCompletion = DateTime.utc(2026, 2, 9, 23, 0, 0);
      final localDate = DateUtils.extractLocalDate(utcCompletion);

      // Verify it uses local timezone
      final expectedLocal = utcCompletion.toLocal();
      expect(localDate.year, expectedLocal.year);
      expect(localDate.month, expectedLocal.month);
      expect(localDate.day, expectedLocal.day);
    });

    test('timezone offset near midnight handled correctly', () {
      // Example: UTC-5 timezone
      // UTC: Feb 10 at 04:00 (4am)
      // Local (UTC-5): Feb 9 at 23:00 (11pm)
      // Should map to Feb 9 local date

      final utcCompletion = DateTime.utc(2026, 2, 10, 4, 0, 0);
      final localDate = DateUtils.extractLocalDate(utcCompletion);

      final local = utcCompletion.toLocal();
      expect(localDate.year, local.year);
      expect(localDate.month, local.month);
      expect(localDate.day, local.day);
    });
  });
}
