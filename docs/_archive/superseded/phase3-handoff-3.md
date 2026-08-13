> **ARCHIVED 2026-08-13 — superseded.** Superseded by `docs/planning/phase3-wave-plan.md` and `docs/planning/phase3-handoff-5.md`. Retained for history only; do not treat as current. See `docs/planning/firestore-finish-line-plan.md` for the live plan.

# Phase 3 handoff #3 — "the contract has moved; now move its callers"

**You are a fresh agent with no memory of the session that wrote this.** Every
number below was produced by a command run at `3457b195`, not remembered. Where a
number will go stale the moment you touch code, this gives you the COMMAND.

Repo: `/home/daniel/repos/learning-tracker`. App: `learning_tracker/`.
Branch: `dev`. HEAD when written: `3457b195`. **12 unpushed commits — correct.**

---

## 0. Read this first — TWO things that will mislead you

**1. The tree does not compile, deliberately.** 3,945 errors is the work queue,
not a regression. The owner ordered the Drift user DB removed in one step so the
compiler's error list would become a finite, shrinking work list. Do not "restore
green" by reverting; that was tried and explicitly overruled.

**2. `docs/planning/phase3-handoff-2.md` §6 IS WRONG.** It names
"design `CompletionWriter`'s replacement" as your first task, calls it *"the
architectural centre"*, and says it is *"depended on by 24 files"*. Measured:
`CompletionWriter` had **zero production consumers**, and the 24 came from a
`grep -l` that counted **doc-comment mentions**. It is archived (`cbbf5c19`).
**Two workers degenerated on that task in an earlier session** — at least partly
because they were asked to port a class with no consumer, against a false premise.
Everything else in handoff-2 (§0-§5, §7-§11) still stands.

**A `grep -l` count is not a dependency count.** Exclude comments before it means
anything.

---

## 1. Owner's standing decisions — quote these, do not re-derive

`D-A`…`D-K` are in handoff-2 §1 and all still hold. **Two new ones, both given
this session, both load-bearing:**

| id | Decision |
|---|---|
| **D-L** | `completions` keeps immutable key fields, but a narrow allowlist — `purged_at`, `source`, `completed_at` — MAY change. `allow delete: if false` unchanged. Erase = stamp `purged_at`; re-mark = clear it; B8 = `source` `bulkInTrack → live`. Reads exclude tombstones. |
| **D-M** | The same treatment for `learning_ledger` (`purged_at` only), so retracting a bulk-marked unit also retracts the siyum it earned. Without it the two collections disagree permanently. |

### ⚠️ `firestore.rules` IS EDITED AND NOT DEPLOYED
Both allowlists are committed in `learning_tracker/firestore.rules` (lines 279 and
345). **D-K stands: the deploy is the OWNER's alone. You are forbidden to deploy.**
Until it is deployed, `purgeCompletion` / `restoreCompletion` /
`upgradeSourceToLive` / `purgeEntry` will be **rejected server-side in production**
while passing locally against `fake_cloud_firestore`. **Tell the owner this before
they test on a device.**

Why D-L was necessary, so nobody "simplifies" it away: pre-change, `firestore.rules`
allowed `update` ONLY as a byte-identical replay, and denied `delete`
unconditionally. Un-ticking a bulk-marked item — a live path at
`bulk_mark_screen.dart:322` — was therefore **unimplementable**, and
`_expungeRefs` already swallows failures, so it would have silently diverged.

---

## 2. What this session did — four commits

```
3457b195 P3-11: two pure-function services move to CompletionEntity; the rest triaged
e12a26f3 P3-10: CompletionRepository moves onto CompletionEntity; _toDriftCompletion deleted
cbbf5c19 P3-9:  archive CompletionWriter (DEAD, not central); D-M lands on the ledger
64b8bc66 P3-8:  tombstone-capable completions (D-L, D-M in the rules)
```
Full entries in `docs/planning/firestore-cutover-log.md` (newest at the top, from
line ~2448). **Read P3-8 through P3-11 before acting** — they carry evidence not
repeated here.

---

## 3. Measured state at `3457b195` — re-derive before trusting

```bash
cd learning_tracker
dart analyze --fatal-infos > /tmp/q.txt 2>&1
awk '{print $1}' /tmp/q.txt | sort | uniq -c | sort -rn | head -4
```

| | session start `4d0c70f0` | now `3457b195` |
|---|---|---|
| issues | 5,907 | **5,707** |
| errors | 4,038 | **3,945** |
| — `lib/` | 720 | **639** |
| — `test/` | 3,291 | **3,279** |

**⚠️ The gate target is 0 ISSUES, not 0 errors.** `--fatal-infos` makes all 5,707
fatal. 890 info + 872 warning are mostly `inference_failure_on_*` collapsing
because types are unresolvable — 175 of the 180 affected files also carry errors,
so most should evaporate. **Five files carry warnings with NO errors** — genuine
standalone work.

**Counting trap:** `dart analyze` RIGHT-ALIGNS severity — `  error` (2 spaces),
`warning` (0), `   info` (3). `grep -c '^  warning'` returns **0** against a true
**872**. Always `awk '{print $1}' | sort | uniq -c`.

Environment: 12 unpushed commits, **1 stash** (do not touch), tree dirty = 3
(untracked `.g.dart` inside the archive; `*.g.dart` is gitignored at
`learning_tracker/.gitignore:52`, so generated files are local-only — though a few
older ones ARE tracked, so the repo is in a mixed state on generated files).

---

## 4. What the completion vertical now looks like

**Live write path** (there is only one):
`FirestoreCompletionRepositoryAdapter.markComplete`
(`features/learning/data/repositories/completion_repository_impl.dart:254,:303`)
→ `FirestoreCompletionRepository` (`lib/data/repositories/`).

`CompletionRepository`, `MarkCompletionResult`, the adapter and
`CompletionOrchestrator` all now trade in **`CompletionEntity`**, not the deleted
Drift `Completion`. The `_toDriftCompletion` shim is gone.

**`FirestoreCompletionRepository` gained five methods** (all `dart analyze` clean):

```dart
Future<CompletionEntity?> getCompletion({curriculumId, sefariaRef, stageId});
Future<bool>  recordCompletionIfAbsent(CompletionEntity entity);   // runTransaction
Future<void>  purgeCompletion({..., required DateTime purgedAt});
Future<void>  restoreCompletion({..., required DateTime completedAt});
Future<void>  upgradeSourceToLive({..., required DateTime completedAt});
```
`FirestoreLearningLedgerRepository` gained `purgeEntry({ulid, purgedAt})`.

### 🎯 YOUR FIRST TASK — finish the adapter (it is written but not wired)

`markComplete` already does the idempotency pre-check, for the right reason (its
own comment: SR-1 permits `update` only as a byte-identical replay, so a re-mark
computing a fresh `nowUtc()` would be rules-denied). It still needs:

1. **Resurrect** — `completionExists` now reports a purged doc as **ABSENT**, so
   without `restoreCompletion` a re-mark after expunge attempts a create against
   an existing document and is **DENIED**. This is a live bug the moment the rules
   deploy.
2. **B8 upgrade** — call `upgradeSourceToLive` when an existing doc has
   `source == bulkInTrack` and the incoming command is real learning.
3. **`recordCompletionIfAbsent`** in place of exists-then-write. Not cosmetic:
   `MarkCompletionResult`'s own doc comment records that `isNew` gates **points,
   streak, siyum detection AND bookmark advance** — a lost race double-credits all
   four.
4. **`expungePriorCompletions`** (`bulk_prior_completion_service.dart:375`) still
   queries the archived Drift `prior_completion_imports` table. Rewrite on
   Firestore: purge completions whose `source == bulkInTrack` (a B8-upgraded row is
   `live` and therefore invisible to expunge — same semantics, no second table),
   **and purge the siyum ledger entry** (D-M).

---

## 5. The remaining `List<Completion>` holders — triaged, NOT a batch

Each fails for its own reason. **Do not sweep these as a type swap.**

| File | Blocker |
|---|---|
| `points_service.dart` | `c.trackId` as an **eligibility map key** (`:135,:152,:166`). `CompletionEntity` has no `trackId`. **Needs an owner decision** — same "trackId is gone" question AD-25 raised for stage definitions. |
| `lifetime_knowledge_providers.dart` | `c.trackId` (`:343`) **and** live Drift queries. 46 errors — largest single file. |
| `items_learned_providers.dart` | live Drift queries (`t.profileId.equals`, `:338,:393`) |
| `parent_dashboard_aggregator.dart` | imports archived `user_database.dart`, 6 Drift calls, `c.curriculumId == curriculum.storageKey` (`:160`) becomes enum-to-enum |
| `scheduler_completion_repository_impl.dart` | `c.stageIdFormat` (`:70`) — absent by design; every Firestore completion is `stageOrder` by construction |
| `parent_analytics_repository.dart` | 8 sites, interface+impl pair |
| `dashboard_providers.dart`, `bulk_mark_completion_use_case.dart` | smaller, unexamined |

**`kFirestoreUnmappedCompletionRowId`** (`completion_repository_impl.dart:79`) is
deliberately still there — two doc comments reference it. Remove it WITH them, in
one edit. Removing a symbol out from under its own documentation is how `T-68`-class
false doc claims get created.

**`CompletionCommand.profileId` is a vestigial Drift `int`** — the Firestore repo
is profile-scoped, so nothing needs it. It belongs with the profile-identity sweep
and check 104, not with this vertical.

---

## 6. How to run workers — the pattern changed, and why

**Use OpenCode Zen**: `providerID: "opencode"`, `modelID: "nemotron-3-ultra-free"`.
OpenRouter free (`nvidia/nemotron-3-ultra-550b-a55b:free`) started returning status
`retry` under rate limiting mid-session. Cost across this whole session: **$0.00**.

### ⭐ Never put script text in the dispatch prompt
Workers do **not** reliably pipe a heredoc verbatim — they RECONSTRUCT it. Three
confirmed single-character corruptions, all silent, all reported
`DEVIATIONS: NONE`:

1. `);` → `)` — `firestore_completion_repository.dart:459`
2. `';` → `;` — `completion_orchestrator.dart:5`
3. `';` → `;` — `completion_repository_impl.dart:10`

**Corruption 3 is the one to learn from.** It produced `implements_non_class` plus
**five `override_on_non_overriding_member` warnings** — which read exactly like
"the adapter no longer matches the migrated interface", i.e. precisely the defect
that refactor would be expected to cause. Acting on that reading means redesigning
five correct signatures. All 14 issues were cascade from one missing quote.

> **A warning cluster downstream of a parse error is not evidence about design.
> Fix the parse error first, then re-read the gate.**

**The pattern that removes this failure entirely:** write the edit script to YOUR
OWN scratch directory (scratch is yours under the contract), then dispatch exactly:

```
python3 /abs/path/to/script.py      # or: bash /abs/path/to/commit.sh
```

with "do NOT open, read, retype, or reconstruct that script, just run it". No
script text in the prompt ⇒ nothing to retype ⇒ this corruption class is
impossible. The repository change is still performed by the worker, so the
delegation rule holds. **Every dispatch since adopting this has been clean.**

### Make every edit script assert its own match counts
```python
c = s.count(old)
if c != n: print('ABORT ...'); sys.exit(1)
```
This converted an orchestrator miscount (`List<Completion>` asserted 3, actually 2)
into a **clean no-op instead of a silent partial edit**. Count with
`grep -o PATTERN file | wc -l` — never estimate from a `grep -n` listing you read.

### Verification rules — each bought with a real failure
1. **`git diff --stat` proves a change happened; only the gate proves it parses.**
   Run `dart analyze` on every file a worker edits, BEFORE the next dispatch.
2. **Never mark work done on a worker's report.** One returned `STATUS: DONE` with
   a quoted signature and a caller argument having made zero edits.
3. **Never accept `ASSERTIONS_WEAKENED: NONE`.** Diff every test file a worker touches.
4. **Where a behaviour contract changed, YOU write the new expectation.**
5. **Never read `$?` through a pipe.** Use `${PIPESTATUS[0]}` or redirect to a file.
6. **"busy with no output" has THREE distinct causes** — a pending permission gate,
   prompt re-delivery, and provider rate-limiting (`retry`). The symptom carries no
   diagnostic information. Run `opencode_permission_list` FIRST, then
   `opencode_check`. Before aborting anything, check the tree: a worker can die
   having already done correct work.

### Claude sub-agents (the `Agent` tool)
Usable but **very high latency** — three returned 20+ minutes late, after
`ListAgents` had already reported "No reachable agents". They were not lost. Their
output was genuinely good and caught two things direct greps had missed. Treat them
as slow, high-quality background readers; never block on one.

---

## 7. Standing instructions (unchanged)

Run autonomously; make sensible decisions without asking, but **escalate product
decisions** — a default you cannot quote verbatim with a file and line does not
exist. Never push. Never deploy. Never create a branch or worktree. Never
`git stash`. Never `git add -A`. Local commits on `dev` with explicit pathspecs
only. **`make ci` in a single invocation remains forbidden.** GREENFIELD — no live
users; prefer REMOVING a divergence to adding a guard.

**D-G: no full test runs mid-migration.** `dart analyze` is the progress signal.
`make test`, `test-rules`, `test-functions`, `validate-calendar` and
`test-serial-tools` run ONCE, at the end. `test-serial-tools` **has never produced
a result** — its one attempt was killed at a 45-minute ceiling. Give it a much
larger ceiling and run it with nothing else executing.

**Protected — do not archive** (handoff-2 §4 has the full list): the content DB
(`lib/core/database/content/`, 113,273 rows, no Firestore equivalent), the shared
`lib/core/database/tables/` (`content_database.dart` imports `calendar_cycles.dart`),
six PIN-gating tests, and the three "Option-B regression guard" tests. Also NOT
archived and deliberately so: `regression_invariants_test.dart` and
`bulk_prior_completion_b6_b8_test.dart` — mixed-purpose guards to be rewritten
against the adapter, not deleted.

## 8. Before you finish
Write your own successor handoff from YOUR measured state. Do not let this one rot
into the authority — **this document exists because handoff-2's §6 did exactly
that, and sent two workers to port dead code.**
