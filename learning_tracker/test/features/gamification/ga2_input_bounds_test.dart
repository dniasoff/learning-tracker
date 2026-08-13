@Tags(['gamification', 'ga2'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader, PointsLifetimeEarnedReader {
  @override
  Future<int> getBalance() async => 0;

  @override
  Future<int> getLifetimeEarned() async => 0;
}

ProviderContainer _container() {
  final service = RewardMilestoneService(
    balanceReader: _Balance(),
    lifetimeEarnedReader: _Balance(),
    profileId: '01J00000000000000000000006',
  );
  return ProviderContainer(
    overrides: [rewardMilestoneServiceProvider.overrideWithValue(service)],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('name length 50 is accepted and 51 is rejected', () async {
    final container = _container();
    addTearDown(container.dispose);
    final notifier = container.read(rewardConfigControllerProvider.notifier);
    notifier.setName('A' * 50);
    notifier.setPointsText('100');
    expect(await notifier.saveReward(), isA<RewardSaved>());

    notifier.setName('B' * 51);
    notifier.setPointsText('100');
    expect(await notifier.saveReward(), isA<RewardSaveInvalidInput>());
  });

  test('point cost 99999 is accepted and 100000 is rejected', () async {
    final container = _container();
    addTearDown(container.dispose);
    final notifier = container.read(rewardConfigControllerProvider.notifier);
    notifier.setName('Prize');
    notifier.setPointsText('99999');
    expect(await notifier.saveReward(), isA<RewardSaved>());

    notifier.setName('Too expensive');
    notifier.setPointsText('100000');
    expect(await notifier.saveReward(), isA<RewardSaveInvalidInput>());
  });
}
