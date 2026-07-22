// Regression tests for IL-8 (disabled/low-emphasis controls below WCAG AA;
// Chumash icon washed-out gray).
//
// Root cause:
//   - brandInkSoft (#95A1AE) is used for disabled/secondary labels on white
//     (#FFFFFF) background → contrast ratio ≈2.8:1 (below WCAG AA minimum 3:1
//     for large text and 4.5:1 for body text).
//   - curriculumChumash = brandCoral (slate-gray #708090) gives the Chumash
//     icon a washed-out gray disc that is indistinct from the neutral palette.
//
// Fix:
//   - curriculumChumash must be a distinct non-gray hue (e.g. warm amber/sepia).
//   - brandInkDisabled / brandInkSecondary must achieve ≥3:1 contrast on white
//     for large text, ≥4.5:1 for body text (WCAG AA).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// Approximate luminance-based contrast ratio (simplified).
double _contrastRatio(double l1, double l2) {
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('IL-8 — curriculumChumash is a distinct non-gray hue', () {
    test('curriculumChumash is NOT the same value as brandCoral (slate-gray)', () {
      // Before IL-8 fix: curriculumChumash == brandCoral == 0xFF708090 (gray).
      // After IL-8 fix: curriculumChumash must be a warm/distinct color.
      expect(
        AppPalette.light.curriculumChumash.toARGB32(),
        isNot(equals(AppPalette.light.brandCoral.toARGB32())),
        reason:
            'curriculumChumash must not be the same as brandCoral (slate-gray '
            '#708090). The Chumash icon was washed-out gray because it shared '
            'the neutral palette value.',
      );
    });

    test('curriculumChumash has a warm hue (red channel > blue channel)', () {
      // A warm amber/sepia/earth-tone will have red > blue.
      final c = AppPalette.light.curriculumChumash;
      final r = (c.toARGB32() >> 16) & 0xFF;
      final b = c.toARGB32() & 0xFF;
      expect(
        r > b,
        isTrue,
        reason:
            'curriculumChumash should be a warm color (red > blue). '
            'Current: R=$r B=$b. Use an amber/sepia/earth tone for Chumash.',
      );
    });
  });

  group('IL-8 — disabled/secondary ink meets WCAG AA on white', () {
    test('brandInkSoft contrast on white is ≥3.0:1 (large-text AA)', () {
      // brandInkSoft on white must achieve at least WCAG AA large-text (3:1).
      final inkSoftLum = AppPalette.light.brandInkSoft.computeLuminance();
      final ratio = _contrastRatio(inkSoftLum, 1.0);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason:
            'brandInkSoft (#${AppPalette.light.brandInkSoft.toARGB32().toRadixString(16)}) on white '
            'has contrast ratio ${ratio.toStringAsFixed(2)}:1. '
            'Must be ≥3.0:1 for WCAG AA large text. '
            'Darken brandInkSoft (or the disabled-label color) to meet AA.',
      );
    });

    test('brandInkMuted contrast on white is ≥4.5:1 (normal-text AA)', () {
      // brandInkMuted on white: pre-fix #708090 was 4.05:1 (below 4.5:1 AA).
      final inkMutedLum = AppPalette.light.brandInkMuted.computeLuminance();
      final ratio = _contrastRatio(inkMutedLum, 1.0);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'brandInkMuted (#${AppPalette.light.brandInkMuted.toARGB32().toRadixString(16)}) on white '
            'has contrast ratio ${ratio.toStringAsFixed(2)}:1. '
            'Must be ≥4.5:1 for WCAG AA normal text.',
      );
    });
  });
}
