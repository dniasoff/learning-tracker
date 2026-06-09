# Master On-Device E2E Test Design & Execution Plan

**Project:** Learning Tracker (Flutter, `com.jcom.torah.learning_tracker`)
**Branch:** `dev` (main) · **Date:** 2026-06-09 · **Author:** Lead Test Architect
**Scope:** Exhaustive on-device end-to-end test design across 12 functional areas, 485 catalogued scenarios, driven manually via `adb` on 5 live emulators.

---

## 0. Executive summary

Last month: **804 commits, 325 of them fixes (40%).** The merge gate (`make ci`) is **100% headless** and **never runs the assembled app on a device**. Despite **596 unit/widget test files** and an **80.1% line-coverage floor**, the user finds defects by *just opening the app* — because the recurring failure classes live in the **seams between units** (FK/transaction boundaries, deployed Firestore rules, two-device sync, the live auto_route/Riverpod runtime, the full navigation+sheet+dialog stack, and Hebrew/RTL real-pixel rendering) that the architecture configures away in tests.

This document delivers: (1) a diagnosis of why past testing missed these bugs, (2) a risk-ranked bug taxonomy, (3) the full E2E scenario catalog grouped by area/screen with P0 first, (4) a 5-emulator execution plan sharded into **disjoint slices (disjoint in screens AND owned source files** so parallel fixes never collide), and (5) a CI-gate recommendation to make a real-device E2E pass block merges.

**Verified environment (2026-06-09):** `adb devices` → emulator-5554 (API29), 5556 (API28), 5558 (API34), 5560 (API31 phone), 5562 (API36 TABLET) all online. `find test -name '*_test.dart'` → **596**; `integration_test/` → **1 file (app_test.dart)**; mock/fake test files → **255**. `Makefile` `ci: analyze validate-calendar test` where `test` is a headless `flutter test`; `.github/workflows/ci.yml` has a **Firestore-rules emulator job only** — no Android-emulator / flutter-drive step, and `integration_test/app_test.dart` is **not** in the ci chain.

---

## 1. Why past testing missed bugs (diagnosis)

### 1.1 The structural gap

`make ci` = `analyze` + `validate-calendar` + `test`, and `test` is a bare **headless** `flutter test` behind a ~60% line-coverage floor. CI on `ubuntu-latest` has a Firestore-**rules** emulator job but **no Android-emulator / flutter-drive step**, and the lone `integration_test/app_test.dart` (which only asserts the app launches) is **excluded** from the ci chain. So although **5 emulators are online**, **no merge-blocking check ever**:

- authenticates to Firestore or exercises the **deployed** `firestore.rules`,
- runs `PRAGMA foreign_keys=ON` against RESTRICT FKs (SQLite 787),
- drives the real router → modal-sheet → dialog → `auto_route` stack,
- holds **two screens' providers alive** across a single DB mutation,
- interleaves **two actors / two devices** with independently-advancing clocks,
- renders a **Hebrew/RTL** surface at real device pixel width.

### 1.2 The inverted pyramid (the 596 : 1 ratio and the 255 mocks)

There are **596 unit/widget test files** versus **1 integration test** — a 596:1 ratio tilted entirely toward mocked units. **255 of the 596 test files use `Mock`/`Fake`** and stub the repo+sync boundary, so they never serialize the real snake_case / ISO-string payload the client emits and never touch FK constraints or transaction boundaries. Single-screen `pumpWidget` harnesses run in isolation at fixed size in the **en** locale, so `find.text('English literal')` renders identically to the localized `en` value — **the assertion itself encodes the i18n bug**. The ~88 real-sqlite tests pre-seed FK-valid, internally-consistent fixtures that *coincidentally align two keys*, so key-mismatch and tombstone-resurrection pass **by accident**. Roughly **58 of the 325 fixes** were not product defects at all — they were the upkeep cost of keeping the headless suite compiling/green through schema rebuilds and `build_runner` regen. The suite largely catches **its own drift**, not user-facing bugs.

### 1.3 Three concrete bug-log examples (cited)

- **D1 — absent persistent §5 switcher** (`test-fix-bug-log.md:12`, product-rule §5, "top priority"). The repeatedly-requested persistent profile/role switcher was **absent from the default Dashboard/Learn/Progress** context — `AppShellScreen.appBarBuilder` rendered no bar in the own-profile case, and the name chain fell back to "User" instead of "Daniel Niasoff" for a self-learner whose identity lives on the account. A cross-route **negative invariant** ("every default context shows exactly one switcher") that no per-screen widget test and no nav harness (which never set the selected-profile pref) ever asserted.

- **D4 — Add Profile silent no-op** (`test-fix-bug-log.md:82`/`:102`). `profile_switcher_sheet.dart` "Add Profile" did `Navigator.pop()` **then** `showAddProfileDialog`, so the popped-sheet context+ref were **unmounted** and `if(!context.mounted) return` bailed **before** `createProfile` ever ran (3 on-device attempts, list stayed empty, no error). A headless widget test that presents the dialog directly keeps the context mounted and the happy path passes — the bug lives only in the **seam between** the sheet and the dialog.

- **D11 — tombstone resurrection / natural-key timestamp mismatch** (`test-fix-bug-log.md:174`). A completion tombstoned on device A and later re-marked stayed **permanently dead** on a device still holding the tombstone: `findTombstonedEventByNaturalKey` filtered on `eventTimestamp`, which the UNIQUE natural key doesn't have — a re-mark carries a **new** `completed_at`, so the lookup missed the tombstone (permanent data loss). The ~88 real-sqlite tests passed only because a fixture **reused one timestamp**, coincidentally aligning the two keys. Catching it requires a real two-device round-trip with skewed clocks.

**Net:** the failure modes live at the device / FK-transaction / deployed-rules / multi-device / full-navigation / Hebrew-render boundaries — exactly where an on-device exhaustive E2E walk on the 5 emulators is the only reliable detector.

---

## 2. Risk-ranked bug taxonomy

| # | Bug class | Risk | On-device only | Freq | Why headless tests miss it (one line) |
|---|-----------|:----:|:--------------:|:----:|---------------------------------------|
| 1 | **Delete/FK-ordering + tombstone resurrection** — delete dialog dismisses but nothing deleted; orphaned/dangling rows; completions resurrect or stay permanently dead | **P0** | yes | 41 | Prod runs `PRAGMA foreign_keys=ON` with RESTRICT FKs (787); in-memory Drift defaults FKs OFF, so the ordering crash that rolls back the delete never reproduces. Profile-less/churned account state no fixture models. |
| 2 | **Sync outbox wedge** — permission-denied from **deployed** Firestore rules (stale `hasOnly` allowlist, snake_case vs camelCase, ISO-string vs Timestamp), dead-letters, identity mismatch; queue never drains | **P0** | yes | 25 | `make ci` never authenticates to Firestore; rules are deployed server-side and not in any headless code path. Commit bodies state "no test enforces deployed rules." |
| 3 | **Cross-device sync correctness** — LWW clobbers a newer un-pushed local edit; orphan recovery; FK crash on pull resets app to signed-out | **P0** | yes | 18 | Needs two real devices with independently-advancing clocks + a real Firestore round-trip; a single mocked merge store with deterministic timestamps never enters the both-null / skew branch. |
| 4 | **Navigation lockout / dead-end** — guard throw leaves `auto_route` resolver completer un-completed (permanent hang); Riverpod-3 auto-retry hides error UI; missing route fail-safe; back-button mis-wire | **P0** | no | 25 | Emergent behaviours of the live auto_route/Riverpod runtime; guard tests covered only success cells and never injected a throwing dependency. |
| 5 | **Wiring / navigation-context dead callbacks** — widget mounted but action dead (sheet pops context+ref before dialog runs → silent no-op); wrong AutoTabs context; absent persistent §5 switcher | **P0** | yes | 7 | Headless tests pump ONE screen with a synthetic harness; the bug lives in the seam BETWEEN screens (pop order, context provenance, which appBar branch renders). |
| 6 | **Silent failure / swallowed error** — operation no-ops but UI shows success or nothing (empty catch, success-snackbar on empty write, swallowed FK exception, unlock/reward set never populated) | **P0** | no | 13 | Tests asserted pop() happened, not that the side-effect ran or that a failure surfaced a snackbar. |
| 7 | **Runtime crash on widget build / invalid DB companion** — intrinsic-dimension ListView in dialog, partial-companion `InvalidDataException`, malformed deep-link decode, Material-ancestor assertion | **P0** | no | 4 | Relevant tests skipped or used pre-resolved/seeded harnesses that dodged the failing path. |
| 8 | **Reactive staleness** — a value mutates in DB but the on-screen counter never re-reads (one-shot Future provider, leaf watching the wrong invalidation tick, provider pushed-over but never re-evaluated) | **P1** | no | 20 | Each provider unit-tested in its own container reading once; the bug is cross-provider (screen A mutates, screen B kept alive but wired to the wrong refresh signal). |
| 9 | **Hebrew/i18n leaks + RTL/long-number overflow** — hard-coded English shown to Hebrew users, wrong nusach transliteration, RenderFlex overflow on real pixels/tablet/RTL | **P1** | yes | 42 | Widget tests run in `en`, so `find.text('English literal')` passes — the assertion encodes the bug. 0 he-RTL/dark golden baselines. |
| 10 | **Product-rule / invariant violations** — tutor scope & live-mark bar, profile-type leakage, chazara `stageOrder>1` gating, TrackType resurfacing | **P1** | yes | 30 | Global product invariants, not unit contracts; mocked tests model a single use case in isolation, never whole-session role state. |
| 11 | **Race / lost-update / non-idempotent writes / listener leaks** — single-flight, debounce, disposed-Ref, double-tap, two-device, CF txn | **P1** | yes | 22 | Single-threaded `flutter_test` resolves the in-memory DAO before a second awaited tap can overlap; the guard is "verified by construction," not asserted. |
| 12 | **Offline-first violations** — stuck/flickering offline banner, sync-gated UI that never resolves offline (gated on `initialSyncComplete` / a launch-pull that can't complete without network) | **P1** | yes | 10 | Headless tests inject a fake connectivity stream + a fake repo that resolves instantly, so "stuck forever offline" and the cold-start blip cannot occur. |
| 13 | **Scheduling / pace arithmetic** — over/under-scheduling with the ~400-line provider body bypassed by fixtures | **P1** | no | 1 | `allDailyTasksProvider` body was overridden with fixed lists; the real pace→N-tasks computation never ran end-to-end. |
| 14 | **Set-after-dispose / use-after-dispose** — controller disposed during animate-out, `_load` after dispose, provider-mutation during build | **P2** | no | 3 | Assertions fire during animation/teardown — timing windows a synchronous in-memory test that settles immediately never opens. |
| 15 | **Headless-CI / false-confidence meta-class** — merge gate is 100% headless; structural "renders"/network-conditional/tautological ticks inflate coverage while verifying nothing; plus test/CI churn fixes | **P2** | no | 58 | No quality gate runs the assembled app on a device; un-injectable static singletons have no DI seam; ~52/325 fixes are upkeep of the suite itself. |

**Totals:** P0 classes 1–7 (the core), P1 classes 8–13, P2 classes 14–15. The P0 core is overwhelmingly `on_device_only=true`.

---

## 3. E2E scenario catalog (P0 first, grouped by area → screen)

**Conventions.** Each scenario lists **steps**, **permutations**, **targets** (bug classes), **risk**, **device_pref**. `adb` = `/home/daniel/bin/adb`. Offline = `svc wifi disable; svc data disable`. Relaunch = `am force-stop com.jcom.torah.learning_tracker`. Hebrew/RTL via device locale or in-app toggle. DB assertions via `adb exec-out run-as com.jcom.torah.learning_tracker cat <drift .sqlite>` then local `sqlite3`. Two-device scenarios need two emulators on the **same** cloud account. Catalog total: **485 scenarios** across **12 areas**.

> Below, each scenario is rendered compactly as `ID · title — [risk] device_pref · targets`. Full step lists are preserved verbatim in the per-area catalog inputs that seed this plan; the **load-bearing P0 hooks and exact source lines** are reproduced inline where a worker must reproduce a specific known regression.

### AREA 1 — sync (outbox, drain, push/pull, merge router, offline-first)

**Screens:** DeviceRestoreScreen `/restore`, UpgradeToCloudScreen, BackupSyncSection widget (in Settings + ParentSettings), SettingsScreen "Send Diagnostic Logs" tile, SyncStatusIndicator (dead UI), cross-cutting outbox drain.

**P0**
- `SYNC-RESTORE-01` New-device restore happy path → AppShell with sole profile — [P0] small-phone · cross-device, nav-lockout, staleness
- `SYNC-RESTORE-03` Restore error shows Retry+Skip, Retry genuinely re-pulls (pull guard reset) — [P0] small-phone · outbox wedge, silent-fail, offline-first
- `SYNC-RESTORE-04` Skip-and-continue marks restore complete, never re-traps on /restore — [P0] any · nav-lockout, offline-first
- `SYNC-RESTORE-05` FK-violating cloud row during pull must NOT bounce to signed-out — [P0] any · cross-device, delete/FK, crash
- `SYNC-RESTORE-02` Multiple cloud profiles → ProfilePicker, not auto-select — [P0] any · cross-device, absent §5 switcher, nav-lockout
- `SYNC-BACKUP-04` Error state is tappable; `retryPull` recovers without restart — [P0] any · dead-callback, silent-fail, outbox wedge
- `SYNC-BACKUP-05` Identity mismatch shows "Sign in to back up" → SignInRoute; drain SKIPPED (no dead-letter burn) — [P0] any · outbox wedge identity, dead-callback, cross-device
- `SYNC-BACKUP-06` "Sync paused — N stuck" degraded state at 3+ attempts; profile-0 bootstrap row COUNTED not hidden behind false "Synced" — [P0] any · outbox wedge, silent-fail, staleness
- `SYNC-UPGRADE-01` Local→cloud upgrade pushes all local data, flips tier — [P0] small-phone · outbox wedge, cross-device, success-on-empty-write
- `SYNC-UPGRADE-02` Email collision "Upload local into cloud" merges without clobbering newer un-pushed local edit — [P0] any · cross-device LWW, outbox wedge
- `SYNC-DRAIN-01` Offline-queued completions drain idempotently on reconnect (no double-apply, no resurrection) — [P0] small-phone · outbox wedge, tombstone, race
- `SYNC-DRAIN-02` Cross-device LWW: a newer un-pushed local edit not clobbered by an older cloud pull — [P0] any (two-device) · cross-device LWW, race, staleness
- `SYNC-DRAIN-03` Permission-denied dead-letters revived once after rule/identity fix; malformed dead-letters left untouched — [P0] any · outbox wedge, tombstone, silent-fail
- `SYNC-DRAIN-04` Delete propagation: deleting profile/goal leaves no orphans / no resurrection after pull — [P0] any (two-device) · tombstone, orphan recovery, crash

**P1**
- `SYNC-RESTORE-06` Restore progress+error no overflow on RTL/short/tablet — [P1] tablet · i18n/RTL, crash
- `SYNC-BACKUP-01` Local-born adult "LOCAL ONLY" card + working Upgrade button — [P1] small-phone · dead-callback, silent-fail
- `SYNC-BACKUP-02` Cold-launch resume does not wedge card on "Connecting…" forever — [P1] any · offline-first, staleness, false-confidence
- `SYNC-BACKUP-03` Queued offline write surfaces "Offline"/"N pending"; counter decrements live as it drains — [P1] small-phone · staleness, offline-first, outbox wedge
- `SYNC-BACKUP-07` he-RTL: degraded/offline/connecting subtitles are HARD-CODED ENGLISH (only `backupLastSynced/Syncing/PendingChanges/SyncError/TapToRetry` localized) — [P1] tablet · i18n/RTL, false-confidence
- `SYNC-BACKUP-08` Backup & Sync hidden for child + tutored sessions; switcher still visible — [P1] any · product-rule, absent §5 switcher
- `SYNC-UPGRADE-03` Collision "Keep cloud, discard local" requires acknowledgment checkbox — [P1] any · silent-fail, tombstone, dead-callback
- `SYNC-UPGRADE-04` Offline upgrade blocked with clear message, data stays local — [P1] small-phone · offline-first, silent-fail, race
- `SYNC-UPGRADE-05` Wrong password vs wrong cloud password → distinct inline errors — [P1] any · silent-fail, set-after-dispose
- `SYNC-UPGRADE-07` he-RTL & tablet: upgrade form/collision/ack do not overflow; flag non-localized literals — [P1] tablet · i18n/RTL, crash
- `SYNC-DIAG-01` Send Diagnostic Logs uploads under own auth with observable feedback (no dead tap) — [P1] any · silent-fail dead-callback, outbox wedge
- `SYNC-DIAG-02` Diagnostic Logs tile hidden in tutored sessions — [P1] any · product-rule, dead-callback
- `SYNC-DRAIN-05` Offline-first reads never gate on `initialSyncComplete`/launch-pull — [P1] small-phone · offline-first, staleness, nav-lockout

**P2**
- `SYNC-BACKUP-09` "X ago" updates after a fresh sync, not frozen — [P2] any · staleness, offline-first
- `SYNC-INDICATOR-01` Verify SyncStatusIndicator is genuinely unmounted (dead UI); if mounted, English + spinner-lifecycle leaks — [P2] any · false-confidence, i18n, set-after-dispose

### AREA 2 — tracks (add-track wizard, edit, delete archive/wipe, chazara, starting-position, reorder)

**Screens:** TrackManagementHubScreen `/settings/tracks`, TrackDetailScreen, ParentTrackManagementScreen `/parent-mode/tracks`, AddTrackFlow (+ steps), ChazaraInlineSetup, StartingPositionStep/Calendar, EditTrackScreen, TrackLearningOrderScreen, TrackManagementBody.

**Code facts for workers:** delete dialogs at `track_management_hub_screen.dart:222`, `track_detail_screen.dart:738`, `parent_track_management_screen.dart:222`. `archive`=`dao.deleteTrackAndData` (soft tombstone), `wipe`=`dao.purgeHistory` (hard-delete + `purgedAt` stamp); DAO `track_dao.dart:217`/`:407`; both clear `profile_programs` (D7). `completion_events` are **append-only (N8)** — assert row count never decreases. **DIVERGENCE (test-fix-bug-log.md:425):** `TrackManagementBody.archive` calls `curriculumActivationService.deactivate` (guarded by `LastActiveCurriculumException`) while Hub/Detail/Parent archive call `deleteTrackAndData` with **no** last-curriculum guard.

**P0**
- `TRK-HUB-01` Archive soft-deletes, completions survive, no resurrection on relaunch — [P0] any · tombstone, silent-fail, staleness
- `TRK-HUB-02` Wipe hard-deletes track row, tombstones completions (count never decreases), no dangling profile_programs — [P0] any · tombstone, outbox wedge, pace, silent-fail
- `TRK-HUB-04` Delete the LAST active track via hub — no dead-end, dashboard recovers (exposes missing last-curriculum guard) — [P0] any · nav-lockout, product-rule, crash, staleness
- `TRK-HUB-05` Back button from hub never strands the user — [P0] any · nav-lockout, dead-callback
- `TRK-HUB-07` Persistent §5 switcher reachable from track hub; list re-reads on profile switch — [P0] any · dead-callback, staleness, product-rule
- `TRK-DET-03` Tutor session: goal tile disabled, write barred with permission-denied feedback — [P0] any · product-rule, outbox wedge, silent-fail
- `TRK-DET-04` Delete from detail pops back to hub, removes card, stays gone — [P0] any · tombstone, nav-lockout, staleness
- `TRK-PAR-01` Parent-mode reaches tracks only past PIN guard; manages CHILD profile — [P0] any · nav-lockout, product-rule, dead-callback
- `TRK-PAR-02` Parent-mode delete updates DB + invalidates; child dashboard not stale — [P0] any · tombstone, staleness, cross-device
- `TRK-ADD-01` End-to-end self-paced creation persists track+stages+goal+study days atomically — [P0] any · crash, silent-fail, tombstone, product-rule
- `TRK-ADD-02` Program track w/ built-in chazara seeds learn + chazara stages (B1: must NOT be zero-stage/dead) — [P0] any · silent-fail, product-rule, pace, tombstone
- `TRK-ADD-03` Profile-less/sentinel-0 account: track save fails gracefully, no orphan zero-stage track (D4/D6/D7) — [P0] any · silent-fail, tombstone, crash, nav-lockout
- `TRK-ADD-04` Replace-existing-track confirmation guards destructive overwrite of completed sections — [P0] any · silent-fail, tombstone, dead-callback
- `TRK-ADD-06` Back/exit semantics: auto-skipped step doesn't strand; exit-confirm guards data loss — [P0] any · nav-lockout, dead-callback, set-after-dispose
- `TRK-ADD-07` Tutor creating a track: permission-denied surfaces, no outbox wedge — [P0] any · outbox wedge, product-rule, silent-fail
- `TRK-CHZ-03` Edit Track "Change review" sheet pre-selects current delays + applies change (modal dead-callback) — [P0] any · dead-callback, silent-fail, tombstone
- `TRK-SP-01` Back-date start (today-N) → correct back-dated anchor + overdue catch-up, NOT 7× weekly-pace flood — [P0] any · pace, product-rule, staleness
- `TRK-EDIT-02` Clear Overdue (program) re-anchors to today, clears queue; enabled only when overdue — [P0] any · pace, staleness, outbox wedge, silent-fail
- `TRK-EDIT-04` Tutor without canEditGoals/canEditStages: Save blocked w/ feedback, no partial write — [P0] any · product-rule, outbox wedge, silent-fail

**P1**
- `TRK-HUB-03` Delete dialog Cancel is a true no-op — [P1] any · silent-fail, dead-callback
- `TRK-HUB-06` Hebrew RTL: hub strings localized, RUNNING pill not clipped — [P1] tablet · i18n/RTL
- `TRK-DET-01` Program-enrolled track hides self-paced-only controls — [P1] any · product-rule, dead-callback
- `TRK-DET-02` Set goal then re-open detail — counters re-read (no staleness) — [P1] any · staleness, silent-fail, pace
- `TRK-DET-05` Bulk-prior opens scoped browser; historical completions distinct from live — [P1] any · silent-fail, staleness, pace, product-rule
- `TRK-DET-06` he-RTL + Hebrew calendar: chazara/dates/percent localized, no leak/overflow — [P1] tablet · i18n/RTL, product-rule
- `TRK-PAR-03` Empty-state error/retry recovers without dead-end (Riverpod-3 auto-retry not hiding error UI) — [P1] any · nav-lockout, silent-fail
- `TRK-PAR-04` i18n leak: parent header "Active Tracks"/"N RUNNING" hard-coded English — [P1] any · i18n/RTL
- `TRK-ADD-05` Mid-flow resume from prefs restores step; stale program state doesn't bleed across curricula — [P1] any · staleness, product-rule, silent-fail
- `TRK-ADD-08` he-RTL across all wizard steps — flag hard-coded literals, no overflow — [P1] small-phone · i18n/RTL, crash
- `TRK-CHZ-01` "Learn Only" preset → learn-only track, no chazara UI anywhere — [P1] any · product-rule, silent-fail
- `TRK-CHZ-02` Custom chazara rounds (stageOrder>1) seed correctly, drive delayed review tasks — [P1] any · pace, product-rule, staleness
- `TRK-CHZ-04` Program-with-open-chazara offers inline setup; defined-chazara is read-only — [P1] any · product-rule, silent-fail
- `TRK-SP-02` "Use today" resets offset; "Start Here" disabled until calendar entry resolves (offline-first) — [P1] any · offline-first, silent-fail, nav-lockout
- `TRK-SP-03` Content-program drill-down selection becomes the starting ref — [P1] any · silent-fail, pace, dead-callback
- `TRK-SP-04` Calendar entry + dates localized in Hebrew, weekday names not hard-coded English — [P1] tablet · i18n/RTL
- `TRK-EDIT-01` Rename + change pace persists, propagates to detail/dashboard — [P1] any · silent-fail, staleness, pace
- `TRK-EDIT-03` Program hides study-days/review + locked banner; self-paced shows them — [P1] any · product-rule, dead-callback
- `TRK-EDIT-05` Deadline-goal: Hebrew date picker path + clearing deadline behave correctly — [P1] any · i18n/RTL, pace, crash
- `TRK-ORD-01` Reorder sedarim persists, re-seeds masechtos without losing a newer edit (race guard) — [P1] any · race, staleness, silent-fail
- `TRK-ORD-02` Reorder amnesty clears outstanding overdue per the warned dialog — [P1] any · pace, staleness, silent-fail
- `TRK-ORD-04` Curriculum without reorderable level-2 hides masechtos; RTL header; flag "• Reorder" English — [P1] tablet · i18n/RTL, product-rule
- `TRK-BODY-01` Archive of the LAST curriculum is blocked here vs allowed by hub — exposes divergence — [P1] any · product-rule, nav-lockout, silent-fail, false-confidence
- `TRK-BODY-02` Archive (deactivate) vs Wipe semantics differ correctly — [P1] any · tombstone, staleness

**P2**
- `TRK-EDIT-06` Save with no changes / cancel confirm is a clean no-op; no set-after-dispose on background — [P2] any · silent-fail, set-after-dispose
- `TRK-ORD-03` Reset to default order restores canonical order — [P2] any · silent-fail, staleness

### AREA 3 — progress (hub, recent activity, siyumim, curriculum detail, lifetime knowledge)

**Screens:** ProgressScreen (tab 2), RecentActivityScreen, SiyumimMilestonesScreen, CurriculumProgressScreen, LifetimeKnowledgeScreen.

**Code findings:** hard-coded English in `curriculum_progress_screen.dart` — "Breakdown by Level" (`:163`), "Loading progress..." (`:188`), "Failed to load progress: $error" (`:196`). `recent_activity_providers.dart` and the "Track only" `items_learned_providers.dart` do **not** watch `completionCommittedProvider` → charts/tree stale until hub pull-to-refresh. `journeySortModeProvider` resets on every navigation.

**P0**
- `PROG-04` All three lens tiles navigate correctly and back returns to hub — [P0] any · nav-lockout, dead-callback
- `PROG-09` §5 persistent switcher present on Progress tab in own-profile context; counters re-fetch on switch — [P0] any · dead-callback, staleness, product-rule
- `RA-01` Time-range pills re-fetch all charts; All-time swaps calendar grid for summary (no ~9,600-cell freeze) — [P0] any · crash, staleness, race
- `RA-06` Back button returns to Progress hub, not a dead-end — [P0] any · nav-lockout, dead-callback
- `SIY-02` Level counters update after a completion that earns a new siyum (`completionCommittedProvider` reactivity) — [P0] any · staleness, silent-fail, pace
- `SIY-04` Tutor/parent cross-profile view shows CHILD's journey titled by name; NO live-mark affordance — [P0] any · product-rule, cross-device, silent-fail
- `CP-02` Unknown/invalid `curriculumId` path-param never leaks raw key, no crash — [P0] any · malformed deep-link/crash, silent-fail, i18n
- `LK-02` Curriculum + nested tree expand/collapse at every depth (no intrinsic-dimension crash) — [P0] any · crash, silent-fail, staleness

**P1**
- `PROG-01` Tier counters resolve to real numbers, never stuck on "…" — [P1] small-phone · staleness, silent-fail, crash
- `PROG-02` Counter-row gating: a single errored provider keeps placeholder, not misleading 0 — [P1] any · staleness, offline-first, silent-fail
- `PROG-03` Pull-to-refresh re-reads counters/lens trees after an external completion — [P1] any · staleness, silent-fail
- `PROG-05` Per-track row opens correct curriculum (storageKey round-trips, no unknown-curriculum leak) — [P1] any · dead-callback, silent-fail, i18n
- `PROG-06` Child mode adds 4th points counter; adult hides it (no overflow on 4→3) — [P1] any · product-rule, i18n/RTL
- `PROG-07` Counter row + per-track rows no overflow with 4-digit counts + long Hebrew labels — [P1] small-phone · i18n/RTL, crash
- `PROG-08` Empty-state when no active curricula; no crash, no phantom counters — [P1] any · crash, silent-fail, dead-callback
- `RA-02` Curriculum filter scopes charts + calendar; global streak headline annotated — [P1] any · staleness, silent-fail, product-rule
- `RA-03` Recent Activity charts STALE after a completion until pull-to-refresh (no auto-update) — [P1] any · staleness, silent-fail
- `RA-04` Chazara refs fully suppressed when no active track has chazara (stageOrder>1 gating) — [P1] any · product-rule, i18n
- `RA-05` Points chart shown ONLY in child mode — [P1] any · product-rule, silent-fail
- `RA-07` he-RTL: pills/titles/disclaimers Hebrew, no untranslated leaks or overflow — [P1] tablet · i18n/RTL, crash
- `RA-08` All-time summary survives a single ancient completion (chart floor bucketization) — [P1] any · crash, pace, race
- `SIY-01` View toggle flips grouped↔timeline; both render real milestone data — [P1] any · dead-callback, silent-fail, staleness
- `SIY-06` Empty state for active-but-uncompleted profile (no crash, no phantom siyumim) — [P1] any · crash, silent-fail
- `SIY-07` he-RTL siyum level labels + plurals correct, no English leak — [P1] any · i18n/RTL, product-rule
- `CP-01` i18n leak: hard-coded English ("Breakdown by Level", "Loading progress...", error) shown to Hebrew users — [P1] any · i18n/RTL, silent-fail
- `CP-03` Dual stats: trackProgress% vs lifetime% distinct + arithmetically correct, no div-by-zero — [P1] any · pace, staleness, crash
- `CP-04` Pace indicator reflects live-only learning, updates after a live completion — [P1] any · pace, staleness, silent-fail
- `CP-06` Bulk/lifetime completions do NOT move the live-only pace indicator — [P1] any · product-rule, pace, staleness
- `CP-07` Hierarchy cards + long Hebrew names render on tablet without overflow — [P1] tablet · i18n/RTL, crash
- `LK-01` Source toggle swaps both header counters AND tree (All sources vs Track only consistency, F3) — [P1] any · staleness, silent-fail, pace
- `LK-03` Lifetime tree STALE after a completion until pull-to-refresh ("Track only" branch) — [P1] any · staleness, silent-fail
- `LK-04` Header counter ↔ hub lifetime tier counter consistency — [P1] any · staleness, pace, silent-fail
- `LK-05` CTA → Lifetime Marking; a bulk-mark there reflects back on return — [P1] any · dead-callback, staleness, silent-fail
- `LK-06` Empty/zero-progress shows `itemsLearnedNoCurricula`, not a broken tree — [P1] any · crash, silent-fail
- `LK-07` he-RTL: provenance labels, chazara plurals, toggle labels Hebrew, no leak/overflow — [P1] small-phone · i18n/RTL, product-rule
- `LK-08` Header/tree error path: retry recovers without app reset — [P1] any · nav-lockout, offline-first, silent-fail

**P2**
- `SIY-03` Zero-tier rows render dimmed (not hidden) so layout doesn't jump on first siyum (F15) — [P2] any · staleness, i18n/RTL
- `SIY-05` Sort-mode toggle is NOT persisted across navigation (state-reset assertion) — [P2] any · set-after-dispose, staleness, silent-fail
- `CP-05` Grace-window shows on-track (no phantom "Ahead/Behind by 0 days") — [P2] any · pace, i18n

### AREA 4 — scheduler (overdue durability, calendar programs, sacred time / in-Israel two-day)

**Screens:** SchedulerScreen, StudyDayConfigScreen, GoalSetupScreen/Form (+ HebrewDatePicker), calendar-program tasks, SacredTimeSettingsCard, CityPickerScreen, SacredTimeLockOverlay.

**Architecture facts:** overdue/today buckets are **re-derived** on every read by `allDailyTasksProvider._buildProjectionTasks` — never read from a persisted `isOverdue` flag, so durability tests verify re-derivation across relaunch+date change. Skips persist via SharedPreferences, auto-reset on date change. Sacred windows recompute from `(lat,long,inIsrael)`; the in-Israel switch collapses diaspora 2-day Yom Tov to 1 day. SchedulerScreen + StudyDayConfigScreen are **pushed routes**, so the persistent `ProfileSwitcherBar` (only in the AutoTabsScaffold) is structurally absent.

**P0**
- `SCHED-OVERDUE-DURABLE-01` Overdue survives kill/relaunch, re-derived from projection not a stale flag — [P0] any · tombstone, staleness, pace, silent-fail
- `SCHED-NO-SWITCHER-07` Persistent §5 switcher absent on pushed SchedulerScreen (multi-profile) — [P0] any · absent §5 switcher, product-rule
- `STUDYDAY-TOGGLE-WRITE-09` Toggling a study day persists to Drift, pushes sync, re-derives schedule (no silent no-op) — [P0] any · silent-fail, staleness, crash, pace
- `STUDYDAY-COMPANION-10` `upsertDayConfig` trackId-fallback-0 does not throw InvalidDataException / partial companion — [P0] any · crash, tombstone, silent-fail
- `STUDYDAY-TUTOR-BAR-11` Tutor without canEditStudyDays: read-only tiles; editing tutor surfaces permission-denied not a wedge — [P0] any · product-rule, outbox wedge, silent-fail
- `CALPROG-DEAD-AFTER-SETUP-19` Calendar program (Daf/Amud/Perek/Tehillim Yomi) actually produces a task after setup, not silently dead — [P0] any · silent-fail, pace, crash, staleness
- `CALPROG-DATE-ROLLOVER-20` Calendar task advances its ref at local midnight; yesterday's becomes overdue not stuck — [P0] any · staleness, tombstone, pace, crash
- `GOAL-PERSIST-SYNC-17` Submitting a goal writes Drift, queues Firestore, reflects on dashboard/scheduler without manual refresh — [P0] any · outbox wedge, silent-fail, staleness, cross-device
- `SACRED-INISRAEL-TWODAY-23` In-Israel toggle flips two-day diaspora Yom Tov to one-day (and back), changing the lock-window set — [P0] any · staleness, product-rule two-day, pace, silent-fail
- `SACRED-LOCKSCREEN-24` Lock overlay appears during a window, covers ALL routes, self-dismisses at window end (no nav lockout) — [P0] any · nav-lockout, staleness, set-after-dispose

**P1**
- `SCHED-SKIP-DURABLE-02` Swipe-to-skip persists across relaunch (same day), auto-resets next day boosted — [P1] any · tombstone, staleness, silent-fail, race
- `SCHED-SKIP-UNDO-03` Undo skip restores card without leaving it permanently dead — [P1] any · tombstone, race, set-after-dispose
- `SCHED-VIEWTOGGLE-04` Grouped/flat toggle reactive; grouped-view dismiss maps to correct task — [P1] any · dead-callback, staleness, crash
- `SCHED-I18N-RTL-05` Hebrew/RTL: header/goal card/summary/"Overdue" badge must not leak English (`:184-187`,`:293`,`:302`; `daily_task_card.dart:131`) — [P1] tablet · i18n/RTL
- `SCHED-EMPTY-06` All-caught-up per section (today vs overdue vs review) — [P1] any · silent-fail, offline-first, i18n/RTL
- `SCHED-OFFLINE-RESOLVES-08` Scheduler loads fully offline (Drift-first), never wedged on a launch-pull — [P1] any · offline-first, outbox wedge, silent-fail
- `STUDYDAY-CHAZARA-GATE-12` Learn-only (stageOrder==1) shows neutral fallback, no review/chazara terminology — [P1] any · product-rule chazara-gate, i18n/RTL
- `STUDYDAY-I18N-OVERFLOW-13` Hebrew + large text: title/summary/badges localized, no overflow (`:59`,`:86`,`:165`) — [P1] small-phone · i18n/RTL
- `GOAL-PACE-ARITH-14` Pace arithmetic per_day vs per_week + deadline pace correct (provider body exercised) — [P1] any · pace, silent-fail, staleness
- `GOAL-UNIT-LABEL-VARIANT-15` Unit pills honour Hebrew-terms + Ashkenazi/Sephardi nusach (Dafim vs Dapim vs דפים) — [P1] any · i18n/RTL, product-rule nusach
- `GOAL-HEBREW-DATEPICKER-16` Hebrew date picker round-trips to correct Gregorian UTC, survives leap-month/clamp — [P1] any · pace, crash, i18n/RTL
- `GOAL-I18N-LEAK-18` Goal setup riddled with hard-coded English under Hebrew locale — [P1] small-phone · i18n/RTL
- `CALPROG-I18N-REF-21` Calendar ref label honours Hebrew toggle (`todayRefHe`), falls back cleanly when missing — [P1] tablet · i18n/RTL, silent-fail
- `CALPROG-OFFLINE-22` Calendar programs resolve fully offline (LocalCalendarEngine reads bundled DB) — [P1] any · offline-first, silent-fail
- `SACRED-LOCK-KIND-I18N-25` Lock greeting matches window kind; Shabbos term honours nusach + Hebrew — [P1] small-phone · i18n/RTL, nusach
- `SACRED-DETECT-PERM-26` "Detect" handles each permission outcome with right snackbar, no wedge — [P1] any · silent-fail, outbox wedge, staleness, set-after-dispose
- `CITYPICKER-SEARCH-27` Typeahead: <2 chars idle, no-match, selection persists manual city & pops result — [P1] any · staleness, i18n/RTL, silent-fail, offline-first
- `SACRED-LOCK-DURING-LIVEMARK-28` Lock overlay during an active mark-complete does not corrupt state on dismiss — [P1] any · race, set-after-dispose, silent-fail

### AREA 5 — account-auth (sign-in, signup, account picker, restore, upgrade, magic-link, empty-login)

**Screens:** SignInScreen, SignupScreen, AccountPickerScreen, DeviceRestoreScreen, UpgradeToCloudScreen, EmptyLoginScreen, EmailVerificationDialog, NoBackupBadge, OfflineTopBanner; MagicLinkService (app-wide).

**P0**
- `SI-01` Cloud email/password sign-in lands in app and drains outbox — [P0] API34 · outbox wedge, nav-lockout, silent-fail
- `SI-02` Unverified cloud account triggers verification dialog, not silent dead-end; Cancel signs out half-auth — [P0] API34 · silent-fail, nav-lockout, dead-callback
- `SI-03` Offline cloud-born sign-in restores local data with no network round-trip (Google btn hidden) — [P0] API31 · offline-first, silent-fail, nav-lockout
- `SI-04` Offline cloud-born sign-in when local DB missing surfaces honest error (not fake success) — [P0] API28 · silent-fail, offline-first, nav-lockout
- `SI-05` Local-born sign-in online auto-finalizes a verified pending cloud upgrade — [P0] API34 · cross-device LWW, outbox wedge, silent-fail
- `SI-06` Local-born sign-in offline stays local, routes by profile state (no onboarding loop) — [P0] API29 · nav-lockout, offline-first
- `SI-11` Google sign-in cancel + max-accounts(5) cap from SignIn; orphan session signed out — [P0] API34 · silent-fail, identity mismatch, nav-lockout
- `SI-12` Google email collides with existing local-born → upgrade redirect, not silent merge — [P0] API34 · silent-fail, cross-device, product-rule
- `SU-01` Online cloud signup sends verification email, routes to sign-in, not auto-logged-in unverified — [P0] API34 · silent-fail, nav-lockout
- `SU-02` Offline local signup requires acknowledge; argon2id account; email reserved atomically; orphan rollback — [P0] API29 · tombstone orphan rollback, silent-fail, invalid-companion crash
- `SU-03` Connection drops mid-cloud-signup → fallback dialog; both branches work (modal pops context) — [P0] API31 · dead-callback, silent-fail, race
- `SU-05` Google signup max-account cap + local-collision redirect cleans up — [P0] API34 · silent-fail, identity mismatch, product-rule
- `AP-01` Instant cloud switch swaps DB, lands in target account, NORMAL mode own profile — [P0] API34 · cross-device FK, product-rule context-leak, staleness
- `AP-02` Cloud→cloud switch with STALE session re-auths to correct identity, aborts on wrong pick (no PERMISSION_DENIED flood) — [P0] API34 · identity mismatch, cross-device, listener leak, silent-fail
- `AP-03` Cloud stale-session OFFLINE activates local data without network — [P0] API28 · offline-first, nav-lockout
- `AP-05` Swipe-to-delete LOCAL account: confirm + actual deletion (no resurrection, no orphan inode) — [P0] API34 · tombstone, silent-fail
- `AP-06` Removing the CURRENTLY-ACTIVE account tears down session FIRST then deletes — [P0] API34 · tombstone live-DB, crash, nav-lockout
- `AP-07` Swipe "Remove from device" keeps cloud, drops local; re-add restores from cloud — [P0] API34 · tombstone, orphan recovery, outbox wedge
- `DR-01` New-device restore pulls profiles, routes by count, FK-consistent — [P0] API34 · cross-device FK, nav-lockout, delete/FK
- `DR-02` Restore failure shows working Retry + Skip; Skip marks complete, no loop — [P0] API31 · nav-lockout, outbox wedge, silent-fail
- `UC-01` Happy-path local→cloud upgrade flips tier + pushes local data — [P0] API34 · cross-device LWW, outbox wedge, silent-fail
- `UC-04` Email-collision → no silent merge; both resolution options gated correctly — [P0] API34 · silent-fail, cross-device, tombstone
- `ML-01` verifyEmail deep link completes verification end-to-end (warm + cold) — [P0] API34 · silent-fail, malformed-decode crash, nav-lockout
- `ML-02` Malformed/wrapped deep link does not crash the link stream; valid one still processed — [P0] API31 · malformed-decode crash, listener leak, silent-fail
- `EL-01` Switch-account affordance appears only with ≥2 accounts; reaches picker (no dead-end) — [P0] API34 · absent switcher, nav-lockout, staleness
- `EV-01` Verification dialog buttons each perform their real action — [P0] API34 · dead-callback, silent-fail, set-after-dispose
- `EV-02` "I've verified" before verifying does not falsely advance — [P0] API34 · success-on-empty-check, race

**P1**
- `SI-07` Wrong password / unknown email → correct distinct errors (no generic fallthrough) — [P1] API34 · silent-fail, i18n
- `SI-08` 15s sign-in watchdog surfaces timeout instead of permanent spinner — [P1] API31 · nav-lockout, race, offline-first
- `SI-09` Registry debounce reactive correctness as email is edited — [P1] API34 · staleness, listener leak
- `SI-10` Hebrew RTL layout + i18n on sign-in surface — [P1] tablet · i18n/RTL
- `SU-04` Duplicate email guards (cloud + local + in-progress reservation) — [P1] API34 · race, tombstone, silent-fail
- `SU-06` Hard-coded English leak audit on Signup — [P1] small-phone · i18n/RTL
- `SU-07` Field validation + input formatters — [P2→P1] any · silent-fail, crash
- `AP-04` Local-born tile instant activation (no password modal) — [P1] API31 · dead-callback, silent-fail, product-rule
- `AP-08` Max-accounts cap UI + add-account count copy — [P1] API34 · product-rule, silent-fail
- `AP-09` Hebrew RTL + long-name/long-email overflow on tiles — [P1] tablet · i18n/RTL
- `AP-10` Deleting last account auto-redirects to SignIn (empty-state safety) — [P1] API29 · nav-lockout, silent-fail
- `DR-03` Restore short-viewport / large-text does not overflow — [P1] small-phone · i18n/RTL, crash
- `DR-04` Local-only account never enters restore (guard skip) — [P1] API29 · offline-first, nav-lockout
- `UC-02` Upgrade requires internet — offline blocked, no data loss — [P1] API28 · offline-first, silent-fail
- `UC-03` Wrong local password rejected before any cloud mutation — [P1] API34 · silent-fail, product-rule
- `UC-05` Verification resend + cancel back to form, no duplicate listeners/spinners (S7) — [P1] API34 · listener leak, outbox wedge, set-after-dispose
- `UC-06` Hard-coded English leak audit + RTL on Upgrade — [P1] small-phone · i18n/RTL
- `ML-03` signIn magic link with no pending email handled (cross-device case) — [P1] API34 · silent-fail, identity mismatch, nav-lockout
- `ML-04` Expired/already-consumed action code tolerated — [P1] API34 · race, silent-fail
- `EL-02` Tutor entry routes to picker (talmid section); CTA banner actions live — [P1] API31 · dead-callback, silent-fail, product-rule
- `EV-03` Dialog scroll-escape + Hebrew RTL on small viewport (flag English literals) — [P1] small-phone · i18n/RTL, crash
- `NB-01` No-backup badge visibility tier-correct, tap opens upgrade — [P1] API34 · staleness, product-rule, dead-callback
- `OB-01` Offline banner shows for cloud users, never for local; clears on reconnect — [P1] API34 · offline-first, staleness, i18n
- `EL-03` Hebrew RTL on empty-login surface — [P2] tablet · i18n/RTL

### AREA 6 — tutor (invite/accept/decline, grant lifecycle + D18 resurrection, tutor=child PARENT view, PIN, audit log)

**Screens:** InviteTutorScreen, AcceptInviteScreen (deep link), DeclineInviteScreen, ManageTutorsScreen (parent), ManageGrantsScreen (tutor), TutorAuditLogScreen, TutorPinSetupScreen, TutorPinEntryGate, TutorPinResetScreen, showTutorPinVerificationDialog, tutor talmid PARENT view + live-mark bar.

**P0**
- `INV-01` Send invite to valid email pushes pending grant, returns to Manage Tutors w/ confirmation, pending row appears (no manual refresh) — [P0] any (two-device) · dead-callback, silent-fail, staleness, outbox wedge
- `INV-03` Send invite while OFFLINE surfaces failure inline (not false success) — [P0] any · silent-fail, outbox wedge, offline-first
- `ACC-01` Accept via deep link flips grant pending→active in-session everywhere (SEV-2 stale row) — [P0] any · staleness, dead-callback, cross-device, nav-lockout
- `ACC-02` Accept by a NOT-signed-in user routes through sign-in then re-delivers and completes — [P0] any · nav-lockout, dead-callback, silent-fail
- `ACC-03` Accept when tutor has NO PIN forces inline PIN setup before success (mandatory PIN) — [P0] any · product-rule, nav-lockout, silent-fail
- `ACC-04` Malformed deep link (missing/empty token) lands on error card, not crash/hang — [P0] any · crash, nav-lockout, silent-fail
- `ACC-05` Accept an already-revoked/expired/declined grant → precondition error (no resurrection to active) — [P0] any (two-device) · tombstone, cross-device, race, silent-fail
- `ACC-06` Decline from Accept screen reaches real decline flow (state change + parent notify), not no-op — [P0] any · dead-callback, silent-fail, race
- `DEC-01` Confirm decline changes server state + fires DEC-23 parent notification once — [P0] any (two-device) · silent-fail, race, outbox wedge
- `DEC-03` Decline failure path shows error card; Try-again recovers — [P0] any · silent-fail, offline-first, nav-lockout
- `MGT-01` Revoke active grant wipes mirror, removes row, notifies tutor — [P0] any (two-device) · tombstone, silent-fail, staleness, cross-device
- `MGT-06` Revoke error keeps the row + SnackBar (no silent loss) — [P0] any · silent-fail, offline-first, tombstone
- `MGT-08` D18 resurrection guard: a revoked grant does not reappear after a sync/refresh cycle — [P0] any (two-device) · tombstone, cross-device, staleness
- `MGG-01` Resign from active grant wipes mirror, exits tutored session, notifies parent — [P0] any (two-device) · tombstone, dead-callback, silent-fail, cross-device
- `MGG-02` DEC-21 dual-role: backing out of ManageGrants must NOT leave tutor in a tutor session on own profile — [P0] any · product-rule, staleness, dead-callback, set-after-dispose
- `PGT-01` Correct PIN unlocks + enters talmid PARENT view; wrong PIN errors+clears — [P0] any · nav-lockout, dead-callback, product-rule, offline-first
- `PGT-03` Cancel (X) backs out cleanly without entering a tutored session or wedging the sheet — [P0] any · dead-callback, nav-lockout, product-rule
- `PGT-05` Entry-pull offline-first: cached mirror enters immediately; no-mirror caps spinner at 15s; permissionDenied wipes stale mirror — [P0] any (two-device) · offline-first, outbox wedge, cross-device, nav-lockout, tombstone
- `PVD-01` Tutor-scope route guard prompts dialog; correct PIN proceeds without re-prompting elsewhere — [P0] any · nav-lockout, race, dead-callback
- `PVD-02` Cancel returns false; guarded route does not open (no dead-end) — [P0] any · nav-lockout, dead-callback, silent-fail
- `PSU-01` Happy-path PIN setup: enter, confirm matching, save succeeds, onPinSet fires — [P0] any · dead-callback, silent-fail, product-rule
- `LMB-01` Live-mark BARRED in tutor session: disabled+amber+tooltip; any forced call throws the forbidden dialog, no DB write — [P0] any · product-rule, silent-fail, dead-callback
- `LMB-03` DEC-21: on the tutor's OWN profile live-mark is ENABLED (not disabled by having a grant) — [P0] any · product-rule, staleness, silent-fail
- `LMB-04` Tutored entry from BOTH switcher sheet and Settings is PIN-gated and lands cleanly (no wedged sheet) — [P0] any · dead-callback, nav-lockout, set-after-dispose
- `LMB-05` D18 live revocation while inside talmid view ejects tutor on next authoritative sync — [P0] any (two-device) · tombstone, cross-device, staleness, race

**P1**
- `INV-02` Invalid/partial email rejected client-side without network round trip — [P1] any · silent-fail, crash
- `INV-04` Hebrew/RTL invite screen: no English leaks, email field stays LTR — [P1] any · i18n/RTL
- `INV-05` Snapshotted child/parent names persisted on the grant (tutor sees real names) — [P1] any (two-device) · i18n/RTL, product-rule, silent-fail
- `ACC-07` readyToAccept/success/error cards no overflow on short/large-text/RTL — [P1] small-phone · i18n/RTL, crash
- `ACC-08` Offline accept: grant not in cached list falls back to stub, does not hang — [P1] any · offline-first, nav-lockout, silent-fail
- `DEC-02` Cancel on confirm step backs out without declining — [P1] any · dead-callback, nav-lockout
- `DEC-04` Decline screen scrolls without overflow, no English leaks in Hebrew — [P1] small-phone · i18n/RTL, crash
- `MGT-02` Rescind a pending invite removes it without affecting other pending rows — [P1] any · tombstone, staleness, silent-fail
- `MGT-03` Audit-log icon only on active rows; opens the correct grant log — [P1] any · dead-callback, nav-lockout
- `MGT-04` Adult profiles never tutorable; empty/child-only filtering correct — [P1] any · product-rule, crash
- `MGT-05` Double-tap Revoke is single-flight — [P1] any · race, set-after-dispose
- `MGT-07` Hebrew/RTL + long emails: section/status/buttons no overflow — [P1] small-phone · i18n/RTL
- `MGG-03` Offline-first: returning tutor sees previously-entered talmidim from local mirror (CF empty) — [P1] any · offline-first, tombstone, staleness
- `MGG-04` Resign error keeps row + SnackBar; double-tap single-flight — [P1] any · silent-fail, race, offline-first
- `MGG-05` Empty grants + Hebrew/RTL; pending rows show no Resign — [P1] small-phone · i18n/RTL, product-rule
- `AUD-01` Action filter chips narrow the list; clear-filters resets — [P1] any · staleness, silent-fail
- `AUD-02` Date-range pickers filter inclusively; filtered-empty state shows — [P1] any · pace, staleness, silent-fail
- `AUD-03` Empty log + error + retry; read-only enforced — [P1] any · silent-fail, offline-first, nav-lockout
- `AUD-04` All 9 action chips + entry labels localized in Hebrew, no overflow on tablet/RTL — [P1] tablet · i18n/RTL
- `PSU-02` Mismatched confirm resets to step 1 with error, clears digits — [P1] any · silent-fail, set-after-dispose
- `PSU-03` Backspace/over-typing guards; numpad never summons soft keyboard (TUT-07) — [P1] any · dead-callback, crash
- `PGT-02` Lockout after repeated wrong PINs shows countdown, blocks entry — [P1] any · race, silent-fail, nav-lockout
- `PGT-04` TUT-01: freshly-(re)set PIN verifies on FIRST entry — [P1] any · staleness, set-after-dispose, silent-fail
- `PGT-06` Forgot-PIN affordance routes into reset flow — [P1] any · dead-callback, nav-lockout
- `PRS-01` Send reset email clears local PIN, advances to email-sent step — [P1] any · silent-fail, dead-callback, product-rule
- `PRS-02` Send failure (offline) shows inline error, does NOT clear PIN or advance — [P1] any · silent-fail, offline-first
- `PVD-03` Same-namespace consistency: a tutor who passed the entry gate isn't re-prompted under a mismatched namespace — [P1] any · product-rule, race
- `LMB-02` Tutor sees the child's PARENT/management view (not child play); persistent switcher present; chazara only stageOrder>1 — [P1] any · product-rule, dead-callback, staleness
- `LMB-06` Permitted tutor edits (bulk-prior, config) succeed + recorded in audit log — [P1] any (two-device) · silent-fail, pace, staleness, product-rule
- `PSU-04` PIN setup heading/body localized, small/RTL without overflow — [P2] small-phone · i18n/RTL
- `PRS-03` Reset screen localized; missing-email path handled — [P2] any · i18n/RTL, crash

### AREA 7 — dashboard-gamification (dashboard, achievements, redemption, pending redemptions, reward/point config, adjust-points)

**Screens:** DashboardScreen→DashboardBody, GamificationScreen, ChildRedemptionScreen, ParentPendingRedemptionsScreen, RewardConfigurationScreen, PointConfigScreen, Parent Adjust-Points dialog, AchievementUnlockCelebration, Manage Rewards sheet.

**P0**
- `DG-DASH-01` Child completion credit live-updates dashboard star counter without pull-to-refresh (`watchBalance`) — [P0] any · staleness, silent-fail, false-confidence
- `DG-DASH-02` Redemption debit reflected on dashboard counter while dashboard stays mounted under pushed redeem route (D2/F8) — [P0] any · staleness, race
- `DG-DASH-03` Streak chip is a dead no-op for adult/tutor (by design) but live nav for child — [P0] any · dead-callback, nav-lockout, product-rule
- `DG-DASH-05` Streak counter survives offline cold start (no sync-gated strand) (BUG-#35) — [P0] any · offline-first, staleness, nav-lockout
- `DG-RED-01` Affordable redeem debits balance atomically, creates pending redemption, updates balance card — [P0] any · silent-fail, staleness, tombstone
- `DG-RED-02` Insufficient balance: button disabled; double-spend race cannot drive balance negative — [P0] any · race, silent-fail, staleness
- `DG-RED-03` Tutor session: redeem view-only (disabled + hard guard), no redemption created — [P0] any · product-rule, dead-callback, silent-fail
- `DG-RED-04` Wired back button pops to Dashboard, not the switcher bar (#31) — [P0] any · dead-callback, nav-lockout
- `DG-RED-07` Offline redeem queues to outbox, survives reconnect (drain) without dead-letter — [P0] any · outbox wedge, offline-first, cross-device
- `DG-PND-01` Fulfil marks prize handed-over, no refund, child balance unchanged — [P0] any · silent-fail, staleness, product-rule
- `DG-PND-02` Decline refunds points, child balance restored, propagates to child — [P0] any · silent-fail, staleness, cross-device
- `DG-PND-03` Fulfil-vs-decline race on same card cannot both grant AND refund (D5 + `_busy`) — [P0] any · race, silent-fail, tombstone
- `DG-PND-04` Two-device decline idempotency: a late fulfil from a second device doesn't overwrite a declined+refunded row — [P0] 5554+5558 · race, cross-device, outbox wedge
- `DG-PND-06` Decline refund pushes to child's device (cross-device convergence, no LWW clobber) — [P0] 5560+5558 · cross-device, outbox wedge, staleness
- `DG-RWC-01` Create a reward end-to-end; it appears on child's redeem screen — [P0] any · silent-fail, staleness, dead-callback
- `DG-RWC-03` Manage Rewards: toggle disable hides reward; delete removes fully (no resurrection) — [P0] any · tombstone, dead-callback, silent-fail
- `DG-RWC-04` Manage Rewards modal-sheet callbacks not dead after sheet pops (edit/delete wiring; confirm dialog still appears) — [P0] any · dead-callback, silent-fail

**P1**
- `DG-DASH-04` Adult profile shows 0 points + no child rewards card (Rule 3 leakage) — [P1] any · product-rule, silent-fail
- `DG-DASH-06` Long child name + large points RTL no overflow on phone & tablet — [P1] tablet · i18n/RTL
- `DG-DASH-07` Streak does not lapse erroneously across local midnight while dashboard open (D16/D17) — [P1] any · staleness, set-after-dispose
- `DG-ACH-01` Track filter chips subset achievement rows; "All" restores — [P1] any · i18n/RTL, silent-fail, staleness
- `DG-ACH-02` Earning enough points flips a tier locked→unlocked after refresh — [P1] any · staleness, silent-fail, product-rule
- `DG-ACH-03` Empty-state and error-state render correctly (no crash, no untranslated string) — [P1] any · i18n/RTL, crash
- `DG-ACH-04` Activity & Points expansion renders streak calendar + points without intrinsic-dimension crash — [P1] tablet · crash, i18n/RTL, set-after-dispose
- `DG-ACH-05` Unlock celebration: single-flight, auto-close, no use-after-dispose on fast navigation — [P1] any · set-after-dispose, race, dead-callback, silent-fail
- `DG-RED-05` Cancel on confirm dialog leaves balance untouched (no silent debit) — [P1] any · silent-fail, dead-callback
- `DG-RED-06` Empty rewards + long single-token title render without overflow (#39) in RTL — [P1] tablet · i18n/RTL, crash
- `DG-PND-05` Pending list reactive/empties correctly; back button pops to ParentSettings (#32) — [P1] any · dead-callback, nav-lockout, staleness, i18n/RTL
- `DG-RWC-02` Duplicate threshold + invalid input rejected without a phantom success — [P1] any · silent-fail, product-rule
- `DG-RWC-05` Tutor without canEditRewards fully barred (button+toggle+delete) with feedback — [P1] any · product-rule, silent-fail, outbox wedge
- `DG-RWC-06` Manage Rewards fixed-height list scrolls without intrinsic-dimension crash; RTL/Hebrew — [P1] tablet · crash, i18n/RTL
- `DG-PTC-01` Adjust per-task points and save persists; new completions credit the new amount — [P1] any · pace, silent-fail, staleness
- `DG-PTC-02` Stepper clamps at 1 (min) and 9999 (max); decrement disabled at floor — [P1] any · pace, silent-fail
- `DG-PTC-03` Save-All with no edits → nothing-to-save / permission message — [P1] any · product-rule, silent-fail
- `DG-PTC-04` Empty-state + default-seeding do not crash or write phantom configs — [P1] any · crash, silent-fail, staleness
- `DG-PTC-05` Hebrew/RTL + multi-curriculum cards no overflow; back pops cleanly — [P1] tablet · i18n/RTL, dead-callback, nav-lockout
- `DG-ADJ-01` Parent ADD points reflects on child balance everywhere — [P1] any · staleness, silent-fail
- `DG-ADJ-02` Parent DEDUCT clamps at zero (never negative) under transactional RMW — [P1] any · race, silent-fail, pace
- `DG-ADJ-03` Adjust dialog: digit-only amount, keyboard-resize no overflow, RTL labels — [P1] small-phone · i18n/RTL, crash

**P2**
- `DG-ACH-06` First open of My Achievements does NOT surprise-party already-unlocked milestones — [P2] any · silent-fail, race

### AREA 8 — profiles-onboarding (picker, add-profile, switcher sheet, §5 switcher, PIN, onboarding, intro, permissions, parent hubs)

**Screens:** ProfilePickerScreen, showAddProfileDialog, ProfileSwitcherSheet, PersistentSwitcherScaffold+ProfileSwitcherBar, PinFlowScreen, OnboardingScreen wizard, AppIntroScreen, PermissionPromptScreen, EmptyLoginScreen, ParentSettingsScreen, ManageLearnersScreen, ParentTrackManagementScreen.

**P0**
- `PP-01` Multi-profile pick lands on correct dashboard; single-flight blocks double-tap — [P0] any · dead-callback, double-tap race, nav-lockout, staleness
- `PP-02` Delete non-active profile removes DB row + its track/completion data (no resurrection) — [P0] any · tombstone, silent-fail, cross-device
- `PP-03` Delete the ACTIVE profile auto-switches; greeting never falls back to "Learner" (Bug B) — [P0] any · staleness, dead-callback, silent-fail
- `PP-04` Delete-only-profile "Delete anyway" wipes data + routes to a recoverable empty state, not a dead-end — [P0] any · tombstone, nav-lockout, dead-callback, product-rule
- `PP-05` Cloud-born offline delete BLOCKED by picker path but ALLOWED by switcher path — surface divergence + reconcile — [P0] any · offline-first, outbox wedge, cross-device, silent-fail, tombstone
- `PP-08` Skip-to-Settings reachable for tutor-only / zero-own-profile account without forced creation — [P0] any · nav-lockout, product-rule, dead-callback
- `AP-01` (profiles) Add Profile from switcher sheet ACTUALLY creates a row (D4 silent-no-op) — [P0] any · dead-callback, silent-fail, crash
- `AP-02` (profiles) Add Profile FK/account-mismatch failure surfaces error snackbar (never silent) — [P0] any · silent-fail, invalid-companion crash, outbox wedge
- `SW-01` Switch INTO a child drops to plain child LEARNING view (parent elevation cleared, no banner) — [P0] any · dead-callback, product-rule, staleness, listener leak
- `PS-01` Switcher bar present + tappable in EVERY context (tabs + pushed sub-routes) — §5 invariant — [P0] any · absent §5 switcher, nav-lockout
- `PS-04` Exit parent-mode from child-view banner returns to own adult profile — [P0] any · dead-callback, staleness, product-rule
- `PIN-01` (profiles) Set parent PIN (setup): re-mount does NOT freeze the keypad (mount-token) — [P0] any · dead-callback, staleness, set-after-dispose
- `PIN-02` (profiles) Verify PIN unlocks parent-mode + marks guard session (correct+wrong+backspace) — [P0] any · silent-fail, nav-lockout, race, product-rule
- `PIN-05` (profiles) PIN gate is not a dead-end: cancel/back never leaves resolver hanging — [P0] any · nav-lockout, dead-callback
- `OB-01` Adult happy path: create→intent→add track→Start Learning lands on dashboard — [P0] any · dead-callback, staleness, nav-lockout, pace
- `OB-02` Child path forces parent PIN before tracks; PIN persists; handoff offers add-another-learner — [P0] any · silent-fail, dead-callback, product-rule, staleness
- `OB-04` Skip path: bypass profile creation → EmptyLoginRoute (recoverable, not dead-end) — [P0] any · nav-lockout, dead-callback, offline-first

**P1**
- `PP-06` Rename profile: duplicate-name guard + persistence — [P1] any · silent-fail, staleness, race
- `PP-07` Hebrew/RTL picker: titles/role badges/manage sheet/last-profile delete copy localized + no overflow (flag English literals in `_showDeleteDialog`) — [P1] tablet · i18n/RTL, crash
- `AP-03` (profiles) Duplicate-name + max-profiles(10) guards; controller not disposed mid-anim — [P1] any · silent-fail, set-after-dispose, product-rule
- `AP-04` (profiles) Profile type is only child/adult — no 'parent' leakage — [P1] any · product-rule, i18n/RTL
- `SW-02` Active profile row non-tappable + marked; edit/delete act on correct row — [P1] any · dead-callback, staleness, silent-fail
- `SW-03` Sheet bounded height + scroll: every tile reachable, small phone + large text — [P1] small-phone · i18n/RTL, nav-lockout, crash
- `SW-04` Switch Account routes to AccountPicker without leaving the sheet lingering — [P1] any · dead-callback, nav-lockout
- `PS-02` Switcher bar identity resolution: name + role badge never fall back wrongly — [P1] any · staleness, product-rule, i18n/RTL
- `PS-03` Switcher bar readable under DARK mode (Bug 7: opaque light strip) — [P1] any · i18n/RTL, crash
- `PIN-03` (profiles) Lockout after 5 failures: panel localized in Hebrew (D3), keypad disabled — [P1] any · i18n/RTL, silent-fail, race
- `PIN-04` (profiles) Change PIN flow (verifyCurrent→enterNew→confirm) with mismatch + lockout — [P1] any · silent-fail, race, set-after-dispose
- `OB-03` PIN-confirm mismatch in onboarding resets cleanly (no swallowed error, no stuck step) — [P1] any · silent-fail, set-after-dispose, nav-lockout
- `OB-05` Intent "Join to tutor" and "Skip" both route to empty-login with correct flags — [P1] any · nav-lockout, product-rule, dead-callback
- `OB-06` Resume onboarding after kill mid-flow restores the correct phase (no lost progress / overwrite race) — [P1] any · race, staleness, silent-fail
- `OB-07` Combined form: Hebrew-terms pill hidden under he; no English leaks; tablet no overflow — [P1] tablet · i18n/RTL, crash
- `OB-08` Onboarding entered without a live session bounces to SignIn (no orphan wizard) — [P1] any · nav-lockout, silent-fail
- `INT-01` Intro→permission prompt→sign-in chain (continue and skip both reach sign-in once) — [P1] any · nav-lockout, dead-callback, false-confidence
- `INT-02` Intro pages render localized domain terms + no overflow on small phone/RTL — [P1] small-phone · i18n/RTL, crash
- `PERM-01` First-run permission prompt requests both perms + proceeds to sign-in — [P1] API34 · silent-fail, dead-callback, set-after-dispose, staleness
- `PERM-02` Settings-launched variant uses "App Permissions"/"Done"; Shabbos terms localized — [P1] any · i18n/RTL, dead-callback
- `PERM-03` Permission prompt not shown twice (onboarding skips when already prompted) — [P1] any · dead-callback, nav-lockout, staleness
- `EL-01` (profiles) Empty-login surface gives every recovery path for a zero-profile account — [P1] any · nav-lockout, dead-callback, product-rule
- `PSET-01` Tutor scope gating: only permitted tiles show (live-mark/owner tiles barred) — [P1] any · product-rule, dead-callback, silent-fail
- `PSET-02` Adjust Points dialog: add then deduct updates live balance + pending subtitle reactively — [P1] any · staleness, silent-fail, race, pace
- `PSET-03` Parent hub navigation: every row lands on its target (no dead callback / wrong route) — [P1] any · dead-callback, nav-lockout, absent §5 switcher
- `PSET-04` Delete Account tile branches correctly local-born vs cloud-born; hidden for anonymous — [P1] any · silent-fail, tombstone, product-rule
- `ML-01` (profiles) Manage Learners list reflects add/edit/delete reactively via stream provider — [P1] any · staleness, tombstone, dead-callback, silent-fail
- `ML-02` (profiles) ProfileEditFormDialog avatar row no crash (intrinsic-dimension guard); mode display-only — [P1] any · crash, silent-fail, product-rule
- `ML-03` (profiles) Edit profile tutor permission-denied surfaces snackbar; no LWW clobber — [P1] any · outbox wedge, silent-fail, cross-device
- `PTM-01` Parent track management scoped to ACTIVE child profile (no cross-profile leakage) — [P1] any · product-rule, staleness, pace, silent-fail
- `PTM-02` Chazara UI only stageOrder>1; empty-state vs populated-state FAB gating — [P1] any · product-rule chazara-gate, staleness, pace

### AREA 9 — settings (preferences hub, permissions, sacred time, account actions, delete, upgrade, backup, lifetime marking, curriculum settings, scope, parental controls, pending invites)

**Screens:** SettingsScreen, PermissionPromptScreen, SacredTimeSettingsCard→CityPickerScreen, _AccountActionsSheet, deletion flow, UpgradeToCloudScreen, BackupSyncSection, LifetimeMarkingScreen, CurriculumSettingsScreen, ScopeSelectionScreen, _ParentalControlsSection+PIN, _PendingInvitesSection.

**P0**
- `SET-03` In-Israel flag cross-device LWW + per-device-global scope on profile switch — [P0] 5560+5558 · cross-device, outbox wedge, staleness, offline-first
- `ACCT-01` Sign out tears down shell + lands on Account Picker / Sign In without stranding on Settings — [P0] any · nav-lockout, dead-callback, set-after-dispose
- `SET-05` Account actions sheet opens from header; all rows route (not dead callbacks; `closeThen()` ROOT nav) — [P0] any · dead-callback, nav-lockout, crash
- `DEL-01` Cloud deletion: reauth, blocking overlay, wipe, route to SignIn, no resurrection (D19) — [P0] any · tombstone, cross-device, nav-lockout, silent-fail
- `DEL-02` Delete account blocked offline with explicit message — [P0] any · offline-first, silent-fail, tombstone
- `DEL-03` Local-born deletion removes db file + registry, routes correctly — [P0] any · tombstone, nav-lockout, silent-fail
- `DEL-04` Deletion error overlay offers Retry/Cancel without leaving an interactive wiped Settings — [P0] any · silent-fail, nav-lockout, set-after-dispose, tombstone
- `UPG-01` Local-born upgrade happy path: password→cloud→data pushed→success — [P0] any · cross-device, silent-fail, outbox wedge, staleness
- `UPG-03` Email-collision surfaces explicit merge choices (no silent merge) — [P0] any · cross-device, silent-fail, tombstone
- `BAK-02` Offline shows offline/pending count; identity-mismatch shows actionable Sign-in — [P0] any · outbox wedge, offline-first, cross-device, dead-callback
- `CURR-01` Change Program deletes old stages + creates new without orphaning completions — [P0] any · tombstone, staleness, pace, silent-fail
- `CURR-02` Malformed/unknown `curriculumId` path-param does not whitescreen (`:41` `firstWhere` no orElse) — [P0] any · crash, nav-lockout, silent-fail

**P1**
- `SET-01` In-Israel toggle survives location auto-detect race (no clobber) — [P1] small-phone · race, staleness, silent-fail
- `SET-02` In-Israel toggle clobbered by Detect/Choose-City auto-set — [P1] any · staleness, silent-fail, product-rule
- `SET-04` Sacred Time Detect with permission denied → correct snackbar, no crash — [P1] any · silent-fail, i18n/RTL, crash
- `SET-06` Account-management surface hidden in tutored session — [P1] any · product-rule, dead-callback, silent-fail
- `SET-07` Hebrew Terms toggle hides transliteration tile + persists; Hebrew-date updates dates app-wide — [P1] tablet · staleness, silent-fail, i18n/RTL
- `SET-08` Settings renders fully in Hebrew RTL on tablet, no overflow / English leaks (flag `:304` tagline) — [P1] tablet · i18n/RTL, crash
- `SET-09` Diagnostic-logs upload reports real outcome (no success on empty/failed write) — [P1] any · silent-fail, outbox wedge, offline-first
- `PERM-01..04` (settings) Permission prompt request/denial/re-entry + hard-coded English leak — [P1] mixed (API34/API28) · nav-lockout, silent-fail, i18n/RTL
- `CITY-01` City typeahead selects a city + persists as manual location — [P1] any · silent-fail, staleness, dead-callback
- `CITY-03` In-Israel Switch toggling pushes sync snapshot + stays consistent — [P1] any · race, outbox wedge, silent-fail
- `ACCT-02` Sign-out Cancel keeps session + data intact — [P1] any · silent-fail, tombstone
- `ACCT-03` Change password requires reauth, rejects wrong current, succeeds with valid — [P1] any · silent-fail, crash, nav-lockout
- `ACCT-04` Account sheet rows gate by profile mode (child can't sign out/delete; parent-mode unlocks add-account) — [P1] any · product-rule, silent-fail, dead-callback
- `ACCT-05` Account sheet no overflow on small/large-text/RTL (Material-ancestor ink) — [P1] small-phone · i18n/RTL, crash
- `UPG-02` Upgrade requires internet — guarded, no partial tier flip offline — [P1] any · offline-first, silent-fail, cross-device
- `UPG-04` Upgrade one-way warning + RTL/large-text integrity; flag literals — [P1] small-phone · i18n/RTL, crash
- `BAK-01` Sync status reactive, not stuck on "Connecting…" — [P1] any · staleness, offline-first, outbox wedge
- `BAK-03` Local-born LOCAL-ONLY hero card shows Upgrade CTA only for local auth — [P1] tablet · product-rule, dead-callback, i18n/RTL
- `LIFE-01` Mark lifetime selections writes to ledger + updates progress counters (idempotent) — [P1] any · silent-fail, staleness, race
- `LIFE-02` Save error surfaces; Save disabled on empty; Clear works; offline-first ledger — [P1] any · silent-fail, offline-first, i18n/RTL
- `LIFE-03` Lifetime marking entry hidden for child + tutored sessions — [P1] any · product-rule, dead-callback
- `CURR-03` Request New Program mailto launches / copy-email fallback; flag English literals — [P1] any · silent-fail, i18n/RTL
- `SCOPE-01` Save guarded against empty subset (no silent no-op with success snackbar) — [P1] any · silent-fail, staleness
- `SCOPE-02` Select-all clears subset + writes clearScopes; values render proper Hebrew names — [P1] any · staleness, i18n/RTL, silent-fail
- `PIN-01..03` (settings) Parental controls PIN gating; change PIN; section absent for adult/tutor — [P1] any · product-rule, staleness, silent-fail, set-after-dispose
- `INV-01` (settings) Pending tutor invite surfaces in Settings + Accept routes correctly — [P1] any · staleness, outbox wedge, dead-callback, offline-first

**P2**
- `CITY-02` City search short-query + no-match states (no crash, idle hint; flag English) — [P2] tablet · crash, i18n/RTL, staleness
- `LIFE-04` Panel back navigation + large tablet layout do not break — [P2] tablet · crash, i18n/RTL, nav-lockout

### AREA 10 — learning-completion (live mark-complete, bulk-mark prior, lifetime-only, learning home counters)

**Screens:** TextDisplayScreen (live writer), BulkMarkScreen, LifetimeMarkingScreen + LifetimeCurriculumMarkingScreen, LearningScreen (counter home).

**Invariants:** natural key `(profileId, sefariaRef, stageId, trackType, curriculumId)`; idempotency via pre-insert existence check (outbox has no unique index); H1 re-mark after expunge clears `purgedAt` + enqueues fresh outbox row; B8 upgrade deletes the import record; tutor live-mark barred at domain (`MarkLiveCompletionUseCase` throws `TutorWriteForbiddenException`); B1 three-tier credit (live=streak+points+siyum+lifetime; bulkInTrack=siyum+lifetime; lifetimeOnly=lifetime). Firestore payload is snake_case + ISO `completed_at`.

**P0**
- `LC-TD-01` Adult marks a scheduled daf complete — writer commits, counter projects, next task auto-advances — [P0] 5560 · silent-fail, staleness, dead-callback, race
- `LC-TD-03` Tutor session live-mark barred at domain boundary (disabled + dialog on bypass); own-profile not affected (DEC-21) — [P0] 5560 · product-rule, dead-callback, silent-fail, i18n
- `LC-TD-04` Child cannot self-mark live completion without parent PIN session; no false success — [P0] 5560 · product-rule, silent-fail
- `LC-TD-05` Offline mark-complete writes locally + queues outbox; banner does not gate the button — [P0] 5560 · offline-first, outbox wedge, silent-fail, staleness
- `LC-TD-06` Re-mark after expunge resurrects the tombstoned completion (H1) — must not stay permanently dead — [P0] 5558 · tombstone, silent-fail, outbox wedge
- `LC-BM-01` Bulk-mark a seder writes N completion_events w/ sentinel date; NOT streak (B1) — [P0] 5558 · silent-fail, pace, product-rule, staleness
- `LC-BM-03` Pre-tick reflects existing priors; untick triggers expunge (tombstone) (B7/B8) — [P0] 5554 · tombstone, staleness, silent-fail
- `LC-BM-05` B8 upgrade: live-learning a previously bulk-marked item removes the import record so untick can't kill it — [P0] 5558 · tombstone, silent-fail, product-rule
- `LC-BM-06` Bulk-mark of a large container does not hang/crash; processing→done clean — [P0] tablet 5562 · invalid-companion crash, set-after-dispose, silent-fail
- `LC-LM-01` Lifetime-only mark credits lifetime ONLY — no streak, points, or siyum — [P0] 5560 · product-rule, silent-fail, staleness, pace
- `LC-LS-01` Completing a task elsewhere reactively decrements the daily-task counter on return — [P0] 5560 · staleness, dead-callback, silent-fail

**P1**
- `LC-TD-02` Double-tap Mark Complete → exactly one completion_event + one outbox row (single-flight) — [P1] 5560 · race, silent-fail, outbox wedge
- `LC-TD-07` Mark Complete on chazara (stage>1) records correct stageId + awards stage points — [P1] 5560 · product-rule, pace, silent-fail
- `LC-TD-08` he-RTL: button + tutor tooltip + snackbars localized, no overflow on tablet — [P1] tablet 5562 · i18n/RTL, crash
- `LC-TD-09` Reader for a ref NOT in today's tasks — completion section hides, no dead button — [P1] 5560 · dead-callback, crash, silent-fail
- `LC-BM-02` Cannot mark EVERYTHING — validation blocks all-selected — [P1] 5556 · silent-fail, product-rule, i18n
- `LC-BM-04` Re-running bulk-mark over overlapping set idempotent — no duplicate outbox pushes — [P1] 5560 · race, outbox wedge, silent-fail
- `LC-BM-07` Hardcoded-English audit on bulk-mark in Hebrew — [P1] 5560 · i18n/RTL
- `LC-BM-08` "Skip" returns null + writes nothing; back-navigation doesn't strand — [P1] 5556 · silent-fail, nav-lockout, dead-callback
- `LC-LM-02` Duplicate selections de-dupe; Save idempotent across re-entry — [P1] 5554 · race, staleness, outbox wedge
- `LC-LM-03` Save error path surfaces a real error (not false success); Clear works; offline-first — [P1] 5558 · silent-fail, offline-first, set-after-dispose
- `LC-LM-04` Lifetime marking gated behind parent context; child cannot reach it — [P1] 5560 · product-rule, nav-lockout, i18n
- `LC-LS-02` All-caught-up state appears after the last task; no permanent stale list — [P1] 5556 · staleness, i18n, silent-fail
- `LC-LS-03` Empty-state Add-Track gating respects child/tutor product rules — [P1] 5558 · product-rule, dead-callback, nav-lockout
- `LC-LS-04` Overdue card "OVERDUE"/"Browse" hard-coded English — RTL tablet overflow audit — [P1] tablet 5562 · i18n/RTL

### AREA 11 — i18n-rtl (cross-cutting: 5 preference axes, locale root, curriculum labels, date-heavy surfaces, persistent switcher)

**Wiring facts:** `MaterialApp.locale` is hard-coded `null` (device-resolved only); `CurrentAppLocale`/`LanguageNotifier.setLanguage` exist but are **not wired** to `MaterialApp.locale` and there is **no in-app language picker** — so switching profiles never changes app language (a user-visible no-op). Five independent axes: appLocale, useHebrewTerms (hidden when locale==he, default TRUE), useHebrewDate (default FALSE), transliterationVariant (Ashkenazi/Sephardi, not synced), showNikud. ARB parity is exact (1153 keys each); leaks come from **hard-coded literals**, not ARB gaps.

**P0**
- `I18N-SET-06` Preference write pushes a UI-preferences snapshot to the sync outbox (and survives offline) — [P0] any · outbox wedge, offline-first, silent-fail
- `I18N-SW-01` Persistent switcher bar mirrors RTL + shows Hebrew profile/role labels on every pushed sub-route — [P0] any · absent §5 switcher / dead-callback, i18n/RTL, nav-lockout
- `I18N-SW-02` Tutor-mode amber banner + switcher localize and persist RTL across a tutored session — [P0] any · dead-callback, product-rule live-mark, i18n/RTL

**P1**
- `I18N-SET-01` Hebrew Terms toggle flips curriculum labels Hebrew↔transliteration live across screens — [P1] small-phone · staleness, i18n/RTL, dead-callback
- `I18N-SET-02` Ashkenazi↔Sephardi nusach changes named values (Bereishis vs Bereshit) — [P1] any · i18n/RTL, silent-fail, staleness
- `I18N-SET-03` Calendar English↔Hebrew reformats every displayed date app-wide (gematriya) — [P1] any · staleness, i18n/RTL, silent-fail
- `I18N-SET-04` Hebrew Terms tile correctly HIDDEN when device locale is Hebrew; no Settings leaks (flag `:304` tagline) — [P1] any · i18n/RTL, product-rule
- `I18N-SET-05` Preference toggle persists across restart AND is profile-scoped (multi-profile) — [P1] any · cross-device, staleness, product-rule, silent-fail
- `I18N-LOC-01` Switching device locale en→he flips the ENTIRE app to RTL + Hebrew on every shell tab — [P1] any · i18n/RTL, crash, absent §5 switcher
- `I18N-LOC-02` Per-profile locale preference is a dead-end: switching profiles does NOT change language (locale:null) — [P1] any · silent-fail no-op, dead-callback, product-rule
- `I18N-LOC-03` Unsupported device locale (fr/ar) falls back cleanly to a supported locale without crash — [P1] any · crash, nav-lockout, i18n/RTL
- `I18N-ONB-01` First-run onboarding on a Hebrew device shows untranslated English controls (leak hunt) — [P1] any · i18n/RTL, silent-fail
- `I18N-ONB-02` Onboarding Hebrew-calendar / Hebrew-terms pre-toggles actually take effect post-onboarding — [P1] any · silent-fail unlock-never-populated, staleness, dead-callback
- `I18N-ONB-03` Long Hebrew display name in onboarding name field does not overflow on a small phone — [P1] small-phone · i18n/RTL, crash
- `I18N-LBL-01` Hebrew curriculum label renders RTL inside an English (LTR) app shell — mixed-direction — [P1] any · i18n/RTL, staleness
- `I18N-LBL-02` Async breadcrumb/local/parent label modes resolve, never stuck on zero-width-space loading — [P1] any · offline-first, staleness, silent-fail
- `I18N-PRG-01` Progress/Siyumim leak hard-coded English to Hebrew users (stats labels + "No activity data") — [P1] any · i18n/RTL, silent-fail
- `I18N-PRG-02` Achievement dates honor calendar pref AND locale order (US month-first vs IL day-first vs gematriya) — [P1] any · i18n/RTL, staleness, pace
- `I18N-PRG-03` Long Hebrew names + large counts no overflow on tablet + small phone (RTL real pixels) — [P1] tablet · i18n/RTL, crash
- `I18N-TRK-01` Starting-position calendar header forces English month-first order in Hebrew (hard-coded pattern `:109`) — [P2] any · i18n/RTL, silent-fail
- `I18N-TRK-02` Track Detail dates respect calendar pref + locale; study-day weekday chips localize RTL — [P1] any · i18n/RTL, staleness, pace
- `I18N-RWD-01` Reward milestone tier names leak hard-coded English to a Hebrew child (`reward_milestone_service.dart:207-214`) — [P1] any · i18n/RTL, silent-fail unlock-never-populated
- `I18N-AUTH-01` Auth/intent/upgrade/search surfaces leak hard-coded English in Hebrew (sweep) — [P1] any · i18n/RTL, silent-fail
- `I18N-AUTH-02` LTR-only inputs (email/password) behave correctly inside an RTL Hebrew form — [P1] any · i18n/RTL, nav-lockout, crash
- `I18N-TXT-01` Text display renders Hebrew RTL with nikud toggle + font scaling, no overflow/clipping — [P1] tablet · i18n/RTL, crash, staleness
- `I18N-TXT-02` Content search with a Hebrew query returns + renders mixed-direction results offline — [P1] any · offline-first, i18n/RTL, nav-lockout

### AREA 12 — navigation-guards (shell, switcher sheet, PIN flow + PinGuard, profile/account pickers, accept-invite deep-link, tutor PIN gate, auth/restore guards)

**Screens:** AppShellScreen, ProfileSwitcherSheet, PinFlowScreen (3 routes), PinGuard-protected routes, ProfilePickerScreen, AccountPickerScreen, AcceptInviteScreen, TutorPinEntryGate, AuthGuard+RestoreGuard chain.

**Guard fail directions (Phase 5b systemic lockout fix):** AuthGuard→SignIn; ProfileGuard/RestoreGuard→fail OPEN; PinGuard/ChildModeGuard→fail CLOSED. Every guard wraps `onNavigation` in try/catch with `if(!resolver.isResolved) resolver.next(...)`.

**P0**
- `SHELL-01` Persistent switcher bar present + tappable on every default-context tab (D1) — [P0] any · absent §5 switcher, silent-fail
- `SHELL-02` Switcher bar tap opens sheet on a PUSHED sub-route (root-navigator context); back-arrow dead-zone — [P0] any · dead-callback, silent-fail, nav-lockout
- `SHELL-03` Tutor-mode bar persists across pushed sub-routes; Exit cleanly resets context — [P0] any · product-rule scope-leak, absent §5 switcher, nav-lockout
- `SHELL-04` Profile-less (tutor-only) account auto-lands on Settings, not stuck on empty Dashboard — [P0] any · nav-lockout, product-rule
- `SHELL-05` Parent-mode banner shows ONLY after PIN, never on bare child selection; bottom-nav suppressed — [P0] any · product-rule, silent-fail unlock-never-populated, dead-callback
- `SHELL-06` Account-switch UID change clears tutored selection (no cross-account leak) — [P0] any · product-rule scope-leak, cross-device, identity mismatch
- `SWSHEET-01` Switching profile fully resets context (tutored exit + parent-PIN clear + selection) — [P0] any · product-rule, staleness, dead-callback
- `SWSHEET-02` Add Profile from sheet actually creates a row (D4 — was silent no-op) — [P0] any · dead-callback, success-on-empty-write, delete/FK
- `SWSHEET-03` Delete profile from sheet removes the row + clears selection if active — [P0] any · tombstone, offline-first, silent-fail, nav-lockout
- `PINFLOW-01` Setup mode keypad never freezes on first keypress (stale keepAlive controller fix) — [P0] any · set-after-dispose, silent-fail, crash
- `PINFLOW-02` Verify mode success primes guard session + pops to the gated route — [P0] any · silent-fail unlock-never-populated, nav-lockout, race
- `PINFLOW-03` Wrong PIN ×5 → lockout panel localized in Hebrew (D3); route stays BLOCKED, no hang — [P0] any · i18n/RTL, nav-lockout resolver-uncompleted, silent-fail
- `PINFLOW-04` Cancel/back from PIN prompt doesn't strand the user (guard resolves next(false)) — [P0] any · nav-lockout, silent-fail
- `PINGUARD-01` childModeGuard bars an ADULT profile from parent-mode routes (fail-closed, no hang) — [P0] any · product-rule, nav-lockout, silent-fail
- `PINGUARD-02` No-PIN child profile routed to setup; success unlocks; cancel does not unlock — [P0] any · silent-fail unlock-never-populated, nav-lockout
- `PINGUARD-03` Tutor scope vs parent scope isolation — authenticating one does not unlock the other — [P0] any · product-rule PIN-namespace, silent-fail, race
- `PINGUARD-04` Corrupt `profile.mode` string does not hang child-gated routes (fail-closed catch) — [P0] any · nav-lockout resolver-uncompleted, crash, silent-fail
- `PINGUARD-05` Deep-link directly into a PIN-gated route from cold start enforces the full guard chain — [P0] small-phone · nav-lockout, silent-fail, dead-callback, malformed-decode crash
- `PICKER-01` ProfileGuard redirects to picker with 2+ profiles; selection lands in shell — [P0] any · nav-lockout, double-tap race, staleness
- `PICKER-02` Stale `selectedProfileId` from a previous account does not surface the wrong profile — [P0] any · cross-device id-collision, product-rule, staleness
- `PICKER-03` Delete last profile warning + delete; offline cloud delete blocked w/ snackbar — [P0] any · tombstone, offline-first, silent-fail, nav-lockout
- `ACCTPICK-01` Cloud account switch fully resets prior tutor/parent context + selection — [P0] any · product-rule context-reset, identity mismatch, cross-device
- `ACCTPICK-02` Cloud needing re-auth: wrong Google account aborts the switch (no half-switch) — [P0] any · identity mismatch, cross-device FK, silent-fail
- `ACCTPICK-03` Offline cloud account activates from local data (offline-first, no network gate) — [P0] any · offline-first, nav-lockout
- `ACCTPICK-04` Swipe-remove the CURRENTLY-ACTIVE account tears session down before deleting (no orphan inode) — [P0] any · tombstone, set-after-dispose, nav-lockout, crash
- `INVITE-01` Malformed deep link (?token empty/garbage/percent-junk) lands on error, no crash — [P0] small-phone · malformed-decode crash, nav-lockout, silent-fail
- `INVITE-02` Signed-out invite deep link routes to sign-in then re-delivers + accepts — [P0] any · outbox wedge, staleness, dead-callback, nav-lockout
- `TUTGATE-01` Enter talmid context: PIN gate, then pull, then land in talmid shell with no lingering sheet — [P0] any · dead-callback, nav-lockout, offline-first
- `TUTGATE-02` Tutor PIN cancel does NOT enter the talmid context (no half-entered state) — [P0] any · silent-fail, nav-lockout, product-rule scope-leak
- `TUTGATE-03` Entry pull permission-denied (revoked grant) clears selection + shows error, never enters — [P0] any · outbox wedge, cross-device orphan recovery, silent-fail
- `TUTGATE-04` Mid-session revocation while deep in a talmid sub-route auto-exits — [P0] any · cross-device orphan recovery, listener leak, nav-lockout, product-rule
- `AUTHG-01` First launch (not onboarded, no accounts) routes to SignIn, not a hang — [P0] small-phone · nav-lockout, silent-fail
- `AUTHG-02` AuthGuard fails safe to SignIn when prefs/registry throw (no hang) — [P0] any · nav-lockout resolver-uncompleted, crash, silent-fail
- `AUTHG-03` New-device restore: empty local DB + cloud account redirects to restore, completes to right destination — [P0] any · cross-device FK, nav-lockout, outbox wedge

**P1**
- `SHELL-07` RTL + long Hebrew name — switcher bar + banners no overflow on phone or tablet — [P1] tablet · i18n/RTL, crash
- `SWSHEET-04` Skip to Settings reaches Settings even with no own profile — [P1] any · nav-lockout, dead-callback
- `SWSHEET-05` Switch Account from mid-session sheet routes to AccountPicker (no dead callback after pop) — [P1] any · dead-callback, nav-lockout
- `SWSHEET-06` Sheet content scrolls (no overflow) with many profiles / large text / RTL — [P1] small-phone · i18n/RTL, crash
- `PINFLOW-05` Change-PIN flow: verify-current→new→confirm, mismatch path recovers — [P1] any · silent-fail, crash, race
- `PINFLOW-06` PIN keypad layout + dots on tablet and small-phone, RTL keypad order — [P1] tablet · i18n/RTL, crash
- `PINGUARD-06` `pinGuard.lock()` on Exit-parent-mode forces re-prompt next time — [P1] any · silent-fail, staleness, product-rule
- `PICKER-04` Pending tutor invite Accept from picker flows into accept-invite (no dead-end) — [P1] any · nav-lockout, staleness, dead-callback
- `PICKER-05` Rename duplicate-name validation + RTL grid layout — [P1] small-phone · i18n/RTL, silent-fail, race
- `ACCTPICK-05` Empty registry auto-redirects to SignInRoute, no blank screen — [P1] any · nav-lockout, silent-fail
- `ACCTPICK-06` AccountPicker tiles + dismiss backgrounds render RTL on tablet without overflow — [P1] tablet · i18n/RTL
- `INVITE-03` Accept when offline / grant not in cache uses stub + surfaces failure honestly — [P1] any · offline-first, silent-fail, outbox wedge
- `INVITE-04` Decline path changes server state + exits to shell — [P1] any · silent-fail, staleness, nav-lockout
- `INVITE-05` Accept-invite scrollable states don't overflow on short/keyboard-up, RTL — [P1] small-phone · i18n/RTL, product-rule live-mark bar
- `TUTGATE-05` Entry pull 15s timeout (offline, no cache) does not hang the spinner — [P1] any · offline-first, nav-lockout, set-after-dispose
- `TUTGATE-06` View-invitations / Manage-grants rows enforce Tutor PIN before grant data; both pop the sheet — [P1] any · dead-callback, silent-fail, product-rule
- `AUTHG-04` RestoreGuard fails OPEN to shell when DB read throws — [P1] any · nav-lockout, offline-first, silent-fail
- `AUTHG-05` Local-only user is never sent to restore (DNI-190 skip) — [P1] any · offline-first, nav-lockout

---

## 4. Execution plan — 5-emulator disjoint sharding

### 4.1 Design principle: disjoint in BOTH screens AND owned files

The cardinal rule: a fix made while running slice on emulator X must **never collide** with a fix made on emulator Y. Slices are therefore partitioned so that **no two slices touch the same `lib/features/*` directory** (owned source-file disjointness) **and** no two slices drive the same screen route (screen disjointness). Cross-cutting concerns (sync outbox, navigation guards, i18n/RTL) own files in `lib/core/`, `lib/app/router/`, and `lib/l10n/` that many features import; those are isolated onto their own device so that a guard/outbox/locale edit is the only writer of those shared roots during a run. Each worker owns a `git worktree` on its own branch; merges are serialized through the CI gate in §5.

### 4.2 Owned-file boundaries (the disjointness contract)

| Slice | Owns these source roots (writer) | Reads-only (no edits) |
|-------|----------------------------------|-----------------------|
| A (sync) | `lib/features/sync/`, `lib/app/restore/`, `lib/core/sync/`, `lib/core/outbox/`, `lib/features/settings/.../upgrade_to_cloud_screen.dart` + `backup_sync_section.dart` | content, scheduler |
| B (tracks + scheduler) | `lib/features/tracks/`, `lib/features/scheduler/`, `lib/features/sacred_time/` | sync, gamification |
| C (account-auth + nav-guards) | `lib/features/account/`, `lib/app/router/`, `lib/core/navigation/guards/` | tracks, progress |
| D (tutor + dashboard-gamification) | `lib/features/tutoring/`, `lib/features/gamification/`, `lib/features/dashboard/` | account, settings |
| E (i18n-rtl + profiles-onboarding + progress + learning-completion) | `lib/l10n/`, `lib/core/labels/`, `lib/core/preferences/`, `lib/features/profiles/`, `lib/features/onboarding/`, `lib/features/progress/`, `lib/features/content_browsing/`, `lib/features/learning/` | everything else |

These five owned-root sets are pairwise disjoint. (Slice E aggregates the read-heavy/render-heavy areas because i18n/RTL fixes live in `lib/l10n/` + per-widget literals, profiles/onboarding/progress/learning own distinct feature dirs, and none overlap A–D's owned roots.)

### 4.3 Device assignment

RTL/overflow-sensitive scenarios go to the **tablet (5562, API36)** and a **small phone (5556 API28 / 5554 API29)**; i18n/RTL is deliberately spread across device types (tablet for wide-layout RenderFlex, small phone for crowding/large-text). Pure-logic FK/outbox/lifecycle scenarios run on the mid phones.

| Emulator | API | Form | Owns slice | Primary load | RTL/overflow duty |
|----------|----:|------|-----------|--------------|-------------------|
| **emulator-5562** | 36 | **TABLET** | **E** (i18n-rtl + profiles + progress + learning) | All `device_pref: tablet`/i18n-RTL scenarios across ALL areas run their **tablet pass** here; plus slice-E logic | **Primary RTL/wide-layout device** — runs the tablet column of every i18n/overflow scenario |
| **emulator-5556** | 28 | small phone | **B** (tracks + scheduler) | Slice-B P0 logic + the **small-phone pass** of RTL/overflow scenarios | **Secondary RTL/crowding device** — small-phone column of i18n/overflow scenarios + large-text (`font_scale 1.5`) |
| **emulator-5560** | 31 | phone | **C** (account-auth + nav-guards) | Slice-C P0 logic (sign-in, restore, account picker, guards, deep-links); also the learning-completion writer pass (`LC-TD-*`) by arrangement with E's reader pass | none (logic device) |
| **emulator-5558** | 34 | phone | **A** (sync) | Slice-A P0 (outbox wedge, drain, upgrade, identity mismatch); the **cloud-side** of two-device sync pairs; runtime-permission prompts (POST_NOTIFICATIONS) | none |
| **emulator-5554** | 29 | phone | **D** (tutor + dashboard-gamification) | Slice-D P0 (grant lifecycle, redemption races, D18 resurrection); the **second device** for fulfil/decline & revocation two-device pairs | none |

**Two-device pairing map** (both emulators on the SAME cloud account/profile):
- Cross-device sync LWW / drain (`SYNC-DRAIN-02/04`, `SYNC-UPGRADE-02`): **5558 (A) ↔ 5560 (C)** — A owns sync files, C provides the second device read-only.
- In-Israel cross-device (`SET-03`): **5560 ↔ 5558**.
- Tutor parent↔tutor (`INV-05`, `DEC-01`, `MGT-01/08`, `MGG-01`, `LMB-05/06`, `ACC-05`): **5554 (D, tutor) ↔ 5558 (A, parent account)** or **5554 ↔ 5560**.
- Fulfil/decline + refund convergence (`DG-PND-04/06`): **5554 (parent) ↔ 5558 / 5560 (child)** exactly as the catalog specifies (5554+5558 and 5560+5558).

Two-device scenarios are the only place slices "share" a device; the **owning** slice (the one whose files may change) drives the test and writes fixes; the partner device is **read-only** (drives input, asserts UI, never edits source). This preserves owned-file disjointness even across pairs.

### 4.4 Run order within each slice

1. **P0 on-device-only first** (taxonomy classes 1–3, 5): tombstone/FK, outbox wedge, cross-device, dead-callback. These are the highest-yield and cannot be caught headless.
2. **Remaining P0** (classes 4, 6, 7): nav-lockout, silent-fail, crash.
3. **P1** (8–13): staleness, i18n/RTL, product-rule, race, offline-first, pace. RTL/overflow scenarios queue onto 5562 + 5556 for their device passes.
4. **P2** (14–15): lifecycle, dead-UI / false-confidence.

Each worker: per scenario, drive via `adb input tap/text`, assert via `uiautomator dump` + `adb exec-out screencap`, relaunch via `am force-stop`, inspect DB via `run-as ... cat *.sqlite` → `sqlite3`. On a failure, fix **only within the slice's owned roots**, re-run the scenario, log the result and the bug-class to `docs/planning/test-fix-bug-log.md`. If a fix would need to touch another slice's owned root, file a cross-slice handoff rather than editing it.

### 4.5 Coverage accounting

P0 distribution by owning slice (approx.): A ≈ 14, B ≈ 18, C ≈ 38, D ≈ 26, E ≈ 35. Every two-device P0 is assigned to exactly one owning slice + one read-only partner. RTL/overflow P1s (~50 scenarios) each get a tablet pass on 5562 and a small-phone pass on 5556, run after that slice's P0s clear.

---

## 5. CI-gate recommendation — make real-device E2E block merges

**Problem today:** `make ci` = `analyze validate-calendar test`, where `test` is a headless `flutter test` behind a line-coverage floor that a "renders/no-throw" test satisfies without asserting behaviour. `.github/workflows/ci.yml` has only a Firestore-**rules** emulator job; there is **no Android-emulator / flutter-drive step**, and `integration_test/app_test.dart` is **not** in the ci chain. So none of the P0 classes above can ever be regression-gated.

**Recommendation (phased, so it can ship incrementally):**

1. **Promote `integration_test/` into a real device job, and make it required.** Add a CI job (`e2e-android`) that boots a headless Android emulator via `reactivecircus/android-emulator-runner` (matrix: 1 phone API31 + 1 tablet API36) and runs `flutter drive`/`flutter test integration_test/` against it. Wire this job into the **branch-protection required checks** so a red E2E blocks merge — closing the exact gap that lets `make ci` pass while the assembled app breaks.

2. **Encode the P0 invariants as the first integration scenarios**, in priority order of the taxonomy: (a) **FK-delete with `PRAGMA foreign_keys=ON`** against RESTRICT FKs (archive/wipe a populated track, assert the dialog actually deleted and `completion_events` count never decreased, then relaunch and assert no resurrection); (b) **outbox drain against the Firebase emulator with the deployed `firestore.rules`** loaded (queue a snake_case/ISO-string write, assert it drains to 0, assert a permission-denied write surfaces "Sync paused" not a false "Synced"); (c) **navigation-lockout fuzz** that injects a throwing dependency into each guard and asserts the `auto_route` resolver still completes (no hang); (d) **persistent §5 switcher present-and-tappable** on every default tab and pushed sub-route; (e) **tutor live-mark bar** asserting `MarkLiveCompletionUseCase` writes nothing in a tutor session. Each maps 1:1 to a taxonomy class so a regression is auto-classified.

3. **Add a Hebrew/RTL render gate.** Run the integration suite a second time with `--dart-define=LOCALE=he` (or set the emulator locale to he-IL) on the tablet matrix leg, scanning `logcat` for `RenderFlex overflowed` and asserting key surfaces render the localized value rather than a Latin literal — turning the 42-frequency i18n leak class from "invisible to `find.text` in en" into a blocking check.

4. **Two-device convergence as a nightly required-before-release job.** A scheduled job pairs two emulators on one Firebase-emulator account and runs the LWW / fulfil-vs-decline / revocation-resurrection convergence scenarios; gate **release tags** (not every PR) on it, since these are slower.

5. **Retire the false-confidence floor as the sole gate.** Keep the line-coverage floor as a signal, but make the **device E2E job the merge-blocking authority**, so coverage can no longer climb to 80% while every on-device sweep still root-causes defects.

**One-paragraph summary:** Add a required `e2e-android` CI job that boots real phone+tablet emulators (`reactivecircus/android-emulator-runner`), runs `flutter test integration_test/` (currently excluded from `make ci`) with `PRAGMA foreign_keys=ON`, the deployed `firestore.rules` loaded into the Firebase emulator, a guard-throw navigation-lockout fuzz, the persistent-§5-switcher and tutor-live-mark invariants, and a second he-RTL pass on the tablet that fails on `RenderFlex overflowed` or untranslated literals — wired into branch-protection so a red device E2E blocks merge, with two-device LWW/fulfil-decline/revocation-resurrection convergence gating release tags nightly; this makes the FK-delete, outbox-wedge, cross-device, nav-lockout, dead-callback, and i18n-leak classes regression-proof instead of invisible to today's headless `flutter test`.

---

*End of master E2E test design document. Scenario IDs trace back to the per-area catalogs; P0 on-device-only scenarios are the priority because the merge gate is 100% headless and the single integration test is excluded from `make ci`.*
