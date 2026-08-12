@Tags(['gamification', 'staleness'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader {
  @override
  Future<int> getBalance() async => 0;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'child reward list refreshes when the controller invalidates it',
    () async {
      final service = RewardMilestoneService(
        balanceReader: _Balance(),
        profileId: '01J0000000000000000000000F',
      );
      final container = ProviderContainer(
        overrides: [rewardMilestoneServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final values = <List<RewardMilestone>>[];
      final subscription = container.listen(
        childRedemptionRewardsProvider,
        (_, next) => next.whenData(values.add),
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      expect(
        await container.read(childRedemptionRewardsProvider.future),
        isEmpty,
      );

      final notifier = container.read(rewardConfigControllerProvider.notifier);
      notifier.setName('Test Prize');
      notifier.setPointsText('50');
      expect(await notifier.saveReward(), isA<RewardSaved>());
      await pumpEventQueue();
      expect(values.last.single.title, 'Test Prize');
    },
  );
}
