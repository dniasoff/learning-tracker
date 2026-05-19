# Execution Prompt — 2026-05-17 Outstanding Items

Paste the content below into a fresh Claude Code session on the `dev` branch.

Full plan at: `/home/daniel/.claude/plans/jolly-kindling-hinton.md`

---

```
Execute the plan at /home/daniel/.claude/plans/jolly-kindling-hinton.md on the dev branch.
Work proceeds in waves. All agents use isolation: "worktree". All worktrees merge to dev
before the next wave starts. Each agent runs make ci in their worktree before returning.

Step 0 — Verification sweep (single blocking agent):
  Run: cd learning_tracker && flutter test test/story_acceptance/regression_invariants_test.dart --reporter=expanded
  Run: flutter test test/story_acceptance/track_lifecycle_test.dart --reporter=expanded
  Run: make ci
  All must be green. Report any failures before proceeding. Do not continue if any test fails.

Wave 1 — Small fixes (three parallel agents, each in an isolated worktree):

  Agent A — Fix F1: pace-goal forecast anchor drift
    File: learning_tracker/lib/features/track_setup/presentation/screens/track_detail_screen.dart
    Method: _estimatedFinish() ~line 343-362
    Change: DateTimeFactory.nowLocal().add(Duration(days: days))
         → goal.createdAt.toLocal().add(Duration(days: days))
    Semantics: projected finish anchors to goal-creation date; only moves when user makes progress.
    Also add invariant test N7 to learning_tracker/test/story_acceptance/regression_invariants_test.dart:
      - Create a pace goal with createdAt = 7 days ago, 100 items, 10/week pace.
      - Assert projected finish = goal.createdAt + 70 days (not DateTime.now() + 70 days).
      - Call twice; assert identical result (no drift).
    Run make ci. Commit: "fix(forecast): anchor Est. finish to goal.createdAt — stable across days (N7)"

  Agent B — Fix F2: "Yom Rishon" subtitle on Sunday (BUG-4 recurring)
    File: learning_tracker/lib/features/track_setup/presentation/steps/step_study_days.dart
    Change: Delete _daySubtitle() method (lines 125-130). At call site (line ~78), replace
            subtitle: _daySubtitle(dayNum)  →  subtitle: ''
    Also check lines 79-84 for any Friday colour override; remove if present.
    Confirm no other call sites for _daySubtitle exist.
    Run make ci. Commit: "fix(wizard): remove Yom Rishon subtitle from Study Days step (BUG-4)"

  Agent C — Fix F3 + Verify F4
    F3a (Root breadcrumb, Bug #5):
      File: learning_tracker/lib/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart
      Read the full file first. Hide the root-level breadcrumb chip entirely when at the root
      (i.e. when there is no parent selection), or replace "Root" with the curriculum name.
    F3b (100% progress, Bug #5):
      File: learning_tracker/lib/features/track_setup/presentation/screens/add_track_flow_screen.dart
      Find the progress % calculation (~line 717). Change it to exclude the current (unfinished)
      step from the numerator so it shows <100% while still on the last step.
    F4 (verify skip-for-now resolved):
      Read step_goal.dart in full. Confirm TextButton skip has onPressed: () => widget.onComplete(null).
      Read step_chazara.dart in full. Confirm no "Skip (no review)" button exists.
      If both are clean, document as verified — no code change needed.
    Run make ci. Commit: "fix(wizard): Step 7 root label + progress %; verify skip resolved (Bug #5/#6)"

Merge all Wave 1 worktrees to dev. Run make ci on dev. All must be green.

Code review:
  Run /bmad-code-review on all diffs since commit 280e1d1d (last review commit).

Wave 2 — Code review fixes (parallel agents, one per finding):
  Fix every MEDIUM and LOW finding from the review.
  Each agent runs make ci. All merge to dev. Run make ci on dev. Commit all.

Wave 3 — Scheduler investigation (two parallel agents):

  Agent D — Investigate and fix F5: "Nothing to learn" on new self-paced track (Bug #1)
    Read: learning_tracker/lib/features/track_setup/presentation/screens/add_track_flow_screen.dart
          lines 515-524 (_finishFlow) and 641-670 (_applySelfPacedPriorCompletions)
    Read: learning_tracker/lib/features/scheduler/ — SchedulerEngine.generateDailyTasks lines 70-353
    Trace the flow: _finishFlow → createTrack → _applySelfPacedPriorCompletions → onTrackChanged → scheduler.
    Find where no tasks are generated. Write a failing unit/integration test. Fix. Confirm green.
    If prior learning marks EVERYTHING complete and 0 tasks is correct, document as working-as-designed
    and add a UI note to the wizard completion screen.
    Run make ci. Commit: "fix(scheduler): ensure tasks generated after prior-learning bulk-mark"

  Agent E — Investigate and fix F6: No overdue tasks on app open (Bug #8)
    Read: learning_tracker/lib/features/scheduler/domain/ — SchedulerEngine, all files
    Read: learning_tracker/lib/features/scheduler/data/repositories/daily_plan_repository.dart lines 34-87
    Read: learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_helpers.dart lines 36-109
    Root cause: activatedAt = now → no prior-day plan rows → overdue is empty even after days pass.
    Fix: derive overdue from studyDayConfig × elapsed calendar dates since activatedAt, independent
    of whether daily_plan rows exist. Write failing test. Fix. Confirm green.
    Run make ci. Commit: "fix(scheduler): derive overdue from studyDayConfig × elapsed days (Bug #8)"

Merge Wave 3 worktrees to dev. Run make ci. All must be green.

Wave 4 — Product features (three parallel agents):

  Agent F — I-3: Rich Items Learned breakdown + Lifetime view
    Two new screens under learning_tracker/lib/features/progress/presentation/screens/:
    - items_learned_screen.dart: per-curriculum hierarchy drill (track completions only).
      Reuse CurriculumProgressService and existing hierarchy config providers.
      Motivational presentation: visual coverage per seder/masechta/daf equivalent.
    - lifetime_view_screen.dart: same layout, all completions (track + bulk-marked).
    New providers in learning_tracker/lib/features/progress/presentation/providers/ for each view.
    Add acceptance tests. Run make ci. Commit: "feat(progress): Items Learned breakdown + Lifetime view (I-3)"

  Agent G — I-4: Curriculum overlap (Tenach ⊇ Chumash + Nach)
    A Bereishit Perek completed via a Chumash track must also count toward Tenach.
    Define an overlap map (e.g. CurriculumOverlapRegistry) in
      learning_tracker/lib/core/enums/curriculum_id.dart or a new file alongside it.
    Apply deduplication in Items Learned and Lifetime view providers when aggregating counts.
    Add acceptance tests for the overlap case. Run make ci.
    Commit: "feat(progress): deduplicate Tenach/Chumash/Nach overlap in Items Learned (I-4)"

  Agent H — I-6: Sluggishness investigation
    Profile the app via Flutter DevTools connected via ADB to the user's device.
    Capture CPU flame graph and widget rebuild counts for Dashboard and Progress screens.
    Identify the top rebuild hotspot (likely a provider rebuilding too broadly on completion events).
    Apply targeted fixes: narrow provider scope, use select(), switch ref.watch to ref.listen
    in non-UI contexts where appropriate.
    Document findings in docs/perf-findings-2026-05-17.md.
    Run make ci. Commit: "perf: targeted provider-scope fixes for sluggishness (I-6)"

Merge Wave 4 worktrees to dev. Run make ci. All must be green.

Wave 5 — Safe consolidation (three parallel agents):

  Agent I — C4: Delete dead scheduling_strategy cluster
    Pre-check: grep -rn 'scheduling_strategy' learning_tracker/lib/ must return 0 results
    outside the cluster files themselves.
    Delete:
      learning_tracker/lib/features/scheduler/domain/services/scheduling_strategy.dart (921 lines)
      learning_tracker/lib/features/scheduler/domain/services/scheduling_strategy_runner.dart
      Any test files that ONLY reference these deleted files.
    Run make ci. Commit: "refactor(scheduler): delete dead scheduling_strategy cluster (921 lines, C4)"

  Agent J — C5: Extract SefariaRefMatcher from scheduler_providers.dart
    File: learning_tracker/lib/features/scheduler/presentation/providers/scheduler_providers.dart (1,333 lines)
    Extract the ~350-line Sefaria ref fuzzy-matching/regex block into:
      learning_tracker/lib/features/scheduler/domain/services/sefaria_ref_matcher.dart
    No logic change — pure extraction. Update all references. Run make ci.
    Commit: "refactor(scheduler): extract SefariaRefMatcher domain service (C5)"

  Agent K — C6: Decompose createTrack and generateDailyTasks
    File: TrackCreationService.createTrack (~190-line god method) — split along SRP lines:
      separate methods/classes for: track restore, curriculum activation, goal creation, bookmark upsert.
    File: SchedulerEngine.generateDailyTasks — remove duplicated guard (lines 204 and 211, same condition).
    No behavior change. Run make ci.
    Commit: "refactor(scheduler): decompose createTrack + remove duplicate guard in generateDailyTasks (C6)"

Merge Wave 5 worktrees to dev. Run make ci. All must be green.

Wave 6 — Higher-risk consolidation (DO NOT execute autonomously):
  C1 (collapse completion tables), C2 (FK constraints), C3 (unify delete semantics),
  and I-5 (two-way cross-device sync) require schema migrations and conflict-resolution design.
  Open a new planning session before starting any of these.
  Write a one-line entry for each in docs/open-items.md and stop.

Final verification:
  cd learning_tracker && make ci
  All 4,900+ tests must pass. dart analyze must report 0 issues.
  Report a summary of every commit made, grouped by wave.
```
