# Self-resuming exhaustive on-device test-and-fix loop — progress

Heartbeat for the week-long autonomous loop. Orchestrator = Opus; workers = Sonnet, one per device,
worktree-isolated. Design + catalog: `docs/test-artifacts/e2e-test-design-2026-06-09.md`.
Scoreboard: `test-coverage-matrix.md`. Bug log: `test-fix-bug-log.md`.

## SETUP status (first run 2026-06-09)
- [x] Toolchain fixed: `ANDROID_HOME`/`ANDROID_SDK_ROOT` → `/home/daniel/Android/Sdk` symlink → Windows SDK; `flutter doctor` Android toolchain green.
- [x] Codegen: `dart run build_runner build` (2889 outputs). Seed asset: `tool/prepare_asset.dart` → `content.db.gz` (111 MB).
- [x] APK built (314 MB) and installed on all 5 emulators. App boots to MainActivity (verified emulator-5554).
- [x] `flutter devices` sees all 5 (API 28/29/31/34/36). On-device `flutter test -d emulator-XXXX` path verified.
- [x] Diagnosis + 485-scenario E2E catalog designed (15 bug classes, 7 P0).
- [ ] Sync (App Check / Firebase emulator) — DEFERRED to iteration 2. `gcloud` is authed; iteration 1 runs LOCAL-observable P0s (no cloud needed), which is where most "obvious" bugs live (FK-delete, Add-Profile no-op, RTL/i18n, nav-lockout, stale counters).

## Device → slice map (live)
| Serial | API | Form | Slice | Owned roots (writer) |
|--------|----:|------|-------|----------------------|
| emulator-5556 | 28 | small phone | B tracks+scheduler | `lib/features/tracks/`, `lib/features/scheduler/`, `lib/features/sacred_time/` |
| emulator-5560 | 31 | phone | C account-auth+nav-guards | `lib/features/account/`, `lib/app/router/`, `lib/core/navigation/guards/` |
| emulator-5554 | 29 | phone | D tutor+dashboard-gamification | `lib/features/tutoring/`, `lib/features/gamification/`, `lib/features/dashboard/` |
| emulator-5558 | 34 | phone | A sync | `lib/features/sync/`, `lib/app/restore/`, `lib/core/sync/`, `lib/core/outbox/` |
| emulator-5562 | 36 | **tablet** | E i18n-rtl+profiles+progress+learning | `lib/l10n/`, `lib/core/labels/`, `lib/core/preferences/`, `lib/features/profiles/`, `lib/features/onboarding/`, `lib/features/progress/`, `lib/features/content_browsing/`, `lib/features/learning/` |

Owned-root sets are pairwise disjoint → parallel fixes never collide.

## Iteration log
_(each iteration: per-device cells driven + bugs found/fixed + commit shas; appended by orchestrator)_

### Iteration 1 — COMPLETE (2026-06-09) — pushed to dev (f5acf635..39c11b1d)

**Infra fix (the big one):** workers found 3 of 5 emulators (API 28/29/31) could not run the app —
first-launch seeding decompressed the entire 432 MB content DB as one contiguous `Uint8List`, which the
Scudo allocator can't satisfy on 2 GB / older devices → OOM crash → user dropped on the launcher. Fixed
in `seed_manager.dart` (stream gzip → disk in 1 MB chunks; commit `b0d9895e`). Verified on-device: fresh
first-launch seed now succeeds on API 28/29/31 + 34 + 36. **The whole fleet (Android 9–16) now runs the app.**
This was a real product bug (would crash any low-RAM phone on first launch), and it was the actual cause of
the "all devices stuck" symptom — NOT the 5-way parallelism.

**14 defects fixed + red→green tested (committed, merged clean — disjoint owned roots held):**
- Slice B (tracks/scheduler): last-curriculum delete guard on hub+detail (`bdf2476b`); study-day `trackId=0`
  FK-crash guard (`b659b430`).
- Slice C (account/nav-guards): account-picker silent-fail on null profile (`7f39caff`); RestoreGuard stale
  cache on account switch (`8a271ea4`,`46f83917`); local sign-in session-context reset (`14556412`).
- Slice D (gamification): stale `globalPoints`/`childRedemptionBalance`/`pendingRedemptions`/
  `curriculumBreakdown` providers after mutations — the staleness class (`c9858974`,`084f254f`,`16e54ec4`,`0699e9b9`).
- Slice A (sync): he-RTL hard-coded English in BackupSyncSection subtitles (`9a1093c6`).
- Slice E (i18n/progress): 3 hard-coded English strings localized; progress cards now watch
  `completionCommittedProvider` (`d46fe19b`,`d5b53992`).

**CI gate caught real quality issues before push (gate working as designed):** 18 worker lint problems
(unused imports, directive ordering) auto-fixed via `dart fix`; one worker test was tautological (study-day
guard simulated a null var, asserted an empty table is empty) → rewrote to drive the real lookup. Cleanup
commit `d16346de`. The only remaining `make ci` reds are 4 golden screenshot tests that ALSO fail on
pristine dev (local WSL font rendering ≠ CI image) — pre-existing, not introduced here.

**Process lessons → folded into iteration 2 brief:**
1. Workers must `dart analyze --fatal-infos` + `dart format` before every commit (the gap that reddened CI).
2. Seed fixtures via the real app UI (now that the app boots on every device), NOT fragile binary `sqlite`
   pushes (those hung 30 min and wedged a worker in iter 1).
3. Tap by resource-id/content-desc with a "focus left the app → relaunch" guard; hard timeout on every adb call.
4. No tautological tests — a regression test must exercise the real production path.

### Iteration 2 — PENDING
Rebuild+redeploy combined APK to all 5 (now all run) → relaunch 5 workers with the hardened brief above →
bring sync (App Check) online for the cloud/two-device P0s.
