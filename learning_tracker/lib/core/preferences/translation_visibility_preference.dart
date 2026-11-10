import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart'
    show ProfileScopedPreference, kNoProfilePreferenceSentinel;
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile preference for showing inline English glosses in the reader.
/// Defaults to on; the reader only exposes this preference when English exists.
class TranslationVisibilityPreference extends ProfileScopedPreference<bool> {
  TranslationVisibilityPreference();

  @override
  bool get defaultValue => true;

  @override
  bool readFromPrefs(SharedPreferences prefs, String profileId) {
    final scoped = prefs.getBool(
      ProfileScopedPreferenceKeys.textShowTranslation(profileId),
    );
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
      return prefs.getBool(
            ProfileScopedPreferenceKeys.legacyShowTranslationKey,
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
      ProfileScopedPreferenceKeys.textShowTranslation(profileId),
      value,
    );
  }
}
