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
| `PriorCompletionImports` | `import_metadata` | |

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
