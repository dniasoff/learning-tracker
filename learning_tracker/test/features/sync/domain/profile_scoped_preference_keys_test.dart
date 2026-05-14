/// Tests for ProfileScopedPreferenceKeys — covers both the key-builder
/// helpers and the read* methods with scoped and legacy fallback paths.
library;

// Tests for ProfileScopedPreferenceKeys — exercises all read* methods,
// covering both the scoped-key path and the legacy-key fallback path.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // Key generators (static getters / functions)
  // =========================================================================

  group('ProfileScopedPreferenceKeys — key generators', () {
    test('appLocale key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.appLocale(5),
        'app_locale_p5',
      );
    });

    test('appLocale key includes profileId', () {
      expect(ProfileScopedPreferenceKeys.appLocale(5), 'app_locale_p5');
    });

    test('useHebrewCalendar key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.useHebrewCalendar(3),
        'use_hebrew_calendar_p3',
      );
    });

    test('useHebrewCalendar key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.useHebrewCalendar(3),
        'use_hebrew_calendar_p3',
      );
    });

    test('textFontSize key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textFontSize(7),
        'text_display_font_size_p7',
      );
    });

    test('textFontSize key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textFontSize(2),
        'text_display_font_size_p2',
      );
    });

    test('textShowNikud key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textShowNikud(2),
        'text_display_show_nikud_p2',
      );
    });

    test('textShowNikud key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textShowNikud(1),
        'text_display_show_nikud_p1',
      );
    });

    test('learningOrderParentControls key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.learningOrderParentControls(1),
        'learning_order_parent_controls_p1',
      );
    });

    test('learningOrderParentControls key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.learningOrderParentControls(6),
        'learning_order_parent_controls_p6',
      );
    });

    test('hebrewTermsScript key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.hebrewTermsScript(9),
        'hebrew_terms_script_p9',
      );
    });

    test('hebrewTermsScript key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.hebrewTermsScript(7),
        'hebrew_terms_script_p7',
      );
    });

    test('transliterationVariant key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.transliterationVariant(4),
        'transliteration_variant_p4',
      );
    });

    test('transliterationVariant key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.transliterationVariant(9),
        'transliteration_variant_p9',
      );
    });

    test('uiPreferencesUpdatedAtMs key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(6),
        'ui_preferences_updated_at_ms_p6',
      );
    });

    test('uiPreferencesUpdatedAtMs key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(4),
        'ui_preferences_updated_at_ms_p4',
      );
    });
  });

  // =========================================================================
  // readAppLocale
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readAppLocale', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({'app_locale_p1': 'he'});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readAppLocale(prefs, 1),
        'he',
      );
    });

    test('falls back to legacy key for profileId 0', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'he'});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readAppLocale(prefs, 0),
        'he',
      );
    });

    test('returns default en when nothing is set (non-zero profileId)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readAppLocale(prefs, 5), 'en');
    });

    test('returns default en when nothing is set (profileId 0)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readAppLocale(prefs, 0), 'en');
    });
  });

  group('readAppLocale', () {
    test('returns scoped value when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale_p1', 'he');
      expect(
        ProfileScopedPreferenceKeys.readAppLocale(prefs, 1),
        'he',
      );
    });

    test('falls back to legacy key for profile 0', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.legacyAppLocaleKey: 'he',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readAppLocale(prefs, 0),
        'he',
      );
    });

    test('returns "en" by default for non-zero profile with no value', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readAppLocale(prefs, 5),
        'en',
      );
    });

    test('returns "en" for profile 0 when no legacy key present', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readAppLocale(prefs, 0),
        'en',
      );
    });
  });

  // =========================================================================
  // readUseHebrewCalendar
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readUseHebrewCalendar', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({'use_hebrew_calendar_p2': true});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 2),
        isTrue,
      );
    });

    test('falls back to legacy key for profileId 0', () async {
      SharedPreferences.setMockInitialValues({'use_hebrew_calendar': true});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 0),
        isTrue,
      );
    });

    test('returns false when nothing is set (non-zero profileId)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 3),
        isFalse,
      );
    });

    test('returns false when nothing is set (profileId 0)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 0),
        isFalse,
      );
    });
  });

  group('readUseHebrewCalendar', () {
    test('returns scoped value when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_hebrew_calendar_p2', true);
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 2),
        isTrue,
      );
    });

    test('falls back to legacy key for profile 0', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.legacyUseHebrewCalendarKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 0),
        isTrue,
      );
    });

    test('returns false by default for non-zero profile', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 3),
        isFalse,
      );
    });
  });

  // =========================================================================
  // readFontSizeIndex
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readFontSizeIndex', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({'text_display_font_size_p4': 2});
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, 4), 2);
    });

    test('falls back to legacy key for profileId 0', () async {
      SharedPreferences.setMockInitialValues({'text_display_font_size': 3});
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, 0), 3);
    });

    test('returns default 1 when nothing is set (non-zero profileId)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, 5), 1);
    });

    test('returns default 1 when nothing is set (profileId 0)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, 0), 1);
    });
  });

  group('readFontSizeIndex', () {
    test('returns scoped value when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('text_display_font_size_p1', 2);
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, 1), 2);
    });

    test('falls back to legacy key for profile 0', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.legacyFontSizeKey: 2,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, 0), 2);
    });

    test('returns default 1 for non-zero profile', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, 4), 1);
    });
  });

  // =========================================================================
  // readShowNikud
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readShowNikud', () {
    test('returns scoped value when set to false', () async {
      SharedPreferences.setMockInitialValues(
        {'text_display_show_nikud_p1': false},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readShowNikud(prefs, 1), isFalse);
    });

    test('falls back to legacy key for profileId 0', () async {
      SharedPreferences.setMockInitialValues({'text_display_show_nikud': false});
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readShowNikud(prefs, 0), isFalse);
    });

    test('returns default true when nothing is set (non-zero profileId)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readShowNikud(prefs, 6), isTrue);
    });

    test('returns default true when nothing is set (profileId 0)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readShowNikud(prefs, 0), isTrue);
    });
  });

  group('readShowNikud', () {
    test('returns scoped value when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('text_display_show_nikud_p1', false);
      expect(
        ProfileScopedPreferenceKeys.readShowNikud(prefs, 1),
        isFalse,
      );
    });

    test('falls back to legacy key for profile 0', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.legacyShowNikudKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readShowNikud(prefs, 0),
        isFalse,
      );
    });

    test('returns true by default for non-zero profile', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readShowNikud(prefs, 2), isTrue);
    });
  });

  // =========================================================================
  // readLearningOrderParentControls
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readLearningOrderParentControls', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues(
        {'learning_order_parent_controls_p3': true},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(prefs, 3),
        isTrue,
      );
    });

    test('falls back to legacy key for profileId 0', () async {
      SharedPreferences.setMockInitialValues(
        {'learning_order_parent_controls': true},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(prefs, 0),
        isTrue,
      );
    });

    test('returns false when nothing is set (non-zero profileId)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(prefs, 7),
        isFalse,
      );
    });

    test('returns false when nothing is set (profileId 0)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(prefs, 0),
        isFalse,
      );
    });
  });

  group('readLearningOrderParentControls', () {
    test('returns scoped value when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('learning_order_parent_controls_p3', true);
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(prefs, 3),
        isTrue,
      );
    });

    test('falls back to legacy key for profile 0', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.legacyLearningOrderKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(prefs, 0),
        isTrue,
      );
    });

    test('returns false by default', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(prefs, 5),
        isFalse,
      );
    });
  });

  // =========================================================================
  // readHebrewTermsScript
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readHebrewTermsScript', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p2': true});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 2),
        isTrue,
      );
    });

    test('falls back to legacy key for profileId 0', () async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script': true});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 0),
        isTrue,
      );
    });

    test('returns false when nothing is set (non-zero profileId)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 8),
        isFalse,
      );
    });

    test('returns false when nothing is set (profileId 0)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 0),
        isFalse,
      );
    });
  });

  group('readHebrewTermsScript', () {
    test('returns scoped value when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hebrew_terms_script_p1', true);
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 1),
        isTrue,
      );
    });

    test('falls back to legacy key for profile 0', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.legacyHebrewTermsScriptKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 0),
        isTrue,
      );
    });

    test('returns false by default for non-zero profile', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 6),
        isFalse,
      );
    });
  });

  // =========================================================================
  // readTransliterationVariant
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readTransliterationVariant', () {
    test('returns stored value when set', () async {
      SharedPreferences.setMockInitialValues(
        {'transliteration_variant_p1': 'sephardi'},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readTransliterationVariant(prefs, 1),
        'sephardi',
      );
    });

    test('returns default ashkenazi when not set', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readTransliterationVariant(prefs, 1),
        'ashkenazi',
      );
    });
  });

  group('readTransliterationVariant', () {
    test('returns stored value when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('transliteration_variant_p1', 'sephardi');
      expect(
        ProfileScopedPreferenceKeys.readTransliterationVariant(prefs, 1),
        'sephardi',
      );
    });

    test('returns "ashkenazi" by default', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readTransliterationVariant(prefs, 1),
        'ashkenazi',
      );
    });
  });
}
