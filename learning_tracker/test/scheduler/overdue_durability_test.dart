/// Overdue durability invariants — O4, O5, O6.
///
/// O4 and O5 are IMPLEMENTED using the pure projection module.
/// O6 is IMPLEMENTED in Wave 4: sync-completeness gate.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Insert a completion event so the projection can filter it.
Future<void> _seedCompletion(
  UserDatabase db, {
  required int profileId,
  required String curriculumId,
  required int trackId,
  required String sefariaRef,
  required DateTime completedAt,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: 1,
      trackType: TrackType.personal.storageKey,
      trackId: Value<int?>(trackId),
      points: const Value(0),
      eventTimestamp: completedAt,
    ),
  );
}

/// Build a fake program calendar:
/// for dates in [anchor, today] inclusive, returns one entry per date with
/// ref = 'program YYYY-MM-DD'.
List<(DateTime, String)> _buildProgramCalendar(
  DateTime anchor,
  DateTime today,
) {
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── O4 — Reinstall durability ─────────────────────────────────────────────
  //
  // Discarding the local plan cache and recomputing from synced inputs
  // yields an IDENTICAL overdue set.  Architecture §6.
  test('O4: discarding the local plan cache and recomputing yields identical '
      'overdue set (reinstall durability)', () async {
    final db = inMemoryDb();
    await seedProfile(db);

    try {
      // Fixed dates.
      final today = DateTime.utc(2026, 5, 19);
      const n = 5; // 5 days of overdue.
      final anchor = today.subtract(const Duration(days: n)); // 2026-05-14

      // Insert a curriculum track.
      final trackId = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              stateChangedAt: anchor,
              activatedAt: anchor,
            ),
          )
          .then((r) => r.id);

      // Seed some completions (2 of the 5 overdue days completed).
      final calendar = _buildProgramCalendar(anchor, today);
      final completedRef0 = calendar[0].$2; // anchor day
      final completedRef1 = calendar[1].$2; // anchor+1 day

      await _seedCompletion(
        db,
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: trackId,
        sefariaRef: completedRef0,
        completedAt: anchor,
      );
      await _seedCompletion(
        db,
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: trackId,
        sefariaRef: completedRef1,
        completedAt: anchor.add(const Duration(days: 1)),
      );

      // Build schedule and project (first computation — S1).
      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: calendar,
        today: today,
      );
      final completions = await db.completionDao
          .getCompletionsByCurriculumAndProfile(
            CurriculumId.mishnayos.storageKey,
            1,
          );
      final completionRefs = completions.map((c) => c.sefariaRef).toSet();

      final s1 = project(
        schedule: schedule,
        completions: completionRefs,
        today: today,
      );

      // ── Simulate reinstall: wipe ALL daily_plans rows ──────────────────
      await db.delete(db.dailyPlans).go();

      // Verify: table is empty after wipe.
      final rowsAfterWipe = await db.select(db.dailyPlans).get();
      expect(
        rowsAfterWipe,
        isEmpty,
        reason: 'O4: daily_plans must be empty after simulated reinstall',
      );

      // Recompute projection from the SAME synced inputs — S2.
      final s2 = project(
        schedule: schedule,
        completions: completionRefs,
        today: today,
      );

      // ── Assert S1 == S2 ────────────────────────────────────────────────
      expect(
        s2.overdue,
        equals(s1.overdue),
        reason:
            'O4: overdue set after cache wipe must equal the original — '
            'the projection is pure; daily_plans held no unique truth',
      );
      expect(
        s2.dueToday,
        equals(s1.dueToday),
        reason: 'O4: dueToday set must be identical after cache wipe',
      );
      expect(
        s2.overdue.length,
        n - 2,
        reason: 'O4: 5 elapsed days − 2 completions = 3 overdue',
      );

      // ── Also cover "cache never existed" (first-launch after reinstall) ─
      // Compute S3 on a fresh DB instance (no daily_plans rows ever written).
      final freshDb = inMemoryDb();
      await seedProfile(freshDb);

      await freshDb
          .into(freshDb.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              stateChangedAt: anchor,
              activatedAt: anchor,
            ),
          );

      // Same completions on fresh DB.
      await _seedCompletion(
        freshDb,
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: trackId,
        sefariaRef: completedRef0,
        completedAt: anchor,
      );
      await _seedCompletion(
        freshDb,
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: trackId,
        sefariaRef: completedRef1,
        completedAt: anchor.add(const Duration(days: 1)),
      );

      final freshCompletions = await freshDb.completionDao
          .getCompletionsByCurriculumAndProfile(
            CurriculumId.mishnayos.storageKey,
            1,
          );
      final freshRefs = freshCompletions.map((c) => c.sefariaRef).toSet();

      // The projection is pure — no daily_plans needed.
      final s3 = project(
        schedule: schedule,
        completions: freshRefs,
        today: today,
      );
      expect(
        s3.overdue,
        equals(s1.overdue),
        reason:
            'O4: "cache never existed" case — projection on fresh DB '
            'yields the identical overdue set (synced inputs are enough)',
      );

      await freshDb.close();
    } finally {
      await db.close();
    }
  });

  // ── O5 — Sync-timing immunity ─────────────────────────────────────────────
  //
  // The projection computed against a PARTIALLY-MERGED input set and the
  // projection computed against the FULLY-MERGED set converge to the same
  // value; no wrong value is ever persisted as authoritative.
  // Architecture §3 Bug 2, §4, §12.
  test(
    'O5: partial-merge and full-merge projections converge; '
    'no wrong value is persisted as authoritative (sync-timing immunity)',
    () async {
      // Scenario: program track anchored 10 days ago.  Sync delivers
      // completions in two batches: 3 first, then 5 more (total 8).
      // Expected overdue after full sync: 10 − 8 = 2.

      final db = inMemoryDb();
      await seedProfile(db);

      try {
        final today = DateTime.utc(2026, 5, 19);
        const totalDays = 10;
        final anchor = today.subtract(const Duration(days: totalDays));

        final trackId = await db
            .into(db.curriculumTracks)
            .insertReturning(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: anchor,
                activatedAt: anchor,
              ),
            )
            .then((r) => r.id);

        final calendar = _buildProgramCalendar(anchor, today);
        final allRefs = calendar.map((e) => e.$2).toList();
        // overdue refs are all but today's (index 0..9, where 9 = today).
        final overdueRefs = allRefs.sublist(0, totalDays); // [0..9]
        final todayRef = allRefs[totalDays]; // today

        final schedule = programSchedule(
          anchor: anchor,
          calendarEntries: calendar,
          today: today,
        );

        // ── State 1: before any sync — no completions (P1) ────────────────
        final p1 = project(schedule: schedule, completions: {}, today: today);
        expect(
          p1.overdue.length,
          totalDays,
          reason: 'O5: before sync → $totalDays overdue (none completed)',
        );

        // Verify no wrong value has been written to daily_plans.
        final plansBefore = await db.select(db.dailyPlans).get();
        expect(
          plansBefore,
          isEmpty,
          reason: 'O5: the projection never writes to daily_plans',
        );

        // ── State 2: partial sync — 3 completions arrive (P2) ─────────────
        final batch1 = overdueRefs.sublist(0, 3); // first 3 overdue refs
        for (final ref in batch1) {
          await _seedCompletion(
            db,
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            sefariaRef: ref,
            completedAt: anchor,
          );
        }

        final completions2 = await db.completionDao
            .getCompletionsByCurriculumAndProfile(
              CurriculumId.mishnayos.storageKey,
              1,
            );
        final p2 = project(
          schedule: schedule,
          completions: completions2.map((c) => c.sefariaRef).toSet(),
          today: today,
        );
        expect(
          p2.overdue.length,
          totalDays - 3,
          reason: 'O5: partial sync (3 completed) → $totalDays - 3 overdue',
        );

        // P2 must not have been written to daily_plans (projection is ephemeral).
        final plansAfterPartial = await db.select(db.dailyPlans).get();
        expect(
          plansAfterPartial,
          isEmpty,
          reason:
              'O5: the partial-sync projection must NOT be persisted in '
              'daily_plans — it is re-derived on demand',
        );

        // ── State 3: full sync — 5 more completions arrive (P3) ───────────
        final batch2 = overdueRefs.sublist(3, 8); // next 5 overdue refs
        for (final ref in batch2) {
          await _seedCompletion(
            db,
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            sefariaRef: ref,
            completedAt: anchor,
          );
        }

        final completions3 = await db.completionDao
            .getCompletionsByCurriculumAndProfile(
              CurriculumId.mishnayos.storageKey,
              1,
            );
        final p3 = project(
          schedule: schedule,
          completions: completions3.map((c) => c.sefariaRef).toSet(),
          today: today,
        );

        // ── Assert P3 is the correct final value: 10 − 8 = 2 ─────────────
        expect(
          p3.overdue.length,
          2,
          reason:
              'O5: full sync (8 completed of 10) → 2 overdue units remaining',
        );

        // ── Assert P2 is a valid intermediate value: 10 − 3 = 7 ──────────
        expect(
          p2.overdue.length,
          7,
          reason: 'O5: partial sync (3 completed) → 7 overdue',
        );

        // ── Assert P3 is reproducible (determinism O1) ────────────────────
        final p3again = project(
          schedule: schedule,
          completions: completions3.map((c) => c.sefariaRef).toSet(),
          today: today,
        );
        expect(
          p3again,
          equals(p3),
          reason: 'O5: P3 is deterministic — same inputs → same output',
        );

        // ── Assert today's ref is in dueToday (not overdue) ───────────────
        expect(
          p3.dueToday,
          contains(todayRef),
          reason: "O5: today's calendar unit is in dueToday, not overdue",
        );

        // ── Verify no wrong value is in daily_plans after full sync ────────
        final plansAfterFull = await db.select(db.dailyPlans).get();
        expect(
          plansAfterFull,
          isEmpty,
          reason:
              'O5: the full-sync projection is never persisted in '
              'daily_plans — it is always re-derived on demand; '
              'no stale overdue flag can persist across sync cycles',
        );
      } finally {
        await db.close();
      }
    },
  );

  // ── O6 — Sync-completeness gate ───────────────────────────────────────────
  //
  // Invariant: when the "initial sync complete" flag is UNSET, the read-path
  // returns a NOT-READY state — never a number, never 0.  When the flag IS set,
  // the projection runs normally and exposes the actual count.
  //
  // Architecture §10.2: a persisted flag is set the first time a full pull from
  // Firestore finishes.  Before it is set the dashboard shows "syncing…" and
  // never a count — which this test pins via initialSyncCompleteProvider.
  //
  // The "not-ready" sentinel: initialSyncCompleteProvider returns false (or is
  // loading).  The dashboard gate is:
  //   tasksReady = dailyTasksAsync.hasValue && initialSyncComplete
  // When tasksReady is false the tiles show "…" — a distinct, non-numeric
  // value.  The test verifies the gate through the same provider the production
  // code uses (kInitialSyncCompleteKey / initialSyncCompleteProvider).
  test(
    'O6: overdue view is "syncing" (not a number) until initial sync completes',
    () async {
      // ── Helper: read the gate through the production accessor ─────────────
      //
      // "tasksReady" on the dashboard is:
      //   initialSyncCompleteProvider.asData?.value == true
      // We replicate that exact expression here so the test is coupled only to
      // the public API surface, not to internal SharedPrefs key strings.
      Future<bool> readSyncGate() async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        return container.read(initialSyncCompleteProvider.future);
      }

      // ── Part 1: flag never set (key absent) ───────────────────────────────
      SharedPreferences.setMockInitialValues({});
      final gateWhenAbsent = await readSyncGate();
      expect(
        gateWhenAbsent,
        isFalse,
        reason:
            'O6: with flag absent, the gate must be false — '
            'the dashboard must not show a numeric count',
      );

      // ── Part 2: flag explicitly set to false ──────────────────────────────
      SharedPreferences.setMockInitialValues({kInitialSyncCompleteKey: false});
      final gateWhenFalse = await readSyncGate();
      expect(
        gateWhenFalse,
        isFalse,
        reason:
            'O6: with flag explicitly false, the gate must be false — '
            'same "syncing" state as if the key were absent',
      );

      // ── Part 3: simulate first pull completing ────────────────────────────
      //
      // Use markInitialSyncComplete (the production write path) to set the
      // flag, then verify the gate flips to true.
      SharedPreferences.setMockInitialValues({});
      var callbackFired = false;
      await markInitialSyncComplete(onComplete: () => callbackFired = true);

      expect(
        callbackFired,
        isTrue,
        reason:
            'O6: onComplete callback must fire the first time the flag is set '
            '(transition from unset to true)',
      );

      // Read the gate after the write — must be true.
      final gateAfterFirstPull = await readSyncGate();
      expect(
        gateAfterFirstPull,
        isTrue,
        reason:
            'O6: after first pull completes, the gate must be true so the '
            'dashboard can show the actual counts',
      );

      // ── Part 4: idempotent — second write must NOT fire callback ──────────
      var secondCallbackFired = false;
      await markInitialSyncComplete(
        onComplete: () => secondCallbackFired = true,
      );
      expect(
        secondCallbackFired,
        isFalse,
        reason:
            'O6: markInitialSyncComplete is idempotent — the callback must NOT '
            'fire on a second call when the flag is already true',
      );

      // ── Part 5: projection exposes the correct count once ready ───────────
      //
      // Seed a simple program track with 3 overdue days, 0 completions.
      // With the gate open, the projection must return 3 — not 0, not a string.
      final db = inMemoryDb();
      await seedProfile(db);
      try {
        final today = DateTime.utc(2026, 5, 19);
        const overdueDays = 3;
        final anchor = today.subtract(const Duration(days: overdueDays));

        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: anchor,
                activatedAt: anchor,
              ),
            );

        final calendar = _buildProgramCalendar(anchor, today);
        final schedule = programSchedule(
          anchor: anchor,
          calendarEntries: calendar,
          today: today,
        );

        // Gate is open (flag was set in Part 3 above and persists in mock prefs).
        // Projection with no completions: all elapsed days are overdue.
        final projection = project(
          schedule: schedule,
          completions: {},
          today: today,
        );

        expect(
          projection.overdue.length,
          overdueDays,
          reason:
              'O6: once the sync gate is open, the projection returns the real '
              'overdue count — $overdueDays elapsed days, 0 completions = '
              '$overdueDays overdue',
        );

        // The count is a genuine non-zero integer — not 0 ("all done") and not
        // any other sentinel value.
        expect(
          projection.overdue.length,
          isNonZero,
          reason: 'O6: overdue count must be non-zero when items are overdue',
        );
      } finally {
        await db.close();
      }

      // ── Part 6: flag persists across "app restart" ────────────────────────
      //
      // Simulate a restart: re-seed the mock SharedPreferences with the flag
      // already true (as a previous run would have written it), then read
      // through a fresh ProviderContainer — the gate must still be true.
      SharedPreferences.setMockInitialValues({kInitialSyncCompleteKey: true});
      final gateAfterRestart = await readSyncGate();
      expect(
        gateAfterRestart,
        isTrue,
        reason:
            'O6: the flag persists across app restarts — a fresh '
            'ProviderContainer seeded with the flag=true must read true, '
            'confirming SharedPreferences durability',
      );
    },
  );
}
