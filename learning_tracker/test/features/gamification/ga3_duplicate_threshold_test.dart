/// GA-3 regression test — Remove duplicate-threshold uniqueness constraint.
///
/// Root cause: saveReward() calls _hasDuplicateThreshold which prevents two
/// rewards from having the same cost (a holdover "ladder" constraint). In the
/// spend-economy model multiple distinct rewards CAN share the same price.
///
/// Fix: remove the _hasDuplicateThreshold check from saveReward() so the parent
/// can offer multiple rewards at the same point cost.
///
/// RED → GREEN: the test below fails (returns RewardSaveDuplicateThreshold)
/// before the check is removed, and passes (returns RewardSaved) after.
@Tags(['gamification', 'ga3'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/drift_memory.dart';
import '../../helpers/test_database.dart';

ProviderContainer _makeContainer({int profileId = 1}) {
  final db = inMemoryDb();
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(profileId),
      syncWriteFacadeProvider.overrideWithValue(null),
      achievementsOverviewProvider.overrideWith(
        (ref) async => const AchievementsOverview(
          rows: [],
          unlockedCount: 0,
          totalMilestones: 0,
          trackFilterOptions: [],
        ),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GA-3: duplicate threshold constraint removed', () {
    test(
      'two distinct rewards at the same point cost both save successfully',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);
        await seedProfileWithIds(
          c.read(userDatabaseProvider),
          accountId: 1,
          profileId: 1,
        );

        // First reward at cost 500
        c.read(rewardConfigControllerProvider.notifier).setName('Ice Cream');
        c.read(rewardConfigControllerProvider.notifier).setPointsText('500');
        final first = await c
            .read(rewardConfigControllerProvider.notifier)
            .saveReward();
        expect(
          first,
          isA<RewardSaved>(),
          reason: 'first reward at 500 pts should save',
        );

        // Second reward at the SAME cost 500
        c.read(rewardConfigControllerProvider.notifier).setName('Movie Night');
        c.read(rewardConfigControllerProvider.notifier).setPointsText('500');
        final second = await c
            .read(rewardConfigControllerProvider.notifier)
            .saveReward();
        expect(
          second,
          isA<RewardSaved>(),
          reason:
              'second reward at same 500 pts cost should also save (spend-economy allows duplicate prices)',
        );

        // Verify both milestones are persisted
        final db = c.read(userDatabaseProvider);
        final svc = RewardMilestoneService(db, profileId: 1);
        final milestones = await svc.getGlobalMilestones();
        expect(milestones, hasLength(2));
        expect(
          milestones.map((m) => m.title),
          containsAll(['Ice Cream', 'Movie Night']),
        );
        expect(
          milestones.every((m) => m.thresholdPoints == 500),
          isTrue,
          reason: 'both rewards should have threshold = 500',
        );
      },
    );

    test('three rewards at same cost all save successfully', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      for (final name in ['Alpha', 'Beta', 'Gamma']) {
        c.read(rewardConfigControllerProvider.notifier).setName(name);
        c.read(rewardConfigControllerProvider.notifier).setPointsText('250');
        final result = await c
            .read(rewardConfigControllerProvider.notifier)
            .saveReward();
        expect(
          result,
          isA<RewardSaved>(),
          reason: '$name at 250 pts should save',
        );
      }

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getGlobalMilestones();
      expect(milestones, hasLength(3));
    });

    test(
      'editing own milestone with same threshold is still not a duplicate',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);
        await seedProfileWithIds(
          c.read(userDatabaseProvider),
          accountId: 1,
          profileId: 1,
        );

        // Seed a milestone
        final db = c.read(userDatabaseProvider);
        final svc = RewardMilestoneService(db, profileId: 1);
        await svc.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'Original',
          thresholdPoints: 300,
          milestoneId: 'ms-orig',
        );

        final all = await svc.getAllMilestones();
        c
            .read(rewardConfigControllerProvider.notifier)
            .applyMilestoneToForm(all.first);
        c.read(rewardConfigControllerProvider.notifier).setName('Updated');
        c.read(rewardConfigControllerProvider.notifier).setPointsText('300');

        final result = await c
            .read(rewardConfigControllerProvider.notifier)
            .saveReward();
        expect(
          result,
          isA<RewardSaved>(),
          reason: 'editing own milestone at same price should always succeed',
        );
      },
    );
  });
}
