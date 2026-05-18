# Firestore Collection Layout

> Status: **current** — reconciled to the live application code on 2026-05-18
> (Firebase Sync Rework, Wave 2).
>
> History: an earlier revision of this document described a flat *top-level*
> collection layout (planned under DNI-325). That layout was **never built** —
> `FirestoreGatewayImpl` ships a nested, user-scoped layout. The document below
> describes what the app actually reads and writes; the old top-level content
> is superseded.

## Overview

The application uses a **nested, user-scoped** layout. Everything a user owns
lives beneath `users/{uid}`, and per-learner data lives beneath
`users/{uid}/learner_profiles/{profileId}`.

```
users/{uid}                                         — account user-profile doc
users/{uid}/profile/data                            — account profile snapshot
users/{uid}/diagnostic_logs/{autoId}                — diagnostic log events
users/{uid}/learner_profiles/{profileId}            — one doc per learner
users/{uid}/learner_profiles/{profileId}/<collection>/...
```

Ownership is enforced structurally: the security rules gate every path on
`isOwner(uid)` against the `users/{uid}` segment, so no document body needs to
be read to authorize a request. Doc IDs are *not* uid-prefixed in this layout —
the path itself encodes ownership.

The canonical rules and indexes live at:

- `learning_tracker/firestore.rules`
- `learning_tracker/firestore.indexes.json`

Both are wired into `learning_tracker/firebase.json`. (The repo-root copies of
these files were stale descriptions of the never-built top-level layout and
were deleted in the Wave 2 reconciliation.)

---

## Account-level documents

| Path | Kind | Written by |
|---|---|---|
| `users/{uid}` | Snapshot | `pushAccountUserProfile` |
| `users/{uid}/profile/data` | Snapshot | `pushAccountProfile` |
| `users/{uid}/diagnostic_logs/{autoId}` | Append-only event | `pushDiagnosticLog` |
| `users/{uid}/learner_profiles/{profileId}` | Snapshot | `pushLearnerProfile` |

`learner_profiles` documents are keyed by the local profile id as a string
(e.g. `1`, `2`). Client deletes are denied — `deleteLearnerProfile` invokes a
server Cloud Function that runs a recursive delete.

---

## Per-profile subcollections

All of these live under
`users/{uid}/learner_profiles/{profileId}/<collection>/...`.

### Append-only event collections

These deny `update` and `delete` (the streak doc is the documented exception —
see note). New rows may only be appended.

| Collection | Doc ID | Purpose | Written by |
|---|---|---|---|
| `completions` | `<profileId>_<sefariaRef>_<stageId>_<trackType>` (sanitized) | One event per discrete completion act | `pushCompletion` / `pushCompletionsBatch` |
| `learning_ledger` | auto-id | Daily ledger entries: points, minutes, completions | `pushLedgerEntry` / `pushLedgerEntriesBatch` |

`completions` create is additionally validated: `0 <= points <= 100`.

### Snapshot collections

These hold current-state documents. Owner-gated `read`, `create`, `update`;
`delete` is denied (except `profile_programs` — see note).

| Collection | Doc ID | Purpose | Written by |
|---|---|---|---|
| `streak` | `data` (single doc) | Current streak snapshot | `pushStreak` |
| `settings` | `<curriculumId>` or `default` | User preferences (global + per-curriculum) | `pushSettings` |
| `curriculum_tracks` | `<curriculumId>_<trackType>` | Per-curriculum track config | `pushTrack` |
| `bookmarks` | `<curriculumId>_<trackType>` | Current bookmark position | `pushBookmark` |
| `learning_order` | `<curriculumId>_<ref>` | Learning-order snapshot | `pushLearningOrder` |
| `notification_settings` | `preferences` (single doc) | Notification preferences | `pushNotificationSettings` |
| `gamification_settings` | `config` (single doc) | Gamification config | `pushGamificationSettings` |
| `ui_preferences` | `data` (single doc) | UI preferences | `pushUiPreferences` |
| `goals` | `<goalId>` or auto-id | Learner goals | `pushGoal` |
| `curriculum_import_metadata` | `<curriculumId>` or `default` | Curriculum import metadata | `pushCurriculumImportMetadata` |
| `profile_programs` | `<curriculumId>` | Curriculum-to-profile assignments | `pushProfileProgram` |

**Notes:**

- `streak` is a running snapshot doc, not an event log, so its rule permits
  `update`; it is never client-deleted.
- `profile_programs` is the one collection where the client deletes documents
  directly (`removeProfileProgramAssignment` un-assigns a curriculum), so its
  rule permits `delete`.

### Doc ID sanitization

`FirestoreGatewayImpl._sanitizeDocId` replaces `/`, space and `.` with `_`
before a string is used as a document ID, so a Sefaria reference such as
`Mishnah Berakhot.1.1` becomes `Mishnah_Berakhot_1_1`.

---

## Security rules

`learning_tracker/firestore.rules` is authoritative. Shape:

1. A global `match /{document=**}` **default-deny** wildcard, declared first so
   any unlisted collection inherits a hard deny.
2. **Top-level compatibility blocks** for `accounts`, `learner_profiles`,
   `completion_events`, `streak_events`, `learning_ledger`, `track_configs`,
   `bookmarks` and `settings`. These describe the *deprecated* top-level layout
   the app never writes; they are retained because Story 27.8's acceptance test
   (`epic_27_story_27_8_rules_and_offline_flush_test.dart`) pins their
   append-only clauses, field whitelists and validators. They allow `create`
   only and deny `update`/`delete`.
3. The **live nested rules** under `users/{uid}/...`, gated by `isOwner(uid)`.

### Event validators (live nested rules)

| Collection | Create validators |
|---|---|
| `completions` | `points >= 0 && points <= 100` |

### Event validators (top-level compat blocks)

| Collection | Create validators |
|---|---|
| `completion_events` | `points >= 0 && points <= 100`, `completed_at <= request.time` |
| `streak_events` | `created_at <= request.time` |
| `learning_ledger` | `created_at <= request.time` |

### Field whitelists (top-level compat snapshot blocks)

| Collection | Allowed fields |
|---|---|
| `accounts` | `uid`, `email`, `display_name`, `created_at`, `updated_at`, `fcm_token`, `platform`, `app_version` |
| `learner_profiles` | `uid`, `profile_id`, `display_name`, `avatar_url`, `created_at`, `updated_at`, `is_child_mode` |
| `track_configs` | `uid`, `profile_id`, `curriculum_id`, `track_type`, `learning_order`, `stage_id`, `is_active`, `updated_at` |
| `bookmarks` | `uid`, `profile_id`, `sefaria_ref`, `curriculum_id`, `stage_id`, `track_type`, `updated_at` |
| `settings` | `uid`, `profile_id`, `hebrew_terms`, `use_hebrew_date`, `curriculum_id`, `updated_at`, `display_name`, `learning_order`, `daily_goal`, `review_enabled`, `chazara_interval`, `show_points`, `track_type` |

---

## Indexes

`learning_tracker/firestore.indexes.json` declares **no composite indexes**.

The sync layer's only Firestore-side query is
`FirestoreGatewayImpl.fetchPage`, which paginates with
`orderBy(FieldPath.documentId)` — that uses the implicit single-field index and
needs no composite index. Listener channels use unfiltered `.snapshots()`.
Every other `where`/`orderBy` in the codebase runs against the local Drift
(SQLite) database, not Firestore.

If a future feature adds a filtered or ordered Firestore query, add the
matching composite index here and keep this note current.
