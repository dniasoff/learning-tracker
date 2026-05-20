import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile toggle for displaying Hebrew vowel points (nikud) in the text
/// display screen. Defaults to **true** — most users want pointed text on
/// first launch.
class NikudPreference extends ProfileScopedPreference<bool> {
  NikudPreference();

  @override
  bool get defaultValue => true;

  @override
  bool readFromPrefs(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getBool(
      ProfileScopedPreferenceKeys.textShowNikud(profileId),
    );
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getBool(ProfileScopedPreferenceKeys.legacyShowNikudKey) ??
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
      ProfileScopedPreferenceKeys.textShowNikud(profileId),
      value,
    );
  }
}
