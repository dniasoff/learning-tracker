---
title: Progress IA — Parallel Squad Execution Plan
date: 2026-05-20
author: Claude (orchestrator) for Daniel
status: Active — orchestrator executing
related:
  - docs/planning/progress-ia-redesign.md (the proposal being executed)
---

# Progress IA — Parallel Squad Execution Plan

## Globals (every wave)

- **Branch:** dev. No worktrees. No feature branches.
- **No defer:** every agent fixes every issue it sees while working. No TODOs left behind. No "shipped half-done."
- **Code quality:** no tech debt. If an agent finds a hack, smell, or layering violation in a file it owns, fix it.
- **Tests:** every code change ships with a test that exercises **real** production code (no mirror tests — see B1-B11 Finding 3). All existing tests must pass.
- **Disjoint file ownership** within a wave — no two agents in the same wave edit the same file.
- **Verification gate between waves:** orchestrator runs `make ci` + `make audit` after every wave. RED → dispatch fix agent → re-run. GREEN → commit each agent's slice as its own commit, then move to next wave.
- **One agent = one commit** (per agent's slice), conventional commit message.
- **Layering rules** (`learning_tracker/CLAUDE.md`) are non-negotiable.

## Wave summary

| Wave | Tasks | Agents (parallel) | Purpose |
|---|---|---|---|
| **W0** | — | orchestrator | Baseline: `make ci` + `make audit` green |
| **W1** | #1, #7, (#2 #3 #4 #5 #6 bundled) | 3 | Correctness + perf foundation |
| **W2** | #13 | 1 | Vocabulary sweep — l10n + Hebrew Terms toggle |
| **W3** | #9, #10, #11 | 3 | New screens built (Recent Activity, Siyumim multi-level, Lifetime Knowledge) |
| **W3b** | #8, #12 | 2 | Hub restructure + delete obsolete screens |
| **W4** | #14 | 1 | Dashboard refinement |
| **W5** | #15, #16, #17, #18 | 4 | Per-screen relabels |
| **W6** | — | orchestrator | `/bmad-code-review` on full diff |
| **W7** | review findings | parallel | Fix EVERY finding (critical / high / medium / low) |
| **W8** | — | orchestrator | Final verification + report + commit |

Estimated dispatches: 14 engineering agents + 1 review pass + N fix agents.

## Wave details

### W0 — Baseline (orchestrator)

1. Verify `git status` — owner WIP is acceptable (e.g. existing modifications to `pull_pipeline.dart`); do not commit it.
2. `cd learning_tracker && make ci && make audit`. Both MUST be green. If RED, STOP and report.
3. Record HEAD. No commit.
4. Commit the planning docs (`progress-ia-redesign.md` + this file) as a single docs commit before W1 starts, so the proposal is persisted.

### W1 — Correctness + perf (Phase A — 3 parallel agents)

File-ownership conflict on `chart_data_service.dart` means tasks #2 #3 #4 #5 #6 must be one agent.

**Agent W1-A — Task #1 (siyumim gate)**
Owns:
- `lib/features/learning/data/repositories/completion_repository_impl.dart`
- `lib/features/learning/domain/use_cases/mark_completion_use_case.dart`
- `lib/features/learning/domain/entities/completion_source.dart` (read only — already correct)
- Tests under `test/features/learning/`
Task: Pass `creditsAchievement` separately from `creditsEngagement` to `markComplete`. Change the gate at line 177 from `awardGamificationPoints` to a new `creditsAchievement` parameter. Regression test: a bulkInTrack completion of the last leaf in a masechta produces a siyum ledger entry; a lifetimeOnly completion does NOT.
Commit: `fix(learning): credit achievement tier (siyumim) for bulkInTrack completions`

**Agent W1-B — Tasks #2 + #3 + #4 + #5 + #6 (chart fixes — bundled)**
Owns:
- `lib/features/progress/domain/services/chart_data_service.dart`
- `lib/features/progress/presentation/screens/progress_charts_screen.dart`
- Tests under `test/features/progress/domain/services/`
Task:
- #2: switch `getDailyCompletions` and `getCumulativeProgress` to `CompletionTierFilter.trackAchievement`.
- #3: cap "All Time" range to the user's first live (or trackAchievement) completion date — not Jan 2000; for ranges over ~60 days aggregate by week not day.
- #4: memoize the FutureBuilders in `progress_charts_screen.dart` so they don't recreate on every `setState`. (NOTE: this screen will be DELETED in W3 by #12 — fix it anyway, as the screen is still live during W1.)
- #5: switch `getStreakCalendar` to use `getCompletionsByDateRangeAndProfile` (SQL date filter).
- #6: pass `since` + `until` to `getCompletionsByTier` in `getDailyCompletions`, `getCumulativeProgress`, `getDailyPoints`.
Regression tests: data layer returns the right rows for each tier; All-Time range query stays under N rows; date-range query at SQL level returns the right count.
Commit: `fix(progress): chart tier + range + memo + SQL pushdown for chart data`

**Agent W1-C — Task #7 (N+1 siyum detection)**
Owns:
- `lib/features/learning/domain/services/completion_detection_service.dart`
- Tests under `test/features/learning/domain/services/`
Task: Replace the per-leaf `getCompletionsForContentAndProfile` loop with a single `getCompletionsByCurriculumAndProfile` fetch, then filter in memory per leaf. Regression test: completing the last leaf of a masechta with 40 leaves performs ≤2 DB calls in detection (not 40).
Commit: `perf(learning): single-query siyum detection (drop N+1 per-leaf loop)`

Gate. Commit each agent. Move to W2.

### W2 — Vocabulary sweep (Phase C — 1 agent)

**Agent W2-A — Task #13**
Owns:
- `learning_tracker/lib/l10n/app_en.arb`
- `learning_tracker/lib/l10n/app_he.arb`
- `learning_tracker/lib/core/labels/domain_term_labels.dart`
- All call-sites that reference the retired keys (sweep)
Task per `docs/planning/progress-ia-redesign.md §"vocabulary sweep"`. Add new keys (`limud`, `chazara`, `chazaros`, `siyum`, `siyumim`, `milestone`, `trackProgress`, `lifetimeKnowledge`, `recentActivity`, `totalChazaros`, `itemsLearnedCount`, plus per-curriculum siyum labels). Retire `statCompletions`, `statUnitsDone`, `statActiveTracks`, `chartDailyActivity`, `chartCompletionsOverTime`, `chartCumulativeProgress`, `lifetimeViewTitle`. Wire `useHebrewTermsProvider` so the toggle swaps script (Latin↔Hebrew) but not concept. Run `flutter gen-l10n`. `make audit` must pass (no raw `HebrewTerms.*` leaked into `features/`).
Commit: `feat(i18n): canonical vocabulary for B1 three-tier policy (siyum/chazara/limud)`

Gate. Commit. Move to W3.

### W3 — Build new screens (Phase B partial — 3 parallel agents)

**Agent W3-A — Task #9 (Recent Activity screen)**
Owns:
- NEW: `lib/features/progress/presentation/screens/recent_activity_screen.dart`
- NEW: `lib/features/progress/presentation/providers/recent_activity_providers.dart`
- Reusable chart widgets in `lib/features/progress/presentation/widgets/` (new files only — limudim_chazaros_bar_chart.dart etc.)
- Tests
Task per `docs/planning/progress-ia-redesign.md §3`. Live-only data. Two-colour stacked bar (Limud / Chazara). Bounded "All time" range. Riverpod providers — NO FutureBuilder-in-build. Charts subtitled with the live-only scope disclaimer.
Commit: `feat(progress): Recent Activity screen (engagement-tier lens)`

**Agent W3-B — Task #10 (Siyumim & Milestones restructure)**
Owns:
- RENAME: `lib/features/progress/presentation/screens/learning_journey_screen.dart` → `siyumim_milestones_screen.dart`
- `lib/features/progress/presentation/providers/journey_providers.dart` (multi-level detection)
- `lib/features/progress/domain/models/journey_view_model.dart` (add level counters)
- Reusable widgets in `lib/features/progress/presentation/widgets/journey_*`
- Tests
Task per `docs/planning/progress-ia-redesign.md §4`. Three additive celebration levels per curriculum (unit / aggregate / curriculum-complete). Top counters split by level. Hierarchy-aware grouping with expand chevron. Curriculum-complete visually distinguished. NO provenance label. Preserves grouped/timeline toggle.
Commit: `feat(progress): multi-level siyumim screen (unit/aggregate/curriculum)`

**Agent W3-C — Task #11 (Lifetime Knowledge screen)**
Owns:
- NEW: `lib/features/progress/presentation/screens/lifetime_knowledge_screen.dart`
- `lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart` (extend with toggle)
- Reuse + modify `CurriculumBreakdownList` widget (add per-leaf provenance display)
- Tests
Task per `docs/planning/progress-ia-redesign.md §5`. Toggle: All sources (default — includes lifetimeOnly) vs Track learning only. Header: items + total chazaros. Per-leaf provenance label. CTA at bottom linking to Lifetime Marking.
Commit: `feat(progress): Lifetime Knowledge screen (all-sources lifetime lens)`

Gate. Commit each agent. Move to W3b.

### W3b — Hub restructure + obsolete deletion (2 parallel agents)

**Agent W3b-A — Task #8 (Progress hub restructure)**
Owns:
- `lib/features/progress/presentation/screens/progress_screen.dart`
- NEW: `lib/features/progress/presentation/widgets/progress_tier_counter_row.dart` (shared widget used by Dashboard too)
- Tests
Task per `docs/planning/progress-ia-redesign.md §2`. Replace stat grid with top counter row + 3 lens tiles + per-track list. Routes go to the new screens (built in W3). Drop ACTIVE TRACKS stat. Remove inline lifetime tree (moved into Lifetime Knowledge).
Commit: `feat(progress): restructure Progress hub with three-lens IA`

**Agent W3b-B — Task #12 (Delete obsolete)**
Owns: DELETE
- `lib/features/progress/presentation/screens/tasks_done_screen.dart`
- `lib/features/progress/presentation/screens/completion_history_screen.dart`
- `lib/features/progress/presentation/screens/items_learned_screen.dart`
- `lib/features/progress/presentation/screens/lifetime_view_screen.dart`
- Their tests
- Their auto_route entries (via codegen on delete)
- Their l10n keys not already retired by #13 (e.g. `itemsLearnedTitle`, `itemsLearnedSubtitle`, `lifetimeViewTitle`)
- Any orphaned providers (e.g. `items_learned_providers.dart` if no consumers remain)
- Grep for remaining callsites to deleted routes; remove or repoint.
Commit: `refactor(progress): delete obsolete progress screens (folded into Recent Activity + Lifetime Knowledge)`

Gate. Commit each. Move to W4.

### W4 — Dashboard refinement (Phase D — 1 agent)

**Agent W4-A — Task #14**
Owns:
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_body.dart`
- Other dashboard widgets as needed
Task per `docs/planning/progress-ia-redesign.md §1`. Add top counter row (3 adult / 4 child including ⭐ points). Use the shared `progress_tier_counter_row.dart` from W3b-A. Restyle per-track rows with dual labels. Remove ACTIVE TRACKS card.
Commit: `feat(dashboard): tier-aware counter row + dual track labels`

Gate. Move to W5.

### W5 — Per-screen relabels (Phase E — 4 parallel agents)

**Agent W5-A — Task #15 (Curriculum Progress)**
Owns: `lib/features/progress/presentation/screens/curriculum_progress_screen.dart`, `lib/features/progress/presentation/widgets/overall_stats_card.dart` (split into two cards if needed), `lib/features/progress/presentation/widgets/pace_indicator.dart`.
Commit: `refactor(progress): split Curriculum Progress stats into Track + Lifetime`

**Agent W5-B — Task #16 (Track Detail)**
Owns: `lib/features/tracks/setup/presentation/screens/track_detail_screen.dart`, related bulk-mark button widgets.
Commit: `refactor(tracks): dual progress labels + differentiated bulk-mark button`

**Agent W5-C — Task #17 (Bulk Mark wizard)**
Owns: `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart`, related wizard step widgets.
Commit: `refactor(onboarding): bulk-mark wizard explains tier credit policy`

**Agent W5-D — Task #18 (Lifetime Marking)**
Owns: `lib/features/settings/presentation/screens/lifetime_marking_screen.dart`, settings entry point, surface CTA on Lifetime Knowledge (cross-file edit allowed because the only conflict file is itself owned by W5-D).
Commit: `refactor(settings): Lifetime Marking — relabel + surface via Lifetime Knowledge CTA`

Gate. Move to W6.

### W6 — Code review (orchestrator)

Run `/bmad-code-review` on the full diff from W0 HEAD → current HEAD. Collect ALL findings grouped by severity (critical / high / medium / low). Each finding: `file:line` + proposed fix.

### W7 — Fix EVERY review finding (parallel agents)

Partition findings into disjoint file-sets. One agent per partition. **No defer, no downgrade.** Every finding gets a fix. Each agent adds a regression test where the finding warrants one. Gate between agent commits. Each slice: `fix(review): <desc>`.

If W7's diff produces new review findings, run W6 again on the W7 diff and fix those too. Repeat until clean.

### W8 — Final verification (orchestrator)

- `make ci` + `make audit` — both fully green; `dart analyze` 0 issues.
- Re-run touched test suites: completions, progress, onboarding, dashboard.
- Final report:
  - Every commit grouped by wave.
  - Every original task (#1–#18) marked complete with its commit.
  - Every review finding marked resolved with its fix commit.
  - Any follow-ups that surfaced.
Commit: `docs(planning): progress IA execution — final report`

## Discipline rules — never violate

- ❌ No mirror tests (tests that re-implement logic under test, then assert against the copy)
- ❌ No `--no-verify`, no skipped hooks
- ❌ No defer ("we'll fix in a future PR")
- ❌ No partial implementations
- ❌ No agents in the same wave sharing a file
- ❌ No agent runs `make ci` or commits — only the orchestrator does
- ❌ No worktree, no branch — all on dev
- ✅ Fix everything the agent finds in its owned files (not just the assigned task)
- ✅ Add a regression test for every fix
- ✅ One agent = one commit
