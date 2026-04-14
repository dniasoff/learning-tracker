# 06 — Amnesty History

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Amnesty History / Skipped View |
| **Route** | `/tracks/:trackId/amnesty-history` (single-track) or `/amnesty-history` (cross-track) |
| **Platform** | Mobile (Flutter) |
| **Page Type** | Full-screen pushed route |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated, requires 1+ track with amnesty capability |

---

## Overview

**Page Purpose:** Answer "What have I deliberately skipped, and can I change my mind?" — a browsable, filterable list of all amnesty records with unforgive capability.

**User Situation:** Learner wants to audit their amnesty decisions, possibly restore items they previously skipped. May arrive from track settings (proactive audit), from Review Debt (seeing a skipped count), from Learning Journey (noticing a gap), or from a snackbar after an amnesty action.

**Success Criteria:** User can find any amnestied item within 5 seconds via grouping/filtering, and can unforgive an item in exactly 2 taps (matching amnesty gesture weight).

**Entry Points:**
- Track Settings panel -> "Skipped items" link
- Review Debt view -> "Skipped" section -> "See all" link
- Learning Journey view -> tap amnestied item -> detail -> "See all skipped"
- Undo snackbar -> "See all skipped" secondary action
- Cycle Boundary Welcome -> "Review previous cycle" (arrives pre-filtered to previous cycle)

**Exit Points:**
- Back arrow -> previous screen
- Tap item ref -> Learning detail screen (read-only context)
- Unforgive + undo snackbar -> item removed from list, remains on current screen

---

## Layout Structure

```
+-----------------------------------------+
| <- Skipped Items              [...]menu |
+-----------------------------------------+
| N items skipped                         |
| [This track v] [All] [This cycle]      |
| [Manual] [Bulk] [Triage]               |
+-----------------------------------------+
| Group by: [Unit]  [Source]              |
+-----------------------------------------+
|                                         |
| -- Berachos (4 skipped) --------------- |
|                                         |
| Daf 4b  . all stages . Apr 8           |
|   "missed-traveling" . manual           |
|                           [Unforgive]   |
| --------------------------------------- |
| Daf 11a . stage 2 only . Apr 8         |
|   triage . bulk                         |
|                           [Unforgive]   |
| --------------------------------------- |
| Daf 15b . all stages . Apr 10          |
|   manual                                |
|                           [Unforgive]   |
| --------------------------------------- |
| Daf 22a . stage 1 only . Apr 12        |
|   manual . "too advanced"              |
|                           [Unforgive]   |
|                                         |
| -- Shabbos (2 skipped) --------------- |
|                                         |
| Daf 3a  . all stages . Apr 9           |
|   cycle-boundary                        |
|                           [Unforgive]   |
| --------------------------------------- |
| Daf 7b  . stage 3 only . Apr 11        |
|   bulk                                  |
|                           [Unforgive]   |
|                                         |
| ======================================= |
| v Previous cycles (42 skipped)          |
| ======================================= |
|                                         |
|   [ ] Show revoked                      |
|                                         |
+-----------------------------------------+
```

**Scroll behavior:** Single scrollable `CustomScrollView` with `SliverAppBar` (pinned), filter chips in a `SliverPersistentHeader` (pinned), and `SliverList` for grouped content. Pull-to-refresh invalidates amnesty provider.

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `md` (16dp) |
| AppBar bottom padding | `sm` (8dp) |
| Filter chip row gap (between chips) | `sm` (8dp) |
| Filter chip row padding (vertical) | `sm` (8dp) top, `md` (16dp) bottom |
| Group header padding (vertical) | `md` (16dp) top, `sm` (8dp) bottom |
| Record row padding (vertical) | `sm-md` (12dp) |
| Record row internal gap (between lines) | `xs` (4dp) |
| Section divider padding | `md` (16dp) vertical |
| Cycle section padding | `lg` (24dp) top |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Size | Weight |
|---------|------|--------|
| AppBar title ("Skipped Items") | `titleLarge` (22sp) | normal |
| Summary count ("N items skipped") | `titleMedium` (16sp) | w500 |
| Filter chip label | `labelLarge` (14sp) | w500 |
| Group toggle label ("Group by:") | `labelMedium` (12sp) | normal |
| Group header ("Berachos (4 skipped)") | `titleSmall` (14sp) | w500 |
| Record line 1 (ref + stage + date) | `bodyMedium` (14sp) | w500 |
| Record line 2 (reason + source) | `bodySmall` (12sp) | normal |
| Unforgive button | `labelLarge` (14sp) | w500 |
| Cycle section header | `titleSmall` (14sp) | w500 |
| Cycle section description | `bodySmall` (12sp) | normal |
| Empty state title | `titleMedium` (16sp) | w500 |
| Empty state body | `bodyMedium` (14sp) | normal |

---

## Page Sections

### Section: App Bar

**OBJECT ID:** `amnesty-history-appbar`

| Property | Value |
|----------|-------|
| Type | `SliverAppBar`, pinned |
| Title | "Skipped Items" |
| Leading | Back arrow (auto from Navigator) |
| Trailing | Overflow menu (`[...]`) |

#### Overflow Menu

**OBJECT ID:** `amnesty-history-overflow`

| Property | Value |
|----------|-------|
| Item 1 | "Show revoked" (toggle) — includes revoked amnesty records in the list |
| Item 2 | "Unforgive all visible" — bulk action on current filtered set (confirmation required) |

---

### Section: Summary + Filters

**OBJECT ID:** `amnesty-history-filters`

| Property | Value |
|----------|-------|
| Layout | Pinned `SliverPersistentHeader` below AppBar |
| Background | `surface` color with elevation shadow when scrolled under |

#### Summary Count

**OBJECT ID:** `amnesty-history-count`

| Property | Value |
|----------|-------|
| Content | "{N} items skipped" — count of visible (filtered) active amnesty records |
| Style | `titleMedium`, w500 |
| Updates | Reactively when filters change |

#### Track Filter Chip

**OBJECT ID:** `amnesty-history-track-chip`

| Property | Value |
|----------|-------|
| Default | "{Track name}" (when opened from single-track entry point) |
| Dropdown options | List of all tracks with amnesty records + "All tracks" |
| Pattern | Same dropdown chip as Review Debt cross-track toggle |
| When "All tracks" | Group headers prefix unit name with track label |

#### Source Filter Chips

**OBJECT ID:** `amnesty-history-source-chips`

| Property | Value |
|----------|-------|
| Layout | Horizontally scrollable `SingleChildScrollView` row |
| Chips | `[All]` `[This cycle]` `[Manual]` `[Bulk]` `[Triage]` `[Cycle-boundary]` |
| Behavior | Single-select. "All" is default. Selecting a source chip deselects "All". Selecting "All" clears source filter. |
| "This cycle" | Only visible for program tracks. Filters to `cycle_number == current_cycle`. |
| Style | Material 3 `FilterChip`, selected state uses `primaryContainer` fill |

#### Group Toggle

**OBJECT ID:** `amnesty-history-group-toggle`

| Property | Value |
|----------|-------|
| Layout | Row: "Group by:" label + `SegmentedButton` with two segments |
| Options | `[Unit]` (default) / `[Source]` |
| Behavior | Toggles grouping of the list below. Persists for session, not saved. |

---

### Section: Amnesty Record List

**OBJECT ID:** `amnesty-history-list`

| Property | Value |
|----------|-------|
| Layout | `SliverList` inside `CustomScrollView` |
| Grouping (by unit) | Records grouped by masechta/sefer/unit. Group header shows unit name + count. Within each group, sorted by amnesty date descending (newest first). |
| Grouping (by source) | Records grouped by source type (manual, bulk, triage, cycle-boundary). Group header shows source label + count. Within each group, sorted by amnesty date descending. |
| Separator | 1dp `Divider` between records within a group |

#### Group Header

**OBJECT ID:** `amnesty-history-group-header`

| Property | Value |
|----------|-------|
| Layout | Row: group label (left) + count badge (right) |
| Label (unit mode) | Unit display name (e.g., "Berachos", "Perek 3") |
| Label (source mode) | Source display name (e.g., "Manual", "Bulk amnesty", "Triage", "Cycle boundary") |
| Count | "({N} skipped)" in `bodySmall`, `onSurfaceVariant` |
| Collapsible | Yes — tap to collapse/expand group. Default expanded. |
| Style | `titleSmall`, w500, `onSurface` color |
| Padding | `md` horizontal, `md` top, `sm` bottom |

#### Amnesty Record Row

**OBJECT ID:** `amnesty-history-record`

| Property | Value |
|----------|-------|
| Layout | Two-line content area + trailing unforgive button |
| Line 1 | "{itemRef} . {stageScope} . {amnestyDate}" |
| Line 1 detail — itemRef | Human-readable content reference (e.g., "Daf 4b") in `bodyMedium`, w500 |
| Line 1 detail — stageScope | "all stages" if whole-item amnesty, "stage {N} only" if stage-scoped. `bodyMedium`, normal weight, `onSurfaceVariant` |
| Line 1 detail — amnestyDate | Short date format (e.g., "Apr 8"). `bodyMedium`, normal weight, `onSurfaceVariant` |
| Line 2 | "{source}" + optional " . \"{reason}\"" |
| Line 2 detail — source | Source badge text: "manual" / "bulk" / "triage" / "cycle-boundary". `bodySmall`, `onSurfaceVariant` |
| Line 2 detail — reason | Quoted reason text when present (e.g., `"missed-traveling"`). `bodySmall`, `onSurfaceVariant`, italic |
| Trailing | `[Unforgive]` text button |
| Long-press | Enters multi-select mode (see Multi-Select below) |
| Tap row | No-op in default mode. In multi-select mode: toggles selection. |
| Revoked state | When "Show revoked" is on: revoked records show strikethrough on line 1, "Revoked {date}" replacing unforgive button, `onSurfaceVariant` color at 60% opacity |
| Cross-track mode | When track filter is "All tracks": prepend track label to line 1 (e.g., "Daf Yomi . Daf 4b . ...") |

#### Unforgive Button

**OBJECT ID:** `amnesty-history-unforgive-btn`

| Property | Value |
|----------|-------|
| Type | `TextButton` |
| Label | "Unforgive" |
| Color | `primary` |
| Touch target | 48dp minimum |
| Tap | Shows inline confirmation (see Unforgive Flow below) |

---

### Section: Inline Unforgive Confirmation

**OBJECT ID:** `amnesty-history-unforgive-confirm`

| Property | Value |
|----------|-------|
| Trigger | Tap `[Unforgive]` on any record row |
| Layout | Row replaces the unforgive button area: "{itemRef} back in queue?" `[Yes]` `[Cancel]` |
| Confirmation text | "Put {itemRef} back in your queue?" — `bodySmall` |
| Yes button | `FilledTonalButton`, `primary`, label "Yes" |
| Cancel button | `TextButton`, label "Cancel" |
| Tap Yes | Revoke amnesty (set `item_amnesty.revoked_at = now`), log to `track_action_log` with `action_type: "unforgive"`, remove row with animation, show snackbar |
| Tap Cancel | Restore unforgive button |
| Auto-dismiss | If user scrolls away or taps another row, cancel confirmation |

---

### Section: Multi-Select Mode

**OBJECT ID:** `amnesty-history-multiselect`

| Property | Value |
|----------|-------|
| Trigger | Long-press any record row |
| AppBar change | Title becomes "{N} selected", leading becomes close (X) to exit multi-select, trailing becomes "Select all" toggle |
| Row change | Leading checkbox appears on each row. Tap row toggles selection. |
| Bottom bar | Fixed bottom action bar: `FilledTonalButton` "Put {N} items back in queue" |
| Confirmation | Bottom sheet: "Unforgive {N} items? They will return to your active chazara queue." `[Confirm]` `[Cancel]` |
| On confirm | Batch revoke all selected, log each to `track_action_log`, exit multi-select, snackbar: "{N} items restored" `[Undo]` |
| Exit | Tap X in app bar, or tap outside selection, or back gesture |

---

### Section: Previous Cycles (Program Tracks Only)

**OBJECT ID:** `amnesty-history-prev-cycles`

| Property | Value |
|----------|-------|
| Visible | Only for program tracks with `cycle_number` data |
| Layout | `ExpansionTile` at the bottom of the list, below current-cycle records |
| Header | "Previous cycles ({N} skipped)" — `titleSmall`, w500 |
| Default state | Collapsed |
| Expanded content | Grouped by cycle (newest cycle first), each with header "Cycle {N} ({count} skipped)" and descriptive text: "These were skipped in Cycle {N}" |
| Records within | Same `AmnestyRecordRow` format, unforgive available |
| Pre-filtered entry | When arriving from Cycle Boundary Welcome, this section auto-expands and the relevant cycle is scrolled into view |

---

### Section: Show Revoked Toggle

**OBJECT ID:** `amnesty-history-revoked-toggle`

| Property | Value |
|----------|-------|
| Location | Overflow menu item (toggle) |
| Default | Off — revoked records hidden |
| When on | Revoked amnesty records appear inline in their original group position, styled with reduced opacity and strikethrough |
| Purpose | Audit trail — user can verify that a previously amnestied item was restored |

---

### Section: Empty State

**OBJECT ID:** `amnesty-history-empty`

| Property | Value |
|----------|-------|
| Visible | When no amnesty records exist for the current track/filter |
| Layout | Centered vertically in the scroll area |
| Icon | Outlined bookmark or skip-forward icon, 48dp, `onSurfaceVariant` at 40% opacity |
| Title | "No skipped items" — `titleMedium`, w500 |
| Body | "When you amnesty (skip) items during chazara, triage, or catch-up, they appear here. You can always unforgive them to put them back in your queue." — `bodyMedium`, `onSurfaceVariant`, center-aligned, max-width 280dp |

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Default** | 1+ active amnesty records | Full layout with grouped list | Filter, unforgive, multi-select |
| **Loading** | Initial data fetch | Shimmer placeholders: 3 group headers + 2 rows each | Pull-to-refresh |
| **Empty — no amnesty** | Zero amnesty records for track | Empty state with educational text | Back navigation only |
| **Empty — filtered** | Amnesty records exist but none match active filter | Inline message: "No items match this filter" with `[Clear filters]` button | Clear filters, change filter |
| **Multi-select** | Long-press activated | Checkboxes on rows, bottom action bar, modified app bar | Select/deselect, bulk unforgive, exit |
| **Previous-cycle focus** | Arrived from Cycle Boundary Welcome | Previous cycles section auto-expanded, "This cycle" chip not selected | Same as default |
| **Show revoked** | Toggle enabled via overflow menu | Revoked records visible inline with reduced styling | Toggle off to re-hide |
| **Error** | Provider error | Error banner with retry below app bar | Pull-to-refresh, retry |

---

## Data Sources

| Provider | Returns | Used By |
|----------|---------|---------|
| `amnestyRecordsProvider(trackId)` | `List<AmnestyRecord>` — all `item_amnesty` rows for track, joined with curriculum metadata for display labels | Record list, count, grouping |
| `amnestyRecordsAllTracksProvider` | `List<AmnestyRecord>` — cross-track query, includes `trackLabel` | Cross-track mode |
| `activeTracksProvider` | `List<Track>` — for track filter dropdown | Track filter chip |
| `currentCycleProvider(trackId)` | `int?` — current cycle number for program tracks | "This cycle" filter chip, cycle section headers |

### AmnestyRecord Model

| Field | Type | Source |
|-------|------|--------|
| `id` | `String` | `item_amnesty.id` |
| `trackId` | `String` | `item_amnesty.track_id` |
| `trackLabel` | `String` | Joined from `learning_track.label` |
| `sefariaRef` | `String` | `item_amnesty.sefaria_ref` |
| `displayRef` | `String` | Human-readable ref (e.g., "Daf 4b") from curriculum metadata |
| `unitLabel` | `String` | Parent unit display name (e.g., "Berachos") for grouping |
| `stageNumber` | `int?` | `item_amnesty.stage_number` (null = whole-item) |
| `amnestyDate` | `DateTime` | `item_amnesty.created_at` |
| `source` | `AmnestySource` | Enum: `manual`, `bulk`, `triage`, `cycleBoundary` |
| `reason` | `String?` | `item_amnesty.reason` (optional free text) |
| `cycleNumber` | `int?` | `item_amnesty.cycle_number` (program tracks only) |
| `revokedAt` | `DateTime?` | `item_amnesty.revoked_at` (null = active) |

---

## Animations

| Trigger | Animation | Duration |
|---------|-----------|----------|
| Record removed (unforgive) | `SizeTransition` collapse + `FadeTransition` out | 300ms |
| Record restored (undo) | `SizeTransition` expand + `FadeTransition` in | 300ms |
| Multi-select enter | Checkboxes slide in from left (`SlideTransition`) | 200ms |
| Multi-select exit | Checkboxes slide out left, bottom bar slides down | 200ms |
| Group collapse/expand | `AnimatedCrossFade` / `SizeTransition` | 250ms |
| Previous cycles expand | `ExpansionTile` default animation | 200ms |
| Filter chip selection | Material 3 default chip animation | 100ms |
| Snackbar | Slide up from bottom | Material default |

---

## Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Screen reader — record row | Semantics: "{displayRef}, {stageScope}, skipped {amnestyDate}, source {source}" + reason if present |
| Screen reader — unforgive button | Semantics: "Unforgive {displayRef}, put back in chazara queue" |
| Screen reader — multi-select | Announce "{N} items selected" on selection change |
| Screen reader — group header | Semantics: "{groupLabel}, {count} skipped items, collapsed/expanded" |
| Touch targets | All interactive elements minimum 48dp |
| Color contrast | Source labels and dates use `onSurfaceVariant` (meets 4.5:1 on `surface`) |
| Keyboard navigation | Tab order: filters -> group toggle -> records (top to bottom) -> previous cycles |
| Reduce motion | When `MediaQuery.disableAnimations`, skip row collapse/expand animations |

---

## Acceptance Criteria

- [ ] View displays all active `item_amnesty` records for the selected track
- [ ] Records are grouped by unit (default) with date sort within each group (newest first)
- [ ] Toggle switches grouping to by-source; groups show source label + count
- [ ] Track filter chip shows current track name with dropdown to other tracks and "All tracks"
- [ ] Source filter chips (`All`, `This cycle`, `Manual`, `Bulk`, `Triage`, `Cycle-boundary`) filter the list correctly
- [ ] "This cycle" chip only appears for program tracks
- [ ] Summary count updates reactively when filters change
- [ ] Tap `[Unforgive]` shows inline confirmation with item ref ("Put Daf 4b back in your queue?")
- [ ] Confirm unforgive sets `item_amnesty.revoked_at`, removes row with animation, shows snackbar with undo
- [ ] Undo within snackbar timeout restores the amnesty record and re-inserts the row
- [ ] All unforgive actions log to `track_action_log` with `action_type: "unforgive"`
- [ ] Long-press enters multi-select mode with checkboxes, modified app bar, and bottom action bar
- [ ] Multi-select "Put N items back in queue" shows confirmation bottom sheet before executing
- [ ] Previous cycles section appears collapsed at bottom for program tracks with `cycle_number` data
- [ ] Previous cycle header reads "These were skipped in Cycle {N}"
- [ ] Arriving from Cycle Boundary Welcome auto-expands previous cycles section
- [ ] "Show revoked" toggle in overflow menu reveals revoked records with strikethrough + reduced opacity
- [ ] Revoked records cannot be unforgiven (no action button)
- [ ] Empty state shows educational explanation of amnesty when no records exist
- [ ] Filtered-empty state shows "No items match this filter" with clear-filters button
- [ ] Loading state shows shimmer placeholders
- [ ] Pull-to-refresh invalidates amnesty provider
- [ ] All entry points navigate to this screen correctly (Track Settings, Review Debt, Learning Journey, snackbar, Cycle Boundary Welcome)
- [ ] Vocabulary uses "amnesty", "unforgive", "chazara" throughout (never "review")

---

## Design Decisions (Resolved)

| # | Decision | Resolution |
|---|----------|------------|
| 1 | Default grouping | **By unit** — matches how the learner thinks about their curriculum. Toggle to by-source available. |
| 2 | Cross-track mode | **Filter chip dropdown** — same pattern as Review Debt view. Default is single-track when opened from a track context. |
| 3 | Revoked amnesty visibility | **Hidden by default** — available under "Show revoked" toggle in overflow menu for audit purposes. Revoked records are read-only (no re-amnesty action). |
| 4 | Empty state | **Educational** — brief explanation of what amnesty is and where it can be used. Not a blank screen. |

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All states documented
- [x] Entry/exit points documented
- [x] Filter and grouping behavior specified
- [x] Unforgive flow (single + bulk) specified
- [x] Cycle-aware behavior specified
- [x] Accessibility requirements documented
- [x] Animations documented
- [x] Data sources and model defined
- [x] Design decisions resolved
- [x] Acceptance criteria complete

---

_Created using Whiteport Design Studio (WDS) methodology_
