// DNI-480 (Story 1.18): achievement surfaces read the latched
// `unlocked_achievement_ids` record live, and never a fabricated "nothing
// unlocked" when there is no active learner.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_settings_repository.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/data/repositories/unlocked_achievements_source.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'unlocked-achievements-user';
const _profileId = '01J0000000000000000000A480';

void main() {
  test('reads the latch record and follows a later latch', () async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final settings = FirestoreRewardSettingsRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    await settings.latchUnlockedAchievementIds({'bronze'});
    final container = ProviderContainer.test(
      overrides: [
        firestoreRewardSettingsRepositoryProvider.overrideWith(
          (ref) async => settings,
        ),
      ],
    );
    container.listen(unlockedAchievementIdsProvider, (_, _) {});

    expect(await container.read(unlockedAchievementIdsProvider.future), {
      'bronze',
    });

    await settings.latchUnlockedAchievementIds({'silver'});
    await pumpEventQueue();
    expect(await container.read(unlockedAchievementIdsProvider.future), {
      'bronze',
      'silver',
    });
  });

  test('no settings repository is not ready, never an empty set', () async {
    final container = ProviderContainer.test(
      overrides: [
        firestoreRewardSettingsRepositoryProvider.overrideWith(
          (ref) async => null,
        ),
      ],
    );

    await expectLater(
      container.read(unlockedAchievementIdsProvider.future),
      throwsA(isA<PointsNotReadyException>()),
    );
  });
}
