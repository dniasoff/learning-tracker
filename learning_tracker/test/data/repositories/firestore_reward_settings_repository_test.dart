import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_settings_repository.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/firestore_fixtures.dart';

const _uid = 'owner-uid';
const _profileId = '01J0000000000000000000000E';

class _Balance implements PointsBalanceReader, PointsLifetimeEarnedReader {
  @override
  Future<int> getBalance() async => 0;

  @override
  Future<int> getLifetimeEarned() async => 0;
}

RewardMilestoneService _service() => RewardMilestoneService(
  balanceReader: _Balance(),
  lifetimeEarnedReader: _Balance(),
  profileId: _profileId,
);

ProviderContainer _container({
  required FirestoreRewardSettingsRepository repository,
  required RewardMilestoneService service,
}) => ProviderContainer(
  overrides: [
    rewardMilestoneServiceProvider.overrideWithValue(service),
    firestoreRewardSettingsRepositoryProvider.overrideWith(
      (ref) async => repository,
    ),
  ],
);

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreRewardSettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    await seedProfile(firestore, uid: _uid, profileId: _profileId);
    repository = FirestoreRewardSettingsRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  });

  test(
    'saving a reward persists the reward snapshot at the tutor path',
    () async {
      final container = _container(repository: repository, service: _service());
      addTearDown(container.dispose);
      final controller = container.read(
        rewardConfigControllerProvider.notifier,
      );
      controller.setName('Library trip');
      controller.setPointsText('125');

      expect(await controller.saveReward(), isA<RewardSaved>());

      final snapshot = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('preferences')
          .doc('gamification_settings')
          .get();
      final data = snapshot.data()!;
      final rewardSettings = data['reward_settings'] as Map<String, dynamic>;
      final milestones = (rewardSettings['milestones'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(milestones.single['title'], 'Library trip');
      expect(milestones.single['threshold_points'], 125);
    },
  );

  test(
    'owner reads reward settings written at the simulated tutor path',
    () async {
      final timestamp = DateTime.utc(2026, 1, 2).toIso8601String();
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('preferences')
          .doc('gamification_settings')
          .set({
            'reward_settings': {
              'updated_at': timestamp,
              'milestones': [
                {
                  'id': 'tutor-reward',
                  'profile_id': _profileId,
                  'title': 'Tutor prize',
                  'threshold_points': 240,
                  'is_enabled': true,
                  'icon_index': 2,
                  'created_at': timestamp,
                  'updated_at': timestamp,
                },
              ],
              'unlocks': <Map<String, dynamic>>[],
            },
            'synced_at': timestamp,
          });

      final service = _service();
      final container = _container(repository: repository, service: service);
      addTearDown(container.dispose);

      final rewards = await container
          .read(rewardConfigControllerProvider.notifier)
          .milestonesForCurrentLadder();

      expect(rewards.single.id, 'tutor-reward');
      expect(rewards.single.title, 'Tutor prize');
      expect(rewards.single.thresholdPoints, 240);
    },
  );
}
