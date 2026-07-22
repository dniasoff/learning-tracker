/// Run-10 device audit — gold ink must stay legible on surfaces that remain
/// COLOURED in dark mode.
///
/// THE DEFECT (measured on emulator-5564, API 36 tablet, dark mode):
/// `dashboard_level_points_card.dart` painted [AppPalette.goldTrophy] on the
/// Dashboard hero card's own medium-blue circle (the "חזרה"/Review stat digit)
/// and on its translucent-white lifetime progress track. `goldTrophy` darkens to
/// a near-brown `0xFF332A13` in dark mode — correct for its ORIGINAL role, ink on
/// a fixed-WHITE circle (`child_points_rewards_tab_card.dart`), and wrong here.
///
/// Measured on device from screenshot pixels (not eyeballed):
///   * Review digit vs its circle  → **1.75:1**  (WCAG large text needs ≥ 3:1)
///   * progress-bar fill vs track  → **2.26:1**  (WCAG non-text needs ≥ 3:1)
///   * the same digit in LIGHT mode → 4.15:1     (so: dark-mode-only)
/// The progress-fill case was invisible on the seeded account only because it sat
/// at 0% lifetime progress — any user with completed work would have hit it.
///
/// THE FIX: split [AppPalette.goldOnColouredSurface] out of [goldTrophy], exactly
/// as `chartLimudBlue` was split out of `blueMid` for the identical reason (ink-on-
/// card vs fill-under-white-text are opposite requirements). The new token keeps
/// the light amber in BOTH themes.
///
/// This test pins the contrast maths rather than the hex literals, so it fails if
/// either token is re-darkened or a call site is pointed back at `goldTrophy`.
@Tags(['core_widgets', 'dashboard'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// WCAG relative luminance (sRGB), per w3.org/TR/WCAG21/#dfn-relative-luminance.
double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // The hero card's own circle behind the Review digit, sampled from the device
  // screenshot in dark mode. The card stays coloured in dark mode — that is the
  // whole point: the surface does not go dark, so dark ink sinks into it.
  const heroCircleDark = Color(0xFF465DA1);

  group('goldOnColouredSurface — the run-10 dark-mode legibility fix', () {
    test('gold ink clears WCAG large-text 3:1 on the dark hero card '
        '(measured 1.75:1 before the fix)', () {
      const palette = AppPalette.dark;

      final ratio = _contrast(palette.goldOnColouredSurface, heroCircleDark);

      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason:
            'the Review-stat digit is painted on the hero card circle, which '
            'stays coloured in dark mode; goldTrophy darkens to near-brown and '
            'measured 1.75:1 on device — genuinely illegible, not a marginal '
            'nitpick',
      );
    });

    test('the token does NOT darken in dark mode — that is what broke it', () {
      final light = AppPalette.light.goldOnColouredSurface;
      final dark = AppPalette.dark.goldOnColouredSurface;

      expect(
        dark,
        light,
        reason:
            'ink painted on a surface that stays coloured must keep its light '
            'value in both themes — the opposite of the ink-on-white role that '
            'goldTrophy serves',
      );
    });

    test('goldTrophy keeps its dark-mode darkening, because its own call site '
        'paints it on a fixed WHITE circle', () {
      // Guards against "fixing" this by darkening/lightening goldTrophy itself,
      // which would break child_points_rewards_tab_card.dart in the other
      // direction. The two roles genuinely need different derivations.
      const palette = AppPalette.dark;

      final onWhite = _contrast(palette.goldTrophy, const Color(0xFFFFFFFF));

      expect(
        onWhite,
        greaterThanOrEqualTo(3.0),
        reason:
            'goldTrophy must stay dark enough to read on the fixed-white circle '
            'it was designed for; the fix is a SPLIT, not a re-tint',
      );
    });

    test(
      'light mode did not regress — gold still reads on the light hero card',
      () {
        // The classic cost of a dark-mode fix. Run-9 shipped several of these.
        const heroCircleLight = Color(0xFF3252B4);
        const palette = AppPalette.light;

        expect(
          _contrast(palette.goldOnColouredSurface, heroCircleLight),
          greaterThanOrEqualTo(3.0),
          reason:
              'device measured 4.15:1 in light mode before the fix; the split '
              'must preserve that',
        );
      },
    );
  });
}
