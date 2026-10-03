// DNI-480: `unlockedAchievementIdsProvider` is the single read of the
// latched `unlocked_achievement_ids` record (AD-27 / AD-50).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_settings_repository.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/data/repositories/unlocked_achievements_source.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'unlocked-source-user';
const _profileId = '01J0000000000000000000U480';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreRewardSettingsRepository repo;

  ProviderContainer container({bool nullRepo = false}) {
    final c = ProviderContainer.test(
      overrides: [
        firestoreRewardSettingsRepositoryProvider.overrideWith(
          (ref) async => nullRepo ? null : repo,
        ),
      ],
    );
    return c;
  }

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    repo = FirestoreRewardSettingsRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  });

  test('is empty when nothing has been latched', () async {
    final c = container();
    expect(await c.read(unlockedAchievementIdsProvider.future), isEmpty);
  });

  test('reads the latched ids', () async {
    await repo.latchUnlockedAchievementIds({'bronze', 'silver'});
    final c = container();
    expect(await c.read(unlockedAchievementIdsProvider.future), {
      'bronze',
      'silver',
    });
  });

  test('a latch after the first read re-reads the provider', () async {
    await repo.latchUnlockedAchievementIds({'bronze'});
    final c = container();
    c.listen(unlockedAchievementIdsProvider, (_, _) {});
    expect(await c.read(unlockedAchievementIdsProvider.future), {'bronze'});

    await repo.latchUnlockedAchievementIds({'gold'});
    await pumpEventQueue();
    expect(await c.read(unlockedAchievementIdsProvider.future), {
      'bronze',
      'gold',
    });
  });

  test(
    'without a settings repository it errors, never "nothing unlocked"',
    () async {
      final c = container(nullRepo: true);
      await expectLater(
        c.read(unlockedAchievementIdsProvider.future),
        throwsA(isA<PointsNotReadyException>()),
      );
    },
  );

  test('a malformed stored field is an error', () async {
    await firestore
        .doc(
          'users/$_uid/learner_profiles/$_profileId/preferences/'
          'gamification_settings',
        )
        .set({'unlocked_achievement_ids': 'bronze'});
    final c = container();
    await expectLater(
      c.read(unlockedAchievementIdsProvider.future),
      throwsA(isA<FormatException>()),
    );
  });
}
