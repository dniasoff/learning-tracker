# Phase 3 handoff — Firestore cutover, "Wire and move"

**You are a fresh agent with no memory of Phase 2.** This prompt is the entire
context you need to start. It was authored by Phase 2's own closing round
(P2-35), from Phase 2's own measured state, per this project's Working
Protocol rule 15 ("each phase's CLOSING step authors the NEXT phase's handoff
... never speculatively, in advance"). Everything below is either a standing
owner instruction, a fact re-derivable from the repo, or a number explicitly
attributed to who measured it and at which commit. Where a number is a "last
known" figure rather than something you yourself measured, it is labeled as
such — re-measure it before you trust it (§2 tells you how and why).

Repo: `/home/daniel/repos/learning-tracker`. App: `learning_tracker/`. Branch:
`dev`. This document lives at `docs/planning/phase3-handoff.md`.

---

## 0. Owner's standing operating instructions (verbatim in effect)

These are not Phase-3-specific; they are how this owner runs every phase of
this project. Follow them without being asked again.

1. **Use ultracode multi-agent orchestration (the Workflow tool).** Sonnet
   subagents do the actual work (reading, editing, running tests). Opus
   subagents do code review, planning, adversarial verification, and design.
   The main loop coordinates and does no work itself.
2. **Run autonomously. Make sensible decisions without asking.** The owner
   has granted standing authority to override his own earlier rulings when
   they are demonstrably producing bad outcomes — when you do, report what
   you overrode and why, in the same commit's log entry.
3. **Never push. Never deploy. Never create a branch or a worktree. Never
   `git stash`. Never `git add -A`.** Local commits on `dev` only, explicit
   paths staged by name (`git status --porcelain | grep -v '^ M _bmad'` to
   check what's dirty before staging — `_bmad` churn is pre-existing and not
   yours to touch).
4. **GREENFIELD.** No live users, no data worth preserving. Never build
   backfills, migrations, dual-write bridges, version gates, rollout flags,
   or back-compat readers. Delete the old path in the same commit that adds
   the new one. Prefer REMOVING a divergence over ADDING a guard.
   Correctness is not relaxed by this ruling — it only removes the need for
   transitional machinery. This ruling is what let Phase 2 close `T-49` by
   deleting a write instead of relocating it a fifth time (Working Protocol
   rule / trap #1, §5 below) — expect the same shape to be the right answer
   repeatedly in Phase 3.
5. **`T-30`/`T-31` (tutoring) are IN Phase 3**, re-phased out of Phase 2 by
   an owner ruling (`firestore-phase2-plan.md` §3, Q1, 2026-08-06) because
   their coupling is blocking, not stylistic — see §4 below for the
   evidence. They land as ONE commit-unit with `T-20`, not before it.
6. **A doc comment your change makes false gets fixed in the SAME commit, in
   the CODE, not only in the `.md` files.** A docs-only round may DISCLOSE a
   false code comment it finds (name a task, quote the false text), but
   cannot CLOSE it. This recurred three times in Phase 2 (`T-50`, `T-49`,
   `T-67`) each costing an extra round. Don't let it recur a fourth time.

---

## 1. Read-first order

Read in this order, before writing any code:

1. **`docs/planning/firestore-cutover-log.md` — IN FULL.** This is the
   recovery log: recovery protocol, IN FLIGHT protocol, the Working
   Protocol (binding for Phases 3/4/5 — 15 numbered rules), `CURRENT
   STATE`, Standing Facts, the PHASE 2 RETROSPECTIVE, then the dated
   `### ` entries (newest first — `## Entries` is append-only, oldest never
   rewritten, only superseded in place). **Two structural quirks to know
   before you read it:**
   - `CURRENT STATE` is a single-valued snapshot, NOT part of the
     append-only history below it — always read it fresh, not
     incrementally, and note that by the end of Phase 2 it still contained
     several nested "(Superseded paragraph below, from P2-N...)" chains
     that a future round is explicitly invited to collapse (Working
     Protocol rule 8) — don't mistake a superseded paragraph for the
     current one.
   - Numbered sub-tables inside individual dated entries (the
     deferred-verification table, the Phase 3 ENTRY CRITERIA checklist) are
     versioned with letter suffixes as they get superseded — `§10`, `§10a`,
     `§10b`, `§10c`... and `§11`, `§11a`, `§11b`, `§11c`... — **always read
     the HIGHEST-lettered variant**, and note that a later round's
     superseding table is sometimes appended physically inside an EARLIER
     round's dated entry (immediately above the table it supersedes,
     because the convention is "supersede in place at the point of the
     original claim," not "append at the bottom of the file"). Grep for the
     highest letter (`grep -n "^#### 1[01][a-z]*\."`) rather than assuming
     position-in-file means chronological order.
2. **`docs/planning/firestore-cutover-plan.md`** — the phases and the
   anti-slop protocol. As of Phase 2's close, Phase 3/4/5 each carry their
   own "Entry criteria and traps" subsection (added 2026-08-09), which is
   Phase-3-specific detail this handoff summarizes but does not replace —
   read Phase 3's subsection there directly (`### Phase 3 — Wire and move`).
3. **`docs/planning/firestore-cutover-tasks.md`** — the durable, single
   source of truth for task status. Every task id this handoff cites has
   its full evidence in that file's own row; this handoff does not
   duplicate it, only points at it.
4. **`docs/planning/firestore-phase2-plan.md`** — read this only as a
   WORKED EXAMPLE of what a frozen phase plan looks like. It is
   self-stamped "tree `d74e3829`," predates all seven rounds of the `T-49`
   saga, and its line-number citations are long stale. Do not treat any
   fact inside it as current — it records Phase 0/2 decisions (notably the
   `T-30`/`T-31` re-phasing ruling in §3, Q1) that are still binding, but
   for anything about the CODE, prefer the log.
5. **This document**, `phase3-handoff.md` — you're reading it.

The recovery protocol (log.md's own §"Recovery protocol", lines 15-46) says
to run it BEFORE reading the plan or the task list. This handoff reorders
that slightly only because you need the log's own content to know what the
recovery protocol even checks against — but §2 below is still your first
ACTION, before any code edit.

---

## 2. FIRST ACTION: re-establish the suite baselines yourself

**Read this before touching any code.** The full test suites (`make test`,
`make test-rules`, `make test-functions`, and the three cheap gates) were
LAST RUN by the round-7 independent verifier at commit `6655f184`, and
LAST RE-CONFIRMED as still attributable to the current code (via an empty
`git diff --stat 17134b43..HEAD -- learning_tracker/lib learning_tracker/test`)
at commits `f2f59e6e`, `14860643`, and `677262fd` — every one of those
re-confirmations was a **read-only tree-identity check**, not a fresh test
run. **No agent has actually re-run the full suites since `6655f184`.** This
matters specifically to you: inheriting an unmeasured baseline means you
cannot tell YOUR first regression from one you inherited unmeasured. Do not
start editing code on the strength of the numbers in this document — they
are LAST KNOWN, not a warranty.

Run this now, before any edit:

```bash
cd /home/daniel/repos/learning-tracker
git log --oneline -5
git rev-list --left-right --count origin/dev...dev   # want: 0 <n> — never push
git status --porcelain | grep -v '^ M _bmad'         # _bmad churn is pre-existing, ignore it
git stash list                                        # want exactly 2 — see §8, a 3rd is a RED FLAG
pgrep -af "flutter[ ]test"                            # orphaned test process check — this machine has
                                                       # held one for 4+ days before; it burns CPU and
                                                       # skews timing you observe

cd learning_tracker
dart analyze --fatal-infos
dart run tool/check_profile_path_keying.dart
dart run tool/check_profile_id_int_sites.dart
make audit                       # MUST run from learning_tracker/, never the repo root — see §7
make test                        # ~8.5 min
```

Then, ONE AT A TIME with ports confirmed free first (`ss -ltnp | grep -E
':8080|:9099|:4400'`):

```bash
make test-rules
make test-functions
```

**LAST KNOWN numbers to compare against** (all measured by the round-7
independent verifier at commit `6655f184`, code-identical to `17134b43` —
the commit that actually landed Phase 2's `T-49` fix — and reconfirmed
identical, by tree-diff only, through `677262fd`):

| Command | Last known result | Last actually measured at |
|---|---|---|
| `dart analyze --fatal-infos` | `No issues found!`, exit 0 | `6655f184` |
| `dart run tool/check_profile_path_keying.dart` (check 103) | `PROFILE-KEY-SPLIT check OK: 2 collection(s) currently split (bookmarks, learning_order), 0 new violations`, exit 0 | `6655f184` |
| `dart run tool/check_profile_id_int_sites.dart` (check 104) | `PROFILE-ID-INT-SITES OK: 88 tracked entries covering 91 site(s) across 5 pattern(s); 0 new, 0 stale, 0 changed`, exit 0 | `6655f184` |
| `make audit` | `104/104 checks; === audit PASSED — all 68 greps clean ===`, exit 0 | `6655f184` |
| `make test` | `08:54 +11527 ~131: All tests passed!`, exit 0 | `6655f184` |
| `flutter test test/features/profiles/` | `00:12 +441: All tests passed!` (433 baseline + 8 new) | `6655f184` |
| `make test-rules` (alone) | `pass 116 fail 0`; TQ-9: all 37 conditional allow rules evaluated at least once | `6655f184` |
| `make test-functions` (alone) | `pass 337 fail 0` | `6655f184` |
| `dart format --output=none --set-exit-if-changed` (9 touched files) | `0` changed | `6655f184` |

**NOT measured since round 5 — two code commits before `17134b43` — do not
treat these as current:**

| Command | Last known result | Last actually measured at |
|---|---|---|
| `make validate-calendar` | `OK: 62068 expected (program, date) pairs all present, every ref resolves`, exit 0 | `~3872fdbc` |
| `make test-serial-tools` | `32:16 +38 ~1: All tests passed!`, exit 0 (the `~1` is `T-38`'s pre-existing disclosed skip) | `~3872fdbc` |

**Never run, this cutover or any prior phase:** `make ci` in a single
invocation (owner policy batches it to the end of Phase 4 — seven of its
nine targets have each run standalone; `validate-calendar` and
`test-serial-tools` are the two that haven't, above; this is tracked as
open task `T-69`).

**Coverage** (`coverage/lcov.info`): `469470` bytes as of 2026-08-07 07:25;
R6d (`check_lcov_denominator.dart --strict`) last explicit result (P2-21):
`76` zero-coverage files, `0` new violations — not re-measured since, though
`make test` regenerates the file on every run.

If anything above comes back different from what you just measured: name
the difference explicitly (predicted / actual / mechanism / whether any
invariant is affected — see the deviation-reporting shape used throughout
`firestore-cutover-log.md`). Do not silently update the number in your head
and move on, and do not assume a difference is a regression you caused
before checking whether it predates your first edit.

**A killed test run manufactures fake red tests.** Before reading any
suite's failure count, check for a `Terminated` line and an explicit
`EXIT=` code. A `make test-serial-tools` attempt during Phase 2 ended
`09:14 +19 ~1 -1` with a `Bad state: Cannot close sink while adding stream`
error and no `EXIT=` line at all — that is a killed process (a session
limit or timeout), not a code failure, and the lane is still open (`T-69`)
because of it, not because of a real red test.

---

## 3. Where Phase 2 landed

**Verdict:** `T-49` (the phase's one SERIOUS code defect — a
write-after-await race on `activeProfileDocIdProvider`, the provider that
keys all 13 profile-scoped Firestore providers) is **CLOSED, by REMOVAL**,
in commit `17134b43` (`fix(profiles): delete the T-49 activation write
instead of hoisting it a fifth time`). `FirestoreProfileRepositoryAdapter`
no longer writes `activeProfileDocIdProvider` on any path; `select()` in
`profile_providers.dart` is the sole activation seam. This closure is
**confirmed by a review independent of the fixing round** (the round-7
verifier, at commit `6655f184`), which is the mandatory step this project's
own rule requires ("a round cannot certify its own fix" — §5 trap #10,
below) — the four PRIOR closure attempts (P2-18, P2-23, P2-28, and the fix
P2-29 reviewed) each lacked this and each was later falsified.

**Phase 2 AS A WHOLE is recorded NOT RESOLVED**, per this project's own
DECISION RULE (a disjunction — ANY of: verdict incomplete, `safe_for_phase_3`
false, `still_open_unrecorded` non-empty, an unguarded post-await write
found, or a new blocking defect found ⇒ NOT RESOLVED, blockers named and
owned by task id, Phase 3 explicitly blocked). The rule fires here on
exactly one item: **`T-39`** — untouched by every one of Phase 2's seven
rounds, and Phase 3's own declared entry blocker (§10 below). The rule is
mechanical, not a judgment call on severity: `T-49` (the phase's only
SERIOUS code defect, across all seven rounds) is genuinely closed, and
`T-39` alone is still enough to keep the verdict NOT RESOLVED.

**What's live on Firestore (4, unchanged since before Phase 2):** bookmarks
· learning-order · profile identity · scheduler learning-order read.

**What's still int-keyed / dead (7 adapters, built, tested, never
constructed):** `FirestoreCompletionRepositoryAdapter`,
`FirestoreCurriculumTrackRepositoryAdapter`, `FirestoreGoalRepositoryAdapter`,
`FirestoreProgressRepositoryAdapter`, `FirestoreStageDefinitionRepositoryAdapter`,
`FirestoreStudyDayConfigRepositoryAdapter`, `FirestoreTrackLearningOrderRepositoryAdapter`.

**The scale of the move:** 135 files import the Drift database or its DAOs.
Net of `core/database` (25 files, the Drift layer itself — stays until
Phase 4) and `core/sync` (14 files, dies in Phase 4), **~96 feature files**
need to move in Phase 3.

**Full known-issues table, task id per item, one line each** (reproduced
from `firestore-cutover-log.md`'s §2 in the P2-33 entry — read each row's
own task-file entry in `firestore-cutover-tasks.md` for full mechanism and
evidence, not duplicated here):

| ID | Phase | Status | One-line note |
|---|---|---|---|
| `T-39` | 3 | **`todo` — SOLE DECLARED PHASE 3 ENTRY BLOCKER** | Reconcile check 103's WATCHLIST against `CURRENT STATE`'s "dead adapters" list before wiring anything; 5 gate names / 2 log names unmatched. Prerequisite for `T-20`. |
| `T-69` | 2 | `todo` (new, P2-33) | Re-run `make validate-calendar` and `make test-serial-tools` against the current code — neither has run since round 5, two code commits before `17134b43`. |
| `T-65` | 3 | `todo`, MINOR (P2-32) | Design residual R1 — six post-await `select()` call sites guarded only by widget/screen liveness, not a selection re-check. Strictly better than pre-Phase-2 (both providers now agree, even if on the wrong profile) — not closed. |
| `T-66` | 2 | `todo`, MINOR (P2-32) | The 14-case permanent T-49 matrix has no case for `ensureDefaultProfile`'s FAST path; GROUP-3's gate is unreachable on it by construction. Verifier's `E2-fast` probe went RED on the reverted tree, confirming a real, previously-unprobed site. |
| `T-67` | 2 | `todo`, MINOR as code / SERIOUS as an unqualified claim (P2-32, enriched P2-33) | CONTROL-4's regex has a demonstrated 40-character blind spot, PLUS an unnamed aliased-notifier evasion and a trailing-comment false-positive. The overbroad "structurally impossible" claim still stands in the test's own printed NAME (emits on every run). |
| `T-68` | 2 | `todo`, MINOR, pre-existing, dates to `a3c92d6c` (P2-32) | `profile_repository_impl.dart:617-619`'s doc comment claims a grep "returns every one of them and nothing else" for ~9 activation call sites; re-run, it returns 3 — the rest use a multi-line form the pattern can't match. |
| `T-44` | 2 | `todo`, MINOR (P2-13) | `T-41`'s refusal relocates the second-identity outcome (a fresh ULID mint) instead of preventing it. Needs a product decision. |
| `T-46` | 2 | `todo`, MINOR, informational (P2-13) | `T-41`'s export/import fix has no production caller. Correct hygiene, closes zero runtime risk today. |
| `T-55` | 2 | `todo`, MINOR, informational (P2-21) | ~60 further ulid-less test seeders beyond the 9 known/fixed instances, none currently failing. Needs a decision. |
| `T-60` | 5 | `todo`, MINOR (P2-26) | `T-58`'s fix excludes lines by bare substring match, not anchored like its sibling exclusion. Narrow today. |
| `T-37` | 3 | `todo` | Tutored read seam — owner-uid-scoped handles. Blocks D1's completion. Untouched by Phase 2. Detail in §4. |
| `T-38` | 5 | `todo` | Gate retarget + housekeeping folded together (check 104 into `T-23`, stale `all 68 greps clean` summary string, un-skip a now-false `skip:`). |
| `T-30` | 3 | `re-phased` | Owner-path CF deletes still key `learner_profiles` by the Drift int — moves with `T-20`. Detail in §4. |
| `T-31` | 3 | `re-phased` | Tutoring identity is Drift-int end-to-end — 13-read/9-write coupling. Detail in §4. |
| `T-20` | 3 | `todo` | Wire the 7 dead adapters, move ~96 feature files. Prerequisite: `T-39`. |
| `T-32` | 3 | `decided` | Reorder amnesty — both forgiveness paths restored by owner ruling; content-reseed half needs a NEW mechanism (no Firestore version field). |

**Device checks, still open, not task ids** (full deferred-verification
table: `firestore-cutover-log.md`'s §10c): `D10` (create a profile
offline, restore network, activate — highest-value remaining device check
in the whole cutover), `D11` (deploy `T-33`/P2-6's `firestore.rules` change
+ reset + negative control — TEST-VERIFIED 116/116 but still UNDEPLOYED,
the owner's call — §9 below), `D20` (code-level subject CLOSED by removal
this phase; the device observation itself stays open —
`fake_cloud_firestore` cannot model an offline queue plus a reconnect
ack, so no in-repo test substitutes for either D10 or D20).

---

## 4. Phase 3's scope

**The move, in order:** for each of the 7 dead adapters' collections, (1)
move every writer, (2) move every reader, (3) add the Phase-1 writer/reader
agreement test, (4) run `make ci` (not `make audit` — `make audit` is a
strict subset, §7). Order by DATA DEPENDENCY, writers before readers, not
by feature convenience. **Known reader/writer pairs that must move
together** (learned the hard way in earlier phases): track-creation →
bookmarks; learning-order → bookmarks *and* the scheduler's daily-task
projection; completion → bookmarks.

**Exit criteria:** zero files under `lib/features/**` import Drift. Phase
1's check baseline is empty. `make ci` green.

### `T-39` — do this FIRST, before wiring anything

Check 103's WATCHLIST and `CURRENT STATE`'s "dead adapters (7)" list are
**not the same set**. The WATCHLIST is dynamically computed by
`tool/check_profile_path_keying.dart --report` (every one of the 17
profile-scoped collections carrying a live INT writer opposite a DORMANT
ULID repo file); the dead-adapters list is a hand-maintained adapter-class
enumeration. Per `T-39`'s own row in `firestore-cutover-tasks.md`: 5
WATCHLIST collection names have no counterpart in the dead-adapters list,
and 2 dead-adapters entries have no WATCHLIST counterpart. Reconcile them
by RUNNING the actual `--report` output against the current tree — do not
infer the mapping from either list's prose. This is the prerequisite for
`T-20`.

### `T-30` — 3 owner-path Cloud Functions still int-keyed

`functions/src/deletes.ts`: `deleteLearnerProfile` (:135),
`deleteCurriculumTrack` (:214), `deleteBulkMarkedCompletions` (:406) —
each validates `profileId` as a positive integer and addresses
`learner_profiles/{String(profileId)}` (:225, :441). Post-cutover, unfixed,
they address a path holding no data: delete nothing, report success.
`deleteBulkMarkedCompletions` implements the owner's un-tick-a-bulk-mark
rule, so that feature would silently stop working with no error.
**Ordering trap:** `deleteLearnerProfile` must capture the profile's ULID
BEFORE the local delete removes the row —
`profile_repository_impl.dart:284` deletes the Drift row, `:291` calls the
sync engine, and the adapter at `:538-539` delegates straight through, so
a naive re-keyed implementation has nothing left to build the remote path
from by the time it tries.

### `T-31` — tutoring identity is Drift-int end-to-end

Owner decision D1 (2026-08-04): re-file under the ULID; the tutor reads
the parent's tree directly; the local mirror dies. **Coupling evidence,
why this could not land in Phase 2:** `TutoredProfileSelection.profileId`
is a live Firestore path segment on both sides — **13 read collections**
(`pull_pipeline.dart:73-98`) and **9 write collections**
(`tutor_writes.ts:187` + 12 call sites). For 11 of the 13 read
collections, the owner-side writer is still the int-keyed sync engine.
Re-keying tutoring's identity ALONE makes the tutor read a tree nothing
writes and write a tree nobody reads — **silently**: `pullForTutoredProfile`
counts no failures on an empty collection, so the pull "succeeds" into an
empty talmid, and no gate through Phase 3 can see a doc-id-formula
mismatch (neither check 103 nor check 104 covers doc-id formulas — §7).
**Site-count correction already made:** `manage_tutors_screen.dart`'s
`.id.toString()` sites are **six** (`163,173,206,293,298,312`), not three
— the omitted three include `outgoingTutorGrantsProvider`, which filters
`where("child_profile_id","==",…)`; converting only three would list a
child's grants under the old id while creating them under the new one.
Do not re-key one direction (reads or writes) without the other, and do
not re-key one of the 13 read collections without checking whether its
owner-side writer is still int-keyed.

### `T-37` — the tutored read seam (repairs a Phase-2-created regression)

P2-5 (Phase 2) hoisted a uniform refusal into
`_watchActiveAccountAndProfile` for all 13 profile-scoped providers during
a tutored session — correct, it closed a live latent corruption where the
other 12 providers (besides `bookmark_repository_impl.dart`, the only one
that had carried the check) silently served the TUTOR's own account+profile
tree. But the refusal sources `uid` from the signed-in account (the
tutor's own). **Substituting the profile ULID alone, without also
substituting the owner's `uid`, addresses `users/{TUTOR}/learner_profiles/
{talmid ULID}` — a brand-new WRONG tree, not the parent's.** The rules
already permit the correct read (`firestore.rules:450` + 16 sibling `allow
read: if isOwner(uid) || hasActiveTutorAccess(uid, profileId)` lines).
`T-37` needs an owner-uid-scoped HANDLE SEAM — feature wiring, not a
config flip or a value substitution. Blocks D1's completion.

### New Riverpod-chain trap for every adapter you wire

Every new provider chain — the 7 currently-dead adapters, `T-37`'s
owner-scoped handles — is a fresh Riverpod chain that may await
`activeAccountFirebaseProvider.future` or similar. **Declare `retry: (_,
__) => null` on it, or verify its test container came through
`bootstrap()`.** Riverpod 3's default per-provider retry
(`ProviderContainer.defaultRetry`) treats a structural exception (e.g. an
unauthenticated-account error) as retryable for up to ~6.4s per attempt,
~38s total backoff, before `.future` ever settles — and while retrying,
`AsyncLoading(retrying: true)` routes to `onLoading`, which does NOT
complete the `.future` Completer, so a bare test container hangs for the
full backoff. The app's ONE production `ProviderContainer`
(`lib/app/bootstrap/bootstrap.dart:68-81`) already disables retry
container-wide, so this is a test-harness-only risk, not production — but
it cost real debugging time twice in Phase 2 before the container-wide fix
was found, and every one of the 7 new chains reintroduces the exposure in
whatever bare test container first exercises it.

### Every "adapter" hides 4-6 awaits — enumerate before wiring

`FirestoreProfileRepositoryAdapter.createProfile`'s own chain — not fully
discovered until Phase 2's SIXTH round — hid four of
`ProfileRepositoryImpl`'s own awaits plus a durable-outbox enqueue that is
a **one-shot Cloud Function RPC** in a tutored session
(`TutoredWriteRouter.pushLearnerProfile` →
`tutored_write_router.dart:301-321`). None of it was visible from the
adapter's own signature or doc comments. Enumerate every await
TRANSITIVELY reachable from each of the 7 adapters' public methods before
wiring them — from the public entry point, not from the adapter's own
body (Working Protocol rule 2, trap #1/#2 in §5).

### Check 104's baseline is (mostly) T-30/T-31's own files

`tool/profile_id_int_sites_baseline.txt` (88 entries) sits almost entirely
inside the exact files `T-30`/`T-31` will edit: every `cf-int-guard`/
`cf-string-profileid-doc` entry is in `functions/src/deletes.ts` (T-30) or
`functions/src/tutor_writes.ts`/`tutor_bulk_completions.ts` (T-31); every
`dart-tutoring-*` entry is in `lib/features/tutoring/**` (T-31). The
`dart-int-profileid-param` entries against
`lib/core/sync/firestore_gateway.dart` and
`lib/core/sync/outbox/push_pipeline.dart` are interface-level and belong
to **Phase 4**, not Phase 3 — do not touch those baseline lines in this
phase. **Editing a T-30/T-31 file WILL change check 104's output**
(expected, not a regression) — the code fix and the matching
`tool/profile_id_int_sites_baseline.txt` edit MUST land in the SAME
commit.

---

## 5. Traps this phase proved are real — instructions, not anecdotes

Each rule below cost at least one full round of Phase 2 (some cost four).
Full incident evidence for every one lives in `firestore-cutover-log.md`'s
Working Protocol section (12 numbered rules, at the top of the file) and
PHASE 2 RETROSPECTIVE (prepended atop `## Entries`) — this list restates
them as direct instructions with the incident cited by name and where each
one bites in Phase 3.

1. **Prefer DELETING a write to relocating it.** Four rounds (P2-18,
   P2-23, P2-28, and the fix P2-29 reviewed) each asked "is this write
   above the awaits I can see from inside this method?" and each was
   falsified by an await one level up. That question has no terminating
   answer — there is always one more caller. "Does this path perform this
   write at all?" does terminate: a write that doesn't exist has no
   boundary to enumerate and no doc comment that can go stale. Phase 3
   will hit the same shape wiring `T-20`, `T-30`, `T-31`, `T-37` — every
   one adds a write behind a new caller chain. Default to deleting the old
   write, not guarding it.
2. **Enumerate awaits from the PUBLIC ENTRY POINT of the class, not from
   inside the method holding the write.** Enumerate EVERY public method of
   the class under review, not only the ones your change touches — the
   round-7 verifier found `T-66` (a real, previously-unprobed activation
   site) only by enumerating all 8 of `FirestoreProfileRepositoryAdapter`'s
   public methods, where the design that shipped the original fix had
   named only 3.
3. **A negative claim is verified by (a) re-run enumeration against the
   CURRENT tree, or (b) an executable probe gating the specific
   await/branch — never by re-reading the code more carefully.** A defect
   filed `done` with a plausible written justification is NOT closed by
   that justification. Two different agents wrote two well-argued,
   individually-plausible justifications for the same underlying `T-49`
   error (P2-18's, P2-23's); both were disproven in minutes by a 30-line
   probe.
4. **An unqualified safety claim is a defect even when the code is
   correct.** Every failed `T-49` round stated its result at a scope wider
   than it had verified ("nothing asynchronous precedes it," "no
   post-await re-check is needed"). The round that finally got the code
   RIGHT still produced one — "CONTROL-4 makes a fifth reopening
   structurally impossible" — disproved by execution in minutes (`T-67`).
   State the scope you actually checked: "this path performs no such write
   on any path," not "nothing can race this."
5. **A guard that watches for a COMPETING selection cannot detect the
   ABSENCE of one.** The design that finally held enumerated all four race
   states and showed a re-check guard leaves the abandoned-create cell
   open: nothing raced, the caller died, the guard writes C, nobody
   selects C. This is why relocation (option "re-check after the await")
   was rejected on CORRECTNESS, not style. Enumerate all four cells before
   reaching for a post-await re-check anywhere in Phase 3's new wiring.
6. **A source-scanning structural gate is only as good as its pattern, and
   its pattern will be optimistic — attack it before trusting it.**
   CONTROL-4's bounded 40-character regex window was evaded by a longer
   variable name in minutes; a separate aliased-notifier gap is
   width-independent. If Phase 3 or 5 write a new structural gate to
   police the moved code, inject an evading variant and confirm it goes
   RED before trusting the gate's claim.
7. **A test that passes on the broken tree is not a regression guard.**
   The six inherited GROUP-1/GROUP-2 race cases stayed GREEN on the
   reverted, pre-fix tree in exactly the sub-cases where the verifier's own
   sentinel probes went RED — because they asserted only the FINAL value
   after an interleave that happened to complete first. Assert the
   intermediate state, not only the outcome, for every new race-condition
   test Phase 3 writes.
8. **Use a SENTINEL value, never `expect(..., isNull)`, to prove "never
   written."** `isNull` cannot distinguish "untouched" from "written to
   null" — a re-added `set(null)` passes an `isNull` assertion. Pre-set the
   provider under test to a string no production code could produce
   (`'SENTINEL-...'`) and assert byte-identity afterward.
9. **Six sanity assertions per race case, or the case is vacuous.** The
   likeliest way a new permanent test silently rots: it "passes" because
   the whole operation completed before the interleave point. Required
   set: gate genuinely shut at the interleave; operation genuinely
   incomplete (a done-flag + `pumpEventQueue`); gated collaborator
   genuinely reached (`verify(...).called(1)`); remote document genuinely
   landed; competing selection genuinely current; local row genuinely
   exists.
10. **Publish the predicted revert signature BEFORE running the revert.**
    The design that finally held predicted exactly 6 RED / 8 GREEN, named
    each case, and matched on the first real run — every earlier round
    skipped this and each shipped a defect. Before trusting any new
    permanent test: disable the fix (or revert via `cp`, never `git
    stash`), state which cases you predict go RED, run it, and treat any
    mismatch as a defect in the TEST, not noise.
11. **A round cannot certify its own fix — the review must be
    adversarial, not confirmatory.** Round 7's verifier returned
    `t49_closed: true` AND `verdict: defective` in the same report,
    because it separated "is the code right?" from "is the record true?"
    That split is what made round 7 the round that finally held. Any
    Phase 3 round that closes a defect needs a SEPARATE round — not itself
    — to review it before the entry criteria checkbox is marked satisfied.
12. **Read-only passes still find real defects — budget one at the end of
    every phase.** P2-33 ran no test and no gate and still found a
    two-round-stale deferred-verification table asserting the OPPOSITE of
    the truth, missed by the fix round, the independent code verifier, AND
    the recording round. Static enumeration plus cross-document checking
    is cheap and catches a class execution cannot.
13. **A record correction applied only to a `.md` file leaves the false
    claim live in the code.** `T-50` and `T-49`'s own doc comments each
    recurred this way. A docs-only round can and must DISCLOSE a false
    code comment it finds (name a task), but cannot CLOSE it — closing
    needs a round explicitly scoped to touch `lib/`/`functions/src/`. Never
    let disclosure substitute for the fix.
14. **Multi-field self-reference staleness (`T-62`) is the most persistent
    defect class in this project — it recurred SEVEN times in Phase 2.**
    Correcting one field that cites "current HEAD" does not correct its
    siblings elsewhere in the same file, in a companion file, or inside a
    table. After ANY closing commit, grep all three planning docs for
    every SHA, line number, count, and "only writer"/"structurally
    impossible"/"no path" claim, and re-derive each one — do not trust
    that fixing the narrative paragraph in one file fixed the same fact
    stated elsewhere.
15. **Never delete a probe that found something real — make it
    permanent.** A throwaway probe that finds a defect and is then deleted
    lets the SAME defect survive to be rediscovered from scratch by the
    next round. This happened at least four times in Phase 2, including
    inside the round that finally closed `T-49`. If a probe must be
    disposable by charter (a docs-only round with no fix yet to guard),
    say so explicitly and open a task for a future round to make it
    permanent.
16. **`git stash` is never the tool.** Every revert and restore across
    Phase 2 used `cp` with md5 verification. Two unattributed stash
    entries have sat untouched since before the cutover began (§8, below);
    their reflog SHAs are byte-identical across every round's record.
    Never pop, apply, drop, or index them positionally.

---

## 6. Test policy

- **Targeted `flutter test <paths>` is REQUIRED per commit.** A fix is not
  done until its test has been RUN and PASSES, with the ACTUAL command and
  ACTUAL output pasted into the commit's log entry — never imply a test is
  green without running it. (A fabricated `01:31 +1` test timing in one
  Phase 2 round's own entry had to be corrected by a follow-up commit that
  actually ran the suite.)
- **Prefer a directory-level run over a hand-picked file list as the
  disclosure baseline.** A hand-picked list missed a 6th red test twice in
  Phase 2 — once inside `test/features/profiles/`, once for all 14
  failures under `test/e2e/journeys/**`, invisible for FIVE rounds because
  no round ever ran `flutter test test/e2e/` as its own net.
- **Emulator suites ONE AT A TIME**, on port 8080 — confirm free first:
  `ss -ltnp | grep -E ':8080|:9099|:4400'`. Running `make test-rules` and
  `make test-functions` concurrently already produced one self-inflicted
  port collision in this cutover.
- **Check for a `Terminated` line and an explicit `EXIT=` code before
  reading a suite's failure count** — a killed run manufactures fake red
  tests (sink-close errors, teardown `PathNotFoundException`s) that are
  process artifacts, not code failures (§2, above, has the concrete
  example).
- **Never run two agent sessions against the same planning documents
  concurrently.** Three separate Phase-2 incidents: files excluded
  mid-edit because a concurrent session was writing them; a commit landing
  with NO log entry at all because `docs/planning/**` was dirty from a
  sibling session; gates going red transiently from a concurrent session's
  mid-write state. A gate or test result collected while another session
  is writing describes nothing.

---

## 7. Gate map

- **`make audit` (the 104-check gate every log entry means) MUST run from
  `learning_tracker/`, never the repo root.** The repo-root Makefile
  (`/home/daniel/repos/learning-tracker/Makefile:112`) defines a
  DIFFERENT, 12-grep `audit` target — a pre-existing check, unrelated to
  this cutover — and it FAILS today on unrelated pre-existing violations.
  Running it from the repo root and reading a red result as a Phase 3
  regression is a documented trap (`T-52`).
- **`make audit` is a SUBSET of `make ci`** — checks exist in only one
  lane. TQ-9 (rule coverage) is `make ci`/`make test-rules`-only, chained
  with `&&` behind a `node --test` step that can itself silently block it
  from ever running — confirm the chain actually REACHED the second
  command, not merely that it exited 0. (A stale assertion once prevented
  TQ-9 from running even once for an entire phase — `T-54`.)
- **Check 103 (`PROFILE-KEY-SPLIT`, `check_profile_path_keying.dart`) is
  FILE-LOCATION-based, not keying-based.** INT-A = every `.dart` under
  `lib/core/sync/**` (no liveness filter); INT-B = every `.ts` under
  `functions/src/**`; ULID-C = `lib/data/repositories/**` +
  `lib/features/**/data/repositories/**` (liveness-filtered). It CANNOT
  register Phase 3 progress until those directories are deleted or
  edited, cannot see `learner_profiles` itself (parent collection, outside
  its scan), `tutor_active_access`, or ANY doc-id formula — that gap is
  exactly what let `T-31`'s tutoring coupling go undetected before this
  phase, and why a doc-id-formula mismatch will still be invisible to
  every gate you have if you re-key `T-31` incompletely.
- **Check 104 (`PROFILE-ID-INT-SITES`) counts, it does not reach.** Scope
  is five patterns only (see `tool/profile_id_int_sites_baseline.txt`'s
  header). It has ZERO concept of whether a symbol is ever called — "a
  location can be counted with perfect accuracy while being provably
  unreachable from any UI trigger" is its own documented blind spot. This
  is the check `T-38` plans to fold into `T-23`'s gate retarget in Phase
  5 — until then, treat its green as counting evidence only, never
  reachability evidence.
- **R6d (`coverage/lcov.info` denominator) soft-skips and still exits 0
  when the file is absent.** Read the stdout line above the exit code,
  never the exit code alone. Never delete `coverage/lcov.info` to make a
  gate green.
- **`dart analyze` + `make audit` green means it COMPILES and no ratchet
  MOVED — nothing more.** Two Phase 2 rounds shipped confidently-documented
  fixes on exactly that basis while a real defect sat underneath both
  gates, green before and after.

---

## 8. Environment hazards

- **Two `git stash` entries exist, identified by BASE COMMIT, never by
  positional index** (`stash@{N}` reorders on every push/pop):
  - `stash@{0}` (as of Phase 2's close): `WIP on dev: d74e3829` — appeared
    MID-SESSION during Phase 2's own P2-0, with **no `git stash` command
    ever run by the agent that found it**. The mechanism is still
    unidentified.
  - `stash@{1}` (as of Phase 2's close): `WIP on (no branch): 8855b9b1` —
    pre-existing, predates this cutover entirely.
  - Neither is popped, applied, or dropped; neither is ruled on. Full
    measured facts: `firestore-cutover-log.md`'s "Known stashes —
    UNDISPOSITIONED-REPORTED" section, near the end of the file.
- **A clean `git status --porcelain` is NOT proof nothing is wrong.**
  Re-verify immediately before every `git add`, and if a just-written edit
  is missing on re-read, check `git stash list` before assuming the edit
  tool failed.
- **Verify the tree first, because the log may predate a crash.** Sessions
  die mid-work — session limits, interrupts, crashes. Run `git log
  --oneline -1` and compare to `CURRENT STATE`'s `Head:` field before
  trusting anything else in the log.
- **Uncommitted work in the tree is suspect until verified, not lost.**
  Check whether the last agent finished by reading its section under IN
  FLIGHT in the log. Never `git stash` to clean up — a partial pop has
  already silently dropped work on this project once. Edit by hand.

---

## 9. What is deliberately NOT done — the owner's call

- **The `firestore.rules` change (T-33, P2-6, owner-delete for
  `learning_order`) is TEST-VERIFIED but still UNDEPLOYED.**
  `Deployed:` in `CURRENT STATE` still reads `unknown — not deployed`.
  `make test-rules` → `pass 116 fail 0`, TQ-9 → all 37 conditional allow
  rules evaluated at least once — proves the rule text is internally
  consistent against `fake_cloud_firestore`'s emulation; proves NOTHING
  about what is live on the dev Firebase project, which only a real
  deploy changes. **You are instructed never to deploy** (§0, standing
  instruction #3) — this stays the owner's call. Before attributing any
  device `permission-denied` to a keying defect, check this field first:
  an undeployed rules change and an unregistered App Check debug token
  present IDENTICALLY.
- **`D10`/`D11`/`D20` (device checks) require an actual device**, not a
  docs pass or a code change — `fake_cloud_firestore` cannot model an
  offline queue plus a reconnect ack. They are standing work, not phase
  gates: read them before touching profile-activation code a second time,
  but they do not block Phase 3's start.
- **`T-44` and `T-46` need a PRODUCT decision, not a mechanical fix** — do
  not resolve them unilaterally as part of Phase 3 wiring work.
- **`T-55`** (the ~60 further ulid-less test seeders) needs a decision:
  fix preventively, or wait for each to fail on its own the way its
  predecessors did. Not yours to decide silently either way — flag it if
  Phase 3's work starts exercising any of them.

---

## 10. Phase 3 entry criteria — verify each, in order, before your first edit

- [ ] **Recovery protocol run** (§2, above) — tree verified against
      `CURRENT STATE`'s `Head:`, no orphaned `flutter test` process, gates
      and `make test` re-run FRESH by you, not inherited. Any drift from
      the "last known" table in §2 named explicitly.
- [ ] **`git stash list` confirms exactly 2 entries**, same bases
      (`d74e3829`, `8855b9b1`) as §8. A third entry, or a changed base, is
      a red flag — stop and investigate before editing anything.
- [ ] **`git status --porcelain | grep -v '^ M _bmad'` is empty**, or any
      dirty file is explained (a prior session's genuinely-finished,
      uncommitted work — verify against that session's own IN FLIGHT
      entry, don't assume).
- [ ] **`T-39` reconciled** — check 103's `--report` WATCHLIST run fresh
      against the current tree and compared line-by-line to `CURRENT
      STATE`'s "dead adapters (7)" list; the mapping between the two
      written down before any adapter is wired (§4).
- [ ] **You understand the IN FLIGHT protocol** (top of the log) and will
      append an entry naming your commit id and remaining edit-list items
      BEFORE your first edit — the commit that lands your code clears it
      and rewrites `CURRENT STATE` truthfully, in the same commit.
- [ ] **You have read §5's 16 traps** and intend to apply them, not just
      acknowledge them — in particular: enumerate from the public entry
      point (#2), delete rather than relocate (#1), and never delete a
      probe that finds something real (#15).

Once every box above is checked, you are clear to start Phase 3's own
work. **This handoff document does not write Phase 4's handoff — that is
explicitly Phase 3's own closing round's job, from Phase 3's own measured
state (Working Protocol rule 15). Do not treat any "bites Phase 4" note
anywhere in this project's docs as a substitute for writing that handoff
when the time comes.**
