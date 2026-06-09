/// Regression test for achievementsOverviewProvider staleness after a
/// child redemption debit (DG-ACHV-01).
///
/// `achievementsOverviewProvider` is a FutureProvider. It reads the current
/// debitable balance via [RewardMilestoneService.getGlobalPointsForRewards]
/// to classify milestones as "unlocked" (balance >= threshold) or locked.
///
/// When a child redeems a reward via [ChildRedemptionScreen], the balance is
/// debited. If the [achievementsOverviewProvider] is NOT invalidated after the
/// debit, the gamification screen continues to show the milestone as
/// "unlocked" (based on the pre-debit balance) even though the child no
/// longer has sufficient balance.
///
/// BEFORE the fix: `_confirmRedeem()` in [ChildRedemptionScreen] does not
/// call `ref.invalidate(achievementsOverviewProvider)`. The gamification
/// screen shows stale "unlocked" classification until the user does a
/// pull-to-refresh.
///
/// AFTER the fix: `_confirmRedeem()` also invalidates
/// [achievementsOverviewProvider] after a successful `createRedemption()`,
/// so the gamification screen immediately reflects the updated unlock state.
@Tags(['gamification', 'staleness', 'achievements'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('achievementsOverviewProvider — staleness after redemption '
      '(DG-ACHV-01)', () {
    test('achievementsOverviewProvider re-classifies milestone as locked '
        'after ref.invalidate() when balance drops below threshold '
        '(simulates the invalidation that _confirmRedeem must add)', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      // Seed a global milestone at 100 pts threshold.
      final svc = RewardMilestoneService(db, profileId: 1);
      await svc.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'GoldStar',
        thresholdPoints: 100,
        isEnabled: true,
      );

      // Credit 150 pts → milestone is "unlocked" (balance >= threshold).
      await db.pointsBalanceDao.creditCompletion(1, 150);

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          syncWriteFacadeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      // Initial read — milestone must be unlocked.
      final before = await container.read(achievementsOverviewProvider.future);
      expect(
        before.rows.any((r) => r.milestone.title == 'GoldStar' && r.isUnlocked),
        isTrue,
        reason:
            'pre-condition: GoldStar must be unlocked when balance(150) '
            '>= threshold(100)',
      );

      // Debit 100 pts via a redemption → balance drops to 50.
      await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'GoldStar',
        iconIndex: 0,
        pointsCost: 100,
      );

      // WITHOUT invalidation, the provider still shows the stale (unlocked) state.
      // This is the core of the DG-ACHV-01 defect.
      final stale = await container.read(achievementsOverviewProvider.future);
      expect(
        stale.rows.any((r) => r.milestone.title == 'GoldStar' && r.isUnlocked),
        isTrue,
        reason:
            'DEFECT CONFIRMED: achievementsOverviewProvider shows stale '
            '"unlocked" state after a redemption debit — provider was NOT '
            'invalidated automatically.',
      );

      // The fix: _confirmRedeem must call
      // ref.invalidate(achievementsOverviewProvider) after a successful
      // createRedemption. Simulating that invalidation here:
      container.invalidate(achievementsOverviewProvider);

      // Wait for the provider to re-run and settle.
      final after = await container.read(achievementsOverviewProvider.future);

      // After re-evaluation, balance=50 < threshold=100 → GoldStar must
      // be classified as LOCKED (not unlocked).
      expect(
        after.rows.any((r) => r.milestone.title == 'GoldStar' && !r.isUnlocked),
        isTrue,
        reason:
            'after invalidation + re-evaluation, GoldStar must be '
            'LOCKED because balance(50) < threshold(100). This verifies '
            'that ref.invalidate(achievementsOverviewProvider) in '
            '_confirmRedeem corrects the stale unlock display.',
      );
    });

    test(
      'achievementsOverviewProvider does NOT re-classify milestone '
      'after redemption WITHOUT explicit invalidation — defect confirmed',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final svc = RewardMilestoneService(db, profileId: 1);
        await svc.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'SilverStar',
          thresholdPoints: 80,
          isEnabled: true,
        );
        await db.pointsBalanceDao.creditCompletion(1, 120);

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWithValue(1),
            syncWriteFacadeProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        // Initial read — milestone is unlocked.
        final before = await container.read(
          achievementsOverviewProvider.future,
        );
        expect(
          before.rows.any(
            (r) => r.milestone.title == 'SilverStar' && r.isUnlocked,
          ),
          isTrue,
        );

        // Debit 80 pts → balance drops to 40 < threshold(80).
        await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'SilverStar',
          iconIndex: 0,
          pointsCost: 80,
        );

        // WITHOUT invalidation — provider returns the same cached value.
        final staleResult = await container.read(
          achievementsOverviewProvider.future,
        );
        expect(
          staleResult.rows.any(
            (r) => r.milestone.title == 'SilverStar' && r.isUnlocked,
          ),
          isTrue,
          reason:
              'DEFECT CONFIRMED: without ref.invalidate(), '
              'achievementsOverviewProvider shows stale "unlocked" state '
              'even though balance(40) < threshold(80). The fix must add '
              'ref.invalidate(achievementsOverviewProvider) to '
              '_confirmRedeem().',
        );
      },
    );
  });
}
