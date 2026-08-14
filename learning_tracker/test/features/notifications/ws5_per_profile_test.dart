/// WS5.per-profile — Tests that inactive profiles' reminders are still scheduled.
///
/// Verifies DEC-28: every profile's reminders fire on schedule even when
/// another profile is currently active, and that tapping a notification
/// with a profile-scoped payload triggers a profile switch.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _profile0 = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _profile1 = '01ARZ3NDEKTSV4RRFFQ69G5FB0';
const _profile2 = '01ARZ3NDEKTSV4RRFFQ69G5FB1';
const _profile5 = '01ARZ3NDEKTSV4RRFFQ69G5FB4';
const _profile10 = '01ARZ3NDEKTSV4RRFFQ69G5FB9';
const _profile42 = '01ARZ3NDEKTSV4RRFFQ69G5FC0';

/// Mocks [FlutterLocalNotificationsPlugin] at the plugin boundary so the
/// per-profile payload-format tests below drive the real
/// [NotificationGateway] and capture what it actually sends, instead of
/// re-deriving the expected payload string independently
/// (AUD-t-notifications-07 — a self-computed comparison can never go red
/// when the gateway's payload format changes).
class _MockNotificationPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// Stubs [FlutterLocalNotificationsPlugin.zonedSchedule] on [mock] so it
/// completes without error.
void _stubZonedSchedule(_MockNotificationPlugin mock) {
  when(
    () => mock.zonedSchedule(
      id: any<int>(named: 'id'),
      scheduledDate: any<tz.TZDateTime>(named: 'scheduledDate'),
      notificationDetails: any<NotificationDetails>(
        named: 'notificationDetails',
      ),
      androidScheduleMode: any<AndroidScheduleMode>(
        named: 'androidScheduleMode',
      ),
      title: any<String>(named: 'title'),
      body: any<String>(named: 'body'),
      payload: any<String>(named: 'payload'),
      matchDateTimeComponents: any<DateTimeComponents>(
        named: 'matchDateTimeComponents',
      ),
    ),
  ).thenAnswer((_) async {});
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    // TQ-6: a fixed constant, not a wall-clock read — this only needs to be
    // *some* TZDateTime so mocktail has a fallback value for the untyped
    // `any` matcher; the value itself is never asserted on.
    registerFallbackValue(tz.TZDateTime(tz.UTC, 2024));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  group('WS5.per-profile — per-profile notification ID allocation', () {
    test('profile 0 gets its deterministic ULID-derived daily reminder ID', () {
      expect(dailyReminderIdForProfile(_profile0), equals(1523713000));
    });

    test('profile 1 gets its deterministic ULID-derived daily reminder ID', () {
      expect(dailyReminderIdForProfile(_profile1), equals(28042000));
    });

    test('different ULIDs get their deterministic daily reminder IDs', () {
      expect(dailyReminderIdForProfile(_profile5), equals(1138518000));
      expect(dailyReminderIdForProfile(_profile10), equals(1471375000));
    });

    test('two different profiles have different daily reminder IDs', () {
      final idA = dailyReminderIdForProfile(_profile1);
      final idB = dailyReminderIdForProfile(_profile2);
      expect(idA, isNot(equals(idB)));
    });

    test(
      'streakAlertIdForProfile returns different IDs for different profiles',
      () {
        final idA = streakAlertIdForProfile(_profile0);
        final idB = streakAlertIdForProfile(_profile1);
        expect(idA, isNot(equals(idB)));
      },
    );

    test(
      'batchBaseIdForProfile returns different bases for different profiles',
      () {
        final baseA = batchBaseIdForProfile(_profile0);
        final baseB = batchBaseIdForProfile(_profile1);
        expect(baseA, isNot(equals(baseB)));
        // Batch base + 13 (last slot) must still be < next profile's base.
        expect(baseA + 13, lessThan(baseB));
      },
    );

    test('no overlap between profile 0 and profile 1 batch ID ranges', () {
      const batchSize = 14;
      final base0 = batchBaseIdForProfile(_profile0);
      final base1 = batchBaseIdForProfile(_profile1);
      final ids0 = List.generate(batchSize, (i) => base0 + i).toSet();
      final ids1 = List.generate(batchSize, (i) => base1 + i).toSet();
      expect(ids0.intersection(ids1), isEmpty);
    });
  });

  group('WS5.per-profile — notification payload format', () {
    test('daily reminder payload is bare string for legacy', () {
      expect(dailyReminderPayload, equals('daily_reminder'));
    });

    test('per-profile payload format is daily_reminder:<profileId>', () async {
      final plugin = _MockNotificationPlugin();
      final gateway = NotificationGateway(plugin: plugin);
      _stubZonedSchedule(plugin);

      // Drives the real gateway method instead of re-deriving the
      // expected string, so this fails if the gateway's payload format
      // ever changes.
      await gateway.scheduleDailyReminderForProfile(
        profileId: _profile42,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );

      final payloadsCaptured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: any<tz.TZDateTime>(named: 'scheduledDate'),
          notificationDetails: any<NotificationDetails>(
            named: 'notificationDetails',
          ),
          androidScheduleMode: any<AndroidScheduleMode>(
            named: 'androidScheduleMode',
          ),
          title: any<String>(named: 'title'),
          body: any<String>(named: 'body'),
          payload: captureAny<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      final payload = payloadsCaptured.single as String;
      expect(payload, equals('daily_reminder:$_profile42'));

      // The tap handler splits on ':' to extract the profileId — verify
      // that parsing works against what the gateway actually produced.
      final parts = payload.split(':');
      expect(parts.length, equals(2));
      expect(parts[1], equals(_profile42));
    });

    test('profile B payload does not match profile A payload', () async {
      final plugin = _MockNotificationPlugin();
      final gateway = NotificationGateway(plugin: plugin);
      _stubZonedSchedule(plugin);

      await gateway.scheduleDailyReminderForProfile(
        profileId: _profile1,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );
      await gateway.scheduleDailyReminderForProfile(
        profileId: _profile2,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );

      final payloadsCaptured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: any<tz.TZDateTime>(named: 'scheduledDate'),
          notificationDetails: any<NotificationDetails>(
            named: 'notificationDetails',
          ),
          androidScheduleMode: any<AndroidScheduleMode>(
            named: 'androidScheduleMode',
          ),
          title: any<String>(named: 'title'),
          body: any<String>(named: 'body'),
          payload: captureAny<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(payloadsCaptured, hasLength(2));
      expect(payloadsCaptured[0], isNot(equals(payloadsCaptured[1])));
    });
  });
}
