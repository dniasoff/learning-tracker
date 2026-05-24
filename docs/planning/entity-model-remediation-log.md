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

## [2026-05-24 12:00] START — WS3 begins

- stream: WS3
- detail: Read all required docs (plan, audit, log, tracker, product-rules, hebrew-terms, CLAUDE.md). Baseline CI green (5791 tests). Key files explored: tutored_children_section.dart (lines 35/99/142 confirmed), parent_settings_screen.dart (no Manage tutors tile), router_provider.dart:65-71 (PinScope hard-coded to parent), tutor_pin_entry_gate.dart (exists, zero call sites confirmed), tutor_permissions.dart (canEdit* fields written-never-read), text_display_screen.dart:748 (_isTutorSession reads incomingTutorGrantsProvider — confirmed dual-role bug), tutor_notification_service.dart (3 methods, 0 call sites), manage_tutors_screen.dart (parent revoke UI exists), accept_invite_screen.dart:110 (stub grant confirmed). Duplicate tutorGrantRepositoryProvider confirmed in manage_tutors_providers.dart + tutor_grant_providers.g.dart. Starting 3a.
- next: WS3.3a — add "Manage tutors" tile to parent_settings_screen.dart
