// Tests for TextDisplayPreferences and FontSize — covers:
//   - FontSize.multiplier (lines 10-18) and FontSize.label (lines 22-30)
//   - TextDisplayPreferences.initialize, setFontSize, setShowNikud, reset
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // =========================================================================
  // FontSize enum
  // =========================================================================

  group('FontSize.multiplier', () {
    test('small has multiplier 0.85', () {
      expect(FontSize.small.multiplier, 0.85);
    });

    test('medium has multiplier 1.0', () {
      expect(FontSize.medium.multiplier, 1.0);
    });

    test('large has multiplier 1.2', () {
      expect(FontSize.large.multiplier, 1.2);
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

  // =========================================================================
  // TextDisplayPreferences singleton
  // =========================================================================

  group('TextDisplayPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Reset singleton state between tests.
      TextDisplayPreferences.instance.reset();
    });

    test('default fontSize is medium and showNikud is true', () {
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });

    test('initialize loads defaults when no prefs stored', () async {
      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });

    test('initialize loads stored fontSize', () async {
      SharedPreferences.setMockInitialValues({
        'text_display_font_size': FontSize.large.index,
        'text_display_show_nikud': false,
      });
      TextDisplayPreferences.instance.reset();
      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.large);
      expect(TextDisplayPreferences.instance.showNikud, isFalse);
    });

    test('initialize is idempotent (called twice)', () async {
      await TextDisplayPreferences.instance.initialize();
      // Set font size to large after first init.
      await TextDisplayPreferences.instance.setFontSize(FontSize.large);
      // Second init should be a no-op (already initialized).
      await TextDisplayPreferences.instance.initialize();
      // Value should remain large (not reset to medium from prefs).
      expect(TextDisplayPreferences.instance.fontSize, FontSize.large);
    });

    test('setFontSize persists and updates in-memory value', () async {
      await TextDisplayPreferences.instance.setFontSize(FontSize.small);
      expect(TextDisplayPreferences.instance.fontSize, FontSize.small);
    });

    test('setShowNikud persists and updates in-memory value', () async {
      await TextDisplayPreferences.instance.setShowNikud(false);
      expect(TextDisplayPreferences.instance.showNikud, isFalse);
    });

    test('reset restores defaults', () async {
      await TextDisplayPreferences.instance.setFontSize(FontSize.large);
      await TextDisplayPreferences.instance.setShowNikud(false);
      TextDisplayPreferences.instance.reset();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });
  });
}
