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

### Iteration 2 — COMPLETE (2026-06-09) — pushed to dev (6f68ca9f..bca4b912)

First round with REAL on-device driving on all 5 (the hardened brief worked: screencaps, uiautomator dumps,
DB ground-truth, disk hygiene, analyze+format before commit). **~14 fixes integrated** + 3 regression guards:
- Slice B: `StudyDayConfig` screen had NO navigation path anywhere in the app (added the tile); study-day
  toggle race (scheduler rebuilt from stale data before the DB write committed). Dead `toggleStudyDay`
  provider annotated.
- Slice C: drift `.sqlite`-suffix orphan **data-loss** (account DBs never deleted — bare path missing suffix);
  3× false sign-out errors on no-Play-Services / partial-CredentialManager devices.
- Slice D: idempotency + stream-reactivity regression guards (declineRedemption/fulfilRedemption/watchBalance).
- Slice A: spurious `SyncStatus.syncing` on late subscribe; `DeviceRestoreScreen` hard-coded English.
- Slice E: `OverallStatsCard` + `ContentHierarchy` i18n; recent-activity staleness.
- Regression-fix pass (caught by the consolidated gate): the ContentTree integration over-restricted the
  `filteredContentProvider` fallback (`&& _navigationStack.isNotEmpty`) → **root-level content screen showed
  "No content available" even with data** — real user-facing bug, fixed; content-hierarchy tests given i18n
  delegates. sync/infra "failures" were transient full-suite pollution, not real regressions.

**Gate discipline held:** iter-2 worker fixes changed behaviour their slice tests didn't cover; the
consolidated `make ci` caught 7 cross-cutting test breakages, a focused 2-agent fix-it pass resolved them
(fix-code vs update-test decided per case, no weakened tests), and only then did dev go green + push. Remaining
reds are the 4 pre-existing golden screenshot tests (fail on pristine dev too — local WSL fonts ≠ CI image).

**New process lessons → iteration 3:**
1. Copy git-ignored build assets (`content.db.gz`, `google-services.json`) into each worktree at setup so
   workers can rebuild the APK for on-device re-verification (slice E was blocked on this).
2. Workers should run the FULL relevant test directory (not just their new test) before committing, to catch
   sibling-test breakage their slice change causes (the gap that needed the regression-fix pass).
3. Exclude `test/golden/` from the loop's local gate so "any failure = a real regression" (the 4 goldens
   can't pass locally and were masking real reds).

**Blockers routed to iteration 3:**
- **Parent-PIN nav dead-end (P0):** confirming a new PIN in SetParentPINScreen loops back to itself instead of
  ParentSettings — lives in `features/profiles/` (slice E root); blocked slice D's whole redemption/reward
  sweep. → assign to slice E.
- Cross-slice i18n: `backup_sync_section.dart` hard-coded English (lines 148/211/292/395). → assign to slice E
  (owns l10n) or settings owner.

### Iteration 3 — PENDING
Rebuild+redeploy (done post-iter2) → relaunch with: parent-PIN nav fix on slice E (unblocks gamification
sweep on slice D); worktree asset-copy in setup; full-test-dir pre-commit check; golden exclusion in gate.
Then bring sync (App Check) online for cloud/two-device P0s.

### Iteration 3 — COMPLETE (2026-06-10) — pushed to dev. CLEAN run (no regression-fix pass needed).
4 phones (tablet deferred for partition repair). 6 fixes, all red→green + full-dir-green + analyze/format clean:
- Slice C: **P0 parent-PIN nav dead-end FIXED** — PinFlowSetup completion didn't call pinGuard.markAuthenticated
  before maybePop, so the guard re-pushed the PIN screen in an infinite loop; fixed in pin_flow_screen.dart,
  on-device verified reaching Parent Settings. (C ran out of context before its Area 5+12 sweep — carry over.)
- Slice A: DeviceRestoreScreen went **permanently blank** (SizedBox.shrink nav-deadlock); Backup error-card
  state-machine invariant violation. Both fixed.
- Slice D: 2 more stale-provider bugs (childRedemptionRewards after save; achievementsOverview after debit);
  drove the real decline→refund flow on-device; re-verified 3 iter2 stream fixes.
- Slice B: pluralization "1 today tasks" grammar; re-verified archive/wipe DB ground-truth + chazara gate.
The "run full test dir before commit" rule (iter2 lesson) eliminated cross-cutting regressions — gate passed
first try (modulo the 4 environmental goldens).

### Iteration 4 — PENDING
Repair tablet (wipe-data restart → 32G partition; config already set) → re-add slice E (i18n/profiles/progress
tablet RTL + carryover) → bring sync (App Check) online for cloud/two-device P0s → carry over slice C Area 5+12.

### Iteration 4 — CRASHED mid-run (2026-06-10 ~02:30) → partial salvage
The host computer crashed ~8h into the run, killing the workflow. 4 fixes had committed to branches before the
crash and were SALVAGED (merged + gated + pushed to dev f1141a98):
- A: write-tee drain didn't update sync-status badge after push failure.
- B: stale goal display after EditTrack (provider not invalidated on route pop).
- C: onboarding intent screen hardcoded English → localized; Google sign-in null-user showed no error.
- D, E: never committed (crash hit first). Setup that DID survive: all 5 devices were rebuilt with Play Store +
  32G partitions + App Check registered (cloud sync online), so cloud P0s are now testable.
Lesson: commit-as-you-go + git branches made the crash a non-event for completed work.

### Iteration 5 — IN PROGRESS (2026-06-10) — 3 devices (post-crash, user reduced fleet)
Live fleet (port→API reshuffled again on reboot): emu-5554=API36 TABLET, emu-5556=API31, emu-5558=API29 —
all Play Store + app + App Check registered. Prioritizing the two areas the crash left at ZERO coverage:
- E (tablet 5554): i18n/RTL + profiles + progress + learning — Add-Profile, persistent switcher, he-RTL tablet overflow.
- D (5556): parent-mode gamification sweep (now unblocked) — rewards/redemption/fulfil-vs-decline/achievements.
- A (5558): REAL cloud sync — outbox drain to Firestore, push/pull, deployed-rules rejection, offline→online idempotent drain.

### Iteration 5 — COMPLETE (2026-06-10, 3 devices) — validation-heavy, 0 commits
- D (5556): drove the FULL parent-mode gamification flow on-device — 15 cells, ALL PASS, 0 bugs. Set PIN →
  redeem → fulfil → decline+refund → adjust points → disable/delete rewards → streak nav. Strong validation
  that the iter1/3 fixes hold end-to-end. Found 2 cross-slice items: wrong-password sign-in shows no error
  (account); childRedemptionRewardsProvider one-shot (low-sev).
- A (5558): identified offline stale-sync-badge bug but did not land the fix.
- E (5554 tablet): FAILED on an image-processing API error (worker loaded a screenshot into context). 0 coverage.
  → Lesson: workers must NEVER load screenshot PNGs into context; text-only assertions (uiautomator/logcat).

### Iteration 6 — COMPLETE (2026-06-10, 3 devices) — pushed to dev (..24678e1c). 2 fixes.
- C (5556): FIXED the wrong-password silent sign-in failure — setCallbacks ran in a postFrameCallback, racing
  sign-in completion so the error was dropped; moved to synchronous initState (df797460). red→green.
- A (5558): FIXED the offline stale-sync-badge — offline transition during an active pull stuck on "Syncing…"
  (82eea7b3). red→green.
- E (5554 tablet): image-safe RETRY succeeded — 13 cells ALL PASS, 0 bugs. Add-Profile works, persistent
  switcher on all tabs, he-RTL ZERO RenderFlex overflow + all-Hebrew rendering, multi-profile, progress fresh.
  ~2800 owned-root regression tests green. Tablet i18n/profiles/progress area CONFIRMED clean.
- BLOCKER (A+C): interactive Google sign-in is NOT automatable on the emulator → deep cloud-sync P0s (outbox
  drain to Firestore, two-device convergence) gated on establishing a cloud session. App Check IS registered;
  options for iter8+: email/password signup (creates test accounts in real Firebase) OR user signs in a test
  account manually. Awaiting user decision.

### Iteration 7 — IN PROGRESS (2026-06-10, 3 devices) — non-cloud-gated coverage
- B (5556): tracks/scheduler deep sweep (EditTrack, calendar programs, sacred-time, reorder, overdue) — overdue since iter3.
- E (5554 tablet): learning-completion + content-browsing + onboarding remaining cells.
- C (5558): account/nav cells not needing Google (account picker, switch/sign-out, magic-link, offline restore).

### Iteration 8 — COMPLETE (2026-06-10) — pushed to dev (..67854cf4). CLOUD SYNC MILESTONE.
Cloud unblocked via pre-created VERIFIED test accounts (Firebase Admin API: test-loop-a/c@orvex.test,
emailVerified=true — bypasses the app's sign-in verification gate; deployed rules only need auth!=null).
- A (5558, cloud sync): REAL Firestore sync PROVEN — outbox drains to 0 (10 rows), force-stop+relaunch pulls
  back (no loss), offline→online drains IDEMPOTENTLY (6 rows, UNIQUE index prevents resurrection), ZERO
  permission-denied on own data. FIXED SYNC-DRAIN-DELAY-01 (no event-driven drain when Firebase identity
  transitions mismatched→matched on a multi-account device → completions sat ~3min unsynced). Test added in iter9.
- C (5556, cloud account): lifecycle VALIDATED clean — email sign-in → registry row correct (tier=cloudBorn,
  firebaseUid), sign-out clean, re-sign-in no dup, account picker + switch cloud↔local all work.
- E (5554 tablet): onboarding — found + fixed a 0.1px RenderFlex overflow on profile-creation (narrow viewport).
CROSS-SLICE FINDINGS (routed to iter9): FK-CONSTRAINT-ONBOARDING-01 (P0 — fresh cloud account keeps stale
profile_id=1 → track-create FK crash); SYNC-STATUS-STALE-02 (badge stuck pending w/ empty outbox after relaunch);
account-picker tap, settings header condition, registration hardcoded English.
PROCESS: worktree codegen gap left A's fix unverified → iter9 PRE-RUNS build_runner in every worktree.
KEY: these cloud seam bugs (drain latency, stale badge, FK-on-fresh-account) are exactly the P0 classes the
596 headless tests structurally cannot see — the original thesis, now demonstrated on real Firestore.

### Iteration 9 — IN PROGRESS (2026-06-10) — fixing iter8 cross-slice findings
- E (tablet): P0 FK-onboarding self-heal (stale profile selection). A: SYNC-STATUS-STALE-02 + drain-delay test.
  C: account-picker tap + registration i18n + settings header. Worktrees have codegen pre-run.

### Iteration 10 — COMPLETE (2026-06-10) — TUTOR FRONTIER (last zero-coverage area). 2 fixes.
- TUTOR (two-device: parent test-loop-c on 5556, tutor test-loop-a on 5558): the cross-account flow WORKS
  end-to-end — invite → accept → tutor sees the child's PARENT view (not child-mode), LIVE-MARK BARRED
  (MarkLiveCompletionUseCase throws TutorWriteForbiddenException), persistent switcher shows tutored context,
  revoke removes access. FIXED DG-TUT-STALE-01: parent's Manage Tutors stuck on stale "Pending" after the
  tutor accepted — non-autoDispose FutureProvider.family cached it; → autoDispose (c56ca72d). red→green.
- SETTINGS (5554 tablet): FIXED 3 i18n bugs — delete-account dialog, sign-out dialog, send-logs snackbar all
  hardcoded English → localized (ccbb7e15). Validated: in-Israel/Hebrew-terms persistence, curriculum, account sheet.
CROSS-SLICE FINDINGS → iter11:
- D18 mirror-wipe skipped in tutored session: currentAccountIdProvider resolves to the talmid's id (not the
  tutor's account) during a tutored session → the local mirror wipe targets the wrong id and no-ops (safety net:
  next pull throws permission-denied and wipes directly). Cross-root: core/sync + profiles.
- Notification reminderEnabled returns true with profileId=0 before activeProfileIdProvider resolves → toggle
  shows ON after relaunch despite pref=false (lib/features/notifications/).
- permission_prompt_screen.dart (onboarding) rationale copy hardcoded English.

MILESTONE: every catalog area (sync, tracks, progress, scheduler, account, tutor, gamification, profiles,
settings, learning, i18n, nav) now has real on-device coverage. Trend is strongly validation-heavy → convergence.

### VISION-AUDIT REMEDIATION (2026-06-11) — the redesigned approach
Daniel's concern (correct): the text-only loop left the app buggy after every run. Recalibration audit proved
it caught only 1 of 75 escaped manual bugs (~99% blind) — the bugs live in pixels (visual), meaning (domain
terms), timing (exploration), and the 2nd device, none of which uiautomator+logcat can see.
REDESIGN: vision (downscaled screenshots judged by a vision agent against a human rubric) + domain-term oracle
+ adversarial exploration + depth (one screen exhausted per unit). Capability proven (tool/vision_find_pass.js).
- FIND: 47-screen vision sweep → 248 findings (2 P0, 47 P1, 199 P2). By sense: vision 75, oracle 65,
  exploration 61, logic 47 — exactly the classes the old loop scored ~0 on. Evidence in docs/test-artifacts/vision-findings/.
- TRIAGE: 248 → 82 clusters (63 confirmed bugs, 12 product-decisions, 7 needs-investigation). Plan:
  docs/test-artifacts/bulk-fix-plan-2026-06-11.md.
- BULK FIX: Wave A (45 confirmed bugs, owned-root shards) + 16 stale-test corrections + golden regen → FIRST
  fully-green make ci (exit 0). Wave B (18 cross-root clusters incl. the child-switch-without-PIN P1 security
  bug, gematriya year, chazara-label collision, city-build-script, deep-link manifest). 63 confirmed bugs fixed,
  37 fix commits, pushed to dev (3b3b542c), gate green.
- DEFERRED: 12 product-decisions (await Daniel); city cities.sqlite asset regen (needs GeoNames source download);
  ST-3 a11y leftovers (point-config/add-learner/invite-tutor); PP-17 search aliases.
- NEXT: rebuild+redeploy, REDO vision sweep to confirm findings resolved + catch regressions; iterate until clean.
KEY LESSON: a green automated run means nothing without VISION + a DOMAIN ORACLE + EXPLORATION. "String present"
is not "string correct"; the widget tree is not the rendered screen.
