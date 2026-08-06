# Firestore cutover plan

**Status:** Phase 0 ✅ · Phase 1 ✅ · **Phase 2 next** · Phases 3–5 pending
**Last updated:** 2026-08-06
**Head:** `a2a21d0a` on `dev` — `make audit` green (103 checks), 4 features on
Firestore, keying gate live.

**Verification cadence (owner decision, 2026-08-06):** `dart analyze` and the
keying gate run every stage (seconds); `make audit` runs at each phase
boundary (~9 min); full `make ci` is **batched to the end of Phase 4**
(~35 min). Rationale for keeping audit per-phase rather than batching it too:
Phase 1's own defect — a duplicate `main()` in the libraries-only
`test/helpers/` directory — was invisible to analyze and to the keying gate,
and `make audit` caught it in minutes while only one phase had changed.

This plan finishes the Drift→Firestore migration. It is written to be executed
by a future session with no memory of how we got here, so every claim below
carries its evidence and every phase carries its own exit gate.

---

## 1. Why this is one cutover, not a sequence of features

Measured 2026-08-03 by taking bookmarks — the smallest feature with real UI
consumers — end-to-end (commit `5b4d7924`).

The old sync engine writes `learner_profiles/{int}/…` for **14 collections**
(`FirestoreGatewayImpl._learnerProfileDoc`, which its own doc comment
identifies as the sole constructor of that path). Every Firestore repository
reads `learner_profiles/{ULID}/…`. **These are disjoint document trees.** A
feature flipped alone reads a tree nothing writes.

Observed cascade, in order:

1. Flipping bookmarks stranded track-creation, learning-order and tutoring.
2. Fixing the learning-order writer then stranded the scheduler's reader.

Each fix relocated the boundary rather than removing it. Features here do not
own their data: bookmarks is *written* by track-creation, *ordered* by
learning-order, *re-scoped* by tutoring, *read* by completion.

> **The migration unit is the int→ULID cut, not the feature.**

Cost of ignoring this: wiring 2 of ~15 adapters produced 6 regressions in 4
features nobody was touching, across 71 files.

### 1.1 Why the test suite did not catch any of it

`fake_cloud_firestore`'s rules companion cannot evaluate `resource.data` /
`request.resource`, and tests seed documents directly into whichever path the
test chooses. So a writer and reader disagreeing about the document tree
produces a **fully green suite**. During the bookmarks slice, 144 tests
passed — including six custom-order regression tests — over a branch that
could not execute in production at all.

This is the single most important fact in this document. Phase 1 exists to fix
it, and every later phase depends on Phase 1 landing first.

---

## 2. Anti-slop protocol — applies to every phase

These are not style preferences. Each one is here because its absence caused a
real defect during the bookmarks slice.

### 2.1 Gates

- **`make ci` is the only gate. `make audit` is a subset of it.** A Rule 5
  layering violation sat on `dev` for days while `make audit` reported
  102/102 clean, because that check runs only under `make ci`.
- **Read the lines above an exit-0, not just the exit code.** `make audit`'s
  R6d lcov check *soft-skips* when `coverage/lcov.info` is absent, printing
  "SKIPPED … this is not a failure of `make audit` alone" and still exiting 0.
  Only `make ci` generates coverage and enforces it.
- **Never gate a moving tree.** Wait for a genuine write-quiet window across
  `lib/` and `test/` before running a gate. A verdict collected while agents
  are still writing describes nothing.
- **Never run two `make ci` concurrently.**

### 2.2 Evidence

- **Reproduce, don't inherit.** Do not carry forward a number or a file:line
  citation from a report, a doc comment, or a previous session without
  re-deriving it. During the slice: a coordinator's "24 collections" was
  actually 24 call sites of one helper (the true count is 14), and an agent
  correctly refused to reuse it.
- **Doc comments on this project are load-bearing and go stale.** A stale
  comment claiming `last_reorder_at` was absent from the rules whitelist
  caused an agent to delete a live feature. Three of the four files carrying
  that claim had already been corrected; it read the fourth. **Verify a
  claim against current code before acting on it.**
- **A soft-skip is not a pass.** Report what ran, not what exited 0.

### 2.3 Changes

- **Red demo, always.** For every fix: revert the production change (by hand),
  confirm the test genuinely FAILS, capture that output verbatim, restore, and
  confirm with `git diff` that the tree is in the fixed state. An abandoned
  revert ships the regression it was meant to prove.
- **Never `git stash` in a shared tree.** A partial pop silently drops work;
  this has already cost changes on this project once. Edit back by hand.
- **Sequential edits on cross-referenced files.** Two agents on one file
  silently loses one of them. This project has been bitten.
- **Ratchets do not move without explicit approval.** When a baseline addition
  is genuinely correct (e.g. a zero-statement file that can never get an lcov
  `SF:` entry), **hand-edit** the baseline. Never run `--update-baseline`: it
  regenerates wholesale from the current coverage file and silently exempts
  genuinely-undertested files.
- **`dev` only.** No branches, no worktrees.
- **Verify a push by ahead-count**, not by exit code — a piped `tail` will
  happily report success next to an auth failure.

---

## 3. Phases

### Phase 0 — Decisions — **RESOLVED 2026-08-04 (owner)**

#### D1 (#31) — Tutor identity: re-file permissions under the ULID

**Decision:** the tutor reads the parent's tree directly, keyed by the child's
ULID everywhere — invite, grant record, `tutor_active_access` index, and all
17 CF validations. The local tutored mirror is deleted (already listed as a
deleted concept in `docs/firestore-rewrite-map.md`).

The rules formula does **not** change. `hasActiveTutorAccess` builds
`accessId = tutorUid + '_' + ownerUid + '_' + profileId` from the **path
segment** (`firestore.rules:87-91`) and `acceptInvite` writes the identical
formula (`functions/src/tutor_invites.ts:17`). Both are already
self-consistent — only the *value* of `profileId` changes from the Drift int
to the ULID. This is a value migration, not a redesign.

No live users, so no existing grants to migrate.

→ **Phase 2** owns this.

#### D2 (#32) — Overdue backlog: restore both forgiveness paths

**Decision:** both a user reorder and a content update clear overdue items.
Rationale: "overdue" is computed against a schedule, so changing the schedule
makes the old count meaningless; and a content update must not manufacture a
backlog nobody could have completed.

**Two paths, and they are NOT equal cost — this was under-stated when the
decision was put to the owner:**

- **Reorder forgiveness — cheap.** Write `last_reorder_at` on the track and
  move `daily_task_projection_service`'s read off Drift. The rules whitelist
  already permits the field (`firestore.rules:412`); it was added earlier in
  this migration. Falls out of the Phase 3 tracks migration.
- **Content-reseed forgiveness — needs a new mechanism.** The old detection
  used the Drift `learning_order.learningOrderVersion` column compared against
  the seed version. **There is no Firestore equivalent** — the `learning_order`
  rules whitelist is `curriculum_id, sefaria_ref, ref, user_sort_order,
  updated_at, synced_at`, with no version field. Restoring this requires
  either adding a version field to the collection (rules change) or detecting
  staleness another way. **Design this explicitly in Phase 3; do not assume
  it comes free with the stamp.**

→ **Phase 3** owns both.

#### D3 (#33) — Learning-order reset: narrow client-delete allowance

**Decision:** permit the owner to delete their own `learning_order` rows —
`allow delete: if isOwner(uid)`, exactly as `goals` already does.

Context for the exception: 19 of 20 collections currently say
`allow delete: if false`, with `goals` the sole precedent (opened earlier in
this migration to fix a delete-goal feature that had been built but was
silently rules-blocked). That blanket rule largely protects the **old sync
engine's** retry idempotency, which Phase 4 deletes. Learning order is user
settings, not a ledger — no audit or history reason to retain it.

Rejected: a Cloud Function (disproportionate — a cold start and round trip to
clear one's own settings) and a soft "custom order off" flag (changes the
"does a custom order exist" predicate that several call sites now depend on,
and leaves orphaned rows).

→ **Phase 2** owns the rules change (rules and the code writing through them
must land in the same commit).

**Exit:** ✅ all three resolved. Mirror these decisions into
`docs/firestore-rewrite-map.md` when Phase 2 starts.

---

### Phase 1 — Make the boundary detectable — **RESOLVED 2026-08-06** (`a2a21d0a`)

**This is the phase that makes the rest reliable. It is done; everything below
depends on it.**

**Shipped:**

- **`tool/check_profile_path_keying.dart`** — audit check 103. Classifies every
  writer and reader of all **17** profile-scoped collections (the planned
  figure of 14 was the count of collections on the int path specifically; 17 is
  the full set) as int- or ULID-keyed across `lib/` and `functions/src/`, and
  fails when a collection has both. Wired into **both** `make audit` and the
  `make ci` lane.
- **`tool/profile_path_keying_baseline.txt`** — exactly `bookmarks` and
  `learning_order`, the only two collections with a live split. Nothing was
  baselined to make anything pass.
- **A WATCHLIST** for the five dormant collections (`points_ledger`,
  `profile_programs`, `stage_definitions`, `streak_events`,
  `study_day_configs`), naming per collection exactly what wiring trips the
  gate — and what does **not** (intermediate factories, DI/service-locator
  lookups, torn-off constructor refs). Phase 3 gets warned before it creates a
  split, not after.
- **`test/helpers/writer_reader_agreement.dart`** — asserts a collection's
  production writer and reader resolve the same document, with the path coming
  from production code on **both** sides. Its own test
  (`test/writer_reader_agreement_helper_test.dart`) includes a deliberately
  mis-wired case, so the helper is proven non-vacuous.

**Deviation from plan, deliberate:** the gate ships **green**, not red. The
plan assumed it would be red on today's splits. It is not, because both live
splits are baselined — which is the same information expressed as "0 new
violations" rather than as a failure. The burn-down property is unchanged:
Phase 2/3 remove baseline entries, and any NEW split fails immediately.

**Verification found five defects, all fixed with reproductions** (see
`a2a21d0a`'s message for the full list). The one worth carrying forward:
reachability originally counted **doc comments and string literals** as
evidence, and *both* baseline entries were classified live on the strength of
a doc comment. They were live anyway — but the gate was right by luck. A
dormant repository merely discussed in prose would have hard-failed an empty
baseline.

**Known blind spots** are documented in the checker's own class doc comment
and restated in every watchlist line. A static check will always have them;
the requirement is that they are stated, because an unstated blind spot
manufactures exactly the false confidence this gate exists to remove.

---

### Phase 2 — Unify the identity (int → ULID)

Do this **before** wiring features, so features land on a stable identity
rather than being rewired twice.

Scope, all verified:

- **3 owner-path Cloud Functions** (`functions/src/deletes.ts`):
  `deleteLearnerProfile` (:135), `deleteCurriculumTrack` (:214),
  `deleteBulkMarkedCompletions` (:406) — each validates `profileId` as a
  positive integer and addresses `learner_profiles/{String(profileId)}`
  (:225, :441). Post-cutover they address a path with no data: **delete
  nothing, report success.** `deleteBulkMarkedCompletions` implements the
  owner's un-tick rule, so that feature would silently stop working. (#30)
- **17 CF int-validations**: 13 in `tutor_writes.ts`, 3 in `deletes.ts`,
  1 in `tutor_bulk_completions.ts`.
- **Tutoring identity** (#31, per the Phase 0 decision): grant creation
  (`profile.id.toString()`), `buildAccessId` / `tutor_active_access` keying,
  `TutoredWriteRouter`'s `int.tryParse`, and `ProfileDao.upsertTutoredProfile`
  minting no ULID.
- **Doc-id divergence**: `DocIds.bookmarkDocId` is bare `{curriculum_id}`
  while `TutoredWriteRouter.pushBookmark` computes
  `{curriculum_id}_{track_type}` — two writers, different documents, on a
  two-writer collection.
- **Hoist the tutored guard** into `_watchActiveAccountAndProfile` so all 13
  profile-scoped providers behave uniformly in one place, rather than
  replicating the bookmark guard 13 times.

**Exit:** Phase 1's check shows the identity split closed. `make ci` green.
Firestore rules and CF tests updated together — the rules and the CF that
writes through them must never be changed in separate commits.

---

### Phase 3 — Wire and move

7 adapters exist and are tested but are **never constructed**:
`FirestoreCompletionRepositoryAdapter`, `FirestoreCurriculumTrackRepositoryAdapter`,
`FirestoreGoalRepositoryAdapter`, `FirestoreProgressRepositoryAdapter`,
`FirestoreStageDefinitionRepositoryAdapter`,
`FirestoreStudyDayConfigRepositoryAdapter`,
`FirestoreTrackLearningOrderRepositoryAdapter`.

135 files import the Drift database or its DAOs. Net of `core/database` (25,
the Drift layer itself) and `core/sync` (14, deleted in Phase 4), that is
**~96 feature files** to move.

**Order by data dependency, not by feature convenience: writers before
readers.** For each collection:

1. Move every writer.
2. Move every reader.
3. Add the Phase 1 writer/reader agreement test.
4. Run `make ci`. Not `make audit`.

Known reader/writer pairs that must move together (learned the hard way):
track-creation → bookmarks; learning-order → bookmarks *and* the scheduler's
daily-task projection; completion → bookmarks.

**Exit:** zero files under `lib/features/**` import Drift. Phase 1's check
baseline is empty. `make ci` green.

---

### Phase 4 — Demolish

Delete, in one change:

| Target | Files | Lines |
|---|---|---|
| `lib/core/sync` | 62 | 12,819 |
| `lib/core/database/user` | 2 | 25,774 |
| `lib/core/database/daos` | 49 | 5,991 |
| `lib/core/database/tables` | 26 | 1,111 |
| `lib/core/database/views` | 1 | 34 |
| sync tests | 85 | — |

**≈45,700 lines.**

**Before deleting, re-verify #29:** `firestore.rules` enforces `is timestamp`
on three fields (`streak_events.created_at`,
`completions`/`learning_ledger.completed_at`, `points_ledger.created_at`).
Historically `FirestoreGatewayImpl._timestampifyField` converted the outbox's
ISO strings to real `Timestamp`s before the write landed. That gateway dies
here. As of 2026-08-03 the new repositories handle all three correctly, but
**`fake_cloud_firestore` cannot catch a regression** — it surfaces only as
permission-denied on a real device.

Also remove, **as pairs**: the Rule 5 allow-list entries for the Firestore
repositories alongside their Drift counterparts (noted in
`epic_25_story_25_9_lints_test.dart`), so the list shrinks rather than
accumulating exemptions for files that no longer exist.

**Exit:** `make ci` green. No `drift` import anywhere outside the content
database.

---

### Phase 5 — Retarget the gates and verify on a device

- **#23** — retarget enforcement gates to the new architecture. Many encode
  the old sync engine's invariants and will be checking rules about deleted
  code.
- **#24** — verify `resolve()` cold-start re-attach on a real device. Mock-only
  today, and it runs every launch. Specifically: the route guard clears the
  ULID when auto-selecting a single profile by bare int; it self-heals on the
  next frame via `ensureSelected()`, but whether anything can fire inside that
  window is **not statically determinable**.
- **#25** — add a gate rejecting non-text source files. A single NUL byte makes
  grep treat a file as binary, silently disabling all 102 audit checks on it.
  This has happened once already.

**Exit:** gates describe the architecture that exists; device verification
signed off.

---

## 4. Execution notes

- **Phases 0 and 1 were strictly sequential and strictly first.** ✅ Both done.
  Phase 1 is what converts this migration's characteristic failure — a silent
  data-tree split — from invisible into caught. Everything below now runs with
  that gate in place; do not disable or baseline around it.
- **Open work items live in
  [`firestore-cutover-tasks.md`](firestore-cutover-tasks.md)**, mapped to the
  phase that owns each one. Update it in the same commit as the work.
- **Agent recovery runs off
  [`firestore-cutover-log.md`](firestore-cutover-log.md)**. Sessions die
  mid-work — a session limit killed a workflow at 9/16 agents, and an interrupt
  stopped 48 more. Every agent brief MUST require reading that log first and
  following its recovery protocol; the coordinator appends an entry when a
  phase lands, when a session dies (recording what was in flight), and when a
  finding changes the plan.
- Phase 2 is one unit; identity cannot be half-migrated.
- Phase 3 parallelises *by collection*, but only after Phase 1 exists to
  catch the mistakes that parallelism causes.
- Phase 4 is one commit.
- **Anything that cannot be verified statically goes on the device list, not
  into a claim.** Say which gate ran.
