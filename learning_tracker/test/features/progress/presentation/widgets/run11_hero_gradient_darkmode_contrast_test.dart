// Run-11 progress-area dark-mode legibility sweep — three findings, modelled
// on `test/core/theme/darkmode_sweep_contrast_test.dart`'s WCAG helper and
// finding-per-group style.
//
// Finding 1 (P1) — `OverallStatsCard` (Curriculum Progress screen): the
// card's hero gradient painted directly from `brandBlueDeep`/`brandBlue`/
// `brandBlueBright` — a CONTRAST role that deliberately LIGHTENS in dark
// mode for ink-on-dark-surface use — with white title/stat text on top. Used
// as a FILL instead, the lightened dark-mode values washed the card to pale
// sky-blue and dropped the white content to **1.63:1** / **2.52:1** /
// **1.85:1** (computed from the hex values). Same hero-fill role/bug as
// `blueMedium`/`blueLight`/`blueMid`/`chazaraSelectedGradientStart`
// (`a68c97d5`'s sweep, which missed this call site). Fixed with three new
// tokens, `progressOverallStatsGradientStart`/`Mid`/`End`, pinned to the
// exact pre-fix light-mode hex triple in both themes.
//
// Finding 2 (P1) — `LifetimeFolderGradients.card` (the Lifetime-folder tree
// panel gradient, `lifetime_folder_styled_widgets.dart`): the start/end
// stops are already pinned deep for dark mode, but the MIDDLE stop read
// `brandBlue` directly — same lightens-in-dark bug as Finding 1 — painting a
// light pastel-blue band (measured **2.52:1**) between two deep bands. Fixed
// with a new token, `progressLifetimeCardGradientMid`, holding the same
// pinned `brandBlue`-light hex.
//
// Finding 3 (P2) — `progressLifetimeCardGradientEnd`: `a68c97d5`'s sweep
// pinned this gradient's START stop deep but left the END stop at its
// pre-sweep dark value (`0xFF84AAE0`), which still measured only **2.38:1**
// with white content. Darkened in place to **7.90:1**; light mode unchanged.
//
// Finding 4 (P1) — `progressPointsBarFill` (Points-over-time bar chart,
// Recent Activity screen, child mode): the bar is drawn directly on
// `brandCreamCard`/`colorScheme.surface` — an ADAPTIVE card — but the token
// DARKENED in dark mode (the derivation correct for ink on a FIXED-light
// surface, not a fill on a card that itself goes dark), measured **1.19:1**
// against the dark card — the bars nearly invisible. Pinned to the existing
// light-mode hex in both themes instead (**12.71:1** against the dark card);
// light mode is byte-for-byte unchanged.
//
// Finding 5 (P1) — the Progress hub's "Lifetime Knowledge" lens tile and its
// per-track row icon (`progress_screen.dart`): both paint their icon on a
// FIXED pale-blue chip (`0xFFEEF3FF`, a raw literal that does not adapt with
// brightness) but read the icon colour from `context.colors.brandBlue`,
// which LIGHTENS in dark mode for its normal ink-on-ADAPTIVE-dark-card role
// — the mirror image of the goldTrophy/chartAmber class named in this
// campaign's brief. Painted on the fixed chip instead, dark mode produced a
// pale-blue icon on a pale-blue chip: measured **2.27:1** (light mode was
// already fine at 7.56:1 — a dark-mode-only regression). Fixed with a new
// token, `progressFixedChipBlueIcon`, pinned to `brandBlue`'s light-mode hex
// in both themes.
@Tags(['progress', 'core_widgets'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';

import '../../../../helpers/pump_app.dart';

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

const _stats = OverallCurriculumStats(
  totalItems: 120,
  completedAllStages: 40,
  inProgress: 35,
  notStarted: 45,
);

/// [OverallStatsCard] renders several `Container`s (the outer gradient card
/// plus one small circular "leading dot" per stat row) — find the one
/// carrying a [LinearGradient] rather than assuming there is exactly one.
LinearGradient _gradientCardOf(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  for (final container in containers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.gradient is LinearGradient) {
      return decoration.gradient! as LinearGradient;
    }
  }
  fail('expected to find a Container with a LinearGradient decoration');
}

void main() {
  group('Finding 1 — OverallStatsCard hero gradient', () {
    test('progressOverallStatsGradientStart/Mid/End all clear WCAG 4.5:1 with '
        'white content (measured 1.63:1 / 2.52:1 / 1.85:1 on the pre-fix '
        'brandBlueDeep/brandBlue/brandBlueBright dark values)', () {
      const dark = AppPalette.dark;

      // RED DEMO: the pre-fix tokens, evaluated at dark brightness, fail.
      expect(
        _contrast(Colors.white, dark.brandBlueDeep),
        lessThan(4.5),
        reason:
            'brandBlueDeep LIGHTENS in dark mode for its ink role — '
            'this is the wrong token for a fill, confirming the bug '
            'existed before the fix',
      );
      expect(_contrast(Colors.white, dark.brandBlue), lessThan(4.5));
      expect(_contrast(Colors.white, dark.brandBlueBright), lessThan(4.5));

      // GREEN: the fixed, pinned-deep tokens clear the floor.
      expect(
        _contrast(Colors.white, dark.progressOverallStatsGradientStart),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(Colors.white, dark.progressOverallStatsGradientMid),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(Colors.white, dark.progressOverallStatsGradientEnd),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — the new tokens equal the old '
        'brandBlueDeep/brandBlue/brandBlueBright light-mode hexes exactly', () {
      const light = AppPalette.light;

      expect(light.progressOverallStatsGradientStart, light.brandBlueDeep);
      expect(light.progressOverallStatsGradientMid, light.brandBlue);
      expect(light.progressOverallStatsGradientEnd, light.brandBlueBright);
      expect(
        _contrast(Colors.white, light.progressOverallStatsGradientStart),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real card paints its gradient from the new progressOverallStats '
      'tokens (not brandBlueDeep/brandBlue/brandBlueBright) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(body: OverallStatsCard(stats: _stats)),
            ),
          ),
        );
        await tester.pump();

        final gradient = _gradientCardOf(tester);

        expect(
          gradient.colors[0],
          AppPalette.dark.progressOverallStatsGradientStart,
        );
        expect(
          gradient.colors[1],
          AppPalette.dark.progressOverallStatsGradientMid,
        );
        expect(
          gradient.colors[2],
          AppPalette.dark.progressOverallStatsGradientEnd,
        );
        expect(gradient.colors[0], isNot(AppPalette.dark.brandBlueDeep));
        expect(gradient.colors[1], isNot(AppPalette.dark.brandBlue));
        expect(gradient.colors[2], isNot(AppPalette.dark.brandBlueBright));
      },
    );

    testWidgets('the real card keeps the exact pre-fix gradient in light mode '
        '(no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Scaffold(body: OverallStatsCard(stats: _stats)),
        ),
      );
      await tester.pump();

      final gradient = _gradientCardOf(tester);

      expect(gradient.colors[0], const Color(0xFF0E3392));
      expect(gradient.colors[1], const Color(0xFF1442B8));
      expect(gradient.colors[2], const Color(0xFF2B5FD9));
    });
  });

  group('Finding 2 — LifetimeFolderGradients.card middle stop', () {
    test(
      'progressLifetimeCardGradientMid clears WCAG 4.5:1 with white content '
      'in dark mode (measured 2.52:1 on the pre-fix brandBlue dark value)',
      () {
        const dark = AppPalette.dark;

        expect(
          _contrast(Colors.white, dark.brandBlue),
          lessThan(4.5),
          reason:
              'brandBlue LIGHTENS in dark mode for its ink role — the '
              'middle gradient stop used it directly as a fill',
        );
        expect(
          _contrast(Colors.white, dark.progressLifetimeCardGradientMid),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('light mode is unchanged — progressLifetimeCardGradientMid equals the '
        'old brandBlue light-mode hex exactly', () {
      const light = AppPalette.light;
      expect(light.progressLifetimeCardGradientMid, light.brandBlue);
    });

    testWidgets('the real tree-panel gradient paints its middle stop from '
        'progressLifetimeCardGradientMid (not brandBlue) in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: const Scaffold(
              body: LifetimeFolderSurface(child: Text('x')),
            ),
          ),
        ),
      );
      await tester.pump();

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      expect(
        gradient.colors[1],
        AppPalette.dark.progressLifetimeCardGradientMid,
      );
      expect(gradient.colors[1], isNot(AppPalette.dark.brandBlue));
    });

    testWidgets(
      'the real tree-panel gradient keeps the exact pre-fix middle stop in '
      'light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: const Scaffold(
              body: LifetimeFolderSurface(child: Text('x')),
            ),
          ),
        );
        await tester.pump();

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;

        expect(gradient.colors[1], const Color(0xFF1442B8));
      },
    );
  });

  group('Finding 3 — progressLifetimeCardGradientEnd deepened', () {
    test('clears WCAG 4.5:1 with white content in dark mode (measured 2.38:1 '
        'on the pre-fix 0xFF84AAE0 value, missed by the a68c97d5 sweep)', () {
      const dark = AppPalette.dark;

      expect(
        _contrast(Colors.white, const Color(0xFF84AAE0)),
        lessThan(4.5),
        reason: 'the pre-fix dark value, kept here as the RED-demo anchor',
      );
      expect(
        _contrast(Colors.white, dark.progressLifetimeCardGradientEnd),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged', () {
      const light = AppPalette.light;
      expect(light.progressLifetimeCardGradientEnd, const Color(0xFF3D7DDA));
    });
  });

  group('Finding 4 — progressPointsBarFill on the adaptive card', () {
    test('clears WCAG 4.5:1 against brandCreamCard in dark mode (measured '
        '1.19:1 on the pre-fix 0xFF332713 darkened value)', () {
      const dark = AppPalette.dark;

      // RED DEMO: the pre-fix darkened value nearly disappears into the
      // dark card.
      expect(
        _contrast(const Color(0xFF332713), dark.brandCreamCard),
        lessThan(4.5),
      );

      // GREEN: the fixed value stands out clearly.
      expect(
        _contrast(dark.progressPointsBarFill, dark.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — progressPointsBarFill keeps the exact '
        'pre-fix 0xFFF2D9B3 hex', () {
      const light = AppPalette.light;
      expect(light.progressPointsBarFill, const Color(0xFFF2D9B3));
      // Same value in both themes now (a fixed light-tan accent) — verify
      // dark resolves identically.
      expect(AppPalette.dark.progressPointsBarFill, const Color(0xFFF2D9B3));
    });
  });

  group(
    'Finding 5 — progressFixedChipBlueIcon on the FIXED 0xFFEEF3FF chip',
    () {
      test('clears WCAG 4.5:1 against the fixed chip in dark mode (measured '
          '2.27:1 on the pre-fix brandBlue-dark value; light mode was already '
          'fine at 7.56:1 — a dark-mode-only regression)', () {
        const dark = AppPalette.dark;
        const fixedChip = Color(0xFFEEF3FF);

        // RED DEMO: brandBlue's dark (lightened) value nearly disappears
        // into the fixed pale-blue chip.
        expect(_contrast(dark.brandBlue, fixedChip), lessThan(4.5));

        // GREEN: the pinned token stands out clearly, same as light mode.
        expect(
          _contrast(dark.progressFixedChipBlueIcon, fixedChip),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('light mode is unchanged — progressFixedChipBlueIcon equals the old '
          'brandBlue light-mode hex exactly', () {
        const light = AppPalette.light;
        const fixedChip = Color(0xFFEEF3FF);

        expect(light.progressFixedChipBlueIcon, light.brandBlue);
        expect(
          _contrast(light.progressFixedChipBlueIcon, fixedChip),
          greaterThanOrEqualTo(4.5),
        );
      });
    },
  );
}
