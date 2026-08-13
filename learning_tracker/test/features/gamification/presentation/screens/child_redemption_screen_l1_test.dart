@Tags(['needs_flutter', 'gamification', 'child_redemption'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';

import '../../../../helpers/pump_app.dart';

RewardMilestone _reward(String title, int cost) => RewardMilestone(
  id: title.toLowerCase().replaceAll(' ', '-'),
  profileId: '01J00000000000000000000010',
  title: title,
  thresholdPoints: cost,
  isEnabled: true,
  iconIndex: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester tester, {
  required int balance,
  required List<RewardMilestone> rewards,
  Exception? balanceError,
  bool balanceLoading = false,
}) async {
  await tester.pumpWidget(
    pumpApp(
      retry: (_, __) => null,
      overrides: [
        childRedemptionBalanceProvider.overrideWith((ref) {
          if (balanceLoading) return Completer<int>().future;
          if (balanceError != null) {
            return Future<int>.error(balanceError, StackTrace.empty);
          }
          return Future.value(balance);
        }),
        childRedemptionRewardsProvider.overrideWith((ref) async => rewards),
      ],
      child: const ChildRedemptionScreen(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'renders balance, enabled reward, and empty state from provider data',
    (tester) async {
      await _pump(tester, balance: 100, rewards: [_reward('Ice Cream', 50)]);
      expect(find.text('100 Points'), findsOneWidget);
      expect(find.text('Ice Cream'), findsOneWidget);
      expect(find.text('Redeem'), findsOneWidget);

      // ProviderScope keeps its container when pumpWidget updates the same
      // scope, so unmount it before installing the empty-state overrides.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pump(tester, balance: 0, rewards: const []);
      expect(find.textContaining('No prizes configured yet.'), findsOneWidget);
    },
  );

  testWidgets('unaffordable rewards are disabled', (tester) async {
    await _pump(tester, balance: 10, rewards: [_reward('Movie', 50)]);
    expect(find.text('Not enough points'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'balance error shows an error affordance instead of a fabricated zero',
    (tester) async {
      await _pump(
        tester,
        balance: 0,
        rewards: [_reward('Movie', 50)],
        balanceError: Exception('balance unavailable'),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('0 Points'), findsNothing);
      expect(find.text('Not enough points'), findsNothing);
    },
  );

  testWidgets('balance loading stays loading instead of showing zero', (
    tester,
  ) async {
    await _pump(
      tester,
      balance: 0,
      rewards: [_reward('Movie', 50)],
      balanceLoading: true,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('0 Points'), findsNothing);
    expect(find.text('Not enough points'), findsNothing);
  });
}
