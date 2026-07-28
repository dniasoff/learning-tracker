// Dark-mode legibility sweep — three on-device findings, one file each
// covering both the palette-level WCAG math and the real widget's resolved
// colour, modelled on `run10_gold_on_coloured_surface_test.dart`'s WCAG
// helper and `run9_darkmode_legibility_test.dart`'s widget-pump style.
//
// Finding 1 (P1) — Onboarding AppIntro carousel primary CTA button
// (`glowing_cta_button.dart`): the label/arrow icon read
// `context.colors.brandCreamCard` — a SURFACE-role token that correctly
// darkens for cards — instead of a foreground token, so on the
// always-navy `introNavy` fill the label sank to near-black in dark mode.
// Measured on device: button bg `RGB(20,42,128)` vs label ink
// `RGB(21,26,38)` = **1.39:1**. Fixed by a new foreground token,
// `AppPalette.introCtaLabel`, that keeps white in both themes (same split
// rationale as `goldOnColouredSurface`).
//
// Finding 2 (P1) — Add-track wizard chazara step, unselected preset cards
// (`chazara_widgets.dart`'s `ReviewPresetCard`): the card background was a
// hardcoded `Colors.white`, which stays white in dark mode, while the
// heading text correctly read `context.colors.brandInk` (near-white in
// dark) — white-on-white, measured ~1.16:1 on the same token pair. Fixed
// by pointing the background at `context.colors.brandCreamCard` (its
// light value, `0xFFFFFFFF`, is pixel-identical to the old literal).
//
// Finding 3 (P2) — Add/Edit-Profile "Choose Mode" cards
// (`add_profile_mode_pick_card.dart`): the unselected card background was
// a hardcoded `Color(0xFFF2F4F7)` against the same `brandInk` heading —
// measured **1.06:1** on device for the "Child Mode" heading. Fixed by a
// new token, `AppPalette.profileModeCardBg`, that keeps the exact
// `0xFFF2F4F7` in light mode (not a re-point onto `brandCreamCard`, which
// is pure white and would have shifted the light-mode hex) and darkens in
// dark mode.
@Tags(['core_widgets', 'onboarding', 'tracks', 'profiles'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/glowing_cta_button.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/chazara_widgets.dart';

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
  group('Finding 1 — GlowingCtaButton label on introNavy', () {
    test('introCtaLabel clears WCAG 4.5:1 on introNavy in dark mode '
        '(measured 1.39:1 before the fix)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.introCtaLabel, palette.introNavy);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the CTA label/arrow icon sit on introNavy, which stays a deep '
            'saturated blue in both themes; borrowing the card-surface '
            'token (brandCreamCard) darkened the label to near-black and '
            'measured 1.39:1 on device',
      );
    });

    test('light mode is unchanged — introCtaLabel stays pure white, '
        'same as the old brandCreamCard-light value', () {
      const light = AppPalette.light;

      expect(light.introCtaLabel, const Color(0xFFFFFFFF));
      expect(
        _contrast(light.introCtaLabel, light.introNavy),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real button reads introCtaLabel (not brandCreamCard) for both '
      'the label and the arrow icon in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: Scaffold(
                body: GlowingCtaButton(onTap: () {}, label: 'Continue'),
              ),
            ),
          ),
        );
        await tester.pump();

        final text = tester.widget<Text>(find.text('Continue'));
        expect(text.style?.color, AppPalette.dark.introCtaLabel);
        expect(text.style?.color, isNot(AppPalette.dark.brandCreamCard));

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.arrow_forward_rounded),
        );
        expect(icon.color, AppPalette.dark.introCtaLabel);
        expect(icon.color, isNot(AppPalette.dark.brandCreamCard));
      },
    );

    testWidgets('the real button keeps white label/icon in light mode '
        '(no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: GlowingCtaButton(onTap: () {}, label: 'Continue'),
          ),
        ),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('Continue'));
      expect(text.style?.color, AppPalette.light.introCtaLabel);
      expect(text.style?.color, const Color(0xFFFFFFFF));
    });
  });

  group(
    'Finding 2 — ReviewPresetCard unselected background (chazara step)',
    () {
      test('brandInk clears WCAG 4.5:1 on brandCreamCard in dark mode '
          '(measured ~1.16:1 on the pre-fix white-on-white pair)', () {
        const palette = AppPalette.dark;
        final ratio = _contrast(palette.brandInk, palette.brandCreamCard);

        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              'the unselected preset card painted a hardcoded Colors.white '
              'background under a brandInk (near-white in dark) heading — '
              'white-on-white',
        );
      });

      test('light mode is unchanged — brandCreamCard stays pure white, '
          'same as the old hardcoded Colors.white literal', () {
        const light = AppPalette.light;

        expect(light.brandCreamCard, const Color(0xFFFFFFFF));
        expect(
          _contrast(light.brandInk, light.brandCreamCard),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets(
        'the real unselected card reads brandCreamCard (not the hardcoded '
        'white literal) in dark mode',
        (tester) async {
          await tester.pumpWidget(
            pumpApp(
              child: Theme(
                data: AppTheme.darkTheme(),
                child: Scaffold(
                  body: ReviewPresetCard(
                    title: 'Week',
                    subtitle: 'Review after 1 and 7 days',
                    icon: Icons.auto_awesome_rounded,
                    isSelected: false,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final box = tester.widget<DecoratedBox>(
            find.byType(DecoratedBox).first,
          );
          final decoration = box.decoration as BoxDecoration;

          expect(decoration.color, AppPalette.dark.brandCreamCard);
          expect(decoration.color, isNot(Colors.white));
        },
      );

      testWidgets('the real unselected card stays white in light mode '
          '(no regression)', (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Scaffold(
              body: ReviewPresetCard(
                title: 'Week',
                subtitle: 'Review after 1 and 7 days',
                icon: Icons.auto_awesome_rounded,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox).first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, const Color(0xFFFFFFFF));
      });
    },
  );

  group('Finding 3 — AddProfileModePickCard unselected background '
      '("Choose Mode" cards)', () {
    test('brandInk clears WCAG 4.5:1 on profileModeCardBg in dark mode '
        '(measured 1.06:1 before the fix)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.brandInk, palette.profileModeCardBg);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the unselected "Child Mode" card painted a hardcoded '
            'Color(0xFFF2F4F7) background under a brandInk (near-white '
            'in dark) heading — measured 1.06:1 on device',
      );
    });

    test('light mode is unchanged — profileModeCardBg keeps the exact '
        'pre-fix 0xFFF2F4F7 hex', () {
      const light = AppPalette.light;

      expect(light.profileModeCardBg, const Color(0xFFF2F4F7));
      expect(
        _contrast(light.brandInk, light.profileModeCardBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('the real unselected card reads profileModeCardBg (not the '
        'hardcoded 0xFFF2F4F7 literal) in dark mode', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: Scaffold(
              body: AddProfileModePickCard(
                selected: false,
                onTap: () {},
                icon: Icons.rocket_launch_rounded,
                title: 'Child Mode',
                subtitle: 'Fun rewards along the way',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final ink = tester.widget<Ink>(find.byType(Ink));
      final decoration = ink.decoration! as BoxDecoration;

      expect(decoration.color, AppPalette.dark.profileModeCardBg);
      expect(decoration.color, isNot(const Color(0xFFF2F4F7)));
    });

    testWidgets(
      'the real unselected card keeps the exact 0xFFF2F4F7 background in '
      'light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Scaffold(
              body: AddProfileModePickCard(
                selected: false,
                onTap: () {},
                icon: Icons.rocket_launch_rounded,
                title: 'Child Mode',
                subtitle: 'Fun rewards along the way',
              ),
            ),
          ),
        );
        await tester.pump();

        final ink = tester.widget<Ink>(find.byType(Ink));
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFFF2F4F7));
      },
    );
  });
}
