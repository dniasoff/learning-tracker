/// Run-10 acceptance sweep — every ProgressTierCounterRow accent must be legible
/// as NUMBER TEXT on [AppPalette.brandCreamCard], in dark mode.
///
/// THE DEFECT (found on emulator-5556, API 29, dark mode; 4 screenshots + hex
/// math): the Siyumim/trophy counter number was illegible on the Dashboard hero
/// and the Progress hub (both render `ProgressTierCounterRow`). Its `accent` was
/// [AppPalette.chartAmber], which DARKENS to `0xFF332913` in dark mode — a
/// chart-ink-on-fixed-LIGHT-background role — while the card it sits on darkens
/// to `0xFF151A26`: measured **1.22:1** (WCAG large text needs >= 4.5:1 for a
/// number this weight/size, and >= 3:1 at the very least).
///
/// Its sibling accents (streak / points / lifetime) all LIGHTEN in dark so the
/// number reads on the card; Siyumim alone still pointed at the chart token. Fix:
/// [AppPalette.progressTierSiyumimAccent], split from chartAmber exactly as
/// [AppPalette.goldOnColouredSurface] was split from goldTrophy. chartAmber is
/// left untouched at its legitimate fixed-light-background site (the lens-tile
/// trophy icon on `0xFFFFF4E0`).
///
/// This test is SYSTEMIC: it pins EVERY accent used by ProgressTierCounterRow, so
/// the next accent that darkens onto the card is caught here — not just this one.
@Tags(['core_widgets', 'progress'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

double _lin(double c) {
  final s = c / 255.0;
  return s <= 0.03928
      ? s / 12.92
      : math.pow((s + 0.055) / 1.055, 2.4) as double;
}

double _luminance(Color c) =>
    0.2126 * _lin((c.r * 255).roundToDouble()) +
    0.7152 * _lin((c.g * 255).roundToDouble()) +
    0.0722 * _lin((c.b * 255).roundToDouble());

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // The exact card the counter numbers are painted on (ProgressTierCounterRow's
  // _Counter uses brandCreamCard as its Container colour).
  const darkCard = Color(0xFF151A26); // AppPalette.brandCreamCard (dark)

  // Every accent ProgressTierCounterRow passes to a _Counter's number text.
  final darkAccents = <String, Color>{
    'streak': AppPalette.dark.progressTierStreakAccent,
    'siyumim': AppPalette.dark.progressTierSiyumimAccent,
    'lifetime': AppPalette.dark.brandBlue,
    'points': AppPalette.dark.progressTierPointsAccent,
  };

  group('ProgressTierCounterRow accents are legible on the dark card', () {
    darkAccents.forEach((name, color) {
      test('$name accent clears 4.5:1 on brandCreamCard in dark mode', () {
        expect(
          _contrast(color, darkCard),
          greaterThanOrEqualTo(4.5),
          reason:
              'the $name counter NUMBER is painted in this accent on the dark '
              'card; it must be readable. Siyumim was 1.22:1 (chartAmber, which '
              'darkens) before the fix',
        );
      });
    });

    test('Siyumim accent LIGHTENS in dark (the whole point) and is unchanged in '
        'light', () {
      // Regression guard against re-pointing it at a darkening token, and
      // against a light-mode change (the classic cost of a dark-mode fix).
      expect(
        AppPalette.light.progressTierSiyumimAccent,
        const Color(0xFFF8C146),
        reason: 'light mode must keep the original Siyumim amber',
      );
      expect(
        _luminance(AppPalette.dark.progressTierSiyumimAccent),
        greaterThan(_luminance(const Color(0xFF332913))),
        reason:
            'must be lighter than chartAmber-dark (0xFF332913), which was the '
            'illegible value',
      );
    });

    test('chartAmber stays dark — it is still correct at its fixed-LIGHT-bg site '
        '(lens-tile trophy icon on 0xFFFFF4E0)', () {
      // Guards against "fixing" this by lightening chartAmber itself, which would
      // break the trophy icon on the fixed cream chip in the other direction.
      const lensChipBg = Color(0xFFFFF4E0);
      expect(
        _contrast(AppPalette.dark.chartAmber, lensChipBg),
        greaterThanOrEqualTo(4.5),
        reason:
            'chartAmber must stay dark enough to read on the fixed cream lens '
            'chip; the fix is a SPLIT, not a re-tint of the shared token',
      );
    });
  });
}
