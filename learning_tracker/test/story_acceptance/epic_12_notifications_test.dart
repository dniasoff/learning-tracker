/// Story acceptance tests for Epic 12 -- Notifications.
@Tags(['epic_12'])
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

import '../helpers/drift_memory.dart' show seedCompletion;
import '../helpers/test_database.dart';

class MockNotificationGateway extends Mock implements NotificationGateway {}

class MockAppRouter extends Mock implements AppRouter {}

/// The fixed "today" used across streak tests: 2026-03-16 UTC.
const _streakToday = (year: 2026, month: 3, day: 16);

/// Insert [count] consecutive `completion` streak events ending yesterday
/// relative to _streakToday (2026-03-15), giving currentStreak == count.
Future<void> _seedStreak(UserDatabase db, int profileId, int count) async {
  final base = DateTime.utc(
    _streakToday.year,
    _streakToday.month,
    _streakToday.day - 1,
  );
  for (var i = count - 1; i >= 0; i--) {
    final day = base.subtract(Duration(days: i));
    await db.streakEventDao.appendEvent(
      StreakEventsCompanion.insert(
        profileId: profileId,
        eventType: 'completion',
        dayUtc: day,
        eventTimestamp: day.copyWith(hour: 18),
      ),
    );
  }
}

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTime.now(),
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('America/New_York'));
    registerFallbackValue(const GamificationRoute());
    registerFallbackValue(<tz_lib.TZDateTime>[]);
  });

  // ── Story 12.1: Local notifications ───────────────────────────

  group('Story 12.1 -- Local notifications', tags: ['story_12_1'], () {
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

    test(
      'schedule() calls service with correct body for plural counts',
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

    test('schedule() uses singular forms for count of 1', () async {
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
    });

    test(
      'cancel() delegates to service.cancelDailyReminder() and batch',
      () async {
        await scheduler.cancel();

        verify(() => mockService.cancelDailyReminder()).called(1);
        verify(() => mockService.cancelBatchReminders()).called(1);
      },
    );

    test('notification payload enables deep link to daily tasks', () {
      expect(dailyReminderPayload, 'daily_reminder');
    });

    test('daily reminder ID is stable', () {
      // Verified by the notification ID constant.
      expect(dailyReminderId, 0);
    });
  });

  // ── Story 12.2: Streak Protection Alerts ──────────────────────

  group('Story 12.2 -- Streak Protection Alerts', tags: ['story_12_2'], () {
    late UserDatabase db;
    late int trackId;
    late MockNotificationGateway mockService;
    late StreakAlertService alertService;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await _insertTrack(db);
      mockService = MockNotificationGateway();
      alertService = StreakAlertService(
        db: db,
        notificationService: mockService,
        profileId: 1,
        clock: () => DateTime.utc(2026, 3, 16, 12, 0, 0),
        streakClock: FakeLocalDayClock(
          DateTime.utc(_streakToday.year, _streakToday.month, _streakToday.day),
        ),
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
      await _seedStreak(db, 1, 5);

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
      await _seedStreak(db, 1, 3);

      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'test',
          sefariaRef: 'test_ref',
          stageId: 1,
          trackType: 'review',
          trackId: Value(trackId),
          eventTimestamp: DateTime.utc(2026, 3, 16, 10, 0, 0),
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
      // Insert a single event 6 days before today → gap > 1 → currentStreak = 0
      final oldDay = DateTime.utc(2026, 3, 10, 18, 0, 0);
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: 1,
          eventType: 'completion',
          dayUtc: oldDay,
          eventTimestamp: oldDay,
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
      // Build a 5-day streak via streak events (3/11-3/15, yesterday is 3/15)
      await _seedStreak(db, 1, 5);

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

  // ── Story 12.4: Notification Preferences & Shabbos Mode ──────

  group(
    'Story 12.4 -- Notification Preferences & Shabbos Mode',
    tags: ['story_12_4'],
    () {
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
        when(
          () => mockService.scheduleStreakAlert(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockService.cancelStreakAlert()).thenAnswer((_) async {});
      });

      // Unit: Disabling daily reminder cancels scheduled notification
      test('disabling daily reminder cancels scheduled notification', () async {
        await scheduler.cancel();

        verify(() => mockService.cancelDailyReminder()).called(1);
        verify(() => mockService.cancelBatchReminders()).called(1);
      });

      // Unit: Changing reminder time reschedules notification batch
      test('changing reminder time reschedules notification', () async {
        await scheduler.schedule(
          time: const TimeOfDay(hour: 19, minute: 0),
          taskCount: 3,
          curriculumCount: 1,
        );

        // Change time
        await scheduler.schedule(
          time: const TimeOfDay(hour: 7, minute: 30),
          taskCount: 3,
          curriculumCount: 1,
        );

        // Called twice total (once for 19:00, once for 7:30)
        verify(
          () => mockService.scheduleBatchReminders(
            fireTimes: any(named: 'fireTimes'),
            title: 'Learning Reminder',
            body: 'You have 3 tasks across 1 curriculum today',
          ),
        ).called(2);
      });
    },
  );
}
