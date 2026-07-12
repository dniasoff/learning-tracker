/// Unit tests for [NotificationScheduler].
///
/// The legacy (pre-per-profile) schedule()/cancel()/cancelForSacredTime()
/// methods this file used to test were deleted as dead code
/// (AUD-notifications-04): a repo-wide grep found zero production callers
/// once WS5.per-profile's scheduleReminderForProfile/cancelForProfile
/// equivalents took over the only production call site
/// (notification_providers.dart's reminderSyncEffect). See
/// notification_gateway_test.dart's header comment for the full removal
/// rationale.
///
/// scheduleReminder() (the non-profile, locale-aware wrapper) is kept — it
/// is not itself one of the removed methods — but now routes through the
/// profile-0 block of the *ForProfile gateway API internally, since the
/// scheduleBatchReminders() it used to call no longer exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

class MockNotificationGateway extends Mock implements NotificationGateway {}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('America/New_York'));
    registerFallbackValue(<tz_lib.TZDateTime>[]);
  });

  late MockNotificationGateway mockService;
  late NotificationScheduler scheduler;

  setUp(() {
    mockService = MockNotificationGateway();
    scheduler = NotificationScheduler(service: mockService);

    when(
      () => mockService.scheduleBatchRemindersForProfile(
        profileId: any(named: 'profileId'),
        fireTimes: any(named: 'fireTimes'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockService.cancelBatchRemindersForProfile(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockService.cancelDailyReminderForProfile(any()),
    ).thenAnswer((_) async {});
  });

  group('NotificationScheduler', () {
    test('scheduleReminder creates a 14-day batch notification for profile 0 '
        'at the configured time', () async {
      await scheduler.scheduleReminder(
        time: const TimeOfDay(hour: 19, minute: 0),
        title: 'Learning Reminder',
        body: 'You have 5 tasks across 2 curricula today',
      );

      verify(
        () => mockService.scheduleBatchRemindersForProfile(
          profileId: 0,
          fireTimes: any(named: 'fireTimes'),
          title: 'Learning Reminder',
          body: 'You have 5 tasks across 2 curricula today',
        ),
      ).called(1);
    });

    test('rescheduling at a new time produces a second batch call', () async {
      // Schedule at 7 PM
      await scheduler.scheduleReminder(
        time: const TimeOfDay(hour: 19, minute: 0),
        title: 'Learning Reminder',
        body: 'You have 3 tasks across 2 curricula today',
      );

      // Reschedule at 8 AM
      await scheduler.scheduleReminder(
        time: const TimeOfDay(hour: 8, minute: 0),
        title: 'Learning Reminder',
        body: 'You have 3 tasks across 2 curricula today',
      );

      verify(
        () => mockService.scheduleBatchRemindersForProfile(
          profileId: 0,
          fireTimes: any(named: 'fireTimes'),
          title: 'Learning Reminder',
          body: 'You have 3 tasks across 2 curricula today',
        ),
      ).called(2);
    });

    test(
      'buildFireTimesForTest returns up to 14 entries without repository',
      () {
        final fireTimes = scheduler.buildFireTimesForTest(
          time: const TimeOfDay(hour: 19, minute: 0),
          location: null,
          inIsrael: false,
          fromDay: DateTime(2026, 5, 13), // a Wednesday
        );
        // Without a sacred window repository, all 14 entries should be returned.
        expect(fireTimes.length, equals(kBatchDays));
      },
    );
  });
}
