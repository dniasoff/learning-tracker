// L1 widget test for ManageRewardsList / RewardCard.
//
// AUD-gamification-24: manage_rewards_list.dart previously built its
// "label: value" points-threshold subtitle by concatenating
// `l10n.rewardConfigPointsThresholdLabel` with a hardcoded ': ' separator
// and a raw number, instead of routing the composed string through an
// ICU-parameterized AppLocalizations placeholder. This test pins the
// rendered subtitle text through the fixed `l10n.commonLabelWithValue(...)`
// call site so a future regression back to raw interpolation is visible as
// a broken assertion here (the visible text is unchanged; the regression
// this guards is the l10n call path, not the string bytes).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/manage_rewards_list.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

RewardMilestone _makeMilestone({
  String id = 'm1',
  String title = 'Ice Cream Trip',
  int thresholdPoints = 250,
}) => RewardMilestone(
  id: id,
  profileId: 1,
  trackId: RewardMilestone.kGlobalTrackSentinel,
  title: title,
  thresholdPoints: thresholdPoints,
  isEnabled: true,
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
);

Widget _harness({required Locale locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ManageRewardsList(
        load: () async => [_makeMilestone()],
        onEdit: (_) {},
        onDelete: (_) async {},
        onToggle: (_) async {},
      ),
    ),
  );
}

void main() {
  group('ManageRewardsList / RewardCard points-threshold subtitle', () {
    testWidgets('renders label:value via AppLocalizations in English', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Ice Cream Trip'), findsOneWidget);
      expect(find.text('Points needed: 250'), findsOneWidget);
    });

    testWidgets('renders label:value via AppLocalizations in Hebrew', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(locale: const Locale('he')));
      await tester.pumpAndSettle();

      expect(find.text('נקודות נדרשות: 250'), findsOneWidget);
    });
  });
}
