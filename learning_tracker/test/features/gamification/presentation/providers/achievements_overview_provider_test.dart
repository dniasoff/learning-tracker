/// Unit tests for [achievementsOverviewProvider] unlock classification.
///
/// Regression coverage for P1 reward-unlock bugs (#36 / #37):
///   - A reward whose threshold <= the points balance must classify as
///     UNLOCKED (not "next up"/locked).
///   - The unlocked COUNT must include every such reward.
///
/// Scenario from the field report: a child "Kid" with 72 points and two
/// global rewards priced at 50 and 502.
///   - The 50-pt reward must be Unlocked (isUnlocked=true, isNextUp=false).
///   - The 502-pt reward must be locked + "next up" (isNextUp=true).
///   - unlockedCount must be 1 (the summary reads "1/2").
@Tags(['gamification', 'achievements_overview'])
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
import '../../../../helpers/test_database.dart';

ProviderContainer _makeContainer({int profileId = 1}) {
  final db = inMemoryDb();
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(profileId),
      syncWriteFacadeProvider.overrideWithValue(null),
    ],
  );
}

Future<void> _seedGlobalMilestone(
  ProviderContainer c, {
  required String id,
  required String title,
  required int thresholdPoints,
}) async {
  final db = c.read(userDatabaseProvider);
  final profileId = c.read(activeProfileIdProvider);
  final svc = RewardMilestoneService(db, profileId: profileId);
  await svc.upsertMilestone(
    trackId: RewardMilestone.kGlobalTrackSentinel,
    title: title,
    thresholdPoints: thresholdPoints,
    milestoneId: id,
  );
}

AchievementRowVm _rowForThreshold(AchievementsOverview o, int threshold) =>
    o.rows.firstWhere((r) => r.milestone.thresholdPoints == threshold);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('unlock classification (threshold <= balance ⇒ unlocked)', () {
    test(
      'balance 72, thresholds {50,502}: 50 unlocked, 502 next-up, count 1/2',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        final db = c.read(userDatabaseProvider);
        await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
        await db.pointsBalanceDao.parentAdjust(1, 72);

        await _seedGlobalMilestone(
          c,
          id: 'ms-50',
          title: 'Small Reward',
          thresholdPoints: 50,
        );
        await _seedGlobalMilestone(
          c,
          id: 'ms-502',
          title: 'Big Reward',
          thresholdPoints: 502,
        );

        final overview = await c.read(achievementsOverviewProvider.future);

        // #37 — summary count must be 1/2.
        expect(overview.unlockedCount, 1);
        expect(overview.totalMilestones, 2);

        // #36 — 50-pt reward at 72 pts is Unlocked, not "coming soon".
        final fifty = _rowForThreshold(overview, 50);
        expect(fifty.isUnlocked, isTrue);
        expect(fifty.isNextUp, isFalse);

        // 502-pt reward is locked and is the next-up target.
        final big = _rowForThreshold(overview, 502);
        expect(big.isUnlocked, isFalse);
        expect(big.isNextUp, isTrue);
      },
    );

    test(
      'threshold exactly equal to balance is unlocked (>= boundary)',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        final db = c.read(userDatabaseProvider);
        await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
        await db.pointsBalanceDao.parentAdjust(1, 50);

        await _seedGlobalMilestone(
          c,
          id: 'ms-eq',
          title: 'Exact',
          thresholdPoints: 50,
        );

        final overview = await c.read(achievementsOverviewProvider.future);
        expect(overview.unlockedCount, 1);
        expect(_rowForThreshold(overview, 50).isUnlocked, isTrue);
      },
    );

    test('threshold above balance stays locked', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final db = c.read(userDatabaseProvider);
      await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
      await db.pointsBalanceDao.parentAdjust(1, 49);

      await _seedGlobalMilestone(
        c,
        id: 'ms-hi',
        title: 'Too High',
        thresholdPoints: 50,
      );

      final overview = await c.read(achievementsOverviewProvider.future);
      expect(overview.unlockedCount, 0);
      final row = _rowForThreshold(overview, 50);
      expect(row.isUnlocked, isFalse);
      expect(row.isNextUp, isTrue);
    });

    test('all affordable: both unlocked, none next-up, count 2/2', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final db = c.read(userDatabaseProvider);
      await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
      await db.pointsBalanceDao.parentAdjust(1, 1000);

      await _seedGlobalMilestone(
        c,
        id: 'ms-a',
        title: 'A',
        thresholdPoints: 50,
      );
      await _seedGlobalMilestone(
        c,
        id: 'ms-b',
        title: 'B',
        thresholdPoints: 502,
      );

      final overview = await c.read(achievementsOverviewProvider.future);
      expect(overview.unlockedCount, 2);
      expect(overview.rows.where((r) => r.isNextUp), isEmpty);
    });
  });
}
