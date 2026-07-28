// core-widgets-app dark-mode legibility burndown (owner decision #2,
// docs/planning/post-sweep-decisions.md) — three hero-fill misuses found
// under lib/core/widgets/, modelled on darkmode_sweep_contrast_test.dart's
// WCAG-helper + widget-pump style.
//
// All three are the SAME bug shape (the goldTrophy/chartAmber class, run-9's
// "hero-fill" variant): a CONTRAST-role palette token that deliberately
// LIGHTENS in dark mode for its normal ink-on-dark-card use was painted
// instead as a SOLID FILL under a hardcoded white foreground, which the
// lightened dark value cannot hold.
//
// Finding 1 (P1) — the shared learning date-picker theme's selected
// day/year chip (`learning_date_picker_theme.dart`): `colorScheme.primary`
// and the explicit `dayBackgroundColor` selected-state both read
// `brandBlue` directly, painted under a hardcoded white foreground
// (`onPrimary` / `dayForegroundColor`'s selected branch). `brandBlue`
// lightens to `0xFF7CA0FF` in dark mode for its normal ink role — used as a
// fill, that measured **2.52:1** against a 4.5:1 AA floor. Fixed with a new
// token, `AppPalette.brandBlueDeepFill`, pinned to brandBlue's own
// light-mode hex in both themes (10.36:1 with white text in dark).
//
// Finding 2 (P1) — the shared confirm dialog's primary button
// (`app_dialog.dart`'s `_ConfirmDialogBody`): `confirmColor` read
// `brandBlue` (non-destructive) / `chartRed` (destructive) directly under a
// hardcoded white `foregroundColor`. Both lighten in dark mode for their
// normal ink roles — measured **2.52:1** / **2.55:1** as fills. Fixed with
// `AppPalette.brandBlueDeepFill` / `AppPalette.chartRedDeepFill`.
//
// Finding 3 (P2) — `PreferenceSegmentedTile`'s `SegmentedButton`
// (`preference_segmented_tile.dart`): `selectedBackgroundColor` read
// `brandBlueBright` directly under a hardcoded white
// `selectedForegroundColor`. `brandBlueBright` lightens to `0xFFA3BEFF` in
// dark mode for its normal ink role — measured **1.85:1** as a fill (the
// same numeric failure already fixed once for
// `chazaraSelectedGradientEnd`, which pins the same light-mode hex). Fixed
// with a new token, `AppPalette.preferenceSegmentedSelectedFill`, pinned to
// brandBlueBright's own light-mode hex in both themes (5.61:1 with white
// text in dark).
@Tags(['core_widgets'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';
import 'package:learning_tracker/core/widgets/preference_segmented_tile.dart';

import '../../helpers/pump_app.dart';

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
  group('Finding 1 — learning date-picker selected day/year fill', () {
    test('brandBlueDeepFill clears WCAG 4.5:1 with white text in dark mode '
        '(measured 2.52:1 on the pre-fix brandBlue-as-fill pair)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(Colors.white, palette.brandBlueDeepFill);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the selected day/year chip painted brandBlue as a solid FILL '
            'under a hardcoded white foreground; brandBlue lightens in dark '
            'mode for its normal ink-on-card role, dropping that white text '
            'to 2.52:1',
      );
    });

    test('light mode is unchanged — brandBlueDeepFill equals brandBlue\'s '
        'own light-mode hex exactly', () {
      const light = AppPalette.light;

      expect(light.brandBlueDeepFill, light.brandBlue);
      expect(
        _contrast(Colors.white, light.brandBlueDeepFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real date-picker theme resolves brandBlueDeepFill (not brandBlue) '
      'for both colorScheme.primary and the selected day fill in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            child: Builder(
              builder: (context) =>
                  learningDatePickerThemeBuilder(context, const SizedBox()),
            ),
          ),
        );
        await tester.pump();

        // ThemeData.datePickerTheme itself is never null (Flutter defaults it
        // to a mostly-empty `const DatePickerThemeData()`), so every ambient
        // Theme matches a bare null-check. dayBackgroundColor IS unique to
        // OUR override — the ambient app theme never sets it.
        final themeWidget = tester
            .widgetList<Theme>(find.byType(Theme))
            .firstWhere(
              (t) => t.data.datePickerTheme.dayBackgroundColor != null,
            );

        expect(
          themeWidget.data.colorScheme.primary,
          AppPalette.dark.brandBlueDeepFill,
        );
        expect(
          themeWidget.data.colorScheme.primary,
          isNot(AppPalette.dark.brandBlue),
        );

        final dayBg = themeWidget.data.datePickerTheme.dayBackgroundColor!
            .resolve({WidgetState.selected});
        expect(dayBg, AppPalette.dark.brandBlueDeepFill);
        expect(dayBg, isNot(AppPalette.dark.brandBlue));
      },
    );

    testWidgets(
      'the real date-picker theme keeps the exact pre-fix brandBlue value in '
      'light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Builder(
              builder: (context) =>
                  learningDatePickerThemeBuilder(context, const SizedBox()),
            ),
          ),
        );
        await tester.pump();

        final themeWidget = tester
            .widgetList<Theme>(find.byType(Theme))
            .firstWhere(
              (t) => t.data.datePickerTheme.dayBackgroundColor != null,
            );

        expect(
          themeWidget.data.colorScheme.primary,
          AppPalette.light.brandBlue,
        );
        final dayBg = themeWidget.data.datePickerTheme.dayBackgroundColor!
            .resolve({WidgetState.selected});
        expect(dayBg, AppPalette.light.brandBlue);
      },
    );
  });

  group('Finding 2 — showAppConfirmDialog primary button fill', () {
    test(
      'brandBlueDeepFill / chartRedDeepFill clear WCAG 4.5:1 with white text '
      'in dark mode (measured 2.52:1 / 2.55:1 on the pre-fix brandBlue/'
      'chartRed-as-fill pairs)',
      () {
        const palette = AppPalette.dark;
        final nonDestructiveRatio = _contrast(
          Colors.white,
          palette.brandBlueDeepFill,
        );
        final destructiveRatio = _contrast(
          Colors.white,
          palette.chartRedDeepFill,
        );

        expect(nonDestructiveRatio, greaterThanOrEqualTo(4.5));
        expect(
          destructiveRatio,
          greaterThanOrEqualTo(4.5),
          reason:
              'the destructive confirm button painted chartRed as a solid '
              'FILL under a hardcoded white foreground; chartRed lightens in '
              'dark mode for its normal chart-series ink role, dropping that '
              'white text to 2.55:1',
        );
      },
    );

    test('light mode is unchanged — chartRedDeepFill equals chartRed\'s own '
        'light-mode hex exactly', () {
      const light = AppPalette.light;

      expect(light.chartRedDeepFill, light.chartRed);
      expect(
        _contrast(Colors.white, light.chartRedDeepFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    Future<void> pumpConfirmDialog(
      WidgetTester tester, {
      required bool destructive,
      required ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        pumpApp(
          theme: theme,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showAppConfirmDialog(
                  context: context,
                  title: 'Title',
                  message: 'Message',
                  destructive: destructive,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the real confirm button reads brandBlueDeepFill (not brandBlue) in '
      'dark mode',
      (tester) async {
        await pumpConfirmDialog(
          tester,
          destructive: false,
          theme: AppTheme.darkTheme(),
        );

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        final bg = button.style?.backgroundColor?.resolve({});
        final fg = button.style?.foregroundColor?.resolve({});

        expect(bg, AppPalette.dark.brandBlueDeepFill);
        expect(bg, isNot(AppPalette.dark.brandBlue));
        expect(fg, Colors.white);
      },
    );

    testWidgets(
      'the real DESTRUCTIVE confirm button reads chartRedDeepFill (not '
      'chartRed) in dark mode',
      (tester) async {
        await pumpConfirmDialog(
          tester,
          destructive: true,
          theme: AppTheme.darkTheme(),
        );

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        final bg = button.style?.backgroundColor?.resolve({});

        expect(bg, AppPalette.dark.chartRedDeepFill);
        expect(bg, isNot(AppPalette.dark.chartRed));
      },
    );

    testWidgets(
      'the real confirm button keeps the exact pre-fix brandBlue/chartRed '
      'values in light mode (no regression)',
      (tester) async {
        await pumpConfirmDialog(tester, destructive: false, theme: null);
        final nonDestructive = tester.widget<FilledButton>(
          find.byType(FilledButton),
        );
        expect(
          nonDestructive.style?.backgroundColor?.resolve({}),
          AppPalette.light.brandBlue,
        );

        await tester.pumpWidget(const SizedBox());
        await pumpConfirmDialog(tester, destructive: true, theme: null);
        final destructiveButton = tester.widget<FilledButton>(
          find.byType(FilledButton),
        );
        expect(
          destructiveButton.style?.backgroundColor?.resolve({}),
          AppPalette.light.chartRed,
        );
      },
    );
  });

  group('Finding 3 — PreferenceSegmentedTile selected segment fill', () {
    test('preferenceSegmentedSelectedFill clears WCAG 4.5:1 with white text '
        'in dark mode (measured 1.85:1 on the pre-fix brandBlueBright-as-fill '
        'pair)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(
        Colors.white,
        palette.preferenceSegmentedSelectedFill,
      );

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the selected segment painted brandBlueBright as a solid '
            'FILL under a hardcoded white label; brandBlueBright '
            'lightens in dark mode for its normal ink-on-card role, '
            'dropping that white text to 1.85:1',
      );
    });

    test('light mode is unchanged — preferenceSegmentedSelectedFill equals '
        'brandBlueBright\'s own light-mode hex exactly', () {
      const light = AppPalette.light;

      expect(light.preferenceSegmentedSelectedFill, light.brandBlueBright);
      expect(
        _contrast(Colors.white, light.preferenceSegmentedSelectedFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    Widget buildTile() => PreferenceSegmentedTile<String>(
      title: 'Preference',
      options: const [(value: 'a', label: 'A'), (value: 'b', label: 'B')],
      value: 'a',
      onChanged: (_) {},
    );

    testWidgets(
      'the real SegmentedButton reads preferenceSegmentedSelectedFill (not '
      'brandBlueBright) for its selected fill in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            child: Scaffold(body: buildTile()),
          ),
        );
        await tester.pump();

        final button = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        );
        final bg = button.style?.backgroundColor?.resolve({
          WidgetState.selected,
        });
        final fg = button.style?.foregroundColor?.resolve({
          WidgetState.selected,
        });

        expect(bg, AppPalette.dark.preferenceSegmentedSelectedFill);
        expect(bg, isNot(AppPalette.dark.brandBlueBright));
        expect(fg, Colors.white);
      },
    );

    testWidgets(
      'the real SegmentedButton keeps the exact pre-fix brandBlueBright '
      'value in light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(pumpApp(child: Scaffold(body: buildTile())));
        await tester.pump();

        final button = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        );
        final bg = button.style?.backgroundColor?.resolve({
          WidgetState.selected,
        });
        expect(bg, AppPalette.light.brandBlueBright);
      },
    );
  });
}
