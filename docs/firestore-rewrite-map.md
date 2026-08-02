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

**RESOLVED — owner decision, 2026-08-02.** *"app is able to delete just bulk marked
learning linked to a track which will remove their global learnt status as well —
deleting is only possible for bulk marked track learning and that's it."*

- A completion with `source == 'bulkInTrack'` may be deleted (the onboarding un-tick).
- A completion with `source == 'live'` is **permanent**. There is no undo for genuinely
  learned material — a mis-tap cannot be corrected. This follows from the once-per-track
  invariant and is intended.
- Deleting a bulk mark **also deletes its `learning_ledger` entry**, retracting the
  lifetime "learnt" status, not just the track one.

**Implementation: a Cloud Function, not a rules relaxation.** Both `completions` and
`learning_ledger` are SR-1 append-only (`allow delete: if false`). Rather than punch the
first delete hole into append-only history — which a client could widen by writing
`source: 'bulkInTrack'` onto a live completion and then deleting it — this routes
server-side through the Admin SDK, matching `deleteLearnerProfile`,
`deleteCurriculumTrack` and `tutorResetCompletion`. The rules stay fully closed and the
client repository gets **no delete method at all**.

Note the distinction from track deletion: deleting a *track* must NOT touch
`learning_ledger` (lifetime history deliberately survives). Deleting a *bulk mark* must.

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

## Where shared utilities may live (AD-23 constraint, learned the hard way)

`tool/check_dependency_direction.dart` (audit check 102, **hard gate, zero tolerance**)
forbids any `lib/features/**` or `lib/domain/**` file from importing
`package:learning_tracker/data/firestore/...` unless its path contains the segment
`/data/repositories/`.

Consequence: **any shared Firestore-adjacent utility that a DOMAIN MODEL calls directly
must live outside `lib/data/firestore/`.** `lib/data/firestore/` is reserved for the
repository layer. This is why `FirestoreCodec` — a pure date/number coercion helper with
no Firebase dependency — sits at `lib/core/codec/firestore_codec.dart` and not in the
Firestore ring: `stage_definition.dart` is a domain model under `lib/features/`, and it
calls the codec directly under the "entity owns its codec" pattern.

Note the two import gates have **different** path semantics, which is easy to get
backwards: the Firebase-confinement gate (check 2) matches a path **prefix**
(`lib/data/repositories/`), while the dependency-direction gate (check 102) matches a
path **segment** (`/data/repositories/`).

**Also:** there are two Makefiles. Always run `make audit` from `learning_tracker/`, not
the repo root — the root one runs different checks and will report unrelated
pre-existing debt as a false alarm.

## Traps found while building the repositories (each cost a real debugging cycle)

None of these are caught by the analyzer, the tests, or a green `make audit`. Several
pass locally and fail only in production; one passes forever while doing nothing.

1. **`orderBy` on a nullable field silently DROPS documents.** Firestore omits documents
   that lack the ordered field entirely — no error. The Drift `goals` query ordered by
   `target_date`, which is null for pace-type goals; a literal port made every pace goal
   invisible. Sort client-side when the field is optional.
2. **ISO strings fail `is timestamp` rules.** `FirestoreCodec.encodeDateTime` emits an
   ISO-8601 String, but SR-3 guards on `streak_events`, `learning_ledger` and
   `points_ledger` require a real `timestamp`, and `completions` compares
   `completed_at <= request.time` — a type mismatch in rules evaluates to **deny**. So a
   String there rules-denies **every write** in production. Write a raw `DateTime`.
   Also: `Timestamp.toDate()` returns **local** time, not UTC — normalize on read.
3. **`SetOptions(merge: true)` leaves stale keys.** Omitting a key does not clear it. When
   a field goes from set to null, send `FieldValue.delete()` explicitly, or the old value
   silently survives.
4. **A raw NUL byte in source disables every grep gate on that file.** grep classifies the
   file as binary and skips it, while audit still reports a pass. Use an escape sequence,
   never a literal control byte. (A gate that stops applying looks identical to a gate
   that passes.)
5. **Doc comments trip greps.** Audit check 6/15 greps for the literal `DateTime.now()`
   and does not exclude comments — prose warning against it fails the gate.
6. **New `lib/` files need a MIRRORED test** at the matching `test/` path (audit check
   29/40, AG-5) — a repository test does not satisfy it for a separate model file. New
   `lib/` files also need real coverage or the lcov-denominator gate fails.
7. **Hand-rolled doc-ids collide.** Free-text key components can contain the separator —
   always use `DocIds` with `encodeKeyComponent`.
   **Pre-existing exception worth fixing:** `DocIds.learningOrderDocId` is the only formula
   that does NOT route its components through `encodeKeyComponent` — it mirrors the live
   gateway's `'${curriculumId}_$ref'` byte-for-byte. A `sefariaRef` containing a literal
   `_` can therefore collide. The byte-for-byte continuity requirement that justified it no
   longer applies (greenfield, no back-compat), so this should be encoded like every other
   formula.
8. **Check whether a collection is keyed by doc-id or by a field** before writing a query.
   `profile_programs` is keyed by doc-id; a `where('curriculum_id', …)` sweep matches
   nothing, deletes nothing, and reports success.
9a. **`completions` doc-id does NOT include `trackType`**, despite `firestore.rules`'
   own comment claiming a 5-component natural key. The code
   (`DocIds.completionDocId`) joins only `profileId/sefariaRef/stageId/curriculumId`.
   Two completions differing ONLY by `trackType` for the same item+stage therefore
   collide onto one document, and the second write is rules-denied as a non-identical
   SR-1 replay. Probably unreachable in practice (one track per curriculum per profile),
   but pinned by a `DOCUMENTED COLLISION` test in
   `firestore_completion_repository_test.dart`. Decide deliberately before relying on
   multi-track-type completion of the same item.

9b. **`DocIds.completionDocId` takes a Drift-era `int` profileId** and cannot be called
   from a repository keyed by the AD-24 ULID `String`. Needs a `String` variant so the
   "doc-ids always come from `DocIds`" rule holds without a lossy conversion.

9. **`fake_cloud_firestore` quirks:**
   A single `.where(field, isGreaterThanOrEqualTo: a, isLessThanOrEqualTo: b)` silently
   DROPS one bound (verified by standalone repro — a document past the upper bound came
   back). Split into two chained `.where()` calls, which is what production Firestore
   expects anyway. `orderBy(FieldPath.documentId) + startAfter([id])`
   throws — use `startAfterDocument(snapshot)`; `.limit()` must be chained AFTER the
   cursor or page 2 comes back empty; a `WriteBatch` arrives as several incremental
   snapshots rather than one atomic update; and `strictRules: true` denies even the
   legitimate owner's writes, so **no positive rules test is possible** — rules
   correctness rests on reading the rules text.

## OPEN: schema fields that exist in Drift but have no Firestore home

Adding a field that is absent from a collection's `.hasOnly()` whitelist does not merely
drop the field — it **permission-denies the entire write**. So each of these needs a
`firestore.rules` change (mirrored in the matching `ALLOWED_FIELDS` list in
`functions/src/tutor_writes.ts`, which the rules whitelists are kept identical to) before
the feature can be ported.

- **Track-level learning order has NO Firestore home at all, and the feature dies without
  one.** `TrackLearningOrder` (reordering sedarim/masechtos *within* a track) is Drift-only
  today — never synced, no gateway push, no rules block. It cannot share the
  `learning_order` collection: `DocIds.learningOrderDocId` is `{curriculumId}_{ref}` with
  nowhere for a track key (AD-25 retired the Drift-local `trackId`), the rules
  `hasOnly(['curriculum_id','sefaria_ref','ref','user_sort_order','updated_at','synced_at'])`
  forbids writing any discriminator, and both orderings draw from the **same `sefariaRef`
  universe** — so they compute identical doc-ids and silently clobber one another
  (red-demo in `firestore_learning_order_repository_test.dart`, group "doc-id collision").
  Since the Drift user database is being deleted, this needs its own collection
  (`track_learning_order` under the profile) with its own rules block — preferred, because
  it is purely additive and cannot destabilise the working curriculum-order path — or the
  feature is lost.
- **`learning_order` has no reset path.** Drift's `resetToDefault` deletes all rows to fall
  back to natural order; rules deny delete on `learning_order` unconditionally, and unlike
  `stage_definitions` there is no fixed doc-id universe to overwrite in place (a custom
  order can be an arbitrary subset). Needs either a soft-delete marker in the whitelist or
  a server-side reset. Currently throws `UnimplementedError`.
- **`learning_order.learning_order_version`** — the content-seed staleness marker. Absent
  from the whitelist; its Drift side effect was local bookkeeping only.
- **`curriculum_tracks.last_reorder_at`** — the reorder-amnesty baseline
  (`TrackDao.stampReorderAt`). Absent from both whitelists. The repository method was
  dropped rather than smuggling the timestamp into an unrelated field; the feature is
  non-functional until the field is added.

Also note `curriculum_tracks` carries five fields that are whitelisted but have **no
producer or consumer anywhere in the repo**: `progress_schema_version`,
`progress_computed_at`, `progress_model`, `program_progress`, `self_paced_progress`.
They are preserved as decode-only round-trip fields rather than having a schema invented
for them.

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
