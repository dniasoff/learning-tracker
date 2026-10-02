import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
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

  static String appLocale(String profileId) => 'app_locale_p$profileId';

  static String useHebrewCalendar(String profileId) =>
      'use_hebrew_calendar_p$profileId';

  static String textFontSize(String profileId) =>
      'text_display_font_size_p$profileId';

  static String textShowNikud(String profileId) =>
      'text_display_show_nikud_p$profileId';

  static String learningOrderParentControls(String profileId) =>
      'learning_order_parent_controls_p$profileId';

  static String hebrewTermsScript(String profileId) =>
      'hebrew_terms_script_p$profileId';

  static String transliterationVariant(String profileId) =>
      'transliteration_variant_p$profileId';

  static String uiPreferencesUpdatedAtMs(String profileId) =>
      'ui_preferences_updated_at_ms_p$profileId';

  /// Per-(profile, curriculum) siyum granularity: the FINEST milestone level a
  /// family wants celebrated for [curriculumStorageKey]. Curriculum is part of
  /// the key (not just the profile) because the choice is per-curriculum — a
  /// family may want per-masechta siyumim for Mishnayos but only a whole-Chumash
  /// siyum. Pass [CurriculumId.storageKey] as [curriculumStorageKey].
  static String siyumGranularity(
    String profileId,
    String curriculumStorageKey,
  ) => 'siyum_granularity_p${profileId}_$curriculumStorageKey';

  /// Prefix of every per-device siyum-shown key of [profileId] (AD-15,
  /// DNI-474 AC-4). Device-local: never part of the synced UI preferences.
  static String siyumShownPrefix(String profileId) =>
      'siyum_shown_p${profileId}_';

  /// The per-device siyum-shown key of one completion: scoped by
  /// [profileId], the unit ([curriculumStorageKey] + [unitRef]) and the
  /// unit's `first_completed_at(1)` ([firstCompletedAt], the engine's
  /// `effectiveAt` instant). A void that takes the siyum away clears it, and
  /// a later re-completion has a new instant and so a new key (Consistency
  /// → Siyum; `prd-deviations` #11).
  static String siyumShown(
    String profileId,
    String curriculumStorageKey,
    String unitRef,
    DateTime firstCompletedAt,
  ) =>
      '${siyumShownPrefix(profileId)}${curriculumStorageKey}_'
      '${Uri.encodeComponent(unitRef)}_'
      '${firstCompletedAt.toUtc().microsecondsSinceEpoch}';

  /// Whether this device has seeded [profileId]'s already-completed units
  /// (so installing the app, or the cutover, does not replay every past
  /// siyum at once).
  static String siyumShownSeeded(String profileId) =>
      'siyum_shown_seeded_p$profileId';

  static String readAppLocale(SharedPreferences prefs, String profileId) {
    final scoped = prefs.getString(appLocale(profileId));
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
      return prefs.getString(legacyAppLocaleKey) ?? 'en';
    }
    return 'en';
  }

  static bool readUseHebrewCalendar(SharedPreferences prefs, String profileId) {
    final scoped = prefs.getBool(useHebrewCalendar(profileId));
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
      // Legacy key defaults to true — Hebrew calendar is the factory
      // default (matches HebrewDatePreference.defaultValue). The old
      // `?? false` was stale (AUD-core-preferences-02).
      return prefs.getBool(legacyUseHebrewCalendarKey) ?? true;
    }
    return true;
  }

  static int readFontSizeIndex(SharedPreferences prefs, String profileId) {
    final scoped = prefs.getInt(textFontSize(profileId));
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
      return prefs.getInt(legacyFontSizeKey) ?? 1;
    }
    return 1;
  }

  static bool readShowNikud(SharedPreferences prefs, String profileId) {
    final scoped = prefs.getBool(textShowNikud(profileId));
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
      return prefs.getBool(legacyShowNikudKey) ?? true;
    }
    return true;
  }

  static bool readLearningOrderParentControls(
    SharedPreferences prefs,
    String profileId,
  ) {
    final scoped = prefs.getBool(learningOrderParentControls(profileId));
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
      return prefs.getBool(legacyLearningOrderKey) ?? false;
    }
    return false;
  }

  static bool readHebrewTermsScript(SharedPreferences prefs, String profileId) {
    final scoped = prefs.getBool(hebrewTermsScript(profileId));
    if (scoped != null) return scoped;
    if (profileId == kNoProfilePreferenceSentinel) {
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
    String profileId,
  ) {
    return prefs.getString(transliterationVariant(profileId)) ?? 'ashkenazi';
  }
}
