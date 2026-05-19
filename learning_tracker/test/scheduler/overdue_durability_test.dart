/// Overdue durability invariants — O4, O5, O6.
///
/// O4 and O5 are now IMPLEMENTED using the pure projection module.
/// O6 stays skipped — Wave 4 owns it.
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
              trackType: TrackType.personal.storageKey,
              isActive: const Value(true),
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
              trackType: TrackType.personal.storageKey,
              isActive: const Value(true),
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
                trackType: TrackType.personal.storageKey,
                isActive: const Value(true),
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

  // ── O6 — COMPILING STUB (Wave 4) ────────────────────────────────────────
  //
  // Invariant: Sync-completeness gate.
  //   When the "initial sync complete" flag is UNSET, the overdue view reports
  //   a "not-ready / syncing" state — never a number, never 0.
  //   When the flag IS set, the projection runs on local data normally.
  //
  // Background (§10.2 of overdue-refactor-architecture.md):
  //   A persisted "initial sync complete" flag is set the first time a full
  //   pull from Firestore finishes.  Before it is set, the DB might hold an
  //   empty or partial completion log — the projection would produce an
  //   artificially high overdue count (or 0 if the tracks haven't synced yet).
  //   Showing that as a number is misleading.  The dashboard must show a
  //   "syncing…" indicator instead.
  //   This replaces the `dailyTasksAsync.value ?? []` masking at
  //   dashboard_body.dart:134.
  //
  // Wave 4 must set up and assert:
  //   1. The "initial sync complete" flag is stored persistently (SharedPrefs
  //      or the UserDatabase — the exact location is a Wave 4 decision).
  //   2. With the flag UNSET:
  //        a. The overdue view (dashboard / provider / projection read-path)
  //           returns a SyncingState / NotReadyState — NOT a numeric count.
  //        b. Specifically: the view must NOT return 0 (which would suggest
  //           "all done" to the user).
  //        c. The view must NOT return any positive integer (which would
  //           suggest "N items overdue" when data is incomplete).
  //   3. Set the flag (simulate first full pull completing).
  //   4. Assert the view now returns the projection's computed count normally.
  //   5. Cover: flag absent (never-set) AND flag explicitly set to false.
  //   6. Cover: flag set, then app restarts — flag must persist across restarts.
  //      (Test with a new DB / SharedPrefs instance seeded with the flag.)
  //
  // Implementation notes for Wave 4:
  //   • The flag location (SharedPrefs vs DB column) is a Wave 4 design choice.
  //     This test must adapt to that choice.
  //   • The "not-ready" return type should be a sealed variant (e.g.
  //     OverdueView.syncing vs OverdueView.ready(count)) so the caller cannot
  //     accidentally treat syncing as 0.
  //   • This test MUST NOT read the flag directly from SharedPreferences in a
  //     way that couples to the implementation; use the same accessor the
  //     production code uses.
  //   • Reference: dashboard_body.dart:134 and the sync rework S-invariants
  //     in test/sync/sync_rework_engine_test.dart for style guidance.
  test(
    'O6: overdue view is "syncing" (not a number) until initial sync completes',
    skip: 'un-skip in Wave 4',
    () {
      // TODO(Wave 4): implement using the "initial sync complete" flag API.
    },
  );
}
