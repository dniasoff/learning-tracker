/// Tests for ProfileScopedPreferenceKeys — covers both the key-builder
/// helpers and the read* methods with scoped and legacy fallback paths.
library;

// Tests for ProfileScopedPreferenceKeys — exercises all read* methods,
// covering both the scoped-key path and the legacy-key fallback path.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

const profileA = '01J5K7M2N4P6Q8R0S1T3V5W7X9';
const profileB = '01J5K7M2N4P6Q8R0S1T3V5W7Y9';
const profileC = '01J5K7M2N4P6Q8R0S1T3V5W8X9';
const profileD = '01J5K7M2N4P6Q8R0S1T3V6W7X9';
const profileE = '01J5K7M2N4P6Q8R0S1T4V5W7X9';

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
        ProfileScopedPreferenceKeys.appLocale(profileA),
        'app_locale_p$profileA',
      );
    });

    test('appLocale key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.appLocale(profileB),
        'app_locale_p$profileB',
      );
    });

    test('useHebrewCalendar key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.useHebrewCalendar(profileA),
        'use_hebrew_calendar_p$profileA',
      );
    });

    test('useHebrewCalendar key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.useHebrewCalendar(profileB),
        'use_hebrew_calendar_p$profileB',
      );
    });

    test('textFontSize key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textFontSize(profileA),
        'text_display_font_size_p$profileA',
      );
    });

    test('textFontSize key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textFontSize(profileB),
        'text_display_font_size_p$profileB',
      );
    });

    test('textShowNikud key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textShowNikud(profileA),
        'text_display_show_nikud_p$profileA',
      );
    });

    test('textShowNikud key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.textShowNikud(profileB),
        'text_display_show_nikud_p$profileB',
      );
    });

    test('learningOrderParentControls key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.learningOrderParentControls(profileA),
        'learning_order_parent_controls_p$profileA',
      );
    });

    test('learningOrderParentControls key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.learningOrderParentControls(profileB),
        'learning_order_parent_controls_p$profileB',
      );
    });

    test('hebrewTermsScript key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.hebrewTermsScript(profileA),
        'hebrew_terms_script_p$profileA',
      );
    });

    test('hebrewTermsScript key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.hebrewTermsScript(profileB),
        'hebrew_terms_script_p$profileB',
      );
    });

    test('transliterationVariant key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.transliterationVariant(profileA),
        'transliteration_variant_p$profileA',
      );
    });

    test('transliterationVariant key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.transliterationVariant(profileB),
        'transliteration_variant_p$profileB',
      );
    });

    test('uiPreferencesUpdatedAtMs key is scoped by profileId', () {
      expect(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileA),
        'ui_preferences_updated_at_ms_p$profileA',
      );
    });

    test('uiPreferencesUpdatedAtMs key includes profileId', () {
      expect(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileB),
        'ui_preferences_updated_at_ms_p$profileB',
      );
    });
  });

  // =========================================================================
  // readAppLocale
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readAppLocale', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({'app_locale_p$profileA': 'he'});
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readAppLocale(prefs, profileA), 'he');
    });

    test('falls back to legacy key for the no-profile sentinel', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'he'});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readAppLocale(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        'he',
      );
    });

    test('returns default en when nothing is set (real profile)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readAppLocale(prefs, profileB), 'en');
    });

    test(
      'returns default en when nothing is set (no-profile sentinel)',
      () async {
        final prefs = await SharedPreferences.getInstance();
        expect(
          ProfileScopedPreferenceKeys.readAppLocale(
            prefs,
            kNoProfilePreferenceSentinel,
          ),
          'en',
        );
      },
    );
  });

  // =========================================================================
  // readUseHebrewCalendar
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readUseHebrewCalendar', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({
        'use_hebrew_calendar_p$profileA': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, profileA),
        isTrue,
      );
    });

    test('falls back to legacy key for the no-profile sentinel', () async {
      SharedPreferences.setMockInitialValues({'use_hebrew_calendar': true});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        isTrue,
      );
    });

    // Default is true — Hebrew calendar is the factory default, matching
    // HebrewDatePreference.defaultValue (AUD-core-preferences-02: the old
    // `?? false` / `return false` fallback was stale).
    test('returns true when nothing is set (real profile)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, profileB),
        isTrue,
      );
    });

    test('returns true when nothing is set (no-profile sentinel)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readUseHebrewCalendar(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        isTrue,
      );
    });

    test(
      'falls back to legacy key explicit false for the no-profile sentinel '
      '(explicit false is honoured, not overridden by the default)',
      () async {
        SharedPreferences.setMockInitialValues({'use_hebrew_calendar': false});
        final prefs = await SharedPreferences.getInstance();
        expect(
          ProfileScopedPreferenceKeys.readUseHebrewCalendar(
            prefs,
            kNoProfilePreferenceSentinel,
          ),
          isFalse,
        );
      },
    );
  });

  // =========================================================================
  // readFontSizeIndex
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readFontSizeIndex', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({
        'text_display_font_size_p$profileA': 2,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, profileA), 2);
    });

    test('falls back to legacy key for the no-profile sentinel', () async {
      SharedPreferences.setMockInitialValues({'text_display_font_size': 3});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readFontSizeIndex(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        3,
      );
    });

    test('returns default 1 when nothing is set (real profile)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, profileB), 1);
    });

    test(
      'returns default 1 when nothing is set (no-profile sentinel)',
      () async {
        final prefs = await SharedPreferences.getInstance();
        expect(
          ProfileScopedPreferenceKeys.readFontSizeIndex(
            prefs,
            kNoProfilePreferenceSentinel,
          ),
          1,
        );
      },
    );
  });

  // =========================================================================
  // readShowNikud
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readShowNikud', () {
    test('returns scoped value when set to false', () async {
      SharedPreferences.setMockInitialValues({
        'text_display_show_nikud_p$profileA': false,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readShowNikud(prefs, profileA),
        isFalse,
      );
    });

    test('falls back to legacy key for the no-profile sentinel', () async {
      SharedPreferences.setMockInitialValues({
        'text_display_show_nikud': false,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readShowNikud(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        isFalse,
      );
    });

    test('returns default true when nothing is set (real profile)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readShowNikud(prefs, profileC),
        isTrue,
      );
    });

    test(
      'returns default true when nothing is set (no-profile sentinel)',
      () async {
        final prefs = await SharedPreferences.getInstance();
        expect(
          ProfileScopedPreferenceKeys.readShowNikud(
            prefs,
            kNoProfilePreferenceSentinel,
          ),
          isTrue,
        );
      },
    );
  });

  // =========================================================================
  // readLearningOrderParentControls
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readLearningOrderParentControls', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({
        'learning_order_parent_controls_p$profileA': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(
          prefs,
          profileA,
        ),
        isTrue,
      );
    });

    test('falls back to legacy key for the no-profile sentinel', () async {
      SharedPreferences.setMockInitialValues({
        'learning_order_parent_controls': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        isTrue,
      );
    });

    test('returns false when nothing is set (real profile)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(
          prefs,
          profileB,
        ),
        isFalse,
      );
    });

    test('returns false when nothing is set (no-profile sentinel)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        isFalse,
      );
    });
  });

  // =========================================================================
  // readHebrewTermsScript
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readHebrewTermsScript', () {
    test('returns scoped value when set', () async {
      SharedPreferences.setMockInitialValues({
        'hebrew_terms_script_p$profileA': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, profileA),
        isTrue,
      );
    });

    test('falls back to legacy key for the no-profile sentinel', () async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script': true});
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        isTrue,
      );
    });

    // Default is true — Hebrew script is the factory default (§9 / §11.7 fix).
    test('returns true when nothing is set (real profile)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, profileC),
        isTrue,
      );
    });

    test('returns true when nothing is set (no-profile sentinel)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readHebrewTermsScript(
          prefs,
          kNoProfilePreferenceSentinel,
        ),
        isTrue,
      );
    });
  });

  // =========================================================================
  // readTransliterationVariant
  // =========================================================================

  group('ProfileScopedPreferenceKeys.readTransliterationVariant', () {
    test('returns stored value when set', () async {
      SharedPreferences.setMockInitialValues({
        'transliteration_variant_p$profileA': 'sephardi',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readTransliterationVariant(prefs, profileA),
        'sephardi',
      );
    });

    test('returns default ashkenazi when not set', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        ProfileScopedPreferenceKeys.readTransliterationVariant(prefs, profileA),
        'ashkenazi',
      );
    });
  });
}
