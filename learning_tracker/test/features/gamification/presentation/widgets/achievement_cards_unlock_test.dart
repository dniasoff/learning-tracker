/// Widget tests for the achievement reward cards' unlocked/locked rendering.
///
/// Regression coverage for P1 reward-unlock bugs (#36 / #37):
///   - #36: An UNLOCKED [AchievementTierCard] (threshold met) shows the
///     "Unlocked!" status, has NO blur/lock overlay (no lock icon), and is
///     NOT labelled "Coming soon!".
///   - #37: [ProgressSummaryCard] renders the unlocked/total fraction (e.g.
///     "1 / 2") it is given.
@Tags(['gamification', 'achievement_cards'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_tier_card.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/locked_achievement_shell.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/progress_summary_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

RewardMilestone _milestone({
  required String id,
  required int threshold,
  String title = 'Small Reward',
}) {
  return RewardMilestone(
    id: id,
    profileId: 1,
    trackId: RewardMilestone.kGlobalTrackSentinel,
    title: title,
    thresholdPoints: threshold,
    isEnabled: true,
    iconIndex: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

AchievementRowVm _row({
  required int threshold,
  required int trackPoints,
  required bool isUnlocked,
  required bool isNextUp,
}) {
  return AchievementRowVm(
    trackId: RewardMilestone.kGlobalTrackSentinel,
    trackLabel: '',
    curriculumId: null,
    milestone: _milestone(id: 'ms-$threshold', threshold: threshold),
    trackPoints: trackPoints,
    isUnlocked: isUnlocked,
    isNextUp: isNextUp,
    isLegendTier: false,
  );
}

Widget _wrap(Widget Function(AppLocalizations l10n) builder) {
  return MaterialApp(
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
        builder: (context) => builder(AppLocalizations.of(context)!),
      ),
    ),
  );
}

void main() {
  group('AchievementTierCard — unlocked (#36)', () {
    testWidgets(
      'threshold met → "Unlocked!", no lock overlay, not "Coming soon!"',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            (l10n) => AchievementTierCard(
              l10n: l10n,
              row: _row(
                threshold: 50,
                trackPoints: 72,
                isUnlocked: true,
                isNextUp: false,
              ),
              trackTag: 'Total',
            ),
          ),
        );

        final l10n = AppLocalizations.of(
          tester.element(find.byType(AchievementTierCard)),
        )!;

        expect(find.text(l10n.achievementsStatusUnlocked), findsOneWidget);
        expect(find.text(l10n.achievementsStatusComingSoon), findsNothing);
        // No blur/lock overlay for an unlocked card.
        expect(find.byType(LockedAchievementShell), findsNothing);
        expect(find.byIcon(Icons.lock_rounded), findsNothing);
        // Progress bar reads 100%.
        expect(
          find.text(l10n.achievementsProgressPercent(100)),
          findsOneWidget,
        );
      },
    );
  });

  group('AchievementTierCard — locked / next-up', () {
    testWidgets('threshold not met → lock overlay + "Coming soon!"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (l10n) => AchievementTierCard(
            l10n: l10n,
            row: _row(
              threshold: 502,
              trackPoints: 72,
              isUnlocked: false,
              isNextUp: true,
            ),
            trackTag: 'Total',
          ),
        ),
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AchievementTierCard)),
      )!;

      expect(find.text(l10n.achievementsStatusComingSoon), findsOneWidget);
      expect(find.text(l10n.achievementsStatusUnlocked), findsNothing);
      // Locked card is wrapped in the blur/lock overlay shell.
      expect(find.byType(LockedAchievementShell), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    });
  });

  group('ProgressSummaryCard — fraction (#37)', () {
    testWidgets('renders "1 / 2" for unlocked=1, total=2', (tester) async {
      await tester.pumpWidget(
        _wrap((l10n) => ProgressSummaryCard(l10n: l10n, unlocked: 1, total: 2)),
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProgressSummaryCard)),
      )!;

      expect(find.text(l10n.achievementsRewardsFraction(1, 2)), findsOneWidget);
    });
  });
}
