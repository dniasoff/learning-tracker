> ⚠️ **Status — 2026-04-19:** Epic 20 (DNI-210) was canceled 2026-04-15 (all 12 child stories). The per-track data infrastructure partially landed via Epic 23 and Epic 21, but the dashboard UI redesign specified in this set is **not shipped**. Use this scenario set as a design reference if Epic 20 is re-scoped.

# 07 — Track Detail Screen

**Parent scenario:** [00-scenario-overview.md](00-scenario-overview.md)

---

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Dashboard Redesign |
| **Route** | `/settings/tracks/:trackId` (TrackDetailRoute) |
| **Platform** | Mobile (Flutter) |
| **Page Type** | Full page (pushed onto nav stack) |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |

---

## Overview

**Page Purpose:** Full view of a single track's configuration, progress, and available actions. The "control panel" for one track.

**User Situation:** Wants to see detailed progress for a specific track, edit its configuration, or take a recovery action (jump to today, reset pace).

**Success Criteria:** User can see full track status, access all editable settings, and take recovery actions — all from one screen.

**Entry Points:**
- Tap track card body on Dashboard
- Tap track tile on Progress screen
- Tap track row in Track Management Hub

**Exit Points:**
- Back navigation -> previous screen
- "Edit" actions -> modal screens (scope, chazara, goal, study days, label)
- "View Charts" -> Progress Charts (pre-filtered to this track)
- "View History" -> Completion History (pre-filtered to this track)

---

## Layout Structure

```
┌──────────────────────────────────────┐
│ ← {trackLabel}              AppBar   │
├──────────────────────────────────────┤
│ TRACK STATUS                         │
│ ┌──────────────────────────────────┐ │
│ │ Full card variant (expanded)    │ │
│ │ (same as dashboard card but     │ │
│ │  with more detail)              │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ PROGRESS DETAIL                      │
│ (variant-specific expanded view)     │
├──────────────────────────────────────┤
│ QUICK LINKS                          │
│ ┌──────────────────────────────────┐ │
│ │ 📊 View Charts               →  │ │
│ │ 📋 View History              →  │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ TRACK SETTINGS                       │
│ ┌──────────────────────────────────┐ │
│ │ Label          {value}     [✏]  │ │
│ │ Curriculum     {value}          │ │
│ │ Program        {value}          │ │
│ │ Scope          {value}     [✏]  │ │
│ │ Study Days     {value}     [✏]  │ │
│ │ Chazara        {value}     [✏]  │ │
│ │ Goal           {value}     [✏]  │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ ACTIONS                              │
│ ┌──────────────────────────────────┐ │
│ │ {Recovery action if applicable} │ │
│ │ Archive Track                   │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

---

## Spacing

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `md` (16dp) |
| Section gap | `lg` (24dp) |
| Element gap within sections | `md` (16dp) |
| Settings row gap | `zero` (divided by 1dp separator) |

---

## Page Sections

### Section: Track Status

**OBJECT ID:** `trackdetail-status`

| Property | Value |
|----------|-------|
| Purpose | Expanded version of the dashboard track card |
| Component | Same card variant widget as dashboard, but with `expanded: true` flag |
| Content | All content from the dashboard card variant (see 02-05 specs) |

The expanded card shows everything the dashboard card shows. No additional metrics here — the detail comes in the next section.

---

### Section: Progress Detail (variant-specific)

**OBJECT ID:** `trackdetail-progress`

Deeper progress breakdown that doesn't fit on the dashboard card. Content varies by variant.

#### Program Calendar Variant

```
PROGRESS
├── Calendar Timeline
│   ├── Visual bar: [████████░░░░░░░░░░] Day 142 / 2,711
│   ├── Started: {startDate}
│   ├── Current position: {todayDisplayHe}
│   └── Expected position: {expectedDisplayHe} (if behind/ahead)
│
├── Completions This Cycle
│   ├── Learned: {count}
│   └── Missed: {count} (items skipped via "Jump to today")
│
└── Chazara Compliance (if prescribed)
    ├── Due: {count}
    ├── Overdue: {count}
    └── Completed today: {count}
```

#### Deadline Variant

```
PROGRESS
├── Scope Breakdown
│   ├── Completed (all stages): {count}
│   ├── In progress (some stages): {count}
│   └── Not started: {count}
│
├── Pace
│   ├── Current pace: {rate}/day (7-day avg)
│   ├── Required pace: {rate}/day
│   ├── Deadline: {dateHe} ({dateGreg})
│   └── Projected completion: {dateHe} ({dateGreg})
│
└── Chazara Load (if configured)
    ├── Due today: {count}
    ├── Overdue: {count}
    └── Upcoming (next 7 days): {count}
```

#### Velocity Variant

```
PROGRESS
├── Scope Breakdown
│   ├── Completed (all stages): {count}
│   ├── In progress: {count}
│   └── Not started: {count}
│
├── Pace
│   ├── Current rate: {rate}/{unit} (7-day avg)
│   ├── Target rate: {rate}/{unit}
│   ├── This week: {count}
│   └── Last week: {count}
│
└── Chazara Load (if configured)
    ├── Due today: {count}
    ├── Overdue: {count}
    └── Upcoming (next 7 days): {count}
```

#### Momentum Variant

```
PROGRESS
├── Scope Breakdown
│   ├── Completed (all stages): {count}
│   ├── In progress: {count}
│   └── Not started: {count}
│
├── Activity
│   ├── This week: {count}
│   ├── Personal average: {avg}/week
│   ├── Last active: {date} ({N} days ago)
│   └── Total completions: {count}
│
└── Chazara Load (if configured)
    ├── Due today: {count}
    ├── Overdue: {count}
    └── Upcoming (next 7 days): {count}
```

**Presentation:** Each sub-section is a `Card` with a section title and rows of label-value pairs. Labels left-aligned (`bodyMedium`, `onSurfaceVariant`), values right-aligned (`bodyMedium`, default color).

---

### Section: Quick Links

**OBJECT ID:** `trackdetail-links`

| Property | Value |
|----------|-------|
| Purpose | Navigate to Charts/History pre-filtered to this track |
| Layout | `Card` with `ListTile` items |

#### View Charts

| Property | Value |
|----------|-------|
| Action | Navigate to Progress Charts with `trackId` pre-selected in filter |

#### View History

| Property | Value |
|----------|-------|
| Action | Navigate to Completion History with `trackId` pre-selected in filter |

---

### Section: Track Settings

**OBJECT ID:** `trackdetail-settings`

| Property | Value |
|----------|-------|
| Purpose | View and edit track configuration |
| Layout | `Card` containing `ListTile` rows with dividers |
| Data source | Track entity + related configs (scope, stages, goal, study days) |

#### Settings Rows

| Setting | Value Display | Editable | Edit Action | Program Track |
|---------|--------------|----------|-------------|---------------|
| **Label** | Track name (e.g., "דף היומי") | Yes | `AlertDialog` with `TextField` | Yes |
| **Curriculum** | Hebrew name (e.g., "בבלי") | No (read-only) | — | Read-only |
| **Program** | Program name or "Self-paced" | No (read-only) | — | Read-only |
| **Scope** | Summary (e.g., "ברכות only" or "All") | Self-paced only | Opens `ScopeSelectionScreen` | Read-only ("Program-defined") |
| **Study Days** | Summary (e.g., "Sun-Thu" or "All days") | Self-paced only | Opens `StudyDayConfigScreen` | Read-only ("Program-defined") |
| **Chazara** | Summary (e.g., "3 stages" or "None") | Self-paced + open chazara | Opens `LearningProcessWizardScreen` | Prescribed: read-only. Open: editable. |
| **Goal** | Summary (e.g., "Finish by ט״ו ניסן" or "2/day" or "No goal") | Self-paced only | Opens `GoalSetupScreen` | Read-only ("N/A") |

**Edit indicator:** Pencil icon button on the trailing edge. Only shown on editable rows.

**Program track rules:** Program-defined settings show the value with "(Program)" suffix and no edit button. The "show don't ask" principle carries through to the detail screen.

**Study days summary format:**
- All 7 active: "Every day"
- Specific days: "Sun, Mon, Tue, Wed, Thu" (abbreviated)
- Include review-only days: "Sun-Thu (Fri, Shabbos review only)"

**Chazara summary format:**
- No chazara: "None"
- N stages: "{N} stages (לימוד + {N-1} חזרה)"
- Prescribed: "{N} stages (prescribed)"

**Goal summary format:**
- No goal: "No goal set" + "Set a goal" text button
- Deadline: "Finish by {dateHe}"
- Velocity: "{rate}/{unit}"

---

### Section: Actions

**OBJECT ID:** `trackdetail-actions`

| Property | Value |
|----------|-------|
| Purpose | Recovery actions and track lifecycle |
| Layout | Vertical list of action buttons |
| Position | Bottom of page, above safe area |

#### Recovery Action (conditional)

Variant-specific, same logic as dashboard card recovery actions:

| Variant | Condition | Action | Button Style |
|---------|-----------|--------|-------------|
| Program | 5+ items behind | "Jump to Today" | `OutlinedButton` |
| Velocity | Below target 7+ days | "Reset Pace" | `OutlinedButton` |
| Momentum | Paused 14+ days | "Reset Pace" | `OutlinedButton` |
| Deadline | — | No recovery action (edit the goal instead) | — |

Confirmation dialogs same as dashboard card specs (02-05).

#### Archive Track

| Property | Value |
|----------|-------|
| Always visible | Yes (unless last active track) |
| Text | "Archive Track" |
| Style | `TextButton`, `error` color |
| Guard | Cannot archive last active track — show snackbar "Cannot archive your only active track" |
| Action | Confirmation dialog |
| Dialog title | "Archive Track?" |
| Dialog text | "This track will be hidden from your dashboard and scheduler. Your learning history is preserved. You can reactivate it later from Manage Tracks." |
| Dialog actions | "Cancel" / "Archive" |
| Effect | Sets `archived_at` on track. Navigates back. Invalidates `activeTracksProvider`. |

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Default** | Track loaded with data | Full layout | Edit settings, recovery actions, archive |
| **Loading** | Fetching track + progress data | Shimmer on status card + settings | Wait |
| **Error** | Provider error | Error state with retry | Pull-to-refresh |
| **Archived track** | Viewing an archived track (from Manage Tracks) | All settings read-only. No recovery actions. "Reactivate" button instead of "Archive." | Reactivate |

---

## Provider Invalidation After Edits

| Edit | Providers Invalidated |
|------|----------------------|
| Label | `activeTracksProvider` |
| Scope | `trackProgressProvider(trackId)`, scope providers |
| Study Days | `trackProgressProvider(trackId)`, `allDailyTasksProvider` |
| Chazara | `trackProgressProvider(trackId)`, `allDailyTasksProvider`, stage providers |
| Goal | `trackProgressProvider(trackId)`, pace providers |
| Archive | `activeTracksProvider`, `allDailyTasksProvider` |
| Jump to Today | `trackProgressProvider(trackId)`, `allDailyTasksProvider` |
| Reset Pace | `trackProgressProvider(trackId)` |

---

## Technical Notes

- **Track detail reuses dashboard card widget** — the status section renders the same variant card component with an `expanded` flag for slightly more space, but no new content. Detail comes from the Progress Detail section below it.
- **Edit screens are modal** — pushed onto nav stack, return result. Same screens used in AddTrackFlow (scope, study days, chazara wizard, goal setup) but with pre-populated values.
- **"Jump to Today" writes to DB** — updates the track's `startingPosition` field. Does not create completions for skipped items.
- **"Reset Pace" writes to DB** — stores a `paceResetDate` on the track. Momentum/velocity calculations use this as the baseline start date instead of track creation date.
- **Program track settings are read-only** — enforced at the widget level (no edit buttons rendered), not just visually grayed.

---

## Open Questions

_No open questions._

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined
- [x] Spacing tokens specified
- [x] Variant-specific progress detail for all 4 variants
- [x] Settings rows with edit/read-only rules per variant
- [x] Recovery actions with conditions and dialogs
- [x] Archive flow with guard (last track)
- [x] Provider invalidation matrix
- [x] All states documented
- [x] Technical implementation notes

---

_Created using Whiteport Design Studio (WDS) methodology_
