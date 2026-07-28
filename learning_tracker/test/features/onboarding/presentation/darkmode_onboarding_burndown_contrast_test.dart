// Dark-mode legibility burndown — onboarding area (Owner Decision #2,
// docs/planning/post-sweep-decisions.md). Modelled on
// `test/core/theme/darkmode_sweep_contrast_test.dart`'s WCAG-helper +
// widget-pump style.
//
// Every finding below shares the same root cause: `introNavy` is a FILL
// role that deliberately stays a deep, saturated blue in BOTH themes (hero
// card/pill backgrounds), but several call sites across the intro carousel
// illustrations reused either introNavy itself (or a SURFACE token like
// `brandCreamCard`) directly as INK on top of a surface that behaves the
// opposite way — either the surface correctly darkens (so fixed-navy ink
// sinks into it) or the fill stays coloured (so a surface-role ink washes
// out). All ratios below are COMPUTED from the palette's hex values (no
// device needed), per the campaign's own WCAG method.
//
// Finding O1 — AppIntroScreen's highlighted title word: a private
// `_kNavy = Color(0xFF1A36A5)` (== introNavy's light value) painted directly
// on the screen's own `brandCream` background, which correctly darkens.
// Computed: 9.35:1 (light) vs **1.93:1** (dark). Fixed by a new
// `AppPalette.introAccentInk` token (identical light hex, lightens in dark).
//
// Finding O2 — IntroPageIndicator's active dot: introNavy fill on the same
// darkening `brandCream` background. Computed: 9.35:1 (light) vs **1.52:1**
// (dark) — barely above the INACTIVE dot's 1.44:1, so the active state
// nearly vanished. Fixed with introAccentInk.
//
// Finding O3 — Daily-plan illustration's "checked" pill: the check icon read
// `brandCreamCard` (a SURFACE token, correctly darkens) painted on the
// introNavy pill (stays deep navy). Computed: 9.93:1 (light) vs **1.39:1**
// (dark). Fixed with the existing `introCtaLabel` token (fixed white, same
// pairing as GlowingCtaButton's label on introNavy).
//
// Finding O4 — goldTrophy (darkens in dark mode by design, for ink-on-fixed
// -white use) painted on introNavy fill in two illustrations (daily-plan
// auto_awesome badge, rewards trophy hero). Computed: 6.48:1 (light) vs
// **1.13:1** (dark). Fixed with the existing `goldOnColouredSurface` token.
//
// Finding O5 — Mishna "Review…" chip: introNavy text on introPillBlue (a
// SURFACE token, correctly darkens). Computed: 6.92:1 (light) vs **1.33:1**
// (dark). Fixed with introAccentInk.
//
// Finding O6 — Mishna illustration's big icon + lightbulb chip: same
// brandCreamCard-as-ink-on-introNavy-fill bug as O3. Computed: 9.93:1
// (light) vs **1.39:1** (dark). Fixed with introCtaLabel.
//
// Finding O7 — Rewards "Badge Collection" feature card: text/icon read
// introNavy on brandCreamCard / introBadgeBg (both correctly darken).
// Computed: 8.45–9.93:1 (light) vs **1.38–1.39:1** (dark) — the sibling
// "Mystery Prizes" card already used adapting ink (introMysteryText/Icon).
// Fixed with introAccentInk.
//
// Finding O8 — IntroChildModeTag: icon/title/body read introNavy on
// introBadgeBg (correctly darkens). Computed: 8.45:1 (light) vs **1.38:1**
// (dark). Fixed with introAccentInk.
//
// Finding O9 — IntroScholarLevelCard's "EXAMPLE" badge: text read introNavy
// on a low-alpha introNavy tint over brandCreamCard (correctly darkens).
// Computed: 8.34:1 (light) vs **1.35:1** (dark). Fixed with introAccentInk.
//
// Finding O10 — OnboardingProfileCreationStep's "Child" mode card icon
// circle: a hardcoded `Color(0xFFE8E0FF)` background (stays light lavender
// in dark) under `brandInkMuted` ink (lightens for dark surfaces) — the
// sibling "Adult" card already used the theme-aware `brandOutline`.
// Computed: 4.71:1 (light) vs **2.03:1** (dark). Fixed with a new
// `AppPalette.onboardingChildIconBg` token.
//
// Finding O11 — brandBlue-filled CTAs with hardcoded white text
// (PermissionPromptScreen's primary CTA; OnboardingProfileCreationStep's
// "Create Profile" CTA and the selected Nikud/Calendar pill). brandBlue
// LIGHTENS in dark mode (0xFF7CA0FF, a pale pastel blue) — the app's own
// `AppTheme._build`'s `onFill` helper already computes the correct
// contrast-safe foreground (near-black vs white) for exactly this fill, but
// these call sites bypassed it with a literal `Colors.white`. Computed:
// 8.40:1 (light) vs **2.52:1** (dark). Fixed by reading
// `theme.colorScheme.onPrimary` instead of hardcoding white.

@Tags(['onboarding', 'core'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/permission_prompt_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_daily_plan_page.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_mishna_page.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_page_indicator.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_rewards_page.dart';

import '../../../helpers/pump_app.dart';

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

void _noopCreated({
  required dynamic profile,
  required bool isChildMode,
  required bool useHebrewCalendar,
  required bool useHebrewTerms,
  required bool showNikud,
  required dynamic transliterationVariant,
}) {}

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
  group('Finding O1 — AppIntroScreen highlighted title word', () {
    test('introAccentInk clears WCAG 4.5:1 on brandCream in dark mode '
        '(computed 1.93:1 on the pre-fix fixed-navy literal)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.introAccentInk, palette.brandCream);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the highlighted word read a private _kNavy literal (== '
            "introNavy's light value), which stayed deep navy on this "
            'screen\'s own brandCream background — a SURFACE token that '
            'correctly darkens in dark mode',
      );
    });

    test('light mode is unchanged — introAccentInk keeps the exact '
        'pre-fix 0xFF1A36A5 hex', () {
      const light = AppPalette.light;

      expect(light.introAccentInk, const Color(0xFF1A36A5));
      expect(
        _contrast(light.introAccentInk, light.brandCream),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Finding O2 — IntroPageIndicator active dot', () {
    test('introAccentInk clears WCAG (non-text) 3:1 on brandCream in dark '
        'mode (computed 1.52:1 on the pre-fix introNavy fill, barely above '
        "the inactive dot's 1.44:1)", () {
      const palette = AppPalette.dark;
      final activeRatio = _contrast(palette.introAccentInk, palette.brandCream);
      final inactiveRatio = _contrast(
        palette.introIndicatorInactive,
        palette.brandCream,
      );

      expect(activeRatio, greaterThanOrEqualTo(3.0));
      expect(
        activeRatio,
        greaterThan(inactiveRatio * 2),
        reason:
            'the active dot must clearly outshine the inactive dot in dark '
            'mode too, not converge with it (pre-fix: 1.52:1 vs 1.44:1)',
      );
    });

    testWidgets(
      'the real active dot reads introAccentInk (not introNavy) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(
                body: IntroPageIndicator(pageCount: 3, currentPage: 0),
              ),
            ),
          ),
        );
        await tester.pump();

        final containers = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .toList();
        final activeDecoration = containers.first.decoration! as BoxDecoration;

        expect(activeDecoration.color, AppPalette.dark.introAccentInk);
        expect(activeDecoration.color, isNot(AppPalette.dark.introNavy));
      },
    );

    testWidgets('the real active dot keeps the exact pre-fix introNavy '
        'colour in light mode (no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Scaffold(
            body: IntroPageIndicator(pageCount: 3, currentPage: 0),
          ),
        ),
      );
      await tester.pump();

      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      final activeDecoration = containers.first.decoration! as BoxDecoration;
      expect(activeDecoration.color, const Color(0xFF1A36A5));
    });
  });

  group('Finding O3/O6 — introCtaLabel ink on introNavy fill '
      '(daily-plan check icon, mishna big icon + lightbulb chip)', () {
    test('introCtaLabel clears WCAG 4.5:1 on introNavy in dark mode '
        '(computed 1.39:1 on the pre-fix brandCreamCard-as-ink pairing)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.introCtaLabel, palette.introNavy);

      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(
        _contrast(palette.brandCreamCard, palette.introNavy),
        lessThan(1.5),
        reason:
            'documents the pre-fix failure: brandCreamCard (a SURFACE '
            'token) darkens to near-introNavy in dark mode',
      );
    });

    testWidgets(
      'IntroDailyPlanIllustration check icon reads introCtaLabel (not '
      'brandCreamCard) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(
                body: IntroDailyPlanIllustration(
                  animation: AlwaysStoppedAnimation(1),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(checkIcon.color, AppPalette.dark.introCtaLabel);
        expect(checkIcon.color, isNot(AppPalette.dark.brandCreamCard));
      },
    );

    testWidgets(
      'IntroMishnaIllustration big icon + lightbulb chip read introCtaLabel '
      '(not brandCreamCard) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(
                body: IntroMishnaIllustration(
                  animation: AlwaysStoppedAnimation(1),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final bigIcon = tester.widget<Icon>(
          find.byIcon(Icons.psychology_rounded),
        );
        expect(bigIcon.color, AppPalette.dark.introCtaLabel);
        expect(bigIcon.color, isNot(AppPalette.dark.brandCreamCard));

        final lightbulbChip = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(Icons.lightbulb_outline),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = lightbulbChip.decoration! as BoxDecoration;
        expect(decoration.color, AppPalette.dark.introCtaLabel);
        expect(decoration.color, isNot(AppPalette.dark.brandCreamCard));
      },
    );
  });

  group('Finding O4 — goldOnColouredSurface ink on introNavy fill '
      '(daily-plan + rewards trophy icons)', () {
    test('goldOnColouredSurface clears WCAG 4.5:1 on introNavy in dark mode '
        '(computed 1.13:1 on the pre-fix goldTrophy pairing)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.goldOnColouredSurface, palette.introNavy);

      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(
        _contrast(palette.goldTrophy, palette.introNavy),
        lessThan(1.5),
        reason:
            'documents the pre-fix failure: goldTrophy DARKENS in dark mode '
            '(designed for ink-on-fixed-white use) but introNavy stays deep '
            'navy in both themes',
      );
    });

    testWidgets('IntroDailyPlanIllustration auto_awesome badge reads '
        'goldOnColouredSurface (not goldTrophy) in dark mode', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: const Scaffold(
              body: IntroDailyPlanIllustration(
                animation: AlwaysStoppedAnimation(1),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
      expect(icon.color, AppPalette.dark.goldOnColouredSurface);
      expect(icon.color, isNot(AppPalette.dark.goldTrophy));
    });

    testWidgets(
      'IntroRewardsHeroIllustration trophy icon reads goldOnColouredSurface '
      '(not goldTrophy) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(
                body: IntroRewardsHeroIllustration(
                  animation: AlwaysStoppedAnimation(1),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.emoji_events_rounded),
        );
        expect(icon.color, AppPalette.dark.goldOnColouredSurface);
        expect(icon.color, isNot(AppPalette.dark.goldTrophy));
      },
    );
  });

  group('Finding O5 — Mishna "Review…" chip text', () {
    test('introAccentInk clears WCAG 4.5:1 on introPillBlue in dark mode '
        '(computed 1.33:1 on the pre-fix introNavy-as-ink pairing)', () {
      const palette = AppPalette.dark;
      final ratio = _contrast(palette.introAccentInk, palette.introPillBlue);

      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(
        _contrast(palette.introNavy, palette.introPillBlue),
        lessThan(1.5),
      );
    });

    testWidgets(
      'the real chip reads introAccentInk (not introNavy) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(
                body: IntroMishnaIllustration(
                  animation: AlwaysStoppedAnimation(1),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final chipText = tester.widget<Text>(find.text('Review…'));
        expect(chipText.style?.color, AppPalette.dark.introAccentInk);
        expect(chipText.style?.color, isNot(AppPalette.dark.introNavy));
      },
    );
  });

  group('Finding O7 — Rewards "Badge Collection" feature card', () {
    test('introAccentInk clears WCAG 4.5:1 on both brandCreamCard and '
        'introBadgeBg in dark mode (computed 1.38-1.39:1 on the pre-fix '
        'introNavy-as-ink pairing)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.introAccentInk, palette.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette.introAccentInk, palette.introBadgeBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette.introNavy, palette.brandCreamCard),
        lessThan(1.5),
      );
    });

    testWidgets(
      'the real "Badge Collection" card reads introAccentInk (not introNavy) '
      'for its text/icon in dark mode, while "Mystery Prizes" keeps its '
      'already-correct adapting ink',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(body: IntroFeatureCardsRow()),
            ),
          ),
        );
        await tester.pump();

        final badgeIcon = tester.widget<Icon>(
          find.byIcon(Icons.military_tech_outlined),
        );
        expect(badgeIcon.color, AppPalette.dark.introAccentInk);
        expect(badgeIcon.color, isNot(AppPalette.dark.introNavy));

        final badgeText = tester.widget<Text>(find.text('Badge\nCollection'));
        expect(badgeText.style?.color, AppPalette.dark.introAccentInk);

        final mysteryIcon = tester.widget<Icon>(
          find.byIcon(Icons.card_giftcard_rounded),
        );
        expect(mysteryIcon.color, AppPalette.dark.introMysteryIcon);
      },
    );

    testWidgets('the real "Badge Collection" card keeps the exact pre-fix '
        'introNavy-equal colour in light mode (no regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(child: const Scaffold(body: IntroFeatureCardsRow())),
      );
      await tester.pump();

      final badgeIcon = tester.widget<Icon>(
        find.byIcon(Icons.military_tech_outlined),
      );
      expect(badgeIcon.color, const Color(0xFF1A36A5));
    });
  });

  group('Finding O8 — IntroChildModeTag', () {
    test('introAccentInk clears WCAG 4.5:1 on introBadgeBg in dark mode '
        '(computed 1.38:1 on the pre-fix introNavy-as-ink pairing)', () {
      const palette = AppPalette.dark;
      expect(
        _contrast(palette.introAccentInk, palette.introBadgeBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real tag reads introAccentInk (not introNavy) for its icon/title '
      'in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Theme(
              data: AppTheme.darkTheme(),
              child: const Scaffold(body: IntroChildModeTag()),
            ),
          ),
        );
        await tester.pump();

        final icon = tester.widget<Icon>(find.byIcon(Icons.child_care_rounded));
        expect(icon.color, AppPalette.dark.introAccentInk);
        expect(icon.color, isNot(AppPalette.dark.introNavy));

        final title = tester.widget<Text>(find.text('For Child profiles only'));
        expect(title.style?.color, AppPalette.dark.introAccentInk);
      },
    );
  });

  group(
    'Finding O10 — OnboardingProfileCreationStep child-mode icon circle',
    () {
      test('onboardingChildIconBg clears WCAG 4.5:1 against brandInkMuted in '
          'dark mode (computed 2.03:1 on the pre-fix Color(0xFFE8E0FF) '
          'literal)', () {
        const palette = AppPalette.dark;
        final ratio = _contrast(
          palette.brandInkMuted,
          palette.onboardingChildIconBg,
        );

        expect(ratio, greaterThanOrEqualTo(4.5));
        expect(
          _contrast(palette.brandInkMuted, const Color(0xFFE8E0FF)),
          lessThan(2.5),
        );
      });

      test('light mode is unchanged — onboardingChildIconBg keeps the exact '
          'pre-fix 0xFFE8E0FF hex', () {
        const light = AppPalette.light;
        expect(light.onboardingChildIconBg, const Color(0xFFE8E0FF));
      });

      testWidgets(
        'the real "Child" mode card circle reads onboardingChildIconBg (not '
        'the hardcoded 0xFFE8E0FF literal) in dark mode',
        (tester) async {
          await tester.pumpWidget(
            pumpApp(
              overrides: [
                useHebrewTermsProvider.overrideWith(
                  () => _FalseUseHebrewTerms(),
                ),
              ],
              child: Theme(
                data: AppTheme.darkTheme(),
                child: const Scaffold(
                  body: OnboardingProfileCreationStep(onCreated: _noopCreated),
                ),
              ),
            ),
          );
          await tester.pump();

          final avatars = tester
              .widgetList<CircleAvatar>(find.byType(CircleAvatar))
              .toList();
          // First card is the (unselected-by-default) "Child" mode card.
          expect(
            avatars.first.backgroundColor,
            AppPalette.dark.onboardingChildIconBg,
          );
          expect(avatars.first.backgroundColor, isNot(const Color(0xFFE8E0FF)));
        },
      );
    },
  );

  group('Finding O11 — brandBlue-filled CTA foreground '
      '(PermissionPromptScreen + OnboardingProfileCreationStep)', () {
    test('AppTheme.darkTheme()\'s colorScheme.onPrimary clears WCAG 4.5:1 on '
        'brandBlue in dark mode (computed 2.52:1 on the pre-fix hardcoded '
        'Colors.white)', () {
      final darkTheme = AppTheme.darkTheme();
      final ratio = _contrast(
        darkTheme.colorScheme.onPrimary,
        darkTheme.colorScheme.primary,
      );

      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(
        _contrast(Colors.white, darkTheme.colorScheme.primary),
        lessThan(3.0),
        reason:
            'documents the pre-fix failure: brandBlue LIGHTENS in dark '
            'mode (a pale pastel blue) so hardcoded white text on it fails',
      );
    });

    test('light mode is unchanged — onPrimary still resolves to white on '
        "brandBlue's saturated light-mode value", () {
      final lightTheme = AppTheme.lightTheme();
      expect(lightTheme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(
        _contrast(
          lightTheme.colorScheme.onPrimary,
          lightTheme.colorScheme.primary,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      "PermissionPromptScreen's primary CTA reads colorScheme.onPrimary "
      '(not hardcoded white) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            overrides: [
              useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
            ],
            theme: AppTheme.darkTheme(),
            child: const PermissionPromptScreen(isOnboarding: true),
          ),
        );
        await tester.pump();

        // PermissionPromptScreen has a second FilledButton (the idle-state
        // "Allow" button on each permission card, which correctly reads the
        // fixed-deep notifDeviceToggleActiveTrack — not in scope here), so
        // find the primary CTA by its own label text instead of by type.
        final buttonText = tester.widget<Text>(find.text('Start Learning'));
        expect(
          buttonText.style?.color,
          AppTheme.darkTheme().colorScheme.onPrimary,
        );
        expect(buttonText.style?.color, isNot(Colors.white));
      },
    );

    testWidgets("OnboardingProfileCreationStep's \"Create Profile\" CTA reads "
        'colorScheme.onPrimary (not hardcoded white) in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
          ],
          theme: AppTheme.darkTheme(),
          child: const Scaffold(
            body: OnboardingProfileCreationStep(onCreated: _noopCreated),
          ),
        ),
      );
      await tester.pump();

      final buttonText = tester.widget<Text>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Create Profile'),
        ),
      );
      expect(
        buttonText.style?.color,
        AppTheme.darkTheme().colorScheme.onPrimary,
      );
      expect(buttonText.style?.color, isNot(Colors.white));
    });
  });
}
