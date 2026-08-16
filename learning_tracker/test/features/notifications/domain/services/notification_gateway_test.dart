/// Unit tests for [NotificationGateway].
///
/// Mocks [FlutterLocalNotificationsPlugin] at the plugin boundary so no real
/// platform code runs.  Covers:
///   - initialize (success / null / callback wiring)
///   - per-profile daily reminder (ULID-hash-derived ID, payload carries
///     profileId)
///   - per-profile batch (ULID-hash-derived base ID, payload carries
///     profileId)
///   - cancelDailyReminderForProfile / cancelBatchRemindersForProfile
///   - per-profile streak alert (ULID-hash-derived ID, payload carries
///     profileId)
///   - cancelStreakAlertForProfile
///   - requestPermission: non-mobile fallback, Android branch (permission +
///     exact-alarm requests, granted flag threaded through), iOS branch
///     (alert/badge/sound request, granted flag threaded through)
///   - hasPermission: non-mobile fallback, Android branch
///     (areNotificationsEnabled threaded through)
///   - _nextInstanceOfTime: scheduled time is never in the past; if the
///     requested hour:minute is in the past it rolls forward one day
///   - ID allocation helpers (unit maths, no platform)
///
/// The legacy (pre-per-profile) scheduleDailyReminder/cancelDailyReminder/
/// scheduleBatchReminders/cancelBatchReminders/scheduleStreakAlert/
/// cancelStreakAlert methods and the dailyReminderId/streakAlertId singleton
/// constants were deleted as dead code (AUD-notifications-04): a repo-wide
/// grep found zero production callers once WS5.per-profile's *ForProfile
/// equivalents took over every call site. Their test coverage below was
/// removed with them; the *ForProfile groups already covered the same
/// scheduling behaviour.
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

const _profile0 = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _profile1 = '01ARZ3NDEKTSV4RRFFQ69G5FB0';
const _profile2 = '01ARZ3NDEKTSV4RRFFQ69G5FB1';
const _profile3 = '01ARZ3NDEKTSV4RRFFQ69G5FB2';
const _profile4 = '01ARZ3NDEKTSV4RRFFQ69G5FB3';
const _profile5 = '01ARZ3NDEKTSV4RRFFQ69G5FB4';
const _profile7 = '01ARZ3NDEKTSV4RRFFQ69G5FB6';
const _profile9 = '01ARZ3NDEKTSV4RRFFQ69G5FB8';
const _profile10 = '01ARZ3NDEKTSV4RRFFQ69G5FB9';
const _profile42 = '01ARZ3NDEKTSV4RRFFQ69G5FC0';

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
  // per-profile daily reminder
  // -------------------------------------------------------------------------

  group('scheduleDailyReminderForProfile', () {
    test('uses the deterministic ULID-derived ID for profile 0', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: _profile0,
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

      expect(idsCaptured.single, equals(1523713000));
    });

    test('uses the deterministic ULID-derived ID for profile 1', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: _profile1,
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

      expect(idsCaptured.single, equals(28042000));
    });

    test('embeds profileId in payload: "daily_reminder:<profileId>"', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: _profile7,
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

      expect(
        payloadsCaptured.single,
        equals('$dailyReminderPayload:$_profile7'),
      );
    });

    test('different profiles produce different notification IDs', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: _profile2,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
      );
      await gw.scheduleDailyReminderForProfile(
        profileId: _profile3,
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

    // _nextInstanceOfTime is shared private logic used by every zonedSchedule
    // call site on the gateway (both daily-reminder and streak-alert). These
    // two cases used to be attached to the now-deleted scheduleDailyReminder;
    // re-attached here to scheduleDailyReminderForProfile so the rollover
    // behaviour keeps coverage (AUD-notifications-04).
    test('scheduled time is never in the past', () async {
      await gw.scheduleDailyReminderForProfile(
        profileId: _profile0,
        hour: 0,
        minute: 0,
        title: 'T',
        body: 'B',
      );

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
        await gw.scheduleDailyReminderForProfile(
          profileId: _profile0,
          hour: 0,
          minute: 0,
          title: 'T',
          body: 'B',
        );

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

        expect(scheduledDate.day, equals(tomorrow.day));
        expect(scheduledDate.hour, equals(0));
        expect(scheduledDate.minute, equals(0));
      },
    );
  });

  group('cancelDailyReminderForProfile', () {
    test('cancels the deterministic ID for the profile', () async {
      await gw.cancelDailyReminderForProfile(_profile3);

      verify(() => plugin.cancel(id: 472804000)).called(1);
    });

    test('does not cancel profile 0 when cancelling profile 1', () async {
      await gw.cancelDailyReminderForProfile(_profile1);

      verify(() => plugin.cancel(id: 28042000)).called(1);
      verifyNever(() => plugin.cancel(id: 1523713000));
    });
  });

  // -------------------------------------------------------------------------
  // per-profile batch reminders
  // -------------------------------------------------------------------------

  group('scheduleBatchRemindersForProfile', () {
    test('cancels profile batch range before scheduling', () async {
      final times = _futureTimes(3);
      // Profile 1's base is derived from its ULID hash.
      await gw.scheduleBatchRemindersForProfile(
        profileId: _profile1,
        fireTimes: times,
        title: 'T',
        body: 'B',
      );

      final base = batchBaseIdForProfile(_profile1);
      for (var i = 0; i < 14; i++) {
        verify(() => plugin.cancel(id: base + i)).called(1);
      }
    });

    test('schedules with correct IDs for profile 2', () async {
      final times = _futureTimes(3);
      await gw.scheduleBatchRemindersForProfile(
        profileId: _profile2,
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

      final base = batchBaseIdForProfile(_profile2);
      expect(idsCaptured, equals([base, base + 1, base + 2]));
    });

    test('embeds profileId in payload for each batch entry', () async {
      final times = _futureTimes(2);
      await gw.scheduleBatchRemindersForProfile(
        profileId: _profile5,
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
        expect(p, equals('$dailyReminderPayload:$_profile5'));
      }
    });

    test('no overlap between profile 0 and profile 1 batch IDs', () {
      final ids0 = List.generate(
        14,
        (i) => batchBaseIdForProfile(_profile0) + i,
      ).toSet();
      final ids1 = List.generate(
        14,
        (i) => batchBaseIdForProfile(_profile1) + i,
      ).toSet();
      expect(ids0.intersection(ids1), isEmpty);
    });
  });

  group('cancelBatchRemindersForProfile', () {
    test(
      'cancels IDs in range batchBaseIdForProfile(_profile0)..+14',
      () async {
        await gw.cancelBatchRemindersForProfile(_profile0);

        final base = batchBaseIdForProfile(_profile0);
        for (var i = 0; i < 14; i++) {
          verify(() => plugin.cancel(id: base + i)).called(1);
        }
      },
    );

    test(
      'cancels IDs in range batchBaseIdForProfile(_profile1)..+14',
      () async {
        await gw.cancelBatchRemindersForProfile(_profile1);

        final base = batchBaseIdForProfile(_profile1);
        for (var i = 0; i < 14; i++) {
          verify(() => plugin.cancel(id: base + i)).called(1);
        }
        // Profile 0 IDs untouched.
        verifyNever(() => plugin.cancel(id: batchBaseIdForProfile(_profile0)));
      },
    );
  });

  // -------------------------------------------------------------------------
  // per-profile streak alert
  // -------------------------------------------------------------------------

  group('scheduleStreakAlertForProfile', () {
    test('uses the deterministic ULID-derived streak ID', () async {
      await gw.scheduleStreakAlertForProfile(
        profileId: _profile4,
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

      expect(idsCaptured.single, equals(1695185001));
    });

    test(
      'embeds profileId in payload: "streak_protection:<profileId>"',
      () async {
        await gw.scheduleStreakAlertForProfile(
          profileId: _profile9,
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

        expect(
          payloadsCaptured.single,
          equals('$streakAlertPayload:$_profile9'),
        );
      },
    );

    test('different profiles produce non-overlapping streak IDs', () {
      final id0 = streakAlertIdForProfile(_profile0);
      final id1 = streakAlertIdForProfile(_profile1);
      expect(id0, isNot(equals(id1)));
      // streak IDs must not collide with daily reminder IDs.
      expect(id0, isNot(equals(dailyReminderIdForProfile(_profile0))));
    });
  });

  group('cancelStreakAlertForProfile', () {
    test('cancels the deterministic streak ID for the profile', () async {
      await gw.cancelStreakAlertForProfile(_profile2);

      verify(() => plugin.cancel(id: 1250423001)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // ID allocation helpers (pure maths — no plugin calls)
  // -------------------------------------------------------------------------

  group('ID allocation helpers', () {
    test('dailyReminderIdForProfile derives IDs from the ULID hash', () {
      expect(dailyReminderIdForProfile(_profile0), equals(1523713000));
      expect(dailyReminderIdForProfile(_profile1), equals(28042000));
      expect(dailyReminderIdForProfile(_profile10), equals(1471375000));
    });

    test('streakAlertIdForProfile derives IDs from the ULID hash', () {
      expect(streakAlertIdForProfile(_profile0), equals(1523713001));
      expect(streakAlertIdForProfile(_profile1), equals(28042001));
      expect(streakAlertIdForProfile(_profile5), equals(1138518001));
    });

    test('batchBaseIdForProfile derives IDs from the ULID hash', () {
      expect(batchBaseIdForProfile(_profile0), equals(1523713010));
      expect(batchBaseIdForProfile(_profile1), equals(28042010));
      expect(batchBaseIdForProfile(_profile3), equals(472804010));
    });

    test('no overlap between any two selected profile batch ranges', () {
      const profileIds = [
        _profile0,
        _profile1,
        _profile2,
        _profile3,
        _profile4,
      ];
      for (var p = 0; p < profileIds.length - 1; p++) {
        final baseA = batchBaseIdForProfile(profileIds[p]);
        final baseB = batchBaseIdForProfile(profileIds[p + 1]);
        final idsA = List.generate(14, (i) => baseA + i).toSet();
        final idsB = List.generate(14, (i) => baseB + i).toSet();
        expect(idsA.intersection(idsB), isEmpty);
      }
    });

    test(
      'streak ID does not overlap with daily or batch IDs for any profile',
      () {
        const profileIds = [
          _profile0,
          _profile1,
          _profile2,
          _profile3,
          _profile4,
        ];
        for (final profileId in profileIds) {
          final streakId = streakAlertIdForProfile(profileId);
          final dailyId = dailyReminderIdForProfile(profileId);
          final batchIds = List.generate(
            14,
            (i) => batchBaseIdForProfile(profileId) + i,
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
        const profileId = _profile42;
        const daily = '$dailyReminderPayload:$profileId';
        const streak = '$streakAlertPayload:$profileId';

        expect(daily.split(':').last, equals(profileId));
        expect(streak.split(':').last, equals(profileId));
      },
    );
  });
}
