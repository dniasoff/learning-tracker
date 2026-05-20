// Tests for StreakEvent.copyWith — covers lines 28-38 which were uncovered.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';

void main() {
  final base = StreakEvent(
    profileId: 1,
    eventType: 'completion',
    eventTimestamp: DateTime.utc(2026, 3, 15, 12),
    clientDeviceId: 'device-1',
  );

  group('StreakEvent.copyWith', () {
    test('returns an equal copy when called with no arguments', () {
      final copy = base.copyWith();
      expect(copy.profileId, base.profileId);
      expect(copy.eventType, base.eventType);
      expect(copy.eventTimestamp, base.eventTimestamp);
      expect(copy.clientDeviceId, base.clientDeviceId);
    });

    test('overrides profileId only', () {
      final copy = base.copyWith(profileId: 99);
      expect(copy.profileId, 99);
      expect(copy.eventType, base.eventType);
      expect(copy.eventTimestamp, base.eventTimestamp);
      expect(copy.clientDeviceId, base.clientDeviceId);
    });

    test('overrides eventType only', () {
      final copy = base.copyWith(eventType: 'day_boundary');
      expect(copy.eventType, 'day_boundary');
      expect(copy.profileId, base.profileId);
    });

    test('overrides eventTimestamp only', () {
      final newTs = DateTime.utc(2026, 4, 1);
      final copy = base.copyWith(eventTimestamp: newTs);
      expect(copy.eventTimestamp, newTs);
      expect(copy.profileId, base.profileId);
    });

    test('overrides clientDeviceId only', () {
      final copy = base.copyWith(clientDeviceId: 'device-2');
      expect(copy.clientDeviceId, 'device-2');
      expect(copy.profileId, base.profileId);
    });

    test('overrides multiple fields at once', () {
      final copy = base.copyWith(profileId: 2, eventType: 'manual_adjust');
      expect(copy.profileId, 2);
      expect(copy.eventType, 'manual_adjust');
      expect(copy.eventTimestamp, base.eventTimestamp);
    });

    test('works with null clientDeviceId on base', () {
      final noDevice = StreakEvent(
        profileId: 1,
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 3, 20),
      );
      final copy = noDevice.copyWith(profileId: 5);
      expect(copy.profileId, 5);
      expect(copy.clientDeviceId, isNull);
    });
  });
}
