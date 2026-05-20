import 'dart:ui';

import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile UI locale. Stored as a language code string ('en' / 'he'); the
/// public `read`/`write` surface speaks in [Locale] so callers don't reinvent
/// the parse. Defaults to English.
class AppLocalePreference extends ProfileScopedPreference<Locale> {
  AppLocalePreference();

  static const _supported = {'en', 'he'};

  @override
  Locale get defaultValue => const Locale('en');

  @override
  Locale readFromPrefs(SharedPreferences prefs, int profileId) {
    final code = ProfileScopedPreferenceKeys.readAppLocale(prefs, profileId);
    if (_supported.contains(code)) return Locale(code);
    return defaultValue;
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    int profileId,
    Locale value,
  ) async {
    await prefs.setString(
      ProfileScopedPreferenceKeys.appLocale(profileId),
      value.languageCode,
    );
  }
}
