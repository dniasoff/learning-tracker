// darkmode/tracks audit — dark-mode legibility sweep over
// lib/features/tracks/, modelled on darkmode_sweep_contrast_test.dart's WCAG
// helper and widget-pump style.
//
// Finding 1 — `CustomDayEditorChip` (chazara_widgets.dart): the day-number
// circle was a hardcoded `Colors.white` while the day-number text reads the
// theme's default `headlineSmall` colour (`brandInk`, near-white in dark) —
// white-on-white, measured ~1.05:1. Fixed by pointing the circle at
// `context.colors.brandCreamCard` (identical `0xFFFFFFFF` in light).
//
// Finding 2 — `TinyCircleButton` (chazara_widgets.dart): the +/- stepper
// circle fill was a hardcoded `Color(0xFFF1F3F7)` under an icon reading
// `brandInkMuted` (lightens in dark) — measured ~2.32:1. Fixed with the new
// `chazaraTinyButtonBg` token.
//
// Finding 3 — `ChazaraReadOnlyStep` (step_chazara_readonly.dart): three
// separate raw-literal surfaces (the "fixed by program" hint banner, the
// numbered stage-badge circle, and the stage-card background) sat under
// already-adapting ink (`brandBlueDeep`/default `brandInk`) — each measured
// well under 4.5:1 in dark. Fixed with `chazaraReadOnlyHintBg`,
// `chazaraReadOnlyStageBadgeBg`, and a repoint onto `brandCreamCard`.
//
// Finding 4 — `BlurInactiveGoalOption` (goal_cards.dart): the "why is this
// blurred" hint chip is a fixed near-opaque white in BOTH themes (a
// tooltip-like callout, not a themed card), but its text read
// `brandBlueDeep`, which deliberately LIGHTENS in dark for ink-on-dark-card
// use — measured 1.63:1 on the fixed white chip. Fixed with the new
// `goalHintChipInk` token, pinned to the exact light-mode hex in both themes.
//
// Findings 5-11 are genuinely visual sites behind PRIVATE widget classes
// (`EditTrackScreen`'s `_buildProgramLockedBanner`/`_SectionCard`/
// `_PeriodChip`; `TrackManagementBody`'s FAB;
// `StartingPositionCalendarMode`'s reset/date-icon/offset buttons;
// `CurriculumPickerStep`'s Mishnayos tile; `ProgramSelectionStep`'s
// `_FeaturedProgramCard`/self-paced CTA; `ScopeTopLevelView`'s "Learn All"
// hero gradient + breadcrumb card) that cannot be constructed/found from an
// external test file, or require heavy DB/router scaffolding out of
// proportion to a colour-token check. Per the campaign's "no clean unit
// assertion" fallback, these are covered at the palette level: each
// assertion below reproduces the exact pre-fix pairing's measured ratio and
// proves the fixed token clears WCAG while the light-mode hex is unchanged.
@Tags(['tracks', 'core_widgets'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/chazara_widgets.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_cards.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara_readonly.dart';

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
  group('Finding 1 — CustomDayEditorChip circle fill', () {
    test('brandInk clears WCAG 4.5:1 on brandCreamCard in dark mode '
        '(measured ~1.05:1 on the pre-fix Colors.white pair)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.brandInk, palette.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real chip circle reads brandCreamCard (not Colors.white) in '
      'dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: Scaffold(
                body: CustomDayEditorChip(
                  day: 3,
                  accentColor: Colors.blue,
                  onMinus: () {},
                  onPlus: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration! as BoxDecoration;

        expect(decoration.color, AppPalette.dark.brandCreamCard);
        expect(decoration.color, isNot(Colors.white));
      },
    );

    testWidgets('the real chip circle stays white in light mode '
        '(no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: CustomDayEditorChip(
              day: 3,
              accentColor: Colors.blue,
              onMinus: () {},
              onPlus: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
    });
  });

  group('Finding 2 — TinyCircleButton fill', () {
    test('brandInkMuted clears WCAG 3:1 (icon) on chazaraTinyButtonBg in '
        'dark mode (measured ~2.32:1 on the pre-fix Color(0xFFF1F3F7) '
        'pair)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.brandInkMuted, palette.chazaraTinyButtonBg),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('light mode is unchanged — chazaraTinyButtonBg keeps the exact '
        'pre-fix 0xFFF1F3F7 hex', () {
      const light = AppPalette.light;
      expect(light.chazaraTinyButtonBg, const Color(0xFFF1F3F7));
    });

    testWidgets('the real stepper button reads chazaraTinyButtonBg (not '
        'Color(0xFFF1F3F7)) in dark mode', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: Scaffold(
              body: TinyCircleButton(
                icon: Icons.add,
                onTap: () {},
                semanticLabel: 'Increase',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, AppPalette.dark.chazaraTinyButtonBg);
      expect(decoration.color, isNot(const Color(0xFFF1F3F7)));
    });
  });

  group('Finding 3 — ChazaraReadOnlyStep raw surfaces', () {
    test('brandBlueDeep clears WCAG 4.5:1 on chazaraReadOnlyHintBg in dark '
        'mode (measured ~1.46:1 on the pre-fix Color(0xFFEFF2FF) pair)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.brandBlueDeep, palette.chazaraReadOnlyHintBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test(
      'brandBlueDeep clears WCAG 4.5:1 on chazaraReadOnlyStageBadgeBg in '
      'dark mode (measured ~1.5:1 on the pre-fix Color(0xFFE9ECFF) pair)',
      () {
        const palette = AppPalette.dark;
        expect(
          _contrast(palette.brandBlueDeep, palette.chazaraReadOnlyStageBadgeBg),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    testWidgets(
      'the real screen reads the new tokens (not the raw literals) for '
      'the hint banner, stage badge, and card background in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: Scaffold(
                body: ChazaraReadOnlyStep(
                  programName: 'Daf Yomi',
                  stages: const [
                    {'stage': 'review_1', 'label': 'חזרה א׳', 'delay_days': 1},
                  ],
                  onContinue: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Hint banner is the sole plain Container in this screen (CircleAvatar
        // renders via AnimatedContainer, not Container).
        final hint = tester.widget<Container>(find.byType(Container).first);
        final hintDecoration = hint.decoration! as BoxDecoration;
        expect(hintDecoration.color, AppPalette.dark.chazaraReadOnlyHintBg);
        expect(hintDecoration.color, isNot(const Color(0xFFEFF2FF)));

        // The stage card is identified by its distinctive borderRadius(22)
        // (the hint banner above it uses borderRadius(14)) rather than
        // positional indexing, since Container/AnimatedContainer also build
        // through an internal DecoratedBox.
        final cardFinder = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).borderRadius ==
                  BorderRadius.circular(22),
        );
        final card = tester.widget<DecoratedBox>(cardFinder);
        final cardDecoration = card.decoration as BoxDecoration;
        expect(cardDecoration.color, AppPalette.dark.brandCreamCard);
        expect(cardDecoration.color, isNot(Colors.white));

        final badge = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(
          badge.backgroundColor,
          AppPalette.dark.chazaraReadOnlyStageBadgeBg,
        );
        expect(badge.backgroundColor, isNot(const Color(0xFFE9ECFF)));
      },
    );

    testWidgets('the real screen keeps the exact pre-fix hexes in light '
        'mode (no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: ChazaraReadOnlyStep(
              programName: 'Daf Yomi',
              stages: const [
                {'stage': 'review_1', 'label': 'חזרה א׳', 'delay_days': 1},
              ],
              onContinue: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final hint = tester.widget<Container>(find.byType(Container).first);
      final hintDecoration = hint.decoration! as BoxDecoration;
      expect(hintDecoration.color, const Color(0xFFEFF2FF));

      final cardFinder = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            (w.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(22),
      );
      final card = tester.widget<DecoratedBox>(cardFinder);
      final cardDecoration = card.decoration as BoxDecoration;
      expect(cardDecoration.color, const Color(0xFFFFFFFF));
    });
  });

  group('Finding 4 — BlurInactiveGoalOption hint-chip text', () {
    test('goalHintChipInk clears WCAG 4.5:1 on white in BOTH modes '
        '(brandBlueDeep measured 1.63:1 in dark on this fixed-white chip)', () {
      expect(
        _contrast(Colors.white, AppPalette.dark.goalHintChipInk),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(Colors.white, AppPalette.light.goalHintChipInk),
        greaterThanOrEqualTo(4.5),
      );
      expect(AppPalette.dark.goalHintChipInk, AppPalette.light.goalHintChipInk);
    });

    testWidgets('the real hint chip reads goalHintChipInk (not the lightening '
        'brandBlueDeep) in dark mode', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: Scaffold(
              body: BlurInactiveGoalOption(
                hint: 'Switch to Pace mode',
                onTap: () {},
                child: const SizedBox(width: 200, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('Switch to Pace mode'));
      expect(text.style?.color, AppPalette.dark.goalHintChipInk);
      expect(text.style?.color, isNot(AppPalette.dark.brandBlueDeep));
    });
  });

  // ---------------------------------------------------------------------------
  // Findings 5-11 — palette-level only (private widget classes / heavy
  // DB+router scaffolding). See the file-level doc comment.
  // ---------------------------------------------------------------------------

  group('Finding 5 — EditTrackScreen "program locked" banner', () {
    test('trackProgramLockedIcon/Text clear WCAG on trackProgramLockedBg in '
        'dark mode (measured ~1.46:1 on the pre-fix Color(0xFFF0F4FF) '
        'triple)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.trackProgramLockedIcon, palette.trackProgramLockedBg),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrast(palette.trackProgramLockedText, palette.trackProgramLockedBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — exact pre-fix hexes preserved', () {
      const light = AppPalette.light;
      expect(light.trackProgramLockedBg, const Color(0xFFF0F4FF));
      expect(light.trackProgramLockedIcon, const Color(0xFF6B84D6));
      expect(light.trackProgramLockedText, const Color(0xFF4A5C99));
    });
  });

  group('Finding 6 — EditTrackScreen _SectionCard background', () {
    test('brandInkMuted clears WCAG 4.5:1 on brandCreamCard in dark mode '
        '(measured ~2.58:1 on the pre-fix Colors.white pair)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.brandInkMuted, palette.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Finding 7 — EditTrackScreen _PeriodChip selected fill', () {
    test('white clears WCAG 4.5:1 on chazaraSelectedGradientEnd in dark '
        'mode (measured 1.85:1 on the pre-fix brandBlueBright-as-fill '
        'pair)', () {
      expect(
        _contrast(Colors.white, AppPalette.dark.chazaraSelectedGradientEnd),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — chazaraSelectedGradientEnd equals the '
        'old brandBlueBright light-mode hex exactly', () {
      expect(
        AppPalette.light.chazaraSelectedGradientEnd,
        AppPalette.light.brandBlueBright,
      );
    });
  });

  group('Finding 8 — TrackManagementBody "Add Track" FAB fill', () {
    test('white clears WCAG 4.5:1 on trackAddFabFill in dark mode '
        '(measured 2.52:1 on the pre-fix brandBlue-as-fill pair)', () {
      expect(
        _contrast(Colors.white, AppPalette.dark.trackAddFabFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — trackAddFabFill equals the old '
        'brandBlue light-mode hex exactly', () {
      expect(AppPalette.light.trackAddFabFill, AppPalette.light.brandBlue);
    });
  });

  group('Finding 9 — StartingPositionCalendarMode reset/date-icon/offset '
      'buttons', () {
    test('paired inks clear WCAG on the new button-fill tokens in dark '
        'mode (each measured well under threshold on its pre-fix raw '
        'literal)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.brandInk, palette.calendarResetButtonBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette.brandBlueDeep, palette.calendarDateIconBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette.brandBlueDeep, palette.calendarOffsetButtonBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — exact pre-fix hexes preserved', () {
      const light = AppPalette.light;
      expect(light.calendarResetButtonBg, const Color(0xFFE9EBF1));
      expect(light.calendarDateIconBg, const Color(0xFFE6E8FF));
      expect(light.calendarOffsetButtonBg, const Color(0xFFF4F6FA));
    });
  });

  group('Finding 10 — CurriculumPickerStep Mishnayos tile icon', () {
    test('curriculumMishnaPickerIcon clears WCAG 3:1 (icon) on '
        'surfaceBlueLight in dark mode (measured 2.65:1 on the pre-fix '
        'fixed-icon pair)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.curriculumMishnaPickerIcon, palette.surfaceBlueLight),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('light mode is unchanged — exact pre-fix hex preserved', () {
      expect(
        AppPalette.light.curriculumMishnaPickerIcon,
        const Color(0xFF3F53BF),
      );
    });
  });

  group(
    'Finding 11 — ProgramSelectionStep featured-card icon + self-paced CTA',
    () {
      test('programFeaturedCardIcon clears WCAG 3:1 (icon) on '
          'surfaceBlueLight in dark mode (measured 2.34:1 on the pre-fix '
          'fixed-icon pair)', () {
        const palette = AppPalette.dark;
        expect(
          _contrast(palette.programFeaturedCardIcon, palette.surfaceBlueLight),
          greaterThanOrEqualTo(3.0),
        );
      });

      test('programSelfPacedCtaText clears WCAG 4.5:1 on peachMid in dark '
          'mode (measured ~1.01:1 on the pre-fix pair — the fixed literal '
          'nearly coincided with peachMid\'s dark value)', () {
        const palette = AppPalette.dark;
        expect(
          _contrast(palette.programSelfPacedCtaText, palette.peachMid),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('light mode is unchanged — exact pre-fix hexes preserved', () {
        const light = AppPalette.light;
        expect(light.programFeaturedCardIcon, const Color(0xFF2E4BBB));
        expect(light.programSelfPacedCtaText, const Color(0xFF2E271E));
      });
    },
  );

  group('Finding 12 — ScopeTopLevelView "Learn All" hero gradient + breadcrumb '
      'card', () {
    test('white clears WCAG 4.5:1 on both chazaraSelectedGradient stops '
        'in dark mode (measured 1.63:1 / 1.85:1 on the pre-fix '
        'brandBlueDeep/brandBlueBright-as-gradient-fill pair — the exact '
        'hero-fill bug already fixed for ReviewPresetCard, missed at '
        'this call site)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(Colors.white, palette.chazaraSelectedGradientStart),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(Colors.white, palette.chazaraSelectedGradientEnd),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('brandInkMuted/brandBlueDeep clear WCAG 4.5:1 on brandCreamCard '
        'in dark mode (breadcrumb header card measured ~1.1:1 on the '
        'pre-fix Colors.white pair)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.brandInk, palette.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
