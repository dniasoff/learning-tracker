import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for UI-related settings, scoped per learner profile so
/// cloud sync can restore them on a new device without colliding across profiles.
class ProfileScopedPreferenceKeys {
  ProfileScopedPreferenceKeys._();

  static const legacyAppLocaleKey = 'app_locale';
  static const legacyUseHebrewCalendarKey = 'use_hebrew_calendar';
  static const legacyFontSizeKey = 'text_display_font_size';
  static const legacyShowNikudKey = 'text_display_show_nikud';
  static const legacyLearningOrderKey = 'learning_order_parent_controls';
  static const legacyHebrewTermsScriptKey = 'hebrew_terms_script';

  static String appLocale(int profileId) => 'app_locale_p$profileId';

  static String useHebrewCalendar(int profileId) =>
      'use_hebrew_calendar_p$profileId';

  static String textFontSize(int profileId) =>
      'text_display_font_size_p$profileId';

  static String textShowNikud(int profileId) =>
      'text_display_show_nikud_p$profileId';

  static String learningOrderParentControls(int profileId) =>
      'learning_order_parent_controls_p$profileId';

  static String hebrewTermsScript(int profileId) =>
      'hebrew_terms_script_p$profileId';

  static String transliterationVariant(int profileId) =>
      'transliteration_variant_p$profileId';

  static String uiPreferencesUpdatedAtMs(int profileId) =>
      'ui_preferences_updated_at_ms_p$profileId';

  static String readAppLocale(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getString(appLocale(profileId));
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getString(legacyAppLocaleKey) ?? 'en';
    }
    return 'en';
  }

  static bool readUseHebrewCalendar(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getBool(useHebrewCalendar(profileId));
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getBool(legacyUseHebrewCalendarKey) ?? true;
    }
    return true;
  }

  static int readFontSizeIndex(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getInt(textFontSize(profileId));
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getInt(legacyFontSizeKey) ?? 1;
    }
    return 1;
  }

  static bool readShowNikud(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getBool(textShowNikud(profileId));
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getBool(legacyShowNikudKey) ?? true;
    }
    return true;
  }

  static bool readLearningOrderParentControls(
    SharedPreferences prefs,
    int profileId,
  ) {
    final scoped = prefs.getBool(learningOrderParentControls(profileId));
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getBool(legacyLearningOrderKey) ?? false;
    }
    return false;
  }

  static bool readHebrewTermsScript(SharedPreferences prefs, int profileId) {
    final scoped = prefs.getBool(hebrewTermsScript(profileId));
    if (scoped != null) return scoped;
    if (profileId == 0) {
      return prefs.getBool(legacyHebrewTermsScriptKey) ?? true;
    }
    return true;
  }

  /// Reads the saved transliteration variant ("ashkenazi" or "sephardi").
  /// Defaults to "ashkenazi" when no setting has been persisted yet.
  static String readTransliterationVariant(
    SharedPreferences prefs,
    int profileId,
  ) {
    return prefs.getString(transliterationVariant(profileId)) ?? 'ashkenazi';
  }
}
