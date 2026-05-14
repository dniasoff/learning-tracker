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

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;
  late RewardMilestoneService service;
  const profileId = 1;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = createTestDatabase();
    service = RewardMilestoneService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

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
      expect(RewardMilestoneService.defaultMilestoneLadder.first.title, 'Bronze Star');
      expect(
        RewardMilestoneService.defaultMilestoneLadder.first.thresholdPoints,
        500,
      );
    });

    test('last tier is Legend Star at 50000 points', () {
      expect(RewardMilestoneService.defaultMilestoneLadder.last.title, 'Legend Star');
      expect(
        RewardMilestoneService.defaultMilestoneLadder.last.thresholdPoints,
        50000,
      );
    });
  });

  // ─── upsertMilestone / getAllMilestones ───────────────────────────────────

  group('upsertMilestone + getAllMilestones', () {
    test('inserts a new milestone when no id supplied', () async {
      // Insert a track so profile program checks work
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

    test('getMilestonesForTrack returns milestones sorted ascending by threshold', () async {
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
    });

    test('getGlobalMilestones returns only sentinel-track milestones', () async {
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

    test('returns empty list when prefs value is invalid JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_config_v1_$profileId',
        'not-json',
      );
      final milestones = await service.getAllMilestones();
      expect(milestones, isEmpty);
    });

    test('returns empty list when prefs value is JSON object (not list)', () async {
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

    test('returns empty list when unlock prefs value is invalid JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_unlocks_v1_$profileId',
        'bad json',
      );
      final unlocks = await service.getAllUnlocks();
      expect(unlocks, isEmpty);
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

    test('imports milestones from remote payload with newer timestamp', () async {
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
    });

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
  });

  // ─── kGlobalTrackSentinel ─────────────────────────────────────────────────

  group('kGlobalTrackSentinel', () {
    test('sentinel value is 0', () {
      expect(RewardMilestone.kGlobalTrackSentinel, 0);
    });
  });
}
