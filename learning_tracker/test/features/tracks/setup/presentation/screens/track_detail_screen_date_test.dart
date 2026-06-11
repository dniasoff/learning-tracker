/// Regression test for TS-8:
/// track_detail_screen.dart computes the header "Since {date}" using
/// DateFormat.yMMMd unconditionally (Gregorian), ignoring the
/// useHebrewCalendar preference. After the fix, the helper respects the flag.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  final testDate = DateTime(2026, 6, 10); // 10 June 2026
  const locale = 'en';

  group('TS-8 — formatTrackDate respects useHebrewCalendar', () {
    test('when useHebrewCalendar=false returns Gregorian format', () {
      final result = formatTrackDate(
        date: testDate,
        locale: locale,
        useHebrewCalendar: false,
      );

      final expected = DateFormat.yMMMd(locale).format(testDate.toLocal());
      expect(result, equals(expected));
    });

    test('when useHebrewCalendar=true returns Hebrew calendar string', () {
      final result = formatTrackDate(
        date: testDate,
        locale: locale,
        useHebrewCalendar: true,
      );

      final hebrewExpected = HebrewCalendarUtils.gregorianToHebrew(
        testDate.toLocal(),
      );

      // The result must match the Hebrew formatted output.
      expect(result, equals(hebrewExpected));

      // Critically: must NOT equal the plain Gregorian string.
      final gregorian = DateFormat.yMMMd(locale).format(testDate.toLocal());
      expect(
        result,
        isNot(equals(gregorian)),
        reason:
            'Hebrew calendar preference must produce a different string than '
            'plain Gregorian (TS-8)',
      );
    });
  });
}
