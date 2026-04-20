# 02 — Triage Sheet

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Multi-Track Recovery Triage |
| **Route** | `/triage` (full-screen modal route, pushed over dashboard) |
| **Platform** | Mobile (Flutter / Android) |
| **Page Type** | Full-screen modal route (not a bottom sheet) |
| **Interaction** | Touch-first, horizontal swipe between cards |
| **Visibility** | Authenticated |
| **Trigger** | Auto on app open when triage conditions met; manual from dashboard banner |
| **Target Duration** | 90 seconds for a 4-track user |

---

## Overview

**Page Purpose:** Walk a multi-track learner through every out-of-sync track in a bounded, guided sequence, collecting one quick decision per track.

**User Situation:** The learner is behind on 3+ tracks (S11 Multi-Track Overload) or returning after 14+ days of dormancy (S9 Returning Learner). The dashboard feels overwhelming; the triage sheet replaces that overwhelm with a structured one-at-a-time workflow.

**Success Criteria:** Learner resolves or defers every track in the sequence within 90 seconds and lands on a summary confirming what happened.

**Entry Points:**
- Auto-trigger on app open when `count(tracks where primaryState != "normal") >= 3` or `sessionIsFirstAfterGap(> 14 days)` (S9)
- Manual tap on `TriageBanner` card at top of dashboard
- Routed from Returning Learner onboarding welcome-back screen

**Exit Points:**
- Summary screen "Done" button -> Dashboard (refreshed)
- "Pause triage" -> Dashboard with resume banner persisted
- System back / swipe-down dismiss -> "Pause triage" confirmation dialog
- "Details" on a card -> `CatchupSheet` (modal bottom sheet, returns to triage on close)

---

## Design Decisions (Resolved)

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| 1 | Card navigation model | **Horizontal `PageView` swipe** | Enforces one-at-a-time focus; matches the "quick decision per track" mental model; consistent with onboarding page pattern |
| 2 | Triage session persistence | **Lightweight local storage** (`triage_session` table or shared prefs JSON) | Triage is precious state the learner should not have to redo after app kill or background eviction |
| 3 | "Skip for now" semantics | **Deferred, re-evaluated on next session** | Skipping is not a decision, just a deferral; track reappears in triage only if triage conditions still hold next session |
| 4 | Bulk action placement | **Available from start via top-bar icon**, visually deemphasized (icon button, not prominent CTA) | Power users can reach it immediately; new users focus on per-card flow |
| 5 | Notification suppression | **Session-scoped**; "triage awaits" nudge fires once daily max while triage is pending | Per-track notifications suppressed while triage is pending; suppression cleared when triage completes or conditions no longer met |

---

## Layout Structure

### Card Sequence View (pages 1..N)

```
┌──────────────────────────────────────┐
│ TOP BAR                              │
│ [← Pause triage]   [Bulk ⚡]        │
├──────────────────────────────────────┤
│                                      │
│  PROGRESS INDICATOR                  │
│  "Track 2 of 4"                      │
│  ○ ● ○ ○                            │
│                                      │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │  TRIAGE TRACK CARD             │  │
│  │                                │  │
│  │  {trackLabel}                  │  │
│  │  {curriculum color chip}       │  │
│  │  {mode label: program /        │  │
│  │   self-paced / dormant}        │  │
│  │                                │  │
│  │  {DEBT SUMMARY}                │  │
│  │  "5 dapim behind" /            │  │
│  │  "6 days behind your pace" /   │  │
│  │  "Inactive 72 days"            │  │
│  │                                │  │
│  │  ───────────────────────────── │  │
│  │                                │  │
│  │  {PRIMARY ACTIONS — 2 buttons} │  │
│  │  [Action A]    [Action B]      │  │
│  │                                │  │
│  │  ───────────────────────────── │  │
│  │                                │  │
│  │  {SECONDARY ROW}               │  │
│  │  [Details...]  [Skip for now]  │  │
│  │                                │  │
│  └────────────────────────────────┘  │
│                                      │
│  ← swipe left/right →               │
│                                      │
└──────────────────────────────────────┘
```

### Summary Screen (after last card)

```
┌──────────────────────────────────────┐
│ TOP BAR                              │
│              Triage Complete          │
├──────────────────────────────────────┤
│                                      │
│  ✓  "3 tracks handled"              │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Daf Yomi Bavli — Amnesty all  │  │
│  │ School Gemara  — Paused 7d    │  │
│  │ Mishna Berurah — Rescoped     │  │
│  │ Nach Yomi      — Skipped      │  │
│  └────────────────────────────────┘  │
│                                      │
│  [Undo last]            [Done]       │
│                                      │
└──────────────────────────────────────┘
```

**Navigation model:** `PageView` with `PageController`. Swiping right advances only after an action is taken on the current card (or user taps "Skip for now"). Swiping left goes back to review a previous decision. After the last card, the PageView transitions to the summary screen.

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `md` (16dp) |
| Top bar height | 56dp |
| Progress indicator top margin | `md` (16dp) |
| Progress indicator bottom margin | `lg` (24dp) |
| Card internal padding | `lg` (24dp) |
| Card border radius | 16dp |
| Action button gap (horizontal) | `sm` (8dp) |
| Action button height | 48dp (adult) / 56dp (child) |
| Secondary row top margin | `md` (16dp) |
| Summary item gap | `sm` (8dp) |
| Summary bottom button row padding | `lg` (24dp) |

---

## Typography

| Element | Style | Size | Weight |
|---------|-------|------|--------|
| Top bar title | `titleMedium` | 16sp | w500 |
| Progress text ("Track 2 of 4") | `bodyMedium` | 14sp | normal |
| Track label | `titleLarge` | 22sp | w500 |
| Mode chip label | `labelSmall` | 11sp | w500 |
| Debt summary | `bodyLarge` | 16sp | normal |
| Primary action button | `labelLarge` | 14sp | w500 |
| Secondary text button | `bodyMedium` | 14sp | normal |
| Summary header | `headlineSmall` | 24sp | w500 |
| Summary track label | `bodyMedium` | 14sp | w500 |
| Summary action label | `bodyMedium` | 14sp | normal |

---

## Page Sections

### Section: Top Bar

**OBJECT ID:** `triage-topbar`

| Property | Value |
|----------|-------|
| Purpose | Navigation controls + bulk action entry |
| Layout | Row: leading back action, trailing bulk action icon |
| Background | `surface` |
| Elevation | 0 (flat, no shadow) |

#### Pause Triage Button

**OBJECT ID:** `triage-topbar-pause`

| Property | Value |
|----------|-------|
| Content | `←` icon + "Pause triage" label |
| Style | `TextButton`, `onSurface` color |
| Action | Save session state to local storage, pop route, show resume banner on dashboard |

#### Bulk Action Button

**OBJECT ID:** `triage-topbar-bulk`

| Property | Value |
|----------|-------|
| Content | Lightning bolt icon (⚡) |
| Style | `IconButton`, `onSurfaceVariant` color, 48dp touch target |
| Action | Opens `BulkActionPanel` as modal bottom sheet |
| Badge | Dot badge visible when 2+ self-paced or 2+ program tracks are in sequence |

---

### Section: Progress Indicator

**OBJECT ID:** `triage-progress`

| Property | Value |
|----------|-------|
| Purpose | Show position in sequence + completion state |
| Layout | Column: text label + dot row |
| Text | "Track {current} of {total}" (`bodyMedium`) |
| Dots | One per track. States: `completed` (filled primary), `current` (filled primary + ring), `pending` (outlined), `removed` (absent — track was paused/dropped) |
| Dynamic count | Total adjusts when a track is paused mid-triage (e.g., "Track 2 of 3" after one paused) |

---

### Section: Triage Track Card

**OBJECT ID:** `triage-track-card`

| Property | Value |
|----------|-------|
| Purpose | Present one track's debt + mode-adaptive actions |
| Component | Material 3 `Card` (filled) |
| Left border | 6dp, curriculum color |
| Padding | `lg` (24dp) all sides |
| Corner radius | 16dp |
| Max width | 400dp (centered on wider screens) |
| Vertical centering | Card centered vertically in available space between progress and bottom edge |

#### Track Header

**OBJECT ID:** `triage-track-card-header`

| Property | Value |
|----------|-------|
| Track label | `titleLarge`, w500 |
| Mode chip | `Chip` with label: "Program" / "Self-paced" / "Dormant". Curriculum color background, `onPrimary` text |
| Layout | Column: track label, then mode chip below with `xs` (4dp) gap |

#### Debt Summary

**OBJECT ID:** `triage-track-card-debt`

| Property | Value |
|----------|-------|
| Purpose | One-line human-readable debt context |
| Style | `bodyLarge`, `onSurfaceVariant` color |
| Top margin | `md` (16dp) |

**Content by mode:**

| Track Mode | Debt Text |
|------------|-----------|
| Program | "{N} {unit} behind" (e.g., "5 dapim behind") |
| Self-paced with goal | "{N} days behind your pace" |
| Dormant (60+ days inactive) | "Inactive {N} days" |

#### Primary Actions

**OBJECT ID:** `triage-track-card-primary-actions`

| Property | Value |
|----------|-------|
| Layout | Row of 2 buttons, equal width, `sm` (8dp) gap |
| Button style | `FilledButton` for first action, `FilledTonalButton` for second |
| Top margin | `lg` (24dp) |

**Actions by track mode:**

| Track Mode | Button A (FilledButton) | Button B (FilledTonalButton) |
|------------|------------------------|------------------------------|
| Program | "Amnesty all {N}" | "Catch up" |
| Self-paced with goal | "Rescope" | "Push harder" |
| Dormant / ghosted (60+ days) | "Revive" | "Archive" |

**Button behaviors:**

| Action | Behavior |
|--------|----------|
| Amnesty all {N} | Bulk inserts `item_amnesty` for all overdue items. Brief inline confirmation ("Amnestied {N} items"). Logs to `track_action_log` with source `"triage"`. Auto-advances to next card after 800ms. |
| Catch up | Opens `CatchupSheet` for this track (modal bottom sheet). On return, card reflects decision if one was made; if dismissed, card stays current. |
| Rescope | Calls `rescope()` on track. Inline confirmation ("Pace reset to today"). Logs with source `"triage"`. Auto-advances after 800ms. |
| Push harder | Opens `CatchupSheet` with stretch-goal calculator pre-selected. On return, card reflects decision. |
| Revive | Reactivates track (sets `primaryState` back to "normal", resets velocity baseline). Inline confirmation. Logs with source `"triage"`. Auto-advances after 800ms. |
| Archive | Confirmation dialog: "Archive {trackLabel}? You can restore it later." On confirm: sets track to archived state. Logs with source `"triage"`. Card removed from sequence, count adjusts. |

#### Secondary Row

**OBJECT ID:** `triage-track-card-secondary`

| Property | Value |
|----------|-------|
| Layout | Row: "Details..." left-aligned, "Skip for now" right-aligned |
| Button style | `TextButton`, `primary` color for Details, `onSurfaceVariant` for Skip |
| Top margin | `md` (16dp) |
| Divider | 1dp `outlineVariant` divider above this row |

| Action | Behavior |
|--------|----------|
| Details... | Opens `CatchupSheet` for this track (same as "Catch up" / "Push harder" drill-down) |
| Skip for now | Marks track as `skipped` in triage session. Does not modify track state. Logs `skip` to `track_action_log` with source `"triage"`. Advances to next card. |

#### Pause Track (contextual)

**OBJECT ID:** `triage-track-card-pause`

| Property | Value |
|----------|-------|
| Visibility | Shown as a third option replacing "Skip for now" when the learner long-presses the card or when debt is severe (program track 10+ items behind, or self-paced 30+ days behind) |
| Label | "Pause track" |
| Style | `TextButton`, `onSurfaceVariant` color |
| Action | Opens `PausePicker` (duration selection). On confirm: sets `paused_at` / `paused_until` on track. Track drops from triage sequence immediately. Progress count adjusts. Logs with source `"triage"`. |

---

### Section: Bulk Action Panel

**OBJECT ID:** `triage-bulk-panel`

| Property | Value |
|----------|-------|
| Purpose | Batch operations with per-track confirmation |
| Component | Modal bottom sheet |
| Trigger | Tap bulk action icon in top bar |

#### Bulk Action Options

| Action | Visible When | Description |
|--------|-------------|-------------|
| "Reset pace on all self-paced" | 2+ self-paced tracks in triage | Calls `rescope()` on confirmed tracks |
| "Amnesty all chazara debt > 60 days" | Any track with chazara items overdue 60+ days | Bulk `item_amnesty` insert for qualifying items on confirmed tracks |

#### Confirmation Chips

**OBJECT ID:** `triage-bulk-chips`

| Property | Value |
|----------|-------|
| Layout | Horizontal wrap of `FilterChip` widgets, one per affected track |
| Default state | All selected (checked) |
| Chip label | Track label |
| Chip color | Curriculum color when selected, `surfaceVariant` when deselected |
| Interaction | Tap to toggle inclusion/exclusion |

#### Bulk Panel Buttons

| Button | Style | Action |
|--------|-------|--------|
| Apply | `FilledButton` | Execute action on all selected tracks. Log each to `track_action_log` with source `"triage"`. Close panel. Update affected cards in sequence (mark as handled). |
| Cancel | `TextButton` | Close panel, no changes |

---

### Section: Summary Screen

**OBJECT ID:** `triage-summary`

| Property | Value |
|----------|-------|
| Purpose | Recap all actions taken during triage |
| Trigger | Automatically shown after last track card is handled or skipped |
| Layout | Vertically centered content with action list and bottom buttons |

#### Summary Header

**OBJECT ID:** `triage-summary-header`

| Property | Value |
|----------|-------|
| Text | "Triage complete" |
| Style | `headlineSmall`, w500, centered |
| Subtitle | "{N} tracks handled" (`bodyLarge`, `onSurfaceVariant`, centered) |
| Icon | Checkmark circle, `primary` color, 48dp, above header text |

#### Action Log List

**OBJECT ID:** `triage-summary-log`

| Property | Value |
|----------|-------|
| Layout | `ListView` of action rows, one per track in triage |
| Top margin | `lg` (24dp) |
| Item layout | Row: curriculum color dot (8dp), track label (`bodyMedium` w500), action label (`bodyMedium`, `onSurfaceVariant`) |
| Item gap | `sm` (8dp) |

**Action labels by resolution:**

| Resolution | Label |
|------------|-------|
| Amnesty | "Amnestied {N} items" |
| Rescope | "Pace reset" |
| Push harder | "Stretch goal set" |
| Revive | "Revived" |
| Archive | "Archived" |
| Paused | "Paused {N} days" |
| Skipped | "Skipped" (muted color) |
| Via CatchupSheet | Label from CatchupSheet decision |

#### Summary Buttons

**OBJECT ID:** `triage-summary-buttons`

| Property | Value |
|----------|-------|
| Layout | Row: "Undo last" left, "Done" right |
| "Undo last" | `OutlinedButton`. Reverts the most recent action, returns to that card. Disabled if no undoable actions remain. |
| "Done" | `FilledButton`. Pops triage route, returns to dashboard. Dashboard providers invalidated on return. |
| Bottom padding | `lg` (24dp) + safe area inset |

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Active — card sequence** | Default during triage | Card sequence with progress indicator | Swipe, tap actions, bulk |
| **Loading** | Computing triage queue (sorting tracks, fetching debt) | Centered circular progress indicator over blurred dashboard | None — resolves in < 500ms |
| **Resuming** | Saved triage session exists from prior app session | Resume banner: "Resume triage? {N} tracks remaining" with [Resume] / [Start fresh] | Resume restores position; Start fresh re-evaluates all tracks |
| **Single card** | Only 1 track remains after others were paused/dropped | Same layout, progress shows "Track 1 of 1". No swipe affordance. | Same actions |
| **All skipped** | Learner skipped every track | Summary screen with all items showing "Skipped" | "Done" returns to dashboard |
| **Empty — conditions cleared** | Resuming but debt conditions no longer met | "All caught up!" message with [Done] button | Returns to dashboard |
| **Interrupted — CatchupSheet open** | "Details" or "Catch up" was tapped | Triage sheet remains in stack below CatchupSheet | CatchupSheet close returns focus to current card |

---

## States & Conditions

### Triage Trigger Conditions

```dart
bool shouldTriggerTriage() {
  final debtTracks = activeTracks.where((t) => t.primaryState != 'normal');
  final isDormant = lastSessionDate != null &&
      DateTime.now().difference(lastSessionDate!).inDays >= 14;
  return debtTracks.length >= 3 || isDormant;
}
```

### Track Ordering

```
1. Program tracks, sorted by debt ascending (smallest debt first)
2. Self-paced tracks with goal, sorted by debt ascending
3. Dormant tracks (60+ days inactive), sorted by last-active ascending
```

### Card Advancement Rules

| Trigger | Behavior |
|---------|----------|
| Primary action completed | Auto-advance after 800ms (inline confirmation visible) |
| "Skip for now" tapped | Immediate advance |
| CatchupSheet closed with decision | Auto-advance after 800ms |
| CatchupSheet dismissed without decision | Stay on current card |
| Track paused via PausePicker | Card removed, sequence reindexed, next card shown |
| Track archived | Card removed, sequence reindexed, next card shown |
| Last card resolved | Transition to summary screen |

### Swipe Constraints

| Direction | Allowed When | Behavior |
|-----------|-------------|----------|
| Swipe left (advance) | Current card has been acted on (action taken or skipped) | Advance to next card |
| Swipe left (advance) | Current card has NOT been acted on | Bounce-back with haptic feedback; card stays |
| Swipe right (back) | Not on first card | Return to previous card (read-only review; action already taken) |

---

## Data Sources

| Provider / Query | Purpose | Invalidation |
|------------------|---------|-------------|
| `activeTracksProvider` | List of all active (non-archived) tracks | On triage complete |
| `trackDebtProvider(trackId)` | Debt count + unit for a single track | After action on that track |
| `triageSessionProvider` | Current triage session state (position, decisions, skips) | On every action; persisted to local storage |
| `trackActionLogProvider` | Write target for all triage actions | Append-only during triage |

### Triage Session Schema (local persistence)

```dart
class TriageSession {
  final String id;               // UUID
  final DateTime startedAt;
  final List<TriageTrackEntry> tracks;  // ordered queue
  final int currentIndex;
  final bool isComplete;
}

class TriageTrackEntry {
  final String trackId;
  final String trackLabel;
  final String mode;             // 'program' | 'self_paced' | 'dormant'
  final int debtAmount;
  final String? resolution;      // null = pending, 'amnesty', 'rescope', etc.
  final String? resolutionLabel; // human-readable for summary
  final bool skipped;
  final bool removed;            // paused or archived mid-triage
}
```

### Writes

| Action | Table | Fields |
|--------|-------|--------|
| Amnesty | `item_amnesty` (bulk insert) | `trackId`, `itemRef`, `amnestyDate`, `source: "triage"` |
| Rescope | `tracks` (update) | `velocityBaselineDate = now`, recalculate pace fields |
| Pause | `tracks` (update) | `paused_at`, `paused_until` |
| Archive | `tracks` (update) | `archived_at` |
| Revive | `tracks` (update) | `primaryState = "normal"`, `velocityBaselineDate = now` |
| All actions | `track_action_log` (insert) | `trackId`, `action`, `source: "triage"`, `timestamp`, `details` |

---

## Animations

| Animation | Spec | Trigger |
|-----------|------|---------|
| Card entrance (first load) | Fade-in + scale from 0.95 to 1.0, 300ms, `easeOutCubic` | Triage route opens |
| Card advance | `PageView` physics swipe, 350ms `easeInOutCubic` | Action completed or skip |
| Card bounce-back | Spring physics, 200ms | Swipe attempted on unresolved card |
| Inline confirmation | Action buttons fade out, confirmation text fades in, 200ms | Action button tapped |
| Auto-advance delay | 800ms hold on confirmation state, then page transition | After inline confirmation |
| Track removal (pause/archive) | Card scales to 0.9 + fades out, 250ms. Remaining cards reindex. | Track paused or archived |
| Summary entrance | Fade-in + slide-up from 24dp, 400ms, `easeOutCubic` | Last card resolved |
| Bulk panel | Standard bottom sheet slide-up | Bulk icon tapped |
| Progress dot removal | Dot shrinks to 0 + gap closes, 200ms | Track removed from sequence |

---

## Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Screen reader | Each card announced as "Track {N} of {M}: {trackLabel}, {mode}, {debtSummary}" |
| Action buttons | `semanticsLabel` on each: "Amnesty all {N} items for {trackLabel}", "Rescope {trackLabel}", etc. |
| Skip for now | `semanticsLabel`: "Skip {trackLabel} for now, will re-evaluate next session" |
| Swipe navigation | `PageView` has `Semantics(label: "Swipe left for next track, right for previous")` |
| Keyboard nav (external keyboard) | Left/right arrow keys map to page navigation; Enter activates focused button |
| Progress indicator | `Semantics(label: "Track {current} of {total}")`, live region so updates are announced |
| Bulk chips | Each chip: `semanticsLabel: "Include {trackLabel} in bulk action"` with checked/unchecked state |
| Summary | Action log list uses `MergeSemantics` per row: "{trackLabel}: {actionLabel}" |
| Motion reduction | When `MediaQuery.disableAnimations`, skip all transitions; use instant page jumps |
| Touch targets | Minimum 48dp adult / 56dp child on all interactive elements |
| Color contrast | All text meets WCAG 2.1 AA (4.5:1 body, 3:1 large text) against card surface |

---

## Notification Suppression

| Rule | Detail |
|------|--------|
| Scope | While triage is pending (conditions met but triage not completed), all per-track recovery notifications are suppressed |
| Replacement | A single "Triage awaits" push notification, max once per day |
| Clearing | Suppression clears when triage completes (summary "Done" tapped) or when triage conditions no longer hold |
| Persistence | Suppression flag is session-scoped (evaluated on app open), not persisted across days — the daily nudge is a separate scheduled notification |

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Triage auto-triggers when 3+ tracks have `primaryState != "normal"` on app open | Unit test: mock 3 tracks in debt, assert triage route pushed |
| 2 | Triage auto-triggers on first session after 14+ day dormancy gap | Unit test: mock `lastSessionDate` 15 days ago, assert trigger |
| 3 | Tracks ordered: program smallest-debt-first, then self-paced smallest-debt-first, then dormant | Unit test: provide mixed tracks, assert ordering |
| 4 | Program cards show [Amnesty all {N}] [Catch up] [Details] [Skip for now] | Widget test: render program track card, verify buttons |
| 5 | Self-paced cards show [Rescope] [Push harder] [Details] [Skip for now] | Widget test: render self-paced card, verify buttons |
| 6 | Dormant cards show [Revive] [Archive] [Details] [Skip for now] | Widget test: render dormant card, verify buttons |
| 7 | "Skip for now" is always visible and functional on every card | Widget test: every card variant has skip button |
| 8 | Swiping forward is blocked until card is resolved or skipped | Widget test: attempt swipe on unresolved card, assert bounce-back |
| 9 | Pausing a track via PausePicker removes card from sequence and adjusts count | Integration test: pause track 2 of 4, assert "Track 2 of 3" |
| 10 | Archiving a track removes card from sequence and adjusts count | Integration test: archive track, verify removal |
| 11 | "Details" opens CatchupSheet for the correct track | Widget test: tap Details, verify CatchupSheet route with trackId |
| 12 | Bulk "Reset pace on all self-paced" shows confirmation chips per track | Widget test: open bulk panel, verify chip count matches self-paced tracks |
| 13 | Bulk action only executes on confirmed (selected) chips | Unit test: deselect one chip, verify that track excluded from rescope |
| 14 | Summary screen lists every track with correct action label | Integration test: complete 4-track triage, verify summary entries |
| 15 | "Undo last" on summary reverts most recent action and returns to that card | Integration test: undo, verify track state rolled back and card shown |
| 16 | Interrupted triage persists to local storage and resumes on next app open | Integration test: kill app mid-triage, reopen, verify resume prompt at correct position |
| 17 | All actions write to `track_action_log` with source `"triage"` | Unit test: perform action, query log, verify source field |
| 18 | 4-track triage completes in <= 90 seconds (all amnesty/rescope, no drill-down) | Manual QA timing test with stopwatch |
| 19 | Per-track notifications suppressed while triage pending; single daily nudge fires | Integration test: verify notification channel suppression and nudge scheduling |
| 20 | Dashboard providers invalidated and debt counts refresh after triage completion | Integration test: complete triage, verify dashboard state updated |

---

## Open Questions

| # | Question | Context | Status |
|---|----------|---------|--------|
| 1 | Severe-debt threshold for showing "Pause track" inline vs only in long-press | Spec says 10+ program / 30+ self-paced, but needs UX validation | 🟡 In Discussion |
| 2 | Should "Push harder" open CatchupSheet or show an inline stretch calculator? | Current spec routes to CatchupSheet; inline would be faster for the 90s target | 🟡 In Discussion |

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined (ASCII art)
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All card variants documented (program, self-paced, dormant)
- [x] All states documented
- [x] Design decisions resolved
- [x] Data sources and writes specified
- [x] Animations listed
- [x] Accessibility requirements defined
- [x] Acceptance criteria enumerable and testable
- [x] Bulk action flow specified with per-track confirmation
- [x] Notification suppression rules documented
- [x] Session persistence schema defined

---

_Created using Whiteport Design Studio (WDS) methodology_
