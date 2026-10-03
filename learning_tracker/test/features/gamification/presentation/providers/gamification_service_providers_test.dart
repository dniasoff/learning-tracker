@Tags(['gamification'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader, PointsLifetimeEarnedReader {
  @override
  Future<int> getBalance() async => 0;

  @override
  Future<int> getLifetimeEarned() async => 0;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reward provider scopes the service to the active profile ULID', () {
    final container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWithValue('01J0000000000000000000000B'),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(rewardMilestoneServiceProvider).profileId,
      '01J0000000000000000000000B',
    );
  });

  test('lifetime-earned reader throws while Firestore is not ready', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(rewardMilestoneServiceProvider);
    expect(service.getGlobalLifetimeEarnedForRewards, throwsStateError);
  });

  test('service providers can be overridden directly', () {
    final service = RewardMilestoneService(
      balanceReader: _Balance(),
      lifetimeEarnedReader: _Balance(),
      profileId: '01J0000000000000000000000D',
    );
    final container = ProviderContainer(
      overrides: [rewardMilestoneServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    expect(
      identical(container.read(rewardMilestoneServiceProvider), service),
      isTrue,
    );
  });
}
