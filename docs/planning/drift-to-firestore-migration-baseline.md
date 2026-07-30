---
title: "Drift → Firestore-Native Migration — Baseline Inventory"
project: Learning Tracker
status: draft
audience: [repo owner (decision maker), migration architect]
scope: AS-IS baseline only. No migration plan. Per-item target notes are annotations, not design.
date: 2026-07-30
sources:
  - "Subsystem 1 — Drift Schema"
  - "Subsystem 2 — Sync Engine Mechanics (lib/core/sync/)"
  - "Subsystem 3 — Merge Semantics (lib/core/sync/merge/)"
  - "Subsystem 4 — Firestore Side (cloud schema, rules, codecs, functions)"
  - "Subsystem 5 — Consumer Seams (repositories, DAOs, reactive queries, transactions)"
  - "Subsystem 6 — Identity, Multi-Account & Non-Drift Local State"
evidence_convention: "Every material claim carries file:line. Paths are relative to learning_tracker/ unless prefixed (tool/, functions/, firestore.rules)."
---

# Drift → Firestore-Native Migration — Baseline Inventory

## 1. Purpose & scope

This is the **as-is baseline** for a proposed migration from the app's custom Drift-plus-outbox sync engine to a Firestore-native data layer. Its job is to make sure **nothing that currently protects user data gets silently dropped** during that migration. It is not a migration plan and contains no target architecture — the brief/architecture is the next artifact. Where an item has an obvious target implication, it is annotated as a short *target note* only.

Three audiences: the **repo owner** (owner-decision items in §10), the **migration architect** (investigation items in §10, and the protection layer in §4 and MCF register in §9), and any engineer reconciling this against the code (file:line evidence throughout).

**Honesty about uncertainty is a design goal.** Where an inventory pass could not confirm a claim, or where in-file documentation was found to contradict the code, it is flagged as such rather than smoothed over. Two doc-comment drift instances, a suspected-but-unconfirmed merge defect, several dead code paths, and several live cross-account defects are called out explicitly.

**Reconstruction warning that governs this whole document:** `docs/architecture.md` and `docs/explainers/sync-subsystem.md` are materially stale against the code (a deleted `SyncEngine`, wrong retry count, wrong pull-step count/order — MCF-31). Every count and ordering fact below was **re-derived from code by direct enumeration**, not taken from those docs. The migration plan must do the same.

---

## 2. System map

### 2.1 Data-flow, as-is (text diagram)

```
                    ┌─────────────────────── ONE DEVICE ───────────────────────┐
                    │                                                            │
  bundled asset ──▶ Content DB (read-only, v5, ~87K rows)   Device Registry DB   │
  content.db.gz     TextCache/CalendarCycles/DailyContent/   (v1, per-DEVICE)    │
  (SeedManager)     SeedMetadata — NEVER synced              DeviceAccounts(≤5)  │
                                                             DeviceState         │
                                                             — NEVER synced,     │
                                                               pre-auth          │
                    ┌──────────────── active account (1 of ≤5) ───────────────┐  │
                    │  User DB  user_acc_<id>.db  (v37, 24 tables)             │  │
                    │  ── writes ──▶ CompletionWriter / repositories / DAOs    │  │
                    │       │  (local commit + Outbox row, SAME transaction)   │  │
                    │       ▼                                                   │  │
                    │   Outbox table ──▶ OutboxProcessor.drain (5 triggers)    │  │
                    │                         │ single-flight, backoff,        │  │
                    │                         │ dead-letter @10, batch         │  │
                    │                         ▼                                 │  │
                    │                    PushPipeline ─▶ FirestoreGatewayImpl ──┼──┼─▶ Firestore
                    │   SyncKv (LWW      (per-kind)      (only cloud_firestore  │  │   users/{uid}/
                    │   watermark) ◀───┐                 importer)              │  │   learner_profiles/
                    │                  │                                        │  │   {profileId}/<16 colls>
                    │   Drift tables ◀─┤ MergeRouter ◀─ PullPipeline / Listener │  │
                    │   + SharedPrefs ─┘ (18 mergers)   Supervisor (18 own /    │◀─┼── snapshots()
                    │                                    16 tutored channels)   │  │
                    └───────────────────────────────────────────────────────────┘  │
                    SharedPreferences (device-wide, per-profileId keys)             │
                    FlutterSecureStorage (device-wide, PINs)                        │
                    └────────────────────────────────────────────────────────────┘
  SyncOrchestrator: device-wide keepAlive singleton — pull-on-launch (17 steps),
  drain fan-in, status state machine, identity-mismatch guard, lifecycle/connectivity.
  Cloud Functions (Admin SDK): tutor invite/accept/revoke, all tutor-proxied writes.
```

### 2.2 Numbers table

| Dimension | Count | Evidence |
|---|---|---|
| Physical Drift databases | 3 (Content v5, User v37, Device Registry v1) | §2, Sub-1 |
| Drift table classes total | 30 (28 "official" + 2 registry) | Sub-1 §1–2 |
| — Content DB tables | 4 (all local-only) | `content/content_database.dart:29` |
| — User DB tables | 24 | `user/user_database.dart:150-176` |
| — Device Registry tables | 2 | `registry/device_registry_database.dart:41` |
| Drift tables that sync (some form) | 14 | Sub-1 §6 |
| Local-only Drift tables (within 28) | 14 | Sub-1 §6 |
| EntityKinds (`EntityKind.all`) | 18 | `merge/entity_merger.dart:40-59` |
| Dedicated `EntityCodec` subclasses | 13 (5 kinds parse inline) | `sync/codec/` |
| Concrete `EntityMerger` classes | 18 (4-way parity) | `merge/` |
| `lib/core/sync/` files / lines | 64–65 / 12,201 | Sub-2 §0 |
| Largest sync files | `sync_orchestrator.dart` 1716, `firestore_gateway_impl.dart` 1483, `drift_merge_store.dart` 808, `outbox_processor.dart` 737 | Sub-2 §0 |
| Own-account listener channels | 18 | `firestore_listener_source.dart:107-208` |
| Tutored listener channels | 16 | `tutored_listener_supervisor.dart:70` |
| Pull-on-launch sequential steps | 17 | `sync_orchestrator.dart:828-902` |
| Per-profile Firestore subcollections | 16 | `firestore.rules` match blocks |
| `firestore.rules` lines / match blocks | 540 / 23 | Sub-4 §0 |
| Composite indexes (all `tutor_grants`) | 6; `fieldOverrides: []` | `firestore.indexes.json` |
| Repository classes | 45 (20 abstract + 24 impl + 1 fallback); brief expected 57 | Sub-5 §1 |
| Feature files importing DAOs directly | 37 (10 repo-layer, **27 true bypasses**) | Sub-5 §2 |
| DAO `watch()` methods | 14 (only 6 reached in production) | Sub-5 §3 |
| Riverpod providers wrapping a Drift stream | 13 | Sub-5 §3 |
| Multi-table transaction call sites | 33 across 19 files | Sub-5 §5 |
| Max accounts per device | 5 (`kMaxDeviceAccounts`) | `registry/device_registry_database.dart:28` |
| Sync/core test files | 84 (`test/core/sync/` 52 + `test/sync/` 32) | Sub-2 §0 |

---

## 3. Data inventory

### 3.1 Synced Drift tables (14) — Firestore path · merge strategy · migration note

All doc-ids are deterministic client-side natural-key functions (idempotency; MCF-3). Firestore paths are under `users/{uid}/learner_profiles/{profileId}/`.

| # | Drift table | EntityKind | Firestore collection · doc-id | Merge strategy | Migration note |
|---|---|---|---|---|---|
| 1 | `LearnerProfiles` (`tables/learner_profiles.dart:12-47`) | `learnerProfile` | `learner_profiles/{profileId.toString()}` (`firestore_gateway_impl.dart:1283-1291`) | Phase-3 LWW; **account-id remap** `_resolveLocalAccountId` (`drift_merge_store.dart:324-438`, "Bug 1") | needs-design: remote `account_id` ≠ local autoincrement — MCF-11/MCF-16. Tutor-mirror rows (`isTutored`) are read-only mirrors of another account's child. |
| 2 | `CurriculumTracks` (`tables/curriculum_tracks.dart:12-63`) | `trackConfig` | `curriculum_tracks/{curriculum_id}` (one track per profile+curriculum, W3.22) | LWW on `state_changed_at` (not `updated_at`); tombstone `purged`/`purged_at` | safe (doc-level LWW). Must-merge-before track-scoped children (MCF-15). |
| 3 | `StageDefinitions` (`tables/stage_definitions.dart:17-42`) | `stageDefinition` **and** legacy `settings` | `stage_definitions/{trackId}_{stageOrder}`; legacy `settings/{curriculum_id}` embeds `stages[]` | dedicated: LWW + FK-gate on track; legacy: full-replace of all stage rows (`_upsertSettings`, `drift_merge_store.dart:532-597`) | needs-design: two write paths to one table; `SettingsCodec.encode()` is dead (throws). MCF-16. |
| 4 | `PointConfigs` (`tables/point_configs.dart:8-21`) | `gamificationSettings` | embedded `points_config[]` array inside `preferences/gamification_settings` (single doc) | inline-parsed in merger; fans array → N rows; **also writes SharedPreferences** | needs-remodel: doc-per-collection aggregate, not doc-per-row (MCF-14, MCF-19). One doc → two local stores. |
| 5 | `StudyDayConfigs` (`tables/study_day_configs.dart:4-15`) | `studyDayConfig` | `study_day_configs/{curriculumId}_{dayOfWeek}_{trackId}` | LWW via `remoteIsNewer`; local-track-id remap; FK-gate | needs-design: local-track-id remap (MCF-4). FK-abort → "dashboard rebuild storm." |
| 6 | `CompletionEvents` (`tables/completion_events.dart:24-68`) | `completion` | `completions/{profileId_sefariaRef_stageId_curriculumId}` (percent-encoded, `_completionDocId`, `firestore_gateway_impl.dart:78-139`) | append-only insert-if-absent; **tombstone resurrection** (H2/D11) | needs-design: preserve `purgedAt` field + resurrect-without-timestamp-filter; `stage_id_format` marker (v37) must travel. MCF-6, MCF-7, MCF-8. Highest-volume table. |
| 7 | `LearningLedger` (`tables/learning_ledger.dart:24-58`) | `learningLedger` | `learning_ledger/{ulid}` | append-only; dedup `UNIQUE(profileId, ulid)`; FK-guard | safe. **Never migrate a pre-v30 ledger** (MCF-9 bare-scope-id over-credit bugs). |
| 8 | `Bookmarks` (`tables/bookmarks.dart:12-37`) | `bookmark` | `bookmarks/{curriculum_id}` | Phase-3 LWW; dual-key read (`sefaria_ref ?? content_item_id`); skip if track not synced | safe (doc-level LWW). Keep legacy dual-key decode. |
| 9 | `LearningOrder` (`tables/learning_order.dart:15-46`) | `learningOrder` | `learning_order/{curriculumId}_{ref}` | Phase-3 LWW | safe. Reorder-amnesty stamp must be atomic (MCF-25). |
| 10 | `Goals` (`tables/goals.dart:21-43`) | `goal` | `goals/{id|goal_id | curriculum_targetPercent_createdAt}` | Phase-3 LWW **dual guard** (merger + DAO); local-track-id remap | needs-design: suspected tie-break gap F4 (MCF-27); track-id remap. |
| 11 | `StreakEvents` (`tables/streak_events.dart:18-41`) | `streak` | `streak_events/{ulid}` (W3.37 migrated from `streak/{profileId}`) | append-only insert-if-absent; dedup `UNIQUE(profileId, dayUtc, eventType)` | safe-leaning: cloud shape already event-sourced. State replayed by `StreakReducer` (scale note MCF-24). |
| 12 | `PointsLedger` (`tables/points_balance.dart:48-95`) | `pointsLedger` | `points_ledger/{ulid}` | append-only insert-if-absent; **re-derives `PointsBalance`** | dangerous-if-naive: never sync balance counter (MCF-2). `UNIQUE(profileId, ulid)` (v34) closes double-credit TOCTOU. |
| 13 | `RewardRedemptions` (`tables/points_balance.dart:112-143`) | `rewardRedemption` | `reward_redemptions/{ulid}` | **bespoke plain-`isAfter` LWW** (`points_balance_dao.dart:384-425`), bypasses SyncKv/±5s window | needs-design: F3 divergence — decide standardize vs preserve (MCF-13). `redemptionId` FK restrict (v35). |
| 14 | `ProfilePrograms` (`tables/profile_programs.dart:6-22`) | `profileProgram` | `profile_programs/{curriculum_id}`; client `delete` allowed here | Phase-3 LWW; timestamp fallback chain; R3-6 double-scoping fix | safe. |

**Sync-adjacent EntityKinds with NO backing Drift table** (part of the same sync engine — a migration inventory must not stop at Drift):
- `tutorGrant` — Firestore-only today, no-op merger, read live via `listTutorGrants` CF poll. **The existing working precedent for Firestore-native** (MCF-14 in Sub-1 / MCF-30).
- `notificationSettings` — SharedPreferences only (per-profile-namespaced keys).
- `uiPreferences` — SharedPreferences only; `sacred_time`/location deliberately removed (DEC-26/WS6).
- `gamificationSettings` — fans to **both** `PointConfigs` (Drift) **and** SharedPreferences.

### 3.2 Local-only Drift tables — fate

| Table | DB | Nature | Fate under Firestore-native |
|---|---|---|---|
| `TextCache` (~52K), `CalendarCycles` (~35K), `DailyContent`, `SeedMetadata` | Content | bundled read-only Sefaria text/calendar | **Stay local/bundled.** Wrong shape/cost for Firestore; must work offline from first launch. `SeedManager` gzip-decompress + `.bak` recovery + `ContentDbHealthChecker` self-heal has no Firestore equivalent (MCF-35). Owner-confirm needed (§10). |
| `DeviceAccounts`, `DeviceState` | Registry | per-device account picker, pre-auth | **Stay local.** Must work before any Firestore session exists (MCF-35). |
| `Accounts` (`tables/accounts.dart:12-33`) | User | local identity; `tier` cloudBorn/localBorn | local; written defensively during profile merge to satisfy FK (`_resolveLocalAccountId`). |
| `CurriculumScopes` | User | scope config | local; but see §6 gap — has rules + tutor-CF write path, **no owner round-trip**. |
| `DailyPlans` | User | materialized scheduler snapshot (rolling window, prunable) | local derived cache. One of 6 no-FK-cascade tables. |
| `TrackLearningOrder` | User | per-track custom order | local; only gained `profileId` in v36 — re-verify integrity (MCF-12). |
| `Outbox` | User | **the custom sync engine's own queue** | **Deleted** — replaced by SDK's offline write queue (MCF-20, MCF-21). Lives inside each account's DB → free per-account isolation (§8). |
| `SacredWindowEntries` | User | precomputed Shabbos/YomTov windows, device-wide | local derived cache (clear-all + insert-all). |
| `TextDownloadStatuses` | User | per-text on-device download status | local-only, no cloud shape — never synced. |
| `PriorCompletionImports` | User | import-provenance bookkeeping | local device state; decide whether provenance must travel with completion (currently does not) — MCF-8b. |
| `SyncKv` | User | **LWW watermark store** | **Job must be re-solved, not reused** (MCF-1). The single most important corruption guard. |
| `PointsBalance` | User | denormalized derived counter | **Never synced; re-derive from ledger** (MCF-2). |

---

## 4. The protection layer (the heart — nothing may be lost silently)

Each merger's invariant, the corruption it prevents, and its Firestore-native risk class: **safe** (pattern ports directly), **needs-design** (a decision or new mechanism is required), **dangerous** (naive port re-introduces a known-shipped P0).

### 4.0 Shared LWW machinery (consulted by all non-legacy mergers)

- **`driftMergeStoreRemoteIsNewer` (`drift_merge_store.dart:25-64`) — the single canonical predicate.** Six rules: (1) null remote ts → false; (2) null local ts → true (remote wins); (3) outside ±5s window (`clockSkewTieBreakWindow`, line 91) → strict `remote.isAfter(local)`, ties to local; (4) inside window with both `synced_at` → server timestamp authoritative; (5) **D15** — `synced_at` missing/equal → compare client `updated_at`, keep strictly-newer (prevents clobbering an un-pushed newer local edit); (6) true tie → remote (convergence). **A hand-copied test-double of this predicate already drifted and shipped a bug (AUD-t-cross-68).** Risk: **needs-design** — must live in exactly one place (MCF-1).
- **`SyncKv` shadow (`tables/sync_kv.dart:6-18`).** Stores last-applied `updatedAtMs`/`syncedAtMs` per `(kind, entityKey)`; `_scopedKey` folds `profileId` into `'$profileId|$naturalKey'`. Exists to fix the historical lost-update where `currentUpdatedAt` returned null → `remoteIsNewer` unconditionally true. Risk: **needs-design** (MCF-1).
- **`runInTransaction` atomicity (`entity_merger.dart:162-175`, AUD-core-sync-08).** Every LWW merger's entity upsert + its SyncKv write happen in ONE Drift transaction, or a crash between them leaves a stale shadow that lets a later pull clobber a newer local edit. Risk: **needs-design** — Firestore transaction or fold marker into same doc (MCF-3-atomicity).
- **`resolveLocalTrackId` (`local_track_id_resolver.dart:38-48`).** Track-scoped children carry a REMOTE per-device autoincrement `track_id`; must be remapped to the LOCAL track row or the FK breaks on any other device. Contract: return null → **skip the row, never insert against remote id** (an unresolved FK throws `SqliteException(787)` aborting the whole batch page). Four call sites (goal, gamification, study_day_config, settings/stage_definition) previously drifted (AUD-t-cross-43). Risk: **dangerous** — kill per-device autoincrement ids globally (MCF-4). **Highest-leverage structural fact (F5).**

### 4.1 Per-merger catalog (all 18)

| Merger | Invariant / corruption prevented | Firestore-native risk |
|---|---|---|
| **CompletionEvent** (`completion_event_merger.dart`) | append-only insert-if-absent; **H2 tombstone-resurrection** — a `purgedAt` row re-marked on another device is resurrected (clear tombstone), matched WITHOUT timestamp filter (**D11**) or it stays dead forever | **needs-design**: deterministic doc-id (have) + preserve `purgedAt` field + transactional resurrect. MCF-6/7/8. |
| **StreakEvent** (`streak_event_merger.dart`) | replay-derived state; dedup on `(profileId,dayUtc,eventType)`; "ordering corruption mathematically impossible" | **safe-leaning**: cloud already event-sourced (W3.37). Point reducer at SDK cache. |
| **LearningLedger** (`learning_ledger_merger.dart`) | append-only; dedup on ulid; FK-guard skips foreign profileId | **safe**. FK-guard → app-level existence check. Never migrate pre-v30 (MCF-9). |
| **PointsLedger** (`points_ledger_merger.dart`) — **named exemplar** | balance NEVER synced; re-derived by summing ledger; `UNIQUE(profileId,ulid)` closes double-credit TOCTOU | **dangerous**: bare `FieldValue.increment` re-opens counter LWW lost-update unless idempotency-gated on ulid-doc non-existence. MCF-2. |
| **RewardRedemption** (`reward_redemption_merger.dart`) | LWW state machine `pending→fulfilled/declined`; **bespoke plain-isAfter gate, bypasses shared ±5s/synced_at algorithm** (F3) | **needs-design**: explicit decide-standardize-or-preserve. MCF-13. |
| **Bookmark** (`bookmark_merger.dart`) | full Phase-3 LWW; dual-key tolerance; skip-if-track-unsynced | **safe** (doc-level LWW). |
| **LearnerProfile** (`learner_profile_merger.dart`) | **account-id remap** — raw remote id previously "bounced user to first-launch splash" (P0) | **needs-design** — most structurally important: use Firebase UID as canonical id, kill autoincrement in payloads. MCF-11/16. |
| **TrackConfig** (`track_config_merger.dart`) | LWW on `state_changed_at`; key simplified W3.22 | **safe**. |
| **Settings** (`settings_merger.dart` + `_upsertSettings`) | doc-level LWW gates a **bulk replace-all** of child stage rows; FK-ordering skip (AUD-core-sync-07) | **needs-design**: embedded-array vs separate collection decision. MCF-16. |
| **StageDefinition** (`stage_definition_merger.dart`) | merges FULL field set (T1.9 fixed a partial-merge bug); FK-gate; schedule quartet→JSON (W3.27) | **safe**, contingent on collection-ordering. |
| **ProfileProgram** (`profile_program_merger.dart`) | R3-6 double-scoping fix; timestamp fallback for legacy null-ts payloads | **safe**. |
| **LearningOrder** (`learning_order_merger.dart`) | Phase-3 LWW; "closes C3/H3" (scenario not recovered — §10) | **safe**. |
| **Goal** (`goal_merger.dart`) | dual guard (merger + DAO); track-id remap; natural key = remote track id | **needs-design**: track-id remap + suspected F4 tie-break gap (DAO plain-isAfter no-ops while SyncKv advances). MCF-27. |
| **NotificationSettings** (`notification_settings_merger.dart`) | writes 7 per-profile-namespaced SharedPreferences keys (WS5.clobber) | **needs-design**: not in Drift; preserve per-profile namespacing. MCF-9-prefs. |
| **GamificationSettings** (`gamification_settings_merger.dart`) | one doc → PointConfigs rows + SharedPreferences; deliberately omits the buggy `getById` fallback | **needs-design**: remodel embedded array; two-store fan-out. MCF-14/19. |
| **UiPreferences** (`ui_preferences_merger.dart`) | SharedPreferences store-of-record; `sacred_time`/location removed to stop cross-profile clobber (DEC-26/WS6) | **needs-design**: keep location OUT of per-profile doc. MCF-9-prefs. |
| **TutorGrant** (`tutor_grant_merger.dart`) | no-op; grants read live from Firestore | **safe/trivial** — the existing Firestore-native precedent. But keep routing registered for every collection or new kinds silently drop. MCF-30. |
| **StudyDayConfig** (`study_day_config_merger.dart`) | track-id remap; FK-abort → "dashboard rebuild storm"; already on Phase-3 (contradicting `merge_rules.dart`'s stale comment) | **needs-design**: track-id remap. MCF-4. |

### 4.2 Confirmed stale/dead code in the protection layer

- **F1** — `entity_merger.dart:64-66` says "only the seven listed kinds are valid"; actual `EntityKind.all` = 18. Stale.
- **F2** — `merge_rules.dart:14-16` claims `StudyDayConfigMerger` still depends on it; the merger uses `_store.remoteIsNewer` and a repo-wide grep finds **zero** production importers. Dead code, safe to retire; verify no skipped test references it (§10).
- **F4** — GoalMerger dual-guard tie-break gap: **suspected, not confirmed** (no test found). Recommend a targeted unit test before the rewrite either preserves or fixes it.

**4-way parity invariant (MCF-32):** 18 `EntityKind` constants ↔ 18 `MergeRouter` cases ↔ 18 DI registrations (`merge_router_provider.dart:69-129`) ↔ 18 concrete classes. A Story 25.13 acceptance test enforces the taxonomy half. Must not be silently narrowed.

---

## 5. Engine mechanics being replaced

Component → native replacement → **gap with no native equivalent** (the residue a migration must re-engineer).

| Component (file · LOC) | Native replacement | Gap / residue |
|---|---|---|
| **SyncOrchestrator** (`sync_orchestrator.dart`, 1716) — pull-on-launch, 5-trigger drain fan-in, status state machine, guards | Mostly collapses: SDK cache + `snapshots()` = local state; SDK offline queue auto-flushes | **Pending-count status UI** (SDK exposes only `hasPendingWrites`/`isFromCache` per doc, not aggregate "N pending"); **identity-mismatch guard** (still needed); **"N rows stuck after N attempts"** (no SDK primitive). MCF-22. |
| **Outbox + OutboxProcessor + PushPipeline** (`outbox_processor.dart` 737, `push_pipeline_impl.dart` 287) — enqueue/drain/single-flight/stale-reclaim/generation-counter/backoff | **Deleted** — SDK's own persisted write queue | **Dead-letter @10** (SDK retries forever, no "gave up" signal); **per-kind drain ordering** (SDK is FIFO, no priority); **completion batching** (SDK doesn't auto-batch discrete `.set()`); **identity/profile-0/tutored skip guards** must move to the `.set()` call site. MCF-20/21/22. |
| **FirestoreGatewayImpl** (1483) — sole `cloud_firestore` importer; page sizes 200/500; `_writeBatchLimit=500` | SDK `Query`/`WriteBatch` remain first-class | Dead `pushLedgerEntriesBatch` (zero prod callers, MCF-29) is moot; **deterministic doc-id-as-idempotency-key** is a design pattern that **must be preserved** (MCF-3); **FB-3 local/cache-echo guard** (`hasPendingWrites`/`isFromCache`) **ports directly** (MCF-26). |
| **PullPipeline** (470) — cursor pagination, halt-on-merge-error, tutored per-collection resilience | Listener-driven; no separate pull step | **`curriculum_tracks`-before-track-scoped ordering** (Bug-3) is a MERGE concern that persists — independent listeners fire in no order; rely on idempotent skip-and-re-merge. MCF-15. |
| **ListenerSupervisor + FirestoreListenerSource + Tutored variants** (366/209/210/85) — 18 own + 16 tutored channels, restart state machine, park/unpark | SDK `snapshots()` per collection | **Listeners are TERMINAL ON ERROR at SDK level** — native migration does NOT fix R-1; must implement resubscribe-on-error (MCF-23); **park/unpark** has no native primitive (MCF-28); **tutored has no park/unpark today** (E-3, live gap); at-limit/recovery-pull (§3 500-row bound) disappears unless migration re-bounds for cost. |
| **LifecycleObserver** (173) — resume hooks, park timer | `disableNetwork`/`enableNetwork` survive | `triggerPull` disappears; SOME resume hook still needed to re-validate terminal-on-error listeners; cold-launch drain gap (R-2/R-8). |
| **Connectivity plumbing** — two independent signals (`connectivityStreamProvider` hardened vs orchestrator's raw inline stream, R-3) | Orthogonal to data layer; SDK manages gRPC health | Periodic-drain trigger (gated on the LESS-hardened signal) disappears; two-signal duplication is pre-existing, migration-orthogonal (MCF-8-conn). |
| **SyncWriteFacade + write-tee** (`sync_write_facade.dart` 88, `outbox_sync_write_facade.dart` 644) | Direct `docRef.set(data, SetOptions(merge:true))` | Enqueue+tee ceremony collapses; **completions-bypass-facade asymmetry** (no immediate write-tee for highest-volume kind) mooted (MCF-1-facade); **`pointsBalanceDao.syncSink` dual-assignment race (R-6)** disappears; **preserve completion pre-insert idempotency check + tombstone-resurrection gate**. |

**Cross-cutting:** EH-4 broad-catch policy (narrow `on Exception`, never bare `catch`) is a correctness convention any migration code must keep. Several of these gaps (R-1 terminal listeners, R-6 syncSink race, tutored park/unpark, dead `pushLedgerEntriesBatch`) are being addressed by active agent threads (`sync-wave1/2/3`, `sync-error-telemetry`) on `dev` — treat as possibly-in-flight, not purely latent (§10).

---

## 6. Cloud schema as-is — reuse vs remodel, continuity constraints

**Document tree** (`firestore.rules:3-54`, "LIVE LAYOUT authoritative"): `users/{uid}` · `users/{uid}/profile/data` · `users/{uid}/diagnostic_logs/{autoId}` · `users/{uid}/learner_profiles/{profileId}` + 16 subcollections · top-level `tutor_grants/{grantId}` (+`audit_log`) · `tutor_active_access/{accessId}`.

**Reuse directly as-is** (one-doc-per-entity, deterministic natural-key doc-id — existing user data needs zero transformation): `completions, streak_events, learning_ledger, bookmarks, curriculum_tracks, learning_order, goals, stage_definitions, profile_programs, study_day_configs, points_ledger, reward_redemptions, learner_profiles`, and `tutor_grants`/`tutor_active_access`/`audit_log`.

**Needs remodel:**
1. `preferences/gamification_settings` — embedded `points_config[]` is a doc-per-collection aggregate; split into a subcollection (mirroring W3.32's `stage_definitions`-out-of-`settings` precedent). Existing array still readable; one-time fan-out write, not a drop.
2. `preferences/notification_settings` + `preferences/ui_preferences` — cloud shape fine; only the local SharedPreferences plumbing changes.
3. `points_balance` — never existed in Firestore; keep client-side re-derivation or introduce a new aggregate doc (Firestore has no native SUM without a CF) — MCF-2 risk.
4. `curriculum_scopes` — no coherent owner round-trip exists; behavior must be **defined** before "reuse" applies (§10).
5. `settings` (legacy) — preserve READ compatibility only; already retired for new writes.
6. `import_metadata` + `users/{uid}/profile/data` — dead/orphan-risk paths; wire up or consciously retire.

**Continuity constraints (must preserve or existing data breaks):**
- **Reproduce every doc-id formula exactly** or all historical docs orphan (MCF-3).
- **Keep decoding legacy field aliases** (`sefaria_ref`??`content_item_id`; `state`/`is_active`; `pace_unit`/`pace_period`; learning_ledger snake↔camel) — MCF-continuity.
- **SR-1 append-only rules** deny `delete` and allow `update` only when `request.resource.data == resource.data` (idempotent replay) — write-idempotency mandatory (MCF-5).
- **SR-3** requires `completed_at`/`created_at` as real `Timestamp` ≤ `request.time` — `_timestampifyField` coercion (MCF-10). Native SDK Timestamps satisfy this for free; any JSON-bridging replay must replicate it.
- **Tutor read hinges entirely on `tutor_active_access`** `exists()` (MCF-17) — one doc per active triple, CF-maintained.
- **App Check is enforced only at CF layer**, absent from `firestore.rules` (zero `request.app`) — expanding direct-SDK surface expands rules-only-auth surface (MCF-firestore-appcheck).

**Known cloud gaps / orphan risks (don't perpetuate blindly):**
- `deleteUserData`'s hardcoded 14-item list omits `import_metadata` + `curriculum_scopes` → client-path account deletion **orphans those two collections in production today** (MCF-24-orphan). Server `recursiveDelete` path does not have this gap.
- Dead paths: `pushCurriculumImportMetadata`, `pushAccountProfile`, `TutorGrantCodec`, `SettingsCodec.encode()`, `deleteCurriculumTrack` CF — all zero prod callers.

---

## 7. Consumer seams

**Repositories — 45 classes** (20 abstract + 24 impl + 1 private fallback; brief expected 57). The gap is architectural drift: **10 `repositories/` directories are empty scaffolding never filled in** (settings, gamification, onboarding, sync ×2 each; notifications/data; tracks/setup/domain) — those features route to DAOs through plain domain services instead (MCF-13-scaffold). Confirm whether 57 was a target-state count before using it as a gate (§10).

**Direct-DAO feature files — 37** (`import '.../daos/*_dao.dart'`). 10 are repo-layer (legitimate; 2 type-only). **27 are true bypasses** (the extra migration surface): `auth_state.dart`, `local_auth_service.dart`, `upgrade_to_cloud_service.dart`, `sign_in_controller.dart`, `auth_state_provider.dart`, `account_picker_screen.dart`, `text_download_service.dart`, `parent_dashboard_aggregator.dart`, `track_completion_service.dart`, `dashboard_providers.dart`, `points_service.dart`, `completion_writer.dart`, `mark_completion_result.dart`, `bulk_mark_completion_use_case.dart`, `bulk_prior_completion_service.dart`, `learning_process_wizard_service.dart`, `user_profile_service.dart`, `chart_data_service.dart`, `curriculum_progress_service.dart`, `items_learned_providers.dart`, `lifetime_knowledge_providers.dart`, `progress_providers.dart`, `scheduler_providers.dart`, `data_export_import_service.dart`, `outbox_sync_write_facade.dart`, `curriculum_activation_service.dart`, `track_progress_service.dart`. Note: Riverpod provider files (dashboard, 3× progress) reach straight into `db.trackDao`/`db.pointsBalanceDao` with no repository indirection.

**Reactive queries.** 14 DAO `watch()` methods, **only 6 reached in production** (`watchConfigsByCurriculumAndProfile`, `watchActiveCurriculaByProfile`, `watchProfilesByAccount`, `watchActiveTracksForProfile`, `watchBalance`, `watchPendingRedemptions`); 8 are dead reactive surface. 13 providers wrap a Drift stream. Two structural facts:
- **Drift-generated row types cannot be `@riverpod` return types** (`CurriculumTrack`, `RewardRedemption`) — hand-written `StreamProvider` fallback; expect the same friction with Firestore model types (MCF-10-codegen).
- **No de-dup of identical subscriptions**: `watchBalance` is wrapped by 4 separate providers → 4 independent live subscriptions; N-listeners-per-query-per-screen if ported 1:1 (MCF-11-listeners).
- **The dominant completion-UI reactivity is NOT Drift `watch()`** — it's `completionCommittedProvider`, a manual monotonic `int` counter watched at **25 sites across 10 files** but incremented at only **4 sites** (`add_track_flow_screen.dart:711`, `text_display_screen.dart:746`, `bulk_mark_screen.dart:352,448`). `CompletionWriter` never fires it. Any new completion path that forgets `.increment()` leaves dashboard/progress/gamification silently stale — a documented P0 class (MCF-9-counter).

**Aggregates needing redesign.**
- `completions_view` — the read-model behind nearly every progress/points query — has its real filter (`WHERE purged_at IS NULL`) in a **hand-maintained raw SQL string** (`user_database.dart:214-232`) outside Dart's type system, because drift_dev can't parse a `.where()` in a view `as()`. Must be rediscovered and replicated (MCF-view).
- `PointsBalanceDao.reDeriveBalanceFromLedger` — `pointsLedger.delta.sum()` clamped `[0,2^30)`; balance never LWW-synced (MCF-2).
- `StreakReducer` replays the **entire** `streak_events` history on every read + a 15-min periodic tick, no date bound — unbounded read growth; needs bounded query or denormalized cache (MCF-24).
- `getGlobalLifetimeEarnedForRewards` — N+1 per-track sum loop (cost concern if ported to per-doc Firestore reads).
- Client-side aggregation services (`TrackCompletionService`, `CurriculumProgressService`, `ChartDataService`, `LifetimeTreeBuilder`, `RewardMilestoneService`) fetch raw rows then bucketize/reduce in Dart.

**Transactions — 33 sites / 19 files** (multi-table atomic writes needing a Firestore transaction/batch equivalent). Load-bearing ones:
- `CompletionWriter.commit`/`commitBatch` — `completion_events` + `outbox` + tombstone-resurrection (H1) + B8 prior-import upgrade, one tx (MCF-writer).
- Ledger/points/reorder writes pair data + outbox in one tx (D14, AUD-tracks-16). **`fulfilRedemption` is NOT transactional** unlike `declineRedemption` — a TOCTOU asymmetry (decide during rewrite).
- **Profile-deletion FK-drop ORDER** — `curriculum_scopes`/`study_day_configs` (RESTRICT FKs) MUST delete before `curriculum_tracks` or the whole tx rolls back with `SqliteException(787)` and the profile silently fails to delete (MCF-7-delete).
- **The 6 no-cascade tables** (`CurriculumTracks, DailyPlans, Outbox, PointConfigs, ProfilePrograms, StudyDayConfigs`) — profile delete AND tutor-mirror-wipe must explicitly delete these in order; Firestore has NO cascade at all (MCF-cascade).
- `_clearLocalDatabase` iterates `_database.allTables` (replaced a hand-list that missed `outbox`/`daily_plans`).
- `MergeStore.runInTransaction` (`drift_merge_store.dart:248`) — **the exact seam a Firestore-native rewrite must replace** with a Firestore transaction/batch (MCF-3-atomicity).

**Non-Drift persistence** (migration must not assume "everything is in Drift"): SharedPreferences (notification prefs, ui_preferences store-of-record, `ProfileScopedPreference<T>` with its own broadcast reactivity), FlutterSecureStorage (PINs), and `CitiesRepository`'s raw `sqlite3` bundled cities asset (static reference data, likely out of scope — exclude explicitly).

---

## 8. Identity & multi-account

**Two-tier model on one device.** Tier A = **Device Registry** (separate Drift DB, `driftDatabase(name:'device_registry')`): `DeviceAccounts` (≤5, `kMaxDeviceAccounts`) each with a unique `dbFileName`, plus `DeviceState.lastActiveAccountId`. Never synced. Tier B = **per-account User DB file** (`user_acc_<uuid>.db`), one open at a time. The active file is chosen by `AccountDbFileName` notifier → `userDatabaseProvider` rebuilds `UserDatabase` on change. **At any instant exactly one account's Drift file is open; the others sit inert and fully isolated on disk — this is the source of multi-account correctness and of offline-capable instant switching.**

**Active-account resolution.** `bootstrapAccount()` → `SessionPersistenceService.resolveActiveAccountId()` (dual-write: SharedPreferences fast path validated against the authoritative registry pointer). Switch = `setFileName(...)` then `invalidate(userDatabaseProvider)` before any profile read.

**Switch orchestration** (`account_picker_screen.dart`): tear down previous account's listeners FIRST (`stopListeners()`) before re-auth (single FirebaseAuth slot — flipping uid under live listeners floods `PERMISSION_DENIED`), verify `liveUid==targetUid` and abort on mismatch, then swap DB → resolve profile → clear `selectedProfileIdProvider` (autoincrement-collision guard, R1o-C2) → `restartListeners()`. `ProfileGuard` revalidates the selected id on every navigation.

**Identity-mismatch guard** (`syncIdentityStatusProvider`, `database_provider.dart:50-71`): compares the active-account-record uid against the live signed-in uid; symmetric pull-side (`_skipPullOnIdentityMismatch`) and push-side (`OutboxProcessor.isIdentityMismatched`) skips. Firestore paths are addressed from the **active-account record's** uid, never `currentUser` (MCF-orchestrator).

**Sync engine is a device-wide singleton** (S7) — does NOT rebuild on account switch; all account-specific collaborators are lazy closures re-`ref.read` per call; listener teardown/rebind is manual UI-driven orchestration (MCF-singleton).

**Offline / credential-less local-born tier** (`signup_screen.dart:110-123`): synthetic `offline_<uuid>@offline.local` email/password, never shown to the user, filtered out of every UI surface. Two-phase crash-safe registration (`PendingLocalSignupStore` + `cleanupStaleOnStartup`). One-way "Upgrade to Cloud" (`UpgradeToCloudService`) with three collision-merge options (upload-local / keep-cloud-discard-local / re-sign-in). **This tier has zero Firebase/Firestore presence until upgrade** (MCF-localborn).

**Non-Drift local state is NOT partitioned per account** — live confirmed defects (pre-existing, NOT introduced or fixed by the migration; treat correction as in-scope cleanup):
- SharedPreferences & FlutterSecureStorage are single device-wide stores; per-profile keys use the **bare Drift autoincrement `profileId`** which restarts at 1 per account file → two accounts' first children both hit `profileId==1` → **shared keys** (locale, font, PIN hashes, notification schedules) collide across accounts (MCF-collision).
- `deleteAccount()` calls unconditional `prefs.clear()` + `secureStorage.deleteAll()` → deleting ONE account **wipes every other registered account's** settings + PIN state (MCF-blastradius).
- Global write-once flags `initial_sync_complete` and `device_restore_state` govern per-account questions → a second cloud account on the same device silently skips its own sync/restore (acknowledged in-repo, `device_restore_screen.dart:55-57`) (MCF-globalflags).

**The honest feasibility statement.** Firestore's client SDK gives **exactly one local persistent cache tied to one FirebaseAuth identity** (default settings; sole construction site `firestore_instance_provider.dart:18`, bare `FirebaseFirestore.instance`, no persistence override anywhere). The app's entire multi-account model — N independently-openable local datasets, each offline-available, switchable instantly with no network — **cannot be reproduced by a single `FirebaseFirestore.instance`**. Switching to a second previously-synced account offline would either need its data already resident in the shared cache (not app-controllable — eviction is the SDK's affair) or a network round-trip (breaking the documented instant-offline-switch UX). The only structurally sound path is **N independent named `FirebaseApp` instances** (`Firebase.initializeApp(name:'account_<id>')`), each with its own Auth + Firestore + cache file, created/torn down per account up to 5 — a materially larger integration than "turn on Firestore persistence." Separately, the credential-less local-born tier has **no Firestore analogue** and would require inventing one (e.g. Anonymous Auth per local-born account, recasting upgrade as account-linking). The device registry must stay local regardless. **This is the single scope-defining architectural decision the rest of the migration depends on** (MCF-feasibility; §10).

---

## 9. Migration-critical facts register (deduplicated union)

Numbered MCF-1..MCF-35 (plus suffixed variants). Each fact appeared in one or more subsystem passes; evidence is the tightest citation available.

**Conflict resolution / corruption prevention**

- **MCF-1 — LWW is a 5-step algorithm, not `remote > local`.** `driftMergeStoreRemoteIsNewer` (`drift_merge_store.dart:25-64`): ±5s clock-skew window → `synced_at` server-timestamp tie-break → D15 prefer-newer-un-pushed-local → remote-wins-on-true-tie. Backed by the `SyncKv` shadow (`tables/sync_kv.dart:6-18`) storing last-applied `updatedAtMs`/`syncedAtMs`. A hand-copied test double already drifted and shipped a bug (AUD-t-cross-68). **Any replacement must live in exactly one place and preserve symmetric LWW + the ±5s tie-break, or the historical lost-update P0 reappears.**
- **MCF-2 — PointsBalance is derived, NEVER synced.** Re-summed from the append-only `PointsLedger` on every merge (`points_ledger_merger.dart:6-8`; `points_balance_dao.dart:341-380`), clamped `[0,2^30)`. A naive `FieldValue.increment` on a synced counter re-opens the "classic counter LWW lost-update" this design specifically eliminated. **dangerous.**
- **MCF-3 — Deterministic doc-id + transactional entity+watermark write.** Every push derives a doc-id from the natural key, never `collection.add()` (`_completionDocId` percent-encodes 4 components, `firestore_gateway_impl.dart:78-139`; `pushGoal` "must NEVER fall back to collection.add()" `:1247-1260`) so retries are idempotent overwrites. Each merger's entity upsert + SyncKv write are ONE Drift transaction (AUD-core-sync-08) — the atomicity must be reproduced (Firestore transaction, or fold the marker into the same doc).
- **MCF-4 — Track-scoped children carry a per-device autoincrement `track_id`, remapped at merge (`local_track_id_resolver.dart`).** Four entities (goal, gamification/points_config, study_day_config, settings/stage_definition). Contract: skip, never insert-against-remote-id (FK-abort aborts the whole page). **Kill per-device autoincrement ids globally (use ULID / Firestore doc-id) or reimplement this remap.** Highest-leverage structural fact.
- **MCF-5 — Append-only + dedup, per collection.** `completion_events, learning_ledger, streak_events, points_ledger` are INSERT-only with `UNIQUE` composite/ulid indexes and INSERT-OR-IGNORE; SR-1 rules deny delete and allow update only on identical replay (`firestore.rules:264,292,319,343`). Preserve (a) never mutate/delete rows, only tombstone; (b) deterministic natural-key/ULID doc-id so offline-queue retries collapse (Firestore dedups by doc-id, never by content).
- **MCF-6 — Completion tombstone resurrection (H2/D11).** A `purgedAt` row re-marked on another device is resurrected (clear tombstone, adopt new `completed_at`), matched WITHOUT a timestamp filter (`drift_merge_store.dart:286-308`; `completion_event_dao.dart:49-62`) or it collides on the natural key and stays dead forever. Preserve as a `purgedAt` field, never a hard delete; resurrect in a transaction.
- **MCF-7 — `completion_events.stage_id` is ambiguous pre-v37** (can encode `stageOrder` OR `StageDefinitions.id`, both small ints). v37 added a `stage_id_format` marker via lossy best-effort classification. Any export must carry the marker verbatim or downstream readers resolve to the wrong stage.
- **MCF-8 — Double-credit race closed at v34.** `points_ledger` + `reward_redemptions` got `UNIQUE(profileId,ulid)` to close a SELECT-then-INSERT TOCTOU that had already produced wild duplicates; v34 deduped + re-derived balance before creating the index. Native design needs an equivalent hard uniqueness (deterministic doc-id=ulid); an auto-id collection re-opens the P0.
- **MCF-9 — LearningLedger had three real over-credit bugs from bare (unqualified) unit ids** (v30/v31/v32; one blanket-credited ~5846 pesukim from one mark). All three legacy rows were UNRECOVERABLE and deleted. **Never migrate a pre-v30 ledger; new writers must emit fully-qualified `level1|level2[|level3[|level4]]` paths.**
- **MCF-10 — SR-3 client date fields must be real Firestore `Timestamp` ≤ `request.time`** (`completed_at`/`created_at`), hence `_timestampifyField` (`firestore_gateway_impl.dart:159-203`). Native SDK Timestamps satisfy this; any JSON-bridging/replay path must replicate the coercion or writes fail permission-denied.
- **MCF-11 — Identity remap (`learner_profiles.accountId`, "Bug 1", `drift_merge_store.dart:346-438`).** Remote cloud account_id ≠ local autoincrement id; embedding the raw id previously "bounced the user to the first-launch splash" (P0). Fix seeds a placeholder `accounts` row if needed. Use Firebase UID as the canonical cross-device key or reproduce the placeholder workaround. **Audit for ALL device-local-autoincrement-ids-in-payloads — this is a proven landmine class.**
- **MCF-12 — `TrackLearningOrder` only gained `profileId` at v36** (correlated-subquery backfill that DROPS unresolvable rows). Verify no user is still on schema <36; re-verify `profileId` integrity, don't just trust the column exists.
- **MCF-13 — RewardRedemptionMerger bypasses the shared Phase-3 algorithm** (bespoke plain `updatedAt.isAfter`, no clock-skew, ties favor local; `points_balance_dao.dart:384-425`). Explicitly decide standardize-vs-preserve; silently "fixing" it changes concurrent-decline race outcomes.
- **MCF-14 — `gamification_settings` fans one doc into TWO local stores** (Drift `PointConfigs` + SharedPreferences `reward_settings`+LWW-timestamp). Two other kinds (`notification_settings`, `ui_preferences`) write ONLY to SharedPreferences. "What must move" cannot stop at Drift.
- **MCF-15 — Pull/merge ordering is a hard dependency:** `curriculum_tracks` must merge before any track-scoped child (settings/stage_definitions/goals/study_day_configs), guarded by an AUD-core-sync-18 parity test. Independent native listeners have no ordering guarantee — re-solve, or rely on every one of those mergers already tolerating out-of-order arrival via idempotent skip-and-re-merge.
- **MCF-16 — `settings` doc and `stage_definition` collection both write `StageDefinitions`; settings merge does a full REPLACE; settings PUSH is dead (`SettingsCodec.encode()` throws).** Don't assume `settings` can be dropped without checking for a live reader; don't write both shapes.
- **MCF-26 — FB-3 local/cache-echo guard** (`firestore_gateway_impl.dart:927-990`, `hasPendingWrites`/`isFromCache`) is a genuine correctness guard on native SDK metadata — **directly portable**, must be preserved in whatever replaces MergeRouter reconciliation.
- **MCF-27 — Suspected GoalMerger dual-guard tie-break gap (F4):** merger's `synced_at` tie-break says "apply" while `GoalDao`'s plain `isAfter` silently no-ops, yet SyncKv advances as if applied. Unconfirmed (no test found) — targeted test before preserve/fix.

**Engine mechanics (deleted / replaced / no native equivalent)**

- **MCF-20 — Outbox atomicity is the durability boundary.** Outbox row is written in the SAME Drift transaction as the triggering write (`tables/outbox.dart:5`). SDK offline queue is a different, non-app-visible mechanism — verify the all-or-nothing pairing still holds (or that there are no remaining local writes to pair, which is itself a simplification to call out).
- **MCF-21 — Outbox has NO UNIQUE on `entityKey`;** multiple rows can share a key and the processor dedups then applies the result to all (`outbox_processor.dart:314-441`). Native writes must preserve "repeated logical writes for the same natural key never produce duplicate remote docs."
- **MCF-22 — No native equivalent for: dead-lettering @10 attempts** (SDK retries forever, no "gave up" signal; `stuckCount`/`syncOutboxDeadLettered` have nothing to read from), **per-kind drain ordering** (SDK FIFO), **identity-mismatch skip** (move to `.set()` call site), **completion batching** (SDK doesn't auto-batch discrete `.set()`), **profile-0/tutored sweep guards**.
- **MCF-23 — Firestore `.snapshots()` streams are TERMINAL ON ERROR at the SDK level** (permission-denied / App-Check / UNAVAILABLE). Migrating to native listeners does NOT fix R-1 — the app must implement resubscribe-on-error or dead channels stay dark for the session.
- **MCF-28 — `TutoredListenerSupervisor` has NO park()/unpark()** (16 streams stay live when backgrounded); own-account has park/unpark for 18. No native "auto-detach in background" primitive. Make an explicit decision.
- **MCF-29 — `pushLedgerEntriesBatch` is dead** (zero prod callers; ledger/streak/points are pushed ONE row at a time — only completions are batched). A cost model assuming batched ledger writes is wrong.
- **MCF-30 — `tutor_grant` is ALREADY Firestore-native** (no local row, read live; no-op merger). The working shipped precedent/template for the target architecture. But keep routing registered for every collection or a future kind silently drops.
- **MCF-31 — Docs are stale; re-derive from code.** `docs/architecture.md` describes a deleted `SyncEngine` and "retries up to 5 times" (actual `_maxAttempts=10`); `docs/explainers/sync-subsystem.md` describes "7 steps" (actual 17). F1/F2 doc-comment drift inside the merge subsystem itself. Verify every behavioral claim against call sites.
- **MCF-32 — 4-way parity invariant** (18 EntityKind ↔ 18 router cases ↔ 18 DI registrations ↔ 18 classes). Must not be silently narrowed.

**Cloud schema continuity**

- **MCF-3-continuity — Reproduce every doc-id formula exactly and keep decoding legacy field aliases**, or historical user documents orphan / stop round-tripping.
- **MCF-17 — Tutor read hinges on `tutor_active_access` `exists()`** (CF-maintained, one doc per active triple). Any grant-lifecycle change must keep this index in step or tutor access silently breaks (or a revoked grant stays readable).
- **MCF-24-orphan — `deleteUserData`'s 14-item list omits `import_metadata` + `curriculum_scopes`;** client-path deletion orphans them in production today. Live prod Firestore may already contain such orphans.
- **MCF-appcheck — App Check is CF-layer only** (absent from rules). Expanding direct-SDK read/write surface expands the rules-only-auth (no App Check) surface — a pre-existing gap the migration could widen.
- **MCF-19 — `preferences/gamification_settings` embeds `points_config[]`** — a doc-per-collection aggregate that doesn't map to per-row native docs without a fan-out remodel (W3.32 precedent).

**Consumer seams**

- **MCF-view — `completions_view`'s real filter (`WHERE purged_at IS NULL`) lives in a hand-maintained raw SQL string** outside Dart's type system (`user_database.dart:214-232`); reimplement explicitly.
- **MCF-writer — CompletionWriter atomically writes `completion_events` + `outbox` + tombstone-resurrection (H1) + B8 prior-import upgrade** in one transaction, idempotent on the 5-col natural key; the same data-write+outbox-enqueue-in-one-transaction pattern repeats across ledger/points/reorder repos. Each needs an equivalent all-or-nothing native operation.
- **MCF-8b — B8 rule:** a `prior_completion_imports` row must be deleted the instant a matching real (non-prior-mark) completion is written, so a later bulk-expunge doesn't wipe a promoted row. Easy to silently drop.
- **MCF-25 — Reorder-amnesty:** any ordering change must, in the SAME atomic write, stamp `lastReorderAt`, or the scheduler's overdue filter misprojects.
- **MCF-7-delete — Profile-deletion FK-drop ORDER** (`curriculum_scopes`/`study_day_configs` before `curriculum_tracks`) or `SqliteException(787)` rolls back the whole delete silently.
- **MCF-cascade — The 6 no-cascade tables** must be explicitly, transactionally deleted (in dependency order) on profile delete AND tutor-mirror-wipe; Firestore has no cascade at all.
- **MCF-24-streak — Streak is never a counter;** `StreakReducer` replays the entire history on every read + a 15-min tick, no date bound — unbounded read growth; needs a bounded query or denormalized cache.
- **MCF-9-counter — `completionCommittedProvider`** is a manual counter watched at 25 sites, incremented at only 4; any new completion path forgetting `.increment()` leaves UI silently stale (documented P0 class).
- **MCF-10-codegen — Drift-generated types can't be `@riverpod` return types** (hand-written StreamProvider fallback); expect the same with Firestore model types.
- **MCF-11-listeners — No de-dup of identical subscriptions** (`watchBalance` wrapped 4×); 1:1 port = N listeners per query per screen.
- **MCF-13-scaffold — 10 empty `repositories/` scaffold dirs** cause most of the 27 DAO bypasses and the 45-vs-57 undercount; `fulfilRedemption` non-transactional vs `declineRedemption` transactional (TOCTOU asymmetry to decide on).

**Identity & multi-account**

- **MCF-orchestrator / MCF-singleton — Sync engine is a device-wide keepAlive singleton that does NOT rebuild on account switch;** listener teardown/rebind is manual, ordered, UI-driven (stopListeners BEFORE re-auth). Identity guard exists because there is ONE FirebaseAuth slot but ≤5 in-app accounts; all Firestore paths addressed from the active-account record's uid, not `currentUser`. Preserve verbatim or gate every direct `.set()`.
- **MCF-35 — Device registry + Content DB stay local regardless.** The registry must work before any network/Auth session; ~87K bundled content rows are the wrong shape/cost for Firestore and must be offline-from-first-launch. Three physically distinct DBs with different offline/auth requirements — don't treat "the app's data" as homogeneous.
- **MCF-collision — SharedPreferences & FlutterSecureStorage are unpartitioned device-wide stores keyed by bare `profileId`** (which restarts at 1 per account file) → cross-account key collisions for locale/font/PIN/notification state. Pre-existing; not fixed by the migration; namespace by `(accountId, profileId)`.
- **MCF-blastradius — `deleteAccount()`'s `prefs.clear()` + `secureStorage.deleteAll()`** destroys every OTHER registered account's local state on a single-account GDPR delete.
- **MCF-globalflags — `initial_sync_complete` + `device_restore_state`** are global write-once flags governing per-account questions → second cloud account silently skips its own sync/restore (acknowledged in-repo).
- **MCF-localborn — The credential-less local-born tier has zero Firebase/Firestore presence** until one-way upgrade; needs a substitute principal (e.g. Anonymous Auth) and a redesigned collision-merge flow.
- **MCF-uiprefs-sor — `ui_preferences` value-of-record is SharedPreferences,** not Drift (Drift holds only LWW metadata).
- **MCF-outbox-isolation — The Outbox lives inside each account's own Drift file** → free per-account isolation; `removeCloudFromDevice` refuses to delete a file with undrained outbox rows (the only copy of a queued mutation). Preserve a "don't destroy the only copy of an unsynced mutation" guard.
- **MCF-feasibility — Firestore's client SDK = one local cache tied to one FirebaseAuth identity;** the multi-account offline-switch model requires N named `FirebaseApp` instances (one per account), a materially larger integration than enabling persistence. **Scope-defining.**

---

## 10. Open questions

Tagged **[owner-decision]** (product/scope/resourcing) or **[architect-investigation]** (resolvable by reading more code / a targeted test).

**Scope & product**
1. **[owner-decision]** Multi-account offline model: pursue N named `FirebaseApp` instances (true per-account offline isolation, larger integration) or accept a reduced experience (only the most-recent account offline, others need a network round-trip)? Everything downstream depends on this (MCF-feasibility).
2. **[owner-decision]** Is a "N changes pending / N rows stuck" status UI a hard product requirement post-migration? If yes, what app-level attempt-counting/dead-letter bookkeeping replaces the SDK's opaque queue (MCF-22)?
3. **[owner-decision]** Confirm the ~87K-row bundled Content DB stays local/bundled (the inventory concludes it must, but this was never an explicit scope decision anywhere in code) (MCF-35).
4. **[owner-decision]** Are the pre-existing non-Drift defects (per-`profileId` key collisions MCF-collision; `deleteAccount` blast radius MCF-blastradius; global sync/restore flags MCF-globalflags) accepted debt or in-scope cleanup for this migration? Confirm each has (or lacks) a bug report / test — none were found for the specific cross-account cases.
5. **[owner-decision]** `curriculum_scopes` intended behavior: full bidirectional owner sync (like its 15 siblings) or deliberately tutor-CF-write-only with the local Drift copy as owner source of truth? Current code implements neither coherently (§6, MCF-24-orphan-adjacent).
6. **[owner-decision]** Is the completions-bypass-facade asymmetry (no immediate write-tee for the highest-volume kind) intentional (latency-tolerant) or an overlooked gap — preserve, fix, or moot?
7. **[owner-decision]** Should tutored-mirror listeners get lifecycle-driven detach (own-account has it, tutored does not, MCF-28)? Same-namespace-isolation decision (T1) also needs confirming — via the "never call SDK from tutored context" guard or via security rules alone.

**Architect investigation**
8. **[architect-investigation]** Does the PUSH side already write completions/streak/ledger/points under a deterministic doc-id = natural key? Determines whether "dedup via composite UNIQUE" becomes "dedup via doc-id" trivially or needs push-side work first (MCF-3/5).
9. **[architect-investigation]** Confirm the GoalMerger F4 tie-break gap is reachable (drive the clock-skew-tie/synced_at-decisive branch in a unit test) before preserving or fixing it (MCF-27).
10. **[architect-investigation]** Do server-side Cloud Functions / security rules impose invariants on the 13–14 synced collections beyond what client codecs/mergers reveal? This baseline covers only the Flutter client's view (plus a read of `functions/`).
11. **[architect-investigation]** Is there any production data under `users/{uid}/profile/data` or `import_metadata` from earlier versions needing a read-compat shim, or safely GC-able?
12. **[architect-investigation]** Are there device-local-autoincrement-id-in-payload landmines (the MCF-11 class) on paths OUTSIDE `lib/core/sync/merge/` that bypass MergeRouter entirely? The merge pass was scoped to `merge/` only.
13. **[architect-investigation]** Recover the corruption scenarios behind the short audit codes referenced but not spelled out inline: `C3`/`H3` (learning_order), `M1` (multiple mergers). Likely in an audit-history corpus outside `lib/`.
14. **[architect-investigation]** Is `merge_rules.dart` (confirmed zero prod importers) safe to delete now, or is a skipped/disabled test still referencing it (F2)?
15. **[architect-investigation]** Does the `tutor_grants` real-time listener (wired but merged to a no-op; UI reads via the `listTutorGrants` CF poll) exist for a non-obvious reason (liveness telemetry), or is it vestigial (MCF-30)?
16. **[architect-investigation]** Reconcile the brief's "57 repositories" and "~13 aggregate queries" against found counts (45 repos; ~13 SQL-level aggregates if client-side reducers are excluded) — target-state vs as-is scoping (Sub-5).
17. **[architect-investigation]** Which reliability/efficiency findings (R-1 terminal listeners, R-6 syncSink race, tutored park/unpark, dead `pushLedgerEntriesBatch`) are already in-flight on the active `sync-wave1/2/3`/`sync-error-telemetry` threads — so this baseline's "currently uncorrected" flags can be treated as being-fixed rather than migration-independent work?
18. **[architect-investigation]** Do any old app builds still WRITE the pre-W3.32 `settings/{curriculumId}` `stages[]` array, or is it purely a read-only legacy fallback (safe to freeze) (MCF-16)?

---

*End of baseline inventory (draft). Next artifact: the migration brief/architecture — this document is its input, not its substitute.*