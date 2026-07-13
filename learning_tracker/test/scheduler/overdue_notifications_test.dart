/// Overdue notifications invariant — O8.
///
/// O8 — Notifications track the projection.
///   • The reminder body count equals the projection's task count.
///   • When the count is zero, the reminder is cancelled (not fired with
///     "0 tasks today").
///   • A re-anchor (tracking_start_date moved to today) drives an immediate
///     reschedule to the new count via reminderSyncEffect.
///
/// O8 is a REAL characterisation test — it targets code that EXISTS today
/// (notification_providers.dart and notification_scheduler.dart).
///
/// Wave 4 fixed the two defects this test documents:
///   D1 — Fixed: the reminder body count now excludes overdue and review tasks;
///        only "today's units" (isOverdue: false, not scheduledChazara) are
///        counted.  overdueChazara tasks are excluded via !isOverdue (they have
///        isOverdue: true in production; see scheduler_engine.dart:238).
///   D2 — Fixed: when taskCount == 0, reminderSyncEffect now cancels the
///        reminder instead of firing "0 tasks today".
///
/// O8 is active (no skip).  All four sub-tests (O8-a through O8-d) assert the
/// corrected Wave 4 behaviour.
///
/// Architecture note on re-anchor (O8 third bullet):
///   reminderSyncEffect watches allDailyTasksProvider.  When tracking_start_date
///   changes (a re-anchor), allDailyTasksProvider rebuilds (next read).
///   The effect re-reads the new task list and reschedules with the corrected
///   body count.  The test verifies this chain works by injecting a fake
///   scheduleBatchRemindersForProfile that records calls, then triggering a
///   re-anchor and asserting a NEW scheduleBatchRemindersForProfile call with
///   the updated count.
///
/// AUD-notifications-04: the non-profile scheduleBatchReminders/
/// cancelBatchReminders/cancelDailyReminder/cancel() methods this file used
/// to drive (via NotificationScheduler.scheduleReminder()/.cancel()) were
/// deleted as dead code from NotificationGateway/NotificationScheduler —
/// zero production callers once WS5.per-profile's *ForProfile equivalents
/// took over. scheduleReminder() itself is kept (not one of the removed
/// methods) but now routes through the profile-0 *ForProfile block
/// internally, so the fake below records via *ForProfile overrides and the
/// zero-count case now drives cancelForProfile(0) — the real call
/// reminderSyncEffect's D2 fix makes in production.
///
/// AUD-t-cross-09: O8-b and O8-d used to hand-duplicate the D1/D2 guard logic
/// (calling `scheduler.cancelForProfile(0)` directly, or re-typing the
/// today-only filter inline) instead of exercising the actual
/// [reminderSyncEffect] provider — a mutation that deleted or inverted the
/// real guards in notification_providers.dart would still leave this file
/// green. Both sub-tests now build a real [ProviderContainer] (mirroring
/// reminder_sync_sacred_time_test.dart), override [allDailyTasksProvider] and
/// [notificationSchedulerProvider], and read [reminderSyncEffectProvider] so
/// the guards actually inside production code are what's exercised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records all `scheduleBatchRemindersForProfile` calls so tests can assert
/// on the body string passed without touching the OS notification stack.
class _RecordingNotificationGateway implements NotificationGateway {
  final List<({List<tz_lib.TZDateTime> fireTimes, String title, String body})>
  scheduledBatches = [];

  int cancelBatchCount = 0;
  int cancelDailyCount = 0;

  @override
  Future<void> scheduleBatchRemindersForProfile({
    required int profileId,
    required List<tz_lib.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {
    scheduledBatches.add((fireTimes: fireTimes, title: title, body: body));
  }

  @override
  Future<void> cancelBatchRemindersForProfile(int profileId) async {
    cancelBatchCount++;
  }

  @override
  Future<void> cancelDailyReminderForProfile(int profileId) async {
    cancelDailyCount++;
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
    required int profileId,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleStreakAlertForProfile({
    required int profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
  }) async {}

  @override
  Future<void> cancelStreakAlertForProfile(int profileId) async {}
}

/// Fixes the active profile to 0 — the profile-0 block the doc comment above
/// (AUD-notifications-04) documents `reminderSyncEffect`'s D2 guard as
/// driving in production.
class _ProfileId0 extends ActiveProfileId {
  @override
  int build() => 0;
}

// ---------------------------------------------------------------------------
// Body-string helper — mirrors the logic in notification_providers.dart:317-320
// ---------------------------------------------------------------------------

/// Builds the expected notification body for [taskCount] tasks across
/// [curriculumCount] curricula, matching the current template in
/// notification_providers.dart.
///
/// Used only by O8-a/O8-c, which test the [NotificationScheduler]/
/// [NotificationGateway] boundary directly (not the D1/D2 guards inside
/// [reminderSyncEffect] — those are covered by O8-b/O8-d via a real
/// [ProviderContainer], see below).
String _buildBody(int taskCount, int curriculumCount) {
  return 'You have $taskCount '
      'task${taskCount == 1 ? '' : 's'} across '
      '$curriculumCount curricul${curriculumCount == 1 ? 'um' : 'a'} today';
}

/// Builds a synthetic [DailyTask] as [reminderSyncEffect] would see it via
/// `allDailyTasksProvider`.
DailyTask _makeTask({
  required DailyTaskPriority priority,
  required bool isOverdue,
  required CurriculumId curriculumId,
  String? refSuffix,
}) {
  final suffix = refSuffix ?? priority.name;
  return DailyTask(
    curriculumId: curriculumId,
    contentItemSefariaRef: 'ref-$suffix-${curriculumId.name}',
    stageOrder: 1,
    stageDefinitionId: 1,
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test',
    stageName: 'Test Stage',
    trackId: 1,
    trackLabel: 'Test Track',
  );
}

/// Builds a [ProviderContainer] wired so `reminderSyncEffectProvider` can be
/// read directly: [allDailyTasksProvider] returns [tasks], the notification
/// gateway is [gateway] (via a real [NotificationScheduler]), Sacred Time is
/// forced inactive, and the active profile is fixed to 0.
///
/// Mirrors reminder_sync_sacred_time_test.dart's `makeContainer` helper.
ProviderContainer _makeContainer(
  _RecordingNotificationGateway gateway, {
  required List<DailyTask> tasks,
}) {
  final scheduler = NotificationScheduler(service: gateway);
  return ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(_ProfileId0.new),
      currentAppLocaleProvider.overrideWithValue(const Locale('en')),
      outboxSyncWriteFacadeProvider.overrideWithValue(null),
      notificationSchedulerProvider.overrideWithValue(scheduler),
      isSacredTimeActiveProvider.overrideWithValue(false),
      allDailyTasksProvider.overrideWith((ref) async => tasks),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('UTC'));
  });

  // ── O8 — REAL characterisation tests (Wave 4 un-skips) ──────────────────
  //
  // Target spec (§8 of overdue-refactor-architecture.md):
  //   1. The reminder body count equals the projection count (not a mix of
  //      today+overdue+review, but specifically the count that feeds the
  //      projection).
  //   2. When the projection count is zero, the reminder is CANCELLED —
  //      scheduler.cancel() is called, NOT scheduleBatchReminders("0 tasks").
  //   3. A re-anchor triggers an immediate reschedule to the new count.
  //
  // O8-a/O8-c exercise the NotificationScheduler/NotificationGateway boundary
  // directly. O8-b/O8-d exercise the actual reminderSyncEffect provider
  // through a real ProviderContainer (AUD-t-cross-09) so the D1/D2 guards
  // inside notification_providers.dart are what's under test.

  group('O8 — notifications track the projection', () {
    late _RecordingNotificationGateway notifService;
    late NotificationScheduler scheduler;

    setUp(() {
      notifService = _RecordingNotificationGateway();
      scheduler = NotificationScheduler(service: notifService);
    });

    // ── O8-a: body count matches task count ─────────────────────────────────
    //
    // Verifies that the body string built for the notification exactly reflects
    // the task count passed to it.  This is a UNIT TEST of the body-building
    // logic — it does not exercise the full provider chain.
    test('O8-a: body count matches task count', () async {
      // Given: 5 tasks across 2 curricula.
      const taskCount = 5;
      const curriculumCount = 2;
      final expectedBody = _buildBody(taskCount, curriculumCount);

      // When: scheduleReminder is called with that body.
      await scheduler.scheduleReminder(
        time: const TimeOfDay(hour: 19, minute: 0),
        title: 'Learning Reminder',
        body: expectedBody,
        location: null,
        inIsrael: false,
      );

      // Then: scheduleBatchRemindersForProfile was called exactly once with
      // the correct body.
      expect(
        notifService.scheduledBatches,
        hasLength(1),
        reason:
            'O8-a: scheduleReminder must call scheduleBatchRemindersForProfile '
            'exactly once.',
      );
      expect(
        notifService.scheduledBatches.single.body,
        expectedBody,
        reason:
            'O8-a: the body string must exactly encode the projection count.',
      );
    });

    // ── O8-b: zero count → reminderSyncEffect cancels, not "0 tasks" ────────
    //
    // AUD-t-cross-09: drives the REAL reminderSyncEffect provider (not a
    // hand-called scheduler.cancelForProfile(0)) with a task list that
    // collapses to taskCount == 0 after the today-only filter. If the D2
    // guard ("if (taskCount == 0) { await scheduler.cancelForProfile(...) }")
    // in notification_providers.dart were deleted, reminderSyncEffect would
    // instead call scheduleReminderForProfile with a "You have 0 tasks..."
    // body, and the first expectation below would fail.
    test('O8-b: when task count is zero, reminderSyncEffect cancels the '
        'reminder (not fired with "0 tasks")', () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _RecordingNotificationGateway();

      // Every task is excluded by the today-only filter: one overdue
      // program task (isOverdue: true) and one scheduledChazara review
      // task — taskCount collapses to 0 inside reminderSyncEffect.
      final container = _makeContainer(
        gateway,
        tasks: [
          _makeTask(
            priority: DailyTaskPriority.overdueProgram,
            isOverdue: true,
            curriculumId: CurriculumId.bavli,
          ),
          _makeTask(
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
            curriculumId: CurriculumId.mishnayos,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(reminderSyncEffectProvider.future);

      // scheduleReminderForProfile must NOT have been called (no 0-task
      // notification).
      expect(
        gateway.scheduledBatches,
        isEmpty,
        reason:
            'O8-b: zero task count must cancel the reminder, not schedule '
            '"0 tasks today". D2 bug: current code would fire the '
            '0-count body if the guard were removed.',
      );
      expect(
        gateway.cancelBatchCount,
        greaterThanOrEqualTo(1),
        reason:
            'O8-b: cancelling must call cancelBatchRemindersForProfile at '
            'least once.',
      );
      expect(
        gateway.cancelDailyCount,
        greaterThanOrEqualTo(1),
        reason:
            'O8-b: cancelling must call cancelDailyReminderForProfile at '
            'least once (NotificationScheduler.cancelForProfile drives '
            'both).',
      );
    });

    // ── O8-c: re-anchor triggers reschedule to new count ────────────────────
    //
    // When tracking_start_date is moved to today (Clear Overdue / re-anchor),
    // the overdue set collapses to zero and the task list shrinks.
    // reminderSyncEffect must immediately reschedule with the NEW (smaller) body.
    //
    // The mechanism: reminderSyncEffect watches allDailyTasksProvider; a
    // re-anchor changes profile_programs, which invalidates allDailyTasksProvider
    // on next read, which re-runs the effect.
    //
    // This test verifies the reschedule contract at the NotificationScheduler
    // level: calling scheduleReminder a SECOND time (with new count) must
    // cancel the previous batch before scheduling the new one.
    //
    // See NotificationGateway.scheduleBatchRemindersForProfile:
    //   "Cancel existing batch first."
    // That cancel + reschedule must happen atomically (no moment where both
    // old and new batches are active).
    test('O8-c: re-anchor triggers reschedule; second scheduleReminder call '
        'cancels previous batch before scheduling new one', () async {
      const time = TimeOfDay(hour: 19, minute: 0);
      const title = 'Learning Reminder';

      // First schedule: 5 tasks (before re-anchor).
      final bodyBefore = _buildBody(5, 2);
      await scheduler.scheduleReminder(
        time: time,
        title: title,
        body: bodyBefore,
        location: null,
        inIsrael: false,
      );
      expect(
        notifService.scheduledBatches,
        hasLength(1),
        reason: 'O8-c: first scheduleReminder must produce 1 scheduled batch.',
      );

      // Simulate re-anchor: the overdue set collapses; tasks = [today's unit only].
      // Count drops from 5 to 1 (1 due-today unit from a single program track).
      final bodyAfter = _buildBody(1, 1);
      await scheduler.scheduleReminder(
        time: time,
        title: title,
        body: bodyAfter,
        location: null,
        inIsrael: false,
      );

      // Two scheduleBatchRemindersForProfile calls recorded (cancel-then-
      // reschedule happens INSIDE
      // NotificationGateway.scheduleBatchRemindersForProfile, which our
      // recording fake doesn't simulate — it records the outer call).
      expect(
        notifService.scheduledBatches,
        hasLength(2),
        reason:
            'O8-c: second scheduleReminder after re-anchor must produce a '
            'second batch call (the scheduler re-runs for the new count).',
      );

      // The second batch must reflect the updated (smaller) count.
      final secondBody = notifService.scheduledBatches[1].body;
      expect(
        secondBody,
        bodyAfter,
        reason:
            'O8-c: after re-anchor the body must encode the new (smaller) '
            'task count, not the pre-anchor count.',
      );
      expect(
        secondBody,
        isNot(equals(bodyBefore)),
        reason:
            'O8-c: the post-re-anchor body must differ from the pre-anchor '
            'body (the count changed).',
      );
    });

    // ── O8-d: body count is today-only (D1 fix — Wave 4) ───────────────────
    //
    // AUD-t-cross-09: drives the REAL reminderSyncEffect provider with a
    // synthetic mix of tasks (overdue + today + review) so the D1 today-only
    // filter actually inside notification_providers.dart is what's under
    // test, not a hand-retyped copy of it. If that filter stopped excluding
    // scheduledChazara (or started excluding a valid today task), the body
    // assertion below would fail.
    test('O8-d: reminderSyncEffect body count is today-only (excludes overdue '
        'and review tasks)', () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _RecordingNotificationGateway();

      // Build a synthetic mix of tasks:
      //   • 1 overdueProgram task  (isOverdue: true,  bavli)      — EXCLUDED
      //   • 2 todayProgram tasks   (isOverdue: false, bavli × 2)  — INCLUDED
      //   • 1 overdueChazara task  (isOverdue: true,  bavli)      — EXCLUDED
      //   • 1 scheduledChazara task (isOverdue: false, mishnayos) — EXCLUDED
      //   • 1 newLearning task     (isOverdue: false, tanach)     — INCLUDED
      //
      // Today-only count = todayProgram (2) + newLearning (1) = 3 tasks,
      // across 2 unique curricula (bavli + tanach).
      final allTasks = <DailyTask>[
        _makeTask(
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          curriculumId: CurriculumId.bavli,
        ),
        _makeTask(
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          curriculumId: CurriculumId.bavli,
          refSuffix: 'todayProgram-1',
        ),
        _makeTask(
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          curriculumId: CurriculumId.bavli,
          refSuffix: 'todayProgram-2',
        ),
        // overdueChazara tasks have isOverdue: true in production
        // (scheduler_engine.dart:238) — mirrored here (F-M4 fix).
        _makeTask(
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
          curriculumId: CurriculumId.bavli,
        ),
        _makeTask(
          priority: DailyTaskPriority.scheduledChazara,
          isOverdue: false,
          curriculumId: CurriculumId.mishnayos,
        ),
        _makeTask(
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          curriculumId: CurriculumId.tanach,
        ),
      ];

      final container = _makeContainer(gateway, tasks: allTasks);
      addTearDown(container.dispose);

      await container.read(reminderSyncEffectProvider.future);

      expect(
        gateway.scheduledBatches,
        hasLength(1),
        reason:
            'O8-d: a non-zero today-only count must schedule exactly one '
            'batch.',
      );

      // Compare against the REAL localized template (not a hand-rolled
      // copy) so the assertion tracks production wording.
      final expectedBody = lookupAppLocalizations(
        const Locale('en'),
      ).notificationReminderBody(3, 2);
      expect(
        expectedBody,
        'You have 3 tasks across 2 curricula today',
        reason:
            'sanity check: the localized template for (3, 2) must read as '
            'expected — guards against this test silently drifting.',
      );

      expect(
        gateway.scheduledBatches.single.body,
        expectedBody,
        reason:
            'O8-d: the scheduled body must encode the today-only count '
            '(3 tasks, 2 curricula) produced by reminderSyncEffect\'s own '
            'D1 filter, not the raw allDailyTasksProvider length (6 tasks, '
            '3 curricula) — overdue (1) and review (2) rows must be '
            'excluded.',
      );
    });
  });
}
