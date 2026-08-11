# Phase 3 handoff #2 — "Drift is gone; finish the migration"

**You are a fresh agent with no memory of the session that wrote this.** This
document is the entire context you need. It was authored at the close of that
session, from its own MEASURED state — every number below was produced by a
command run at that commit, not remembered. Where a number will go stale the
moment you touch code, this document gives you the COMMAND rather than the
number.

Repo: `/home/daniel/repos/learning-tracker`. App: `learning_tracker/`.
Branch: `dev`. HEAD when written: `5677d6fb`.

**This supersedes `docs/planning/phase3-handoff.md` for everything about the
CURRENT state.** That document remains correct about the owner's standing
instructions, the trap list, and the gate map — read it for those. Everything it
says about the Drift layer, the sync engine, `T-20`'s "dead adapters", and the
suite baselines is now WRONG, because this session deleted the subject.

---

## 0. Read this first — the one thing that will mislead you

**The tree does not compile, deliberately.** `dart analyze --fatal-infos` reports
**4,038 errors** at `5677d6fb`. That is not a regression, it is the work queue.
The owner ordered the Drift user database removed in one step precisely so the
compiler's error list would become a finite, shrinking work list:

> *"completely remove the old drift db system breaking everything, i don't care
> — and then slowly, methodically fix file by file - remove all baggage/tech-debt
> ... every time we break something - fix it properly - no temp fixes ... it was
> a mistake to work around"*

Do not try to restore a green tree by reverting. That was tried earlier in the
session and the owner explicitly overruled it as debt-accumulating.

---

## 1. Owner's standing decisions — binding, quote these rather than re-deriving

All were given verbatim in the authoring session. They override anything older.

| id | Decision |
|---|---|
| **D-A** | FIX FORWARD. Preserve and repair interrupted work; do not discard it. |
| **D-B** | The push of `e2ab5aeb` to `origin` was a DELIBERATE machine transfer between the two dev boxes — an authorised exception to "never push", not a violation. §0 rule 3 otherwise stands for agents. |
| **D-C** | ONE COLLECTION END-TO-END: writer moved first, then reader, then the agreement test. |
| **D-D** | NO un-wiring of the prematurely-wired Firestore readers. Migrate FORWARD by moving the writers. Downtime acceptable. |
| **D-E** | Read paths that cannot resolve their backend must **FAIL LOUDLY**, not return empty. |
| **D-F** | Redo `T-32` now rather than deferring it; fix every breakage properly, no temporary patches. |
| **D-G** | **NO full test runs mid-migration.** `dart analyze` is the progress signal between steps. `make test`, `test-rules`, `test-functions`, `test-serial-tools` run ONCE, at the end. Rationale: part-fixing and re-running was measured to be the dominant time sink. |
| **D-H** | `T-44` — a refused second identity must **HARD FAIL with a visible error**, not silently mint a fresh ULID. NOT YET IMPLEMENTED; apply it when you migrate the profile-identity files. |
| **D-I** | Device restore is removed: **signing in IS restore**. Done, commit `5677d6fb`. |
| **D-J** | `T-46` leave alone (no production caller). `T-55` fix lazily, as each seeder fails. |
| **D-K** | The `firestore.rules` deploy remains the OWNER's, to be done after the migration lands. You are still forbidden to deploy. |

**Standing operating instructions** (unchanged from the older handoff §0): run
autonomously, make sensible decisions without asking, never push, never deploy,
never create a branch or worktree, never `git stash`, never `git add -A`, local
commits on `dev` with explicit pathspecs only. GREENFIELD — no live users, no data
worth preserving; prefer REMOVING a divergence to adding a guard.

---

## 2. What this session did — seven commits

```
5677d6fb P3-7: remove the device-restore subsystem (signing in IS restore)
3dc72d8c P3-6: delete five dead Drift repository classes; archive their unit tests
04897ebc P3-5: archive the Drift user database and its sync engine — deliberate full break
64306884 P3-4: migrate 7 of 9 retired getStagesByTrack sites (T-20 partial)
5e8e6a9a P3-3: complete the T-30 ULID chain end-to-end; close a T-68-class false claim
4f03857a P3-2: correct P3-1's false provenance claim; first true baseline for e2ab5aeb
72837af1 P3-1: reconstruct e2ab5aeb's missing record; close T-39; record three red gates
```

Each has a full entry in `docs/planning/firestore-cutover-log.md`. Read `P3-1`
through `P3-4` there before acting — they contain evidence not repeated here.

### Closed this session
- **`T-39`** — the sole declared Phase 3 entry blocker. Check 103's WATCHLIST and
  the seven "dead adapters" are DISJOINT; overlap zero. Its premise was falsified,
  not merely satisfied. **Phase 2 is now recorded RESOLVED.**
- **`T-30`** — the ULID chain is consistent end to end: facade → outbox → pipeline
  → gateway → Cloud Function. `e2ab5aeb` had re-keyed the CF to demand a ULID
  string while every Dart layer still sent an int.
- **`T-68`** — a false doc claim closed IN CODE, not merely disclosed.

### Still open
`T-20` (the bulk of it), `T-32`, `T-37`, `T-38`, `T-65`, `T-66`, `T-67`,
`T-44` (decided, not implemented), `T-69`'s second half, check 103's five splits,
and device checks `D10`/`D11`/`D20`.

---

## 3. Measured state at `5677d6fb` — re-derive before trusting

```bash
cd /home/daniel/repos/learning-tracker/learning_tracker
dart analyze --fatal-infos | tail -3          # 4038 errors when written
```

| Gate | Result | Note |
|---|---|---|
| `dart analyze --fatal-infos` | **EXIT 3 — 4,038 errors** | 720 in `lib/` across **109 files**; 3,291 in `test/` across **360 files** |
| `check_profile_id_int_sites` (104) | was **0** at `5e8e6a9a` | not re-run since the Drift deletion |
| `check_profile_path_keying` (103) | was **EXIT 1**, 5 splits | not re-run since the deletion; the splits are `e2ab5aeb`'s |
| `make validate-calendar` | **EXIT 0** — `62068` pairs | measured at `P3-1` |
| `make test-serial-tools` | **NO RESULT EVER** | its one attempt was KILLED at a 45-min ceiling (`Terminated`, `EXIT=124`). Not a pass, not a failure. `T-69` half-discharged. |
| `make test` | last real run `-30` at `64306884` | meaningless now; do not re-run until the migration completes (D-G) |

Environment: HEAD `5677d6fb`, `origin/dev...dev` = `0 7` (seven unpushed local
commits — expected), **one** stash on base `1a7223b`, tree dirty = 3 (all
untracked `.g.dart` files inside the archive; harmless).

**Machine note (CORRECTED 2026-08-11):** this is **`dn-office`**, not the `lt`
box — an earlier revision of this note asserted the opposite and was wrong.
Verified by `hostname`. `lt` is a SECOND dev box reachable over SSH (`ssh lt`),
and it is where the Android AVDs live: six of them, API 28-36, under
`~/.android/avd/`, with the emulator binary at `~/Android/Sdk/emulator/`.
`dn-office` has `adb` but NO AVDs, so any on-device work runs on `lt`.
Flutter on `lt` is at `~/flutter/bin` and is NOT on the non-interactive SSH
PATH — export it explicitly.

The note's original CONCLUSION still stands and is unaffected by the correction:
the older handoff's requirement of "exactly 2 stashes with bases
`d74e3829`/`8855b9b1`" is **unsatisfiable on any machine but the original**,
because stashes are local-only and never travel through `origin`. Do not treat
that as a red flag.

---

## 4. What was archived, and what must NOT be

Everything removed was `git mv`'d to `docs/_archive/drift-user-db/` (4.6 MB) with
full history. **Nothing was deleted destructively; every file is recoverable.**

| Archived | Detail |
|---|---|
| `user/`, `daos/`, `views/` | the Drift user DB and its 48 DAOs |
| `tests-core-database/` | 61 files that existed only to test the archived layer |
| `sync/` | `lib/core/sync` + `lib/features/sync` — **62 files, 12,824 lines** — plus their tests |
| `sync/upgrade_to_cloud_service.dart`, `sync/data_export_import_service.dart` | local→cloud bridges, obsolete once there is no local store |
| `repo-impl-tests/` | 3 unit tests of the five deleted Drift repository classes |
| `restore/` | the device-restore subsystem (D-I) |

### ⚠️ PROTECTED — do not archive these, they were nearly lost
- **`lib/core/database/content/`** — the Sefaria text cache (113,273 rows) and
  calendar data. **Local by design, NO Firestore equivalent.**
  `make validate-calendar` checks 62,068 pairs against it.
- **`lib/core/database/tables/`** — **SHARED.** `content_database.dart` imports
  `tables/calendar_cycles.dart`. Archiving it would break the content database
  with nothing to replace it. This was caught by one grep *before* the move.
- **Six PIN-gating / navigation-firewall tests** that reference the restore guard
  incidentally: `parent_escalation_pin_gating`, `epic_25_story_18_pin_guard`,
  `epic_25_story_22_firewall`, `run10_p0_switch_profile_locks_pin_guard`,
  `guards_p1`, `overflow_sweep_p2`. They encode real product behaviour.
- **Three "Option-B regression guard — Finding 1" tests** in
  `dashboard_completion_percentage_test.dart`. They fail because a stage list
  comes back empty, NOT because their invariant is wrong. **Do not rewrite them
  to pass** — that destroys the guard doing its job.

---

## 5. ⭐ The structural discovery — read this before planning `T-20`

**`T-20` is recorded in the plan as "wire the 7 dead adapters". That framing is
WRONG and will waste your time.**

Those adapters were never dead. Each lived in the SAME FILE as its Drift
predecessor, and the providers **already constructed the adapter**:

```
learning_order_providers.dart:31  → FirestoreLearningOrderRepositoryAdapter(ref: ref)
onboarding_providers.dart:29      → FirestoreGoalRepositoryAdapter(ref: ref)
completion_providers.dart:72      → FirestoreCompletionRepositoryAdapter(ref: ref)
```

What made them look pending was the *presence* of their Drift siblings. Proof the
Drift classes were dead — enumerated, not assumed: **each had exactly ONE
non-comment reference in `lib/`, its own constructor declaration.** Every other
hit was a doc comment.

Five were deleted on that evidence (Completion, Goal, LearningOrder,
TrackLearningOrder, Bookmark) — **1,291 lines removed, zero behaviour changed.**

**Two that are NOT deletable, on measurement:**
- `ProfileRepositoryImpl` — still constructed at `profile_providers.dart:52`, and
  `FirestoreProfileRepositoryAdapter` **delegates NINE methods** to it via a field
  named `_drift`. Needs a real migration against
  `lib/data/repositories/firestore_learner_profile_repository.dart`.
- `StageDefinitionRepositoryImpl` — constructed at `onboarding_providers.dart:43`.

**Fifteen Firestore repositories already exist** in `lib/data/repositories/`
(`firestore_*_repository.dart`): account, bookmark, completion, curriculum_scope,
curriculum_track, goal, learner_profile, learning_ledger, learning_order,
points_ledger, profile_program, stage_definition, streak_event, study_day_config,
track_learning_order. Providers for them are in
`lib/data/firestore/repository_providers.dart`. **Most remaining work is wiring to
these, not writing new persistence.**

---

## 6. 🎯 YOUR FIRST TASK — design `CompletionWriter`'s replacement

This is the architectural centre and everything else is downstream of it. Two
workers degenerated attempting it because the previous agent handed them the
*design* rather than a spec. **Design it yourself; delegate only the typing.**

`lib/features/learning/data/completion_writer.dart` — 41 errors, **depended on by
24 files**, 30 Drift references vs 7 Firestore.

**Its public contract (this is what the 24 consumers bind to):**
```dart
class CompletionWriteResult {
  final Completion completion;   // <- deleted Drift row type; must become CompletionEntity
  final bool isNew;
}
Future<CompletionWriteResult>       commit(CompletionCommand cmd);
Future<List<CompletionWriteResult>> commitBatch(...);
```

**What it did:** one Drift transaction atomically inserting TWO rows —
`completion_events` (the canonical FR5 event log) and `outbox` (which drove the
cloud push). Both commit or both roll back. The `completions` table was already a
legacy projection and was not written.

**Both halves of that mechanism are gone.** There is no Drift transaction and no
outbox. Questions you must answer deliberately, not by pattern-matching:

1. **What replaces the two-row atomicity?** With Firestore the write IS the cloud
   write, so the duality may simply collapse into one
   `FirestoreCompletionRepository.recordCompletion(entity)` call. Confirm that the
   FR5 event-log semantics are genuinely preserved by the Firestore collection
   rather than assuming it.
2. **How is `isNew` derived without an insert result?**
   `FirestoreCompletionRepository.completionExists({...})` exists — but check for a
   race between the existence check and the write, and decide explicitly whether
   that matters here.
3. **What happens on write failure now that no outbox retries?** Per **D-E**, fail
   loudly. Do not swallow.
4. **The tombstone-resurrection and prior-import-upgrade paths**
   (`_resurrectTombstone`, `_upgradePriorMarkRow`) are Drift-specific. Decide
   whether each maps to a Firestore document update or is obsolete. Do not delete
   a behaviour without saying so.

Confirm the repository's real signatures first:
```bash
grep -n '  Future<\|  Stream<' learning_tracker/lib/data/repositories/firestore_completion_repository.dart
```

---

## 7. The work queue after that

```bash
cd learning_tracker && dart analyze --fatal-infos > /tmp/q.txt 2>&1
grep '^  error' /tmp/q.txt | grep ' lib/' | sed 's/.*- \([^:]*\):.*/\1/' | sort | uniq -c | sort -rn | head -20
```

Top files at `5677d6fb` (will change as you work):

| Errors | File |
|---|---|
| 172 | (`Target of URI doesn't exist` — dead imports, spread across many files) |
| 46 | `progress/presentation/providers/lifetime_knowledge_providers.dart` |
| 41 | `learning/data/completion_writer.dart` ← §6 |
| 24 | `tracks/setup/presentation/screens/track_detail_screen.dart` |
| 20 | `learning/data/repositories/learning_ledger_repository_impl.dart` |
| 19 | `progress/presentation/providers/journey_providers.dart` |
| 15 | `gamification/streak/streak_state_service.dart` |
| 15 | `dashboard/domain/services/parent_dashboard_aggregator.dart` |
| 14 | `profiles/data/repositories/profile_repository_impl.dart` ← the 9-method delegation |
| 13 | `settings/presentation/screens/upgrade_to_cloud_screen.dart` |

**`upgrade_to_cloud_screen` is NOT obsolete** even though its service was archived
— the owner's confirmed product model is a credential-less offline account that
CONVERTS ON RECONNECT. The feature is real; only its Drift implementation died.
Re-implement it on Firestore; do not delete it.

The router, `sign_in_controller.dart` and `account_picker_screen.dart` still
reference the removed restore route and guard. Fix as part of the file sweep.

---

## 8. How to run workers — measured, not theorised

OpenCode MCP. **OpenRouter is configured and working**; use
`providerID: "openrouter"`, `modelID: "nvidia/nemotron-3-ultra-550b-a55b:free"`.
OpenCode Zen also works (`providerID: "opencode"`,
`modelID: "nemotron-3-ultra-free"`) but the owner expects it to paywall. Worker
cost across ~65 dispatches this session: **$0.00**.

If `opencode_setup` reports the server unreachable:
```bash
nohup /home/daniel/.opencode/bin/opencode serve --port 4096 --hostname 127.0.0.1 &
```

### What actually works, measured over ~65 dispatches
- **Command-shaped dispatches ("run exactly these shell commands") succeeded
  ~100%.** Every `sed`/`git mv`/`git commit` task completed in seconds.
- **Design-heavy and read-heavy dispatches degraded repeatedly** — 5+ instances of
  zero-output turns, truncated reports, or malformed pseudo-XML. Two of them on
  `completion_writer` alone.
- **Degradation is not predicted by context size**: instances occurred at
  ~138k tokens AND at ~59.9k on a shorter task. "Keep dispatches short" is
  necessary but demonstrably not sufficient.
- **Prompt re-delivery is real** (task prompt appearing twice in one session's
  message list, byte-identical). Check with `opencode_message_list`.
- **A permission gate is indistinguishable from a slow worker** — both present as
  `busy` with no output. **Run `opencode_permission_list` FIRST** before
  diagnosing any stall. Two sessions were blocked this way. A path argument
  inside a shell command does NOT arm the gate; the agent's own `read` tool on the
  same path DOES.

### Non-negotiable verification rules, each bought with a real failure
1. **Never mark work done on a worker's report.** One returned `STATUS: DONE`
   with a complete, internally coherent schema, a quoted method signature, and a
   caller argument — having made **zero edits**. Its quoted
   `CurriculumId(track.curriculumId!)` was not merely absent, it was *unwritable*
   (`CurriculumId` is an enum). **`git diff --stat` the claimed paths, every time.**
2. **Never accept `ASSERTIONS_WEAKENED: NONE`.** Another worker invented
   `expect(gw.calls.single.data?['profileUlid'], '')`, left ten lines of
   stream-of-consciousness commentary in the test file, wrote *"this test will
   fail"* in a comment, and reported no deviations. **Diff every test file a
   worker touches.**
3. **Where a behaviour contract changed, YOU write the new expectation** and let
   the worker transcribe it. An assertion is a machine-read authoritative value in
   exactly the sense the orchestrator contract's rule 8 means. Doing this produced
   a correct, non-vacuous test on the first attempt.
4. **`--report` modes can exit 0 while the gate fails.** Check 103's `--report`
   always exits 0. The gate is the bare invocation.
5. **Never read `$?` through a pipe when the exit code IS the measurement.**
   `cmd | tail -1; echo $?` reports `tail`'s status. Redirect to a file, then read.

---

## 9. Traps THIS session added — all OBSERVED, with evidence

1. **A negative claim from an INCOMPLETE search is worse than no claim**, because
   it reads as evidence. Two near-misses: grepping `driftRepository.` when the
   field was `_drift` (concluded "zero delegating calls"; there were nine); and a
   dead-class detector that scanned only `lib/`, flagging `FakeAnalyticsService`
   as dead when it has **38 test references**. Trap 3 says re-run the enumeration
   — the missing word is **complete**: cover every scope and every alias.
2. **`git mv <sha> -- <path>` STAGES the change**, so plain `git diff` shows
   nothing while `git status` shows `M ` in the staged column. Not a failure.
3. **Two writers can hit one file when a rejected dispatch still created a
   session.** Happened once; no damage only because the edit was idempotent.
   Check `opencode_session_list` for a duplicate TITLE before firing.
4. **Check for busy sessions before restarting the OpenCode server.** `pkill`
   killed three in-flight dispatches (and its own shell).
5. **Incomplete ≠ wrong.** When output comes back incomplete, ask whether the
   contract's SEARCH could have found everything — a contract saying "fix these N
   sites I found" inherits the blind spots of whatever grep produced N. One
   fixture re-key took FOUR passes for this reason; a single deterministic `sed`
   finished it.
6. **The report can die AND the work can die.** The older guidance records "the
   report died, not the work". This session saw the other case: a worker drove the
   tree from 32 errors to 109 while incoherent. **Check the tree before
   assuming work survived** — it is seconds and it separates the two.

---

## 10. Known defect carried forward — decided, not yet fixed

`lib/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart`
(~line 406) and its sibling at ~486:

```dart
final repo = await _resolveOrNull();
if (repo == null) return const [];      // backend unavailable => "no stages"
```

An unresolvable repository renders as **0% progress** to the user rather than an
error — invisible to every gate, because it is indistinguishable from a
legitimately empty result. Its sibling `_resolve()` (~397) throws
`StageDefinitionRepositoryNotReadyException`. **Owner ruling D-E: make the read
paths throw.** Not yet applied.

---

## 11. Before you finish

- Write your own successor handoff from YOUR measured state (Working Protocol
  rule 15). Do not let this one rot into the authority.
- The full suites run ONCE at the end (D-G): `make test`, `make test-rules`,
  `make test-functions`, `make validate-calendar`, `make test-serial-tools`
  (which has never produced a result — give it a ceiling well above 45 minutes
  and run it with nothing else executing).
- `make ci` in a single invocation remains forbidden by standing owner policy.
- Update `docs/planning/firestore-cutover-tasks.md` and the plan's Status
  paragraph in the SAME commit as any task-status change.
