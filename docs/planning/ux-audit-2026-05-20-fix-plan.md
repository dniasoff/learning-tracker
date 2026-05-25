# UX Audit 2026-05-20 — Fix Plan

**Source:** Live audit session with Daniel (party mode: Sally — UX, Mary — BA).
**Scope:** Hebrew Terms leakage, dashboard / progress tile defects, Recent Activity perf+IA failure (3rd attempt — architectural rewrite), completion-credit sentinel date, app-wide offline guarantee.
**Status:** Draft for owner review.

---

## Hard constraints (apply to every stream)

1. **Offline-first everywhere.** All reads from Drift, all writes Drift-first then queued. No network-gated UI. Sync state is informational, never blocking. (See `feedback_offline_first` memory.)
2. **Hebrew Terms spec is authoritative.** `docs/hebrew-terms.md` §1–§10 is the target; §11 lists drift to fix.
3. **Pre-launch — no live users.** Schema resets, big-bang rewrites, and breaking changes are all on the table. No migration windows needed.
4. **Code is the source of truth.** Existing planning docs (incl. `tech-debt-remediation-plan.md` W4.16/W4.18/W7.11) are reference, not gospel — verify against current code before executing each task.

---

## Captured issues (verbatim from the audit)

### Dashboard top section (child profile)
- D-1. **Confirmed 2026-05-20.** The top section (greeting + 4 tiles + Current Balance card + Stats card) is the **child UI**. It shows for `currentProfile.type == child` only. Adults see a different, adult-style top section (no points — points are child-only). Tutors viewing a tutored child see the child UI because `currentProfile` is then the child — no separate tutor view exists. Profile model: child + adult only, no "parent." (See `project_profile_model` memory.)
- D-2. Streak and Points labels are **English words**, not domain terms. They must **never** be affected by the Hebrew Terms setting. (Currently `רצף של 0 ימים` and `נקודות 0` on the dashboard.)
- D-3. 3rd tile (`1336 / 1336 פריטים ב…`) is truncated and unreadable.
- D-4. The 4 tiles in the row should be the same size; currently inconsistent (3rd is wider/taller).

### Progress screen
- P-1. The same 4-tile row repeats with the same defects (D-2, D-3, D-4).
- P-2. Only one menu card title is a domain term — **Mishnayos** (the curriculum). The others — `פעילות אחרונה`, `סיומים והישגים`, `ידע כולל` — are **structural strings** and must follow UI locale, not Hebrew Terms.
- P-3. *Open question:* `סיומים` (siyumim) — is it a domain term governed by Hebrew Terms, or treated as a standard English word ("Siyumim" / "Completions")? Needs decision.

### Recent Activity screen
- R-1. **"All Time" filter is unusable.** Endless calendar grid, no month/year separators, no orientation.
- R-2. **Device freezes on "All Time".** Sluggish UI. **Two prior fix attempts have failed — the architecture is wrong, not the implementation.**
- R-3. Page title `פעילות אחרונה` should be English in English locale.
- R-4. Streak section header `רצף` and pill `רצף של 0 ימים` (again — same as D-2).
- R-5. Weekday header `S S M T W T F` — two adjacent S's ambiguous in English.

### Curriculum track screen (Mishnayos example)
- T-1. **Pace says "Ahead by 296 days" on day 1 of the track.** Bulk-marked prior learning (1,336 items) is leaking into the velocity calculation. The page already declares the right rule in its own caption: `Pace tracks live learning only`. The implementation isn't honoring it.
   - Correct behavior: **velocity required** = `(total_items - bulk_baseline) ÷ days_from_track_start_to_target_date`. **Actual velocity** = `live_completions_since_track_start ÷ days_elapsed_since_track_start`. Ahead/behind compares those two from day 1 forward. Bulk-marked prior learning establishes the starting baseline, not retroactive pace credit.
   - Mechanism for the fix already exists: bulk-in-track entries are sentinel-dated `1/1/2000` (per `project_completion_credit_policy`). Any pace read that filters `completedAt > trackStartDate` excludes them naturally. The bug is that this filter is missing somewhere in the pace pipeline.
- T-2. **§11.1 drift visible here.** "Seder Zeraim" / "Seder Moed" / "Mishnah Berakhot" / "Mishnah Peah" / etc. render in transliteration even when Hebrew Terms = Hebrew. Per §6 these are domain terms (seder + masechta proper names) and should show `סדר זרעים` / `סדר מועד` / `משנה ברכות`. Tracked in Stream A4.
- T-3. **Existing audit violations active on this screen** — `התקדמות מסלול: 32%` (#3) and `ידע כולל: 32%` (#4). Tracked in Stream A2.
- T-4. **`אישי` ("Personal") label appearing per-masechta.** This is a **track-type leakage** — the app has no track types (Product Rules §7). The `אישי: 57` row inside each masechta expansion is a regression to a removed concept. Tracked in new Stream H.
- T-5. **Chazara reference on tracks that may not have chazara enabled.** Every masechta card shows `· N חזרות` and a per-masechta `חזרות` count, unconditionally. Per Product Rules §8 (chazara conditional rendering), chazara UI must be gated on `track.chazaraEnabled`. If this Mishnayos track has chazara enabled the count is fine; otherwise it must disappear. Tracked in new Stream I.
- T-6. **"100.00%" visual styling looks off** (owner feedback — visual nit). The percentage label inside the green circular progress ring feels mismatched. Lower-priority polish item; tracked in Stream J.
- T-7. **Missing track info on this screen** (owner feature request): no visible target/goal date, no track start date, no required velocity, no days elapsed / days remaining. Tracked in new Stream G.

### Cross-cutting
- X-1. **Hebrew Terms boundary is systemically broken.** Every screen leaks Hebrew script into structural strings. Per `docs/hebrew-terms.md` §10, reads must be confined to `lib/core/labels/`, `lib/core/preferences/`, and settings screens — and feature widgets should only ever see resolved strings. The boundary itself is the bug.
- X-2. **Completion credit sentinel date.** Bulk-in-track entries must be stamped with a placeholder date (e.g. `1/1/2000`) so they count toward siyumim / lifetime / "other counters" but never appear in streak math, "today's activity," or "last N days" reads. (See `project_completion_credit_policy` memory — updated 2026-05-20.)
- X-3. **Offline must work on every screen** — non-negotiable.

---

## Architectural ground truth (from exploration)

| Area | Current state | Verdict |
|---|---|---|
| Recent Activity calendar | `StreakCalendar` widget is a handwritten `Column` of `Row`s. **Not virtualized.** Renders one widget per day. `chartTimeRange.allTime` floors to `2000-01-01`, capped by `_effectiveStartDate()` to first completion. Drift-backed via `ChartDataService.getStreakCalendarLive`. | Non-virtualized → widget explosion on multi-year ranges → device freeze. **Architecture is wrong for unbounded ranges.** |
| Dashboard tile row | `ProgressTierCounterRow` — `Row` of 4 `_Counter`s with `Expanded`. Labels via `domainTermLabels(ref)`. Points gated externally via `showPoints: userMode == UserMode.child`. | Layout is OK; **but labels for streak & points are going through `DomainTermLabels` when they shouldn't.** Sizing of the 3rd tile breaks because the label wraps to 2 lines. |
| Hebrew Terms layering | `useHebrewTermsProvider` is read by `domainTermLabels(ref)` (facade) + `curriculum_label.dart` (lower-level renderer). `make audit` grep enforces confinement to `lib/core/labels/`. | Facade exists; **drift is in *what counts as a domain term*, not in the layering.** Streak/points are wrongly inside `DomainTermLabels`. |
| Offline data flow | Drift-first. `CompletionDao.getCompletionsByTier()` from `CompletionsView`. Firestore is sync target only. `initialSyncCompleteProvider` gates first-launch number display. | Architecturally sound for the audited screens. **Needs verification for every other screen** before we can declare app-wide offline. |

---

## Streams

### Stream A — Hebrew Terms boundary cleanup (systemic)

**A1. Reclassify "structural string" vs "domain term" — write the rule down once.**
- Take `docs/hebrew-terms.md` §6's domain-term catalog as the closed list.
- Anything not on that list is structural → English in English locale, Hebrew in Hebrew locale, **never** touched by Hebrew Terms.
- **Decisions needed from owner:** (1) Is `siyumim` a domain term or a normal English word? (2) Is `streak` / `points` / `chazara` (already in catalog) — confirm streak/points are NOT domain terms.

**A2. Move streak & points labels out of `DomainTermLabels`.**
- `tierCounterStreakDays()`, `tierCounterPointsEarned()` (and any sibling methods) should resolve to `l10n.tileStreakLabel` / `l10n.tilePointsLabel` — pure structural ARB strings.
- Remove the Hebrew-Terms branch from those specific accessors.

**A3. Audit every screen for structural strings reading `useHebrewTermsProvider` or `HebrewTerms.*`.**
- Run `make audit` with the corrected grep (see A5).
- For each violator, decide: move to facade if it's a domain term, or replace with ARB lookup if it's structural.
- Examples already found: page titles (`Recent Activity`), card titles (`Completions and Achievements`, `Overall Knowledge`), section headers (`Streak`), pill labels (`Streak: 0 days`).

**A4. Execute the `docs/hebrew-terms.md` §11 punch list.**
- §11.1 — extend Hebrew-Terms awareness to `daf`, `seder`, `chumash`, `amud`, `masechta` and structural unit words (they're in the catalog but currently follow UI locale only).
- §11.2 — fix `"Chazara/Review"` → `"Chazara"`. "Review" is not used for a domain term.
- §11.3 — remove dead `HebrewTerms.uiBubbleChazara` constant or wire it up.
- §11.4 — route "Talmid Chochom" through the setting, not inline literals.
- §11.6 — stage names must re-render live on setting change (currently frozen at track creation).
- §11.7 — fix the stale "default is false" comment (it's `true`).
- §11.8 — consolidate `HebrewTerms.curriculumDisplayNames` vs `CurriculumId.displayNameHe` to a single source.

**A5. Fix `make audit` grep.**
- Per §11.5, the grep targets `hebrewTermsScriptProvider` (doesn't exist). Real symbol is `useHebrewTermsProvider`. Correct the Makefile target.
- Add a second grep for `HebrewTerms.` direct access outside `lib/core/labels/`.

---

### Stream B — Recent Activity rearchitecture (offline, perf, IA)

**Premise:** Two prior fix attempts failed because they tried to *optimise the existing flat-grid render*. The flat grid is the wrong primitive. The fix is to replace it with a virtualized + aggregated view.

**B1. Replace `StreakCalendar` with a Sliver-based virtualized list.**
- Use `CustomScrollView` + `SliverList` (one sliver per month) or `SliverGrid` (one grid per month).
- Each month becomes its own sliver section with a sticky header (`SliverPersistentHeader` with month/year label).
- Only visible months pay rendering cost; off-screen months stay as cheap delegates.
- **Target:** All Time scrolls at 60fps on a low-end device with 10+ years of data.

**B2. Introduce a `MonthlyActivityRollup` aggregation table.**
- Drift table: `(profileId, yearMonth, activeDays, totalCompletions, totalChazaros, firstActivityDate, lastActivityDate)`.
- Populated by a trigger or backfill from `CompletionEvents`.
- Backfilled on first launch after schema bump; incrementally updated by `CompletionWriter`.
- All Time view reads from this table first; only drills into per-day cells when a month is expanded.
- This is also the data that powers month sticky-headers (count, % active, etc.).

**B3. Two-level IA — "summary first, details on demand."**
- Default All Time view: a *list of month cards*, each showing the month name, activity count, and a mini heat strip (7-wide × 4–6 tall, computed from rollup).
- Tap a month → expand to the daily calendar for that month only.
- Last 7 / Last 30 keep the current direct day-cell view (bounded data, no perf issue).
- This matches the user's mental model — "show me what I did" at a glance, "let me drill in" on demand.

**B4. Offline-first by construction.**
- Both `MonthlyActivityRollup` and `CompletionsView` queries already live in Drift. No Firestore reads on this path.
- Sync state shown as a small badge at the top of the screen, not a blocking spinner.

**B5. Quality-of-life fixes.**
- R-3: title becomes "Recent Activity" via ARB (no Hebrew Terms touch).
- R-4: streak section header becomes "Streak" via ARB; pill becomes "0 day streak" / locale-aware plural.
- R-5: weekday header — either show `Sun Mon Tue Wed Thu Fri Sat` (3-letter) or `S M T W T F S` (start Sunday, US norm). Decide based on dashboard convention. (Current `S S M T W T F` starting with two S's is broken either way.)

**B6. Telemetry & regression guard.**
- Add a perf marker: `recent_activity_frame_time` (median + 95p) when "All Time" is selected.
- Add a unit test: `MonthlyActivityRollup.backfill` produces correct counts for a fixture profile.
- Add a widget test: All Time view renders within N ms with 10 years of fixture data.

---

### Stream C — Dashboard / Progress tile row cleanup

**C1. Equalize tile sizing.**
- Replace 4× `Expanded` `_Counter`s with a fixed-width tile (e.g. `width = (screen - gutters) / 4`) and clip / ellipsize labels that don't fit.
- OR introduce a `GridView.count(crossAxisCount: 4, childAspectRatio: 1)` so all tiles are guaranteed square and identical.

**C2. Fix the truncated 3rd tile.**
- Identify the label being cut off (likely `tierCounterLifetimeItems()` — "1336 פריטים בלמידת מסלול" or similar long Hebrew/English).
- Pick a short structural label that survives in both locales (e.g. "Items" / "פריטים") and move long context to the card subtitle below the number, not the tile label.
- Constrain to 2 lines max, ellipsize beyond.

**C3. Apply A2 to this widget.**
- Streak label & points label go through ARB, not `DomainTermLabels`.

**C4. Profile-scope the entire dashboard top section.**
- **Confirmed:** child-only. Move the gating from per-counter (`showPoints: child`) to a single `if (currentProfile.type != ProfileType.child) return _AdultDashboardTopSection()` at the section level.
- Rename any `UserMode.parent` / "parent" references in code to `adult` (terminology cleanup — see `project_profile_model` memory).
- **Tutor handling falls out for free:** when a tutor is active-as-tutored-child, `currentProfile.type == child`, so the child top section renders. No special case needed.
- **Adult top section is a separate design task** (Q-A below). Likely shape: family-overseer view — curricula progress summary across all child profiles in the household, no points, no streak, possibly a "needs attention" surface (children with overdue tasks).

**C5. Same tile row on Progress screen.**
- If it's the same widget, fixes auto-propagate. If it's a duplicate, consolidate to a single `ProgressTierCounterRow` used in both places.

---

### Stream D — Completion credit sentinel date enforcement

**D1. Verify `MarkCompletionUseCase` writes the sentinel date for `bulkInTrack`.**
- Audit `CompletionWriter` and any caller that passes `CompletionSource.bulkInTrack`.
- The stored date for bulk-in-track entries must be `1/1/2000` (or an agreed sentinel), not `DateTime.now()`.
- Add a unit test.

**D2. Audit every "recent" / "today" / "last N days" read.**
- Streak reducer, "today's missions", recent activity charts, achievement dailies — all must filter by date such that the sentinel value naturally excludes bulk entries from engagement-tier views.
- Confirm `getStreakCalendarLive` window excludes sentinel-dated rows.

**D3. Telemetry guards.**
- `bulk_engagement_skipped` counter (already noted in `project_completion_credit_policy`): increment when a bulk-in-track write reaches an engagement-tier handler and is correctly skipped.
- `lifetime_achievement_skipped` counter: same for lifetime-only writes that reach achievement handlers.

---

### Stream G — Track info display (goal date, start date, velocity)

**Premise:** Self-paced tracks have rich metadata that drives the pace calculation, but none of it is visible on the track screen. Surfacing it gives the user agency over their own pace and makes the "Ahead / Behind" indicator legible.

**G1. Define the track-info card** at the top of the track detail screen.
- `Started: <date locale-aware>` — when the user started this track.
- `Goal: <date locale-aware>` — target completion date.
- `Required pace: X items / day` (or `X items / week` if more legible).
- `Actual pace: X items / day` over the last 7 days of live activity.
- `Elapsed: N days · Remaining: N days`.
- Optionally: a small `Edit goal` action that opens the goal date picker.

**G2. Copy is structural, not Hebrew-Terms-aware** ("Started", "Goal", "Required pace", "Elapsed", "Remaining" all follow Rule 1).

**G3. Date format follows Rule 2** (locale-aware, never ISO or DMY).

**G4. Lives above the "Overall Progress" card** but below the back-button row. Keeps the existing pace indicator badge (after Stream F fix) — they reinforce each other rather than duplicate.

---

### Stream H — No track types cleanup (Product Rule 7)

**H1. Find every track-type leakage in the UI.**
- Start with the `אישי` ("Personal") label flagged on the Mishnayos breakdown — find its rendering site.
- Grep for `אישי`, `personal`, `custom`, `standard`, `default`, `manual` (case-insensitive) in `lib/features/**`.
- Grep for `trackType`, `TrackType`, `TrackCategory`, `track.type`.
- For each hit: is it a UI surface? If yes, remove it.

**H2. Decide between two fixes per call site:**
- **Remove entirely** — if the label adds no information.
- **Replace with the underlying signal** — if the label was masking something real (e.g. if `אישי` is currently being shown when stage data is missing, fix the missing stage data instead of showing a fallback).

**H3. Data layer.**
- If a `trackType` column / field exists in Drift or domain models, it's tech debt. Either remove or keep but ensure it never surfaces in UI. Owner decision: full removal vs UI-only suppression.

**H4. Regression guard.**
- ARB-level check: no `personal` / `custom` / `standard` keys in any track-scoped string set.
- Widget-level test: snapshot of a track-detail screen for two distinct track configurations contains no track-type label.

---

### Stream I — Chazara conditional rendering (Product Rule 8)

**I1. Find every chazara-related UI surface.**
- Per-masechta `· N חזרות` and `חזרות` counter on the Mishnayos breakdown.
- Stage rows showing `Chazara 1 / 2 / 3`.
- Per-track chazara progress on dashboards / progress lens screens.
- "X chazaros" labels anywhere.
- Total items math (`total = unique × (1 + chazara_passes)` only when chazara enabled).

**I2. Gate each on `track.chazaraEnabled`.**
- Build a single helper / extension: `if (track.chazaraEnabled) renderChazaraStuff() else nothing`.
- No "0 chazaros" placeholder. No greyed-out chazara row. Gone entirely.

**I3. Total-items math.**
- Audit every place that computes `total` for a track. If it multiplies by `(1 + chazaraPassCount)` unconditionally, it's wrong on non-chazara tracks.

**I4. Cross-track aggregates.**
- Lifetime knowledge / dashboard tiles that sum chazaros across tracks should sum only across tracks-that-have-chazara — and phrase the label to make this clear, or omit if no tracks have chazara enabled.

**I5. Generalisable principle (apply same lens to other per-track features):**
- Scheduling, daily goals, rewards, study-days — render only when configured for that track.

---

### Stream J — Visual polish (percentage badge & weekday header)

**J1. Percentage badge styling.**
- "100.00%" inside the green circular progress ring on track breakdown cards reads as visually mismatched (owner feedback 2026-05-20).
- Options: thinner ring, smaller %, integer-only when at 100% (`100%` not `100.00%`), different placement (above/below the circle instead of inside).
- Lower priority; lift to design review.

**J2. Weekday header in Recent Activity calendar.** (Cross-reference R-5 / Stream B5.)
- Resolve `S S M T W T F` ambiguity — pick 3-letter (`Sun Mon Tue …`) or 1-letter starting Sunday (`S M T W T F S`). (Q-W in Open Questions.)

---

### Stream F — Pace / velocity logic for self-paced tracks

**Premise:** A track is self-paced — the user sets a target completion date. The app must calculate the velocity required to hit that date and compare it against the user's actual live velocity. **Bulk-marked prior learning establishes the starting baseline** (where the learner is *today*); it must not count as retroactive pace credit. The "Ahead by 296 days" bug on day 1 is the visible failure.

**F1. Define the pace contract.**
- `trackStartDate` = date the track was created / configured by the user. Persisted on the track entity. Never derived from earliest completion.
- `targetDate` = user-set finish date.
- `bulkBaseline` = count of items completed before `trackStartDate` (all bulk-in-track entries, identifiable by sentinel date `< trackStartDate` per `project_completion_credit_policy`).
- `liveProgress` = count of live completions where `completedAt >= trackStartDate`. (Sentinel-dated bulk entries naturally fall below this threshold and are excluded.)
- `requiredVelocity` = `(total_items - bulkBaseline) ÷ (targetDate - trackStartDate).days`.
- `actualVelocity` = `liveProgress ÷ (today - trackStartDate).days` (with a floor on day 1 to avoid divide-by-zero).
- `expectedProgressToday` = `requiredVelocity × (today - trackStartDate).days`.
- `paceVariance` = `liveProgress - expectedProgressToday` (positive = ahead, negative = behind).
- `paceVarianceInDays` = `paceVariance ÷ requiredVelocity` (positive = ahead).

**F2. Fix the read.**
- Locate the pace provider (likely under `learning_tracker/lib/features/tracks/` or `progress/`).
- Verify it filters `completedAt >= trackStartDate` when computing `liveProgress`. If not, that single filter is the fix.
- If bulk entries are not currently sentinel-dated, the upstream `MarkCompletionUseCase` defect (Stream D1) is a prerequisite.

**F3. UI presentation.**
- Day 1 with no live completions: display `On track` or `Starts today` — not "Ahead by X" and not "Behind by X" (variance is meaningfully zero for an entire window of grace).
- The grace window length is a design decision — propose 1–3 days. (Q-G below.)
- Caption text `Pace tracks live learning only` is correct and should stay.

**F4. Tests.**
- Unit: track started today, 1000 bulk-baseline items, 0 live → variance = 0, status = "On track."
- Unit: track started 30 days ago, target 100 days out, 1000 baseline + 100 live, expected 33 items by now → variance = +67 items / +~10 days ahead.
- Unit: same but 10 live instead of 100 → variance = -23 items / behind.
- Widget: regression test that re-loads the Mishnayos screen with a fixture profile matching today's bug and asserts the variance is zero on day 1.

**F5. Telemetry.**
- `pace_bulk_leakage_detected` counter: increments if `liveProgress > 0` is computed *and* any contributing completion has `completedAt < trackStartDate`. Should always be zero — if it fires, the date filter regressed.

---

### Stream E — App-wide offline verification

**E1. Inventory every screen and identify its data source.**
- Use the route table / page list to enumerate.
- For each, confirm: reads from Drift, writes Drift-first, no `await firestore` in the UI path.

**E2. Identify and refactor any Firestore-direct reads.**
- Any provider that calls Firestore directly is a bug. Route it through Drift via the sync engine.

**E3. Network state UI policy.**
- Single global `syncStatusBadge` (synced / syncing / offline) — informational, top-right of every screen, never blocks.
- Remove any "you're offline" full-screen states except for genuinely-online-only flows (sign-in, password reset, first-launch initial sync, remote config refresh).

**E4. Offline test in CI.**
- Add an integration test that runs the app with network disabled and exercises: open dashboard, open progress, open recent activity, open settings, mark a completion live, mark a completion bulk, switch profile.
- All must succeed without a network round-trip.

---

## Sequencing

| Wave | Streams | Why |
|---|---|---|
| **Wave 1 — Architecture & decisions** | A1, A5, B1+B2 (spike), D1, F1, G1, H1, I1, E1 | Decide the catalog, fix the audit tool, prototype the rollup table, verify sentinel date, define the pace contract, sketch the track-info card, locate track-type leakage, locate chazara surfaces, inventory offline status. Cheap, blocking everything downstream. |
| **Wave 2 — Hebrew Terms structural cleanup + track-screen fixes** | A2, A3, A4 (partial: 11.1, 11.2, 11.4), C3, F2, F3, G2-G4, H2-H4, I2-I5 | High-volume label moves once the catalog is settled. Pace read fix small (depends on D1+F1). Track-info card UI build. Track-type removal & chazara gating across screens. Parallel-safe within each stream. |
| **Wave 3 — Recent Activity rewrite** | B1, B2, B3, B4, B5, B6 | The big one. Land behind a feature flag if the rewrite is risky; otherwise direct replace (pre-launch, so safe). |
| **Wave 4 — Tile row cleanup + polish** | C1, C2, C4, C5, J1, J2 | Smaller-scope UI fixes; benefits from A's catalog being finalised. |
| **Wave 5 — Credit, offline finishing & tests** | A4 (rest: 11.3, 11.6, 11.7, 11.8), D2, D3, F4, F5, E2, E3, E4 | Stage-name live re-render, dedup, telemetry (incl. pace tests + leakage counter), full offline test harness. |

---

## Open questions for owner

1. **Q-S.** Is "siyumim" a domain term (governed by Hebrew Terms) or a structural English word? (P-3)
2. **Q-A. Adult top section shape.** What does an adult profile see on the dashboard instead of the child's 4-tile + streak + points + Current Balance + Stats? No points (confirmed). Candidates worth your reaction:
    - **(a)** Family overview — list of child profiles in this household with each child's "today's missions" status, overdue count, recent streak.
    - **(b)** Single adult-focused metric strip — total household items learnt this week / this month, total siyumim by all children, perhaps an "X children active today" pulse.
    - **(c)** Action-first — "needs your attention" surface (children with overdue, pending tutor invitations, sync issues) above a quieter progress strip.
    - Your call — or describe the worldview and Sally can sketch.
3. **Q-W.** Weekday header preference — 3-letter (`Sun Mon Tue`) or 1-letter (`S M T W T F S`)? (B5/R-5)
4. **Q-IA.** All Time IA — month cards with mini heat strips (B3), or a different shape entirely (e.g. year-row of monthly bars, or a heat-map only)? Owner has the worldview; I have the patterns.
5. **Q-O.** Online-only flows — confirm the candidate list (sign-in, password reset, first initial sync, remote-config refresh) is exhaustive. Anything else needs to be offline-safe.
6. **Q-Term.** Code-side terminology cleanup — there appears to be `UserMode.parent` (or similar) in the codebase. Rename to `adult` as part of Stream C? Or treat that as a separate cleanup pass?
7. **Q-G.** Pace grace window — on day 1 (and possibly day 2–3), there's no meaningful "ahead" or "behind" to display. Propose: show `On track` or `Just started` for the first 1–3 days of a track. How many days?

---

## What this plan does NOT do

- It does not rewrite the sync engine. Drift-first is already in place; offline work is enforcement + verification, not rebuild.
- It does not redesign the broader information architecture beyond what these specific defects surface. Tutor mode, completion-policy UI, curriculum browsing are out of scope.
- It does not change the data model except to add `MonthlyActivityRollup`. No Drift/Firestore schema reset is proposed here (although the pre-launch status would permit one if scope grew).
