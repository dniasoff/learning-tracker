/// Tests for TextDisplayPreferences and FontSize enum.
// Covers:
//   - FontSize.multiplier and FontSize.label
//   - TextDisplayPreferences.initialize, setFontSize, setShowNikud, reset
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Reset the singleton state between tests.
    TextDisplayPreferences.instance.reset();
  });

  // ── FontSize enum ─────────────────────────────────────────────────────────

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

  // ── TextDisplayPreferences singleton ─────────────────────────────────────

  group('TextDisplayPreferences — default state', () {
    test('fontSize defaults to medium before initialization', () {
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
    });

    test('showNikud defaults to true before initialization', () {
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });
  });

  group('TextDisplayPreferences', () {
    test('default fontSize is medium and showNikud is true', () {
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });
  });

  group('TextDisplayPreferences.initialize', () {
    test('initializes with default values when prefs are empty', () async {
      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });

    test('initializes from stored font size index', () async {
      SharedPreferences.setMockInitialValues({
        'text_display_font_size': FontSize.large.index,
      });
      TextDisplayPreferences.instance.reset();
      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.large);
    });

    test('initializes from stored nikud preference', () async {
      SharedPreferences.setMockInitialValues({
        'text_display_show_nikud': false,
      });
      TextDisplayPreferences.instance.reset();
      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.showNikud, isFalse);
    });

    test('initialize loads stored fontSize and nikud together', () async {
      SharedPreferences.setMockInitialValues({
        'text_display_font_size': FontSize.large.index,
        'text_display_show_nikud': false,
      });
      TextDisplayPreferences.instance.reset();
      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.large);
      expect(TextDisplayPreferences.instance.showNikud, isFalse);
    });

    test('is idempotent — second call does not override in-memory state', () async {
      await TextDisplayPreferences.instance.initialize();
      // Change in-memory state
      await TextDisplayPreferences.instance.setFontSize(FontSize.large);
      // Re-initialize — should not reset the in-memory value since already initialized.
      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.large);
    });
  });

  group('TextDisplayPreferences.setFontSize', () {
    test('updates in-memory font size', () async {
      await TextDisplayPreferences.instance.setFontSize(FontSize.small);
      expect(TextDisplayPreferences.instance.fontSize, FontSize.small);
    });

    test('persists font size to shared preferences', () async {
      await TextDisplayPreferences.instance.setFontSize(FontSize.large);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('text_display_font_size'), FontSize.large.index);
    });
  });

  group('TextDisplayPreferences.setShowNikud', () {
    test('updates in-memory showNikud', () async {
      await TextDisplayPreferences.instance.setShowNikud(false);
      expect(TextDisplayPreferences.instance.showNikud, isFalse);
    });

    test('persists showNikud to shared preferences', () async {
      await TextDisplayPreferences.instance.setShowNikud(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('text_display_show_nikud'), isFalse);
    });
  });

  group('TextDisplayPreferences.reset', () {
    test('resets font size to medium', () async {
      await TextDisplayPreferences.instance.setFontSize(FontSize.small);
      TextDisplayPreferences.instance.reset();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
    });

    test('resets showNikud to true', () async {
      await TextDisplayPreferences.instance.setShowNikud(false);
      TextDisplayPreferences.instance.reset();
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });

    test('reset restores defaults (combined)', () async {
      await TextDisplayPreferences.instance.setFontSize(FontSize.large);
      await TextDisplayPreferences.instance.setShowNikud(false);
      TextDisplayPreferences.instance.reset();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.medium);
      expect(TextDisplayPreferences.instance.showNikud, isTrue);
    });

    test('allows re-initialization after reset', () async {
      await TextDisplayPreferences.instance.initialize();
      TextDisplayPreferences.instance.reset();

      SharedPreferences.setMockInitialValues({
        'text_display_font_size': FontSize.small.index,
      });

      await TextDisplayPreferences.instance.initialize();
      expect(TextDisplayPreferences.instance.fontSize, FontSize.small);
    });
  });
}
