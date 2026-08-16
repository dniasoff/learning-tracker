/// Story acceptance coverage for Epic 12 — notifications.
@Tags(['epic_12'])
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
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

  group(
    'Story 12.2 — streak protection alerts',
    tags: ['story_12_2'],
    skip:
        'Blocked: this acceptance flow seeds and reads Drift streak_events; Firestore streak state is not wired into StreakAlertService here.',
    () {
      test('placeholder for the pending Firestore streak-alert seam', () {});
    },
  );

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
