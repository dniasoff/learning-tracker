import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader {
  _Balance(this.value);
  final int value;

  @override
  Future<int> getBalance() async => value;
}

RewardMilestoneService _service() => RewardMilestoneService(
  balanceReader: _Balance(100),
  profileId: '01J00000000000000000000002',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'starts empty and upserts a global reward using a string profile id',
    () async {
      final service = _service();
      expect(await service.getMilestones(), isEmpty);

      await service.upsertMilestone(
        title: '  Movie night  ',
        thresholdPoints: 100,
        milestoneId: 'reward-1',
      );
      final rewards = await service.getMilestones();
      expect(rewards.single.title, 'Movie night');
      expect(rewards.single.profileId, '01J00000000000000000000002');
      expect(rewards.single.pointsCost, 100);
    },
  );

  test('sorts rewards by cost and permits duplicate prices', () async {
    final service = _service();
    await service.upsertMilestone(title: 'Expensive', thresholdPoints: 500);
    await service.upsertMilestone(title: 'Cheap', thresholdPoints: 50);
    await service.upsertMilestone(title: 'Also cheap', thresholdPoints: 50);

    final rewards = await service.getMilestones();
    expect(rewards.map((r) => r.title), ['Cheap', 'Also cheap', 'Expensive']);
  });

  test('editing and removing a reward do not create duplicate rows', () async {
    final service = _service();
    await service.upsertMilestone(
      title: 'Original',
      thresholdPoints: 20,
      milestoneId: 'reward-1',
    );
    await service.upsertMilestone(
      title: 'Updated',
      thresholdPoints: 30,
      milestoneId: 'reward-1',
    );
    expect((await service.getAllMilestones()).single.title, 'Updated');

    await service.removeMilestone('reward-1');
    expect(await service.getAllMilestones(), isEmpty);
  });

  test(
    'classifies stock titles and custom titles independently of track ids',
    () {
      expect(RewardTier.classify('Bronze Star'), RewardTier.bronze);
      expect(RewardTier.classify('Parent prize'), RewardTier.custom);
    },
  );
}
