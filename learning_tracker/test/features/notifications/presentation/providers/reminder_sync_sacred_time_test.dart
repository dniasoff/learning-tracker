/// Regression test for the bug-hunt round-2 finding:
///   "[medium/regression] Daily-reminder batch is fully cancelled while Sacred
///    Time is active, losing the next ~13 weekdays of reminders if the app
///    isn't reopened"
///   (notification_providers.dart:459)
///
/// ROOT CAUSE: reminderSyncEffect (and the inactive-profile branch in
/// allProfilesReminderBootstrap) used to early-return with a BLANKET cancel of
/// the entire 14-day rolling reminder batch the moment a Sacred Time window was
/// live. Per-fire-time suppression already lives inside
/// NotificationScheduler.buildFireTimesForTest, so the only fire-times the
/// blanket cancel removed were the legitimate non-Shabbos weekday reminders —
/// which then only re-scheduled when the app was next resumed.
///
/// FIX: never blanket-cancel the batch on a live Sacred-Time window — always
/// (re)schedule the per-fire-time-filtered batch. Shabbos fire-times stay
/// suppressed via buildFireTimesForTest while weekday reminders survive even if
/// the app is closed over Shabbos.
///
/// These tests drive reminderSyncEffect / allProfilesReminderBootstrap with a
/// recording NotificationScheduler while Sacred Time is active, and assert the
/// per-profile batch is SCHEDULED (not cancelled). They are RED against the old
/// blanket-cancel code and GREEN after the fix.
@Tags(['needs_flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

// ---------------------------------------------------------------------------
// Recording gateway — records the per-profile schedule/cancel calls without
// touching the OS notification stack.
// ---------------------------------------------------------------------------

class _RecordingNotificationGateway implements NotificationGateway {
  final List<String> scheduledBatchProfiles = [];
  final List<String> cancelledBatchProfiles = [];
  final List<String> cancelledDailyProfiles = [];

  @override
  Future<void> scheduleBatchRemindersForProfile({
    required String profileId,
    required List<tz_lib.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {
    scheduledBatchProfiles.add(profileId);
  }

  @override
  Future<void> cancelBatchRemindersForProfile(String profileId) async {
    cancelledBatchProfiles.add(profileId);
  }

  @override
  Future<void> cancelDailyReminderForProfile(String profileId) async {
    cancelledDailyProfiles.add(profileId);
  }

  // ── Unused stubs ─────────────────────────────────────────────────────────

  @override
  Future<bool> initialize({
    void Function(String? payload)? onNotificationTap,
  }) => Future.value(false);

  @override
  Future<bool> requestPermission() => Future.value(false);

  @override
  Future<bool> hasPermission() => Future.value(false);

  @override
  Future<void> scheduleDailyReminderForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleStreakAlertForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
  }) async {}

  @override
  Future<void> cancelStreakAlertForProfile(String profileId) async {}
}

// ---------------------------------------------------------------------------
// Active-profile + locale overrides.
// ---------------------------------------------------------------------------

class _ProfileId1 extends SelectedProfileId {
  @override
  String? build() => 'profile-1';
}

DailyTask _todayTask() => const DailyTask(
  curriculumId: CurriculumId.bavli,
  contentItemSefariaRef: 'Berakhot 2a',
  stageOrder: 1,
  priority: DailyTaskPriority.todayProgram,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Test Track',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('UTC'));
  });

  ProviderContainer makeContainer(
    _RecordingNotificationGateway gateway, {
    required bool sacredTimeActive,
    required List<DailyTask> tasks,
  }) {
    // A scheduler with NO SacredWindowRepository: buildFireTimesForTest then
    // performs no per-fire-time filtering, so a full 14-entry batch is built.
    // The point of the test is that the provider SCHEDULES the batch instead of
    // blanket-cancelling it — the per-fire-time suppression itself is covered
    // by shabbos_notification_suppression_test.dart.
    final scheduler = NotificationScheduler(service: gateway);
    return ProviderContainer(
      overrides: [
        selectedProfileIdProvider.overrideWith(_ProfileId1.new),
        currentAppLocaleProvider.overrideWithValue(const Locale('en')),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        isSacredTimeActiveProvider.overrideWithValue(sacredTimeActive),
        allDailyTasksProvider.overrideWith((ref) async => tasks),
      ],
    );
  }

  group('reminderSyncEffect — Sacred Time no longer blanket-cancels the batch', () {
    test(
      'with reminders enabled + tasks present, an ACTIVE Sacred window still '
      'SCHEDULES the per-profile batch (does not blanket-cancel)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final gateway = _RecordingNotificationGateway();
        final container = makeContainer(
          gateway,
          sacredTimeActive: true,
          tasks: [_todayTask()],
        );
        addTearDown(container.dispose);

        await container.read(reminderSyncEffectProvider.future);

        expect(
          gateway.scheduledBatchProfiles,
          contains('profile-1'),
          reason:
              'A live Sacred Time window must NOT cancel the whole batch. The '
              'per-fire-time filter inside the scheduler already drops Shabbos '
              'fire-times; weekday reminders must still be scheduled so they '
              'survive even if the app is closed over Shabbos.',
        );
        expect(
          gateway.cancelledBatchProfiles,
          isEmpty,
          reason:
              'The blanket cancelForProfileSacredTime path must no longer run '
              'while a Sacred Time window is active.',
        );
      },
    );

    test(
      'with a non-active window it behaves identically (still schedules)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final gateway = _RecordingNotificationGateway();
        final container = makeContainer(
          gateway,
          sacredTimeActive: false,
          tasks: [_todayTask()],
        );
        addTearDown(container.dispose);

        await container.read(reminderSyncEffectProvider.future);

        expect(gateway.scheduledBatchProfiles, contains('profile-1'));
        expect(gateway.cancelledBatchProfiles, isEmpty);
      },
    );

    test(
      'reminders DISABLED still cancels regardless of Sacred Time',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationPreferencesRepository.reminderEnabledKey('profile-1'):
              false,
        });
        final gateway = _RecordingNotificationGateway();
        final container = makeContainer(
          gateway,
          sacredTimeActive: true,
          tasks: [_todayTask()],
        );
        addTearDown(container.dispose);

        // AUD-notifications-02: reminderEnabledProvider is now an AsyncNotifier
        // that genuinely awaits SharedPreferences before resolving — it no
        // longer emits a hardcoded `true` default and then flips to the
        // persisted `false`, so reminderSyncEffect (which awaits
        // reminderEnabledProvider.future directly) never observes an
        // intermediate value and never gets invalidated mid-flight. The old
        // 10-attempt "disposed during loading" retry-loop workaround this test
        // needed is gone — a single read now settles on the first attempt.
        await container.read(reminderSyncEffectProvider.future);

        expect(
          gateway.scheduledBatchProfiles,
          isEmpty,
          reason: 'Disabled reminders must never schedule a batch.',
        );
        expect(
          gateway.cancelledBatchProfiles,
          contains('profile-1'),
          reason: 'Disabled reminders still cancel the per-profile batch.',
        );
      },
    );
  });
}
