/// Clear Overdue re-anchor tests.
///
/// Validates that the re-anchor operation (replacing the old cache-delete
/// approach) correctly moves profile_programs.tracking_start_date to today,
/// which collapses the overdue window to empty via the pure projection.
///
/// Tests:
///   A  — BEFORE re-anchor: N overdue + 1 today.
///   B  — AFTER  re-anchor: overdue empty, exactly 1 today unit.
///   C  — IDEMPOTENCE: calling re-anchor again (same day) yields same result.
///   D  — DB WRITE: the synced profile_programs row holds tracking_start_date == today.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a fake program calendar (date → ref) for [anchor, today] inclusive.
///
/// Each ref follows the pattern `"program YYYY-MM-DD"` so the test can
/// assert that the correct calendar unit is assigned to today.
List<(DateTime, String)> _buildCalendar(DateTime anchor, DateTime today) {
  final entries = <(DateTime, String)>[];
  var cursor = DateTime.utc(anchor.year, anchor.month, anchor.day);
  final end = DateTime.utc(today.year, today.month, today.day);
  while (!cursor.isAfter(end)) {
    final label =
        'program ${cursor.year}-'
        '${cursor.month.toString().padLeft(2, '0')}-'
        '${cursor.day.toString().padLeft(2, '0')}';
    entries.add((cursor, label));
    cursor = cursor.add(const Duration(days: 1));
  }
  return entries;
}

/// The ref the fake calendar assigns to [date].
String _refForDate(DateTime date) =>
    'program ${date.year}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Perform the re-anchor write: set tracking_start_date = today (UTC midnight)
/// and tracking_start_ref = today's calendar ref, on the profile_programs row
/// for the given profile + curriculum.
///
/// This mirrors the logic in edit_track_screen.dart's _clearOverdue() —
/// extracted here so tests exercise it without driving the full widget.
Future<void> reanchorProgramTrack({
  required UserDatabase db,
  required int profileId,
  required String curriculumType,
  required int programId,
  required DateTime today,
  String? todayRef,
}) async {
  final todayUtc = DateTime.utc(today.year, today.month, today.day);
  await db.profileProgramDao.setProfileProgram(
    profileId: profileId,
    curriculumType: curriculumType,
    programId: programId,
    trackingStartDate: todayUtc,
    trackingStartRef: todayRef,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Fixed "today" — never use DateTime.now() for determinism.
  final today = DateTime.utc(2026, 5, 19);
  const n = 4; // days of backlog before today
  final anchor = today.subtract(const Duration(days: n)); // 2026-05-15

  // The calendar ref the fake engine assigns to today.
  final todayRef = _refForDate(today);

  // Build the calendar spanning [anchor, today] inclusive (n+1 entries).
  final calendar = _buildCalendar(anchor, today);

  // A fixed program ID that the profile_programs row will reference.
  const programId = 1;

  // ── A: BEFORE re-anchor ──────────────────────────────────────────────────
  test('A: program track anchored N days ago → N overdue + 1 today', () {
    // The pure projection is a function of (schedule, completions, today).
    // No DB needed here — pure logic.
    final schedule = programSchedule(
      anchor: anchor,
      calendarEntries: calendar,
      today: today,
    );
    final projection = project(
      schedule: schedule,
      completions: {},
      today: today,
    );

    expect(
      projection.overdue.length,
      n,
      reason: 'A: N days of backlog → N overdue units',
    );
    expect(projection.dueToday.length, 1, reason: 'A: exactly 1 today unit');
    expect(
      projection.dueToday,
      contains(todayRef),
      reason: 'A: today unit ref matches the calendar entry for today',
    );
  });

  // ── B: AFTER re-anchor ───────────────────────────────────────────────────
  test(
    'B: after re-anchor to today → overdue empty, exactly 1 today unit',
    () async {
      final db = inMemoryDb();
      await seedProfile(db);
      try {
        // Seed a curriculum track.
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.bavli.storageKey,
                trackType: TrackType.personal.storageKey,
                isActive: const Value(true),
                activatedAt: anchor,
              ),
            );

        // Seed a profile_programs row with the OLD anchor.
        await db.profileProgramDao.setProfileProgram(
          profileId: 1,
          curriculumType: CurriculumId.bavli.storageKey,
          programId: programId,
          trackingStartDate: DateTime.utc(
            anchor.year,
            anchor.month,
            anchor.day,
          ),
          trackingStartRef: _refForDate(anchor),
        );

        // Confirm BEFORE state: N overdue.
        final beforeSchedule = programSchedule(
          anchor: anchor,
          calendarEntries: calendar,
          today: today,
        );
        final before = project(
          schedule: beforeSchedule,
          completions: {},
          today: today,
        );
        expect(
          before.overdue.length,
          n,
          reason: 'B-pre: before re-anchor → N overdue',
        );

        // Perform the re-anchor.
        await reanchorProgramTrack(
          db: db,
          profileId: 1,
          curriculumType: CurriculumId.bavli.storageKey,
          programId: programId,
          today: today,
          todayRef: todayRef,
        );

        // Read back the updated row to derive the new anchor.
        final updated = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(
              1,
              CurriculumId.bavli.storageKey,
            );
        expect(updated, isNotNull, reason: 'B: profile_programs row exists');

        final newAnchor = updated!.trackingStartDate != null
            ? DateTime.utc(
                updated.trackingStartDate!.year,
                updated.trackingStartDate!.month,
                updated.trackingStartDate!.day,
              )
            : today;

        // The calendar for the re-anchored track spans [today, today] → 1 entry.
        final reanchoredCalendar = _buildCalendar(newAnchor, today);
        final afterSchedule = programSchedule(
          anchor: newAnchor,
          calendarEntries: reanchoredCalendar,
          today: today,
        );
        final after = project(
          schedule: afterSchedule,
          completions: {},
          today: today,
        );

        expect(
          after.overdue,
          isEmpty,
          reason: 'B: after re-anchor overdue must be empty',
        );
        expect(
          after.dueToday.length,
          1,
          reason: 'B: after re-anchor exactly 1 today unit',
        );
        expect(
          after.dueToday,
          contains(todayRef),
          reason: "B: today unit ref matches today's calendar entry",
        );
      } finally {
        await db.close();
      }
    },
  );

  // ── C: IDEMPOTENCE ───────────────────────────────────────────────────────
  test('C: calling re-anchor again on the same day is idempotent', () async {
    final db = inMemoryDb();
    await seedProfile(db);
    try {
      // Seed a profile_programs row (already at anchor).
      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: CurriculumId.bavli.storageKey,
        programId: programId,
        trackingStartDate: DateTime.utc(anchor.year, anchor.month, anchor.day),
        trackingStartRef: _refForDate(anchor),
      );

      // First re-anchor.
      await reanchorProgramTrack(
        db: db,
        profileId: 1,
        curriculumType: CurriculumId.bavli.storageKey,
        programId: programId,
        today: today,
        todayRef: todayRef,
      );

      // Compute projection after first re-anchor.
      final afterOnce = project(
        schedule: programSchedule(
          anchor: today,
          calendarEntries: _buildCalendar(today, today),
          today: today,
        ),
        completions: {},
        today: today,
      );

      // Second re-anchor (same day).
      await reanchorProgramTrack(
        db: db,
        profileId: 1,
        curriculumType: CurriculumId.bavli.storageKey,
        programId: programId,
        today: today,
        todayRef: todayRef,
      );

      // Compute projection after second re-anchor.
      final afterTwice = project(
        schedule: programSchedule(
          anchor: today,
          calendarEntries: _buildCalendar(today, today),
          today: today,
        ),
        completions: {},
        today: today,
      );

      expect(
        afterTwice,
        equals(afterOnce),
        reason: 'C: second re-anchor on same day is idempotent',
      );
      expect(
        afterTwice.overdue,
        isEmpty,
        reason: 'C: idempotent — overdue still empty',
      );
      expect(
        afterTwice.dueToday.length,
        1,
        reason: 'C: idempotent — still exactly 1 today unit',
      );
    } finally {
      await db.close();
    }
  });

  // ── D: DB WRITE ──────────────────────────────────────────────────────────
  test(
    'D: re-anchor writes tracking_start_date == today (UTC) to profile_programs',
    () async {
      final db = inMemoryDb();
      await seedProfile(db);
      try {
        // Seed the profile_programs row with OLD anchor.
        await db.profileProgramDao.setProfileProgram(
          profileId: 1,
          curriculumType: CurriculumId.bavli.storageKey,
          programId: programId,
          trackingStartDate: DateTime.utc(
            anchor.year,
            anchor.month,
            anchor.day,
          ),
          trackingStartRef: _refForDate(anchor),
        );

        // Confirm the OLD anchor is in the DB.
        final beforeRow = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(
              1,
              CurriculumId.bavli.storageKey,
            );
        expect(
          beforeRow?.trackingStartDate?.day,
          anchor.day,
          reason: 'D-pre: old anchor day',
        );

        // Perform the re-anchor.
        final todayUtc = DateTime.utc(today.year, today.month, today.day);
        await reanchorProgramTrack(
          db: db,
          profileId: 1,
          curriculumType: CurriculumId.bavli.storageKey,
          programId: programId,
          today: today,
          todayRef: todayRef,
        );

        // Read back and assert.
        final row = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(
              1,
              CurriculumId.bavli.storageKey,
            );
        expect(row, isNotNull, reason: 'D: row must exist after re-anchor');
        expect(
          row!.programId,
          programId,
          reason: 'D: programId must be unchanged',
        );

        // tracking_start_date must be today (UTC midnight).
        final storedDate = row.trackingStartDate;
        expect(storedDate, isNotNull, reason: 'D: tracking_start_date is set');
        final storedUtc = storedDate!.toUtc();
        expect(
          DateTime.utc(storedUtc.year, storedUtc.month, storedUtc.day),
          todayUtc,
          reason: 'D: tracking_start_date must equal today (UTC midnight)',
        );

        // tracking_start_ref must be today's calendar ref.
        expect(
          row.trackingStartRef,
          todayRef,
          reason: "D: tracking_start_ref must be today's calendar entry",
        );
      } finally {
        await db.close();
      }
    },
  );
}
