import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile toggle controlling whether dates show on the Hebrew calendar
/// (vs the English / Gregorian calendar). New profiles default to **true**
/// (Hebrew calendar) so the app ships with Jewish calendar on first launch.
class HebrewDatePreference extends ProfileScopedPreference<bool> {
  HebrewDatePreference();

  @override
  bool get defaultValue => true;

  @override
  bool readFromPrefs(SharedPreferences prefs, String profileId) {
    // Delegates to the single source of truth for the scoped/legacy-key
    // read+default logic (matches TextDisplayPreference's pattern) so this
    // default can never drift from ProfileScopedPreferenceKeys' own default
    // again — see AUD-core-preferences-02.
    return ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, profileId);
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    String profileId,
    bool value,
  ) async {
    await prefs.setBool(
      ProfileScopedPreferenceKeys.useHebrewCalendar(profileId),
      value,
    );
  }
}
