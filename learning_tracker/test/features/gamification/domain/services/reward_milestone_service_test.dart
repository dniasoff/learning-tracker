/// Tests for [RewardMilestoneService].
///
/// Covers:
///  - [RewardMilestoneService._matchesStockDefaultLadderEntry] (via defaultMilestoneLadder)
///  - [RewardMilestoneService.upsertMilestone] + [getAllMilestones]
///  - [RewardMilestoneService.removeMilestone]
///  - [RewardMilestoneService.stripStockTemplateMilestones]
///  - [RewardMilestoneService.getAllUnlocks]
///  - [RewardMilestoneService.mergeCloudPayload]
///  - [RewardMilestoneService.exportCloudPayload]
///
/// [RewardMilestone.fromJson]/[toJson] and [RewardUnlockRecord.fromJson]/
/// [toJson] round-trip coverage lives in
/// test/features/gamification/domain/models/reward_milestone_test.dart.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late RewardMilestoneService service;
  const profileId = 1;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = inMemoryDb();
    await seedProfile(db);
    service = RewardMilestoneService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper — insert a track + goal so trackCountsTowardRewardPoints returns true
  // ---------------------------------------------------------------------------

  Future<int> insertTrackWithGoal({
    String curriculumId = 'bavli',
    String trackType = 'personal',
  }) async {
    final trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    final now = DateTime.utc(2026, 1, 1);
    await db.goalDao.insertGoal(
      GoalsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return trackId;
  }

  Future<void> insertCompletion({
    required int trackId,
    required int points,
    String sefariaRef = 'Berakhot.2a',
    String trackType = 'personal',
    DateTime? completedAt,
  }) async {
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: 'bavli',
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: trackType,
        trackId: Value(trackId),
        eventTimestamp: completedAt ?? DateTime.utc(2026, 1, 1),
        points: Value(points),
      ),
    );
  }

  // RewardMilestone.fromJson/toJson and RewardUnlockRecord.fromJson/toJson
  // round-trip coverage lives in the dedicated model test file:
  // test/features/gamification/domain/models/reward_milestone_test.dart
  // (AUD-t-gamification-03 — do not re-add model-level round-trip tests here).

  // ─── defaultMilestoneLadder ───────────────────────────────────────────────

  group('defaultMilestoneLadder', () {
    test('contains 8 tiers in ascending threshold order', () {
      const ladder = RewardMilestoneService.defaultMilestoneLadder;
      expect(ladder.length, 8);
      for (var i = 1; i < ladder.length; i++) {
        expect(
          ladder[i].thresholdPoints,
          greaterThan(ladder[i - 1].thresholdPoints),
        );
      }
    });

    test('first tier is Bronze Star at 500 points', () {
      expect(
        RewardMilestoneService.defaultMilestoneLadder.first.title,
        'Bronze Star',
      );
      expect(
        RewardMilestoneService.defaultMilestoneLadder.first.thresholdPoints,
        500,
      );
    });

    test('last tier is Legend Star at 50000 points', () {
      expect(
        RewardMilestoneService.defaultMilestoneLadder.last.title,
        'Legend Star',
      );
      expect(
        RewardMilestoneService.defaultMilestoneLadder.last.thresholdPoints,
        50000,
      );
    });
  });

  // ─── getAllMilestones — empty / persistence ───────────────────────────────

  group('RewardMilestoneService.getAllMilestones', () {
    test('returns empty list when no milestones have been saved', () async {
      final milestones = await service.getAllMilestones();
      expect(milestones, isEmpty);
    });

    test('persists milestones across calls', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Gold Star',
        thresholdPoints: 1000,
      );

      final milestones = await service.getAllMilestones();
      expect(milestones, hasLength(1));
      expect(milestones.first.title, 'Gold Star');
      expect(milestones.first.thresholdPoints, 1000);
    });
  });

  // ─── upsertMilestone + getAllMilestones ───────────────────────────────────

  group('upsertMilestone + getAllMilestones', () {
    test('inserts a new milestone when no id supplied', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Test Milestone',
        thresholdPoints: 300,
      );

      final all = await service.getAllMilestones();
      expect(all.length, 1);
      expect(all.first.title, 'Test Milestone');
      expect(all.first.thresholdPoints, 300);
      expect(all.first.profileId, profileId);
      expect(all.first.trackId, 1);
    });

    test('updates existing milestone when id supplied', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Initial',
        thresholdPoints: 100,
        milestoneId: 'fixed-id',
      );

      await service.upsertMilestone(
        trackId: 1,
        title: 'Updated',
        thresholdPoints: 200,
        milestoneId: 'fixed-id',
      );

      final all = await service.getAllMilestones();
      expect(all.length, 1);
      expect(all.first.title, 'Updated');
      expect(all.first.thresholdPoints, 200);
    });

    test('getMilestonesForTrack filters by trackId', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Track 1 Milestone',
        thresholdPoints: 100,
      );
      await service.upsertMilestone(
        trackId: 2,
        title: 'Track 2 Milestone',
        thresholdPoints: 200,
      );

      final track1 = await service.getMilestonesForTrack(1);
      expect(track1.length, 1);
      expect(track1.first.title, 'Track 1 Milestone');

      final track2 = await service.getMilestonesForTrack(2);
      expect(track2.length, 1);
      expect(track2.first.title, 'Track 2 Milestone');
    });

    test(
      'getMilestonesForTrack returns milestones sorted ascending by threshold',
      () async {
        await service.upsertMilestone(
          trackId: 1,
          title: 'High',
          thresholdPoints: 1000,
          milestoneId: 'high',
        );
        await service.upsertMilestone(
          trackId: 1,
          title: 'Low',
          thresholdPoints: 100,
          milestoneId: 'low',
        );

        final milestones = await service.getMilestonesForTrack(1);
        expect(milestones.first.thresholdPoints, 100);
        expect(milestones.last.thresholdPoints, 1000);
      },
    );

    test(
      'getGlobalMilestones returns only sentinel-track milestones',
      () async {
        await service.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'Global',
          thresholdPoints: 5000,
        );
        await service.upsertMilestone(
          trackId: 1,
          title: 'Track',
          thresholdPoints: 100,
        );

        final global = await service.getGlobalMilestones();
        expect(global.length, 1);
        expect(global.first.title, 'Global');
      },
    );
  });

  // ─── upsertMilestone — insert path ───────────────────────────────────────

  group('RewardMilestoneService.upsertMilestone — insert', () {
    test('creates a new milestone with trimmed title', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: '  Bronze Star  ',
        thresholdPoints: 500,
        iconIndex: 2,
      );

      final milestones = await service.getMilestonesForTrack(trackId);
      expect(milestones, hasLength(1));
      expect(milestones.first.title, 'Bronze Star');
      expect(milestones.first.iconIndex, 2);
      expect(milestones.first.isEnabled, isTrue);
    });

    test('auto-generates an id when milestoneId is null', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Star',
        thresholdPoints: 100,
      );

      final milestones = await service.getAllMilestones();
      expect(milestones.first.id, isNotEmpty);
    });

    test('uses provided milestoneId when given', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Named',
        thresholdPoints: 50,
        milestoneId: 'my-custom-id',
      );

      final milestones = await service.getAllMilestones();
      expect(milestones.first.id, 'my-custom-id');
    });

    test(
      'multiple milestones for the same track are stored correctly',
      () async {
        final trackId = await insertTrackWithGoal();
        await service.upsertMilestone(
          trackId: trackId,
          title: 'Bronze',
          thresholdPoints: 500,
        );
        await service.upsertMilestone(
          trackId: trackId,
          title: 'Silver',
          thresholdPoints: 1000,
        );

        final milestones = await service.getMilestonesForTrack(trackId);
        expect(milestones, hasLength(2));
        // Ordered by thresholdPoints ascending.
        expect(milestones.first.thresholdPoints, 500);
        expect(milestones.last.thresholdPoints, 1000);
      },
    );
  });

  // ─── upsertMilestone — update path ───────────────────────────────────────

  group('RewardMilestoneService.upsertMilestone — update', () {
    test('updates an existing milestone when milestoneId matches', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Old Title',
        thresholdPoints: 200,
        milestoneId: 'id-1',
      );

      await service.upsertMilestone(
        trackId: trackId,
        title: 'New Title',
        thresholdPoints: 400,
        milestoneId: 'id-1',
        iconIndex: 5,
        isEnabled: false,
      );

      final milestones = await service.getMilestonesForTrack(trackId);
      expect(milestones, hasLength(1)); // no duplicate
      expect(milestones.first.title, 'New Title');
      expect(milestones.first.thresholdPoints, 400);
      expect(milestones.first.iconIndex, 5);
      expect(milestones.first.isEnabled, isFalse);
    });
  });

  // ─── removeMilestone ──────────────────────────────────────────────────────

  group('RewardMilestoneService.removeMilestone', () {
    test('removes the milestone with the matching id', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Remove Me',
        thresholdPoints: 100,
        milestoneId: 'rm-1',
      );
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Keep Me',
        thresholdPoints: 200,
        milestoneId: 'rm-2',
      );

      await service.removeMilestone('rm-1');

      final milestones = await service.getMilestonesForTrack(trackId);
      expect(milestones, hasLength(1));
      expect(milestones.first.id, 'rm-2');
    });

    test('is a no-op when milestoneId does not exist', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Keep',
        thresholdPoints: 100,
      );

      await service.removeMilestone('nonexistent-id');

      final milestones = await service.getMilestonesForTrack(trackId);
      expect(milestones, hasLength(1));
    });
  });

  // ─── getAllMilestones with empty/invalid prefs ─────────────────────────────

  group('getAllMilestones edge cases', () {
    test('returns empty list when prefs key is absent', () async {
      final milestones = await service.getAllMilestones();
      expect(milestones, isEmpty);
    });

    test('returns empty list when prefs value is blank string', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reward_milestones_config_v1_$profileId', '  ');
      final milestones = await service.getAllMilestones();
      expect(milestones, isEmpty);
    });

    test('returns empty list when prefs value is empty string', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reward_milestones_config_v1_$profileId', '');
      expect(await service.getAllMilestones(), isEmpty);
    });

    test('returns empty list when prefs value is invalid JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_config_v1_$profileId',
        'not-json',
      );
      final milestones = await service.getAllMilestones();
      expect(milestones, isEmpty);
    });

    test('returns empty list when prefs contain non-list JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_config_v1_$profileId',
        '{"key":"value"}',
      );
      final milestones = await service.getAllMilestones();
      expect(milestones, isEmpty);
    });

    // AUD-gamification-06: a JSON-decode failure must not be swallowed
    // silently -- it must be logged via AppLogger so a corrupted-storage
    // event that later exports an empty snapshot to the cloud (overwriting
    // every other device's rewards) leaves a diagnostic trail.
    test(
      'logs the decode failure via AppLogger when prefs value is invalid JSON',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'reward_milestones_config_v1_$profileId',
          'not-json',
        );

        await service.getAllMilestones();

        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any(
            (m) => m.contains('reward_milestone_service getAllMilestones'),
          ),
          isTrue,
          reason:
              'Expected the swallowed JSON-decode failure in getAllMilestones '
              'to be logged via AppLogger instead of silently returning an '
              'empty list with no diagnostic trail. Talker history: $history',
        );
      },
    );
  });

  // ─── getAllUnlocks edge cases ──────────────────────────────────────────────

  group('getAllUnlocks', () {
    test('returns empty list when no unlocks stored', () async {
      final unlocks = await service.getAllUnlocks();
      expect(unlocks, isEmpty);
    });

    test('returns empty list when unlock prefs value is blank', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reward_milestones_unlocks_v1_$profileId', '');
      final unlocks = await service.getAllUnlocks();
      expect(unlocks, isEmpty);
    });

    test(
      'returns empty list when unlock prefs value is invalid JSON',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'reward_milestones_unlocks_v1_$profileId',
          'bad json',
        );
        final unlocks = await service.getAllUnlocks();
        expect(unlocks, isEmpty);
      },
    );

    // AUD-gamification-06: same log-else-swallow requirement as
    // getAllMilestones above.
    test('logs the decode failure via AppLogger when unlock prefs value is '
        'invalid JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_unlocks_v1_$profileId',
        'bad json',
      );

      await service.getAllUnlocks();

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any(
          (m) => m.contains('reward_milestone_service getAllUnlocks'),
        ),
        isTrue,
        reason:
            'Expected the swallowed JSON-decode failure in getAllUnlocks '
            'to be logged via AppLogger instead of silently returning an '
            'empty list with no diagnostic trail. Talker history: $history',
      );
    });
  });

  // ─── getGlobalMilestones / getMilestonesForTrack ──────────────────────────

  group('RewardMilestoneService.getGlobalMilestones', () {
    test('returns milestones tied to kGlobalTrackSentinel', () async {
      await service.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Global Star',
        thresholdPoints: 5000,
      );

      final global = await service.getGlobalMilestones();
      expect(global, hasLength(1));
      expect(global.first.title, 'Global Star');
      expect(global.first.trackId, RewardMilestone.kGlobalTrackSentinel);
    });

    test(
      'getMilestonesForTrack only returns milestones for that track',
      () async {
        final trackId = await insertTrackWithGoal();
        await service.upsertMilestone(
          trackId: trackId,
          title: 'Track Milestone',
          thresholdPoints: 500,
        );
        await service.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'Global',
          thresholdPoints: 9999,
        );

        final trackMilestones = await service.getMilestonesForTrack(trackId);
        expect(trackMilestones, hasLength(1));
        expect(trackMilestones.first.title, 'Track Milestone');
      },
    );

    test('returns only global-sentinel milestones (F2 variant)', () async {
      await service.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Global',
        thresholdPoints: 500,
        milestoneId: 'global-1',
      );
      await service.upsertMilestone(
        trackId: 10,
        title: 'Track',
        thresholdPoints: 200,
        milestoneId: 'track-1',
      );

      final globalMs = await service.getGlobalMilestones();
      expect(globalMs, hasLength(1));
      expect(globalMs.first.id, 'global-1');
    });
  });

  // ─── trackCountsTowardRewardPoints ───────────────────────────────────────

  group('RewardMilestoneService.trackCountsTowardRewardPoints', () {
    test('returns false for a non-existent track', () async {
      final result = await service.trackCountsTowardRewardPoints(9999);
      expect(result, isFalse);
    });

    test('returns false when track has no goal and no program', () async {
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

      final result = await service.trackCountsTowardRewardPoints(trackId);
      expect(result, isFalse);
    });

    test('returns true when track has a goal', () async {
      final trackId = await insertTrackWithGoal();
      final result = await service.trackCountsTowardRewardPoints(trackId);
      expect(result, isTrue);
    });
  });

  // ─── getTrackPointsTotal ──────────────────────────────────────────────────

  group('RewardMilestoneService.getTrackPointsTotal', () {
    test('returns 0 when no completions exist for the track', () async {
      final trackId = await insertTrackWithGoal();
      expect(await service.getTrackPointsTotal(trackId), 0);
    });

    test('sums points across all completions for the track', () async {
      final trackId = await insertTrackWithGoal();
      await insertCompletion(
        trackId: trackId,
        points: 100,
        sefariaRef: 'Berakhot.2a',
      );
      await insertCompletion(
        trackId: trackId,
        points: 250,
        sefariaRef: 'Berakhot.2b',
        completedAt: DateTime.utc(2026, 2, 1),
      );

      expect(await service.getTrackPointsTotal(trackId), 350);
    });
  });

  // ─── getTrackPointsTotalForRewards ───────────────────────────────────────

  group('RewardMilestoneService.getTrackPointsTotalForRewards', () {
    test('returns 0 when track does not count toward rewards', () async {
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
      await insertCompletion(trackId: trackId, points: 500);

      expect(await service.getTrackPointsTotalForRewards(trackId), 0);
    });

    test('returns points when track counts toward rewards', () async {
      final trackId = await insertTrackWithGoal();
      await insertCompletion(trackId: trackId, points: 300);

      expect(await service.getTrackPointsTotalForRewards(trackId), 300);
    });
  });

  // ─── evaluateUnlocksForTrack ──────────────────────────────────────────────

  group('RewardMilestoneService.evaluateUnlocksForTrack', () {
    test(
      'returns empty list when track does not count toward rewards',
      () async {
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

        final unlocks = await service.evaluateUnlocksForTrack(trackId);
        expect(unlocks, isEmpty);
      },
    );

    test('returns empty list when no milestones exist for the track', () async {
      final trackId = await insertTrackWithGoal();
      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });

    test('DEC-32: crossing a threshold is a no-op (ladder removed)', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Bronze',
        thresholdPoints: 100,
        milestoneId: 'b1',
      );
      await insertCompletion(trackId: trackId, points: 150);

      // Rewards are priced spend-items now; no auto-unlock on threshold (R4o-C1).
      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });

    test('DEC-32: repeated evaluation stays a no-op', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Bronze',
        thresholdPoints: 100,
        milestoneId: 'b1',
      );
      await insertCompletion(trackId: trackId, points: 200);

      expect(await service.evaluateUnlocksForTrack(trackId), isEmpty);
      expect(await service.evaluateUnlocksForTrack(trackId), isEmpty);
    });

    test('does not unlock disabled milestones', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Disabled',
        thresholdPoints: 10,
        isEnabled: false,
      );
      await insertCompletion(trackId: trackId, points: 100);

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });

    test('does not unlock when points are below the threshold', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'High Bar',
        thresholdPoints: 10000,
      );
      await insertCompletion(trackId: trackId, points: 50);

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });
  });

  // ─── evaluateUnlocksForGlobal ─────────────────────────────────────────────

  group('RewardMilestoneService.evaluateUnlocksForGlobal', () {
    test('returns empty list when no global milestones configured', () async {
      final unlocks = await service.evaluateUnlocksForGlobal();
      expect(unlocks, isEmpty);
    });

    test(
      'DEC-32: crossing the global threshold is a no-op (ladder removed)',
      () async {
        await service.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'Global 500',
          thresholdPoints: 500,
          milestoneId: 'g1',
        );

        // WS7.balance: credit the stored balance directly.
        await db.pointsBalanceDao.creditCompletion(profileId, 600);

        // The auto-unlock ladder against the debitable balance was removed
        // (R4o-C1); the reward is a priced spend-item, not an auto-unlock.
        final unlocks = await service.evaluateUnlocksForGlobal();
        expect(unlocks, isEmpty);
      },
    );

    test('global milestone is only unlocked once', () async {
      await service.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Global',
        thresholdPoints: 100,
        milestoneId: 'g1',
      );
      // WS7.balance: credit the stored balance.
      await db.pointsBalanceDao.creditCompletion(profileId, 200);

      await service.evaluateUnlocksForGlobal();
      final second = await service.evaluateUnlocksForGlobal();
      expect(second, isEmpty);
    });

    test(
      'returns empty when no global milestones configured (F2 variant)',
      () async {
        final unlocks = await service.evaluateUnlocksForGlobal();
        expect(unlocks, isEmpty);
      },
    );
  });

  // ─── getAllUnlocks (extended) ─────────────────────────────────────────────

  group('RewardMilestoneService.getAllUnlocks', () {
    test('returns empty list when no unlocks have occurred', () async {
      expect(await service.getAllUnlocks(), isEmpty);
    });

    test(
      'DEC-32: no unlocks are written by evaluation (ladder removed)',
      () async {
        final trackId = await insertTrackWithGoal();
        await service.upsertMilestone(
          trackId: trackId,
          title: 'A',
          thresholdPoints: 50,
          milestoneId: 'a1',
        );
        await service.upsertMilestone(
          trackId: trackId,
          title: 'B',
          thresholdPoints: 100,
          milestoneId: 'b1',
        );
        await insertCompletion(trackId: trackId, points: 200);

        await service.evaluateUnlocksForTrack(trackId);

        // The auto-unlock ladder was removed; evaluation never writes unlock
        // records. (getAllUnlocks's stored-record sort is covered by the
        // extended test which stores records directly.)
        expect(await service.getAllUnlocks(), isEmpty);
      },
    );
  });

  // ─── stripStockTemplateMilestones ────────────────────────────────────────

  group('RewardMilestoneService.stripStockTemplateMilestones', () {
    test('returns false when no milestones exist', () async {
      final result = await service.stripStockTemplateMilestones();
      expect(result, isFalse);
    });

    test('removes milestone matching default ladder entry', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Bronze Star',
        thresholdPoints: 500,
        milestoneId: 'bronze',
      );

      final result = await service.stripStockTemplateMilestones();
      expect(result, isTrue);
      expect((await service.getAllMilestones()).length, 0);
    });

    test('removes legacy 50/150/300 tier set for a single track', () async {
      final trackId = await insertTrackWithGoal();
      for (final threshold in [50, 150, 300]) {
        await service.upsertMilestone(
          trackId: trackId,
          title: 'Legacy $threshold',
          thresholdPoints: threshold,
        );
      }

      final stripped = await service.stripStockTemplateMilestones();
      expect(stripped, isTrue);

      final remaining = await service.getMilestonesForTrack(trackId);
      expect(remaining, isEmpty);
    });

    test('removes stock milestones but preserves a custom milestone on the '
        'same track', () async {
      final trackId = await insertTrackWithGoal();
      // Add a milestone matching the default ladder exactly.
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Bronze Star',
        thresholdPoints: 500,
      );
      // Add a custom milestone that should be kept.
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Custom Prize',
        thresholdPoints: 750,
      );

      final stripped = await service.stripStockTemplateMilestones();
      expect(stripped, isTrue);

      final remaining = await service.getMilestonesForTrack(trackId);
      expect(remaining, hasLength(1));
      expect(remaining.first.title, 'Custom Prize');
    });

    test('preserves non-stock custom milestones', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'My Custom Award',
        thresholdPoints: 750,
        milestoneId: 'custom',
      );

      final result = await service.stripStockTemplateMilestones();
      expect(result, isFalse);
      expect((await service.getAllMilestones()).length, 1);
    });
  });

  // ─── mergeCloudPayload ───────────────────────────────────────────────────

  group('RewardMilestoneService.mergeCloudPayload', () {
    test('no-ops on null payload', () async {
      await service.mergeCloudPayload(null);
      expect((await service.getAllMilestones()).length, 0);
    });

    test('no-ops on empty payload', () async {
      await service.mergeCloudPayload({});
      expect((await service.getAllMilestones()).length, 0);
    });

    test(
      'imports milestones from remote payload with newer timestamp',
      () async {
        final remoteTime = DateTime.utc(2026, 5, 1).toIso8601String();
        final payload = {
          'updated_at': remoteTime,
          'milestones': [
            {
              'id': 'rm_remote_1',
              'profile_id': profileId,
              'track_id': 1,
              'title': 'Remote Milestone',
              'threshold_points': 999,
              'is_enabled': true,
              'icon_index': 0,
              'created_at': remoteTime,
              'updated_at': remoteTime,
            },
          ],
          'unlocks': <Map<String, dynamic>>[],
        };

        await service.mergeCloudPayload(payload);

        final milestones = await service.getAllMilestones();
        expect(milestones.length, 1);
        expect(milestones.first.title, 'Remote Milestone');
      },
    );

    test('skips merge when remote timestamp is older than local', () async {
      // Establish a local updated_at first by inserting a milestone.
      await service.upsertMilestone(
        trackId: 1,
        title: 'Local',
        thresholdPoints: 100,
        milestoneId: 'local-m',
      );

      // Try to merge with an older timestamp.
      final oldTime = DateTime.utc(2020, 1, 1).toIso8601String();
      await service.mergeCloudPayload({
        'updated_at': oldTime,
        'milestones': <Map<String, dynamic>>[],
        'unlocks': <Map<String, dynamic>>[],
      });

      // Local milestone must still be present.
      expect((await service.getAllMilestones()).length, 1);
      expect((await service.getAllMilestones()).first.id, 'local-m');
    });

    // AUD-gamification-05: a non-empty remote payload whose 'updated_at' is
    // missing or unparseable must NOT be treated as unconditionally newer
    // than local -- that silently clobbers local milestones/unlocks with no
    // way to prove the remote data is actually more recent. The malformed
    // timestamp must be treated the same as an older timestamp: skip merge,
    // keep local data untouched.
    test('skips merge and preserves local data when remote updated_at key is '
        'missing entirely (non-empty payload)', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Local',
        thresholdPoints: 100,
        milestoneId: 'local-m',
      );

      await service.mergeCloudPayload({
        // No 'updated_at' key at all.
        'milestones': [
          {
            'id': 'remote-should-not-land',
            'profile_id': profileId,
            'track_id': 1,
            'title': 'Remote',
            'threshold_points': 999,
            'is_enabled': true,
            'icon_index': 0,
            'created_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        ],
        'unlocks': <Map<String, dynamic>>[],
      });

      final milestones = await service.getAllMilestones();
      expect(milestones.length, 1);
      expect(milestones.first.id, 'local-m');
    });

    test('skips merge and preserves local data when remote updated_at is a '
        'garbage string (non-empty payload)', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Local',
        thresholdPoints: 100,
        milestoneId: 'local-m',
      );

      await service.mergeCloudPayload({
        'updated_at': 'not-a-real-timestamp',
        'milestones': [
          {
            'id': 'remote-should-not-land',
            'profile_id': profileId,
            'track_id': 1,
            'title': 'Remote',
            'threshold_points': 999,
            'is_enabled': true,
            'icon_index': 0,
            'created_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        ],
        'unlocks': <Map<String, dynamic>>[],
      });

      final milestones = await service.getAllMilestones();
      expect(milestones.length, 1);
      expect(milestones.first.id, 'local-m');
    });
  });

  // ─── exportCloudPayload (extended) ────────────────────────────────────────
  //
  // mergeCloudPayload null/empty/newer/older-timestamp coverage lives solely
  // in the 'RewardMilestoneService.mergeCloudPayload' group above — the
  // duplicate copies formerly here were removed under AUD-t-gamification-03.

  group('RewardMilestoneService — cloud sync', () {
    test('exportCloudPayload includes milestones and unlocks', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Export Test',
        thresholdPoints: 50,
        milestoneId: 'ex1',
      );

      final payload = await service.exportCloudPayload();
      expect(payload.containsKey('milestones'), isTrue);
      expect(payload.containsKey('unlocks'), isTrue);
      expect(payload.containsKey('updated_at'), isTrue);
      expect(payload['milestones'] as List, hasLength(1));
    });
  });

  // ─── exportCloudPayload ───────────────────────────────────────────────────

  group('exportCloudPayload', () {
    test('returns map with updated_at, milestones, and unlocks keys', () async {
      final payload = await service.exportCloudPayload();
      expect(payload.containsKey('updated_at'), isTrue);
      expect(payload.containsKey('milestones'), isTrue);
      expect(payload.containsKey('unlocks'), isTrue);
    });

    test('exported milestones match stored milestones', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Exported',
        thresholdPoints: 250,
        milestoneId: 'exp-1',
      );

      final payload = await service.exportCloudPayload();
      final milestones = payload['milestones'] as List<Map<String, dynamic>>;
      expect(milestones.length, 1);
      expect(milestones.first['title'], 'Exported');
    });

    test(
      'returns map with updated_at, milestones, unlocks keys (F2 variant)',
      () async {
        await service.upsertMilestone(
          trackId: 10,
          title: 'Export Test',
          thresholdPoints: 100,
          milestoneId: 'exp-1',
        );

        final payload = await service.exportCloudPayload();

        expect(payload.containsKey('updated_at'), isTrue);
        expect(payload.containsKey('milestones'), isTrue);
        expect(payload.containsKey('unlocks'), isTrue);
        expect(payload['milestones'], isA<List<dynamic>>());
        expect(payload['milestones'] as List<dynamic>, hasLength(1));
      },
    );

    test('export of empty service returns empty lists', () async {
      final payload = await service.exportCloudPayload();
      expect(payload['milestones'] as List<dynamic>, isEmpty);
      expect(payload['unlocks'] as List<dynamic>, isEmpty);
    });
  });

  // ─── kGlobalTrackSentinel ─────────────────────────────────────────────────

  group('kGlobalTrackSentinel', () {
    test('sentinel value is 0', () {
      expect(RewardMilestone.kGlobalTrackSentinel, 0);
    });
  });

  // ─── ensureDefaultsForTrack ───────────────────────────────────────────────

  group('RewardMilestoneService.ensureDefaultsForTrack', () {
    test(
      'is a no-op for a real track (does not seed any milestones)',
      () async {
        final trackId = await insertTrackWithGoal();
        await service.ensureDefaultsForTrack(trackId);

        final milestones = await service.getMilestonesForTrack(trackId);
        expect(milestones, isEmpty);
      },
    );

    test('is a no-op for kGlobalTrackSentinel', () async {
      await service.ensureDefaultsForTrack(
        RewardMilestone.kGlobalTrackSentinel,
      );
      final milestones = await service.getGlobalMilestones();
      expect(milestones, isEmpty);
    });

    test('is a no-op for non-global tracks (F2 variant)', () async {
      // Should not throw and not add milestones.
      await service.ensureDefaultsForTrack(42);
      expect(await service.getMilestonesForTrack(42), isEmpty);
    });

    test('is a no-op for global sentinel (F2 variant)', () async {
      await service.ensureDefaultsForTrack(
        RewardMilestone.kGlobalTrackSentinel,
      );
      expect(
        await service.getMilestonesForTrack(
          RewardMilestone.kGlobalTrackSentinel,
        ),
        isEmpty,
      );
    });
  });
}
