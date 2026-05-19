> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

# 04 — Review Debt View

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Review Debt View |
| **Route** | `/track/{trackId}/review-debt` (single-track) / `/review-debt` (cross-track) |
| **Platform** | Mobile (Flutter) |
| **Page Type** | Full-screen pushed route |
| **Interaction** | Touch-first, swipe gestures |
| **Visibility** | Authenticated |

---

## Overview

**Page Purpose:** Let the learner browse overdue chazara, amnesty individual items or in bulk, and choose a recovery path that fits their situation — all by choice, never by nag.

**User Situation:** The learner has some amount of overdue chazara and has deliberately navigated here. They may have a handful of scattered missed reviews (Archipelago / S6) or a systemic backlog (Collapse / S7). The view adapts its framing and affordances to the severity.

**Success Criteria:**
- Learner can find and act on any specific overdue chazara in under 10 seconds (Archipelago)
- Collapse framing never leads with a number — leads with acknowledgement of learning strength
- Single-item amnesty is one swipe + snackbar undo
- Bulk amnesty shows a count confirmation before executing
- Amnestied items remain visible in the Skipped section with unforgive capability

**Entry Points:**
- Dashboard track card: tap chazara status badge
- Track detail screen: chazara section link
- Weekly chazara digest notification: deep link with `trackId`
- Learning Journey view: "N reviews overdue in this section" link (pre-filtered to unit)

**Exit Points:**
- Tap item row -> Learning screen (review launcher with `trackId` + `sefariaRef`)
- Back button / swipe-back -> previous screen
- "See all skipped" -> Amnesty History view

---

## Layout Structure

### Archipelago (S6: 1-15 overdue items)

```
┌──────────────────────────────────────┐
│ <- Chazara Debt          [This track ▼] │
├──────────────────────────────────────┤
│ 7 reviews waiting                    │
├──────────────────────────────────────┤
│ [Amnesty all]  [Schedule into rotation] │
├──────────────────────────────────────┤
│ ▼ Berachos (3 reviews)               │
│ ┌──────────────────────────────────┐ │
│ │ Daf 4b  · Stage 2 · 12 days ago │ │  <- swipe left to amnesty
│ │ Daf 11a · Stage 1 · 8 days ago  │ │
│ │ Daf 15b · Stage 3 · 5 days ago  │ │
│ └──────────────────────────────────┘ │
│ ▼ Shabbos (4 reviews)               │
│ ┌──────────────────────────────────┐ │
│ │ Daf 2a  · Stage 1 · 3 days ago  │ │
│ │ ...                              │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ ▶ Skipped (2 amnestied)             │
│   (collapsed by default)            │
└──────────────────────────────────────┘
```

### Collapse (S7: 15+ overdue items, declining review velocity)

```
┌──────────────────────────────────────┐
│ <- Chazara Debt          [This track ▼] │
├──────────────────────────────────────┤
│ Your learning is strong.             │
│ Chazara paused around Mar 12.        │
│ Reviews help retention — here are    │
│ some options.                        │
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │ Restart reviews from today       │ │
│ │ Amnesty old debt, fresh schedule │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ Small commitment                 │ │
│ │ 5 reviews this week              │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ Amnesty all chazara debt         │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ Disable chazara on this track    │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ ▶ 23 overdue items (tap to browse)  │
│   (collapsed by default)            │
├──────────────────────────────────────┤
│ ▶ Skipped (5 amnestied)             │
│   (collapsed by default)            │
└──────────────────────────────────────┘
```

**Scroll behavior:** Single scrollable `ListView` containing all sections. No pull-to-refresh (data is fetched on entry and updated reactively after actions).

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `md` (16dp) |
| App bar to summary text | `md` (16dp) |
| Summary text to action buttons | `lg` (24dp) |
| Action button gap | `sm` (8dp) |
| Action buttons to item list | `lg` (24dp) |
| Unit group gap | `md` (16dp) |
| Item row gap | `zero` (divided by 1dp separator) |
| Restart option card gap | `sm` (8dp) |
| Skipped section top margin | `lg` (24dp) |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Size | Weight |
|---------|------|--------|
| App bar title ("Chazara Debt") | `titleLarge` (22sp) | normal |
| Summary count ("7 reviews waiting") | `titleMedium` (16sp) | w500 |
| Collapse warm framing | `titleMedium` (16sp) | normal |
| Collapse sub-text | `bodyMedium` (14sp) | normal |
| Unit group header ("Berachos (3 reviews)") | `titleSmall` (14sp) | w500 |
| Item ref label ("Daf 4b") | `bodyMedium` (14sp) | w500 |
| Item stage + age ("Stage 2 . 12 days ago") | `bodySmall` (12sp) | normal |
| Action button text | `labelLarge` (14sp) | w500 |
| Restart option card title | `titleSmall` (14sp) | w500 |
| Restart option card subtitle | `bodySmall` (12sp) | normal |
| Skipped section header | `titleSmall` (14sp) | w500 |
| Filter chip label | `labelLarge` (14sp) | w500 |
| Empty state message | `titleMedium` (16sp) | normal |

---

## Page Sections

### Section: App Bar

**OBJECT ID:** `review-debt-appbar`

| Property | Value |
|----------|-------|
| Type | Material 3 `AppBar` with back button |
| Title | "Chazara Debt" |
| Leading | Back arrow (navigates to previous screen) |
| Actions | Filter chip (see Cross-Track Filter) |

---

### Section: Cross-Track Filter

**OBJECT ID:** `review-debt-filter`

| Property | Value |
|----------|-------|
| Component | Material 3 `FilterChip` in app bar actions area |
| Default | "This track" (single-track mode) |
| Options | "This track", "All tracks" |
| Behavior | Tap opens dropdown. Selecting "All tracks" regroups items by track, then by unit within each track. |
| Visible | Always (even if learner has only one track — chip is disabled with single track) |

---

### Section: Summary (Archipelago / S6)

**OBJECT ID:** `review-debt-summary-archipelago`

| Property | Value |
|----------|-------|
| Visible | When overdue count is 1-15 |
| Content | "{N} reviews waiting" |
| Style | `titleMedium`, w500 |
| Tone | Matter-of-fact |

---

### Section: Summary (Collapse / S7)

**OBJECT ID:** `review-debt-summary-collapse`

| Property | Value |
|----------|-------|
| Visible | When overdue count is 15+ AND review velocity is declining |
| Line 1 | "Your learning is strong." (`titleMedium`, normal) |
| Line 2 | "Chazara paused around {date}." (`bodyMedium`, `onSurfaceVariant`) |
| Line 3 | "Reviews help retention — here are some options." (`bodyMedium`, `onSurfaceVariant`) |
| Date format | Approximate date of last completed review — month + day (e.g., "Mar 12") |
| Tone | Warm, acknowledges learning before addressing debt |

---

### Section: Top Actions (Archipelago)

**OBJECT ID:** `review-debt-actions-archipelago`

| Property | Value |
|----------|-------|
| Layout | Horizontal row of outlined action buttons, wrapping if needed |
| Visible | Archipelago (S6) variant only |

#### Action: Amnesty All

**OBJECT ID:** `review-debt-action-amnesty-all`

| Property | Value |
|----------|-------|
| Component | Material 3 `OutlinedButton` |
| Label | "Amnesty all" |
| Behavior | Shows confirmation dialog: "Amnesty {N} overdue reviews? They'll move to the Skipped section." with [Cancel] [Amnesty] buttons. |
| Effect | Creates `item_amnesty` records for all overdue items (`source = "user_manual"`). Updates view reactively. Logs to `track_action_log`. |
| Snackbar | "Amnestied {N} reviews" with [Undo] (5s timeout) |

#### Action: Schedule Into Rotation

**OBJECT ID:** `review-debt-action-schedule`

| Property | Value |
|----------|-------|
| Component | Material 3 `OutlinedButton` |
| Label | "Schedule into rotation" |
| Behavior | Shows confirmation dialog: "Spread {N} reviews across your daily plan? Oldest items will be scheduled first, max 2 extra reviews per day." with [Cancel] [Schedule] buttons. |
| Algorithm | Oldest-first ordering. Inserts up to 2 extra review tasks per day into the daily plan. Remaining items queue for subsequent days. |
| Effect | Creates scheduler adjustment entries. Updates view reactively. Logs to `track_action_log`. |
| Snackbar | "Scheduled {N} reviews — {D} days to clear" |

---

### Section: Restart Options (Collapse / S7)

**OBJECT ID:** `review-debt-restart-options`

| Property | Value |
|----------|-------|
| Layout | Vertical stack of option cards |
| Visible | Collapse (S7) variant only |
| Position | Above the item list (prominent) |

#### Option: Restart Reviews From Today

**OBJECT ID:** `review-debt-restart-fresh`

| Property | Value |
|----------|-------|
| Component | Material 3 `Card` (filled tonal) |
| Title | "Restart reviews from today" |
| Subtitle | "Amnesty old debt, fresh schedule" |
| Behavior | Shows confirmation dialog: "Start chazara fresh from today? {N} overdue reviews will be amnestied." with [Cancel] [Restart] buttons. |
| Effect | Bulk amnesty all overdue items. Resets chazara schedule baseline to today. Logs to `track_action_log`. |
| Snackbar | "Chazara restarted — old reviews amnestied" with [Undo] (5s) |

#### Option: Small Commitment

**OBJECT ID:** `review-debt-restart-small`

| Property | Value |
|----------|-------|
| Component | Material 3 `Card` (outlined) |
| Title | "Small commitment" |
| Subtitle | "5 reviews this week" |
| Behavior | Shows confirmation dialog: "Schedule 5 oldest reviews across this week?" with [Cancel] [Schedule] buttons. |
| Effect | Picks 5 oldest overdue items, schedules 1/day across the next 5 days (oldest first). Remaining debt untouched. Logs to `track_action_log`. |
| Snackbar | "5 reviews scheduled this week" |

#### Option: Amnesty All Chazara Debt

**OBJECT ID:** `review-debt-restart-amnesty`

| Property | Value |
|----------|-------|
| Component | Material 3 `Card` (outlined) |
| Title | "Amnesty all chazara debt" |
| Subtitle | none |
| Behavior | Same as top-level "Amnesty all" action (see `review-debt-action-amnesty-all`) |

#### Option: Disable Chazara on This Track

**OBJECT ID:** `review-debt-restart-disable`

| Property | Value |
|----------|-------|
| Component | Material 3 `Card` (outlined) |
| Title | "Disable chazara on this track" |
| Subtitle | none |
| Behavior | Shows confirmation dialog: "Turn off chazara for {trackName}? You can re-enable it in track settings. Existing overdue reviews will be amnestied." with [Cancel] [Disable] buttons. |
| Effect | Sets track chazara config to disabled. Bulk amnesty all overdue items. Logs to `track_action_log`. |
| Snackbar | "Chazara disabled for {trackName}" with [Undo] (5s) |

---

### Section: Overdue Item List

**OBJECT ID:** `review-debt-item-list`

| Property | Value |
|----------|-------|
| Layout | Grouped by unit (masechta/perek/siman per `primary_unit_type`), each group expandable |
| Default expand state | Archipelago: all groups expanded. Collapse: all groups collapsed with a tap-to-browse prompt. |
| Cross-track grouping | When "All tracks" filter active: grouped by track first, then by unit within each track. Track group headers show track name + curriculum color left border. |

#### Unit Group Header

**OBJECT ID:** `review-debt-unit-group`

| Property | Value |
|----------|-------|
| Component | `ExpansionTile`-style header |
| Content | "{unitName} ({N} reviews)" |
| Style | `titleSmall`, w500 |
| Leading | Expand/collapse chevron |
| Tap | Toggle expand/collapse of the unit's item rows |

#### Item Row

**OBJECT ID:** `review-debt-item-row`

| Property | Value |
|----------|-------|
| Component | `Dismissible` widget (left-swipe only) |
| Layout | Single row: ref label, separator dot, stage label, separator dot, age |
| Line 1 | "{refLabel}" (`bodyMedium`, w500) |
| Line 2 | "Stage {N} . {age}" (`bodySmall`, `onSurfaceVariant`) |
| Left border | 4dp curriculum color (matches track) |
| Height | 56dp minimum (touch target) |

**Age display rules:**

| Condition | Format | Example |
|-----------|--------|---------|
| 0 days | "Today" | "Today" |
| 1 day | "Yesterday" | "Yesterday" |
| 2-30 days | Relative | "12 days ago" |
| 31+ days | Absolute date | "Mar 1" |

**Item Row interactions:**

| Gesture | Action |
|---------|--------|
| Tap | Navigate to Learning screen — launches review for this item (`trackId` + `sefariaRef` + `stageId`) |
| Swipe LEFT | Reveal red amnesty background with "Amnesty" label. On release past threshold: amnesty this stage. Snackbar: "Amnestied {refLabel} stage {N}" with [Undo] (5s). |
| Swipe RIGHT | No action (reserved — swipe has no effect) |
| Long-press | Enter multi-select mode (see Multi-Select below) |

**Swipe-to-amnesty details:**

| Property | Value |
|----------|-------|
| Direction | `DismissDirection.endToStart` (left-only) |
| Background color | `error` container color |
| Background icon | Amnesty icon + "Amnesty" text, right-aligned |
| Threshold | 40% of row width |
| Effect | Creates `item_amnesty` record (`source = "user_manual"`, stage-scoped). Item moves to Skipped section. Logs to `track_action_log`. |
| Undo | Snackbar with [Undo] (5s). Undo revokes the amnesty (`revoked_at` set). |

---

### Section: Multi-Select Mode

**OBJECT ID:** `review-debt-multiselect`

| Property | Value |
|----------|-------|
| Trigger | Long-press on any item row |
| Visual | Checkboxes appear on leading edge of all item rows. Selected rows get `secondaryContainer` background. |
| App bar changes | Title becomes "{N} selected". Actions become: [Amnesty selected] and [X] (exit multi-select). |
| Tap in multi-select | Toggles item selection (does NOT navigate) |
| "Amnesty selected" | Confirmation dialog: "Amnesty {N} selected reviews?" with [Cancel] [Amnesty]. Effect same as bulk amnesty. |
| Exit | Tap [X] in app bar, or back button, or after amnesty completes |

---

### Section: Skipped (Amnestied Items)

**OBJECT ID:** `review-debt-skipped`

| Property | Value |
|----------|-------|
| Layout | Collapsible section at bottom of the list |
| Header | "Skipped ({N} amnestied)" (`titleSmall`, w500) with expand/collapse chevron |
| Default state | Collapsed |
| Visible | When at least 1 amnestied item exists for this track (or across tracks in cross-track mode) |

#### Skipped Item Row

**OBJECT ID:** `review-debt-skipped-row`

| Property | Value |
|----------|-------|
| Layout | Row: ref label + stage, amnesty date, trailing [Unforgive] button |
| Line 1 | "{refLabel} . Stage {N}" (`bodyMedium`, `onSurfaceVariant`) |
| Line 2 | "Skipped {date}" (`bodySmall`, `onSurfaceVariant`) |
| Trailing | `TextButton` labeled "Unforgive" (`primary` color) |
| Unforgive action | Sets `revoked_at` on the amnesty record. Item reappears in the overdue list. Snackbar: "Restored {refLabel} stage {N}" with [Undo] (5s). Logs to `track_action_log`. |

#### See All Skipped Link

**OBJECT ID:** `review-debt-skipped-viewall`

| Property | Value |
|----------|-------|
| Visible | When amnestied item count > 10 (only first 10 shown inline) |
| Text | "See all skipped ->" |
| Style | `bodyMedium`, `primary` color |
| Action | Navigate to Amnesty History view |

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Archipelago (S6)** | 1-15 overdue items | Matter-of-fact summary + expanded item groups + top actions | Swipe, tap, multi-select, bulk amnesty, schedule |
| **Collapse (S7)** | 15+ overdue items AND declining review velocity | Warm framing + restart option cards + collapsed item groups | Restart options, expand to browse, same item gestures |
| **Loading** | Initial data fetch | Shimmer placeholders for summary, item list area | Back button |
| **Empty** | 0 overdue items, 0 amnestied items | Centered illustration + "All caught up on chazara!" message | Back button |
| **Empty with skipped** | 0 overdue items, 1+ amnestied items | "All caught up on chazara!" message + Skipped section visible below | Unforgive actions, back button |
| **Cross-track** | "All tracks" filter selected | Items grouped by track then by unit. Track group headers with curriculum color. | Same gestures. Restart options scoped to per-track within the list. |
| **Error** | Provider error | Error illustration + "Something went wrong" + [Retry] button | Retry, back button |

---

## Severity Detection Logic

```dart
ReviewDebtVariant variant = overdueCount == 0
    ? ReviewDebtVariant.empty
    : overdueCount <= 15
        ? ReviewDebtVariant.archipelago
        : reviewVelocityDeclining
            ? ReviewDebtVariant.collapse
            : ReviewDebtVariant.archipelago; // 15+ but velocity stable = still archipelago
```

**`reviewVelocityDeclining`**: True when the 14-day rolling average of completed reviews is less than 50% of the 14-day average from 30 days ago. This distinguishes "many items but still reviewing" from "stopped reviewing."

---

## Data Sources

| Provider / Source | Purpose |
|-------------------|---------|
| `trackReviewDebtProvider(trackId)` | Per-stage overdue list for a single track. Returns `List<OverdueReviewItem>` with `refLabel`, `stageId`, `overdueDate`, `unitName`. |
| `allTracksReviewDebtProvider` | Aggregated overdue list across all active tracks. Used when cross-track filter is active. |
| `reviewVelocityProvider(trackId)` | Rolling review completion rate. Used for S6/S7 severity detection. |
| `itemAmnestyProvider(trackId)` | List of amnestied items (where `revoked_at IS NULL`). Feeds the Skipped section. |
| `trackConfigProvider(trackId)` | Track metadata including `primary_unit_type` (for grouping), track name, curriculum color. |
| `track_action_log` | Write target for all user actions on this screen. |

---

## Animations

| Trigger | Animation | Duration |
|---------|-----------|----------|
| Swipe-to-amnesty complete | Row slides out left, rows below collapse up | 300ms ease-out |
| Undo amnesty (from snackbar) | Row fades in at original position, rows shift down | 300ms ease-in |
| Unforgive action | Item fades out of Skipped, fades into overdue list at correct position | 300ms ease-in-out |
| Unit group expand/collapse | Standard `ExpansionTile` height animation | 200ms ease-in-out |
| Multi-select enter | Checkboxes slide in from left edge | 200ms ease-out |
| Multi-select exit | Checkboxes slide out to left, selection highlights fade | 200ms ease-in |
| Restart action (S7) | Restart cards fade out, view transitions to empty or archipelago state | 400ms ease-out |
| Empty state appear | Illustration + text fade in | 300ms ease-in |
| Filter chip switch | Cross-fade between single-track and all-tracks grouping | 200ms |

---

## Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Swipe-to-amnesty alternative | Each item row has a semantic action "Amnesty" accessible via TalkBack custom actions menu (three-finger swipe or context menu). |
| Screen reader for item rows | Announced as: "{refLabel}, Stage {N}, {age}, overdue chazara. Swipe left to amnesty, double tap to review." |
| Screen reader for skipped rows | Announced as: "{refLabel}, Stage {N}, skipped on {date}. Double tap Unforgive to restore." |
| Multi-select mode | Announced: "Multi-select mode. {N} of {total} selected. Double tap items to select or deselect." |
| Touch targets | All interactive elements minimum 48dp (56dp in child mode) |
| Collapse warm framing | Entire framing block is a single semantics node with full text read aloud |
| Confirmation dialogs | Focus trapped within dialog. Buttons labeled clearly. |
| Color contrast | All text meets WCAG 2.1 AA. Swipe background uses `onError` text on `error` container. |
| Reduced motion | When `MediaQuery.disableAnimations` is true, all animations complete instantly (0ms). |

---

## Design Decisions (Resolved)

| # | Decision | Resolution |
|---|----------|------------|
| 1 | Swipe direction | Left-only for amnesty. Swipe right is reserved (no action). "Do now" is a tap action, not a swipe. |
| 2 | Age display | Relative for 0-30 days ("12 days ago", "Yesterday", "Today"). Absolute for 31+ days ("Mar 1"). |
| 3 | Schedule algorithm | Oldest-first ordering, capped at 2 extra review tasks per day added to the daily plan. |
| 4 | Cross-track toggle | Filter chip in the app bar actions area. Default: single track. |
| 5 | Empty state | "All caught up on chazara!" with illustration. Only reachable if learner navigates here explicitly. |

---

## Acceptance Criteria

- [ ] View opens from dashboard chazara badge with correct `trackId`
- [ ] View opens from track detail chazara link
- [ ] View opens from weekly digest notification deep link
- [ ] Archipelago variant shows when overdue count is 1-15
- [ ] Collapse variant shows when overdue count is 15+ with declining velocity
- [ ] Archipelago displays matter-of-fact summary: "{N} reviews waiting"
- [ ] Collapse displays warm framing with approximate date of last review
- [ ] Items grouped by unit (masechta/perek/siman per `primary_unit_type`)
- [ ] Each item row shows ref label, stage number, and age
- [ ] Age displays as relative for 0-30 days, absolute for 31+ days
- [ ] Swipe left on item row amnesty that stage with snackbar + undo
- [ ] Swipe right on item row does nothing
- [ ] Tap item row navigates to learning screen for review
- [ ] Long-press enters multi-select mode with checkboxes
- [ ] Multi-select allows bulk amnesty of selected items with confirmation dialog
- [ ] "Amnesty all" shows confirmation dialog with count, then amnesty all items
- [ ] "Schedule into rotation" shows confirmation, schedules oldest-first at 2/day cap
- [ ] Collapse variant shows all four restart option cards above item list
- [ ] "Restart reviews from today" bulk amnesty + resets chazara schedule
- [ ] "Small commitment" schedules 5 oldest reviews across 5 days
- [ ] "Disable chazara on this track" disables chazara config + bulk amnesty
- [ ] Skipped section shows amnestied items, collapsed by default
- [ ] "Unforgive" on skipped item restores it to overdue list with snackbar + undo
- [ ] "See all skipped" link appears when amnestied count > 10
- [ ] Filter chip toggles between "This track" and "All tracks"
- [ ] Cross-track mode groups items by track, then by unit within track
- [ ] Empty state shows "All caught up on chazara!" with illustration
- [ ] All actions write to `track_action_log`
- [ ] All amnesty operations create `item_amnesty` records with `source = "user_manual"`
- [ ] All undo operations set `revoked_at` on the amnesty record
- [ ] Swipe-to-amnesty has accessible alternative via TalkBack custom action
- [ ] All touch targets meet 48dp minimum (56dp child mode)
- [ ] Confirmation dialogs appear before all destructive bulk operations

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined (both variants)
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All states documented
- [x] Gesture vocabulary specified (swipe, tap, long-press)
- [x] Multi-select mode specified
- [x] Severity detection logic defined
- [x] Cross-track mode specified
- [x] Data sources listed
- [x] Animations documented
- [x] Accessibility requirements defined
- [x] Design decisions resolved
- [x] Acceptance criteria complete

---

_Created using Whiteport Design Studio (WDS) methodology_
