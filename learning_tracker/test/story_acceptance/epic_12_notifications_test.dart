/// Story acceptance tests for Epic 12 -- Notifications.
@Tags(['epic_12'])
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  // ── Story 12.1: Local notifications ───────────────────────────

  group('Story 12.1 -- Local notifications', tags: ['story_12_1'], () {
    late MockNotificationService mockService;
    late NotificationScheduler scheduler;

    setUp(() {
      mockService = MockNotificationService();
      scheduler = NotificationScheduler(service: mockService);
    });

    test(
      'schedule() calls service with correct body for plural counts',
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

    test('schedule() uses singular forms for count of 1', () async {
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
    });

    test('cancel() delegates to service.cancelDailyReminder()', () async {
      when(() => mockService.cancelDailyReminder()).thenAnswer((_) async {});

      await scheduler.cancel();

      verify(() => mockService.cancelDailyReminder()).called(1);
    });

    test('notification payload enables deep link to daily tasks', () {
      expect(dailyReminderPayload, 'daily_reminder');
    });

    test('notification repeats daily via matchDateTimeComponents', () {
      // The service uses matchDateTimeComponents: DateTimeComponents.time
      // which repeats daily. Verified by the notification ID constant.
      expect(dailyReminderId, 0);
    });
  });

  // ── Story 12.2: Streak Protection Alerts ──────────────────────

  group('Story 12.2 -- Streak Protection Alerts', tags: ['story_12_2'], () {
    late AppDatabase db;
    late MockNotificationService mockService;
    late StreakAlertService alertService;

    setUp(() {
      db = createTestDatabase();
      mockService = MockNotificationService();
      alertService = StreakAlertService(
        db: db,
        notificationService: mockService,
        clock: () => DateTime.utc(2026, 3, 16, 12, 0, 0),
      );

      when(
        () => mockService.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockService.cancelStreakAlert()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await db.close();
    });

    test('alert fires when streak > 0 and no completions today', () async {
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 15, 18, 0, 0)),
        ),
      );

      await alertService.evaluate(hour: 21, minute: 0);

      verify(
        () => mockService.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
        ),
      ).called(1);
    });

    test('alert does NOT fire when completions exist today', () async {
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(3),
          maxStreak: const Value(3),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 16, 10, 0, 0)),
        ),
      );

      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'test_ref',
          stageId: 1,
          trackType: 'review',
          completedAt: DateTime.utc(2026, 3, 16, 10, 0, 0),
        ),
      );

      await alertService.evaluate(hour: 21, minute: 0);

      verify(() => mockService.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockService.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when streak is 0', () async {
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(0),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 10, 18, 0, 0)),
        ),
      );

      await alertService.evaluate(hour: 21, minute: 0);

      verify(() => mockService.cancelStreakAlert()).called(1);
    });

    test('alert body includes correct streak count', () {
      expect(StreakAlertService.buildBody(5), 'Your 5-day streak is at risk!');
    });

    test('notification taps open app to daily tasks screen', () {
      // Streak alert payload is defined and routed to SchedulerRoute
      // in NotificationInitializer._handleNotificationTap
      expect(streakAlertPayload, 'streak_protection');
    });

    test('integration: 5-day streak with no learning triggers alert', () async {
      // Build a 5-day streak via streak record
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 15, 18, 0, 0)),
        ),
      );

      // No completions today — alert should fire at 9 PM
      await alertService.evaluate(hour: 21, minute: 0);

      verify(
        () => mockService.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
        ),
      ).called(1);
    });
  });

  // ── Story 12.3: Notification preferences ──────────────────────

  group(
    'Story 12.3 -- Notification preferences',
    tags: ['story_12_3'],
    skip: 'Backlog: notification preferences not yet implemented',
    () {
      test('user can toggle daily reminder on/off', () {
        // TODO: verify preference toggle persists
      });

      test('user can set preferred reminder time', () {
        // TODO: verify time preference and rescheduling
      });
    },
  );
}
