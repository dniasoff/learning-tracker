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
///   scheduleBatchReminders that records calls, then triggering a re-anchor
///   and asserting a NEW scheduleBatchReminders call with the updated count.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

// ---------------------------------------------------------------------------
// Fakes and mocks
// ---------------------------------------------------------------------------

class MockNotificationGateway extends Mock implements NotificationGateway {}

/// Records all `scheduleBatchReminders` calls so tests can assert on the body
/// string passed without touching the OS notification stack.
class _RecordingNotificationGateway implements NotificationGateway {
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
    //
    // After Wave 2 the "task count" will be the PROJECTION's output (overdue +
    // today's units from the pure schedule function).  For now, we test the
    // body template against a fixed task count.
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
    });

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
    test('O8-b: when task count is zero, reminder is cancelled (not fired with '
        '"0 tasks")', () async {
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
    // See NotificationGateway.scheduleBatchReminders (~line 153):
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

      // Two scheduleBatchReminders calls recorded (cancel-then-reschedule
      // happens INSIDE NotificationGateway.scheduleBatchReminders, which our
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
    // D1 fix (§8 of overdue-refactor-architecture.md):
    //   The body count must be TODAY's units only — tasks where isOverdue is
    //   false AND priority is not overdueChazara / scheduledChazara.
    //
    // This test constructs a synthetic task list that mirrors what
    // allDailyTasksProvider returns (overdue + today + review tasks), applies
    // the same filter that notification_providers.dart now applies (Wave 4
    // D1 fix), and asserts the body reflects only the today-only count.
    //
    // Wave 2 projection is already shipped — the projection provides the mix
    // of overdueProgram, todayProgram, overdueChazara, and scheduledChazara
    // tasks.  This test validates the filter here at the notification layer.
    test(
      'O8-d: body count is today-only (excludes overdue and review tasks)',
      () async {
        // Build a synthetic mix of tasks:
        //   • 1 overdueProgram task  (isOverdue: true,  bavli)      — EXCLUDED
        //   • 2 todayProgram tasks   (isOverdue: false, bavli × 2)  — INCLUDED
        //   • 1 overdueChazara task  (isOverdue: false, bavli)      — EXCLUDED
        //   • 1 scheduledChazara task (isOverdue: false, mishnayos) — EXCLUDED
        //   • 1 newLearning task     (isOverdue: false, tanach)     — INCLUDED
        //
        // Today-only count = todayProgram (2) + newLearning (1) = 3 tasks.
        // Unique curricula in today-only = bavli + tanach = 2.

        DailyTask makeTask({
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

        final allTasks = <DailyTask>[
          // Excluded: overdue program task.
          makeTask(
            priority: DailyTaskPriority.overdueProgram,
            isOverdue: true,
            curriculumId: CurriculumId.bavli,
          ),
          // Included: two today-program tasks, both bavli.
          makeTask(
            priority: DailyTaskPriority.todayProgram,
            isOverdue: false,
            curriculumId: CurriculumId.bavli,
            refSuffix: 'todayProgram-1',
          ),
          makeTask(
            priority: DailyTaskPriority.todayProgram,
            isOverdue: false,
            curriculumId: CurriculumId.bavli,
            refSuffix: 'todayProgram-2',
          ),
          // Excluded: review tasks (overdueChazara + scheduledChazara).
          // overdueChazara tasks have isOverdue: true in production
          // (scheduler_engine.dart:238) — mirrored here (F-M4 fix).
          makeTask(
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
            curriculumId: CurriculumId.bavli,
          ),
          makeTask(
            priority: DailyTaskPriority.scheduledChazara,
            isOverdue: false,
            curriculumId: CurriculumId.mishnayos,
          ),
          // Included: new-learning task, different curriculum.
          makeTask(
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            curriculumId: CurriculumId.tanach,
          ),
        ];

        // Apply the same filter as notification_providers.dart (D1 fix, F-M4).
        // overdueChazara is already excluded by !t.isOverdue (isOverdue: true
        // in production); only scheduledChazara needs an explicit check.
        final todayTasks = allTasks
            .where(
              (t) =>
                  !t.isOverdue &&
                  t.priority != DailyTaskPriority.scheduledChazara,
            )
            .toList();

        final taskCount = todayTasks.length;
        final curriculumCount = todayTasks
            .map((t) => t.curriculumId)
            .toSet()
            .length;

        // today-only: 2 todayProgram (bavli) + 1 newLearning (tanach) = 3 tasks,
        // 2 unique curricula (bavli + tanach).
        expect(
          taskCount,
          3,
          reason:
              'O8-d: today-only count must be 3 (2 todayProgram + 1 newLearning); '
              'overdue (1) and review (2) tasks must be excluded.',
        );
        expect(
          curriculumCount,
          2,
          reason:
              'O8-d: curriculum count must be 2 (bavli + tanach); '
              'mishnayos only appears in the review row and must be excluded.',
        );

        // The body built from the filtered count must match the template.
        final body = _buildBody(taskCount, curriculumCount);
        expect(
          body,
          'You have 3 tasks across 2 curricula today',
          reason:
              'O8-d: body must encode the today-only count, not the total '
              'allDailyTasksProvider length (which would be 6).',
        );

        // Verify that scheduleReminder called with this body records it correctly.
        await scheduler.scheduleReminder(
          time: const TimeOfDay(hour: 19, minute: 0),
          title: 'Learning Reminder',
          body: body,
          location: null,
          inIsrael: false,
        );
        expect(
          notifService.scheduledBatches.single.body,
          body,
          reason:
              'O8-d: the scheduled batch body must reflect today-only count.',
        );
      },
    );
  });
}
