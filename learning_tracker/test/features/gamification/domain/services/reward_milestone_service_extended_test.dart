import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Balance implements PointsBalanceReader, PointsLifetimeEarnedReader {
  @override
  Future<int> getBalance() async => 0;

  @override
  Future<int> getLifetimeEarned() async => 0;
}

const _profileId = '01J00000000000000000000001';

RewardMilestoneService _service() => RewardMilestoneService(
  balanceReader: _Balance(),
  lifetimeEarnedReader: _Balance(),
  profileId: _profileId,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'filters malformed and foreign-profile reward payloads safely',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_config_v1_$_profileId',
        jsonEncode([
          {
            'id': 'mine',
            'profile_id': _profileId,
            'title': 'Mine',
            'threshold_points': 1,
            'is_enabled': true,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          },
          {
            'id': 'other',
            'profile_id': '01J00000000000000000000002',
            'title': 'Other',
            'threshold_points': 2,
            'is_enabled': true,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          },
          'not-a-map',
        ]),
      );

      final rewards = await _service().getAllMilestones();
      expect(rewards.map((reward) => reward.id), ['mine']);
    },
  );

  test(
    'stripStockTemplateMilestones removes only canonical stock rewards',
    () async {
      final service = _service();
      await service.upsertMilestone(
        title: 'Bronze Star',
        thresholdPoints: 500,
        milestoneId: 'stock',
      );
      await service.upsertMilestone(
        title: 'My prize',
        thresholdPoints: 500,
        milestoneId: 'custom',
      );

      expect(await service.stripStockTemplateMilestones(), isTrue);
      final remaining = await service.getAllMilestones();
      expect(remaining.map((reward) => reward.id), ['custom']);
      expect(await service.stripStockTemplateMilestones(), isFalse);
    },
  );

  test(
    'export and newer cloud merge preserve the active ULID profile',
    () async {
      final service = _service();
      await service.upsertMilestone(
        title: 'Local',
        thresholdPoints: 10,
        milestoneId: 'local',
      );
      final payload = await service.exportCloudPayload();
      expect(payload['milestones'], isNotEmpty);

      await service.mergeCloudPayload({
        'updated_at': DateTime.utc(2099).toIso8601String(),
        'milestones': [
          {
            'id': 'remote',
            'profile_id': _profileId,
            'title': 'Remote',
            'threshold_points': 20,
            'is_enabled': true,
            'created_at': '2099-01-01T00:00:00Z',
            'updated_at': '2099-01-01T00:00:00Z',
          },
        ],
        'unlocks': const <Map<String, dynamic>>[],
      });
      expect((await service.getAllMilestones()).single.id, 'remote');
    },
  );

  test('getAllUnlocks filters profiles and sorts newest first', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reward_milestones_unlocks_v1_$_profileId',
      jsonEncode([
        {
          'milestone_id': 'older',
          'profile_id': _profileId,
          'title': 'Older',
          'threshold_points': 50,
          'points_at_unlock': 60,
          'unlocked_at': '2026-01-01T00:00:00Z',
        },
        {
          'milestone_id': 'foreign',
          'profile_id': '01J00000000000000000000002',
          'title': 'Foreign',
          'threshold_points': 50,
          'points_at_unlock': 60,
          'unlocked_at': '2026-06-01T00:00:00Z',
        },
        {
          'milestone_id': 'newer',
          'profile_id': _profileId,
          'title': 'Newer',
          'threshold_points': 100,
          'points_at_unlock': 110,
          'unlocked_at': '2026-05-01T00:00:00Z',
        },
      ]),
    );

    final unlocks = await _service().getAllUnlocks();
    expect(unlocks.map((unlock) => unlock.milestoneId), ['newer', 'older']);
  });

  test('getAllUnlocks treats malformed JSON as an empty result', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reward_milestones_unlocks_v1_$_profileId',
      'not json',
    );

    expect(await _service().getAllUnlocks(), isEmpty);
  });

  test('merge ignores an older cloud timestamp', () async {
    final service = _service();
    await service.upsertMilestone(
      title: 'Local',
      thresholdPoints: 10,
      milestoneId: 'local',
    );
    await service.mergeCloudPayload({
      'updated_at': DateTime.utc(2020).toIso8601String(),
      'milestones': [
        {
          'id': 'stale',
          'profile_id': _profileId,
          'title': 'Stale',
          'threshold_points': 20,
          'is_enabled': true,
          'created_at': '2020-01-01T00:00:00Z',
          'updated_at': '2020-01-01T00:00:00Z',
        },
      ],
      'unlocks': const <Map<String, dynamic>>[],
    });

    expect((await service.getAllMilestones()).single.id, 'local');
  });
}
