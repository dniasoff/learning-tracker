/// Hebrew calendar utilities wrapping kosher_dart library.
/// Provides conversion between Gregorian and Hebrew dates.
library;

import 'package:kosher_dart/kosher_dart.dart';

/// Utilities for Hebrew calendar operations.
class HebrewCalendarUtils {
  /// Converts a Gregorian DateTime to a Hebrew date string.
  /// Returns formatted string like "י״א טבת תשפ״ו" (11 Teves 5786).
  ///
  /// Example:
  /// ```dart
  /// final hebrewDate = HebrewCalendarUtils.gregorianToHebrew(
  ///   DateTime.utc(2026, 1, 1)
  /// );
  /// // Returns: "י״ב טבת תשפ״ו" (12 Teves 5786)
  /// ```
  static String gregorianToHebrew(DateTime gregorianDate) {
    final jewishCalendar = JewishCalendar.fromDateTime(gregorianDate);
    final formatter = HebrewDateFormatter();
    formatter.hebrewFormat = true;
    return formatter.format(jewishCalendar);
  }

  /// Converts a Gregorian DateTime to a JewishDate object.
  /// Use this for more detailed Hebrew date information.
  static JewishDate gregorianToJewishDate(DateTime gregorianDate) {
    return JewishDate.fromDateTime(gregorianDate);
  }

  /// Converts a Hebrew date back to Gregorian DateTime.
  /// Takes Hebrew year, month (1-13), and day.
  ///
  /// Note: In leap years, Adar I is month 12 and Adar II is month 13.
  ///
  /// Example:
  /// ```dart
  /// final gregorian = HebrewCalendarUtils.hebrewToGregorian(
  ///   year: 5786,
  ///   month: JewishDate.TEVES,
  ///   day: 12,
  /// );
  /// // Returns: DateTime.utc(2026, 1, 1)
  /// ```
  static DateTime hebrewToGregorian({
    required int year,
    required int month,
    required int day,
  }) {
    final jewishDate = JewishDate.initDate(
      jewishYear: year,
      jewishMonth: month,
      jewishDayOfMonth: day,
    );
    return jewishDate.getGregorianCalendar();
  }

  /// Checks if a given Gregorian date is Shabbos (Friday sunset to Saturday nightfall).
  /// Returns true if the date falls on Saturday.
  ///
  /// Note: This is a simplified check. For precise sunset/nightfall times,
  /// use ComplexZmanimCalendar with a GeoLocation.
  static bool isShabbos(DateTime gregorianDate) {
    return gregorianDate.weekday == DateTime.saturday;
  }

  /// Checks if a given Gregorian date is a Yom Tov (Jewish holiday).
  /// Returns true for major holidays: Rosh Hashana, Yom Kippur, Pesach,
  /// Shavuos, Sukkos, and Simchas Torah.
  static bool isYomTov(DateTime gregorianDate) {
    final jewishCalendar = JewishCalendar.fromDateTime(gregorianDate);
    return jewishCalendar.isYomTov();
  }

  /// Checks if a given Hebrew year is a leap year (has Adar I and Adar II).
  /// In leap years, month 12 is Adar I and month 13 is Adar II.
  static bool isHebrewLeapYear(int hebrewYear) {
    final jewishDate = JewishDate.initDate(
      jewishYear: hebrewYear,
      jewishMonth: JewishDate.TISHREI,
      jewishDayOfMonth: 1,
    );
    return jewishDate.isJewishLeapYear();
  }

  /// Formats a Hebrew date with custom formatting options.
  /// By default returns Hebrew format like "י״ב טבת תשפ״ו".
  ///
  /// Set [useEnglish] to true for transliterated format like "11 Teves 5786".
  static String formatHebrewDate(
    JewishDate jewishDate, {
    bool useEnglish = false,
  }) {
    final formatter = HebrewDateFormatter();
    formatter.hebrewFormat = !useEnglish;
    return formatter.format(jewishDate);
  }

  /// Returns the Hebrew month name for display.
  /// Uses Hebrew characters by default, or transliterated if [useEnglish] is true.
  ///
  /// Example:
  /// ```dart
  /// final monthName = HebrewCalendarUtils.getHebrewMonthName(
  ///   JewishDate.TEVES,
  ///   hebrewYear: 5786,
  /// );
  /// // Returns: "טבת"
  /// ```
  static String getHebrewMonthName(
    int month, {
    required int hebrewYear,
    bool useEnglish = false,
  }) {
    final jewishDate = JewishDate.initDate(
      jewishYear: hebrewYear,
      jewishMonth: month,
      jewishDayOfMonth: 1,
    );
    final formatter = HebrewDateFormatter();
    formatter.hebrewFormat = !useEnglish;
    return formatter.formatMonth(jewishDate);
  }
}
