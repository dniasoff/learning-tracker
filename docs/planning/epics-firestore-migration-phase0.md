---
stepsCompleted: [step-01, step-02, step-03, step-04]
status: draft
ownerDecisions:
  - "Story 1.5 slim-status shape kept as ratified (owner [C], 2026-08-02): AD-30 per-item recovery affordance stays Phase 3; NO Story 1.6 pulling it forward. Accepted regression window — a permanently-failed write shows only as 'syncing' until Phase 3."
validation: "Adversarial step-04 validation READY (b352952d); 22 FRs covered, 11 stories, no forward deps."
wikiPublish: "BLOCKED — docmost-cli absent; this is the unpublished local draft, route to the living manual via doc-amend when the CLI is restored (never treat local as canon)."
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

## Epic 1: Bulletproof sync on the current engine

Users get sync that recovers by itself — a dead listener never stays dark while online, status never lies, and the app stops burning battery/mobile data on a 5-second polling loop. These are the two migration-surviving fixes (CAP-5 resubscribe → AD-9, CAP-6 slim-status/connectivity → AD-11), landing now on the *current* Drift+outbox engine per the two-survivor freeze (owner, 2026-07-30). Every Epic-1 story touches CAP-5/CAP-6 files, so **all of them run in an isolated worktree per NFR-11** and coordinate against the live `sync-wave1/2/3` threads. AD-29 three-tier verification (pure-unit → emulator → on-device seeded `emulator-5556`, Parent PIN 2580) applies to the resubscribe-on-error and slim-status SDK-signal invariants (NFR-8).

### Story 1.1: Own-account listeners resubscribe on error with bounded backoff

As a parent or child using the app,
I want a listener that dies mid-session to heal itself instead of staying dark until I relaunch,
So that my data keeps updating in real time after a transient fault (App-Check attestation, `UNAVAILABLE`, permission blip) without me noticing anything went wrong.

**Acceptance Criteria:**

**Given** `ListenerSupervisor` (`lib/core/sync/listener_supervisor.dart:192-208`) whose `start()` `onError` today only forwards to `_onError?.call(...)` and leaves `_attached == true` (`:171`, `:200-204`),
**When** any own-account `snapshots()` channel emits an error,
**Then** the supervisor marks *that channel* dead, records it as no-longer-attached, and schedules a bounded-exponential-backoff re-subscribe of only that channel,
**And** sibling channels stay live and are never torn down by one channel's failure (FR14; CAP-5; AD-9).

**Given** a channel that keeps failing while connectivity is up,
**When** the backoff interval reaches its configured cap,
**Then** the supervisor keeps retrying *at the cap* forever (no permanent give-up, no resting "exhausted" state — AD-9), the retry interval is bounded (never unbounded growth), and the still-dead channel is exposed to the orchestrator as an in-flight/unsettled signal (consumed later by Story 1.5, never reported as settled).

**Given** the DNI-335 single-delivery contract and the R-1 "needs care around double-attach" warning,
**When** a resubscribe races a concurrent `restart()`/`unpark()` or a second error on the same channel,
**Then** exactly one live subscription set results (no duplicate subscription, no doubled `_onEvent` delivery for a single upstream emission), reusing the existing serialized/coalesced `restart()` machinery (`:264-308`),
**And** a channel that errors while `park()`ed does not resubscribe until `unpark()` (AD-9).

**Given** the red-demo requirement (NFR-1),
**When** a test forces a live own-account channel into `onError` and then pushes a new server snapshot,
**Then** before the fix the new snapshot is never delivered (channel stays dead, `_attached` still true) and the test fails; after the fix the channel resubscribes within the backoff schedule and the snapshot is delivered, so the test passes.

**Given** the gate + verification requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps) are green, tests pass under `--test-randomize-ordering-seed=random` (NFR-4) and follow TQ-3/TQ-6 (NFR-5), and the invariant is verified across AD-29 tiers 1 (pure-unit backoff/mark-dead state machine) and 2 (emulator resubscribe-on-error) (NFR-8),
**And** the work lands in an isolated worktree because it edits the shared CAP-5 listener path (NFR-11).

### Story 1.2: Tutored listeners get park/unpark and resubscribe parity

As a parent using the app to watch my child's progress,
I want the tutored listener fleet to park when I background the app and to self-heal on error just like my own listeners,
So that 16 tutored gRPC streams don't stay live 24/7 draining battery, and a revoked-grant or transient error on a tutored channel doesn't silently freeze the mirror for the rest of my session.

**Acceptance Criteria:**

**Given** `TutoredListenerSupervisor` (`lib/core/sync/tutored_listener_supervisor.dart`) which today exposes only `attach`/`detach` (`:82-115`), declares `channelCount = 16` (`:70`), and passes an `_onError` that only logs (`:197-209`), alongside the **pre-existing** lifecycle park/unpark hooks (`parkListeners`/`unparkListeners` in `lib/core/sync/lifecycle_observer.dart:70-78,136-138,156-159`, built by prior sync-architecture-plan work) that today drive only the own-account supervisor,
**When** those existing lifecycle park/unpark hooks fire after the background window,
**Then** the tutored supervisor is wired into the existing hooks and parks/unparks its inner `ListenerSupervisor` with the same semantics as the own-account fleet, so all 16 tutored streams detach while backgrounded and reopen on resume (FR16; CAP-5; AD-9, AD-22).

**Given** the own-account resubscribe machinery from Story 1.1,
**When** a tutored `snapshots()` channel errors (e.g. a parent revokes `tutor_active_access` while the tutor's channels are live, or a transient `UNAVAILABLE`),
**Then** that tutored channel marks-dead and resubscribes with bounded-exponential-backoff identically to own-account channels — resubscribe parity, no per-fleet exception (FR14 tutored half, FR16; AD-9, AD-22),
**And** cross-account isolation is preserved: the tutored supervisor still reads only through the parent-scoped gateway (`users/{parentUid}/learner_profiles/{remoteProfileId}/…`) and never issues writes (AD-22).

**Given** a permission-denied that is genuinely permanent (grant actually revoked),
**When** the tutored channel resubscribes and is rejected again,
**Then** it degrades to retrying-at-the-cap (Story 1.1 rule) rather than looping tightly, and `detach()` on session exit / mirror-wipe cleanly cancels all pending backoff timers (no leaked timer after detach) (AD-9, AD-22).

**Given** the red-demo requirement,
**When** a test (a) backgrounds a live tutored session past the park window and (b) forces a tutored channel into `onError`,
**Then** before the fix the 16 streams stay attached (no park/unpark exists) and the errored channel stays dark — the test fails; after the fix the fleet parks and the errored channel resubscribes — the test passes.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps) are green, seed-randomized (NFR-4) and TQ-3/TQ-6-compliant (NFR-5), tier-2 emulator verification covers tutored resubscribe/park (NFR-8), and it lands in an isolated worktree (shared CAP-5 files; must land *after* Story 1.1 since it reuses that resubscribe verb) (NFR-11).

### Story 1.3: Connectivity-online and resume resurrect dead channels; resume network reset is gated and debounced

As a parent or child using the app,
I want the app to bring my listeners back the moment the network returns or I reopen the app, without a full teardown on every trivial app-switch,
So that recovery from a Wi-Fi↔cell handoff or an App-Check outage is automatic and doesn't cost a wasteful all-fleet re-handshake every time I glance away and back.

**Acceptance Criteria:**

**Given** the connectivity-online and resume paths that today only reset-network + drain / pull-and-unpark and never resubscribe a terminated stream (report R-1/R-8; `lifecycle_observer.dart:145-160`, orchestrator connectivity path),
**When** connectivity transitions offline→online, or the app resumes from background,
**Then** both paths trigger a resubscribe of every dead channel (own and tutored) via the Story 1.1/1.2 machinery, so App-Check recovery and network handoffs resurrect listeners without a relaunch (FR15; CAP-5; AD-9).

**Given** `LifecycleObserver` today unconditionally awaits `resetFirestoreNetwork` whenever `_wasBackgrounded`, and sets `_wasBackgrounded` on *any* non-resumed state including a transient `inactive` blip (`:125-131`, `:145-149`),
**When** the app receives a brief `inactive` event (notification shade, permission dialog) or a sub-park-window foreground bounce with no network change,
**Then** no `resetFirestoreNetwork` fires — the reset is gated to a real **network-identity change**, restricted to the `paused`/`hidden` states (never `inactive`), and debounced (FR18; CAP-5; AD-9, E-5),
**And** a genuine network-identity change on resume does still fire exactly one debounced reset.

**Given** airplane-mode / flaky-link edge transitions,
**When** connectivity flaps offline→online→offline rapidly,
**Then** resubscribes coalesce (no thundering-herd of overlapping attaches), and a channel that is already healthy is left untouched (no needless teardown) (FR15; AD-9).

**Given** the red-demo requirement,
**When** a test drives (a) a dead channel + connectivity-online and (b) a resume preceded only by an `inactive` blip,
**Then** before the fix the dead channel stays dark on connectivity-online and the `inactive` blip still triggers a full network reset — the test fails; after the fix the channel resubscribes and the `inactive` blip triggers no reset — the test passes.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, and it lands in an isolated worktree (shared CAP-5 lifecycle/orchestrator files; must land *after* Stories 1.1–1.2) (NFR-11).

### Story 1.4: Source connectivity from a hardened stream / platform events, not the demo poller

As a parent or child using the app,
I want the app to stop pinging three third-party demo servers every 5 seconds all day,
So that it stops draining my battery and mobile data on an invisible background loop and its offline/online detection stops flapping.

**Acceptance Criteria:**

**Given** `internetConnectionCheckerProvider` today builds `InternetConnectionChecker.createInstance()` with no overrides — the package default of a 5 s poll against 3 demo hosts (`dummyapi.online`/`jsonplaceholder`/`fakestoreapi`) (`lib/features/account/presentation/providers/connectivity_providers.dart:14-20`) — and `connectivity_plus` is transitive-only in the lock,
**When** connectivity is sourced,
**Then** it comes from the hardened `connectivityStreamProvider`/platform events backed by a **direct** `connectivity_plus` dependency (promoted in `pubspec.yaml`, currently only `internet_connection_checker: ^3.0.1` at `:102`), never the raw 5 s demo-host poller (FR19; CAP-6; AD-11, E-1).

**Given** the redundant offline re-probe loop (`_offlineRecoveryProbeInterval` 5 s, `connectivity_providers.dart:90`, `:153-172`) and the factually-wrong comment "event-driven instead of polling, so idle CPU cost is ~0" (`:8-10`),
**When** the connectivity source is rebuilt,
**Then** the redundant offline-poll loop is removed and the false "~0 idle cost" comment is corrected to describe the real cost model (FR20; CAP-6; AD-11, E-1),
**And** the orchestrator's periodic-drain / connectivity gates (`sync_orchestrator.dart`, `sync_orchestrator_providers.dart:141-147`) read the hardened source rather than the inline `async*` demo-checker stream.

**Given** the NFR-9 efficiency target,
**When** connectivity traffic is measured before/after (per the report's instrumentation guidance, since this is invisible to Cloud Monitoring),
**Then** the change achieves E-1's ~99% connectivity-traffic reduction (≈51,840 req/day → a few hundred/day) and eliminates the 5 s radio-wake cadence (NFR-9).

**Given** airplane-mode and cold-start transitions,
**When** the device toggles airplane mode or cold-starts genuinely offline,
**Then** offline is detected without the startup false-offline flash (the existing debounce is preserved), and recovery to online is automatic on platform events/resume without a manual pull-to-refresh (FR19; AD-11).

**Given** the red-demo requirement,
**When** a test asserts (a) the connectivity source is the hardened stream/platform events, (b) no 5 s demo-host poll loop remains, and a grep asserts (c) the false "~0 idle cost" comment is gone,
**Then** before the fix (a)/(b)/(c) fail; after the fix they pass.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, any user-visible offline-banner string change ships EN+HE arb parity (NFR-6) and adds no raw color literal (NFR-7), and it lands in an isolated worktree (shared CAP-6 connectivity files) (NFR-11).

### Story 1.5: Collapse sync status to synced|syncing|offline from SDK signals, with no app-level bookkeeping

As a parent or child using the app,
I want the sync indicator to tell me the truth — synced, syncing, or offline — and never claim "synced" while a listener is actually dead,
So that I can trust the badge instead of seeing a stuck "N pending" / error card that masks the real state.

**Acceptance Criteria:**

**Given** `SyncStatus` today is a 7-case union (`localOnly`/`syncing`/`synced`/`pending`/`offline`/`error`/`degraded`, `lib/features/sync/domain/models/sync_status.dart`) with app-level `pendingChanges` counts and a `degraded` dead-letter-style state,
**When** status is derived,
**Then** it collapses to exactly `synced | syncing | offline`, derived only from SDK signals (`hasPendingWrites`, `isFromCache`, connectivity) and per-account app state — no app-level "N pending / N stuck" bookkeeping, no dead-letter counter remains (FR21, FR22; CAP-6; AD-11).

**Given** a backoff-capped / still-dead channel while connectivity is up (Story 1.1's exposed signal),
**When** status is computed,
**Then** that channel surfaces as `syncing` (in-flight/unsettled), **never** falsely `synced` and never `offline` (the network is fine) — the explicit AD-11 total-function rule that keeps the tri-state model complete without reviving an `error` state (FR17; CAP-5, CAP-6; AD-9, AD-11).

**Given** the removed `pending`/`error`/`degraded` states and their UI,
**When** the sync card renders (`lib/features/settings/presentation/widgets/backup_sync_section.dart:104-142`, mapper `lib/core/sync/providers/sync_status_providers.dart:54`),
**Then** no code path reads or displays an app-maintained pending/stuck count, and a permanently-rejected *write* is explicitly out of scope here (it is owned by the AD-30 recovery affordance in a later phase, not represented in this tri-state) (FR22; AD-11, AD-30).

**Given** the red-demo requirement,
**When** a test drives a dead-but-online channel and asserts the status,
**Then** before the fix the status can read `synced` (channel believed attached) or expose a `pendingChanges`/`degraded` value — the test fails; after the fix it reads `syncing` and the union offers no pending/dead-letter field — the test passes.

**Given** the gate + verification requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, user-visible status strings ship EN+HE arb parity (NFR-6) with no raw color literals (NFR-7), the SDK-signal slim-status invariant is verified across AD-29 tiers 1–2 (`hasPendingWrites`/`isFromCache` need the emulator; the fake cannot model them) (NFR-8), and it lands in an isolated worktree (shared CAP-6 status files; must land *after* Stories 1.1 and 1.4) (NFR-11).

## Epic 2: Migration Phase 0 — foundations and the go/no-go gate

The Firestore migration is proven feasible on real hardware and its data-integrity foundations exist: the two-named-app cache-isolation smoke test returns a recorded go/no-go (failure STOPS and reopens AD-1, with no ratified fallback — the owner rejected the reduced-experience option); deterministic doc-ids with no autoincrement landmines; the canonical LWW predicate in exactly one pinned module; and every boundary rule enforced by a `make audit` grep (not `custom_lint`, which is documented non-functional here). These are additive/refactor foundations — no collection is cut over in Phase 0. Stories that touch shared foundation files (`doc_ids.dart`, `conflict.dart`, Makefile grep defs) **run in isolated worktrees per NFR-11** and must not run concurrently with a sibling editing the same file.

### Story 2.1: Prove two-named-app cache isolation on the oldest supported device (go/no-go gate)

As the repo owner making the migration go/no-go decision,
I want the per-account named-`FirebaseApp` topology run and verified on the oldest supported device,
So that the entire migration paradigm is proven feasible on real hardware before any Phase-1 investment — and if it fails, we stop and reopen AD-1 instead of building on sand.

**Acceptance Criteria:**

**Given** the AD-1 topology `[ASSUMPTION]` (N named apps against the *same* project/database, differing only by app-name + Auth identity, each retaining a fully independent persistent cache on Android) is not an officially blessed configuration,
**When** a two-named-app / one-project / two-anonymous-user smoke test runs on the oldest supported device (built as a `tool/device_e2e/` harness against seeded `emulator-5556`, Parent PIN 2580 — AD-29 tier 3),
**Then** writes and listeners in app A are provably invisible to app B's cache, and the test asserts **no cache-directory collision** between the two named apps (FR1; CAP-1; AD-1, AD-29).

**Given** the CAP-1 gate semantics,
**When** the smoke test completes,
**Then** its result is recorded as an ADR/memlog event in `docs/planning/architecture/architecture-learning-tracker-2026-07-30/.memlog.md`, and a **failure is an explicit STOP signal that reopens AD-1 with no ratified fallback** (the owner rejected the reduced-experience "only most-recent account offline" option) — the AC states this outcome verbatim (CAP-1 gate; AD-1 "What could kill this" #1).

**Given** the red-demo requirement (the assertion must have teeth),
**When** the harness is deliberately mis-configured so the two contexts share one app-name / one cache directory,
**Then** the test must FAIL loudly — app B sees app A's writes and/or the cache-dir collision check trips — proving the isolation assertion can actually detect a violation rather than passing vacuously.

**Given** the oldest-hardware resource risk (the `api29-learn-oom` thread is a live warning),
**When** the two named apps run concurrently with persistence enabled on the oldest supported device,
**Then** the pass/fail bar is binary — the two-app run completes with **no resource failure** (no OOM kill, no file-handle exhaustion, no cache-init crash) at the 2-app shape (the leading edge of the ≤5-account target); the recorded memory/file-handle numbers are observational evidence attached to the memlog event, not themselves the gate (CAP-1; AD-1).

**Given** the gate requirements,
**When** the story is complete,
**Then** the smoke test passes on the oldest supported device, its go result is recorded, and `make ci MAKE_CI_RC=0` + `make audit` (67 greps) stay green (the harness adds no analyzer/format/grep regression); this story is on-device (AD-29 tier 3) rather than a shared-source edit, so no worktree-isolation collision applies (NFR-11).

### Story 2.2: Extract deterministic doc-id formulas into one module, byte-for-byte

As a migration engineer,
I want every collection's doc-id formula in one standalone module that reproduces today's outputs byte-for-byte,
So that native writes and the Phase-5 backfill mint the exact same document ids as the live engine — no duplicate remote docs, no orphaned history.

**Acceptance Criteria:**

**Given** doc-id derivation is today scattered across `lib/core/sync/firestore_gateway_impl.dart` `.doc(...)` sites (e.g. `curriculum_tracks` in `pushTrack` — `_collection(profileId, 'curriculum_tracks')` `:346` → `collection.doc(docId).set(...)` `:357`; ULID-keyed ledger/points/streak/redemption `:302/:516/:541/:1219/:1242`) and the per-collection codecs (`lib/core/sync/codec/*.dart`),
**When** the formulas are extracted into a new `lib/data/firestore/doc_ids.dart`,
**Then** the module reproduces **every** formula byte-for-byte *except* the AD-25 track-scoped re-key (owned by Story 2.3), keeping every legacy field-alias path intact (FR2; CAP-2; AD-5, AD-13).

**Given** the byte-for-byte requirement,
**When** unit tests compare `doc_ids.dart` output against the current gateway/codec output for a representative document of every synced collection,
**Then** all outputs match exactly (AD-29 tier 1, pure-unit) (FR2; AD-5, AD-13, AD-29).

**Given** the red-demo requirement,
**When** a test deliberately perturbs one extracted formula (e.g. drops a separator or swaps a natural-key component),
**Then** the byte-for-byte golden test fails on that collection — proving the golden pins the exact formula, not an approximation.

**Given** this is Phase-0 additive scaffolding,
**When** `doc_ids.dart` lands,
**Then** it is a pure string-formula module with no `cloud_firestore` import (so it does not trip the Story 2.6 Firebase-confinement grep), and no feature yet imports it (no cutover in Phase 0) (AD-28 interplay; CAP-2).

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps) are green, tests are seed-randomized (NFR-4) and TQ-3/TQ-6-compliant (NFR-5), and it lands in an isolated worktree because `doc_ids.dart` is a shared foundation file (NFR-11).

### Story 2.3: Re-key track-scoped children to curriculum_id, mint profile-scoped ULIDs, standardize ULID generation

As a migration engineer,
I want the one canonical stable track key, profile-scoped ULID profile ids, and a single ULID generator,
So that cross-device docs match after the per-device `track_id` is abolished, an account's many profiles never collide onto one document, and there is exactly one id-minting code path.

**Acceptance Criteria:**

**Given** track-scoped children today embed the per-device `track_id` in their doc-ids and rely on `resolveLocalTrackId` remapping (`drift_merge_store.dart`), and AD-13 byte-for-byte is provably impossible for these collections,
**When** `doc_ids.dart` expresses the track-scoped child formulas (`stage_definitions`, `study_day_configs`, `goals`),
**Then** the single canonical stable track key is `curriculum_id` (consistent with `curriculum_tracks/{curriculum_id}`) — e.g. `stage_definitions/{curriculum_id}_{stageOrder}` — with no track ULID and the `resolveLocalTrackId` remap retired by construction (FR3; CAP-2; AD-5, AD-25).

**Given** the `learner_profiles` doc-id is today the path-derived profile id (`firestore_gateway_impl.dart:1290` `.doc(profileId.toString())`), which would collide every child of an account onto one document,
**When** `doc_ids.dart` mints the `learner_profiles` doc-id,
**Then** it is a profile-scoped stable **ULID** minted per profile — distinct from the path uid (`users/{uid}/learner_profiles/{profileId}`) — never the account/Firebase uid (FR4; CAP-2; AD-5, AD-24).

**Given** the in-repo generator `lib/core/time/ulid.dart` (`newUlid`) and the existing call sites (`learning_ledger.dart:35`, `points_balance_dao.dart`),
**When** ULID generation is standardized,
**Then** every ULID emission routes through that one module, **no new pub.dev package is added** (the only viable `ulid: ^2.0.1` stays out), and the profile-ULID minting reuses `newUlid` (FR5; CAP-2; AD-5).

**Given** the red-demo requirement,
**When** tests assert (a) a track-scoped child doc-id built from a per-device `track_id` is rejected in favor of the `curriculum_id`-keyed form, (b) two profiles under one account get distinct ULID doc-ids rather than colliding on the path uid, and (c) any ULID minted outside `lib/core/time/ulid.dart` is flagged,
**Then** before the fix (a) yields the old `{perDeviceTrackId}_*` shape, (b) collides, and (c) an alternate generator is undetected — the tests fail; after the fix all three pass.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, and it lands in an isolated worktree editing the shared `doc_ids.dart` — and therefore lands **after** Story 2.2 and never concurrently with it (NFR-11).

### Story 2.4: Sweep and gate autoincrement-id-in-payload landmines

As a migration engineer,
I want a report of every autoincrement-id-in-payload landmine and a standing grep that keeps them out,
So that device-local Drift ids can never leak into a synced payload and break cross-device FKs after cutover — and the MCF-11 class stays closed permanently, not just once.

**Acceptance Criteria:**

**Given** the MCF-11 landmine class (device-local autoincrement ids appearing inside synced payloads) exists on paths outside `merge/`,
**When** the Phase-0 sweep runs,
**Then** it produces an attached landmine-sweep report enumerating every autoincrement-id-in-payload site (or confirming none), fulfilling the Phase-0 exit deliverable (FR6; CAP-2, CAP-4; AD-5, AD-28; Additional Requirements — Phase-0 exit).

**Given** AD-28's rule that the MCF-11 sweep becomes a **standing** gate (not a one-time audit),
**When** the audit runs,
**Then** a new `make audit` grep bans autoincrement-id-in-payload **outside `merge/`**, enforced by grep only (never `custom_lint`, which is documented non-functional here) (FR6, FR10; CAP-4; AD-5, AD-28).

**Given** the red-demo requirement (the grep must have teeth),
**When** a test/fixture plants an autoincrement id inside a payload on a path outside `merge/`,
**Then** the new grep flags it and `make audit` fails; with the planted violation removed, the grep passes on the current tree (green, not yet tripping any real code) (FR6; AD-28).

**Given** the shared-Makefile edit,
**When** the grep is added,
**Then** `make audit` still reaches its "audit PASSED" terminus with the new CAP-4 grep folded into the suite (count rises from 67 as the new grep lands), and `make ci MAKE_CI_RC=0` stays green (NFR-2, NFR-3),
**And** the story lands in an isolated worktree because it edits the shared Makefile grep definitions, and must not run concurrently with Story 2.6 (which also edits audit greps) (NFR-11).

### Story 2.5: Extract the canonical LWW predicate and route every merger through it

As a migration engineer,
I want the 5-step LWW decision in exactly one module that every reconciliation path calls,
So that no hand-copied second implementation can drift and silently ship a lost-update bug again (the AUD-t-cross-68 class).

**Acceptance Criteria:**

**Given** the real 5-step algorithm today lives in `driftMergeStoreRemoteIsNewer` (`lib/core/sync/merge/drift_merge_store.dart:25-64`), a superseded plain copy in `merge_rules.dart:28-35` (still used by `StudyDayConfigMerger`), and a bespoke plain-`isAfter` in the RewardRedemption path (`reward_redemption_merger.dart:61` → `pointsBalanceDao.upsertRemoteRedemption`, F3),
**When** the predicate is extracted,
**Then** the canonical LWW decision (±5 s clock-skew window → `synced_at` server-timestamp tie-break → D15 prefer-newer-un-pushed-local → remote-wins-on-true-tie) lives in **exactly one** module, `lib/data/firestore/conflict.dart` (FR11; CAP-3; AD-7, AD-29).

**Given** the FB-3 cache-echo guard (`hasPendingWrites`/`isFromCache`) must be preserved,
**When** every merger/reconciliation path is rerouted,
**Then** all of them — including `StudyDayConfigMerger` and RewardRedemption's bespoke plain-`isAfter` (F3) — call the single `conflict.dart` predicate unconditionally, with **no per-merger exception and independent of AD-21 gating**, and the legacy `merge_rules.dart` predicate is removed once it has zero callers (FR13; CAP-3; AD-7).

**Given** the golden-branch pinning requirement (AD-29 tier 1),
**When** unit tests run,
**Then** every predicate branch is pinned with a golden case: the ±5 s window, the `synced_at` tie-break, D15 prefer-newer-un-pushed-local, and remote-wins-on-true-tie (FR12; CAP-3; AD-7, AD-29).

**Given** the red-demo requirement closing the hand-copy-drift class,
**When** a test introduces a hand-copied/drifted second implementation (e.g. one that omits the D15 fallback, exactly the AUD-t-cross-68 defect),
**Then** the suite fails on that drifted copy, and a grep-gated single-module check fails if any reconciliation path re-implements the predicate instead of calling `conflict.dart` — proving a second copy cannot silently exist (FR12; AD-7, AD-28, AD-29).

**Given** the Story 2.2 grep-safety pattern and that Story 2.5 lands *before* the Story 2.6 grep widening,
**When** `lib/data/firestore/conflict.dart` lands,
**Then** it is a pure decision module — plain `DateTime`/`bool`/duration parameters with **no** `cloud_firestore` import (callers pass in the `synced_at` values and the FB-3 `hasPendingWrites`/`isFromCache` booleans) — so it cannot trip the not-yet-widened Firebase-confinement grep, keeping 2.5's "`make audit` green" claim true even though `lib/data/firestore/**` is not yet on the allow-list (FR11; CAP-3; AD-28 interplay).

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (67 greps, plus the single-module predicate grep) are green, tests are seed-randomized (NFR-4) and TQ-3/TQ-6-compliant (NFR-5), no shipped P0 (MCF-2/6/8/9/11) is reopened (NFR-10), and it lands in an isolated worktree because `conflict.dart` and the merger fleet are shared foundation files (NFR-11).

### Story 2.6: Retarget and add the boundary-enforcement greps

As a migration engineer,
I want the Firebase-confinement grep retargeted and new dependency-direction and bare-instance greps added,
So that when features start reading through repositories, the layer boundaries are mechanically enforced by `make audit` — the only enforcement that actually runs here.

**Acceptance Criteria:**

**Given** the shipped `no-firebase-outside-core` gate today confines Firebase symbols to `lib/core/sync/` + `lib/core/auth/` (`Makefile` checks `1/15` and `2/15`, `:356-368`), that today's check `2/15` **additionally carves out** `lib/core/providers/` and all of `lib/features/` from the scan (`:364-366`), and that the engine is not deleted until Phase 6,
**When** the grep is retargeted,
**Then** its allowed-dir list is **widened** to include `lib/data/firestore/**` and `lib/data/repositories/**` alongside the retained legacy `lib/core/sync|auth` entries (so the still-live engine is not flagged), **and** the existing `lib/core/providers/` + `lib/features/` carve-outs are removed/tightened so that a feature/service/provider file importing `cloud_firestore` actually fails the gate (today those files are silently exempt); the grep stays green on the current tree (not yet tripped, no feature imports Firestore) (FR7; CAP-4; AD-28, AD-3).

**Given** AD-2's bare-instance ban,
**When** a new grep is added,
**Then** it bans bare `FirebaseFirestore.instance` / `FirebaseAuth.instance` outside the `AccountFirebase` registry (FR8; CAP-4; AD-28, AD-2).

**Given** AD-23's dependency direction,
**When** a new grep/analyzer check is added,
**Then** it enforces that no `lib/features/**` or `lib/domain/**` file imports the data-access ring past a repository interface (FR9; CAP-4; AD-28, AD-23),
**And** all three of these mechanical boundary rules are enforced via `make audit` greps only, never `custom_lint` (documented non-functional — a green `dart run custom_lint` is not a passing signal) (FR10; CAP-4; AD-28).

**Given** the red-demo requirement (each grep must have teeth),
**When** fixtures plant (a) a `cloud_firestore` import in a feature file, (b) a bare `FirebaseFirestore.instance` outside the registry, and (c) a `lib/features/**` import reaching past a repository interface,
**Then** each corresponding grep flags its violation and `make audit` fails; with the planted violations removed, all three greps pass green on the current tree (FR7, FR8, FR9; AD-28).

**Given** the shared-Makefile edit and Phase-0 exit,
**When** the story is complete,
**Then** `make audit` reaches "audit PASSED" with the retargeted + new CAP-4 greps folded in (the suite count rises from 67 as each new grep lands, and stays green per NFR-3), `make ci MAKE_CI_RC=0` is green (NFR-2), and it lands in an isolated worktree editing shared Makefile grep definitions — after Stories 2.2/2.5 (so `lib/data/firestore/**` exists) and never concurrently with Story 2.4 (NFR-11).
