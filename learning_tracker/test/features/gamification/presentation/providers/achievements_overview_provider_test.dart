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

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/test_database.dart';

/// Seed a reward-eligible track (with a learning goal) for [profileId].
/// Returns the track id.
Future<int> _seedRewardTrack(UserDatabase db, {int profileId = 1}) async {
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

/// Insert a completion event worth [points] on [trackId] for [profileId].
/// R-GA2: global milestone unlock now uses lifetime-earned (completions),
/// not the spendable balance — so tests must seed completions, not just
/// balance credits.
Future<void> _seedCompletion(
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

// ── SM-2 purity fake (AUD-gamification-03) ──────────────────────────────────

/// [SyncWriteFacade] that counts [pushGamificationSettingsSnapshot] calls
/// instead of performing any real push — used to prove
/// [achievementsOverviewProvider]'s build never triggers a sync push as a
/// side effect of being watched/rebuilt.
class _CountingSyncFacade implements SyncWriteFacade {
  int pushCount = 0;

  @override
  Future<void> pushGamificationSettingsSnapshot() async {
    pushCount++;
  }

  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {}
  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // R-GA2: global milestones now use lifetime-earned (completion-derived total)
  // not the spendable balance. Tests must seed completions to drive unlock
  // classification (parentAdjust alone no longer affects milestone state).
  group('unlock classification (threshold <= lifetime-earned ⇒ unlocked)', () {
    test(
      'lifetime-earned 72, thresholds {50,502}: 50 unlocked, 502 next-up, count 1/2',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        final db = c.read(userDatabaseProvider);
        await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
        // Seed a reward-eligible track + completions totalling 72 pts.
        final trackId = await _seedRewardTrack(db);
        await _seedCompletion(db, trackId: trackId, points: 72);

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

        // #36 — 50-pt reward at 72 pts lifetime-earned is Unlocked.
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
      'threshold exactly equal to lifetime-earned is unlocked (>= boundary)',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        final db = c.read(userDatabaseProvider);
        await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
        final trackId = await _seedRewardTrack(db);
        await _seedCompletion(db, trackId: trackId, points: 50);

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

    test('lifetime-earned below threshold stays locked', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final db = c.read(userDatabaseProvider);
      await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
      final trackId = await _seedRewardTrack(db);
      await _seedCompletion(db, trackId: trackId, points: 49);

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

    test('both thresholds crossed by lifetime-earned: both unlocked, '
        'none next-up, count 2/2', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final db = c.read(userDatabaseProvider);
      await seedProfileWithIds(db, accountId: 1, profileId: 1, mode: 'child');
      final trackId = await _seedRewardTrack(db);
      await _seedCompletion(db, trackId: trackId, points: 1000);

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

  // ── SM-2: build is pure (AUD-gamification-03) ───────────────────────────────

  group('SM-2: build performs no writes/sync-pushes (AUD-gamification-03)', () {
    test(
      'watching achievementsOverviewProvider twice (rebuild via invalidate) '
      'neither strips a legacy stock-template milestone from the DB nor '
      'pushes a sync snapshot -- that is now GamificationMaintenanceController\'s '
      'job, invoked explicitly, never a side effect of this read provider',
      () async {
        final counting = _CountingSyncFacade();
        final db = inMemoryDb();
        final c = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWithValue(1),
            syncWriteFacadeProvider.overrideWithValue(counting),
          ],
        );
        addTearDown(c.dispose);
        await seedProfileWithIds(db, accountId: 1, profileId: 1);

        // A legacy stock-template-ladder entry (exact title + threshold from
        // RewardMilestoneService.defaultMilestoneLadder) -- this is exactly
        // what stripStockTemplateMilestones() removes.
        await _seedGlobalMilestone(
          c,
          id: 'legacy-bronze',
          title: 'Bronze Star',
          thresholdPoints: 500,
        );

        // First watch.
        await c.read(achievementsOverviewProvider.future);
        // Force a rebuild (second watch) -- a mutating build would strip/push
        // again here, growing the counters.
        c.invalidate(achievementsOverviewProvider);
        await c.read(achievementsOverviewProvider.future);

        final svc = RewardMilestoneService(db, profileId: 1);
        final remaining = await svc.getAllMilestones();
        expect(
          remaining.any((m) => m.title == 'Bronze Star'),
          isTrue,
          reason:
              'the legacy stock-template milestone must still be present -- '
              'a pure achievementsOverviewProvider build must never call '
              'stripStockTemplateMilestones() as a side effect of being watched',
        );
        expect(
          counting.pushCount,
          0,
          reason:
              'a pure achievementsOverviewProvider build must never push a '
              'sync snapshot as a side effect of being watched/rebuilt',
        );
      },
    );
  });
}
