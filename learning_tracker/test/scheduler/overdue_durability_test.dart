/// Overdue durability invariants — O4, O5, O6.
///
/// These invariants test behaviours that depend on APIs built in LATER waves:
///   • O4, O5 — the pure projection module (Wave 3: durability / reinstall).
///   • O6 — the "initial sync complete" flag (Wave 4).
///
/// All three are COMPILING STUBS: each has a thorough comment specifying
/// exactly what the owning wave must set up and assert.
/// Bodies are empty; NO symbols from not-yet-existing modules are referenced.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── O4 — COMPILING STUB (Wave 3) ────────────────────────────────────────
  //
  // Invariant: Reinstall durability.
  //   Discarding the local plan cache and recomputing from synced inputs only
  //   yields an IDENTICAL overdue set to the one computed before the discard.
  //
  // Background (§6 of overdue-refactor-architecture.md):
  //   `daily_plans` is a disposable cache.  The only truth is in synced tables:
  //     • profile_programs (anchor / tracking_start_date)
  //     • curriculum_tracks (activation date, pace baseline)
  //     • completion_events (the log)
  //     • study_day_config  (weekday pattern)
  //   Losing the cache (reinstall, wipe) must cost nothing — the projection
  //   rebuilds the identical answer.
  //
  // Wave 3 must set up and assert:
  //   1. Seed a UserDatabase with a program track anchored N days ago and some
  //      completions.  Run the projection → capture overdue set S1.
  //   2. Delete ALL rows from `daily_plans` (the cache) — simulate reinstall.
  //   3. Recompute the projection using the SAME DB (synced inputs intact).
  //      Capture overdue set S2.
  //   4. Assert S1 == S2 (identical overdue sets, identical counts, identical
  //      sefariaRefs).
  //   5. Also assert S2 is computed WITHOUT reading any `daily_plans` row —
  //      either by asserting the table is empty post-discard, or by verifying
  //      the projection does not reference it at all (pure function).
  //   6. Cover both "cache existed and was discarded" and "cache never existed"
  //      (first-launch after reinstall).
  //
  // Implementation notes for Wave 3:
  //   • The projection module (lib/features/scheduler/domain/projection/)
  //     ships in Wave 2; Wave 3 proves its reinstall behaviour.
  //   • Use seedProfile + _seedProgramTrack from overdue_projection_test.dart
  //     (or the shared helpers in test/helpers/).
  //   • The assertion "S1 == S2" must be an equality check on Sets, not just
  //     count equality — two identical counts with different refs is a bug.
  test(
    'O4: discarding the local plan cache and recomputing yields identical '
    'overdue set (reinstall durability)',
    skip: 'un-skip in Wave 3',
    () {
      // TODO(Wave 3): implement after the pure projection module (Wave 2) and
      // the daily_plans demotion (Wave 3) are in place.
    },
  );

  // ── O5 — COMPILING STUB (Wave 3) ────────────────────────────────────────
  //
  // Invariant: Sync-timing immunity.
  //   The projection computed against a PARTIALLY-MERGED input set and the
  //   projection computed against the FULLY-MERGED set converge to the same
  //   value; no wrong value is ever persisted as authoritative.
  //
  // Background (§3 Bug 2, §4, §12 of overdue-refactor-architecture.md):
  //   Bug 2: the daily plan is snapshotted while an asynchronous launch sync
  //   is still merging curriculum_tracks, profile_programs, and completions
  //   into the DB.  When sync finishes, `rebuildPlan` re-runs and the OVERDUE
  //   count changes with no user action — non-deterministic.
  //   The projection model fixes this: it is a pure function re-derived on
  //   demand; it never persists an overdue count; so a partial-merge only
  //   causes a momentary stale view, which self-corrects when sync completes.
  //
  // Wave 3 must set up and assert:
  //   1. Seed a UserDatabase representing the "before launch sync" state:
  //        • profile_programs with an old anchor (e.g. 10 days ago).
  //        • No completions yet.
  //      Compute projection P1.
  //   2. Simulate a partial sync merge: add 3 completion_events rows.
  //      Compute projection P2.
  //   3. Simulate full sync completion: add the remaining 5 completion_events
  //      rows that the sync also delivers (total 8 completions for the 10-day
  //      window).  Compute projection P3.
  //   4. Assert P3 is the correct final value (10 - 8 = 2 overdue units).
  //   5. Assert P2 is a valid intermediate value (10 - 3 = 7 overdue).
  //   6. Assert that NEITHER P1 NOR P2 was ever WRITTEN to `daily_plans` as
  //      an authoritative overdue count — the projection is never persisted.
  //      (Check that daily_plans is either empty or has no `is_overdue` column
  //      with a stale value.)
  //   7. Assert P3 == recomputing from the same inputs (determinism, O1).
  //
  // The key invariant: "no wrong value is ever persisted as authoritative."
  // The projection model satisfies this by construction — it is never stored.
  //
  // Implementation notes for Wave 3:
  //   • This test relies on the pure projection module from Wave 2.
  //   • The "initial sync complete" flag (O6 / Wave 4) is NOT yet required
  //     for O5 — O5 tests intermediate states, O6 gates the whole view.
  //   • Use the two-device-harness pattern from test/sync/two_device_sync_test.dart
  //     if it helps model concurrent device writes, but it is not required.
  test(
    'O5: partial-merge and full-merge projections converge; '
    'no wrong value is persisted as authoritative (sync-timing immunity)',
    skip: 'un-skip in Wave 3',
    () {
      // TODO(Wave 3): implement after the pure projection module ships (Wave 2).
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
