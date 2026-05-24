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
