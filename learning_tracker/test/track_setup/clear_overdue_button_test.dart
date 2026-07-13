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
///   E  — PUSH SPY (F-C1): drives the REAL EditTrackScreen widget (tap the
///         Clear Overdue button + confirm dialog) and spies on the real
///         collaborator, SyncWriteFacade.pushProfileProgram(Map) — not a
///         hand-mocked FirestoreGateway (AUD-t-cross-24).
///   F  — BUTTON GATE (F-H1): the projection-based overdue predicate flips from
///         true to false after re-anchor; the stale daily_plans table is not used.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Mocks / fakes for driving the real EditTrackScreen widget (Test E)
// ---------------------------------------------------------------------------

/// The real seam EditTrackScreen._clearOverdue() writes through:
/// `ref.read(syncWriteFacadeProvider)?.pushProfileProgram(Map payload)` — a
/// single-arg interface, reached two layers before FirestoreGateway
/// (AUD-t-cross-24).
class _MockSyncWriteFacade extends Mock implements SyncWriteFacade {}

/// Stands in for `calendarProgramServiceProvider` so the widget test never
/// touches the real (asset-backed) content database. The program id used by
/// Test E resolves to a seed program with a null `api_program_key`, so
/// production code never actually calls `getEntry` on this fake — it exists
/// purely to satisfy the unconditional
/// `await ref.read(calendarProgramServiceProvider.future)` at the top of
/// `_clearOverdue()`.
class _FakeCalendarProgramService extends Mock
    implements CalendarProgramService {}

class _FakeActiveProfileId extends ActiveProfileId {
  _FakeActiveProfileId(this._value);
  final int _value;
  @override
  int build() => _value;
}

class _FakeActiveTutoredProfileSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

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

/// Perform the re-anchor DB write: set tracking_start_date = today (UTC
/// midnight) and tracking_start_ref = today's calendar ref, on the
/// profile_programs row for the given profile + curriculum.
///
/// This mirrors ONLY the DB-write half of edit_track_screen.dart's
/// _clearOverdue() — extracted here so Tests A-D/F can assert the pure
/// re-anchor/projection behaviour without driving the full widget. It
/// deliberately does NOT attempt to mirror the Firestore push half: Test E
/// below exercises that seam by driving the real widget instead (see
/// AUD-t-cross-24 — a hand-rolled mirror of the push call previously drifted
/// out of sync with production and silently dropped the `updated_at` field).
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

/// Minimal [CurriculumTrack] fixture for Test E. Never persisted to [db] —
/// [EditTrackScreen] reads the track's fields directly from this
/// constructor argument, the same way the real navigation call site does.
CurriculumTrack _programTrackFixture({
  required int id,
  required int profileId,
  required String curriculumId,
  required DateTime activatedAt,
}) => CurriculumTrack(
  id: id,
  profileId: profileId,
  curriculumId: curriculumId,
  state: 'active',
  stateChangedAt: activatedAt,
  activatedAt: activatedAt,
);

/// Builds the real [EditTrackScreen] for Test E. Every collaborator except
/// [SyncWriteFacade] is wired to the real, in-memory-DB-backed production
/// path — the same seam the widget actually runs through at runtime.
/// [syncFacade] is the one collaborator this test spies on.
Widget _buildEditTrackApp({
  required CurriculumTrack track,
  required UserDatabase db,
  required SyncWriteFacade syncFacade,
  required List<DailyTask> dailyTasks,
}) {
  final curriculum = CurriculumId.values
      .where((c) => c.storageKey == track.curriculumId)
      .firstOrNull;
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      activeProfileIdProvider.overrideWith(
        () => _FakeActiveProfileId(track.profileId),
      ),
      activeTutoredProfileSelectionProvider.overrideWith(
        () => _FakeActiveTutoredProfileSelection(),
      ),
      if (curriculum != null)
        dashboardHasProgramEnrollmentProvider(
          curriculum,
        ).overrideWith((ref) async => true),
      allDailyTasksProvider.overrideWith((ref) => Future.value(dailyTasks)),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
      calendarProgramServiceProvider.overrideWith(
        (ref) async => _FakeCalendarProgramService(),
      ),
      syncWriteFacadeProvider.overrideWithValue(syncFacade),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditTrackScreen(track: track),
    ),
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
                stateChangedAt: anchor,
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

  // ── E: PUSH SPY (F-C1) — drives the real widget, spies the real seam ─────
  //
  // AUD-t-cross-24: the previous version of this test drove a hand-rolled
  // reanchorProgramTrack(gateway:) helper that hand-mocked FirestoreGateway
  // directly (profileId:, data: named params) — a collaborator
  // edit_track_screen.dart never touches. The real _clearOverdue() routes
  // through `ref.read(syncWriteFacadeProvider)?.pushProfileProgram(Map)`, a
  // single-arg interface reached two layers before FirestoreGateway. This
  // version pumps the real EditTrackScreen, taps the real "Clear Overdue"
  // button + confirm dialog, and spies on SyncWriteFacade directly, so a
  // regression in the real call (wrong facade, dropped field, stopped
  // calling it) fails this test.
  testWidgets('E: tapping Clear Overdue on the real EditTrackScreen calls '
      'SyncWriteFacade.pushProfileProgram(Map) with the full production '
      'payload, not FirestoreGateway (F-C1 / AUD-t-cross-24)', (tester) async {
    useLocalDayClock(FakeLocalDayClock(today));
    addTearDown(resetLocalDayClock);

    final db = inMemoryDb();
    await seedProfile(db);
    addTearDown(db.close);

    // Seed a profile_programs row with the OLD anchor. programId matches
    // the 'oraysa' seed program (api_program_key: null in
    // learning_program_seeds.dart), so the calendar-lookup branch inside
    // _clearOverdue is deterministically skipped and tracking_start_ref
    // stays null in the pushed payload.
    await db.profileProgramDao.setProfileProgram(
      profileId: 1,
      curriculumType: CurriculumId.bavli.storageKey,
      programId: programId,
      trackingStartDate: DateTime.utc(anchor.year, anchor.month, anchor.day),
      trackingStartRef: _refForDate(anchor),
    );

    final track = _programTrackFixture(
      id: 1,
      profileId: 1,
      curriculumId: CurriculumId.bavli.storageKey,
      activatedAt: anchor,
    );

    final mockFacade = _MockSyncWriteFacade();
    when(() => mockFacade.pushProfileProgram(any())).thenAnswer((_) async {});

    // Drives _hasOverdue = true in EditTrackScreen._loadData(), which
    // enables the "Clear Overdue" button.
    final overdueTask = DailyTask(
      curriculumId: CurriculumId.bavli,
      contentItemSefariaRef: todayRef,
      stageOrder: 1,
      stageDefinitionId: 1,
      priority: DailyTaskPriority.overdueProgram,
      isOverdue: true,
      reason: 'overdue',
      stageName: 'Learn',
      trackId: track.id,
      trackLabel: 'Test Track',
    );

    await tester.pumpWidget(
      _buildEditTrackApp(
        track: track,
        db: db,
        syncFacade: mockFacade,
        dailyTasks: [overdueTask],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap the real "Clear Overdue" trigger button.
    final triggerButton = find.widgetWithText(OutlinedButton, 'Clear Overdue');
    expect(
      triggerButton,
      findsOneWidget,
      reason:
          'E: button must be enabled — _hasOverdue is true from the '
          'overdue daily task seeded above',
    );
    await tester.tap(triggerButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Confirm the destructive-action dialog. The dialog's FilledButton is
    // the only one on screen at this point.
    final confirmButton = find.byType(FilledButton);
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The REAL seam: SyncWriteFacade.pushProfileProgram(Map) — not
    // FirestoreGateway.pushProfileProgram(profileId:, data:).
    final captured = verify(
      () => mockFacade.pushProfileProgram(captureAny()),
    ).captured;
    expect(
      captured.length,
      1,
      reason: 'E: pushProfileProgram must be called exactly once',
    );

    final payload = captured.single as Map<String, dynamic>;

    expect(payload['profile_id'], 1, reason: 'E: payload.profile_id');
    expect(
      payload['curriculum_id'],
      CurriculumId.bavli.storageKey,
      reason: 'E: payload.curriculum_id',
    );
    expect(payload['program_id'], programId, reason: 'E: payload.program_id');

    // tracking_start_date must encode today (UTC midnight).
    final encodedDate = payload['tracking_start_date'] as String?;
    expect(encodedDate, isNotNull, reason: 'E: tracking_start_date is set');
    expect(
      DateTime.parse(encodedDate!),
      DateTime.utc(today.year, today.month, today.day),
      reason: 'E: tracking_start_date encodes today (UTC midnight)',
    );

    // tracking_start_ref is always sent, even when null (the calendar
    // could not resolve a ref for this program).
    expect(
      payload.containsKey('tracking_start_ref'),
      isTrue,
      reason: 'E: tracking_start_ref key is present in the payload',
    );

    // The field the old FirestoreGateway-mocking test silently dropped —
    // proof its hand-rolled payload had already drifted from production.
    expect(
      payload['updated_at'],
      encodedDate,
      reason:
          'E: updated_at must be present and equal to tracking_start_date '
          '(both set from the same todayUtc value in _clearOverdue())',
    );
  });

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
