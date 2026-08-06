# Firestore cutover — recovery log

**Purpose: agent recovery.** Sessions die mid-work — session limits, interrupts,
crashes. This file is what a fresh agent reads to resume without re-deriving
anything or redoing finished work.

**READ THIS FIRST**, before the plan, before the code, before any grep.

Companions: [`firestore-cutover-plan.md`](firestore-cutover-plan.md) (the
phases and the anti-slop protocol) · [`firestore-cutover-tasks.md`](firestore-cutover-tasks.md)
(open work items).

---

## Recovery protocol

Run these in order. Do not skip to the code.

1. **Read the CURRENT STATE block below.** It names the head commit, the phase
   in flight, and anything left half-done.
2. **Verify the tree**, because the log may predate a crash:
   ```
   cd /home/daniel/repos/learning-tracker
   git log --oneline -1
   git rev-list --left-right --count origin/dev...dev   # 0 0 = in sync
   git status --porcelain | grep -v '^ M _bmad'         # _bmad churn is pre-existing
   git stash list                                       # a stash here is a RED FLAG
   ```
3. **Check for orphaned work** if a session died: `pgrep -af "flutter[ ]test"`.
   This machine has held test processes orphaned for 4+ days; they burn CPU and
   skew any timing you observe.
4. **Confirm the gates** before trusting anything:
   ```
   cd learning_tracker
   dart analyze --fatal-infos                       # seconds
   dart run tool/check_profile_path_keying.dart     # ~1s — the keying gate
   dart run tool/check_profile_id_int_sites.dart    # ~1s — int-keyed profile-identity sites (check 104)
   ```
5. **Only then** read the plan and the task list.

### If a session died mid-build

- Uncommitted work in the tree is **suspect until verified**, not lost. Check
  whether the last agent finished: read its section under IN FLIGHT below.
- **Never `git stash`** to clean up. A partial pop has already silently dropped
  work on this project. Edit by hand.
- A gate result collected while agents were writing describes nothing. Wait for
  a write-quiet window first.

---

## IN FLIGHT protocol

The recovery protocol above tells a cold agent to "read its section under IN
FLIGHT" to find out what the last agent was doing. That only works if IN
FLIGHT entries exist **before** the work they describe. Up to and including
Phase 1, every IN FLIGHT entry in this log was written after the fact, by the
agent that finished cleanly — which means an agent interrupted mid-commit left
nothing on disk to diff against. This is the fix, binding from 2026-08-06
(Phase 2) forward:

1. **Before starting any commit boundary** (e.g. `P2-3`), the implementing
   agent appends an entry to `CURRENT STATE`'s **IN FLIGHT** field naming:
   - the commit id (e.g. `P2-3`), and
   - its remaining edit-list items, citing the plan section they come from
     (e.g. `docs/planning/firestore-phase2-plan.md` §4 P2-3's edit list).
2. **The same commit that lands the code clears that entry** — resets IN
   FLIGHT to `nothing` — and rewrites the rest of `CURRENT STATE` (`Head:`,
   `Deployed:` where relevant, `Phase:`, `Gates:`) truthfully, in the same
   commit.
3. If an agent is interrupted before landing the commit, the entry stays as
   the last true statement of intent. A cold agent diffs the working tree
   against the named edit-list items in the plan, and either finishes them or
   reverts the named files by hand — **never `git stash`**.

---

## CURRENT STATE

**Head:** this commit (P2-3) — SHA unknowable within its own commit, same
self-reference lag as before. Parent is `0d5d9125` (P2-2, verified via `git
log --oneline -1` at P2-3 start).
**Deployed:** unknown — nothing deployed this phase yet.
**Phase:** 0 ✅ · 1 ✅ · **2 in progress** (P2-1 ✅, P2-2 ✅, P2-3 ✅, P2-4
through P2-7 not started).
**Gates:** `dart analyze --fatal-infos` → `No issues found!` (0 issues in
both `lib/` and `test/`). `make audit` green (**104** checks, unchanged;
`=== audit PASSED — all 68 greps clean ===`). Check 104 (PROFILE-ID-INT-SITES)
unchanged at **88 entries**, 0 new, 0 stale — P2-3 touches `ProfileModel`'s
nullability, not the tracked int-keyed sites, so the count did not move.
Check 103's OK line and split set are **unchanged**: 2 collections
(bookmarks, learning_order), 0 new violations. Full `make ci` last green at
`5b4d7924`; batched to end of Phase 4 by owner decision (2026-08-06).

**IN FLIGHT:** nothing.

**Live on Firestore (4):** bookmarks · learning-order · profile identity ·
scheduler learning-order read.
**Dead adapters (7):** completion · curriculum-track · goal · progress ·
stage-definition · study-day-config · track-learning-order.

---

## Standing facts an agent must not re-derive

- **The migration unit is the int→ULID cut, not the feature.** The old sync
  engine writes `learner_profiles/{int}/…` for 14 collections; every Firestore
  repository reads `learner_profiles/{ULID}/…`. Disjoint trees. A feature moved
  alone reads a tree nothing writes.
- **The test suite cannot see this class of defect.** `fake_cloud_firestore`'s
  rules companion cannot evaluate `request.resource`, and tests seed whatever
  path the test itself chose. 144 tests passed over a branch that could not
  execute in production. Audit check 103 exists to close this.
- **`make audit` is a subset of `make ci`.** Checks exist in only one lane.
  `make audit`'s R6d coverage check *soft-skips* when `coverage/lcov.info` is
  absent and still exits 0 — read the lines above an exit code, not just the
  code.
- **Doc comments here are load-bearing and go stale.** A stale comment caused
  the deletion of a live feature. Verify a claim against code before acting.

---

## Entries

Newest first. Append; never rewrite history.

### 2026-08-06 — P2-3 complete (`ProfileModel.ulid` is `required String`; compiler-enforced identity)

Per `docs/planning/firestore-phase2-plan.md` §4 P2-3, executed as a three-part
agent brief (A: model + codegen + `lib/` fixes; B1/B2: the two test-file
halves; C — this entry — closes and commits). `ProfileModel.ulid` is now
`required String`, not `String?`; the "NULL means not yet migrated" comment
is deleted. `ProfileModel.fromDriftRow` is the enforcement point (the Drift
column itself stays nullable, per plan): on a `null` `row.ulid` it throws a
named `StateError` —
`'ProfileModel.fromDriftRow: profile id $id has no ulid — pre-P2-2 profile
row with no ULID — wipe and reseed the device'` — no silent fallback
anywhere, verified by grep across every touched `lib/` file for
`ulid ?? `/`ulid?.`-shaped fallback patterns (none found). `SelectedProfileId.select`
is now `void select(int id, {required String ulid})`, closing the third bare
call site the type system couldn't previously prevent. Codegen
(`dart run build_runner build --delete-conflicting-outputs`) regenerated
`profile_model.freezed.dart` and `profile_providers.g.dart` in the same
commit, plus three transitively-affected `.g.dart` files whose provider
hashes shifted (`user_database.g.dart`, `completion_providers.g.dart`,
`scheduler_providers.g.dart`) — all mechanical.

**Part C's own fix, beyond stitching A/B1/B2 together:** `dart analyze
--fatal-infos` on hand-off showed exactly the one error B2 had flagged and
declined to guess at —
`test/features/profiles/presentation/providers/profile_providers_test.dart:40`,
a test titled *"select() without a ulid clears activeProfileDocIdProvider"*.
Per the GREENFIELD ruling and `select`'s new signature, a caller omitting
`ulid` is no longer a legal call — the scenario this test existed to pin
cannot be constructed any more. Supplying a literal `ulid:` to make it
compile (as B2 correctly judged) would silently flip the immediately-following
`expect(activeProfileDocIdProvider, isNull)` to a guaranteed-false assertion,
and would falsify both the test's name and its own docstring. **Fix: deleted
the test** (lines 35–44), leaving the file's other two tests (`select()` with
a known ulid; `clear()`), both of which already exercised the real, current
contract and needed no change. This is a deliberate test-behavior change, not
a mechanical patch — recorded here per the same rule P2-2 used for its own
rewritten assertions.

**Gates (verbatim, run after `dart format`, all four confirmed a second time
post-format):**
```
$ dart analyze --fatal-infos
Analyzing learning_tracker...
No issues found!

$ dart run tool/check_profile_path_keying.dart | tail -1
PROFILE-KEY-SPLIT check OK: 2 collection(s) currently split (bookmarks, learning_order), all within the tracked baseline (0 new violations).

$ dart run tool/check_profile_id_int_sites.dart | tail -1
PROFILE-ID-INT-SITES OK: 88 tracked site(s) across 5 pattern(s) [cf-int-guard, cf-string-profileid-doc, dart-int-profileid-param, dart-tutoring-int-parse, dart-tutoring-id-tostring]; 0 new, 0 stale.

$ make audit | tail -1
=== audit PASSED — all 68 greps clean ===   (104/104 checks)

$ dart format <61 touched .dart files>
Formatted 61 files (0 changed) in 0.69 seconds.
```
All four match the plan's prediction (§6 P2-3: *"`dart analyze` green is a
**complete** proof here... This is the one step in the phase where the cheap
gate is sufficient."*) — no deviation on any of the four gates themselves.

**DEVIATION — test-file blast radius vs. the plan's original prediction**
(surfaced by part A, confirmed unchanged by part C; recorded here since this
is the commit that lands it):
- **Predicted** (`firestore-phase2-plan.md` §4 P2-3): "43 test files / 67
  occurrences."
- **Actual, measured:** **47 test files / 83 occurrences** fixed by B1+B2,
  plus **1 additional file** (`profile_providers_test.dart`, 1 occurrence)
  that part C resolved by deletion rather than by adding `ulid:` — so the
  true total touched-file count for this commit is **48 test files**.
- **Why the prediction was wrong (mechanism, not a person):** the plan's
  blast-radius count was taken against tree `d74e3829` at plan-synthesis
  time, before P2-1 and P2-2 executed. P2-2 itself added new call sites in
  the same population it was later measured against (its own log entry
  above records 8 files/~13 closures for the widened `setSelectedProfileId`
  type, and a new `_FakeProfileRepository` override) — `auto_selected_profile_id_test.dart`
  appears in both P2-2's touched-file list and P2-3's error list, confirming
  test-file churn between plan-writing and P2-3 execution as at least a
  partial cause. Not every one of the extra files/occurrences was
  exhaustively attributed to a specific prior commit.
- **Invariant unaffected:** check 103's OK line/split set and check 104's
  count/scan-set are byte-identical before and after this commit.

**Deferred (D1, per the plan's own table, unchanged from P2-2):** `make
test` was not run. The 47 fixed + 1 deleted test files compile but were not
executed — a green compile proves the fixture shape changed, not that the
retained assertions still pass or that no test now asserts on a value it no
longer meaningfully varies (e.g. the `ulid: 'ulid-$id'` convention used at
`select()` call sites that assert only on the returned int id). Left for the
end-of-cutover CI phase.

### 2026-08-06 — P2-2 complete: eager unconditional ULID mint; lazy backfill deleted

Per `docs/planning/firestore-phase2-plan.md` §4 P2-2. `ProfileRepositoryImpl.createProfile`/
`ensureDefaultProfile` now mint via `DocIds.mintProfileUlid()` and write the
`ulid` into the SAME Drift insert that creates the row — no more window
where a row exists with `ulid IS NULL` on a path this adapter controls.
`FirestoreProfileRepositoryAdapter` deleted `_mintAndActivateFirestoreProfile`
and `setProfileUlid`/`ProfileDao.setUlid` entirely; replaced with
`_ensureFirestoreProfile`, an idempotent create-if-missing
`set(..., SetOptions(merge: true))` that never mints (the id is always
already on the model it's handed). `FirestoreLearnerProfileRepository.createProfile`
now takes a REQUIRED `profileId` and deleted its own internal mint, so
exactly one site in the whole codebase mints a profile's identity — the
adapter, which threads the same value into both the Drift row and the
Firestore document, closing the "two independent mints for one profile"
trap the brief called out. `ProfileDao.upsertTutoredProfile`'s insert branch
now sets `ulid: Value(remoteChildProfileId)` — the tutored mirror records
the remote child's own id, never mints a fresh one (T-31's decoupled line
item). The two bare `select(id)` call sites
(`notifications_bootstrap.dart`'s `onSwitchProfile`, `router_provider.dart`'s
`ProfileGuard` wiring) now resolve the profile and pass `ulid:`.

**Interface-change design, recorded because the brief flagged it as the
trap to not improvise on:** `ProfileRepository.createProfile`/
`ensureDefaultProfile` gained a new `String? ulid` parameter each —
**optional, not required.** Dart's override rules (verified empirically:
adding a new *required* named parameter in an implementing class, or
promoting an *optional* interface parameter to *required* in an override,
are both `invalid_override` compile errors; an override MAY relax
required→optional but never the reverse) meant a `required` parameter on
the abstract interface would have forced every caller reachable through
that interface — including the two screens that call `createProfile`
(`add_profile_dialog.dart`, `onboarding_profile_creation_step.dart`) and
`profile_providers.dart:184`'s `ensureDefaultProfile` call — to supply a
`ulid:` themselves. Those callers cannot legally mint one: `DocIds` lives
at `lib/data/firestore/doc_ids.dart`, and `check_dependency_direction.dart`
(audit check 102) forbids any `lib/features/**` file outside its own
`data/repositories/` from importing `lib/data/**`. So the parameter is
optional at the interface; `FirestoreProfileRepositoryAdapter` (which lives
in an exempt `data/repositories/` directory) is the only real caller that
ever supplies a value, and `ProfileRepositoryImpl` falls back to minting
its own (`ulid ?? DocIds.mintProfileUlid()`) for any caller that bypasses
the adapter (bare construction, some tests) — so the eager-mint invariant
holds universally, not just on the adapter's path. This kept the blast
radius to exactly what `dart analyze` needed to prove: zero screen
call-site changes, one `_FakeProfileRepository` in
`auto_selected_profile_id_test.dart` (explicit `implements ProfileRepository`
override needed the new param — Mockito `Mock`-based fakes elsewhere in the
suite needed nothing, since `noSuchMethod` fallback isn't checked against
the interface shape the same way).

**A second, separate override-rule consequence hit `ProfileGuard`'s
`setSelectedProfileId` callback**, which is a plain closure VALUE, not a
method call — Dart's function-subtyping rules (also verified empirically)
do not let a shorter-arity closure (`void Function(int)`) satisfy a
longer-arity function-typed parameter, even when the extra parameter is
optional, the way a method call CAN omit an optional argument. So widening
`setSelectedProfileId`'s type to `void Function(int, {String? ulid})`
mechanically rippled into every test constructing
`ProfileGuard(setSelectedProfileId: ...)` — 8 files, ~13 closures, each a
one-line arity widening. `router_provider.dart`'s wiring stayed fully
synchronous (`ProfileGuard` already holds the full Drift row —
`profiles.first.ulid` — at its call site, so no extra DB read or async gap
was needed, preserving the exact synchronous-only contract
`SelectedProfileId.select`'s own doc comment requires of a route-guard
caller). `notifications_bootstrap.dart`'s `onSwitchProfile` callback, by
contrast, was made to resolve the profile asynchronously before selecting —
its type stays `void Function(int)` (fire-and-forget, allowed because
nothing downstream synchronously awaits a notification tap's selection the
way a route guard's `resolver.next()` does).

**Doc comments fixed in the same commit (their claims went false):**
`learner_profiles.dart`'s `ulid` column comment ("NULL means not yet
migrated" / lazy-backfill description); `profile_repository_impl.dart`'s
`FirestoreProfileRepositoryAdapter` class comment ("Backfill policy... lazy,
on edit — not eager"); `profile_providers.dart`'s `SelectedProfileId.select`
comment ("a caller with only a bare int... omits ulid" — both such callers
are fixed now); `firestore_learner_profile_repository.dart`'s "Doc-id"
section (no longer mints) and its `tutorEditProfile` "SAME document" claim,
annotated per R7 as verified false today and staying false through the rest
of Phase 2 (tutoring re-keys in Phase 3, not this commit).

**Test behavior deliberately changed, not just made to compile:** the
"updateProfile lazily backfills a missing ulid" test in
`profile_repository_impl_test.dart` pinned exactly the behavior this commit
deletes; rewritten to assert the new reality (a pre-P2-2 legacy profile's
`ulid` stays `null` through an edit — wipe-and-reseed is the remedy, not a
mint-on-edit path). `firestore_learner_profile_repository_test.dart` was
rewritten throughout: `createProfile` no longer mints, so its 15 call sites
now pass explicit literal `profileId`s and the "two distinct ids" test
asserts on caller-supplied ids rather than on minting uniqueness; added one
new test for the create-if-missing idempotency this commit introduces
(calling `createProfile` twice for the same id writes one document, not
two).

**Gates:** `dart analyze --fatal-infos` → `No issues found!` (after fixing
30 analyzer-flagged sites — 15 in the Firestore-repo test file, 12 across
the `ProfileGuard`-callback test files, 2 in `_FakeProfileRepository`, 1 the
`router_provider.dart`/`profile_guard.dart` production wiring itself —
matching the plan's prediction that the interface change would be
analyzer-visible at every caller including under `test/`). Check 103's OK
line and split set unchanged (`learner_profiles` is not in its registry).
Check 104 unchanged at 88 tracked sites, 0 new, 0 stale (profile identity
is outside its scan set by design). `make audit` green, 104 checks, `=== audit
PASSED — all 68 greps clean ===`. No deviation from the plan's predicted
gate table (§4 P2-2) — all four predictions held exactly.

**Deferred (D1, per the plan's own table):** `make test` was not run
(out of scope for this phase's gates). The rewritten/edited test files
compile but were not executed; a green compile is not evidence the
retired/rewritten assertions pass. Left for the end-of-cutover CI phase.

### 2026-08-06 — P2-1 complete: audit check 104, PROFILE-ID-INT-SITES

Built `tool/check_profile_id_int_sites.dart` + `tool/profile_id_int_sites_baseline.txt`
per `docs/planning/firestore-phase2-plan.md` §4 P2-1. Named-entry ratchet
keyed by `<pattern-id> <file>:<enclosing-symbol>` (never a line number): a
NEW entry fails, a STALE baseline entry (present in the baseline but absent
from the current scan) also fails. Baseline carries the required sentinel
(`# format: profile-id-int-sites v1` + a `# pattern-hash: <hex>` line); a
missing/sentinel-less baseline exits 1, and — a strengthening beyond the
plan's literal ask — the hash is also *verified* against the live pattern
list on every run, not just recorded, so a scanner change without a matching
`--update-baseline` fails closed too. Wired into `Makefile` immediately after
the 103 block (no renumbering — denominators are per-group), added
`check-profile-id-int-sites` to `ci:`, and added the gate to this log's Step
4 in the same commit.

**Deviation — measured count vs. the plan's prediction:**
- **Predicted:** "~31 entries" (`firestore-phase2-plan.md` §4 P2-1, §8).
- **Actual:** **88 entries** (`cf-int-guard` 17, `cf-string-profileid-doc` 5,
  `dart-int-profileid-param` 61, `dart-tutoring-int-parse` 2,
  `dart-tutoring-id-tostring` 3) — verified via `--report`'s per-pattern
  counts, each matching an independent `grep -c`/`grep -n` count against the
  live tree.
- **Why the prediction was wrong (mechanism, not a person):** the plan's
  `dart-int-profileid-param` pattern description named
  `firestore_gateway.dart` and `outbox/push_pipeline.dart` as
  "interface-level only" scan targets but did not state a per-file count,
  unlike every other pattern in the same list (which all cite their
  population explicitly — 17, 5, "all six"). Both files are genuinely
  *pure* abstract interfaces (`abstract class FirestoreGateway`/
  `PushPipeline`, zero implementation) with one `int profileId`-typed method
  per collection-operation — 28 and 20 sites respectively, verified by
  direct count, not estimate. Whoever wrote "~31" was almost certainly
  eyeballing a smaller number of representative sites rather than expanding
  each interface's full method list. The other four patterns' raw
  occurrence counts (17, 5, 13-of-61, 2, 3) already sum past 31 on their
  own before the interface files are even added, which the plan's own §7 R2
  register anticipates in spirit ("179 `int profileId` occurrences under
  `lib/core/sync/**` alone" is cited there as the reason NOT to demand an
  empty end-state) — a large tracked count is consistent with the gate's
  own design rationale, not a symptom of a broken scanner.
- **Invariant unaffected:** the four load-bearing design corrections (named-
  entry ratchet with no empty-state requirement; OK line prints its scan
  set; baseline sentinel; pattern-vs-code commit separation) hold regardless
  of N. Check 103's OK line and split set are confirmed byte-identical
  before and after this commit (`PROFILE-KEY-SPLIT check OK: 2
  collection(s) currently split (bookmarks, learning_order), all within the
  tracked baseline (0 new violations).`). `make audit` is green with 104
  checks.

**Two implementation defects found and fixed during construction, before the
baseline was ever generated** (same spirit as Phase 1's adversarial-
verification list below — recorded because a ratchet whose own construction
silently miscounted would be exactly the "gate reports a fix that never
happened" failure mode §4 P2-1 warns against):
1. **Premature scope-pop on multi-line signatures.** The brace-depth scope
   stack popped a just-pushed function frame on the SAME line it was pushed
   whenever that line's own net brace delta was zero — true for every
   multi-line TS function signature (`async function verifyTutorGrant(` has
   no brace at all; the body's `{` arrives 6 lines later) and every bare
   single-line abstract Dart method ending in `;` with no body
   (`Future<void> deleteLearnerProfile(int profileId);`). Fixed by adding an
   `opened` flag to each frame, set only once depth genuinely exceeds the
   frame's push-time depth, with a separate immediate-pop rule for a
   still-unopened frame whose line ends in `;` (an abstract signature that
   never opens a body at all). Caught by hand-tracing `verifyTutorGrant`
   against independent debug scripts before the real baseline was ever
   written.
2. **Nullable generic return types silently failed the whole Dart
   function-declaration regex.** `Stream<Map<String, dynamic>?>` and
   `Future<Map<String, dynamic>?>` (both real return types in
   `firestore_gateway.dart`) do not match a character class that omits `?`
   — regex alternation doesn't partially match, so the entire alternative
   failed and no frame was pushed for `listenToDocument`/`fetchDocument` at
   all. Both `int profileId` sites then silently fell back to the same
   bare `FirestoreGateway`-only symbol and **collapsed into one entry**,
   dropping one real site from the count without any error. Fixed by adding
   `?` to the generic-argument character class; verified by re-running
   `--report` and diffing every file's reported line numbers against an
   independent `grep -nE` count until all five patterns' printed counts
   equal their raw `grep -c` counts exactly (17/5/61/2/3 — no further silent
   collapses).

**Ratchet verified to actually fire (§6 P2-1's required red-demo):** added a
throwaway `typeof profileId !== "number"` guard in a scratch
`functions/src/_scratch_ratchet_probe.ts`, ran the gate — `PROFILE-ID-INT-SITES
FAILED — 1 NEW int-keyed profile-identity site(s)`, exit 1 — then deleted the
scratch file and re-ran — `PROFILE-ID-INT-SITES OK: 88 tracked site(s) ...
0 new, 0 stale`, exit 0. `git status --porcelain` confirmed the scratch file
left no trace.

**Process note:** this session did not append an IN FLIGHT entry before its
first edit (see CURRENT STATE above) — flagged, not silently corrected.

### 2026-08-06 — Phase 1 complete (`a2a21d0a`)

Built audit check 103 (`tool/check_profile_path_keying.dart`) + baseline +
`test/helpers/writer_reader_agreement.dart`. Baseline is exactly `bookmarks`
and `learning_order`. Wired into both `make audit` and `make ci`.

Adversarial verification found five defects, all fixed with reproductions:
gate never scanned `lib/features/**/data/repositories/` (where the adapters
live); reachability recognised one naming convention only, while the watchlist
promised otherwise; class regex missed Dart 3 modifiers (70 files use them);
unreadable files now ABORT loudly rather than reclassify; **reachability
counted doc comments and string literals as evidence — both baseline entries
were classified live off a doc comment, right by luck.**

Deviation: the gate ships **green**, not red as planned — both live splits are
baselined, which is the same information as "0 new violations". Burn-down
property unchanged.

Late defect caught by `make audit` at the phase boundary: the new helper test
declared a second `main()` under the libraries-only `test/helpers/`. Moved to
`test/writer_reader_agreement_helper_test.dart`. Invisible to analyze and to
the keying gate — the reason `make audit` stays per-phase.

### 2026-08-04 — Phase 0 decisions (`9a5cb97c`)

D1 tutor identity → re-file under ULID (value migration, not redesign: the
rules formula and `acceptInvite` already agree; only what `profileId` *is*
changes). D2 overdue backlog → restore both forgiveness paths; **cost was
under-stated to the owner** — the content-reseed half needs a new mechanism.
D3 learning-order reset → narrow client-delete allowance, `goals` precedent.

### 2026-08-04 — Cutover plan written (`70f23979`)

Five phases, gates first.

### 2026-08-03 — Bookmarks vertical slice (`5b4d7924`)

Took the smallest feature with real UI consumers end-to-end to convert an
estimate into a measurement. 71 files, +2354/−915.

**Result: feature-by-feature migration is impossible here.** Flipping bookmarks
stranded track-creation, learning-order and tutoring; fixing the learning-order
writer then stranded the scheduler's reader. Six regressions in four untouched
features. Every one passed the test suite.

Also found: the tutor read path documented in `firestore-rewrite-map.md` is
**rules-denied as written**; three owner-path Cloud Functions would silently
delete nothing post-cutover; `make ci` had been red on `dev` since the B2 wave
(a Rule 5 violation `make audit` cannot see, plus two re-export shims with no
lcov entry).

**Recovery events this session** (both survived without loss because work was
committed promptly): a workflow hit the session limit with 9/16 agents done,
leaving the tree built but entirely unverified; and a user interrupt stopped 48
agents mid-flight. Commit early — that is what made both recoverable.

---

## Convention for agent briefs

Every agent brief for this migration MUST require the agent to:

1. **Read this file first** and follow the recovery protocol.
2. **Report** — not silently absorb — anything contradicting the standing facts
   above.
3. Never `git stash`, never branch, never worktree, never commit or push —
   **except under the A1 override below.**

**A1 override (binding for Phase 2, recorded 2026-08-06):** for Phase 2, the
implementing agent **does** commit, at the named commit boundaries only (the
`P2-n` sequence in `docs/planning/firestore-phase2-plan.md` §5), and rewrites
`CURRENT STATE` truthfully in that same commit. This is a brief-level
exception to point 3 above, not a repeal of it — never-stash, never-branch,
never-worktree remain absolute with no exception, in Phase 2 or any other
phase. A brief for a later phase that wants the same exception must state it
explicitly; it does not carry forward by default.

The **coordinator** appends an entry here when a phase lands, when a session
dies mid-work (recording exactly what was in flight), and when a finding
changes the plan. Entries are append-only.

---

## Known stashes — UNDISPOSITIONED-REPORTED

Identified below by **base commit**, not by `stash@{N}` index — the index is
positional and reorders every time a stash is pushed or popped, which already
happened once during the P2-0 session that wrote this section (see the second
entry). Do not pop, apply, or drop either stash based on this entry; nobody
has ruled on either.

### Stash on base `8855b9b1` (pre-existing, predates this cutover)

Measured facts (verified 2026-08-06):
- Base commit `8855b9b1` — `fix(tracks): AUD-tracks-18 - de-duplicate
  Hebrew-script detection regex`, dated 2026-07-19 (18 days old at time of
  writing, predates this cutover's first commit `5b4d7924` by two weeks).
- Label: `(no branch)`.
- Base is **not an ancestor of `dev`** and is **contained by no branch** —
  `git branch --contains 8855b9b1` returns nothing.
- Contents: two generated `*.g.dart` Riverpod provider files. Their subject
  does not match the stash's own label (`(no branch)` names no subject at
  all, so there is nothing for the contents to confirm or contradict — the
  mismatch is that generated codegen output was stashed rather than just
  regenerated).
- Reflog: `refs/stash@{2026-07-19 12:08:06 +0200}`.

### Stash on base `d74e3829` (appeared mid-session, during P2-0 itself — see the risk note below)

Measured facts (verified 2026-08-06, immediately on discovery):
- Base commit `d74e3829` — the commit that was `dev`'s HEAD for almost all of
  the P2-0 session that wrote this file (superseded by `b076006c` once P2-0
  landed).
- Label: `WIP on dev: d74e3829 docs(planning): durable task list + recovery
  log; mark Phase 1 resolved` — i.e. an ordinary `git stash push` label, not
  `(no branch)`.
- Reflog: `refs/stash@{2026-08-06 19:52:02 +0200}`, authored under this
  session's own configured git identity (`Daniel Niasoff
  <daniel@orvex.ai>`).
- Contents: the 8 pre-existing `_bmad/**` regenerator-noise files (the ones
  this log's brief convention already says to never stage or commit), **plus
  a partial, superseded copy of this same commit's own log edits** — the
  `Head:`/`Deployed:` fix and the IN FLIGHT protocol section, but *not* the
  A1 override or this stash section, i.e. a snapshot taken partway through
  P2-0's own edit sequence.
- **No data was lost.** The complete, correct version of every edit this
  stash partially captured is in commit `b076006c`, verified by diff before
  that commit was made. This stash's copy is strictly a stale subset.

**Risk note, not yet in the risk register proper (R13 candidate for whoever
next touches §7 of the phase plan):** P2-0 did not run `git stash` at any
point — no `git stash` invocation appears in its command history — yet a
stash matching this session's git identity materialized mid-edit, and the
working tree was observed reverted to the pre-stash state immediately after
(a live grep showed the just-written `Head:`/`Deployed:`/IN FLIGHT edits
gone, and `git status --porcelain` showed the 8 `_bmad` files clean when
they had been dirty at session start). **Mechanism unidentified** — some
process in this environment other than the executing agent creates stashes
autonomously and can catch uncommitted document edits, not only the `_bmad`
regenerator churn it was presumably scoped to. The concrete consequence for
every future step in this phase: **do not treat a `git status --porcelain`
read as trustworthy for more than the instant it was taken.** Re-verify
immediately before every `git add`, and if a just-written edit is missing on
re-read, check `git stash list` before assuming the edit tool failed.
