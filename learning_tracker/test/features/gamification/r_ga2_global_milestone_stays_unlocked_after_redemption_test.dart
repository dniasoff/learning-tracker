/// Regression test for R-GA2: global reward milestone must NOT flip back to
/// LOCKED after a redemption debits the spendable points balance.
///
/// BEFORE the fix: [RewardMilestoneService.getGlobalPointsForRewards] returned
/// the debitable balance ([PointsBalanceDao.getBalance]). A redemption debit
/// reduces that balance, so a child who had earned enough points to unlock a
/// milestone could have it re-lock once they spent points — the opposite of
/// intended achievement semantics.
///
/// AFTER the fix: [achievementsOverviewProvider] calls
/// [RewardMilestoneService.getGlobalLifetimeEarnedForRewards] which sums
/// completion points across all reward-eligible tracks (from [completionsView],
/// which is append-only and never decremented). The resulting total is
/// monotonically non-decreasing: a milestone unlocked by reaching a threshold
/// stays unlocked permanently regardless of subsequent redemptions.
///
/// Scenario:
///   - Global milestone threshold: 100 pts
///   - Child earns 150 pts via completions → lifetime-earned = 150 → unlocked
///   - Child redeems a 120-pt reward → spendable balance drops to 30 < 100
///   - Milestone must STILL be unlocked (lifetime-earned = 150 >= threshold = 100)
@Tags(['gamification', 'r_ga2', 'regression'])
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

import '../../helpers/drift_memory.dart';

/// Seed a track with a learning goal so [trackCountsTowardRewardPoints] = true.
Future<int> _seedTrackWithGoal(UserDatabase db, {int profileId = 1}) async {
  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: 'bavli',
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
  final now = DateTime.utc(2026, 1, 1);
  await db.goalDao.insertGoal(
    GoalsCompanion.insert(
      profileId: profileId,
      curriculumId: 'bavli',
      trackId: trackId,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return trackId;
}

/// Insert a completion event worth [points] on [trackId].
Future<void> _insertCompletion(
  UserDatabase db, {
  required int trackId,
  required int points,
  int profileId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: profileId,
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

ProviderContainer _makeContainer(UserDatabase db, {int profileId = 1}) {
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(profileId),
      syncWriteFacadeProvider.overrideWithValue(null),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R-GA2: global milestone stays unlocked after redemption debit', () {
    test(
      'milestone earned at 150 pts stays unlocked after 120-pt redemption '
      '(balance = 30 < threshold = 100, but lifetime-earned = 150 >= 100)',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        // Seed profile + reward-eligible track.
        await seedProfile(db);
        final trackId = await _seedTrackWithGoal(db);

        // Earn 150 pts via completions (lifetime-earned = 150, balance = 150).
        await _insertCompletion(db, trackId: trackId, points: 150);
        await db.pointsBalanceDao.creditCompletion(1, 150);

        // Seed a global milestone with threshold = 100.
        final svc = RewardMilestoneService(db, profileId: 1);
        await svc.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'Gold Reward',
          thresholdPoints: 100,
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        // PRE-CONDITION: milestone is unlocked before any redemption.
        final before = await container.read(
          achievementsOverviewProvider.future,
        );
        final rowBefore = before.rows.firstWhere(
          (r) => r.milestone.title == 'Gold Reward',
        );
        expect(
          rowBefore.isUnlocked,
          isTrue,
          reason:
              'pre-condition: milestone must be unlocked when '
              'lifetime-earned(150) >= threshold(100)',
        );

        // Redeem 120 pts → balance drops to 30, which is BELOW the threshold.
        await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'Some Reward',
          iconIndex: 0,
          pointsCost: 120,
        );

        // Invalidate the provider so it re-reads (simulates navigation / screen
        // refresh that would show the updated state).
        container.invalidate(achievementsOverviewProvider);

        // POST-CONDITION: milestone must STILL be unlocked.
        // Spendable balance = 30 < 100, but lifetime-earned = 150 >= 100.
        final after = await container.read(achievementsOverviewProvider.future);
        final rowAfter = after.rows.firstWhere(
          (r) => r.milestone.title == 'Gold Reward',
        );
        expect(
          rowAfter.isUnlocked,
          isTrue,
          reason:
              'R-GA2 regression: milestone must remain unlocked after a '
              'redemption debit. lifetime-earned(150) >= threshold(100) even '
              'though spendable balance(30) < threshold(100).',
        );
        expect(rowAfter.isNextUp, isFalse);
      },
    );

    test(
      'getGlobalLifetimeEarnedForRewards returns completion sum, not balance',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        await seedProfile(db);
        final trackId = await _seedTrackWithGoal(db);

        // Earn 200 pts in completions, credit only 200 to balance, then spend 150.
        // lifetime-earned (from completions) = 200; balance = 50.
        await _insertCompletion(db, trackId: trackId, points: 200);
        await db.pointsBalanceDao.creditCompletion(1, 200);
        await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'Big Item',
          iconIndex: 0,
          pointsCost: 150,
        );

        final svc = RewardMilestoneService(db, profileId: 1);

        final lifetimeEarned = await svc.getGlobalLifetimeEarnedForRewards();
        final spendableBalance = await svc.getGlobalPointsForRewards();

        expect(
          lifetimeEarned,
          200,
          reason:
              'lifetime-earned must equal the sum of completion points (200), '
              'not the reduced spendable balance',
        );
        expect(
          spendableBalance,
          50,
          reason: 'the spendable balance is 200 - 150 = 50 after redemption',
        );
      },
    );
  });
}
