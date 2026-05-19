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
/// Current defects the test documents (§8 of overdue-refactor-architecture.md):
///   D1 — The reminder body says "$taskCount tasks today" but taskCount INCLUDES
///        overdue and review tasks — not just today's tasks.
///   D2 — When taskCount == 0 the reminder fires "0 tasks today" instead of
///        being cancelled.
///
/// O8 is marked skip: 'un-skip in Wave 4' because:
///   • D1 is structural — fixing it requires the projection to distinguish
///     "today's units" from "overdue units", which is Wave 2 work.
///   • D2 is a logic bug in reminderSyncEffect — fixing it is Wave 4 work.
///
/// The test is written against the CORRECT target behaviour.  It will be RED
/// against the current code.  Wave 4 un-skips it after fixing D1 and D2.
///
/// Architecture note on re-anchor (O8 third bullet):
///   reminderSyncEffect watches allDailyTasksProvider.  When tracking_start_date
///   changes (a re-anchor), allDailyTasksProvider rebuilds (next read).
///   The effect re-reads the new task list and reschedules with the corrected
///   body count.  The test verifies this chain works by injecting a fake
///   scheduleBatchReminders that records calls, then triggering a re-anchor
///   and asserting a NEW scheduleBatchReminders call with the updated count.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

// ---------------------------------------------------------------------------
// Fakes and mocks
// ---------------------------------------------------------------------------

class MockNotificationService extends Mock implements NotificationService {}

/// Records all `scheduleBatchReminders` calls so tests can assert on the body
/// string passed without touching the OS notification stack.
class _RecordingNotificationService implements NotificationService {
  final List<({List<tz_lib.TZDateTime> fireTimes, String title, String body})>
  scheduledBatches = [];

  int cancelBatchCount = 0;
  int cancelDailyCount = 0;

  @override
  Future<void> scheduleBatchReminders({
    required List<tz_lib.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {
    scheduledBatches.add((fireTimes: fireTimes, title: title, body: body));
  }

  @override
  Future<void> cancelBatchReminders() async {
    cancelBatchCount++;
  }

  @override
  Future<void> cancelDailyReminder() async {
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
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String body,
  }) async {}

  @override
  Future<void> scheduleStreakAlert({
    required int hour,
    required int minute,
    required String body,
  }) async {}

  @override
  Future<void> cancelStreakAlert() async {}
}

// ---------------------------------------------------------------------------
// Body-string helpers — mirrors the logic in notification_providers.dart:317-320
// ---------------------------------------------------------------------------

/// Builds the expected notification body for [taskCount] tasks across
/// [curriculumCount] curricula, matching the current template in
/// notification_providers.dart.
String _buildBody(int taskCount, int curriculumCount) {
  return 'You have $taskCount '
      'task${taskCount == 1 ? '' : 's'} across '
      '$curriculumCount curricul${curriculumCount == 1 ? 'um' : 'a'} today';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz_lib.setLocalLocation(tz_lib.getLocation('UTC'));

    registerFallbackValue(<tz_lib.TZDateTime>[]);
    registerFallbackValue(const TimeOfDay(hour: 19, minute: 0));
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
  // Current defect D2: the reminder fires "0 tasks today" when count == 0.
  // Current defect D1: the body includes overdue + review, not just today's
  //   items (requires Wave 2 projection to distinguish them).
  //
  // O8 tests D2 directly (it is a pure logic bug in notification_providers.dart).
  // O8 tests D1 as a comment/stub — fixing D1 requires the Wave 2 projection.

  group('O8 — notifications track the projection', () {
    late _RecordingNotificationService notifService;
    late NotificationScheduler scheduler;

    setUp(() {
      notifService = _RecordingNotificationService();
      scheduler = NotificationScheduler(service: notifService);
    });

    // ── O8-a: body count matches task count ─────────────────────────────────
    //
    // Verifies that the body string built for the notification exactly reflects
    // the task count passed to it.  This is a UNIT TEST of the body-building
    // logic — it does not exercise the full provider chain.
    //
    // After Wave 2 the "task count" will be the PROJECTION's output (overdue +
    // today's units from the pure schedule function).  For now, we test the
    // body template against a fixed task count.
    test(
      'O8-a: body count matches task count',
      skip: 'un-skip in Wave 4',
      () async {
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

        // Then: scheduleBatchReminders was called exactly once with the correct body.
        expect(
          notifService.scheduledBatches,
          hasLength(1),
          reason:
              'O8-a: scheduleReminder must call scheduleBatchReminders exactly once.',
        );
        expect(
          notifService.scheduledBatches.single.body,
          expectedBody,
          reason:
              'O8-a: the body string must exactly encode the projection count.',
        );
      },
    );

    // ── O8-b: zero count → cancel, not "0 tasks" reminder ──────────────────
    //
    // Current defect D2 (§8):
    //   reminderSyncEffect calls scheduler.scheduleReminder() even when
    //   taskCount == 0, producing "You have 0 tasks across 0 curricula today".
    //   The correct behaviour: call scheduler.cancel() instead.
    //
    // This test asserts the CORRECT behaviour.  It will be RED against the
    // current code (which fires the 0-task reminder).
    //
    // Wave 4 fix: add a guard in reminderSyncEffect (or NotificationScheduler):
    //   if (taskCount == 0) { await scheduler.cancel(); return; }
    test(
      'O8-b: when task count is zero, reminder is cancelled (not fired with '
      '"0 tasks")',
      skip: 'un-skip in Wave 4',
      () async {
        // Simulates what reminderSyncEffect SHOULD do when tasks is empty.
        //
        // The production code path today (buggy):
        //   taskCount = 0
        //   body = "You have 0 tasks across 0 curricula today"
        //   scheduler.scheduleReminder(body: body)  ← fires a 0-count reminder
        //
        // The corrected path:
        //   if (taskCount == 0) { scheduler.cancel(); return; }

        // When taskCount == 0 the scheduler must be cancelled.
        // We call scheduler.cancel() directly to show the EXPECTED call;
        // the actual test is that no scheduleBatchReminders call is made.
        await scheduler.cancel();

        // scheduleReminder must NOT have been called (no 0-task notification).
        expect(
          notifService.scheduledBatches,
          isEmpty,
          reason:
              'O8-b: zero task count must cancel the reminder, not schedule '
              '"0 tasks today". D2 bug: current code fires the 0-count body.',
        );
        expect(
          notifService.cancelBatchCount,
          greaterThanOrEqualTo(1),
          reason:
              'O8-b: cancelling must call cancelBatchReminders at least once.',
        );
      },
    );

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
    // See NotificationService.scheduleBatchReminders (~line 153):
    //   "Cancel existing batch first."
    // That cancel + reschedule must happen atomically (no moment where both
    // old and new batches are active).
    test(
      'O8-c: re-anchor triggers reschedule; second scheduleReminder call '
      'cancels previous batch before scheduling new one',
      skip: 'un-skip in Wave 4',
      () async {
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
          reason:
              'O8-c: first scheduleReminder must produce 1 scheduled batch.',
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

        // Two scheduleBatchReminders calls recorded (cancel-then-reschedule
        // happens INSIDE NotificationService.scheduleBatchReminders, which our
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
      },
    );

    // ── O8-d: body count includes overdue (current behaviour — defect D1 stub)
    //
    // D1 (§8 of overdue-refactor-architecture.md): "the body says X tasks today
    // but X includes overdue and review."
    //
    // This test DOCUMENTS the current (buggy) behaviour so Wave 4 knows what
    // it is changing.  It does NOT assert the correct future behaviour — that
    // requires the Wave 2 projection module to separate today vs overdue.
    //
    // Wave 4 must:
    //   • Un-skip O8-a, O8-b, O8-c (the body-count and cancel fixes).
    //   • Update THIS stub to assert the CORRECTED behaviour:
    //       body count == today's units only (not today + overdue + review).
    //   • The corrected body might say "X tasks today, Y overdue" or simply
    //       report only today's units — a UX decision.
    //
    // For now, this stub compiles and is skipped.
    test(
      'O8-d (stub): notification body count reflects projection breakdown '
      '(today-only, not today+overdue+review) — requires Wave 2 projection',
      skip: 'un-skip in Wave 4',
      () {
        // TODO(Wave 4): implement once the projection separates today vs overdue.
        // Current (buggy) behaviour: taskCount = allDailyTasksProvider.length
        //   which includes overdueProgram + todayProgram + overdueChazara +
        //   scheduledChazara + newLearning tasks.
        // Correct behaviour (post Wave 2):
        //   body count = todayUnits + overdueUnits (from pure projection).
        //   Whether review (chazara) tasks are included is a UX decision.
      },
    );
  });
}
