// Tests for RewardMilestone and RewardUnlockRecord — covers copyWith, toJson,
// fromJson, and _asInt for non-int numeric types.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';

void main() {
  final now = DateTime.utc(2026, 5, 14, 10, 0, 0);

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

  group('RewardMilestone', () {
    RewardMilestone base() => RewardMilestone(
      id: 'milestone-1',
      profileId: 1,
      trackId: 42,
      title: 'First 100',
      thresholdPoints: 100,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
      iconIndex: 3,
    );

    test('toJson serialises all fields correctly', () {
      final json = base().toJson();
      expect(json['id'], 'milestone-1');
      expect(json['profile_id'], 1);
      expect(json['track_id'], 42);
      expect(json['title'], 'First 100');
      expect(json['threshold_points'], 100);
      expect(json['is_enabled'], isTrue);
      expect(json['icon_index'], 3);
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());
    });

    test('fromJson round-trips through toJson', () {
      final original = base();
      final decoded = RewardMilestone.fromJson(original.toJson());

      expect(decoded.id, original.id);
      expect(decoded.profileId, original.profileId);
      expect(decoded.trackId, original.trackId);
      expect(decoded.title, original.title);
      expect(decoded.thresholdPoints, original.thresholdPoints);
      expect(decoded.isEnabled, original.isEnabled);
      expect(decoded.iconIndex, original.iconIndex);
    });

    test('fromJson handles int ids stored as strings', () {
      final json = base().toJson();
      json['profile_id'] = '2';
      json['track_id'] = '99';
      json['threshold_points'] = '500';

      final m = RewardMilestone.fromJson(json);
      expect(m.profileId, 2);
      expect(m.trackId, 99);
      expect(m.thresholdPoints, 500);
    });

    test('fromJson handles null/missing optional fields gracefully', () {
      final m = RewardMilestone.fromJson({
        'id': 'x',
        'title': 'test',
        // profile_id, track_id, threshold_points absent
      });
      expect(m.profileId, 0);
      expect(m.trackId, 0);
      expect(m.thresholdPoints, 0);
      expect(m.isEnabled, isTrue); // default
      expect(m.iconIndex, 0); // default
    });

    test('copyWith overrides only the specified fields', () {
      final original = base();
      final updated = original.copyWith(title: 'Gold', thresholdPoints: 500);

      expect(updated.title, 'Gold');
      expect(updated.thresholdPoints, 500);
      // unchanged fields
      expect(updated.id, original.id);
      expect(updated.profileId, original.profileId);
      expect(updated.trackId, original.trackId);
      expect(updated.isEnabled, original.isEnabled);
      expect(updated.iconIndex, original.iconIndex);
    });

    test('kGlobalTrackSentinel is 0', () {
      expect(RewardMilestone.kGlobalTrackSentinel, 0);
    });

    test('value equality: two instances with identical fields are ==', () {
      // Regression for AUD-gamification-14: RewardMilestone must be a value
      // object (generated ==/hashCode via @freezed), not identity-compared.
      final a = base();
      final b = base();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('value equality: differing a field breaks equality', () {
      final a = base();
      final b = a.copyWith(title: 'Different');
      expect(a, isNot(equals(b)));
    });
  });

  // ── RewardMilestone.copyWith ──────────────────────────────────────────────

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

  // ── RewardMilestone.fromJson — _asInt edge cases ──────────────────────────

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

  // ── RewardUnlockRecord ────────────────────────────────────────────────────

  group('RewardUnlockRecord', () {
    RewardUnlockRecord baseUnlock() => RewardUnlockRecord(
      milestoneId: 'milestone-1',
      profileId: 1,
      trackId: 42,
      title: 'First 100',
      thresholdPoints: 100,
      pointsAtUnlock: 115,
      unlockedAt: now,
    );

    test('toJson serialises all fields correctly', () {
      final json = baseUnlock().toJson();
      expect(json['milestone_id'], 'milestone-1');
      expect(json['profile_id'], 1);
      expect(json['track_id'], 42);
      expect(json['title'], 'First 100');
      expect(json['threshold_points'], 100);
      expect(json['points_at_unlock'], 115);
      expect(json['unlocked_at'], now.toIso8601String());
    });

    test('fromJson round-trips through toJson', () {
      final original = baseUnlock();
      final decoded = RewardUnlockRecord.fromJson(original.toJson());

      expect(decoded.milestoneId, original.milestoneId);
      expect(decoded.profileId, original.profileId);
      expect(decoded.trackId, original.trackId);
      expect(decoded.title, original.title);
      expect(decoded.thresholdPoints, original.thresholdPoints);
      expect(decoded.pointsAtUnlock, original.pointsAtUnlock);
    });

    test('fromJson handles numeric fields stored as strings', () {
      final json = baseUnlock().toJson();
      json['profile_id'] = '3';
      json['points_at_unlock'] = '200';

      final r = RewardUnlockRecord.fromJson(json);
      expect(r.profileId, 3);
      expect(r.pointsAtUnlock, 200);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final r = RewardUnlockRecord.fromJson({'milestone_id': 'abc'});
      expect(r.profileId, 0);
      expect(r.thresholdPoints, 0);
      expect(r.pointsAtUnlock, 0);
      expect(r.title, '');
    });

    test('value equality: two instances with identical fields are ==', () {
      // Regression for AUD-gamification-14: RewardUnlockRecord must be a
      // value object (generated ==/hashCode via @freezed), not identity-compared.
      final a = baseUnlock();
      final b = baseUnlock();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

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
