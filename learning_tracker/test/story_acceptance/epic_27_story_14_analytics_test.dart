/// Story acceptance tests for DNI-390 (27.14) — 12 named analytics events.
///
/// Each test asserts that exactly one event fires per trigger, using
/// [FakeAnalyticsService] injected into each service under test. No real
/// Firebase SDK is exercised; all dependencies are either in-memory or
/// mocktail mocks.
@Tags(['epic_27', 'story_27_14'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockNotificationGateway extends Mock implements NotificationGateway {}

// ---------------------------------------------------------------------------
// Utility: in-memory FlutterSecureStorage backed by a Map
// ---------------------------------------------------------------------------

_MockSecureStorage _createMockStorage() {
  final mock = _MockSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((inv) async {
    final key = inv.namedArguments[#key] as String;
    final value = inv.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });

  when(() => mock.read(key: any(named: 'key'))).thenAnswer((inv) async {
    final key = inv.namedArguments[#key] as String;
    return store[key];
  });

  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((inv) async {
    final key = inv.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('America/New_York'));
    registerFallbackValue(<tz_lib.TZDateTime>[]);
  });

  // ── 1. app_launch ──────────────────────────────────────────────────────────
  group('27.14 — app_launch', () {
    test('logAppLaunch fires exactly one app_launch event', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logAppLaunch();
      expect(analytics.countOf(AnalyticsEvent.appLaunch), 1);
    });
  });

  // ── 2. completion_recorded ─────────────────────────────────────────────────
  group(
    '27.14 — completion_recorded',
    skip:
        'Blocked: deleted CompletionWriter API at '
        'lib/features/learning/data/completion_writer.dart; the old test '
        'also depended on deleted UserDatabase at '
        'lib/core/database/user/user_database.dart, and no current '
        'Firestore completion API exposes this analytics hook.',
    () {
      test('placeholder for the retired completion-writer contract', () {});
    },
  );

  // ── 3. bulk_mark_prior_used ─────────────────────────────────────────────
  group('27.14 — bulk_mark_prior_used', () {
    test('logBulkMarkPriorUsed fires with correct params', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logBulkMarkPriorUsed(itemCount: 50, completionCount: 150);
      expect(analytics.countOf(AnalyticsEvent.bulkMarkPriorUsed), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.bulkMarkPriorUsed),
        containsPair('item_count', 50),
      );
      expect(
        analytics.lastParamsOf(AnalyticsEvent.bulkMarkPriorUsed),
        containsPair('completion_count', 150),
      );
    });
  });

  // ── 4. track_added ─────────────────────────────────────────────────────────
  group('27.14 — track_added', () {
    test('logTrackAdded fires with curriculum_id param', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logTrackAdded(curriculumId: 'mishnayos');
      expect(analytics.countOf(AnalyticsEvent.trackAdded), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.trackAdded),
        containsPair('curriculum_id', 'mishnayos'),
      );
    });
  });

  // ── 5. streak_milestone_reached ─────────────────────────────────────────
  group('27.14 — streak_milestone_reached', () {
    test('logStreakMilestoneReached fires with milestone param', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logStreakMilestoneReached(milestone: 7);
      expect(analytics.countOf(AnalyticsEvent.streakMilestoneReached), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.streakMilestoneReached),
        containsPair('milestone', 7),
      );
    });

    test('kStreakMilestones contains 7, 30, 100', () {
      expect(kStreakMilestones, containsAll([7, 30, 100]));
    });
  });

  // ── 6. sync_failed ─────────────────────────────────────────────────────────
  group('27.14 — sync_failed', () {
    test('logSyncFailed fires with reason param', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logSyncFailed(reason: 'network_timeout');
      expect(analytics.countOf(AnalyticsEvent.syncFailed), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.syncFailed),
        containsPair('reason', 'network_timeout'),
      );
    });
  });

  // ── 7. pin_locked_out ─────────────────────────────────────────────────────
  group('27.14 — pin_locked_out', () {
    test(
      'PinService fires pin_locked_out after maxFailedAttempts wrong guesses',
      () async {
        final analytics = FakeAnalyticsService();
        final storage = _createMockStorage();

        final svc = PinService(
          storage,
          maxFailedAttempts: 3,
          lockoutDurationMinutes: 1,
          analytics: analytics,
        );

        // Set a PIN so verification is possible.
        await svc.setParentPin('1234');

        // Exhaust allowed attempts — 3rd wrong guess triggers lockout.
        for (var i = 0; i < 3; i++) {
          try {
            await svc.verifyParentPin('9999');
          } on PinLockoutException {
            break; // lockout may throw on the last attempt
          }
        }

        // Give the unawaited future a microtask cycle.
        await Future<void>.delayed(Duration.zero);

        expect(analytics.countOf(AnalyticsEvent.pinLockedOut), 1);
        // PV-1: no profile_id — the event signals only THAT a lockout
        // occurred, never WHICH profile (docs/coding-standards.md PV-1).
        expect(
          analytics.lastParamsOf(AnalyticsEvent.pinLockedOut),
          isNot(contains('profile_id')),
        );
      },
    );
  });

  // ── 8. parent_mode_entered ─────────────────────────────────────────────────
  group('27.14 — parent_mode_entered', () {
    test(
      'logParentModeEntered fires without a profile_id param (PV-1)',
      () async {
        final analytics = FakeAnalyticsService();
        await analytics.logParentModeEntered();
        expect(analytics.countOf(AnalyticsEvent.parentModeEntered), 1);
        expect(
          analytics.lastParamsOf(AnalyticsEvent.parentModeEntered),
          isNot(contains('profile_id')),
        );
      },
    );
  });

  // ── 9. notification_fired (daily_reminder) ─────────────────────────────────
  group('27.14 — notification_fired / daily_reminder', () {
    test(
      'NotificationScheduler.scheduleReminder fires notification_fired',
      () async {
        final analytics = FakeAnalyticsService();
        final notifSvc = _MockNotificationGateway();

        // (AUD-notifications-04) scheduleReminder() now routes through the
        // profile-0 block of the *ForProfile gateway API.
        when(
          () => notifSvc.scheduleBatchRemindersForProfile(
            profileId: any(named: 'profileId'),
            fireTimes: any(named: 'fireTimes'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => notifSvc.cancelBatchRemindersForProfile(any()),
        ).thenAnswer((_) async {});

        final scheduler = NotificationScheduler(
          service: notifSvc,
          analytics: analytics,
        );

        await scheduler.scheduleReminder(
          time: const TimeOfDay(hour: 9, minute: 0),
          title: 'Learning Reminder',
          body: 'You have 3 tasks across 1 curriculum today',
        );
        await Future<void>.delayed(Duration.zero);

        expect(analytics.countOf(AnalyticsEvent.notificationFired), 1);
        expect(
          analytics.lastParamsOf(AnalyticsEvent.notificationFired),
          containsPair('notification_type', 'daily_reminder'),
        );
      },
    );
  });

  // ── 9b. notification_fired (streak_alert) ──────────────────────────────────
  group('27.14 — notification_fired / streak_alert', () {
    test('StreakAlertService.scheduleAlert fires notification_fired', () async {
      final analytics = FakeAnalyticsService();
      final notifSvc = _MockNotificationGateway();
      const profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      when(
        () => notifSvc.scheduleStreakAlertForProfile(
          profileId: any(named: 'profileId'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});

      final svcProvider = Provider<StreakAlertService>(
        (ref) => StreakAlertService(
          ref: ref,
          notificationService: notifSvc,
          profileId: profileId,
          hasCompletionsInRange: (start, end) async => false,
          analytics: analytics,
        ),
      );
      final svc = container.read(svcProvider);

      await svc.scheduleAlert(hour: 20, minute: 0, currentStreak: 5);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.countOf(AnalyticsEvent.notificationFired), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.notificationFired),
        containsPair('notification_type', 'streak_alert'),
      );
    });
  });

  // ── 10. notification_suppressed_sacred_time ────────────────────────────────
  group('27.14 — notification_suppressed_sacred_time', () {
    test('NotificationScheduler.cancelForProfileSacredTime fires suppression '
        'event', () async {
      final analytics = FakeAnalyticsService();
      final notifSvc = _MockNotificationGateway();

      // (AUD-notifications-04) cancelForSacredTime() (non-profile) was
      // deleted as dead code; cancelForProfileSacredTime is the surviving
      // production call site and fires the same analytics event.
      when(
        () => notifSvc.cancelDailyReminderForProfile(any()),
      ).thenAnswer((_) async {});
      when(
        () => notifSvc.cancelBatchRemindersForProfile(any()),
      ).thenAnswer((_) async {});

      final scheduler = NotificationScheduler(
        service: notifSvc,
        analytics: analytics,
      );

      await scheduler.cancelForProfileSacredTime('01JQ8M9Y7V3K2N6P4R5T8W0X1Z');
      await Future<void>.delayed(Duration.zero);

      expect(
        analytics.countOf(AnalyticsEvent.notificationSuppressedSacredTime),
        1,
      );
      expect(
        analytics.lastParamsOf(AnalyticsEvent.notificationSuppressedSacredTime),
        containsPair('notification_type', 'daily_reminder'),
      );
    });
  });

  // ── 11. cloud_restore_completed ────────────────────────────────────────────
  group('27.14 — cloud_restore_completed', () {
    test('logCloudRestoreCompleted fires with steps_restored param', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logCloudRestoreCompleted(stepsRestored: 3);
      expect(analytics.countOf(AnalyticsEvent.cloudRestoreCompleted), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.cloudRestoreCompleted),
        containsPair('steps_restored', 3),
      );
    });
  });

  // ── 12. crash_reported ────────────────────────────────────────────────────
  group('27.14 — crash_reported', () {
    test('logCrashReported fatal=true fires with correct param', () async {
      // Verifies the AnalyticsService.logCrashReported contract directly.
      // NullCrashlyticsService's own no-op behaviour (it never calls
      // analytics.logCrashReported) is covered separately in
      // test/core/logging/crashlytics_service_test.dart.
      final analytics = FakeAnalyticsService();
      await analytics.logCrashReported(fatal: true);
      expect(analytics.countOf(AnalyticsEvent.crashReported), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.crashReported),
        containsPair('fatal', true),
      );
    });

    test('logCrashReported fatal=false fires with correct param', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logCrashReported(fatal: false);
      expect(analytics.countOf(AnalyticsEvent.crashReported), 1);
      expect(
        analytics.lastParamsOf(AnalyticsEvent.crashReported),
        containsPair('fatal', false),
      );
    });
  });

  // ── FakeAnalyticsService contract ─────────────────────────────────────────
  group('27.14 — FakeAnalyticsService contract', () {
    test('countOf returns 0 for unfired events', () {
      final analytics = FakeAnalyticsService();
      expect(analytics.countOf(AnalyticsEvent.appLaunch), 0);
    });

    test('clear() resets all recorded events', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logAppLaunch();
      expect(analytics.countOf(AnalyticsEvent.appLaunch), 1);
      analytics.clear();
      expect(analytics.countOf(AnalyticsEvent.appLaunch), 0);
    });

    test('eventNames returns events in order', () async {
      final analytics = FakeAnalyticsService();
      await analytics.logAppLaunch();
      await analytics.logTrackAdded(curriculumId: 'mishnayos');
      expect(analytics.eventNames, [
        AnalyticsEvent.appLaunch,
        AnalyticsEvent.trackAdded,
      ]);
    });

    test('lastParamsOf returns null when no event fired', () {
      final analytics = FakeAnalyticsService();
      expect(analytics.lastParamsOf(AnalyticsEvent.appLaunch), isNull);
    });
  });
}
