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
  test(
    'O1: identical inputs → identical overdue projection result (determinism)',
    skip: 'un-skip in Wave 2',
    () {
      // TODO(Wave 2): implement with OverdueProjection.compute().
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
  test(
    'O3: re-anchoring to today collapses overdue to empty; idempotent same-day',
    skip: 'un-skip in Wave 2',
    () {
      // TODO(Wave 2): implement after Bug 1 is fixed (Wave 1) and the
      // pure projection module exists.
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
  test(
    'O7: self-paced track without a pace throws; '
    'with pace yields pace × elapsed_study_days − completed',
    skip: 'un-skip in Wave 2',
    () {
      // TODO(Wave 2): implement using OverdueProjection for self-paced tracks.
    },
  );
}
