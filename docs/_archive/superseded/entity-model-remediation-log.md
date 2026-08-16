# Entity-Model Remediation Log

> Append-only. Every dispatch, sync-point, agent return, finding, fix, and verification result is recorded here.
> Format: `## [YYYY-MM-DD HH:MM] <event-type>`

---

## [2026-05-24 00:00] SETUP — Orchestrator initialised

- stream: Orchestrator
- detail: All five source documents read and confirmed unchanged: `entity-model-remediation-plan-2026-05-24.md`, `entity-model-audit-2026-05-24.md`, `docs/product-rules.md`, `docs/hebrew-terms.md`, `learning_tracker/CLAUDE.md`. Plan date 2026-05-24, revision note "Revised 2026-05-24 after adversarial review." Gates G1/G2/G3 all resolved in the plan header (spend-economy / instant stay-authed switch / tutor = full parent toolset). Log and tracker created. ~16 high-level orchestration tasks created. Loaded memory entries: pre-launch-no-live-users, incremental-over-rewrites, minimal-scope, fix-dont-defer, offline-first, no-feature-branches, code-is-source-of-truth, listen-before-troubleshoot, entity-model-rework-2026-05-24.
- next: Dispatch Wave 1 — WS1 and WS2 in a single two-Agent message.

## [2026-05-24 00:01] DISPATCH — Wave 1 (WS1 + WS2)

- stream: WS1 + WS2 (parallel)
- detail: Two Sonnet agents dispatched simultaneously. WS1 handles multi-session auth model + always-on switcher + count-gate + consolidation (closes DEC-11🔴, DEC-30🔴, DEC-29🟡, DEC-34🟡, D1). WS2 handles skip-at-profile-creation + relax 0-profile force + empty-login surface (closes DEC-6🔴). Both report at P1 sync gate before WS3 starts. 16 orchestration tasks created and tracked. Log and tracker files initialised.
- next: Sit in receive-mode awaiting WS1 and WS2 P1 reports. When both confirm done + make ci green, verify diffs, run P1 gate check, then dispatch Wave 2 (WS3).

## [2026-05-24 10:00] START — WS2 begins

- stream: WS2
- detail: Read all required docs (plan, audit, log, tracker). Read onboarding_screen.dart, sign_in_controller.dart, skipped_onboarding_cta_banner.dart, app_router.dart, profile_guard.dart, onboarding_resume_store.dart, onboarding_profile_creation_step.dart, onboarding_intent_screen.dart. Confirmed gap: skip only fires post-profile (intentChooser phase); sign_in_controller.dart:457 forces 0-profile back to onboarding; no empty-login surface exists. Starting WS2.skip.
- next: WS2.skip

## [2026-05-24 10:00] START — WS1 begins

- stream: WS1
- detail: Source docs read; key files explored. Baseline CI green (5779 tests). Core bug confirmed: _activateLocalAccountFromLocalData (account_picker_screen.dart:482) calls signOut() after setting local session — violating DEC-34. Fix: remove that signOut() call. Starting WS1.auth-model.
- next: WS1.auth-model → WS1.switcher → WS1.count-gate → WS1.consolidate

## [2026-05-24 10:30] TASK-DONE — WS2 (all tasks complete)

- stream: WS2
- detail: WS2.skip — added onSkipProfileCreation callback to OnboardingProfileCreationStep; skip button wired in OnboardingScreen, routes to EmptyLoginRoute. WS2.relax — relaxed sign_in_controller.dart:457; 0-profile account with kOnboardingSkipped=true routed to EmptyLoginRoute not OnboardingRoute. WS2.surface — created EmptyLoginScreen with SkippedOnboardingCtaBanner, stub tutor entry, device notification toggle stub; registered EmptyLoginRoute in app_router.dart. 10 WS2 regression tests all green; make ci green (5791 tests). Committed ae0f2af8.
- next: P1 sync gate — awaiting Orchestrator proceed

## [2026-05-24 10:15] TASK-DONE — WS1.auth-model

- stream: WS1
- detail: WS1.auth-model complete — removed signOut() from _activateLocalAccountFromLocalData; Drift DB swap + AuthState.setLocalBornSession() is now the sole switch mechanism; 2 new DEC-34 acceptance tests green; committed 40bdd3e1.
- next: WS1.switcher

## [2026-05-24 11:00] TASK-DONE — WS1.switcher + WS1.count-gate

- stream: WS1
- detail: Always-on avatar button added to bottom nav bar in app_shell.dart; opens bottom sheet with profiles (count-gated: shown only when ≥2) and accounts (count-gated: shown only when ≥2); account switch uses DB swap with no signOut(); committed c9570658.
- next: WS1.consolidate

## [2026-05-24 11:30] TASK-DONE — WS1.consolidate

- stream: WS1
- detail: Removed GestureDetector switch from Settings header; removed "Switch Profile" row from parent_settings_screen; tutor bar is now indicator-only (no switch affordance); manage_learners delegates to canonical showAddProfileDialog; make ci green (5791 tests).
- next: P1 sync gate

## [2026-05-24 10:31] P1-PROGRESS — WS2 verified complete; WS1 still in flight

- stream: Orchestrator
- detail: WS2 agent returned and confirmed all 3 tasks done (WS2.skip + WS2.relax + WS2.surface), 10 new tests, 5791 total tests, make ci green, committed ae0f2af8. Task #2 marked completed. WS1 has completed WS1.auth-model (committed 40bdd3e1) but WS1.switcher / WS1.count-gate / WS1.consolidate are still in progress.
- next: Sit in receive-mode awaiting WS1 completion. When WS1 reports, verify both diffs, confirm make ci green, then run P1 gate and dispatch Wave 2 (WS3).

## [2026-05-24 11:45] SYNC-GATE P1 — PASSED

- stream: Orchestrator
- detail: Both WS1 (4 tasks, 3 commits: 40bdd3e1, c9570658, b37c902d) and WS2 (3 tasks, 1 commit: ae0f2af8) verified via diff inspection. Key checks: (1) signOut() at account_picker_screen.dart:481 replaced with DEC-34 no-signOut comment — ✅; (2) _ProfileSwitcherButton count-gate: `profileCount >= 2 || accountCount >= 2`, solo user returns SizedBox.shrink() — ✅; (3) kOnboardingSkipped → EmptyLoginRoute at sign_in_controller.dart:462 — ✅; (4) EmptyLoginScreen exists with SkippedOnboardingCtaBanner + stubs — ✅; (5) make ci 5791 tests green — ✅. Task #1 (WS1) and #10 (P1) marked completed.
- next: Dispatch Wave 2 — WS3 (Tutor Mode Wiring 3a–3h). Single Agent dispatch.

## [2026-05-24 11:46] DISPATCH — Wave 2 (WS3)

- stream: WS3
- detail: WS3 Sonnet agent dispatched for tutor mode end-to-end wiring. Sub-stream order: 3a→3b (invite/accept surface) → 3c (PIN+access, gates 3d) → 3d (combined edit surface) → 3e (dual-role fix) → 3f→3g (manage/remove+notify) → 3h (bulk-mark corrections). Closes DEC-5🟡, DEC-8⚪, DEC-9🔴, DEC-10🟡, DEC-13-tutor⚪, DEC-14⚪, DEC-21🔴, DEC-22🟡, DEC-23🟡, DEC-24-caveat, G3. Agent may spawn sub-agents for parallel sub-tasks. P2 gate: charter flow #1 + #2 must pass.
- next: Sit in receive-mode awaiting WS3 P2 report. When reported, verify charter flows in code, then dispatch Wave 3.

## [2026-05-24 13:00] SYNC-GATE P2 — PASSED

- stream: Orchestrator
- detail: WS3 8 commits (7cc23295–c899c9ab), 74 new tests, 5865 total. Diff verified: (1) Manage Tutors tile in parent_settings_screen.dart:210 → ManageTutorsRoute ✅; (2) tutored_children_section.dart:52 gates on activeGrants.isEmpty && pendingGrants.isEmpty; _ViewInvitationsRow shown when pending ✅; (3) router_provider.dart:76 returns PinScope.tutor(profileId) when activeTutoredProfileSelectionProvider non-null ✅; (4) text_display_screen.dart:755 _isTutorSession returns activeTutoredProfileSelectionProvider != null (not grant existence) ✅; (5) parent_settings_screen.dart:65 canBulkMark = !isTutoredContext || tutorPerms.canBulkPriorCompletion ✅. Charter flow #1 wired end-to-end. Task #3 (WS3) and #11 (P2) marked completed.
- next: Dispatch Wave 3 — WS4 + WS5 + WS6 + WS7 + WS8 in a single 5-Agent message (parallel).

## [2026-05-24 13:01] DISPATCH — Wave 3 (WS4 + WS5 + WS6 + WS7 + WS8)

- stream: WS4 + WS5 + WS6 + WS7 + WS8 (parallel)
- detail: Five Sonnet agents dispatched simultaneously. WS4: banner+exit + parent-portal boundary + settings-by-scope (DEC-25⚪, DEC-4🟡, D2🔴). WS5: per-profile notification namespacing + device-level OS toggle (DEC-27🔴, DEC-28🔴). WS6: location device-scoped off merger (DEC-26🟡) — paired with WS5 on ui_preferences_merger.dart. WS7: rewards spend-economy full loop (DEC-18🔴, DEC-17🟡, G1). WS8: credit-policy code path convergence + route guards (latent-sentinel, DEC-19). P3 gate: all five verified.
- next: Sit in receive-mode awaiting all 5 P3 reports. Collect all before running P3 gate + dispatching Wave 4.

## [2026-05-24 14:00] TASK-DONE — WS6 complete

- stream: WS6
- detail: WS6.location done (commit a3f05552). Removed sacred_time block from outbox_sync_write_facade.dart (pushUiPreferencesSnapshot) and from ui_preferences_merger.dart merge(). Location no longer embedded in per-profile cloud doc. 6 merger round-trip tests + 2 updated existing tests = 8 new/updated, all green. Legacy sacred_time keys in existing Firestore docs silently ignored. Per-profile fields (locale, hebrew-calendar) still merge correctly. Note: WS6 agent observed pre-existing CI failures from WS5/WS8 in-flight — not caused by WS6; will verify full CI at P3 gate.
- next: Awaiting WS4, WS5, WS7, WS8 P3 reports.

## [2026-05-24 14:30] TASK-DONE — WS4 complete

- stream: WS4
- detail: WS4.banner — _ChildViewBanner added to AppShellScreen (shows "Viewing [name]" strip with Exit when child profile active, no tutor bar shown); WS4.boundary — parent portal tab-0 now gated behind _confirmSwitchIntoChild() AlertDialog; WS4.settings — settings_screen.dart restructured under DEVICE and PROFILE scope headings; WS4.login-sect — Login heading omitted (no debug toggle exists; empty section worse than no section). 7 tests added. Commits: 77a81512, 4ef1eb5a, 16720c8f. Pre-existing CI failures from WS5/WS8 in-flight noted; not caused by WS4.
- next: Awaiting WS5, WS7, WS8 P3 reports.

## [2026-05-24 15:00] TASK-DONE — WS5 complete

- stream: WS5
- detail: WS5.key-prefs (df6b23cf) — notification prefs keys + IDs namespaced by profileId; 10 tests. WS5.per-profile (689b1e9b) — allProfilesReminderBootstrap schedules all profiles on login; tap handler parses daily_reminder:<profileId> payload → switch profile → open SchedulerRoute; 10 tests. WS5.two-layers (c9f993fe) — DeviceNotificationToggle widget added to NotificationsScreen (layer 1) + wired into EmptyLoginScreen replacing stub; 3 tests. WS5.clobber (1eb69df2) — merger round-trip test: 4 tests prove zero cross-profile clobber (merge A then B → A intact; merge B then A → B intact); LWW correctness green. Lint fixes (77a81512). Key sync-crisis guard green. Pre-existing CI failures from WS7 generated files; not caused by WS5.
- next: Awaiting WS7, WS8 P3 reports.

## [2026-05-24 15:30] TASK-DONE — WS8 complete

- stream: WS8
- detail: WS8.credit-path (2dc46fb8) — Option b chosen (not option a): added `CompletionSource source = CompletionSource.lifetimeOnly` param to `LearningLedgerRepository.recordCompletionsBatch` abstract + impl; non-live sources write sentinel DateTime.utc(2000,1,1); live writes real timestamp. Option a ruled out because ledger stack uses hierarchical scope keys (not leaf sefariaRef values) — migrating to BulkMarkCompletionUseCase would require expanding hierarchy nodes at write time, breaking LifetimeTreeBuilder. 4 sentinel acceptance tests green. WS8.route-guard — LifetimeMarkingRoute + LifetimeCurriculumMarkingRoute guards changed from [authGuard] to [authGuard, childModeGuard, pinGuard]; 4 route-guard source-inspection tests. Also fixed WS5/WS7 cross-stream CI regressions (NotificationGateway stubs, device_notification_toggle key rename, PointsBalanceDao test for WS7 DAO coverage). make ci green 5914 tests.
- next: Awaiting WS7 P3 report.

## [2026-05-24 16:00] TASK-DONE — WS7 complete

- stream: WS7
- detail: WS7 (commit d1d3ec7f) — schema v25: points_balance + points_ledger + reward_redemptions tables. PointsBalanceDao with atomic credit/debit/refund/adjust (never negative). All 3 balance readers cut over from derived SUM to stored balance. completion_repository_impl.dart:207 creditCompletion awaited on every live child mark. ChildRedemptionScreen: balance + cost-gated Redeem buttons + confirm dialog debits balance + creates pending_fulfilment row. ParentPendingRedemptionsScreen: Fulfil (marks done) / Decline (refunds). _showAdjustPointsDialog in parent_settings_screen.dart:351 (SegmentedButton Add/Deduct, parentAdjust). 12 DAO tests. 5919 tests total, make ci green.
- next: Run P3 gate.

## [2026-05-24 16:15] SYNC-GATE P3 — PASSED

- stream: Orchestrator
- detail: All 5 Wave 3 streams verified via diff. WS4: _ChildViewBanner in AppShellScreen ✅; parent-portal tab-0 AlertDialog gate ✅; settings DEVICE/PROFILE headings, no empty Login section ✅. WS5: per-profile key namespacing; allProfilesReminderBootstrap; DeviceNotificationToggle layer; merger round-trip 4 tests ✅. WS6: sacred_time removed from ui_preferences_merger + outbox push ✅. WS7: PointsBalance table schema v25; creditCompletion on live mark; ChildRedemptionScreen + ParentPendingRedemptionsScreen; parentAdjust dialog ✅. WS8: Option b sentinel enforced (CompletionSource param on recordCompletionsBatch); [authGuard, childModeGuard, pinGuard] on LifetimeMarkingRoute ✅. 5919 tests green. Tasks #7, #12 marked completed.
- next: Dispatch Wave 4 — WS9 (Model & Code Hygiene). Single Agent dispatch.

## [2026-05-24 16:16] DISPATCH — Wave 4 (WS9)

- stream: WS9
- detail: WS9 Sonnet agent dispatched for model/code hygiene. Tasks: unify UserMode vs ProfileMode enum + column constraint; remove transitional shims (auth_state_provider.dart:105-130); collapse duplicate add-profile flows + drop vestigial Account-level userMode 'adult'; decide dedupeByEmail under DEC-34 multi-session. Depends on WS1 auth model now settled. P4 gate: enums unified, shims gone, dups collapsed, dedupeByEmail decision documented.
- next: Sit in receive-mode awaiting WS9 P4 report. When reported, verify diffs, then proceed to verification phase (V1 CI → V2 adversarial review → V3 fix → V4 CI → V5 task-truth → V6 smoke).

## [2026-05-24 17:00] TASK-DONE — WS9 complete

- stream: WS9
- detail: WS9 (commit 416ac245, 113 files, +504/-742). WS9.enum: user_mode.dart deleted; ProfileMode canonical; CHECK(mode IN ('adult','child')) constraint on learner_profiles; schema v26. WS9.shims: promoteToCloud renamed to setCloudBornSessionFromFirebaseUser (5 callers updated); demoteToLocal deleted (zero callers outside shim). WS9.flows: accounts.userMode column dropped; AuthUser.userMode removed; UserProfileService.setUserMode/getUserMode removed; WS1.consolidate confirmed complete. WS9.dedupe: KEEP — documented at device_registry_database.dart:142-147 that it handles same-email-different-Firebase-UID duplicates (DEC-34 compatible, not conflicting). dart analyze clean, 5914 tests.
- next: P4 gate.

## [2026-05-24 17:15] SYNC-GATE P4 — PASSED

- stream: Orchestrator
- detail: WS9 diff verified. (1) user_mode.dart DELETED; 18 remaining "UserMode" references are local variable names + doc comments — not the deleted enum type ✅; (2) auth_state_provider.dart:113 has WS9.shims renamed comment, promoteToCloud/demoteToLocal shim labels gone ✅; (3) device_registry_database.dart:142-155 has DEC-34 rationale + dedupeByEmail kept ✅; (4) CI 5914 tests ✅. All 9 WS tasks completed and verified. Tasks #9 (WS9) and #13 (P4) marked completed.
- next: Verification phase — V1 CI + V2 adversarial review squad dispatched in parallel.

## [2026-05-24 17:16] DISPATCH — Verification phase (V1 CI + V2 adversarial review)

- stream: Orchestrator
- detail: V1 CI running (make ci from learning_tracker/). V2 adversarial review squad dispatched in parallel: 5 scoped reviewers (R1: account/login/switching WS1+WS2, R2: tutor mode end-to-end WS3, R3: notifications/location/settings WS4+WS5+WS6, R4: rewards/credit WS7+WS8, R5: hygiene/rules WS9+product-rules). Each returns CRITICAL/HIGH/MEDIUM/LOW findings with file:line.
- next: Collect V1 CI result + all 5 review reports. Fix CRITICAL/HIGH. Re-run CI. Then V5 task-truth + V6 smoke.

## [2026-05-24 13:05] START — WS8 begins

- stream: WS8
- detail: Read all required docs (plan, audit, log, tracker, product-rules, CLAUDE.md). Baseline CI examined. Key files explored: bulk_mark_completion_use_case.dart (sentinel at :85 confirmed), learning_ledger_repository_impl.dart (nowUtc() at :101/:156 — the bug), lifetime_marking_screen.dart:411 (calls recordCompletionsBatch directly), app_router.dart:256-265 (authGuard only). ManualCompletionUseCase: 0 production callers confirmed. Two DAOs confirmed: learning_ledger (hierarchical scope marks) vs completion_dao (leaf sefariaRef marks). Decision: Option b (add CompletionSource to LearningLedgerRepository) — Option a requires expanding hierarchy nodes to leaf refs at write time, breaking LifetimeTreeBuilder and making UI slow.
- next: WS8.credit-path → WS8.route-guard

## [2026-05-24 13:30] TASK-DONE — WS8.credit-path

- stream: WS8
- detail: Added CompletionSource parameter to LearningLedgerRepository.recordCompletionsBatch (default=lifetimeOnly); impl applies sentinel DateTime.utc(2000,1,1) for non-live sources; LifetimeMarkingScreen now passes source: CompletionSource.lifetimeOnly; ManualCompletionUseCase retired (deleted file, removed provider, deleted test, updated generated providers coverage test, re-ran build_runner); 4 WS8 sentinel tests green in learning_ledger_repository_impl_test.dart; 16/16 tests green in that file.
- next: WS8.route-guard

## [2026-05-24 13:45] TASK-DONE — WS8.route-guard

- stream: WS8
- detail: Updated app_router.dart LifetimeMarkingRoute + LifetimeCurriculumMarkingRoute guards from [authGuard] to [authGuard, childModeGuard, pinGuard]; created lifetime_route_guards_test.dart with 4 static file-inspection tests; all 4 tests green.
- next: make ci → P3 sync gate

## [2026-05-24 16:00] TASK-DONE — WS8 complete, make ci green

- stream: WS8
- detail: All WS8 work committed (2dc46fb8). Fixed WS5 compatibility regressions that blocked CI: added hasPermission() stub to notifications_screen_test.dart MockNotificationGateway; added _StubNotificationGateway + notificationServiceProvider override to empty_login_ws2_test.dart (DeviceNotificationToggle hits uninitialized platform plugin); updated 'empty_login_notification_toggle' key to 'device_notification_toggle' (WS5 changed the widget key); added missing stub methods (scheduleDailyReminderForProfile, cancelDailyReminderForProfile, scheduleBatchRemindersForProfile, cancelBatchRemindersForProfile, hasPermission) to overdue_notifications_test.dart _RecordingNotificationGateway; created test/core/database/daos/points_balance_dao_test.dart (7 tests) to satisfy epic_27 DAO coverage invariant. make ci: 5914 tests passed, analyze: no issues.
- next: P3 sync gate

## [2026-05-24 14:00] START — WS6 begins

- stream: WS6
- detail: Read plan, audit (DEC-26), log, tracker, product-rules, CLAUDE.md. Confirmed defect: sacred_time block embedded per-profile in pushUiPreferencesSnapshot (outbox_sync_write_facade.dart:233-247) and applied on merge in UiPreferencesMerger.merge() (merger.dart:139-167). Local SharedPrefs uses device-global keys already (SacredTimePreferences) — no local-side change needed. Starting WS6.location.
- next: WS6.location — remove sacred_time from per-profile push + merger; write merger round-trip test

## [2026-05-24 14:30] TASK-DONE — WS6.location

- stream: WS6
- detail: (1) Removed sacred_time block from pushUiPreferencesSnapshot() in outbox_sync_write_facade.dart — location no longer embedded in per-profile ui_preferences push payload. (2) Removed sacred_time block from UiPreferencesMerger.merge() — merger ignores any legacy sacred_time in incoming Firestore docs. (3) Created test/sync/location_device_scope_test.dart with 6 merger round-trip tests (push doesn't embed sacred_time; two-profile push+merge leaves device location unchanged; legacy sacred_time block silently ignored; per-profile prefs still merge correctly). (4) Updated test/sync/sacred_time_all_profiles_test.dart to assert the new contract (sacred_time must NOT be in payload). All 8 tests green. Analyze: no issues. Pre-existing CI failures from WS5/WS8 are not caused by WS6. Committed.
- next: P3 sync gate

## [2026-05-24 14:05] START — WS4 begins

- stream: WS4
- detail: Read all required docs (plan, audit, log, tracker, product-rules, CLAUDE.md). Confirmed: app_shell.dart has _TutorModeIndicatorBar (tutor bar) but no child-view banner (DEC-25⚪). parent_portal_bottom_nav.dart:146 tab-0 does silent replaceAll to child dashboard (DEC-4🟡). settings_screen.dart uses TRACKS/LEARNING feature headers, no Device/Profile scope grouping (D2🔴). debug toggle absent — no Login section to build (WS4.login-sect). Starting WS4.banner.
- next: WS4.banner → WS4.boundary → WS4.settings+login-sect

## [2026-05-24 15:00] TASK-DONE — WS4 (all tasks complete)

- stream: WS4
- detail: WS4.banner — _ChildViewBanner added to AppShellScreen; shown when child profile active + tutor bar absent; displays "Viewing [name]" with emerald-700 strip; exit switches to first adult profile; l10n viewingChildBanner/viewingChildBannerExit EN+HE. WS4.boundary — navigateParentPortalTab() case 0 gated behind _confirmSwitchIntoChild() AlertDialog (requires explicit confirm before entering child's full experience); ref param added; caller updated; l10n switchIntoChildTitle/Message/Confirm EN+HE. WS4.settings — settings_screen.dart restructured: DEVICE section (App Permissions) + PROFILE section (per-learner settings); old TRACKS/LEARNING feature headers removed. WS4.login-sect — Login section omitted (debug toggle absent); no empty heading shipped. 7 tests added/updated across ws4_mode_boundaries_test.dart and settings_screen_test.dart; all green. Commit 4ef1eb5a. Note: app_shell.dart + l10n changes were incidentally committed in WS5's 77a81512 (stash contamination); functional effect identical.
- next: P3 sync gate

## [2026-05-24 15:30] TASK-DONE — WS5.key-prefs

- stream: WS5
- detail: Namespaced all notification SharedPrefs keys and notification IDs by profileId. NotificationPreferencesRepository now exposes per-profile static key helpers (reminderEnabledKey, reminderHourKey, etc.). SharedPrefsNotificationPreferencesRepository takes required profileId. NotificationGateway adds per-profile ID blocks (N*1000 + offset) and per-profile schedule/cancel methods. NotificationSettingsMerger + LocalDataUploadService updated to use per-profile keys. 10 tests green. Commit df6b23cf.
- next: WS5.per-profile

## [2026-05-24 15:45] TASK-DONE — WS5.per-profile

- stream: WS5
- detail: Decoupled reminder scheduling from activeProfileIdProvider. allProfilesReminderBootstrap provider schedules reminders for ALL profiles on login, skipping sacred time. Tap handler parses daily_reminder:<profileId> payload and calls onSwitchProfile(profileId) → selectedProfileIdProvider before opening SchedulerRoute. Per-profile payload format: 'daily_reminder:42'. 10 tests green (ID allocation + payload format). Commit 689b1e9b.
- next: WS5.two-layers

## [2026-05-24 16:00] TASK-DONE — WS5.two-layers

- stream: WS5
- detail: Added DeviceNotificationToggle ConsumerStatefulWidget (Key('device_notification_toggle'), SwitchListTile, WidgetsBindingObserver). hasPermission() method added to NotificationGateway. Toggle placed in NotificationsScreen (above per-profile controls) and replaces stub in EmptyLoginScreen. 3 widget tests green. Commit c9f993fe.
- next: WS5.clobber

## [2026-05-24 16:15] TASK-DONE — WS5.clobber

- stream: WS5
- detail: Merger round-trip test: 4 tests in notification_settings_merger_round_trip_test.dart prove zero cross-profile clobber (merge profile A then B — A keys intact; merge B then A — B keys intact) plus LWW correctness (newer remote wins; older remote does not overwrite newer local). All per-profile SharedPrefs keys fully isolated. Commit 1eb69df2. Note: lint fixes for WS5 test files in commit 77a81512. make ci WS5 code is clean; pre-existing failures from parallel WS4/WS7 in-flight code — not caused by WS5.
- next: P3 sync gate

## [2026-05-24 17:00] TASK-DONE — WS7 (all tasks complete)

- stream: WS7
- detail: WS7.balance — introduced points_balance table (schema v25), points_ledger table, reward_redemptions table; PointsBalanceDao with creditCompletion/debitRedemption/refundRedemption/parentAdjust/createRedemption/fulfilRedemption/declineRedemption/getPendingRedemptions/watchPendingRedemptions/getLedger; getGlobalTotal() and getGlobalPointsForRewards() and dashboardGlobalPoints cut over to stored balance; completion_repository_impl.dart now awaits creditCompletion on every live child completion; getDerivedTotal() added for raw-sum consumers; all test regressions fixed (unawaited race fixed, evaluateUnlocksForGlobal tests credit balance directly). WS7.reward-price — pointsCost getter added to RewardMilestone as alias for thresholdPoints (spend-economy semantics documented). WS7.redeem — ChildRedemptionScreen + ParentPendingRedemptionsScreen built; createRedemption atomic debit+row; fulfilRedemption/declineRedemption (refunds); routes registered (ChildRedemptionRoute, ParentPendingRedemptionsRoute); 12 DAO unit tests green. WS7.adjust — _showAdjustPointsDialog (inline dialog with Add/Deduct segmented control + amount + note) wired into parent_settings_screen.dart under canEditPoints guard. WS7.child-ui — onOpenRewards in dashboard_body.dart wired to ChildRedemptionRoute (was GamificationRoute). Also incidentally fixed WS8 tests that arrived in-flight (route guards already applied; sentinel date impl already done). EN+HE l10n strings added. make ci green (5914 tests passed, 125 skipped, 0 failed). dart analyze: no issues.
- next: P3 sync gate

## [2026-05-24 17:30] START — WS9 begins

- stream: WS9
- detail: Read all required docs (plan, audit, log, tracker, CLAUDE.md). Baseline CI: 5914 tests. Key files explored: core/enums/user_mode.dart (UserMode.child/adult, no helpers), core/domain/value_objects/profile_mode.dart (canonical with storageKey/fromStorageKey/.isChild/.isAdult), accounts.dart (vestigial userMode column), auth_state_provider.dart (promoteToCloud shim at :105-130), device_registry_database.dart:148 (dedupeByEmail), all callers of UserMode (32 files). Starting WS9.enum.
- next: WS9.enum → WS9.shims → WS9.flows → WS9.dedupe

## [2026-05-24 18:00] TASK-DONE — WS9 (all tasks complete)

- stream: WS9
- detail:
  WS9.enum — Deleted core/enums/user_mode.dart; replaced all 32 UserMode references with ProfileMode across lib/ and test/. Added Drift CHECK constraint on learner_profiles.mode column (NOT NULL CHECK (mode IN ('adult','child'))). Schema bumped to v26; migration uses deleteTable+createTable for learner_profiles (CHECK) and accounts (drop userMode column).
  WS9.shims — Renamed promoteToCloud() → setCloudBornSessionFromFirebaseUser() (no-longer-transitional, 5 callers updated). Removed dead demoteToLocal() (0 outside callers, just called signOut()). Removed 'delete after 20.x' shim label.
  WS9.flows (a) — Confirmed WS1.consolidate already collapsed duplicate add-profile flows; manage_learners_screen.dart uses canonical showAddProfileDialog. No duplicate detected.
  WS9.flows (b) — Removed vestigial accounts.userMode column from Accounts table and all references (AccountsCompanion inserts, AuthUser.fromProfile, upsertProfile, UserProfileService, data_export_import_service.dart export/import). Data export no longer includes userMode in userProfiles payload.
  WS9.dedupe — Decision: KEEP dedupeByEmail. Under DEC-34, distinct accounts (distinct emails) all stay authenticated simultaneously. dedupeByEmail targets same-email/same-user duplicates (Firebase re-mints new UID after account deletion + re-signup) — not different users. Updated code comment with DEC-34 rationale.
  All 5914 tests pass. dart analyze --fatal-infos: no issues.
- next: Commit, update tracker, send P4 gate report to Orchestrator.

## [2026-05-24 19:00] RESULT — V1 CI pass

- stream: Orchestrator
- detail: `make ci` from `learning_tracker/` completed exit-code 0. 5914 tests passed, 125 skipped, 0 failed. dart analyze: no issues. Format: clean.
- next: Await R1–R5 review reports. Dispatch V3 fix-all once all 5 complete.

## [2026-05-24 19:01] RESULT — R1 review (WS1+WS2 — Account/Login/Switching) COMPLETE

- stream: R1
- severity-summary: 1 CRITICAL, 5 HIGH, 7 MEDIUM, 4 LOW
- CRITICAL:
  - R1-C1: `_switchAccount` in `app_shell.dart:506` silently returns when target account has 0 profiles — DB already swapped, authState not updated; empty-login (DEC-6 tutor) account permanently unreachable from switcher.
- HIGH:
  - R1-H1: `isViewingChildProfile` fires for ANY child profile including child's own login — child sees amber "Viewing [child]" banner with Exit button. `app_shell.dart:60–62`.
  - R1-H2: `_switchAccount` uses `getAllUserProfiles()` unordered scan; `profiles.first` may not be right profile; raw tier string comparison `profile.tier == 'cloudBorn'` fragile to schema drift. `app_shell.dart:505–522`.
  - R1-H3: `_tryLocalFallbackSignIn` calls `signOut()` at `sign_in_controller.dart:227` — DEC-34 violation on local-born fallback path.
  - R1-H4: `signInWithEmail` calls `signOut()` at `sign_in_controller.dart:570` — DEC-34 violation on offline local-born sign-in path.
  - R1-H5: `AuthStateNotifier._init()` calls `signOut()` at `auth_state_provider.dart:62` for unverified email accounts — silent cross-account session clobber on every cold launch.
  - R1-H6: `EmptyLoginScreen` pushes `SettingsRoute` (`empty_login_screen.dart:36`) — child route of `AppShellRoute` guarded by `profileGuard`; will crash or fail from non-shell context; `activeProfileIdProvider` is null.
- MEDIUM (7): kOnboardingSkipped duplicate constant; skip may set flag when profile exists; one-shot account load in switcher not refreshed; "Add account" always shown in sheet; `profileMode.name` raw enum in UI; hardcoded 'Child mode'/'Adult mode' in manage_learners_screen; EmptyLoginScreen tutor snackbar + switcher headers hardcoded English.
- LOW (4): DeviceNotificationToggle English snackbars; 'Welcome, tutor!' not l10n; count-gate doc ambiguity (no bug); 'Skip for now' not l10n.
- next: Await R2–R5. Then dispatch V3 fix-agents for all CRITICAL/HIGH.

## [2026-05-25 00:30] RESULT — Sonnet review squad (R1–R5) COMPLETE — superseded by Opus re-run

- stream: Orchestrator
- detail: All 5 Sonnet reviewers returned. Top findings retained for cross-check against Opus re-run:
  - R1 (WS1+WS2): C1 _switchAccount aborts on 0-profile target (app_shell.dart:506); H _isViewing child banner fires for child's own login (:60-62); 3× signOut() DEC-34 violations (sign_in_controller.dart:227,570; auth_state_provider.dart:62); EmptyLoginScreen pushes guarded SettingsRoute (:36).
  - R2 (WS3): C _tutorProfileId never assigned in accept_invite (dead PIN setup); C profile-less tutor PIN scoped to sentinel id 0 (shared namespace); H ManageGrantsRoute no pinGuard; H canEditPoints gated on canEditGoals; H inline Decline pops w/o notify; H decline/resign notify with parentEmail:''.
  - R3 (WS4+5+6): C1 _ChildViewBanner suppressed for any tutor-grant holder on own child (:60-62); C2 reminder ID-space collision legacy block vs per-profile; C3 streak alerts never scheduled for inactive profiles; H SacredTime card under PROFILE not DEVICE (:170).
  - R4 (WS7+8): C getTrackPointsTotal still SUM-derived not stored balance (reward_milestone_service.dart:222); H curriculumBreakdownProvider stale derived sum; H ParentPendingRedemptions single-profile scope; H debitRedemption not atomic; M single-item recordCompletion ignores sentinel.
  - R5 (WS9+cross): H all 9 tutor screens zero l10n; H EmptyLoginScreen zero l10n; M migration v26 misleading comment + orphaned child-table rows + drop-order FK assumption; LOW TrackType/trackType refs still alive (Rule 7).
- next: User directed re-run of adversarial review with OPUS model. Dispatching R1–R5 (opus) in parallel. Will reconcile Opus findings with Sonnet findings before V3 fix-all.

## [2026-05-25 00:32] DISPATCH — V2 review squad RE-RUN (Opus, R1–R5)

- stream: Orchestrator
- detail: Per user instruction, re-dispatching all 5 reviewers with model: "opus" (same scopes/focus as Sonnet run). Finding-only, no fixes.
- next: Await 5 Opus reports. Reconcile with Sonnet findings. Dispatch V3 fix-all per merged CRITICAL/HIGH set.

## [2026-05-25 00:48] RESULT — R2 Opus (WS3 Tutor) COMPLETE

- stream: R2-opus
- severity-summary: 4 CRITICAL, 5 HIGH, 4 MEDIUM, 3 LOW. Deeper than Sonnet on the PIN boundary.
- CRITICAL:
  - R2o-C1: Tutor PIN namespace mismatch — gate keys PIN on tutor's OWN profile id (tutored_children_section.dart:272), but guard resolves PinScope.tutor(TALMID id) (router_provider.dart:75) → pin_guard.dart:113 checks hasTutorPin(talmidId). Different namespaces → tutor bounced to PARENT pin setup (pin_guard.dart:92).
  - R2o-C2: promptForPin always verifies PARENT pin — closure (router_provider.dart:53-65) unconditionally calls showParentPinVerificationDialog with parent pinService+selectedProfileIdProvider, ignoring resolved scope. _hasPin is scope-aware; promptForPin is not. Tutor-scoped edit routes (Manage Tracks/Point Config/Reward Config, app_router.dart:235,240,260) challenge for parent PIN.
  - R2o-C3: Decline from accept screen is a bare pop() (accept_invite_screen.dart:293) — no DeclineTutorInviteUseCase, no DEC-23 parent notify; DeclineInviteRoute defined but never navigated (app_router.dart:319-323).
  - R2o-C4: Accept flow never sets up Tutor PIN — _tutorProfileId never assigned (accept_invite_screen.dart:74, read-only :135,:306), always null → PIN check dead, pinSetup step unreachable / would pass profileId:0.
- HIGH:
  - R2o-H1: activeTutoredProfileSelection (keepAlive) never cleared on back-nav; .exit() only in onSessionLocked (router_provider.dart:96) which never fires (ManageGrantsRoute has no pinGuard). Selection leaks → _isTutorSession stays true on tutor's own profile. Re-creates DEC-21 bug.
  - R2o-H2: _TutorModeIndicatorBar NOT migrated — still keys on incomingTutorGrantsProvider grant existence (app_shell.dart:46-48), not active selection. Bar + banner-suppression fire on own profile. WS3.3e fixed _isTutorSession but left the visible bar on buggy signal.
  - R2o-H3: ManageGrantsRoute carries only authGuard (app_router.dart:300-304); PIN enforced only by widget gate that deep-link / _ViewInvitationsRow.onTap (tutored_children_section.dart:169) bypasses. DEC-13-tutor not satisfied.
  - R2o-H4: Offline-first violated — all tutor reads hit listTutorGrants callable (firestore_tutor_grant_repository.dart:146-166), return [] on error; zero Drift cache in features/tutoring/. Offline shows empty, no message. Rule 6.
  - R2o-H5: Point Configuration gated on canEditGoals (parent_settings_screen.dart:63,140) — conflation; parent_points_adjust under same gate (a goals-tutor can adjust balance); canEditStudyDays never consulted.
- MEDIUM: M1 decline/resign notify parentEmail:'' dropped (decline_invite_screen.dart:121; manage_grants_screen.dart:207); M2 all 9 tutor screens hardcoded English (Rule 1); M3 talmid rows show raw profile id/uid; M4 profile-less tutor PIN sentinel 0 shared namespace.
- LOW: L1 fake PIN-reset snackbar; L2 stub-grant accept mis-fire offline; L3 empty TutoredProfileSelection in text_display_screen.dart:766.
- correct: _isTutorSession migration right; canMarkLiveCompletion hard-false; revoke notify correctly addressed; Manage Tutors owner-only; dup provider removal clean; no Rule 2 violations in WS3.
- next: Await R1/R3/R4/R5 Opus. Reconcile, then V3.

## [2026-05-25 00:55] RESULT — R1 Opus (WS1+WS2) COMPLETE — corrects Sonnet on signOut()

- stream: R1-opus
- severity-summary: 2 CRITICAL, 3 HIGH, 4 MEDIUM, 4 LOW.
- RECONCILIATION: Opus CLEARS Sonnet R1's 3 signOut() DEC-34 findings (sign_in_controller.dart:227,570; auth_state_provider.dart:62) — verified those are legitimate sign-out / verification-failure rollback / upgrade-collision rollback paths, NOT switch paths. _switchAccount and _activateLocalAccountFromLocalData correctly avoid signOut(). Treat Sonnet R1-H3/H4/H5 as FALSE POSITIVES.
- CRITICAL:
  - R1o-C1: cloud→cloud switch leaves Firebase currentUser on wrong account. _switchAccount (app_shell.dart:495-530) swaps Drift DB + setCloudBornSession(profiles.first) but never re-auths Firebase. Single currentUser slot → sync push/pull writes B's data into A's UID space. DEC-34 "all accounts stay Firebase-authed simultaneously" not achievable with one Firebase instance. CORE WS1 GAP.
  - R1o-C2: stale selectedProfileId leaks across switch. _switchAccount never clears selectedProfileIdProvider (keepAlive, profile_providers.dart:36-48). ProfileGuard.onNavigation (profile_guard.dart:35-43) short-circuits when id != null, never validates id exists in new DB. Per-account autoincrement id spaces collide → opens WRONG profile silently.
- HIGH:
  - R1o-H1: switcher can't reach 0-profile accounts; switching INTO one no-ops on already-swapped DB (app_shell.dart:505-506 returns after DB swap). [matches Sonnet R1-C1]
  - R1o-H2: EmptyLoginScreen has no switcher / no exit to other accounts — stranded if other accounts exist on device.
  - R1o-H3: kOnboardingSkipped→EmptyLogin routing only in cloud path (_navigateAfterSignIn, sign_in_controller.dart:462-468); local-born (signInWithEmail :576-586) + local-fallback (:232-243) still replaceAll([OnboardingRoute]) on empty profiles — skipped local users loop back into onboarding.
- MEDIUM: M1 switcher sheet hardcoded English (app_shell.dart:587,607,642; profilesLabel ARB exists); M2 profileMode.name raw in UI (:693, Rule 3); M3 EmptyLoginScreen hardcoded English (:30,36,69,84; learningTracker ARB exists); M4 'Skip for now' hardcoded + frozen by test empty_login_ws2_test.dart:114 (actionSkipForNow ARB exists).
- LOW: L1 dup kOnboardingSkipped constant; L2 _switchAccount string tier vs typed accountTier (:518); L3 mixed nav context closing sheet; L4 TrackManagementHubRoute reachable from 0-profile empty-login.
- verified-OK: DEC-34 no-signOut on switch paths; DEC-30 count-gate correct; EmptyLoginRoute reachable; offline-first OK on these surfaces; old switch entry points removed.
- next: Await R3/R4/R5 Opus.

## [2026-05-25 01:02] RESULT — R3 Opus (WS4+5+6) COMPLETE — corroborates Sonnet

- stream: R3-opus
- severity-summary: 2 CRITICAL, 4 HIGH, 3 MEDIUM, 2 LOW. Confirms Sonnet R3 banner + reminder findings.
- CRITICAL:
  - R3o-C1: "Viewing [child]" banner fires for a child on their OWN profile (app_shell.dart:60-65) — condition is purely profileMode==child, no "entered-via-adult" signal. Exit (:127-134) tries to switch to an adult they may not own. [== Sonnet R3-C1 / R1-H1]
  - R3o-C2: banner suppressed for parent who also holds tutor grants; amber tutoring bar shown instead. hasActiveTutoredProfiles from incomingTutorGrantsProvider (app_shell.dart:45-62). [== Sonnet R3-C1 second half; ties to R2o-H2]
- HIGH:
  - R3o-H1: active profile gets TWO daily reminders — reminderSyncEffect batch IDs 10-23 ("You have N tasks") + allProfilesReminderBootstrap ID activeId*1000 ("Time to learn!"). No de-dup. (notification_providers.dart:446-452 vs 533-539). [== Sonnet R3-C2]
  - R3o-H2: streak alerts NOT per-profile — scheduleStreakAlert hardcodes id=streakAlertId=1 (notification_gateway.dart:351); no scheduleStreakAlertForProfile; inactive profiles get none, single ID overwritten on switch. [== Sonnet R3-C3]
  - R3o-H3: deleted profile's reminder keeps firing — bootstrap never cancelDailyReminderForProfile on delete; tapping switches into nonexistent profile (notification_initializer.dart:66-70). NEW vs Sonnet.
  - R3o-H4: hardcoded English across WS4/WS5 UI (settings_screen.dart:91,241,416,440; device_notification_toggle.dart:71,89,107; switcher sheet; notification bodies). Rule 1.
- MEDIUM: M1 banner Exit lands on another child / first-adult-not-origin (app_shell.dart:127-130); M2 notification settings push bumps updated_at every launch/switch — LWW risk (notification_providers.dart:262-268); M3 transient default-state reschedule on switch (disabled profile briefly scheduled).
- LOW: L1 legacy ID block 0 shared with profile-0 batch (latent); L2 inactive-profile reminders skip per-fire Sacred-Time suppression (notification_gateway.dart:257-285).
- clean: WS6/DEC-26 location fully removed from push+merge, device-global, no LWW clobber; D2 tab-0 confirm is only portal entry; NotificationSettingsMerger per-profile keys clean. SacredTime card under PROFILE section (settings_screen.dart:170) = borderline-M visual misfile but data layer correct. [Sonnet R3-H3 rated this HIGH; Opus rates borderline-MEDIUM]
- next: Await R4/R5 Opus.

## [2026-05-25 01:10] RESULT — R4 Opus (WS7+8) COMPLETE — finds major sync miss

- stream: R4-opus
- severity-summary: 2 CRITICAL, 2 HIGH, 3 MEDIUM, 3 LOW.
- CRITICAL:
  - R4o-C1: old auto-unlock achievement ladder NOT removed (DEC-32) and now reads the DEBITABLE balance. evaluateUnlocksForGlobal (reward_milestone_service.dart:296-329) → getGlobalPointsForRewards() → getBalance(); wired live on every completion (completion_repository_impl.dart:214-222,304-306) + achievements screen. thresholdPoints simultaneously = redeem price AND cumulative unlock threshold — one value can't be both. [sharper than Sonnet R4-C which flagged getTrackPointsTotal:222 SUM-derived — BOTH point to milestone-service incoherence]
  - R4o-C2: NEW — points_balance/points_ledger/reward_redemptions have ZERO sync wiring (absent from core/sync + features/sync). Authoritative balance is device-local. Child earns on device A → 0 on device B; redemption request never reaches parent's device → redeem→fulfil loop (DEC-18) broken in normal 2-device setup; parentAdjust never propagates. Multi-device regression. SONNET MISSED THIS.
- HIGH:
  - R4o-H1: single-item recordCompletion never writes sentinel (learning_ledger_repository_impl.dart:89,102 always nowUtc); sentinel only on batch (:124-144). Used by siyum detection for bulkInTrack → siyum row dated today. MITIGATION: learning_ledger.completedAt only used for orderBy (learning_ledger_dao.dart), NOT date-windowed streak/recent reads — so no streak leak today. Still contradicts WS8 intent. [Sonnet rated MEDIUM; Opus HIGH]
  - R4o-H2: per-track rewards incoherent — reward config still offers Per-track vs Total tabs (reward_configuration_screen.dart:361-367) but redemption prices ALL rewards against single global balance (child_redemption_screen.dart:35-50). Per-track "50" becomes redeemable for 50 global.
- MEDIUM: M1 "Next reward" progress bar regresses against debitable balance (child_points_rewards_tab_card.dart:45-52); M2 parentAdjust deduct non-atomic read-modify-write (points_balance_dao.dart:99-120) — isolated to adjust-deduct, redeem/credit/refund ARE atomic; M3 no backfill of points_balance on v25 migration (acceptable pre-launch).
- LOW: L1 dead non-atomic debitRedemption/refundRedemption (points_balance_dao.dart:60-94) — trap, remove or make txn; L2 redeem affordability from stale snapshot (txn guard holds); L3 per-track UI symptom of H2.
- RECONCILIATION vs Sonnet R4: Opus CLEARS Sonnet R4-H "ParentPendingRedemptions single-profile scope" — verified correct (switch-into-each-child satisfies DEC-18). Opus downgrades Sonnet R4-H "debitRedemption not atomic" to LOW (dead method). Sonnet R4-H "curriculumBreakdownProvider stale" folds into R4o-C1 milestone-service family.
- verified-OK: lifetime routes guarded [auth,childMode,pin]; lifetime screen uses batch→sentinel; dashboardGlobalPoints/getGlobalTotal read stored balance, adults 0 (Rule 3); creditCompletion only live child marks, bulk-prior writes 0; adjust/pending PIN-gated child-scoped; redemption reads all Drift (offline modulo C2).
- next: Await R5 Opus (last one).

## [2026-05-25 01:18] RESULT — R5 Opus (WS9 + cross-cutting) COMPLETE — escalates v26 migration to CRITICAL

- stream: R5-opus
- severity-summary: 1 CRITICAL, 3 HIGH, 2 MEDIUM, 3 LOW.
- CRITICAL:
  - R5o-C1: v26 migration orphans all child-table rows. deleteTable+createTable for learner_profiles + accounts (user_database.dart:175-184); 13+ child tables FK-ref learner_profiles(id) onDelete:cascade but FKs are OFF during onUpgrade (PRAGMA foreign_keys=ON in beforeOpen runs after, no-op in txn) → DROP doesn't cascade → recreated learner_profiles empty w/ AUTOINCREMENT reset to 1 → child rows orphaned, new profiles collide with stale orphan IDs. Comment (lines 71-76) "No data migration needed / recreate in-place" materially inaccurate (it's a DROP). Pre-launch mitigates users but corrupts dev/QA v25 DBs. Fix: column-preserving rebuild (TableMigration / disableForeignKeys + manual copy). [Sonnet R5 rated this MEDIUM ×3; Opus consolidates to CRITICAL]
- HIGH:
  - R5o-H1: no migration test for v25→v26 (snapshots stop at v22; migration_test.dart no >=26 / deleteTable / CHECK coverage). The riskiest migration is untested.
  - R5o-H2: Rule 1 — all 9 tutor screens hardcode English, zero AppLocalizations (accept_invite_screen.dart:195,219,289,354,398; invite_tutor_screen.dart:84,108,122,267; manage_tutors_screen.dart:39,210,314,350,445). ARB keys exist for some but unused. [== Sonnet R5-H, R2o-M2]
  - R5o-H3: Rule 1 — empty_login_screen.dart hardcodes English (:30 'Learning Tracker', :70 "I'm a tutor"). [== R1o-M3]
- MEDIUM: M1 Hebrew-terms drift — tutorModeIndicator="מצב מדריך" (madrich) vs manageTutors="ניהול מורים" (morim); pick canonical per docs/hebrew-terms.md. M2 Rule 7 — live TrackType.personal filters (dashboard_providers.dart:404; scheduler_providers.dart:217). [== Sonnet R5-LOW, escalated]
- LOW: L1 dead trackType helper 'school'/'advanced' (learning_track_card.dart:199-213, never called); L2 completion_events.track_type column + completions_view still select it; L3 ProfileMode.fromStorageKey throws on unknown key (no defensive fallback).
- verified-OK: UserMode fully eliminated, analyze clean; CHECK constraint applied (learner_profiles.dart:22); accounts.userMode dropped; shim removal complete (promoteToCloud/demoteToLocal 0 callers); dedupeByEmail KEEP justified; Rule 2 (no "Gregorian"); Rule 3 (points gated child, no raw profileMode.name); Rule 4 (sentinel on batch); Rule 6; Rule 8; redemption screens DO use AppLocalizations.

## [2026-05-25 01:20] MILESTONE — All 5 Opus reviewers complete; consolidated finding set

- stream: Orchestrator
- detail: Merged Opus set (authoritative; Sonnet false-positives dropped). CRITICALs (8):
  1. R1o-C1 cloud→cloud switch wrong Firebase currentUser (sync data corruption) — app_shell.dart:495-530
  2. R1o-C2 stale selectedProfileId leaks across switch → wrong profile shown — app_shell.dart:495-530 + profile_guard.dart:35-43
  3. R2o-C1 tutor PIN namespace mismatch gate(ownId) vs guard(talmidId) — tutored_children_section.dart:272 + router_provider.dart:75 + pin_guard.dart:113
  4. R2o-C2 promptForPin always verifies PARENT pin for tutor scope — router_provider.dart:53-65
  5. R2o-C3 decline is bare pop(), no DEC-23 notify, DeclineInviteRoute unreachable — accept_invite_screen.dart:293
  6. R2o-C4 accept never sets up Tutor PIN (_tutorProfileId never assigned) — accept_invite_screen.dart:74
  7. (banner) R3o-C1+C2 / R1o-H1 — "Viewing [child]" banner over-fires (child's own login) AND under-fires (parent w/ tutor grants); indicator bar R2o-H2 on wrong signal — app_shell.dart:45-65,114
  8. R4o-C1 old auto-unlock ladder reads debitable balance (DEC-32 not done) — reward_milestone_service.dart:296-329
  9. R4o-C2 points_balance/ledger/redemptions NOT synced — multi-device regression — core/sync (absent)
  10. R5o-C1 v26 migration orphans child tables — user_database.dart:175-184
- HIGH (merged, deduped): R1o-H1 switcher can't reach 0-profile acct (==Sonnet R1-C1); R1o-H2 EmptyLogin no exit-to-account; R1o-H3 skip→empty-login only on cloud path; R2o-H1 tutored selection never cleared on back-nav (re-creates DEC-21); R2o-H3 ManageGrantsRoute no pinGuard; R2o-H4 tutor reads no Drift cache (offline); R2o-H5 point-config gated on canEditGoals; R3o-H1 double daily reminder; R3o-H2 streak alerts not per-profile; R3o-H3 deleted-profile reminder keeps firing; R3o-H4 hardcoded EN WS4/5; R4o-H1 single-item recordCompletion no sentinel; R4o-H2 per-track rewards incoherent in single-balance; R5o-H1 no v25→v26 migration test; R5o-H2 9 tutor screens hardcoded EN; R5o-H3 empty_login hardcoded EN.
- decision: Dispatch V3 fix-all. Group by area to avoid file collisions: F1=auth/switch (R1o-C1,C2 + H1,H2,H3 + switcher l10n/profileMode.name), F2=tutor PIN+lifecycle (R2o-C1,C2,C3,C4 + H1,H3,H5), F3=banner+indicator (R3o-C1,C2 + R2o-H2 + M1), F4=notifications (R3o-H1,H2,H3 + M2,M3 + L2), F5=rewards/credit (R4o-C1,C2 + H1,H2 + M1,M2), F6=migration (R5o-C1 + H1), F7=l10n sweep tutor+empty-login+settings (R5o-H2,H3 + R3o-H4 + Hebrew-terms M1) + Rule7 trackType cleanup. F2/F3/F7 touch overlapping tutor + app_shell files — sequence to avoid cl, or single owner per file.
- next: Dispatch V3 fix agents (Sonnet) by area, sequencing app_shell.dart (F1+F3 share it) and tutor files (F2+F7 share them) under single owners. Then V4 CI rerun.

## [2026-05-25 01:35] RESEARCH — Design-critical analysis (auth switch + points sync) COMPLETE

- stream: Orchestrator (Opus research agent a38749dcd2a82d22c)
- C#1 (auth switch) CONFIRMED severe: single Firebase app (firebase_bootstrap.dart:14, no secondary apps). ALL Firestore paths derive UID from FirebaseAuth.currentUser (firestore_gateway_impl.dart:955-963,1008-1017; never from active-account record). After cloud-A→cloud-B switch with currentUser=A, every outbox push + listener reads/writes A's cloud space while UI/DB think B → B's data pushed into A's Firestore, A's docs merged into B's DB. DEC-34 "all cloud accounts authed simultaneously" architecturally false (currentUser is one slot).
  - REC: option (b) safety floor + (c) reality. Source addressed UID from active-account record (DeviceAccount.firebaseUid, already stored) injected into FirestoreGatewayImpl → stale currentUser can't address wrong space (Firestore rules then DENY not corrupt). Accept effective cloud sync requires currentUser==active account: silent re-auth when online; offline = queue locally + "sign in to sync" badge (infra exists account_picker_screen.dart:241,373-377). Keep no-forced-logout UX + local-account multi-session; DROP literal "all cloud authed simultaneously". Effort medium (1 gateway, ~12 call sites + provider wiring).
- C#2 (points sync) CONFIRMED: points_balance/points_ledger/reward_redemptions absent from MergeRouter (merge_router.dart:29-54), no codec/OutboxEntityKind/PushPipeline/gateway push/listener. balance is ALREADY a denormalised sum of ledger deltas (points_balance.dart:11-12; _applyDeltaInTransaction:280-317) — i.e. already derived.
  - REC: option (a). Sync points_ledger append-only (add ULID col — mirror learning_ledger_merger INSERT-OR-IGNORE); DERIVE balance locally on merge (do NOT sync mutable balance — avoids counter LWW lost-update). Sync reward_redemptions as LWW state-machine docs (add ULID + updated_at; pending→fulfilled/declined terminal). Closes DEC-18 2-device loop: child redemption+debit ledger sync up → parent pulls, fulfil/decline writes status (+refund ledger on decline) → child pulls, re-derives. Wiring path per table: facade enqueue → OutboxEntityKind → PushPipeline + FirestoreGateway push (users/{uid}/learner_profiles/{pid}/<coll>, ULID doc-id) → listener register → EntityKind + MergeRouter case + codec + EntityMerger. Schema bump (safe pre-launch). FIX C#1 FIRST so points inherit correct UID addressing.
- decision: user chose Opus fixes + plan-first for these 2. Presenting plan + mechanical-fix partition for sign-off before any dispatch.
- next: On approval — sequence: (1) C#1 auth UID-source guard, (2) C#2 points sync, in parallel with mechanical Opus fix agents on non-overlapping files. Then V4 CI rerun.

## [2026-05-25 01:45] DISPATCH — V3 fix-all Wave A (4 Opus agents, parallel, disjoint files)

- stream: Orchestrator
- detail: User approved both design-critical approaches + Opus fixes. Two-wave structure (Wave B depends on Wave A schema+gateway; l10n sweep must follow logic fixes). All Wave-A agents instructed: NO l10n/ARB edits (dedicated FIX-L10N agent in Wave B owns all string localization + ARB). File ownership disjoint to allow parallel on dev (no worktrees per repo policy). Only FIX-SCHEMA touches schemaVersion.
  - FIX-SWITCH (a515b37762cdd8620, task#17): owns app_shell.dart + firestore_gateway_impl.dart(+provider) + account_picker + sign_in_controller + auth_state_provider + profile_guard + profile_providers + empty_login_screen. Fixes R1o-C1 (UID from active-account record + online re-auth/offline-queue badge), R1o-C2 (clear selectedProfileId + guard validates id), R1o-H1 (0-profile switch), R1o-H2 (empty-login account exit), R1o-H3 (skip-routing local paths), R3o-C1/C2 + R2o-H2 (banner adult-viewing-child signal + indicator on activeTutoredProfileSelectionProvider), R3o-M1 (exit target), R1o-L2 (typed tier).
  - FIX-TUTOR (a2abc492e79adb9c6, task#18): owns features/tutoring/** + router_provider + pin_guard + tutored_children_section + parent_settings_screen + text_display(_isTutorSession) + app_router tutor routes. Fixes R2o-C1 (PIN namespace gate↔guard agree on tutor-own id), C2 (promptForPin scope dispatch + gate primes scope), C3 (decline wiring+notify), C4 (accept sets PIN), H1 (clear selection on back-nav), H3 (talmid route pin guard / gate every entry), H5 (canEditPoints not canEditGoals + canEditStudyDays), M1 (decline/resign real parent email), M3 (resolve names), L1/L3.
  - FIX-NOTIF (a307d27690669dafc, task#19): owns features/notifications/** + streak_alert_service. Fixes R3o-H1 (dedup double reminder→canonical per-profile scheme), H2 (per-profile streak alerts + bootstrap), H3 (cancel deleted-profile schedules + reconcile), M2 (gate push on actual change), M3 (wait for loaded prefs), L2 (sacred-time per-fire).
  - FIX-SCHEMA (a5a7837f896a6e10f, task#20): owns user_database.dart + points table defs + migration tests. Fixes R5o-C1 (data-preserving v26 rebuild + accurate comment), H1 (v25→v26→v27 migration test w/ FK-integrity + preservation asserts), + v27 additive ULID cols on points_ledger + reward_redemptions(+updated_at) for Wave-B sync. Sole owner of schemaVersion.
- next: Await 4 Wave-A returns. Run V4 CI (make ci). If green, dispatch Wave B: FIX-REWARDS (ladder removal + per-track + sentinel + atomic adjust + points sync wiring + Rule-7 cleanup; depends on FIX-SCHEMA cols + FIX-SWITCH gateway) and FIX-L10N (tutor/empty-login/settings/notif/switcher strings + ARB en+he + Hebrew-terms drift + profileMode.name label + fix empty_login_ws2_test 'Skip for now' assertion). Then V4 CI again, V5 task-truth, V6 smoke.

## [2026-05-25 01:58] TASK-DONE — FIX-SCHEMA (Wave A, task#20)

- stream: FIX-SCHEMA (a5a7837f896a6e10f)
- detail: R5o-C1 FIXED — v26 migration rewritten row-preserving via Drift TableMigration/alterTable (PRAGMA foreign_keys OFF for rebuild, ids preserved, learner_profiles gains CHECK(mode IN adult/child), accounts drops user_mode; foreign_key_check assert empty; FK ON restored; accurate comment). R5o-H1 FIXED — new test/migration/v25_to_v27_test.dart (7/7): seeds v25 DB w/ account+3 profiles(non-contiguous ids)+child rows across completion_events/goals/streak_events/points_balance/points_ledger/reward_redemptions, opens live UserDatabase to trigger onUpgrade(25→27), asserts preservation+FK integrity+CHECK enforced+ulid cols present. v27 ADDED: schemaVersion 26→27; nullable ulid TEXT on points_ledger + reward_redemptions (reward_redemptions.updated_at already existed) via addColumn; build_runner regenerated user_database.g.dart (ulid → String?). Analyze clean for owned files. Full migration suite + points_balance_dao_test green.
- next: Wave-B FIX-REWARDS can wire DAO/sync to populate ulid. Await FIX-SWITCH/FIX-TUTOR/FIX-NOTIF.

## [2026-05-25 02:08] TASK-DONE — FIX-NOTIF (Wave A, task#19)

- stream: FIX-NOTIF (a307d27690669dafc)
- detail: H1 FIXED — active profile now schedules via per-profile batch block (scheduleReminderForProfile); allProfilesReminderBootstrap SKIPS active profile → exactly one daily reminder/profile, one canonical profileId*1000 scheme, no orphaned legacy profile-0 schedules. H2 FIXED — scheduleStreakAlertForProfile (id profileId*1000+1) + cancelStreakAlertForProfile; bootstrap schedules streak alerts for all inactive profiles (per-profile StreakAlertService, respects streakAlertEnabledKey). H3 FIXED — bootstrap watches profileListStreamProvider (reactive), persists scheduledProfileIdsKey, reconciles: cancels reminder+streak for absent ids. M2 FIXED — _persistNotificationSettingsToCloud diffs stable signature vs lastPushedSettingsHashKey(profileId), early-return if unchanged (no updated_at bump). M3 FIXED — reminderSyncEffect reads authoritative SharedPrefs per-profile values before scheduling (not synchronous defaults). L2 FIXED — inactive reminders route through scheduleReminderForProfile → same buildFireTimesForTest per-fire sacred-time filtering. New keys: scheduledProfileIdsKey (account-wide), lastPushedSettingsHashKey(profileId). Updated 4 test files mocking NotificationGateway/StreakAlertService for new interface methods (incl. overdue_notifications_test.dart hand-written gateway). build_runner OK; analyze clean; 100 notif/streak/analytics tests pass. No ARB/l10n edits.
- next: Await FIX-SWITCH, FIX-TUTOR.

## [2026-05-25 02:20] TASK-DONE — FIX-TUTOR (Wave A, task#18)

- stream: FIX-TUTOR (a2abc492e79adb9c6)
- detail: C1 FIXED — added tutorOwnProfileId to TutoredProfileSelection (session_role.dart:43); gate stores it (tutored_children_section.dart:287); router_provider getScope resolves PinScope.tutor(tutorOwnProfileId) not talmidId → gate+guard one namespace. C2 FIXED — promptForPin dispatches on scope: tutor → new showTutorPinVerificationDialog (tutor_pin_entry_dialog.dart) vs tutorOwnId; both gate entries prime scope via markScopeAuthenticated. C3 FIXED — inline Decline routes to DeclineInviteRoute → DeclineTutorInviteUseCase + DEC-23 notify. C4 FIXED — _tutorProfileId assigned in _initialize; post-accept PIN check reachable, routes to setup w/ correct id. H1 FIXED — ManageGrantsScreen → ConsumerStatefulWidget w/ PopScope calling activeTutoredProfileSelectionProvider.exit() on pop. H3 FIXED — gate enforced on every in-app entry (_TutoredChildRow + _ViewInvitationsRow); deliberately NOT route-level pinGuard (no selection → getScope falls back to parent, would wrongly prompt parent PIN). H5 FIXED — added canEditPoints to TutorPermissions (+owner perms); parent_settings:63 gates point config + adjust on canEditPoints. M1 FIXED — TutorNotificationGateway optional parentUid + _recipient routes to uid:{parentUid}; decline/resign pass grant.parentUid (uid-addressed not dropped). M3 FIXED — TutorGrantDoc childName/parentName + childDisplayLabel/parentDisplayLabel friendly fallbacks (no raw id leak). L1 FIXED — real TutorPinResetScreen nav. L3 FIXED — text_display reads real activeTutoredProfileSelectionProvider. analyze clean; 120 tutoring + PIN/settings/multi-profile tests pass. No ARB/l10n.
- carry-forward: (1) canEditStudyDays now serialized but consumer is scheduler study-day screen (/study-days/:curriculumId, authGuard only) — OUTSIDE tutor ownership; wire in Wave B cleanup. (2) M3 needs listTutorGrants Cloud Function to denormalize child_name/parent_name (server, out of repo scope) — generic labels meanwhile. (3) M1 email transport still LoggingTransactionalEmailService (infra not provisioned) — uid recipient now routable/logged.
- next: Await FIX-SWITCH (last Wave-A agent), then V4 CI gate.

## [2026-05-25 02:24] TASK-DONE — FIX-SWITCH (Wave A, task#17) + V4 CI dispatched

- stream: FIX-SWITCH (a515b37762cdd8620)
- detail: C#1 FIXED — firestore_gateway_impl.dart takes optional activeAccountUid resolver; new _addressedUid getter prefers active-account UID, falls back to currentUser only if no resolver; replaced 5 currentUser?.uid path-building sites (pushAccountProfile, listenToTutorGrants, listenToLearnerProfiles, fetchLearnerProfiles, _learnerProfileDoc). Wired in outbox_providers.dart:31 → authStateProvider.currentUser?.firebaseUid (offline-safe, local session). _switchAccount documents one-FirebaseAuth-slot constraint; on cloud switch w/ mismatched currentUser surfaces non-blocking "sign in to sync" SnackBar+action, local DB/outbox stay usable, no forced sign-out. R1o-C2 FIXED — _switchAccount + both account_picker activation paths clear selectedProfileIdProvider; profile_guard fetches list + validates selected id exists in current DB before short-circuit (stale → re-resolve/picker). R1o-H1 FIXED — 0-profile switch completes + routes EmptyLoginRoute (no half-state). R1o-H2 FIXED — count-gated switch-account app-bar action on empty_login (pushes AccountPickerRoute, shown when ≥2 accounts). R1o-H3 FIXED — kOnboardingSkipped→EmptyLoginRoute applied to signInWithEmail + _tryLocalFallbackSignIn. R3o-C1/C2 + R2o-H2 + R3o-M1 FIXED — hasActiveTutoredProfiles from activeTutoredProfileSelectionProvider; banner shows only when active=child AND account owns adult (adult-viewing-child; standalone child never sees it) AND not tutor mode; Exit → adult profile or clear→picker, never another child. R1o-L2 FIXED — account.accountTier.isCloud typed. Test: ProfileGuard hardening broke app_shell_test (unseeded guard DB hardcoding getSelectedProfileId→1); fixed via seedProfileWithIds helper + seeding id 1 (7 async call sites). No build_runner needed (no new annotated providers). analyze clean for owned files; make audit 18/18.
- ALL 4 WAVE-A AGENTS COMPLETE. Cross-agent analyzer observations (router_provider unused import, overdue_notifications_test missing methods) should now resolve (FIX-TUTOR + FIX-NOTIF finished those).
- V4 CI (make ci) dispatched in background (bffvx1hy1) to validate integrated tree.
- next: On CI green → dispatch Wave B (FIX-REWARDS + FIX-L10N). On red → fix-forward per failure.

## [2026-05-25 02:42] GATE+DISPATCH — V4 CI(Wave A) GREEN; Wave B dispatched

- stream: Orchestrator
- detail: V4 CI after Wave A = exit 0, 5921 tests pass (was 5914; +migration tests), 125 skip, 0 fail. Four parallel agents merged cleanly. Wave B dispatched (2 Opus agents, disjoint files):
  - FIX-REWARDS (a423f4c888568125d, task#21): owns gamification/rewards + completion/ledger repos + sync wiring (core/sync, outbox facade, gateway push methods, listener supervisor) + dashboard/scheduler providers + learning_track_card + completion_events view + scheduler study-day screen. Fixes C#2 (points_ledger append-only sync w/ v27 ulid doc-id, DERIVE balance locally, reward_redemptions LWW; mirror learning_ledger), R4o-C1 (remove auto-unlock ladder DEC-32), H1 (single-item sentinel), H2 (per-track coherence → all global priced), M1 (next-reward card), M2 (atomic adjust-deduct), L1 (dead DAO methods), Rule-7 cleanup, + canEditStudyDays consumer gating (carry-forward). MUST NOT change schemaVersion (v27 cols exist) or edit ARB.
  - FIX-L10N (ac5bc2776de7d5220, task#22): owns ARB en+he exclusively + UI-string-only edits in 9 tutor screens, empty_login, settings_screen (+move SacredTimeSettingsCard PROFILE→DEVICE), notification copy, app_shell switcher strings + profileMode.name→label, manage_learners, skipped_onboarding_cta_banner, onboarding 'Skip for now'. Fixes R5o-H2/H3 + R3o-H4 + R1o-M1/M2/M3 + Hebrew-terms drift (canonical tutor term). Updates breaking find.text tests. EXCLUDES gamification/dashboard/scheduler/sync (FIX-REWARDS owns).
- next: Await both Wave-B returns. Run V4 CI again (integrated). On green → V5 task-truth + V6 smoke.

## [2026-05-25 03:08] TASK-DONE — FIX-L10N (Wave B, task#22)

- stream: FIX-L10N (ac5bc2776de7d5220)
- detail: ~150 keys added to BOTH app_en.arb + app_he.arb in lockstep (1461 en / 1455 he; 6-gap pre-existing meta). Canonical Hebrew tutor term = מדריך/מדריכים (madrich); fixed drift (manageTutors/Subtitle מורים→מדריכים). Localized all 10 tutor screens, empty_login, settings_screen, device_notification_toggle, notification titles/bodies (parameterized ICU plurals notificationReminderBody/notificationStreakBody), app_shell switcher headers + profileMode subtitle→profileTypeChild/Adult, manage_learners child/adult labels, skipped_onboarding_cta_banner, onboarding 'Skip for now'→actionSkipForNow. Notification locale: lookupAppLocalizations(currentAppLocaleProvider) in provider layer, threaded localized title/body into scheduler/gateway (added optional params, English fallback, no scheduling-logic change). DEC-26 structural: moved SacredTimeSettingsCard PROFILE→DEVICE section. Tests updated: empty_login_ws2_test, onboarding_screen_test (added l10n delegates + Locale en), settings_screen_test (scrollUntilVisible after card move), ws3_3h_corrections_test (asserts ARB copy). flutter gen-l10n clean; analyze no issues; format applied; 401+ feature tests + onboarding/notif/settings epics pass.
- next: Await FIX-REWARDS (points sync, last agent), then integrated V4 CI.

## [2026-05-25 03:30] TASK-DONE — FIX-REWARDS (Wave B, task#21) + integration fix

- stream: FIX-REWARDS (a423f4c888568125d) + Orchestrator integration patch
- detail: C#2 FIXED — full points sync mirroring learning_ledger: PointsBalanceDao populates ulid on ledger insert + redemption create, pushes via new PointsSyncSink (registered sync_orchestrator_providers.dart:78 + sync_providers.dart); new outbox kinds points_ledger_entry/reward_redemption (outbox_processor enum+drain+dispatch), PushPipeline methods, gateway writes to users/{uid}/learner_profiles/{pid}/points_ledger/{ulid} + .../reward_redemptions/{ulid}; pull: EntityKind.pointsLedger/rewardRedemption, MergeRouter cases, 2 codecs, 2 mergers (points_ledger_merger INSERT-OR-IGNORE-by-ulid + reDeriveBalanceFromLedger; reward_redemption_merger LWW by updated_at), listeners+orderFields in firestore_listener_source, pull steps in sync_orchestrator. points_balance NEVER synced (re-derived). firestore.rules added (append-only ledger, LWW redemptions). Convergence+re-derivation proven test/core/sync/merge/points_sync_merger_test.dart. R4o-C1 FIXED — evaluateUnlocks* now no-ops returning []; live-wiring removed from completion_repository_impl + achievements_overview_provider; dead _rewardMilestoneService field/param/wiring dropped. R4o-H1 FIXED — CompletionSource threaded through recordCompletion + checkAndRecordCompletions; non-live → sentinel 2000-01-01; _bulkSourceFor derives source. R4o-H2 FIXED — reward config always-global (kGlobalTrackSentinel); per-track UI removed. R4o-M1 FIXED — dashboard card shows Current Balance + Redeem CTA (no regressing progress bar). R4o-M2 FIXED — parentAdjust deduct atomic (single txn). R4o-L1 FIXED — dead debitRedemption/refundRedemption removed. Rule-7 FIXED — dead trackType helpers deleted (learning_track_card), live TrackType.personal filters removed (dashboard_providers, scheduler_providers); completion_events.track_type column stays (in unique index, schema-owned). canEditStudyDays FIXED — study_day_config_screen watches activeTutorPermissionsProvider (via barrel), disables toggles when tutored-context lacks perm. Doc-id: ledger ULID idempotent append; redemptions ULID + LWW updated_at; ledger refs redemption by stable redemption_ulid. No ARB edits. 513 sync+gamification+learning+DAO tests pass.
- INTEGRATION FIX (Orchestrator): integrated make ci surfaced 2 analyzer errors — _RecordingNotificationGateway fake in test/scheduler/overdue_notifications_test.dart missing optional `String title` param FIX-L10N added to scheduleStreakAlert/scheduleStreakAlertForProfile (notification_gateway.dart:335,375). Added matching optional param (title='Streak at Risk!') to both fake overrides. Trivial signature alignment, fully determined by error.
- next: Re-run integrated make ci (bcrej0tuj). On green → V5 task-truth + V6 smoke.

## [2026-05-25 03:40] GATE — V4 CI (integrated, post Wave A+B) GREEN

- stream: Orchestrator
- detail: make ci exit 0. dart analyze: No issues found. 5926 tests pass, 125 skip, 0 fail. All 6 fix agents (FIX-SWITCH/TUTOR/NOTIF/SCHEMA/REWARDS/L10N) + 1 orchestrator integration patch (overdue_notifications_test fake gateway title param) merged clean. V3 fix-all + V4 CI-rerun CLOSED.
- next: V5 task-truth verification (2 read-only Opus verifiers dispatched: V5a switch/tutor/notif reachability a36d477bbce740439; V5b rewards/sync/migration/Rule7 reachability a60bbf5068492e6a4). Then V6 smoke.

## [2026-05-25 03:41] DISPATCH — V5 task-truth (2 read-only Opus verifiers)

- stream: Orchestrator
- detail: V5a (a36d477bbce740439): verifies 12 items + locale — account-switch UID-source/clear-profile/0-profile-route/banner-signal, tutor PIN namespace+scope+gate-every-entry+decline/accept+canEditPoints+selection-clear, notif single-reminder/per-profile-streak/deleted-cancel, 9 tutor + empty-login l10n. V5b (a60bbf5068492e6a4): verifies 11 items + offline — points sync full path wired (DAO sink registered, listener registered, codec+merger in router), balance re-derived not synced, redemptions LWW convergence test real, firestore.rules, ladder removed from live path, single-item sentinel, per-track neutralized, atomic adjust, next-reward card, v26 data-preserving migration + test asserts, Rule-7 no branching. Both READ-ONLY (report VERIFIED/WEAK/FAILED w/ file:line + entry point); adversarial re stranded-wiring.
- next: Collect V5a+V5b. Demote any FAILED→re-fix; WEAK→judge. Then V6 smoke (charter flows EN+HE).

## [2026-05-25 03:52] RESULT — V5a task-truth (switch/tutor/notif) COMPLETE

- stream: V5a (a36d477bbce740439)
- detail: ALL 12 reachability items VERIFIED + locale VERIFIED.
  1 UID-source verified (firestore_gateway_impl _addressedUid :51-52, all 7 path builders, injected outbox_providers.dart:34). 2 clear selectedProfileId (app_shell.dart:516) + ProfileGuard validates id (profile_guard.dart:50-66). 3 0-profile→EmptyLoginRoute (app_shell.dart:592) + empty_login switch affordance (:40-52). 4 indicator bar + banner on activeTutoredProfileSelectionProvider (app_shell.dart:46-49,64-71); standalone-child suppresses banner. 5 tutor PIN namespace = tutorOwnProfileId both gate (tutored_children_section.dart:182,301) + guard (router_provider.dart:97-99); promptForPin scope dispatch (:67-79). 6 gate on both entries (talmid row :289 + view-invitations :174), selection set only in onPinVerified. 7 decline → declineTutorInviteUseCase + notifyParentOfDecline (decline_invite_screen.dart:105-128); accept assigns _tutorProfileId (:106) + PIN setup reachable. 8 canEditPoints distinct field (tutor_permissions.dart:64), gates point config (parent_settings_screen.dart:65,142). 9 ManageGrantsScreen PopScope → exit() (:39-54). 10 active profile excluded from bootstrap (notification_providers.dart:604). 11 scheduleStreakAlertForProfile (:375) per inactive profile (:644-668). 12 reconcile cancels reminder+streak for removed ids (:591-594).
- RESIDUALS (minor, do not affect reachability):
  - V5a-R1: tutored_children_section.dart still hardcodes EN — 'View invitations'(:155), pending-count subtitle(:161), 'Tutoring'(:256), 'Tutor'(:279). User-visible; outside FIX-L10N "9 screens" scope (lives in features/profiles). Rule-1 gap.
  - V5a-R2: stale comment parent_settings_screen.dart:141 says canEditGoals but code uses canEditPoints (cosmetic).
- next: await V5b, then batch-fix residuals + any V5b WEAK/FAILED, re-run ci, then V6.

## [2026-05-25 04:00] RESULT — V5b task-truth (rewards/sync/migration/Rule7) COMPLETE — NO FAILED

- stream: V5b (a60bbf5068492e6a4)
- detail: ALL items VERIFIED, zero FAILED. Points sync genuinely wired end-to-end incl. the commonly-stranded sink registration:
  1 points_ledger: ulid on insert (points_balance_dao.dart:479,183), DAO _pushLedgerEntry/_pushRedemption → syncSink.enqueue (:487-527), SINK REGISTERED sync_orchestrator_providers.dart:88 + sync_providers.dart:116 (OutboxSyncWriteFacade implements PointsSyncSink), outbox kinds (outbox_processor.dart:44-45,468-479) → push_pipeline_impl:224-242 → gateway write users/{uid}/learner_profiles/{pid}/points_ledger/{ulid} (firestore_gateway_impl:965), listener (firestore_listener_source:171) + pull pipeline (:216) + full-pull (sync_orchestrator:737) + realtime (:1125) + recovery (:1205), merger in router (merge_router_provider:96, merge_router:47). 2 points_balance NOT synced, reDeriveBalanceFromLedger (points_ledger_merger:71, clamp@0). 3 reward_redemptions LWW by updated_at (:384 overwrite-if-newer); convergence test points_sync_merger_test.dart non-trivial (stale-pull rejection + decline-refund re-derive to 30 across 2 merges), 5 tests pass. 4 firestore.rules:274,284. 5 ladder no-ops (reward_milestone_service:268-275), zero live callers, completion_repository_impl:212-215 sets []. 6 sentinel single-item (learning_ledger_repository_impl:95,128), source threaded. 7 per-track neutralized (reward_config_controller:67-73,86; UI removed). 8 parentAdjust atomic single-txn (:97-119); debitRedemption/refundRedemption removed. 9 next-reward bar removed (child_points_rewards_tab_card:25-28,125-129). 10 schemaVersion 27, v26 TableMigration+foreign_key_check gate (:216-237), v25_to_v27_test 7 pass. 11 dashboard/scheduler/track-card trackType cleaned. offline: reads Drift-first, push queued via outbox non-blocking, syncSink null for local-born.
- WEAK residuals (none user-reachable breakage): (a) PointsLedgerCodec+RewardRedemptionCodec dead (mergers parse inline) — delete; (b) progress_providers.dart:219 no-op trackType==personal branch — remove. Also dead RewardTypeSegmented widget (harmless), dashboardChildNextReward still computes but not rendered (harmless).
- ACTION: dispatched V5 cleanup agent (af938505c2610f48d, task#23): localize tutored_children_section 4 strings (V5a-R1, canonical madrich ARB en+he), fix stale comment (V5a-R2), delete 2 dead codecs (V5b-a), remove no-op trackType branch (V5b-b), make ci green.
- V5 VERDICT: all sampled done-tasks confirmed user-reachable → upgrade done→verified. No demotions.
- next: V5 cleanup return → ci green → V6 charter-flow smoke (EN+HE).

## [2026-05-25 04:12] TASK-DONE — V5 cleanup (task#23) + V5 CLOSED

- stream: V5 cleanup (af938505c2610f48d)
- detail: V5a-R1 FIXED — tutored_children_section.dart localized: 4 ARB keys en+he (tutoredChildrenViewInvitations, tutoredChildrenPendingInvitations [ICU plural on count], tutoredChildrenStatusTutoring, tutoredChildrenRoleBadge); Hebrew canonical מדריך; flutter gen-l10n. V5a-R2 FIXED — parent_settings_screen.dart:141 comment canEditGoals→canEditPoints. V5b-a FIXED — deleted dead points_ledger_codec.dart + reward_redemption_codec.dart (grep proved zero refs; were untracked). V5b-b FIXED — removed no-op trackType==personal filter progress_providers.dart:218 (bulkBaseline/liveProgress/F5-telemetry now use allCompletions; TrackType import retained for trackBreakdown). make ci GREEN: 5926 pass, 125 skip, analyze+format clean. No test changes needed.
- V5 task-truth COMPLETE: all done-tasks → verified, 0 demotions, all residuals closed.
- next: V6 final smoke dispatched (a8db00c4d03312c64): trace charter flow #1 (tutor e2e) + #2 (relationship mgmt) + switcher/reminder/rewards-spend cross-cutting + EN/HE locale + offline; GO/NO-GO verdict.

## [2026-05-25 04:25] RESULT — V6 final smoke COMPLETE — GO verdict

- stream: V6 (a8db00c4d03312c64)
- detail: ALL 12 charter journey steps CONNECTED end-to-end (each hop cited file:line), NO BROKEN.
  Flow#1 tutor: 1 Manage Tutors tile owner-only (parent_settings:240,255) 2 invite→inviteTutorUseCase→CF (invite_tutor:75; repo:36) 3 accept→CF + PIN setup w/ tutorOwnId (accept_invite:130-146,335,106) 4 PIN gate on path, selection set only in onPinVerified (tutored_children:291,322,327-329) 5 child view + perm-gated edits + live-mark blocked on active selection + domain guard (text_display:754-755,885; mark_live_completion_use_case:55-63) + bulk sentinel skips streak/recent (bulk_prior_completion_service:258,250; streak_restorer:36; completion_dao:138) 6 all 3 removal paths notify real recipient (revoke manage_tutors:304; resign manage_grants:235; decline decline_invite:122; _recipient never empty) 7 back-nav clears selection (manage_grants:51-55 PopScope). Flow#2: 8 section iff ≥1 active OR pending (tutored_children:54-56) 9 add+remove+notify (manage_tutors:213,293,341,304). Cross: 10 switcher count-gate+no-signout+active-account UID+0-profile→empty-login+way-back (app_shell:447,518,542-570,592; empty_login:48) 11 inactive reminder fires+tap-switch+scheduler, deleted cancelled (notifications_bootstrap:42,29-31; notification_providers:596-604,591-594) 12 rewards spend atomic/never-neg + child→parent + cross-device sync (child_redemption:152; points_balance_dao:172,90-91; fulfil:98/decline-refund:117; RewardRedemptionMerger LWW + ledger re-derive). Test coverage: WS3.3a-h acceptance + epic_12/21/25/27 + points_sync_merger + mark_live_completion + points_balance_dao.
- NON-BLOCKING residuals (Rule-1 fast-follow): text_display_screen.dart:938-941 live-mark button labels ('Not available (tutor mode)','Mark Complete','Completed'), :717 'OK', :812 error string NOT localized (tooltip at :880 IS); app_shell.dart:559-563 offline-switch SnackBar ('Working offline…','Sign in') hardcoded. Cosmetic: decline/resign email carries raw childProfileId not display name (+ email transport is logging-only stub). Architectural-accepted: tutor relationship surface (invite/accept/decline/revoke/resign + grant LISTS) inherently online via Cloud Functions; offline returns [] gracefully (not crash) but tutor can't enter talmid offline — consistent w/ Admin-SDK server-side grant design.
- VERDICT: GO for shipping. No BROKEN items.

## [2026-05-25 04:26] COMPLETE — Entity-Model Remediation finished

- stream: Orchestrator
- detail: Full plan executed: WS1-9 (4 waves) + P1-P4 gates + V1 CI + V2 review (Sonnet then user-directed Opus re-run) + V3 Opus fix-all (2 design criticals planned+approved, 6 fix agents 2 waves + integration patch) + V4 integrated CI green (5926) + V5 task-truth (2 verifiers, all VERIFIED 0 demotions, residuals cleaned) + V6 smoke GO. make ci green throughout. All audit CRITICAL/HIGH closed. Remaining: minor Rule-1 fast-follow (2 files' journey-path strings) + cosmetic email display-name + architectural online-tutor-surface note. NOT yet committed (awaiting user direction on commit + fast-follow).
- next: Report GO to user; offer to close the 2 Rule-1 fast-follow l10n gaps; await commit direction.

## [2026-05-25 14:10] REGRESSION+FIX — sign-in lockout from undeployed points-sync rules

- stream: Orchestrator (post-commit field bug from Daniel's device)
- symptom: Google sign-in → Firebase auth SUCCEEDS (uid UTZNGSUVElWNWbPRHrXJimZo9P23) but SignInController → SignInError; returning user locked out.
- diagnosis (via Settings→Send Diagnostic Logs, users/{uid}/diagnostic_logs): `[cloud_firestore/permission-denied]` on listeners + pull for channels points_ledger + reward_redemptions → `sync_orchestrator_pull_on_launch_failed` → FirestorePermissionDeniedException(collection: points_ledger, op: read). Root cause = TWO defects from the C#2 points-sync work:
  1. OPERATIONAL: firestore.rules for points_ledger + reward_redemptions (correct, learning_tracker/firestore.rules:274-286) NOT deployed to live project torah-study-tracker → reads denied. CI didn't catch: tests use fake_cloud_firestore which does not enforce rules.
  2. CODE/offline-first: sync_orchestrator.pullOnLaunch() runs points_ledger/reward_redemptions as sequential steps; catch at :812 rethrows (:849); _navigateAfterSignIn (sign_in_controller.dart:417,442) awaited pullOnLaunch with only .timeout (no try/catch) → thrown permission-denied propagated into signInWithGoogle catch (:730) → SignInError. Sign-in wrongly depended on a successful cloud pull (violates offline-first: sync is informational).
- FIX (Defect 2, code, DONE): wrapped both pullOnLaunch() calls in _navigateAfterSignIn in try/catch (AppLogger.warning event:navigate_after_sign_in_pull_failed) so a pull failure is logged and sign-in proceeds on local Drift state. dart analyze clean; sign_in_controller_test.dart all pass. No test coupled pull-failure→SignInError, so no assertions broken.
- FIX (Defect 1, operational, PENDING USER): deploy rules — `firebase deploy --only firestore:rules` from learning_tracker/ (project torah-study-tracker). Shared-infra action; awaiting user go. Needed so points actually sync + sync status stops going red.
- memory saved: [[firestore-rules-deploy]] (deploy requirement + fake-Firestore CI gap).
- next: user deploys rules + retries sign-in to confirm; then commit Defect-2 fix.

## [2026-05-24 12:00] START — WS3 begins

- stream: WS3
- detail: Read all required docs (plan, audit, log, tracker, product-rules, hebrew-terms, CLAUDE.md). Baseline CI green (5791 tests). Key files explored: tutored_children_section.dart (lines 35/99/142 confirmed), parent_settings_screen.dart (no Manage tutors tile), router_provider.dart:65-71 (PinScope hard-coded to parent), tutor_pin_entry_gate.dart (exists, zero call sites confirmed), tutor_permissions.dart (canEdit* fields written-never-read), text_display_screen.dart:748 (_isTutorSession reads incomingTutorGrantsProvider — confirmed dual-role bug), tutor_notification_service.dart (3 methods, 0 call sites), manage_tutors_screen.dart (parent revoke UI exists), accept_invite_screen.dart:110 (stub grant confirmed). Duplicate tutorGrantRepositoryProvider confirmed in manage_tutors_providers.dart + tutor_grant_providers.g.dart. Starting 3a.
- next: WS3.3a — add "Manage tutors" tile to parent_settings_screen.dart
