import 'package:flutter_test/flutter_test.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/core/utils/hebrew_calendar_utils.dart';

void main() {
  group('HebrewCalendarUtils - Gregorian to Hebrew Conversion', () {
    test('converts Jan 1 2026 to Hebrew date correctly', () {
      // Jan 1 2026 = 12 Teves 5786
      final gregorian = DateTime.utc(2026, 1, 1);
      final hebrewDate = HebrewCalendarUtils.gregorianToJewishDate(gregorian);

      expect(hebrewDate.getJewishYear(), 5786);
      expect(hebrewDate.getJewishMonth(), JewishDate.TEVES);
      expect(hebrewDate.getJewishDayOfMonth(), 12);
    });

    test('converts known dates to expected Hebrew dates', () {
      // Test a few known conversions
      final testCases = [
        {
          'gregorian': DateTime.utc(2026, 1, 1),
          'hebrewYear': 5786,
          'hebrewMonth': JewishDate.TEVES,
          'hebrewDay': 12,
        },
        {
          'gregorian': DateTime.utc(2025, 9, 23),
          'hebrewYear': 5786,
          'hebrewMonth': JewishDate.TISHREI,
          'hebrewDay': 1, // Rosh Hashana
        },
      ];

      for (final testCase in testCases) {
        final gregorian = testCase['gregorian'] as DateTime;
        final hebrewDate = HebrewCalendarUtils.gregorianToJewishDate(gregorian);

        expect(hebrewDate.getJewishYear(), testCase['hebrewYear']);
        expect(hebrewDate.getJewishMonth(), testCase['hebrewMonth']);
        expect(hebrewDate.getJewishDayOfMonth(), testCase['hebrewDay']);
      }
    });

    test('gregorianToHebrew produces formatted Hebrew string', () {
      final gregorian = DateTime.utc(2026, 1, 1);
      final formatted = HebrewCalendarUtils.gregorianToHebrew(gregorian);

      // Should return Hebrew string (not empty)
      expect(formatted, isNotEmpty);
      // Should contain Hebrew characters
      expect(formatted, contains(RegExp(r'[\u0590-\u05FF]')));
    });
  });

  group('HebrewCalendarUtils - Hebrew to Gregorian Conversion', () {
    test('converts 12 Teves 5786 to Jan 1 2026', () {
      final gregorian = HebrewCalendarUtils.hebrewToGregorian(
        year: 5786,
        month: JewishDate.TEVES,
        day: 12,
      );

      expect(gregorian.year, 2026);
      expect(gregorian.month, 1);
      expect(gregorian.day, 1);
    });

    test('round-trips correctly for known dates', () {
      final testDates = [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2025, 9, 23), // Rosh Hashana 5786
        DateTime.utc(2026, 4, 1), // Pesach 5786
        DateTime.utc(2026, 9, 25), // Sukkos 5787
      ];

      for (final original in testDates) {
        final hebrewDate = HebrewCalendarUtils.gregorianToJewishDate(original);

        final roundTrip = HebrewCalendarUtils.hebrewToGregorian(
          year: hebrewDate.getJewishYear(),
          month: hebrewDate.getJewishMonth(),
          day: hebrewDate.getJewishDayOfMonth(),
        );

        expect(roundTrip.year, original.year);
        expect(roundTrip.month, original.month);
        expect(roundTrip.day, original.day);
      }
    });
  });

  group('HebrewCalendarUtils - Hebrew Date Formatting', () {
    test('formats Hebrew date with Hebrew characters', () {
      final gregorian = DateTime.utc(2026, 1, 1);
      final formatted = HebrewCalendarUtils.gregorianToHebrew(gregorian);

      // Should contain Hebrew characters
      expect(formatted, contains(RegExp(r'[\u0590-\u05FF]')));
    });
  });

  group('HebrewCalendarUtils - Hebrew Leap Year', () {
    test('identifies leap years correctly', () {
      // Known leap years: 5784, 5787, 5790
      // Known non-leap years: 5785, 5786, 5788, 5789
      expect(HebrewCalendarUtils.isHebrewLeapYear(5784), isTrue);
      expect(HebrewCalendarUtils.isHebrewLeapYear(5787), isTrue);
      expect(HebrewCalendarUtils.isHebrewLeapYear(5790), isTrue);

      expect(HebrewCalendarUtils.isHebrewLeapYear(5785), isFalse);
      expect(HebrewCalendarUtils.isHebrewLeapYear(5786), isFalse);
      expect(HebrewCalendarUtils.isHebrewLeapYear(5788), isFalse);
    });

    test('converts leap year dates (Adar I/Adar II) correctly', () {
      // 5784 is a leap year
      final adarI = HebrewCalendarUtils.hebrewToGregorian(
        year: 5784,
        month: JewishDate.ADAR, // Adar I in leap year
        day: 15,
      );

      final adarII = HebrewCalendarUtils.hebrewToGregorian(
        year: 5784,
        month: JewishDate.ADAR_II, // Adar II in leap year
        day: 15,
      );

      // Adar II should be later than Adar I
      expect(adarII.isAfter(adarI), isTrue);

      // Round-trip to verify
      final hebrewDate1 = HebrewCalendarUtils.gregorianToJewishDate(adarI);
      final hebrewDate2 = HebrewCalendarUtils.gregorianToJewishDate(adarII);

      expect(hebrewDate1.getJewishYear(), 5784);
      expect(hebrewDate2.getJewishYear(), 5784);
      expect(hebrewDate1.getJewishMonth(), JewishDate.ADAR);
      expect(hebrewDate2.getJewishMonth(), JewishDate.ADAR_II);
    });
  });

  group('HebrewCalendarUtils - Edge Cases', () {
    test('handles Rosh Hashana (Hebrew new year boundary)', () {
      // Rosh Hashana 5786: Sep 23, 2025 (1 Tishrei 5786)
      final roshHashana = DateTime.utc(2025, 9, 23);
      final hebrewDate = HebrewCalendarUtils.gregorianToJewishDate(roshHashana);

      expect(hebrewDate.getJewishYear(), 5786);
      expect(hebrewDate.getJewishMonth(), JewishDate.TISHREI);
      expect(hebrewDate.getJewishDayOfMonth(), 1);

      // Day before should be end of previous year
      final dayBefore = DateTime.utc(2025, 9, 22);
      final hebrewBefore = HebrewCalendarUtils.gregorianToJewishDate(dayBefore);

      expect(hebrewBefore.getJewishYear(), 5785);
    });

    test('handles month boundaries correctly', () {
      // Last day of Teves 5786 (29 Teves)
      final lastDayOfTeves = HebrewCalendarUtils.hebrewToGregorian(
        year: 5786,
        month: JewishDate.TEVES,
        day: 29,
      );

      // Next day should be 1 Shevat
      final nextDay = lastDayOfTeves.add(const Duration(days: 1));
      final hebrewNextDay = HebrewCalendarUtils.gregorianToJewishDate(nextDay);

      expect(hebrewNextDay.getJewishMonth(), JewishDate.SHEVAT);
      expect(hebrewNextDay.getJewishDayOfMonth(), 1);
    });

    test('handles year boundary (Gregorian)', () {
      // Dec 31, 2025 to Jan 1, 2026
      final dec31 = DateTime.utc(2025, 12, 31);
      final jan1 = DateTime.utc(2026, 1, 1);

      final hebrewDec31 = HebrewCalendarUtils.gregorianToJewishDate(dec31);
      final hebrewJan1 = HebrewCalendarUtils.gregorianToJewishDate(jan1);

      // Should be consecutive Hebrew dates
      final diff =
          (hebrewJan1.getJewishDayOfMonth() - hebrewDec31.getJewishDayOfMonth())
              .abs();

      // Either same month (diff=1) or consecutive months
      expect(
        diff <= 1 ||
            hebrewJan1.getJewishMonth() != hebrewDec31.getJewishMonth(),
        isTrue,
      );
    });
  });

  group('HebrewCalendarUtils - Month Names', () {
    test('getHebrewMonthName returns Hebrew month name', () {
      final monthName = HebrewCalendarUtils.getHebrewMonthName(
        JewishDate.TEVES,
        hebrewYear: 5786,
        useEnglish: false,
      );

      expect(monthName, isNotEmpty);
      // Should contain Hebrew characters
      expect(monthName, contains(RegExp(r'[\u0590-\u05FF]')));
    });

    test('getHebrewMonthName with useEnglish=true returns transliteration', () {
      final monthName = HebrewCalendarUtils.getHebrewMonthName(
        JewishDate.TEVES,
        hebrewYear: 5786,
        useEnglish: true,
      );

      expect(monthName, isNotEmpty);
      expect(monthName.toLowerCase(), contains('teves'));
    });

    test('getHebrewMonthName handles leap year months', () {
      // In leap year 5784
      final adarIName = HebrewCalendarUtils.getHebrewMonthName(
        JewishDate.ADAR,
        hebrewYear: 5784,
        useEnglish: true,
      );

      final adarIIName = HebrewCalendarUtils.getHebrewMonthName(
        JewishDate.ADAR_II,
        hebrewYear: 5784,
        useEnglish: true,
      );

      expect(adarIName, isNotEmpty);
      expect(adarIIName, isNotEmpty);
      // Should be different
      expect(adarIName, isNot(equals(adarIIName)));
    });
  });
}
