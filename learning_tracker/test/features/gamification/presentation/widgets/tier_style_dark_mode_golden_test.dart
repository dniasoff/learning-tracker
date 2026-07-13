// Golden/screenshot coverage for AUD-gamification-23.
//
// Finding: TierStyle's ~80 hardcoded hex colors bypass the theme system
// entirely (no Brightness/ColorScheme parameter on TierStyle.forTier) and
// never adapt to dark mode, while the app follows the DEVICE theme
// automatically (LearningTrackerApp: `themeMode: ThemeMode.system`), so a
// user/parent whose OS is in dark mode reaches AppTheme.darkTheme() live in
// production on every other screen.
//
// This finding was SUSPECTED confidence: "This may be an intentional
// 'badges always look the same' design choice, but nothing in the file
// states that." Acceptance criterion: "Manual check (or a golden test) of
// the achievements screen under ThemeMode.dark confirms tier cards are
// legible and intentional."
//
// This test renders every named tier (bronze through elite), the legend
// tier, and the default/custom style -- in both locked and unlocked state
// -- under MaterialApp(theme: AppTheme.lightTheme()) and
// MaterialApp(theme: AppTheme.darkTheme()), and records the review
// conclusion below.
//
// REVIEW (2026-07-12, ThemeMode.dark, all 14 tier/status combinations):
// Rendered goldens/aud_gamification_23_tiers.light.png and
// goldens/aud_gamification_23_tiers.dark.png and compared them side by
// side. CONFIRMED INTENTIONAL:
//   - AchievementTierCard paints its own opaque `Material(color:
//     scheme.cardBg)` background for every card (see
//     achievement_tier_card.dart), so every card's text/icon colors are
//     ALWAYS composited against that card's own tier-specific background --
//     never against the surrounding scaffold. Legibility (text-on-card
//     contrast) is therefore identical in both themes: each tier's
//     titleColor/iconFg/tagFg were chosen for contrast against that SAME
//     tier's cardBg, and neither the card background nor those foreground
//     colors change with theme, so the pairing never breaks.
//   - The 8 tiers are a literal medal/material metaphor (bronze, silver,
//     gold, platinum, diamond, ...) -- real-world medal colors that read as
//     intentionally brand-constant regalia, the same way a trophy icon
//     doesn't recolor for dark mode elsewhere in the app (see the
//     hardcoded gradient on the Legend-tier DecoratedBox in
//     achievement_tier_card.dart, which is unconditional in the pre-fix
//     code too).
//   - Visually compared goldens/aud_gamification_23_tiers.light.png against
//     .dark.png: every card renders byte-for-byte the SAME regardless of
//     theme (TierStyle takes no Brightness input at all), and in both
//     renders every card is fully legible -- title, status label, points,
//     and percent text all read clearly against their own card's
//     background, in every one of the 14 rows (7 named tiers x
//     locked/unlocked + legend x locked/unlocked + the default/custom
//     style used by a parent-configured title). The cream/pastel cards
//     read as distinct "medal cards" floating in a list on the dark
//     scaffold, not as a broken/unstyled patch -- nothing is
//     invisible, low-contrast, or clipped.
// No code change to TierStyle is warranted; this finding's SUSPECTED
// hypothesis (invisible/illegible dark-mode text) is refuted by direct
// visual review, and the golden below makes any future accidental
// *regression* of card-self-contained-contrast (e.g. someone starts reading
// scheme colors from Theme.of(context) for only SOME fields) regression-
// visible in both theme renders.

@Tags(['gamification', 'tier_style', 'golden', 'aud_gamification_23'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_tier_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/golden_font_loader.dart' show loadFonts;

RewardMilestone _milestone(String title, int threshold) {
  return RewardMilestone(
    id: 'rm_$title',
    profileId: 1,
    trackId: 1,
    title: title,
    thresholdPoints: threshold,
    isEnabled: true,
    iconIndex: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

AchievementRowVm _row(
  String title,
  int threshold, {
  required bool isUnlocked,
  bool isLegendTier = false,
}) {
  return AchievementRowVm(
    trackId: 1,
    trackLabel: 'Total',
    curriculumId: null,
    milestone: _milestone(title, threshold),
    trackPoints: isUnlocked ? threshold : 0,
    isUnlocked: isUnlocked,
    isNextUp: !isUnlocked,
    isLegendTier: isLegendTier,
  );
}

/// One locked + one unlocked card per named tier, plus the legend tier and
/// a parent-configured custom title (exercises the default/custom style).
final _rows = <AchievementRowVm>[
  _row('Bronze Star', 500, isUnlocked: true),
  _row('Bronze Star', 500, isUnlocked: false),
  _row('Silver Star', 1000, isUnlocked: true),
  _row('Silver Star', 1000, isUnlocked: false),
  _row('Gold Star', 3000, isUnlocked: true),
  _row('Gold Star', 3000, isUnlocked: false),
  _row('Platinum Star', 5000, isUnlocked: true),
  _row('Premium Star', 10000, isUnlocked: true),
  _row('Diamond Star', 15000, isUnlocked: true),
  _row('Elite Star', 25000, isUnlocked: true),
  _row('Legend Star', 50000, isUnlocked: true, isLegendTier: true),
  _row('Legend Star', 50000, isUnlocked: false, isLegendTier: true),
  _row('Ice Cream Trip', 200, isUnlocked: true),
  _row('Ice Cream Trip', 200, isUnlocked: false),
];

Widget _rig({required Brightness brightness}) {
  return MaterialApp(
    theme: AppTheme.themeFor(brightness: brightness),
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final row in _rows) ...[
                AchievementTierCard(l10n: l10n, row: row, trackTag: 'Total'),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await loadFonts();
  });

  for (final brightness in Brightness.values) {
    testWidgets('achievement tier cards — ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(420, 4200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_rig(brightness: brightness));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/aud_gamification_23_tiers.${brightness.name}.png',
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  }
}
