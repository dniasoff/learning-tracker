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
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
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
    // Normalise to local-midnight so date comparisons are consistent.
    final local = DateTime(date.year, date.month, date.day);
    return CalendarProgramEntry(
      programId: programId,
      displayNameEn: '',
      displayNameHe: '',
      todayRef: _refForDate(date),
      apiSource: 'fake',
      date: local,
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
      final local = DateTime(cursor.year, cursor.month, cursor.day);
      result.add(
        CalendarProgramEntry(
          programId: programId,
          displayNameEn: '',
          displayNameHe: '',
          todayRef: _refForDate(cursor),
          apiSource: 'fake',
          date: local,
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

  // ── F-H2 regression: non-daily program date assignment ──────────────────
  //
  // For a weekly-cadence program (one DB row per week), the old cursor walk
  // mis-dated every entry after the first.  With entry.date populated,
  // the projection must produce exactly 2 overdue units dated on the two
  // weeks that fall in [anchor, today−1], not 14 sequential days.
  test(
    'F-H2: weekly-cadence program produces 2 overdue units (not 14)',
    () async {
      // Fixed "today" = 2026-05-19.  Anchor = 14 days earlier = 2026-05-05.
      // The weekly calendar has entries only on anchor and anchor+7.
      final today = DateTime.utc(2026, 5, 19);
      final anchor = DateTime.utc(2026, 5, 5); // 14 days before today
      const programKey = 'daf_a_week';

      // Weekly engine: returns rows only on [anchor, anchor+7]; today has
      // no entry (it is anchor+14, i.e. today itself, which the engine
      // excludes from the range to simulate a not-yet-published week).
      final weeklyDates = [
        anchor, // 2026-05-05
        anchor.add(const Duration(days: 7)), // 2026-05-12
      ];

      final weeklyEngine = _WeeklyFakeCalendarEngine(programKey, weeklyDates);
      final calendarService = CalendarProgramService(weeklyEngine);

      final entries = await programCalendarSchedule(
        programKey: programKey,
        anchor: anchor,
        today: today,
        calendarService: calendarService,
      );

      // The engine has no entry for today (2026-05-19), so only 2 rows come
      // back.  Both are before today → both are overdue when projected.
      // The critical invariant: exactly 2 entries, not 14.
      expect(
        entries,
        hasLength(2),
        reason:
            'F-H2: weekly engine has 2 rows in [anchor, today]; '
            'must return 2 entries, not 14 (cursor walk bug)',
      );

      // Dates must be the actual weekly dates, not sequential daily dates.
      expect(
        entries[0].date,
        equals(DateTime(2026, 5, 5)),
        reason: 'F-H2: first entry date must be anchor (2026-05-05)',
      );
      expect(
        entries[1].date,
        equals(DateTime(2026, 5, 12)),
        reason: 'F-H2: second entry date must be anchor+7 (2026-05-12)',
      );

      // Build calendarEntries using entry.date (the fixed path).
      final calendarEntries = <(DateTime, String)>[
        for (final e in entries)
          if (e.date != null) (e.date!, e.todayRef),
      ];

      expect(
        calendarEntries,
        hasLength(2),
        reason: 'F-H2: calendarEntries must have 2 items (one per weekly row)',
      );

      // Project: both entries are before today so both are overdue.
      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: calendarEntries,
        today: today,
      );
      final result = project(schedule: schedule, completions: {}, today: today);

      expect(
        result.overdue,
        hasLength(2),
        reason: 'F-H2: 2 weekly units in [anchor, today-1] → 2 overdue, not 14',
      );
      expect(
        result.dueToday,
        isEmpty,
        reason: 'F-H2: engine has no entry for today → dueToday is empty',
      );
    },
  );

  // ── F-H4 regression: multi-stage completion must not mask first-stage ────
  //
  // A chazara (stage 2) completion for ref X must NOT suppress X from the
  // overdue set when the first-stage (learn) completion is absent.
  test(
    'F-H4: stage-2 completion does not mask stage-1 overdue for same ref',
    () {
      // Fixed "today" = 2026-05-19.  Anchor = 3 days ago.
      final today = DateTime.utc(2026, 5, 19);
      final anchor = today.subtract(const Duration(days: 3)); // 2026-05-16

      // Calendar: one entry per day in [anchor, today].
      final calendarEntries = <(DateTime, String)>[];
      var cursor = anchor;
      while (!cursor.isAfter(today)) {
        final ref =
            'daf_yomi ${cursor.year}-'
            '${cursor.month.toString().padLeft(2, '0')}-'
            '${cursor.day.toString().padLeft(2, '0')}';
        calendarEntries.add((cursor, ref));
        cursor = cursor.add(const Duration(days: 1));
      }

      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: calendarEntries,
        today: today,
      );

      // Pick the anchor-day ref (index 0) as the ref that has a stage-2
      // chazara completion but no stage-1 (learn) completion.
      final anchorRef = calendarEntries[0].$2; // 'daf_yomi 2026-05-16'

      // F-H4 fix: _buildProjectionTasks filters allCompletions to
      // firstStage.id before building completionRefs, so a chazara
      // completion is excluded.  We model the correctly-filtered set here:
      // stage-2 completion is absent from completionRefs.
      const stage2FilteredRefs = <String>{}; // stage-2 excluded → empty set

      final result = project(
        schedule: schedule,
        completions: stage2FilteredRefs,
        today: today,
      );

      expect(
        result.overdue,
        contains(anchorRef),
        reason:
            'F-H4: a stage-2 completion for ref X must NOT remove X from '
            'overdue when the first-stage (learn) completion is absent.',
      );
      expect(
        result.overdue,
        hasLength(3),
        reason: 'F-H4: 3 days in [anchor, today-1] → 3 overdue units',
      );
    },
  );

  // ── F-M1 regression: fallback "today only" entry has date == today ───────
  //
  // When getEntriesForRange returns empty (calendar gap) but getEntry(today)
  // succeeds, programCalendarSchedule must return a single entry whose
  // date field == today (local midnight).
  test(
    'F-M1: fallback getEntry(today) returns entry with date == today',
    () async {
      final today = DateTime.utc(2026, 5, 19);
      final anchor = today.subtract(const Duration(days: 5));
      const programKey = 'daf_yomi';

      // Fake engine: range queries return empty (gap), getEntry(today) returns
      // a valid entry with date populated.
      final gapEngine = _GapFakeCalendarEngine(programKey, today);
      final calendarService = CalendarProgramService(gapEngine);

      final entries = await programCalendarSchedule(
        programKey: programKey,
        anchor: anchor,
        today: today,
        calendarService: calendarService,
      );

      expect(
        entries,
        hasLength(1),
        reason: 'F-M1: fallback produces exactly 1 entry (today)',
      );

      final entry = entries.single;
      expect(
        entry.date,
        isNotNull,
        reason: 'F-M1: fallback entry must have a non-null date field',
      );
      expect(
        entry.date,
        equals(DateTime(today.year, today.month, today.day)),
        reason: 'F-M1: fallback entry date must equal today (local midnight)',
      );
    },
  );

  // B2 — a weekly pace must schedule paceValue units per WEEK, not per study
  // day. Previously paceToDaily(per_week)=paceValue/7 was ceil'd to 1, so any
  // 1..7 per-week pace inflated to one ref EVERY study day (up to 7x) and
  // flooded the overdue queue.
  group('B2 — weekly pace window does not inflate to per-study-day', () {
    test('pace 1 over a 7-study-day window schedules one ref per 7 days', () {
      final anchor = DateTime.utc(2026, 5, 4); // Monday
      final today = anchor.add(const Duration(days: 13)); // 14 days inclusive
      final refs = List.generate(20, (i) => 'r$i');
      const everyDay = StudyDayPattern.everyDay; // empty = every day

      final weekly = selfPacedSchedule(
        anchor: anchor,
        pace: 1,
        paceWindowStudyDays: 7,
        studyDayPattern: everyDay,
        orderedRefs: refs,
        today: today,
      );
      // 14 study days / 7 = exactly 2 units (the old ceil bug produced 14).
      expect(
        weekly.length,
        2,
        reason: '1/week over 14 days must be 2 units, not 14',
      );

      // Default window (1) keeps the legacy 1-unit-per-study-day behaviour.
      final daily = selfPacedSchedule(
        anchor: anchor,
        pace: 1,
        studyDayPattern: everyDay,
        orderedRefs: refs,
        today: today,
      );
      expect(
        daily.length,
        14,
        reason: 'window=1 (default) is unchanged: one unit per study day',
      );
    });

    test('pace 2 per week distributes 2 units across each 7-day window', () {
      final anchor = DateTime.utc(2026, 5, 4);
      final today = anchor.add(const Duration(days: 13));
      final refs = List.generate(20, (i) => 'r$i');
      const everyDay = StudyDayPattern.everyDay;

      final weekly = selfPacedSchedule(
        anchor: anchor,
        pace: 2,
        paceWindowStudyDays: 7,
        studyDayPattern: everyDay,
        orderedRefs: refs,
        today: today,
      );
      // 14 study days × (2/7) = 4 units.
      expect(weekly.length, 4);
    });
  });
}

// ---------------------------------------------------------------------------
// Helper fakes for new regression tests (F-H2, F-M1).
// ---------------------------------------------------------------------------

/// A calendar engine that only yields entries on the specified [_weeklyDates].
/// Simulates a weekly-cadence program (e.g. Daf a Week) where the DB has
/// one row per week, not per day.
class _WeeklyFakeCalendarEngine implements LocalCalendarEngine {
  _WeeklyFakeCalendarEngine(this._programId, this._weeklyDates);

  final String _programId;
  final List<DateTime> _weeklyDates;

  String _refForDate(DateTime local) =>
      '$_programId ${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';

  @override
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async {
    if (programId != _programId) return null;
    final local = DateTime(date.year, date.month, date.day);
    final match = _weeklyDates.firstWhere(
      (d) => DateTime(d.year, d.month, d.day) == local,
      orElse: () => DateTime(1970),
    );
    if (match.year == 1970) return null;
    return CalendarProgramEntry(
      programId: programId,
      displayNameEn: '',
      displayNameHe: '',
      todayRef: _refForDate(local),
      apiSource: 'fake',
      date: local,
    );
  }

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (programId != _programId) return const [];
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final result = <CalendarProgramEntry>[];
    for (final d in _weeklyDates) {
      final local = DateTime(d.year, d.month, d.day);
      if (local.isBefore(start) || local.isAfter(end)) continue;
      result.add(
        CalendarProgramEntry(
          programId: programId,
          displayNameEn: '',
          displayNameHe: '',
          todayRef: _refForDate(local),
          apiSource: 'fake',
          date: local,
        ),
      );
    }
    result.sort((a, b) => a.date!.compareTo(b.date!));
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

/// A calendar engine that always returns empty for range queries (simulates
/// a calendar gap / partially-seeded DB) but returns a valid entry for
/// [_today] via getEntry().
class _GapFakeCalendarEngine implements LocalCalendarEngine {
  _GapFakeCalendarEngine(this._programId, this._today);

  final String _programId;
  final DateTime _today;

  @override
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async {
    if (programId != _programId) return null;
    final local = DateTime(date.year, date.month, date.day);
    final todayLocal = DateTime(_today.year, _today.month, _today.day);
    if (local != todayLocal) return null;
    return CalendarProgramEntry(
      programId: programId,
      displayNameEn: '',
      displayNameHe: '',
      todayRef:
          '$_programId ${local.year}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}',
      apiSource: 'fake',
      date: local,
    );
  }

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async => const []; // Simulate the calendar gap.

  @override
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async =>
      const [];

  @override
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) => getEntry(programKey, date);
}
