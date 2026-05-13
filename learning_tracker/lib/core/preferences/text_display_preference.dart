import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile text-display font size. Persisted as an int (the [FontSize]
/// enum index). Defaults to [FontSize.medium].
class TextDisplayPreference extends ProfileScopedPreference<FontSize> {
  TextDisplayPreference();

  @override
  FontSize get defaultValue => FontSize.medium;

  @override
  FontSize readFromPrefs(SharedPreferences prefs, int profileId) {
    final idx = ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, profileId);
    if (idx >= 0 && idx < FontSize.values.length) {
      return FontSize.values[idx];
    }
    return defaultValue;
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    int profileId,
    FontSize value,
  ) async {
    await prefs.setInt(
      ProfileScopedPreferenceKeys.textFontSize(profileId),
      value.index,
    );
  }
}
