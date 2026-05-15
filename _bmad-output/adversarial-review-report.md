# BMAD Adversarial Review — Epics 24–27
**Date:** 2026-05-14
**Codebase HEAD:** fdc2d4f1
**Scope:** All Linear stories from DNI-312 (E24) through DNI-315 (E27)
**Method:** Per-story AC validation against origin/dev HEAD — adversarial lens
**Status:** COMPLETE

---

## Executive Summary

| Epic | Stories | ✅ Pass | ⚠️ Partial | ❌ Fail | Pass Rate |
|------|---------|--------|-----------|--------|-----------|
| E24 — Stop-the-Bleeding (DNI-312) | 8 | 8 | 0 | 0 | 100% |
| E25 — Schema + Core Foundation (DNI-313) | 22 | 15 | 7 | 0 | 68% |
| E26 — Feature Rebuilds + Cleanups (DNI-314) | 33 | 17 | 13 | 1 | 52% |
| E27 — Discipline & Closure (DNI-315) | 16 | 4 | 11 | 1 | 25% |
| **TOTAL** | **79** | **44** | **31** | **2** | **56%** |

> Note: E26 squad agent ran against the local working tree (which has unstaged dev-agent edits). Two of three original "Fail" ratings were downgraded to Partial after independent verification against `origin/dev` via `git show`. Numbers above reflect origin/dev-verified ratings.

---

## Confirmed Hard Issues (verified against origin/dev HEAD)

These were independently verified with `git show origin/dev:...`.

### CRITICAL — Custom lint package broken (27.10)
`packages/custom_lints/lib/learning_tracker_lints.dart` imports:
- `src/rules/no_curriculum_display_name_bypass.dart`
- `src/rules/no_feature_cross_import.dart`

**Neither file exists in origin/dev.** The lint package fails to compile. The three rules that DO exist (`no_firebase_outside_core`, `no_raw_talker`, `no_hardcoded_text_direction`) are unreachable. Additionally, `custom_lint` is not declared in `learning_tracker/pubspec.yaml`, so the plugin is not loaded by the analyzer even if it compiled.

### HIGH — StreakReducer unit tests still stubbed (27.2)
`test/features/sync/domain/reducers/streak_reducer_test.dart` contains only:
```dart
test('StreakReducer coverage placeholder', () {}, skip: 'DNI-337 pending');
```
DNI-337 landed at `5423d95f`. The TODO was never resolved. Zero unit test coverage for `StreakReducer`.

### HIGH — `sync_engine.dart` monolith still live (25.12)
`lib/features/sync/data/sync_engine.dart` is **3,252 lines** on origin/dev.
AC required it to be reduced to <300 lines or deleted after extracting `FirestoreGateway`/`PushPipeline`/`PullPipeline`. The new `core/sync/` classes exist but `sync_engine.dart` remains the live production path. Its test file is `.skip`-suffixed.

### HIGH — `dashboard_screen.dart` not decomposed (26.5)
`lib/features/dashboard/presentation/screens/dashboard_screen.dart` is **2,221 lines** on origin/dev.
AC required < 600 lines after extracting 20 private classes. Story was marked Done but extraction appears partial or was lost during merge conflict resolution.

### MEDIUM — Firebase Auth leaking outside core/auth (25.11)
`firebase_auth` imported directly in:
- `lib/core/sync/firestore_gateway_impl.dart`
- `lib/features/auth/presentation/providers/auth_providers.dart`

AC required `FirebaseAuth.instance` to exist only inside `core/auth/AuthRepository`.

### MEDIUM — `GoalFormResult` not deleted (26.4)
`lib/features/scheduler/domain/models/goal_form_result.dart` (27 lines) still exists on origin/dev. AC required complete replacement with `GoalEntity`. Still referenced in `goal_setup_screen.dart`, `step_goal.dart`, `add_track_flow_screen.dart`.

### MEDIUM — `SacredWindow` is in-memory only (26.24)
AC explicitly required a **persisted DB table** so background notification fire-time checks can run without the Flutter engine. Implementation uses an in-memory cache. Background suppression will fail on cold-start.

### MEDIUM — `StageDao` bypass calls remain (26.26)
At least 9 `db.stageDao.*` call sites remain outside `StageDefinitionRepository`. AC required the repository to be the sole write path.

### LOW — 3 of 7 TrackProgressVariant files not deleted (26.8)
`chazara_status.dart`, `momentum_status.dart`, `calendar_position.dart` (+ `calendar_position_providers.dart`) still exist on origin/dev. The other 4 files were correctly deleted.

### LOW — `CompletionWriter.commit()` inserts 2 rows, not 3 (25.15)
AC requires atomic insert into `completion_events` + `completions` + `outbox`. Implementation only inserts `completions` + `outbox`. The implementation comment explicitly defers `completion_events` insertion.

### LOW — Orphan Drift table files (25.1)
`tables/profiles.dart` and `tables/user_profiles.dart` exist but are not in `@DriftDatabase`. Dead generated code.

### LOW — `duplicate_completion_exception.dart` accesses `.displayNameEn` (25.9)
Line 31 accesses `.displayNameEn` outside `core/labels/` — violates the no_curriculum_display_name_bypass rule (which is ironically not enforced, per 27.10).

### LOW — `AddTrackFlowScreen` oversized + hardcoded strings (26.9 / 26.10)
`add_track_flow_screen.dart` is 907 lines (AC implied lean orchestrator). 18+ hardcoded English strings remain in step files (`Text('Continue')`, `Text('Skip for now')`, `Text('Study Days')`) — not extracted to ARB as 26.10 AC required.

### LOW — `BaseDao` mixin not broadly adopted (25.17)
AC required migrating existing DAOs to the `BaseDao<T>` mixin + `TrackScope`. Only `StreakDao` adopted it; other DAOs unchanged.

### LOW — Missing Firebase emulator integration test (25.22)
Wipe-install AC requires emulator-stack verification. Only mock-based unit tests exist.

### LOW — `coding-standards.md` doc/code mismatch (27.16)
Doc lists 5 enforcement grep examples; `make audit` implements 12. AC said "12 enforcement greps listed with explanations."

---

## Epic 24 Detail — 8/8 PASS ✅

All 8 stop-the-bleeding stories fully delivered. See `_bmad-output/review/epic_24.md` for per-story breakdown.

---

## Epic 25 Detail — 15/22 PASS, 7 PARTIAL, 0 FAIL

See `_bmad-output/review/epic_25.md` for per-story breakdown.

**Passing:** DNI-323, 324, 325, 326, 327, 328, 329, 331, 334, 335, 337, 338, 339, 340, 341, 342
**Partial:** DNI-322, 330, 332, 333, 336, 338, 343

---

## Epic 26 Detail — 17/33 PASS, 13 PARTIAL, 1 FAIL

See `_bmad-output/review/epic_26.md` for per-story breakdown.

**Hard Fail:** DNI-348 (26.5) — dashboard_screen.dart 2,221 lines vs <600 AC
**Passing:** 26.2, 26.3, 26.6, 26.7, 26.11, 26.12, 26.13, 26.14, 26.16, 26.17, 26.18, 26.20, 26.21, 26.22, 26.25, 26.27, 26.28, 26.30, 26.31, 26.32
**Partial:** 26.1, 26.4, 26.8, 26.9/26.10, 26.15, 26.19, 26.24, 26.26, 26.29, 26.33

---

## Epic 27 Detail — 4/16 PASS, 11 PARTIAL, 1 FAIL

See `_bmad-output/review/epic_27.md` for per-story breakdown.

**Hard Fail:** DNI-377b / 27.10 — lint rule files missing, package uncompilable
**Passing:** 27.1, 27.3, 27.6, 27.9
**Partial:** 27.2, 27.4, 27.5, 27.7, 27.8, 27.11, 27.12, 27.13, 27.14, 27.15, 27.16

---

## Recommended Fix Priority

| Priority | Issue | Story | Effort |
|----------|-------|-------|--------|
| P0 | Add `no_curriculum_display_name_bypass.dart` + `no_feature_cross_import.dart`; wire `custom_lint` in pubspec | 27.10 | Small |
| P0 | Activate StreakReducer unit tests (DNI-337 landed at `5423d95f`) | 27.2 | Small |
| P1 | Decompose `dashboard_screen.dart` to <600 lines | 26.5 | Large |
| P1 | Delete `sync_engine.dart`; verify `core/sync/` is live production path | 25.12 | Large |
| P1 | Persist `SacredWindow` to DB for background notification cold-start | 26.24 | Medium |
| P2 | Fix Firebase auth boundary in `firestore_gateway_impl` + `auth_providers` | 25.11 | Small |
| P2 | Complete `StageDao` sole-write-path (9 bypass sites) | 26.26 | Medium |
| P2 | Delete 3 remaining TrackProgressVariant files | 26.8 | Tiny |
| P2 | Delete `GoalFormResult`; replace 3 callers with `GoalEntity` | 26.4 | Small |
| P3 | Add `completion_events` insert to `CompletionWriter.commit()` | 25.15 | Medium |
| P3 | Migrate remaining DAOs to `BaseDao` mixin | 25.17 | Medium |
| P3 | Extract remaining 18+ hardcoded strings in step files to ARB | 26.10 | Medium |
| P3 | Add Firebase emulator integration test for wipe-install flow | 25.22 | Large |
| P3 | Update `coding-standards.md` to document all 12 `make audit` greps | 27.16 | Tiny |
