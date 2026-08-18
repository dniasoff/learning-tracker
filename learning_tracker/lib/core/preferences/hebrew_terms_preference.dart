import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart'
    show ProfileScopedPreference, kNoProfilePreferenceSentinel;
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile toggle controlling whether Jewish learning terms (chazara,
/// review section, …) render in Hebrew script vs English transliteration.
///
/// Independent of the app's UI locale (which follows the device language). New
/// profiles default to **true** (Hebrew script) so the app ships with
/// Hebrew terms on first launch.
class HebrewTermsPreference extends ProfileScopedPreference<bool> {
  HebrewTermsPreference();

  @override
  bool get defaultValue => true;

  @override
  bool readFromPrefs(SharedPreferences prefs, String profileId) {
    final scoped = prefs.getBool(
      ProfileScopedPreferenceKeys.hebrewTermsScript(profileId),
    );
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
      return prefs.getBool(
            ProfileScopedPreferenceKeys.legacyHebrewTermsScriptKey,
          ) ??
          defaultValue;
    }
    return defaultValue;
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    String profileId,
    bool value,
  ) async {
    await prefs.setBool(
      ProfileScopedPreferenceKeys.hebrewTermsScript(profileId),
      value,
    );
  }
}
