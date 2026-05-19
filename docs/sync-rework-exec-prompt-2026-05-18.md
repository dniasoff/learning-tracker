# Execution Prompt — Firebase Sync Rework (2026-05-18)

Paste the fenced block below into a fresh Claude Code session on the `dev` branch.

- **Full diagnosis + plan:** [`docs/planning/research/technical-firebase-sync-optimization-research-2026-05-18.md`](planning/research/technical-firebase-sync-optimization-research-2026-05-18.md) — read §2 (root causes, file:line) and §7 (the 10-point fix) before starting.
- **Execution model:** a parallel agent squad in waves. **No worktrees** — every agent works directly in the shared checkout on `dev`. Safety comes from **strict disjoint-file ownership per wave** (no two agents in a wave ever touch the same file) and an orchestrator-run verification gate between waves.
- **Pre-work HEAD:** `e5c052d0`.
- **Added after scoping (2026-05-19):** two overdue-count defects diagnosed — see the **Addendum** at the end of this file. Bug 1 (scheduler-side) is **not** covered by Waves 1–2 as written; Bug 2 (sync timing) fits the rework but has no S-invariant yet.

---

```
Execute the Firebase sync rework. The full diagnosis and plan is in
docs/planning/research/technical-firebase-sync-optimization-research-2026-05-18.md
— read §2 and §7 now before doing anything else.

You are the ORCHESTRATOR. You spawn agents, enforce gates, and commit. You do not
edit production code yourself except to resolve a gate failure.

═══════════════════════════════════════════════════════════════════════
GLOBAL RULES (apply to every wave)
═══════════════════════════════════════════════════════════════════════

BRANCH & ISOLATION
- All work happens on the `dev` branch. NO worktrees. NO feature branches.
- Every agent edits files directly in the shared working tree.
- Each wave's agents run IN PARALLEL (spawn them in a single message with
  multiple Agent tool calls) and own STRICTLY DISJOINT files. The file lists
  below are exhaustive — an agent must not create or edit any file outside its
  list. If an agent finds it needs a file owned by another agent, it must STOP
  and report to you rather than edit it.

NO-WORKTREE COORDINATION PROTOCOL (critical — follow exactly)
- Agents EDIT their files only. Agents do NOT run `build_runner`, do NOT run
  `make ci`, and do NOT commit. (The tree holds every agent's half-done edits
  mid-wave; per-agent builds/tests/commits would be meaningless or race.)
- Each agent, when done, reports: (a) the exact files it changed, (b) a one-line
  conventional commit message, (c) which S-tests it un-skipped and that they pass
  in isolation (`flutter test <its own test file>`), (d) anything notable.
- After ALL agents in a wave report done, YOU (orchestrator) run, in order:
    1. cd learning_tracker && dart run build_runner build --delete-conflicting-outputs
    2. make ci          (analyze + format + schema-check + all tests)
    3. make audit       (12 layering greps + custom lints)
- If the gate is RED: identify the culprit, dispatch a single fix agent against
  the offending files, re-run the gate. Repeat until GREEN.
- When the gate is GREEN: commit each agent's slice as its OWN commit
  (sequentially — `git add <that agent's files> && git commit <files> -m "..."`),
  using that agent's reported message. One agent = one commit. This keeps
  failing-test+fix+green together and avoids any git index.lock race.
- Do NOT start wave N+1 until wave N is committed and the gate is GREEN.

DISCIPLINE (from docs/tracking-system-review-2026-05-17.md §7)
- Every fix ships as ONE commit containing: the characterization test (un-skipped
  from the Wave 0 net), the fix, and the test green. A fix is not done otherwise.
- If a change breaks a pre-existing test, update the test to match the CORRECTED
  behavior — never to re-encode the bug. If unsure whether a test encodes intended
  behavior, stop and report to the orchestrator.

CONVENTIONS
- Commit style: conventional, scoped — fix(sync:), perf(sync:), refactor(sync:),
  test(sync:), fix(review:). Match recent git history.
- Run codegen after any Drift/Freezed/Riverpod change (orchestrator does this).
- Respect the 5 layering rules in learning_tracker/CLAUDE.md (Firebase confined
  to lib/core/sync + lib/features/auth; no core→features imports; etc.).
- Do NOT deploy Firestore rules — committing the files is the deliverable; the
  owner deploys manually.

═══════════════════════════════════════════════════════════════════════
WAVE 0 — Baseline + characterization net   (1 agent, blocking)
═══════════════════════════════════════════════════════════════════════
First: run `make ci`. It MUST be green. If not, STOP and report — do not proceed.

Then create the characterization-test net — operation-counting tests against
fakes/mocks (see test/mocks/, test/fixtures/, test/helpers/). Split into FOUR
files so later waves' parallel agents own disjoint test files:

  test/sync/sync_rework_writepath_test.dart   (S1, S2)
  test/sync/sync_rework_push_test.dart        (S3, S4, S9)
  test/sync/sync_rework_engine_test.dart      (S5, S6, S8)
  test/sync/sync_rework_orchestrator_test.dart(S7)

The invariants:
  S1 — bulk-mark of N items performs exactly 1 Drift transaction (not N).
  S2 — bulk-mark of N items writes N outbox rows and 0 sync_queue rows.
  S3 — a completion is pushed to a DETERMINISTIC Firestore doc id; pushing the
       same completion twice creates NO second document (idempotent).
  S4 — bulk-mark of 655 items pushes via <=2 WriteBatch commits and 0 individual
       collection.add() calls.
  S5 — two concurrent _runBackgroundFlush calls result in only ONE drain running.
  S6 — a completions snapshot carrying metadata.hasPendingWrites does NOT trigger
       a merge (local self-echoes are filtered).
  S7 — exactly one SyncOrchestrator instance exists per app session.
  S8 — pullOnLaunch runs exactly once per launch.
  S9 — two devices marking overlapping items converge to the same state (union,
       no duplicate documents). Reuse the two-device harness from commit 1eba9dbf.

Every test must COMPILE and be marked `skip: 'un-skip in Wave N'` so `make ci`
stays green. Each fix agent un-skips its own tests later.

Gate (orchestrator): build_runner, make ci, make audit — all green.
Commit: test(sync): characterization net for sync rework (S1-S9, skipped)

═══════════════════════════════════════════════════════════════════════
WAVE 1 — Core push path   (3 parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════

── Agent A — Batched local write + dual-queue removal ──
Owns exclusively:
  learning_tracker/lib/core/learning/completion_writer.dart
  learning_tracker/lib/features/learning/data/repositories/completion_repository_impl.dart
  learning_tracker/lib/core/database/daos/outbox_dao.dart
  learning_tracker/lib/core/database/daos/completion_event_dao.dart  (only if a batch append is needed)
  test/sync/sync_rework_writepath_test.dart
Tasks:
  - completion_writer.dart: add commitBatch(List<CompletionCommand>) — ONE Drift
    transaction that batch-inserts all completion_events rows and all outbox rows
    (use Drift `batch()` with InsertMode.insertOrIgnore). Input is assumed already
    de-duplicated (the repo pre-filters). Keep single-item commit() working
    (it may delegate to commitBatch).
  - outbox_dao.dart: add a batch-insert method for outbox rows.
  - completion_repository_impl.dart: in _bulkMarkCompletePriorOptimized (~:278-368)
    replace the per-item await loop (:309-322) with ONE commitBatch call. DELETE
    the syncEngine.pushCompletionsBatch(...) call at ~:351. In the slow
    bulkMarkComplete path (~:214-242) DELETE the pushCompletionsBatch call at ~:239.
    The outbox is now the ONLY completion queue.
  - Un-skip S1, S2 and make them pass.
Commit msg: perf(sync): batch bulk-mark into one transaction; drop dual-queue (S1,S2)

── Agent B — Batched idempotent Firestore push + listener echo filter ──
Owns exclusively:
  learning_tracker/lib/core/sync/firestore_gateway_impl.dart
  learning_tracker/lib/core/sync/firestore_gateway.dart
  learning_tracker/lib/core/sync/push_pipeline_impl.dart
  learning_tracker/lib/core/sync/outbox/push_pipeline.dart
  learning_tracker/lib/core/sync/outbox/outbox_processor.dart
  test/sync/sync_rework_push_test.dart
Tasks:
  - firestore_gateway.dart + firestore_gateway_impl.dart: add
    pushCompletionsBatch(profileId, items) writing via Firestore WriteBatch,
    chunked at <=500 ops per commit. Switch completion writes from
    collection.add() to collection.doc(<deterministic id>).set(...): the doc id
    is derived from the natural key entityKey (profileId:sefariaRef:stageId:
    trackType) — sanitize/hash it to a valid Firestore id since sefariaRef can
    contain '/'. Completions become idempotent.
  - firestore_gateway_impl.dart: in the completions .snapshots() stream
    (~:392-403) FILTER OUT changes whose metadata.hasPendingWrites is true
    (local echoes) so the stream emits only server-confirmed snapshots.
  - push_pipeline.dart + push_pipeline_impl.dart: thread entityKey through to the
    gateway as the deterministic id; add a batched completion-push entry point;
    pushCompletion must use entityKey (stop discarding it).
  - outbox_processor.dart: drain() for the 'completion' kind must collect all
    pending completion rows and dispatch them through the batched push
    (<=500/batch) instead of 50-at-a-time singles. KEEP the drain(profileId)
    signature unchanged. Add exponential backoff (compute nextAttemptAt from the
    existing attempts + lastAttemptAt columns), a maxAttempts cap, and
    dead-letter skip — no schema change, compute from existing columns.
  - Un-skip S3, S4, S9 and make them pass.
Commit msg: perf(sync): batched idempotent completion push + listener echo filter (S3,S4,S9)
Contract for Agent C: the completions listener stream now emits ONLY
server-confirmed changes — C's merge can assume local echoes are already gone.

── Agent C — SyncEngine hardening ──
Owns exclusively:
  learning_tracker/lib/features/sync/data/sync_engine.dart
  test/sync/sync_rework_engine_test.dart
Tasks:
  - _runBackgroundFlush (~:577-608): add a single-flight guard — if a flush is
    running, set a "rerun-requested" flag instead of starting a second; when the
    running flush ends, run once more if requested. No overlapping flushes.
  - Make the drain run to completion (drain until the processor returns 0).
  - _enrichLearnerProfilePayload (~:2307-2443): DELETE the write-only
    progress_summary / streak_summary / gamification_summary computation and the
    ~6 DB queries feeding them (verified zero readers). Keep the rest of the
    profile payload intact.
  - Deduplicate pull_on_launch — it must run exactly once per launch.
  - Completions listener merge (_onCompletionsUpdate / _mergeCompletions,
    ~:1053-1167, :2447-2465): add a debounce; rely on Agent B's upstream filter
    so self-echoes never reach the merge.
  - Un-skip S5, S6, S8 and make them pass.
Commit msg: fix(sync): flush single-flight guard, drop write-only summaries, dedup pull-on-launch (S5,S6,S8)

Gate (orchestrator): build_runner, make ci, make audit — all green. Then commit
A, B, C as three separate commits.

═══════════════════════════════════════════════════════════════════════
WAVE 2 — Hardening + cleanup   (3 parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════

── Agent D — Singleton SyncOrchestrator ──
Owns exclusively:
  learning_tracker/lib/core/sync/providers/sync_orchestrator_providers.dart
  learning_tracker/lib/core/sync/sync_orchestrator.dart
  learning_tracker/lib/features/auth/presentation/screens/sign_in_screen.dart
  learning_tracker/lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart
  test/sync/sync_rework_orchestrator_test.dart
Tasks:
  - Make syncOrchestratorProvider a keepAlive singleton; it must NOT rebuild when
    syncEngineProvider is invalidated (drop/restructure the syncEngineProvider
    watch). One SyncOrchestrator per app session.
  - sync_orchestrator.dart: make start() idempotent; guard against double
    lifecycle-observer and double listener-set registration.
  - sign_in_screen.dart + upgrade_to_cloud_screen.dart: remove
    ref.invalidate(syncEngineProvider); trigger a pull via a direct method call.
  - Un-skip S7 and make it pass.
Commit msg: fix(sync): make SyncOrchestrator a true singleton; stop sign-in invalidation (S7)

── Agent E — Firestore rules / indexes / layout reconciliation ──
Owns exclusively:
  learning_tracker/firestore.rules
  learning_tracker/firestore.indexes.json
  learning_tracker/firebase.json
  firestore.rules                       (repo root — DELETE)
  firestore.indexes.json                (repo root — DELETE)
  docs/firestore-collection-layout.md
Tasks:
  - Rewrite learning_tracker/firestore.rules for the LIVE nested layout
    (users/{uid}/learner_profiles/{profileId}/<collection>/...): completion
    documents append-only (allow update, delete: if false), field whitelists,
    a points range check, completed_at <= request.time. Keep isOwner(uid) gating.
  - Fix learning_tracker/firestore.indexes.json with correct composite indexes
    for the nested layout; wire it into learning_tracker/firebase.json.
  - DELETE the dead repo-root firestore.rules and firestore.indexes.json — they
    describe an unbuilt top-level layout and would deny the app's real writes.
  - Update docs/firestore-collection-layout.md to describe the actual nested
    layout (or mark it superseded).
  - Do NOT deploy. Commit the files only.
Commit msg: fix(sync): reconcile firestore rules/indexes to live nested layout; append-only completions

── Agent F — Retire the legacy OfflineQueue completion path ──
Owns exclusively:
  learning_tracker/lib/features/sync/data/offline_queue.dart
  learning_tracker/lib/core/database/daos/sync_queue_dao.dart
  learning_tracker/lib/features/sync/data/sync_engine.dart   (free now — Wave 1 Agent C is committed)
Tasks:
  - Remove the now-dead completion handling: SyncEngine.pushCompletionsBatch
    (~:740-748) and SyncEngine's enqueueCompletion usage; the 'completion' case
    in offline_queue.dart's flush switch (unreachable for new data after Wave 1).
  - IMPORTANT: OfflineQueue still serves bookmark, settings, streak, goal,
    profile, ledger_entry, etc. — DO NOT remove those. Touch only completion code.
  - Add a one-time launch purge of any stale operationType='completion' rows left
    in sync_queue from before the fix.
Commit msg: refactor(sync): retire legacy OfflineQueue completion path (outbox is canonical)

Gate (orchestrator): build_runner, make ci, make audit — all green. Commit D, E, F.

═══════════════════════════════════════════════════════════════════════
WAVE 3 — BMAD code review   (orchestrator, single step)
═══════════════════════════════════════════════════════════════════════
Run /bmad-code-review on the full diff of the rework — every commit from Wave 0
through Wave 2, i.e. everything after e5c052d0 (`git diff e5c052d0...HEAD`).
Collect ALL findings. Produce a list grouped by severity (critical / high /
medium / low), each with file:line and a proposed fix.

═══════════════════════════════════════════════════════════════════════
WAVE 4 — Fix EVERY review finding   (parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════
Fix EVERY finding — critical, high, MEDIUM, AND LOW. No finding is deferred,
downgraded, or waved off. Medium and low are in scope explicitly.
- Partition the findings into disjoint file-sets; spawn one agent per partition,
  in parallel. Each agent fixes only its files and adds a regression test where
  the finding warrants one.
- Gate (orchestrator): build_runner, make ci, make audit — green. Commit each
  agent's slice: fix(review): <short description>.
- If Wave 4's changes are non-trivial, run /bmad-code-review ONCE MORE on the
  Wave 4 diff and fix any new findings the same way (all severities) before
  proceeding.

═══════════════════════════════════════════════════════════════════════
WAVE 5 — Final verification   (1 agent, then orchestrator report)
═══════════════════════════════════════════════════════════════════════
- Un-skip ALL remaining S1-S9 tests; confirm every one passes.
- Run: make ci  and  make audit  — both fully green; `dart analyze` 0 issues.
- Run the sync story tests: make test-story-25.12, make test-story-25.13,
  make test-story-25.16, make test-story-27.5, and
  flutter test test/story_acceptance/epic_13_cloud_sync_test.dart
              test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart
              test/story_acceptance/regression_invariants_test.dart
              test/sync/
- Commit any final test un-skips: test(sync): activate sync rework invariant net (S1-S9)
- Produce a final report: every commit grouped by wave; S1-S9 status; the
  before/after numbers for a 655-item bulk mark (research doc §2.9); and any
  follow-ups (notably: migrating the remaining non-completion entity kinds off
  the legacy OfflineQueue onto the outbox — out of scope here, recommended next).

═══════════════════════════════════════════════════════════════════════
DO NOT, at any point: create worktrees or branches; let two agents in a wave
share a file; skip a gate; defer a medium/low review finding; deploy Firestore
rules; bypass hooks. If a wave's files genuinely cannot be made disjoint, split
that wave into two sequential sub-waves rather than sharing a file.
```

---

## Wave summary

| Wave | Agents | Disjoint file ownership | Delivers |
|---|---|---|---|
| 0 | 1 | new `test/sync/sync_rework_*` files | baseline confirmed; S1–S9 net (skipped) |
| 1 | A · B · C | A: writer/repo/daos · B: gateway/pipeline/processor · C: `sync_engine.dart` | batched local write, single queue, batched idempotent push, echo filter, flush guard, summaries dropped |
| 2 | D · E · F | D: orchestrator+screens · E: rules/indexes/layout · F: `offline_queue`+`sync_queue_dao`+`sync_engine` | singleton orchestrator, hardened rules, legacy queue retired |
| 3 | orchestrator | — | `/bmad-code-review` findings |
| 4 | parallel | partitioned by finding | every finding fixed — incl. medium + low |
| 5 | 1 | — | full green, S1–S9 active, final report |

All work lands on `dev`. No worktrees. Verification gate (`make ci` + `make audit`) between every wave.

---

## Addendum — overdue-count defects (diagnosed 2026-05-19)

Two bugs behind a user report: the dashboard `OVERDUE` count is wrong and unstable — Daf Yomi showed overdue on one launch, gone on the next, with nothing marked done between. Diagnosed from code + live Firestore data + diagnostic log `users/{uid}/diagnostic_logs/3CSalXoTY6rkrgNdZUdD` (captured 2026-05-19T09:08Z).

### Bug 1 — a program track with a chosen start ref never advances or goes overdue (certain)

`_applyProgramCalendarOverrides`, `learning_tracker/lib/features/scheduler/presentation/providers/scheduler_providers.dart:830-1009`.

When `profile_programs.tracking_start_ref` is a plain ref with no `offset:`/`|ref:` prefix (live data: the `bavli` enrollment has `tracking_start_ref = "Chullin 18"`), the `userSelectedTodayRef` branch (`:924-944`) treats that ref as *today's* unit and ignores elapsed days. It then tries to fetch the following days, gated by:

```
final startRangeDate = todayDate.add(const Duration(days: 1));        // :935
final rangeEntries = startRangeDate.isBefore(todayDate) ? ... : <…>[]; // :936
```

`startRangeDate` is tomorrow → `startRangeDate.isBefore(todayDate)` is always false → `rangeEntries` is always empty → `entries == [todayEntry]` → exactly one task, `isOverdue: false` (`:995`), every day.

Effect: the program (Daf Yomi / `bavli`) is frozen on its start daf — never advances, never accrues a backlog. `OVERDUE 0` for Daf Yomi is this bug. The intended `offset:N|ref:REF` encoding is parsed but the `offset:N` is never consumed.

Pure scheduler logic, **not** a sync bug. Waves 1–2 as written do not touch `scheduler_providers.dart`, so this is **outside the current plan's scope**. Fix direction: the started-with-a-ref path must derive elapsed days from `tracking_start_date` and emit catch-up/overdue entries like the calendar-derived branch (`:945-968`) already does.

### Bug 2 — daily plan computed against a DB still being mutated by async sync (the flip-flop)

`OVERDUE` = `count(daily_plans WHERE isOverdue)`, produced by the `allDailyTasks` provider (`scheduler_providers.dart:260-392`) via `DailyPlanRepository.getOrSnapshotPlan` / `rebuildPlan` (`learning_tracker/lib/features/scheduler/data/repositories/daily_plan_repository.dart`). `isOverdue` is persisted to and read back from the `daily_plans` table verbatim — the snapshot itself is faithful.

The problem is timing. Diagnostic log, one launch:

- launched OFFLINE (`sync_listeners_attach_skipped_offline`);
- `sync_orchestrator_pull_on_launch_start` logged **twice**, 2 ms apart — independently confirms the Wave 1 **S8** defect (pull-on-launch not deduped);
- ~3.5 s post-launch the network came up and sync merged `curriculum_tracks` (2), `profile_programs` (1) and `completions` (655) into the local DB — all *after* the dashboard had rendered.

`allDailyTasks` snapshots the plan on first read of the day; `rebuildPlan` **deletes + regenerates** that snapshot whenever sync-driven DB changes trip the `snapshotMissingActiveCurriculum` guard (`scheduler_providers.dart:294-342`). So `OVERDUE` is "whatever the last regeneration produced" and changes between launches with no user action — for Daf Yomi and self-paced Mishnayos alike.

Sync-adjacent and in the spirit of this rework, but not covered by S1–S9. Fix direction: make the day's plan deterministic — do not regenerate it against a DB still being mutated by an in-flight sync (settle the launch sync before the first plan build, or treat the day's snapshot as immutable). Caveat: the scheduler path has **no logging**, so the rebuild trigger is inferred from code + sync timing, not a logged scheduler trace — adding scheduler logging would make this directly verifiable.

### Related minor defect

`dashboard_body.dart:134` — `final allTasks = dailyTasksAsync.value ?? const <DailyTask>[];` — renders `OVERDUE / TODAY / CHAZARA` as 0 whenever the provider is loading or errored, silently masking those states as "0 overdue".

### Scope decision needed

- **Bug 2** fits this rework (sync timing) but needs its own invariant + wave — currently unscoped.
- **Bug 1** is a scheduler bug outside the current waves' file ownership — it needs either an added wave/agent here or a separate fix.
- Neither is reflected in research doc §2/§7.
