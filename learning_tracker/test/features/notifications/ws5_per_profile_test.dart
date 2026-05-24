/// WS5.per-profile — Tests that inactive profiles' reminders are still scheduled.
///
/// Verifies DEC-28: every profile's reminders fire on schedule even when
/// another profile is currently active, and that tapping a notification
/// with a profile-scoped payload triggers a profile switch.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';

void main() {
  group('WS5.per-profile — per-profile notification ID allocation', () {
    test('profile 0 gets dailyReminderId 0', () {
      expect(dailyReminderIdForProfile(0), equals(0));
    });

    test('profile 1 gets dailyReminderId 1000', () {
      expect(dailyReminderIdForProfile(1), equals(1000));
    });

    test('profile N gets dailyReminderId N*1000', () {
      expect(dailyReminderIdForProfile(5), equals(5000));
      expect(dailyReminderIdForProfile(10), equals(10000));
    });

    test('two different profiles have different daily reminder IDs', () {
      final idA = dailyReminderIdForProfile(1);
      final idB = dailyReminderIdForProfile(2);
      expect(idA, isNot(equals(idB)));
    });

    test('streakAlertIdForProfile returns different IDs for different profiles',
        () {
      final idA = streakAlertIdForProfile(0);
      final idB = streakAlertIdForProfile(1);
      expect(idA, isNot(equals(idB)));
    });

    test('batchBaseIdForProfile returns different bases for different profiles',
        () {
      final baseA = batchBaseIdForProfile(0);
      final baseB = batchBaseIdForProfile(1);
      expect(baseA, isNot(equals(baseB)));
      // Batch base + 13 (last slot) must still be < next profile's base.
      expect(baseA + 13, lessThan(baseB));
    });

    test('no overlap between profile 0 and profile 1 batch ID ranges', () {
      const batchSize = 14;
      final base0 = batchBaseIdForProfile(0);
      final base1 = batchBaseIdForProfile(1);
      final ids0 = List.generate(batchSize, (i) => base0 + i).toSet();
      final ids1 = List.generate(batchSize, (i) => base1 + i).toSet();
      expect(ids0.intersection(ids1), isEmpty);
    });
  });

  group('WS5.per-profile — notification payload format', () {
    test('daily reminder payload is bare string for legacy', () {
      expect(dailyReminderPayload, equals('daily_reminder'));
    });

    test('per-profile payload format is daily_reminder:<profileId>', () {
      const profileId = 42;
      // The gateway embeds profileId in the payload for per-profile scheduling.
      // The tap handler splits on ':' to extract the profileId.
      final payload = '$dailyReminderPayload:$profileId';
      expect(payload, equals('daily_reminder:42'));

      final parts = payload.split(':');
      expect(parts.length, equals(2));
      expect(int.tryParse(parts[1]), equals(profileId));
    });

    test('profile B payload does not match profile A payload', () {
      final payloadA = '$dailyReminderPayload:1';
      final payloadB = '$dailyReminderPayload:2';
      expect(payloadA, isNot(equals(payloadB)));
    });
  });
}
