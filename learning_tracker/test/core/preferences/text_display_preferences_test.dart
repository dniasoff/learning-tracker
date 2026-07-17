/// Tests for the [FontSize] enum.
// Covers:
//   - FontSize.multiplier and FontSize.label
//
// AUD-core-preferences-03: the TextDisplayPreferences singleton this file
// used to test was DEAD -- it read/wrote unscoped legacy SharedPreferences
// keys directly and nothing under lib/ consumed it (the real font-size /
// nikud state flows through core/preferences/preference_providers.dart's
// currentFontSizeProvider / showNikudPrefProvider, which are backed by the
// profile-scoped TextDisplayPreference / NikudPreference instead). The
// singleton has been deleted; this file now covers only the FontSize enum,
// which IS genuinely used (text_display_screen.dart, text_display_providers.dart,
// preference_providers.dart). The provider-level write+read round trip is
// covered by epic_02_content_test.dart's "AC: font size adjustable" and
// "showNikudPrefProvider defaults to true and persists" tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';

void main() {
  group('FontSize.multiplier', () {
    test('small has multiplier 0.85', () {
      expect(FontSize.small.multiplier, closeTo(0.85, 0.001));
    });

    test('medium has multiplier 1.0', () {
      expect(FontSize.medium.multiplier, 1.0);
    });

    test('large has multiplier 1.2', () {
      expect(FontSize.large.multiplier, closeTo(1.2, 0.001));
    });
  });

  group('FontSize.label', () {
    test('small label is Small', () {
      expect(FontSize.small.label, 'Small');
    });

    test('medium label is Medium', () {
      expect(FontSize.medium.label, 'Medium');
    });

    test('large label is Large', () {
      expect(FontSize.large.label, 'Large');
    });
  });

  group('FontSize enum', () {
    test('each enum value has a distinct multiplier', () {
      final multipliers = FontSize.values.map((f) => f.multiplier).toSet();
      expect(multipliers.length, FontSize.values.length);
    });
  });
}
