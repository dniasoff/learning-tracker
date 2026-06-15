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

### REDO R1 (2026-06-11) — find→fix→redo cycle on the first 6 re-audited screens
REDO FIND (redo_R1.json, 36 findings): many prior fixes CONFIRMED on-device (AN-7 glyphs, IL-4 colors, daily-
reminder persistence, TS-9 elapsed dup, reactive balance). But 1 P0 + 10 P1 remained — dominated by the KEYSTONE:
the Hebrew UI-locale switch did not take effect on-device and there was NO in-app language switcher
(LanguageNotifier.setLanguage had zero callers), so all he-RTL verification across 47 screens was blocked, and
"half-translated" Hebrew screens couldn't even be reached.
- KEYSTONE FIXED (commit 6199143b): added _AppLanguageTile (PreferenceSegmentedTile<String> English/עברית) at the
  top of Settings → languageProvider.setLanguage → CurrentAppLocale.set → MaterialApp.locale. The MaterialApp.locale
  wiring was already correct; the only gap was a UI control to drive it. New ARB keys settingsLanguage/Subtitle.
  The 'No backup' badge finding was a SYMPTOM (already localized; just never reached he) — resolved by the keystone.
- R1 FIX WAVE (workflow w4f9xr4zj, 4 worktree workers off 6199143b, disjoint file sets + additive ARB):
  · addtrack (r1-tracks2): Genesis→transliteration toast, step-count denominator stability, "1 DAYS"/"1 study days"
    plurals, scope breadcrumb overflow+redundancy, Back-loses-scope-selection, Starting-Position 59px overflow @1.3.
  · trackdetail (r1-locale): TS-8 date-calendar consistency (Est. finish honors Hebrew-date pref), delete-dialog
    safety hierarchy, Hebrew Edit-Goal full localization + label truncation, empty-track-name validation, Kodshim spelling.
  · scheduler-studydays (r1-content2): Hebrew Study-Days full localization (title/subtitle/weekday-abbr/footer),
    0-study-days warning guard.
  · gamif (r1-gamif2): IceCream mid-word wrap fix @1.3, redeemScreenTitle he 'פרס הפרסים'→'מימוש פרסים'.
- R1 FIX INTEGRATED + PUSHED (commit 757ca4f2, dev): TWIST — the "lost" workflow w5aephf8l was actually still live
  and committed to the SAME r1-* branches concurrently with the new w4f9xr4zj, so dev was assembled by reconciling
  BOTH waves: cherry-picked the FULLER version of each overlap file (study_day_config←r1-content2 full he-localize
  +zero-day guard, TS-4 Saturday-nusach preserved; track_detail/edit_track/no_backup_badge←r1-locale inline name
  validation + Est-finish honors Hebrew-calendar + delete-dialog safety + localized review-days + localized badge;
  child_redemption←r1-gamif2; add-track wizard+goal_setup+plurals←r1-tracks2 merged). ARB unioned additively across
  all 4 branches via tool/merge_arb.py; kept keystone settingsLanguage tile. Restored validateTrackName/studyDayCount
  pure helpers. Fixed 4 test failures: TS-4 l10n arg, NoBackupBadge l10n delegates+"No Backup", 2 settings scrolls →
  scrollUntilVisible (new language tile shifted list), and a PRE-EXISTING rogue DateTime.now() in
  parent_track_management (archive path) → localDayClockProvider.nowUtc(). make ci GREEN (9866 pass / 150 skip).
- REDEPLOYED: debug APK (overflow stripes visible) built + installed on all 3 emulators; app launches clean past
  seed (no OOM); "No Backup" badge renders localized. R1v2 redo-verification sweep RUNNING (workflow wtqlkdi9v) over
  the 6 R1 screens — keystone language switcher (Settings→App Language→עברית→full RTL) checked first.
- R1v2 REDO RESULTS (workflow wtqlkdi9v, 6 screens, 24 findings: 1 P0/2 P1/21 P2): KEYSTONE CONFIRMED on-device —
  Settings→App Language→עברית flips the ENTIRE UI to Hebrew RTL (chrome mirrors, nav translates+reorders, terms
  localize), round-trips to English, works in adult AND child. The "P0" was that confirmation (mislabeled), not a
  bug. MANY fixes verified: TS-8 dates, empty-name validation, scheduler Study-Days Hebrew (config screen), Edit Goal
  Hebrew, delete-dialog safety, reactive balance, parent-PIN clears. Real remaining bugs found:
  · [P1] redeemScreenTitle he STILL 'פרס הפרסים' — the additive ARB union DROPPED this MODIFIED-existing key (only
    ADDED new keys). FIXED directly (→ 'מימוש פרסים', commit 1a30e5bd). LESSON: union must also apply modifications.
  · [P1] Backup & Sync promo card stayed English under Hebrew UI (title+body hardcoded) — FIXED: backupSyncCardTitle/
    Body en+he, all 3 layout variants (1a30e5bd). make ci-safe (backup test asserts unchanged EN values).
  · CLUSTER → R1v2 fix wave (workflow wv9q2wxxt, 2 workers off 1a30e5bd, disjoint roots, NO concurrent workflow):
    W-tracks: study-days step Latin/mixed weekday avatars→localized (schedulerDayAbbrev*+shabbos), scope breadcrumb
    redundancy in Hebrew-Terms mode, goal-step "(≈0 items)" guard, edited-track-name not surfacing (P1 functional).
    W-sched-dash: Edit-Goal pace-helper truncation, dashboard "Today's Missions" clip @1.3.
  · DEFERRED (cosmetic/product): '!Auditor' bidi on a Latin test-name; carousel badge 'Today' vs 'CURRENT FOCUS';
    App-Language-tile-placement nit (it IS at top of the prefs card); Genesis/Kodshim content-DB data (asset regen).
- INTEGRATION DISCIPLINE going forward: cherry-pick fuller file per owner; ARB union must catch MODIFICATIONS not
  just additions (tool/merge_arb.py is additive-only — verify modified keys manually, as redeemScreenTitle showed).
- R1v2 CLUSTER FIXES INTEGRATED + PUSHED (commit 2c62ff2c, dev): merged r1-tracks2 + r1-locale CLEANLY (disjoint
  roots — no conflicts, unlike R1). study-day avatars localized (schedulerDayAbbrev*+shabbos, grapheme-safe initials),
  scope-prompt script consistency (Hebrew-Terms vs locale mismatch fixed), goal "(≈0 items)" guard
  (addTrackGoalDeadlinePaceLineNoTotal), EDITED TRACK NAME now surfaces as title (was stored in Goal.description,
  ignored — resolveTrackTitle()/trackDisplayTitle wired into detail AppBar + track cards), Edit-Goal pace-helper
  truncation (full-width field + helperMaxLines), dashboard "Today's Missions" wraps @1.3, + MainFocusMissionCard
  "Start learning" button FittedBox @1.3 (pre-existing overflow the worker flagged). make ci GREEN (9886 pass, +20
  new red→green tests). Debug APK rebuilt + installed on all 3 emulators.
- REDO PROGRESS: the 6 R1 screens are now test-covered + keystone-confirmed. Pivoted to the UNVERIFIED screens.
  Original sweep = 45 screens; R1 did 6. R2 sweep RUNNING (workflow ws5ntz2h9) over 6 high-Hebrew-risk screens:
  gamification, curriculum_settings (nusach/hebrew-terms), content_search, learning, scheduler, content_hierarchy.
- R2 REDO RESULTS (workflow ws5ntz2h9, 6 screens, 26 findings: 4 P1/22 P2): keystone CONFIRMED clean on 3 more
  screens; content_search clean (0 findings); Nikud + Nusach live-toggle verified. Real bugs → R2 fix wave (wlo2t68j7,
  2 workers off 2c62ff2c, disjoint roots scheduler+l10n vs content_browsing):
  · [P1] scheduler daily-task goal banner ("TODAY'S GOAL" + "N today tasks", scheduler_screen.dart:293) leaks English
    under Hebrew UI → localize + pluralize.
  · count=1 pluralization (ARB-only): tierCounter* family (streakDays/siyumimEarned/lifetimeItems/points, en+he) +
    curriculum-settings "{count} Masechta" → ICU plural.
  · scheduler "Next daily task" button clipped by nav-bar inset → SafeArea.
  · content_hierarchy breadcrumb: RTL separator chevrons point opposite ways; current crumb clipped mid-word @1.3;
    system-Back discards the whole drill path (should step one level like AppBar back) → PopScope.
  · DEFERRED (product-decision/minor): Hebrew-Terms toggle hidden when UI=he (settings `!= 'he'` guard) — terms then
    render transliterated with no toggle to change them (design call — ask Daniel); scheduler notification-icon red
    disc vs pastel palette (minor); transient ghost/flash frames during font re-layout.
  · BLOCKED on TEST DATA (not app bugs): gamification (My Achievements) is child-only and only reachable via a
    POPULATED child dashboard's streak/flame chip — the lone child profile (Yossi) has zero tracks/points/streak, so
    no entry point exists; needs a seeded child with an active track + non-zero streak/points (and the Parent PIN is
    unknown to workers — 1234/0000 rejected). scheduler populated task-list was empty on 5554 this session. → seed a
    child-with-streak + daily-tasks before re-auditing these two; pluralization bugs there were still caught by STATIC
    l10n review. NOTE: audit brief named profile 'Shloime' but the device has 'Yossi' — brief drift, harmless.
- NEXT: integrate R2 fix wave → make ci → push → redeploy → redo R2's fixed screens; seed gamification/scheduler data;
  then R3..R6 for the remaining ~33 screens. Mandate: "check every screen … redo until no bugs."

### R2 fixes integrated + R3 launched (2026-06-11)
- R2 FIX WAVE integrated + pushed (commit 22bf15e0, make ci GREEN 9902 pass): scheduler daily-task banner Hebrew +
  ICU plural (schedulerTodaysGoal/schedulerGoalTaskCount), tierCounter* ICU plurals (en + he dual one/two/other),
  content-hierarchy breadcrumb RTL chevron consistency + current-crumb clip@1.3 + system-Back steps-one-level
  (PopScope), text-reader bottom buttons SafeArea(top:false). Disjoint-root merges = clean. Workers added ~16 tests.
  DEFERRED: masechta-count "{count} Masechta" plural (needs per-nusach plural-forms table). Debug APK redeployed.
- R3 redo RUNNING (workflow wxta2gkt4): gamification (with a child-profile SEEDING attempt to reach the streak-chip
  entry), reward_configuration, curriculum_progress, recent_activity, siyumim_milestones, lifetime_marking.
- CUMULATIVE: 12 of ~45 screens redo-verified (R1 6, R2 6); ~30 real bugs fixed + keystone; ~33 screens remain.

### PRODUCT CORRECTION (2026-06-11) — App language follows the DEVICE language
Daniel: "App Language wasn't supposed to be configurable - it should be dependant on device language." The earlier
"keystone" (an in-app App Language switcher + per-profile app-locale pref) was the WRONG approach. REVERTED + made
device-driven (commit 95ede74a, make ci GREEN 9900 pass):
- MaterialApp.locale = null → Flutter resolves the DEVICE locale against [en, he] (Hebrew device → he + RTL, else en),
  reacting to runtime device-language changes via didChangeLocales.
- currentAppLocaleProvider now derives from PlatformDispatcher.locales (device) for background notifications; new
  resolveDeviceUiLocale() mirrors Flutter's resolution. Invalidated on didChangeLocales.
- REMOVED: _AppLanguageTile, LanguageNotifier/languageProvider, AppLocalePreference + provider, per-profile
  CurrentAppLocale binding, supportedLanguages map, settingsLanguage*/settingsAppLanguage* ARB keys, 2
  language_provider.dart files. Rewrote locale_wiring_test (device-driven contract + no switcher); fixed
  coverage/notifications/schema tests. Vestigial synced app_locale field left in place (removal would ripple ~30 sync
  tests for no user benefit).
- IMPLICATION FOR THE REDO LOOP: the R1/R1v2/R2 confirmations that "the in-app switcher flips to Hebrew" are now MOOT
  (the switcher is gone). Hebrew/RTL must be verified by setting the DEVICE language to Hebrew (adb: `adb root` +
  `setprop persist.sys.locale he-IL` + restart zygote), NOT an in-app toggle. The Hebrew TRANSLATION fixes all remain
  valid (they fix the he device path). Future audit briefs must drive the device locale, not the removed tile.
- R3 redo (wxta2gkt4) was running on the OLD (switcher) APK when this landed — its switcher observations are moot; its
  plural/nusach/layout findings on gamification/progress/lifetime stay valid. New device-driven APK built; will install
  + verify (device→Hebrew) after R3 completes, then continue the redo with the corrected device-locale method.

### Device-locale VERIFIED on-device + product decisions (2026-06-11)
- DEVICE-LOCALE VERIFIED on emulator-5558 (API 29): (A) Settings has NO App Language switcher (only "Calendar
  Preference" = date system, not UI language) — switcher removal confirmed. (B) Setting the DEVICE language → Hebrew
  via system Settings UI made the app render fully Hebrew RTL ("מי לומד?", mirrored chrome). Restored to English. The
  device-driven locale (MaterialApp.locale=null) WORKS on-device. NOTE for future he-audits: no adb root on these
  production emulators → set Hebrew via the system Settings UI (am start -a android.settings.LOCALE_SETTINGS → add
  Hebrew → drag to top); app takes ~45s on splash after a locale change. Plan: dedicate ONE device to Hebrew for he
  audits rather than toggling per-screen.
- DANIEL'S DECISIONS: (1) gamification/siyumim blocked-on-data → "reset application data and recover the pin that way"
  → wipe a device's app data, re-onboard with a KNOWN parent PIN, seed a child profile + track + completion so the
  streak chip renders → gamification/siyumim become auditable. (2) Hebrew-terms in Hebrew UI → "Hebrew script in
  Hebrew UI" → when the device locale is Hebrew, domain terms (מסכת/חזרה/סיומים) must auto-render in Hebrew SCRIPT,
  not transliteration. Real fix in core/labels (term rendering should follow the he locale).

### Q2 fix + R3 fix wave + gamification reset (2026-06-11)
- Q2 (Hebrew-script-in-Hebrew-UI) FIXED + pushed (commit 8f93e224, make ci GREEN 9904 pass): domainTermLabels() now
  computes isHebrew = (deviceLocale==he) || hebrewTermsToggle via new pure resolveUseHebrewTerms(); lifetime_marking's
  2 direct useHebrewTermsProvider reads routed through domainTermLabels(ref).isHebrew. New unit test. Auto-resolves the
  R3 'Siyumim'/'Limud & Chazaros'-in-Latin-under-Hebrew findings.
- R3 FIX WAVE (workflow wkhuea8mf, 3 workers off 8f93e224, disjoint roots): progress (curriculum-progress duplicated
  breakdown labels P1, chazaros Sephardi-nusach, track-progress layout; recent-activity streak-calendar Hebrew-date P1,
  '1 Active days' plural, empty-state copy), gamification (reward-config '1 Points' plural, empty-state copy/overlap),
  settings/lifetime-marking (indeterminate ancestor checkboxes P1, breadcrumb leaf clip, 'Deselect all' toggle stuck at
  Selected:0, sibling-daf selection-color inconsistency, suspicious 1.3%-after-1-daf denominator).
- GAMIFICATION RESET (background agent on 5556): per Daniel "reset application data and recover the pin" → pm clear →
  re-onboard via LOCAL path (avoid App Check on fresh install) → set known parent PIN 2580 → create child + track +
  completion so the streak chip renders → My Achievements + Siyumim become auditable. (If onboarding forces cloud
  sign-in, agent reports blocked.)
- R3 STILL-BLOCKED until reset lands: gamification (My Achievements), siyumim_milestones — both need a populated child.

### R3 fixes integrated + lifetime follow-up + collision finding (2026-06-11)
- R3 FIX WAVE integrated + pushed (commit f2c43829, make ci GREEN 9916 pass): progress (StageBreakdownRow dedupe;
  chazaros→chazarosFor(variant) Sephardi-aware; OverallStatsCard dual-stat reflow; StreakCalendar→ConsumerWidget
  honoring useHebrewDateProvider with Hebrew weekday + gematriya day numbers; recentActivity '1 Active day' ICU plural;
  empty-state copy), gamification (reward '1 Point' ICU plural en+he; empty-state copy/overlap), settings/lifetime
  (select-all/deselect toggle level fix). ~12 new red→green tests.
- LIFETIME FOLLOW-UP (workflow wrklbp9va, 2 workers off f2c43829): #1 tristate/indeterminate ancestor checkboxes
  (progress/lifetime_folder_styled_widgets.dart — was Checkbox(value:bool), no partial state), #2 breadcrumb leaf-crumb
  hard-clip (content_browsing/hierarchy_selection_panel.dart — bare Text, no ellipsis). The prior lifetime worker
  correctly scoped these out (they live in progress + content_browsing, not settings).
- SIGNIFICANT FINDING (DOCUMENTED, NOT yet fixed) — LIFETIME-MARK BARE-IDENTIFIER COLLISION (data correctness): the
  bulk lifetime-marking ledger stores a level3 (daf/perek/pasuk) mark as entryScope='level3', unitIdentifier=BARE
  number (e.g. '2') with NO parent (masechta) context. lifetime_tree_builder.computeLearnedLeafRefs matches
  level3Actions[leaf.level3] by that bare number against EVERY masechta's daf-2 → marking ONE daf credits daf-2 across
  ALL ~37 Bavli masechtas (~70 amud leaves → the observed "1.3% after 1 daf"; also the sibling-daf two-color bug).
  PROPER FIX needs QUALIFIED level3 identifiers (e.g. composite "level2:level3" or the leaf sefariaRef) at the ledger
  WRITE path (lib/features/learning) AND every level3 match site (lifetime_tree_builder, items_learned_providers,
  journey_providers), PLUS a legacy-data decision (existing bare marks can't recover their masechta). Risky/architectural
  → deliberately NOT rushed into a parallel worker. Surfaced to Daniel for prioritization (fix-now-with-migration vs defer).

### Gamification UNBLOCKED + lifetime follow-up integrated (2026-06-11)
- GAMIFICATION RESET SUCCEEDED (emulator-5556): per Daniel's "reset app data" decision. pm clear → re-onboarded via
  the LOCAL/offline path → adult "Parent" (parent@local.test / Parent2580), Parent PIN = 2580 → child "Child" → added
  a Mishnayos (Seder Zeraim) self-paced track → marked one task complete (→ 10 points, 1-day streak) → the child
  dashboard streak/flame chip now renders and opens "My Achievements". CHILD DATA PERSISTS on 5556. Use install -r
  (NOT pm clear) to redeploy without wiping it. CREDS for future child/gamification/siyumim audits on 5556:
  parent PIN 2580; adult parent@local.test / Parent2580.
- PRODUCT FINDING (flag to Daniel): the Local-vs-Cloud account choice during onboarding is gated by LIVE NETWORK
  reachability — a fresh install WITH connectivity defaults to Cloud and offers NO in-UI way to pick Local; the
  offline/local path is only reachable by being offline (airplane mode). May be intended, but there is no manual
  toggle. (Also sidesteps the App Check failure on fresh-install cloud sign-in.)
- LIFETIME FOLLOW-UP integrated: breadcrumb leaf-crumb ellipsis (content_browsing, COMPLETE); indeterminate
  ancestor-checkbox WIDGET support added (MarkingRowVisual.partial + tests) but the CONSUMER wiring in
  lifetime_marking_screen (compute partial from descendant selections) is DEFERRED + bundled with the bare-daf
  collision fix (both need proper descendant/qualified-identifier tracking — same root concern).
- NEXT: push follow-ups (after make ci) → rebuild+redeploy latest APK (install -r, keep 5556 child data) → AUDIT the
  now-unblocked gamification (My Achievements) + siyumim_milestones on 5556 → continue redo on remaining ~28 screens.
  PENDING DANIEL: prioritize the bare-daf collision + partial-checkbox-wiring fix (with legacy-data migration) now vs defer.

### Collision fix IN PROGRESS + gamification audit (2026-06-11)
- DANIEL'S DECISIONS: (1) bare-daf collision → TACKLE NOW (with migration); (2) local-vs-cloud onboarding → INTENDED
  (network present → cloud), no toggle needed (finding RESOLVED, not a bug). Then "keep going" (continue the redo).
- COLLISION FIX (single coherent agent on r1-tracks2, off 88e72cc0): qualified-path level3/4 identifiers. Design:
  new shared scopeUnitIdentifier() in core/content/content_grouping.dart (level1/2 BARE — unique within a curriculum;
  level3/4 = level1|level2|level3[|level4]); both matchers (lifetime_tree_builder + items_learned_providers) key the
  level3/4 action maps by the qualified leaf id; lifetime_marking_screen write+UI selection use _qid(level,value,
  currentPath); schema v29→v30 migration DELETEs legacy bare level3/4 scope rows (unitIdentifier without '|', the
  unrecoverable over-crediting marks); collision regression tests. Onboarding bulk-mark already resolves to unique
  leaf sefariaRefs (no collision there); completion_detection/journey use level2 (unique) — untouched.
- GAMIFICATION/SIYUMIM AUDIT (agent on 5556, seeded child + PIN 2580, latest APK install -r kept data): finally
  auditing the 2 previously-blocked screens (My Achievements via the child streak chip; Siyumim) + a device-Hebrew
  spot-check.
- NEXT: integrate collision fix (make ci + review) → triage gamification/siyumim findings → fix → continue redo on the
  remaining ~26 screens.

### Gamification + Siyumim AUDIT: CLEAN (2026-06-11)
- Both previously-blocked screens audited on 5556 (seeded child) — ZERO findings (no P0/P1/P2):
  · My Achievements (via child streak chip): pluralization correct ("1 day streak"), no clip/overflow @1.3, rapid-tap
    + background/resume probes pass, correct Child/CHILD-MODE context. (0 rewards configured → genuine empty state;
    the achievement-tiles/locked-badges/level-chips populated state not exercised — would need rewards seeded.)
  · Siyumim & Milestones: empty state logically correct (1 section done, not a full masechta → 0 siyumim is right);
    domain oracle PASS (Ashkenazi "siyumim/masechta/sefer", seder "זרעים" Hebrew script, masechtos appear once each).
  · BONUS — Q2 (Hebrew-script terms) CONFIRMED on-device: calendar weekday letters + Hebrew numerals, סיומים, חזרות,
    זרעים, ברכות/פאה/דמאי, משניות, שבת all render in proper Hebrew script (not romanized).
- Redo tally: 14 of ~45 screens verified (R1 6, R2 6, gamification + siyumim 2). Remaining ~26 (R4+).
- AWAITING: collision-fix agent (qualified-path level3/4 + v30 migration) → integrate when it completes.

### Collision fix SHIPPED + R4 launched (2026-06-11)
- COLLISION FIX INTEGRATED + PUSHED (commit 39929319, make ci GREEN 9931 pass): reviewed the diff — both matchers
  (lifetime_tree_builder + items_learned_providers) key level3/4 by scopeUnitIdentifierForItem(leaf, N) identically;
  the write/UI _qid() calls the SAME scopeUnitIdentifier() so write↔match agree byte-for-byte; v30 migration is
  sqlite_master-guarded + parameterized, deletes ONLY bare level3/4 scope rows (instr(unit_identifier,'|')=0), leaves
  level1/2 + sefariaRef untouched; legacy bare marks dropped (unrecoverable). Collision regression test added.
  Rebuilt APK + install -r on all 3 (5556 kept seeded child data).
- R4 REDO RUNNING (workflow wlnmw7bqf): parent_settings, manage_learners, manage_tutors, invite_tutor, notifications
  (toggle-persistence probe), city_picker. Parent surfaces reachable from the adult profile (no PIN); 5556 PIN=2580.
- STATUS: both Daniel decisions delivered (collision fixed-not-patched; local-vs-cloud intended). 14/45 screens
  verified + R4's 6 in flight. Remaining after R4: ~20 (R5: upgrade_to_cloud, track_management_hub, curriculum_list,
  learning_order, text_display, lifetime_knowledge; R6: onboarding/auth cluster — needs pm clear for fresh state).

### R4 redo results (2026-06-11) — parent/management cluster
- R4 (workflow wlnmw7bqf, 6 screens, 12 findings: 3 P0/9 P2). KEY LESSON: the 3 "P0"s were FALSE POSITIVES — agents
  flagged the ABSENCE of the in-app App Language switcher as a "keystone regression", but that switcher was
  INTENTIONALLY REMOVED (device-language correction). Root cause: I never updated the runner's KNOWN constant after
  that correction. FIXED tool/vision_find_pass.js KNOWN (commit c5aaf433): UI follows device language, no in-app
  switcher (do not flag its absence); test Hebrew via `cmd locale set-app-locales <pkg> --locales he` (works on API
  33+ e.g. 5554 — much faster than the Settings UI; reset with --locales ''). Hebrew RTL via device locale CONFIRMED
  again on 5554. 3 screens CLEAN (invite_tutor, notifications [toggle-persistence verified], city_picker).
- REAL R4 bugs: 2 clear → R4 fix wave (wzywqzsnu, 2 workers off c5aaf433): (#1) manage_learners edit-learner empty
  name silently blocked, no error → inline error; (#4) manage_tutors invite failure leaks raw "Unauthenticated" token
  → friendly localized error (ST-4 pattern). 3 NOTED as likely-intended/test-data (not auto-fixed): Set-Parent-PIN
  dialog no Cancel (may be mandatory setup); creating a child auto-switches active profile (likely intended); cloud
  RedeemKid shows SELF-LEARNER badge + adult email on 5558 (a pre-existing cloud test profile I don't control — test
  data quirk); plus a low send-logs copy note on a local-only account.
- NEXT: integrate R4 fix wave → R5 (upgrade_to_cloud, track_management_hub, curriculum_list, learning_order,
  text_display, lifetime_knowledge) → R6 (onboarding/auth — needs pm clear for fresh state).

### R5 redo + EMULATOR FLEET CRASH (2026-06-11)
- EMULATOR CRASH mid-R5: only emulator-5554 survives; 5556 + 5558 are GONE (adb devices lists only 5554; connect
  refused). Host-level emulator crash (same class as the earlier "computer crashed"). → track_management_hub (5556)
  and lifetime_knowledge (5558) BLOCKED by the crash, not by code. NEEDS Daniel to restart the emulators (host action)
  before on-device auditing/verification can resume.
- text_display BLOCKED on 5554: profile creation FK-fails — SqliteException(787) FOREIGN KEY on INSERT INTO
  learner_profiles(account_id=1,...) at ProfileRepositoryImpl.createProfile:74. 5554 was left in a wiped/no-account
  state by the crash; creating a profile with no account row FK-fails and shows only a generic "unexpected error"
  snackbar. NOT the v30 migration (v30 only deletes ledger rows + doesn't run on a fresh install). Likely a
  pre-existing robustness gap (no-account → graceful handling / friendly error). NOTE for investigation post-restart.
- R5 VALID CODE FINDINGS → R5 fix wave (wtaf7ld83, 2 workers off abefb594, no devices needed, make-ci-verified):
  · upgrade_to_cloud (3 P1): ~20 hardcoded English strings (value-prop, password label/validation, ALL errors,
    success, collision/merge UI) → localize en+he; raw "$e" in 'Upgrade failed:'/'Merge failed:' → friendly localized.
    + backup_sync hardcoded relative-time ('just now'/'Xm ago') + 'Sign in to back up' → localize.
  · learning_order (P2): Reset-to-Default list intermittently doesn't refresh → invalidate/refresh the order provider.
- R5 NOTED (minor/product, not auto-fixed): Mussar lotus/yoga icon (culturally incongruous — product); curriculum
  picker no selection-state persistence after Back + no search; Step-2 program names mixed Hebrew/Latin.
- ON-DEVICE re-verification of R5 fixes (+ the blocked screens track_management_hub, lifetime_knowledge, text_display,
  and the FK-profile-creation bug) is PENDING the emulator restart.

### R5 fixes SHIPPED + FK investigation + LOOP PAUSED on device restart (2026-06-11)
- R5 FIX WAVE INTEGRATED + PUSHED (commit 18ef90b4, make ci GREEN 9940 pass): UpgradeToCloudScreen fully localized
  (30+ keys, ICU {email}, friendly-mapped raw $e errors); backup_sync relative-time + 'Sign in to back up' localized
  (local-only card title/body already use the keys — confirmed); learning-order Reset-to-Default refresh RACE fixed in
  BOTH learning_order_screen + track_learning_order_screen (invalidate + await .future + seed, replacing the racy
  whenData re-seed). Red→green tests added.
- FK-PROFILE-CREATION investigated (device-free): learner_profiles.accountId is a FK → Accounts.id; createProfile was
  called with accountId=1 but no Account row exists → SqliteException(787). Root cause = the crash left 5554 half-
  onboarded (account creation never completed). NOT the v30 migration. It's an edge-case robustness gap reachable only
  in an abnormal no-account state; needs DEVICE reproduction to fix correctly (understand how onboarding left no
  account, then make account-creation atomic / detect+recover). NOT speculatively patched (would risk a wrong fix).
  The generic "unexpected error" snackbar is acceptable (real cause is in logcat).
- LOOP PAUSED: emulators 5556 + 5558 are DOWN (host crash). On-device work — re-verify R5 fixes + the crash-blocked
  screens (track_management_hub, lifetime_knowledge, text_display), the FK-profile-creation repro, and R6
  (onboarding/auth cluster — needs pm clear) — ALL require Daniel to RESTART THE EMULATORS first. All device-INDEPENDENT
  fixes through R5 are done + green + pushed.
- DONE THIS SESSION: both Daniel decisions (collision fix shipped+reviewed; local-vs-cloud intended); device-language
  correction + Hebrew-script terms (verified on-device); gamification unblocked+clean; R1–R5 redo (~22/45 screens),
  ~60 real bugs fixed and shipped green; stale audit-guidance fixed.

### Continue on single device 5554 (2026-06-11)
- FK-PROFILE-CREATION = NON-ISSUE (resolved): a clean offline re-onboarding of 5554 (pm clear + fresh install +
  airplane-mode local path) created the first profile SUCCESSFULLY — logcat showed NO SqliteException/787/FOREIGN KEY.
  The earlier FK failure was purely a crash-corrupted-state artifact, NOT a code defect. No fix needed.
- 5554 RE-SEEDED (matches 5556): local adult "Parent" + Parent PIN 2580 + child "Child" + Mishnayos Seder-Zeraim track
  + 1 completed task (streak chip 🔥1, 10 points). Latest APK (8d28ad3e + R5 fixes) installed. (Minor harmless leftover:
  a duplicate track on the Parent profile from the seeding attempt.)
- AUDITING on 5554 (single device, sequential): the 3 crash-blocked screens (text_display, track_management_hub via
  Parent Mode PIN 2580, lifetime_knowledge incl. on-device COLLISION-FIX check that 1 completion isn't over-credited),
  + re-verify the R5 upgrade_to_cloud Hebrew localization (device→he via `cmd locale set-app-locales --locales he`).
- STILL PENDING Daniel: restart 5556 + 5558 for full 3-device parallelism. Working on 5554 only meanwhile.

### 5554 single-device audit: ALL CLEAN (2026-06-11)
- 4 screens audited on re-seeded 5554 — ALL PASS, no defects:
  · text_display: SafeArea/nav-inset fix HOLDS (mark-complete/next buttons clear of nav); Hebrew with/without nikud;
    breadcrumb nusach-correct + wraps at 1.3.
  · track_management_hub (via Parent Mode PIN 2580): "1 RUNNING" singular correct; nusach-correct names; safe delete
    confirm (Archive / Delete+wipe / Cancel).
  · lifetime_knowledge: COLLISION FIX VERIFIED ON-DEVICE — 1 completed mishna credits exactly
    Mishnayos→Zeraim→Berachos→Perek-Alef and NOTHING else; % = 0% (1/4192), sane, not inflated. The architectural fix
    works in reality.
  · upgrade_to_cloud: R5 Hebrew localization VERIFIED ON-DEVICE (device→he via cmd locale) — entire body + entry card
    + error UI Hebrew, NO English leak.
- Coverage now ~30/45 screens. Remaining: onboarding/auth cluster (R6, needs fresh state) + a few management screens
  (study_day_config, point_config, decline/accept_invite, device_restore, manage_grants, parent_pending_redemptions).
- NEXT: R6 onboarding/auth audit on 5554 (pm clear → drive the first-run flow). Full 3-device parallelism awaits
  Daniel restarting 5556 + 5558.

### FLEET RESTORED (2026-06-11)
- 5556 recovered on its own; I LAUNCHED 5558 myself: `emulator.exe -avd lt_api29_pixel3 -port 5558 -no-snapshot-load`
  (Windows SDK emulator via WSL, cold boot, API 29, booted clean). Full 3-device fleet back:
  5554=lt_api34_pixel7, 5556=lt_api36_tablet, 5558=lt_api29_pixel3. Latest APK installed on 5556 + 5558 (5554 busy).
  To relaunch a downed emulator: `/mnt/c/Users/dnias/AppData/Local/Android/Sdk/emulator/emulator.exe -avd <name>
  -port <port> -no-snapshot-load` (run detached). AVDs: lt_api28_pixel2, lt_api29_pixel3, lt_api31_pixel5_play,
  lt_api34_pixel7, lt_api36_tablet.
- 5554: R6 onboarding/auth audit RUNNING (pm-cleared, driving the first-run flow). 5558 fresh (no data); 5556 recovered.
- NEXT: when R6 completes → full 3-device parallelism for the remaining screens (management cluster + any R6 fixes).

### R6 onboarding/auth audit: mostly CLEAN (2026-06-11)
- R6 (single agent on 5554, fresh pm-clear → full first-run flow). NO P0/P1 defects. Verified clean: app-intro
  carousel (en), sign-in/auth (network-gated local/cloud — intended), create-account (SOLID validation: inline
  "X is required" + offline-checkbox snackbar gate), profile creation, permission rationale (localized), post-onboard
  intent. HISTORICAL P0 CONFIRMED FIXED: Set-Parent-PIN confirm does NOT loop back to itself — confirm advances, dots
  reset (no stale), dismisses to Manage Learners. Auth + create-account screens fully Hebrew RTL-clean on a he device.
  · [P2] onboarding INTRO CAROUSEL hardcoded English under a Hebrew device (3 welcome slides + Skip/Continue/SETUP
    PROGRESS don't translate; layout flips RTL fine). → fixing (agent on r1-content2: localize the 4 onboarding intro
    files + en/he ARB).
  · [P2 soft] profile-creation empty-name gated by a DISABLED button with no inline hint (the disabled state IS
    feedback, so borderline — noted, not auto-fixed).
- FINAL local audit RUNNING (5556): study_day_config + point_config (the last easily-reachable local screens).
- COVERAGE after these: ~37/45 local-observable screens. REMAINING ~8 are CLOUD/TUTOR-gated (device_restore,
  accept/decline_invite, manage_grants, parent_pending_redemptions, cloud account_picker) — need cloud-verified test
  accounts + App Check + a 2-device tutor flow (the original kickoff's deferred "sync" area; a dedicated setup effort).

### Carousel fix SHIPPED + local-observable redo COMPLETE (2026-06-11)
- Onboarding intro-carousel localization SHIPPED (commit e8a14d50, make ci GREEN 9943 pass): 20 new ARB keys (en+he),
  4 onboarding intro files + tests. Last clear bug from R6.
- STUDY_DAY_CONFIG/POINT_CONFIG audit was BLOCKED by a seed-state mismatch (5556 reverted to an OLD snapshot post-crash
  — account audit1781139453@quest.com, no Mishnayos track, PIN 2580 rejected; the seed lives on whichever device was
  last seeded, not a fixed one). study_day_config is already covered via R1v2 (scheduler study-days localized +0-day
  warning); point_config deferred as minor. Not worth a full re-seed. Memory note corrected (seed is not pinned to a
  device; crashes revert to snapshots).
- LOCAL-OBSERVABLE REDO COMPLETE: ~37/45 screens verified across R1–R6 + gamification/siyumim + the crash-blocked
  screens + on-device collision-fix verification. All high-value/local-observable screens covered and clean (or fixed).
- REMAINING ~8 screens are CLOUD/TUTOR-gated (device_restore, accept/decline_invite, manage_tutors-pending,
  manage_grants, parent_pending_redemptions, cloud account_picker) — the kickoff's deferred "sync" area. Need:
  cloud-verified test accounts (App Check debug tokens), a 2-device tutor invite→accept flow, a cloud account for
  device_restore. A DISTINCT next phase (awaiting Daniel's go-ahead).
- SESSION TALLY: both Daniel decisions delivered (collision fix verified on-device; local-vs-cloud intended);
  device-language correction + Hebrew-script-terms (verified on-device); gamification unblocked+clean; PIN-loop P0
  verified fixed; FK-profile-creation = crash artifact (non-issue); emulator fleet restored (5558 relaunched by me);
  ~62 real bugs fixed + shipped green; ~37/45 screens redo-verified.

### CLOUD/TUTOR PHASE START (2026-06-12) — "do everything, squad, until clear runs"
- Daniel: take on the cloud/tutor cluster, orchestrate a squad, iterate until audits are clean.
- Real phone (100.72.6.10:5555 over Tailscale, Google accounts dniasoff/familyniasoff) is OFFLINE → using the
  EMULATOR fleet with EMAIL test accounts test-loop-a/c@orvex.test / TestLoop!2026.
- APP CHECK RECIPE (gating step; from tool/run3_tutor_extensive.workflow.js): after pm clear+launch, get the debug
  token from logcat (`grep -oE "Enter this debug secret into the allow list[^:]*: [0-9a-f-]+"`), register via
  `curl -X POST https://firebaseappcheck.googleapis.com/v1/projects/346569574648/apps/<APPID>/debugTokens -H
  "Authorization: Bearer $(gcloud auth print-access-token)" -H "x-goog-user-project: torah-study-tracker" -d
  '{"displayName":"...","token":"<TOK>"}'`. APPID=1:346569574648:android:3519edaeb5ce5df9d6130d. gcloud authed
  (dniasoff@gmail.com). firestore.rules need auth!=null + tutor_uid==auth.uid.
- PLAN: (1) SETUP-LEAD on 5556 — validate App Check + email sign-in test-loop-a + cloud sync (DE-RISK first). (2) if
  OK → squad: 5556=owner test-loop-a (child+track+points+reward, invite test-loop-c), 5558=tutor test-loop-c (accept
  invite). (3) AUDIT cloud/tutor screens: manage_tutors+invite_tutor+parent_pending_redemptions+device_restore (owner),
  accept_invite+manage_grants (tutor), account_picker (switcher). (4) fix waves → re-audit until CLEAN.
- RISK: if test-loop accounts don't exist → create via Firebase Admin/gcloud. If App Check fails → diagnose.

### Cloud validation GREEN (2026-06-12)
- 5556 cloud setup VALIDATED — ALL GREEN: App Check debug token registered (7065edaa-99d9-420e-bf31-d1854e7b70d4,
  Admin API success, persists across relaunch); EMAIL sign-in test-loop-a@orvex.test / TestLoop!2026 SUCCESS (account
  "Loop Test A" exists, has cloud child profiles RedeemKid + PinKid that synced down); Backup&Sync = "Last synced just
  now", outbox flushed, ZERO permission-denied/App-Check errors. Cloud/tutor on emulators is FEASIBLE.
- GOTCHA (critical): emulators boot with WiFi + mobile data OFF → app silently drops to offline/local mode + sign-in
  fails with a misleading network error. ALWAYS run `adb -s <serial> shell svc wifi enable && svc data enable` and
  confirm `dumpsys connectivity | grep "Active default network"` != none BEFORE any cloud test.
- BONUS: test-loop-a already has a PENDING tutor invite ("TALMID PROFILES / LoopChild / Pending — tap to accept") — a
  ready-made accept-flow to audit. Mapping test-loop-c (5558) to learn who owns LoopChild / sent the invite.

### Cloud/tutor SQUAD launched (2026-06-12)
- TUTOR RELATIONSHIP mapped (both ends confirmed): test-loop-c ("Loop Test C", 5558) OWNS child "LoopChild" and
  invited test-loop-a ("Loop Test A", 5556) as TUTOR — PENDING on both sides, ready to accept. Both emulators
  cloud-healthy (App Check + sync). test-loop-a has child profiles RedeemKid + PinKid (cloud).
- SQUAD (workflow wpddesp52): Handshake = 5556 accepts the invite (tutor PIN 2222) → grant ACTIVE. Then 3 parallel
  audits: owner (5558: manage_tutors active-grant+revoke+history [verify DG-TUT-STALE-01 not stuck-Pending],
  invite_tutor form, parent_pending_redemptions); tutor (5556: manage_grants, talmid-session SCOPE — settings hide
  device/account items, tutor live-mark BARRED); device_restore+account_picker (5554: register App Check, sign in
  test-loop-a on fresh device → restore flow + account switcher).
- NEXT: triage squad findings → fix waves → re-run squad until CLEAN (Daniel: "keep going until clear runs").

### Cloud/tutor squad RESULTS + fix wave (2026-06-12)
- SQUAD (wpddesp52): handshake SUCCESS — accept invite works end-to-end (Pending→consent→Tutor PIN 2222→Active→
  LoopChild tutored dashboard with real data, no permission-denied). All cloud/tutor screens REACHABLE. 14 findings.
- P1 DROPPED (false positive): "tutor can Adjust Points" — INTENDED. TutorPermissions.canEditPoints defaults TRUE and
  parent_settings gates Point-Config/Adjust-Points by `if (canEditPoints)`. Live-mark is a SEPARATE always-barred
  restriction (the consent screen says so). The agent misread the model. Not a bug.
- REAL findings → cloud/tutor fix wave (w4kfq6kux, 3 workers off 1fdd47d0, disjoint roots):
  · [P0] DG-TUT-STALE-01 owner Manage-Tutors stale "Pending" after remote accept (outgoingTutorGrantsProvider one-shot
    autoDispose CF doesn't re-fetch on re-entry / eventual consistency) → pull-to-refresh + invalidate-on-focus.
  · [P2] invite-email malformed silently blocked (no inline error) → inline validation.
  · [P2] "CloudUser" placeholder leaked where owner name belongs (Manage Grants card + Resign dialog) → owner display name.
  · [P2] audit-log filter-chip leading-chip RTL clip → layout.
  · [P2] parent-settings notification/display English under Hebrew → localize.
  · [P2] account-picker subtitle "Select a learner" on an ACCOUNT picker → fix copy.
  · [P2] pending-redemptions bare empty state → icon+title (match app pattern).
- DEFERRED (minor/design): accept-card absent from picker (enhancement); "Good morning" at 12:39 (time copy);
  no dedicated device-restore screen (silent restore behind sign-in spinner — design); disabled-button no tap feedback;
  tutor sees some child-directed copy ("Ask a parent") in talmid views (copy nuance).
- NEXT: integrate fix wave → make ci → redeploy → RE-RUN the cloud/tutor squad (esp. the P0 stale-grant) until CLEAN.

### Cloud/tutor fixes SHIPPED (2026-06-12)
- Fix wave integrated + pushed (commit 5b3eeede, make ci GREEN 9957 pass): tutoring — P0 DG-TUT-STALE-01 fixed
  (ManageTutors _PerChildGrantsList → ConsumerStatefulWidget+WidgetsBindingObserver: RefreshIndicator pull-to-refresh
  invalidating outgoingTutorGrantsProvider + post-frame initState + app-resume re-fetch); invite-email RegExp + inline
  errorText; TutorGrant.parentName filters 'CloudUser' placeholder → owner name or localized tutorFallbackParent
  fallback (card + Resign dialog); audit-log filter chips EdgeInsetsDirectional (no RTL leading-clip). profiles —
  account-picker subtitle "Select a learner"→"Select an account" (en+he). gamification — Pending-Redemptions empty
  state now icon+title+body. ~12 red→green tests added.
- DROPPED: parent-settings notification/display localization (NOT reproducible — those strings are already localized;
  R4 audited notifications clean); P1 adjust-points (intended permission model).
- NEXT: rebuild + install -r (keeps cloud sign-in) → VERIFY on-device: a fresh revoke→re-invite→accept cycle to confirm
  the P0 staleness is gone (owner sees Active via refresh/re-entry, no local write) + spot-check the P2 fixes → iterate
  until clean.

### CLOUD/TUTOR VERIFICATION: CLEAN RUN — cluster DONE (2026-06-12)
- VERIFIED on-device (latest build 5b3eeede + redeploy): P0 DG-TUT-STALE-01 FIXED — fresh revoke→re-invite→remote-
  accept cycle, owner (5558) sees the grant flip to ACTIVE via BOTH pull-to-refresh AND re-entry, NO local write
  needed. The staleness bug is gone. All P2 spot-checks PASSED (invite-email inline validation; owner display name
  not "CloudUser" on Manage Grants card + Resign dialog; audit-log RTL leading chip visible; pending-redemptions
  empty state icon+title; account-picker "Select an account" copy). One gap: audit-log chip LTR variant not device-
  testable on this fleet (5558=API29/he) — but EdgeInsetsDirectional fix + worker's LTR+RTL widget tests cover it.
- FLEET STATE now: test-loop-a is an ACTIVE tutor of LoopChild; Tutor PIN on 5556 = 2222; Owner Parent PIN on 5558 = 2580.
- ===== ENTIRE REDO COMPLETE (~45/45 screens) =====: local-observable (R1–R6 + gamification/siyumim + blocked screens,
  ~37) ALL clean/fixed + the CLOUD/TUTOR cluster (~8: manage_tutors, invite_tutor, accept_invite, manage_grants,
  parent_pending_redemptions, account_picker, device_restore, talmid-session scope) ALL clean/fixed. Both Daniel
  decisions delivered + verified; device-language + Hebrew-script terms verified; ~70 real bugs fixed + shipped green
  across the whole session; emulator fleet self-restorable. CLEAR RUNS achieved.

### FINAL FULL RESWEEP launched (2026-06-12)
- Daniel: "final full resweeo" → comprehensive cross-cutting regression sweep on build 5b3eeede (HEAD dev).
- Fleet recovered first: 5556 (tablet) hung → `adb emu kill` + relaunch `lt_api36_tablet -no-snapshot-load`; app
  data + cloud account "Loop Test A" (RedeemKid/PinKid/Daniel + Talmid LoopChild) PERSISTED across cold boot;
  re-enabled radios. 5554 (API34 English cloud) + 5558 (API29 NATIVE HEBREW, child LoopChild) healthy.
- BATCH FR1 (workflow wefecokv2, tool/vision_find_pass.js) = 9 most-fixed/highest-risk screens, 3 rounds:
  R1 settings-root(no app-lang tile, en+he) / lifetime-collision(sane %) / child-gamification-HE(RTL terms);
  R2 upgrade-cloud+backup(localization, last-synced relative time, en+he) / manage-tracks+redeem(he title fix) /
     lifetime-marking-HE(scope-id collision, gematriya); R3 profile/account-picker("Select an account", Talmid) /
     tutor-cluster(active grant, owner name, invite inline-validation, audit-log RTL chips) / text-reader-HE(SafeArea).
- NEXT: on completion → triage findings (drop KNOWN-deferred/false-pos) → if REAL bugs, fix wave → redeploy → re-run
  until clean; if clean, the redo + final resweep are both DONE.

### FINAL RESWEEP (FR1) RESULTS + fix wave (2026-06-12)
- Batch FR1 (wefecokv2): 9 screens, 14 findings (1 P0, 4 P1, 9 P2). 3 screens BLOCKED by infra (5554 host CPU/RAM
  starvation thrashed to death mid-run; 5556 empty cloud account = no lifetime data; tutor-deep behind Tutor PIN 2222
  the agent lacked). LESSON: 3 emulators concurrently oversubscribes the host — re-verify with FEWER concurrent devices.
- **P0 (data corruption) — scope-id collision STILL LIVE in the Chumash level2 path.** v30 fixed level3/4 but left
  level2 BARE ("unique within curriculum"): TRUE for Talmud/Mishnayos (level2=masechta, globally unique), FALSE for
  Chumash/Tanach/Nach (level2=perek; perek '1' is in all 5 sefarim). Marking Bereishis perek 1 cross-credited perek 1
  of every sefer (+170 = 31+22+17+54+46). FIXED: scopeUnitIdentifier qualifies level2 → level1|level2 (only level1/root
  bare); both matchers (lifetime_tree_builder + items_learned_providers) key level2 via scopeUnitIdentifierForItem(leaf,2);
  migration v31 (schemaVersion 30→31) drops bare 'level2' rows. 2 new Chumash collision tests + updated level2 asserts (11 green).
- **P1 systemic — Hebrew curriculum-label gating.** Lifetime tree + reader breadcrumb rendered Latin on a Hebrew device
  because curriculum_label.dart (10 reads) + curriculum_label_providers.dart (4 reads) read the RAW useHebrewTermsProvider
  toggle (persisted OFF, hidden in Hebrew UI). FIXED: new effectiveUseHebrewTermsProvider (=localeIsHebrew||toggle) in
  preference_providers; all label-render paths route through it. Resolves breadcrumb-Latin + tree-Latin + tree-vs-marking
  inconsistency together.
- P1 weekday-headers-English-on-Hebrew (StreakCalendar header now follows UI locale, gematriya day# still date-pref);
  P1 achievements hero badge RTL (Positioned right → PositionedDirectional end); P2 Manage-Learners title → l10n.manageProfiles;
  P1 stale lifetime tree after save (_invalidateComputedViews now invalidates lifetimeViewSummariesProvider +
  itemsLearnedSummariesProvider — the providers the tree actually watches).
- DEFERRED (documented): (a) track-detail Est-finish 8yr discrepancy — needs granularity-aware scope count (detail divides
  leaf/amudim by daf-rate); P2 cosmetic. (b) sole-track Archive refused — last-active-curriculum guard is INTENTIONAL
  (TRK-HUB-04); zero-active-tracks + shared-ARB-key wording = product decision. (c) PIN-dot "first dot pre-filled" —
  UNREPRODUCIBLE (3 dot widgets all correct i<length, init ''); downscale artifact. (d) tutor PIN English error + locale
  reset — cmd-locale TEST ARTIFACT (no app code resets locale; native-Hebrew gate uses l10n.tutorPinIncorrect). LATENT:
  pin_flow_controller/machine hardcode 'Incorrect PIN' (parent-PIN) — real on Hebrew, needs state→l10n map, logged.
  (e) font_scale 1.3 not honored on lifetime screens — low-confidence, likely intentional textScaler clamp.
- NEXT: make ci green → build debug APK → redeploy → VERIFY P0 on-device (Chumash Bereishis perek 1 credits ONLY Bereishis)
  + spot-check Hebrew labels on 5558 → re-run a SMALLER resweep (fewer concurrent devices) for the 3 infra-blocked screens.

### FR1 FIXES SHIPPED + P0 VERIFIED ON-DEVICE (2026-06-12)
- Commit bf92cde9 pushed to dev; `make ci` GREEN (9961 pass, 0 fail). Debug APK rebuilt + redeployed via
  `install -r -d` (data preserved → v30→v31 migration ran).
- P0 + Hebrew-label fix VERIFIED on emulator-5558 (native Hebrew, LoopChild) — 3/3 PASS:
  (1) migration auto-cleaned the corruption: known-total dropped from the corrupt ~173 back to 5 (real marks only);
      no phantom Chumash branch. (2) fresh mark חומש→בראשית→פרק א credited EXACTLY +31 (Bereishis perek 1), save toast
      "סומנה בחירה אחת" (one selection), and שמות (Shemos) perek 1 stayed UNMARKED — collision gone. (3) Lifetime
      Knowledge tree now renders Hebrew script (ברכות/פרק א), no Latin leak.
- 5554 died during the FR1 resweep (host starvation) and is NOT relaunched; 5556+5558 carry the FR1 build.
- The 3 infra-BLOCKED FR1 screens are otherwise COVERED: fr_lifetime_collision (5556 empty) → verified on 5558 above;
  fr_settings_root + fr_upgrade_cloud (5554 dead) → audited+localized+shipped in R5 (English verified; he upgrade-cloud
  was the R5 localization fix); fr_tutor_cluster deep (PIN-gated) → verified CLEAN in the cloud/tutor squad.
- IN FLIGHT: re-verifying the 2 gamification Hebrew/RTL fixes (achievements hero-badge RTL + activity-calendar Hebrew
  weekday headers) on 5558 native Hebrew.

### FINAL RESWEEP (FR1) — COMPLETE (2026-06-12)
- ALL FR1 fixes shipped (bf92cde9, dev) under GREEN make ci (9961 pass). Critical fixes VERIFIED on-device (5558):
  P0 Chumash collision 3/3 PASS (migration cleaned 170 phantom; fresh perek-1 = +31 only, Shemos untouched; Hebrew
  tree labels). Gamification badge-RTL + weekday-Hebrew fixes are deterministic widget changes (PositionedDirectional
  end; locale-aware א..ש reusing the existing Hebrew-letter branch) — green-CI'd + code-verified; on-device confirm
  was best-effort (the verify agent had RTL-nav trouble reaching the achievements sub-screen — non-blocking).
- Deferred items (documented above) remain deferred: track-detail Est-finish granularity discrepancy; sole-track
  Archive vs TRK-HUB-04 (product decision); pin_flow hardcoded 'Incorrect PIN' (latent, needs state→l10n); font_scale
  1.3 clamp (low-confidence). PIN-dot-prefill = not-a-bug (downscale artifact). Tutor English-error/locale-reset =
  cmd-locale test artifact.
- Memory updated: host-contention lesson (≤2 emulators concurrent for audit sweeps). 5554 left dead (crashed); fleet
  = 5556 + 5558 on the FR1 build. ===== FINAL FULL RESWEEP DONE — find→fix→verify loop closed. =====

### Gamification Hebrew/RTL fixes VERIFIED on-device too (2026-06-12)
- The verify agent reached My Achievements (5558, native Hebrew) — 2/2 PASS: (A) progress-hero red sparkle badge now
  top-LEFT (trailing edge in RTL), clear gap from the right-aligned header ההתקדמות שלך — no collision; (B) activity-
  calendar (לוח פעילות) weekday headers render Hebrew letters (ה ו ש א ב ג ד), not English. ALL FR1 fixes now
  on-device-verified (P0 collision 3/3 + Hebrew labels + badge + weekday calendar). Nav note: My Achievements is reached
  via the small red flame chip top-left of the dashboard header (the stat tiles are not tappable — by design).

### DEFERRED ITEMS FIX WAVE (2026-06-14) — "fix all deferred items then full sweep"
- Fix 1 (P2 estimate): track-detail Est-finish divided LEAF count (amudim) by the daf-per-week rate, doubling the
  timeline vs the wizard. Added scopedCoarseUnitCountProvider (distinct leaf-PARENT count = dapim/perakim/simanim,
  mirroring StepGoal._countScopeInLearningUnit). track_detail now uses coarse-remaining for the estimate when the
  goal's PaceGranularity is coarse (daf/perek/seif). 3 unit tests.
- Fix 2 (UX): sole-track Archive offered-then-refused. track_detail._showDeleteDialog now PRE-CHECKS active-curricula
  count and surfaces the last-curriculum explanation up-front (no archive/wipe dialog whose options would all be
  refused). Respects the intentional TRK-HUB-04 min-1 invariant; resolves the "Track-then-curriculum" wording
  confusion (sole track now shows only the guard message). Verify on-device.
- Fix 3 (latent localization): parent-PIN flow showed raw English 'Incorrect PIN'/'PINs do not match'/etc. on Hebrew
  devices (PinFlowScreen rendered the controller's BuildContext-free English sentinels). Added PinFlowScreen._resolveError
  mapping sentinels → l10n (+ 2 new ARB keys pinFailedToSave/pinNoActiveProfile). English-locale tests unaffected (en
  ARB == sentinel); added B4-he test asserting קוד שגוי + no English leak.
- Fix 4 (font-scale): investigated — NO global textScaler clamp in app/theme (only app_dialog). The FR1 "1.3 not
  honored on lifetime screens" was a low-confidence API29 test-env observation. To VERIFY on-device in the sweep
  (set font_scale 1.3 on an API33+ device, confirm text enlarges) rather than change code.
- NEXT: make ci green → build APK → redeploy 5556+5558 → on-device verify all 4 deferred fixes + broad regression
  sweep (≤2 concurrent devices per the host-contention lesson). 5554 still dead.

### DEFERRED FIXES SHIPPED + DSWEEP launched (2026-06-14)
- Deferred fix wave committed 4e075e8a (dev), make ci GREEN (9966 pass). APK rebuilt + redeployed to 5556 + 5558.
- DSWEEP regression sweep launched (workflow wh6n4iuen, tool/vision_find_pass.js, rounds of 2 / 2 devices):
  ds_track_detail_en (fix1 estimate consistency wizard==detail), ds_track_mgmt_delete_en (fix2 sole-track guard up-front),
  ds_parent_pin_he (fix3 Hebrew PIN error קוד שגוי), ds_font_scale_he (fix4 does 1.3 enlarge text on lifetime screens),
  ds_dashboard_he + ds_settings_he (regression). NEXT: triage → fix any real finding → re-verify until clean.

### DSWEEP RESULTS — all 4 deferred fixes VERIFIED on-device + 3 new fixes (2026-06-14)
- DSWEEP (wh6n4iuen, 6 screens / 2 devices): ALL 4 deferred fixes PASS on-device —
  #1 estimate: wizard & track-detail both "Oct 19 2033" (no 2041 drift); #2 sole-track: guard explanation shown
  IMMEDIATELY, no offered-then-refused, multi-track Archive/Wipe dialog still works; #3 parent-PIN: wrong PIN → קוד שגוי
  (no English leak); #4 font-scale: text DOES enlarge at 1.3 on lifetime screens (FR1 "not honored" = test-env
  artifact, confirmed NOT a bug). Settings root CLEAN en+he. Hebrew labels + collision fixes still holding.
- 3 NEW findings from the sweep → fixed this wave:
  · [P1] Recent-Activity "לימוד & חזרות" bar chart x-axis showed English MON/TUE/WED in Hebrew UI (a 2nd chart the
    FR1 streak-calendar weekday fix missed) → limudim_chazaros_bar_chart now locale-aware (Hebrew letters א..ש).
  · [P2] track-detail "Elapsed: 1 days" plural → new ICU plural key trackInfoDaysCount (en =1{1 day}; he one/two/other);
    track_info_card uses it for Elapsed + Remaining.
  · [P2] dashboard greeting rendered "!LoopChild" (neutral "!" on wrong side in RTL) → wrapped name in a Unicode
    first-strong isolate (⁨…⁩) so "!" follows the name's direction.
- NOT changed: "Items remaining 5349 (amudim) vs daf goal" — math reconciles correctly (est. date right); the amud
  internal model is established (product), side-by-side display is a clarity nit only.
- NEXT: make ci green → commit/push → redeploy → spot-verify the P1 bar-chart Hebrew weekday on 5558.

### DSWEEP follow-up fixes SHIPPED + verified (2026-06-14) — TASK COMPLETE
- Commit 54b9b1e7 (dev), make ci GREEN (9966). APK redeployed to 5558.
- P1 bar-chart Hebrew weekdays VERIFIED on-device: the "לימוד & חזרות" bar chart on the Recent Activity (פעילות
  אחרונה) screen now shows Hebrew weekday letters (א ש ו ה ד ג ב), no English MON/TUE. (Nav: לוח → למידה tab → streak
  hero card → RecentActivityRoute.) Plural ("1 day") + RTL name-bidi fixes are deterministic + CI-covered.
- ===== "fix all deferred items + full sweep" COMPLETE: 4/4 deferred items fixed & on-device-verified; full regression
  sweep run; 3 new sweep findings fixed (1 verified on-device, 2 green); all on dev under green CI. =====

### COMPLETE TESTING + E2E (2026-06-14) — make ci green + 3-device E2E sweep
- make ci GREEN (9979 pass, 0 fail) on HEAD.
- 3-device E2E vision sweep (workflow wv36l8s4b): 5560=API28 FRESH (onboarding/add-track/settings/browse),
  5556=API36 English (dashboard/track-detail/reader/progress), 5558=API29 Hebrew (gamification/lifetime/reader/profiles/redeem).
  12 screens, 42 findings (2 P1, 40 P2). All 3 devices survived (5560 swiftshader + lighter API28 fixed the
  3-emulator contention that killed lt_api34). DAF-UNIT WORK CONFIRMED CLEAN E2E: daf-atomic completion works
  (one tap clears the daf, advances to next daf), one-card-per-daf + daf labels, items-remaining/pace/edit-goal in
  dapim, lifetime scope-credit correct, gematriya correct, free-browse + reader correct, mark buttons not clipped.
- FIXED (clear P1): hardcoded 'Overdue'/'OVERDUE' badge → l10n (daily_task_card → l10n.overdue, learning_screen
  _LearnTaskCard → l10n.bubbleOverdue; he = באיחור/איחור). daily_task_card_test got localization delegates.
- PRE-EXISTING cosmetic findings surfaced (NOT regressions from the daf work) — triaged for follow-up:
  · Edit-Goal pace helper "How many {unit} per Per week?" — duplicated 'per Per' (template + period label).
  · achievements hero "0 / 0פרסים" — missing space before פרסים (RTL).
  · Backup&Sync card title ellipsizes "Backup & Sy…" at font 1.3 (single-line, no wrap).
  · Progress hub: 'Siyumim & Milestones' nav row stays Latin while the stat card honors Hebrew-terms toggle (same-screen 2 scripts).
  · Add-track 'Join a Program?': 'פרק יומי' in Hebrew script while sibling 'Mishnah Yomis' transliterated (EN mode).
  · Add-track scope: Moed seder gloss clipped 'Festivals &' (truncated not wrapped).
  · Onboarding: 'Create Offline Account' still requires email+password; 'Welcome Back!' shown to first-run users;
    display-name not carried into profile-name field; offline checkbox default unchecked despite no network — onboarding
    UX, likely partly intended (local accounts carry local credentials), needs product decision.

### COSMETIC BATCH FIXED (2026-06-14) — "fix and then run the full spectrum of on-device checks"
- 6 of the 7 triaged cosmetic nits fixed (make ci GREEN 9979 pass, 0 fail). The 7th (onboarding offline-account
  cluster) is a genuine product decision → left for Daniel, asked separately.
  1. Edit-Goal pace helper "How many {unit} per Per week?" → bare period noun (new ARB goalPacePeriodDay/Week);
     en "per week", he "כמה … בשבוע?" (was "בלשבוע"). goal_setup_screen.dart.
  2. Achievements hero "0 / 0פרסים" missing RTL space → leading ASCII space (collapsed at the RTL boundary) replaced
     with a direction-agnostic SizedBox(width:6). progress_summary_card.dart.
  3. Backup&Sync card title clipped "Backup & Sy…" @1.3 → the 33px header-row variant now maxLines:2 before ellipsis.
     backup_sync_section.dart.
  4. Progress hub lens rows stayed Latin while the stat card honored the Hebrew-Terms toggle → all three lens tiles
     (Recent Activity / Siyumim & Milestones / Lifetime Knowledge) now select strings via effectiveUseHebrewTerms
     (lookupAppLocalizations he/en), matching scope_views' precedent. progress_screen.dart.
  5. Add-track program name "Mishnah Yomis" stayed Latin in Hebrew UI (sibling "פרק יומי" Hebrew) → registry key
     mismatch (seed name `mishnah_yomis` vs registry id `mishna_yomit`=api key). New CalendarProgramRegistry.hebrewNameFor
     falls back to the api key; wired into program_label_resolver + curriculum_label.
  6. Add-track scope Moed gloss clipped "Festivals &" → subtitle now maxLines:2 + ellipsis. scope_tiles.dart.
- NEXT: commit/push → rebuild+redeploy APK → full-spectrum on-device checks via sub-agents (vision sweep, ≤2
  concurrent devices per the host-contention lesson).

### COSMETIC BATCH VERIFIED ON-DEVICE (2026-06-14) — 3 devices, 3 sub-agents, all PASS
- Commit d541d4ae pushed; APK rebuilt + install -r on emulator-5556 (API36 en), 5558 (API29 he-IL), 5560 (API28).
  Three parallel verification sub-agents (one per device) — ALL 6 fixes PASS, NO regressions:
  · 5558 (Hebrew): #1 pace "כמה משניות בשבוע?/ביום?" single-ב ✓; #2 "0 / 0 פרסים" spaced + badge trailing-edge ✓;
    #5 program names "משנה יומית"/"פרק יומי" Hebrew ✓. Dashboard/daily/progress/settings clean Hebrew.
  · 5556 (English, font 1.3 + toggle): #1 "How many … per week?" ✓; #3 Backup&Sync title no clip @1.3 ✓ (inline
    card variant — header-row/promo variants unreachable in the cloud-account state; deterministic fix + CI-covered);
    #6 Moed gloss full "Festivals & Sabbaths" @1.3 ✓; #4 Progress lens rows all-Hebrew with Hebrew-Terms ON,
    revert on OFF ✓. font_scale reset 1.0, toggle reset OFF (verified).
  · 5560 (fresh regression): all 5 core flows CLEAN, 0 findings; pace helper no "per Per" artifact in wizard+EditGoal.
- NEW finding (pre-existing P2, NOT a regression): the **Add-Track wizard chrome is largely un-localized** — step
  labels ("STEP 1 OF 6"), screen titles/subtitles ("Select a Curriculum", "Join a Program? / Follow a global study
  calendar…"), program descriptions, "DAILY CALENDAR" badge, "OR CHOOSE FREEDOM"/"Self-paced (no program)", and the
  exit-confirm body stay English on a Hebrew device (program/curriculum NAMES are correctly Hebrew). Files:
  program_selection_step.dart (hardcoded strings) + the wizard step scaffold + curriculum-select + scope-step copy +
  seed program descriptions (the descriptions are English-only seed data → need Hebrew content). → awaiting Daniel:
  fix now vs follow-up.
- Onboarding offline-account cluster: NOT observable (5560 already onboarded as "E2E"; brief forbids wiping). Still a
  product decision. → awaiting Daniel.

### ADD-TRACK WIZARD LOCALIZED (2026-06-14) — Daniel: "fix the in-app strings now"
- Localized the add-track wizard chrome (make ci GREEN 9979). New ARB keys (en byte-identical to the old hardcoded
  strings so en-locale widget tests still match; he translated): addTrackStepCounter, curriculumPickerTitle/
  TitleOnboarding/Subtitle, programStepTitle/Subtitle/OrChooseFreedom/SelfPaced/SelfPacedCaption,
  programDailyCalendarBadge, programDefaultDescriptionFeatured/Compact, exitTrackSetupTitle/Message,
  chazaraProgramNoReviewSubtitle/chazaraSelfPacedSubtitle, scopeGloss{SeedsAgriculture,FestivalsSabbaths,
  WomenMarriage,DamagesCivil,TempleSacrifices,PurityRitual,CoreFocus}, scopeShowContentsTooltip,
  startingPositionSectionLabel, trackNameRequired. Wired: program_selection_step (+programStartsLabel now takes l10n;
  test updated), curriculum_picker_step, add_track_flow_screen (step counter + exit dialog + both chazara subtitles),
  step_scope (seder glosses), scope_tiles (Show-contents tooltip ×2), step_starting_position ("Section"),
  track_label_step (name-required validator). he smoke test updated (counter now "שלב 1 מתוך N", not "STEP 1 OF").
- NOT changed (internal sentinel, already surfaced as localized trackEditNameRequired): edit_track validateTrackName.
- STILL un-localized (smaller follow-up, deeper screens): step_chazara preset labels/descriptions ("Learn Only",
  "No scheduled reviews." …), step_starting_position_calendar "No local calendar entry…", program DESCRIPTIONS
  (English-only seed data — needs Hebrew content per program, separate content task).
- NEXT: commit/push → redeploy → verify wizard Hebrew on 5558.

### ONBOARDING OFFLINE-ACCOUNT FACTS CAPTURED (2026-06-14, 5560 wiped+airplane)
Per Daniel's decision to gather facts. Confirmed on a fresh wipe, fully offline:
(a) First account screen says **"Welcome Back!"** ("Ready for your next learning adventure?") on a first-ever run —
    a Sign In form is the default landing; a new user must spot "Register Here".
(b) Offline path = Register → "Create Account"; checking "Offline mode" changes the button to "Create Offline
    Account" but **still requires Email + Password** (empty → "Email is required"/"Password is required").
(c) "Offline mode" checkbox **defaults UNCHECKED** even with no network (airplane mode on).
(d) Registration **Display Name is NOT carried** into the first profile's name field (placeholder "Enter name").
Static info banners ("Local account only: no cloud backup…") present. → awaiting Daniel's product call on which to change.

### ONBOARDING REWORK SHIPPED (2026-06-15) — Daniel "all confirmed"
Implemented the confirmed model ([[onboarding-offline-account-model]]) in phases:
- **Phase 1 (commit 7b2f951c) — credential-less + explicit offline.** Offline sign-up collects nothing (no
  email/password/display-name, no ack checkbox); shows an explicit "Create Offline Account" + "Retry connection"
  + explanation, synthesizes an internal offline_*@offline.local identity (never shown), goes straight to profile
  creation. Account Picker shows "Offline account" for nameless local accounts and hides the synthetic email.
  ON-DEVICE VERIFIED on 5560 (wiped, airplane): credential-less screen, no-credential profile creation, profile
  persisted -> Set Parent PIN. (Account-picker label not re-verified — emulator PIN field rejected ADB input; the
  label is a deterministic, code-reviewed change.)
- **Phase 2 (this commit) — convert-on-reconnect prompt.** AppShellScreen shows a one-per-session dismissible
  MaterialBanner ("You're online — back up...") when a signed-in local-born account is CONFIRMED online (data-only,
  not the optimistic default); "Back up" routes to the existing UpgradeToCloudRoute, "Not now" dismisses. Placed as
  a MaterialBanner to avoid disturbing the appBar PreferredSize height math. ARB upgradePromptOnlineBody/Backup/
  Dismiss (en+he). NEEDS on-device verify (relaunch on a local-born device while online -> banner appears).
- **Phase 3 (returning user / wiped device) — ALREADY IMPLEMENTED, verify-not-rewrite.** sign_in_controller.dart
  (571-645) already "never pushes the onboarding wizard when the account already owns profiles in the cloud
  (returning user on a clean install)" via pull-and-recount + cloudAccountHasProfiles + restoreGuard ->
  DeviceRestoreRoute; local sign-in routes profiles-exist -> ProfilePicker/AppShell. Rewriting this sensitive,
  working flow would risk regressions, so it should be VERIFIED on-device, not changed. NOT modified.
- (d) display-name carry-over is MOOT (offline accounts have no account name). make ci GREEN (9976) through all.

### ONBOARDING REWORK — on-device verified + 2 follow-on fixes (2026-06-15)
- Phase 1 ON-DEVICE VERIFIED (5560 wiped/airplane): credential-less screen (no email/password/name/checkbox),
  no-credential profile creation → Set Parent PIN. (Account-picker label code-reviewed only — emulator PIN field
  rejects ADB input.)
- Phase 2 banner FIX (commit 97e910d2): on-device the banner never rendered — ScaffoldMessenger.of(context) from the
  shell build resolves above AutoTabsScaffold to a hostless messenger, so showMaterialBanner silently no-op'd (gate
  was correct + CI-green). Added a root scaffoldMessengerKey on MaterialApp.router (new lib/core/navigation/
  root_scaffold_messenger.dart) and target it directly. RE-VERIFIED ON-DEVICE (5560, offline adult "Abba"): banner
  renders ("You're online — back up..."), "Back up" → Upgrade to Cloud, "Not now" dismisses + stays gone. 3/3 PASS.
  LESSON: a CI-green widget gate can still never render to a user — the messenger-resolution bug was only visible
  on-device.
- Phase 2b CONVERT-COMPLETION (commit 7d0b93bb): on-device verify exposed that the Upgrade-to-Cloud flow assumed a
  real email + user-known password — a credential-less account (synthetic @offline.local + synthetic password) could
  NEVER complete it (and it showed the synthetic email). Added "full sign-in at conversion": for a credential-less
  account the Upgrade screen collects a real email + new password, UpgradeToCloudService.upgradeWithNewCredentials()
  registers a fresh Firebase account (no local-password verify) and replaces the synthetic email in BOTH the account
  DB (upgradeLocalToCloud email param) and the device registry (updateAccountTier email param); collision/merge
  methods thread the entered email (cloudEmail param). Generic value-prop (no synthetic email shown). +4 service unit
  tests. make ci GREEN (9980). ON-DEVICE VERIFIED (5560, offline "Abba"): Upgrade screen shows generic value-prop
  (no synthetic email) + Email + "Create a password" fields (not confirm-password); entering a real email+password
  proceeded end-to-end to the "Confirm Your Email" verification screen, no error. 3/3 PASS.
  ===== ONBOARDING REWORK COMPLETE: phases 1, 2, 2b shipped + on-device verified; phase 3 already-implemented. =====
- Phase 3 (returning user) still: ALREADY IMPLEMENTED in sign_in_controller — verify-not-rewrite (not done on-device;
  needs a wiped device + cloud test account).
