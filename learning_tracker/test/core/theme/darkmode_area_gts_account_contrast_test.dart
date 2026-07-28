// Dark-mode legibility burndown — gamification / tutoring / sacred_time /
// account areas (OWNER DECISION #2 burndown, one dedicated agent per area).
// Modelled on `darkmode_sweep_contrast_test.dart`'s WCAG helper + widget-pump
// style and `run10_gold_on_coloured_surface_test.dart`'s "pin the maths, not
// the hex" approach.
//
// Every finding below is the SAME root-cause shape: a CONTRAST-role token
// (ink meant to lighten against a darkening CARD, or an ACCENT meant to
// lighten for a dynamically-computed button foreground) was instead painted
// as a FILL/background under hardcoded white content, or as ink on a FIXED
// (non-adapting) surface — so in dark mode the two ends of the pair moved
// the SAME direction instead of opposite, collapsing the contrast.
//
// Finding A — `TierStyle.forTier`'s bronze branch: the badge icon glyph was
// a hardcoded `Colors.white`, but the bronze badge's own icon-accent surface
// (`gamifTierBronzeIconAccent`) LIGHTENS in dark mode (the opposite
// direction from every sibling tier) — measured 2.18:1. Fixed with
// `gamifTierBronzeIconFg`.
//
// Finding B — `ProgressSummaryCard`'s hero fill + "sparkle" badge: painted
// `brandBlue` (hero fill) and `statusErrorCardText` (badge fill) directly —
// both are CONTRAST roles that lighten in dark — under hardcoded white
// content. Measured 2.52:1 / 2.71:1. Fixed with `gamifProgressSummaryFill` /
// `gamifProgressSummaryBadgeFill`.
//
// Finding C — the recurring "brandBlueDeep as button/pill FILL" bug, present
// in `RewardConfigurationScreen`'s Save button + reward-preview icon (on a
// FIXED white circle), `ChildRedemptionScreen`'s Redeem button,
// `ParentPendingRedemptionsScreen`'s Approve button, `RewardTypeSegmented`'s
// selected pill, and `AccountPickerScreen`'s cloud-pill text (on a FIXED
// light-blue pill) — all measured ~1.4-1.6:1 in dark. Fixed by repointing
// each call site at the EXISTING `chazaraSelectedGradientStart` token (a
// deep navy pinned to the exact old brandBlueDeep light literal
// `0xFF0E3392` in both themes).
//
// Finding D — the recurring "brandBlue-as-fill needs onPrimary, not a
// hardcoded white" bug, present in `AchievementFilterChip`'s selected label,
// `_RoundStepButton`/`_SaveBar` in `PointConfigScreen`,
// `InviteTutorScreen`/`TutorPinResetScreen`'s send-button spinners, and
// `EmailVerificationConfirmPanel`'s "Open Email" button + star badge — all
// measured ~2.52:1 in dark. Fixed by reading
// `Theme.of(context).colorScheme.onPrimary`, the SAME dynamically-computed
// contrast-safe ink `FilledButton`'s own default style already uses for
// this exact accent colour.
//
// Finding E — `AchievementFilterChip`'s UNSELECTED fill was a hardcoded
// `Colors.white` under `inkSlate` text (documented "text on white cards",
// lightens in dark) — white-on-white, ~1:1. Fixed by repointing the fill at
// `brandCreamCard`.
//
// Finding F — two custom SnackBars (`SignInScreen`'s error toast,
// `InviteTutorScreen`'s confirmation toast) set only `backgroundColor` to a
// CONTRAST-role token (`brandWarningDeep` / `statusSuccessSnackbar`, both
// lighten in dark), leaving `SnackBarThemeData.contentTextStyle` (near-white
// in dark) untouched — measured 1.36:1 / 1.55:1. Fixed with pinned-deep
// `signInErrorSnackbarBg` / `inviteSentSnackbarBg` (the latter's call site
// also now sets its content text to a fixed white).
//
// Finding G — `EmailVerificationConfirmPanel`'s "Send Again" pill painted
// `brandInk` (lightens in dark) on a FIXED peach literal — near-white-on-
// peach, ~1:1. Fixed with the new `_sendAgainPeachInk` file-local constant.
//
// Finding H — `AccountPickerScreen`'s "Local Account" pill was a hardcoded
// `Color(0xFFE8EBF0)` under `brandInkMuted` text (lightens in dark) —
// measured 2.16:1. Fixed by repointing at the EXISTING
// `gamifPointConfigChipUnselectedBg` token (byte-identical light value).
//
// Finding I — `AccountPickerScreen`'s "needs re-sign-in" avatar icon painted
// `chartRed` (lightens in dark, a chart-on-card role) on a FIXED pink
// literal — measured 2.00:1 (light mode already only marginal at 4.51:1).
// Fixed with `accountPickerAlertBadgeIcon` (pinned to the exact old chartRed
// light literal).
//
// Finding J — `SacredTimeLockOverlay`'s Yom Tov full-screen background
// painted `accentPurpleDeep` (lightens in dark, an ink-on-card role) as a
// hero fill under hardcoded white greeting text — measured 1.97:1. Fixed
// with `sacredTimeLockYomTovBg` (pinned to the exact old accentPurpleDeep
// light literal), matching the OTHER three sacred-time lock backgrounds,
// which already stay deep in both themes.
@Tags(['core_widgets', 'gamification', 'tutoring', 'sacred_time', 'account'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart'
    show RewardTier;
import 'package:learning_tracker/features/gamification/presentation/widgets/progress_summary_card.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_style.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/track_filter_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

void _noop() {}

void main() {
  group('Finding A — bronze achievement badge icon glyph', () {
    test(
      'RED DEMO: the old raw Colors.white literal fails on the '
      'lightened bronze icon-accent surface in dark mode (measured 2.18:1)',
      () {
        const dark = AppPalette.dark;
        final ratio = _contrast(Colors.white, dark.gamifTierBronzeIconAccent);
        expect(ratio, lessThan(3.0));
      },
    );

    test('gamifTierBronzeIconFg clears WCAG 3:1 (graphical icon) on the '
        'lightened bronze icon-accent surface in dark mode', () {
      const dark = AppPalette.dark;
      final ratio = _contrast(
        dark.gamifTierBronzeIconFg,
        dark.gamifTierBronzeIconAccent,
      );
      expect(ratio, greaterThanOrEqualTo(3.0));
    });

    test('light mode is unchanged — gamifTierBronzeIconFg stays pure white, '
        'same as the old literal', () {
      const light = AppPalette.light;
      expect(light.gamifTierBronzeIconFg, const Color(0xFFFFFFFF));
      expect(
        _contrast(light.gamifTierBronzeIconFg, light.gamifTierBronzeIconAccent),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('TierStyle.forTier(bronze) resolves gamifTierBronzeIconFg for iconFg '
        'in both themes', () {
      final darkStyle = TierStyle.forTier(
        AppPalette.dark,
        RewardTier.bronze,
        false,
      );
      expect(darkStyle.iconFg, AppPalette.dark.gamifTierBronzeIconFg);
      expect(darkStyle.iconFg, isNot(Colors.white));

      final lightStyle = TierStyle.forTier(
        AppPalette.light,
        RewardTier.bronze,
        false,
      );
      expect(lightStyle.iconFg, const Color(0xFFFFFFFF));
    });
  });

  group('Finding B — ProgressSummaryCard hero fill + sparkle badge', () {
    test('RED DEMO: the old raw brandBlue fill fails white text in dark mode '
        '(measured 2.52:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(Colors.white, dark.brandBlue), lessThan(4.5));
    });

    test('gamifProgressSummaryFill clears WCAG 4.5:1 with white text in '
        'dark mode', () {
      const dark = AppPalette.dark;
      expect(
        _contrast(Colors.white, dark.gamifProgressSummaryFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — gamifProgressSummaryFill keeps the exact '
        'pre-fix brandBlue-light hex', () {
      const light = AppPalette.light;
      expect(light.gamifProgressSummaryFill, light.brandBlue);
      expect(light.gamifProgressSummaryFill, const Color(0xFF1442B8));
    });

    test('RED DEMO: the old raw statusErrorCardText fill fails white text in '
        'dark mode (measured 2.71:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(Colors.white, dark.statusErrorCardText), lessThan(3.0));
    });

    test('gamifProgressSummaryBadgeFill clears WCAG 3:1 with white icon in '
        'dark mode', () {
      const dark = AppPalette.dark;
      expect(
        _contrast(Colors.white, dark.gamifProgressSummaryBadgeFill),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('light mode is unchanged — gamifProgressSummaryBadgeFill keeps the '
        'exact pre-fix statusErrorCardText-light hex', () {
      const light = AppPalette.light;
      expect(light.gamifProgressSummaryBadgeFill, light.statusErrorCardText);
    });

    testWidgets(
      'the real card reads the pinned-deep fill tokens (not brandBlue / '
      'statusErrorCardText) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            locale: const Locale('en'),
            theme: AppTheme.darkTheme(),
            child: Localizations(
              locale: const Locale('en'),
              delegates: AppLocalizations.localizationsDelegates,
              child: Builder(
                builder: (context) => Directionality(
                  textDirection: TextDirection.ltr,
                  child: Material(
                    child: ProgressSummaryCard(
                      l10n: AppLocalizations.of(context)!,
                      unlocked: 3,
                      total: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final outerContainer = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = outerContainer.decoration as BoxDecoration;
        expect(decoration.color, AppPalette.dark.gamifProgressSummaryFill);
        expect(decoration.color, isNot(AppPalette.dark.brandBlue));
      },
    );
  });

  group('Finding C — brandBlueDeep misused as a FIXED button/pill FILL', () {
    test('RED DEMO: the old raw brandBlueDeep fill fails white content in '
        'dark mode (measured ~1.63:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(Colors.white, dark.brandBlueDeep), lessThan(4.5));
    });

    test('chazaraSelectedGradientStart (the reused fix token) clears WCAG '
        '4.5:1 with white content in dark mode, and equals the exact old '
        'brandBlueDeep-light literal in both themes', () {
      const dark = AppPalette.dark;
      const light = AppPalette.light;
      expect(
        _contrast(Colors.white, dark.chazaraSelectedGradientStart),
        greaterThanOrEqualTo(4.5),
      );
      expect(light.chazaraSelectedGradientStart, light.brandBlueDeep);
      expect(dark.chazaraSelectedGradientStart, light.brandBlueDeep);
    });

    test('RED DEMO: the same fixed navy pill fails as an ink-on-white-circle '
        'pair too (reward-preview icon on a FIXED white circle)', () {
      const dark = AppPalette.dark;
      expect(
        _contrast(dark.brandBlueDeep, const Color(0xFFFFFFFF)),
        lessThan(4.5),
      );
      expect(
        _contrast(dark.chazaraSelectedGradientStart, const Color(0xFFFFFFFF)),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Finding D — brandBlue-as-fill needs the dynamic onPrimary ink, not a '
      'hardcoded white', () {
    test('RED DEMO: a hardcoded white foreground fails on brandBlue in dark '
        'mode (measured 2.52:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(Colors.white, dark.brandBlue), lessThan(4.5));
    });

    testWidgets(
      'the real FilledButton default style (colorScheme.onPrimary) — the '
      'value every fixed call site now reads instead of Colors.white — '
      'clears WCAG 4.5:1 against brandBlue in dark mode',
      (tester) async {
        late Color onPrimary;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme(),
            home: Builder(
              builder: (context) {
                onPrimary = Theme.of(context).colorScheme.onPrimary;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();

        expect(
          _contrast(onPrimary, AppPalette.dark.brandBlue),
          greaterThanOrEqualTo(4.5),
        );
        expect(onPrimary, isNot(Colors.white));
      },
    );
  });

  group('Finding E — AchievementFilterChip unselected fill', () {
    test(
      'RED DEMO: the old raw Colors.white fill fails inkSlate text in dark '
      'mode (measured ~1:1, "text on white cards" lightens to near-white)',
      () {
        const dark = AppPalette.dark;
        expect(_contrast(dark.inkSlate, Colors.white), lessThan(4.5));
      },
    );

    test('brandCreamCard clears WCAG 4.5:1 with inkSlate text in dark mode, '
        'and stays pure white in light mode (unchanged)', () {
      const dark = AppPalette.dark;
      const light = AppPalette.light;
      expect(
        _contrast(dark.inkSlate, dark.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
      expect(light.brandCreamCard, const Color(0xFFFFFFFF));
    });

    testWidgets(
      'the real unselected chip reads brandCreamCard (not the hardcoded '
      'white literal) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            child: const Scaffold(
              body: AchievementFilterChip(
                label: 'All',
                selected: false,
                onTap: _noop,
              ),
            ),
          ),
        );
        await tester.pump();

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppPalette.dark.brandCreamCard);
        expect(decoration.color, isNot(Colors.white));
      },
    );

    testWidgets('the real unselected chip stays white in light mode (no '
        'regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Scaffold(
            body: AchievementFilterChip(
              label: 'All',
              selected: false,
              onTap: _noop,
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
    });
  });

  group(
    'Finding F — custom SnackBar fills left contentTextStyle untouched',
    () {
      test('RED DEMO: brandWarningDeep lightens in dark mode and fails the '
          "theme's own near-white SnackBar ink (measured 1.36:1)", () {
        const dark = AppPalette.dark;
        expect(_contrast(dark.brandInk, dark.brandWarningDeep), lessThan(4.5));
      });

      test(
        "signInErrorSnackbarBg clears WCAG 4.5:1 against both themes' "
        'SnackBar ink, and keeps the exact old brandWarningDeep-light hex',
        () {
          const dark = AppPalette.dark;
          const light = AppPalette.light;
          expect(
            _contrast(dark.brandInk, dark.signInErrorSnackbarBg),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(const Color(0xFFFFFFFF), light.signInErrorSnackbarBg),
            greaterThanOrEqualTo(4.5),
          );
          expect(light.signInErrorSnackbarBg, light.brandWarningDeep);
        },
      );

      test(
        'RED DEMO: statusSuccessSnackbar lightens in dark mode and fails the '
        "theme's own near-white SnackBar ink (measured 1.55:1)",
        () {
          const dark = AppPalette.dark;
          expect(
            _contrast(dark.brandInk, dark.statusSuccessSnackbar),
            lessThan(4.5),
          );
        },
      );

      test('inviteSentSnackbarBg keeps the exact old statusSuccessSnackbar-'
          'light hex, and a fixed-white SnackBar ink clears 4:1 against it '
          'in both themes (the call site now sets that explicitly) -- a '
          'large improvement on the dark-mode-only 1.55:1, matching the '
          'already-shipped (if marginal) light-mode number in both themes', () {
        const dark = AppPalette.dark;
        const light = AppPalette.light;
        expect(light.inviteSentSnackbarBg, light.statusSuccessSnackbar);
        expect(
          _contrast(const Color(0xFFFFFFFF), dark.inviteSentSnackbarBg),
          greaterThanOrEqualTo(4.0),
        );
        expect(
          _contrast(const Color(0xFFFFFFFF), light.inviteSentSnackbarBg),
          greaterThanOrEqualTo(4.0),
        );
      });
    },
  );

  group('Finding G — "Send Again" pill ink on a fixed peach surface', () {
    // _sendAgainPeach / _sendAgainPeachInk are file-private constants in
    // email_verification_confirm_panel.dart; the fix's exact literals are
    // re-asserted here against brandInk's dark-mode value to pin the maths.
    const sendAgainPeach = Color(0xFFFFE4D6);
    const sendAgainPeachInk = Color(0xFF101828);

    test('RED DEMO: brandInk lightens in dark mode and fails on the fixed '
        'peach pill (measured ~1:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(dark.brandInk, sendAgainPeach), lessThan(4.5));
    });

    test(
      '_sendAgainPeachInk clears WCAG 4.5:1 on the fixed peach pill, and '
      "equals brandInk's OLD light-mode literal so light mode is unchanged",
      () {
        const light = AppPalette.light;
        expect(
          _contrast(sendAgainPeachInk, sendAgainPeach),
          greaterThanOrEqualTo(4.5),
        );
        expect(sendAgainPeachInk, light.brandInk);
      },
    );
  });

  group('Finding H — account-picker "Local Account" pill fill', () {
    const oldLiteral = Color(0xFFE8EBF0);

    test('RED DEMO: the old raw Color(0xFFE8EBF0) fill fails brandInkMuted '
        'text in dark mode (measured ~2.16:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(dark.brandInkMuted, oldLiteral), lessThan(4.5));
    });

    test('gamifPointConfigChipUnselectedBg clears WCAG 4.5:1 with '
        'brandInkMuted text in dark mode, and keeps the exact old literal in '
        'light mode', () {
      const dark = AppPalette.dark;
      const light = AppPalette.light;
      expect(
        _contrast(dark.brandInkMuted, dark.gamifPointConfigChipUnselectedBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(light.gamifPointConfigChipUnselectedBg, oldLiteral);
    });
  });

  group('Finding I — account-picker "needs re-sign-in" avatar icon', () {
    const fixedPink = Color(0xFFF8DDE2);

    test('RED DEMO: chartRed lightens in dark mode and drops below 3:1 on the '
        'fixed pink avatar background (measured ~2.00:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(dark.chartRed, fixedPink), lessThan(3.0));
    });

    test('accountPickerAlertBadgeIcon keeps the exact old chartRed-light '
        'literal, holding dark mode to the same (already-marginal) number as '
        'light mode instead of collapsing further', () {
      const light = AppPalette.light;
      const dark = AppPalette.dark;
      expect(light.accountPickerAlertBadgeIcon, light.chartRed);
      expect(
        _contrast(dark.accountPickerAlertBadgeIcon, fixedPink),
        _contrast(light.chartRed, fixedPink),
      );
    });
  });

  group('Finding J — sacred-time Yom Tov lock-overlay background', () {
    test('RED DEMO: accentPurpleDeep lightens in dark mode and fails white '
        'greeting text (measured 1.97:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(Colors.white, dark.accentPurpleDeep), lessThan(3.0));
    });

    test('sacredTimeLockYomTovBg clears WCAG 4.5:1 with white greeting text '
        'in dark mode (comfortably above the 3:1 large-text floor)', () {
      const dark = AppPalette.dark;
      expect(
        _contrast(Colors.white, dark.sacredTimeLockYomTovBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode is unchanged — sacredTimeLockYomTovBg keeps the exact '
        'pre-fix accentPurpleDeep-light hex', () {
      const light = AppPalette.light;
      expect(light.sacredTimeLockYomTovBg, light.accentPurpleDeep);
    });

    test(
      'sacredTimeLockYomTovBg does not lighten between themes (dark == '
      'light, unlike the pre-fix accentPurpleDeep) — matching the OTHER '
      'three sacred-time lock backgrounds, which also stay a deep, '
      'high-contrast-with-white fill in dark mode rather than washing out',
      () {
        const dark = AppPalette.dark;
        const light = AppPalette.light;
        expect(dark.sacredTimeLockYomTovBg, light.sacredTimeLockYomTovBg);

        for (final ratio in [
          _contrast(Colors.white, dark.sacredTimeLockShabbosBg),
          _contrast(Colors.white, dark.sacredTimeLockShabbosYomTovBg),
          _contrast(Colors.white, dark.sacredTimeLockYomKippurBg),
        ]) {
          expect(ratio, greaterThanOrEqualTo(4.5));
        }
      },
    );
  });
}
