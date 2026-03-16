import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockNotificationService mockService;
  late NotificationScheduler scheduler;

  setUp(() {
    mockService = MockNotificationService();
    scheduler = NotificationScheduler(service: mockService);
  });

  group('NotificationScheduler', () {
    test(
      'schedule creates daily repeating notification at configured time',
      () async {
        when(
          () => mockService.scheduleDailyReminder(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});

        await scheduler.schedule(
          time: const TimeOfDay(hour: 19, minute: 0),
          taskCount: 5,
          curriculumCount: 2,
        );

        verify(
          () => mockService.scheduleDailyReminder(
            hour: 19,
            minute: 0,
            body: 'You have 5 tasks across 2 curricula today',
          ),
        ).called(1);
      },
    );

    test(
      'notification body includes correct task count from scheduler',
      () async {
        when(
          () => mockService.scheduleDailyReminder(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});

        await scheduler.schedule(
          time: const TimeOfDay(hour: 8, minute: 30),
          taskCount: 1,
          curriculumCount: 1,
        );

        verify(
          () => mockService.scheduleDailyReminder(
            hour: 8,
            minute: 30,
            body: 'You have 1 task across 1 curriculum today',
          ),
        ).called(1);
      },
    );

    test('time change updates scheduled notification', () async {
      when(
        () => mockService.scheduleDailyReminder(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});

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
        () => mockService.scheduleDailyReminder(
          hour: 8,
          minute: 0,
          body: 'You have 3 tasks across 2 curricula today',
        ),
      ).called(1);
    });

    test('cancel removes the daily reminder', () async {
      when(() => mockService.cancelDailyReminder()).thenAnswer((_) async {});

      await scheduler.cancel();

      verify(() => mockService.cancelDailyReminder()).called(1);
    });

    test('zero tasks produces correct body', () async {
      when(
        () => mockService.scheduleDailyReminder(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});

      await scheduler.schedule(
        time: const TimeOfDay(hour: 19, minute: 0),
        taskCount: 0,
        curriculumCount: 0,
      );

      verify(
        () => mockService.scheduleDailyReminder(
          hour: 19,
          minute: 0,
          body: 'You have 0 tasks across 0 curricula today',
        ),
      ).called(1);
    });
  });
}
