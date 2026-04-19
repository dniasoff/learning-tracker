# 03 — Pause Control

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Pause Control |
| **Surfaces** | PausePicker (modal bottom sheet) + PauseResumeCard (dashboard card) + Paused track overlay |
| **Platform** | Mobile (Flutter / Android) |
| **Page Type** | Modal bottom sheet + inline dashboard card |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |
| **Scenario doc** | `../scenarios/03-pause-control.md` |

---

## Overview

**Surface Purpose:** Pause is the only silence mechanism in the app. It allows a learner to deliberately silence a track for a chosen duration, freezing notifications and pace clock while preserving all learning state. Two surfaces: a PausePicker bottom sheet for setting pause duration, and a PauseResumeCard for returning from pause.

**User Situation:** Learner is overwhelmed, going on vacation, observing a holiday, or simply needs a break from one or more tracks. They want to stop notifications and pace pressure without losing progress or archiving.

**Success Criteria:**
- Pause is reachable from every recovery flow in max 2 taps
- Duration selection completes in 1 tap (presets) or 2 taps (custom/indefinite)
- Paused track produces zero notifications
- Paused track excluded from triage
- Pace clock frozen during pause (`daysBehind` does not increase)
- Welcome-back card appears on first app open after pause expiry
- Undo available for 5 seconds after pausing

**Entry Points (PausePicker):**
- Catch-up Sheet (follow-up after recovery action)
- Triage Sheet (per-track `[Pause track]` action)
- Track Detail screen (header/settings area)
- Track Settings panel
- Notification action (7-day default only, no picker)

**Exit Points:**
- PausePicker: confirm -> snackbar + sheet closes -> returns to caller
- PauseResumeCard: Resume -> Learning/Catch-up, Extend -> PausePicker, Archive -> confirmation dialog

---

## Design Decisions (Resolved)

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| 1 | Paused track position on dashboard | **Keep in place, muted** | Moving tracks creates confusion about track order. Learner expects their list to be stable. |
| 2 | Custom duration input | **Date picker** | Learner thinks "resume after Pesach" not "pause for 12 days." Calendar mental model matches real-world intent. |
| 3 | Resume card persistence | **Persistent until acted on; dismissible with "Not now"** | Learner must make an explicit decision. "Not now" hides the card until next app session. |
| 4 | Pause from notification | **Yes, 7-day default duration only** | Reduces friction for the most common case. Full picker not practical from notification context. |

---

## Surface 1: PausePicker

### Layout Structure

```
┌──────────────────────────────────────┐
│ ─── drag handle ───                  │
│                                      │
│  Pause {trackLabel}                  │
│  No notifications. Pace clock stops. │
│  Your learning is safe.              │
│                                      │
│  [1 day] [3 days] [1 week] [2 weeks]│
│  [Custom...]       [Indefinite]      │
│                                      │
└──────────────────────────────────────┘
```

**Sheet type:** Material 3 modal bottom sheet with drag handle. Compact — no scroll needed.

### Spacing

| Property | Token |
|----------|-------|
| Sheet padding (horizontal) | `lg` (24dp) |
| Sheet padding (vertical) | `lg` (24dp) |
| Drag handle to title | `md` (16dp) |
| Title to explanation | `xs` (4dp) |
| Explanation to chip row | `lg` (24dp) |
| Chip row gap (horizontal) | `sm` (8dp) |
| Chip row gap (vertical) | `sm` (8dp) |
| Bottom safe area | System inset + `md` (16dp) |

### Components

#### Drag Handle

**OBJECT ID:** `pause-picker-handle`

| Property | Value |
|----------|-------|
| Component | Material 3 drag handle |
| Width | 32dp |
| Height | 4dp |
| Color | `onSurfaceVariant` at 40% opacity |
| Alignment | Center horizontal |

#### Title

**OBJECT ID:** `pause-picker-title`

| Property | Value |
|----------|-------|
| Content | "Pause {trackLabel}" |
| Style | `titleMedium` (16sp), w500 |
| Color | `onSurface` |

#### Explanation

**OBJECT ID:** `pause-picker-explanation`

| Property | Value |
|----------|-------|
| Content | "No notifications. Pace clock stops. Your learning is safe." |
| Style | `bodyMedium` (14sp), normal weight |
| Color | `onSurfaceVariant` |
| Max lines | 2 |

#### Duration Preset Chips

**OBJECT ID:** `pause-picker-presets`

| Property | Value |
|----------|-------|
| Layout | `Wrap` widget, two rows |
| Row 1 | [1 day] [3 days] [1 week] [2 weeks] |
| Row 2 | [Custom...] [Indefinite] |
| Component | Material 3 `FilterChip` (uncheckmarked) or `ActionChip` |
| Chip height | 36dp (adult) / 44dp (child) |
| Chip padding | `sm` (8dp) horizontal internal |
| Touch target | 48dp (adult) / 56dp (child) |

##### Preset Chip

**OBJECT ID:** `pause-picker-chip-preset`

| Property | Value |
|----------|-------|
| Variants | "1 day", "3 days", "1 week", "2 weeks" |
| Style | `labelLarge` (14sp) |
| Color | `secondaryContainer` background, `onSecondaryContainer` text |
| Action | Single tap confirms pause with computed `paused_until` |
| Feedback | Chip briefly fills `primary` on tap -> sheet closes -> undo snackbar |

##### Custom Chip

**OBJECT ID:** `pause-picker-chip-custom`

| Property | Value |
|----------|-------|
| Label | "Custom..." |
| Style | `labelLarge` (14sp) |
| Color | `surfaceContainerHighest` background, `onSurface` text |
| Leading icon | `Icons.calendar_today` (18dp) |
| Action | Opens Material 3 date picker |

**Date Picker Constraints:**

| Property | Value |
|----------|-------|
| First selectable date | Tomorrow |
| Last selectable date | Today + 365 days |
| Initial date | Today + 7 days |
| Confirmation | Date picker "OK" confirms pause with selected date as `paused_until` |
| Cancellation | Date picker "Cancel" returns to PausePicker (sheet stays open) |

##### Indefinite Chip

**OBJECT ID:** `pause-picker-chip-indefinite`

| Property | Value |
|----------|-------|
| Label | "Indefinite" |
| Style | `labelLarge` (14sp) |
| Color | `surfaceContainerHighest` background, `onSurface` text |
| Action | Tap shows inline confirmation: chip transforms to "Pause indefinitely?" with [Confirm] button |
| Rationale | Extra confirmation prevents accidental indefinite pause |

### PausePicker States

| State | When | Appearance |
|-------|------|------------|
| **Default** | Sheet opens | All chips enabled, no selection |
| **Custom date picking** | "Custom..." tapped | Material date picker overlays the sheet |
| **Indefinite confirming** | "Indefinite" tapped | Chip row replaced with inline confirmation row |
| **Processing** | Confirm tapped, write in flight | Chips disabled, subtle circular progress on selected chip |

### PausePicker Behavior

| Event | Action |
|-------|--------|
| Tap preset chip | Write pause state -> close sheet -> show undo snackbar |
| Tap "Custom..." | Open date picker. On OK: write pause state -> close sheet -> show undo snackbar. On Cancel: return to default state. |
| Tap "Indefinite" | Show inline confirmation. On "Confirm": write pause state -> close sheet -> show undo snackbar. On dismiss: return to default state. |
| Swipe down / tap scrim | Close sheet, no action taken |
| Back gesture | Close sheet, no action taken |

### Undo Snackbar

**OBJECT ID:** `pause-undo-snackbar`

| Property | Value |
|----------|-------|
| Duration | 5 seconds |
| Text (fixed) | "Paused for {duration}. Resumes {date}." (e.g., "Paused for 1 week. Resumes Apr 20.") |
| Text (indefinite) | "Paused indefinitely." |
| Action | "Undo" button |
| Undo behavior | Reverts `paused_at` and `paused_until` to null, removes `track_action_log` entry |
| Position | Bottom, above bottom nav |
| Style | Material 3 `SnackBar` with action |

---

## Surface 2: PauseResumeCard

### Layout Structure

```
┌──────────────────────────────────────┐
│  ▶  {trackLabel} is ready            │
│                                      │
│  "Welcome back. Ready to continue?"  │
│                                      │
│  [Resume]  [Extend pause]  [Archive] │
│                                 [x]  │
└──────────────────────────────────────┘
```

### Spacing

| Property | Token |
|----------|-------|
| Card padding | `md` (16dp) all sides |
| Card margin (horizontal) | `md` (16dp) |
| Title to body text | `xs` (4dp) |
| Body text to action row | `md` (16dp) |
| Action button gap | `sm` (8dp) |
| Corner radius | 12dp (adult) / 16dp (child) |

### Position on Dashboard

| Property | Value |
|----------|-------|
| Location | Inserted above "Your Tracks" section, below "Today's Learning" |
| Multiple tracks | One card per expired-pause track, stacked vertically with `md` (16dp) gap |
| Order | Most recently expired first |

### Components

#### Card Container

**OBJECT ID:** `pause-resume-card`

| Property | Value |
|----------|-------|
| Component | Material 3 `Card` (filled variant) |
| Background | `primaryContainer` |
| Left border | 4dp, curriculum color of the track |
| Elevation | 0 (filled card, no shadow) |

#### Title Row

**OBJECT ID:** `pause-resume-card-title`

| Property | Value |
|----------|-------|
| Leading icon | `Icons.play_circle_outline` (24dp), `onPrimaryContainer` color |
| Text | "{trackLabel} is ready" |
| Style | `titleMedium` (16sp), w500 |
| Color | `onPrimaryContainer` |

#### Dismiss Button

**OBJECT ID:** `pause-resume-card-dismiss`

| Property | Value |
|----------|-------|
| Icon | `Icons.close` (20dp) |
| Position | Top-right corner of card |
| Touch target | 48dp |
| Color | `onPrimaryContainer` at 60% opacity |
| Action | Hides card for current session. Card re-shows on next app open. |
| Semantics | "Dismiss, will show again next time" |

#### Body Text

**OBJECT ID:** `pause-resume-card-body`

| Property | Value |
|----------|-------|
| Content | "Welcome back. Ready to continue?" |
| Style | `bodyMedium` (14sp), normal weight |
| Color | `onPrimaryContainer` at 80% opacity |
| Tone | Supportive + action-oriented per NQ3 |

#### Action Row

**OBJECT ID:** `pause-resume-card-actions`

| Property | Value |
|----------|-------|
| Layout | `Row`, start-aligned, wrapping if needed |

##### Resume Button

**OBJECT ID:** `pause-resume-card-action-resume`

| Property | Value |
|----------|-------|
| Component | Material 3 `FilledButton` |
| Label | "Resume" |
| Color | `primary` background, `onPrimary` text |
| Touch target | 48dp height (adult) / 56dp (child) |
| Action | Clear pause state -> if debt accumulated: route to Catch-up Sheet; otherwise: track returns to active dashboard state |

##### Extend Pause Button

**OBJECT ID:** `pause-resume-card-action-extend`

| Property | Value |
|----------|-------|
| Component | Material 3 `OutlinedButton` |
| Label | "Extend pause" |
| Color | `onPrimaryContainer` outline and text |
| Touch target | 48dp height (adult) / 56dp (child) |
| Action | Opens PausePicker for this track (pre-populated with track context) |

##### Archive Button

**OBJECT ID:** `pause-resume-card-action-archive`

| Property | Value |
|----------|-------|
| Component | Material 3 `TextButton` |
| Label | "Archive" |
| Color | `onPrimaryContainer` at 60% opacity |
| Touch target | 48dp height (adult) / 56dp (child) |
| Action | Opens confirmation dialog: "Archive {trackLabel}? You can restore it later from Settings." On confirm: archive track. |

### PauseResumeCard States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Default** | Pause expired, card visible | Full card as designed | Resume, Extend, Archive, Dismiss |
| **Dismissed** | "Not now" / dismiss tapped | Card hidden | Re-shows on next app session |
| **Processing** | Resume/Archive tapped, write in flight | Tapped button shows loading indicator, other buttons disabled | Wait |
| **Debt detected** | Resume tapped, track has accumulated debt | Card transitions out, Catch-up Sheet opens | Catch-up flow |

---

## Surface 3: Dashboard Paused Track State

### Paused Track Overlay

**OBJECT ID:** `dashboard-track-card-paused`

| Property | Value |
|----------|-------|
| Applied to | Any track card on dashboard where `paused_at != null` |
| Position | Track stays in its natural list position (not moved to bottom) |
| Opacity | Card content at 60% opacity |
| Color overlay | None (opacity-only treatment to keep curriculum colors visible but muted) |
| Interaction | Tap still navigates to Track Detail screen |
| "Continue" button | Hidden while paused |

### Pause Badge

**OBJECT ID:** `dashboard-track-card-pause-badge`

| Property | Value |
|----------|-------|
| Position | Replaces status line in the track card |
| Text (fixed duration) | "Paused until {date}" (e.g., "Paused until Apr 20") |
| Text (indefinite) | "Paused (indefinite)" |
| Style | `bodyMedium` (14sp), w500 |
| Color | `onSurfaceVariant` |
| Leading icon | `Icons.pause_circle_outline` (16dp), same color |

### Paused Card Behavior

| Event | Action |
|-------|--------|
| Tap card body | Navigate to Track Detail (where Resume is available) |
| Tap pause badge | Navigate to Track Detail |
| Long press | No special action |

---

## Data Sources

| Provider / Source | Purpose | Notes |
|-------------------|---------|-------|
| `trackPauseStateProvider(trackId)` | Reads `paused_at`, `paused_until` from `curriculum_tracks` | Reactive — UI updates on write |
| `expiredPauseTracksProvider` | Filters tracks where `paused_until != null && paused_until <= now` | Drives PauseResumeCard visibility |
| `activeTracksProvider` | Existing — must exclude paused tracks from task generation | Paused tracks still appear in list but generate zero tasks |
| `trackActionLogProvider` | Writes pause/resume entries | Audit trail |
| `trackDebtProvider(trackId)` | Checks accumulated debt on resume | Routes to Catch-up Sheet if debt exists |

### Data Writes

| Action | Fields Written | Table |
|--------|---------------|-------|
| Pause (fixed) | `paused_at = now`, `paused_until = computed date` | `curriculum_tracks` |
| Pause (indefinite) | `paused_at = now`, `paused_until = null` | `curriculum_tracks` |
| Resume | `paused_at = null`, `paused_until = null` | `curriculum_tracks` |
| Undo pause | `paused_at = null`, `paused_until = null` | `curriculum_tracks` |
| All actions | `action_type`, `track_id`, `timestamp`, `metadata` | `track_action_log` |

---

## Animations

| Animation | Trigger | Spec |
|-----------|---------|------|
| Sheet entrance | PausePicker opens | Material 3 bottom sheet spring animation (default) |
| Sheet exit | Confirm / dismiss | Material 3 bottom sheet dismiss (default) |
| Chip tap feedback | Preset chip tapped | Chip fills `primary` color, 150ms ease-in, then sheet closes |
| Snackbar entrance | After sheet closes | Slide up from bottom, 200ms, Material default |
| Snackbar exit | After 5s or undo | Fade out, 150ms |
| Resume card entrance | App open with expired pause | Fade in + slide down, 300ms, `easeOutCubic` |
| Resume card exit | Action taken | Fade out + collapse height, 250ms, `easeInCubic` |
| Track muting | Pause confirmed | Opacity animates from 1.0 to 0.6, 300ms, `easeInOut` |
| Track unmuting | Resume confirmed | Opacity animates from 0.6 to 1.0, 300ms, `easeInOut` |

---

## Accessibility

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: PausePicker | Sheet announced as "Pause {trackLabel}. Choose duration." Chips labeled with full duration text. |
| Screen reader: Presets | Each chip: "Pause for {duration}" (e.g., "Pause for 1 week") |
| Screen reader: Indefinite | "Pause indefinitely. Requires confirmation." |
| Screen reader: Resume card | "Welcome back card for {trackLabel}. Actions available: Resume, Extend pause, Archive, Dismiss." |
| Screen reader: Dismiss | "Dismiss. Card will show again next time you open the app." |
| Screen reader: Pause badge | "{trackLabel}, paused until {date}" or "{trackLabel}, paused indefinitely" |
| Touch targets | All interactive elements minimum 48dp (adult) / 56dp (child) |
| Focus order (PausePicker) | Title -> explanation -> chips left-to-right, top-to-bottom |
| Focus order (ResumeCard) | Title -> body -> Resume -> Extend pause -> Archive -> Dismiss |
| Reduce motion | Skip chip fill animation, use instant opacity changes for muting |
| Color contrast | All text meets WCAG AA (4.5:1 body, 3:1 large text) on container colors |

---

## Acceptance Criteria

### PausePicker

- [ ] PausePicker opens as modal bottom sheet from all 4 entry points (Catch-up Sheet, Triage Sheet, Track Detail, Track Settings)
- [ ] Title displays correct track name
- [ ] Explanation text is always visible: "No notifications. Pace clock stops. Your learning is safe."
- [ ] Tapping a preset chip (1 day, 3 days, 1 week, 2 weeks) immediately pauses the track and closes the sheet
- [ ] `paused_at` and `paused_until` are correctly written to `curriculum_tracks`
- [ ] Tapping "Custom..." opens a date picker with tomorrow as first selectable date
- [ ] Custom date picker OK writes correct `paused_until` and closes sheet
- [ ] Custom date picker Cancel returns to PausePicker without action
- [ ] Tapping "Indefinite" shows inline confirmation before committing
- [ ] Indefinite pause sets `paused_at = now` and `paused_until = null`
- [ ] Undo snackbar appears for 5 seconds after every pause action
- [ ] Undo snackbar "Undo" reverts pause state completely
- [ ] Snackbar text shows correct duration and resume date (or "indefinitely")
- [ ] All actions logged to `track_action_log` with correct `action_type`
- [ ] Sheet dismissable via swipe-down or scrim tap without taking action

### PauseResumeCard

- [ ] Card appears on dashboard when a fixed-duration pause has expired (`paused_until <= now`)
- [ ] Card does NOT appear for indefinite pauses (no auto-expiry)
- [ ] Card displays correct track name
- [ ] "Resume" clears pause state and returns track to active
- [ ] "Resume" routes to Catch-up Sheet if debt accumulated during pause
- [ ] "Resume" returns track to normal active state if no debt
- [ ] "Extend pause" opens PausePicker for the same track
- [ ] "Archive" shows confirmation dialog before archiving
- [ ] Dismiss ("x") hides card for current session only
- [ ] Dismissed card re-appears on next app open if not acted upon
- [ ] Multiple expired tracks show multiple cards, most recent first

### Dashboard Paused State

- [ ] Paused track cards render at 60% opacity
- [ ] Pause badge replaces status line with "Paused until {date}" or "Paused (indefinite)"
- [ ] Paused tracks remain in their natural list position (not moved)
- [ ] Paused track card tap navigates to Track Detail
- [ ] "Continue" button hidden on paused track cards
- [ ] Paused tracks generate zero tasks in "Today's Learning"
- [ ] Paused tracks excluded from triage sequences

### Notification Pause

- [ ] Pause action available in track notification
- [ ] Notification pause applies 7-day default duration (no picker)
- [ ] Notification pause writes same data as PausePicker preset
- [ ] Notification pause shows undo snackbar on next app open

### System Behavior

- [ ] Paused track receives zero notifications of any kind
- [ ] Pace clock (`daysBehind`) does not increment while paused
- [ ] Pause is never applied automatically by any system flow
- [ ] Pause is always learner-initiated
- [ ] Pause is distinct from Archive in data model and UI treatment

---

## Open Questions

| # | Question | Context | Status |
|---|----------|---------|--------|
| — | None | All design decisions resolved in this spec | N/A |

---

## Checklist

- [x] Surface purpose clear
- [x] All component IDs assigned
- [x] Layout structure defined (both surfaces)
- [x] Spacing tokens specified
- [x] All states documented
- [x] Design decisions resolved with rationale
- [x] Entry/exit points mapped
- [x] Data sources and writes specified
- [x] Animations defined
- [x] Accessibility requirements specified
- [x] Acceptance criteria complete
- [x] Child/adult mode differences captured (touch targets, corner radius)

---

_Created using Whiteport Design Studio (WDS) methodology_
