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

### Iteration 1 — IN PROGRESS (2026-06-09)
Local-first P0 hunt across all 5 slices. Workers drive the installed app, root-cause defects, ship a
red→green regression test, fix within owned roots, commit to branch `loop-iter1-slice<X>`. Orchestrator
integrates serially → one `make ci` → commit+push to dev → rebuild+redeploy → schedule iteration 2.
