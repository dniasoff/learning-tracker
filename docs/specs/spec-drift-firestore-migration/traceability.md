# Traceability — capability ↔ AD ↔ phase ↔ MCF

Companion to `SPEC.md`. Downstream (epics/stories) cite a **CAP-N** for scope and an **AD-N** for the governing rule; this table joins them to the migration-plan phase and the baseline MCF classes. The authoritative fine-grain **MCF-1..35 → target location + governing AD** map lives in the adopted `ARCHITECTURE-SPINE.md` ("Capability → Architecture Map"); this file is the capability-level projection, not a replacement.

## Capabilities → phase → governing ADs → MCF classes

| CAP | Migration-plan phase | Governing ADs | Representative MCF coverage |
| --- | --- | --- | --- |
| CAP-1 Named-app topology smoke test | Phase 0 (existential gate) | AD-1, AD-29 | MCF-feasibility |
| CAP-2 Deterministic id hygiene | Phase 0 (targets fixed; Wave-A backfill in P3) | AD-5, AD-13, AD-24, AD-25 | MCF-3, MCF-4, MCF-8, MCF-11, MCF-3-continuity |
| CAP-3 Single-owner conflict predicate | Phase 0 | AD-7, AD-29 | MCF-1, MCF-26 |
| CAP-4 Boundary greps | Phase 0 (enforced, not yet tripped) | AD-28, AD-2, AD-3, AD-23 | MCF-13-scaffold, MCF-11 (standing sweep) |
| CAP-5 Listener resubscribe-on-error | Phase 0 quick-win → P1/P2 lifecycle | AD-9, AD-22 | MCF-23, MCF-28 |
| CAP-6 Connectivity + slim 3-state status | Phase 0 quick-win | AD-11, E-1 | MCF-22, MCF-8-conn |
| CAP-7 Per-account named-`FirebaseApp` subsystem | Phase 1 | AD-1, AD-2, AD-18, AD-24 | MCF-feasibility, MCF-orchestrator/singleton, MCF-collision |
| CAP-8 Repository seam + `tutor_grants` slice | Phase 2 | AD-3, AD-17, AD-23, AD-22 | MCF-13-scaffold, MCF-30, MCF-32, MCF-10-codegen |
| CAP-9 Per-collection strangler waves | Phase 3 | AD-4, AD-5, AD-6, AD-7, AD-8, AD-10, AD-12, AD-13, AD-25, AD-27, AD-29 | MCF-2/5/6/7/8/8b/14/15/16/19/24-streak/25/27, MCF-view, MCF-writer |
| CAP-10 Permanent-write-failure recovery | Phase 3 (once direct-SDK writes ship) | AD-30 | R-4/R-7 successor |
| CAP-11 Cross-account fixes + local-born + hard-delete | Phase 4 | AD-14, AD-15, AD-19, AD-20, AD-21, AD-24, AD-26 | MCF-blastradius, MCF-globalflags, MCF-collision, MCF-localborn, MCF-24-orphan, MCF-cascade, MCF-7-delete, MCF-1-facade, MCF-13 |
| CAP-12 Backfill + shadow verify + point of no return | Phase 5 | AD-13, AD-16, AD-29 | MCF-9, MCF-12, MCF-3, MCF-35 |
| CAP-13 Engine retirement & deletion | Phase 6 | (deletes all engine-owned MCF residue) | MCF-20, MCF-21, MCF-29, MCF-16 (dead paths) |
| CAP-14 Verification, telemetry & rollout | Phase 7 | AD-12, AD-29 | MCF-appcheck, MCF-32 (final sign-off) |

## Every AD lands in a capability

| AD | Owned/exercised by | AD | Owned/exercised by |
| --- | --- | --- | --- |
| AD-1 | CAP-1, CAP-7 | AD-16 | CAP-12 (+ Constraint: local stores) |
| AD-2 | CAP-4, CAP-7 | AD-17 | CAP-8 |
| AD-3 | CAP-4, CAP-8 | AD-18 | CAP-7 |
| AD-4 | CAP-9 (Wave C) | AD-19 | CAP-11 |
| AD-5 | CAP-2, CAP-9 | AD-20 | CAP-11 |
| AD-6 | CAP-9 (Waves C/D) | AD-21 | CAP-11 |
| AD-7 | CAP-3, CAP-9 | AD-22 | CAP-5, CAP-8 |
| AD-8 | CAP-9, CAP-11 | AD-23 | CAP-4, CAP-8 |
| AD-9 | CAP-5, CAP-7 | AD-24 | CAP-2, CAP-7, CAP-11 |
| AD-10 | CAP-9 (Wave A) | AD-25 | CAP-2, CAP-9 (Wave A) |
| AD-11 | CAP-6 | AD-26 | CAP-11 |
| AD-12 | CAP-9, CAP-14 | AD-27 | CAP-9 (Wave B) |
| AD-13 | CAP-2, CAP-9, CAP-12 | AD-28 | CAP-4 |
| AD-14 | CAP-11 | AD-29 | CAP-1, CAP-3, CAP-9, CAP-12 |
| AD-15 | CAP-11 | AD-30 | CAP-10 |

## Three-tier verification split (AD-29) → capabilities

- **Tier 1 (pure-unit):** canonical predicate (CAP-3), codec legacy-alias round-trips + doc-id formulas (CAP-2, CAP-9).
- **Tier 2 (emulator/instrumented):** `isFromCache`/`hasPendingWrites` logic, resubscribe-on-error, App-Check-in-rules (CAP-9, CAP-5, CAP-14).
- **Tier 3 (on-device, emulator-5556 seeded, Parent PIN 2580):** named-app isolation smoke test + instant offline switch + per-account cache independence (CAP-1, CAP-7).
