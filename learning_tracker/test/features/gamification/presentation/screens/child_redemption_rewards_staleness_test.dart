/// Regression test for childRedemptionRewardsProvider staleness after
/// reward config changes (DG-RDMP-02).
///
/// `childRedemptionRewardsProvider` is a FutureProvider. When the parent
/// saves, toggles, or deletes a reward via [RewardConfigController],
/// [RewardConfigController._persistAndSync] MUST invalidate
/// [childRedemptionRewardsProvider] so that the ChildRedemptionScreen
/// immediately reflects the updated reward list without requiring the child to
/// navigate away and back.
///
/// BEFORE the fix: `_persistAndSync()` called
/// `ref.invalidate(achievementsOverviewProvider)` and
/// `ref.invalidate(dashboardChildNextRewardProvider)` only, omitting
/// `ref.invalidate(childRedemptionRewardsProvider)`. After a parent saves or
/// deletes a reward, the child redemption screen showed the stale reward list.
///
/// AFTER the fix: `_persistAndSync()` also invalidates
/// `childRedemptionRewardsProvider`, so the screen rebuilds with the
/// updated reward list as soon as the parent completes the save.
@Tags(['gamification', 'staleness'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  setUp(() {
    // RewardMilestoneService reads SharedPreferences for stock-template
    // migration state. Initialize with empty values before each test.
    SharedPreferences.setMockInitialValues({});
  });

  group('childRedemptionRewardsProvider — invalidated after reward config save '
      '(DG-RDMP-02)', () {
    test('childRedemptionRewardsProvider reflects newly-added reward after '
        'RewardConfigController.saveReward WITHOUT navigating away '
        '(must be invalidated in _persistAndSync)', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          syncWriteFacadeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      // Keep BOTH providers alive simultaneously — mimics the app state
      // where the child has ChildRedemptionScreen open while a parent
      // has RewardConfigurationScreen open on another session.
      final rewardsVersions = <List<RewardMilestone>>[];
      container.listen<AsyncValue<List<RewardMilestone>>>(
        childRedemptionRewardsProvider,
        (_, next) {
          next.whenData(rewardsVersions.add);
        },
        fireImmediately: true,
      );
      // Keep the controller alive (prevent autoDispose before saveReward).
      container.listen<RewardForm>(
        rewardConfigControllerProvider,
        (_, __) {},
        fireImmediately: false,
      );

      // Wait for the initial load to complete.
      await container.read(childRedemptionRewardsProvider.future);
      // Initial rewards list is empty.
      expect(rewardsVersions.isNotEmpty, isTrue);
      expect(
        rewardsVersions.last.isEmpty,
        isTrue,
        reason: 'initial rewards list must be empty (no milestones seeded)',
      );

      // Simulate the parent adding a new reward via the controller.
      final notifier = container.read(rewardConfigControllerProvider.notifier);
      await notifier.bootstrap();
      notifier.setName('TestPrize');
      notifier.setPointsText('50');
      final result = await notifier.saveReward();
      expect(result, isA<RewardSaved>());

      // Allow Riverpod to propagate the invalidation and re-fetch.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // Wait for re-fetched future to complete.
      await container.read(childRedemptionRewardsProvider.future);

      // childRedemptionRewardsProvider must have emitted a new version
      // that contains the newly-saved reward — without requiring
      // ref.invalidate() from the caller or navigation away and back.
      final allRewardTitles = rewardsVersions
          .expand((list) => list)
          .map((m) => m.title)
          .toList();
      expect(
        allRewardTitles,
        contains('TestPrize'),
        reason:
            'childRedemptionRewardsProvider must re-emit with the new '
            'reward after saveReward — _persistAndSync must call '
            'ref.invalidate(childRedemptionRewardsProvider). '
            'If this fails the reward list stays stale.',
      );
    });

    test(
      'childRedemptionRewardsProvider reflects deleted reward after '
      'RewardConfigController.deleteMilestone WITHOUT navigating away',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        // Seed a milestone directly so the initial list is non-empty.
        final svc = RewardMilestoneService(db, profileId: 1);
        await svc.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'Toy',
          thresholdPoints: 30,
          isEnabled: true,
        );

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWithValue(1),
            syncWriteFacadeProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final rewardsVersions = <List<RewardMilestone>>[];
        container.listen<AsyncValue<List<RewardMilestone>>>(
          childRedemptionRewardsProvider,
          (_, next) {
            next.whenData(rewardsVersions.add);
          },
          fireImmediately: true,
        );
        container.listen<RewardForm>(
          rewardConfigControllerProvider,
          (_, __) {},
          fireImmediately: false,
        );

        // Wait for the initial load to complete.
        final initialData = await container.read(
          childRedemptionRewardsProvider.future,
        );
        expect(
          initialData.any((m) => m.title == 'Toy'),
          isTrue,
          reason: 'pre-condition: Toy must appear in the initial data',
        );
        final toy = initialData.firstWhere((m) => m.title == 'Toy');

        // Simulate the parent deleting the reward via the controller.
        final notifier = container.read(
          rewardConfigControllerProvider.notifier,
        );
        await notifier.bootstrap();
        await notifier.deleteMilestone(toy);

        // Allow Riverpod to propagate the invalidation and re-fetch.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        // Wait for re-fetched future to complete.
        await container.read(childRedemptionRewardsProvider.future);

        // The deleted reward must not appear in the latest emission.
        expect(
          rewardsVersions.length,
          greaterThan(1),
          reason:
              'childRedemptionRewardsProvider must re-emit after deleteMilestone '
              '— _persistAndSync must call '
              'ref.invalidate(childRedemptionRewardsProvider).',
        );
        final latestList = rewardsVersions.last;
        expect(
          latestList.any((m) => m.title == 'Toy'),
          isFalse,
          reason: 'the deleted reward must not appear in the updated emission.',
        );
      },
    );
  });
}
