// Regression test for IL-4: brandCoral* constants were mis-defined as
// SlateGray (0xFF708090), giving zero warning/urgency to error snackbars and
// destructive offline cards.  The fix introduces brandWarning* (real coral
// palette).
//
// The test deliberately checks the component values so any future accidental
// revert back to the slate-gray values is caught immediately.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

void main() {
  group('IL-4 — brandWarning* constants are true coral (not SlateGray)', () {
    test('brandWarning is a warm coral — NOT the slate 0xFF708090', () {
      // The old mis-named brandCoral was 0xFF708090 (CSS SlateGray). A real
      // warning colour must have a red channel significantly higher than its
      // blue channel.
      final color = AppPalette.light.brandWarning;
      expect(
        color.r,
        greaterThan(color.b),
        reason: 'Warning colour must lean red/warm, not cool/grey',
      );
      expect(
        color.toARGB32(),
        isNot(0xFF708090),
        reason: 'brandWarning must not be SlateGray (0xFF708090)',
      );
    });

    test(
      'brandWarningSoft is a warm coral tint — NOT the slate 0xFFD8DEE3',
      () {
        final color = AppPalette.light.brandWarningSoft;
        expect(
          color.toARGB32(),
          isNot(0xFFD8DEE3),
          reason: 'brandWarningSoft must not be the old slate tint 0xFFD8DEE3',
        );
        expect(
          color.r,
          greaterThan(color.b),
          reason: 'Soft warning must lean warm',
        );
      },
    );

    test('brandWarningDeep is a dark coral — NOT the slate 0xFF4E5E70', () {
      final color = AppPalette.light.brandWarningDeep;
      expect(
        color.toARGB32(),
        isNot(0xFF4E5E70),
        reason: 'brandWarningDeep must not be old dark slate 0xFF4E5E70',
      );
      expect(
        color.r,
        greaterThan(color.b),
        reason: 'Deep warning must lean warm/red',
      );
    });

    test('brandWarningDeep has sufficient darkness for text-on-white AA', () {
      // brandWarningDeep is used as a text/icon colour so it must be dark
      // enough. Luminance below 0.25 gives ≥4.5:1 contrast on white for
      // larger text (WCAG AA Large).
      final color = AppPalette.light.brandWarningDeep;
      expect(
        color.computeLuminance(),
        lessThan(0.25),
        reason: 'brandWarningDeep should be dark enough for text-on-white AA',
      );
    });

    test('brandCoral is a WARM accent in both modes (not the Orvex grey)', () {
      // Regression guard for the Orvex repalette, which redefined brandCoral
      // as #6A6A76 warm grey. Every accent usage (streaks, highlights,
      // badges) then rendered grey. It must lean red/warm in BOTH modes.
      for (final palette in [AppPalette.light, AppPalette.dark]) {
        final color = palette.brandCoral;
        expect(
          color.r,
          greaterThan(color.b),
          reason: 'brandCoral must be a warm accent, not a neutral grey',
        );
        expect(
          color.toARGB32(),
          isNot(0xFF6A6A76),
          reason: 'brandCoral must not be the Orvex grey (0xFF6A6A76)',
        );
      }
    });
  });
}
