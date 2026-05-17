# Tracking System Review & Quality Assessment — 2026-05-17

**Prepared by:** Analyst (Mary), with Architect / QA / Technical-Research review lenses
**Status:** ASSESSMENT — awaiting owner decision on remediation approach
**Scope:** the sync, scheduler, track-lifecycle and progress/completion subsystems
**Supersedes:** the ad-hoc `bug-reports-2026-05-15.md` round (never committed — see §1)

## TL;DR

A single testing session surfaced **8 bugs**, every one dating from *after* the Epic 25/26/27 ground-up rebuild (2026-05-13 → 05-15). They are not 8 unrelated defects — they are **two root problems**:

- **Root 1 — Code.** A sync/data layer rebuilt in ~48 hours and cut over before it was sound.
- **Root 2 — Process.** A bug-fixing loop that produces *documents and plans* but does not *commit or verify fixes* — so bugs recur.

A structural audit finds the data model **"rushed but recoverable — not fundamentally unsound."** The recommendation is therefore **neither** another rebuild (the cause of this crisis) **nor** continued bug-by-bug patching (proven not to converge). It is a disciplined sequence: **Freeze → Net → Repair → Close the loop** (§5–§7).

## 1. How we got here

Over 19 days (2026-04-26 → 05-15) the repo took **380 commits**: 135 `fix`, 120 `feat`, **10 `test`** — a 13:1 fix-to-test ratio. Within that, **Epics 25/26/27 (DNI-322 → DNI-392)** were a ground-up rebuild — new Drift schema (`schema v1`), new Firestore layout, the SyncEngine decomposed, `core/` rebuilt — **~174 commits in 48 hours**, integrated in 14 cherry-pick batches, with the **SyncEngine cutover on 2026-05-15** ("ACs all green"). Every bug in §2 dates from after that cutover.

A prior bug round was documented in `bug-reports-2026-05-15.md` with a fix plan and a ready-to-run prompt. **Those files were never committed, and the fixes never landed** — `step_goal.dart` was never touched; `step_chazara.dart` / `step_study_days.dart` still carry stale *uncommitted* edits. Three of that round's bugs are back in §2 (#6, #7, and #4's scenario). That is Root 2, in evidence.

## 2. Bug register

| # | Symptom | Root cause | Class | Status |
|---|---------|-----------|-------|--------|
| 1 | New self-paced track has "nothing to learn"; sync runs away | (1C) offline queue never drains + duplicate `SyncOrchestrator`s; (1A) "nothing to learn" is sync starvation, see also #8 | Sync | Root-caused |
| 1B | "Personal Best: 1" on a profile with 0 completions | Stored `max_streak` is 0; the achievement card floors/offsets it to 1 | UI / display | Root-caused |
| 2 | "655 completions" but curriculum reads "0.07%" | Count is `COUNT(*)` over stage/review rows; % is `distinct refs ÷ leaf count` — incompatible numerators, no shared definition of "done" | Data integrity | Root-caused |
| 3 | App sluggish; "836 changes pending" | Same as 1C — runaway / slow-draining offline queue | Sync | Root-caused |
| 4 | Delete track + re-add → phantom ~4% progress | `restoreOrCreate` reuses the soft-deleted row id; progress query ignores `deletedAt`; append-only completions re-attach to the "new" track | Data integrity | Root-caused |
| 5 | Wizard Step 7: "Root" label; "100%" while still on the step | Breadcrumb copy; progress counts the current (unfinished) step as done | UI | Located (cosmetic) |
| 6 | Wizard Step 6: "skip for now" with no skip action | Misleading copy. = `bug-reports-2026-05-15` BUG-2 — documented, planned, never committed | UI | Recurring |
| 7 | Wizard Step 4: "Yom Rishon" / per-day subtitles | Unwanted subtitle copy. = `bug-reports-2026-05-15` BUG-4 — documented, planned, never committed | UI | Recurring |
| 8 | No overdue tasks on app open | A (re-)added track gets `activatedAt = now` → snapshot back-fill writes 0 prior-day rows → overdue is derived *only* from prior-day rows = empty; elapsed calendar days never enter the calculation | Scheduler | Root-caused |

## 3. Audit findings

### 3.1 Data model — "rushed but recoverable"

The mutable DB (`user_database.dart`) declares 22 tables. The defining defect: **the same fact is stored in 3–5 places with nothing reconciling them.**

- A completion is recorded in `completions`, `completion_events` and the `outbox` in one transaction (`completion_writer.dart:52-122`), then teed to `streak_events` (`completion_repository_impl.dart:594-596`); `learning_ledger` is written by a *different path entirely*. Nothing keeps these mutually consistent.
- Streak state lives in both a cached `Streaks` table and a `StreakEvents` log; the cached table is stale-by-design.
- The Firestore `progress_summary` / `streak_summary` / `gamification_summary` maps (`sync_engine.dart:2443-2478`) are recomputed on every push and **never read back by the app** (verified). Write-only denormalization that can only drift.
- **No foreign keys** on `profileId` / `curriculumId` — only `trackId` is constrained. A deleted profile silently orphans rows.
- **Three delete policies in one flow:** tracks soft-delete (`deletedAt`); stages/goals hard-delete; completions are append-only *except* `TrackDao.purgeHistory`, which hard-deletes them against the table's stated INSERT-only contract.

Auditor's verdict: the append-only event-log design is *correct* — it was bolted *on top of* the legacy projection tables instead of replacing them. **Recoverable by consolidation, not rebuild.**

### 3.2 Tracking behavior — structural slop

- **God file:** `scheduler_providers.dart` — **1,333 lines** — mixes ~10 Riverpod providers with ~350 lines of Sefaria reference fuzzy-matching/regex that belongs in a domain service.
- **A dead duplicate engine:** `scheduling_strategy.dart` (**921 lines**) + `scheduling_strategy_runner.dart` — a second, complete, *divergent* scheduler implementation. **Verified dead** — nothing in the live app references it; only its own cluster and 3 test files do. Built (DNI-344), never wired in; the next commit patched the *old* engine.
- **`SchedulerEngine.generateDailyTasks`** — a 280-line method with a literally duplicated guard (`scheduler_engine.dart:204` and `:211`).
- **Triplicated bucketing:** the overdue/today/review classification is written three times (`groupTasks`, `bucketTrackTasks`, `firstTaskInTrackForCategory`).
- **`TrackCreationService.createTrack`** — one ~190-line method doing track restore + curriculum activation + goal recreation + a DB transaction + program-string parsing + bookmark upsert + 3 Firestore pushes.

## 4. Root-cause assessment — four lenses

**Analyst.** The 8 bugs cluster into data-integrity (#2, #4, #1B), sync (#1, #3), scheduler (#8) and cosmetic (#5–#7) — all post-rebuild. Collectively they prove a data/sync layer rebuilt faster than it could be made correct, multiplied by a fix process that never closes (Root 2).

**Architect.** The architecture's *bones* are sound: append-only event log, decomposed sync pipeline. The *assembly* is wrong: the event log bolted onto legacy tables, no single owner per table, no foreign keys, a god file, a dead duplicate engine. Verdict: **consolidate and repair — do not rebuild.** A third rebuild repeats the failure mode.

**QA.** 60% line coverage, golden/DAO/integration tests, and the SyncEngine cutover landed "ACs all green" — beside a runaway offline-queue loop in production. The tests pin the rebuilt code's *behaviour*; they do not assert system *invariants*. Every recurring bug (#6, #7) proves there is no regression test pinned to a fix. The suite manufactures false confidence.

**Technical Research.** Offline-first sync is a known-hard domain with known invariants — idempotent operations, dedup keys, a single drain loop, explicit per-operation acknowledgement. The bespoke queue violates each, which is precisely Bug #1/#3. These are correctable with established technique; no new framework is needed now. (Evaluating a managed local-first sync solution is a reasonable *future* exercise — not mid-crisis.)

## 5. Recommendation

**Do not patch bug-by-bug** — 380 commits / 135 fixes in 19 days proves it does not converge. **Do not rebuild again** — two rebuilds in a month; the last one caused this. Instead, **Freeze → Net → Repair → Close the loop** (§6).

The Repair and Consolidate phases *are* the refactor toward single-responsibility and a single source of truth that the owner asked for — executed the way Clean Code and XP actually prescribe: under a green test net, in small committed steps.

**Option D — scope (raised explicitly).** Independent of the above: the product surface — 22 tables, 9 curricula, multi-profile, parent/child modes, sacred-time, gamification, *and* offline+cloud sync — may exceed what a solo, AI-assisted build can keep correct. The highest-leverage simplification available is to **defer multi-device cloud sync** and run local-first until the local layer is provably sound. This is a product decision for the owner; it is recorded here because it changes the difficulty more than any single code fix.

## 6. Repair backlog (ordered)

**Phase 0 — Freeze.** No new features or refactors in sync / scheduler / track-setup / completions until Phase 2 completes.

**Phase 1 — The Net.** ~6 invariant/characterization tests, written first, most expected to FAIL today. These become the permanent regression suite:
- N1 — after an online flush, offline-queue pending count reaches 0.
- N2 — exactly one `SyncOrchestrator` instance exists per app launch.
- N3 — a fresh profile reports streak 0, personal best 0, 0 completions.
- N4 — delete track → re-add same curriculum → completion %, lifetime % and completion count are all 0.
- N5 — a self-paced track with study days and N elapsed uncompleted study days surfaces the expected overdue set.
- N6 — completion count and lifetime % move together against one shared definition of "done".

**Phase 2 — Repair the roots.** Each is ONE commit: failing test → fix → green.
- R1 [#1,#3] — make `SyncOrchestrator` a true singleton.
- R2 [#1,#3] — offline-queue drain correctness: idempotent, dedup-keyed operations, acknowledged and deleted after sync.
- R3 [#4] — track restore must not reuse the soft-deleted row id (or must cascade-purge its completions); progress query must filter `deletedAt`.
- R4 [#8] — a (re-)added track's back-fill must span the real elapsed window, or overdue must derive from `studyDayConfig × elapsed dates`.
- R5 [#2] — one definition of "done": completion count and progress % share a numerator. (Links to C1.)
- R6 [#1B] — achievement card shows stored `max_streak` verbatim.

**Phase 3 — Consolidation (the disciplined refactor — incremental, under the net).**
- C1 — collapse 3 completion tables → 1 source of truth (the event log); `completions`/`streaks`/`ledger` become derived projections with ONE owner.
- C2 — add foreign keys on `profileId` / `curriculumId` with explicit cascade.
- C3 — unify delete semantics into one policy.
- C4 — delete the dead `scheduling_strategy` cluster (921-line file + runner + 3 test files).
- C5 — break up `scheduler_providers.dart`; move Sefaria ref-matching into a domain service.
- C6 — decompose `createTrack` and `generateDailyTasks` along single-responsibility lines.

**Phase 4 — Cosmetic batch (low priority, one commit).** Bugs #5/#6/#7. Also decide the fate of the stale uncommitted edits to `step_chazara.dart` / `step_study_days.dart` — finish+commit or discard.

## 7. Process change — closing the loop

- Every bug fix ships as ONE commit containing: the failing regression test, the fix, the test green. A fix is not "done" otherwise.
- Bug reports, plans and this assessment are **committed to the repo** — no more orphaned untracked docs.
- Slow the tempo. ~20 commits/day and 174 in 48 hours produced the slop; a sustainable pace is part of the cure.

## Appendix — evidence index

- Bug #1 diagnostic log: Firestore `torah-study-tracker` → `users/uU4A22ylNnTNshb6CzZ75A9PqAD3/diagnostic_logs/Y91RBXnSoJ64jkDOPePn` (444 entries; `flush_start pendingCount: 1052`, no `flush_complete`, duplicate `pull_on_launch`).
- Data model: `user_database.dart`, `completion_writer.dart:52-122`, `completion_repository_impl.dart:594-596`, `sync_engine.dart:2443-2478`, `track_dao.dart` (`restoreOrCreate` ~303-341, `getAllForProfile` ~227-229), `completion_dao.dart:125-138`, `curriculum_progress_service.dart:79-89`.
- Behavior: `scheduler_providers.dart` (1,333 lines), `scheduling_strategy.dart` (921 lines, dead), `scheduler_engine.dart` (`generateDailyTasks` 70-353), `daily_plan_repository.dart:34-87`, `dashboard_helpers.dart:36-109`.
- History: `git log` 2026-04-26 → 05-15 (380 commits); Epics 25/26/27 = DNI-322 → DNI-392; prior round `bug-reports-2026-05-15.md` (uncommitted).
