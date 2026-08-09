# Firestore cutover plan

**Status:** Phase 0 ✅ · Phase 1 ✅ · **Phase 2 — `T-49` CLOSED, Phase 2 AS
A WHOLE recorded NOT RESOLVED (P2-33, 2026-08-09).** `T-49` (the phase's
sole SERIOUS *code* defect) is closed for real, by removal, confirmed by
a review independent of the fixing round — full detail in the paragraph
immediately below, unedited, correct for `T-49`'s own disposition. **But
this project's own DECISION RULE is a disjunction, and `T-39`
(pre-existing, untouched throughout every round of this saga, the
project's own declared sole remaining Phase 3 entry blocker) is still
`todo` — one open blocker is sufficient to force `NOT RESOLVED` no matter
how many other findings a round closes.** A round-7 FINAL REVIEW (its own
verdict: `resolved-with-deviations`, `safe_for_phase_3: false`) found
three further record-integrity gaps beyond `T-39` — a two-round-stale
deferred-verification table, a fifth uncaveated CONTROL-4 claim, and two
`make ci` targets unrun since round 5 — **all three closed or explicitly
named this round (P2-33)**, none of them ever a code defect. **Phase 3
remains explicitly BLOCKED, on `T-39` at minimum, plus the standing
device checks `D10`/`D11`/`D20` and four MINOR non-blocking residuals
(`T-65`–`T-69`).** See the new PHASE 3 ENTRY CRITERIA checklist below §3,
and `firestore-cutover-log.md`'s new **P2-33** entry (including a PHASE 2
RETROSPECTIVE: seven rounds, one failure mechanism per line) for the full
record.
*(Historical, P2-32:)* **Phase 2 — `T-49` CLOSED BY REMOVAL
(P2-31, round 7).** `_activateThenEnsureFirestoreProfile` and
`_writeFirestoreProfile` are deleted; `createProfile`/`ensureDefaultProfile`
now call `_ensureFirestoreProfile` directly — the write-only path
`ensureRemoteProfile` has used since P2-18 — and the repository never
writes `activeProfileDocIdProvider` on any path. This answers the
question four prior rounds (P2-18/P2-23/P2-28, then P2-29's own review)
each failed to ask: not "is this write above the awaits I can see?" but
"does this path perform this write at all?" 14 permanent test cases (the
existing 6 + 3 new cases gating the caller-boundary await P2-29's review
found + 5 controls, including a source-scanning structural gate), revert-
proved byte-exact. `T-39` (pre-existing, unrelated) remains the sole
Phase 3 entry blocker. **CONFIRMED by a fresh independent review (P2-32)**
— per this document's own standing rule, "the round that fixes `T-49`
cannot certify its own fix," a review independent of P2-31 itself
re-derived the call-tree enumeration, ran its own probe matrix, and found
the code sound; it found six record-integrity/test-quality defects in the
round's own written output (none reopening `T-49`, all dispositioned as
`T-65`–`T-68` plus two in-place corrections). See `firestore-cutover-log.md`'s
**P2-31** entry for the fix and mechanism, and its new **P2-32** entry for
the independent review and the corrections it required.
*(Historical, P2-29:)* **Phase 2 — NOT RESOLVED. `T-49` is
REOPENED A FOURTH TIME (P2-29) — the mandatory fresh independent review of
P2-28's own commit found P2-28's fix narrows the race window, it does not
close it.** P2-28 genuinely closed both of
`_activateThenEnsureFirestoreProfile`'s OWN internal awaits — six
permanent test cases, revert-proved, undisputed. But the write it hoisted
is reached from exactly two PUBLIC callers, `createProfile` and
`ensureDefaultProfile`, and BOTH have real, unguarded awaits of their own
— Drift round-trips plus, on the durable-outbox path, a DB enqueue, or in
a tutored session a genuine Cloud Function RPC — that run BEFORE
`_activateThenEnsureFirestoreProfile` is ever entered, none of it
enumerated by P2-28's fix, its doc comments, or its commit message.
**REPRODUCED BY EXECUTION**, zero subclassing of the class under test: a
probe delaying only `SyncWriteFacade.pushLearnerProfile` went RED
(`Expected: 'ulid-p29-b' / Actual: 'ulid-p29-c'`). `T-39` (pre-existing,
unrelated) remains open — both again gate Phase 3 entry, exactly as
before P2-28. See `firestore-cutover-log.md`'s new **P2-29** entry for the
full await enumeration and the reproduction. *(The rest of this
paragraph, through "against `734a6daa`," describes the state as of
P2-26/P2-27 and is left unedited, append-only, per this document's own
"never rewrite history" rule; the **P2-28 addendum** below §3, which
believed `T-49` closed, is itself now superseded by the new **P2-29
addendum** immediately after it — see below.)*
*(Historical, P2-28:)* **Phase 2 — NOT RESOLVED, but `T-49`
IS CLOSED FOR REAL (P2-28) — both internal awaits inside
`_activateThenEnsureFirestoreProfile`, six permanent test cases, revert-
proved byte-exact. `T-39` (pre-existing, unrelated) is now the sole
remaining Phase 3 entry blocker, plus a fresh independent review of
P2-28's own commit (this file's own standing rule: the round that fixes
`T-49` cannot certify its own fix). See `firestore-cutover-log.md`'s new
**P2-28** entry for the fix and full proof.** *(The rest of this
paragraph, through "against `734a6daa`," describes the state as of
P2-26/P2-27 and is left unedited, append-only, per this document's own
"never rewrite history" rule — see the **P2-28 addendum** below §3 for the
correction in full.)* Phase 2 — NOT RESOLVED. `T-49`
(the phase's sole BLOCKING code defect) is REOPENED A THIRD TIME, at
P2-26, RECONFIRMED UNCHANGED at P2-27 — a fourth-round independent review found P2-23's fix (`bb704e07`)
closed the race on only ONE of the two awaits inside
`_activateThenEnsureFirestoreProfile`, and reproduced the identical
clobber through the OTHER one by execution, against `734a6daa`.** Its two
sibling findings, `T-56`/`T-57` (P2-24, both pre-existing, both
unrecorded until P2-22), ARE genuinely closed — round 4 independently
re-checked both and found neither defective. Phase 3 remains explicitly
BLOCKED, now only on `T-39` and `T-49`'s real closure (needing a fix, and
a permanent test, for BOTH internal awaits this time, not one) — see
`firestore-cutover-log.md`'s **P2-26** entry, "Phase 3 ENTRY CRITERIA,"
for the exact checklist. **This paragraph was
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
Full detail: `firestore-cutover-log.md`'s **P2-14** through **P2-27**
entries, and `firestore-cutover-tasks.md`'s `T-40`–`T-62` rows. **This
section's narrative below (commit list, blocked framing) predates P2-8
through P2-23 and is not rewritten here — treat the log entries above as
authoritative over this paragraph's prose; only the status line, Head
field, and the Phase 2 section header/summary immediately below §3 are
corrected, at each closing commit — that convention itself is why this
paragraph went three rounds stale, and is the exact mechanism `T-62`
(P2-27) now names and tracks with a task id, generalized past this one
field: a "state as of my immediate parent" self-reference citation must
be re-derived at every commit of a multi-commit round, not only the
round's first.**
**P2-24 addendum (does not restate the P2-23 paragraph above, which
stands unedited):** `T-56` and `T-57` — the two sibling
provider-clobber defects `T-49`'s own P2-22 reopening review found next
to it, both pre-existing (predate Phase 2), both left `todo` through
P2-23 — are now `done` (P2-24). See the Phase 2 section header/summary
immediately below §3 for the fix shape and evidence pointer.
**P2-26 addendum (docs-only; supersedes the status line above and the
Phase 2 section header/summary below §3 — does not restate or dispute
the P2-24 paragraph above, which correctly closed `T-56`/`T-57` and
stands unedited):** the "two outstanding independent reviews" P2-24
predicted have now happened — a fourth-round independent review ran
against `734a6daa`, re-confirmed `T-56`/`T-57` solid, found `T-58`'s
"CONFIRMED RED" claim itself false (already fixed, unlogged, by
`c794cb35`/P2-25 — recorded retroactively), and found `T-49` **NOT**
actually closed: P2-23's fix closed the race through the
Firestore-WRITE await inside `_activateThenEnsureFirestoreProfile` but
left a DIFFERENT, earlier await on the same method
(`_resolveFirestoreProfileRepo`, resolving
`firestoreLearnerProfileRepositoryProvider` — account/App-Check/auth
resolution) unguarded for the same two callers, reproduced by execution
(two probes, RED). `T-49` is **REOPENED A THIRD TIME.** Full mechanism,
the probes, and a suggested fix (not applied — P2-26 is docs-only):
`firestore-cutover-log.md`'s **P2-26** entry and
`firestore-cutover-tasks.md`'s `T-49` row. **Phase 3 ENTRY CRITERIA now
gates on `T-39` (pre-existing) and `T-49`'s real closure — which now
needs proof for BOTH internal awaits, not one, before any round
self-certifies it again.**
**P2-27 addendum (docs-only; corrects two record-integrity defects round
5's independent review found in P2-26's own output — does not restate or
dispute the `T-49`/`T-56`/`T-57`/`T-58` findings in the P2-26 paragraph
immediately above, which stand unedited):** round 5's review re-read
`_activateThenEnsureFirestoreProfile` (`profile_repository_impl.dart:889-896`)
directly against HEAD `981a8770` (P2-26's own three commits, `11c6fa3f`
→ `bb1b53af` → `981a8770`) and found `T-49`'s residual byte-for-byte
unchanged since P2-26 — **reconfirmed, not re-fixed.** It also found two
NEW documentation defects, both fixed this commit: **`T-61`** (SERIOUS as
a documentation defect) — `firestore-cutover-log.md` cited `+11511 ~131
-0` as round 4's fresh `make test` measurement against `734a6daa`, which
is arithmetically impossible on a tree already containing P2-23's 3 new
tests and P2-24's 2 new tests on top of the `+11511` P2-22 baseline
(`734a6daa`'s own commit message states the correct `+11516` directly);
and **`T-62`** (MINOR) — `CURRENT STATE`'s `Head:` field (and
`firestore-cutover-tasks.md`'s header) still named `734a6daa` even though
P2-26 landed two further same-round commits after it. Full mechanism,
both corrected numbers, and two new standing facts naming the
mechanisms: `firestore-cutover-log.md`'s new **P2-27** entry and
`firestore-cutover-tasks.md`'s `T-61`/`T-62` rows. **Phase 3 ENTRY
CRITERIA is unchanged in substance by this addendum — still `T-39`
(pre-existing) and `T-49`'s real closure (needing proof for BOTH internal
awaits) — `T-61`/`T-62` are both closed and neither was ever blocking.**
**P2-28 addendum (code-touching — closes `T-49`; supersedes the status
line above and the Phase 2 section header/summary below §3; does not
restate or dispute anything in the P2-27 addendum immediately above,
which correctly closed `T-61`/`T-62` and stands unedited):** hoisted
`_activateThenEnsureFirestoreProfile`'s activation write above BOTH of
its internal awaits (P2-23 had hoisted it above only the write; the
resolution await — `_resolveFirestoreProfileRepo`, a real, sometimes-slow
provider chain documented stalling ~38+ seconds in the `T-43`
reproduction — stayed unguarded until now), gated on the same
synchronous, in-memory `activeAccountIdProvider != null` check
`SelectedProfileId.select()` itself already uses, evaluated before either
await rather than on the async result of the first one. Reproduced round
5's `R5-D`/`R5-E` RED first (using its own preserved probe), applied the
fix, all six `R5-A`..`R5-F` cases GREEN, made the RESOLUTION-await half
permanent alongside P2-23's existing WRITE-await tests (six cases total,
all three callers × both boundaries, in
`profile_repository_impl_t49_activation_ordering_test.dart`), revert-proved
byte-exact via `cp` (never `git stash`). Doc comments describing only the
WRITE-await half of the fix corrected in code, same commit. `flutter test
test/features/profiles/` → `+433` (430 baseline + 3 new); `make test` →
`08:29 +11519 ~131: All tests passed!` (11516 baseline + 3 new). **`T-49`
is now `done` (P2-28). Phase 3 ENTRY CRITERIA now gates on `T-39`
(pre-existing, unrelated) alone, plus a fresh independent review of
P2-28's own commit — the round that fixes `T-49` cannot certify its own
fix, this document's own standing rule, re-armed against this exact
commit.** Full mechanism, the fix, and full proof:
`firestore-cutover-log.md`'s new **P2-28** entry; `firestore-cutover-tasks.md`'s
`T-49` row.
**P2-29 addendum (docs-only; this IS the "fresh independent review of
P2-28's own commit" the P2-28 addendum immediately above said Phase 3
could not open without — supersedes the status line above and the Phase
2 section header/summary below §3 for `T-49`'s disposition; does not
restate or dispute anything the P2-27 addendum found about `T-61`/`T-62`,
which stands unedited):** re-read `_activateThenEnsureFirestoreProfile`
and both its public callers directly against `64f1f763`. P2-28's fix is
real and closes both of that method's OWN internal awaits — undisputed.
But the write it hoisted is reached from exactly two PUBLIC callers,
`createProfile` and `ensureDefaultProfile`, and BOTH have real, unguarded
awaits of their own — Drift round-trips plus, on the durable-outbox path,
a DB enqueue, or in a tutored session a genuine Cloud Function RPC
(`TutoredWriteRouter.pushLearnerProfile`) — that run BEFORE
`_activateThenEnsureFirestoreProfile` is ever entered: four awaits on the
`createProfile` path, six on `ensureDefaultProfile`'s, none enumerated by
P2-28's fix, its doc comments, or its commit message. **REPRODUCED BY
EXECUTION**, zero subclassing of the class under test: a probe delaying
only `SyncWriteFacade.pushLearnerProfile` (the collaborator
`ProfileRepositoryImpl.createProfile` already awaits in production) went
RED — `Expected: 'ulid-p29-b' / Actual: 'ulid-p29-c'` — written, run,
deleted (docs-only charter, no permanent test without a fix to guard).
**`T-49` is `blocked`, reopened a FOURTH time (P2-29). Phase 3 ENTRY
CRITERIA re-arms on `T-49`, exactly as before P2-28 — `T-39` remains the
other open blocker.** Also recorded: `T-63` (record-integrity — P2-28's
"CLOSED FOR REAL" claim, stated in its commit message, two doc comments,
and this project's own planning docs, was false in all four places) and
`T-64` (MINOR — the readiness gate P2-28 introduced is a strict widening
of the old async check, not the proven equivalence P2-28's own Deviation
1 claimed; a documented invariant about local-born accounts was silently
dropped; functionally inert today, confirmed by reading the sole `lib/`
consumer). **The generalisable lesson: when hoisting a write above an
await to close a race, enumerate EVERY await on the path first — not
every await inside the method being edited.** Full mechanism, the full
await enumeration for both paths, the probe, and both new tasks:
`firestore-cutover-log.md`'s new **P2-29** entry; `firestore-cutover-tasks.md`'s
`T-49`/`T-63`/`T-64` rows.
**Last updated:** 2026-08-09 (P2-33; this `Last updated:`/`Head:` block
specifically — **found stale AGAIN this round, a FOURTH file/field
combination the `T-62` mechanism has now hit**, see the correction below;
the status line above and the Phase 2 section header/summary below §3
were updated together with this field in this same commit, so all three
now agree)
**Head:** `f2f59e6e` (P2-32's own commit, confirmed via `git log
--oneline -1` at this round's (P2-33) session start, per `T-62`'s own
lesson — re-derived, not copied forward).
**Corrected this round — the `T-62` mechanism recurring a FOURTH time in
this file:** this block still read `6655f184`/"P2-31's own same-session
follow-up commit" even though P2-32 landed a further commit (`f2f59e6e`)
after it and confirmed `T-49`'s fix independently. P2-32's own edit list
updated the top-of-file status line and the Phase 2 section header
further down (§3, below), but never reached this separate mid-document
field a second time — the identical "advances the field its own
narrative cites but not every sibling citation of the same fact" pattern
this file's own text (immediately below) already named once, recurring
against itself. `T-49` is CLOSED BY REMOVAL (P2-31), independently
re-confirmed (P2-32) — see the status line and §3, below, both current
and correct; this field was simply never told, twice running.
*(Historical, P2-29:)* **Last updated:** 2026-08-07 (P2-29; status line, Head field, `Last
updated:` field, this Phase 2 section addendum and the header/summary
below §3 — the verification-cadence paragraph re-verified, needed no
further change)
**Head:** commit SHA not yet knowable — same self-reference lag as every
prior closing commit; the true immediate parent is `64f1f763`, P2-28's
own commit (confirmed via `git log --oneline -1` at this round's session
start, per `T-62`'s own lesson — re-derived, not copied forward from the
prior round's citation).
`_activateThenEnsureFirestoreProfile`
(`profile_repository_impl.dart:938-945`, unchanged since P2-28 — this
round is docs-only, no `lib/` file touched) and its two public callers
(`createProfile` `:684-714`, `ensureDefaultProfile` `:717-749`) re-read
directly this round, not cited from any prior round's prose. `T-40`,
`T-43`, `T-56`, `T-57` remain fixed and independently re-verified,
unaffected. **`T-49` is REOPENED A FOURTH TIME (P2-29) — P2-28's fix
narrowed the race window, it did not close it. Phase 2 closure blocked
on `T-39` and `T-49`'s real closure — needing proof for the CALLER-level
awaits this time, not only the two the shared method itself has — plus,
once a fix lands, its own fresh independent review, not
self-certifiable.**
*(Historical, P2-28:)* **Head:** commit SHA not yet knowable — same self-reference lag as every
prior closing commit; the true immediate parent is `3872fdbc`, P2-27's
own commit (confirmed via `git log --oneline -1` at this round's session
start, per `T-62`'s own lesson — re-derived, not copied forward from the
prior round's citation).
`_activateThenEnsureFirestoreProfile`
(`profile_repository_impl.dart:938-945` as of this commit; was
`:889-896` when P2-26/P2-27 read it) re-read directly this round, fixed,
and re-read again post-fix. `T-40`, `T-43`, `T-56`, `T-57` remain fixed
and independently re-verified, unaffected. **`T-49` is CLOSED FOR REAL
(P2-28) — both internal awaits. Phase 2 closure blocked on `T-39` alone,
plus the still-required fresh independent review of P2-28's own commit.**

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

### Phase 2 — Unify the identity (int → ULID) — **`T-49` RESOLVED 2026-08-09 (P2-31, round 7) — CLOSED BY REMOVAL, CONFIRMED by an independent review (P2-32). `T-56`, `T-57`, `T-58`, `T-59`, `T-63`, `T-64` all genuinely CLOSED. PHASE 2 AS A WHOLE recorded NOT RESOLVED (P2-33) — `T-39` (pre-existing, untouched throughout Phase 2) is the sole declared Phase 3 entry blocker; the DECISION RULE is a disjunction and one open blocker is enough. See the PHASE 3 ENTRY CRITERIA checklist immediately below for the complete, current blocker set.**

**P2-33 addendum (docs-only; restates the verdict at the correct scope —
does not restate or dispute anything the P2-31/P2-32 paragraphs below
found about `T-49` itself, both of which stand unedited):** `T-49` being
closed answers only the question this section's own name asks about
identity-clobber safety — it does not by itself resolve Phase 2, because
Phase 2's exit gate (stated in this plan's own §4 and the log's Phase 3
ENTRY CRITERIA convention) is the FULL blocker set, not `T-49` alone.
`T-39` — the WATCHLIST/dead-adapters reconciliation, pre-existing,
unrelated to `T-49`, untouched by any of Phase 2's seven `T-49` rounds —
remains `todo` and is, on the record's own repeated statement across
P2-22 through P2-32, the sole OTHER declared Phase 3 entry blocker. A
round-7 FINAL REVIEW additionally found (and this round closed or named)
three record-integrity gaps: the log's deferred-verification table had
not been superseded since the fix that invalidated its two most
load-bearing rows (fixed, `firestore-cutover-log.md` §10c); a fifth,
uncaveated copy of the disproven CONTROL-4 "structurally impossible"
claim sat in the log's own highest-traffic field (fixed, in place); and
two of `make ci`'s nine targets have not run against the code since round
5 (named as `T-69`, not run this pass either — owner directive forbids
gate runs for this docs-only step). **PHASE 3 ENTRY CRITERIA — new,
added this round (this document previously had none of its own; the
authoritative checklist lived only in the log):**

- [x] `T-49` (SERIOUS) — CLOSED BY REMOVAL, independently confirmed.
- [x] `T-59`, `T-63`, `T-64` — all `done`, genuinely.
- [x] A fresh independent review of the commit that closes `T-49` —
  SATISFIED (the round-7 verifier, independent of P2-31).
- [ ] **`T-39` — STILL OPEN, `todo`. The sole declared Phase 3 entry
  blocker.**
- [x] The deferred-verification table superseded (P2-33; was two rounds
  stale).
- [x] The fifth CONTROL-4 claim caveated (P2-33).
- [x] `make validate-calendar`/`make test-serial-tools`'s absence named
  as an explicit task, `T-69` (P2-33) — not run, per owner directive, but
  no longer silently glossed as a batching decision.

**VERDICT: Phase 2 NOT RESOLVED. Phase 3 explicitly BLOCKED, on `T-39` at
minimum**, plus the standing device checks `D10`/`D11`/`D20` (see
`firestore-cutover-log.md`'s §10c) and four MINOR, non-blocking code
residuals (`T-65`–`T-68`). Full record: `firestore-cutover-log.md`'s new
**P2-33** entry.

*(Historical, P2-32 — the paragraph immediately below, unedited, stands
for `T-49`'s own disposition; this addendum restates only the WHOLE-PHASE
verdict at its correct, wider scope:)*

**P2-31 supersedes the P2-29 paragraph immediately below — `T-49` is no
longer reopened, it is closed, by deleting the write four prior rounds
each tried to relocate instead. `_activateThenEnsureFirestoreProfile` and
`_writeFirestoreProfile` (`profile_repository_impl.dart`) are deleted;
`createProfile`/`ensureDefaultProfile` call `_ensureFirestoreProfile`
directly, the write-only path `ensureRemoteProfile` has used since P2-18.
The repository writes `activeProfileDocIdProvider` on NO path, verified
both dynamically (9 race cases, all now structurally green) and
structurally (a source-scanning CONTROL-4 test asserting every write site
in `lib/` lives in `profile_providers.dart`). `T-59` — delete the
repo-side write and let `select()` be the sole seam — is not merely
recommended any more, it is what P2-31 did. `T-64` closes by removal too:
the readiness gate the finding was about no longer exists. Revert-proved
byte-exact (reverting `profile_repository_impl.dart` alone predicted,
then measured, exactly 6 of 14 permanent cases RED, 8 GREEN). Per this
plan's own standing rule ("the round that fixes `T-49` cannot certify its
own fix"), the Phase 3 ENTRY CRITERIA line for a fresh independent review
was CHECKED at **P2-32** — a review independent of P2-31 itself confirmed
the fix and found six record-integrity/test-quality defects in the
round's own record, none of them a code defect and none reopening `T-49`
(`T-65`–`T-68`, plus two in-place corrections). Full mechanism and proof:
`firestore-cutover-log.md`'s new **P2-31** and **P2-32** entries.**
*(Historical, P2-29:)* **P2-29 supersedes the P2-28 paragraph immediately below for `T-49`'s
disposition only — does not restate or dispute anything else in it, and
this IS the "fresh independent review of P2-28's own commit" that
paragraph said Phase 3 could not open without.** P2-28's fix closes both
of `_activateThenEnsureFirestoreProfile`'s OWN internal awaits — real,
undisputed. But the write it hoisted is reached from exactly two PUBLIC
callers (`createProfile`, `ensureDefaultProfile`), and BOTH have real,
unguarded awaits of their own — Drift round-trips plus, on the
durable-outbox path, a DB enqueue, or in a tutored session a genuine
Cloud Function RPC — that run BEFORE `_activateThenEnsureFirestoreProfile`
is ever entered, none of it enumerated by P2-28's fix, its doc comments,
or its commit message: four awaits on the `createProfile` path, six on
`ensureDefaultProfile`'s. **REPRODUCED BY EXECUTION**, zero subclassing of
the class under test: a probe delaying only
`SyncWriteFacade.pushLearnerProfile` went RED (`Expected: 'ulid-p29-b' /
Actual: 'ulid-p29-c'`). `T-49` is `blocked`, reopened a FOURTH time
(P2-29). Also recorded: `T-63` (record-integrity — P2-28's "CLOSED FOR
REAL" claim was false in four places) and `T-64` (MINOR — the readiness
gate P2-28 introduced is a strict widening, not a proven equivalence;
functionally inert today). **The generalisable lesson: when hoisting a
write above an await to close a race, enumerate EVERY await on the path
first — not every await inside the method being edited.** Full
mechanism, the full await enumeration, and the probe:
`firestore-cutover-log.md`'s new **P2-29** entry.

**Historical record, P2-28 (2026-08-07) — kept verbatim below, not
rewritten, superseded by P2-29 above for `T-49`'s disposition only.**

**P2-28 supersedes the P2-27/P2-26 paragraphs immediately below for
`T-49`'s disposition only — does not restate or dispute anything else in
them:** `T-49` is `done` (P2-28). Full mechanism, the fix, and full proof:
`firestore-cutover-log.md`'s new **P2-28** entry.

**P2-27 supersedes the P2-26 paragraph immediately below only for the two
record-integrity corrections it names — does not restate or dispute
anything P2-26 found about `T-49`/`T-56`/`T-57`/`T-58`, all of which
stand unedited.** Round 5's independent review re-read
`_activateThenEnsureFirestoreProfile` (`profile_repository_impl.dart:889-896`)
directly against HEAD `981a8770` (P2-26's own three commits, below) and
found `T-49`'s residual byte-for-byte unchanged — **reconfirmed, not
re-fixed; P2-27 is docs-only, same charter as P2-26.** It found, and
P2-27 fixed, two NEW record-integrity defects inside P2-26's own output:
`T-61` (SERIOUS as a documentation defect — a `make test` count,
`+11511 ~131 -0`, misattributed to `734a6daa`, whose real count is
`+11516`, arithmetically confirmed by `734a6daa`'s own commit message)
and `T-62` (MINOR — `CURRENT STATE`'s `Head:` field, and this file's own
`Head:` field above, left three commits stale after P2-26 landed as
three commits, not one, and only the first advanced the field). Neither
defect touches `T-49`/`T-56`/`T-57`/`T-58`'s disposition. Full mechanism:
`firestore-cutover-log.md`'s new **P2-27** entry and
`firestore-cutover-tasks.md`'s `T-61`/`T-62` rows. **Phase 3 ENTRY
CRITERIA is unchanged in substance — still `T-39` (pre-existing) and
`T-49`'s real closure (needing a fix AND a permanent test for BOTH
internal awaits), not self-certifiable by the round that fixes it.**

**Historical record, P2-26 (2026-08-07) — kept verbatim below, not
rewritten, superseded by P2-27 above only for the two record-integrity
corrections it names.**

**P2-26 supersedes the P2-24 paragraph immediately below (kept as
history, not rewritten) — without disputing what it correctly found for
`T-56`/`T-57`.** The "fresh independent review of BOTH `bb704e07` and
this round's own commit" that paragraph's last line called for has now
happened (round 4, against `734a6daa`). It re-confirmed `T-56` and `T-57`
solid — both genuinely `done`, unaffected, full evidence unchanged, see
that paragraph below. It found `T-58`'s "remains open, MINOR" line in
that same paragraph already stale: `c794cb35` (P2-25) had fixed it before
P2-24 even ran, un-logged; recorded retroactively, now `done`
(`firestore-cutover-tasks.md`'s `T-58` row). **And it found `T-49` NOT
closed** — P2-23's fix (described two paragraphs below) genuinely closed
the race through `_activateThenEnsureFirestoreProfile`'s Firestore-WRITE
await, but left the SAME method's OTHER await
(`_resolveFirestoreProfileRepo`, resolving
`firestoreLearnerProfileRepositoryProvider`) unguarded for the same two
callers (`createProfile`, `ensureDefaultProfile`'s self-heal branch) —
reproduced by execution, two probes RED:
`Expected: 'ulid-probe4-b' / Actual: 'ulid-probe4-c'` and
`Expected: 'ulid-probe5-b' / Actual: 'ulid-probe5-d'`. P2-23's own
justification for the design it shipped — "activating before the write
closes this … a later `select()` always wins and is never clobbered" —
is FALSE, the identical false-reachability-claim shape `T-49` was
reopened for at P2-22, restated in weaker form. **`T-49` is `blocked`,
reopened a THIRD time (P2-26).** Not fixed in code this round — P2-26 is
docs-only; a suggested fix (gate the activation write on the same
synchronous `activeAccountIdProvider` check `select()` already uses,
before resolving the Firestore repo) is recorded but not applied. Full
mechanism, both probes, and the suggested fix:
`firestore-cutover-log.md`'s **P2-26** entry and
`firestore-cutover-tasks.md`'s `T-49` row. **Phase 3 ENTRY CRITERIA now
gates on `T-39` (pre-existing) and `T-49`'s real closure — which needs a
fix AND a permanent test for BOTH internal awaits this time, followed by
its own fresh independent review; not self-certifiable.**

---

**Historical record, P2-24 (2026-08-07) — kept verbatim below, not
rewritten, superseded by P2-26 above for `T-49`'s disposition — its
`T-56`/`T-57` closures stand, unaffected.**

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
rewritten. P2-24 (above) correctly superseded this for `T-56`/`T-57`'s
disposition only, saying `T-49`'s closure below was "unaffected and
stands" — that sentence itself is now superseded by P2-26 (top of this
section): `T-49`'s closure did NOT stand, reopened a third time.**

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

**Entry criteria and traps (lesson-mining pass, added 2026-08-09 from Phase
2's seven-round `T-49` saga — verify each claim against the code before
relying on it, per this project's own "reproduce, don't inherit" rule; full
incident evidence is in `firestore-cutover-log.md`'s Working Protocol and
PHASE 2 RETROSPECTIVE sections):**

- **Entry criteria, restated from `firestore-cutover-log.md`'s Phase 3 ENTRY
  CRITERIA checklist — read it there, do not re-derive from scratch:** `T-49`
  closed and independently confirmed; `T-39` (below) still `todo` and the
  sole other declared blocker; the deferred-verification table current as of
  the last entry. Device checks `D10`/`D11`/`D20` are standing work, not
  phase gates — read them before touching profile-activation code a second
  time, but they do not block Phase 3's start.
- **`T-39` first, before wiring anything — the WATCHLIST and the "dead
  adapters" list are not the same set.** Check 103's dynamically-computed
  WATCHLIST (`tool/check_profile_path_keying.dart --report`) is every one of
  the 17 profile-scoped collections with a live INT writer opposite a
  DORMANT ULID repo file; `CURRENT STATE`'s "Dead adapters (7)" line
  (`completion · curriculum-track · goal · progress · stage-definition ·
  study-day-config · track-learning-order`) is a hand-maintained adapter-
  class list. They are drawn from different populations. Reconcile them by
  running the actual `--report` output against the current tree before
  treating either as the wiring order — per `T-39`'s own row in
  `firestore-cutover-tasks.md`, five WATCHLIST collection names have no
  counterpart in the dead-adapters list and two dead-adapters entries have
  no WATCHLIST counterpart.
- **Check 104's baseline (`tool/profile_id_int_sites_baseline.txt`, 88
  entries) is baselined almost entirely against the exact files Phase 3 will
  edit — verified by re-reading the baseline directly, not inherited.**
  Every `cf-int-guard`/`cf-string-profileid-doc` entry sits in
  `functions/src/deletes.ts` (T-30) or `functions/src/tutor_writes.ts` /
  `tutor_bulk_completions.ts` (T-31); every `dart-tutoring-*` entry sits in
  `lib/features/tutoring/**` (T-31). The `dart-int-profileid-param` entries
  against `lib/core/sync/firestore_gateway.dart` and
  `lib/core/sync/outbox/push_pipeline.dart` are interface-level and belong
  to **Phase 4**, not Phase 3 — do not touch those baseline lines here.
  **Editing a T-30/T-31 file WILL change check 104's output** (a baselined
  symbol disappearing, a new pattern appearing, an occurrence count moving
  inside a kept symbol) — expected, not a regression, but the fix and the
  matching `tool/profile_id_int_sites_baseline.txt` edit must land in the
  SAME commit (the tool's own P2-1 doc comment: narrowing the scanner and
  changing the code it covers may not land together).
- **T-30/T-31's 13-read/9-write coupling is why they were re-phased out of
  Phase 2 in the first place — do not re-key one direction without the
  other, and do not re-key one of the 13 read collections without checking
  whether its owner-side writer is still int-keyed.**
  `TutoredProfileSelection.profileId` is a live Firestore path segment:
  `PullPipeline.pullForTutoredProfile` (`lib/core/sync/pull_pipeline.dart:73-98`)
  pulls 13 collections + 3 preference docs; `verifyTutorGrant`
  (`functions/src/tutor_writes.ts:187` + 12 call sites) writes 9. As of
  Phase 2's close, 11 of the 13 reads still have an int-keyed owner-side
  writer. Re-keying tutoring's identity alone makes the tutor read a tree
  nothing writes and write a tree nobody reads — silently:
  `pullForTutoredProfile` counts no failures on an empty collection, so the
  pull "succeeds" into an empty talmid, and no gate through Phase 3 can see
  a doc-id-formula mismatch (neither check 103 nor 104 covers doc-id
  formulas).
- **T-37 repairs a regression Phase 2 deliberately created, and it needs a
  NEW seam, not a value substitution.** P2-5 hoisted a uniform refusal into
  `_watchActiveAccountAndProfile` for all 13 profile-scoped providers during
  a tutored session — correct, closing a live latent corruption — but it
  sources `uid` from the signed-in account (the tutor's own). Setting the
  profile ULID alone, without also substituting the owner's `uid`, addresses
  `users/{TUTOR}/learner_profiles/{talmid ULID}` — a brand-new wrong tree,
  not the parent's. The rules already permit the correct read
  (`firestore.rules:450` + 16 sibling `allow read: if isOwner(uid) ||
  hasActiveTutorAccess(uid, profileId)` lines); T-37 is an owner-uid-scoped
  handles seam — feature wiring, not a config flip.
- **Every new provider chain Phase 3 wires — the 7 currently-dead adapters,
  T-37's owner-scoped handles — is a fresh Riverpod chain that may await
  `activeAccountFirebaseProvider.future` or similar. Declare `retry: (_,
  __) => null` on it, or verify its test container came through
  `bootstrap()`.** Riverpod 3's default per-provider retry treats a
  structural exception (e.g. an unauthenticated-account error) as retryable
  for up to ~38 seconds before `.future` ever settles. The app's one
  production `ProviderContainer` (`lib/app/bootstrap/bootstrap.dart:68-81`)
  already disables this container-wide, so the risk is test-harness-only,
  not production — but a bare test container for a newly-wired adapter will
  hang for the full backoff if this is missed, exactly as it did for two
  providers earlier in this cutover before the container-wide fix was
  found.
- **An "adapter" in this codebase is not a thin wrapper — expect 4-6 awaits
  behind each one you wire, and check whether any of them is a genuine
  network RPC, not a local DB enqueue.** `FirestoreProfileRepositoryAdapter
  .createProfile`'s own chain — not discovered until Phase 2's sixth round —
  hid four of `ProfileRepositoryImpl`'s own awaits plus a durable-outbox
  enqueue that is a **one-shot Cloud Function RPC** in a tutored session.
  None of it was visible from the adapter's own signature or doc comments.
  Enumerate every await transitively reachable from each of the 7 adapters'
  public methods before wiring them, not just the adapter's own body — per
  this section's Working Protocol rule 2, from the PUBLIC ENTRY POINT.
- **Order by data dependency, writers before readers, per collection**
  (below) — **and the writer/reader pairs this project has already learned
  move together:** track-creation → bookmarks; learning-order → bookmarks
  *and* the scheduler's daily-task projection; completion → bookmarks.

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

**Entry criteria and traps (lesson-mining pass, added 2026-08-09):**

- **Check 103 (`PROFILE-KEY-SPLIT`) is file-location-based
  (`lib/core/sync/**`, `functions/src/**`), not keying-based, by design
  (`check_profile_path_keying.dart:54-66`) — it stays green and MEANINGLESS
  for identity progress until `lib/core/sync/**` is actually deleted. **Phase
  4 is the first phase where this check finally becomes an informative
  signal rather than a structural green.** Do not read check 103's OK line
  during Phase 3, or at the start of Phase 4, as evidence the identity split
  is closing — the split set only shrinks when the int-side files it scans
  are deleted, which is this phase's own act, not a side effect of Phase 3's
  moves.
- **`pushLearnerProfile` still writes an int-keyed `learner_profiles` twin on
  every profile create/update**
  (`lib/features/profiles/data/repositories/profile_repository_impl.dart:119,187,379`
  → `outbox_sync_write_facade.dart:146` → `outbox_processor.dart:671` →
  `firestore_gateway_impl.dart:466`) — ungated by check 103 (the parent
  collection, not a child, is outside its scan) and out of check 104's scope
  by design. It dies here, not sooner, and only as part of the whole
  `lib/core/sync` deletion — stopping it in isolation would strand the old
  sync engine's own `learner_profiles` pull/merge while any int-keyed
  collection still lives on that tree.
- **The ~179 `int profileId` occurrences under `lib/core/sync/**` die here.**
  Verified by direct count (`grep -rn "int profileId" lib/core/sync/ | wc -l`
  → `179`). Check 104 deliberately tracks only the INTERFACE-level
  occurrences, in `firestore_gateway.dart` and `outbox/push_pipeline.dart`
  (plus the three `functions/src` files), as a ratchet — the other ~150+
  implementation-level occurrences were never tracked individually, because
  they die wholesale with the directory and tracking them one by one would
  have been noise, not signal (check 104's own P2-1 design rationale).
- **Deleting `lib/core/sync` is where check 104's baseline finally shrinks
  toward its own genuinely-reachable end state.** Every
  `dart-int-profileid-param` entry currently baselined against
  `firestore_gateway.dart` / `push_pipeline.dart` must be removed from
  `tool/profile_id_int_sites_baseline.txt` in the SAME commit that deletes
  those files — a baseline entry present but no longer found in the scan
  fails the gate by the tool's own fail-closed-in-both-directions design.
- **Re-verify the ISO→Timestamp conversion before deleting the gateway that
  performs it.** `firestore.rules` enforces `is timestamp` on three fields
  (`streak_events.created_at`, `completions`/`learning_ledger.completed_at`,
  `points_ledger.created_at`); the dying `FirestoreGatewayImpl
  ._timestampifyField` converts the outbox's ISO strings to real
  `Timestamp`s before each write lands. `fake_cloud_firestore` cannot catch
  a regression here — a wrong type surfaces only as `permission-denied` on a
  real device, indistinguishable at first glance from an undeployed-rules or
  App-Check-token failure. Confirm all three fields are written as real
  Timestamps by the NEW repositories (not the dying gateway) before this
  deletion lands, and check the `Deployed:` field and the App Check debug
  token before attributing any resulting device denial to this change
  specifically.
- **`make audit` means two different things depending on directory (`T-52`)
  — this remains true after this phase's deletion.** A large deletion
  landing does not make the repo-root `Makefile`'s independent,
  currently-failing `audit` target relevant; keep running gates from
  `learning_tracker/`.

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

**Entry criteria and traps (lesson-mining pass, added 2026-08-09):**

- **`T-38` — fold check 104 (`PROFILE-ID-INT-SITES`, built Phase 2) into
  this retarget, in the same pass that retargets check 103 and the other
  `#23`-numbered gates.** By Phase 5, check 104's own reason to exist
  (tracking int-keyed sites during the migration) has been discharged by
  Phase 4's deletion; decide explicitly whether it becomes permanently
  empty-baseline, is deleted outright, or is repurposed — do not leave it
  running against a codebase with nothing left for it to track without a
  recorded decision.
- **The `all 68 greps clean` summary string
  (`learning_tracker/Makefile:1365,1378`) is stale TODAY, not just
  eventually — verified: the audit gate is already `104/104` checks, not
  68.** Fixing the string is explicitly deferred to this phase / `T-23` (not
  Phase 2's problem, per P2-1's own commit note) — do not read the stale
  "68" as a check count; the true count prints on the line immediately
  above it (`104/104 — PROFILE-ID-INT-SITES ...`).
- **Un-skip `test/tool/audit_and_arb_parity_test.dart`'s `'exits 0 when
  codebase is fully clean'` case — verified its skip reason is already
  false.** The skip text reads *"Pre-existing violations from Epics 25–26
  not yet resolved; re-enable once `make audit` is fully clean"*
  (`audit_and_arb_parity_test.dart:155-157`), but `make audit` has exited 0
  (`104/104 checks`, `PASSED`) on every measurement taken across all of
  Phase 2. Un-skipping it is not blocked on any further code work — only on
  running it, confirming it stays green, and removing the `skip:`
  parameter.
- **Verify `resolve()`'s cold-start re-attach on a real device — it is
  mock-only today and runs every launch.** The route guard clears the ULID
  when auto-selecting a single profile by bare int and self-heals on the
  next frame via `ensureSelected()`; whether anything can fire inside that
  window is not statically determinable. Phase 2's own `T-40` saga
  demonstrated exactly this class of gap surviving multiple rounds of
  static reasoning before a wiring test caught it — do not accept a trace as
  proof here either.
- **Add the NUL-byte gate (`#25`) before trusting any of the retargeted
  checks.** A single NUL byte in a source file makes `grep` treat it as
  binary, silently disabling every audit check on that one file — this has
  already happened once in this codebase, undetected by any of the other
  100+ checks, because none of them checks text-file validity as a
  precondition.
- **Device verification here is where `D10`/`D11`/`D20` — the highest-value
  checks never closed across Phase 2 — finally get a chance to run for
  real, if they were not picked up earlier:** `D10` (create a profile
  offline, restore network, activate — `fake_cloud_firestore` cannot model
  the offline queue or reconnect ack, so no in-repo test substitutes); `D11`
  (deploy `firestore.rules` + negative control — check the `Deployed:`
  field in `CURRENT STATE` first, in case this happened earlier); `D20`'s
  device half (activate A offline, switch to B, reconnect, confirm the
  provider ends on B — its code-level subject closed in Phase 2, this is
  the remaining device-only half).

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
