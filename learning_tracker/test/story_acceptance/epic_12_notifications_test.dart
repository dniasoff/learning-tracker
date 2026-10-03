/// Story acceptance coverage for Epic 12 — notifications.
@Tags(['epic_12'])
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _MockNotificationGateway extends Mock implements NotificationGateway {}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    registerFallbackValue(<tz.TZDateTime>[]);
  });

  group('Story 12.1 — local notifications', tags: ['story_12_1'], () {
    late _MockNotificationGateway gateway;
    late NotificationScheduler scheduler;

    setUp(() {
      gateway = _MockNotificationGateway();
      scheduler = NotificationScheduler(service: gateway);
      when(
        () => gateway.scheduleBatchRemindersForProfile(
          profileId: any(named: 'profileId'),
          fireTimes: any(named: 'fireTimes'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => gateway.cancelDailyReminderForProfile(any()),
      ).thenAnswer((_) async {});
      when(
        () => gateway.cancelBatchRemindersForProfile(any()),
      ).thenAnswer((_) async {});
    });

    test('per-profile scheduling forwards the supplied content', () async {
      await scheduler.scheduleReminderForProfile(
        profileId: '01J00000000000000000000007',
        time: const TimeOfDay(hour: 19, minute: 0),
        title: 'Learning Reminder',
        body: 'You have 1 task today',
      );
      verify(
        () => gateway.scheduleBatchRemindersForProfile(
          profileId: '01J00000000000000000000007',
          fireTimes: any(named: 'fireTimes'),
          title: 'Learning Reminder',
          body: 'You have 1 task today',
        ),
      ).called(1);
    });

    test(
      'cancelForProfile delegates to both cancellation operations',
      () async {
        await scheduler.cancelForProfile('01J00000000000000000000007');
        verify(
          () => gateway.cancelDailyReminderForProfile(
            '01J00000000000000000000007',
          ),
        ).called(1);
        verify(
          () => gateway.cancelBatchRemindersForProfile(
            '01J00000000000000000000007',
          ),
        ).called(1);
      },
    );
  });

  // DNI-479: the streak alert is per curriculum, from LearnerState (AD-40);
  // the full AC-2 matrix is streak_alert_service_test.dart.
  group('Story 12.2 — streak protection alerts', tags: ['story_12_2'], () {
    StreakAlertService service(_StreakAlerts alerts) => StreakAlertService(
      notifications: alerts,
      markers: _Markers(),
      profileId: '01JQ8M9Y7V3K2N6P4R5T8W0X1Z',
      // Wed 2026-03-25, noon UTC (the learner's zone is UTC).
      clock: () => DateTime.utc(2026, 3, 25, 12),
    );
    final utc = LearnerSettingsHistory.constant(
      const LearnerSettings(
        profileId: '01JQ8M9Y7V3K2N6P4R5T8W0X1Z',
        timeZone: 'UTC',
        latitude: 40.0821,
        longitude: -74.2097,
        inIsrael: false,
      ),
    );

    test('a running streak not yet kept today schedules its alert', () async {
      final alerts = _StreakAlerts();
      await service(alerts).evaluate(
        curriculumId: 'mishnayos',
        streak: const CurriculumStreak(
          current: 4,
          best: 4,
          lastDay: '2026-03-24',
        ),
        settingsHistory: utc,
        hour: 21,
        minute: 0,
      );
      expect(alerts.scheduled, ['mishnayos']);
    });

    test('a streak already kept today schedules nothing', () async {
      final alerts = _StreakAlerts();
      await service(alerts).evaluate(
        curriculumId: 'mishnayos',
        streak: const CurriculumStreak(
          current: 5,
          best: 5,
          lastDay: '2026-03-25',
        ),
        settingsHistory: utc,
        hour: 21,
        minute: 0,
      );
      expect(alerts.scheduled, isEmpty);
    });
  });

  group(
    'Story 12.4 — notification preferences',
    tags: ['story_12_4'],
    skip:
        'Blocked: preference integration tests in the original suite depend on the Drift-backed profile database.',
    () {
      test('placeholder for the pending Firestore preference seam', () {});
    },
  );
}

class _StreakAlerts implements StreakAlertNotifications {
  final scheduled = <String>[];

  @override
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async => scheduled.add(curriculumId);

  @override
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  }) async {}

  @override
  Future<void> cancelAll(String profileId) async {}
}

class _Markers implements StreakAlertMarkers {
  @override
  Future<String?> read(String profileId, String curriculumId) async => null;

  @override
  Future<void> write(
    String profileId,
    String curriculumId,
    String marker,
  ) async {}

  @override
  Future<void> clear(String profileId, String curriculumId) async {}

  @override
  Future<void> clearAll(String profileId) async {}
}
