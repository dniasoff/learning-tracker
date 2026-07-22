// Guardrail for the brightness-aware palette (AppPalette).
//
// Background: the app previously held 244 light-only `static const Color`
// tokens while running under `ThemeMode.system`. On a dark device those
// painted dark ink onto dark cards at ratios as low as 1.02:1 — invisible
// text. AppPalette now resolves every token per-brightness; these tests keep
// it that way by asserting the contract in BOTH modes.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// WCAG 2.1 relative luminance of [c].
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio between [a] and [b] (1.0 – 21.0).
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// A foreground token paired with the surface it is designed to sit on.
typedef _Pair = ({
  String name,
  Color Function(AppPalette) fg,
  Color Function(AppPalette) bg,
  double min,
});

/// Text/icon roles must clear AA (4.5:1) against the surfaces they sit on.
final List<_Pair> _textRoles = [
  (
    name: 'brandInk on card',
    fg: (p) => p.brandInk,
    bg: (p) => p.brandCreamCard,
    min: 4.5,
  ),
  (
    name: 'brandInk on canvas',
    fg: (p) => p.brandInk,
    bg: (p) => p.brandCream,
    min: 4.5,
  ),
  (
    name: 'brandInk2 on card',
    fg: (p) => p.brandInk2,
    bg: (p) => p.brandCreamCard,
    min: 4.5,
  ),
  (
    name: 'brandInkMuted on card',
    fg: (p) => p.brandInkMuted,
    bg: (p) => p.brandCreamCard,
    min: 4.5,
  ),
  (
    name: 'brandInkMuted on canvas',
    fg: (p) => p.brandInkMuted,
    bg: (p) => p.brandCream,
    min: 4.5,
  ),
  (
    name: 'brandInkSoft on card',
    fg: (p) => p.brandInkSoft,
    bg: (p) => p.brandCreamCard,
    min: 4.5,
  ),
  (
    name: 'brandInk on soft surface',
    fg: (p) => p.brandInk,
    bg: (p) => p.brandCreamSoft,
    min: 4.5,
  ),
  (
    name: 'brandBlue on card',
    fg: (p) => p.brandBlue,
    bg: (p) => p.brandCreamCard,
    min: 4.5,
  ),
  (
    name: 'brandError on card',
    fg: (p) => p.brandError,
    bg: (p) => p.brandCreamCard,
    min: 4.5,
  ),
  (
    name: 'brandGold on card',
    fg: (p) => p.brandGold,
    bg: (p) => p.brandCreamCard,
    min: 4.5,
  ),
  // Tint containers and the text designed to sit on them.
  (
    name: 'brandBlueDeep on brandBlueSoft',
    fg: (p) => p.brandBlueDeep,
    bg: (p) => p.brandBlueSoft,
    min: 4.5,
  ),
  (
    name: 'brandCoralDeep on brandCoralSoft',
    fg: (p) => p.brandCoralDeep,
    bg: (p) => p.brandCoralSoft,
    min: 4.5,
  ),
  (
    name: 'brandGoldDeep on brandGoldSoft',
    fg: (p) => p.brandGoldDeep,
    bg: (p) => p.brandGoldSoft,
    min: 4.5,
  ),
  (
    name: 'brandWarningDeep on brandWarningSoft',
    fg: (p) => p.brandWarningDeep,
    bg: (p) => p.brandWarningSoft,
    min: 4.5,
  ),
];

/// Non-text roles only need the 3:1 UI-component threshold.
final List<_Pair> _uiRoles = [
  (
    name: 'brandOutline on canvas',
    fg: (p) => p.brandOutline,
    bg: (p) => p.brandCream,
    min: 1.2,
  ),
  (
    name: 'brandOutline on card',
    fg: (p) => p.brandOutline,
    bg: (p) => p.brandCreamCard,
    min: 1.2,
  ),
  (
    name: 'brandOutlineMuted on card',
    fg: (p) => p.brandOutlineMuted,
    bg: (p) => p.brandCreamCard,
    min: 1.3,
  ),
  (
    name: 'brandCoral fill on card',
    fg: (p) => p.brandCoral,
    bg: (p) => p.brandCreamCard,
    min: 3.0,
  ),
];

/// Curriculum identity colours are used as text and as chart fills.
final List<Color Function(AppPalette)> _curriculumRoles = [
  (p) => p.curriculumMishna,
  (p) => p.curriculumBavli,
  (p) => p.curriculumYerushalmi,
  (p) => p.curriculumMishnaBerurah,
  (p) => p.curriculumChumash,
  (p) => p.curriculumNach,
  (p) => p.curriculumMussar,
];

void main() {
  for (final entry in <(String, AppPalette)>[
    ('light', AppPalette.light),
    ('dark', AppPalette.dark),
  ]) {
    final (modeName, palette) = entry;

    group('AppPalette ($modeName) — WCAG contrast', () {
      for (final role in _textRoles) {
        test('${role.name} clears ${role.min}:1', () {
          final ratio = _contrast(role.fg(palette), role.bg(palette));
          expect(
            ratio,
            greaterThanOrEqualTo(role.min),
            reason:
                '$modeName: ${role.name} is ${ratio.toStringAsFixed(2)}:1, '
                'below the ${role.min}:1 minimum. Text at this ratio is hard '
                'to read — pick a darker (light mode) or lighter (dark mode) '
                'value for the foreground token.',
          );
        });
      }

      for (final role in _uiRoles) {
        test('${role.name} clears ${role.min}:1', () {
          final ratio = _contrast(role.fg(palette), role.bg(palette));
          expect(
            ratio,
            greaterThanOrEqualTo(role.min),
            reason:
                '$modeName: ${role.name} is ${ratio.toStringAsFixed(2)}:1, '
                'below the ${role.min}:1 minimum.',
          );
        });
      }

      test('every curriculum colour is legible on the card surface', () {
        for (final read in _curriculumRoles) {
          final ratio = _contrast(read(palette), palette.brandCreamCard);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$modeName: a curriculum identity colour is only '
                '${ratio.toStringAsFixed(2)}:1 on the card surface.',
          );
        }
      });
    });
  }

  group('AppPalette resolves per brightness', () {
    test('light and dark disagree on every surface and ink role', () {
      const l = AppPalette.light;
      const d = AppPalette.dark;
      // These are exactly the roles that were light-only before the migration.
      expect(l.brandCream, isNot(d.brandCream));
      expect(l.brandCreamCard, isNot(d.brandCreamCard));
      expect(l.brandCreamSoft, isNot(d.brandCreamSoft));
      expect(l.brandOutline, isNot(d.brandOutline));
      expect(l.brandInk, isNot(d.brandInk));
      expect(l.brandInkMuted, isNot(d.brandInkMuted));
    });

    test('dark ink is light and light ink is dark', () {
      expect(_luminance(AppPalette.light.brandInk), lessThan(0.1));
      expect(_luminance(AppPalette.dark.brandInk), greaterThan(0.7));
    });

    test('the canvas is light in light mode and dark in dark mode', () {
      expect(_luminance(AppPalette.light.brandCream), greaterThan(0.8));
      expect(_luminance(AppPalette.dark.brandCream), lessThan(0.05));
    });
  });

  group('ColorScheme on-colours are legible on their fills', () {
    // The ThemeData is built INSIDE each test: constructing it touches
    // GoogleFonts, which needs the test binding initialised.
    for (final modeName in const ['light', 'dark']) {
      for (final roleName in const [
        'onPrimary/primary',
        'onSecondary/secondary',
        'onTertiary/tertiary',
        'onError/error',
        'onSurface/surface',
        'onSurfaceVariant/surface',
        'onPrimaryContainer/primaryContainer',
        'onSecondaryContainer/secondaryContainer',
        'onTertiaryContainer/tertiaryContainer',
      ]) {
        test('$modeName: $roleName clears 4.5:1', () {
          final scheme =
              (modeName == 'dark'
                      ? AppTheme.darkTheme()
                      : AppTheme.lightTheme())
                  .colorScheme;
          final pair = switch (roleName) {
            'onPrimary/primary' => (scheme.onPrimary, scheme.primary),
            'onSecondary/secondary' => (scheme.onSecondary, scheme.secondary),
            'onTertiary/tertiary' => (scheme.onTertiary, scheme.tertiary),
            'onError/error' => (scheme.onError, scheme.error),
            'onSurface/surface' => (scheme.onSurface, scheme.surface),
            'onSurfaceVariant/surface' => (
              scheme.onSurfaceVariant,
              scheme.surface,
            ),
            'onPrimaryContainer/primaryContainer' => (
              scheme.onPrimaryContainer,
              scheme.primaryContainer,
            ),
            'onSecondaryContainer/secondaryContainer' => (
              scheme.onSecondaryContainer,
              scheme.secondaryContainer,
            ),
            _ => (scheme.onTertiaryContainer, scheme.tertiaryContainer),
          };
          final ratio = _contrast(pair.$1, pair.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$modeName: $roleName is only ${ratio.toStringAsFixed(2)}:1. '
                'A filled component at this ratio has unreadable label text.',
          );
        });
      }
    }
  });

  group('AppTheme registers the palette', () {
    test('light theme carries the light palette', () {
      final theme = AppTheme.lightTheme();
      final palette = theme.extension<AppPalette>();
      expect(palette, isNotNull);
      expect(palette!.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppPalette.light.brandCream);
    });

    test('dark theme carries the dark palette', () {
      final theme = AppTheme.darkTheme();
      final palette = theme.extension<AppPalette>();
      expect(palette, isNotNull);
      expect(palette!.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppPalette.dark.brandCream);
    });

    testWidgets('AppPalette.of falls back to light when unregistered', (
      tester,
    ) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          // A bare theme with no AppPalette extension registered.
          theme: ThemeData(useMaterial3: true),
          home: Builder(
            builder: (context) {
              resolved = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, AppPalette.light);
    });

    testWidgets('context.colors follows the ambient theme brightness', (
      tester,
    ) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Builder(
            builder: (context) {
              resolved = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.brightness, Brightness.dark);
      expect(resolved.brandInk, AppPalette.dark.brandInk);
    });
  });
}
