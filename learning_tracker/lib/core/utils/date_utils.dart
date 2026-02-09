/// Utilities for date handling following P5 pattern:
/// - All stored dates are UTC
/// - Local timezone conversion only in presentation layer
/// - Never use DateTime.now() in data/domain layers
library;

/// Factory helpers for creating UTC DateTime instances.
/// Use these instead of DateTime.now() to ensure UTC storage.
class DateTimeFactory {
  /// Returns current UTC time.
  /// Use this instead of DateTime.now() in data/domain layers.
  static DateTime nowUtc() {
    return DateTime.now().toUtc();
  }

  /// Creates a UTC DateTime from components.
  /// Ensures the result is always in UTC timezone.
  static DateTime utc(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) {
    return DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
  }

  /// Converts any DateTime to UTC.
  static DateTime toUtc(DateTime dateTime) {
    return dateTime.toUtc();
  }
}

/// Utilities for date operations following P5 pattern.
class DateUtils {
  /// Extracts the local date (year, month, day) from a UTC DateTime.
  /// Per P5: streak day boundary uses local timezone.
  ///
  /// Example: Two completions on same local date count as same day,
  /// even if they're on different UTC dates.
  static DateTime extractLocalDate(DateTime utcDateTime) {
    final local = utcDateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Checks if two UTC DateTimes fall on the same local date.
  /// Used for streak calculations per P5.
  static bool isSameLocalDay(DateTime utcDateTime1, DateTime utcDateTime2) {
    final date1 = extractLocalDate(utcDateTime1);
    final date2 = extractLocalDate(utcDateTime2);
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Returns the start of the local day (00:00:00 local time) as UTC.
  /// Useful for comparing dates in UTC while respecting local day boundaries.
  static DateTime startOfLocalDay(DateTime utcDateTime) {
    final local = utcDateTime.toLocal();
    final startOfDay = DateTime(local.year, local.month, local.day);
    return startOfDay.toUtc();
  }

  /// Returns the end of the local day (23:59:59.999 local time) as UTC.
  static DateTime endOfLocalDay(DateTime utcDateTime) {
    final local = utcDateTime.toLocal();
    final endOfDay = DateTime(
      local.year,
      local.month,
      local.day,
      23,
      59,
      59,
      999,
      999,
    );
    return endOfDay.toUtc();
  }
}
