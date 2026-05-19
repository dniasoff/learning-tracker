/// Overdue projection characterisation tests — invariants O1, O2, O3, O7.
///
/// O2 CONVENTION (encode here; Wave 1 & Wave 2 implement to it)
/// ─────────────────────────────────────────────────────────────
///   For a program track anchored at A = profile_programs.tracking_start_date:
///     • "today" = T  (T >= A)
///     • The schedule assigns calendar(program, d) to every date d in [A, T].
///     • overdue   = calendar units for dates [A, T−1] NOT completed.
///     • dueToday  = calendar unit for T, not completed.
///   A program anchored N days before today with no completions →
///     N overdue units + 1 today unit.
///   Re-anchoring tracking_start_date to today collapses overdue to empty.
///
/// O2 — REAL characterisation test (RED against Bug 1, GREEN after Wave 1's fix).
///        Tests PRODUCTION code via programCalendarSchedule().
/// O1, O3, O7 — COMPILING STUBS; Wave 2 fills them in.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

// ---------------------------------------------------------------------------
// Fake LocalCalendarEngine — deterministic, no DB required.
//
// Returns one entry per date in the requested range.
// The todayRef follows the pattern "program YYYY-MM-DD" so each calendar day
// maps to a unique, testable ref.
// ---------------------------------------------------------------------------
class _FakeCalendarEngine implements LocalCalendarEngine {
  _FakeCalendarEngine(this._programId);

  final String _programId;

  String _refForDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$_programId $y-$m-$d';
  }

  @override
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async {
    if (programId != _programId) return null;
    return CalendarProgramEntry(
      programId: programId,
      displayNameEn: '',
      displayNameHe: '',
      todayRef: _refForDate(date),
      apiSource: 'fake',
    );
  }

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (programId != _programId) return const [];
    final result = <CalendarProgramEntry>[];
    var cursor = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    while (!cursor.isAfter(end)) {
      result.add(
        CalendarProgramEntry(
          programId: programId,
          displayNameEn: '',
          displayNameHe: '',
          todayRef: _refForDate(cursor),
          apiSource: 'fake',
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  @override
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async =>
      const [];

  @override
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) => getEntry(programKey, date);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── O2 — REAL characterisation test (Wave 1 un-skips) ───────────────────
  //
  // Tests the PRODUCTION programCalendarSchedule() function directly.
  //
  // What Bug 1 did:
  //   _applyProgramCalendarOverrides treated tracking_start_ref as
  //   "today's unit" and tried to fetch "following days" via
  //   startRangeDate.isBefore(today) — ALWAYS false.
  //   Result: 1 entry (frozen start ref), 0 overdue. Track never advanced.
  //
  // What the test asserts (the CORRECT behaviour after Wave 1's fix):
  //   programCalendarSchedule with anchor 3 days before today →
  //     • 4 entries total (anchor, anchor+1, anchor+2, today)
  //     • entries[0..2] are the overdue units (isOverdue = true when task-built)
  //     • entries[3] = today's unit (isOverdue = false when task-built)
  //     • all refs are distinct calendar days
  //     • today's ref == fake engine's output for today
  test('O2: program track anchored N days ago (with legacy trackingStartRef) → '
      'N overdue units + 1 today unit', () async {
    // Fixed "today" = 2026-05-19 (UTC).  N = 3 days before today.
    const n = 3;
    const programKey = 'daf_yomi';
    final today = DateTime.utc(2026, 5, 19);
    final anchor = today.subtract(const Duration(days: n)); // 2026-05-16

    final fakeEngine = _FakeCalendarEngine(programKey);
    final calendarService = CalendarProgramService(fakeEngine);

    // Exercise the PRODUCTION programCalendarSchedule function.
    // Bug 1 would have returned only [todayEntry] (1 entry).
    // The fix must return 4 entries: anchor, anchor+1, anchor+2, today.
    final entries = await programCalendarSchedule(
      programKey: programKey,
      anchor: anchor,
      today: today,
      calendarService: calendarService,
    );

    // O2 COUNT ASSERTIONS
    expect(
      entries,
      hasLength(n + 1),
      reason:
          'O2: $n days of backlog + today → ${n + 1} calendar entries total. '
          'Bug 1 produced only 1 entry (frozen on start ref).',
    );

    final overdueEntries = entries.sublist(0, entries.length - 1);
    final todayEntry = entries.last;

    expect(
      overdueEntries,
      hasLength(n),
      reason:
          'O2: first $n entries are overdue units (dates [anchor, today−1]).',
    );

    // O2 OVERDUE-CONTENT CHECK: overdue refs must be distinct days in
    // [anchor, today−1] and the today ref must be the calendar unit for today.
    final overdueRefs = overdueEntries.map((e) => e.todayRef).toSet();
    final todayRef = todayEntry.todayRef;

    expect(
      overdueRefs.length,
      n,
      reason: 'O2: all N overdue units must be distinct calendar entries.',
    );
    expect(
      overdueRefs,
      isNot(contains(todayRef)),
      reason: 'O2: no overdue ref should equal the today ref.',
    );
    // Today's ref must match the fake engine's output for today.
    expect(
      todayRef,
      '$programKey 2026-05-19',
      reason: "O2: today's ref must be the calendar unit for today.",
    );
    // Anchor day's ref must be the fake engine's output for the anchor date.
    expect(
      overdueEntries.first.todayRef,
      '$programKey 2026-05-16',
      reason:
          'O2: anchor day ref must be the calendar unit for the anchor '
          '(the schedule is inclusive on the anchor).',
    );
  });

  // ── O1 — COMPILING STUB (Wave 2) ────────────────────────────────────────
  //
  // Invariant: Computing the overdue set twice from IDENTICAL inputs (anchor,
  // completion set, today) yields an IDENTICAL result.
  //
  // Wave 2 owns lib/features/scheduler/domain/projection/ and must:
  //   1. Import OverdueProjection (or equivalent pure-function type).
  //   2. Call compute(anchor, completionSet, today) TWICE with the exact same
  //      arguments.  Both calls must return equal results.
  //   3. Also call compute() twice on the SAME instance — same result.
  //   4. Assert sets are equal: result1 == result2 and counts match.
  //   5. Use a FIXED today (not DateTime.now()) for full determinism.
  //   6. Run no DB queries — the projection is a pure function of its inputs.
  //   7. Cover: zero completions, partial completions, all-completed.
  //
  // The test must NOT reference any symbol from projection/ that does not
  // exist yet.  Wave 2 fills in this body once the module ships.
  // ── O1 — DETERMINISM ─────────────────────────────────────────────────────
  //
  // Computes the overdue projection twice with identical inputs and asserts
  // the results are equal.  Covers zero, partial, and all-completed scenarios.
  //
  // Uses the pure [project] + [programSchedule] functions from the new
  // projection module — no DB, no clock, no providers.
  test(
    'O1: identical inputs → identical overdue projection result (determinism)',
    () {
      // Fixed "today" — must never be DateTime.now().
      final today = DateTime.utc(2026, 5, 19);
      const n = 3; // N days of overdue.
      final anchor = today.subtract(const Duration(days: n)); // 2026-05-16

      // Build a fake calendar: one ref per day in [anchor, today].
      List<(DateTime, String)> buildCalendar() {
        final entries = <(DateTime, String)>[];
        var cursor = anchor;
        while (!cursor.isAfter(today)) {
          final label =
              'program ${cursor.year}-'
              '${cursor.month.toString().padLeft(2, '0')}-'
              '${cursor.day.toString().padLeft(2, '0')}';
          entries.add((cursor, label));
          cursor = cursor.add(const Duration(days: 1));
        }
        return entries;
      }

      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: buildCalendar(),
        today: today,
      );

      // ── Scenario A: zero completions ──────────────────────────────────────
      final r1a = project(schedule: schedule, completions: {}, today: today);
      final r2a = project(schedule: schedule, completions: {}, today: today);

      expect(r1a, equals(r2a), reason: 'O1: zero-completions — results differ');
      expect(r1a.overdue.length, n, reason: 'O1: zero-completions — N overdue');
      expect(r1a.dueToday.length, 1, reason: 'O1: zero-completions — 1 today');
      expect(
        r2a.overdue,
        equals(r1a.overdue),
        reason: 'O1: zero-completions — overdue sets are equal',
      );
      expect(
        r2a.dueToday,
        equals(r1a.dueToday),
        reason: 'O1: zero-completions — dueToday sets are equal',
      );

      // ── Scenario B: partial completions (complete one overdue unit) ────────
      final partialCompleted = {schedule.first.sefariaRef};
      final r1b = project(
        schedule: schedule,
        completions: partialCompleted,
        today: today,
      );
      final r2b = project(
        schedule: schedule,
        completions: partialCompleted,
        today: today,
      );

      expect(
        r1b,
        equals(r2b),
        reason: 'O1: partial-completions — results differ',
      );
      expect(
        r1b.overdue.length,
        n - 1,
        reason: 'O1: partial-completions — N-1 overdue after 1 completed',
      );
      expect(
        r1b.dueToday.length,
        1,
        reason: 'O1: partial-completions — today unit still pending',
      );
      expect(
        r2b.overdue,
        equals(r1b.overdue),
        reason: 'O1: partial-completions — overdue sets are equal',
      );
      expect(
        r2b.dueToday,
        equals(r1b.dueToday),
        reason: 'O1: partial-completions — dueToday sets are equal',
      );

      // ── Scenario C: all completed (including today) ────────────────────────
      final allRefs = schedule.map((u) => u.sefariaRef).toSet();
      final r1c = project(
        schedule: schedule,
        completions: allRefs,
        today: today,
      );
      final r2c = project(
        schedule: schedule,
        completions: allRefs,
        today: today,
      );

      expect(r1c, equals(r2c), reason: 'O1: all-completed — results differ');
      expect(
        r1c.overdue,
        isEmpty,
        reason: 'O1: all-completed — overdue must be empty',
      );
      expect(
        r1c.dueToday,
        isEmpty,
        reason: 'O1: all-completed — dueToday must be empty',
      );
    },
  );

  // ── O3 — COMPILING STUB (Wave 2) ────────────────────────────────────────
  //
  // Invariant: Re-anchoring a program track to today makes the overdue set
  // empty and today's unit the calendar unit for today.
  // Re-running on the same day is idempotent.
  //
  // This validates §7 of docs/planning/overdue-refactor-architecture.md.
  //
  // Wave 2 must:
  //   1. Seed a program track with trackingStartDate = N days before today.
  //   2. Compute the initial projection → verify N overdue units.
  //   3. Call the "re-anchor" operation:
  //        profile_programs.tracking_start_date = today (UTC date only)
  //        profile_programs.tracking_start_ref  = calendar(program, today)
  //      Both fields must be written to the SYNCED profile_programs row.
  //   4. Re-compute the projection.
  //   5. Assert overdueTasks is EMPTY.
  //   6. Assert dueTodayTasks has exactly 1 item, whose ref == calendar(program, today).
  //   7. Re-run the re-anchor with the same date (no-op scenario).
  //   8. Assert results are still empty overdue / 1 today unit (idempotent).
  //
  // Dependency: O3 only works after Bug 1 is fixed (Wave 1) — the re-anchor
  // is inert when the program is frozen on its start ref.
  // ── O3 — RE-ANCHOR ───────────────────────────────────────────────────────
  //
  // At the projection level, moving the anchor to today collapses overdue to
  // empty and leaves exactly one dueToday unit.
  //
  // "Re-anchor" here means: pass anchor = today to programSchedule().
  // The DB write is Wave 4's job; this test validates the pure projection
  // behaviour under a today-anchor.
  //
  // Idempotent: computing again with the same today-anchor gives the same
  // result.
  test(
    'O3: re-anchoring to today collapses overdue to empty; idempotent same-day',
    () {
      final today = DateTime.utc(2026, 5, 19);
      const n = 3;
      final originalAnchor = today.subtract(const Duration(days: n));

      // Build calendar helper: returns (date, ref) pairs for [anchor, today].
      List<(DateTime, String)> buildCalendar(DateTime anchor) {
        final entries = <(DateTime, String)>[];
        var cursor = anchor;
        while (!cursor.isAfter(today)) {
          final label =
              'daf_yomi ${cursor.year}-'
              '${cursor.month.toString().padLeft(2, '0')}-'
              '${cursor.day.toString().padLeft(2, '0')}';
          entries.add((cursor, label));
          cursor = cursor.add(const Duration(days: 1));
        }
        return entries;
      }

      // Step 1: original anchor — verify N overdue units.
      final initialSchedule = programSchedule(
        anchor: originalAnchor,
        calendarEntries: buildCalendar(originalAnchor),
        today: today,
      );
      final initial = project(
        schedule: initialSchedule,
        completions: {},
        today: today,
      );
      expect(
        initial.overdue.length,
        n,
        reason: 'O3: initial anchor → N overdue',
      );
      expect(
        initial.dueToday.length,
        1,
        reason: 'O3: initial anchor → 1 today',
      );

      // Step 2: re-anchor to today — overdue must be empty, exactly 1 today.
      // "Re-anchor" = pass anchor = today.  The calendar now spans [today, today].
      final reanchoredSchedule = programSchedule(
        anchor: today, // <-- the re-anchor
        calendarEntries: buildCalendar(today),
        today: today,
      );
      final reanchored = project(
        schedule: reanchoredSchedule,
        completions: {},
        today: today,
      );

      expect(
        reanchored.overdue,
        isEmpty,
        reason: 'O3: after re-anchor overdue must be empty',
      );
      expect(
        reanchored.dueToday.length,
        1,
        reason: 'O3: after re-anchor exactly 1 today unit',
      );
      // The today unit must be the calendar unit for today.
      expect(
        reanchored.dueToday,
        contains('daf_yomi 2026-05-19'),
        reason: 'O3: the today unit is the calendar entry for today',
      );

      // Step 3: idempotent — calling again with the same today-anchor gives
      // the identical result.
      final reanchoredAgain = project(
        schedule: reanchoredSchedule,
        completions: {},
        today: today,
      );

      expect(
        reanchoredAgain,
        equals(reanchored),
        reason: 'O3: idempotent — same result on second call with today-anchor',
      );
      expect(
        reanchoredAgain.overdue,
        isEmpty,
        reason: 'O3: idempotent — overdue still empty',
      );
      expect(
        reanchoredAgain.dueToday.length,
        1,
        reason: 'O3: idempotent — still exactly 1 today unit',
      );
    },
  );

  // ── O7 — COMPILING STUB (Wave 2) ────────────────────────────────────────
  //
  // Invariant: A self-paced track MUST have an explicit pace.
  // Without a pace the overdue projection must throw / return an error state.
  // With a pace: overdue = (pace × elapsed_study_days) − completed_count.
  //
  // This encodes §10.3 of overdue-refactor-architecture.md:
  //   - kDefaultBackfillPace (5/day) is REMOVED — no default is auto-assigned.
  //   - The setup UI forces the user to choose a pace; a track without one
  //     must prompt "set your pace" on upgrade.
  //   - The projection must NOT silently return 0 for a paceless track.
  //
  // Wave 2 must:
  //   1. Create an OverdueProjection (or equivalent) for a self-paced track
  //      with NO pace value (null / absent).
  //   2. Assert that compute() throws ArgumentError or a domain exception —
  //      a self-paced track without a pace is structurally invalid.
  //   3. Create a self-paced projection WITH an explicit pace (e.g. 5/day).
  //   4. Seed study-day data so elapsed_study_days is deterministic (use a
  //      fixed study-weekday config and a fixed anchor date).
  //   5. Complete some items.
  //   6. Assert overdue count ==
  //        max(0, pace × elapsed_study_days − completed_count).
  //   7. Assert that completed_count > pace × elapsed_study_days → overdue = 0
  //      (cannot be negative).
  //
  // Do NOT reference any symbol from projection/ that does not exist yet.
  // ── O7 — SELF-PACED NEEDS A PACE ─────────────────────────────────────────
  //
  // Part A: selfPacedSchedule() with pace = null throws MissingPaceError.
  //
  // Part B: with an explicit pace:
  //   overdue_count == max(0, pace × elapsed_study_days − completed_count)
  //
  // Uses a deterministic study-day pattern and a fixed anchor date so
  // elapsed_study_days is stable.
  test('O7: self-paced track without a pace throws; '
      'with pace yields pace × elapsed_study_days − completed', () {
    final today = DateTime.utc(2026, 5, 19); // Tuesday (weekday = 2)
    // Anchor: 7 days before today = 2026-05-12 (Tuesday).
    final anchor = today.subtract(const Duration(days: 7));

    // Study pattern: Mon-Fri only (ISO 1-5).
    const pattern = StudyDayPattern({1, 2, 3, 4, 5});

    // 28 distinct ordered refs.
    final orderedRefs = List.generate(28, (i) => 'mishna_$i');

    // ── Part A: no pace → throws MissingPaceError ─────────────────────────
    expect(
      () => selfPacedSchedule(
        anchor: anchor,
        pace: null, // intentionally no pace
        studyDayPattern: pattern,
        orderedRefs: orderedRefs,
        today: today,
      ),
      throwsA(isA<MissingPaceError>()),
      reason:
          'O7: a self-paced track without a pace must throw MissingPaceError',
    );

    // ── Part B: explicit pace = 3/day ─────────────────────────────────────
    const pace = 3;

    // Count elapsed study days in [anchor, today) manually so the test
    // is self-contained and verifiable:
    //   2026-05-12 Tue  ✓
    //   2026-05-13 Wed  ✓
    //   2026-05-14 Thu  ✓
    //   2026-05-15 Fri  ✓
    //   2026-05-16 Sat  ✗
    //   2026-05-17 Sun  ✗
    //   2026-05-18 Mon  ✓
    // Total = 5 elapsed study days before today.
    const expectedElapsed = 5;

    // Verify via the helper exported from the module.
    final actualElapsed = elapsedStudyDays(
      anchor: anchor,
      today: today,
      studyDayPattern: pattern,
    );
    expect(
      actualElapsed,
      expectedElapsed,
      reason: 'O7: elapsed_study_days helper sanity-check',
    );

    // Build the schedule; the schedule covers [anchor, today] inclusive so
    // today (Tue = study day) adds another pace units as dueToday.
    final schedule = selfPacedSchedule(
      anchor: anchor,
      pace: pace,
      studyDayPattern: pattern,
      orderedRefs: orderedRefs,
      today: today,
    );

    // Total scheduled = (elapsed + 1-today) × pace = 6 × 3 = 18 refs.
    // (assuming orderedRefs has enough items.)
    expect(
      schedule.length,
      6 * pace,
      reason: 'O7: schedule should have 6 study-day slots × $pace refs',
    );

    // ── Sub-case: zero completions ────────────────────────────────────────
    // overdue = pace × elapsed = 3 × 5 = 15;  dueToday = 3.
    final r0 = project(schedule: schedule, completions: {}, today: today);
    expect(
      r0.overdue.length,
      pace * expectedElapsed,
      reason: 'O7: 0 completions → overdue = pace × elapsed',
    );
    expect(
      r0.dueToday.length,
      pace,
      reason: 'O7: 0 completions → dueToday = pace',
    );

    // ── Sub-case: partial completions (5 completed from overdue) ─────────
    // overdue = 15 - 5 = 10.
    const completedCount = 5;
    final completed = schedule
        .take(completedCount)
        .map((u) => u.sefariaRef)
        .toSet();
    final rPartial = project(
      schedule: schedule,
      completions: completed,
      today: today,
    );
    expect(
      rPartial.overdue.length,
      (pace * expectedElapsed) - completedCount,
      reason: 'O7: partial completions → overdue = pace×elapsed − completed',
    );

    // ── Sub-case: completed_count > pace × elapsed → overdue = 0 ─────────
    // Complete MORE than pace × elapsed so overdue can never go negative.
    // Complete all overdue refs (15) + today's refs (3) = all 18.
    final allCompleted = schedule.map((u) => u.sefariaRef).toSet();
    final rAll = project(
      schedule: schedule,
      completions: allCompleted,
      today: today,
    );
    expect(
      rAll.overdue,
      isEmpty,
      reason: 'O7: all completed → overdue = 0 (never negative)',
    );
    expect(rAll.dueToday, isEmpty, reason: 'O7: all completed → dueToday = 0');
  });
}
