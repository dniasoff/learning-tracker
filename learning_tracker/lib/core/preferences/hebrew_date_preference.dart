import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile toggle controlling whether dates show on the Hebrew calendar
/// (vs the English / Gregorian calendar). New profiles default to **false**
/// (English calendar) per AC of DNI-328.
class HebrewDatePreference extends ProfileScopedPreference<bool> {
  HebrewDatePreference();

  @override
  bool get defaultValue => false;

  @override
  bool readFromPrefs(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getBool(
      ProfileScopedPreferenceKeys.useHebrewCalendar(profileId),
    );
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getBool(
            ProfileScopedPreferenceKeys.legacyUseHebrewCalendarKey,
          ) ??
          defaultValue;
    }
    return defaultValue;
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    int profileId,
    bool value,
  ) async {
    await prefs.setBool(
      ProfileScopedPreferenceKeys.useHebrewCalendar(profileId),
      value,
    );
  }
}
