# Learning Journey View

## Target

A visual representation of a learner's progress through a curriculum's linear structure, highlighting gaps — items completed on both sides but not in the middle. This is the user-facing surface for Scenario 8 (Out-of-Order Explorer). Internal name: Coverage Map. Learner-facing name: **Learning Journey**.

The Learning Journey answers: "What have I covered, what did I skip, and where are the holes?" It is never nagging — gaps are shown as information, not as debt. The learner can act on gaps or ignore them.

Also serves as the second access point for amnesty history alongside the Review Debt view (per Q20 lean).

## Current State

Today:
- The existing `LearningJourneyScreen` (`/features/progress/presentation/screens/learning_journey_screen.dart`) shows lifetime achievements in a timeline format
- `HierarchyProgressCard` shows per-unit progress percentages
- `JourneyGroupedView` and `JourneyTimelineView` present completions chronologically
- No visualization of *gaps* in sequence — only what's been done, not what's missing
- No way to see that perek 3 is untouched between completed pereks 2 and 4
- No actions available from the progress view (no amnesty, no scheduling)

## Desired State

A curriculum-structure view (not timeline — structure-first) that:

1. **Shows the curriculum as a linear sequence** with learned sections highlighted and gaps shown as hollow segments
2. **Hierarchy navigation**: top level shows units (masechtos/sedarim/simanim per `primary_unit_type`), drill into individual items within a unit
3. **Color coding**:
   - Solid fill: completed (all stages done or current)
   - Partial fill: learning done, chazara incomplete
   - Hollow: not started (expected gap — haven't gotten there yet)
   - Highlighted hollow: gap with completions on both sides (the interesting kind)
   - Striped/dimmed: amnestied (visible but not counted as debt)
4. **Per-item detail on tap**: shows completion date, chazara status, amnesty status
5. **Gap actions**:
   - `[Fill gap]` — route to scheduler for the gapped items
   - `[Amnesty gap]` — mark as deliberately skipped
   - `[Schedule for later]` — add to future plan with a date
   - `[Ignore]` — no action, gap stays visible
6. **Amnestied items visible** in context — shown in their structural position (not hidden), with an "unforgive" action per Q20
7. **Per-track or cross-track**: default is single-track; optional side-by-side for the same curriculum across multiple tracks

## User Journey

### Entry points
- **From track detail screen**: "Learning Journey" section link
- **From progress screen**: per-curriculum card action
- **From Catch-up Sheet**: "See your Learning Journey" link (informational, not action-required)
- **From S8 detection**: if `orderGaps > 0`, a subtle prompt on the track card links here

### Flow

```
1. View opens with track name + curriculum structure

2. Top-level: unit grid or list
   ┌──────────────────────────────────────┐
   │  Mishnayos Berachos                  │
   │                                      │
   │  ██ Perek 1    ██ Perek 2            │
   │  ░░ Perek 3    ██ Perek 4            │
   │  ▒▒ Perek 5    ░░ Perek 6            │
   │  ░░ Perek 7    ░░ Perek 8            │
   │  ░░ Perek 9                          │
   │                                      │
   │  ██ = complete  ░░ = not started     │
   │  ▓▓ = gap (skipped)  ▒▒ = partial   │
   │                                      │
   │  "1 gap: Perek 3"                    │
   └──────────────────────────────────────┘

3. Tap on Perek 3 (gap):
   ┌──────────────────────────────────────┐
   │  Perek 3 — 8 mishnayos, 0 learned   │
   │  Gap: Perek 2 and Perek 4 are done   │
   │                                      │
   │  [Fill gap now]  [Amnesty]           │
   │  [Schedule for later]  [Ignore]      │
   └──────────────────────────────────────┘

4. Tap on Perek 5 (partial — learning done, chazara incomplete):
   ┌──────────────────────────────────────┐
   │  Perek 5 — 6/6 learned              │
   │  Chazara: 4/6 stage 1, 2/6 stage 2  │
   │  "2 reviews overdue" → [Review Debt] │
   └──────────────────────────────────────┘

5. Tap on an amnestied item within a unit:
   Shows amnesty date, reason, source
   [Unforgive] — puts it back in queue
```

### Cross-track comparison (secondary)

```
If learner has two Bavli tracks (personal + Daf Yomi):
Toggle at top: [Single track ▼] → [Compare tracks]

Side-by-side or overlay view showing both tracks' coverage 
of the same curriculum structure. Helps answer: 
"Am I learning different masechtos on each track, or overlapping?"
```

## Success Criteria

- Learner can see their full curriculum coverage at a glance — gaps are immediately visible
- Gaps with completions on both sides are visually distinct from "haven't gotten there yet"
- Amnestied items are visible in structural context (not hidden) with unforgive capability
- Per-gap actions are reachable in 2 taps from the top-level view
- Review debt within a unit links to the Review Debt view (cross-surface navigation)
- Never nags — this view is informational and action-optional
- Notifications never reference this view ("you have gaps!") — it is accessed by choice

## Scope

### Pages affected
- New: **Learning Journey view** (full-screen route — the primary new surface)
- Existing: `LearningJourneyScreen` — either extended or replaced (current timeline view may become a tab alongside the new structural view)
- **Track detail screen** — link to this view
- **Progress screen** — link to this view per curriculum

### Components touched
- New: `CoverageMapScreen` — main structural view (internally named, learner sees "Learning Journey")
- New: `UnitCoverageGrid` — top-level unit grid with fill-state color coding
- New: `UnitDetailSheet` — per-unit drill-down showing items, gaps, chazara status
- New: `GapActionBar` — per-gap actions (fill, amnesty, schedule, ignore)
- New: `CoverageComparisonView` — optional cross-track overlay (secondary)
- Existing: `HierarchyProgressCard` — may be reused or replaced for the unit grid
- Links to: `ReviewDebtScreen` (for chazara debt within a unit)

### Data changes
- Reads: completions per track, `item_amnesty` records, `orderGaps` from `TrackDebt`, stage completion status
- Writes: `item_amnesty` inserts (for gap amnesty), scheduler adjustments (for "schedule for later")
- Writes: `track_action_log` entries with source `"learning_journey"`

### Risk level
**Medium** — the structural visualization requires mapping the curriculum's linear hierarchy to a visual grid, which depends on curriculum metadata quality. The data reads are complex (joining completions + amnesty + stage status across an entire curriculum). Cross-track comparison adds further complexity but is a secondary feature.

## Design decisions to resolve during specification

1. **Visualization style**: grid of blocks (like a heatmap) or linear track (like a scrollable ribbon)? (Lean: grid — more compact, shows the whole curriculum at once for smaller curricula; ribbon for very large ones like full Bavli)
2. **Unit size threshold**: at what curriculum size does the top-level show masechtos vs. sedarim? (Lean: follow `primary_unit_type` — it's already resolved per Q8)
3. **Relationship to existing Learning Journey screen**: replace, or add as a new tab alongside the timeline? (Lean: add as a tab — "Structure" and "Timeline" — the timeline view has value for chronological reflection)
4. **Per-item detail**: inline expansion or separate drill-down sheet? (Lean: bottom sheet — keeps the structural overview visible while showing item detail)
5. **Color accessibility**: the fill-state system relies on color — needs accessible alternatives (patterns, labels) for color-blind users. (Must-have for spec.)
