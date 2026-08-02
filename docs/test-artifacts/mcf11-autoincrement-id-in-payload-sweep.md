# MCF-11 / AD-5 autoincrement-id-in-payload landmine sweep

**Story:** 2.4 — "Sweep and gate autoincrement-id-in-payload landmines"
(`docs/planning/epics-firestore-migration-phase0.md`, Epic 2).
**Phase-0 exit deliverable** per Additional Requirements — Phase-0 exit;
binds FR6, FR10; CAP-2, CAP-4; AD-5, AD-28 (`docs/planning/architecture/
architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md`); MCF-4,
MCF-11 (`docs/planning/drift-to-firestore-migration-baseline.md`).
**Date:** 2026-08-02.

## The landmine class

Three Drift tables define a per-device `IntColumn get id =>
integer().autoIncrement()()` primary key with no meaning outside the device
that generated it:

| Table | File | Aliased payload key(s) |
|---|---|---|
| `LearnerProfiles` | `lib/core/database/tables/learner_profiles.dart:13` | `profile_id` / `profileId` |
| `CurriculumTracks` | `lib/core/database/tables/curriculum_tracks.dart:14` | `track_id` / `trackId` |
| `Accounts` | `lib/core/database/tables/accounts.dart:13` | `account_id` / `accountId` |

If one of these raw integers is embedded inside a document synced to
Firestore, it means nothing on a second device — the exact "Bug 1"
identity-remap defect (`_resolveLocalAccountId`,
`lib/core/sync/merge/drift_merge_store.dart:324-438`) that once bounced a
user to the first-launch splash screen, and the reason
`resolveLocalTrackId` (`lib/core/sync/merge/local_track_id_resolver.dart`)
exists at all. AD-5 states the rule plainly: "no autoincrement id may
appear inside any payload... An audit sweeps for autoincrement-id-in-payload
landmines outside merge/ (MCF-11 class) before cutover." This document is
that audit.

## Scoping notes (what this sweep counted, and what it deliberately didn't)

- **`lib/core/sync/merge/**` is carved out entirely.** It is where these ids
  are legitimately *consumed* (the remap contract), never the leak site.
- The sweep's mechanical detector (`tool/
  check_mcf11_autoincrement_id_in_payload_ratchet.dart`) triggers on a `Map`
  literal string key `track_id` / `trackId` / `account_id` / `accountId` /
  `child_profile_id` / `childProfileId` whose value expression itself names
  the dangerous field or ends in a bare `.id` access. `child_profile_id` is
  included because every current call site aliases `LearnerProfiles.id`
  (see Category B below).
- **`profile_id` / `profileId` is deliberately NOT a trigger key.** It is
  ubiquitous throughout the app as a required scoping/routing parameter —
  DAO `WHERE profileId = ?` queries, `AppLogger` diagnostic `fields:` maps,
  path segments, use-case parameters — not payload identity in the MCF-11
  "Bug 1" sense. A first pass that included it produced overwhelming noise
  (hundreds of matches, nearly all diagnostic/routing, zero signal). The
  `learner_profiles` document's own id/identity is AD-5's separate,
  already-tracked "profile-scoped stable key (ULID)" doc-id redesign — a
  different mechanism (Story 2.2 / AD-25), not a payload-content leak this
  sweep is chartered to find.
- A `Map` literal that is the value of a `fields:` named parameter (this
  codebase's `AppLogger` structured-logging convention, e.g.
  `AppLogger.instance.warning(event: ..., fields: {'trackId': trackId})`)
  is excluded — a diagnostic log payload is never written to Firestore.
- This is a **text-based heuristic**, the same rigor level as this
  codebase's other `tool/check_*_ratchet.dart` scripts — not a full Dart
  parse. It will not catch every conceivable shape (e.g. an id threaded
  through several layers of indirection before reaching a literal map key —
  see the tutor-grant chain in Category B, where the detector's anchor is
  several call-frames downstream of the true origin).

## Findings

The detector (`dart run tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart --report`,
run from `learning_tracker/`) currently finds **39 sites** outside
`lib/core/sync/merge/`. None are new — all 39 are the tracked ratchet
baseline (`tool/mcf11_autoincrement_id_in_payload_baseline.txt`) as of this
sweep. They fall into four categories:

### Category A — the core sync engine's codec layer (8 sites, documented, structural)

Every `EntityCodec.encode()` that carries a track-scoped or account-scoped
field embeds the raw local id. This is the load-bearing (if fragile)
current design of the whole sync engine — mitigated only by the
`lib/core/sync/merge/` remap logic — and is exactly what
`docs/planning/drift-to-firestore-migration-baseline.md` already documents
as MCF-4's "four entities" (goal, gamification/points_config,
study_day_config, settings/stage_definition) and MCF-11's account-id case.
**Not introduced by this story; not fixed by this story** — remediation is
AD-25's canonical-stable-key redesign, a later story.

| Site | Field |
|---|---|
| `lib/core/sync/codec/track_codec.dart:110` | `track_id` ← `model.trackId` |
| `lib/core/sync/codec/goal_codec.dart:109` | `track_id` ← `model.trackId` |
| `lib/core/sync/codec/study_day_config_codec.dart:81` | `track_id` ← `model.trackId` |
| `lib/core/sync/codec/stage_definition_codec.dart:136` | `track_id` ← `model.trackId` |
| `lib/core/sync/codec/learning_ledger_codec.dart:66` | `track_id` ← `model.trackId` |
| `lib/core/sync/codec/completion_event_codec.dart:90` | `track_id` ← `model.trackId` |
| `lib/core/sync/codec/learner_profile_codec.dart:77` | `account_id` ← `model.accountId` — **the literal MCF-11 "Bug 1" field** |
| `lib/core/sync/codec/tutor_grant_codec.dart:86` | `child_profile_id` ← `model.childProfileId` |

(Every codec also embeds `profile_id` ← `model.profileId`, ~13 of 14 files
— out of the trigger-key set per the scoping note above, but worth naming
here for completeness: it is the single most pervasive instance of the
pattern in the codebase.)

### Category B — real, live, outside codec/merge entirely (17 sites)

These are genuine production push paths, confirmed live by reading each
call site, that independently embed a raw autoincrement id — the same
MCF-4 family, just living in feature code instead of `lib/core/sync/codec/`:

| Site | Notes |
|---|---|
| `lib/core/database/daos/track_dao.dart:322` (`archiveTrack`) | "I-5: push the archive to Firestore" — `jsonEncode({'track_id': trackId, ...})` fed to the outbox |
| `lib/core/database/daos/track_dao.dart:587` | same shape, a third `TrackDao` outbox-enqueue site (soft-delete path, line 271 area) |
| `lib/features/gamification/domain/models/reward_milestone.dart:44,97` | `toJson()`; doc comment: "Real curriculum tracks use positive DB ids... Synced in `reward_settings`" — confirmed cloud-bound |
| `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart:439` | `row.trackId` into an outbox-bound payload |
| `lib/features/scheduler/presentation/screens/study_day_config_screen.dart:319` | bare `trackId` under `track_id` |
| `lib/features/sync/data/outbox_sync_write_facade.dart:204,586` | `buildGamificationSnapshot()`'s `points_config` fan-out (the MCF-4/MCF-14/MCF-19 gamification-settings site) and a second push builder |
| `lib/features/tracks/domain/services/curriculum_activation_service.dart:241` | doc comment: "Sync this profile's tracks to Firestore" |
| `lib/features/tracks/setup/domain/services/track_creation_service.dart:364` | mirrors `_pushStudyDaysCloud` |
| `lib/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart:47,211` | `inviteTutor`/`listOutgoingGrants` Cloud Functions callable payloads |
| `lib/features/tutoring/data/routers/tutored_write_router.dart:177` | tutor-mode write-router track payload |
| `lib/features/tutoring/data/services/tutor_write_service.dart:152,166` | `upsertTrack`/`deleteTrack` CF callable payloads — **caveat:** `trackId` is typed `String` here, not `int`; likely already carries a curriculum-scoped stable key rather than the bare local int, but not verified back to its call site in this pass — flagged for the next person to confirm rather than silently dropped |
| `lib/features/tutoring/domain/models/tutor_grant.dart:154` | `TutorGrantDoc.toFirestore()` |

**Genuinely new discovery — the tutor-grant `childProfileId` chain.** Unlike
the codec sites, this one is not named anywhere in the existing migration
baseline doc. Tracing it end to end:

1. `lib/features/tutoring/presentation/screens/manage_tutors_screen.dart:293,298,312`
   — `childProfileId: profile.id.toString()` — the raw local
   `LearnerProfiles.id`, stringified.
2. → `InviteTutorRoute` / `tutor_invite_use_cases.dart` → `TutorGrantDoc`
   (`lib/features/tutoring/domain/models/tutor_grant.dart`, `childProfileId`
   declared `String`, not remapped).
3. → `firestore_tutor_grant_repository.dart:47` — `'childProfileId':
   childProfileId` in the `inviteTutor` Cloud Functions callable request
   (this is the detector's anchor point — see Category B table above).
4. → server-side Admin SDK write into the `tutor_grants` Firestore
   document's `child_profile_id` field, read back by
   `lib/core/sync/codec/tutor_grant_codec.dart` as an **`int`** — a type
   mismatch with step 2's `String` worth separately noting.

`tutor_grant_merger.dart` is a documented no-op ("grants read live from
Firestore" — safe/trivial precedent per the migration baseline), so this
never gets remapped through `lib/core/sync/merge/` at all. Blast radius:
on a device restore/re-registration the child profile is very likely to
reload with a **different** local `id`, silently orphaning any
pre-existing `tutor_grants` document that still names the old one — the
tutor's read access quietly loses its target with no error surfaced
anywhere. Recommend filing this as a follow-up finding for the tutoring
feature owner; out of this story's fix scope (sweep + gate only).

### Category C — confirmed dead code, still a residual landmine (1 site)

| Site | Notes |
|---|---|
| `lib/features/scheduler/domain/models/goal_entity.dart:182` (`GoalEntity.toFirestore()`) | Embeds `track_id` ← `trackId`. **Zero production call sites** — verified via `grep -rn "\.toFirestore()" lib/` (only `test/features/scheduler/domain/models/goal_entity_test.dart` and `test/features/tutoring/s2_entity_parity_test.dart` call it). The live push path is `lib/features/scheduler/data/repositories/goal_repository_impl.dart:247-275`, which routes through `GoalCodec.encode()` — its own comment names this "the Phase B unification: a single serializer." `toFirestore()` is a superseded hand-copied duplicate left in place, exercised only by tests. A residual landmine, not an active one: if ever re-wired as a push path (e.g. during a refactor that reaches for the seemingly-obvious `.toFirestore()` method on the entity itself), it silently reintroduces the raw id, bypassing the canonical codec — the exact "hand-copied second implementation" class the migration baseline separately warns about for the LWW predicate (AUD-t-cross-68). Deletion is out of this story's scope (sweep + gate, not remediation) but is a clean, low-risk follow-up. |

### Category D — false positives (13 sites; not synced Firestore payloads)

Matched textually (same key/value shape) but confirmed, by reading each
file, **not** a Firestore-bound payload:

| Site | Why it's not a landmine |
|---|---|
| `lib/features/settings/domain/services/data_export_import_service.dart` (12 occurrences: lines 202, 232, 259, 274, 286, 303, 319, 340, 365, 381, 406, 419) | The device-to-device **local JSON backup/export** feature (`ImportPreview`, `import_validation_exception.dart`). The exported file is never itself sent to Firestore — a restored device re-imports local Drift rows and normal sync (through the codec layer) takes over from there. |
| `lib/features/account/domain/services/pending_local_signup.dart:35` | `PendingLocalRegistration.toJson()` — a **local SharedPreferences** JSON blob for offline-signup bookkeeping. Its `accountId` field is declared `String` and is a different concept entirely from the `Accounts.id` int autoincrement (device-registry identifier, not the local DB row id). |

## The standing gate

`tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart`, wired into
`make audit` as check 100/100, closes the class going forward:

- **RATCHET, not a one-off audit** (AD-28's explicit requirement: "the
  MCF-11 landmine sweep becomes a standing grep gate — not a one-time
  audit"). Same shape as this repo's other `tool/check_*_ratchet.dart`
  checks (`check_r7_source_text_assertion_ratchet.dart`,
  `check_raw_color_literal_ratchet.dart`): the 39 sites above are the
  pinned baseline (`tool/mcf11_autoincrement_id_in_payload_baseline.txt`).
  **Any NEW site — anywhere outside `lib/core/sync/merge/` — fails `make
  audit` immediately.** The baseline only goes down, by routing a site
  through the canonical codec/remap layer or deleting dead code (e.g.
  Category C), never up.
- Enforced by a plain text/bracket-balance scan invoked from `make audit`
  — **grep only, never `custom_lint`** (AD-28; `dart run custom_lint` is
  documented non-functional in this repo and must not be read as a
  passing signal).
- Red-demo proof: `test/tool/check_mcf11_autoincrement_id_in_payload_ratchet_test.dart`
  plants a fixture reproducing the exact MCF-4 shape (a fresh `toFirestore()`
  embedding `track_id` ← `trackId`) on a path outside `merge/`, asserts the
  checker fails (`make audit`'s equivalent would fail), deletes the
  fixture, and asserts a clean pass again.

## Summary

| Category | Count | Action |
|---|---|---|
| A — core codec layer (documented, structural) | 8 | Pending AD-25 canonical-stable-key redesign (future story) |
| B — real, live, outside codec/merge | 17 | Pending AD-25; tutor-grant `childProfileId` chain is a genuinely new finding worth a dedicated follow-up |
| C — confirmed dead code | 1 | Low-risk cleanup candidate (delete `GoalEntity.toFirestore()`), out of this story's scope |
| D — false positives (not Firestore payloads) | 13 | No action; documented so a future re-run of the ratchet isn't re-litigated from scratch |
| **Total baseline** | **39** | Frozen by the standing gate — see above |
