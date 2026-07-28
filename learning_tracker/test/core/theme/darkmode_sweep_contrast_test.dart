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
//
// Run-11 acceptance sweep deferred three more findings (SELECTED-state
// counterparts of the above, held back for careful, precedent-matching
// fixes) — Findings 4-6 below:
//
// Finding 4 (P1) — `ReviewPresetCard`'s SELECTED variant
// (`chazara_widgets.dart`): the gradient fill was painted directly from
// `brandBlueDeep`/`brandBlueBright` — a CONTRAST role that deliberately
// LIGHTENS in dark mode for ink-on-dark-surface use — with white
// title/icon/subtitle text on top. Used as a FILL instead of ink, the
// lightened dark values washed the card to pale lavender: measured
// **1.63:1** (title/icon) and **1.85:1** (subtitle region) in dark. Same
// hero-fill role as `blueMedium`/`blueLight`/`blueMid`. Fixed with two new
// tokens, `chazaraSelectedGradientStart`/`End`, pinned to the exact
// pre-fix light-mode hex pair in both themes.
//
// Finding 5 (P1) — `AddProfileModePickCard`'s SELECTED variant
// (`add_profile_mode_pick_card.dart`): the background was a hardcoded
// `Colors.white` (stays white in dark) under a title/subtitle reading
// `brandBlueDeep`/`brandBlue`, which LIGHTEN in dark for ink-on-dark-card
// use — light-blue-on-white, measured **1.63:1** (title) / **2.52:1**
// (subtitle). Fixed by pointing the background at `brandCreamCard`
// (identical `0xFFFFFFFF` in light mode); the existing dark-mode ink
// tokens then do exactly the job they were designed for.
//
// Finding 6 (P2) — the "Custom Cycle" card in `step_chazara.dart`: same
// hardcoded-`Colors.white` bug as Finding 2's (already-fixed) unselected
// preset card, under a `titleLarge` heading defaulting to `brandInk` —
// measured **1.16:1** in dark. Fixed the same way: background repointed at
// `brandCreamCard`.
//
// Finding 7 (P1) — Add-Track wizard "Study Days" step
// (`step_study_days.dart`'s `StudyDayCard`): the day-row card background was
// a hardcoded `Colors.white`, which stays white in dark mode, while the day
// title correctly read the theme's default `headlineSmall` colour
// (`brandInk`, near-white in dark) — white-on-white, measured 1.16:1 on
// device. Fixed the same way: background repointed at `brandCreamCard`.
//
// Finding 8 (P1) — Settings → "Add Lifetime Learning" curriculum picker
// (`lifetime_marking_screen.dart`): the card wrapping the title and the
// `HierarchySelectionPanel`/`LifetimeMarkingScopeRow` curriculum rows had a
// hardcoded `Colors.white` background, which stays white in dark mode, under
// text reading `context.colors.brandInk` (near-white in dark) — white-on-
// white, measured 1.16:1 on device. Fixed the same way: background
// repointed at `brandCreamCard`.
@Tags(['core_widgets', 'onboarding', 'tracks', 'profiles', 'settings'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/glowing_cta_button.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/chazara_widgets.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_study_days.dart';

import '../../helpers/pump_app.dart';

class _FakeProfileId extends ActiveProfileId {
  @override
  int build() => 1;
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

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

  group('Finding 4 — ReviewPresetCard SELECTED gradient (chazara step)', () {
    test('white clears WCAG 4.5:1 on both chazaraSelectedGradient stops in '
        'dark mode (measured 1.63:1 / 1.85:1 on the pre-fix '
        'brandBlueDeep/brandBlueBright pair)', () {
      const palette = AppPalette.dark;
      final startRatio = _contrast(
        Colors.white,
        palette.chazaraSelectedGradientStart,
      );
      final endRatio = _contrast(
        Colors.white,
        palette.chazaraSelectedGradientEnd,
      );

      expect(
        startRatio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the selected card gradient start was brandBlueDeep, which '
            'LIGHTENS in dark mode for its normal ink-on-dark-surface '
            'role; painted as a fill under white text it measured 1.63:1',
      );
      expect(
        endRatio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the selected card gradient end was brandBlueBright, same '
            'lightens-in-dark bug, measured 1.85:1 as a fill',
      );
    });

    test('light mode is unchanged — chazaraSelectedGradientStart/End equal the '
        'old brandBlueDeep/brandBlueBright light-mode hexes exactly', () {
      const light = AppPalette.light;

      expect(light.chazaraSelectedGradientStart, light.brandBlueDeep);
      expect(light.chazaraSelectedGradientEnd, light.brandBlueBright);
      expect(
        _contrast(Colors.white, light.chazaraSelectedGradientStart),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('the real selected card paints its gradient from the new '
        'chazaraSelectedGradient tokens (not brandBlueDeep/Bright) in dark '
        'mode', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: Scaffold(
              body: ReviewPresetCard(
                title: 'Week',
                subtitle: 'Review after 1 and 7 days',
                icon: Icons.auto_awesome_rounded,
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final decoration = box.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors[0], AppPalette.dark.chazaraSelectedGradientStart);
      expect(gradient.colors[1], AppPalette.dark.chazaraSelectedGradientEnd);
      expect(gradient.colors[0], isNot(AppPalette.dark.brandBlueDeep));
      expect(gradient.colors[1], isNot(AppPalette.dark.brandBlueBright));
    });

    testWidgets(
      'the real selected card keeps the exact pre-fix gradient in light '
      'mode (no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Scaffold(
              body: ReviewPresetCard(
                title: 'Week',
                subtitle: 'Review after 1 and 7 days',
                icon: Icons.auto_awesome_rounded,
                isSelected: true,
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
        final gradient = decoration.gradient! as LinearGradient;

        expect(gradient.colors[0], const Color(0xFF0E3392));
        expect(gradient.colors[1], const Color(0xFF2B5FD9));
      },
    );
  });

  group('Finding 5 — AddProfileModePickCard SELECTED background '
      '("Choose Mode" cards)', () {
    test(
      'brandBlueDeep/brandBlue clear WCAG 4.5:1 on brandCreamCard in dark '
      'mode (measured 1.63:1 / 2.52:1 on the pre-fix hardcoded-white bg)',
      () {
        const palette = AppPalette.dark;
        final titleRatio = _contrast(
          palette.brandBlueDeep,
          palette.brandCreamCard,
        );
        final subtitleRatio = _contrast(
          palette.brandBlue,
          palette.brandCreamCard,
        );

        expect(
          titleRatio,
          greaterThanOrEqualTo(4.5),
          reason:
              'the selected "Child Mode" card painted a hardcoded '
              'Colors.white background (stays white in dark) under a '
              'brandBlueDeep title, which LIGHTENS in dark for its '
              'ink-on-dark-card role — measured 1.63:1 on the still-white '
              'card',
        );
        expect(subtitleRatio, greaterThanOrEqualTo(4.5));
      },
    );

    test('light mode is unchanged — brandCreamCard keeps the exact pre-fix '
        'Colors.white value', () {
      const light = AppPalette.light;

      expect(light.brandCreamCard, const Color(0xFFFFFFFF));
      expect(
        _contrast(light.brandBlueDeep, light.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real selected card reads brandCreamCard (not the hardcoded '
      'Colors.white literal) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: Scaffold(
                body: AddProfileModePickCard(
                  selected: true,
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

        expect(decoration.color, AppPalette.dark.brandCreamCard);
        expect(decoration.color, isNot(const Color(0xFFFFFFFF)));
      },
    );

    testWidgets(
      'the real selected card keeps the exact Colors.white-equivalent '
      'background in light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Scaffold(
              body: AddProfileModePickCard(
                selected: true,
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
        expect(decoration.color, const Color(0xFFFFFFFF));
      },
    );
  });

  group('Finding 6 — "Custom Cycle" card background (step_chazara)', () {
    test('brandInk clears WCAG 4.5:1 on brandCreamCard in dark mode (measured '
        '1.16:1 on the pre-fix white-on-white pair)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.brandInk, palette.brandCreamCard);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the "Custom Cycle" card painted a hardcoded Colors.white '
            'background under a titleLarge heading defaulting to brandInk '
            '(near-white in dark) — white-on-white',
      );
    });

    test('light mode is unchanged — brandCreamCard stays pure white, same as '
        'the old hardcoded Colors.white literal', () {
      const light = AppPalette.light;

      expect(light.brandCreamCard, const Color(0xFFFFFFFF));
      expect(
        _contrast(light.brandInk, light.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real Custom Cycle card reads brandCreamCard (not the hardcoded '
      'white literal) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: Scaffold(
                body: ChazaraInlineSetup(
                  curriculumId: CurriculumId.mishnayos,
                  headerTitle: 'Review Schedule',
                  headerSubtitle: 'Choose how often to review',
                  onComplete: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester.widget<DecoratedBox>(
          find.ancestor(
            of: find.text('Custom Cycle'),
            matching: find.byType(DecoratedBox),
          ),
        );
        final decoration = box.decoration as BoxDecoration;

        expect(decoration.color, AppPalette.dark.brandCreamCard);
        expect(decoration.color, isNot(Colors.white));
      },
    );

    testWidgets('the real Custom Cycle card stays white in light mode '
        '(no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: ChazaraInlineSetup(
              curriculumId: CurriculumId.mishnayos,
              headerTitle: 'Review Schedule',
              headerSubtitle: 'Choose how often to review',
              onComplete: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('Custom Cycle'),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
    });
  });

  group('Finding 7 — StudyDayCard background (Add-Track "Study Days" step)', () {
    test('brandInk clears WCAG 4.5:1 on brandCreamCard in dark mode (measured '
        '1.16:1 on the pre-fix white-on-white pair)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.brandInk, palette.brandCreamCard);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the day-row card painted a hardcoded Colors.white background '
            'under a headlineSmall title defaulting to brandInk (near-white '
            'in dark) — white-on-white, measured 1.16:1 on device',
      );
    });

    test('light mode is unchanged — brandCreamCard stays pure white, same as '
        'the old hardcoded Colors.white literal', () {
      const light = AppPalette.light;

      expect(light.brandCreamCard, const Color(0xFFFFFFFF));
      expect(
        _contrast(light.brandInk, light.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real StudyDayCard reads brandCreamCard (not the hardcoded white '
      'literal) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: Scaffold(
                body: StudyDayCard(
                  initial: 'S',
                  title: 'Sunday',
                  subtitle: '',
                  subtitleColor: AppPalette.dark.brandInkMuted,
                  activeColor: AppPalette.dark.surfaceE9,
                  isShabbos: false,
                  isOn: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester.widget<DecoratedBox>(
          find.ancestor(
            of: find.text('Sunday'),
            matching: find.byType(DecoratedBox),
          ),
        );
        final decoration = box.decoration as BoxDecoration;

        expect(decoration.color, AppPalette.dark.brandCreamCard);
        expect(decoration.color, isNot(Colors.white));
      },
    );

    testWidgets('the real StudyDayCard stays white in light mode '
        '(no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: StudyDayCard(
              initial: 'S',
              title: 'Sunday',
              subtitle: '',
              subtitleColor: AppPalette.light.brandInkMuted,
              activeColor: AppPalette.light.surfaceE9,
              isShabbos: false,
              isOn: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('Sunday'),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
    });
  });

  group('Finding 8 — LifetimeCurriculumMarkingScreen picker card background '
      '(Settings → Add Lifetime Learning)', () {
    test('brandInk clears WCAG 4.5:1 on brandCreamCard in dark mode '
        '(measured 1.16:1 on the pre-fix white-on-white pair)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.brandInk, palette.brandCreamCard);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the card wrapping the title and the curriculum-picker rows '
            'painted a hardcoded Colors.white background under text '
            'reading brandInk (near-white in dark) — white-on-white, '
            'measured 1.16:1 on device',
      );
    });

    test('light mode is unchanged — brandCreamCard stays pure white, same '
        'as the old hardcoded Colors.white literal', () {
      const light = AppPalette.light;

      expect(light.brandCreamCard, const Color(0xFFFFFFFF));
      expect(
        _contrast(light.brandInk, light.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real picker card reads brandCreamCard (not the hardcoded white '
      'literal) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            overrides: [
              activeProfileIdProvider.overrideWith(() => _FakeProfileId()),
              useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
              curriculumLedgerProvider.overrideWith(
                (ref, id) async => const <LearningLedgerData>[],
              ),
              curriculumContentProvider.overrideWith(
                (ref, curriculumId) async => const <ContentItem>[],
              ),
            ],
            child: LifetimeCurriculumMarkingScreen(
              curriculumId: CurriculumId.mishnayos.storageKey,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        final box = tester.widget<Container>(
          find.ancestor(
            of: find.text("Select what you've learned"),
            matching: find.byType(Container),
          ),
        );
        final decoration = box.decoration! as BoxDecoration;

        expect(decoration.color, AppPalette.dark.brandCreamCard);
        expect(decoration.color, isNot(Colors.white));
      },
    );

    testWidgets('the real picker card stays white in light mode '
        '(no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            activeProfileIdProvider.overrideWith(() => _FakeProfileId()),
            useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
            curriculumLedgerProvider.overrideWith(
              (ref, id) async => const <LearningLedgerData>[],
            ),
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) async => const <ContentItem>[],
            ),
          ],
          child: LifetimeCurriculumMarkingScreen(
            curriculumId: CurriculumId.mishnayos.storageKey,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final box = tester.widget<Container>(
        find.ancestor(
          of: find.text("Select what you've learned"),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
    });
  });
}
