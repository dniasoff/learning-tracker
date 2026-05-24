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
