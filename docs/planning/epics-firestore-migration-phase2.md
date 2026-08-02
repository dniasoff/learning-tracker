---
superseded_by: docs/firestore-rewrite-map.md
superseded_on: 2026-08-02
superseded_note: "MIGRATION MACHINERY SUPERSEDED — owner scrapped the phased migration for a single-phase clean rewrite (greenfield, no users, no back-compat). The DESIGN invariants here are still good; the phasing, strangler waves, back-compat, shadow writes, rollback and feature flags are dead. See docs/firestore-rewrite-map.md."
stepsCompleted: [scoped]
status: draft
scopeVerification:
  daoImportingFiles: "37 total (grep -rlE \"import.*_dao\\.dart\" lib/features/), confirmed 2026-08-02 — matches expectation"
  legitimateRepoLayer: "7 (files whose path contains data/repositories/), confirmed — differs from the baseline doc's earlier '10 repo-layer' figure; the 7/30 split is the one this document uses"
  trueBypasses: "30, confirmed"
  perFeatureBreakdown: "progress 7, account 6, learning 5, scheduler 4, tracks 3, onboarding 3, dashboard 3, content_browsing 2, sync 1, settings 1, notifications 1, gamification 1 — all confirmed exactly against expectation"
  emptyRepositoryScaffoldDirs: "12, confirmed by direct enumeration (find lib -type d -name repositories, zero .dart files) — DIFFERS from migration-plan.md's stated 10. Flagged as an open discrepancy; this document uses 12 (the verified number) and lists all 12 by path."
  tutorGrantsNativePath: "Confirmed and more nuanced than the plan assumed — see 'What tutor_grants actually looks like today' below."
ownerDecisionsCarriedForward:
  - "AD-19/AD-24 ratified 2026-07-30: local-born tier = Anonymous Auth; anon-uid instability handled by named-app-key-is-registry-UUID + path-uid remap-on-reset. The re-home HALF of that remap is unshipped — this document's Epic 3 closes it."
  - "Phase-1 closing decision (coordinator, 2026-08-02): accountFirebaseProvider is keepAlive, not autoDispose. A named app is created once per account per process, disposed only on explicit account removal. The kMaxDeviceAccounts+1 cushion is KEPT for now, explicitly deferred to 'Phase 2 once the removal wiring lands' — this document's Story 3.2 is that trigger."
inputDocuments:
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/migration-plan.md
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/.memlog.md
  - docs/specs/spec-drift-firestore-migration/SPEC.md
  - docs/specs/spec-drift-firestore-migration/traceability.md
  - docs/planning/drift-to-firestore-migration-baseline.md
  - docs/planning/epics-firestore-migration-phase0.md
  - learning_tracker/lib/ (direct enumeration — see scopeVerification)
---

# Learning Tracker — Firestore Migration Phase 2 (Repository Seam + `tutor_grants` Vertical Slice) — Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for **migration-plan Phase 2** ("Repository seam + `tutor_grants` vertical slice", effort class **L**), decomposing **CAP-8** plus three correctness-gating obligations recorded in `.memlog.md` during Phase 1 into implementable stories. Phase 0 (foundations, id hygiene, the AD-1 go/no-go gate) and Phase 1 (the `AccountFirebase` per-account named-app registry) are **both complete and merged to `dev`** — verified directly against the repo (`lib/data/firestore/{account_firebase,account_firebase_providers,conflict,doc_ids}.dart` exist; `make audit` runs 68 greps; the R7 ratchet baseline is 43 and the bare-Firebase-instance ratchet baseline is 2, both matching the values this document's NFRs pin). This document assumes that starting state; it does not re-derive it.

**A fresh session with no prior context can start Phase 2 from this file alone**, provided it also has read access to the five upstream companions listed in `inputDocuments` for AD/MCF/FR definitions this document only cites by id.

## What Phase 2 actually is

Migration-plan Phase 2 has two entry/exit-tested halves and this document adds a third, carried forward from Phase 1's own memlog rather than from the plan:

1. **Repository seam closure** — every one of the 30 true direct-DAO bypass files (Story-set: Epic 2) routes through a repository interface, and the 12 empty repository scaffold dirs (Story-set: Epic 2) are filled or the feature is re-pointed at an existing one — so that when Phase 3 cuts a collection over, only the repository's *implementation* changes, not 30 call sites.
2. **The `tutor_grants` vertical slice** (Epic 1) — the one already-Firestore-native collection (MCF-30) becomes the reference implementation every Phase-3 wave copies: repository over a **named app**, codec, doc-id/collection registration, canonical-predicate reconciliation, a resubscribe-on-error listener. **This story must be exemplary and land first**, stylistically (not as a file dependency — see Parallelization below).
3. **Three Phase-1 memlog obligations** (Epic 3) that gate correctness rather than the seam: the deferred AD-24 anon-reset *re-home* half; wiring `activeAccountIdProvider` into real bootstrap/sign-in/switch call sites; wiring `disposeAccountFirebase` into the real account-removal flow (plus the resulting `kMaxDeviceAccounts + 1` cushion reassessment).

**Hard gate already in force.** Story 2.6 of Phase 0 retired the blanket `lib/features/` + `lib/core/providers/` carve-out from the `no-firebase-outside-core` grep (`Makefile:356-368`, checks 1/15 and 2/15) and widened its allow-list to `lib/data/firestore/**` + `lib/data/repositories/**`. Phase 2's exit criterion — *"zero feature/service/provider files import `cloud_firestore`"* — is therefore **already mechanically enforced by `make audit` today**, before a single Epic-1/2/3 story lands. No story in this document needs to add that grep; every story's job is to not trip it while wiring real Firestore access through for the first time. This is a hard gate, not an aspiration.

## What `tutor_grants` actually looks like today (verified; more nuanced than the plan text implies)

The baseline/plan describe `tutor_grants` as "already Firestore-native... the working shipped precedent." Direct code inspection shows this is true for **write-lifecycle mutations** but **not** for the live UI read path, which matters for how Story 1.2's AC are written:

- **Real UI-facing repository today:** `FirestoreTutorGrantRepository` (`lib/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart`). Every mutation (`inviteTutor`/`acceptInvite`/`declineInvite`/`rescindInvite`/`revokeGrant`/`resignGrant`) and every list read (`listIncomingGrantsWithStatus`/`listOutgoingGrants`/`listPendingInvitesForMe`) goes through an **Admin-SDK Cloud Functions callable** (`_functions.httpsCallable(...)`). There is **no direct Firestore SDK read or write** anywhere in this file — no `snapshots()`, no `.get()`, no `.set()`.
- **The only direct-Firestore code for this collection** is `FirestoreGatewayImpl.listenToTutorGrants` (`lib/core/sync/firestore_gateway_impl.dart:1014-1060`), wired into `FirestoreListenerSource` (`lib/core/sync/firestore_listener_source.dart:131`) purely to feed the **no-op** `TutorGrantMerger` (`lib/core/sync/merge/tutor_grant_merger.dart:19-32`, explicit "No local storage — tutor grants are Firestore-live. No-op.") so the old engine's pull pipeline doesn't halt on the kind. **Nothing reads its output** — it exists only so `MergeRouter` doesn't stall Phase-6-doomed pull pagination on this kind.
- **Consequence for Story 1.2:** the vertical slice is not "rewire an existing live listener onto a named app." There is no existing live `snapshots()` listener feeding the UI to rewire — Story 1.2 must **build tutor_grants' first real Firestore listener**, replacing the CF-poll-on-demand pattern (`pendingTutorInvites`, `incomingTutorGrantsProvider` in `manage_tutors_providers.dart` — the two-provider AUD-tutoring-03 split noted in `tutor_grant_providers.dart:79-88`) with a live, resubscribing, canonical-predicate-reconciled read, while mutations correctly stay on the CF-callable path (grants are server-minted and the security model requires Admin-SDK writes — that does not change).
- **No doc-id formula exists yet** for `tutor_grants` in `lib/data/firestore/doc_ids.dart` (grant ids are server-minted by the `inviteTutor` callable, never client-derived). Story 1.2's "deterministic doc-id" AC (AD-5/AD-13) for this collection is therefore about **routing/registration parity** (AD-17: kind ↔ collection ↔ registration ↔ codec), not about minting a new client-side id formula — flag this distinction explicitly in the story so it isn't dropped as "already done."

## A blocking cross-cutting risk found during verification (not one of the three named memlog obligations, but must be closed alongside them)

`LifecycleObserver.resetFirestoreNetwork` (hook wired from `lib/core/sync/providers/firestore_instance_provider.dart:73`, invoked at `lib/core/sync/sync_orchestrator.dart:582`) targets **the default Firebase app's** Firestore instance — there is no per-account variant. Phase 1's independent review already flagged this exact fact as **non-blocking finding #13** ("`resetFirestoreNetwork` still targets the default app... once Phase 2 reads through named apps it recycles the WRONG channel (reintroduces AUD-core-sync-14)") and explicitly deferred it to "when its trigger lands" — which is now: Story 1.2 is the first story in the whole migration to put a real, resubscribing `snapshots()` listener behind a **named** app. If Story 1.2 ships its resubscribe-on-error machinery (reused from Story 1.1's `ListenerSupervisor`, AD-9) without first repointing the network-reset hook, the reset silently resets the wrong app's gRPC channel and the tutor_grants listener's resubscribe path is invisibly broken from day one. **This document makes that repoint Story 1.1**, landing before the vertical slice, exactly because it is a shared, high-blast-radius file that the exemplary Story 1.2 must not have to work around.

## Requirements Inventory

### Functional Requirements

1. Every one of the 12 empty repository scaffold dirs is filled with a real repository interface + implementation, or its feature is re-pointed at an existing repository elsewhere in the tree, before that feature's DAO-bypass files close. (CAP-8; AD-3, MCF-13-scaffold)
2. Every one of the 30 true direct-DAO bypass files reads/writes through a repository interface; a repository may be a thin pass-through delegating straight back to its DAO (Phase-3 rollback requirement). (CAP-8; AD-3, MCF-13-scaffold)
3. `tutor_grants` reads flow through a repository resolved via `accountFirebase(activeAccountId)` with a real `snapshots()` listener, replacing today's CF-callable-only UI path (there is no existing live listener to "rewire" — see above). (CAP-8; AD-1, AD-2)
4. The `tutor_grants` listener wraps mark-dead + bounded-exponential-backoff resubscribe, reusing Story 1.1 (Epic-1-of-Phase-0)'s `ListenerSupervisor` machinery rather than a second implementation. (CAP-8; AD-9)
5. `tutor_grants` reconciliation calls the single canonical predicate module (`lib/data/firestore/conflict.dart`), not the no-op `TutorGrantMerger`. (CAP-8; AD-7)
6. `tutor_grants`' kind/collection/registration/codec is registered in the AD-17 4-way parity acceptance test alongside every other kind. (CAP-8; AD-17, MCF-30, MCF-32)
7. `resetFirestoreNetwork` (and any sibling still-default-app-scoped listener-reset plumbing) is repointed to the active account's named app before the `tutor_grants` listener ships, closing Phase-1-review finding #13. (CAP-8; AD-2, AD-9)
8. A grep proves zero `lib/features/**`/`lib/domain/**`/service/provider file imports `cloud_firestore`, tripped for real for the first time as `tutor_grants` and the bypass-closure stories land (the gate already exists per Story 2.6 of Phase 0 — this FR is about not tripping it, not building it). (CAP-8; AD-3, AD-28)
9. `activeAccountIdProvider` is **written**, not just declared, by bootstrap, sign-in, and account-switch call sites (`lib/app/bootstrap/account_bootstrap.dart`, `SessionPersistenceService.resolveActiveAccountId()` callers). (memlog obligation "b"; AD-2, AD-24)
10. `disposeAccountFirebase` is called from all three `AccountLifecycleService` removal flows (`removeCloudFromDevice`, `deleteLocalAccount`, `deleteCloudAccount`). (memlog obligation "c"; AD-1)
11. Once FR10 lands, the in-memory `kMaxDeviceAccounts + 1` registry cushion is reassessed and removed if the residual `_pending`-during-first-resolve race no longer requires it (explicitly deferred to this point by the Phase-1 closing decision). (memlog follow-up decision)
12. The AD-24 anon-reset **re-home** half ships: on a detected anon-uid reset for a registry account, `users/<oldUid>/...` is copied to `users/<newUid>/...` under that account's named app, consuming the `previousFirebaseUid`/`uidRemappedAt` breadcrumb columns P1-B left for exactly this purpose. (memlog obligation "a"; AD-19, AD-24)

### NonFunctional Requirements

1. Every fix ships a red-demo (fails before, passes after).
2. `make ci MAKE_CI_RC=0` required.
3. `make audit`'s current 68-grep suite stays green. No story in this document is expected to need a *new* grep (Phase 0 already added the CAP-4 greps) — if one turns out to be necessary, say so explicitly in that story rather than silently growing the suite.
4. Tests stay green under `--test-randomize-ordering-seed=random`.
5. New/changed tests follow TQ-3/TQ-6 rules.
6. User-visible string changes ship EN+HE `.arb` parity.
7. No new raw color literals.
8. R7 ratchet stays **at its current baseline, 43** (`tool/r7_source_text_assertion_baseline.txt`) — no new test may read `lib/` source text and assert on the string instead of on behavior.
9. The bare-Firebase-instance ratchet stays **at its current baseline, 2** (`tool/bare_firebase_instance_baseline.txt`) — no new bare `FirebaseFirestore.instance`/`FirebaseAuth.instance` site outside `lib/data/firestore/account_firebase.dart` is introduced by any story in this document.
10. No change may reopen a shipped P0 (MCF-2/6/8/9/11).
11. Worktree isolation applies to any story editing a file another concurrently-running story in this document also edits (see per-story notes and Parallelization below); AD-29's three-tier verification split applies wherever a story touches an SDK-signal invariant (`isFromCache`/`hasPendingWrites`, resubscribe-on-error) that `fake_cloud_firestore` cannot model.

### Additional Requirements

- **Phase 2 entry** (migration-plan): Phase 1 exit. Verified met — `accountFirebaseProvider` is `@Riverpod(keepAlive: true)` (commit `08d15c20`/`7ae1c496`), the four Phase-1-review defects are fixed (commit `6dfd65c8`/`a6d300fc`), `activeAccountIdProvider`/`disposeAccountFirebase` exist in `lib/data/firestore/account_firebase_providers.dart` (unwired — see Epic 3).
- **Phase 2 exit** (migration-plan, verbatim): zero feature/service/provider files import `cloud_firestore` (lint proves it — already true structurally, must stay true); `tutor_grants` reads/writes entirely through its repository over a named app; resubscribe-on-error red-demo passes; parity acceptance test green; `make ci` + `make audit` green.
- **Ships to users** (migration-plan): tutor-grant reads now flow through the named-app path — low blast radius, already-native data, a safe first production exposure of the new stack.
- **Risk-register carryover (a)** (migration-plan Phase 2 risk register): closing 27→30 (verified) bypasses touches files across hot paths → regression surface; land behind per-feature review, keep repositories thin pass-throughs first. Governs every Epic 2 story.
- **Risk-register carryover (b)**: Riverpod-return-type friction with Drift-generated model types (MCF-10-codegen) → use a hand-written `StreamProvider`/`FutureProvider` fallback, not `@riverpod` codegen, for any repository method whose return type is (or wraps) a raw Drift row class. Concretely on today's tree this bites hardest in **Story 2.1 (progress)** and **Story 2.4 (scheduler)** — `scheduler/domain/repositories/goal_repository.dart` and `.../scheduler_stage_repository.dart` already sit next to Drift-generated `CurriculumTrack`/`Goal` row types (`db.trackDao.getTrackById`, `dashboard_providers.dart:189`), and `progress`'s aggregation services (`chart_data_service.dart`, `curriculum_progress_service.dart`) consume `db.completionDao` result rows directly today.
- **Discrepancy flagged, not resolved:** migration-plan.md's Phase 2 scope text says "Fill/re-point the **10** empty repository scaffold dirs." Direct enumeration (`find lib -type d -name repositories` filtered to zero `.dart` files) finds **12**: `notifications/data/repositories`, `dashboard/data/repositories`, `dashboard/domain/repositories`, `onboarding/data/repositories`, `onboarding/domain/repositories`, `gamification/data/repositories`, `gamification/domain/repositories`, `settings/data/repositories`, `settings/domain/repositories`, `sync/data/repositories`, `sync/domain/repositories`, `tracks/setup/domain/repositories`. This document plans against the verified 12, and flags the plan text as stale rather than silently correcting it upstream.
- **Naming inconsistency found in the singles group:** `lib/features/notifications/data/services/sacred_window_repository.dart` is named "repository" but lives under `data/services/`, not `data/repositories/`, and its sibling `notifications/data/repositories` dir is one of the 12 empty scaffolds. Story 2.7 should decide whether to relocate it into the scaffold or leave it and fill the scaffold with something else — flagged, not resolved, here.
- **`ProfileRepository` reuse, not a new scaffold, for Story 2.2 (account):** all 6 of the `account` feature's DAO-bypass files import `user_profile_dao.dart` directly (`auth_state.dart`, `local_auth_service.dart`, `upgrade_to_cloud_service.dart`, `sign_in_controller.dart`, `auth_state_provider.dart`, `account_picker_screen.dart`). `lib/features/profiles/domain/repositories/profile_repository.dart` + `ProfileRepositoryImpl` (`lib/features/profiles/data/repositories/profile_repository_impl.dart`) already exists and already wraps this same user-profile data (via `user_database.dart`, itself a thin wrapper over the DAO) — and its impl already imports the `tutoring` feature's barrel file for a cross-feature reference, establishing the Rule-2-compliant precedent Story 2.2 should follow (`import '.../features/profiles/profiles.dart'` barrel, not a deep import). Story 2.2 is therefore **"re-point 6 files at an existing cross-feature repository,"** not "build a new `AccountRepository."** Confirm during story kickoff that `ProfileRepository`'s surface actually covers what each of the 6 call sites needs (some may need a narrow addition to the interface) — flagged as a design check, not assumed complete.

### UX Design Requirements

No UX design contract applies to this scope (Phase 2 ships no new user-visible surface beyond the existing tutor-grant screens now reading through a different data path).

### FR Coverage Map

FR1: Epic 2 — Fill/re-point the 12 empty repository scaffold dirs
FR2: Epic 2 — Close all 30 true direct-DAO bypass files to a repository interface
FR3: Epic 1 — `tutor_grants` reads flow through a named-app repository with a real listener
FR4: Epic 1 — `tutor_grants` listener gets resubscribe-on-error (reused machinery)
FR5: Epic 1 — `tutor_grants` reconciliation calls the canonical predicate module
FR6: Epic 1 — `tutor_grants` registered in the AD-17 4-way parity test
FR7: Epic 1 — Repoint `resetFirestoreNetwork`/reset plumbing to the named app first
FR8: Epic 1, Epic 2 — Zero feature/service/provider file trips the `cloud_firestore` grep
FR9: Epic 3 — `activeAccountIdProvider` is written by real bootstrap/sign-in/switch call sites
FR10: Epic 3 — `disposeAccountFirebase` wired into `AccountLifecycleService`'s removal flows
FR11: Epic 3 — Reassess/remove the `kMaxDeviceAccounts + 1` cushion once FR10 lands
FR12: Epic 3 — Ship the AD-24 anon-reset re-home half

## Epic List

### Epic 1: The `tutor_grants` vertical slice — the reference implementation
Proves the end-to-end Firestore-native repository pattern on the one collection already served without Drift, over a **named** `AccountFirebase` app, with a real resubscribing listener and canonical-predicate reconciliation — the exemplary template every Phase-3 wave copies. Must land first, stylistically (see Parallelization).
**FRs covered:** FR3, FR4, FR5, FR6, FR7, FR8 (CAP-8 — AD-1, AD-2, AD-7, AD-9, AD-17, AD-28)

### Epic 2: Repository seam — close the direct-DAO bypasses
Fills the 12 empty repository scaffold dirs and closes all 30 true direct-DAO bypass files, feature by feature, so that when a collection cuts over in Phase 3 only its repository *implementation* changes — no feature call site does.
**FRs covered:** FR1, FR2, FR8 (CAP-8 — AD-3, MCF-13-scaffold)

### Epic 3: Correctness-gating obligations carried from Phase 1
Closes three Phase-1 memlog obligations that gate correctness rather than the repository seam itself: real wiring for `activeAccountIdProvider`, real wiring for `disposeAccountFirebase`, and the deferred AD-24 anon-reset re-home half — plus the cushion reassessment the Phase-1 closing decision explicitly deferred to this point.
**FRs covered:** FR9, FR10, FR11, FR12 (AD-1, AD-2, AD-19, AD-24)

---

## Epic 1: The `tutor_grants` vertical slice — the reference implementation

### Story 1.1: Repoint listener network-reset from the default app to the active named app

As a migration engineer building the first real listener behind a named `AccountFirebase` app,
I want the existing resubscribe/network-reset plumbing to act on the *active account's* app instead of the default app,
So that Story 1.2's `tutor_grants` listener doesn't silently recycle the wrong gRPC channel on reset — closing Phase-1-review finding #13 before it can bite.

**Acceptance Criteria:**

**Given** `LifecycleObserver.resetFirestoreNetwork` (hook supplied from `lib/core/sync/providers/firestore_instance_provider.dart:73`, invoked at `lib/core/sync/sync_orchestrator.dart:582`) today calls `disableNetwork()`/`enableNetwork()` on the **default** app's `FirebaseFirestore` instance unconditionally,
**When** the active account has a named `AccountFirebase` app resolved,
**Then** the reset targets that named app's `FirebaseFirestore` instance (via `accountFirebase(activeAccountId).firestore`), and the default-app instance is reset only for pre-Phase-1 default-app-only concerns (device registry / pre-auth) that still exist until Phase 6 (FR7; AD-2, AD-9).

**Given** the old engine (`SyncOrchestrator`, still live until Phase 6) also calls `resetFirestoreNetwork` on its own connectivity/resume paths,
**When** this story repoints the hook,
**Then** the old engine's own reset behavior against its own (default-app) Firestore usage is unaffected — this story adds an account-scoped path, it does not remove the default-app path the still-live engine depends on (no regression to Story 1.3-of-Phase-0's connectivity/resume resubscribe).

**Given** the red-demo requirement,
**When** a test resolves two named apps (A, B), makes A active, and triggers a reset,
**Then** before the fix the test cannot distinguish which app was reset (or asserts against the default app only) and fails to prove account-scoping; after the fix the test asserts B's channel is untouched and only A's is reset.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, tests are seed-randomized (NFR-4) and TQ-3/TQ-6-compliant (NFR-5), and it lands in an **isolated worktree** because it edits shared `lib/core/sync/{lifecycle_observer.dart,sync_orchestrator.dart}` + `lib/core/sync/providers/firestore_instance_provider.dart` — files the still-live Phase-0-era `sync-wave*` discipline also touches (NFR-11). **Must land before Story 1.2**, which depends on this repoint existing before it ships a real named-app listener.

### Story 1.2: Build the `tutor_grants` repository over the named app — the vertical-slice template

As a migration engineer,
I want `tutor_grants` served entirely through a repository resolved via `accountFirebase(activeAccountId)`, with a real listener, codec, doc-id/collection registration, and canonical-predicate reconciliation,
So that this becomes the exemplary, copy-able pattern for every Phase-3 collection — proving the whole target architecture end-to-end on the one collection that was never encumbered by Drift.

**Acceptance Criteria:**

**Given** today's `tutor_grants` access is split between `FirestoreTutorGrantRepository` (100% Cloud-Functions-callable, zero direct SDK read — see "What `tutor_grants` actually looks like today" above) and the old engine's `listenToTutorGrants`/no-op `TutorGrantMerger` (feeds nothing),
**When** the vertical slice lands,
**Then** a new repository implementation reads `tutor_grants` via a real `snapshots()` query resolved through `accountFirebase(activeAccountId).firestore`, while every **mutation** stays routed through the existing CF-callable methods on `FirestoreTutorGrantRepository` (grants remain server-minted/Admin-SDK-written by design — this does not change) (FR3; AD-1, AD-2).

**Given** Story 1.1 has repointed the network-reset hook,
**When** the new `tutor_grants` listener errors,
**Then** it wraps mark-dead + bounded-exponential-backoff resubscribe by **reusing** the `ListenerSupervisor` machinery Story 1.1-of-Phase-0 (Epic 1, `lib/core/sync/listener_supervisor.dart`) already built for own-account channels — not a second bespoke implementation (FR4; AD-9).

**Given** the canonical predicate module `lib/data/firestore/conflict.dart` (Story 2.5 of Phase 0) already exists and is called by nothing outside its own unit tests today,
**When** the new repository reconciles an incoming snapshot against local state,
**Then** it calls that single module — not the no-op `TutorGrantMerger`, which this story does not delete (the old engine still owns it until Phase 6, per the plan's per-collection rollback discipline: the legacy no-op path stays wired so `MergeRouter` doesn't stall on the kind) (FR5; AD-7).

**Given** AD-17's routing-parity invariant (kind ↔ collection ↔ registration ↔ codec),
**When** the repository is registered,
**Then** a routing-parity acceptance test proves `tutorGrant` is registered against the `tutor_grants` collection with its codec, alongside the existing 18-kind parity test's pattern (this document does not require rewriting that test — it requires `tutor_grants`' *new* repository-side registration to be provable the same way) (FR6; AD-17, MCF-30, MCF-32).

**Given** no doc-id formula exists yet in `doc_ids.dart` for this collection (grant ids are server-minted),
**When** the repository resolves a document reference for a read,
**Then** it does so by the server-assigned `grantId` field already present on every `TutorGrant`/`TutorGrantDoc` — this story does **not** invent a client-side doc-id formula for `tutor_grants` (that would contradict the server-minting design) and says so explicitly in its implementation notes, so a future reader does not mistake the absence of a `doc_ids.dart` entry for an oversight.

**Given** the "zero feature/service/provider file imports `cloud_firestore`" gate is already live (Story 2.6 of Phase 0),
**When** the new repository implementation is added under `lib/features/tutoring/data/repositories/`,
**Then** it imports `cloud_firestore` from **within its own `data/repositories/` dir** (the allowed pattern per the grep's allow-list), and no file outside that dir (no provider, no domain model, no presentation screen) gains a `cloud_firestore` import (FR8; AD-3, AD-28).

**Given** the red-demo requirement,
**When** a test forces the new listener into `onError` and then pushes a new server snapshot, and separately asserts the old CF-poll path still serves mutations,
**Then** before the fix the channel stays dark (no resubscribe wiring exists yet) and the test fails; after the fix the channel resubscribes within the backoff schedule and the snapshot is delivered, while `inviteTutor`/`acceptInvite`/etc. still round-trip through their CF callables unchanged.

**Given** the gate + verification requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, tests are seed-randomized (NFR-4) and TQ-3/TQ-6-compliant (NFR-5), the invariant is verified across AD-29 tiers 1 (pure-unit codec/registration) and 2 (emulator resubscribe-on-error, `isFromCache`/`hasPendingWrites`) (NFR-8), no shipped P0 is reopened (NFR-10), and the story lands in its own worktree scoped to `lib/features/tutoring/**` + new test files — **disjoint from Story 1.1's shared-file edits**, so it can start as soon as Story 1.1 merges, without waiting on any Epic 2/3 story (NFR-11).

---

## Epic 2: Repository seam — close the direct-DAO bypasses

*Grouping rationale:* the four largest per-feature totals (progress 7, account 6, learning 5, scheduler 4) are their own stories; the three mid-size features (tracks 3, onboarding 3, dashboard 3) and the two smallest (content_browsing 2, and the four true singles sync/settings/notifications/gamification at 1 each) are paired/grouped to balance story size at roughly 4-6 files each, since none of these feature directories overlap on disk — grouping introduces no file collision. **Risk-register carryover (a) governs every story below: thin pass-through repositories first, per-feature review, per-feature rollback** (a repository may delegate straight back to its DAO — Phase 3 is where the DAO body actually gets replaced).

### Story 2.1: Close the `progress` feature's DAO bypasses (7 files)

As a migration engineer,
I want every `progress` file that imports a DAO directly to instead depend on a repository interface,
So that `progress`'s eventual Firestore cutover in Phase 3 touches one implementation, not `chart_data_service.dart`, `curriculum_progress_service.dart`, and three presentation providers independently.

**Acceptance Criteria:**

**Given** `progress` has one already-legitimate repository (`progress/data/repositories/progress_repository_impl.dart` + `progress/domain/repositories/progress_repository.dart`) and six bypass files (`domain/repositories/progress_repository.dart` itself importing a DAO type for a signature, plus `domain/services/chart_data_service.dart`, `domain/services/curriculum_progress_service.dart`, `presentation/providers/items_learned_providers.dart`, `presentation/providers/lifetime_knowledge_providers.dart`, `presentation/providers/progress_providers.dart`),
**When** the six are closed,
**Then** each depends on `ProgressRepository` (extended if its surface doesn't yet cover a call site's need) instead of importing `completion_dao.dart`/`goal_dao.dart`/`track_dao.dart` directly (FR2; AD-3).

**Given** risk-register carryover (b) (MCF-10-codegen),
**When** a repository method's return type wraps a raw Drift row (e.g., a `CurriculumTrack` surfaced today via `db.trackDao.getTrackById` in the dashboard-adjacent aggregation path this feature also touches),
**Then** that method is exposed via a hand-written `StreamProvider`/`FutureProvider`, not `@riverpod` codegen, and this is called out explicitly in the story's implementation notes rather than discovered as a build failure.

**Given** the red-demo requirement,
**When** a test asserts each of the six files' import list,
**Then** before the fix a DAO import is present and the test fails; after the fix only the repository import remains.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized (NFR-4) and TQ-3/TQ-6-compliant (NFR-5), no new bare-instance or R7 violation is introduced (NFR-8/9), and it lands in a worktree scoped to `lib/features/progress/**` — **disjoint from every other Epic 2/3 story**, so it can run fully in parallel with them (NFR-11).

### Story 2.2: Close the `account` feature's DAO bypasses by re-pointing at `ProfileRepository` (6 files)

As a migration engineer,
I want `auth_state.dart`, `local_auth_service.dart`, `upgrade_to_cloud_service.dart`, `sign_in_controller.dart`, `auth_state_provider.dart`, and `account_picker_screen.dart` to depend on the existing `ProfileRepository` instead of importing `user_profile_dao.dart` directly,
So that `account`'s six files get the seam for free from a repository that already exists and already wraps this exact data, instead of a new `account`-local repository being invented redundantly.

**Acceptance Criteria:**

**Given** all six files import `lib/core/database/daos/user_profile_dao.dart` directly, and `lib/features/profiles/domain/repositories/profile_repository.dart` + `ProfileRepositoryImpl` already exist and already wrap this same data via `user_database.dart`,
**When** the six files are closed,
**Then** each depends on `ProfileRepository` via the `profiles` feature's barrel file (`import '.../features/profiles/profiles.dart'`) — the same cross-feature-barrel pattern `ProfileRepositoryImpl` itself already uses to reach `tutoring.dart` — never a deep import into `profiles/data/**` (Rule 2 compliance) (FR2; AD-3).

**Given** `ProfileRepository`'s current interface may not cover every one of the six call sites' exact needs (this is a design check this story must perform, not assume),
**When** a gap is found,
**Then** the interface is extended narrowly (new method, not a new parallel repository) and the extension is documented in the story's notes so Story 2.2 doesn't silently duplicate `ProfileRepository`'s responsibility with an `AccountRepository`.

**Given** `account/data/repositories/auth_repository_impl.dart` + `domain/repositories/auth_repository.dart` already exist and are unrelated to this bypass set (they cover credential/session concerns, not profile-row reads),
**When** this story completes,
**Then** it does not touch `AuthRepository` — the six files' concern is profile data, not authentication, and conflating the two would misattribute the fix.

**Given** the red-demo requirement,
**When** a test asserts each of the six files' import list,
**Then** before the fix a `user_profile_dao.dart` import is present and the test fails; after the fix only the `profiles` barrel import remains.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, and it lands in a worktree scoped to `lib/features/account/**` (read-only touch on `lib/features/profiles/domain/repositories/profile_repository.dart` if extended — coordinate with Story 2.1, which does not touch this file, so no real collision) (NFR-11).

### Story 2.3: Close the `learning` feature's DAO bypasses (5 files, 1 already legitimate)

As a migration engineer,
I want `completion_writer.dart`, `mark_completion_result.dart`, `domain/repositories/completion_repository.dart`, and `bulk_mark_completion_use_case.dart` routed through `CompletionRepository` (already implemented at `learning/data/repositories/completion_repository_impl.dart`),
So that the highest-volume, most defect-prone kind in the whole migration (completions — MCF-6/MCF-8b/MCF-writer) has exactly one seam by the time Phase 3 Wave D touches it.

**Acceptance Criteria:**

**Given** `learning` already has a legitimate `CompletionRepository`/`CompletionRepositoryImpl` and four remaining bypass files,
**When** the four are closed,
**Then** each depends on `CompletionRepository` instead of importing `completion_dao.dart`/`completion_events_dao.dart` directly, preserving `CompletionWriter`'s existing one-transaction guarantee (completion + outbox + tombstone-resurrection + B8 prior-import upgrade, MCF-writer) — this story does **not** change write atomicity, only the import path (FR2; AD-3).

**Given** this is the collection the plan explicitly calls "the single most dangerous port" (H2/D11) and schedules last (Phase 3 Wave D),
**When** the repository wrapping happens,
**Then** it is a strictly thin pass-through — no behavior change, no new merge logic — verified by a test that the DAO-level tombstone-resurrection and prior-import-upgrade behavior is bit-for-bit unchanged before/after the re-point (NFR-10, MCF-6/MCF-8b).

**Given** the red-demo requirement,
**When** a test asserts each of the four files' import list and a behavioral test drives tombstone resurrection through the new path,
**Then** before the fix a DAO import is present (test fails on imports) or the resurrection test cannot run through a repository at all; after the fix only the repository import remains and resurrection behavior is unchanged.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, no P0 is reopened (NFR-10 — this is the story where that check matters most), and it lands in a worktree scoped to `lib/features/learning/**` (NFR-11).

### Story 2.4: Close the `scheduler` feature's remaining DAO bypass (4 files, 3 already legitimate)

As a migration engineer,
I want `scheduler_providers.dart` routed through the scheduler feature's existing repository set instead of importing `completion_dao.dart` directly,
So that `scheduler` — which already did most of this work (3 of its 4 DAO-touching files are legitimate `data/repositories/` implementations) — finishes closing its one remaining gap.

**Acceptance Criteria:**

**Given** `scheduler` already has `scheduler_completion_repository_impl.dart`, `scheduler_learning_order_repository_impl.dart`, and `scheduler_stage_repository_impl.dart` (all legitimate) plus one bypass, `presentation/providers/scheduler_providers.dart`,
**When** the bypass is closed,
**Then** `scheduler_providers.dart` depends on `SchedulerCompletionRepository` (or the narrowest applicable existing interface) instead of `completion_dao.dart` directly (FR2; AD-3).

**Given** risk-register carryover (b) (MCF-10-codegen) and that `scheduler/domain/repositories/goal_repository.dart` and `scheduler_stage_repository.dart` already sit adjacent to Drift-generated `Goal`/`CurriculumTrack` row types,
**When** `scheduler_providers.dart` is rewired,
**Then** any provider whose return type would otherwise be a raw Drift row is a hand-written `StreamProvider`/`FutureProvider`, called out explicitly rather than hit as a build surprise.

**Given** the red-demo requirement,
**When** a test asserts `scheduler_providers.dart`'s import list,
**Then** before the fix a DAO import is present and the test fails; after the fix only the repository import remains.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, and it lands in a worktree scoped to `lib/features/scheduler/**` (NFR-11). Smallest story in Epic 2 — good first pick if any story needs to land early to de-risk the pattern before Story 2.1/2.3's larger blast radius.

### Story 2.5: Close the `tracks` and `onboarding` bypasses (3 + 3 = 6 files)

As a migration engineer,
I want `tracks`' two service-layer bypasses plus its one legitimate `stage_definition_repository_impl.dart`, and all three of `onboarding`'s bypasses, routed through repositories,
So that two mid-size, disjoint feature trees close together without needing a dedicated story each.

**Acceptance Criteria:**

**Given** `tracks/domain/services/curriculum_activation_service.dart` and `track_progress_service.dart` import a DAO directly while `tracks/stages/data/repositories/stage_definition_repository_impl.dart` is already legitimate,
**When** the two bypasses are closed,
**Then** each depends on an existing or narrowly-extended repository (`StageDefinitionRepository` or a track-level equivalent) instead of the DAO (FR2; AD-3).

**Given** `onboarding/domain/services/{bulk_prior_completion_service.dart,learning_process_wizard_service.dart,user_profile_service.dart}` all bypass DAOs directly and `onboarding/data/repositories`+`onboarding/domain/repositories` are both **empty scaffolds** (2 of the 12),
**When** `onboarding` is closed,
**Then** both scaffold dirs are filled with a real repository interface + implementation (or `onboarding` is re-pointed at an existing cross-feature repository, per the same design check as Story 2.2) before the three service files are rewired (FR1, FR2; AD-3, MCF-13-scaffold).

**Given** `bulk_prior_completion_service.dart`'s connection to `PriorCompletionImports`/B8 (the "delete the moment a real completion is written" rule, MCF-8b),
**When** it is rewired,
**Then** its interaction with `learning`'s `CompletionRepository` (Story 2.3) is read-only from `onboarding`'s side (no new write path invented here) — flag any coupling discovered between the two features during rewiring rather than silently resolving it.

**Given** the red-demo requirement,
**When** a test asserts the import list of all six files,
**Then** before the fix DAO imports are present in some/all of them and the test fails; after the fix only repository imports remain, and (for `onboarding`) both scaffold dirs are non-empty.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, and it lands in a worktree scoped to `lib/features/tracks/**` + `lib/features/onboarding/**` — disjoint from every other Epic 2 story (NFR-11).

### Story 2.6: Close the `dashboard` and `content_browsing` bypasses (3 + 2 = 5 files)

As a migration engineer,
I want `dashboard`'s three bypasses (two empty scaffold dirs to fill first) and `content_browsing`'s one remaining bypass (its `text_cache_repository.dart` is already legitimate) routed through repositories,
So that these two disjoint, medium-size feature trees close together.

**Acceptance Criteria:**

**Given** `dashboard/domain/services/{parent_dashboard_aggregator.dart,track_completion_service.dart}` and `presentation/providers/dashboard_providers.dart` all bypass `completion_dao.dart` directly, and `dashboard/data/repositories`+`dashboard/domain/repositories` are both **empty scaffolds** (2 of the 12),
**When** `dashboard` is closed,
**Then** both scaffold dirs are filled (or `dashboard` is re-pointed at `learning`'s `CompletionRepository`, since `dashboard_providers.dart:189` already reads a `CurriculumTrack` via `db.trackDao.getTrackById` — a strong signal this feature should consume `learning`/`progress`'s repositories rather than mint a third), before the three files are rewired (FR1, FR2; AD-3, MCF-13-scaffold).

**Given** risk-register carryover (b) (MCF-10-codegen) applies directly here — `dashboard_providers.dart:189`'s `db.trackDao.getTrackById(goal.trackId)` returns a raw Drift `CurriculumTrack`,
**When** this is exposed through a repository,
**Then** the corresponding provider is a hand-written `StreamProvider`/`FutureProvider`, not `@riverpod` codegen, called out explicitly.

**Given** `content_browsing/data/services/text_download_service.dart` bypasses a DAO directly while `content_browsing/data/repositories/text_cache_repository.dart` is already legitimate,
**When** it is closed,
**Then** it depends on the existing content-browsing repository instead of the DAO (FR2; AD-3). Note: Content DB collections stay local per AD-16 regardless — this is seam-closure only, not a Firestore-cutover signal for this feature.

**Given** the red-demo requirement,
**When** a test asserts the import list of all four bypass files across both features,
**Then** before the fix DAO imports are present and the test fails; after the fix only repository imports remain, and `dashboard`'s scaffold dirs are non-empty.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, and it lands in a worktree scoped to `lib/features/dashboard/**` + `lib/features/content_browsing/**` — disjoint from every other Epic 2 story (NFR-11).

### Story 2.7: Close the four single-file bypasses — `sync`, `settings`, `notifications`, `gamification`

As a migration engineer,
I want the four features that each have exactly one DAO-bypass file, and whose scaffold dirs are mostly empty (5 of the 12 empty dirs live here), closed together as one story,
So that four small, disjoint fixes don't each need their own story overhead.

**Acceptance Criteria:**

**Given** `sync/data/outbox_sync_write_facade.dart` bypasses a DAO directly and both `sync/data/repositories`+`sync/domain/repositories` are **empty scaffolds**,
**When** `sync` is closed,
**Then** the scaffold is filled or the facade is left as an explicitly-noted exception (it is itself part of the old engine slated for Phase 6 deletion — MCF-1-facade/AD-21 — so gold-plating its repository seam may be a low-value effort; the story must state which choice it makes and why, not silently pick one) (FR1, FR2; AD-3).

**Given** `settings/domain/services/data_export_import_service.dart` bypasses a DAO directly and both `settings/data/repositories`+`settings/domain/repositories` are **empty scaffolds**,
**When** `settings` is closed,
**Then** the scaffold is filled with a repository covering export/import's data needs, and the service depends on it (FR1, FR2; AD-3).

**Given** `notifications/data/services/sacred_window_repository.dart` bypasses a DAO directly, is misleadingly named "repository" while living in `data/services/` (not `data/repositories/`), and `notifications/data/repositories` is an **empty scaffold** while `notifications/domain/repositories/notification_preferences_repository.dart` already exists,
**When** `notifications` is closed,
**Then** the story explicitly decides — and documents — whether to (a) relocate `sacred_window_repository.dart` into the scaffold dir and rename it to match, or (b) leave it in `data/services/` and fill the scaffold with a distinct notification-preferences-facing repository; either is acceptable, but the ambiguity must not be silently resolved without a note (FR1, FR2; AD-3).

**Given** `gamification/domain/services/points_service.dart` bypasses a DAO directly and both `gamification/data/repositories`+`gamification/domain/repositories` are **empty scaffolds** — the feature whose Phase-3 target (AD-4, derived-not-counter) is one of the two `dangerous`-class MCF risks (MCF-2),
**When** `gamification` is closed,
**Then** the scaffold is filled and `points_service.dart` depends on it as a thin pass-through — this story does **not** change balance-derivation logic (that is Phase 3 Wave C's job under AD-4), only the import seam (FR1, FR2; AD-3, NFR-10).

**Given** the red-demo requirement,
**When** a test asserts the import list of all four bypass files,
**Then** before the fix each has a DAO import and the test fails; after the fix each depends on its repository, and all five scaffold dirs touched by this story (`sync` ×2, `settings` ×2, `notifications` ×1) are non-empty or explicitly-justified exceptions.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, no P0 is reopened (NFR-10 — binds `gamification` specifically), and it lands in a worktree scoped to `lib/features/{sync,settings,notifications,gamification}/**` — disjoint from every other Epic 2 story (NFR-11).

---

## Epic 3: Correctness-gating obligations carried from Phase 1

*These three stories gate correctness, not the repository seam — they can run in parallel with Epic 1 and Epic 2 (different files entirely: `lib/app/bootstrap/**`, `lib/features/account/domain/services/account_lifecycle_service.dart`, `lib/data/firestore/account_firebase*.dart`) but should be sequenced 3.1 → 3.2 (the cushion reassessment in 3.2 explicitly depends on 3.2's own wiring landing) and 3.3 independently.*

### Story 3.1: Wire `activeAccountIdProvider` into bootstrap, sign-in, and account-switch

As a migration engineer,
I want `activeAccountIdProvider` actually written by the real account-activation call sites instead of standing declared-but-unused,
So that the `AccountFirebase` registry (which every later Firestore read resolves through via `activeAccountId`) reflects the real active account instead of always resolving to `null`.

**Acceptance Criteria:**

**Given** `activeAccountIdProvider` (`lib/data/firestore/account_firebase_providers.dart:298-304`, backed by the `ActiveAccountId` `Notifier<String?>` at `:333`) is only **read** today (`ref.watch(activeAccountIdProvider)` at `:304`) and `SessionPersistenceService.resolveActiveAccountId()` (`lib/features/account/domain/services/session_persistence_service.dart:79`) is called directly by `lib/app/bootstrap/account_bootstrap.dart:39` and `lib/features/settings/presentation/utils/account_actions.dart:554` with no write-back to the provider,
**When** bootstrap resolves the active account, and when sign-in/account-switch changes it,
**Then** each of those three call sites also **writes** the resolved account id into `activeAccountIdProvider` (via its `Notifier` setter), so the registry's `activeAccountId` reflects reality end-to-end (FR9; AD-2, AD-24).

**Given** non-blocking Phase-1-review finding #7 (`DeviceRegistryDatabase.updateAccountTier:146-157` writes `firebaseUid` unconditionally, bypassing the path-uid resolver and stamping no breadcrumb — harmless today because local-born rows have a null uid, but becomes a data-loss bug the moment AD-19 gives local-born accounts an anon uid),
**When** this story wires the provider,
**Then** it does **not** fix finding #7 (out of this story's scope — it's a `updateAccountTier` call-site bug, not an `activeAccountIdProvider` wiring gap) but **notes it explicitly** as a pre-condition Story 3.3 (AD-24 re-home) must re-check before it ships, since Story 3.3 is exactly "the moment AD-19 gives local-born accounts an anon uid" in practice.

**Given** the red-demo requirement,
**When** a test drives bootstrap → sign-in → switch and reads `activeAccountIdProvider` after each step,
**Then** before the fix the provider stays `null`/stale throughout (test fails); after the fix it tracks the real active account at every step.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, the bare-instance ratchet stays at 2 (NFR-9 — this story must not introduce a new bare-instance site while wiring), and it lands in a worktree scoped to `lib/app/bootstrap/**` + the three named call sites + `account_firebase_providers.dart` (NFR-11).

### Story 3.2: Wire `disposeAccountFirebase` into account removal; reassess the `kMaxDeviceAccounts + 1` cushion

As a migration engineer,
I want account removal to actually tear down that account's named `FirebaseApp`/cache, and the temporary registry-slot cushion reassessed now that removal is real,
So that a remove-then-add cycle in one session doesn't hold onto apps for accounts that no longer exist, and the `+1` headroom the Phase-1 fix added isn't left in place past its stated justification.

**Acceptance Criteria:**

**Given** `disposeAccountFirebase(ref, accountId)` (`account_firebase_providers.dart:292`) exists and is correct but has **zero callers**, and `AccountLifecycleService.{removeCloudFromDevice:58, deleteLocalAccount:96, deleteCloudAccount:125}` call `DeviceRegistryDatabase.removeAccount` (`device_registry_database.dart:130`) with `AccountLifecycleService` itself a plain non-Riverpod class constructed ad hoc (no `Ref` access) from `account_picker_screen.dart`/`account_actions.dart`,
**When** any of the three removal flows completes,
**Then** `disposeAccountFirebase` is called for that account — requiring `AccountLifecycleService` to gain either an injected callback (`Future<void> Function(String accountId) disposeFirebase`) at construction, or a `Ref`-bearing wrapper at its two construction sites — so the removed account's named app + 20 MiB cache are torn down, not merely orphaned in the registry (FR10; AD-1).

**Given** the Phase-1 closing decision explicitly deferred the `kMaxDeviceAccounts + 1` cushion's removal to "Phase 2 once the removal wiring lands, not as unreviewed churn now,"
**When** this story's wiring lands,
**Then** it reassesses whether the residual race the `+1` guards against (`disposeAccountFirebase` called while that account's first `resolve()` is still `_pending`) still occurs now that removal actually calls dispose — and either removes the `+1` (restoring the cap to exactly `kMaxDeviceAccounts` in the in-memory registry) with a red-demo proving the race no longer reproduces, or keeps it with an updated justification citing what changed; either outcome is acceptable, silence is not (FR11).

**Given** the red-demo requirement,
**When** a test removes an account via each of the three `AccountLifecycleService` flows and then re-adds a new account up to the device cap,
**Then** before the fix the removed account's app/cache is never disposed and a remove-then-add cycle can spuriously hit the cap (test fails); after the fix disposal happens on every removal path and the cap behaves per whatever this story decides about the `+1`.

**Given** the gate + isolation requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, no P0 is reopened, and it lands in a worktree scoped to `lib/features/account/domain/services/account_lifecycle_service.dart` + its two construction call sites + `lib/data/firestore/account_firebase{,_providers}.dart` — **should land after Story 3.1** only if both end up touching `account_firebase_providers.dart`'s same region; otherwise they are independent (verify before parallelizing) (NFR-11).

### Story 3.3: Ship the AD-24 anon-reset re-home half

As a migration engineer,
I want an anon-uid reset to actually copy `users/<oldUid>/...` to `users/<newUid>/...` under the affected account's named app, consuming the breadcrumb columns Phase 1 already left for this purpose,
So that a local-born account surviving a reinstall or App-Check-debug-token wipe doesn't lose its prior document tree — closing the half of AD-24 that P1-B explicitly left undone.

**Acceptance Criteria:**

**Given** P1-B already ships the **re-point** half (the registry re-points `firebaseUid` to the new live uid and stamps `previousFirebaseUid`/`uidRemappedAt` as a durable breadcrumb — memlog, 2026-08-02) but explicitly could not ship the **re-home** half because it "requires Firestore access... out of the registry-only scope of P1-B,"
**When** a re-point is detected (a non-null `previousFirebaseUid` whose re-home has not yet run),
**Then** this story adds the consuming step: under the account's named `AccountFirebase` app, copy every document tree the registry-derived collection set (AD-26) enumerates from `users/<previousFirebaseUid>/...` to `users/<newFirebaseUid>/...`, so the prior cache + document tree are not stranded (FR12; AD-19, AD-24).

**Given** non-blocking Phase-1-review finding #8 (the breadcrumb is **lossy**: a chained remap overwrites `previousFirebaseUid`, destroying the only pointer to the oldest tree, and there is no API to clear it once consumed),
**When** this story implements the consuming step,
**Then** it fixes finding #8 as a precondition — either by adding a "re-home consumed" marker so a chained remap doesn't need to preserve `previousFirebaseUid` indefinitely, or by copying eagerly enough that a second remap before the first re-home completes cannot lose the oldest tree — the story must not consume a lossy breadcrumb as-is and call the job done (AD-24).

**Given** non-blocking finding #7 (`updateAccountTier` writes `firebaseUid` unconditionally, bypassing the path-uid resolver, with no breadcrumb) is flagged by Story 3.1 as exactly the precondition this story must re-check,
**When** this story ships,
**Then** it verifies `updateAccountTier`'s 5 call sites cannot silently produce an unbreadcrumbed uid change for a local-born (AD-19 Anonymous-Auth) account before relying on the breadcrumb being complete — fix the call site if it can, flag-and-block if it's out of reach within this story's scope.

**Given** the destination is a live Firestore document tree under SR-1 append-only rules for history collections,
**When** the re-home copy runs,
**Then** it is idempotent (re-running after a partial failure does not duplicate or corrupt) and uses the same deterministic doc-id formulas (`doc_ids.dart`) as every other write path — no `collection.add()`, matching MCF-3/AD-5 discipline even though this is identity-remap code, not new user data.

**Given** the red-demo requirement,
**When** a test drives an anon-uid reset (old uid → new uid) with pre-existing documents under the old uid, then a **second** reset before the first re-home completes,
**Then** before the fix the prior tree is invisible under the new uid (test fails) and a chained reset loses the oldest tree entirely (finding #8); after the fix the new uid's tree is populated from the old, and a chained reset does not lose data.

**Given** the gate + verification requirements,
**When** the story is complete,
**Then** `make ci MAKE_CI_RC=0` and `make audit` (68 greps) are green, seed-randomized and TQ-3/TQ-6-compliant, the invariant is verified across AD-29 tier 2 (emulator — real document copies) and tier 3 if a device-level anon-uid-reset scenario is feasible to simulate, no P0 is reopened, and it lands in its own worktree scoped to new re-home logic under `lib/data/firestore/**` + `lib/core/database/registry/device_registry_database.dart` (breadcrumb consumption) — **independent of Stories 3.1/3.2** unless both end up touching the same registry file region (NFR-11).

---

## Parallelization summary

| Story | Touches | Can start in parallel with | Must land after |
|---|---|---|---|
| 1.1 (repoint network reset) | `lib/core/sync/{lifecycle_observer,sync_orchestrator}.dart`, `firestore_instance_provider.dart` | Epic 2 (all), Epic 3 (all) | — |
| 1.2 (tutor_grants slice) | `lib/features/tutoring/**`, new tests | Epic 2 (all), Epic 3 (all) | 1.1 |
| 2.1–2.7 | disjoint `lib/features/{progress,account,learning,scheduler,tracks+onboarding,dashboard+content_browsing,sync+settings+notifications+gamification}/**` | Epic 1, Epic 3, and each other (verify no shared barrel/DI file needs edits before assuming zero collision) | — |
| 3.1 (activeAccountIdProvider wiring) | `lib/app/bootstrap/**`, 3 call sites, `account_firebase_providers.dart` | Epic 1, Epic 2 | — |
| 3.2 (disposeAccountFirebase wiring + cushion) | `account_lifecycle_service.dart`, 2 construction sites, `account_firebase{,_providers}.dart` | Epic 1, Epic 2 | 3.1 only if both touch the same `account_firebase_providers.dart` region — verify at kickoff |
| 3.3 (AD-24 re-home) | new logic under `lib/data/firestore/**`, `device_registry_database.dart` breadcrumb consumption | Epic 1, Epic 2, 3.1, 3.2 | — (independent unless file-region check says otherwise) |

**Stylistic, not file, dependency:** Epic 1 (tutor_grants) is meant to be the *pattern* every Phase-3 wave copies. Nothing in Epic 2 or Epic 3 needs Epic 1 to merge first at the file level — they touch entirely different trees — but if a reviewer wants the "exemplary template" to exist before less-scrutinized bypass-closure work begins landing, sequence Epic 1 first by convention, not by blocking merges on it.
