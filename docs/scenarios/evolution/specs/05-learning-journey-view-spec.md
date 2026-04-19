# 05 — Learning Journey: Structure Tab (Coverage Map)

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Learning Journey View (Scenario 05) |
| **Route** | `/journey` (existing `LearningJourneyScreen`, extended with tab bar) |
| **Platform** | Mobile (Flutter / Android) |
| **Page Type** | Full-screen pushed route with tab bar (Timeline + Structure) |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |
| **Internal name** | `CoverageMapTab` |
| **User-facing name** | "Learning Journey" (tab label: "Structure") |

---

## Overview

**Page Purpose:** Show the learner's curriculum coverage as a structural visualization — what has been learned, what was skipped, and where the gaps are — so the learner can act on gaps or simply understand their progress shape.

**User Situation:** The learner has an active track and wants to understand their coverage of the curriculum's linear hierarchy. They may have gaps (items completed on both sides of uncompleted items), partial completions (learning done but chazara incomplete), and amnestied items. This view is informational and never nags.

**Success Criteria:** The learner can see their full curriculum coverage at a glance within 3 seconds. Gaps with completions on both sides are visually distinct from "haven't gotten there yet." Per-gap actions are reachable in 2 taps from the top-level view.

**Entry Points:**
- From track detail screen: "Learning Journey" section link
- From progress screen: per-curriculum card action
- From Catch-up Sheet: "See your Learning Journey" link
- From S8 detection: if `orderGaps > 0`, subtle prompt on the track card

**Exit Points:**
- Tap unit block -> Unit detail bottom sheet
- Tap "Review Debt" link in bottom sheet -> `ReviewDebtScreen` (filtered to unit)
- Tap "Fill gap now" -> Scheduler screen (with gap items pre-selected)
- Tab switch -> Timeline tab (existing `JourneyTimelineView`)
- Back navigation -> previous screen

---

## Layout Structure

```
┌──────────────────────────────────────┐
│ APP BAR                              │
│ "My Learning Journey"                │
├──────────────────────────────────────┤
│ TAB BAR                              │
│ [ Timeline ]  [ Structure ]          │
├──────────────────────────────────────┤
│ TRACK SELECTOR (if multi-track)      │
│ [Track A ▼]        [Compare tracks]  │
├──────────────────────────────────────┤
│ GAP SUMMARY BAR                      │
│ "3 gaps · 12 items with overdue      │
│  chazara"                            │
├──────────────────────────────────────┤
│ LEGEND ROW                           │
│ ██ Complete  ▒▒ Partial  ░░ Not      │
│ ◆◆ Gap       ·· Amnestied           │
├──────────────────────────────────────┤
│ UNIT GRID / RIBBON                   │
│ (adaptive based on curriculum size)  │
│                                      │
│ Grid mode (compact curricula):       │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
│ │ ██ │ │ ██ │ │ ◆◆ │ │ ██ │        │
│ │ P1 │ │ P2 │ │ P3 │ │ P4 │        │
│ └────┘ └────┘ └────┘ └────┘        │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
│ │ ▒▒ │ │ ░░ │ │ ░░ │ │ ░░ │        │
│ │ P5 │ │ P6 │ │ P7 │ │ P8 │        │
│ └────┘ └────┘ └────┘ └────┘        │
│ ┌────┐                              │
│ │ ░░ │                              │
│ │ P9 │                              │
│ └────┘                              │
│                                      │
│ Ribbon mode (large curricula):       │
│ ◄ ██ ██ ◆◆ ██ ▒▒ ░░ ░░ ... ░░ ►   │
│   B  S  E  P  S  Y  N      M       │
│   (horizontally scrollable)          │
│                                      │
├──────────────────────────────────────┤
│ COMPARISON MODE (when toggled):      │
│ Track A:  ██ ██ ◆◆ ██ ░░ ░░        │
│ Track B:  ██ ░░ ██ ░░ ██ ░░        │
└──────────────────────────────────────┘
```

**Scroll behavior:** Vertical scroll for the full page. Grid mode: wrapping grid within the scroll. Ribbon mode: horizontal scroll for the unit strip within a vertically scrollable page. Pull-to-refresh invalidates coverage data providers.

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `md` (16dp) |
| Section gap (tab bar to track selector, selector to summary, summary to legend, legend to grid) | `md` (16dp) |
| Grid cell gap | `sm` (8dp) |
| Grid cell size (grid mode) | 72dp x 72dp |
| Ribbon cell size | 48dp x 48dp |
| Ribbon cell gap | `xs` (4dp) |
| Legend item gap | `md` (16dp) |
| Bottom sheet internal padding | `lg` (24dp) horizontal, `md` (16dp) vertical |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Style | Size | Weight |
|---------|-------|------|--------|
| App bar title | `titleLarge` | 22sp | normal |
| Tab labels | `titleSmall` | 14sp | w500 |
| Track selector | `bodyLarge` | 16sp | w500 |
| Gap summary text | `bodyMedium` | 14sp | normal |
| Legend labels | `labelSmall` | 11sp | normal |
| Unit cell label (grid mode) | `labelMedium` | 12sp | w500 |
| Unit cell label (ribbon mode) | `labelSmall` | 11sp | normal |
| Bottom sheet title | `titleMedium` | 16sp | w500 |
| Bottom sheet body | `bodyMedium` | 14sp | normal |
| Bottom sheet action buttons | `labelLarge` | 14sp | w500 |

---

## Page Sections

### Section: Tab Bar

**OBJECT ID:** `journey-tab-bar`

| Property | Value |
|----------|-------|
| Purpose | Switch between Timeline (existing) and Structure (new) views |
| Component | Material 3 `TabBar` |
| Tabs | "Timeline", "Structure" |
| Default tab | "Timeline" (preserves existing behavior; deep-links from gap prompts select "Structure") |
| Indicator | M3 default underline indicator |
| Persistence | Tab selection persists for session via `journeyTabProvider` |

---

### Section: Track Selector

**OBJECT ID:** `coverage-track-selector`

| Property | Value |
|----------|-------|
| Purpose | Select which track to visualize; toggle comparison mode |
| Visible | When profile has 2+ tracks on the same curriculum |
| Layout | Row: dropdown on left, "Compare" text button on right |
| Dropdown | Lists tracks by `trackLabel`, shows curriculum name as subtitle |
| Compare button | "Compare tracks" / "Single track" toggle |
| Hidden | When only 1 track exists for the curriculum (no selector needed) |

---

### Section: Gap Summary Bar

**OBJECT ID:** `coverage-gap-summary`

| Property | Value |
|----------|-------|
| Purpose | At-a-glance count of structural gaps and chazara debt within this curriculum |
| Layout | Single row of text |
| Content template | "{gapCount} gap(s) · {chazaraOverdueCount} items with overdue chazara" |
| Content (no gaps) | "No gaps — great coverage!" |
| Content (no data) | Hidden |
| Style | `bodyMedium`, `onSurfaceVariant` color. Gap count in `primary` color if > 0 |
| Tap | No action (informational only) |

---

### Section: Legend

**OBJECT ID:** `coverage-legend`

| Property | Value |
|----------|-------|
| Purpose | Key for fill-state color coding and accessible patterns |
| Layout | Horizontal wrap row of legend items |
| Items | 5 items, each: 16dp swatch + 4dp gap + label |

#### Legend Items

| State | Color | Pattern (non-color differentiator) | Icon Badge | Label |
|-------|-------|--------------------------------------|------------|-------|
| Complete | `primary` (solid fill) | Solid fill, no pattern | Small checkmark (check icon, 10dp) | "Complete" |
| Partial | `primaryContainer` | Diagonal lines (45-degree, 2dp stroke, 4dp gap) | Half-circle icon (10dp) | "Partial" |
| Not started | `surfaceContainerHigh` | Hollow (border only, no fill) | None | "Not started" |
| Gap | `errorContainer` with `error` border | Hollow with bold 3dp border + diamond icon | Diamond icon (10dp, `error` color) | "Gap" |
| Amnestied | `surfaceContainerLow` | Dot pattern (2dp dots, 6dp spacing) | Strikethrough icon (10dp) | "Amnestied" |

---

### Section: Unit Grid (Grid Mode)

**OBJECT ID:** `coverage-unit-grid`

| Property | Value |
|----------|-------|
| Purpose | Structural visualization of curriculum units |
| Visible | When unit count <= 20 (adaptive threshold) |
| Component | `Wrap` widget with fixed-size children |
| Cell size | 72dp x 72dp |
| Cell gap | `sm` (8dp) |
| Cell shape | Rounded rectangle, 8dp corner radius |
| Cell content | Unit abbreviation (e.g., "P1", "Ber", "Shab"), centered |
| Cell arrangement | Left-to-right, top-to-bottom, following curriculum sequence order |
| Semantics | Each cell has `Semantics(label: "{unitName}, {stateLabel}")` |

#### Unit Cell States

| State | Fill | Border | Pattern Overlay | Icon Badge | Semantics Label Suffix |
|-------|------|--------|-----------------|------------|----------------------|
| **Complete** | Solid `primary` color | 1dp `primary` | None | Checkmark (top-right, 12dp, `onPrimary`) | "complete" |
| **Partial** | `primaryContainer` | 1dp `primary` | Diagonal lines (45-degree hatch, `primary` at 40% opacity, 2dp stroke, 4dp gap) | Half-circle (top-right, 12dp, `primary`) | "partially complete, chazara remaining" |
| **Not started** | `surface` (transparent/hollow) | 1dp `outline` | None | None | "not started" |
| **Gap** | `surface` (hollow) | 3dp `error` (bold accent border) | None | Diamond (top-right, 12dp, `error`) | "gap, skipped between completed units" |
| **Amnestied** | `surfaceContainerLow` | 1dp `outlineVariant` | Dot pattern (2dp circles at 6dp spacing, `onSurface` at 20% opacity) | Strikethrough (top-right, 12dp, `onSurfaceVariant`) | "amnestied" |

#### Cell Tap Behavior

| Property | Value |
|----------|-------|
| Tap | Opens `UnitDetailSheet` bottom sheet for that unit |
| Long press | No action (reserved) |
| Ripple | M3 default ripple effect, clipped to cell bounds |

---

### Section: Unit Ribbon (Ribbon Mode)

**OBJECT ID:** `coverage-unit-ribbon`

| Property | Value |
|----------|-------|
| Purpose | Horizontal scrollable strip for large curricula |
| Visible | When unit count > 20 |
| Component | Horizontal `ListView.builder` inside a fixed-height container |
| Container height | 80dp (48dp cell + label below) |
| Cell size | 48dp x 48dp |
| Cell gap | `xs` (4dp) |
| Cell shape | Rounded rectangle, 6dp corner radius |
| Cell content | Abbreviated unit name below the cell (e.g., "Ber", "Shab") |
| Scroll indicators | Fade gradient on left/right edges when content overflows |
| Auto-scroll | On open, scroll to first gap (if any); otherwise scroll to last completed unit |
| States | Same fill/border/pattern/badge system as grid cells, scaled to 48dp |

---

### Section: Unit Detail Bottom Sheet

**OBJECT ID:** `coverage-unit-detail-sheet`

| Property | Value |
|----------|-------|
| Purpose | Per-unit drill-down showing items within the unit, their status, and gap actions |
| Component | Material 3 `showModalBottomSheet` with drag handle |
| Max height | 60% of screen height |
| Min height | 200dp |
| Corner radius | 16dp (top corners) |

#### Sheet Header

**OBJECT ID:** `coverage-unit-detail-header`

| Property | Value |
|----------|-------|
| Layout | Column: unit name, item count, status summary |
| Line 1 | Unit name (`titleMedium`, w500) — e.g., "Perek 3 — Eilu Devarim" |
| Line 2 | "{completedCount}/{totalCount} items learned" (`bodyMedium`, `onSurfaceVariant`) |
| Line 3 (if gap) | "Gap: {prevUnit} and {nextUnit} are done" (`bodySmall`, `error` color) |
| Line 3 (if partial) | "{overdueCount} chazara overdue" (`bodySmall`, `error` color) with tap -> `ReviewDebtScreen` filtered |

#### Item List

**OBJECT ID:** `coverage-unit-detail-items`

| Property | Value |
|----------|-------|
| Layout | Vertical `ListView` of item rows within the sheet |
| Item row height | 48dp |
| Item row layout | Row: 8dp left color bar (matching fill state) + content column + trailing status |
| Content | Item reference (e.g., "Mishna 3:1") (`bodyMedium`) |
| Trailing — complete | Checkmark icon, `primary` color |
| Trailing — partial | Clock icon, `primaryContainer` color. Tap -> review debt for this item |
| Trailing — not started | Empty circle, `outline` color |
| Trailing — gap | Diamond icon, `error` color |
| Trailing — amnestied | Strikethrough icon, `onSurfaceVariant` color |

#### Item Detail Expansion

**OBJECT ID:** `coverage-unit-detail-item-expanded`

| Property | Value |
|----------|-------|
| Trigger | Tap on any item row |
| Behavior | Expands in-place (animated, 200ms ease-out) |
| Shows | Completion date (if completed), chazara stage status, amnesty date/reason (if amnestied) |
| Amnestied items | Show amnesty date, reason, source. Include `[Unforgive]` action button |

#### Gap Action Bar

**OBJECT ID:** `coverage-gap-actions`

| Property | Value |
|----------|-------|
| Visible | When the selected unit is a gap (or contains gap items) |
| Position | Sticky at the bottom of the sheet, above safe area |
| Layout | 2x2 grid of action buttons (outlined style) |

##### Gap Actions

| Action | Label | Icon | Behavior |
|--------|-------|------|----------|
| Fill gap now | "Fill gap" | Play circle | Navigate to scheduler with gap items queued. Close sheet. |
| Amnesty | "Amnesty" | Archive | Confirmation dialog: "Mark {count} items as amnestied? They won't count as debt." On confirm: insert `item_amnesty` records, log to `track_action_log` with source `"learning_journey"`. Refresh grid. |
| Schedule for later | "Schedule" | Calendar | Date picker dialog. On confirm: create scheduled tasks for gap items at selected date. Close sheet. |
| Ignore | "Ignore" | Close circle | Close sheet. No data change. Gap remains visible. |

#### Amnesty Item Actions

**OBJECT ID:** `coverage-amnesty-actions`

| Property | Value |
|----------|-------|
| Visible | When viewing an amnestied item in expanded detail |
| Action | `[Unforgive]` outlined button |
| Behavior | Confirmation dialog: "Put this item back in your learning queue?" On confirm: delete `item_amnesty` record, log to `track_action_log`. Refresh grid. |

#### Chazara Debt Link

**OBJECT ID:** `coverage-chazara-debt-link`

| Property | Value |
|----------|-------|
| Visible | When unit has items with overdue chazara |
| Layout | Text button at bottom of sheet header |
| Text | "{N} chazara overdue in this unit" (`bodySmall`, `primary` color, underlined) |
| Action | Navigate to `ReviewDebtScreen` with filter `unitId={unitId}` |

---

### Section: Cross-Track Comparison

**OBJECT ID:** `coverage-comparison-view`

| Property | Value |
|----------|-------|
| Purpose | Side-by-side visualization of two tracks on the same curriculum |
| Visible | When comparison mode toggled on and 2+ tracks share a curriculum |
| Layout | Two stacked ribbons (Track A label + ribbon, Track B label + ribbon), synchronized horizontal scroll |
| Track labels | `bodyMedium`, w500, left-aligned above each ribbon |
| Ribbon height | 48dp per ribbon + 8dp gap between |
| Scroll sync | Both ribbons scroll together (single `ScrollController`) |
| Cell highlighting | When same unit has different states across tracks, add a subtle underline connector between the two cells |

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Default** | Track has curriculum data, completions exist | Full layout: grid/ribbon with fill states | Tap units, switch tabs |
| **Loading** | Initial data fetch | Shimmer placeholders: tab bar visible, grid area shows 8 shimmer rectangles in grid layout | Pull-to-refresh |
| **Empty — no completions** | Track exists but 0 items completed | All units shown as "Not started" (hollow). Gap summary: "No gaps — start learning to see your coverage!" | Tap units (shows items but no status) |
| **All complete** | Every unit fully complete (all stages) | All units solid fill. Gap summary: "Complete coverage — amazing!" | Tap units for chazara detail |
| **Error** | Provider error | Error banner with retry button, tab bar still visible | Pull-to-refresh, retry button |
| **No curriculum metadata** | Curriculum lacks structural hierarchy data | Fallback message: "Structural view isn't available for this curriculum yet. Use the Timeline tab to see your progress." | Switch to Timeline tab |

---

## Data Sources

| Provider | Purpose | Invalidation |
|----------|---------|-------------|
| `coverageMapProvider(trackId)` | Returns `CoverageMapViewModel`: list of units with fill state, gap detection, item counts | Pull-to-refresh, after amnesty/unforgive actions |
| `unitDetailProvider(trackId, unitId)` | Returns items within a unit: completion status, chazara stages, amnesty records | After gap actions (amnesty, unforgive, schedule) |
| `trackDebtProvider(trackId)` | Provides `orderGaps` count and chazara overdue count for summary bar | Pull-to-refresh |
| `activeTracksProvider` | Lists tracks for track selector and comparison mode | Pull-to-refresh |
| `journeyTabProvider` | Stores selected tab index (Timeline/Structure) | Session-scoped, not persisted |

### Coverage Map Computation

The `coverageMapProvider` computes fill state per unit by:

1. Fetching all items in the curriculum's linear sequence, grouped by `primary_unit_type`
2. For each unit, checking completion records: all items complete -> "complete"; some items complete -> check if chazara is current (partial vs complete); no items complete -> "not started"
3. Gap detection: a unit is a "gap" if it has 0 completions AND there exist completed units both before and after it in the sequence
4. Amnesty: any unit where all incomplete items have `item_amnesty` records is "amnestied"
5. Mixed state: if a unit has some amnestied and some gap items, show as "gap" (amnestied items shown in detail drill-down)

---

## Animations

| Animation | Trigger | Duration | Curve |
|-----------|---------|----------|-------|
| Tab switch | Tap tab | 300ms | `easeInOut` (default `TabBarView` animation) |
| Grid cell appear | Initial load | 150ms staggered per cell (50ms delay between cells, max 1s total) | `easeOut` — cells scale from 0.8 to 1.0 with fade-in |
| Bottom sheet open | Tap unit cell | 250ms | M3 default sheet animation |
| Item row expand | Tap item in sheet | 200ms | `easeOut` — height expansion with fade-in for detail content |
| Fill state change | After amnesty/unforgive | 300ms | `easeInOut` — color/pattern cross-fade on affected cells |
| Ribbon auto-scroll | On Structure tab open | 500ms | `easeOut` — smooth scroll to first gap |

---

## Accessibility

| Requirement | Implementation |
|-------------|----------------|
| **Color independence** | Every fill state has a non-color differentiator: pattern overlay (diagonal lines, dots) + icon badge (checkmark, half-circle, diamond, strikethrough). See Unit Cell States table. |
| **Screen reader** | Each unit cell has `Semantics(label: "{unitName}, {stateLabel}")`. Gap summary bar is a live region. Bottom sheet announced on open. |
| **Touch targets** | Grid cells: 72dp (exceeds 48dp minimum). Ribbon cells: 48dp (meets minimum). Action buttons in sheet: 48dp height. |
| **Focus order** | Tab bar -> track selector -> gap summary -> legend -> grid cells (row by row, left to right) -> comparison toggle |
| **Reduce motion** | When `MediaQuery.disableAnimations`, skip staggered cell animation (show all at once), reduce sheet animation to instant |
| **High contrast** | Fill patterns use sufficient contrast against both light and dark surface colors. Gap border is 3dp (exceeds 1dp minimum for visibility). |
| **RTL support** | Grid reads right-to-left. Ribbon scrolls right-to-left. Labels remain correctly positioned. |

---

## Acceptance Criteria

- [ ] Structure tab appears alongside Timeline tab in the Learning Journey screen
- [ ] Tab defaults to Timeline; deep-links from gap prompts open Structure
- [ ] Grid mode renders for curricula with <= 20 units; ribbon mode for > 20
- [ ] All 5 fill states render with correct color, pattern overlay, and icon badge
- [ ] Colorblind users can distinguish all 5 states without relying on color (patterns + badges)
- [ ] Tapping a unit cell opens the bottom sheet with item-level detail
- [ ] Gap units show all 4 actions: Fill gap, Amnesty, Schedule, Ignore
- [ ] Amnesty action inserts `item_amnesty` records and logs to `track_action_log` with source `"learning_journey"`
- [ ] Unforgive action on amnestied items deletes `item_amnesty` record and refreshes grid
- [ ] Chazara debt link in bottom sheet navigates to `ReviewDebtScreen` filtered to the unit
- [ ] Gap summary bar shows correct counts; updates after actions
- [ ] Cross-track comparison mode shows two synchronized ribbons for tracks sharing a curriculum
- [ ] Ribbon mode auto-scrolls to the first gap on open
- [ ] Pull-to-refresh invalidates all coverage providers
- [ ] Loading state shows shimmer placeholders
- [ ] Error state shows retry option
- [ ] Screen reader reads unit names and states correctly
- [ ] RTL layout mirrors grid and ribbon direction
- [ ] No notifications or push prompts ever reference gaps or this view
- [ ] The view never uses nagging language; all content is informational

---

## Components Summary

| Component | Internal Name | Type | New/Existing |
|-----------|--------------|------|-------------|
| Tab bar wrapper | `LearningJourneyTabBar` | Widget | New (wraps existing screen) |
| Structure tab body | `CoverageMapTab` | Widget | New |
| Track selector | `CoverageTrackSelector` | Widget | New |
| Gap summary bar | `CoverageGapSummary` | Widget | New |
| Legend row | `CoverageLegend` | Widget | New |
| Unit grid | `CoverageUnitGrid` | Widget | New |
| Unit ribbon | `CoverageUnitRibbon` | Widget | New |
| Unit cell | `CoverageUnitCell` | Widget | New (shared between grid and ribbon) |
| Unit detail bottom sheet | `UnitDetailSheet` | Widget | New |
| Gap action bar | `GapActionBar` | Widget | New |
| Comparison view | `CoverageComparisonView` | Widget | New |
| Coverage map provider | `coverageMapProvider` | Riverpod provider | New |
| Unit detail provider | `unitDetailProvider` | Riverpod provider | New |

---

## Open Questions

| # | Question | Context | Status |
|---|----------|---------|--------|
| 1 | Exact threshold for grid vs ribbon? | Spec uses 20 as threshold. Bavli has 37 masechtos (ribbon). Mishnayos by seder has 6 (grid). Need to verify edge cases around 15-25 range. | Resolved: 20 units |
| 2 | Comparison mode: overlay or stacked ribbons? | Stacked ribbons are simpler to implement and read. Overlay could be more compact but risks visual confusion. | Resolved: stacked ribbons with synchronized scroll |
| 3 | Should "Schedule for later" show a date picker or a relative selector ("next week", "next month")? | Date picker is more precise but heavier UX. | Open |

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined (grid + ribbon modes)
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All fill states documented with color + pattern + icon
- [x] Color accessibility resolved (patterns, badges, bold borders)
- [x] All page states documented
- [x] Data sources specified
- [x] Animations specified
- [x] Accessibility requirements specified
- [x] Acceptance criteria complete
- [x] Component inventory listed
- [x] Bottom sheet detail and actions specified
- [x] Cross-track comparison specified
- [x] Design decisions resolved (grid/ribbon threshold, unit type, tab structure, bottom sheet, patterns)

---

_Created using Whiteport Design Studio (WDS) methodology_
