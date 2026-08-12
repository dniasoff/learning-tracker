@Tags(['gamification', 'achievements_overview'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader {
  _Balance(this.value);
  final int value;

  @override
  Future<int> getBalance() async => value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('classifies affordable and unaffordable global rewards', () async {
    final service = RewardMilestoneService(
      balanceReader: _Balance(72),
      profileId: '01J00000000000000000000008',
    );
    await service.upsertMilestone(
      title: 'Small',
      thresholdPoints: 50,
      milestoneId: 'small',
    );
    await service.upsertMilestone(
      title: 'Big',
      thresholdPoints: 502,
      milestoneId: 'big',
    );
    final container = ProviderContainer(
      overrides: [rewardMilestoneServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final overview = await container.read(achievementsOverviewProvider.future);
    expect(overview.unlockedCount, 1);
    expect(overview.totalMilestones, 2);
    final small = overview.rows.firstWhere(
      (row) => row.milestone.id == 'small',
    );
    final big = overview.rows.firstWhere((row) => row.milestone.id == 'big');
    expect(small.isUnlocked, isTrue);
    expect(small.isNextUp, isFalse);
    expect(big.isUnlocked, isFalse);
    expect(big.isNextUp, isTrue);
  });

  test(
    'reading the overview is pure and does not strip stock rewards',
    () async {
      final service = RewardMilestoneService(
        balanceReader: _Balance(0),
        profileId: '01J00000000000000000000009',
      );
      await service.upsertMilestone(
        title: 'Bronze Star',
        thresholdPoints: 500,
        milestoneId: 'stock',
      );
      final container = ProviderContainer(
        overrides: [rewardMilestoneServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      await container.read(achievementsOverviewProvider.future);
      container.invalidate(achievementsOverviewProvider);
      await container.read(achievementsOverviewProvider.future);
      expect((await service.getAllMilestones()).single.id, 'stock');
    },
  );
}
