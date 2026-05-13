import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile toggle controlling whether Jewish learning terms (chazara,
/// review section, …) render in Hebrew script vs English transliteration.
///
/// Independent of the app's UI locale and of [AppLocalePreference]. New
/// profiles default to **false** (English transliteration) per AC of DNI-328.
class HebrewTermsPreference extends ProfileScopedPreference<bool> {
  HebrewTermsPreference();

  @override
  bool get defaultValue => false;

  @override
  bool readFromPrefs(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getBool(
      ProfileScopedPreferenceKeys.hebrewTermsScript(profileId),
    );
    if (scoped != null) return scoped;
    if (profileId == 0) {
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
    int profileId,
    bool value,
  ) async {
    await prefs.setBool(
      ProfileScopedPreferenceKeys.hebrewTermsScript(profileId),
      value,
    );
  }
}
