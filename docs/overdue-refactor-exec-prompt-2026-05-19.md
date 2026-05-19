# Execution Prompt — Overdue System Refactor (2026-05-19)

Paste the fenced block below into a fresh Claude Code session on the `dev` branch.

- **Full architecture + resolved decisions:** [`docs/planning/overdue-refactor-architecture.md`](planning/overdue-refactor-architecture.md) — read the whole file before starting. §4–§7 (projection model, durability, Clear Overdue) and §10–§11 (resolved decisions + migration order) are load-bearing.
- **Bug 1 / Bug 2 diagnosis with file:line:** the Addendum of [`docs/sync-rework-exec-prompt-2026-05-18.md`](sync-rework-exec-prompt-2026-05-18.md).
- **Execution model:** a wave-based agent squad on `dev`. **No worktrees.** Unlike the Firebase sync rework, this work is *concentrated in the scheduler* — Waves 1–3 are single-agent and sequential by necessity; genuine parallelism is Wave 4 (features) and Wave 6 (review fixes). Safety: strict disjoint-file ownership inside any parallel wave + an orchestrator gate between every wave.
- **Working-tree note:** a prior delete-based `clearOverdueForTrack` (in `daily_plan_dao.dart` / `edit_track_screen.dart` / the `.arb` files) may be present from an earlier attempt. Wave 4 Agent A replaces it wholesale — that is expected, not a conflict.
- **Pre-work HEAD:** the orchestrator captures `git rev-parse HEAD` as its first action.

---

```
Execute the Overdue System Refactor. The full architecture and the resolved
decisions are in docs/planning/overdue-refactor-architecture.md — read the WHOLE
file now, before anything else. The Bug 1 / Bug 2 diagnosis (with file:line) is in
the Addendum of docs/sync-rework-exec-prompt-2026-05-18.md.

You are the ORCHESTRATOR. You spawn agents, enforce gates, and commit. You do not
edit production code yourself except to resolve a gate failure.

First action: run `git rev-parse HEAD` and record it as the pre-work HEAD.

═══════════════════════════════════════════════════════════════════════
GLOBAL RULES (apply to every wave)
═══════════════════════════════════════════════════════════════════════

SCOPE — NOTHING DEFERRED
- Every item in docs/planning/overdue-refactor-architecture.md is IN SCOPE for
  this run: Bug 1, the projection, the cutover, retiring backfill, Clear Overdue,
  the sync-completeness gate, the mandatory self-paced pace + its migration, and
  the notification fixes. Nothing is deferred to a later effort. The run is not
  finished until Wave 7 confirms every deliverable.

BRANCH & ISOLATION
- All work happens on `dev`. NO worktrees. NO feature branches.
- Every agent edits files directly in the shared working tree.
- A wave's parallel agents own STRICTLY DISJOINT files. The file lists below are a
  starting assessment, not a verified partition — this refactor has no pre-baked
  file-level fix list. Before spawning a parallel wave, READ the relevant files,
  finalize a truly disjoint partition, and if the files cannot be made disjoint,
  split the wave into sequential sub-waves rather than sharing a file.
- If an agent finds it needs a file owned by another agent, it STOPS and reports
  to you rather than editing it.

NO-WORKTREE COORDINATION PROTOCOL
- Agents EDIT their files only. Agents do NOT run build_runner, do NOT run
  `make ci`, and do NOT commit.
- Each agent, when done, reports: (a) the exact files it changed, (b) a one-line
  conventional commit message, (c) which O-tests it un-skipped and that they pass
  in isolation (`flutter test <its own test file>`), (d) anything notable.
- After ALL agents in a wave report done, YOU run, in order:
    1. cd learning_tracker && dart run build_runner build --delete-conflicting-outputs
    2. make ci          (analyze + format + schema-check + all tests)
    3. make audit       (layering greps + custom lints)
- If the gate is RED: identify the culprit, dispatch a single fix agent against
  the offending files, re-run the gate. Repeat until GREEN.
- When GREEN: commit each agent's slice as its OWN commit, sequentially —
  `git add <that agent's files> && git commit <files> -m "..."`. One agent = one
  commit.
- Do NOT start wave N+1 until wave N is committed and the gate is GREEN.

DISCIPLINE
- Every fix ships as ONE commit containing the characterization test (un-skipped
  from the Wave 0 net), the change, and the test green. A fix is not done otherwise.
- If a change breaks a pre-existing test, update the test to match the CORRECTED
  behaviour — never to re-encode a bug. If unsure whether a test encodes intended
  behaviour, STOP and report.

CONVENTIONS
- Commit style: conventional, scoped — fix(scheduler:), feat(scheduler:),
  refactor(scheduler:), test(scheduler:), fix(dashboard:), fix(review:). Match
  recent git history.
- Run codegen after any Drift/Freezed/Riverpod change (orchestrator does this).
- Respect the 5 layering rules in learning_tracker/CLAUDE.md.
- The projection is a PURE function — no I/O, no clock reads inside it; `today`
  and every input are passed in. That is what makes it deterministic and testable.

═══════════════════════════════════════════════════════════════════════
WAVE 0 — Baseline + characterization net   (1 agent, blocking)
═══════════════════════════════════════════════════════════════════════
First: run `make ci`. It MUST be green. If not, STOP and report.

Then create the characterization net for the overdue projection — tests against
fakes/fixtures (see test/mocks/, test/fixtures/, test/helpers/). Create THREE
files so later waves own disjoint test files:

  test/scheduler/overdue_projection_test.dart       (O1, O2, O3, O7)
  test/scheduler/overdue_durability_test.dart       (O4, O5, O6)
  test/scheduler/overdue_notifications_test.dart    (O8)

The invariants:
  O1 — Determinism. Computing the overdue set twice from identical inputs
       (anchor, completion set, today) yields an identical result.
  O2 — Program advance (Bug 1). A program track anchored N days ago with no
       completions yields one unit per elapsed day — the prior days overdue,
       today's day as today. NOT frozen on its start ref.
  O3 — Clear Overdue / re-anchor. Re-anchoring a program track to today makes the
       overdue set empty and today's unit the calendar unit for today. Re-running
       it the same day is idempotent.
  O4 — Reinstall durability. Discard the local plan cache; recompute from the
       synced inputs only — the overdue set is identical.
  O5 — Sync-timing immunity. The projection computed against a partially-merged
       input set and against the fully-merged set converge to the same value, and
       no wrong value is ever persisted as authoritative.
  O6 — Sync-completeness gate. With the "initial sync complete" flag unset, the
       overdue view reports a not-ready/syncing state — never a number, never 0.
  O7 — Self-paced needs a pace. A self-paced track cannot be modelled without a
       pace; its overdue set is the units behind pace x elapsed_study_days.
  O8 — Notifications track the projection. The reminder body count equals the
       projection count; a re-anchor triggers a reschedule to the new count.

Every test must COMPILE and be marked `skip: 'un-skip in Wave N'` so `make ci`
stays green. Each later agent un-skips its own tests.

Gate: build_runner, make ci, make audit — all green.
Commit: test(scheduler): characterization net for overdue refactor (O1-O8, skipped)

═══════════════════════════════════════════════════════════════════════
WAVE 1 — Bug 1: program tracks advance from their anchor   (1 agent)
═══════════════════════════════════════════════════════════════════════
Owns exclusively:
  learning_tracker/lib/features/scheduler/presentation/providers/scheduler_providers.dart
  test/scheduler/overdue_projection_test.dart   (un-skip O2 only)
Task:
  - In _applyProgramCalendarOverrides (~:830-1009): a program track must advance
    from its anchor by walking the calendar forward. Remove the dead range gate
    `(today+1).isBefore(today)` (~:935-936) and the userSelectedTodayRef branch's
    frozen-ref behaviour. Today's unit is calendar(program, today); every elapsed
    calendar unit from the anchor that is not completed is overdue.
  - Un-skip and pass O2.
Commit: fix(scheduler): program tracks advance from their anchor, not frozen on start ref (O2)
This is the contained, independent fix from architecture §11 step 1.

═══════════════════════════════════════════════════════════════════════
WAVE 2 — Pure schedule + projection module   (1 agent, NEW files only)
═══════════════════════════════════════════════════════════════════════
Owns exclusively (new files — nothing existing is edited):
  learning_tracker/lib/features/scheduler/domain/projection/   (new directory)
  test/scheduler/overdue_projection_test.dart   (un-skip O1, O3, O7)
Task:
  - Implement, as PURE functions, the model from architecture §4-§5:
      programSchedule(anchor, calendar, today) -> units by date
      selfPacedSchedule(anchor, pace, studyDayPattern, orderedRefs, today) -> ...
      project(schedule, completions, today) -> { overdue, dueToday, review }
  - Everything keyed on sefariaRef (architecture §10.1). No I/O, no clock reads;
    all inputs are parameters.
  - VERIFY architecture §10.1's open check: confirm the curriculum ordering the
    self-paced schedule relies on is stable across content-DB versions (the seed /
    learning_order path). Report findings; if it is NOT stable, STOP and report.
  - This module is built ALONGSIDE the existing snapshot path — it is NOT wired in
    yet (architecture §11 step 2).
  - Un-skip and pass O1, O3, O7.
Commit: feat(scheduler): pure overdue projection module (O1, O3, O7)

═══════════════════════════════════════════════════════════════════════
WAVE 3 — Cut over to the projection   (1 agent — scheduler-concentrated)
═══════════════════════════════════════════════════════════════════════
Owns exclusively:
  learning_tracker/lib/features/scheduler/presentation/providers/scheduler_providers.dart
  learning_tracker/lib/features/scheduler/data/repositories/daily_plan_repository.dart
  learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_body.dart
  learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_helpers.dart
  test/scheduler/overdue_durability_test.dart   (un-skip O4, O5)
Tasks:
  - Make the Wave 2 projection AUTHORITATIVE: the daily-tasks provider serves the
    projection's output; the dashboard reads it.
  - Demote `daily_plans` to a disposable, input-keyed cache — never the source of
    truth. Remove the snapshotMissingActiveCurriculum rebuild guard (~:294-342)
    and the rebuildPlan-on-sync-change behaviour.
  - DELETE the now-dead backfill machinery — backfillMissingSnapshots and
    backfillStudyDaySnapshots and their call sites (architecture §11 step 4). The
    schedule function spans missed days intrinsically.
  - Notifications inherit the projection automatically (reminderSyncEffect already
    watches the daily-tasks provider) — confirm this, do not rewire it.
  - A legacy self-paced track with no pace is treated as "needs pace" (Wave 4
    Agent C handles the migration prompt) — do not invent a default for it.
  - Un-skip and pass O4, O5.
Commit: refactor(scheduler): make the overdue projection authoritative; retire snapshot-as-truth + backfill (O4, O5)

═══════════════════════════════════════════════════════════════════════
WAVE 4 — Features + hardening   (parallel — VERIFY disjoint first)
═══════════════════════════════════════════════════════════════════════
Before spawning: read each agent's files and confirm a disjoint partition. The
l10n `.arb` files are needed by Agents A and C — run A and C as sequential
sub-waves (A then C), with B and D in parallel alongside, OR have one own the
`.arb` files and the other report its keys to you.

── Agent A — Clear Overdue as a re-anchor ──
Owns: daily_plan_dao.dart, profile_program_dao.dart, edit_track_screen.dart,
      lib/l10n/app_en.arb, lib/l10n/app_he.arb,
      test/track_setup/clear_overdue_button_test.dart   (new)
Task:
  - Replace the delete-based clearOverdueForTrack (it deletes daily_plans rows —
    the disposable cache — so the clear evaporates; architecture §7). The button
    instead RE-ANCHORS: write tracking_start_date = today and tracking_start_ref =
    today's calendar unit to the synced profile_programs row.
  - Keep the existing button UI — confirm dialog, program-only gating,
    greyed-when-empty, the l10n keys. Program tracks only.
Commit: feat(scheduler): Clear Overdue re-anchors the track instead of deleting cache rows

── Agent B — Sync-completeness gate ──
Owns: dashboard_body.dart, plus the sync-flag store/provider it creates,
      test/scheduler/overdue_durability_test.dart   (un-skip O6)
Task:
  - Add a persisted "initial sync complete" flag, set the first time a full pull
    finishes (architecture §10.2).
  - dashboard_body.dart: replace `dailyTasksAsync.value ?? const <DailyTask>[]`
    (~:134) — before the flag is set, render a "syncing..." state, never 0.
  - Un-skip and pass O6.
Commit: fix(dashboard): gate overdue on first-sync-complete; render syncing, not 0 (O6)

── Agent C — Mandatory self-paced pace ──
Owns: the track-setup / goal-setup screens and flow, the kDefaultBackfillPace
      removal site, a migration for existing pace-less tracks,
      test/track_setup/mandatory_pace_test.dart   (new)
Task:
  - The setup UI must FORCE a pace for a self-paced track — it cannot be created
    without one (architecture §10.3). Remove the kDefaultBackfillPace constant and
    its default-pace path entirely.
  - Migration: an existing pace-less self-paced track must prompt the user to set
    a pace before the track resumes. No pace is auto-assigned.
Commit: feat(track-setup): require an explicit pace for self-paced tracks; drop the default-pace hack

── Agent D — Notification cosmetics ──
Owns: notification_providers.dart,
      test/scheduler/overdue_notifications_test.dart   (un-skip O8)
Task:
  - The reminder body says "X tasks today" but X includes overdue + review — make
    the wording or the count honest.
  - Suppress the reminder when the count is 0 (no "You have 0 tasks today").
  - Un-skip and pass O8.
Commit: fix(notifications): honest reminder body count; suppress the empty reminder (O8)

Gate: build_runner, make ci, make audit. Commit A, B, C, D.

═══════════════════════════════════════════════════════════════════════
WAVE 5 — BMAD code review   (orchestrator, single step)
═══════════════════════════════════════════════════════════════════════
Run /bmad-code-review on the full diff — everything after the pre-work HEAD
(`git diff <pre-work-HEAD>...HEAD`). Collect ALL findings, grouped by severity
(critical / high / medium / low), each with file:line and a proposed fix.

═══════════════════════════════════════════════════════════════════════
WAVE 6 — Fix EVERY review finding   (parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════
Fix EVERY finding — critical, high, MEDIUM, AND LOW. Nothing is deferred,
downgraded, or waved off. Partition the findings into disjoint file-sets; one
agent per partition, in parallel; each adds a regression test where the finding
warrants one. Gate, then commit each slice: fix(review): <short description>.
If Wave 6's changes are non-trivial, run /bmad-code-review once more on the
Wave 6 diff and fix any new findings the same way.

═══════════════════════════════════════════════════════════════════════
WAVE 7 — Final verification + report   (1 agent, then orchestrator report)
═══════════════════════════════════════════════════════════════════════
- Un-skip ALL remaining O1-O8; confirm every one passes.
- make ci and make audit fully green; `dart analyze` reports 0 issues.
- Run the scheduler and dashboard story acceptance tests, plus
  `flutter test test/scheduler/`.
- Walk docs/planning/overdue-refactor-architecture.md and confirm EVERY
  deliverable is done: §3 (Bug 1, Bug 2), §4-§7 (projection, durability, Clear
  Overdue), §8 (notifications), §10 (all three resolved decisions, incl. the
  §10.1 content-ordering check), §11 (backfill retired). Nothing outstanding.
- Final report: every commit grouped by wave; O1-O8 status; an explicit statement
  that the dashboard OVERDUE count is now deterministic across launches.

═══════════════════════════════════════════════════════════════════════
DO NOT, at any point: create worktrees or branches; let two agents in a wave
share a file; skip a gate; defer a review finding of any severity; leave any
architecture-doc deliverable unfinished; bypass hooks. If a wave's files cannot
be made disjoint, split it into sequential sub-waves.
```

---

## Wave summary

| Wave | Agents | Delivers |
|---|---|---|
| 0 | 1 | baseline green; O1–O8 characterization net (skipped) |
| 1 | 1 | Bug 1 — program tracks advance from their anchor |
| 2 | 1 | pure schedule + projection module (new files, alongside) |
| 3 | 1 | projection made authoritative; snapshot-as-truth + backfill retired |
| 4 | A · B · C · D | Clear Overdue re-anchor · sync-completeness gate · mandatory pace + migration · notification fixes |
| 5 | orchestrator | `/bmad-code-review` findings |
| 6 | parallel | every finding fixed — incl. medium + low |
| 7 | 1 | full green, O1–O8 active, every deliverable verified, final report |

Sequential by necessity through Wave 3 — the work is concentrated in the scheduler — then parallel in Waves 4 and 6. All work lands on `dev`. No worktrees. Verification gate (`make ci` + `make audit`) between every wave.
