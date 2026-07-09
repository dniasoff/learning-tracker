# Firestore Collection Layout

> Status: **current** — reconciled to `learning_tracker/firestore.rules` and
> `learning_tracker/firestore.indexes.json` on 2026-07-03 (AUD-firebase-03).
>
> History: an earlier revision described a flat *top-level* collection layout
> (planned under DNI-325) plus a set of "top-level compatibility blocks" kept
> in the rules for a since-superseded acceptance test. Neither exists in the
> rules file any more — see [Security rules](#security-rules) below. This
> document describes what the app actually reads and writes today.

## Overview

The application uses a **nested, user-scoped** layout. Everything a user owns
lives beneath `users/{uid}`, and per-learner data lives beneath
`users/{uid}/learner_profiles/{profileId}`. Two top-level collections support
the cross-user tutor-access feature (W3.38 / V2-R3).

```
users/{uid}                                         — account user-profile doc
users/{uid}/profile/data                            — account profile snapshot
users/{uid}/diagnostic_logs/{autoId}                — diagnostic log events
users/{uid}/learner_profiles/{profileId}            — one doc per learner
users/{uid}/learner_profiles/{profileId}/<collection>/...

tutor_grants/{grantId}                              — M:N tutor permission graph
tutor_grants/{grantId}/audit_log/{entryId}          — tutor action audit trail
tutor_active_access/{accessId}                      — O(1) active-grant lookup index
```

Ownership of the nested layout is enforced structurally: the security rules
gate every path on `isOwner(uid)` against the `users/{uid}` segment, so no
document body needs to be read to authorize a request. Doc IDs are *not*
uid-prefixed in this layout — the path itself encodes ownership. The two
top-level collections are keyed differently (see
[Tutor-access collections](#tutor-access-collections-top-level)) since they
are shared across the parent's and tutor's uids.

The canonical rules and indexes live at:

- `learning_tracker/firestore.rules`
- `learning_tracker/firestore.indexes.json`

Both are wired into `learning_tracker/firebase.json`.

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
server Cloud Function that runs a recursive delete. `profile/data` and
`diagnostic_logs` are **owner-only** — a tutor never gets a read clause on
either, since they are account-scoped siblings of `learner_profiles/`, not
part of a learner's subtree.

---

## Tutor-access collections (top-level)

Added by the tutor-access feature (W3.38 onward); not part of the nested
`users/{uid}/learner_profiles/...` tree because they are shared across the
parent's and tutor's uids.

| Collection | Doc ID | Purpose | Client writes |
|---|---|---|---|
| `tutor_grants/{grantId}` | `{encodedEmail}__{parentUid}__{childProfileId}` | Invite/grant lifecycle state machine (pending → active → revoked/resigned/declined/expired) | **None** — Admin SDK only (Cloud Functions: `inviteTutor`, `acceptTutorInvite`, `declineTutorInvite`, `rescindTutorInvite`, `revokeTutorGrant`, `resignTutorGrant`) |
| `tutor_grants/{grantId}/audit_log/{entryId}` | ULID | Per-action audit trail for tutor-originated mutations (12-month retention, server-enforced) | **None** — Admin SDK only |
| `tutor_active_access/{accessId}` | `{tutorUid}_{parentUid}_{profileId}` | O(1) secondary index: existence of this doc is what `hasActiveTutorAccess()` checks to grant a tutor read access to a learner's subcollections | **None** — written by `acceptTutorInvite`, deleted by `revokeTutorGrant`/`resignTutorGrant`/the scheduled `expirePendingInvites` |

**Reads:**
- `tutor_grants/{grantId}`: the tutor (`resource.data.tutor_uid == request.auth.uid`) or the parent (`resource.data.parent_uid == request.auth.uid`).
- `audit_log/{entryId}`: same parent-or-tutor check, resolved via a `get()` on the parent grant doc.
- `tutor_active_access/{accessId}`: only the tutor named in `resource.data.tutor_uid` may read their own entry.

A malicious client forging `tutor_grants.state == 'active'` directly is the
primary attack vector these `allow create/update/delete: if false` rules
close — see coding-standards.md SR-5 for the corresponding cross-user-access
threat model.

---

## Per-profile subcollections

All of these live under
`users/{uid}/learner_profiles/{profileId}/<collection>/...`. Every one is
readable by the profile owner and, in addition, by a tutor with
`hasActiveTutorAccess(uid, profileId)` — i.e. `read: if isOwner(uid) ||
hasActiveTutorAccess(uid, profileId)` — **except** `profile/data` and
`diagnostic_logs`, which are account-level (see above), not per-profile.

### Append-only event collections (SR-1)

Deny `delete`. `create` is owner-only (plus field validation on
`completions`); `update` is allowed **only** as an idempotent identical
replay (`request.resource.data == resource.data`) — an outbox retry can
re-push the same row without stranding it, but a changed-value update is
always denied (AUD-docs-01 / SR-1: previously these permitted any
owner-authenticated value change).

| Collection | Doc ID | Purpose | Written by |
|---|---|---|---|
| `completions` | `{profileId}_{sefariaRef}_{stageId}_{curriculumId}`, each component percent-encoded (see [Doc ID encoding](#doc-id-encoding)) | One event per discrete completion act | `pushCompletion` / `pushCompletionsBatch` |
| `streak_events` | ULID (W3.37) | Per-event streak log (replaced the old `streak/data` snapshot) | `pushStreak` |
| `learning_ledger` | ULID (W3.36) | Daily ledger entries: points, minutes, completions | `pushLedgerEntry` / `pushLedgerEntriesBatch` |
| `points_ledger` | ULID | Points spend-economy ledger entries (WS9 Wave-B / C#2) | `pushPointsLedgerEntry` |

`completions` create is additionally validated: `0 <= points <= 100` (when
`points` is present) and `completed_at <= request.time` (when present).

### LWW state-machine collection

Not append-only — `update` genuinely changes the document as the redemption
progresses through its states.

| Collection | Doc ID | Purpose | Written by |
|---|---|---|---|
| `reward_redemptions` | ULID | `pending_fulfilment` → `fulfilled`/`declined`; the parent transitions it | `pushRewardRedemption` |

`allow create, update: if isOwner(uid)`; `delete` denied.

### Snapshot collections — whitelisted (`.hasOnly(...)`)

Current-state documents with a stable, fully-enumerable payload. `create`/
`update` are gated by a field whitelist so a compromised or buggy client
cannot smuggle extra fields onto the doc. `_`-prefixed bookkeeping keys are
stripped by `FirestoreGatewayImpl._stripInternalKeys` before any write, so
whitelists are never tripped by internal keys.

| Collection | Doc ID | Delete | Written by |
|---|---|---|---|
| `stage_definitions` | `{trackId}_{stageOrder}` (W3.32) | denied | `pushStageDefinition` |
| `curriculum_tracks` | `{curriculumId}` (one track per curriculum, H1/V3-W1) | denied | `pushTrack` |
| `bookmarks` | `{curriculumId}` (one bookmark per curriculum) | denied | `pushBookmark` |
| `learning_order` | `{curriculumId}_{ref}` | denied | `pushLearningOrder` |
| `goals` | `{goalId}` or auto-id | denied | `pushGoal` |
| `import_metadata` | `{curriculumId}` or `default` (W3.34, renamed from `curriculum_import_metadata`) | denied | `pushCurriculumImportMetadata` |
| `profile_programs` | `{curriculumId}` | **owner may delete** (`removeProfileProgramAssignment` un-assigns a curriculum) | `pushProfileProgram` |
| `study_day_configs` | `{curriculumId}_{dayOfWeek}_{trackId}` (Plan §F Phase 1) | **owner may delete** | `pushStudyDayConfig` |

See `firestore.rules` for each collection's exact whitelisted field set —
several (`curriculum_tracks.purged`/`purged_at`, `profile_programs.updated_at`)
carry an inline comment explaining a past `permission-denied`-on-legitimate-
write incident that added the field, and are a cautionary precedent for
`AUD-firebase-05`'s zero-denial-oracle fixture-completeness gap.

### Snapshot collections — open-ended (no whitelist)

Heterogeneous, open-ended payloads — intentionally **not** whitelisted, to
avoid silently dropping a legitimate new field.

| Collection | Doc ID | Delete | Written by |
|---|---|---|---|
| `settings` | `{curriculumId}` or `default` | denied | `pushSettings` |
| `preferences/{scope}` | scope name: `notification_settings`, `gamification_settings`, `ui_preferences` (unified W3.33; replaces three separate collections) | denied | `pushNotificationSettings` / `pushGamificationSettings` / `pushUiPreferences` |
| `curriculum_scopes` | `{scopeId}` | **owner may delete** | `tutorUpsertCurriculumScope` Cloud Function (tutor path, gated on `can_edit_stages`); no owner-client push path is wired yet even though the rule permits `isOwner(uid)` writes directly |

---

## Security rules

`learning_tracker/firestore.rules` is authoritative. Shape (3 sections, in
this order):

1. A global `match /{document=**}` **default-deny** wildcard, declared first
   so any unlisted collection inherits a hard deny.
2. The two [tutor-access collections](#tutor-access-collections-top-level)
   (`tutor_grants` incl. its `audit_log` subcollection, `tutor_active_access`) —
   top-level, Admin-SDK-write-only.
3. The **live nested layout** under `users/{uid}/...`, gated by `isOwner(uid)`
   (see [Per-profile subcollections](#per-profile-subcollections) above).

There is no longer a "top-level compatibility blocks" section — an earlier
revision of this document described `accounts`, `learner_profiles`,
`completion_events`, `track_configs`, `bookmarks`, `settings` compat blocks
retained for a since-superseded acceptance test; they do not exist in the
current `firestore.rules`.

---

## Indexes

`learning_tracker/firestore.indexes.json` declares **6 composite indexes**,
all on `tutor_grants` (supporting `listTutorGrants`' `incoming`/`outgoing`/
`pending_for_me` query modes and their sort orders):

| Fields (in order) |
|---|
| `tutor_uid` ASC, `state` ASC |
| `parent_uid` ASC, `child_profile_id` ASC, `state` ASC |
| `tutor_email` ASC, `state` ASC |
| `state` ASC, `updated_at` ASC |
| `tutor_uid` ASC, `updated_at` DESC |
| `parent_uid` ASC, `updated_at` DESC |

Every per-profile subcollection query still runs through
`FirestoreGatewayImpl.fetchPage`, which paginates with
`orderBy(FieldPath.documentId)` — the implicit single-field index, needing no
composite index. Listener channels use unfiltered `.snapshots()`. Every other
`where`/`orderBy` in the codebase runs against the local Drift (SQLite)
database, not Firestore.

If a future feature adds a new filtered/ordered Firestore query, add the
matching composite index here and keep this table current.

### Doc ID encoding

`FirestoreGatewayImpl._encodeKeyComponent` percent-encodes each component of
a composite document ID (used by `completions` above) before joining with
`_`: only ASCII letters, digits, `-` and `~` survive unescaped; every other
byte — including `%`, the `_` separator itself, `/`, `.` and space — is
escaped as `%XX`. Because `%` is itself escaped, the encoding is injective
(decode is unambiguous), so a Sefaria reference such as `Mishnah Berakhot.1.1`
becomes `Mishnah%20Berakhot%2E1%2E1` and distinct inputs can never collide
into the same joined doc ID.
