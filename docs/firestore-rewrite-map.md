---
title: "Drift → Firestore rewrite map"
status: active
updated: 2026-08-02
---

# Drift → Firestore rewrite map

The app is greenfield (no users, no back-compat). The custom sync engine and the
per-account Drift user database are being replaced with direct Firestore in one pass.

**The target schema is not new.** `learning_tracker/firestore.rules` already specifies
it in full and 27 Cloud Functions already write to it. `lib/data/firestore/doc_ids.dart`
already holds every doc-id formula (golden-tested). Build on those; do not redesign.

## Roots

```
tutor_grants/{grantId}                    top-level, server-written only
tutor_grants/{grantId}/audit_log/{id}     server-written only
tutor_active_access/{accessId}            top-level, server-written only
users/{uid}                               account doc
users/{uid}/profile/{docId}
users/{uid}/diagnostic_logs/{logId}
users/{uid}/learner_profiles/{profileId}
users/{uid}/learner_profiles/{profileId}/<15 subcollections>
```

## Table → collection

| Drift table | Firestore | Notes |
|---|---|---|
| `Accounts` | `users/{uid}` | the account *is* the uid now |
| `LearnerProfiles` | `learner_profiles/{profileId}` | doc-id = profile ULID, **not** the account uid |
| `CurriculumTracks` | `curriculum_tracks` | doc-id = `curriculumId` |
| `CurriculumScopes` | `curriculum_scopes` | |
| `ProfilePrograms` | `profile_programs` | |
| `StageDefinitions` | `stage_definitions` | doc-id = `{curriculumId}_{stageOrder}` |
| `StudyDayConfigs` | `study_day_configs` | doc-id = `{curriculumId}_{dayOfWeek}` |
| `PointConfigs` | `preferences/gamification_settings` | embedded, single owner |
| `CompletionEvents` | `completions` | append-only; deterministic doc-id = dedup |
| `LearningLedger` | `learning_ledger` | append-only; ULID doc-id |
| `StreakEvents` | `streak_events` | append-only; ULID doc-id |
| `PointsLedger` | `points_ledger` | append-only; ULID doc-id |
| `RewardRedemptions` | `reward_redemptions` | mutable state machine, not a ledger |
| `Bookmarks` | `bookmarks` | |
| `LearningOrder` + `TrackLearningOrder` | `learning_order` | |
| `Goals` | `goals` | |
| `PriorCompletionImports` | **UNRESOLVED — see below** | NOT `import_metadata` |

## Deleted outright

| Drift table | Why |
|---|---|
| `Outbox` | the SDK's offline write queue replaces it |
| `SyncKv` | merge bookkeeping for an engine that no longer exists |
| `PointsBalance` | derived by summing `points_ledger` — never a stored counter |

## Stays local (never leaves the device)

- bundled content DB (`lib/core/database/content/**`, ~87K rows, ships as an asset)
- device account registry (`lib/core/database/registry/**`) — maps device → accounts pre-auth
- `TextDownloadStatuses` — "is this text on *this* device"
- `SacredWindowEntries` — derived zmanim cache for this device's location
- `DailyPlans` — recomputed per device from stages + goals + bookmarks

## Deleted concepts

- **Tutored mirror profiles.** `LearnerProfiles.isTutored` / `tutorParentUid` /
  `tutorRemoteProfileId` / `tutorGrantId`, the mirror-wipe transactions and the 7-table
  non-cascading cleanup existed because the sync engine had to *copy* a tutored child's
  data into the tutor's local DB. The rules already let a tutor read
  `users/{parentUid}/learner_profiles/{profileId}` and all 15 subcollections directly
  via `hasActiveTutorAccess()`. The tutor reads the parent's tree. No mirror.
- **LWW conflict predicate** (`conflict.dart`) — one writer per account.
- **`legacy*DocId` twins** in `doc_ids.dart` — for a backfill that will never run.
- Merge routers, mergers, codecs, outbox/push pipeline, sync orchestrator, pull
  pagination, per-account Drift file swapping, Drift user-schema migrations.

## Invariants that survive

- Deterministic doc-ids — never `collection.add()`, never a device-local autoincrement
  id in a payload. Append-only collections dedup by doc-id.
- Balances and streaks are **derived** from append-only ledgers, never stored counters.
- Every listener wraps mark-dead + bounded-exponential-backoff resubscribe
  (`snapshots()` is terminal on error). Small — tens of lines, not a supervisor.
- Sync status is exactly `synced | syncing | offline`, from SDK signals only
  (`hasPendingWrites`, `isFromCache`, connectivity). No queue counters.
- One repository owner per entity; Firestore authoritative, any local copy is a
  rebuildable projection.
- Per-account named `FirebaseApp` **with its own authenticated session**; app key is
  the stable device-registry account UUID, never the Firebase uid.

## RESOLVED: prior-import tier tracking, the B8 upgrade, and lifetime learning

**Owner invariant (2026-08-02):** *"if something is marked as learnt in a track it
cannot be shown or marked learnt again — that should be impossible"*, and *"globally
yes, something can be learnt multiple times"*.

That is exactly the shipped three-tier `CompletionSource` model
(`lib/features/learning/domain/entities/completion_source.dart:34-44`):

| Source | Engagement (streak/points) | Track achievement | Lifetime ledger |
|---|---|---|---|
| `live` | ✓ | ✓ | ✓ |
| `bulkInTrack` | ✗ | ✓ | ✓ |
| `lifetimeOnly` | ✗ | ✗ | ✓ |

- **Per-track: once only.** The `completions` natural key is
  `(profileId, sefariaRef, stageId, trackType, curriculumId)` — one record per item per
  track. Written once, never updated.
- **Globally: many times.** `learning_ledger` is append-only, ULID-keyed, carries
  `completionNumber` (the nth lifetime completion of that unit), and **deliberately has
  no foreign keys to tracks or curricula so entries survive their deletion**
  (`learning_ledger.dart:6-10`). This is the lifetime-statistics feature; the owner
  flagged it as potentially very important, so it must not be weakened.
- `lifetimeOnly` writes **only** a ledger entry — no `completions` row.

**Consequences — all deletions, no rules change:**

1. **No `firestore.rules` relaxation.** A bulk-marked item is hidden, so it can never be
   re-learned; a completion's `source` is therefore fixed at creation and never
   mutates. `completions`' create rule is an open bag (no `.hasOnly()`), so storing
   `source: 'live' | 'bulkInTrack'` on the document needs no rule change. SR-1
   append-only stays exactly as written.
2. **`PriorCompletionImports` is not ported.** Its only job was to distinguish tiers via
   a correlated `EXISTS` subquery; `source` on the document replaces it, and
   `getCompletionsByTier`'s 8 call sites become a plain field filter.
3. **B8 / `_upgradePriorMarkRow` is dead** — it upgraded a prior mark to real learning,
   which the invariant makes unreachable.

**Still open (small):** `expungePriorCompletions` lets a user un-tick an onboarding
bulk-mark, but `completions` denies client deletes. Either permit deleting a completion
whose `source == 'bulkInTrack'`, or make the onboarding bulk-mark a confirm-before-commit
step so there is nothing to undo. Decide before building the completions repository.

## SUPERSEDED (kept for the reasoning): prior-import tier tracking and the B8 upgrade

`PriorCompletionImports` does **not** map to `import_metadata`. They are different
things:

- Drift `PriorCompletionImports` — one row **per imported item**
  (`profileId, curriculumId, sefariaRef, stageId, trackType, source`).
- Firestore `import_metadata` — one doc **per curriculum import**, field-whitelisted to
  `profile_id, curriculum_id, item_count, imported_at, synced_at` (`firestore.rules:482-490`).

So per-item prior-import tracking has no Firestore home today. This matters because
`CompletionDao.getCompletionsByTier` — **8 call sites**, the single most-used read in the
app — distinguishes bulk-imported from genuinely-learned completions via a correlated
`EXISTS` subquery against that per-item table.

**B8 is currently inexpressible.** Its mechanism is "delete the prior-import record so
the row counts as real learning" (`completion_writer.dart:159-162`), but
`import_metadata` is `allow delete: if false` and `completions` permits `update` only as
a byte-identical replay (SR-1). A completion can therefore never transition from
bulk-import to real learning. The old sync engine never hit this because B8 only ever
deleted the *Drift* row; Firestore was never involved.

**Recommended resolution:** carry `source: 'bulkImport' | 'live'` on the completion
document itself (the `completions` create rule is an open bag — no `.hasOnly()` — so a
new field needs no rules change), and relax the `completions` update rule from
"byte-identical replay only" to "byte-identical replay **or** a `source`
`bulkImport`→`live` transition with every other field unchanged". That keeps one
collection and one query (`where source == 'live'`), needs no client-side join against a
possibly-huge import set, and preserves SR-1's actual intent — `points` and
`completed_at` stay immutable, so the record-tampering the rule exists to prevent is
still blocked.

Rejected alternative: a separate mutable per-item `prior_imports` collection with
existence-check semantics. Correct, but forces every tier-filtered read to load the
profile's entire import set client-side — potentially 10k+ docs after a "I already know
all of Shas" bulk import.

## Owner decisions (2026-08-02)

- **Track purge → extend the `deleteCurriculumTrack` Cloud Function** to sweep the
  sibling collections by `curriculum_id`, rather than restructuring track-scoped data
  into subcollections under the track doc. A recursive delete on
  `curriculum_tracks/{curriculumId}` does NOT reach `goals`, `stage_definitions`,
  `study_day_configs`, `curriculum_scopes`, `learning_order` or `profile_programs` —
  they are siblings under the profile, not children of the track. A server path is
  required regardless, because the current code tombstones completions and append-only
  rules forbid that from a client.
- **Data export/import survives, as a nice-to-have** — not on the critical path.
  Rebuild it after the core repositories land. With Firestore authoritative, the natural
  shape is a "download my data" export rather than a local-JSON round-trip backup.
- **Prior-import tier** — proceeding with the `source`-field + narrow-rules-relaxation
  option above. Lands as its own commit, independently revertible.

## Watch out

- **8 collections have two writers** — the owner directly, and a tutor via a proxy CF
  (`goals`, `curriculum_tracks`, `stage_definitions`, `study_day_configs`, `bookmarks`,
  `profile_programs`, `curriculum_scopes`, `preferences/gamification_settings`). Client
  writes must land shapes byte-compatible with what `tutor_writes.ts` writes.
- Server field whitelists in `tutor_writes.ts` mirror the rules `.hasOnly()` lists 1:1.
  A new client field needs updating in both places.
- **No composite indexes exist for any `learner_profiles` subcollection.** Any
  `.where()` + `.orderBy()` on different fields needs a new index added.
- Append-only rules allow `update` only as a byte-identical replay.
- Rule *comments* for `completions` and `stage_definitions` doc-ids are stale;
  `doc_ids.dart` is authoritative.
