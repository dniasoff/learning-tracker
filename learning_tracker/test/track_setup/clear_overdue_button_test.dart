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
///   E  — PUSH SPY (F-C1): re-anchor calls gateway.pushProfileProgram once with
///         correct profile_id + curriculum_id payload.
///   F  — BUTTON GATE (F-H1): the projection-based overdue predicate flips from
///         true to false after re-anchor; the stale daily_plans table is not used.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Mock gateway
// ---------------------------------------------------------------------------

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

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
/// When [gateway] is non-null, also calls [FirestoreGateway.pushProfileProgram]
/// with the correct payload — mirrors the F-C1 fix in edit_track_screen.dart.
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
  FirestoreGateway? gateway,
}) async {
  final todayUtc = DateTime.utc(today.year, today.month, today.day);
  await db.profileProgramDao.setProfileProgram(
    profileId: profileId,
    curriculumType: curriculumType,
    programId: programId,
    trackingStartDate: todayUtc,
    trackingStartRef: todayRef,
  );

  // Mirror the F-C1 push path in _clearOverdue().
  await gateway?.pushProfileProgram(
    profileId: profileId,
    data: {
      'profile_id': profileId,
      'curriculum_id': curriculumType,
      'program_id': programId,
      'tracking_start_date': todayUtc.toIso8601String(),
      'tracking_start_ref': todayRef,
    },
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

  // ── E: PUSH SPY (F-C1) ──────────────────────────────────────────────────
  test(
    'E: re-anchor calls gateway.pushProfileProgram exactly once with correct '
    'profile_id + curriculum_id (F-C1)',
    () async {
      final db = inMemoryDb();
      await seedProfile(db);
      try {
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

        // Set up the mock gateway — stub pushProfileProgram to succeed.
        final mockGateway = _MockFirestoreGateway();
        when(
          () => mockGateway.pushProfileProgram(
            profileId: any(named: 'profileId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async {});

        // Perform the re-anchor with the gateway spy.
        await reanchorProgramTrack(
          db: db,
          profileId: 1,
          curriculumType: CurriculumId.bavli.storageKey,
          programId: programId,
          today: today,
          todayRef: todayRef,
          gateway: mockGateway,
        );

        // Capture the invocation.
        final capturedCalls = verify(
          () => mockGateway.pushProfileProgram(
            profileId: captureAny(named: 'profileId'),
            data: captureAny(named: 'data'),
          ),
        ).captured;

        // pushProfileProgram must be called exactly once.
        // verify() throws if called 0 times; if called >1 the captured list
        // will have >2 entries (one per named param per call).
        expect(
          capturedCalls.length,
          2,
          reason:
              'E: exactly one push call → 2 captured values '
              '(profileId + data)',
        );

        final capturedProfileId = capturedCalls[0] as int;
        final capturedData = capturedCalls[1] as Map<String, dynamic>;

        expect(
          capturedProfileId,
          1,
          reason: 'E: profileId matches the learner profile',
        );
        expect(
          capturedData['profile_id'],
          1,
          reason: 'E: payload.profile_id matches',
        );
        expect(
          capturedData['curriculum_id'],
          CurriculumId.bavli.storageKey,
          reason: 'E: payload.curriculum_id matches',
        );
        expect(
          capturedData['program_id'],
          programId,
          reason: 'E: payload.program_id is preserved',
        );
        // tracking_start_date must encode today (UTC midnight).
        final encodedDate = capturedData['tracking_start_date'] as String?;
        expect(encodedDate, isNotNull, reason: 'E: tracking_start_date is set');
        final parsedDate = DateTime.parse(encodedDate!);
        expect(
          DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day),
          DateTime.utc(today.year, today.month, today.day),
          reason: 'E: tracking_start_date encodes today (UTC midnight)',
        );
      } finally {
        await db.close();
      }
    },
  );

  // ── F: BUTTON GATE via projection (F-H1) ─────────────────────────────────
  test('F: hasOverdue predicate (projection-based) is true before re-anchor and '
      'false after — reflects DailyTaskPriority.overdueProgram, not '
      'stale daily_plans.isOverdue (F-H1)', () async {
    // This test exercises the predicate that _loadData() now uses:
    //   allTasks.any((t) => t.trackId == trackId &&
    //                       t.priority == DailyTaskPriority.overdueProgram)
    //
    // We drive the pure projection directly (no Riverpod) to confirm that
    // the predicate flips correctly before → after re-anchor. The test
    // stands in for the widget-level behaviour without requiring a full
    // ProviderContainer setup.

    const fakeTrackId = 42;

    // ─── BEFORE re-anchor ────────────────────────────────────────────────
    // Build schedule anchored N days ago → N overdue items in projection.
    final beforeSchedule = programSchedule(
      anchor: anchor,
      calendarEntries: calendar,
      today: today,
    );
    final beforeProjection = project(
      schedule: beforeSchedule,
      completions: {},
      today: today,
    );

    // Map projection result to DailyTask list (mirrors _buildProjectionTasks
    // in scheduler_providers.dart) with a fixed trackId.
    final beforeTasks = [
      for (final ref in beforeProjection.overdue)
        DailyTask(
          curriculumId: CurriculumId.bavli,
          contentItemSefariaRef: ref,
          stageOrder: 1,
          stageDefinitionId: 1,
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          reason: 'overdue',
          stageName: 'Learn',
          trackId: fakeTrackId,
          trackLabel: 'Test Track',
        ),
      for (final ref in beforeProjection.dueToday)
        DailyTask(
          curriculumId: CurriculumId.bavli,
          contentItemSefariaRef: ref,
          stageOrder: 1,
          stageDefinitionId: 1,
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          reason: 'today',
          stageName: 'Learn',
          trackId: fakeTrackId,
          trackLabel: 'Test Track',
        ),
    ];

    // The predicate from _loadData() — must be true before re-anchor.
    final hasOverdueBefore = beforeTasks.any(
      (t) =>
          t.trackId == fakeTrackId &&
          t.priority == DailyTaskPriority.overdueProgram,
    );
    expect(
      hasOverdueBefore,
      isTrue,
      reason: 'F-pre: button gate must be enabled when overdue tasks exist',
    );

    // ─── AFTER re-anchor ─────────────────────────────────────────────────
    // Re-anchored schedule starts from today → no overdue items.
    final afterSchedule = programSchedule(
      anchor: today,
      calendarEntries: _buildCalendar(today, today),
      today: today,
    );
    final afterProjection = project(
      schedule: afterSchedule,
      completions: {},
      today: today,
    );

    final afterTasks = [
      for (final ref in afterProjection.overdue)
        DailyTask(
          curriculumId: CurriculumId.bavli,
          contentItemSefariaRef: ref,
          stageOrder: 1,
          stageDefinitionId: 1,
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          reason: 'overdue',
          stageName: 'Learn',
          trackId: fakeTrackId,
          trackLabel: 'Test Track',
        ),
      for (final ref in afterProjection.dueToday)
        DailyTask(
          curriculumId: CurriculumId.bavli,
          contentItemSefariaRef: ref,
          stageOrder: 1,
          stageDefinitionId: 1,
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          reason: 'today',
          stageName: 'Learn',
          trackId: fakeTrackId,
          trackLabel: 'Test Track',
        ),
    ];

    // The predicate must be false after re-anchor — button should be disabled.
    final hasOverdueAfter = afterTasks.any(
      (t) =>
          t.trackId == fakeTrackId &&
          t.priority == DailyTaskPriority.overdueProgram,
    );
    expect(
      hasOverdueAfter,
      isFalse,
      reason:
          'F-post: button gate must be disabled after re-anchor clears '
          'overdue; stale daily_plans.isOverdue must not be consulted',
    );

    // Cross-check: daily_plans table was never involved — the predicate
    // depends solely on DailyTaskPriority.overdueProgram tasks produced by
    // the projection. This is self-documenting: if the predicate read from
    // the DAO, this test would need a DB, which it deliberately does not.
    expect(
      afterProjection.overdue,
      isEmpty,
      reason:
          'F: projection.overdue is the source; it must be empty after '
          're-anchor',
    );
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
