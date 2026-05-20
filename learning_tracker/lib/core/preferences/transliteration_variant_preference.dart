import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile Hebrew-transliteration dialect (Ashkenazi vs Sephardi) used
/// when rendering named values in English mode. Defaults to Ashkenazi.
class TransliterationVariantPreference
    extends ProfileScopedPreference<TransliterationVariant> {
  TransliterationVariantPreference();

  @override
  TransliterationVariant get defaultValue => TransliterationVariant.ashkenazi;

  @override
  TransliterationVariant readFromPrefs(SharedPreferences prefs, int profileId) {
    final raw = ProfileScopedPreferenceKeys.readTransliterationVariant(
      prefs,
      profileId,
    );
    return raw == TransliterationVariant.sephardi.name
        ? TransliterationVariant.sephardi
        : TransliterationVariant.ashkenazi;
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    int profileId,
    TransliterationVariant value,
  ) async {
    await prefs.setString(
      ProfileScopedPreferenceKeys.transliterationVariant(profileId),
      value.name,
    );
  }
}
