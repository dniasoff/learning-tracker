---
title: Progress IA Redesign — Execution Final Report
date: 2026-05-20
status: Complete — 18 tasks + 25 review findings fixed; all tests green
related:
  - docs/planning/progress-ia-redesign.md (the UX proposal)
  - docs/planning/progress-ia-execution-plan.md (the wave plan)
---

# Progress IA Redesign — Final Report

## Headline

The Progress IA redesign is **complete and verified green**. 14 commits on `dev` deliver the three-lens information architecture (Recent Activity / Siyumim & Milestones / Lifetime Knowledge), the underlying correctness + performance fixes, the Hebrew Terms-aware vocabulary sweep, and the Dashboard refinement.

**Gate state at completion:**
- `make ci` — 5643 tests pass, 0 failures, 125 skipped
- `make audit` — all 17 enforcement greps clean

## Commits by wave

| Hash | Wave | Summary |
|---|---|---|
| `b7010ed2` | W0 | Planning docs (Progress IA redesign + execution plan) |
| `706aae4c` | W0.5-A | Firebase gateway in `core/auth/` — fixes audit rule 1 violation |
| `a9dda798` | W0.5-B | Scheduler program labels route via core/labels — fixes audit rule 7 violations |
| `9a7a24b7` | W0.5-C | Empty catch in sign-in controller replaced with AppLogger — fixes audit rule 9 |
| `2380e6eb` | W1-A | Siyumim gate uses `creditsAchievement` not `creditsEngagement` (Task #1) |
| `4b5760a3` | W1-B | Chart bundle: `trackAchievement` tier + bucketed All-Time + SQL date pushdown + chart future memo (Tasks #2–#6) |
| `5d470d8c` | W1-C | Siyum detection N+1 → single bulk fetch (Task #7) |
| `529696b4` | W2 | B1 three-tier vocabulary (`siyum`/`chazara`/`limud`) + Hebrew Terms toggle wiring (Task #13) |
| `82559c7f` | W3 pt 1 | Three new lens screens built — Recent Activity, Siyumim & Milestones (multi-level), Lifetime Knowledge (Tasks #9, #10, #11) |
| `c7ff34ba` | W3 pt 2 | Progress hub restructured + 6 obsolete screens deleted (Tasks #8, #12) |
| `d905c848` | W4 | Dashboard: tier-aware counter row + dual track labels (Task #14) |
| `58ca4656` | W5 | Per-screen relabels — Curriculum Progress, Track Detail, Bulk Mark wizard, Lifetime Marking (Tasks #15–#18) |
| `281d3022` | W7 | 25 adversarial-review findings fixed across 5 parallel agents |
| `44f9b78b` | W7 closure | F25 lens-provider watch wiring (orchestrator completion of the deferred half) |

## Task completion table

| # | Task | Status | Landed in |
|---|---|---|---|
| 1 | Siyumim gate uses `creditsAchievement` | ✅ Done | `2380e6eb` + Wave 7 (`281d3022` extended to bulk-mark) |
| 2 | Chart tier → `trackAchievement` | ✅ Done | `4b5760a3` |
| 3 | "All Time" 9,636-day loop → bucketed | ✅ Done | `4b5760a3` |
| 4 | FutureBuilder memoization | ✅ Done | `4b5760a3` (then deleted by `c7ff34ba` along with the screen) |
| 5 | `getStreakCalendar` SQL date filter | ✅ Done | `4b5760a3` |
| 6 | Chart queries push `since`/`until` to SQL | ✅ Done | `4b5760a3` |
| 7 | Siyum detection drops N+1 | ✅ Done | `5d470d8c` |
| 8 | Progress hub restructure | ✅ Done | `c7ff34ba` |
| 9 | Recent Activity screen | ✅ Done | `82559c7f` |
| 10 | Siyumim & Milestones (multi-level) | ✅ Done | `82559c7f` |
| 11 | Lifetime Knowledge screen | ✅ Done | `82559c7f` |
| 12 | Obsolete progress screens deleted | ✅ Done | `c7ff34ba` |
| 13 | Vocabulary sweep + Hebrew Terms toggle wiring | ✅ Done | `529696b4` |
| 14 | Dashboard refinement | ✅ Done | `d905c848` |
| 15 | Curriculum Progress dual stats | ✅ Done | `58ca4656` |
| 16 | Track Detail dual progress + differentiated bulk-mark | ✅ Done | `58ca4656` |
| 17 | Bulk Mark wizard tier-credit copy + toast | ✅ Done | `58ca4656` |
| 18 | Lifetime Marking relabel + CTA surface | ✅ Done | `58ca4656` |

## Wave 6 code-review findings — all 25 resolved

| Finding | Severity | Resolution commit |
|---|---|---|
| F1 — Bulk-mark wizard never triggers siyum detection | CRITICAL | `281d3022` (W7-A) |
| F2 — Per-curriculum unit scopes broken | CRITICAL | `281d3022` (W7-A) |
| F3 — Lifetime Knowledge header ignores toggle | HIGH | `281d3022` (W7-B) |
| F4 — Rule 1 violation: core/labels imports features/scheduler | HIGH | `281d3022` (W7-D — gated `ProgramLabelResolver` shim) |
| F6 — Siyumim level-counter strings hardcoded English | HIGH | `281d3022` (W7-C) |
| F7 — Lifetime Knowledge hardcoded English strings | HIGH | `281d3022` (W7-B) |
| F12 — Provenance live/bulk classification edge case | HIGH | `281d3022` (W7-B — contract documented + dead code removed) |
| F5 — Rule 2 violation: Dashboard deep import into progress widgets | MEDIUM | `281d3022` (W7-D — barrel populated) |
| F8 — Siyumim grouped view hardcoded English + non-locale-aware dates | MEDIUM | `281d3022` (W7-C — `DateFormat.yMMMd(locale)`) |
| F9 — Provenance text hardcoded English | MEDIUM | `281d3022` (W7-B — routed via `chazaros` + AppLocalizations) |
| F10 — Curriculum Progress TODO(l10n) comment | MEDIUM | `281d3022` (W7-C) |
| F11 — Recent Activity streak ignores curriculum filter | MEDIUM | `281d3022` (W7-D — Path A: thread `curriculumId` end-to-end) |
| F13 — N+1 queries in `lifetimeDataProvider` | MEDIUM | `281d3022` (W7-B — profile-wide shared providers) |
| F14 — LEFT JOIN may duplicate rows | MEDIUM | `281d3022` (W7-E — `EXISTS`/`NOT EXISTS` rewrite) |
| F22 — Test coverage gap for non-Mishnayos/Bavli curricula | MEDIUM | `281d3022` (W7-A — Chumash + Mishna Berurah tests) |
| F25 — Progress hub refresh doesn't reach lens providers | MEDIUM | `281d3022` (W7-E provider added) + `44f9b78b` (lens watches wired) |
| F15 — `_LevelCountersCard` always renders all 3 rows | LOW | `281d3022` (W7-C — `Opacity(0.38)` on zero rows) |
| F16 — Test uses `DateTime.now()` instead of `DateTimeFactory.nowLocal()` | LOW | `281d3022` (W7-E) |
| F17 — `ProgressTierCounterRow` flashes 0s during load | LOW | `281d3022` (W7-E — `'…'` placeholder until all providers resolved) |
| F18 — `DateTime(2000,1,1)` literal in Recent Activity | LOW | `281d3022` (W7-D — `kChartAllTimeFloor` constant) |
| F19 — Sibling empty catches in `sign_in_controller` | LOW | `281d3022` (W7-E — AppLogger on both) |
| F20 — `_safeLoadLeaves` / `_safeHeLabelLookup` swallow exceptions | LOW | `281d3022` (W7-B — AppLogger.warning) |
| F21 — `journey_view_model_test` copyWith coverage gap | LOW | `281d3022` (W7-E — roundtrip tests) |
| F23 — Dashboard tier-row test stubs `journeyViewModelProvider` | LOW | `281d3022` (W7-E — real-provider integration test added) |
| F24 — `_detectMilestones` doesn't dedupe unit-level entries | LOW | `281d3022` (W7-A — dedupe by `unitIdentifier`, latest by `completedAt`) |

## Behaviour notes (what users see now)

### What changed for the user

- **Progress hub** is now a three-lens IA: top counter row (streak / siyumim / items, + points in child mode) → 3 lens tiles → per-track digest list. The legacy 4-card stat grid is gone.
- **Recent Activity screen** (new) replaces the old Progress Charts + Streak History. Strictly live-only data; the bar chart shows limudim (stage 1) + chazaros (stage 2+) as a two-colour stack. Pill subtitles clarify the live-only scope.
- **Siyumim & Milestones screen** (replaces Learning Journey) exposes three additive celebration levels — Siyum Masechta/Sefer (unit), Siyum Seder/Chelek (aggregate), Siyum HaShas/HaTorah/etc (curriculum). Hierarchy-aware grouping with expand chevrons. No provenance label.
- **Lifetime Knowledge screen** (merges Items Learned + Lifetime View) with All-sources / Track-only toggle. Per-leaf provenance label tells the user *how* each item entered (Live · N chazaros / Bulk-marked / Lifetime · imported). Inline CTA to Lifetime Marking.
- **Dashboard** has the same top counter row as the Progress hub (consistency); per-track rows show dual labels (Track progress: X% / Lifetime: Y%).
- **Bulk-mark wizard** now explicitly tells the user "these count toward siyumim and lifetime knowledge — but not toward your streak or points". Post-save toast confirms the count + the destination ("They'll appear in Lifetime Knowledge and may unlock siyumim.").
- **Hebrew Terms toggle** still works as before, but now swaps **script not concept** for the new vocabulary — `Siyum`/`סיום`, `Chazara`/`חזרה`, `Limud`/`לימוד`.

### What is fixed under the hood

- A user who bulk-marked Seder Zeraim before this work now **gets the 11 masechta siyumim + the seder siyum** on next launch (was: zero siyumim — the redesign's biggest broken claim).
- Non-Mishnayos curricula (Chumash, Nach, Tanach, Mussar, Mishna Berurah, Mishneh Torah) now correctly produce **per-curriculum-appropriate siyumim** (was: zero unit-level siyumim regardless of completions).
- The "All Time" Progress Charts no longer generates 9,636 data points in a Dart loop — bucketed weekly past 60 days; capped at the user's first live completion.
- The `getStreakCalendar` SQL no longer pulls all 1,336 completion rows then date-filters in Dart.

## Known follow-ups (not blocking)

None at completion. The original "F25 deferred" note from the W7-E agent was closed by the `44f9b78b` follow-up commit.

The two pre-existing `make audit` warn-only rules (W1.12 "no features/ in core/" and W1.13 "no cross-feature deep imports") still report warnings against pre-existing violations elsewhere in the codebase. These were not in scope of this redesign and are tracked separately in the audit's warn-only output.

## Process notes — what worked + what to keep

- **One-agent-per-task discipline** (with disjoint file ownership) produced clean parallel commits with very few conflicts. The one observed conflict (W3-B's typedef scaffolding in `app_router.gr.dart` after W3-A's screen rename) was resolved by the orchestrator with a single in-file edit, taking less than a minute.
- **Make ci + make audit between waves** caught real regressions early (the WAVE 3 `EdgeInsets.only(left:)` RTL violation; the W7-D Rule 5 catch in the new label resolver). Both were tiny edits at gate time, not full re-runs.
- **No mirror tests** — the discipline held across all 7 fix agents in Wave 7. Every regression test exercises real production code through `ProviderContainer` + in-memory Drift.
- **Agent reports were honest about scope trade-offs** — e.g. W7-E's "F25 lens-side ref.watch lands in a follow-up" — and the orchestrator caught those rather than letting them slip.

## Hand-off

`docs/planning/progress-ia-redesign.md` is the canonical UX proposal and remains the source of truth for the design intent. This report serves as the closing artifact for the orchestration; the per-commit messages have the detail.

Closed at gate-green on 2026-05-20.
