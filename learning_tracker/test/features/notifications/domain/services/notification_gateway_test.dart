/// Unit tests for [NotificationGateway].
///
/// Mocks [FlutterLocalNotificationsPlugin] at the plugin boundary so no real
/// platform code runs.  Covers:
///   - initialize (success / null / callback wiring)
///   - scheduleDailyReminder (correct id, title, body, payload, matchTime,
///     scheduleMode)
///   - cancelDailyReminder
///   - reschedule (cancel-then-schedule produces both calls)
///   - scheduleBatchReminders (cancels existing batch, schedules each entry,
///     caps at 14, no matchDateTimeComponents, correct payload)
///   - cancelBatchReminders (cancels all 14 IDs in the right range)
///   - per-profile daily reminder (ID = profileId*1000, payload carries
///     profileId)
///   - per-profile batch (baseId = profileId*1000+10, payload carries
///     profileId)
///   - cancelDailyReminderForProfile / cancelBatchRemindersForProfile
///   - streakAlert (correct id, channel priority=high, payload, matchTime)
///   - cancelStreakAlert
///   - per-profile streak alert (ID = profileId*1000+1, payload carries
///     profileId)
///   - cancelStreakAlertForProfile
///   - requestPermission: non-mobile fallback, Android branch (permission +
///     exact-alarm requests, granted flag threaded through), iOS branch
///     (alert/badge/sound request, granted flag threaded through) —
///     AUD-notifications-10
///   - hasPermission: non-mobile fallback, Android branch
///     (areNotificationsEnabled threaded through) — AUD-notifications-10
///   - _nextInstanceOfTime: scheduled time is never in the past; if the
///     requested hour:minute is in the past it rolls forward one day
///   - ID allocation helpers (unit maths, no platform)
///
/// We drive the REAL [NotificationGateway]; no production code is modified.

@Tags(['notifications', 'unit'])
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

/// Mocks the Android platform-specific implementation returned by
/// [FlutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation]
/// so the Android branch of requestPermission()/hasPermission() (which is
/// otherwise unreachable in a plain unit test — AUD-notifications-10) can be
/// exercised.
class MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// Mocks the iOS platform-specific implementation returned by
/// [FlutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation]
/// so the iOS branch of requestPermission() (AUD-notifications-10) can be
/// exercised.
class MockIOSPlugin extends Mock
    implements IOSFlutterLocalNotificationsPlugin {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Registers all the named-parameter types that mocktail needs as fallbacks.
void _registerFallbacks() {
  registerFallbackValue(const InitializationSettings());
  registerFallbackValue(const NotificationDetails());
  registerFallbackValue(tz.TZDateTime.now(tz.UTC));
  registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
  registerFallbackValue(DateTimeComponents.time);
}

/// Stub [zonedSchedule] on [mock] so it completes without error.
void _stubZonedSchedule(MockPlugin mock) {
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

/// Stub [cancel] on [mock] so it completes without error.
void _stubCancel(MockPlugin mock) {
  when(() => mock.cancel(id: any<int>(named: 'id'))).thenAnswer((_) async {});
}

/// Builds a list of [count] TZDateTimes that are all in the future.
List<tz.TZDateTime> _futureTimes(int count) {
  final now = tz.TZDateTime.now(tz.local);
  return List.generate(count, (i) => now.add(Duration(days: i + 1)));
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    _registerFallbacks();
  });

  late MockPlugin plugin;
  late NotificationGateway gw;

  setUp(() {
    plugin = MockPlugin();
    gw = NotificationGateway(plugin: plugin);
    _stubZonedSchedule(plugin);
    _stubCancel(plugin);
  });

  // -------------------------------------------------------------------------
  // initialize
  // -------------------------------------------------------------------------

  group('initialize', () {
    test('returns true when plugin returns true', () async {
      when(
        () => plugin.initialize(
          settings: any<InitializationSettings>(named: 'settings'),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((_) async => true);

      expect(await gw.initialize(), isTrue);
    });

    test('returns false when plugin returns false', () async {
      when(
        () => plugin.initialize(
          settings: any<InitializationSettings>(named: 'settings'),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((_) async => false);

      expect(await gw.initialize(), isFalse);
    });

    test('returns false when plugin returns null', () async {
      when(
        () => plugin.initialize(
          settings: any<InitializationSettings>(named: 'settings'),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((_) async => null);

      expect(await gw.initialize(), isFalse);
    });

    test(
      'calls plugin.initialize exactly once with InitializationSettings',
      () async {
        when(
          () => plugin.initialize(
            settings: any<InitializationSettings>(named: 'settings'),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => true);

        await gw.initialize();

        verify(
          () => plugin.initialize(
            settings: any<InitializationSettings>(named: 'settings'),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
          ),
        ).called(1);
      },
    );

    test('wires onNotificationTap callback through response handler', () async {
      String? captured;
      when(
        () => plugin.initialize(
          settings: any<InitializationSettings>(named: 'settings'),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((invocation) async {
        // Simulate the plugin calling the response handler.
        final handler =
            invocation.namedArguments[#onDidReceiveNotificationResponse]
                as void Function(NotificationResponse)?;
        handler?.call(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'daily_reminder',
          ),
        );
        return true;
      });

      await gw.initialize(onNotificationTap: (payload) => captured = payload);

      expect(captured, equals('daily_reminder'));
    });
  });

  // -------------------------------------------------------------------------
  // permission helpers
  // -------------------------------------------------------------------------

  group('requestPermission', () {
    test(
      'returns true when no platform-specific impl is available (non-mobile)',
      () async {
        // resolvePlatformSpecificImplementation returns null for Android/iOS
        // when running in a unit-test context (no platform channel), so the
        // gateway falls through to `return true`.
        expect(await gw.requestPermission(), isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // Android branch (AUD-notifications-10)
    //
    // Stubs resolvePlatformSpecificImplementation<AndroidFlutterLocalNotif...>
    // to return a mocked AndroidFlutterLocalNotificationsPlugin so the real
    // POST_NOTIFICATIONS + exact-alarm request logic is exercised, not just
    // the non-mobile fallback.
    // -----------------------------------------------------------------------

    group('Android branch', () {
      late MockAndroidPlugin android;

      setUp(() {
        android = MockAndroidPlugin();
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(android);
      });

      test('requests POST_NOTIFICATIONS and exact-alarm permission, and '
          'returns true when granted', () async {
        when(
          () => android.requestNotificationsPermission(),
        ).thenAnswer((_) async => true);
        when(
          () => android.requestExactAlarmsPermission(),
        ).thenAnswer((_) async => true);

        final granted = await gw.requestPermission();

        expect(granted, isTrue);
        verify(() => android.requestNotificationsPermission()).called(1);
        verify(() => android.requestExactAlarmsPermission()).called(1);
      });

      test('threads the granted flag through as false when POST_NOTIFICATIONS '
          'is denied (exact-alarm is still requested, best-effort)', () async {
        when(
          () => android.requestNotificationsPermission(),
        ).thenAnswer((_) async => false);
        when(
          () => android.requestExactAlarmsPermission(),
        ).thenAnswer((_) async => true);

        final granted = await gw.requestPermission();

        expect(granted, isFalse);
        verify(() => android.requestExactAlarmsPermission()).called(1);
      });

      test('treats a null POST_NOTIFICATIONS result as not granted', () async {
        when(
          () => android.requestNotificationsPermission(),
        ).thenAnswer((_) async => null);
        when(
          () => android.requestExactAlarmsPermission(),
        ).thenAnswer((_) async => null);

        expect(await gw.requestPermission(), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // iOS branch (AUD-notifications-10)
    // -----------------------------------------------------------------------

    group('iOS branch', () {
      late MockIOSPlugin ios;

      setUp(() {
        ios = MockIOSPlugin();
        // Android resolves to null (unstubbed generic mocktail call) so the
        // gateway falls through to the iOS branch.
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(ios);
      });

      test('requests alert/badge/sound permissions and returns true when '
          'granted', () async {
        when(
          () => ios.requestPermissions(alert: true, badge: true, sound: true),
        ).thenAnswer((_) async => true);

        final granted = await gw.requestPermission();

        expect(granted, isTrue);
        verify(
          () => ios.requestPermissions(alert: true, badge: true, sound: true),
        ).called(1);
      });

      test('threads the granted flag through as false when denied', () async {
        when(
          () => ios.requestPermissions(alert: true, badge: true, sound: true),
        ).thenAnswer((_) async => false);

        expect(await gw.requestPermission(), isFalse);
      });

      test('treats a null result as not granted', () async {
        when(
          () => ios.requestPermissions(alert: true, badge: true, sound: true),
        ).thenAnswer((_) async => null);

        expect(await gw.requestPermission(), isFalse);
      });
    });
  });

  group('hasPermission', () {
    test(
      'returns true when no Android implementation is available (unit test)',
      () async {
        // Same fallback: gateway returns true for non-Android context.
        expect(await gw.hasPermission(), isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // Android branch (AUD-notifications-10)
    // -----------------------------------------------------------------------

    group('Android branch', () {
      late MockAndroidPlugin android;

      setUp(() {
        android = MockAndroidPlugin();
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(android);
      });

      test(
        'returns true when areNotificationsEnabled() reports true',
        () async {
          when(
            () => android.areNotificationsEnabled(),
          ).thenAnswer((_) async => true);

          expect(await gw.hasPermission(), isTrue);
        },
      );

      test(
        'returns false when areNotificationsEnabled() reports false',
        () async {
          when(
            () => android.areNotificationsEnabled(),
          ).thenAnswer((_) async => false);

          expect(await gw.hasPermission(), isFalse);
        },
      );

      test('treats a null result as not granted', () async {
        when(
          () => android.areNotificationsEnabled(),
        ).thenAnswer((_) async => null);

        expect(await gw.hasPermission(), isFalse);
      });
    });
  });

  // -------------------------------------------------------------------------
  // scheduleDailyReminder
  // -------------------------------------------------------------------------

  group('scheduleDailyReminder', () {
    test('calls zonedSchedule with id=dailyReminderId (0)', () async {
      await gw.scheduleDailyReminder(hour: 8, minute: 30, body: 'Test body');

      final captured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured;

      expect(captured.first, equals(dailyReminderId)); // ID == 0
    });

    test('passes the notification title "Learning Reminder"', () async {
      await gw.scheduleDailyReminder(hour: 8, minute: 0, body: 'My body text');

      final captured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: any<tz.TZDateTime>(named: 'scheduledDate'),
          notificationDetails: any<NotificationDetails>(
            named: 'notificationDetails',
          ),
          androidScheduleMode: any<AndroidScheduleMode>(
            named: 'androidScheduleMode',
          ),
          title: captureAny<String>(named: 'title'),
          body: any<String>(named: 'body'),
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(captured.first, equals('Learning Reminder'));
    });

    test('passes the supplied body text verbatim', () async {
      const expectedBody = 'You have 3 tasks across 2 curricula today';
      await gw.scheduleDailyReminder(hour: 20, minute: 0, body: expectedBody);

      final captured = verify(
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
          body: captureAny<String>(named: 'body'),
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(captured.first, equals(expectedBody));
    });

    test('passes payload = dailyReminderPayload', () async {
      await gw.scheduleDailyReminder(hour: 8, minute: 0, body: 'body');

      final captured = verify(
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

      expect(captured.first, equals(dailyReminderPayload));
    });

    test(
      'passes matchDateTimeComponents = DateTimeComponents.time for daily repeat',
      () async {
        await gw.scheduleDailyReminder(hour: 8, minute: 0, body: 'body');

        final captured = verify(
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
            payload: any<String>(named: 'payload'),
            matchDateTimeComponents: captureAny<DateTimeComponents>(
              named: 'matchDateTimeComponents',
            ),
          ),
        ).captured;

        expect(captured.first, equals(DateTimeComponents.time));
      },
    );

    test('passes androidScheduleMode = exactAllowWhileIdle', () async {
      await gw.scheduleDailyReminder(hour: 8, minute: 0, body: 'body');

      final captured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: any<tz.TZDateTime>(named: 'scheduledDate'),
          notificationDetails: any<NotificationDetails>(
            named: 'notificationDetails',
          ),
          androidScheduleMode: captureAny<AndroidScheduleMode>(
            named: 'androidScheduleMode',
          ),
          title: any<String>(named: 'title'),
          body: any<String>(named: 'body'),
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(captured.first, equals(AndroidScheduleMode.exactAllowWhileIdle));
    });

    test('scheduled time is never in the past', () async {
      // Always pick a time that has already passed today by using hour=0 min=0
      // (midnight of the current day is always in the past unless we are
      // running exactly at midnight).
      await gw.scheduleDailyReminder(hour: 0, minute: 0, body: 'body');

      final captured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: captureAny<tz.TZDateTime>(named: 'scheduledDate'),
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
      ).captured;

      final scheduledDate = captured.first as tz.TZDateTime;
      // Must be in the future (or at worst equal to now — using isAfter with a
      // small grace).
      expect(
        scheduledDate.isAfter(tz.TZDateTime.now(tz.local)),
        isTrue,
        reason:
            'Gateway must roll forward to the next occurrence if the time '
            'has already passed today',
      );
    });

    test(
      'rolls time forward by exactly one day when hour:minute is in the past',
      () async {
        // hour=0, minute=0 is always in the past for any non-midnight run.
        await gw.scheduleDailyReminder(hour: 0, minute: 0, body: 'body');

        final captured = verify(
          () => plugin.zonedSchedule(
            id: any<int>(named: 'id'),
            scheduledDate: captureAny<tz.TZDateTime>(named: 'scheduledDate'),
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
        ).captured;

        final scheduledDate = captured.first as tz.TZDateTime;
        final now = tz.TZDateTime.now(tz.local);
        final tomorrow = now.add(const Duration(days: 1));

        // The scheduled date should land on tomorrow.
        expect(scheduledDate.day, equals(tomorrow.day));
        expect(scheduledDate.hour, equals(0));
        expect(scheduledDate.minute, equals(0));
      },
    );
  });

  // -------------------------------------------------------------------------
  // cancelDailyReminder
  // -------------------------------------------------------------------------

  group('cancelDailyReminder', () {
    test('calls plugin.cancel with id = dailyReminderId (0)', () async {
      await gw.cancelDailyReminder();

      verify(() => plugin.cancel(id: dailyReminderId)).called(1);
    });

    test('does not schedule a new notification', () async {
      await gw.cancelDailyReminder();

      verifyNever(
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
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // reschedule (cancel old + schedule new)
  // -------------------------------------------------------------------------

  group('reschedule daily reminder', () {
    test(
      'scheduling twice calls zonedSchedule twice with the new body each time',
      () async {
        await gw.scheduleDailyReminder(
          hour: 7,
          minute: 0,
          body: 'First schedule',
        );
        await gw.scheduleDailyReminder(
          hour: 8,
          minute: 0,
          body: 'Second schedule',
        );

        // Two separate schedule calls are expected (the gateway does not
        // implicitly cancel before scheduling — callers do that via
        // cancelDailyReminder).
        final bodyCaptured = verify(
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
            body: captureAny<String>(named: 'body'),
            payload: any<String>(named: 'payload'),
            matchDateTimeComponents: any<DateTimeComponents>(
              named: 'matchDateTimeComponents',
            ),
          ),
        ).captured;

        expect(bodyCaptured, hasLength(2));
        expect(bodyCaptured[0], equals('First schedule'));
        expect(bodyCaptured[1], equals('Second schedule'));
      },
    );

    test('cancel then re-schedule: cancel is called with dailyReminderId and '
        'schedule is called with the new body', () async {
      await gw.cancelDailyReminder();
      await gw.scheduleDailyReminder(
        hour: 9,
        minute: 30,
        body: 'After reschedule',
      );

      verify(() => plugin.cancel(id: dailyReminderId)).called(1);

      final bodyCaptured = verify(
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
          body: captureAny<String>(named: 'body'),
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(bodyCaptured.single, equals('After reschedule'));
    });
  });

  // -------------------------------------------------------------------------
  // scheduleBatchReminders
  // -------------------------------------------------------------------------

  group('scheduleBatchReminders', () {
    test(
      'cancels all 14 existing batch IDs before scheduling new ones',
      () async {
        final times = _futureTimes(3);
        await gw.scheduleBatchReminders(
          fireTimes: times,
          title: 'T',
          body: 'B',
        );

        // IDs 10..23 must all be cancelled (batchBaseId=10, batchSize=14).
        for (var i = 10; i < 24; i++) {
          verify(() => plugin.cancel(id: i)).called(1);
        }
      },
    );

    test('schedules one notification per fire-time entry', () async {
      final times = _futureTimes(5);
      await gw.scheduleBatchReminders(
        fireTimes: times,
        title: 'Title',
        body: 'Body',
      );

      verify(
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
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).called(5);
    });

    test('caps at 14 even if more fire-times are supplied', () async {
      final times = _futureTimes(20); // 20 > batchSize
      await gw.scheduleBatchReminders(
        fireTimes: times,
        title: 'Title',
        body: 'Body',
      );

      verify(
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
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).called(14);
    });

    test('schedules nothing when fireTimes is empty', () async {
      await gw.scheduleBatchReminders(fireTimes: [], title: 'T', body: 'B');

      // Only the 14 cancel calls (from cancelBatchReminders) should occur.
      verifyNever(
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
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      );
    });

    test('uses IDs in range 10..23 (batchBaseId + index)', () async {
      final times = _futureTimes(14);
      await gw.scheduleBatchReminders(fireTimes: times, title: 'T', body: 'B');

      final idsCaptured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured.cast<int>();

      final expectedIds = List.generate(14, (i) => 10 + i);
      expect(idsCaptured, equals(expectedIds));
    });

    test(
      'does NOT set matchDateTimeComponents (one-shot, not repeating)',
      () async {
        final times = _futureTimes(2);
        await gw.scheduleBatchReminders(
          fireTimes: times,
          title: 'T',
          body: 'B',
        );

        final matchCaptured = verify(
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
            payload: any<String>(named: 'payload'),
            matchDateTimeComponents: captureAny<DateTimeComponents>(
              named: 'matchDateTimeComponents',
            ),
          ),
        ).captured;

        // matchDateTimeComponents should be null for one-shot batch entries.
        for (final v in matchCaptured) {
          expect(v, isNull);
        }
      },
    );

    test('uses dailyReminderPayload as payload for each entry', () async {
      final times = _futureTimes(3);
      await gw.scheduleBatchReminders(fireTimes: times, title: 'T', body: 'B');

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
      ).captured.cast<String>();

      for (final p in payloadsCaptured) {
        expect(p, equals(dailyReminderPayload));
      }
    });
  });

  // -------------------------------------------------------------------------
  // cancelBatchReminders
  // -------------------------------------------------------------------------

  group('cancelBatchReminders', () {
    test('cancels exactly 14 notifications, IDs 10–23', () async {
      await gw.cancelBatchReminders();

      for (var i = 10; i < 24; i++) {
        verify(() => plugin.cancel(id: i)).called(1);
      }
      // Ensure IDs outside the range are not cancelled.
      verifyNever(() => plugin.cancel(id: 9));
      verifyNever(() => plugin.cancel(id: 24));
    });
  });

  // -------------------------------------------------------------------------
  // scheduleStreakAlert
  // -------------------------------------------------------------------------

  group('scheduleStreakAlert', () {
    test('calls zonedSchedule with id = streakAlertId (1)', () async {
      await gw.scheduleStreakAlert(
        hour: 21,
        minute: 0,
        body: 'Your streak is at risk!',
      );

      final idsCaptured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured;

      expect(idsCaptured.single, equals(streakAlertId)); // == 1
    });

    test('default title is "Streak at Risk!"', () async {
      await gw.scheduleStreakAlert(hour: 21, minute: 0, body: 'body');

      final titlesCaptured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: any<tz.TZDateTime>(named: 'scheduledDate'),
          notificationDetails: any<NotificationDetails>(
            named: 'notificationDetails',
          ),
          androidScheduleMode: any<AndroidScheduleMode>(
            named: 'androidScheduleMode',
          ),
          title: captureAny<String>(named: 'title'),
          body: any<String>(named: 'body'),
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(titlesCaptured.single, equals('Streak at Risk!'));
    });

    test('custom title is forwarded', () async {
      await gw.scheduleStreakAlert(
        hour: 21,
        minute: 0,
        body: 'body',
        title: 'Custom Streak Title',
      );

      final titlesCaptured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: any<tz.TZDateTime>(named: 'scheduledDate'),
          notificationDetails: any<NotificationDetails>(
            named: 'notificationDetails',
          ),
          androidScheduleMode: any<AndroidScheduleMode>(
            named: 'androidScheduleMode',
          ),
          title: captureAny<String>(named: 'title'),
          body: any<String>(named: 'body'),
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: any<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(titlesCaptured.single, equals('Custom Streak Title'));
    });

    test('passes payload = streakAlertPayload', () async {
      await gw.scheduleStreakAlert(hour: 21, minute: 0, body: 'body');

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

      expect(payloadsCaptured.single, equals(streakAlertPayload));
    });

    test('uses matchDateTimeComponents.time for daily repeat', () async {
      await gw.scheduleStreakAlert(hour: 21, minute: 0, body: 'body');

      final matchCaptured = verify(
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
          payload: any<String>(named: 'payload'),
          matchDateTimeComponents: captureAny<DateTimeComponents>(
            named: 'matchDateTimeComponents',
          ),
        ),
      ).captured;

      expect(matchCaptured.single, equals(DateTimeComponents.time));
    });

    test('scheduled time is never in the past', () async {
      await gw.scheduleStreakAlert(hour: 0, minute: 0, body: 'body');

      final scheduledCaptured = verify(
        () => plugin.zonedSchedule(
          id: any<int>(named: 'id'),
          scheduledDate: captureAny<tz.TZDateTime>(named: 'scheduledDate'),
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
      ).captured;

      final scheduledDate = scheduledCaptured.single as tz.TZDateTime;
      expect(scheduledDate.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // cancelStreakAlert
  // -------------------------------------------------------------------------

  group('cancelStreakAlert', () {
    test('calls plugin.cancel with id = streakAlertId (1)', () async {
      await gw.cancelStreakAlert();

      verify(() => plugin.cancel(id: streakAlertId)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // per-profile daily reminder
  // -------------------------------------------------------------------------

  group('scheduleDailyReminderForProfile', () {
    test('uses id = profileId * 1000 for profile 0', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: 0,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );

      final idsCaptured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured;

      expect(idsCaptured.single, equals(dailyReminderIdForProfile(0)));
    });

    test('uses id = 1000 for profile 1', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: 1,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );

      final idsCaptured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured;

      expect(idsCaptured.single, equals(1000));
    });

    test('embeds profileId in payload: "daily_reminder:<profileId>"', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: 7,
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

      expect(payloadsCaptured.single, equals('$dailyReminderPayload:7'));
    });

    test('different profiles produce different notification IDs', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: 2,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );
      await gw.scheduleDailyReminderForProfile(
        profileId: 3,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );

      final idsCaptured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured.cast<int>();

      expect(idsCaptured[0], isNot(equals(idsCaptured[1])));
    });
  });

  group('cancelDailyReminderForProfile', () {
    test('cancels id = profileId * 1000', () async {
      await gw.cancelDailyReminderForProfile(3);

      verify(() => plugin.cancel(id: 3000)).called(1);
    });

    test('does not cancel profile 0 when cancelling profile 1', () async {
      await gw.cancelDailyReminderForProfile(1);

      verify(() => plugin.cancel(id: 1000)).called(1);
      verifyNever(() => plugin.cancel(id: 0));
    });
  });

  // -------------------------------------------------------------------------
  // per-profile batch reminders
  // -------------------------------------------------------------------------

  group('scheduleBatchRemindersForProfile', () {
    test('cancels profile batch range before scheduling', () async {
      final times = _futureTimes(3);
      // Profile 1: batchBase = 1010
      await gw.scheduleBatchRemindersForProfile(
        profileId: 1,
        fireTimes: times,
        title: 'T',
        body: 'B',
      );

      for (var i = 1010; i < 1024; i++) {
        verify(() => plugin.cancel(id: i)).called(1);
      }
    });

    test('schedules with correct IDs for profile 2 (base 2010)', () async {
      final times = _futureTimes(3);
      await gw.scheduleBatchRemindersForProfile(
        profileId: 2,
        fireTimes: times,
        title: 'T',
        body: 'B',
      );

      final idsCaptured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured.cast<int>();

      expect(idsCaptured, equals([2010, 2011, 2012]));
    });

    test('embeds profileId in payload for each batch entry', () async {
      final times = _futureTimes(2);
      await gw.scheduleBatchRemindersForProfile(
        profileId: 5,
        fireTimes: times,
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
      ).captured.cast<String>();

      for (final p in payloadsCaptured) {
        expect(p, equals('$dailyReminderPayload:5'));
      }
    });

    test('no overlap between profile 0 and profile 1 batch IDs', () {
      final ids0 = List.generate(
        14,
        (i) => batchBaseIdForProfile(0) + i,
      ).toSet();
      final ids1 = List.generate(
        14,
        (i) => batchBaseIdForProfile(1) + i,
      ).toSet();
      expect(ids0.intersection(ids1), isEmpty);
    });
  });

  group('cancelBatchRemindersForProfile', () {
    test('cancels IDs in range batchBaseIdForProfile(0)..+14', () async {
      await gw.cancelBatchRemindersForProfile(0);

      for (var i = 10; i < 24; i++) {
        verify(() => plugin.cancel(id: i)).called(1);
      }
    });

    test('cancels IDs in range batchBaseIdForProfile(1)..+14', () async {
      await gw.cancelBatchRemindersForProfile(1);

      for (var i = 1010; i < 1024; i++) {
        verify(() => plugin.cancel(id: i)).called(1);
      }
      // Profile 0 IDs untouched.
      verifyNever(() => plugin.cancel(id: 10));
    });
  });

  // -------------------------------------------------------------------------
  // per-profile streak alert
  // -------------------------------------------------------------------------

  group('scheduleStreakAlertForProfile', () {
    test('uses id = profileId * 1000 + 1', () async {
      await gw.scheduleStreakAlertForProfile(
        profileId: 4,
        hour: 21,
        minute: 0,
        body: 'body',
      );

      final idsCaptured = verify(
        () => plugin.zonedSchedule(
          id: captureAny<int>(named: 'id'),
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
      ).captured;

      expect(idsCaptured.single, equals(streakAlertIdForProfile(4)));
    });

    test(
      'embeds profileId in payload: "streak_protection:<profileId>"',
      () async {
        await gw.scheduleStreakAlertForProfile(
          profileId: 9,
          hour: 21,
          minute: 0,
          body: 'body',
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

        expect(payloadsCaptured.single, equals('$streakAlertPayload:9'));
      },
    );

    test('different profiles produce non-overlapping streak IDs', () {
      final id0 = streakAlertIdForProfile(0);
      final id1 = streakAlertIdForProfile(1);
      expect(id0, isNot(equals(id1)));
      // streak IDs must not collide with daily reminder IDs.
      expect(id0, isNot(equals(dailyReminderIdForProfile(0))));
    });
  });

  group('cancelStreakAlertForProfile', () {
    test('cancels id = profileId * 1000 + 1', () async {
      await gw.cancelStreakAlertForProfile(2);

      // streakAlertIdForProfile(2) == 2001
      verify(() => plugin.cancel(id: 2001)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // ID allocation helpers (pure maths — no plugin calls)
  // -------------------------------------------------------------------------

  group('ID allocation helpers', () {
    test('dailyReminderIdForProfile(N) = N * 1000', () {
      expect(dailyReminderIdForProfile(0), equals(0));
      expect(dailyReminderIdForProfile(1), equals(1000));
      expect(dailyReminderIdForProfile(10), equals(10000));
    });

    test('streakAlertIdForProfile(N) = N * 1000 + 1', () {
      expect(streakAlertIdForProfile(0), equals(1));
      expect(streakAlertIdForProfile(1), equals(1001));
      expect(streakAlertIdForProfile(5), equals(5001));
    });

    test('batchBaseIdForProfile(N) = N * 1000 + 10', () {
      expect(batchBaseIdForProfile(0), equals(10));
      expect(batchBaseIdForProfile(1), equals(1010));
      expect(batchBaseIdForProfile(3), equals(3010));
    });

    test('legacy dailyReminderId == dailyReminderIdForProfile(0)', () {
      expect(dailyReminderId, equals(dailyReminderIdForProfile(0)));
    });

    test('legacy streakAlertId == streakAlertIdForProfile(0)', () {
      expect(streakAlertId, equals(streakAlertIdForProfile(0)));
    });

    test('no overlap between any two adjacent profile batch ranges', () {
      for (var p = 0; p < 5; p++) {
        final baseA = batchBaseIdForProfile(p);
        final baseB = batchBaseIdForProfile(p + 1);
        final idsA = List.generate(14, (i) => baseA + i).toSet();
        final idsB = List.generate(14, (i) => baseB + i).toSet();
        expect(idsA.intersection(idsB), isEmpty);
      }
    });

    test(
      'streak ID does not overlap with daily or batch IDs for any profile',
      () {
        for (var p = 0; p < 5; p++) {
          final streakId = streakAlertIdForProfile(p);
          final dailyId = dailyReminderIdForProfile(p);
          final batchIds = List.generate(
            14,
            (i) => batchBaseIdForProfile(p) + i,
          ).toSet();
          expect(streakId, isNot(equals(dailyId)));
          expect(batchIds, isNot(contains(streakId)));
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Payload constants
  // -------------------------------------------------------------------------

  group('payload constants', () {
    test('dailyReminderPayload is "daily_reminder"', () {
      expect(dailyReminderPayload, equals('daily_reminder'));
    });

    test('streakAlertPayload is "streak_protection"', () {
      expect(streakAlertPayload, equals('streak_protection'));
    });

    test(
      'per-profile payloads can be parsed to extract profileId after ":"',
      () {
        const profileId = 42;
        const daily = '$dailyReminderPayload:$profileId';
        const streak = '$streakAlertPayload:$profileId';

        expect(int.tryParse(daily.split(':').last), equals(profileId));
        expect(int.tryParse(streak.split(':').last), equals(profileId));
      },
    );
  });
}
