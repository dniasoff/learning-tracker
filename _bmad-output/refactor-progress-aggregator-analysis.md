# Progress Aggregator Divergence — Analyst Report

**Date:** 2026-05-20
**Analyst:** bmad-analyst sub-agent (Mary — Strategic Business Analyst)
**Mode:** Read-only investigation
**Trigger:** Daniel's V6 manual smoke surfaced 3 inconsistencies on Mishnayos track

---

## Executive Summary

Three progress-display inconsistencies share a common structural root: the codebase grew **four independent aggregation paths** for "how much has the user learned?" without a governing single-source-of-truth provider. Inconsistency 1 is a **semantic mismatch between two aggregators** — `dashboardTrackCompletionPercentageProvider` (stage-multi-complete: "all required stages done per item") vs `trackDualProgressMetricsProvider` (time-gated cycle: "distinct refs since `activatedAt`"). These two providers intentionally compute different things but are displayed under labels so similar that a user cannot distinguish them. Inconsistency 2 is a **missing CompletionSource filter** — `ChartDataService.getDailyCompletions()` reads all completion rows regardless of source tier, but Daniel's Mishnayos completions are overwhelmingly `bulkInTrack` (sentinel timestamp), and the `allTime` chart window hard-codes `DateTime(2024, 1, 1)` which pre-dates the app's data — the bar chart renders all bars at zero height (no zero bars, technically, but visually empty with `M…N` axis labels). Inconsistency 3 is definitively a **hardcoded mock string** in the ARB localisation file: `"+12% vs last week"` is a literal constant, never computed.

**Primary verdict: Code slop — careless implementation.** Multiple independent aggregators were built without shared semantics, and at least one UI string was left as a placeholder copy that made it through the refactor verification passes.

**Recommended fix sequence:** (1) Fix the hardcoded l10n string immediately — highest user-trust damage. (2) Add `completionSource` join guard to `ChartDataService` to distinguish live/bulk/lifetime completions for bar charts. (3) Rename the dashboard track-card label to accurately reflect what `currentCyclePercentage` means. (4) Long-term: unify aggregators behind `TrackProgressService`.

---

## (a) Root Cause Analysis

### Inconsistency 1 — Manage Tracks 31.87% vs Dashboard "This cycle 0.00%"

**Aggregator A — Manage Tracks card: `dashboardTrackCompletionPercentageProvider`**

- File: `lib/features/dashboard/presentation/providers/dashboard_providers.dart` lines 119–154
- Calls: `TrackCompletionService.computeTrackPercentage()` — `lib/features/dashboard/domain/services/track_completion_service.dart` lines 28–50
- Data source: `db.completionDao.getCompletionsByTrackAndProfile(trackId, profileId)` — ALL completions for this track, no time filter
- Query: `completionsView WHERE trackId = ? AND profileId = ?` — reads all rows including `bulkInTrack` sentinel rows
- Stage logic: counts items where every required `stageOrder` has a completion row; denominator = `scopedItemCountProvider` (scoped content leaf count)
- Displayed label: `l10n.carouselCompletion(chazaraTerm)` = **"Completion (with חזרה)"** (`lib/l10n/app_en.arb` line 421)
- Result for Mishnayos with many bulk-prior marks + live completions = ~31.87%

**Aggregator B — Dashboard track card: `trackDualProgressMetricsProvider` → `currentCyclePercentage`**

- File: `lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart` lines 130–227
- Calls: `db.completionDao.getCompletionsByTrackAndProfileSince(track.id, profileId, track.activatedAt)` — lines 160–165
- Data source: `completionsView WHERE trackId = ? AND profileId = ? AND eventTimestamp >= ?` — **time-gated since `track.activatedAt`**
- Stage logic: counts DISTINCT `sefariaRef` values only; denominator = leaf count for track scope
- Displayed label: `'${l10n.trackCurrentCycle} • $currentCycleDisplay'` = **"This cycle • 0.00%"** (`lib/features/dashboard/presentation/widgets/active_track_card.dart` line 218)
- Result for a Mishnayos track: if no live completions have occurred SINCE the track was activated on this device (`activatedAt` timestamp), the set of completions since that time is empty → 0.00%

**Divergence cause:**

The two aggregators answer fundamentally different questions:
- Aggregator A: "Of all items in this track, what fraction has been completed at every required stage?" (all-time, multi-stage gate)
- Aggregator B: "Of all items in this track, what fraction has any completion record since `activatedAt`?" (time-gated, single-ref presence check)

The divergence is worst when: (a) the user has many `bulkInTrack` completions that pre-date `activatedAt` (these appear in A but not B), or (b) the track was re-activated after existing completions (any completion before the current `activatedAt` is invisible to B).

There is a further semantic clash: Aggregator A requires "ALL required stages done per item" (it is a multi-stage-gate calculation), while Aggregator B just checks if a `sefariaRef` appears at all since activation — it does not enforce that all stages are complete.

**Evidence:**
- `dashboardTrackCompletionPercentageProvider` L140: `getCompletionsByTrackAndProfile` (no time filter)
- `trackDualProgressMetricsProvider` L160-165: `getCompletionsByTrackAndProfileSince(track.id, profileId, track.activatedAt)` — `Since` is the key
- `TrackCompletionService.computeTrackPercentage` L36: `requiredStageIds = stages.map((s) => s.stageOrder).toSet()` — requires all stages
- `trackDualProgressMetricsProvider` L166-168: `currentCycleRefs = sessionCompletions.map((c) => c.sefariaRef).toSet()` — just a set of refs, no stage gate

**Bonus defect — invalidation gap:** `trackDualProgressMetricsProvider` does **not** watch `completionCommittedProvider` (confirmed: no `ref.watch<int>(completionCommittedProvider)` in `lifetime_knowledge_providers.dart` lines 130-227). The dashboard card is therefore **not reactively refreshed** after a live completion. `dashboardTrackCompletionPercentageProvider` (L120) does watch it. This means the two displayed values can temporarily diverge even further immediately after marking a completion.

---

### Inconsistency 2 — Empty "Completions Over Time" chart despite 31.87% completion

**Aggregator — `ChartDataService.getDailyCompletions()`**

- File: `lib/features/progress/domain/services/chart_data_service.dart` lines 27–51
- Data source: `_loadCompletions(curriculumId)` → `db.completionDao.getCompletionsByCurriculumAndProfile(curriculumId, profileId)` — ALL rows, NO `CompletionSource` filter
- Filter applied: date window only — rows with `completedAt` in `[startDate, endDate]`
- `allTime` window: `DateTime(2024, 1, 1)` to `today` — hard-coded in `progress_charts_screen.dart` line 45

**Why the chart is visually empty:**

The completions that produce the 31.87% figure are `bulkInTrack` completions. These rows were written with `eventTimestamp = DateTime.utc(2000, 1, 1)` — the bulk-prior sentinel timestamp, as confirmed by `items_learned_providers.dart` line 14: `final kBulkPriorSentinelMs = DateTime.utc(2000, 1, 1).millisecondsSinceEpoch`.

The `allTime` window starts at `DateTime(2024, 1, 1)`. Since `2000-01-01 < 2024-01-01`, ALL bulk-prior completion rows fall outside the `allTime` window — they are filtered out by the date range check at chart_data_service.dart line 37: `if (!localDate.isBefore(startDate) && !localDate.isAfter(endDate))`.

Result: zero completions match the date filter → `DailyCompletionData` list has `count = 0` for every day in the range → `maxCount = 0` → all bars render at zero height → the chart **appears visually empty** (just M…N axis labels with no visible bars, though technically data is present with all-zero counts).

**Secondary factor — `last7Days` and `last30Days` also empty:**

For a user who has only done bulk-prior marking (no live in-session completions since installing the app), the `last7Days` and `last30Days` views are also empty for the same reason — all completions have `eventTimestamp = 2000-01-01`.

**The design intent was apparently to show daily activity for live/recent completions only**, but the service does not enforce this by filtering out sentinel-timestamped rows. No `CompletionSource` column exists in `completion_events` (confirmed: `lib/core/database/tables/completion_events.dart`); the only source-tier indicator is the `prior_completion_imports` join table.

**Evidence:**
- `chart_data_service.dart` L16-24: `_loadCompletions` — no `prior_completion_imports` join
- `chart_data_service.dart` L37: date-range filter that excludes 2000-epoch timestamps
- `progress_charts_screen.dart` L45: `allTime => (start: DateTime(2024, 1, 1), end: today)` — hard-coded
- `items_learned_providers.dart` L14: `kBulkPriorSentinelMs = DateTime.utc(2000, 1, 1).millisecondsSinceEpoch`

---

### Inconsistency 3 — "+12% vs last week" vs "This cycle 0.00%"

**The "+12% vs last week" is a hardcoded string literal.**

- File: `lib/l10n/app_en.arb` line 674: `"chartCumulativeProgressSubtitle": "+12% vs last week"`
- File: `lib/l10n/app_he.arb` line 669: `"chartCumulativeProgressSubtitle": "+12% לעומת השבוע שעבר"`
- File: `lib/l10n/app_localizations.dart` line 2657: docstring confirms the hardcoded default: `/// **'+12% vs last week'**`
- Consumed by: `progress_charts_screen.dart` L110: `subtitle: l10n.chartCumulativeProgressSubtitle`

This string is **never dynamically computed**. It is a static placeholder that was authored as display copy and was carried through the v3.3 refactor unchanged. There is no code anywhere in the codebase that computes a weekly comparison percentage and injects it into this label.

**The single dot at the right edge of the Cumulative chart:**

- File: `lib/features/progress/presentation/widgets/cumulative_line_chart.dart` lines 32–62
- `CumulativeLineChart` renders `FlDotData` with `checkToShowDot: (spot, barData) => spot.x == data.length - 1` — only the **last point** shows a dot (line 45)
- `getCumulativeProgress` builds a running total starting from `cumulativeBeforeStart` (completions before `startDate`). For `allTime` with start 2024-01-01, `cumulativeBeforeStart` = number of completions with `completedAt < 2024-01-01`
- Bulk-prior completions have `eventTimestamp = 2000-01-01 < 2024-01-01`, so `cumulativeBeforeStart` = ~31.87% worth of completions
- For every day in `[2024-01-01, today]` with no live completions, `dailyCounts[date] = 0` → `runningTotal` never increases
- Result: a flat line at the bulk-prior count level, with only the last-point dot rendered → visually appears as **one dot at the right edge**

The "+12%" subtitle label is architecturally disconnected from the chart data; the chart correctly renders (flat line ≈ all completions are old bulk-prior), but the subtitle falsely claims growth.

---

## (b) Code Quality Verdict

**Primary cause: Code slop — multiple aggregators with different semantics, incompatible label terminology, and at least one hardcoded placeholder that shipped.**

Supporting evidence ranked by severity:

| Finding | Category | Severity |
|---|---|---|
| `chartCumulativeProgressSubtitle = "+12% vs last week"` hardcoded | Code slop (placeholder shipped) | Critical |
| `currentCyclePercentage` uses `Since(activatedAt)` but is labelled "This cycle" — which implies a pedagogical cycle reset, not device activation | UX labelling issue + semantic mismatch | High |
| `dashboardTrackCompletionPercentage` (all-time, multi-stage) vs `trackDualProgressMetricsProvider` (time-gated, single-ref) coexist without documentation of why | Code slop (duplicated aggregators, no single source of truth) | High |
| `ChartDataService.getDailyCompletions` does not exclude bulk-prior sentinel rows | Code slop (missing filter — incomplete implementation) | High |
| `trackDualProgressMetricsProvider` not watching `completionCommittedProvider` | Refactor regression (W4 dashboard extraction presumably omitted this wiring) | Medium |
| `allTime` chart window hard-coded to `DateTime(2024, 1, 1)` | Code slop (magic constant) | Medium |
| Duplicate tree-building logic in `LifetimeTreeBuilder` and `_learnedLeafRefs()` in `items_learned_providers.dart` | Code slop (copy-without-extract) | Low |

**Secondary cause: Refactor regression (W4.16/W4.17 dashboard extraction)**

The dashboard extraction (W4.17) created `TrackCompletionService` and `dashboardTrackCompletionPercentageProvider`, while W4.16 `LifetimeTreeBuilder` created the dual-metric `trackDualProgressMetricsProvider`. These were built in separate streams (S4, S5) with different semantics and no cross-stream alignment verification. The B1 three-tier policy was also implemented at the event-write side (correct) but no aggregator was updated to read through the `prior_completion_imports` join table for display-side filtering.

**Not a data model issue:** The underlying schema correctly separates `completion_events` from `prior_completion_imports`. The three-tier policy is correctly enforced on the write path. The problem is that the read path (aggregators) ignores this separation.

---

## (c) Cross-Codebase Audit

| Screen / Widget | File:line | Provider/Aggregator | Data source | Tier filter | Divergence risk | Notes |
|---|---|---|---|---|---|---|
| Manage Tracks — "Completion (with חזרה)" | `learning_track_card.dart:44-48` | `dashboardTrackCompletionPercentageProvider` | `completionsView` all-time | None — includes bulk/lifetime | **HIGH** | Shows 31.87% for Mishnayos |
| Track Detail — same % | `track_detail_screen.dart:56-60` | `dashboardTrackCompletionPercentageProvider` | `completionsView` all-time | None | **HIGH** | Same issue |
| Dashboard card — "This cycle •" | `active_track_card.dart:85-88` | `trackDualProgressMetricsProvider.currentCyclePercentage` | `completionsView WHERE eventTimestamp >= activatedAt` | Time-gated since activatedAt | **HIGH** — shows 0.00% when bulk > live | Not watching `completionCommittedProvider` |
| Progress Charts — Completions Over Time (bar chart) | `progress_charts_screen.dart:249-270` | `ChartDataService.getDailyCompletions()` | `completionsView` all with date filter | Date window only — bulk-prior sentinel excluded implicitly by date math | **HIGH** — empty for bulk-prior users | `allTime` window starts 2024-01-01; sentinel is 2000-01-01 |
| Progress Charts — Cumulative Progress (line chart) | `progress_charts_screen.dart:274-296` | `ChartDataService.getCumulativeProgress()` | `completionsView` all with date filter | None — bulk-prior counted if before `startDate` → `cumulativeBeforeStart` | **MEDIUM** — shows flat line, single dot | Chart is technically correct but subtitle "+12%" is fake |
| Progress Charts — "+12% vs last week" subtitle | `progress_charts_screen.dart:110` | Hardcoded `l10n.chartCumulativeProgressSubtitle` | None (string literal) | N/A | **CRITICAL** | `app_en.arb:674`, `app_he.arb:669` |
| Progress Screen — curriculum summaries | `progress_screen.dart:35` | `lifetimeSummariesProvider` | `completionsView` + `learningLedger` via `LifetimeTreeBuilder` | All three tiers (B1 lifetime tier correct) | LOW — correct by design | Lifetime tier includes bulk/lifetime intentionally |
| Lifetime Marking Screen | `lifetime_marking_screen.dart:33` | `lifetimeSummariesProvider` | Same as above | Lifetime tier | LOW | Same as above |
| Items Learned screen | `items_learned_providers.dart:45-92` | `computeItemsLearnedSummary` | `completionsView` + sentinel-date filter | Excludes sentinel `2000-01-01` via `c.completedAt.millisecondsSinceEpoch != kBulkPriorSentinelMs` | **MEDIUM** | Filter works by magic constant, not by `prior_completion_imports` join — fragile |
| Curriculum Progress Screen | `curriculum_progress_screen.dart:37` | `curriculumProgressProvider` / `CurriculumProgressService` | `completionsView` all | None | **MEDIUM** | `computeCompletionPercentage` counts refs with ≥1 completion — includes bulk-prior, no stage gate |
| Dashboard — per-curriculum % | `dashboard_providers.dart:167-215` | `dashboardCompletionPercentageProvider` | `completionsView` all, grouped by track | None | **HIGH** — inflated by bulk-prior when trackId=0 entries exist | Explicitly skips `trackId == 0` bulk-mark sentinel, but other bulk rows with real trackId are included |
| Streak calendar (charts) | `chart_data_service.dart:163-180` | `ChartDataService.getStreakCalendar()` | `completionsView` all by profile | None | **LOW** — sentinel rows at 2000-01-01 filtered out by date window naturally | |
| Streak (dashboard / history) | `dashboard_providers.dart:252-265` | `dashboardStreakProvider` / `StreakStateProvider` | `streak_events` table | Engagement-tier only (streak events only written for live completions per B1) | LOW — correct by design | B1 write-path correctly gates |
| Points total | `dashboard_providers.dart:273-281` | `dashboardGlobalPointsProvider` / `PointsService` | `completion_events.points` | None — reads `points` column | **MEDIUM** — but bulk-prior rows have `points=0` by B1 write-path, so runtime risk is low | Correct if write-path enforces points=0 for non-live |
| "+X% vs last week" trend subtitle | `app_en.arb:674` | None | None | N/A | **CRITICAL** | Hardcoded placeholder |
| `ParentDashboardAggregator.computeCompletionPercentage` | `parent_dashboard_aggregator.dart:168-196` | Direct DAO call | `completionsView` + `stageRepository` | None | **HIGH** — fourth independent aggregator; uses `stageSet.length >= totalStages` not `every stageId in required` | Different formula from `TrackCompletionService` |
| `CurriculumProgressService.computeCompletionPercentage` | `curriculum_progress_service.dart:76` | Static method | Passed `completions` list | None | **MEDIUM** — relies on caller to filter | No stage gate — counts if `stages.length >= totalStageCount` |

---

## (d) Refactoring Plan

### Design proposal

The root problem is four independent aggregation paths that answer slightly different questions and have grown incoherent. The fix requires three layers:

**Layer 1 — Immediate fixes (< 1 day each, independent)**

1. **Fix the hardcoded subtitle.** Delete the `"+12% vs last week"` constant from both ARB files. Either (a) implement the actual week-over-week calculation, or (b) replace with a neutral label like `l10n.chartCumulativeProgressSubtitle = 'Total completions over time'`. Option (b) is the safe minimum.

2. **Fix `ChartDataService` sentinel exclusion.** Add a sentinel-date guard consistent with `items_learned_providers.dart`:
   - In `getDailyCompletions()` and `getCumulativeProgress()`, filter out completions where `completedAt.millisecondsSinceEpoch == kBulkPriorSentinelMs` before the date-range loop.
   - This correctly shows only live-marked completions on the activity charts.
   - No schema change needed.

3. **Add `completionCommittedProvider` watch to `trackDualProgressMetricsProvider`.** Add `ref.watch<int>(completionCommittedProvider)` at the top of the provider body in `lifetime_knowledge_providers.dart` so the dashboard card refreshes immediately after a live completion.

4. **Fix the `allTime` magic constant.** Replace `DateTime(2024, 1, 1)` in `progress_charts_screen.dart:45` with a query for the earliest actual completion timestamp, or at minimum with `DateTime(2000, 1, 1)` to match the sentinel epoch. Using `DateTime(2000, 1, 1)` would make `cumulativeBeforeStart = 0` for all users (since all bulk-prior completions are at exactly that date) and plot the cumulative curve from zero at the left — more informative than the current offset-line that starts mid-chart.

**Layer 2 — Label accuracy fix (< half day)**

5. **Rename "This cycle" label.** The `currentCyclePercentage` in `trackDualProgressMetricsProvider` is computed since `activatedAt`, which is a device-activation timestamp. It does NOT represent a pedagogical cycle. Rename to "Since last reset" or "This session" with a tooltip, or — better — compute cycle semantics properly if a cycle-reset date is meaningful.

6. **Document the two-percentage design intent.** If both the all-time multi-stage percentage AND the since-activation single-ref percentage are genuinely needed, document this in both providers with cross-references and add a comment explaining why they differ. Otherwise, collapse to one.

**Layer 3 — Architectural unification (medium effort, 1-2 sprints)**

7. **Create a single `TrackProgressService` with explicit tier getters:**

```dart
class TrackProgressService {
  /// % of items where all required stages are done, across all completions
  /// (live + bulk-prior + lifetime). Used for "how complete is this track overall?"
  Future<double> allTimeCompletionPercent({required int trackId, required int profileId});

  /// % of items with any live completion since [cycleStart]. Used for "how
  /// much have I done in this learning cycle?"
  Future<double> cyclePercent({required int trackId, required int profileId, required DateTime cycleStart});

  /// % of items the user has ever encountered (lifetime tier, per LifetimeTreeBuilder).
  /// Includes bulk-prior + lifetime imports.
  Future<double> lifetimePercent({required int trackId, required int profileId});
}
```

8. **Migrate all four independent aggregators** (`dashboardTrackCompletionPercentageProvider`, `trackDualProgressMetricsProvider`, `CurriculumProgressService`, `ParentDashboardAggregator.computeCompletionPercentage`) to use `TrackProgressService`.

9. **Add `prior_completion_imports` join to `CompletionDao`** as a utility method `getCompletionsByTier(tier: CompletionSourceTier)` that performs the LEFT JOIN / NOT IN check against `prior_completion_imports`. This avoids the magic-constant sentinel anti-pattern in `items_learned_providers.dart`.

### Migration steps

Since this is pre-launch with no live users (confirmed memory note):

1. Implement fixes 1–4 as a single commit (can be done by one pass, all independent files)
2. Implement fix 5–6 in a second commit (label + doc changes only)
3. Implement `TrackProgressService` stub with tests, then migrate providers one at a time with regression tests verifying each provider returns the same value before and after migration
4. Add `getCompletionsByTier` DAO method, migrate `items_learned_providers.dart` sentinel-constant filtering, add regression test asserting sentinel rows are excluded from "track completions" count

### Test strategy

The class of divergence caught here is **"provider reads different rows than another provider for conceptually the same metric."** The regression net for this class:

1. **Property test:** For a profile with only bulk-prior completions (no live marks), `getDailyCompletions()` must return all-zero daily counts. Assert `data.every((d) => d.count == 0)`.
2. **Consistency test:** For any given track, `dashboardTrackCompletionPercentage` called before and after migrating to `TrackProgressService.allTimeCompletionPercent` must return equal values.
3. **Labelling contract test:** Assert `chartCumulativeProgressSubtitle` in both ARB files does NOT contain a hardcoded percentage literal (regex check: `\+\d+%`).
4. **Reactive invalidation test:** After `completionCommittedProvider.increment()`, `trackDualProgressMetricsProvider` emits a new value within the same test pump cycle.

### Effort estimate

| Task | Complexity | Effort |
|---|---|---|
| Fix 1: Remove hardcoded subtitle | Trivial | 30 min |
| Fix 2: Add sentinel filter to `ChartDataService` | Simple | 1 hour |
| Fix 3: Add `completionCommittedProvider` watch | Trivial | 15 min |
| Fix 4: Fix `allTime` magic constant | Simple | 30 min |
| Fix 5–6: Label + doc | Simple | 1 hour |
| Layer 3: `TrackProgressService` + DAO method | Medium | 2–3 days |
| Layer 3: Migrate all four aggregators | Medium | 1 day |

Fixes 1–6 (Layer 1 + 2) can be completed in a single focused 4-hour session. Layer 3 is a follow-up sprint.

---

## Recommendations to Daniel (prioritised)

1. **Immediate:** Remove the `"+12% vs last week"` hardcoded string from `app_en.arb:674` and `app_he.arb:669`. Replace with `"Total completions over time"` (or equivalent). This is the highest-trust-damage item — users can see a specific percentage claim that is provably false for their actual data.

2. **Same session:** Add the sentinel-timestamp exclusion to `ChartDataService.getDailyCompletions()` and `getCumulativeProgress()` so the Completions Over Time bar chart shows live activity only and is no longer empty for users who have done bulk prior-marking.

3. **Same session:** Fix the `allTime` window start from `DateTime(2024, 1, 1)` to `DateTime(2000, 1, 1)` so the cumulative chart correctly plots from the epoch of the earliest possible data.

4. **Same session:** Add `ref.watch<int>(completionCommittedProvider)` to `trackDualProgressMetricsProvider` so the dashboard card reflects new completions immediately.

5. **Next sprint:** Rename or document the `currentCyclePercentage` label — "This cycle" is semantically misleading for a `Since(activatedAt)` calculation. Consider whether a true cycle-reset concept is needed or whether this field should simply be removed from the card display.

6. **Follow-up sprint:** Build `TrackProgressService` as the single source of truth and migrate `ParentDashboardAggregator.computeCompletionPercentage` (which uses yet another formula — `stageSet.length >= totalStages` rather than `every(required)`) to be consistent.

7. **Schema hygiene:** Add a `getCompletionsByTier()` DAO method that joins against `prior_completion_imports` instead of relying on the magic `DateTime.utc(2000, 1, 1)` sentinel. The sentinel approach in `items_learned_providers.dart:66-69` is a time bomb — any bulk-prior row written with a different timestamp will leak through undetected.

---

## Layer 3 outcome

**Date:** 2026-05-20
**Agent:** Layer 3 migration agent

### What was built

Recommendation #7 (schema hygiene) and the full aggregator unification sprint.

**Infrastructure (Part 1):**

| Component | File | Description |
|---|---|---|
| `CompletionTierFilter` enum | `lib/features/learning/domain/entities/completion_tier_filter.dart` | Three tiers: `liveOnly`, `trackAchievement`, `lifetime` |
| `CompletionDao.getCompletionsByTier()` | `lib/core/database/daos/completion_dao.dart` | Raw SQL with LEFT JOIN on `prior_completion_imports`; replaces sentinel timestamp filter |
| `TrackProgressService` | `lib/features/tracks/domain/services/track_progress_service.dart` | Single source of truth: `completionPercent`, `dailyCounts`, `cumulativeProgress`; Riverpod provider included |

**Migrations (Part 2):**

| Aggregator | Tier used | What changed |
|---|---|---|
| `dashboardTrackCompletionPercentageProvider` | `trackAchievement` | Delegates to `TrackProgressService.completionPercent` |
| `trackDualProgressMetricsProvider.currentCyclePercentage` | `trackAchievement, since: activatedAt` | Delegates to `TrackProgressService.completionPercent` |
| `CurriculumProgressService.computeCompletionPercentage` | caller-supplied | Doc note added; callers must pass tier-filtered completions |
| `ParentDashboardAggregator.computeCompletionPercentage` | `trackAchievement` | Fixed wrong `stageSet.length >= totalStages` formula → canonical `every(required in done)` |
| `ChartDataService.getDailyCompletions` | `liveOnly` | Replaces `_loadCompletions` + sentinel filter |
| `ChartDataService.getCumulativeProgress` | `liveOnly` | Replaces `_loadCompletions` + sentinel filter |
| `ChartDataService.getDailyPoints` | `liveOnly` | Replaces `_loadCompletions` |
| `computeItemsLearnedSummary` (items_learned_providers) | `trackAchievement` | Removes `kBulkPriorSentinelMs` re-export and inline filter |

**Sentinel retirement (Part 3):**

`kBulkPriorSentinelMs` filter removed from `computeItemsLearnedSummary`. All bulk-row test fixtures updated to seed via `prior_completion_imports` rather than relying on magic timestamp. `chart_data_service_sentinel_test.dart` updated to reflect the new contract (timestamp alone does not drive exclusion).

### Tests added

| File | Tests |
|---|---|
| `test/features/tracks/domain/services/track_progress_service_test.dart` | 18 |
| `test/features/dashboard/domain/services/dashboard_track_completion_migration_test.dart` | 3 |
| `test/features/progress/domain/services/track_dual_progress_migration_test.dart` | 3 |
| `test/features/parent_mode/domain/services/parent_dashboard_aggregator_migration_test.dart` | 4 |
| `test/features/progress/domain/services/chart_data_service_migration_test.dart` | 7 |

### Commits

| Commit | Description |
|---|---|
| (Part 1) | `feat(progress): add CompletionTierFilter + getCompletionsByTier DAO + TrackProgressService (Layer 3)` |
| (Migration 1) | `refactor(dashboard): migrate dashboardTrackCompletionPercentageProvider to TrackProgressService (Layer 3)` |
| (Migration 2) | `refactor(progress): migrate trackDualProgressMetricsProvider.currentCyclePercentage to TrackProgressService (Layer 3)` |
| (Migrations 3+4) | `refactor(progress): migrate CurriculumProgressService doc + ParentDashboardAggregator to trackAchievement tier (Layer 3)` |
| (Migration 5) | `refactor(charts): migrate ChartDataService to CompletionTierFilter.liveOnly (Layer 3)` |
| (Part 3) | `refactor(items-learned): retire kBulkPriorSentinelMs sentinel in computeItemsLearnedSummary (Layer 3)` |

### Status

All items from Recommendation #7 (and #6) are resolved. The `kBulkPriorSentinelMs` sentinel is no longer used as a display-tier filter anywhere in the progress aggregation path. The scheduler engine retains its own copy (it uses it for scheduling logic, not display).
