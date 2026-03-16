import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/earned_rewards_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_progress_widget.dart';

RewardModel _makeReward({
  int id = 1,
  String title = 'Bronze',
  String description = 'First reward',
  int pointsThreshold = 50,
  bool isRevealed = false,
  bool isEarned = false,
  DateTime? earnedAt,
}) => RewardModel(
  id: id,
  title: title,
  description: description,
  pointsThreshold: pointsThreshold,
  isRevealed: isRevealed,
  isEarned: isEarned,
  earnedAt: earnedAt,
  createdAt: DateTime(2026),
);

void main() {
  group('RewardProgressWidget', () {
    testWidgets('displays correct fill percentage toward next reward', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nextRewardProvider.overrideWith(
              (_) async => _makeReward(title: 'Bronze', pointsThreshold: 100),
            ),
            rewardProgressProvider.overrideWith((_) async => 0.75),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RewardProgressWidget(userMode: UserMode.adult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('75% complete'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('child mode shows "Mystery Reward!" instead of title', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nextRewardProvider.overrideWith(
              (_) async => _makeReward(title: 'Bronze', pointsThreshold: 100),
            ),
            rewardProgressProvider.overrideWith((_) async => 0.5),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RewardProgressWidget(userMode: UserMode.child),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mystery Reward!'), findsOneWidget);
      expect(find.text('Bronze'), findsNothing);
      expect(find.text('50% complete'), findsOneWidget);
    });

    testWidgets('adult mode shows reward title immediately', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nextRewardProvider.overrideWith(
              (_) async =>
                  _makeReward(title: 'Silver Star', pointsThreshold: 200),
            ),
            rewardProgressProvider.overrideWith((_) async => 0.3),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RewardProgressWidget(userMode: UserMode.adult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Silver Star'), findsOneWidget);
      expect(find.text('30% complete'), findsOneWidget);
    });

    testWidgets('hidden when no rewards configured', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nextRewardProvider.overrideWith((_) async => null),
            rewardProgressProvider.overrideWith((_) async => 0.0),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RewardProgressWidget(userMode: UserMode.child),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('EarnedRewardsWidget', () {
    testWidgets('displays all previously earned rewards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            earnedRewardsProvider.overrideWith(
              (_) async => [
                _makeReward(
                  id: 1,
                  title: 'Bronze',
                  isEarned: true,
                  isRevealed: true,
                ),
                _makeReward(
                  id: 2,
                  title: 'Silver',
                  isEarned: true,
                  isRevealed: true,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EarnedRewardsWidget(userMode: UserMode.adult)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget);
    });

    testWidgets('child mode shows "Mystery Reward!" for unrevealed', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            earnedRewardsProvider.overrideWith(
              (_) async => [
                _makeReward(
                  id: 1,
                  title: 'Bronze',
                  isEarned: true,
                  isRevealed: true,
                ),
                _makeReward(
                  id: 2,
                  title: 'Silver',
                  isEarned: true,
                  isRevealed: false,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EarnedRewardsWidget(userMode: UserMode.child)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('Mystery Reward!'), findsOneWidget);
      expect(find.text('Silver'), findsNothing);
    });

    testWidgets('adult mode shows reward title even if not revealed', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            earnedRewardsProvider.overrideWith(
              (_) async => [
                _makeReward(
                  id: 1,
                  title: 'Bronze',
                  isEarned: true,
                  isRevealed: false,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EarnedRewardsWidget(userMode: UserMode.adult)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Adult mode ignores isRevealed — always shows title
      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('Mystery Reward!'), findsNothing);
    });

    testWidgets('empty state shown when no rewards earned', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [earnedRewardsProvider.overrideWith((_) async => [])],
          child: const MaterialApp(
            home: Scaffold(body: EarnedRewardsWidget(userMode: UserMode.child)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No rewards earned yet. Keep learning!'),
        findsOneWidget,
      );
    });
  });
}
