---
stepsCompleted: [step-01, step-02]
status: draft
inputDocuments:
  - docs/specs/spec-drift-firestore-migration/SPEC.md
  - docs/specs/spec-drift-firestore-migration/traceability.md
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/migration-plan.md
  - docs/planning/drift-to-firestore-migration-baseline.md
  - docs/reports/sync-reliability-efficiency-review-2026-07-29.md
---

# Learning Tracker — Firestore Migration Phase 0 + Sync Survivors - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Learning Tracker — Firestore Migration Phase 0 + Sync Survivors, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

1. Two-named-app/one-project/two-anon-user smoke test on oldest supported device; writes+listeners in app A invisible to app B's cache, no cache-dir collision. (CAP-1; AD-1, AD-29)
2. Doc-id module reproduces every formula byte-for-byte except AD-25 track-scoped rekey. (CAP-2; AD-5, AD-13)
3. Canonical track key = curriculum_id; all track-scoped child formulas re-expressed against it. (CAP-2; AD-5, AD-25)
4. learner_profiles doc-id is a profile-scoped ULID distinct from path uid. (CAP-2; AD-5, AD-24)
5. ULID generation standardizes on existing lib/core/time/ulid.dart; no new package. (CAP-2; AD-5)
6. Standing grep: zero autoincrement-id-in-payload outside merge/. (CAP-2, CAP-4; AD-5, AD-28)
7. Retarget no-firebase-outside-core grep to lib/data/firestore/** + lib/data/repositories/**. (CAP-4; AD-28, AD-3)
8. New grep bans bare FirebaseFirestore.instance/FirebaseAuth.instance outside the AccountFirebase registry. (CAP-4; AD-28, AD-2)
9. New grep enforces dependency direction (no features/domain importing past repository interface). (CAP-4; AD-28, AD-23)
10. All mechanical boundary rules enforced via make-audit greps only, never custom_lint. (CAP-4; AD-28)
11. The canonical LWW predicate — the 5-step algorithm (±5s clock-skew window → synced_at server-timestamp tie-break → D15 prefer-newer-unpushed-local → remote-wins-on-true-tie) — is extracted into exactly one module, called by every reconciliation path. (CAP-3; AD-7, AD-29)
12. Byte-equivalent/golden-branch unit tests pin every predicate branch (the ±5s window, the synced_at tie-break, D15 prefer-newer-unpushed-local, and remote-wins-on-true-tie), including a red-demo proving a hand-copied/drifted second implementation fails the suite — closing the AUD-t-cross-68 hand-copy-drift class. (CAP-3; AD-7, AD-29)
13. Every merger/reconciliation path — including RewardRedemption's bespoke plain-isAfter predicate (F3) — is routed through the single canonical predicate unconditionally, with no per-merger exception, independent of AD-21 gating. (CAP-3; AD-7)
14. Every listener marks-dead + bounded-exponential-backoff resubscribes on error. (CAP-5; AD-9)
15. Connectivity-online and resume trigger resubscribe of dead channels. (CAP-5; AD-9)
16. Own- and tutored-account listeners have resubscribe parity. (CAP-5; AD-9, AD-22)
17. Backoff-capped channel surfaces as syncing, never falsely synced. (CAP-5, CAP-6; AD-9, AD-11)
18. Resume network reset fires only on real network-identity change, restricted to paused/hidden, debounced. (CAP-5; AD-9)
19. Connectivity sourced from hardened connectivityStreamProvider/platform events (direct connectivity_plus), never the 5s demo poller. (CAP-6; AD-11, E-1)
20. Redundant offline-poll loop removed; false "~0 idle cost" comment corrected. (CAP-6; AD-11, E-1)
21. Status is exactly synced|syncing|offline, derived only from SDK signals. (CAP-6; AD-11)
22. Zero app-level pending/dead-letter bookkeeping. (CAP-6; AD-11)

### NonFunctional Requirements

1. Every fix ships a red-demo (fails before, passes after).
2. make ci MAKE_CI_RC=0 required.
3. make audit's full 67-grep suite stays green (incl. CAP-4 additions).
4. Tests stay green under --test-randomize-ordering-seed=random.
5. New/changed tests follow TQ-3/TQ-6 rules.
6. User-visible string changes ship EN+HE arb parity.
7. No new raw color literals.
8. AD-29 three-tier verification (pure-unit/emulator/on-device) for resubscribe-on-error and slim-status SDK-signal invariants.
9. CAP-6 fix meets E-1's ~99% connectivity-traffic reduction + radio-wake elimination target.
10. No change may reopen a shipped P0 (MCF-2/6/8/9/11).
11. Worktree isolation for stories touching shared foundation files (doc_ids.dart, grep defs) or CAP-5/CAP-6 files.

### Additional Requirements

- Phase-0 entry: spine ratified + owner sign-off on the 4 [ADOPTED] owner decisions (AD-1, AD-11, AD-14+AD-15, AD-16).
- Phase-0 exit (this scope's subset): doc-id module + byte-for-byte unit tests; MCF-11 landmine-sweep report; ULID standardized; retargeted/new greps green; AD-1 smoke test passes on oldest device; make ci + make audit green.
- CAP-1 gate: smoke-test result recorded as ADR/memlog event; failure = STOP signal reopening AD-1, no ratified fallback (owner rejected reduced-experience option).
- Freeze decision: only CAP-5/CAP-6 land; all other sync-wave1/2/3 items DROPPED as mooted by Phase-6 deletion, not deferred.
- AD-19 (Anonymous-Auth) is Phase 4/CAP-11 per traceability — no Phase-0 FR depends on it structurally.
- R-4 drain-in-catch excluded per the two-survivor freeze (owner, 2026-07-30); its status-masking half is mooted by AD-11, its recovery affordance lives at AD-30/CAP-10 (Phase 3).

### UX Design Requirements

No UX design contract applies to this scope.

### FR Coverage Map

FR1: Epic 2 — Prove two-app cache isolation on oldest device (go/no-go gate)
FR2: Epic 2 — Doc-id module reproduces every formula byte-for-byte except track rekey
FR3: Epic 2 — Track-scoped child formulas keyed on the canonical curriculum_id
FR4: Epic 2 — learner_profiles doc-id becomes a profile-scoped ULID, not path uid
FR5: Epic 2 — Standardize ULID generation on the existing in-repo generator
FR6: Epic 2 — Standing grep bans autoincrement ids in payloads outside merge/
FR7: Epic 2 — Retarget no-firebase-outside-core grep to the new data-layer dirs
FR8: Epic 2 — New grep bans bare FirebaseFirestore/FirebaseAuth instance access
FR9: Epic 2 — New grep enforces repository-only dependency direction
FR10: Epic 2 — All boundary rules enforced via make-audit greps, not custom_lint
FR11: Epic 2 — Extract the canonical 5-step LWW predicate into one module
FR12: Epic 2 — Golden-branch unit tests pin every predicate branch plus a drift red-demo
FR13: Epic 2 — Every merger routes through the canonical predicate, no exceptions
FR14: Epic 1 — Every listener marks-dead and backs off before resubscribing on error
FR15: Epic 1 — Connectivity-online and app resume trigger dead-channel resubscribe
FR16: Epic 1 — Own- and tutored-account listeners get resubscribe parity
FR17: Epic 1 — A backoff-capped channel surfaces as syncing, never falsely synced
FR18: Epic 1 — Resume network reset gated to a real network-identity change, debounced
FR19: Epic 1 — Connectivity sourced from a hardened stream/platform events, not the poller
FR20: Epic 1 — Redundant offline-poll loop removed; idle-cost comment corrected
FR21: Epic 1 — Status collapses to exactly synced|syncing|offline from SDK signals
FR22: Epic 1 — Zero app-level pending/dead-letter bookkeeping remains

## Epic List

### Epic 1: Bulletproof sync on the current engine
Users get sync that recovers by itself — a dead listener never stays dark while online, status never lies, and the app stops burning battery/mobile data on a 5-second polling loop. (The two migration-surviving fixes, landing now.)
**FRs covered:** FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22 (CAP-5, CAP-6 — AD-9, AD-11, AD-22)

### Epic 2: Migration Phase 0 — foundations and the go/no-go gate
The Firestore migration is proven feasible on real hardware (the two-app cache-isolation smoke test — its result is a recorded go/no-go; failure STOPS and reopens AD-1) and its data-integrity foundations exist: deterministic doc-ids with no autoincrement landmines, the canonical LWW predicate in exactly one pinned module, and every boundary rule enforced by a make-audit grep.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR11, FR12, FR13 (CAP-1, CAP-2, CAP-3, CAP-4 — AD-1/2/3/5/7/23/24/25/28/29)

<!-- Repeat for each epic in epics_list (N = 1, 2, 3...) -->

## Epic {{N}}: {{epic_title_N}}

{{epic_goal_N}}

<!-- Repeat for each story (M = 1, 2, 3...) within epic N -->

### Story {{N}}.{{M}}: {{story_title_N_M}}

As a {{user_type}},
I want {{capability}},
So that {{value_benefit}}.

**Acceptance Criteria:**

<!-- for each AC on this story -->

**Given** {{precondition}}
**When** {{action}}
**Then** {{expected_outcome}}
**And** {{additional_criteria}}

<!-- End story repeat -->
