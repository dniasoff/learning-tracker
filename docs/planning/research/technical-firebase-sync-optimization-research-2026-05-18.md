---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - docs/_archive/superseded/tracking-system-review-2026-05-17.md
  - docs/planning/architecture-offline-v2.md
  - docs/planning/two-database-architecture.md
  - docs/_archive/superseded/exec-prompt-2026-05-17.md
workflowType: 'research'
lastStep: 6
research_type: 'technical'
research_topic: 'Optimizing Firebase two-way sync to reduce cloud cost, compute, network traffic, and sync latency'
research_goals: 'Make bulk marking operations fast and reliable (e.g. a full seder of 655 mishnayos); cut Firebase cloud cost, device compute load, and network traffic; minimize sync latency; deliver dependable two-way cloud backup and real-time multi-device sync on a shared account'
user_name: 'Daniel'
date: '2026-05-18'
web_research_enabled: true
source_verification: true
---

# Unfreezing the Sync Engine: Optimizing Firebase Two-Way Sync for Learning Tracker

**Date:** 2026-05-18
**Author:** Daniel
**Research Type:** technical
**Facilitated by:** Technical Research workflow (BMAD) — codebase investigation + current web-verified sources

---

## Research Overview

This report investigates why bulk-marking a *seder* of 655 mishnayos freezes the Learning Tracker app and fails to sync after 10+ minutes on a fast connection, and what to do about it. The investigation combined three parallel codebase-investigation agents (write path, sync-drain path, Firestore model/listeners), first-hand source verification, the prior `tracking-system-review-2026-05-17.md` assessment, the canonical `architecture-offline-v2.md` design, and current web-verified Firebase documentation.

The finding is unambiguous and consistent across every lens: **Firestore is not the bottleneck — the bespoke sync layer built on top of it is.** A 655-item bulk mark currently executes **655 separate database transactions on the UI thread**, enqueues every completion into **two independent sync queues** (~1,310 rows), and pushes them as **~1,310 individual, sequential, non-idempotent Firestore document writes**, while the device's own snapshot listeners re-process every one of those writes in an O(n²) self-echo storm. None of this is inherent to Firebase; all of it is fixable with established technique, incrementally, without a third rewrite.

The full executive summary, the 10-point fix, the phased wave roadmap, and the cost/risk analysis follow below. The companion runnable artifact is **[`docs/_archive/superseded/sync-rework-exec-prompt-2026-05-18.md`](../../_archive/superseded/sync-rework-exec-prompt-2026-05-18.md)**.

---

## Executive Summary

Bulk-marking 655 mishnayos is unworkable today because the sync layer — rebuilt in ~48 hours during the Epic 25/26/27 cutover and cut over before it was sound — multiplies one user action into thousands of operations and runs the heaviest of them on the UI thread.

A 655-item, single-stage bulk mark currently produces, mechanically:

- **655 separate Drift (SQLite) transactions** on the **UI isolate** — no batching, no isolate offload — saturating the event loop and freezing the app.
- **~1,310 queue rows** — every completion is written to **both** the new `outbox` table **and** the legacy `sync_queue` table, because the SyncEngine cutover migrated only half the path.
- **~1,311 individual Firestore document writes**, pushed **sequentially** with `collection.add()` — one network round-trip each, **no `WriteBatch`**, and **random document IDs** that make every write non-idempotent (retries and the dual queue create *duplicate* cloud documents).
- **A self-write listener storm** — the device's unfiltered whole-collection `completions` snapshot listener re-fires on each of its own local writes and re-scans the entire growing collection, producing roughly O(n²) database work and UI rebuilds.
- **Repeat work** from a missing flush-concurrency guard, a non-singleton `SyncOrchestrator`, duplicate `pull_on_launch`, and write-only summary maps recomputed on every push and never read.

The fix is **surgical and incremental, not a rewrite** — consistent with the `architecture-offline-v2.md` §4.1 design that is already documented but only half-implemented. It touches roughly a dozen files, almost all inside `lib/core/sync/`.

**Key Technical Findings:**

- The crisis is a **half-completed migration**, not an unsound architecture. The append-only `completion_events` event log is the *correct* model; the defect is the legacy `sync_queue`/`OfflineQueue` push path left running alongside the new `outbox`/`OutboxProcessor` path, with bulk-mark writing to both.
- The single biggest UI-freeze cause is **655 transactions instead of one** (`completion_repository_impl.dart:309-322`); the single biggest sync-latency cause is **655 sequential `collection.add()` round-trips with no batching** (`firestore_gateway_impl.dart:35`, `offline_queue.dart:235-413`).
- **Non-deterministic document IDs** (`collection.add()`) are both a correctness bug (duplicate cloud docs) and a cost bug (unbounded write/storage growth). The natural key (`profileId:sefariaRef:stageId:trackType`) is already computed as `entityKey` and is the obvious deterministic document ID — it is currently discarded.
- Firestore *natively* supports everything the goals require — real-time multi-device sync via snapshot listeners, two-way offline persistence, 10,000 writes/sec headroom. Migrating to PowerSync/Supabase/ElectricSQL would be a **third rewrite in a month** — the exact failure mode that produced this crisis.
- The intended conflict-resolution model (`architecture-offline-v2.md` §4.1) — append-only events merged forward by union, streaks/XP as reduced event logs, LWW for settings — is sound and CRDT-aligned. Append-only completion events are a grow-only set: with deterministic IDs they converge across devices with zero data loss.

**Technical Recommendations:**

1. **Stay on Firebase.** Fix the bespoke sync layer; do not migrate databases mid-crisis. Re-evaluate managed local-first sync (PowerSync) only as a *future* de-risking exercise once the local layer is provably sound.
2. **Batch the local write** — one transaction and batched inserts for the whole bulk operation. Eliminates the UI freeze.
3. **Collapse the dual queue** — `outbox` is the single source of truth; stop the second enqueue into `sync_queue`. Halves writes immediately.
4. **Batch and de-duplicate the cloud push** — chunked `WriteBatch` (≤500 ops) and deterministic document IDs derived from the natural key. Cuts ~1,310 round-trips to ~2 and makes every write idempotent.
5. **Stop the self-echo** — filter `metadata.hasPendingWrites` local echoes from snapshot listeners and merge incremental `docChanges` instead of re-scanning the whole collection. Add a flush-concurrency guard and make `SyncOrchestrator` a true singleton.
6. **Execute under a test net, in waves** — characterization tests first, then disjoint parallel fix agents, then `/bmad-code-review` with every finding fixed (medium and low included).

## Table of Contents

1. Technical Research Introduction and Methodology
2. The 655-Mishnayos Diagnosis — Current Architecture Analysis
3. Technology Stack Analysis
4. Integration and Interoperability Patterns
5. Architectural Patterns and Design
6. Performance and Cost Analysis
7. Implementation Approaches and Best Practices
8. Strategic Technical Recommendations
9. Implementation Roadmap and Risk Assessment
10. Security and Compliance Considerations
11. Future Technical Outlook
12. Methodology, Source Verification, and Appendices

---

## 1. Technical Research Introduction and Methodology

### 1.1 Technical Research Significance

Learning Tracker is a local-first Flutter app: a Drift (SQLite) database is the source of truth, and Firebase Firestore is a background two-way projection for cloud-born accounts. The promise of that design — instant local writes, sync that never blocks the UI — is currently broken for the single most important onboarding action: telling the app what you have already learned. A user enrolling with a *seder* of Mishnah behind them must mark ~655 items as prior learning. Today that action freezes the device and never finishes syncing.

This is not a cosmetic defect. It blocks onboarding, it erodes trust in the backup guarantee, and — per the prior assessment — it is the same root as the production "836 changes pending" / `flush_start pendingCount: 1052` runaway-queue incident. It is also a **cost** problem: every retry of a non-idempotent write creates a new cloud document, so the bill grows without bound while the data does not.

**Business impact:** the feature gates onboarding for exactly the experienced learners the app most wants; an unbounded write/storage path is a latent billing risk; and a sync layer that "never completes" undermines the two-way-backup value proposition.

### 1.2 Technical Research Methodology

- **Technical Scope:** the completion write path, the outbox/queue drain, the Firestore data model, snapshot listeners, conflict resolution, cost, and multi-device behavior.
- **Data Sources:** (a) three parallel codebase-investigation agents over `learning_tracker/lib`; (b) first-hand verification of the load-bearing files (`completion_repository_impl.dart`, `completion_writer.dart`, `offline_queue.dart`, `outbox_processor.dart`, `firestore_gateway_impl.dart`); (c) the prior `docs/_archive/superseded/tracking-system-review-2026-05-17.md` assessment; (d) canonical design docs (`architecture-offline-v2.md`, `two-database-architecture.md`); (e) current Firebase/Firestore/Flutter documentation and engineering sources, web-verified May 2026.
- **Analysis Framework:** trace one concrete user action (655-item bulk mark) end-to-end; quantify every multiplier; verify each claim against at least two independent sources or against the source code directly.
- **Time Period:** current — the defect dates entirely from the 2026-05-13→05-15 Epic 25/26/27 rebuild and the 2026-05-15 SyncEngine cutover.
- **Technical Depth:** file-and-line precision, with quantified before/after for every fix.

**Confidence levels:** all root-cause claims in §2 are **High confidence** — observed directly in source and corroborated by three independent agents. Web-sourced facts (Firestore limits, pricing, listener semantics) are **High confidence** — official Firebase/Google Cloud documentation. Cost projections in §6 are **Medium confidence** — they depend on usage patterns and are presented as ranges.

### 1.3 Technical Research Goals and Objectives

**Original Technical Goals:** make bulk marking fast and reliable; cut Firebase cloud cost, device compute, and network traffic; minimize sync latency; deliver dependable two-way cloud backup and real-time multi-device sync on a shared account.

**Achieved Technical Objectives:**

- **Goal — diagnose the freeze/latency:** achieved. Seven distinct, file-located root causes identified and quantified (§2).
- **Goal — reduce cost/compute/network/latency:** achieved. A 10-point fix maps each goal to specific code changes with before/after numbers (§6, §7).
- **Goal — two-way backup + real-time multi-device:** achieved. Deterministic document IDs + the §4.1 conflict model deliver convergent, zero-data-loss multi-device sync on Firebase natively (§5, §8).
- **Additional insight:** the codebase carries *two* Firestore collection layouts, *two* `firestore.rules` files, and *two* `firestore.indexes.json` files that disagree — a migration-consistency hazard surfaced during this research and folded into the roadmap (§9, §10).

---

## 2. The 655-Mishnayos Diagnosis — Current Architecture Analysis

This section traces one bulk mark end-to-end. Every claim was observed in source.

### 2.1 The symptom chain

`bulk_mark_screen.dart:188 _executeBulkMark()` → `BulkPriorCompletionService.execute()` (`bulk_prior_completion_service.dart:113`) → `CompletionRepositoryImpl.bulkMarkComplete()` (`completion_repository_impl.dart:195`). Because prior-learning marks pass `awardGamificationPoints == false`, every bulk-mark-prior is routed to `_bulkMarkCompletePriorOptimized()` (`completion_repository_impl.dart:278-368`). The "optimized" method is the hot path. It is not optimized.

### 2.2 Root cause 1 — 655 transactions on the UI isolate (the freeze)

The core loop, `completion_repository_impl.dart:309-322`:

```dart
for (final ref in toInsertUnique) {
  await _completionWriter.commit(CompletionCommand(...));
}
```

Each `CompletionWriter.commit()` (`completion_writer.dart:52-154`) opens **its own Drift transaction** (`_db.transaction(...)`). There is **no outer transaction** wrapping the loop. Each transaction performs ~6 SQLite statements (idempotency `SELECT` on `completion_events`, legacy-guard `SELECT` on `completions`, `appendEvent` insert + re-select, `outbox` insert, `getCompletionById`) plus a `jsonEncode`. For 655 items: **655 transactions, ≈3,900 synchronous SQLite operations, 655 `jsonEncode` calls** — all on the UI isolate. Drift's default executor runs SQLite on the main isolate; there is **no `compute()` / `Isolate.spawn` / background-DB offload** anywhere on this path. The event loop is saturated; even the progress spinner cannot animate. *(High confidence — verified in source.)*

**Multi-stage multiplier:** the UI loops per selection group and the service loops per stage (`bulk_prior_completion_service.dart:124`). Marking a seder across Learn + Chazara-1 + Chazara-2 triples every number → **~1,965 transactions**.

### 2.3 Root cause 2 — the dual outbox (writes everything twice)

`_bulkMarkCompletePriorOptimized` writes each completion to **two independent queues**:

1. **`outbox` table** — `CompletionWriter.commit()` inserts an `outbox` row inside the completion transaction (`completion_writer.dart:129-137`). Correct and atomic. Drained by `OutboxProcessor`.
2. **`sync_queue` table** — the *same method* then calls `syncEngine.pushCompletionsBatch(...)` (`completion_repository_impl.dart:351`), which loops `_offlineQueue.enqueueCompletion(...)` (`sync_engine.dart:740-748`) → 655 rows in the **separate legacy `sync_queue` table**. Drained by `OfflineQueue`.

A 655-item mark therefore creates **~1,310 queue rows for 655 completions**, and both queues push the same completions to Firestore — **every completion is uploaded twice**. This is the residue of the DNI-333/334/335 cutover: the new `outbox` pipeline was built, the legacy `OfflineQueue` was left live, and the bulk path feeds both. *(High confidence — verified in source.)*

### 2.4 Root cause 3 — per-document `collection.add()`: no batch, non-idempotent

`FirestoreGatewayImpl.pushCompletion()` (`firestore_gateway_impl.dart:28-36`):

```dart
final collection = _collection(profileId, 'completions');
await collection.add({...data, 'synced_at': FieldValue.serverTimestamp()});
```

Two defects:

- **No `WriteBatch`.** Each completion is one awaited network round-trip. `OfflineQueue.flush()` (`offline_queue.dart:235-413`) iterates rows strictly sequentially; the new `OutboxPushPipeline` serializes completions single-flight per kind. The gateway *has* a batched method — `pushLedgerEntriesBatch()` (`firestore_gateway_impl.dart:184-197`) using `_firestore.batch()` — but completions never use it. Result: **~1,310 sequential round-trips**. At a realistic 100–300 ms RTT that is **2–7 minutes of pure serial network on the critical path**, before any retry — matching the "10+ minutes on fibre" report.
- **`collection.add()` generates a random document ID.** Completions are therefore **not idempotent on the server**. Every retry, every dual-queue duplicate, every re-flush creates a *new* document. The natural key `profileId:sefariaRef:stageId:trackType` is already computed as `entityKey` (`completion_writer.dart:156-157`) and threaded through the pipeline — then discarded (`push_pipeline_impl.dart:24-32`). It is the obvious deterministic document ID and is currently thrown away. *(High confidence — verified in source.)*

### 2.5 Root cause 4 — the self-write listener storm

`SyncEngine.attachListeners()` (`sync_engine.dart:202-278`) attaches **12 live `.snapshots()` listeners**. The `completions` listener subscribes to the **entire `completions` subcollection with no `where`/`limit`** (`firestore_gateway_impl.dart:392-403`).

Firestore's SDK fires `.snapshots()` on local writes immediately — "latency compensation" — *before* server acknowledgement, with `metadata.hasPendingWrites == true`. So as the 655→1,310 `add()` calls land in the local cache, the `completions` listener re-fires repeatedly, each time emitting the **entire grown collection**. `_mergeCompletions` (`sync_engine.dart:1053-1167`) then loops every completion and runs a per-row existence check. The merge **never inspects `hasPendingWrites` / `isFromCache`**, so it processes the device's own optimistic writes as if they were remote changes. A `_mergingCompletions` re-entrancy flag drops *concurrent* callbacks but does not debounce — each queued snapshot still runs a full re-scan. As the collection grows, this is roughly **O(n²) database work plus UI rebuilds** layered on top of the freeze. *(High confidence — verified in source + Firebase listener documentation.)*

### 2.6 Root cause 5 — no flush concurrency guard; partial drains

`_runBackgroundFlush` (`sync_engine.dart:577-608`) is launched fire-and-forget via `unawaited(...)` after **every** push and again on reconnect. There is **no `_isFlushing` guard** — overlapping multi-minute flushes stack, each re-reading the full pending set and racing to push/delete the same rows. Meanwhile `OutboxProcessor.drain()` is capped at **50 rows per call** (`outbox_processor.dart:44`) with no internal loop, so a 655-row backlog needs **14+ event-driven passes** to clear, and `outbox` rows have **no backoff, no dead-letter, no max-attempts** (`outbox_processor.dart:73`) — a permanently failing row is retried forever. This is why the queue count never reaches zero and `flush_complete` is never logged. *(High confidence — verified in source.)*

### 2.7 Root cause 6 — duplicate `SyncOrchestrator` / `pull_on_launch`

`SyncOrchestrator` is a plain Riverpod `Provider`, **not a singleton** (`sync_orchestrator_providers.dart:28-56`), and its constructor *eagerly* starts a lifecycle observer and Firestore listeners (`sync_orchestrator.dart:64-99`). The sign-in flow calls `ref.invalidate(syncEngineProvider)` (`sign_in_screen.dart:272`), which forces the orchestrator to rebuild — transiently producing **duplicate lifecycle observers and listener sets**. `pullOnLaunch` exists on **both** `SyncEngine` and `SyncOrchestrator` and both run — so the device pulls the whole completions collection back *twice* while the 655-write push storm is still draining. *(High confidence — verified in source; matches the bug-report "duplicate pull_on_launch".)*

### 2.8 Root cause 7 — write-only summary maps

`_enrichLearnerProfilePayload` (`sync_engine.dart:2307-2443`) runs ~6 database queries on every profile push to compute `progress_summary`, `streak_summary`, and `gamification_summary` maps, then writes them onto the profile document. A repo-wide search confirms **zero readers** — write-only denormalization that can only drift, adding DB compute and network payload for no benefit. *(High confidence — verified by repo-wide search.)*

### 2.9 The blast radius, quantified

One 655-item, single-stage bulk mark:

| Dimension | Today | After the fix |
|---|---|---|
| Drift transactions | **655** | **1** |
| `completion_events` rows | 655 | 655 *(correct — unchanged)* |
| Queue rows (`outbox` + `sync_queue`) | **~1,310** | **655** (`outbox` only) |
| Firestore document writes | **~1,311**, growing on every retry (non-idempotent) | **~655**, idempotent — no duplicate growth |
| Firestore push round-trips | **~1,310 sequential** | **2** (`WriteBatch`, ≤500/commit) |
| Self-echo listener callbacks | ~655–1,310, each an O(n) full re-merge | ~0 (local echoes filtered) |
| UI-isolate blocking | **full freeze** | sub-second |
| ×3 for a 3-stage seder | every number ×3 | the small numbers ×3 |

**Architectural theme:** *two of everything.* Two queues, two drains, two pull entrypoints, two collection layouts, two `firestore.rules`, two `firestore.indexes.json`. The defect is a half-finished migration — **recoverable by completing it, not by rewriting again.**

---

## 3. Technology Stack Analysis

### 3.1 Languages, Frameworks, Local Storage

- **Dart / Flutter** — single-threaded UI isolate model; heavy synchronous work (including default-executor SQLite) blocks rendering unless offloaded to a background isolate via `compute()` or `Isolate.spawn`. _Source: Flutter concurrency docs, https://docs.flutter.dev/perf/isolates_
- **Drift 2.31 (SQLite)** — the local source of truth; supports background-isolate executors and batched inserts (`batch(...)`), neither currently used on the completion write path. _Source: codebase + Drift documentation._
- **`cloud_firestore` (FlutterFire)** — the only Firestore-touching package; confined by lint to `lib/core/sync/` and `lib/features/auth/` (CLAUDE.md Rule 3). Firestore plugin calls cross a platform channel and can contend with the UI thread under load. _Source: codebase; flutterfire issue #4155, https://github.com/firebase/flutterfire/issues/4155_

### 3.2 Database and Storage Technologies

- **Cloud Firestore (Standard edition)** — document store; **10,000 writes/sec** ceiling, **1,000,000 concurrent connections**, native offline persistence on mobile. Chosen correctly over Realtime Database (1,000 writes/sec, manual sharding) for a sync workload. _Source: https://firebase.google.com/docs/database/rtdb-vs-firestore_
- **Firestore offline persistence** — on by default on mobile; "Cloud Firestore was **not designed as an offline-first database** and is not optimized for handling large amounts of data locally." The app never configures `Settings`/`cacheSizeBytes` — pure platform defaults. _Source: https://firebase.google.com/docs/firestore/manage-data/enable-offline_
- **The bespoke sync layer** — `SyncEngine` (3,258 lines), `OfflineQueue` + `sync_queue` table (legacy), `OutboxProcessor` + `outbox` table (new), `FirestoreGatewayImpl`, `SyncOrchestrator`, `PushPipeline`. This is the layer under repair.

### 3.3 Adoption Trends

The 2026 ecosystem trend is **managed local-first sync engines** (PowerSync, ElectricSQL, RxDB) replacing hand-rolled queues. PowerSync is positioned as "the advanced pick for production apps where sync correctness is a business requirement," with a first-class Flutter/Dart library. This is relevant as a *future* option (§8, §11), not a mid-crisis move. _Source: https://www.powersync.com/blog/offline-first-apps-made-simple-supabase-powersync; https://cssauthor.com/offline-first-tech-stack/_

---

## 4. Integration and Interoperability Patterns

### 4.1 The Outbox / Transactional-Queue Pattern

The app correctly uses an **outbox pattern** — a local write and its sync intent committed in one transaction (`completion_writer.dart` writes `completion_events` + `outbox` atomically). The pattern's required invariants are: **idempotent operations, dedup keys, a single drain loop, explicit per-operation acknowledgement.** The current implementation satisfies acknowledgement (rows deleted only after success) but **violates idempotency** (random doc IDs), **violates single-drain** (no flush guard; two queues), and **plumbs a dedup key it then discards** (`entityKey`). _Confidence: High — verified in source._

### 4.2 Real-Time Listeners and Latency Compensation

Firestore `.snapshots()` listeners are the integration mechanism for real-time multi-device sync. Two behaviors are load-bearing here:

- **Latency compensation:** local writes invoke listeners immediately, before the server round-trip — the cause of the §2.5 self-echo storm.
- **`metadata.hasPendingWrites` / `metadata.isFromCache`:** the documented way to distinguish local-pending from server-confirmed data. The fix uses this to filter echoes. _Source: https://firebase.google.com/docs/firestore/query-data/listen_

A second documented, counterintuitive behavior: **large `WriteBatch` commits can *increase* snapshot-listener notification latency.** The fix therefore chunks batches at a moderate size (≤500, often smaller) rather than maximizing batch size. _Source: https://firebase.google.com/docs/database/rtdb-vs-firestore (bulk-write note)._

### 4.3 Conflict Resolution and Data Formats

`architecture-offline-v2.md` §4.1 specifies a **hybrid per-data-type** strategy: completions/progress merged **forward by union** ("if either side says done, it's done"); streaks/XP as **append-only event logs reduced to state**; settings/bookmarks/goals **last-write-wins by `updatedAt`**. Append-only event logs are conflict-free by construction — a **grow-only set CRDT**. The data format is JSON document payloads; deterministic document IDs make the union automatic on the server side. The current code merges completions by an existence check but undermines it with non-deterministic IDs (§2.4). _Source: architecture-offline-v2.md; CRDT vs LWW analysis, https://dzone.com/articles/conflict-resolution-using-last-write-wins-vs-crdts_

---

## 5. Architectural Patterns and Design

### 5.1 System Architecture Pattern — Local-First with Background Projection

The intended pattern (`architecture-offline-v2.md` §3): local SQLite is always the source of truth; sync is an **async, non-blocking background projection** to Firestore; "the app never waits on the network to render a screen." The defect is that the *write* half of this pattern blocks the UI (§2.2) and the *sync* half never completes (§2.6). The pattern is right; the implementation diverged from it.

### 5.2 Event Sourcing as the Source of Truth

`completion_events` is an append-only event log; the `completions` table is now a read-only projection (`completions_view`, schema v20). This is the **correct** consolidation already underway (commits `298a80d3`, `36350848`). The fix builds *on* it: events are immutable and additive, so two devices' event logs **union** without conflict — exactly the CRDT property that makes zero-data-loss multi-device sync achievable. The work remaining is to make the *transport* of those events batched, idempotent, and single-queued.

### 5.3 Design Principles in Play

- **Single Responsibility / single source of truth** — currently violated by the dual queue; the fix restores one queue (`outbox`).
- **Idempotency** — a non-negotiable for any retried network operation; restored via deterministic document IDs.
- **Backpressure / bounded work** — restored via chunked batches, a single bounded drain loop, and backoff/dead-letter on the `outbox`.
- **Layering** — CLAUDE.md's five enforced rules (Firebase confined to `core/sync`; no `core→features` imports; etc.) constrain *where* fixes land — almost entirely inside `lib/core/sync/`.

### 5.4 Data Architecture

`two-database-architecture.md`: a read-only bundled **Content DB** and a read-write **User DB** (now 23 tables). Only the User DB syncs. The sync-relevant tables are `completion_events` (canonical), `completions`/`completions_view` (projection), `outbox` (canonical queue), `sync_queue` (legacy queue — to be retired for completions), `streak_events`, `xp_events`. The fix does **not** change table schemas; it changes write *batching* and *transport*.

---

## 6. Performance and Cost Analysis

### 6.1 Firestore Limits and Pricing (web-verified, May 2026)

- **Pricing (Standard edition):** writes **$0.18 / 100K**, reads **$0.06 / 100K**, deletes **$0.02 / 100K**, storage **$0.18 / GB-month**. Free tier: **20,000 writes/day**, 50,000 reads/day, 1 GB stored. _Source: https://firebase.google.com/docs/firestore/pricing; https://cloud.google.com/firestore/pricing_
- **Batched writes:** max **500 operations per `WriteBatch`/transaction**. Batched writes outperform serialized writes; for very large volumes, chunk into multiple ≤500-op batches. _Source: https://firebase.google.com/docs/firestore/manage-data/transactions_
- **The 500/50/5 rule:** ramp new-collection traffic from ≤500 ops/sec, +50% every 5 min, to avoid hotspot latency/`deadline-exceeded`. _Source: https://firebase.google.com/docs/firestore/best-practices; https://engineering.doit.com/firestore-scaling-the-500-50-5-rule-and-how-to-test-it_
- **Per-document limit:** ~1 sustained write/sec; **monotonically-increasing indexed fields** (e.g. timestamps) cap a collection at ~500 writes/sec and hotspot. The fix exempts high-churn timestamp fields from indexing where possible. _Source: https://firebase.google.com/docs/firestore/best-practices_

### 6.2 Cost of the Current Design

A 655-item single-stage bulk mark ≈ **1,311 writes ≈ $0.0024** at list price — small *per action*. The real cost problems are structural:

- **Non-idempotency:** every retry/duplicate writes *new* documents, so writes and storage grow without bound while the data set does not. A few failed-and-retried bulk marks can write tens of thousands of documents.
- **Free-tier burn:** at ~1,310 writes per mark, ~15 bulk marks exhaust the **20K-writes/day** free tier.
- **Read amplification:** each device's whole-collection listener re-reads the entire `completions` collection on every change — read cost scales with collection size × write frequency × device count.
- **Write-only summaries:** ~6 DB queries + extra payload per profile push, never read.

### 6.3 Performance and Cost After the Fix

| Goal | Mechanism | Effect |
|---|---|---|
| **Compute** ↓ | One transaction + batched inserts; no isolate-blocking; no self-echo merge; drop summary recompute | UI freeze eliminated; bulk mark sub-second locally |
| **Network** ↓ | Single queue (−50% rows); chunked `WriteBatch` (≈655 → 2 round-trips); no whole-collection re-pulls | Sync completes in seconds, not 10+ minutes |
| **Cloud cost** ↓ | Idempotent deterministic IDs (no duplicate docs/storage growth); filtered incremental listeners (fewer reads); summary maps removed | Writes bounded to the data's true size; reads bounded to actual deltas |
| **Latency** ↓ | Batched push + single bounded drain loop + flush-concurrency guard | Predictable, monotonic drain to zero |

### 6.4 Scalability

Firestore's 10,000-writes/sec ceiling and the 500/50/5 ramp are far above this app's needs (a bulk mark is a one-off burst, not sustained load). The scalability constraint is **client-side**, not Firestore — and it is removed by batching. Multi-device adds listener load proportional to device count; filtered incremental listeners keep that linear and small.

---

## 7. Implementation Approaches and Best Practices — The 10-Point Fix

Each fix is grounded in a §2 root cause and a web-verified best practice.

1. **Batch the local write.** Add `CompletionWriter.commitBatch(List<CompletionCommand>)` — **one** Drift transaction, batch-insert all `completion_events` and all `outbox` rows. `_bulkMarkCompletePriorOptimized` and the slow `bulkMarkComplete` path call it. *Fixes 2.2.*
2. **Collapse the dual queue.** Delete the `syncEngine.pushCompletionsBatch(...)` calls (`completion_repository_impl.dart:239`, `:351`). `outbox` becomes the single completion queue. *Fixes 2.3.*
3. **Batch the cloud push.** Add `FirestoreGatewayImpl.pushCompletionsBatch(...)` using chunked `WriteBatch` (≤500 ops; moderate chunk size per §4.2). `OutboxProcessor.drain` groups pending completion rows into batches internally. *Fixes 2.4.*
4. **Deterministic document IDs.** Completions write via `collection.doc(idFromEntityKey).set(...)`, not `collection.add(...)`. Idempotent: retries and any residual duplicates collapse. *Fixes 2.4 + the cost problem.*
5. **Filter listener self-echoes.** The `completions` listener skips changes with `metadata.hasPendingWrites` / cache-only origin; the merge consumes incremental `docChanges`, not whole-collection re-scans; debounce merges. *Fixes 2.5.*
6. **Flush-concurrency guard + bounded drain loop.** A single-flight guard on `_runBackgroundFlush`; drain-until-empty; add exponential backoff + max-attempts + dead-letter to the `outbox`. *Fixes 2.6.*
7. **Singleton `SyncOrchestrator`; one `pull_on_launch`.** `keepAlive` singleton; stop `ref.invalidate(syncEngineProvider)` on sign-in; one pull entrypoint. *Fixes 2.7.*
8. **Drop write-only summary maps.** Remove `progress_summary`/`streak_summary`/`gamification_summary` enrichment until a real reader exists. *Fixes 2.8.*
9. **Reconcile layouts/rules/indexes.** Adopt the nested layout as canonical; delete the dead repo-root `firestore.rules`/`firestore.indexes.json`/`firestore-collection-layout.md`; tighten the deployed rules (§10). *Fixes the migration-consistency hazard.*
10. **Configure Firestore explicitly.** Set `Settings` (persistence + sane `cacheSizeBytes`); keep the 12 listeners for multi-device but make them incremental and filtered.

### 7.1 Testing and Quality Assurance — the discipline

The prior assessment identified a second root: a fix process that produces documents but does not commit or verify fixes, so bugs recur. The remedy is non-negotiable here: **every fix ships as one commit containing a failing characterization test, the fix, and the test green.** A first wave writes the test net (operation-counting assertions against fakes — S1–S9 in §9); each fix wave un-skips and greens its slice. Verification gate between waves: `make ci` + `make audit`.

### 7.2 Development Workflow and Tooling

- **Branch:** all work on `dev` — no feature branches, **no worktrees** (this run's explicit constraint).
- **Codegen:** `dart run build_runner build --delete-conflicting-outputs` after any Drift/Freezed/Riverpod change.
- **Gates:** `make ci` (analyze + format + schema-check + all tests) and `make audit` (12 layering greps + custom lints).
- **Commits:** conventional style matching history — `fix(sync:)`, `perf(sync:)`, `refactor(sync:)`, `test(sync:)`.

### 7.3 Risk Mitigation

Highest risks: (a) a regression in completion correctness — mitigated by the characterization net and the deterministic-ID idempotency tests; (b) merge-conflict races from parallel agents on a shared branch — mitigated by **strict disjoint-file ownership per wave**; (c) cross-device divergence — mitigated by a two-device convergence test (S9) reusing the existing two-device harness (commit `1eba9dbf`).

---

## 8. Strategic Technical Recommendations

### 8.1 Stay on Firebase — Fix, Do Not Rebuild

The diagnosis proves Firestore is not the bottleneck. Firestore natively provides every capability the goals demand: real-time multi-device sync (snapshot listeners), two-way offline persistence, and ample write headroom. The defects are entirely in the bespoke layer and are correctable with established technique.

Migrating to PowerSync/Supabase/ElectricSQL would be a **third ground-up rewrite in a single month** — and the prior assessment is explicit that the last rebuild *caused* this crisis ("Do not rebuild again"). A migration also would not, by itself, fix a 655-transaction UI-thread loop or a double-enqueue bug — those are client-architecture defects that travel with any backend.

**Recommendation:** complete the half-finished migration on Firebase (the 10-point fix). Treat managed local-first sync as a deliberate *future* evaluation (§11), undertaken from a position of strength once the local layer is provably sound — not as crisis triage.

### 8.2 Multi-Device, Real-Time, Two-Way Backup — How the Fix Delivers It

- **Two-way backup:** the single `outbox` + deterministic IDs + tightened append-only rules make every completion reliably and idempotently mirrored to Firestore.
- **Real-time multi-device:** the 12 snapshot listeners already propagate remote changes to every signed-in device; the fix makes them efficient (incremental, echo-filtered) rather than removing them.
- **Convergence / zero data loss:** deterministic document IDs mean two devices marking the same item write the *same* document — the union is automatic. Append-only events never conflict; streaks/XP reduce from event logs; settings use LWW by `updatedAt` (`architecture-offline-v2.md` §4.1). Worst case is one offline day lost only under catastrophic conflict — acceptable per the design target.

### 8.3 Decision Framework

| Decision | Recommendation | Rationale |
|---|---|---|
| Backend | **Keep Firestore** | Not the bottleneck; native multi-device; rewrite risk |
| Local write | **One transaction, batched inserts** | Eliminates the freeze |
| Queue | **Single `outbox`** | Removes the dual-write defect |
| Cloud push | **Chunked `WriteBatch` + deterministic IDs** | Cuts round-trips ~650×; makes writes idempotent |
| Conflict model | **`architecture-offline-v2.md` §4.1 as-is** | Sound, CRDT-aligned, already documented |
| Execution | **Waves of disjoint parallel agents under a test net** | Parallel speed without merge races; closes the verify-loop gap |

---

## 9. Implementation Roadmap and Risk Assessment

This is the **plan**. Its runnable form is **[`docs/_archive/superseded/sync-rework-exec-prompt-2026-05-18.md`](../../_archive/superseded/sync-rework-exec-prompt-2026-05-18.md)**. Execution model: a parallel agent squad in waves, **all on `dev`, no worktrees**; strict disjoint-file ownership per wave; `make ci` + `make audit` gate between waves; `/bmad-code-review` after implementation with **every** finding (including medium and low) fixed.

### 9.1 The Characterization Net (written first — Wave 0)

Operation-counting tests against fakes, in a new `test/sync/sync_rework_invariants_test.dart`, initially `skip:`-ped (repo convention), un-skipped by the fix wave that satisfies each:

- **S1** — bulk-mark of N items → exactly **1** Drift transaction.
- **S2** — bulk-mark of N items → **N** `outbox` rows, **0** `sync_queue` rows.
- **S3** — completion push uses a **deterministic** doc ID; re-pushing the same completion creates **no** new document.
- **S4** — bulk-mark of 655 → **≤2** `WriteBatch` commits, **0** individual `add()` calls.
- **S5** — concurrent `_runBackgroundFlush` calls → only **one** drain executes.
- **S6** — a `completions` snapshot with `hasPendingWrites` → merge is **skipped** (no self-echo processing).
- **S7** — exactly **one** `SyncOrchestrator` instance per app session.
- **S8** — `pullOnLaunch` runs **once** per launch.
- **S9** — two devices mark overlapping items → state **converges**, union, **no duplicate** documents (reuse the two-device harness, commit `1eba9dbf`).

### 9.2 The Waves

| Wave | Agents (parallel, disjoint files) | Outcome |
|---|---|---|
| **0 — Baseline + Net** | 1 agent | `make ci` green confirmed; S1–S9 written (skipped); committed |
| **1 — Core push path** | **A** writer/repo/dao · **B** gateway/pipeline/processor · **C** `sync_engine.dart` | Fixes 1–8: batched local write, single queue, batched idempotent push, echo filter, flush guard, summary-map removal |
| **2 — Hardening** | **D** orchestrator + sign-in/upgrade screens · **E** rules/indexes/layout · **F** legacy `OfflineQueue` completion-path cleanup | Fixes 7, 9; dead-code removal |
| **3 — Code review** | orchestrator runs `/bmad-code-review` on the full branch diff | Findings list (critical → low) |
| **4 — Fix all findings** | parallel agents, one per disjoint finding-set | **Every** finding fixed — critical, high, **medium, and low** |
| **5 — Final verification** | 1 agent | `make ci` + `make audit` green; S1–S9 un-skipped & green; summary report |

Disjoint-file ownership (Wave 1): **A** = `completion_writer.dart`, `completion_repository_impl.dart`, `outbox_dao.dart`; **B** = `firestore_gateway_impl.dart`, `firestore_gateway.dart`, `push_pipeline_impl.dart`, `push_pipeline.dart`, `outbox_processor.dart`; **C** = `sync_engine.dart`. No two agents share a file in any wave.

### 9.3 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Completion-correctness regression | Medium | High | Characterization net S1–S9; failing-test-first discipline; `make ci` gate |
| Parallel agents collide on a shared file | Medium | Medium | **Strict disjoint-file ownership per wave**; no shared file; serialize the per-agent commit step |
| Cross-device divergence after deterministic-ID switch | Low | High | S3 + S9 convergence tests; deterministic ID = natural key |
| Listener filter drops a real remote change | Low | High | Filter only `hasPendingWrites` echoes; S6 asserts echoes-only; integration test for genuine remote merge |
| `WriteBatch` chunk size hurts listener latency | Low | Low | Moderate chunk size (≤500, smaller in practice) per §4.2 |
| Old non-idempotent duplicate docs already in cloud | Medium | Low | One-off dedup pass keyed on natural key; deterministic IDs prevent recurrence |
| Hidden coupling to removed summary maps | Low | Medium | Repo-wide search confirmed zero readers; `make ci` re-confirms |

---

## 10. Security and Compliance Considerations

### 10.1 The Wide-Open Rules Problem

The **deployed** rules (`learning_tracker/firestore.rules`, 53 lines) grant `allow read, write: if isOwner(uid)` over the entire profile subtree — **no field validation, no append-only enforcement, no value-range checks, no server-time check.** Any compromised or buggy client can overwrite or delete completion history. A stricter 232-line rule set exists at the repo root but targets the *unbuilt* top-level layout and would *deny* the app's actual writes — it is dead.

**Recommendation:** rewrite the deployed rules for the live nested layout — completion documents **append-only** (`allow update, delete: if false`), field whitelists, `points` range check, `completed_at <= request.time`. Delete the dead repo-root rules/indexes. This protects backup integrity (a core product promise) and is a prerequisite for trustworthy multi-device sync.

### 10.2 Compliance and Data Integrity

- **Append-only enforcement** server-side guarantees the event-log integrity the architecture depends on.
- **Idempotent deterministic IDs** prevent silent duplicate history.
- **Local-born accounts** remain unaffected — they never touch Firestore (`architecture-offline-v2.md` §4.7); the "no backup, no recovery" warning still governs them.
- **Indexes:** wire `learning_tracker/firestore.indexes.json` into `firebase.json` and exempt high-churn timestamp fields from indexing to avoid the 500-writes/sec hotspot cap (§6.1).

---

## 11. Future Technical Outlook

- **Near term (1–3 months):** complete the migration (this report's fixes); finish retiring the legacy `OfflineQueue` for *all* entity kinds, not just completions (the dual-queue hazard exists beyond completions).
- **Medium term:** evaluate a managed local-first sync engine — **PowerSync** is the leading 2026 option with a first-class Flutter library, mature sync rules, and customizable conflict resolution. This is a *de-risking* exercise to undertake once the Firebase layer is proven sound — replacing the bespoke `SyncEngine` with a maintained engine, not migrating in panic. _Source: https://www.powersync.com/blog/offline-first-apps-made-simple-supabase-powersync_
- **Innovation opportunity:** the append-only event log is already a CRDT-shaped foundation; formalizing completions as a grow-only set and streaks/XP as reduced event logs would make multi-device correctness provable, not merely tested.
- **Cost monitoring:** add lightweight write/read counters (or a Firestore usage dashboard alert) so a regression in idempotency or listener filtering is caught as a billing anomaly, not a user complaint.

---

## 12. Methodology, Source Verification, and Appendices

### 12.1 Source Documentation

**Primary technical sources (web, verified May 2026):**

- Firestore best practices — https://firebase.google.com/docs/firestore/best-practices
- Transactions and batched writes — https://firebase.google.com/docs/firestore/manage-data/transactions
- Firestore pricing — https://firebase.google.com/docs/firestore/pricing · https://cloud.google.com/firestore/pricing
- Access data offline — https://firebase.google.com/docs/firestore/manage-data/enable-offline
- Real-time updates / listeners — https://firebase.google.com/docs/firestore/query-data/listen
- Understand reads and writes at scale — https://firebase.google.com/docs/firestore/understand-reads-writes-scale
- Realtime Database vs Firestore — https://firebase.google.com/docs/database/rtdb-vs-firestore
- The 500/50/5 rule — https://engineering.doit.com/firestore-scaling-the-500-50-5-rule-and-how-to-test-it
- Flutter concurrency / isolates — https://docs.flutter.dev/perf/isolates
- Background isolates in Flutter — https://invertase.io/blog/improve-flutter-performance-with-background-isolates-in-flutter-3-7
- flutterfire — listener can freeze the UI thread — https://github.com/firebase/flutterfire/issues/4155
- PowerSync + Supabase offline-first — https://www.powersync.com/blog/offline-first-apps-made-simple-supabase-powersync
- CRDT vs last-write-wins — https://dzone.com/articles/conflict-resolution-using-last-write-wins-vs-crdts

**Primary internal sources:** `docs/_archive/superseded/tracking-system-review-2026-05-17.md`; `docs/planning/architecture-offline-v2.md`; `docs/planning/two-database-architecture.md`; `docs/_archive/superseded/exec-prompt-2026-05-17.md`; first-hand reads of `completion_repository_impl.dart`, `completion_writer.dart`, `offline_queue.dart`, `outbox_processor.dart`, `firestore_gateway_impl.dart`.

### 12.2 Quality Assurance

- **Source verification:** every §2 root cause was observed in source by an investigation agent and independently re-verified first-hand before inclusion. Cross-agent corroboration was unanimous.
- **Confidence levels:** root-cause diagnosis — **High**; Firestore limits/pricing/listener semantics — **High** (official docs); cost projections — **Medium** (usage-dependent, given as ranges).
- **Limitations:** no live device profiling or Firestore billing export was available; the 10+-minute figure is user-reported and corroborated by arithmetic (≈1,310 sequential round-trips), not instrumented. A DevTools CPU trace during a bulk mark would further quantify §2.5.

### 12.3 Evidence Index (file:line)

- Bulk path / 655 transactions — `completion_repository_impl.dart:195,278-368`, loop `:309-322`, dual-enqueue `:239,:351`
- Per-completion transaction + `outbox` insert — `completion_writer.dart:52-154`, `:129-137`, `entityKey` `:156-157`
- Legacy queue serial flush — `offline_queue.dart:202-421`
- Outbox drain — 50-row cap, no backoff — `outbox_processor.dart:44,51-81`
- `collection.add()` / no batch / nested layout — `firestore_gateway_impl.dart:28-36,184-197,392-403,482-494`
- `entityKey` discarded — `push_pipeline_impl.dart:24-32`
- Fire-and-forget flush, no guard; summary maps; pullOnLaunch — `sync_engine.dart:202-278,577-608,740-748,1053-1167,2307-2443`
- Non-singleton orchestrator — `sync_orchestrator_providers.dart:28-56`, `sync_orchestrator.dart:64-99`, `sign_in_screen.dart:272-277`

### 12.4 Web Search Queries Used

Firestore `WriteBatch` 500-op limit / bulk-write best practices · Firestore offline persistence with large pending-write queues · Firestore snapshot listener `hasPendingWrites` on local writes · Firestore document read/write pricing 2026 · Flutter Firestore bulk write UI-thread freeze · PowerSync/ElectricSQL/Supabase local-first sync (Flutter, 2026) · CRDT vs last-write-wins conflict resolution · Firestore aggregate/denormalization write-cost optimization · Firestore 500/50/5 rule and sustained write limits · Realtime Database vs Firestore for bulk offline writes.

---

## Technical Research Conclusion

### Summary of Key Technical Findings

The 655-mishnayos failure is not a Firebase limitation and not an unsound architecture. It is a **half-completed migration**: a sync layer rebuilt in 48 hours and cut over before the old path was removed. One bulk mark becomes 655 UI-thread transactions, ~1,310 dual-queued rows, ~1,310 sequential non-idempotent Firestore writes, and an O(n²) self-echo listener storm. Every one of the seven root causes is file-located, verified, and fixable with standard technique.

### Strategic Technical Impact Assessment

The 10-point fix touches ~12 files, almost entirely within `lib/core/sync/`, and directly satisfies all four optimization goals — cost, compute, network, latency — while delivering dependable two-way backup and real-time multi-device sync on Firebase as-is. It honors the prior assessment's hard-won lesson: **consolidate and repair under a test net; do not rebuild.**

### Next Steps

1. Execute the wave roadmap via **[`docs/_archive/superseded/sync-rework-exec-prompt-2026-05-18.md`](../../_archive/superseded/sync-rework-exec-prompt-2026-05-18.md)** — parallel agent squad, waves, all on `dev`, no worktrees, `/bmad-code-review` with every finding fixed.
2. Tighten and deploy `firestore.rules`; reconcile the duplicated layout/index artifacts.
3. After the layer is stable, schedule the PowerSync evaluation as a future de-risking exercise.

---

**Technical Research Completion Date:** 2026-05-18
**Source Verification:** all claims cited to source code (file:line) or official documentation
**Technical Confidence Level:** High — diagnosis verified by three independent investigations plus first-hand source reading

_This document is the authoritative technical reference for the Learning Tracker sync rework. Its runnable companion is `docs/_archive/superseded/sync-rework-exec-prompt-2026-05-18.md`._
