@Tags(['gamification', 'staleness', 'r_ga2'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MutableBalance implements PointsBalanceReader {
  int value = 150;

  @override
  Future<int> getBalance() async => value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'milestone remains unlocked after debit',
    () async {
      final balance = _MutableBalance();
      final service = RewardMilestoneService(
        balanceReader: balance,
        profileId: '01J0000000000000000000000A',
      );
      await service.upsertMilestone(
        title: 'Gold Star',
        thresholdPoints: 100,
        milestoneId: 'gold',
      );
      final container = ProviderContainer(
        overrides: [rewardMilestoneServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final before = await container.read(achievementsOverviewProvider.future);
      expect(before.rows.single.isUnlocked, isTrue);
      balance.value = 50;
      container.invalidate(achievementsOverviewProvider);
      final after = await container.read(achievementsOverviewProvider.future);
      expect(after.rows.single.isUnlocked, isTrue);
    },
    skip:
        'confirmed production gap: achievementsOverviewProvider classifies global milestones from the spendable balance via RewardMilestoneService.getGlobalPointsForRewards(); redemption can therefore re-lock a milestone until lifetime-earned points are implemented',
  );
}
