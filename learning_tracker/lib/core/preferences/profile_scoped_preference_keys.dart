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

  /// Per-(profile, curriculum) siyum granularity: the FINEST milestone level a
  /// family wants celebrated for [curriculumStorageKey]. Curriculum is part of
  /// the key (not just the profile) because the choice is per-curriculum — a
  /// family may want per-masechta siyumim for Mishnayos but only a whole-Chumash
  /// siyum. Pass [CurriculumId.storageKey] as [curriculumStorageKey].
  static String siyumGranularity(int profileId, String curriculumStorageKey) =>
      'siyum_granularity_p${profileId}_$curriculumStorageKey';

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
      // Legacy key defaults to true — Hebrew calendar is the factory
      // default (matches HebrewDatePreference.defaultValue). The old
      // `?? false` was stale (AUD-core-preferences-02).
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
      // Legacy key defaults to true — Hebrew script is the factory default
      // (§9 of hebrew-terms.md). The old `?? false` was stale.
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
