# Firestore cutover plan

**Status:** Phase 0 ✅ · Phase 1 ✅ · **Phase 2 — NOT RESOLVED. `T-49` (the
phase's sole BLOCKING code defect, P2-23) and its two sibling findings
`T-56`/`T-57` (P2-24, both pre-existing, both unrecorded until P2-22) are
ALL now CLOSED.** Phase 3 remains explicitly BLOCKED, now only on `T-39`
and two outstanding independent reviews (of `bb704e07`/P2-23 and of this
round's own commit/P2-24) — see `firestore-cutover-log.md`'s **P2-24**
entry, "Phase 3 ENTRY CRITERIA," for the exact checklist. **This paragraph was
found materially false at P2-22 and is corrected here, in this document,
not only in `firestore-cutover-log.md`/`firestore-cutover-tasks.md` (the
same "docs-only fix left one of three durable documents stale" defect this
project has already named twice for other claims — see
`firestore-cutover-log.md`'s standing facts).** It previously said "Three
tasks now gate Phase 3 entry: `T-49` … `T-50` … and `T-51`" when all three
had been closed or ruled by P2-20, and that `T-47` still had "6 named red
tests" open when it had been `+425`, 0 red, since P2-19 — both stale by
several rounds, with no task id and no warning anywhere in this document
that it was stale. **The current, true state:** P2-13 reopened Phase 2
(below, kept as history) after a second-pass adversarial review found
P2-12's `Phase 2 ✅` false on its own terms: `T-40`'s fix (P2-8) never
fired on any cold-start path, and a second BLOCKING defect (`T-43`)
survived inside the offline-first fix P2-8 also shipped. **P2-14 fixed
both**, proven with a wiring test shown RED against the pre-fix code and
GREEN after. **P2-15 fixed `T-48`** (the `created_at` clobber) by deleting
the read it depended on. **P2-16 independently re-verified both** and
declared Phase 2 ✅. **P2-17 superseded that declaration**, applying this
project's own DECISION RULE to a review run fresh against P2-16's HEAD
that found 4 unrecorded gaps and one new SERIOUS defect (`T-49`). **P2-18
fixed `T-49`… incompletely** — it closed only one of `_ensureFirestoreProfile`'s
three callers (`ensureRemoteProfile`), on a reachability justification
("no later selection to race" for the other two) that was never tested
and turned out to be false. **P2-20 closed `T-50` (in code) and `T-51`
(CARRIED-BY-RULING)** — both genuinely resolved, unaffected by what
follows. **P2-21 ran the full CI suite for the first time this phase and
closed two further Phase-2-attributable failures** (`T-53`, `T-54`).
**P2-22 — a fourth-round independent review, run against `bb97707e` —
REOPENED `T-49`**, reproducing the `createProfile`/`ensureDefaultProfile`
clobber BY EXECUTION (a probe: `Expected: 'ulid-probe-profile-b' / Actual:
'ulid-probe-profile-c'`), and recorded three further findings with task
ids (`T-56`, `T-57`, `T-58`), all MINOR, none individually blocking.
**P2-23 verified the reopening by execution, applied the identified fix
(activate before the Firestore write, for all three callers), and made
the proof permanent** — `test/features/profiles/data/repositories/profile_repository_impl_t49_activation_ordering_test.dart`,
RED before / GREEN after / RED again on a byte-exact revert / restored
and md5-verified — closing `T-49` for real. **The DECISION RULE, applied
mechanically: Phase 2 is still NOT RESOLVED — but its only BLOCKING code
defect is closed. Phase 3 remains explicitly BLOCKED, now only on `T-39`
(pre-existing, unaffected) and a fresh independent review of P2-23's own
commit (not self-certified).** `T-40` and `T-43` — the plan's own
**original** stated exit criterion — remain fixed and independently
verified; nothing above disputes that, and `T-50`–`T-54` remain
closed/ruled, also undisturbed.
Full detail: `firestore-cutover-log.md`'s **P2-14** through **P2-24**
entries, and `firestore-cutover-tasks.md`'s `T-40`–`T-58` rows. **This
section's narrative below (commit list, blocked framing) predates P2-8
through P2-23 and is not rewritten here — treat the log entries above as
authoritative over this paragraph's prose; only the status line, Head
field, and the Phase 2 section header/summary immediately below §3 are
corrected, at each closing commit — that convention itself is why this
paragraph went three rounds stale, and is worth a future round's attention
(no task id assigned; noting it here so the next stale-status discovery
does not read as a new phenomenon).**
**P2-24 addendum (does not restate the P2-23 paragraph above, which
stands unedited):** `T-56` and `T-57` — the two sibling
provider-clobber defects `T-49`'s own P2-22 reopening review found next
to it, both pre-existing (predate Phase 2), both left `todo` through
P2-23 — are now `done` (P2-24). See the Phase 2 section header/summary
immediately below §3 for the fix shape and evidence pointer.
**Last updated:** 2026-08-07 (P2-24; status line, Head field, the Phase 2
section header/summary corrected — the verification-cadence paragraph
needed no further change, re-verified accurate)
**Head:** commit SHA not yet knowable — same self-reference lag as every
prior closing commit; the true immediate parent is `bb704e07` (P2-23's
own commit, closing `T-49`). This commit (P2-24) fixes `T-56`/`T-57` in
`lib/features/profiles/presentation/providers/profile_providers.dart`
and `lib/features/profiles/presentation/widgets/add_profile_dialog.dart`
— `make audit` green (104 checks, run from `learning_tracker/`), 4
features on Firestore, both keying gates (103, 104) live and unchanged,
`T-40`/`T-43`/`T-49`/`T-56`/`T-57` all fixed and independently
re-verified or verified-then-fixed on their own closing round, **Phase 2
closure blocked only on `T-39` and two outstanding independent
reviews.**

**Verification cadence (owner decision, 2026-08-06):** `dart analyze` and the
keying gate run every stage (seconds); `make audit` runs at each phase
boundary (~9 min); full `make ci` is **batched to the end of Phase 4**
(~35 min). Rationale for keeping audit per-phase rather than batching it too:
Phase 1's own defect — a duplicate `main()` in the libraries-only
`test/helpers/` directory — was invisible to analyze and to the keying gate,
and `make audit` caught it in minutes while only one phase had changed.
**`make audit` above means `learning_tracker/Makefile`'s target,
run from inside `learning_tracker/` — never the repo root.** The repo-root
`Makefile` defines a different, unrelated `audit` target (found P2-17,
`T-52`, `firestore-cutover-log.md`'s P2-17 entry) that fails on this tree
independently of anything this cutover has touched; a cold agent running
`make audit` from `/home/daniel/repos/learning-tracker` gets a red gate
that has nothing to do with Phase 2.

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

### Phase 2 — Unify the identity (int → ULID) — **NOT RESOLVED. `T-49`, `T-56`, `T-57` are ALL CLOSED (P2-23/P2-24). Phase 3 blocked only on `T-39` + two outstanding independent reviews.**

**P2-24 supersedes the P2-23 paragraph immediately below (kept as
history, not rewritten) — without disputing what it correctly found.**
`T-49`'s closure stands, unaffected. P2-24 re-verified `T-56` and `T-57`
— the two sibling provider-clobber defects P2-22's review found next to
`T-49` — BY EXECUTION on the post-P2-23 tree (a permanent test per
defect, RED before / GREEN after / RED again on a byte-exact revert /
restored and md5-verified, for each) and closed both. `T-56`:
`AutoSelectedProfileId._resolveSelection`'s "already selected" branch now
re-checks `selectedProfileIdProvider` after its await, mirroring the
sibling guard 43 lines below it that already had one. `T-57`:
`add_profile_dialog.dart` now calls `select()` unconditionally on profile
creation — matching every other creation call site (onboarding, the
zero-profile self-heal) and the repo's own unconditional activation
(T-49, P2-23) — instead of only for child profiles; only the follow-up
Parent PIN prompt stays child-only. **`T-56` and `T-57` are now `done`
(P2-24).** Full mechanism, both fixes, both proofs, both revert-proofs:
`firestore-cutover-log.md`'s **P2-24** entry and
`firestore-cutover-tasks.md`'s `T-56`/`T-57` rows. `T-58` — recorded by
the same P2-22 review — is unaffected by either fix and remains open,
MINOR, non-blocking. **Phase 3 ENTRY CRITERIA now gates on `T-39`
(pre-existing) and a fresh independent review of BOTH `bb704e07` (P2-23)
and this round's own commit (P2-24) — neither self-certified.**

---

**Historical record, P2-23 (2026-08-07) — kept verbatim below, not
rewritten, superseded by P2-24 above for `T-56`/`T-57`'s disposition
only — `T-49`'s closure described below is unaffected and stands.**

**P2-23 supersedes the P2-22 paragraph immediately below (kept as
history, not rewritten) — without disputing what it correctly found.**
P2-22's reopening of `T-49` was real and reproduced by execution; its fix
identification (hoist the activation write above the Firestore write, for
the `createProfile`/`ensureDefaultProfile` paths) was correct. **P2-23
re-verified the reopening by execution first** — re-ran the identical
probe shape as a new, permanent file on the unfixed tree and got the same
RED failure signature — **then applied exactly the identified fix**:
`_ensureFirestoreProfile` no longer takes P2-18's `required bool
activateProvider` parameter at all; `createProfile`/`ensureDefaultProfile`
now go through a new `_activateThenEnsureFirestoreProfile`, which
activates `activeProfileDocIdProvider` BEFORE resolving/attempting the
Firestore write, not after it settles; `ensureRemoteProfile` is unchanged
(still never activates, P2-18's real fix). **Proof, permanent, all three
callers in one file:**
`test/features/profiles/data/repositories/profile_repository_impl_t49_activation_ordering_test.dart`
— RED on the unfixed tree (both previously-open callers), GREEN after the
fix (`+3`), proved real by a byte-exact `cp` revert (never `git stash`) —
RED again, restored, md5-verified identical. `flutter test
test/features/profiles/` → `+428: All tests passed!` (425 baseline + 3
new). **`T-49` is now `done` (P2-23).** Full mechanism, the probe, the
fix, and every gate/test run: `firestore-cutover-log.md`'s **P2-23** entry
and `firestore-cutover-tasks.md`'s `T-49` row. `T-56`, `T-57`, `T-58` —
recorded by the same P2-22 review, below — are unaffected by this fix and
remain open, MINOR, non-blocking. **Phase 3 ENTRY CRITERIA now gates only
on `T-39` (pre-existing) and a fresh independent review of P2-23's own
commit — not self-certified.**

---

**Historical record, P2-22 (2026-08-07) — kept verbatim below, not
rewritten, superseded by P2-23 above for `T-49`'s disposition only —
`T-56`/`T-57`/`T-58` as described below remain open, unaffected.**

**P2-22 supersedes the P2-17 paragraph immediately below (kept as history,
not rewritten) — without disputing what it correctly found.** `T-50`
(MINOR, the `repository_providers.dart` doc comment) and `T-51` (the v38
migration, needing a ruling) were both genuinely resolved at P2-20 — fixed
in code and CARRIED-BY-RULING respectively — and `T-52` stayed closed
since P2-17. **`T-49` did NOT stay closed.** P2-18 (2026-08-07) fixed
`_ensureFirestoreProfile`'s race for exactly one of its three callers
(`ensureRemoteProfile`) and recorded the task `done`, reasoning from
reading that the other two callers (`createProfile`/`ensureDefaultProfile`)
were safe because they are "direct, awaited calls with no later selection
to race." **A fourth-round independent review (P2-22, run against
`bb97707e`) found that reasoning false and REPRODUCED THE CLOBBER BY
EXECUTION**, not by re-reading the same code: a probe mirroring P2-18's
own proof test but driving `createProfile` instead went RED —
`Expected: 'ulid-probe-profile-b' / Actual: 'ulid-probe-profile-c'` — the
exact clobber `T-49` was opened to describe, reachable through the sibling
call path P2-18 left open (`createProfile`/`ensureDefaultProfile` both
still pass `activateProvider: true`). **`T-49` is reopened, `blocked`, and
is now the phase's sole BLOCKING code defect** — full mechanism, the
probe, and the fix identified for a future code-touching round:
`firestore-cutover-log.md`'s **P2-22** entry and
`firestore-cutover-tasks.md`'s `T-49` row. The same review recorded three
further findings with task ids, none individually blocking: `T-56` (a
second unguarded post-await write to `activeProfileDocIdProvider`, in
`AutoSelectedProfileId._resolveSelection`), `T-57` (adult-profile creation
deterministically mis-keys all 13 profile-scoped Firestore providers —
pre-existing, predates this cutover), and `T-58` (a pre-existing, not
Phase-2-attributable red test in the `make test-serial-tools` lane,
previously undertracked). **Phase 3 ENTRY CRITERIA now gates on `T-49`
(reopened), `T-39` (pre-existing), and a fresh independent review of the
commit that finally closes `T-49` for real.** `T-53` and `T-54` (closed at
P2-21, the first round to run the full CI suite to completion this phase)
are unaffected by any of the above.

---

**Historical record, P2-17 (2026-08-07) — kept verbatim below, not
rewritten, superseded by P2-22 above for `T-49`'s disposition only —
`T-50`/`T-51`/`T-52` as described below were correctly resolved and are
NOT reopened by anything above.**

**P2-17 supersedes the P2-16 `RESOLVED` declaration immediately below
(kept as history, not rewritten) — without disputing what P2-16 actually
verified.** `T-40` and `T-43`, the plan's own **original** named blocking
exit criterion, are still fixed and still independently re-verified;
nothing here reopens either. What changed: a further independent review,
run fresh against P2-16's own HEAD (`2c762abc`) rather than trusting
P2-16's account of itself, applied this project's own DECISION RULE (a
disjunction over verdict / `safe_for_phase_3` / `still_open_unrecorded` /
new-BLOCKING-defect, checked mechanically, no carve-out for "minor") and
found it fails: the review's `still_open_unrecorded` list was non-empty (4
items) even though its overall verdict read `"resolved-with-deviations"`
and `safe_for_phase_3: true`. Three tasks now gate Phase 3 entry — full
checklist in `firestore-cutover-log.md`'s **P2-17** entry, "Phase 3 ENTRY
CRITERIA":

- **`T-49` (SERIOUS, new)** — `FirestoreProfileRepositoryAdapter
  ._ensureFirestoreProfile` writes `activeProfileDocIdProvider`
  unconditionally after an unbounded Firestore write, with no check the
  healed profile is still the one selected; P2-14 changed this dispatch
  from once-per-creation to once-per-activation, multiplying the exposure.
  Traced, not reproduced — `fake_cloud_firestore` has no offline model.
- **`T-50` (MINOR)** — `lib/data/firestore/repository_providers.dart:203-211`'s
  doc comment still states the exact production overclaim P2-16 corrected;
  P2-16 touched 3 planning `.md` files only, never the code the claim
  actually lives in.
- **`T-51` (needs an explicit owner ruling)** — `user_database.dart`'s v38
  schema migration materialises `ulid IS NULL` on every in-place app
  upgrade from v26..v37, with no backfill; `ProfileModel.fromDriftRow`
  then hard-throws. The greenfield ruling (R3, `firestore-phase2-plan.md:301`)
  was written about seeded dev data; nothing in the record confirms it was
  meant to cover every existing install's upgrade path.

A fourth item the same review found, `T-52` (`make audit` naming two
different gates depending on working directory — the repo-root Makefile
has its own, unrelated, currently-failing `audit` target), was fixable
docs-only and is **closed** by P2-17 in the same commit — see this file's
own verification-cadence paragraph, above, and the Recovery Protocol's
step 4. `T-44`–`T-46` (MINOR) and `T-47` (`blocked`, 6 named
inherited-P2-3 red tests) remain open, unchanged, and are explicitly
**not** new Phase 3 blockers. Full evidence:
`firestore-cutover-log.md`'s **P2-17** entry.

---

**Historical record, P2-16 (2026-08-07) — kept verbatim, not rewritten,
superseded by P2-17 above.**

**P2-16 supersedes the P2-13 reopening below (kept as history, not
rewritten).** `T-40` and `T-43` — the plan's own named blocking exit
criterion — were fixed at P2-14 and are now **independently
re-verified**: a separate pass (not the agent who shipped the fix) traced
all three production activation paths call-site to call-site into the one
`SelectedProfileId.select()` seam, personally reproduced the wiring test's
RED-before/GREEN-after toggle (md5-verified restore of
`profile_providers.dart`, not trusted from any report), and independently
re-ran the directory-level test suite. `T-48` (the `created_at` clobber)
was fixed at P2-15 by deleting the Firestore read it depended on,
independently re-derived at P2-16 by reading the current code directly.
**This is the first Phase 2 resolution backed by independent
re-verification rather than self-certification by the same round that
shipped the fix** — the specific gap that made the P2-8 and P2-12
"resolved" declarations false. Two documentation defects survived
P2-14/P2-15 and are corrected at P2-16, with no code change: the
inherited-red-test count was 5, not the actual 6
(`profile_picker_deep_l1_test.dart`'s F4, surfaced only by running
`test/features/profiles/` as a directory instead of a hand-picked file
list); and `T-43`'s claim that 12 sibling providers in
`repository_providers.dart` share a live production risk was false — the
app's only `ProviderContainer` (`bootstrap.dart:68-81`) already disables
Riverpod's default auto-retry container-wide, so the shared shape is a
test-harness-only concern. `T-44`–`T-46` (MINOR) and `T-47` (`blocked`, 6
named inherited-P2-3 red tests) remain open, explicitly outside this
phase's stated blocking criterion, carried forward as named tasks — not
silently dropped, not treated as blocking Phase 3. Full evidence:
`firestore-cutover-log.md`'s **P2-14**, **P2-15**, and **P2-16** entries.

---

**Historical record, P2-13 (2026-08-07) — kept verbatim, not rewritten.**
**P2-12's "RESOLVED" marking (2026-08-07) is corrected by this same-date
entry: a second-pass adversarial review re-verified the tree at `c06d942a`
directly and found it false.** `T-40` (BLOCKING DEFECT 1, below) was
believed fixed at P2-8 (`8dea756b`) and `T-41` (BLOCKING DEFECT 2) at P2-9
(`ed42c894`); every other finding this phase's reviews raised was triaged
by P2-10/P2-11/P2-12. **`T-41` and 15 of `T-42`'s 16 triaged items are
independently reconfirmed and stand — this reopening is narrower than the
original P2-7 finding, not a full regression to it.** What does not stand:
`T-40`'s fix is real code that is wired to a trigger which cannot fire on
any cold-start path (the exact scenario it exists for), and P2-8's
offline-first fix shipped its own new test RED (a 2-minute timeout, not a
pass) — tracked as new `T-43`. Full disposition table, evidence, and the
D1–D19 deferred-verification table: `firestore-cutover-log.md`'s **P2-13**
entry. The narrative immediately below describes the state as of the
original end-of-phase review (P2-7) and is kept as the historical record,
not rewritten. The full execution plan is
[`firestore-phase2-plan.md`](firestore-phase2-plan.md); six code commits
(`4877c7ef`, `0d5d9125`, `feefe34b`, `b398bea5`, `30790fef`, `2e85b097`)
landed the profile ULID as an eagerly-minted, compile-enforced,
non-nullable identity at the source, plus audit check 104
(`PROFILE-ID-INT-SITES`), plus three identity-adjacent fixes (T-33, T-34,
T-35 — see `firestore-cutover-tasks.md`'s Done table). **An end-of-phase
review then found two BLOCKING defects that no gate this phase runs can
see** — full detail in `firestore-cutover-log.md`'s P2-7 entry:

1. The replacement for the deleted lazy ULID backfill only fires at profile
   **creation**, never at **activation** — a profile created offline
   permanently never gets a remote document. Tracked as `T-40`.
2. Two live paths (`ProfileDao.upsertFromSync`, `DataExportImportService`)
   still insert `learner_profiles` rows with `ulid IS NULL`, and the new
   compile-enforced non-nullable `ProfileModel.ulid` now hard-crashes on
   exactly that shape. Tracked as `T-41`.

**Phase 3 does not start until both are fixed and re-verified.** `T-41` was,
at P2-9 (`ed42c894`), and stands. `T-40` was believed fixed at P2-8
(`8dea756b`) but the fix does not reach a live trigger — see the reopened
status line above and `firestore-cutover-tasks.md`'s `T-40` row. **A third
BLOCKING defect (`T-43`, new) was found inside P2-8's own offline-first
fix.** Phase 3 may **not** start until `T-40` and `T-43` are both fixed and
independently re-verified by a passing test that exercises the real
trigger, not a code trace.

**Why the original exit line below was unachievable, replaced by §6 of
`firestore-phase2-plan.md`'s verification table:** Phase 1's check
(103, `check_profile_path_keying.dart`) classifies INT writers by **file
location** (`lib/core/sync/**`, `functions/src/**`), not by keying — it
cannot register Phase 2 or Phase 3 progress until those directories are
deleted wholesale in Phase 4, and it has no concept of `learner_profiles`
itself or a doc-id formula. It was never going to "show the identity split
closed" as a Phase 2 exit criterion; check 104 (built this phase, P2-1)
covers what 103 structurally cannot, at the granularity a named-entry
ratchet can offer. Separately, `make ci` green was never a realistic Phase 2
exit gate — it is batched to the end of Phase 4 by owner decision
(2026-08-06, `firestore-cutover-log.md`), and Phase 2's own gates are
`dart analyze`, both keying checks, and `make audit` only.

**Original scope, retained for history (T-30/T-31 — the owner-path CF
deletes and tutoring's identity — moved to Phase 3 below, per Q1's ruling in
`firestore-phase2-plan.md` §3):**

- **Doc-id divergence** (T-34): `DocIds.bookmarkDocId` is bare
  `{curriculum_id}` while `TutoredWriteRouter.pushBookmark` computed
  `{curriculum_id}_{track_type}` — two writers, different documents, on a
  two-writer collection. **Resolved by deletion, not reconciliation** — the
  divergent writer was unreachable from production.
- **Hoist the tutored guard** (T-35) into `_watchActiveAccountAndProfile` so
  all 13 profile-scoped providers behave uniformly in one place, rather than
  replicating the bookmark guard 13 times. **Done**, with a corrected
  observable for its device check — see the log's P2-7 entry.

---

### Phase 3 — Wire and move

**Moved here from Phase 2, per Q1's ruling (`firestore-phase2-plan.md` §3,
2026-08-06) — landing with T-20 as one commit-unit, not before it, since the
coupling evidence below is why they were re-phased in the first place:**

- **T-30 — 3 owner-path Cloud Functions** (`functions/src/deletes.ts`):
  `deleteLearnerProfile` (:135), `deleteCurriculumTrack` (:214),
  `deleteBulkMarkedCompletions` (:406) — each validates `profileId` as a
  positive integer and addresses `learner_profiles/{String(profileId)}`
  (:225, :441). Post-cutover they address a path with no data: **delete
  nothing, report success.** `deleteBulkMarkedCompletions` implements the
  owner's un-tick rule, so that feature would silently stop working. Capture
  the profile's ULID before the local delete removes the row — see
  `firestore-cutover-tasks.md`'s T-30 entry for the exact ordering trap.
- **T-31 — tutoring identity is Drift-int end-to-end.** Owner decision D1
  (2026-08-04): re-file under the ULID; tutor reads the parent's tree
  directly; the local mirror dies. **Coupling evidence (why this could not
  land in Phase 2):** `TutoredProfileSelection.profileId` is a live
  Firestore path segment for **13 read collections**
  (`pull_pipeline.dart:73-98`) and **9 write collections**
  (`tutor_writes.ts:187` + 12 call sites); for 11 of the 13 reads, the
  owner-side writer is still the int-keyed sync engine. Re-keying tutoring
  alone would make the tutor read a tree nothing writes and write a tree
  nobody reads — silently, since no gate available through Phase 2 can see
  a doc-id-formula mismatch. Full evidence and the corrected 6-site count
  for `manage_tutors_screen.dart`: `firestore-cutover-tasks.md`'s T-31 row.
- **T-37 (new) — the tutored read seam.** P2-5 (Phase 2) hoisted a uniform
  refusal for all 13 profile-scoped providers during a tutored session, but
  sourced `uid` from the signed-in account — substituting the ULID alone
  without also substituting the owner's `uid` addresses
  `users/{TUTOR}/learner_profiles/{talmid ULID}`, a brand-new wrong tree.
  T-37 builds the owner-uid-scoped handle seam the rules already permit
  (`firestore.rules:450` + 16 sibling lines).
- **T-39 (new), prerequisite for T-20** — reconcile check 103's 10-collection
  WATCHLIST against `firestore-cutover-log.md`'s 7-item "dead adapters"
  list before wiring anything; they are not the same set today.

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

- **#23 / T-38 (new, folded in)** — retarget enforcement gates to the new
  architecture. Many encode the old sync engine's invariants and will be
  checking rules about deleted code. T-38 adds: fold check 104
  (`PROFILE-ID-INT-SITES`, built Phase 2) into this retarget; fix
  `Makefile:1366`'s stale `all 68 greps clean` summary string; un-skip
  `test/tool/audit_and_arb_parity_test.dart:112-125` (its `skip:` reason is
  now false).
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
