// Tests for RewardMilestone and RewardUnlockRecord — covers copyWith, toJson,
// fromJson, and _asInt for non-int numeric types.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';

void main() {
  final base = RewardMilestone(
    id: 'ms_1',
    profileId: 1,
    trackId: 2,
    title: 'Gold Star',
    thresholdPoints: 100,
    isEnabled: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
    iconIndex: 3,
  );

  // =========================================================================
  // RewardMilestone.copyWith
  // =========================================================================

  group('RewardMilestone.copyWith', () {
    test('returns identical values when no fields overridden', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.title, base.title);
      expect(copy.thresholdPoints, base.thresholdPoints);
      expect(copy.iconIndex, base.iconIndex);
    });

    test('overrides only the specified fields', () {
      final copy = base.copyWith(title: 'Platinum', thresholdPoints: 500);
      expect(copy.id, base.id); // unchanged
      expect(copy.title, 'Platinum');
      expect(copy.thresholdPoints, 500);
      expect(copy.iconIndex, base.iconIndex); // unchanged
    });

    test('can disable a milestone', () {
      final copy = base.copyWith(isEnabled: false);
      expect(copy.isEnabled, isFalse);
      expect(base.isEnabled, isTrue); // original unchanged
    });
  });

  // =========================================================================
  // RewardMilestone.fromJson — _asInt edge cases
  // =========================================================================

  group('RewardMilestone.fromJson', () {
    test('round-trips via toJson/fromJson', () {
      final json = base.toJson();
      final restored = RewardMilestone.fromJson(json);

      expect(restored.id, base.id);
      expect(restored.profileId, base.profileId);
      expect(restored.trackId, base.trackId);
      expect(restored.title, base.title);
      expect(restored.thresholdPoints, base.thresholdPoints);
      expect(restored.isEnabled, base.isEnabled);
      expect(restored.iconIndex, base.iconIndex);
    });

    test('_asInt handles double values (num subtype)', () {
      // Pass thresholdPoints as a double (happens when reading from Firestore).
      final json = {
        'id': 'ms_2',
        'profile_id': 1.0, // double
        'track_id': 2.0,
        'title': 'Silver',
        'threshold_points': 50.0,
        'is_enabled': true,
        'icon_index': 1.0,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };

      final m = RewardMilestone.fromJson(json);

      expect(m.profileId, 1);
      expect(m.trackId, 2);
      expect(m.thresholdPoints, 50);
      expect(m.iconIndex, 1);
    });

    test('_asInt handles string values', () {
      final json = {
        'id': 'ms_3',
        'profile_id': '1', // string
        'track_id': '2',
        'title': 'Bronze',
        'threshold_points': '25',
        'is_enabled': false,
        'icon_index': '0',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };

      final m = RewardMilestone.fromJson(json);

      expect(m.profileId, 1);
      expect(m.thresholdPoints, 25);
    });

    test('_asInt returns null for unparseable strings → falls back to 0', () {
      final json = {
        'id': 'ms_4',
        'profile_id': 'not_a_number',
        'track_id': null,
        'title': '',
        'threshold_points': '',
        'is_enabled': null,
        'icon_index': null,
        'created_at': 'invalid_date',
        'updated_at': 'invalid_date',
      };

      // Should not throw; all fields fall back to defaults.
      expect(() => RewardMilestone.fromJson(json), returnsNormally);
      final m = RewardMilestone.fromJson(json);
      expect(m.profileId, 0);
      expect(m.trackId, 0);
      expect(m.thresholdPoints, 0);
    });
  });

  // =========================================================================
  // RewardUnlockRecord.fromJson
  // =========================================================================

  group('RewardUnlockRecord.fromJson', () {
    test('round-trips via toJson/fromJson', () {
      final record = RewardUnlockRecord(
        milestoneId: 'ms_1',
        profileId: 1,
        trackId: 2,
        title: 'Gold Star',
        thresholdPoints: 100,
        pointsAtUnlock: 150,
        unlockedAt: DateTime.utc(2026, 3, 15),
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

    test('handles invalid unlockedAt gracefully', () {
      final json = {
        'milestone_id': 'ms_x',
        'profile_id': 1,
        'track_id': 2,
        'title': 'Test',
        'threshold_points': 10,
        'points_at_unlock': 20,
        'unlocked_at': 'bad_date',
      };

      // Falls back to DateTimeFactory.nowUtc() — just verify it does not throw.
      expect(() => RewardUnlockRecord.fromJson(json), returnsNormally);
    });
  });
}
