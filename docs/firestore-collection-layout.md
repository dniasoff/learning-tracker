# Firestore v1 Collection Layout

> Story: DNI-325 (Epic 25 — Schema + Core Foundation)
> Replaces the Phase-0 `users/{uid}/` nested layout introduced in Story 24.1 (DNI-316).

## Overview

All collections are **top-level** — there is no `users/{uid}/` nesting.
Every document encodes ownership in its ID (prefix `{uid}`) so security rules can
enforce it without reading the document body.

Deletions are **never** permitted via client-side writes; they must go through
Cloud Functions (server-side admin SDK) to preserve audit integrity.

---

## Collections

### Snapshot collections

Snapshot collections store the _current state_ of an entity. They allow
`read`, `create`, and `update` (with field whitelists) but deny `delete`.

| Collection | Doc ID pattern | Purpose |
|---|---|---|
| `accounts` | `{uid}` | One per Firebase Auth user; account-level metadata |
| `learner_profiles` | `{uid}_{profileId}` | One per learner profile; display name, avatar, child mode |
| `track_configs` | `{uid}_{profileId}_{curriculumId}` | Per-curriculum track settings (order, stage, active flag) |
| `bookmarks` | `{uid}_{profileId}_{sefariaRef}` | Current bookmark position per Sefaria reference |
| `settings` | `{uid}_{profileId}` or `{uid}_{profileId}_{scope}` | User preferences; `{scope}` is an optional curriculum-specific override key |

### Event collections

Event collections are **append-only** logs. They allow `create` only (with
field validators) and deny both `update` and `delete`.

| Collection | Doc ID pattern | Purpose |
|---|---|---|
| `completion_events` | `{uid}_{profileId}_{sefariaRef}_{stageId}_{trackType}` | One event per discrete completion act |
| `streak_events` | `{uid}_{profileId}_{eventType}_{isoDate}` | Streak lifecycle events (extended, broken, restored) |
| `learning_ledger` | `{uid}_{profileId}_{curriculumId}_{isoDate}` | Daily ledger entries: points, minutes, completions |

---

## Doc ID conventions

### General rules

1. Fields are joined with underscores (`_`).
2. All variable parts are **snake\_case**.
3. Date parts use ISO-8601 compact format: `YYYYMMDD` (e.g. `20260513`).
4. `sefariaRef` is the canonical Sefaria passage reference with `/` replaced by `-`
   (e.g. `Mishnah_Berakhot.1.1` → `Mishnah_Berakhot-1-1`).
5. `trackType` values: `personal` | `class` | `daf_yomi`.

### Examples

```
# accounts
abc123uid

# learner_profiles
abc123uid_1
abc123uid_2

# track_configs (profile 1, mishnayos curriculum)
abc123uid_1_mishnayos

# bookmarks (profile 1, Berakhot 1:1)
abc123uid_1_Mishnah_Berakhot-1-1

# settings (profile 1, global)
abc123uid_1

# settings (profile 1, mishnayos-specific override)
abc123uid_1_mishnayos

# completion_events (profile 1, Berakhot 1:1, stage 2, personal track)
abc123uid_1_Mishnah_Berakhot-1-1_2_personal

# streak_events (profile 1, extended, 13 May 2026)
abc123uid_1_streak_extended_20260513

# learning_ledger (profile 1, mishnayos, 13 May 2026)
abc123uid_1_mishnayos_20260513
```

---

## Security rules summary

See `firestore.rules` at the repository root for the authoritative rules.

### Ownership check

Ownership is verified by asserting that the doc ID **starts with**
`request.auth.uid`:

```
resource.id.matches('^' + request.auth.uid + '(_.*)?$')
```

For creates, `docId` (the wildcard variable) is tested the same way:

```
docId.matches('^' + request.auth.uid + '(_.*)?$')
```

Event collections additionally require `request.resource.data.uid == request.auth.uid`
as a belt-and-suspenders field-level check.

### Field whitelists (snapshot collections)

| Collection | Allowed fields |
|---|---|
| `accounts` | `uid`, `email`, `display_name`, `created_at`, `updated_at`, `fcm_token`, `platform`, `app_version` |
| `learner_profiles` | `uid`, `profile_id`, `display_name`, `avatar_url`, `created_at`, `updated_at`, `is_child_mode` |
| `track_configs` | `uid`, `profile_id`, `curriculum_id`, `track_type`, `learning_order`, `stage_id`, `is_active`, `updated_at` |
| `bookmarks` | `uid`, `profile_id`, `sefaria_ref`, `curriculum_id`, `stage_id`, `updated_at` |
| `settings` | `uid`, `profile_id`, `hebrew_terms`, `use_hebrew_date`, `curriculum_id`, `updated_at`, `display_name`, `learning_order`, `daily_goal`, `review_enabled`, `chazara_interval`, `show_points`, `track_type` |

### Event validators

| Collection | Extra create validators |
|---|---|
| `completion_events` | `points >= 0 && points <= 100`, `completed_at <= request.time` |
| `streak_events` | `created_at <= request.time` |
| `learning_ledger` | `created_at <= request.time` |

---

## Migration from Phase-0 layout (DNI-316)

The old layout nested everything under `users/{uid}/learner_profiles/{profileId}/`.
The v1 layout removes this nesting entirely.

| Old path | New collection | New doc ID |
|---|---|---|
| `users/{uid}/profile/{docId}` | `accounts` | `{uid}` |
| `users/{uid}/learner_profiles/{profileId}` | `learner_profiles` | `{uid}_{profileId}` |
| `users/{uid}/learner_profiles/{profileId}/completions/{id}` | `completion_events` | `{uid}_{profileId}_{sefariaRef}_{stageId}_{trackType}` |
| `users/{uid}/learner_profiles/{profileId}/streak_events/{id}` | `streak_events` | `{uid}_{profileId}_{eventType}_{isoDate}` |
| `users/{uid}/learner_profiles/{profileId}/learning_ledger/{id}` | `learning_ledger` | `{uid}_{profileId}_{curriculumId}_{isoDate}` |
| `users/{uid}/learner_profiles/{profileId}/settings/{id}` | `settings` | `{uid}_{profileId}` or `{uid}_{profileId}_{scope}` |
| `users/{uid}/learner_profiles/{profileId}/bookmarks/{id}` | `bookmarks` | `{uid}_{profileId}_{sefariaRef}` |
| `users/{uid}/learner_profiles/{profileId}/curriculum_tracks/{id}` | `track_configs` | `{uid}_{profileId}_{curriculumId}` |

The actual data migration (backfill) and sync engine wiring are handled in Story 25.12 (DNI-333).
