/// GA-2 regression test — Input fields must have sane max caps.
///
/// Root cause: reward name (no maxLength) and reward cost (no max value cap)
/// accept arbitrarily large inputs. Validators only check amount>0 / non-empty.
///
/// Fix: reject reward names > 50 chars (RewardSaveInvalidInput) and reward
/// cost > 99_999 points (RewardSaveInvalidInput) in RewardConfigController.saveReward().
///
/// RED → GREEN: tests fail before the cap constants are added to the controller,
/// and pass after.
@Tags(['gamification', 'ga2'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/drift_memory.dart';
import '../../helpers/test_database.dart';

ProviderContainer _makeContainer({int profileId = 1}) {
  final db = inMemoryDb();
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(profileId),
      syncWriteFacadeProvider.overrideWithValue(null),
      achievementsOverviewProvider.overrideWith(
        (ref) async => const AchievementsOverview(
          rows: [],
          unlockedCount: 0,
          totalMilestones: 0,
          trackFilterOptions: [],
        ),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GA-2: reward name max length cap', () {
    test('name of exactly 50 chars is accepted', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      final name50 = 'A' * 50;
      c.read(rewardConfigControllerProvider.notifier).setName(name50);
      c.read(rewardConfigControllerProvider.notifier).setPointsText('100');

      final result = await c
          .read(rewardConfigControllerProvider.notifier)
          .saveReward();
      expect(
        result,
        isA<RewardSaved>(),
        reason: '50-char name should be accepted',
      );
    });

    test('name longer than 50 chars → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      final name51 = 'A' * 51;
      c.read(rewardConfigControllerProvider.notifier).setName(name51);
      c.read(rewardConfigControllerProvider.notifier).setPointsText('100');

      final result = await c
          .read(rewardConfigControllerProvider.notifier)
          .saveReward();
      expect(
        result,
        isA<RewardSaveInvalidInput>(),
        reason: '51-char name should be rejected with InvalidInput',
      );
    });

    test('name of 100 chars → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final name100 = 'B' * 100;
      c.read(rewardConfigControllerProvider.notifier).setName(name100);
      c.read(rewardConfigControllerProvider.notifier).setPointsText('100');

      final result = await c
          .read(rewardConfigControllerProvider.notifier)
          .saveReward();
      expect(result, isA<RewardSaveInvalidInput>());
    });
  });

  group('GA-2: reward cost max value cap', () {
    test('cost of exactly 99999 is accepted', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      c.read(rewardConfigControllerProvider.notifier).setName('Star');
      c.read(rewardConfigControllerProvider.notifier).setPointsText('99999');

      final result = await c
          .read(rewardConfigControllerProvider.notifier)
          .saveReward();
      expect(
        result,
        isA<RewardSaved>(),
        reason: '99999 cost should be accepted',
      );
    });

    test('cost of 100000 → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      c.read(rewardConfigControllerProvider.notifier).setName('Star');
      c.read(rewardConfigControllerProvider.notifier).setPointsText('100000');

      final result = await c
          .read(rewardConfigControllerProvider.notifier)
          .saveReward();
      expect(
        result,
        isA<RewardSaveInvalidInput>(),
        reason: '100000 cost exceeds sane max and should be rejected',
      );
    });

    test('cost of 999999999999 → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      c.read(rewardConfigControllerProvider.notifier).setName('Star');
      c
          .read(rewardConfigControllerProvider.notifier)
          .setPointsText('999999999999');

      final result = await c
          .read(rewardConfigControllerProvider.notifier)
          .saveReward();
      expect(result, isA<RewardSaveInvalidInput>());
    });
  });
}
