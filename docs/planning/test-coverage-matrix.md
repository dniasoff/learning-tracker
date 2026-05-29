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
</content>
