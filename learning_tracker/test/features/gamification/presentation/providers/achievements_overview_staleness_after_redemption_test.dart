/// Regression tests for global milestone stability after redemption
/// (DG-ACHV-01 / R-GA2).
///
/// ## Background
///
/// [achievementsOverviewProvider] previously classified global milestones as
/// "unlocked" when [balance >= threshold], where [balance] is the DEBITABLE
/// balance from [PointsBalanceDao.getBalance]. A redemption debit reduces the
/// balance, so a child who had earned enough points to unlock a milestone would
/// see it flip back to LOCKED after spending points.
///
/// ## Fix (R-GA2)
///
/// The provider now calls [RewardMilestoneService.getGlobalLifetimeEarnedForRewards],
/// which sums completion points from [completionsView] across all
/// reward-eligible tracks. This value is monotonically non-decreasing
/// (completions are never deleted), so a milestone unlocked by crossing the
/// threshold stays unlocked permanently — regardless of subsequent redemptions.
///
/// ## Tests
///
/// 1. After a redemption that drops the spendable balance BELOW the threshold,
///    the milestone remains UNLOCKED (lifetime-earned still >= threshold).
/// 2. Provider returns the same unlock state before and after invalidation +
///    re-evaluation when a redemption has occurred.
@Tags(['gamification', 'staleness', 'achievements', 'r_ga2'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

Future<int> _seedTrackWithGoal(UserDatabase db) async {
  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
  final now = DateTime.utc(2026, 1, 1);
  await db.goalDao.insertGoal(
    GoalsCompanion.insert(
      profileId: 1,
      curriculumId: 'bavli',
      trackId: trackId,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return trackId;
}

Future<void> _insertCompletion(
  UserDatabase db, {
  required int trackId,
  required int points,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: 1,
      curriculumId: 'bavli',
      sefariaRef: 'Berakhot.2a',
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: DateTime.utc(2026, 1, 2),
      points: Value(points),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('achievementsOverviewProvider — milestone stability after redemption '
      '(R-GA2)', () {
    test(
      'milestone stays UNLOCKED after redemption drops balance below threshold '
      '(R-GA2: unlock uses lifetime-earned, not spendable balance)',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        // Seed a reward-eligible track with 150 pts of completions.
        final trackId = await _seedTrackWithGoal(db);
        await _insertCompletion(db, trackId: trackId, points: 150);
        // Also credit the spendable balance so redemption can debit it.
        await db.pointsBalanceDao.creditCompletion(1, 150);

        // Seed a global milestone at 100 pts threshold.
        final svc = RewardMilestoneService(db, profileId: 1);
        await svc.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'GoldStar',
          thresholdPoints: 100,
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

        // Initial read — milestone must be unlocked (lifetime-earned 150 >= 100).
        final before = await container.read(
          achievementsOverviewProvider.future,
        );
        expect(
          before.rows.any(
            (r) => r.milestone.title == 'GoldStar' && r.isUnlocked,
          ),
          isTrue,
          reason:
              'pre-condition: GoldStar must be unlocked when '
              'lifetime-earned(150) >= threshold(100)',
        );

        // Debit 100 pts via a redemption → spendable balance drops to 50 < 100.
        // Lifetime-earned remains 150 (completions are immutable).
        await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'GoldStar',
          iconIndex: 0,
          pointsCost: 100,
        );

        // Invalidate and re-read — milestone must STILL be unlocked.
        // R-GA2: lifetime-earned(150) >= threshold(100) regardless of balance.
        container.invalidate(achievementsOverviewProvider);
        final after = await container.read(achievementsOverviewProvider.future);

        expect(
          after.rows.any(
            (r) => r.milestone.title == 'GoldStar' && r.isUnlocked,
          ),
          isTrue,
          reason:
              'R-GA2: GoldStar must remain UNLOCKED after redemption. '
              'Spendable balance(50) < threshold(100), but '
              'lifetime-earned(150) >= threshold(100).',
        );
      },
    );

    test('milestone remains unlocked across multiple redemptions that drain '
        'the balance to zero', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final trackId = await _seedTrackWithGoal(db);
      await _insertCompletion(db, trackId: trackId, points: 200);
      await db.pointsBalanceDao.creditCompletion(1, 200);

      final svc = RewardMilestoneService(db, profileId: 1);
      await svc.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'SilverStar',
        thresholdPoints: 80,
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

      // Drain balance via two redemptions (200 total, balance goes to 0).
      await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Item 1',
        iconIndex: 0,
        pointsCost: 100,
      );
      await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Item 2',
        iconIndex: 0,
        pointsCost: 100,
      );

      container.invalidate(achievementsOverviewProvider);
      final after = await container.read(achievementsOverviewProvider.future);

      // Balance = 0 < threshold(80), but lifetime-earned = 200 >= 80.
      expect(
        after.rows.any(
          (r) => r.milestone.title == 'SilverStar' && r.isUnlocked,
        ),
        isTrue,
        reason:
            'R-GA2: SilverStar must remain UNLOCKED even when balance '
            'is fully drained. lifetime-earned(200) >= threshold(80).',
      );
    });
  });
}
