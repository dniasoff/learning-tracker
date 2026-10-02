/// [StreakAlertMarkers] in SharedPreferences (DNI-479): device-local, keyed
/// by profile and curriculum, as the rest of the notification preferences.
library;

import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SharedPreferences key prefix of the streak-alert markers.
const String streakAlertMarkerKeyPrefix = 'streak_alert_marker';

/// The SharedPreferences key of [profileId]'s marker for [curriculumId].
String streakAlertMarkerKey(String profileId, String curriculumId) =>
    '${streakAlertMarkerKeyPrefix}_${profileId}_$curriculumId';

/// SharedPreferences-backed [StreakAlertMarkers].
class SharedPrefsStreakAlertMarkers implements StreakAlertMarkers {
  /// Creates the store; [prefs] defaults to the app instance.
  SharedPrefsStreakAlertMarkers({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  @override
  Future<String?> read(String profileId, String curriculumId) async =>
      (await _prefs()).getString(streakAlertMarkerKey(profileId, curriculumId));

  @override
  Future<void> write(
    String profileId,
    String curriculumId,
    String marker,
  ) async {
    await (await _prefs()).setString(
      streakAlertMarkerKey(profileId, curriculumId),
      marker,
    );
  }

  @override
  Future<void> clear(String profileId, String curriculumId) async {
    await (await _prefs()).remove(
      streakAlertMarkerKey(profileId, curriculumId),
    );
  }

  @override
  Future<void> clearAll(String profileId) async {
    final prefs = await _prefs();
    final prefix = '${streakAlertMarkerKeyPrefix}_${profileId}_';
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      await prefs.remove(key);
    }
  }
}
