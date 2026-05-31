# Test coverage matrix — the scoreboard

Live grid of every routed `@RoutePage` screen (52 routes across ~46 files) + dialogs/sheets + backend
surfaces. One row per surface; tick a cell when a test **asserts that behaviour** (not just renders).
Worst-coverage features first (the work order). Part of the exhaustive test-and-fix run
(plan: `exhaustive-test-and-fix-plan-2026-05-29.md`; bug log: `test-fix-bug-log.md`).

**Legend:** `✓` behaviour asserted · `~` test exists but depth unverified / structural-only · `·` N/A for
this surface · blank = TODO. **`cur`** = # of test files referencing the screen class today (auto-detected
2026-05-29; many are tangential — treat `~` as "audit me", per the kickoff's false-confidence warning).

**Cells:** `R`=renders · `Lo`=loading · `Em`=empty · `Er`=error · `Off`=offline · `Ch`/`Ad`/`Tu`/`Pa`=child/adult/tutor/parent-mode · `He`=he-RTL · `Dk`=dark · `L4`=on-device ADB sweep.

---

## On-device ADB sweep — session 2026-05-31 (real phone, `100.72.6.10:5555`)

Drove the live app per `on-device-exhaustive-test-plan-2026-05-31.md`. **4 root-caused defects found + fixed +
regression-tested + committed green to `dev`** (`make ci` green throughout; details in `test-fix-bug-log.md`):
- **D1** `fix(shell)` — §5 persistent profile/role switcher was **absent from default Dashboard/Learn/Progress**
  (only Settings had an entry). Added always-present `_ProfileSwitcherBar` → `showProfileSwitcherSheet`.
  **On-device verified** on all 4 tabs + child context.
- **D2** `fix(dashboard)` — child redemption debit / parent refund left the Dashboard **points counter stale**;
  made `dashboardGlobalPointsProvider` a reactive `watchBalance` stream. Provider-test verified.
- **D3** `fix(i18n)` — parent-PIN lockout panel was hard-coded English; localized (en+he). Test verified.
- **D4** `fix(profiles)` — **Add Profile from the switcher silently created nothing**: the row popped the sheet
  first, unmounting context/ref so `showAddProfileDialog` bailed before `createProfile`. Fixed (keep sheet
  mounted) + surfaced errors + safe controller dispose. **On-device verified** (create child + PIN + delete).

**Flows:** F6 (persistent switcher in every context) **PASS** — adult Dashboard/Learn/Progress/Settings + child;
tap → switcher sheet (Account/Profiles/Talmid/Add); incidental passes: AddTrackFlow exit-guard, Set/Confirm
Parent PIN, delete-only-profile. **Product rules confirmed:** no track-type label (AddTrackFlow steps 1–2,
track cards); Hebrew curriculum terms in English UI (locale-independent); Settings header = account sheet (not
switcher) distinct from the app-shell switcher. **Method:** `uiautomator dump` for exact coords/labels + pulled
Drift DBs for ground truth (see `reference_phone_testing_adb`). **Device left clean** (test profile deleted).

**NEXT (resume here):** full F7 (parent-mode gating; cheat-sheet predicts no forgot-PIN recovery path),
F8 (rewards economy; cheat-sheet predicts the now-fixed D2 + a fulfil-vs-decline race with no status guard),
F11 (chazara conditional, derived from stage count >1), F2 (tutor invite), F3 (offline sync), F13 (Hebrew/RTL),
then the §1–§12 element-by-element sweep. Create a throwaway child profile via the switcher (now works) to
unblock child/parent/rewards testing. Source-grounded watch-fors per flow: `on-device-preflight-cheatsheet.md`.
§0 dead code to resolve: **ParentPortalBottomNav** + **ScopeSelectionScreen** provably-dead (delete);
**TrackLearningOrderScreen** reachable via TrackDetail → "Reorder content" (document).

---

## Phase 1 — Tutoring (16.7%) · WORST

| Screen | cur | R | Lo | Em | Er | Off | Ch | Ad | Tu | Pa | He | Dk | L4 |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| AcceptInviteScreen (6-step machine) | 1~ |  |  |  |  |  | · |  | · | · |  |  |  |
| DeclineInviteScreen | 0 |  |  |  |  |  | · |  | · | · |  |  |  |
| InviteTutorScreen | 0 |  |  |  |  |  | · |  | · | · |  |  |  |
| ManageTutorsScreen | 0 |  |  |  |  |  | · |  | · | · |  |  |  |
| ManageGrantsScreen | 0 |  |  |  |  |  | · |  | · | · |  |  |  |
| TutorAuditLogScreen (date fmt!) | 0 |  |  |  |  |  | · |  | · | · |  |  |  |
| TutorPinSetupScreen | **0** |  |  |  |  |  | · |  |  | · |  |  |  |
| TutorPinEntryGate | 1~ |  |  |  |  |  | · |  |  | · |  |  |  |
| TutorPinResetScreen | **0** |  |  |  |  |  | · |  |  | · |  |  |  |
| showTutorPinVerificationDialog | 1~ |  |  |  |  |  | · |  |  | · |  |  |  |

**Invariants (L5/unit):** `canMarkLiveCompletion=false` across 4 sites — VO `tutor_permissions.dart`,
use-case `mark_live_completion_use_case.dart:55-63`, `firestore.rules:203-232` (LOAD-BEARING), CF
`index.ts:423-447` (`tutorBulkPriorCompletions` rejects today+). `verifyTutorGrant` rejection branches.
`incomingTutorGrantsProvider` offline union. TutorGrant 7 `_buildState` branches.

## Phase 2 — Sync & offline-first (22.1%)

| Surface | cur | R | Lo | Em | Er | Off | He | Dk | L4 |
|---|--|--|--|--|--|--|--|--|--|
| SyncScreen | 1~ |  |  |  |  |  |  |  |  |
| OfflineTopBanner (cloud-born/local/online) | ? |  | · | · |  | ✓? |  |  |  |
| SyncStatusIndicator (7 states) | ? |  |  |  |  |  |  |  |  |
| app_shell connectivity-adaptive | 4~ |  |  |  |  | ~ |  |  |  |
| Backup&Sync card (Connecting/LOCAL ONLY) | ? |  |  |  |  |  |  |  |  |
| *every screen renders offline* | — | | | | | | | | |

## Phase 3 — Tracks & setup wizard (29.4%)

| Screen | cur | R | Lo | Em | Er | Off | Ch | Ad | Tu | He | Dk | L4 |
|---|--|--|--|--|--|--|--|--|--|--|--|--|
| TrackManagementHubScreen | 0 |  |  |  |  |  |  |  |  |  |  |  |
| AddTrackFlow (live screen — **0 real**) | 0 |  |  |  |  |  |  |  |  |  |  |  |
| TrackDetailScreen | 1~ |  |  |  |  |  |  |  |  |  |  |  |
| EditTrackScreen + ChazaraInlineSetup | 0 |  |  |  |  |  |  |  | · |  |  |  |
| LearningOrderScreen (reorder races) | 1~ |  |  |  |  |  |  |  |  |  |  |  |
| StudyDayConfigScreen | 0 |  |  |  |  |  |  |  |  |  |  |  |

**Rules:** chazara UI only when `track.chazaraEnabled`; start-date back-date → overdue catch-up; scope auto-skip (DNI-202).

## Phase 4 — Gamification (35.9%) & Profiles (38.8%)

| Screen | cur | R | Lo | Em | Er | Off | Ch | Ad | Tu | Pa | He | Dk | L4 |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| GamificationScreen | **0** |  |  |  |  |  | · |  | · | ✓? |  |  |  |
| ChildRedemptionScreen (afford/unafford) | **0** |  |  |  |  |  |  | · | · | · |  |  |  |
| ParentPendingRedemptionsScreen (approve/decline) | **0** |  |  |  |  |  | · |  | · | ✓? |  |  |  |
| RewardConfigurationScreen (validation) | **0** |  |  |  |  |  | · |  |  | ✓? |  |  |  |
| PointConfigScreen | 1~ |  |  |  |  |  | · |  |  |  |  |  |  |
| ProfilePickerScreen | **0** |  |  |  |  |  |  |  |  |  |  |  |  |
| ManageLearnersScreen | **0** |  |  |  |  |  | · |  |  |  |  |  |  |
| ParentSettingsScreen (tutor-perm matrix) | 1~ |  |  |  |  |  | · |  | ✓? | ✓? |  |  |  |
| ParentTrackManagementScreen | **0** |  |  |  |  |  | · |  |  |  |  |  |  |
| showAddProfileDialog | dlg |  |  |  |  |  |  |  |  |  |  |  |  |
| epic_15 multi-profile (un-skip) | skip |  |  |  |  |  |  |  |  |  |  |  |  |

## Phase 5 — Account, onboarding, nav/guards (35.9% / 41.1%)

| Screen | cur | R | Lo | Em | Er | Off | He | Dk | L4 |
|---|--|--|--|--|--|--|--|--|--|--|
| SignInScreen (idle/submit/error/watchdog) | 2~ |  |  | · |  |  |  |  |  |
| SignupScreen (5-acct cap, collide→upgrade) | 1~ |  |  | · |  |  |  |  |  |
| AccountPickerScreen (switch = no sign-out ✓) | 1 | ~ |  |  |  |  |  |  |  |
| UpgradeToCloudScreen | **0** |  |  |  |  |  |  |  |  |
| AppIntroScreen | **0** |  | · | · | · |  |  |  |  |
| OnboardingScreen (child/adult/skip/join-tutor) | 4~ |  |  |  |  |  |  |  |  |
| EmptyLoginScreen | 1~ |  |  |  |  |  |  |  |  |
| PermissionPromptScreen | **0** |  | · | · |  |  |  |  |  |
| DeviceRestoreScreen | **0** |  |  |  |  |  |  |  |  |
| **Guards** (Auth/Restore/Profile/Pin/ChildMode) | ~ |  |  |  |  |  | · | · |  |

## Phase 6 — Settings, scheduler, notifications, sacred-time, dashboard, learning

| Screen | cur | R | Lo | Em | Er | Off | Ch | Ad | Tu | Pa | He | Dk | L4 |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| SettingsScreen (row-visibility matrix) | 1~ |  |  | · |  |  | ~ | ~ | ~ | ~ |  |  |  |
| _AccountActionsSheet (5 role variants) | dlg |  | · | · |  |  |  |  |  |  |  |  |  |
| CurriculumSettingsScreen | **0** |  |  |  |  |  |  |  |  |  |  |  |  |
| LifetimeMarkingScreen | 1~ |  |  |  |  |  |  |  |  |  |  |  |  |
| SchedulerScreen (today/overdue/review) | 1~ |  |  |  |  |  |  |  | · |  |  |  |  |
| NotificationsScreen | 2~ |  |  |  |  |  |  |  |  |  |  |  |  |
| CityPickerScreen (sacred — **0**) | **0** |  |  |  |  |  |  |  |  |  |  |  |  |
| SacredTimeSettingsCard / Shabbos lock | ? |  |  |  |  |  |  |  |  |  |  |  |  |
| DashboardScreen (sync-gate/AllCaughtUp/carousel) | 2~ |  |  |  |  |  |  |  | ✓? | ✓? |  |  |  |
| LearningScreen (mark→advance, tutor block) | 1~ |  |  |  |  |  |  |  | ✓? |  |  |  |  |
| TextDisplayScreen (reader, tutor live-mark block) | 1~ |  |  |  |  |  |  |  |  |  |  |  |  |

## Phase 7 — Backend (27 CFs + 24 rules paths) · **0 server tests**

CFs (auth/state/error branches via `firebase-functions-test`): `onUserDeleted`, `deleteLearnerProfile`,
`deleteCurriculumTrack`, `deleteAccountData`, `purgeExpiredAuditLogs`, `tutorBulkPriorCompletions`,
`inviteTutor`, `acceptTutorInvite`, `declineTutorInvite`, `rescindTutorInvite`, `revokeTutorGrant`,
`resignTutorGrant`, `listTutorGrants`, `expirePendingInvites`, `tutorResetCompletion`, `tutorUpsertGoal`,
`tutorDeleteGoal`, `tutorUpsertTrack`, `tutorDeleteTrack`, `tutorUpsertStageDefinition`,
`tutorUpsertStudyDayConfig`, `tutorDeleteStudyDayConfig`, `tutorUpdateGamificationSettings`,
`tutorUpsertBookmark`, `tutorSetProfileProgram`, `tutorUpsertCurriculumScope`, `tutorEditProfile`.
**Rules (24 paths)** via `@firebase/rules-unit-testing` emulator — owner-only completions (tutor write
block), tutor_grants, tutor_active_access, every `users/{uid}/learner_profiles/{profileId}/*` subtree.

## Phase 8 — Visual / i18n / a11y / data-integrity

- Golden baselines: **0** real-screen baselines (all `skipGolden:true`); none for he-RTL or dark.
- **41 hardcoded-English strings** flagged (scheduler, tracks, learning, dashboard banner, `TALMID PROFILES`).
- Data integrity: `DriftMergeStore.remoteIsNewer` ±5s; tombstone resurrection; FK-guard skips;
  migrations v26→v28; multi-account DB threading.

---

## Progress summary

| Date | Routed screens with L1 | CFs tested | Rules paths tested | Goldens | Overall cov% |
|---|---|---|---|---|---|
| 2026-05-29 (baseline) | ~27/52 have ≥1 test file (depth unaudited); ~25/52 **zero** | 0/27 | 0/24 | 0 | 58.4% |
| 2026-05-29 (rig #3) | — | 0/27 | **5/24** (users, completions+tutor-write-block, goals, tutor_grants, tutor_active_access) via `make test-rules` | 0 | 58.4% |
| 2026-05-29 (tutor wave 1) | +6 tutoring screens (PinSetup/PinReset/Invite/ManageTutors/ManageGrants/AuditLog) — **111 L1 tests**, 0 skipped (RP3-RETRY fixed: global `retry: null` in bootstrap) | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (tutor wave 2) | +AcceptInvite(6-step)/Decline/PinEntryGate behaviour + ManageTutors strengthen + canMarkLiveCompletion invariant — **all 10 tutoring screens L1-covered** (+104 tests, RTL smoke each) | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (sync/offline) | +OfflineTopBanner(15)/SyncStatusIndicator(19,7-state)/BackupSyncSection(18) = **52 L1 tests**; removed dead `SyncScreen` (/sync) placeholder route | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (tracks) | +AddTrackFlow(23)/EditTrack+Chazara(25)/TrackManagementHub(19)/StudyDayConfig(20) = **87 L1 tests**; product rules asserted (no track-type label, scope, back-date→overdue, chazara) | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (gamification) | +GamificationHub(19)/ChildRedemption(15)/ParentPendingRedemptions(17)/RewardConfig(16) = **67 L1 tests**; FIXED double-tap guard on Fulfil/Decline | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (epic_15 un-skip) | un-skipped the fully-`@Skip`'d multi-profile acceptance suite — **119 tests now passing** (12 justified skips: file/git/arch/compile-time checks); 7 fixture-FK repairs, no prod bugs | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (profiles) | +ProfilePicker(17)/ManageLearners(20)/ParentSettings(33, tile-matrix)/ParentTrackMgmt(20) = **90 L1 tests**; FIXED ProfileEditFormDialog crash (lazy ListView in AlertDialog) + AddProfileCard RTL overflow | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (account/onboarding) | +AppIntro(12)/PermissionPrompt(24)/UpgradeToCloud(17, 7 skip-DI)/DeviceRestore(15) = **68 L1 tests** | 0/27 | 5/24 | 0 | re-measure pending |
| 2026-05-29 (backend rules) | Firestore rules **5→24/24 paths, 70 assertions** (full learner subtree read/write matrix, tutor read-only + write-block, account-snapshot/diagnostic-logs tutor-exclusion, audit-log, default-deny, hasOnly whitelists) | 0/27 | **24/24** | 0 | rules layer locked |
| 2026-05-29 (nav guards 5b) | all **5 guards** unit-tested (Auth/Restore/Pin/ChildMode/Profile) + **SYSTEMIC LOCKOUT FIX**: top-level try/catch fail-safe in every guard (no-lockout invariant) + 6 fail-safe regression tests; deleted redundant old auth_guard_test; 111 nav/auth tests green | 0/27 | 24/24 | 0 | guard layer hardened |
| 2026-05-29 (backend CFs) | **all 27 Cloud Functions** tested via fft.wrap() vs emulator — **271 assertions, 271/271 green** (auth/arg/grant/perm gates + effects + audit); fixed clearFirestore (recursiveDelete) + added Auth emulator; 8 server-fn findings logged (3 to fix) | **27/27** | 24/24 | 0 | backend hole CLOSED |
| 2026-05-30 (backend CF fixes) | fixed 3 server bugs + 3 regression tests (**274/274 green**); **deployed all 27 fns live** to torah-study-tracker | 27/27 | 24/24 | 0 | live backend current |
| 2026-05-30 (Phase 6 screens) | +CityPicker(19)/CurriculumSettings(26)/Learning(22, **live-mark-block invariant**)/Scheduler(23)/Notifications(37) = **127 L1 tests**; only i18n/cosmetic findings, no prod bugs | 27/27 | 24/24 | 0 | **measured 68.4%** |
| 2026-05-30 (coverage-leverage) | +249 on highest-uncovered files (sefaria_ref_matcher 116, scheduler_providers 43, sign_in_controller 24, track-setup scope 22 + start-position/goal 44); +v27→v28 migration test | 27/27 | 24/24 | 0 | **measured 70.5%** (from 58.5% baseline) |
| 2026-05-30 (coverage w2: sync) | +298 (firestore_gateway 114, sync_orchestrator 29, local_data_upload 42, wizard_steps 62, account_actions 25, pin_keypad 26); 2 documented skips | 27/27 | 24/24 | 0 | re-measure pending |
| 2026-05-30 (coverage w3: screens) | +242 (scope/lifetime 42, tracks body/order 29, onboarding/bulk 34, profiles 19, content reader 38, lifetime-folder/notif-providers 79); **fixed scope-save silent no-op** + regression test | 27/27 | 24/24 | 0 | **measured 74.7%** (sync 30.5%→74.9%) |
| 2026-05-30 (coverage w4: account) | +188 (upgrade_service 33, email_verify_panel 24, tutor_grant_repo 76, dashboard_providers 41, achievement_celebration 14); **fixed CRITICAL upgrade-crash** (discardLocalCredentials replace→clearPasswordHash) + un-skipped 3 tests | 27/27 | 24/24 | 0 | re-measure pending |
| 2026-05-30 (coverage w5) | +169 (magic_link 27, edit_track/detail 41, add_track_flow 12, recent_activity/hierarchy 27, onboarding 34); **fixed magic-link deep-link crash** (malformed % encoding) + un-skip | 27/27 | 24/24 | 0 | **measured 76.6%** (account 47→62%) |
| 2026-05-30 (coverage w6 deep) | +167 (scheduler allDailyTasks-body 11, reward_config 47, completion_writer 41, chazara/goal 31, signup 37); discarded 1 false-confidence sign-in test (integrity) | 27/27 | 24/24 | 0 | **measured 77.3%** (scheduler 22→60%) |
| 2026-05-30 (coverage w7) | +150 (pin_flow/setup-dialog 28, profile_picker/tutored deep 24, settings/point-config 36, notif-providers deep 32, study-days/content-hierarchy 25, scheduler branches 5) | 27/27 | 24/24 | 0 | (rolled into w8 measure) |
| 2026-05-30 (coverage w8 sync) | +229 sync-engine internals (push_pipeline 39, **drift_merge_store 59 LWW**, outbox 17, seed_manager 43, codecs/mergers 71); no merge/sync bugs — engine holds | 27/27 | 24/24 | 0 | **measured 78.5%** |
| 2026-05-30 (coverage w9) | +217 (sacred_time data/location 47, notification_gateway 60, account_picker 14, siyumim/lifetime 32, tutor_pin/goal_setup 34, content reader 30); **fixed sacred-time inIsrael race** | 27/27 | 24/24 | 0 | **measured 79.4%** |
| 2026-05-30 (connectivity DI) | sign_in_controller now reads internetConnectionCheckerProvider (was bypassing it) — unblocks deterministic sign-in tests | 27/27 | 24/24 | 0 | testability fix |
| 2026-05-30 (coverage w10) | +99 (sign_in routing 7, settings utils 11, curriculum/change-password 23, content tile/search/providers 28, pending-signup/mode-card 30) | 27/27 | 24/24 | 0 | **measured 80.1%** |
| 2026-05-30 (CI gate) | **`make ci` GREEN** (analyze + format-check + 8937 tests) after normalizing dart-format across 35 test files — the canonical clean full pass | 27/27 | 24/24 | 0 | **80.1%, make ci green** |
</content>
