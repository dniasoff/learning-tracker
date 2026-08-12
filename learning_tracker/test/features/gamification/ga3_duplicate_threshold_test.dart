@Tags(['gamification', 'ga3'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader {
  @override
  Future<int> getBalance() async => 0;
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    rewardMilestoneServiceProvider.overrideWithValue(
      RewardMilestoneService(
        balanceReader: _Balance(),
        profileId: '01J00000000000000000000007',
      ),
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('distinct rewards may share the same point cost', () async {
    final container = _container();
    addTearDown(container.dispose);
    final notifier = container.read(rewardConfigControllerProvider.notifier);

    for (final title in ['Ice Cream', 'Movie Night', 'Board Game']) {
      notifier.setName(title);
      notifier.setPointsText('500');
      expect(await notifier.saveReward(), isA<RewardSaved>());
    }

    final rewards = await container
        .read(rewardMilestoneServiceProvider)
        .getMilestones();
    expect(rewards, hasLength(3));
    expect(rewards.every((reward) => reward.thresholdPoints == 500), isTrue);
  });
}
