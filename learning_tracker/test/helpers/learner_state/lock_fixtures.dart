/// Hermetic fixtures for the DNI-466 lock and streak tests: learner
/// settings at real locations, settings histories, and independent
/// kosher_dart zmanim to check the lock bounds against.
library;

import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';

import '../learner_state_fixtures.dart';

/// Settings for [profileUlid].
LearnerSettings lockSettings({
  String timeZone = 'America/New_York',
  double? latitude,
  double? longitude,
  bool? inIsrael,
}) => LearnerSettings(
  profileId: profileUlid,
  timeZone: timeZone,
  latitude: latitude,
  longitude: longitude,
  inIsrael: inIsrael,
);

/// Lakewood, NJ (diaspora).
final lakewood = lockSettings(
  latitude: 40.0821,
  longitude: -74.2097,
  inIsrael: false,
);

/// Jerusalem (Israel).
final jerusalem = lockSettings(
  timeZone: 'Asia/Jerusalem',
  latitude: 31.778,
  longitude: 35.235,
  inIsrael: true,
);

/// New York time zone with no configured location.
final newYorkNoLocation = lockSettings();

/// New York with a configured location, for tests that exercise a real lock.
final newYorkLocated = lockSettings(
  latitude: 40.7128,
  longitude: -74.006,
  inIsrael: false,
);

/// A one-span history holding [s].
LearnerSettingsHistory constantHistory(LearnerSettings s) =>
    LearnerSettingsHistory.constant(s);

/// [before] until [changeAt], then [after].
LearnerSettingsHistory movedHistory(
  LearnerSettings before,
  DateTime changeAt,
  LearnerSettings after,
) => LearnerSettingsHistory([
  SettingsSpan(fromUtc: null, settings: before),
  SettingsSpan(fromUtc: changeAt, settings: after),
]);

ComplexZmanimCalendar _calendar(double lat, double lng, DateTime day) {
  final date = DateTime.utc(day.year, day.month, day.day);
  return ComplexZmanimCalendar.intGeoLocation(
    GeoLocation.setLocation('fixture', lat, lng, date),
  )..setCalendar(date);
}

/// kosher_dart's own candle-lighting instant on civil [day] (standard
/// offset before sea-level sunset), or null.
DateTime? kosherCandleLighting(double lat, double lng, DateTime day) {
  final cal = _calendar(lat, lng, day);
  final sunset = cal.getSeaLevelSunset();
  if (sunset == null) return null;
  return sunset.toUtc().subtract(
    Duration(seconds: (cal.getCandleLightingOffset() * 60).round()),
  );
}

/// kosher_dart's own tzeis (8.5°) instant on civil [day], or null.
DateTime? kosherTzeis(double lat, double lng, DateTime day) =>
    _calendar(lat, lng, day).getTzais()?.toUtc();
