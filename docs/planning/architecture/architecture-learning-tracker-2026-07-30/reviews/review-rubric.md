---
title: Rubric-Walker Review — Drift→Firestore-Native Migration Spine
reviewer: rubric-walker (independent)
target: docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md
date: 2026-07-30
verdict: APPROVE-WITH-REQUIRED-CHANGES
---

# Rubric-Walker Review

**VERDICT: APPROVE WITH REQUIRED CHANGES (revise-in-place, do not re-draft).**

The spine is a genuinely strong good-spine: the MCF-1..35 register is mapped near-exhaustively to a target owner + governing AD (the "completeness contract" is real, not decorative); the invariants attack the actual divergence points the baseline enumerates (single-owner LWW predicate AD-7, derived-not-counter AD-4, deterministic doc-id AD-5, write atomicity AD-8, resubscribe-on-error AD-9, key namespacing AD-15); the operational envelope (deployment diagram, environments, rollout) is present and not silent; and the stack table is accurate to `pubspec.yaml` on the stated date (I re-verified every pinned line — firebase_core ^4.4.0, cloud_firestore ^6.1.2, firebase_auth ^6.1.4, firebase_app_check ^0.4.4+1, cloud_functions ^6.2.0, flutter_riverpod ^3.3.1, drift ^2.31.0, fake_cloud_firestore ^4.1.0 all match). Open dimensions are flagged `[ASSUMPTION]`/`[owner-decision]`, not smoothed over.

It does not pass clean. The dominant problem is that the spine claims to **ratify** the brownfield while, on layering and enforcement, it **contradicts** it — and mis-cites the very rule it claims to mirror. Five findings, most-severe first.

---

## Findings

### F1 (High) — The spine contradicts the brownfield layering it claims to "mirror," and mis-attributes today's Rule 3
The paradigm section asserts its new layering "mirrors today's layering Rule 3 (features route through repositories, never DAOs)," and AD-3/AD-2/AD-23 bind to "today's layering Rule 3." Three problems, all verified against the working tree and `learning_tracker/CLAUDE.md`:

1. **There is no `lib/data/` or `lib/domain/` today.** Top-level `lib/` is `app / core / features`. Repositories today live **feature-scoped** (`lib/features/scheduler/data/repositories`, `lib/features/notifications/domain/repositories`, `lib/features/tutoring/data/repositories`, …). The spine relocates them to a **global horizontal** `lib/data/repositories/**` + `lib/domain/**`. That is a large structural reorganization (feature-first vertical slices → horizontal data ring), presented as continuity.
2. **The spine mis-cites Rule 3.** Today's Rule 3 is *"Firebase symbols (`FirebaseAuth`/`FirebaseFirestore`/`FirebaseStorage`) confined to `lib/core/sync/` and `lib/core/auth/`."* It is **not** "features route through repositories, never DAOs." The spine attributes a rule to Rule 3 that Rule 3 does not state.
3. **The relocation collides with a shipped hard gate.** The real, active enforcement of Rule 3 is the `make audit` grep `no-firebase-outside-core` (DNI-387), a **hard gate**. It confines `cloud_firestore`/`firebase_auth` to `lib/core/sync/` + `lib/core/auth/`. The spine mandates those imports under `lib/data/firestore/**` and `lib/data/repositories/**` — every such file would be **flagged by the existing hard gate**. AD-3/AD-2/AD-23 never state they *supersede* Rule 3 or retarget that grep.

*Divergence let through:* a builder following AD-3 writes `cloud_firestore` under `lib/data/firestore/**`; `make audit`'s hard gate fails; the builder either reverts (breaking the spine) or silently weakens the grep (re-opening the exact bypass class AD-3 exists to prevent). **Fix:** AD-3/AD-23 must explicitly retire-and-replace Rule 3 (new allowed-dir list = `lib/data/firestore/**`, `lib/data/repositories/**`), state the reorganization from feature-scoped to global-horizontal repositories as a deliberate change (not "mirroring"), and correct the Rule-3 paraphrase.

### F2 (High) — Boundary ADs name no working enforcement; the one they name is the documented-broken mechanism
The anti-divergence force of AD-1/AD-2/AD-3/AD-5 is entirely mechanical-gate-dependent ("no bare `FirebaseFirestore.instance`", "no autoincrement-id in payload", "feature files MUST NOT import `cloud_firestore`"). Yet:
- AD-3 rests on *"an import-boundary lint (CI gate)."* The brownfield states plainly (`learning_tracker/CLAUDE.md`, custom_lint status note) that `dart run custom_lint` is **non-functional against this repo** — it silently reports "No issues found!" even on violations — and the **only** real enforcement is the `make audit` greps. The spine picks the broken mechanism.
- AD-1/AD-2/AD-5 name **no** gate at all.

This matters because the spine's own recurring justification for single-ownership (AUD-t-cross-68: a hand-copied LWW predicate drifted and shipped a lost-update bug) is precisely what happens when a rule has no mechanical gate. **Fix:** bind each boundary AD to a specific, existing-style `make audit` grep (bare-`instance` ban, autoincrement-in-payload sweep — AD-5 already calls for the sweep, make it a standing gate not a one-time audit, import-boundary directory list), and drop "lint (CI gate)" in favor of the grep the repo actually runs.

### F3 (Medium) — Verification/test envelope is silent for the SDK-signal invariants the whole design rests on
AD-7 (FB-3 cache-echo guard), AD-9 (terminal-on-error resubscribe), AD-11 (3-state status from `hasPendingWrites`/`isFromCache`), AD-18 (per-app persistence, "merge logic may assume persistence is on") all depend on **SDK runtime metadata** and on **N named-app offline caches** (AD-1). The stack lists `fake_cloud_firestore ^4.1.0` as the test double — but fakes do **not** model named multi-`FirebaseApp` instances, offline persistence, cache-vs-server emission, `isFromCache`, or App Check. The spine never states how AD-7/AD-9/AD-11/AD-18 get verified. This is an operational-envelope dimension the altitude owns, left silent: the load-bearing invariants have no stated test strategy, and the failure it keeps citing (AUD-t-cross-68) came from exactly an un-testable hand-copied double. **Fix:** add a short verification-strategy note — which invariants are fake-testable, which need the Firestore emulator / instrumented on-device tests, and how the single canonical predicate (AD-7) is unit-pinned so no second copy can exist.

### F4 (Medium) — ADOPTED AD-1 over-claims against the still-open AD-19
AD-1 is `[ADOPTED]` and states, universally, *"each device account (`DeviceAccounts` row, ≤5) gets its own `Firebase.initializeApp`."* But credential-less **local-born** accounts have no Firebase principal to scope an app+cache to — that is the entire subject of AD-19, which is `[ASSUMPTION]` and carries a live fork Daniel may still choose ("keep-fully-local-until-upgrade variant… reopens the offline-switch gap"). If Daniel picks that variant, AD-1's "each device account" is **false** for the local-born tier, yet AD-1 is marked adopted/binding. An ADOPTED invariant should not be silently conditional on an unresolved assumption. **Fix:** scope AD-1's quantifier ("each *cloud-backed or Anonymous-Auth-backed* account…") and add an explicit "conditional on AD-19" note, or elevate the Anonymous-Auth decision out of `[ASSUMPTION]`.

### F5 (Low) — Completeness-contract + stack nits
- **MCF-cascade** (the 6 no-cascade tables — profile-delete/tutor-wipe ordering) has **no explicit row** in the Capability→Architecture Map; it is only folded into AD-8's `Binds:` line. The map bills itself as "the completeness contract," so a fold-only fact is a small leak — give it a row (→ `write.dart` ordered delete helper, AD-8).
- **ULID:** the stack table asks to "confirm/standardize the generating package," but there is no ULID package in the lock — the repo already ships a hand-rolled `lib/core/time/ulid.dart`. The `[ASSUMPTION]` should point at standardizing on the existing in-repo generator, not selecting a package.
- **connectivity_plus** is a **transitive** dependency only (absent from `pubspec.yaml`, present in `pubspec.lock`). AD-11's "present in lock; replaces raw poller" understates that it must be **promoted to a direct dependency** before the status path can rely on it. Also note `connectivityStreamProvider` currently lives at `lib/features/account/presentation/providers/` — sourcing a cross-cutting status signal from inside a feature is itself a layering smell under the new `lib/data`/`lib/domain` scheme.

---

## Deferred check
Nothing under **Deferred** can let two units diverge: delta-pull/watermark, real-time re-scope, metered mode, batch-write wiring, CitiesRepository, web offline parity, and C3/H3/M1 recovery are all correctness-neutral cost/scope cuts or investigations — the spine correctly keeps every correctness gate (dedup-by-doc-id, atomicity, resubscribe, canonical predicate) *in* scope and defers only standing-cost optimizations. This section passes.

## What the spine gets right (for the record)
Single-owner LWW predicate (AD-7) directly kills the AUD-t-cross-68 drift class; AD-4/AD-5/AD-8 close the counter-LWW, autoincrement-in-payload, and partial-write divergences the baseline flags dangerous; AD-14/AD-15 pull the three shipped cross-account defects into scope per owner decision #3; AD-16 correctly fences Content DB + registry as never-migrate; the operational envelope (App Check debug-token discipline, strangler-per-collection, device-local backfill, single existing project) is decided, not silent. The paradigm ratifies the sound brownfield precedent (tutor_grant already Firestore-native, MCF-30) as its template.

**File:** docs/planning/architecture/architecture-learning-tracker-2026-07-30/reviews/review-rubric.md
