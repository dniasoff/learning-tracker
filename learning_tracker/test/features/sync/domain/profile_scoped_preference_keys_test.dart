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

    test('useHebrewCalendar key is scoped by profileId', () {
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

    test('textShowNikud key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textShowNikud(2),
        'text_display_show_nikud_p2',
      );
    });

    test('learningOrderParentControls key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.learningOrderParentControls(1),
        'learning_order_parent_controls_p1',
      );
    });

    test('hebrewTermsScript key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.hebrewTermsScript(9),
        'hebrew_terms_script_p9',
      );
    });

    test('transliterationVariant key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.transliterationVariant(4),
        'transliteration_variant_p4',
      );
    });

    test('uiPreferencesUpdatedAtMs key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(6),
        'ui_preferences_updated_at_ms_p6',
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
}
