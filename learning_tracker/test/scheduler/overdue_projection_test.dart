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
/// O2 — REAL characterisation test (expected RED against Bug 1).
///        Wave 1 un-skips it after fixing _applyProgramCalendarOverrides.
/// O1, O3, O7 — COMPILING STUBS; Wave 2 fills them in.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

import '../helpers/drift_memory.dart';

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
// DB seeding helpers
// ---------------------------------------------------------------------------

/// Seeds an active program track for [curriculum] belonging to [profileId].
///
/// Inserts:
///   • `curriculum_tracks` row (personal, is_active = true)
///   • `profile_programs` row (programId = 1 as a placeholder — the O2 test
///     bypasses LearningProgramRepository and drives calendarService directly)
///   • `stage_definitions` row (stageOrder = 1, "Learn")
///
/// Returns the track id.
Future<int> _seedProgramTrack(
  UserDatabase db, {
  required int profileId,
  required CurriculumId curriculum,
  required DateTime trackingStartDate,
  String? trackingStartRef,
}) async {
  final track = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculum.storageKey,
          trackType: 'personal',
          isActive: const Value(true),
          activatedAt: trackingStartDate,
        ),
      );

  await db.profileProgramDao.setProfileProgram(
    profileId: profileId,
    curriculumType: curriculum.storageKey,
    programId: 1, // placeholder; production value irrelevant for O2
    trackingStartDate: trackingStartDate,
    trackingStartRef: trackingStartRef,
  );

  await db.stageDao.insertStageDefinition(
    StageDefinitionsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculum.storageKey,
      trackId: track.id,
      stageOrder: 1,
      stageName: 'Learn',
      delayDays: 0,
    ),
  );

  return track.id;
}

// ---------------------------------------------------------------------------
// Local replication of _applyProgramCalendarOverrides (Bug 1 included).
//
// PURPOSE: Let O2 compile against CURRENT code and be RED against Bug 1,
// without importing a package-private function.
//
// This mirrors the exact logic of scheduler_providers.dart:830-1009.
// Wave 1 does NOT modify this helper; it replaces the test body to call
// the fixed provider instead.
// ---------------------------------------------------------------------------

/// Replicates the "fallback" (no userSelectedTodayRef) branch of
/// _applyProgramCalendarOverrides.  This is the path exercised by O2 when
/// trackingStartRef is null.
///
/// The fallback path is CORRECT (it fetches [anchor+1, today] from the
/// calendar), so O2 with trackingStartRef=null will actually PASS against
/// Bug 1 code.  The test therefore uses the "userSelectedTodayRef" branch
/// (non-null trackingStartRef without prefix) to exercise Bug 1 directly.
Future<List<DailyTask>> _replicateOverrideLogic({
  required UserDatabase db,
  required int profileId,
  required CurriculumId curriculum,
  required int trackId,
  required DateTime now,
  required CalendarProgramService calendarService,
  required String programKey,
}) async {
  final result = <DailyTask>[];

  final enrollment = await db.profileProgramDao
      .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);
  if (enrollment == null) return result;

  final stages = await db.stageDao.getStagesByTrack(trackId);
  if (stages.isEmpty) return result;
  // stages are already ordered by stageOrder (getStagesByTrack uses
  // ..orderBy asc).
  final firstStage = stages.first;

  final todayDate = DateTime.utc(now.year, now.month, now.day);
  final DateTime configuredStartDate;
  if (enrollment.trackingStartDate == null) {
    configuredStartDate = todayDate;
  } else {
    final anchorUtc = enrollment.trackingStartDate!;
    if (anchorUtc.isBefore(DateTime.utc(2020, 1, 1))) {
      configuredStartDate = todayDate;
    } else {
      configuredStartDate = DateTime.utc(
        anchorUtc.year,
        anchorUtc.month,
        anchorUtc.day,
      );
    }
  }

  if (configuredStartDate.isAfter(todayDate)) return result;

  // Determine userSelectedTodayRef — same logic as production.
  final rawRef = enrollment.trackingStartRef;
  String? userSelectedTodayRef;
  if (rawRef != null && rawRef.isNotEmpty) {
    if (rawRef.contains('|ref:')) {
      final parts = rawRef.split('|ref:');
      if (parts.length > 1) userSelectedTodayRef = parts[1].trim();
    } else if (!rawRef.startsWith('offset:')) {
      userSelectedTodayRef = rawRef; // Bug 1 entry point
    }
  }

  final List<CalendarProgramEntry> entries;
  if (userSelectedTodayRef != null && userSelectedTodayRef.isNotEmpty) {
    // ── BUG 1 BRANCH ─────────────────────────────────────────────────────
    // Production code:
    //   startRangeDate = today + 1 day
    //   rangeEntries   = startRangeDate.isBefore(today) ? ... : []
    //                  = ALWAYS []
    //   entries        = [todayEntry]  ← frozen, never advances
    final todayEntry = CalendarProgramEntry(
      programId: programKey,
      displayNameEn: '',
      displayNameHe: '',
      todayRef: userSelectedTodayRef,
      apiSource: 'fake',
    );
    final startRangeDate = todayDate.add(const Duration(days: 1));
    // BUG 1: the condition is always false → rangeEntries is always empty.
    final rangeEntries = startRangeDate.isBefore(todayDate)
        ? await calendarService.getEntriesForRange(
            programKey,
            startRangeDate,
            todayDate.add(const Duration(days: 30)),
          )
        : <CalendarProgramEntry>[];
    entries = [todayEntry, ...rangeEntries];
  } else {
    // ── FALLBACK BRANCH (correct) ─────────────────────────────────────────
    var effectiveStartDate = configuredStartDate.add(const Duration(days: 1));
    if (effectiveStartDate.isAfter(todayDate)) {
      effectiveStartDate = todayDate;
    }
    final rangeEntries =
        effectiveStartDate.isBefore(todayDate) ||
            effectiveStartDate == todayDate
        ? await calendarService.getEntriesForRange(
            programKey,
            effectiveStartDate,
            todayDate,
          )
        : <CalendarProgramEntry>[];
    entries = rangeEntries.isNotEmpty
        ? rangeEntries
        : [
            if (await calendarService.getEntry(programKey, todayDate)
                case final e?)
              e,
          ];
  }

  if (entries.isEmpty) return result;

  for (var i = 0; i < entries.length; i++) {
    final isTodayUnit = i == entries.length - 1;
    result.add(
      DailyTask(
        curriculumId: curriculum,
        // Use the raw todayRef as the sefariaRef (same as displayProgramRef
        // fallback when no content items match).
        contentItemSefariaRef: entries[i].todayRef,
        stageOrder: firstStage.stageOrder,
        stageDefinitionId: firstStage.id,
        priority: isTodayUnit
            ? DailyTaskPriority.todayProgram
            : DailyTaskPriority.overdueProgram,
        isOverdue: !isTodayUnit,
        reason: isTodayUnit
            ? 'Program assignment for today'
            : 'Program day pending from previous days',
        stageName: firstStage.stageName,
        trackId: trackId,
        trackLabel: 'personal',
        estimatedEffortMinutes: 5,
      ),
    );
  }
  return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── O2 — REAL characterisation test (Wave 1 un-skips) ───────────────────
  //
  // What Bug 1 does today:
  //   When tracking_start_ref is a raw Sefaria ref (e.g. "Berakhot 2a"),
  //   _applyProgramCalendarOverrides treats it as userSelectedTodayRef,
  //   then tries to fetch "subsequent days from tomorrow onward" by calling
  //   getEntriesForRange(tomorrow, …) guarded by
  //   startRangeDate.isBefore(today) — ALWAYS false.
  //   Result: entries = [todayEntry only] → 1 task, 0 overdue. Frozen forever.
  //
  // What the test asserts (the CORRECT behaviour after Wave 1's fix):
  //   With trackingStartRef = "daf_yomi 2026-05-16" (a raw legacy ref),
  //   N=3 anchor days before today, no completions:
  //     • 3 tasks with isOverdue == true
  //     • 1 task  with isOverdue == false (today's unit)
  //
  // The test is RED today because Bug 1 produces only 1 task (0 overdue).
  test(
    'O2: program track anchored N days ago (with legacy trackingStartRef) → '
    'N overdue units + 1 today unit',
    skip: 'un-skip in Wave 1',
    () async {
      // Fixed "today" = 2026-05-19 (UTC).  N = 3 days before today.
      const n = 3;
      const programKey = 'daf_yomi';
      final today = DateTime.utc(2026, 5, 19);
      final anchor = today.subtract(const Duration(days: n)); // 2026-05-16

      final db = inMemoryDb();
      addTearDown(db.close);

      await seedProfile(db); // inserts account + profile with id=1
      const profileId = 1;
      const curriculum = CurriculumId.bavli;

      // Seed a program track anchored at [anchor] with a raw legacy
      // tracking_start_ref — this is the Bug 1 trigger path.
      // The ref value matches what the fake engine would return for [anchor].
      const legacyStartRef = '$programKey 2026-05-16';
      final trackId = await _seedProgramTrack(
        db,
        profileId: profileId,
        curriculum: curriculum,
        trackingStartDate: anchor,
        trackingStartRef: legacyStartRef, // ← activates Bug 1
      );

      final fakeEngine = _FakeCalendarEngine(programKey);
      final calendarService = CalendarProgramService(fakeEngine);

      // Exercise the replicated _applyProgramCalendarOverrides logic.
      final tasks = await _replicateOverrideLogic(
        db: db,
        profileId: profileId,
        curriculum: curriculum,
        trackId: trackId,
        now: today,
        calendarService: calendarService,
        programKey: programKey,
      );

      final overdueTasks = tasks.where((t) => t.isOverdue).toList();
      final todayTasks = tasks.where((t) => !t.isOverdue).toList();

      // O2 ASSERTION: correct behaviour (fails against Bug 1).
      expect(
        overdueTasks,
        hasLength(n),
        reason:
            'O2: $n days of backlog with no completions → $n overdue tasks. '
            'Bug 1 produces 0 because the range-fetch condition is always false.',
      );
      expect(
        todayTasks,
        hasLength(1),
        reason:
            'O2: exactly 1 task is due today (calendar unit for today). '
            "Bug 1 produces 1 task but it's frozen on tracking_start_ref.",
      );
      expect(
        overdueTasks.every(
          (t) => t.priority == DailyTaskPriority.overdueProgram,
        ),
        isTrue,
        reason: 'O2: overdue tasks must carry the overdueProgram priority.',
      );
      expect(
        todayTasks.first.priority,
        DailyTaskPriority.todayProgram,
        reason: "O2: today's unit must carry the todayProgram priority.",
      );

      // O2 OVERDUE-CONTENT CHECK: overdue refs must be distinct days in
      // [anchor+1, today−1] and the today ref must be the calendar unit for today.
      // (Proves the schedule advances, not freezes.)
      final overdueRefs = overdueTasks
          .map((t) => t.contentItemSefariaRef)
          .toSet();
      final todayRef = todayTasks.first.contentItemSefariaRef;

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
    },
  );

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
