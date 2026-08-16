// Tests for StreakLogEvent.copyWith — covers lines 28-38 which were uncovered.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/streak/streak_log_event.dart';

void main() {
  final base = StreakLogEvent(
    eventType: 'completion',
    eventTimestamp: DateTime.utc(2026, 3, 15, 12),
    clientDeviceId: 'device-1',
  );

  group('StreakLogEvent.copyWith', () {
    test('returns an equal copy when called with no arguments', () {
      final copy = base.copyWith();
      expect(copy.eventType, base.eventType);
      expect(copy.eventTimestamp, base.eventTimestamp);
      expect(copy.clientDeviceId, base.clientDeviceId);
    });

    test('overrides eventType only', () {
      final copy = base.copyWith(eventType: 'day_boundary');
      expect(copy.eventType, 'day_boundary');
      expect(copy.eventTimestamp, base.eventTimestamp);
    });

    test('overrides eventTimestamp only', () {
      final newTs = DateTime.utc(2026, 4, 1);
      final copy = base.copyWith(eventTimestamp: newTs);
      expect(copy.eventTimestamp, newTs);
      expect(copy.eventType, base.eventType);
    });

    test('overrides clientDeviceId only', () {
      final copy = base.copyWith(clientDeviceId: 'device-2');
      expect(copy.clientDeviceId, 'device-2');
      expect(copy.eventType, base.eventType);
    });

    test('overrides multiple fields at once', () {
      final copy = base.copyWith(
        eventType: 'manual_adjust',
        eventTimestamp: DateTime.utc(2026, 4, 1),
      );
      expect(copy.eventType, 'manual_adjust');
      expect(copy.eventTimestamp, DateTime.utc(2026, 4, 1));
    });

    test('works with null clientDeviceId on base', () {
      final noDevice = StreakLogEvent(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 3, 20),
      );
      final copy = noDevice.copyWith(eventType: 'manual_adjust');
      expect(copy.eventType, 'manual_adjust');
      expect(copy.clientDeviceId, isNull);
    });
  });
}
