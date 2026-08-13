---
id: SPEC-drift-firestore-migration
status: draft
companions:
  - ../../planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md
  - ../../planning/architecture/architecture-learning-tracker-2026-07-30/migration-plan.md
  - ../../planning/drift-to-firestore-migration-baseline.md
  - traceability.md
sources:
  - ../../planning/architecture/architecture-learning-tracker-2026-07-30/.memlog.md
---

> **ARCHIVED 2026-08-13 — superseded.** Superseded by `docs/firestore-rewrite-map.md`. Retained for history only; do not treat as current. See `docs/planning/firestore-finish-line-plan.md` for the live plan.

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. The **ARCHITECTURE-SPINE** (30 ADs, doc-id/predicate/registry detail, diagrams, the MCF→AD completeness map), the **migration-plan** (Phase 0–7 entry/exit/rollback), and the **baseline** (the MCF-1..35 register) are adopted whole: the kernel cites them, it does not duplicate them. AD-N and MCF-N ids are stable and citable. Source documents in `sources:` are for traceability only.

# Drift → Firestore-Native Migration

## Why

A **mandate to fix, and an opportunity to simplify.** The app's data layer is a 12.2k-line (64–65 file) custom Drift-plus-outbox sync engine — an Outbox, 18 mergers, a hand-rolled LWW predicate, a per-account Drift user DB, and a device-wide singleton orchestrator. The 2026-07-29 reliability review documents it as *fickle and heavy* (terminal-on-error listeners that stay dark, an unhardened connectivity source, unbounded reads) and it has repeatedly shipped data-loss P0s (counter lost-update, double-credit, tombstone resurrection, cross-account key collisions). The migration retires that engine and makes **Firestore the SDK-owned data layer** — offline persistence as the local read model, N per-account named `FirebaseApp` instances for true multi-account offline isolation, and a single narrow repository seam — yielding a smaller, maintainable codebase where the SDK owns sync. The engine encodes ~35 hard-won corruption guards; the whole risk of the work is porting the happy path and dropping one. Existing users and their historical cloud data must come through unbroken.

## Capabilities

- **CAP-1 — Named-app topology smoke test (existential gate)**
  - **intent:** The system can run N isolated per-account `FirebaseApp` instances against one Firestore project with independent local caches — proven feasible on real low-end hardware before the paradigm is committed.
  - **success:** A two-named-app / one-project / two-anonymous-user test on the **oldest supported device** shows writes + listeners in app A are invisible to app B's cache with no cache-directory collision; it passes before any Phase-1 investment. (AD-1, AD-29 tier-3)

- **CAP-2 — Deterministic id hygiene**
  - **intent:** No device-local Drift autoincrement id ever travels inside a synced payload; every document id is derived from a natural key or a ULID.
  - **success:** The doc-id module reproduces today's formulas byte-for-byte **except** the AD-25 track-scoped re-key; `learner_profiles` doc-id is a profile-scoped ULID distinct from the path uid; the canonical track key is `curriculum_id`; a standing grep finds zero autoincrement-id-in-payload outside `merge/`. (AD-5, AD-13, AD-24, AD-25)

- **CAP-3 — Single-owner canonical conflict predicate**
  - **intent:** Exactly one conflict-resolution decision governs every last-write-wins collection.
  - **success:** The ±5s → `synced_at` → D15 → true-tie predicate lives in one grep-pinned module called by every reconciliation path; golden branch tests pin all four cases; no second copy can exist (the AUD-t-cross-68 hand-copied-drift class is structurally impossible). (AD-7, AD-29 tier-1)

- **CAP-4 — Boundary enforcement via `make audit` greps**
  - **intent:** Every mechanical architecture boundary has a real mechanical gate that actually runs.
  - **success:** `no-firebase-outside-core` is retargeted to `lib/data/firestore/**` + `lib/data/repositories/**`; bare `FirebaseFirestore.instance`/`FirebaseAuth.instance` is banned outside the `AccountFirebase` registry; the autoincrement-in-payload sweep is a standing gate; a dependency-direction check is green — all under `make audit`, none relying on the non-functional `custom_lint`. (AD-28, AD-2, AD-3, AD-23)

- **CAP-5 — Listener resubscribe-on-error**
  - **intent:** A dead `snapshots()` channel never stays dark while the network is up.
  - **success:** Each listener marks-dead + bounded-exponential-backoff resubscribes; connectivity-online and resume trigger resubscribe of dead channels; own- and tutored-account listeners have parity; a capped-out retry surfaces as `syncing`, never falsely `synced`. Landable now on the current engine (survives the migration). (AD-9, AD-22)

- **CAP-6 — Connectivity-source fix + slim 3-state status**
  - **intent:** Sync status is exactly `synced | syncing | offline`, read from SDK signals alone.
  - **success:** Connectivity comes from the hardened `connectivityStreamProvider`/platform events (a direct `connectivity_plus` dependency), never the 5-second demo poller; an exhausted-dead channel maps to `syncing`; there is zero app-level pending/dead-letter bookkeeping. Landable now (survives the migration). (AD-11, E-1)

- **CAP-7 — Per-account named-`FirebaseApp` subsystem**
  - **intent:** Each device account (≤5) owns an isolated `FirebaseApp` with its own Auth, Firestore, and persistent cache, switchable instantly offline.
  - **success:** The `AccountFirebase` registry creates/tears-down `account_<registryUuid>` apps with a bounded-cache `Settings` pinned before first use; access resolves via `accountFirebase(activeAccountId)`; the named-app key is the stable device-registry UUID and the path uid is a persisted field with remap-on-anon-reset; two previously-synced accounts switch with the network disabled and no `PERMISSION_DENIED` flood. (AD-1, AD-2, AD-18, AD-24)

- **CAP-8 — Repository seam + `tutor_grants` vertical slice**
  - **intent:** Repositories are the sole data seam, and the end-to-end native pattern is proven on one already-native collection.
  - **success:** The 10 empty repository scaffold dirs are filled/re-pointed and the 27 direct-DAO bypasses closed so a grep proves zero feature/service/provider files import `cloud_firestore`; `tutor_grants` reads/writes entirely through its repository over a named app with codec, doc-id, canonical-predicate reconciliation, a resubscribe listener, and a green routing-parity test. (AD-3, AD-17, AD-23, AD-22)

- **CAP-9 — Per-collection strangler waves to native**
  - **intent:** Each synced collection is cut from Drift+merger to a native repository, risk-ordered and reversible per collection.
  - **success:** Each wave shadow-runs to **zero divergence** before reads flip; Wave A (the track-scoped identity cluster) cuts **atomically** carrying the AD-25 one-time re-key backfill with a cross-device match test; Wave B is the config/prefs fan-out (single owner); Wave C the append-only history with derived balances; Wave D completions + tombstones; per-wave red-demos cover tombstone resurrection, double-credit idempotency, and out-of-order arrival; the legacy path is retained for per-collection rollback. (AD-4, AD-5, AD-6, AD-7, AD-8, AD-10, AD-12, AD-13, AD-25, AD-27, AD-29 tier-2)

- **CAP-10 — Permanent-write-failure recovery affordance**
  - **intent:** A genuinely non-retryable write is never silently lost.
  - **success:** A `permission-denied`/non-retryable write (distinct from offline/backoff the SDK will drain) surfaces a per-item, out-of-band tap-to-retry separate from the 3-state chip; it is not a revived dead-letter counter, and it is the successor to the retired `error`-status/dead-letter recovery path. (AD-30)

- **CAP-11 — Cross-account defect fixes + Anonymous-Auth local-born tier + profile hard-delete**
  - **intent:** The shipped cross-account data-loss defects are fixed and the credential-less tier gets a real Firebase principal.
  - **success:** `deleteAccount` touches only the target account's namespaced keys (others intact); sync/restore flags are per-account; per-profile keys are namespaced `(accountId, profileId)` with an idempotent additive on-device re-home; the local-born tier is an Anonymous-Auth user, upgrade is account-linking, and it survives an anon-uid reset without stranding its cache/tree; `curriculum_scopes` runs full bidirectional owner sync; the write path is uniform with a transactional `fulfilRedemption`; a profile hard-delete uses the **registry-derived** collection set (including `curriculum_scopes` **and** `import_metadata`), batching client-deletable collections and routing SR-1 history through the CF `recursiveDelete` path, leaving **zero orphans**. (AD-14, AD-15, AD-19, AD-20, AD-21, AD-24, AD-26)

- **CAP-12 — Existing-user backfill + shadow verification + point of no return**
  - **intent:** Every existing user's cloud/local data lands natively with no loss and a clean before/after gate.
  - **success:** A device-local, per-account, idempotent Drift→named-app Firestore replay runs through the **live** codec/doc-id; precondition gates refuse a pre-v30 ledger, require schema ≥ v37, and re-verify `TrackLearningOrder.profileId`; a dual-run verifier asserts count + per-doc field equality per collection/account; the `firestoreSourceOfTruth` flag flips only on a clean verifier pass; a re-run is idempotent (no duplicates) and a mid-backfill crash is resumable; the Drift copy is retained read-only until Phase 6. (AD-13, AD-16, AD-29)

- **CAP-13 — Custom sync engine retirement & deletion**
  - **intent:** The custom engine is deleted once no account depends on it.
  - **success:** `lib/core/sync/**` (~12.2k lines, 64–65 files), the Outbox/OutboxProcessor/pipelines/ListenerSupervisor/MergeRouter/18 mergers/SyncKv, the per-account Drift user-DB schema, the confirmed dead paths, and the 84 orphaned sync test files are removed; no `cloud_firestore` import survives outside `data/firestore` + `data/repositories`; the app builds and passes full `make ci` + `make audit` with the engine absent; gated on all accounts past the point of no return and the retention window elapsed. (migration-plan Phase 6)

- **CAP-14 — Verification, telemetry & staged rollout**
  - **intent:** The previously-unmeasurable is made observable and the cutover rolls out safely.
  - **success:** Telemetry covers per-collection read counts per launch/resume, listener onError/resubscribe events, backfill/verifier outcomes, and a slim-status queue-depth proxy; App Check enforcement is confirmed green in production; rollout is staged by min-app-version/cohort with no cross-account regression; a full MCF-1..35 sign-off shows every register row handled by its AD. (AD-12, AD-29, migration-plan Phase 7)

## Constraints

- **Every MCF-1..35 (and suffixed variants) maps to an owning AD/capability or an explicit retirement rationale.** The spine's Capability→Architecture Map is the completeness contract (carried by the adopted baseline register); silently narrowing it reintroduces a shipped P0.
- **Child-data integrity — never reopen the shipped P0 corruption classes:** `PointsBalance` stays derived, never a synced counter (MCF-2); double-credit is closed by hard doc-id uniqueness (MCF-8); completion tombstone-resurrection matches the natural key **without** a timestamp filter (MCF-6); a pre-v30 ledger is **never** migrated (MCF-9); no device-local autoincrement id appears in any payload (MCF-11).
- **Cloud-schema continuity for existing users.** Reproduce every doc-id formula byte-for-byte and keep decoding every legacy field alias, **except** the AD-25 track-scoped one-time re-key to the `curriculum_id` key, where byte-for-byte is provably impossible. (AD-13, MCF-3-continuity)
- **Content DB and Device Registry stay local.** The bundled ~87K-row read-only Content DB (SeedManager gzip/`.bak` self-heal) and the pre-auth Device Registry never migrate to Firestore and must work offline from first launch. (AD-16, MCF-35)
- **Security-rules-as-boundary preserved.** SR-1 append-only (deny delete; update only on identical replay) and SR-3 real `Timestamp ≤ request.time` hold; App Check enforcement is extended to `firestore.rules` (`request.app`) **before** the strangler waves ship broadly, because the direct-SDK surface widens. (AD-12)
- **Mechanical boundary rules bind to `make audit` greps, never `custom_lint`** — which is documented non-functional in this repo (it reports "No issues found!" on real violations). (AD-28)
- **Strangler discipline.** Nothing legacy is deleted until its native replacement ships and shadow-verifies zero divergence; the engine is retired only in Phase 6, after every account passes the backfilled-and-verified point of no return. Rollback is per-collection until then.
- **Every phase exits green on `make ci` + `make audit` + its named red-demo gates,** and ships an internal-track release at each phase exit.
- **The named-app topology paradigm is contingent on the Phase-0 empirical smoke test (CAP-1)** passing on the oldest supported device — the single existential risk; no Phase-1 investment precedes it.

## Non-goals

- **No hardening of the custom sync engine beyond the two migration-surviving fixes** (resubscribe-on-error, AD-9; connectivity-source + slim-status, AD-11). The `sync-wave1/2/3` threads are frozen; outbox depth-gating, dead-letter accounting, batch-writer wiring, at-limit/cold-launch tuning and the remainder of the review's ~15 fixes are dropped as mooted by Phase-6 deletion.
- **No iOS work; Web offline-switch is an explicit non-target** (Web persistence differs) unless separately funded. (AD-18)
- **No Content-DB migration** — the bundled ~87K-row content DB and the `CitiesRepository` sqlite asset stay local/out-of-scope. (AD-16)
- **No rich pending-count status UI** — the slim 3-state is decided; no "N pending / N stuck" accounting, no dead-letter counter. (AD-11, MCF-22)
- **No parsha-level or content restructuring, and no server-side data migration** except the client-driven, idempotent `gamification_settings` fan-out.
- **Deferred, not in this migration:** delta-pull watermark + composite indexes, real-time re-scope to collaborative-only data, metered/cellular mode, the `sqlite3` 2.x→3.x upgrade, single-doc→collection preference-listener consolidation, and park-delay tuning. (spine Deferred)

## Success signal

The custom sync engine is gone — `lib/core/sync/**` (~12.2k lines, 64–65 files) plus its 84 sync test files deleted — and no `cloud_firestore` import survives outside `data/firestore` + `data/repositories`; all 30 ADs are enforced by named gates (retargeted `make audit` greps, unit-pinned predicate, per-wave shadow diffs, phase red-demos); existing users' data is byte-verified by a zero-divergence verifier before each account's point of no return; the reliability review's read-count/footprint targets are met; `make ci` + `make audit` stay green throughout with an internal-track release at every phase exit; and the MCF-1..35 register signs off with every row demonstrably handled by its AD.

## Assumptions

- N named `FirebaseApp` instances against one project/database with fully independent Android persistent caches are feasible on the oldest supported device. The work proceeds under this, **empirically gated by CAP-1** before any Phase-1 commitment; the API surface supports it but it is not an officially blessed configuration.
- `functions/**` (tutor invite/accept/revoke, `recursiveDelete`) stay unchanged; tutor read continues to hinge on `tutor_active_access` `exists()`; there is no server-side data migration except the client-driven `gamification_settings` fan-out.
- Android is the sole offline-switch target; Crashlytics/Analytics stay default-app-only, so per-account crash attribution is accepted as coarse (device-level).

## Open Questions

- Fate of legacy `users/{uid}/profile/data` and any pre-version `import_metadata` production data — a read-compat shim or a conscious GC? `import_metadata` is added to the AD-26 delete set, but its round-trip owner and the `profile/data` orphan path are not owned by any AD. (baseline Q11)
- If CAP-1 fails on old hardware there is **no ratified fallback** — the owner explicitly rejected the reduced-experience (most-recent-account-only offline) option, so a failed gate reopens the core paradigm decision. (What-could-kill-this #1)
- GoalMerger F4 tie-break reachability (MCF-27) is unconfirmed; the targeted unit test in Phase-3 Wave A decides preserve-vs-fix, so concurrent-decision behavior parity is undetermined until then.
