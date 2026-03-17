import 'package:kosher_dart/kosher_dart.dart';

/// Calculates Shabbos/Yom Tov start and end times using kosher_dart zmanim.
///
/// Supports two modes:
/// - **Location-based**: Uses latitude/longitude with ComplexZmanimCalendar
///   for precise candle lighting (18 min before sunset) and havdalah times.
/// - **Fixed times**: Uses user-configured fixed candle lighting and havdalah
///   hours/minutes (for users who prefer not to use location).
class ShabbosTimeService {
  const ShabbosTimeService();

  /// Returns true if the given [dateTime] falls within a Shabbos or Yom Tov
  /// quiet window, using location-based zmanim calculations.
  ///
  /// The quiet window is from candle lighting (Friday/Erev Yom Tov) through
  /// havdalah (Tzais/nightfall on Saturday/Motzei Yom Tov).
  bool isDuringShabbosWithLocation({
    required DateTime dateTime,
    required double latitude,
    required double longitude,
    double elevation = 0,
  }) {
    // Check if currently Shabbos (Friday evening through Saturday night)
    if (_isShabbosWindow(dateTime, latitude, longitude, elevation)) {
      return true;
    }

    // Check if currently Yom Tov
    final jewishCalendar = JewishCalendar.fromDateTime(dateTime);
    if (jewishCalendar.isYomTov() || jewishCalendar.isYomTovAssurBemelacha()) {
      return true;
    }

    // Check erev Yom Tov after candle lighting
    final tomorrow = dateTime.add(const Duration(days: 1));
    final tomorrowJewish = JewishCalendar.fromDateTime(tomorrow);
    if (tomorrowJewish.isYomTov() || tomorrowJewish.isYomTovAssurBemelacha()) {
      final candleLighting = _getCandleLighting(
        dateTime,
        latitude,
        longitude,
        elevation,
      );
      if (candleLighting != null && dateTime.isAfter(candleLighting)) {
        return true;
      }
    }

    return false;
  }

  /// Returns true if the given [dateTime] falls within a Shabbos or Yom Tov
  /// quiet window, using fixed start/end times.
  ///
  /// [startHour]/[startMinute]: quiet period start (e.g., Friday 18:00)
  /// [endHour]/[endMinute]: quiet period end (e.g., Saturday 20:00)
  bool isDuringShabbosWithFixedTimes({
    required DateTime dateTime,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    final local = dateTime.toLocal();
    final weekday = local.weekday;
    final localMinutes = local.hour * 60 + local.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Friday after start time
    if (weekday == DateTime.friday && localMinutes >= startMinutes) {
      return true;
    }

    // All day Saturday until end time
    if (weekday == DateTime.saturday && localMinutes < endMinutes) {
      return true;
    }

    return false;
  }

  /// Calculate candle lighting time for a given date and location.
  ///
  /// Returns null if calculation fails (e.g., extreme latitudes).
  DateTime? getCandleLightingTime({
    required DateTime date,
    required double latitude,
    required double longitude,
    double elevation = 0,
  }) {
    return _getCandleLighting(date, latitude, longitude, elevation);
  }

  /// Calculate havdalah (Tzais) time for a given date and location.
  ///
  /// Returns null if calculation fails (e.g., extreme latitudes).
  DateTime? getHavdalahTime({
    required DateTime date,
    required double latitude,
    required double longitude,
    double elevation = 0,
  }) {
    return _getTzais(date, latitude, longitude, elevation);
  }

  bool _isShabbosWindow(
    DateTime dateTime,
    double latitude,
    double longitude,
    double elevation,
  ) {
    final local = dateTime.toLocal();
    final weekday = local.weekday;

    if (weekday == DateTime.friday) {
      // Check if after candle lighting
      final candleLighting = _getCandleLighting(
        dateTime,
        latitude,
        longitude,
        elevation,
      );
      return candleLighting != null && dateTime.isAfter(candleLighting);
    }

    if (weekday == DateTime.saturday) {
      // Check if before havdalah
      final tzais = _getTzais(dateTime, latitude, longitude, elevation);
      return tzais == null || dateTime.isBefore(tzais);
    }

    return false;
  }

  DateTime? _getCandleLighting(
    DateTime dateTime,
    double latitude,
    double longitude,
    double elevation,
  ) {
    final geoLocation = GeoLocation.setLocation(
      'User Location',
      latitude,
      longitude,
      dateTime,
      elevation,
    );
    final calendar = ComplexZmanimCalendar.intGeoLocation(geoLocation)
      ..setCalendar(dateTime);
    return calendar.getCandleLighting();
  }

  DateTime? _getTzais(
    DateTime dateTime,
    double latitude,
    double longitude,
    double elevation,
  ) {
    final geoLocation = GeoLocation.setLocation(
      'User Location',
      latitude,
      longitude,
      dateTime,
      elevation,
    );
    final calendar = ComplexZmanimCalendar.intGeoLocation(geoLocation)
      ..setCalendar(dateTime);
    return calendar.getTzais();
  }
}
