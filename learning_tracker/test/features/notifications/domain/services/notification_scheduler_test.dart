import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
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
      () => mockService.scheduleBatchReminders(
        fireTimes: any(named: 'fireTimes'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});

    when(() => mockService.cancelBatchReminders()).thenAnswer((_) async {});
    when(() => mockService.cancelDailyReminder()).thenAnswer((_) async {});
  });

  group('NotificationScheduler', () {
    test(
      'schedule creates 14-day batch notification at configured time',
      () async {
        await scheduler.schedule(
          time: const TimeOfDay(hour: 19, minute: 0),
          taskCount: 5,
          curriculumCount: 2,
        );

        verify(
          () => mockService.scheduleBatchReminders(
            fireTimes: any(named: 'fireTimes'),
            title: 'Learning Reminder',
            body: 'You have 5 tasks across 2 curricula today',
          ),
        ).called(1);
      },
    );

    test(
      'notification body includes correct task count from scheduler',
      () async {
        await scheduler.schedule(
          time: const TimeOfDay(hour: 8, minute: 30),
          taskCount: 1,
          curriculumCount: 1,
        );

        verify(
          () => mockService.scheduleBatchReminders(
            fireTimes: any(named: 'fireTimes'),
            title: 'Learning Reminder',
            body: 'You have 1 task across 1 curriculum today',
          ),
        ).called(1);
      },
    );

    test('time change updates scheduled notification batch', () async {
      // Schedule at 7 PM
      await scheduler.schedule(
        time: const TimeOfDay(hour: 19, minute: 0),
        taskCount: 3,
        curriculumCount: 2,
      );

      // Reschedule at 8 AM
      await scheduler.schedule(
        time: const TimeOfDay(hour: 8, minute: 0),
        taskCount: 3,
        curriculumCount: 2,
      );

      verify(
        () => mockService.scheduleBatchReminders(
          fireTimes: any(named: 'fireTimes'),
          title: 'Learning Reminder',
          body: 'You have 3 tasks across 2 curricula today',
        ),
      ).called(2);
    });

    test('cancel removes the daily reminder and batch', () async {
      await scheduler.cancel();

      verify(() => mockService.cancelDailyReminder()).called(1);
      verify(() => mockService.cancelBatchReminders()).called(1);
    });

    test('zero tasks produces correct body', () async {
      await scheduler.schedule(
        time: const TimeOfDay(hour: 19, minute: 0),
        taskCount: 0,
        curriculumCount: 0,
      );

      verify(
        () => mockService.scheduleBatchReminders(
          fireTimes: any(named: 'fireTimes'),
          title: 'Learning Reminder',
          body: 'You have 0 tasks across 0 curricula today',
        ),
      ).called(1);
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
