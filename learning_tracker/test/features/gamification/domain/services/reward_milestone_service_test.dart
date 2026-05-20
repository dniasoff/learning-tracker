/// Tests for [RewardMilestoneService] and [RewardMilestone] model.
///
/// Covers:
///  - [RewardMilestone.fromJson] / [toJson] round-trip
///  - [RewardUnlockRecord.fromJson] / [toJson] round-trip
///  - [RewardMilestoneService._matchesStockDefaultLadderEntry] (via defaultMilestoneLadder)
///  - [RewardMilestoneService.upsertMilestone] + [getAllMilestones]
///  - [RewardMilestoneService.removeMilestone]
///  - [RewardMilestoneService.stripStockTemplateMilestones]
///  - [RewardMilestoneService.getAllUnlocks]
///  - [RewardMilestoneService.mergeCloudPayload]
///  - [RewardMilestoneService.exportCloudPayload]
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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

  // ─── RewardMilestone model ────────────────────────────────────────────────

  group('RewardMilestone.fromJson / toJson', () {
    test('round-trips all fields correctly', () {
      final now = DateTime.utc(2026, 1, 15, 10, 30);
      final milestone = RewardMilestone(
        id: 'rm_1_123_456',
        profileId: 2,
        trackId: 5,
        title: 'Bronze Star',
        thresholdPoints: 500,
        isEnabled: true,
        iconIndex: 3,
        createdAt: now,
        updatedAt: now,
      );

      final json = milestone.toJson();
      final restored = RewardMilestone.fromJson(json);

      expect(restored.id, milestone.id);
      expect(restored.profileId, milestone.profileId);
      expect(restored.trackId, milestone.trackId);
      expect(restored.title, milestone.title);
      expect(restored.thresholdPoints, milestone.thresholdPoints);
      expect(restored.isEnabled, milestone.isEnabled);
      expect(restored.iconIndex, milestone.iconIndex);
    });

    test('fromJson handles numeric string profile_id', () {
      final json = {
        'id': 'rm_abc',
        'profile_id': '3',
        'track_id': '7',
        'title': 'Gold Star',
        'threshold_points': '1000',
        'is_enabled': true,
        'icon_index': 0,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };
      final milestone = RewardMilestone.fromJson(json);
      expect(milestone.profileId, 3);
      expect(milestone.trackId, 7);
      expect(milestone.thresholdPoints, 1000);
    });

    test('fromJson handles missing is_enabled (defaults to true)', () {
      final json = {
        'id': 'rm_1',
        'profile_id': 1,
        'track_id': 1,
        'title': 'Test',
        'threshold_points': 100,
        'icon_index': 0,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };
      final milestone = RewardMilestone.fromJson(json);
      expect(milestone.isEnabled, isTrue);
    });

    test('copyWith updates specified fields', () {
      final now = DateTimeFactory.utc(2026, 1, 1);
      final original = RewardMilestone(
        id: 'rm_1',
        profileId: 1,
        trackId: 1,
        title: 'Original',
        thresholdPoints: 100,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );
      final updated = original.copyWith(
        title: 'Updated',
        thresholdPoints: 200,
        isEnabled: false,
      );
      expect(updated.title, 'Updated');
      expect(updated.thresholdPoints, 200);
      expect(updated.isEnabled, isFalse);
      expect(updated.id, original.id);
      expect(updated.profileId, original.profileId);
    });
  });

  group('RewardUnlockRecord.fromJson / toJson', () {
    test('round-trips all fields correctly', () {
      final unlockedAt = DateTime.utc(2026, 3, 10, 12);
      final record = RewardUnlockRecord(
        milestoneId: 'rm_1_abc',
        profileId: profileId,
        trackId: 5,
        title: 'Bronze Star',
        thresholdPoints: 500,
        pointsAtUnlock: 550,
        unlockedAt: unlockedAt,
      );

      final json = record.toJson();
      final restored = RewardUnlockRecord.fromJson(json);

      expect(restored.milestoneId, record.milestoneId);
      expect(restored.profileId, record.profileId);
      expect(restored.trackId, record.trackId);
      expect(restored.title, record.title);
      expect(restored.thresholdPoints, record.thresholdPoints);
      expect(restored.pointsAtUnlock, record.pointsAtUnlock);
    });
  });

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

  group('removeMilestone', () {
    test('removes milestone by id', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'To Remove',
        thresholdPoints: 100,
        milestoneId: 'rm-id',
      );
      expect((await service.getAllMilestones()).length, 1);

      await service.removeMilestone('rm-id');
      expect((await service.getAllMilestones()).length, 0);
    });

    test('removeMilestone with unknown id is a no-op', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Keep',
        thresholdPoints: 100,
        milestoneId: 'keep-id',
      );

      await service.removeMilestone('nonexistent');
      expect((await service.getAllMilestones()).length, 1);
    });
  });

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

    test('unlocks a milestone when points cross the threshold', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Bronze',
        thresholdPoints: 100,
        milestoneId: 'b1',
      );
      await insertCompletion(trackId: trackId, points: 150);

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, hasLength(1));
      expect(unlocks.first.title, 'Bronze');
    });

    test('does not re-unlock already unlocked milestones', () async {
      final trackId = await insertTrackWithGoal();
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Bronze',
        thresholdPoints: 100,
        milestoneId: 'b1',
      );
      await insertCompletion(trackId: trackId, points: 200);

      // First evaluation unlocks it.
      final first = await service.evaluateUnlocksForTrack(trackId);
      expect(first, hasLength(1));

      // Second evaluation should yield nothing new.
      final second = await service.evaluateUnlocksForTrack(trackId);
      expect(second, isEmpty);
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
      'unlocks global milestone when total points cross threshold',
      () async {
        await service.upsertMilestone(
          trackId: RewardMilestone.kGlobalTrackSentinel,
          title: 'Global 500',
          thresholdPoints: 500,
          milestoneId: 'g1',
        );

        // Add a track + goal (so completions count) and insert completions.
        final trackId = await insertTrackWithGoal();
        await insertCompletion(trackId: trackId, points: 600);

        final unlocks = await service.evaluateUnlocksForGlobal();
        expect(unlocks, hasLength(1));
        expect(unlocks.first.title, 'Global 500');
      },
    );

    test('global milestone is only unlocked once', () async {
      await service.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Global',
        thresholdPoints: 100,
        milestoneId: 'g1',
      );
      final trackId = await insertTrackWithGoal();
      await insertCompletion(trackId: trackId, points: 200);

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

    test('returns unlocks sorted by unlockedAt descending', () async {
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

      final unlocks = await service.getAllUnlocks();
      expect(unlocks, hasLength(2));
      // Descending by unlockedAt — the last added should be first.
      expect(
        unlocks.first.unlockedAt.isAfter(unlocks.last.unlockedAt) ||
            unlocks.first.unlockedAt == unlocks.last.unlockedAt,
        isTrue,
      );
    });
  });

  // ─── stripStockTemplateMilestones ────────────────────────────────────────

  group('stripStockTemplateMilestones', () {
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

    test('removes legacy 50/150/300 triple-milestone group', () async {
      await service.upsertMilestone(
        trackId: 1,
        title: 'Starter',
        thresholdPoints: 50,
        milestoneId: 'm50',
      );
      await service.upsertMilestone(
        trackId: 1,
        title: 'Intermediate',
        thresholdPoints: 150,
        milestoneId: 'm150',
      );
      await service.upsertMilestone(
        trackId: 1,
        title: 'Advanced',
        thresholdPoints: 300,
        milestoneId: 'm300',
      );

      final result = await service.stripStockTemplateMilestones();
      expect(result, isTrue);
      expect((await service.getAllMilestones()).length, 0);
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

  group('RewardMilestoneService.stripStockTemplateMilestones', () {
    test('returns false when no milestones exist', () async {
      final stripped = await service.stripStockTemplateMilestones();
      expect(stripped, isFalse);
    });

    test('removes milestones matching the default ladder', () async {
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

    test(
      'removes milestones matching the default ladder (F2 variant)',
      () async {
        await service.upsertMilestone(
          trackId: 10,
          title: 'Bronze Star',
          thresholdPoints: 500,
          milestoneId: 'stock-1',
        );

        final result = await service.stripStockTemplateMilestones();

        expect(result, isTrue);
        expect(await service.getMilestonesForTrack(10), isEmpty);
      },
    );

    test(
      'removes the legacy 50/150/300 tier set when exactly 3 match',
      () async {
        for (final t in [50, 150, 300]) {
          await service.upsertMilestone(
            trackId: 7,
            title: 'Legacy $t',
            thresholdPoints: t,
            milestoneId: 'leg-$t',
          );
        }

        final result = await service.stripStockTemplateMilestones();

        expect(result, isTrue);
        expect(await service.getMilestonesForTrack(7), isEmpty);
      },
    );

    test('keeps milestones that do not match stock entries', () async {
      await service.upsertMilestone(
        trackId: 10,
        title: 'My Custom Reward',
        thresholdPoints: 999,
        milestoneId: 'custom',
      );

      final result = await service.stripStockTemplateMilestones();

      expect(result, isFalse);
      expect(await service.getMilestonesForTrack(10), hasLength(1));
    });
  });

  // ─── mergeCloudPayload ───────────────────────────────────────────────────

  group('mergeCloudPayload', () {
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
  });

  // ─── exportCloudPayload / mergeCloudPayload (extended) ───────────────────

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

    test('mergeCloudPayload is a no-op when remote is null', () async {
      // Should complete without error.
      await expectLater(service.mergeCloudPayload(null), completes);
    });

    test('mergeCloudPayload is a no-op when remote is empty', () async {
      await expectLater(service.mergeCloudPayload({}), completes);
    });

    test(
      'mergeCloudPayload replaces local data when remote timestamp is newer',
      () async {
        // Set up a local milestone.
        final trackId = await insertTrackWithGoal();
        await service.upsertMilestone(
          trackId: trackId,
          title: 'Local Only',
          thresholdPoints: 999,
          milestoneId: 'local-1',
        );

        final remote = {
          'updated_at': DateTime.utc(2099, 1, 1).toIso8601String(),
          'milestones': [
            {
              'id': 'remote-1',
              'profile_id': profileId,
              'track_id': trackId,
              'title': 'Remote Star',
              'threshold_points': 777,
              'is_enabled': true,
              'icon_index': 0,
              'created_at': '2026-01-01T00:00:00.000Z',
              'updated_at': '2026-01-01T00:00:00.000Z',
            },
          ],
          'unlocks': <Map<String, dynamic>>[],
        };

        await service.mergeCloudPayload(remote);

        final milestones = await service.getAllMilestones();
        // Remote data should have replaced local.
        expect(milestones.any((m) => m.id == 'remote-1'), isTrue);
      },
    );

    test(
      'mergeCloudPayload is a no-op when remote timestamp is not newer',
      () async {
        final trackId = await insertTrackWithGoal();
        await service.upsertMilestone(
          trackId: trackId,
          title: 'Local',
          thresholdPoints: 100,
          milestoneId: 'keep-me',
        );

        // Export to bump the local timestamp.
        final exported = await service.exportCloudPayload();

        final remote = {
          'updated_at': DateTime.utc(2000, 1, 1).toIso8601String(), // very old
          'milestones': <Map<String, dynamic>>[],
          'unlocks': <Map<String, dynamic>>[],
        };
        await service.mergeCloudPayload(remote);

        // Local milestone should still be there.
        final milestones = await service.getAllMilestones();
        expect(milestones.any((m) => m.id == 'keep-me'), isTrue);

        // Suppress unused variable warning.
        expect(exported.containsKey('updated_at'), isTrue);
      },
    );
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
