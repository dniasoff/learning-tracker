> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

# 01 — Catch-up Sheet

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Catch-up & Amnesty (S2 / S3 / S4) |
| **Route** | N/A (modal bottom sheet — overlays current screen) |
| **Platform** | Mobile (Flutter) |
| **Page Type** | Modal bottom sheet (3 variants sharing one shell) |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated, shown when learner has active track debt |

---

## Overview

**Surface Purpose:** Resolve single-track recovery in one focused interaction. Adapts to debt severity and track mode so the learner always sees the right options framed positively.

**User Situation:** Learner is behind on one track. They tapped a recovery trigger (dashboard card, inline S1 prompt, triage card detail, or track detail screen). They need to understand their options and act — or dismiss without pressure.

**Success Criteria:**
- Mild recovery resolved in under 30 seconds
- Severe/program recovery resolved in under 60 seconds
- No behind-counter is ever the first thing shown
- Every action previews its outcome before confirmation
- Recovery action logged to `track_action_log` with source `"catchup_sheet"`
- Dashboard track card reflects the new state immediately after action

**Entry Points:**
- Dashboard track card recovery action area
- Inline S1 "Want to catch up?" prompt tap
- Triage sheet card "Details" action
- Track detail screen recovery section

**Exit Points:**
- Action confirmed -> SnackBar with undo -> sheet closes -> return to caller
- "Not now" / "Decide later" -> sheet closes, prompt suppressed 7 days
- Swipe-down or back gesture -> dismiss (same as "Not now")
- Archive confirmed -> sheet closes -> track removed from active list

---

## Variant Selection Logic

```dart
CatchupSheetVariant variant = track.programId != null
    ? CatchupSheetVariant.program        // S4
    : trackDebt.daysBehind >= 15 || trackDebt.daysDormant >= 14
        ? CatchupSheetVariant.severe     // S3
        : CatchupSheetVariant.mild;      // S2
```

| Variant | Track Mode | Condition | Sheet Height |
|---------|-----------|-----------|--------------|
| **Mild (S2)** | Self-paced | 4-14 days behind | Compact — content height, max 40% screen |
| **Severe (S3)** | Self-paced | 15+ days behind OR 14+ days dormant | Tall — content height, max 70% screen |
| **Program (S4)** | Program | 1+ missed items | Scrollable — content height, max 85% screen, draggable |

---

## Layout Structure

### Shared Shell

```
┌──────────────────────────────────────┐
│            ─── drag handle ───       │
│                                      │
│  ┌─ curriculum color bar (4dp) ────┐ │
│  │ HEADER (variant-specific)       │ │
│  └─────────────────────────────────┘ │
│                                      │
│  ┌─────────────────────────────────┐ │
│  │ BODY (variant-specific)         │ │
│  └─────────────────────────────────┘ │
│                                      │
│  ┌─────────────────────────────────┐ │
│  │ ACTIONS (variant-specific)      │ │
│  └─────────────────────────────────┘ │
│                                      │
└──────────────────────────────────────┘
```

### Variant: Mild (S2)

```
┌──────────────────────────────────────┐
│            ─── drag handle ───       │
│                                      │
│  ▌ Adjust your plan                  │
│  ▌ {trackLabel}                      │
│                                      │
│  {daysBehind} days behind your pace  │
│  Rescope to finish {newFinishDate}   │
│                                      │
│  ┌──────────────────────────────────┐│
│  │ [  Rescope                     ] ││
│  │ [  Catch up over...     ▸      ] ││
│  │ [  Not now                     ] ││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

### Variant: Severe (S3)

```
┌──────────────────────────────────────┐
│            ─── drag handle ───       │
│                                      │
│  ▌ Let's restart fresh               │
│  ▌ {trackLabel}                      │
│                                      │
│  You've learned {learnedCount} —     │
│  that's real.                        │
│                                      │
│  ┌──────────────────────────────────┐│
│  │ ○ Full reboot                   ││
│  │   Rescope + amnesty all overdue ││
│  │   chazara. Clean slate.         ││
│  ├──────────────────────────────────┤│
│  │ ○ Rescope + keep chazara        ││
│  │   Reset pace, keep chazara debt ││
│  │   visible in Review Debt.       ││
│  ├──────────────────────────────────┤│
│  │ ○ Rescope only                  ││
│  │   Reset pace, don't touch       ││
│  │   chazara.                      ││
│  ├──────────────────────────────────┤│
│  │ ○ Archive track                 ││
│  │   Stop tracking. Your Learning  ││
│  │   Journey is preserved.         ││
│  └──────────────────────────────────┘│
│                                      │
│        [  Confirm  ]                 │
│                                      │
│      Not now                         │
└──────────────────────────────────────┘
```

### Variant: Program (S4)

```
┌──────────────────────────────────────┐
│            ─── drag handle ───       │
│                                      │
│  ▌ Missing items                     │
│  ▌ {trackLabel} · {programName}      │
│                                      │
│  ┌──────────── scrollable ──────────┐│
│  │ ▾ This week (3 items)           ││
│  │   Item ref    [Learned][Amnesty]││
│  │   Item ref    [Learned][Amnesty]││
│  │   Item ref    [Learned][Amnesty]││
│  │ ▾ Last week (5 items)           ││
│  │   Item ref    [Learned][Amnesty]││
│  │   Item ref    [Learned][Amnesty]││
│  │   ...                           ││
│  │ ▸ 2+ weeks ago (12 items)       ││
│  └──────────────────────────────────┘│
│                                      │
│  ┌──────────────────────────────────┐│
│  │ [Amnesty all N] [Catch up all]  ││
│  │       [ Decide later ]          ││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

**Scroll behavior:** Program variant body scrolls independently; action bar is pinned at bottom. Mild and Severe variants do not scroll — content fits within sheet height.

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Sheet horizontal padding | `md` (16dp) |
| Drag handle top padding | `sm` (8dp) |
| Header top margin (below drag handle) | `md` (16dp) |
| Header to body gap | `md` (16dp) |
| Body to actions gap | `lg` (24dp) |
| Action button gap (vertical stack) | `sm` (8dp) |
| Action button gap (horizontal row, S4) | `sm` (8dp) |
| Section group gap (S4 date groups) | `md` (16dp) |
| Item row internal padding | `sm` (8dp) vertical, `md` (16dp) horizontal |
| Bottom safe area | `lg` (24dp) minimum + system inset |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Style | Size | Weight |
|---------|-------|------|--------|
| Sheet title ("Adjust your plan", etc.) | `titleLarge` | 22sp | normal |
| Track label | `titleSmall` | 14sp | w500 |
| Context line / positive stat | `bodyMedium` | 14sp | normal |
| Preview text (finish date, etc.) | `bodyMedium` | 14sp | normal, `onSurfaceVariant` |
| Action button label | `labelLarge` | 14sp | w500 |
| Action description (S3) | `bodySmall` | 12sp | normal, `onSurfaceVariant` |
| Date group header (S4) | `labelMedium` | 12sp | w500 |
| Item ref label (S4) | `bodyMedium` | 14sp | normal |
| "Not now" / "Decide later" | `labelMedium` | 12sp | normal, `primary` |

---

## Page Sections

### Section: Drag Handle

**OBJECT ID:** `catchup-sheet-handle`

| Property | Value |
|----------|-------|
| Widget | 32dp wide x 4dp tall rounded bar, `outlineVariant` color |
| Alignment | Center horizontal |
| Semantics | "Drag to dismiss" |

---

### Section: Header

**OBJECT ID:** `catchup-sheet-header`

| Property | Value |
|----------|-------|
| Layout | Column: title, track label. Curriculum color 4dp left bar spanning full header height. |
| Left bar | 4dp wide, curriculum color, rounded corners (2dp) |
| Padding left | `md` (16dp) to right of color bar |

#### Title Text

**OBJECT ID:** `catchup-sheet-header-title`

| Variant | Content |
|---------|---------|
| Mild (S2) | "Adjust your plan" |
| Severe (S3) | "Let's restart fresh" |
| Program (S4) | "Missing items" |

#### Track Label

**OBJECT ID:** `catchup-sheet-header-track`

| Property | Value |
|----------|-------|
| Content (S2, S3) | "{trackLabel}" |
| Content (S4) | "{trackLabel} -- {programName}" |
| Style | `titleSmall`, `onSurfaceVariant` |

---

### Section: Context Body

**OBJECT ID:** `catchup-sheet-body`

Content varies by variant.

#### Mild (S2) Body

**OBJECT ID:** `catchup-sheet-body-mild`

| Property | Value |
|----------|-------|
| Line 1 | "{daysBehind} days behind your pace" (`bodyMedium`) |
| Line 2 | "Rescope to finish {newFinishDate}" (`bodyMedium`, `onSurfaceVariant`) |
| Notes | `daysBehind` is stated factually, not as the leading element. Title "Adjust your plan" leads. |

#### Severe (S3) Body

**OBJECT ID:** `catchup-sheet-body-severe`

| Property | Value |
|----------|-------|
| Line 1 | "You've learned {learnedCount} {unitLabel} -- that's real." (`bodyMedium`) |
| Line 2 | None. No behind-counter. |
| Notes | Positive framing only. `learnedCount` from `TrackDebt.completedItems`. `unitLabel` is curriculum-appropriate (e.g., "dapim", "chapters", "items"). |

#### Program (S4) Body — Debt List

**OBJECT ID:** `catchup-sheet-body-program`

| Property | Value |
|----------|-------|
| Layout | Scrollable list of date-range groups |
| Max height | 85% screen minus header and actions |
| Group behavior | Expandable/collapsible sections |

##### Date Range Group

**OBJECT ID:** `catchup-sheet-debt-group`

| Property | Value |
|----------|-------|
| Layout | Expandable section: header row + item rows |
| Header | "{rangeName} ({count} items)" with expand/collapse chevron |
| Default state | "This week" and "Last week" expanded. "2+ weeks ago" collapsed. |
| Range buckets | "This week" (0-7 days), "Last week" (8-14 days), "2+ weeks ago" (15+ days) |
| Expand/collapse | Tap header row toggles. Animated height transition (200ms ease). |

##### Debt Item Row

**OBJECT ID:** `catchup-sheet-debt-item`

| Property | Value |
|----------|-------|
| Layout | Row: item ref label (leading), toggle group (trailing) |
| Ref label | Content reference from curriculum (e.g., "Bava Kamma 42a") |
| Style | `bodyMedium` for ref, curriculum color left accent (2dp) |
| Toggle group | `SegmentedButton` with two segments: "Learned" / "Amnesty" |
| Default state | Neither selected (neutral) |
| Learned selected | Filled `primary` background on Learned segment |
| Amnesty selected | Filled `tertiary` background on Amnesty segment |
| Deselect | Tap active segment to deselect (return to neutral) |
| Swipe | Swipe-left on row = quick amnesty (per Q19). Shows amnesty state immediately. |

---

### Section: Actions

**OBJECT ID:** `catchup-sheet-actions`

#### Mild (S2) Actions

**OBJECT ID:** `catchup-sheet-actions-mild`

| Property | Value |
|----------|-------|
| Layout | Vertical stack of action buttons |

| Button | Style | Label | Action |
|--------|-------|-------|--------|
| Rescope | `FilledButton` | "Rescope" | Calls `rescope()`. SnackBar "Pace reset" with undo. Sheet closes. |
| Catch up | `OutlinedButton` | "Catch up over..." | Expands inline `StretchGoalCalculator`. |
| Not now | `TextButton` | "Not now" | Sheet closes. Suppresses prompt for 7 days. |

#### Severe (S3) Actions

**OBJECT ID:** `catchup-sheet-actions-severe`

| Property | Value |
|----------|-------|
| Layout | Vertical radio-style list (single selection) + Confirm button below |
| Selection | `RadioListTile` style. One option selected at a time. None selected by default. |
| Confirm | `FilledButton` "Confirm" — disabled until an option is selected |

| Option | Description | Effect |
|--------|-------------|--------|
| Full reboot | "Rescope + amnesty all overdue chazara. Clean slate." | `rescope()` + `bulkAmnesty(reviewDebt)` |
| Rescope + keep chazara | "Reset pace, keep chazara debt visible in Review Debt." | `rescope()` only |
| Rescope only | "Reset pace, don't touch chazara." | `rescope()` only (identical write, different framing — chazara explicitly preserved) |
| Archive track | "Stop tracking. Your Learning Journey is preserved." | `archiveTrack()` |

| Post-action | Behavior |
|-------------|----------|
| After Rescope variants | Shows `PauseOfferPrompt` inline (replaces action list) |
| After Archive | SnackBar "Track archived" with undo. Sheet closes immediately (no pause offer). |
| Not now | `TextButton` below Confirm. Sheet closes. Suppresses prompt for 7 days. |

#### Program (S4) Actions

**OBJECT ID:** `catchup-sheet-actions-program`

| Property | Value |
|----------|-------|
| Layout | Pinned bar at bottom of sheet. Row of primary actions + secondary below. |

| Button | Style | Label | Condition | Action |
|--------|-------|-------|-----------|--------|
| Amnesty all | `OutlinedButton` | "Amnesty all {N}" | Always visible | Confirmation sheet: "Amnesty {N} items? They'll be hidden from your Learning Journey but never deleted." Confirm -> bulk amnesty -> SnackBar with single undo. |
| Catch up all | `FilledButton` | "Catch up all" | Always visible | Marks all missed items as learned. SnackBar with single undo. |
| Confirm selection | `FilledButton` | "Confirm ({selectedCount})" | Visible when 1+ items have Learned/Amnesty toggled | Applies per-item decisions. SnackBar summary: "{X} amnestied, {Y} marked learned" with single undo. |
| Decide later | `TextButton` | "Decide later" | Always visible | Sheet closes. Suppresses prompt for 7 days. |

**Button visibility logic:** When no individual items are toggled, show "Amnesty all" and "Catch up all" side by side. When 1+ items are toggled, replace both with "Confirm ({selectedCount})" `FilledButton`.

---

### Section: Stretch Goal Calculator

**OBJECT ID:** `catchup-sheet-stretch-calc`

| Property | Value |
|----------|-------|
| Parent | Mild (S2) variant, inline below "Catch up over..." button |
| Trigger | Tapping "Catch up over..." expands this section with animated reveal (250ms ease) |
| Layout | Row of preset chips + custom option, preview line below |

#### Presets

| Chip | Value | Label |
|------|-------|-------|
| 1 | 3 days | "3 days" |
| 2 | 7 days | "1 week" |
| 3 | 14 days | "2 weeks" |
| 4 | custom | "Custom..." |

| Property | Value |
|----------|-------|
| Chip style | `FilterChip`, single selection |
| Custom input | Tapping "Custom..." reveals a `Stepper` (min 1 day, max 90 days, step 1) |
| Preview | "Finish by {projectedDate} ({extraPerDay} extra/day)" (`bodySmall`, `onSurfaceVariant`) |
| Confirm | `FilledButton` "Set stretch goal" appears below preview |
| Effect | Sets stretch pace on track. SnackBar "Stretch goal set -- {N} extra/day". Sheet closes. |

---

### Section: Pause Offer Prompt

**OBJECT ID:** Referenced as `PauseOfferPrompt` (shared component, defined elsewhere)

| Property | Value |
|----------|-------|
| Context | Shown inline within the Severe (S3) sheet after a rescope action is confirmed |
| Framing | "Pause this track for a week while you get settled?" |
| Actions | [Yes, 7 days] `FilledTonalButton` / [No, start now] `TextButton` |
| Behavior | Replaces the action list in the sheet body. Sheet closes after choice. |

---

## States & Conditions

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Default (per variant)** | Sheet opened, no action taken | Full variant layout as designed | Select actions, toggle items |
| **Loading** | Computing debt / fetching items | Shimmer placeholders in body area. Header visible immediately. | Dismiss only |
| **Stretch calculator open** | Mild variant, "Catch up over..." tapped | Calculator section expanded inline below actions | Select preset, confirm |
| **Option selected (S3)** | Radio option tapped | Selected option highlighted. "Confirm" button enabled. | Confirm, change selection, dismiss |
| **Items toggled (S4)** | 1+ debt items have Learned/Amnesty set | Action bar switches from bulk buttons to "Confirm ({N})" | Confirm, toggle more, dismiss |
| **Pause offer (S3)** | After rescope confirmed | Action list replaced by `PauseOfferPrompt` | Accept pause, decline, dismiss |
| **Confirming bulk action** | "Amnesty all" or "Archive" tapped | Inline confirmation replaces action area: explanation + [Confirm] / [Cancel] | Confirm, cancel |
| **Processing** | Action submitted, awaiting write | Confirm button shows `CircularProgressIndicator`. Sheet not dismissible. | Wait |
| **Error** | Write failed | Inline error banner above actions: "Something went wrong. Try again?" with retry. Sheet stays open. | Retry, dismiss |

---

## Data Sources

### Reads

| Provider | Returns | Used by |
|----------|---------|---------|
| `trackDebtProvider(trackId)` | `TrackDebt` — `learningDebt`, `reviewDebt`, `daysBehind`, `daysDormant`, `completedItems`, `primaryScenario` | Variant selection, header stats, S2 context line |
| `trackProvider(trackId)` | `CurriculumTrack` — `programId`, `label`, `curriculumColor`, `goalType` | Header, color bar, variant selection |
| `programDebtProvider(trackId)` | `List<ProgramDebtItem>` — `ref`, `scheduledDate`, `status` | S4 debt list |
| `rescopePreviewProvider(trackId)` | `RescopePreview` — `newFinishDate`, `currentFinishDate` | S2 preview line |
| `stretchPreviewProvider(trackId, days)` | `StretchPreview` — `projectedDate`, `extraPerDay` | Stretch calculator preview |

### Writes

| Action | Service Call | Data Written |
|--------|-------------|--------------|
| Rescope | `recoveryService.rescope(trackId)` | Updates pace baseline on `curriculum_tracks` |
| Full reboot | `recoveryService.rescope(trackId)` + `recoveryService.bulkAmnesty(trackId, reviewDebt)` | Pace baseline + `item_amnesty` records for all overdue chazara |
| Archive | `trackService.archive(trackId)` | Sets `archived_at` on `curriculum_tracks` |
| Stretch goal | `recoveryService.setStretchGoal(trackId, days)` | Updates pace target on `curriculum_tracks` |
| Item amnesty (single) | `recoveryService.amnestyItem(trackId, itemRef)` | Single `item_amnesty` record |
| Item learned (single) | `recoveryService.markLearned(trackId, itemRef)` | Single `completion` record |
| Bulk amnesty (S4) | `recoveryService.bulkAmnesty(trackId, items)` | Batch `item_amnesty` records |
| Catch up all (S4) | `recoveryService.bulkMarkLearned(trackId, items)` | Batch `completion` records |
| Pause | Via `PauseOfferPrompt` — writes `paused_at` / `paused_until` on `curriculum_tracks` |
| All actions | `trackActionLogService.log(trackId, action, source: "catchup_sheet")` | `track_action_log` entry |

### Undo

| Scope | Behavior |
|-------|----------|
| Single item (S4 per-item) | Individual undo via SnackBar (5 sec). Reverts that one `item_amnesty` or `completion`. |
| Bulk action (S4 amnesty all / catch up all) | Single undo via SnackBar (5 sec). Reverts entire batch as one operation. |
| Rescope (S2, S3) | Single undo via SnackBar (5 sec). Restores previous pace baseline. |
| Archive (S3) | Single undo via SnackBar (5 sec). Restores track to active. |
| Stretch goal (S2) | Single undo via SnackBar (5 sec). Removes stretch target. |
| Confirm selection (S4 mixed) | Single undo for the full batch of per-item decisions. |

---

## Animations

| Trigger | Animation | Duration | Curve |
|---------|-----------|----------|-------|
| Sheet open | Slide up from bottom | 300ms | `Curves.easeOutCubic` |
| Sheet dismiss | Slide down | 250ms | `Curves.easeInCubic` |
| Stretch calculator expand | Height reveal + fade in | 250ms | `Curves.easeOut` |
| Stretch calculator collapse | Height collapse + fade out | 200ms | `Curves.easeIn` |
| Date group expand/collapse (S4) | Height reveal/collapse | 200ms | `Curves.easeOut` |
| Action list -> Pause offer (S3) | Cross-fade | 300ms | `Curves.easeInOut` |
| Action list -> Confirmation (S4 bulk) | Cross-fade | 200ms | `Curves.easeInOut` |
| Bulk buttons -> Confirm button (S4) | Cross-fade + size | 200ms | `Curves.easeOut` |
| Item swipe amnesty (S4) | Slide reveal amnesty background | 200ms | `Curves.easeOut` |
| Processing spinner | Infinite rotate on confirm button | — | Linear |

---

## Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Screen reader | Sheet announced as dialog: "Catch-up options for {trackLabel}" |
| Focus trap | Focus stays within sheet while open. First focus on title. |
| Dismiss | Back gesture or swipe-down dismisses. Also "Not now" / "Decide later" button always reachable. |
| Action descriptions (S3) | Radio options include description as `semanticsLabel`: e.g., "Full reboot. Rescope plus amnesty all overdue chazara. Clean slate." |
| Item toggles (S4) | Each toggle pair announced: "{ref}. Learned, not selected. Amnesty, not selected." State changes announced. |
| Swipe amnesty (S4) | `excludeSemantics` on swipe gesture. Toggle buttons are the accessible path. |
| Confirmation | Bulk actions announce confirmation prompt. "Amnesty {N} items? Confirm or cancel." |
| Motion reduced | When `MediaQuery.disableAnimations`, all transitions are instant (0ms). |
| Min touch targets | All buttons 48dp minimum. Debt item rows 48dp minimum height. |
| Color contrast | All text meets WCAG AA (4.5:1 body, 3:1 large). Toggle states distinguishable without color (icon change). |

---

## Acceptance Criteria

### General

- [ ] Sheet opens via `showModalBottomSheet` with correct variant based on `TrackDebt`
- [ ] Curriculum color bar renders with correct track color on all variants
- [ ] Sheet dismissible by swipe-down, back gesture, and explicit dismiss button
- [ ] Dismiss without action suppresses catch-up prompt for 7 days
- [ ] All actions log to `track_action_log` with `source: "catchup_sheet"`
- [ ] After any confirmed action, dashboard track card reflects new state on return
- [ ] SnackBar with undo (5 sec) appears after every confirmed action
- [ ] Processing state disables dismiss and shows spinner on confirm button
- [ ] Error state shows inline retry without closing sheet

### Mild (S2)

- [ ] Title reads "Adjust your plan" with track label below
- [ ] Context shows days behind and projected rescope finish date
- [ ] "Rescope" calls `rescope()` and closes with SnackBar
- [ ] "Catch up over..." expands `StretchGoalCalculator` inline
- [ ] Stretch calculator shows 4 presets (3 days, 1 week, 2 weeks, custom)
- [ ] Custom option reveals stepper (1-90 days)
- [ ] Stretch preview updates live: projected date + extra items per day
- [ ] "Set stretch goal" confirms and closes with SnackBar
- [ ] "Not now" closes sheet

### Severe (S3)

- [ ] Title reads "Let's restart fresh" with track label below
- [ ] Positive stat shown ("You've learned {N} -- that's real."). No behind-counter.
- [ ] Four radio options with descriptions rendered
- [ ] "Confirm" disabled until one option selected
- [ ] Full reboot calls `rescope()` + `bulkAmnesty()` for review debt
- [ ] Archive shows SnackBar "Track archived" with undo. No pause offer.
- [ ] After non-archive rescope actions, `PauseOfferPrompt` replaces action list
- [ ] Pause offer writes `paused_at` / `paused_until` if accepted
- [ ] "Not now" closes sheet

### Program (S4)

- [ ] Title reads "Missing items" with track + program label
- [ ] Debt items grouped by date range: "This week", "Last week", "2+ weeks ago"
- [ ] "This week" and "Last week" expanded by default. "2+ weeks ago" collapsed.
- [ ] Each item row has Learned/Amnesty segmented toggle, default neutral
- [ ] Swipe-left on item row sets amnesty state
- [ ] When no items toggled: "Amnesty all" and "Catch up all" visible
- [ ] When 1+ items toggled: buttons replaced by "Confirm ({N})"
- [ ] "Amnesty all" shows inline confirmation before executing
- [ ] Bulk amnesty produces single SnackBar with single undo
- [ ] Per-item confirm produces summary SnackBar ("{X} amnestied, {Y} marked learned") with single undo
- [ ] "Decide later" closes sheet

---

## Checklist

- [x] Surface purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined (3 variants)
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All states documented
- [x] Variant selection logic specified
- [x] Data sources and writes documented
- [x] Undo behavior specified per action type
- [x] Animations documented
- [x] Accessibility requirements specified
- [x] Acceptance criteria per variant
- [x] Open design decisions resolved

### Resolved Design Decisions

| # | Decision | Resolution |
|---|----------|------------|
| 1 | Sheet height | Adaptive per variant: mild max 40%, severe max 70%, program max 85% with drag-to-expand. `DraggableScrollableSheet` for program; fixed `showModalBottomSheet` with `isScrollControlled: true` for mild/severe. |
| 2 | Stretch goal calculator | Stepper with 4 presets (3 days / 1 week / 2 weeks / custom). Custom reveals a numeric stepper (1-90 days, step 1). Live preview of projected finish date and extra items per day. |
| 3 | Program debt list | Grouped by date range: "This week" (0-7d), "Last week" (8-14d), "2+ weeks ago" (15+d). Expandable sections. Recent groups expanded by default, oldest collapsed. |
| 4 | Undo scope | Single undo for all bulk operations (amnesty all, catch up all, confirm mixed selection). Individual undo only when a single-item action is performed in isolation (e.g., swipe amnesty). |

---

_Created using Whiteport Design Studio (WDS) methodology_
