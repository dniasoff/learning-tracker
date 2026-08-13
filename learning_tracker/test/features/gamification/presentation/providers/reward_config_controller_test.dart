@Tags(['gamification', 'reward_config_controller'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader, PointsLifetimeEarnedReader {
  @override
  Future<int> getBalance() async => 0;

  @override
  Future<int> getLifetimeEarned() async => 0;
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    rewardMilestoneServiceProvider.overrideWithValue(
      RewardMilestoneService(
        balanceReader: _Balance(),
        lifetimeEarnedReader: _Balance(),
        profileId: '01J0000000000000000000000E',
      ),
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('initial form and bootstrap are global-only', () async {
    final container = _container();
    addTearDown(container.dispose);
    final notifier = container.read(rewardConfigControllerProvider.notifier);
    expect(container.read(rewardConfigControllerProvider), const RewardForm());
    await notifier.bootstrap();
    expect(container.read(rewardConfigControllerProvider).canSave, isFalse);
  });

  test('save, edit, toggle, delete, and list rewards', () async {
    final container = _container();
    addTearDown(container.dispose);
    final notifier = container.read(rewardConfigControllerProvider.notifier);
    notifier.setName('  Toy  ');
    notifier.setPointsText('25');
    expect(await notifier.saveReward(), isA<RewardSaved>());
    var rewards = await notifier.milestonesForCurrentLadder();
    expect(rewards.single.title, 'Toy');

    notifier.applyMilestoneToForm(rewards.single);
    notifier.setName('Updated Toy');
    expect(await notifier.saveReward(), isA<RewardSaved>());
    rewards = await notifier.milestonesForCurrentLadder();
    expect(rewards.single.title, 'Updated Toy');

    await notifier.toggleEnabled(rewards.single);
    rewards = await notifier.milestonesForCurrentLadder();
    expect(rewards.single.isEnabled, isFalse);
    await notifier.deleteMilestone(rewards.single);
    expect(await notifier.milestonesForCurrentLadder(), isEmpty);
  });

  test('validation rejects empty, zero, and over-limit values', () async {
    final container = _container();
    addTearDown(container.dispose);
    final notifier = container.read(rewardConfigControllerProvider.notifier);
    for (final values in [('', '1'), ('Name', '0'), ('Name', '100000')]) {
      notifier.setName(values.$1);
      notifier.setPointsText(values.$2);
      expect(await notifier.saveReward(), isA<RewardSaveInvalidInput>());
    }
  });
}
