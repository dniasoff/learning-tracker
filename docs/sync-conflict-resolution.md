# Sync Conflict-Resolution Strategy (I-5)

**Approach:** hybrid — set-union (CRDT-style) for append-only event logs,
last-write-wins (LWW) by timestamp for mutable documents.

---

## Strategy by entity

| Entity | Strategy | LWW timestamp | Notes |
|--------|----------|---------------|-------|
| `completion_events` | **Set-union** — INSERT OR IGNORE on natural key | — | Natural key: `(profileId, sefariaRef, stageId, trackType)`. Duplicate inserts are silently dropped. |
| `streak_events` | **Set-union** — INSERT OR IGNORE on natural key | — | Natural key: `(profileId, eventTimestamp, eventType)`. Log is replayed to derive streak state. |
| `curriculum_tracks` | **LWW** | `max(activatedAt, deactivatedAt)` | `deactivatedAt` wins over `activatedAt` — a deactivation always propagates. |
| `goals` | **LWW** | `updatedAt` | |
| `stage_definitions` | **LWW** (via enclosing settings document `updated_at`) | `updatedAt` of settings doc | Stages are replaced wholesale when the settings document wins. |
| `learner_profiles` | **LWW** | `updatedAt` | |
| `bookmarks` | **LWW** | `updatedAt` | |
| `settings` | **LWW** | `updatedAt` | Includes per-curriculum stage definitions. |

---

## Push/pull invariant

> After `drainOutbox()` on Device A and `pullCompletions()` (plus the relevant
> collection pulls) on Device B, Device B's local DB contains every
> `completion_event` that Device A has written, and vice versa.
>
> For mutable documents, after a bidirectional pull the device with the
> strictly newer timestamp wins. If both timestamps are equal the remote row
> is silently dropped (the LWW rule is `remoteTimestamp > localTimestamp`).

---

## Implementation map

| Layer | File |
|-------|------|
| Entity kind taxonomy | `lib/core/sync/merge/entity_merger.dart` |
| Route dispatch | `lib/core/sync/merge/merge_router.dart` |
| Drift storage adapter | `lib/core/sync/merge/drift_merge_store.dart` |
| Completion merger | `lib/core/sync/merge/completion_event_merger.dart` |
| Streak merger | `lib/core/sync/merge/streak_event_merger.dart` |
| Track merger | `lib/core/sync/merge/track_config_merger.dart` |
| Bookmark merger | `lib/core/sync/merge/bookmark_merger.dart` |
| Settings / stage merger | `lib/core/sync/merge/settings_merger.dart`, `stage_definition_merger.dart` |
| Profile merger | `lib/core/sync/merge/learner_profile_merger.dart` |

---

## Dependency on C1

Once C1 lands (replacing the explicit `completions` table write with a Drift
view projection), `completion_events` becomes the only write target for
completions. The conflict-resolution strategy above is already written
against that final state — `completion_events` is the canonical log and
streaks are derived from it, so neither requires a separate merge pass.

Until C1 is complete, `completions` projection rows continue to be written
by `CompletionWriter` and are NOT synced — only `completion_events` rows are
pushed and pulled.

---

## Two-device test harness

`test/integration/two_device_sync_test.dart` covers:

1. **Completion set-union** — Device A and Device B each insert a distinct
   completion; after a bidirectional merge, both DBs contain both completions.
2. **Track deactivation propagation (LWW)** — Device A deactivates a track
   (sets `deactivatedAt`); after Device B merges Device A's track row, Device
   B's local track has `deactivatedAt` set.
3. **Idempotent re-merge** — Replaying the same completion rows twice leaves
   the DB unchanged (no duplicate rows, no errors).
