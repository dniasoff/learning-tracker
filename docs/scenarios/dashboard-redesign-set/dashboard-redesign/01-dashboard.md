> ⚠️ **Status — 2026-04-19:** Epic 20 (DNI-210) was canceled 2026-04-15 (all 12 child stories). The per-track data infrastructure partially landed via Epic 23 and Epic 21, but the dashboard UI redesign specified in this set is **not shipped**. Use this scenario set as a design reference if Epic 20 is re-scoped.

# 01 — Dashboard

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Dashboard Redesign |
| **Route** | `/` (AppShellRoute — home tab) |
| **Platform** | Mobile (Flutter) |
| **Page Type** | Full page (tab in bottom nav shell) |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |

---

## Overview

**Page Purpose:** Answer two questions instantly: "What should I do right now?" and "Am I making progress?"

**User Situation:** Opens the app to learn. May have 1-5 active tracks across different curricula, mixing program and self-paced tracks with different goal modes and chazara configurations.

**Success Criteria:** User knows within 3 seconds what to do next and how each track is doing.

**Entry Points:**
- App launch (warm resume)
- Bottom nav "Home" tab tap
- Notification tap (daily reminder)
- Return from learning/completion flow

**Exit Points:**
- Tap task item -> Learning screen (with trackId context)
- Tap "Continue" on track card -> Learning screen (filtered to that track)
- Tap "View all" on tasks -> Scheduler screen
- Tap track card body -> Track detail screen
- Bottom nav -> other tabs

---

## Layout Structure

```
┌──────────────────────────────────────┐
│ HEADER                               │
│ Greeting + date (Gregorian + Hebrew) │
├──────────────────────────────────────┤
│ STATS ROW                            │
│ [Streak] [Tasks] [Points/Pages]      │
├──────────────────────────────────────┤
│ TODAY'S LEARNING              X left │
│ ┌──────────────────────────────────┐ │
│ │ Task 1 (track label · ref)  [✓] │ │
│ │ Task 2 (track label · ref)  [✓] │ │
│ │ Task 3 (track label · ref)  [✓] │ │
│ │ Task 4 (track label · ref)  [✓] │ │
│ │ Task 5 (track label · ref)  [✓] │ │
│ │         View all (12) →         │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ YOUR TRACKS                          │
│ ┌──────────────────────────────────┐ │
│ │ Track Card 1 (variant-specific) │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ Track Card 2 (variant-specific) │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ Track Card 3 (variant-specific) │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Scroll behavior:** Single scrollable `ListView` containing all sections. Pull-to-refresh invalidates all providers.

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `md` (16dp) |
| Section gap (between header, stats, tasks, tracks) | `lg` (24dp) |
| Element gap (within sections) | `md` (16dp) |
| Task item gap | `zero` (divided by 1dp separator) |
| Track card gap | `md` (16dp) |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Semantic | Size | Weight |
|---------|----------|------|--------|
| Greeting | — | `titleLarge` (22sp) | normal |
| Date line | — | `bodyMedium` (14sp) | normal |
| Section title ("Today's Learning") | — | `titleMedium` (16sp) | w500 |
| Stats number | — | `headlineMedium` (28sp) | bold |
| Stats label | — | `labelSmall` (11sp) | normal |
| Track card label | — | `titleMedium` (16sp) | w500 |
| Track card metric | — | `bodyLarge` (16sp) | normal |
| Track card status | — | `bodyMedium` (14sp) | normal |
| Task item title | — | `bodyMedium` (14sp) | w500 |
| Task item subtitle | — | `bodySmall` (12sp) | normal |

---

## Page Sections

### Section: Header

**OBJECT ID:** `dashboard-header`

| Property | Value |
|----------|-------|
| Purpose | Greeting + date context |
| Padding | `md` horizontal, `md` top |

#### Greeting Text

**OBJECT ID:** `dashboard-header-greeting`

| Property | Value |
|----------|-------|
| Content | Time-based: "Good morning/afternoon/evening, {profileName}" |
| Style | `titleLarge`, normal weight |

#### Date Line

**OBJECT ID:** `dashboard-header-date`

| Property | Value |
|----------|-------|
| Content | "{Hebrew date} · {Gregorian date}" (e.g., "ד׳ ניסן תשפ״ו · April 1, 2026") |
| Style | `bodyMedium`, `onSurfaceVariant` color |

---

### Section: Stats Row

**OBJECT ID:** `dashboard-stats`

| Property | Value |
|----------|-------|
| Purpose | At-a-glance global metrics |
| Layout | Row of 3 equal-width stat items |
| Padding | `md` horizontal |

#### Stat: Streak

**OBJECT ID:** `dashboard-stats-streak`

| Property | Value |
|----------|-------|
| Number | Current streak days |
| Label | "Streak" |
| Icon | Flame icon (if streak > 0) |
| Color | Default. Milestone color at thresholds [7, 14, 30, 50, 100, 180, 365] |

#### Stat: Today

**OBJECT ID:** `dashboard-stats-today`

| Property | Value |
|----------|-------|
| Number | "{completed}/{total}" tasks |
| Label | "Today" |
| Color | Green when all done, default otherwise |

#### Stat: Points (child) / Pages (adult)

**OBJECT ID:** `dashboard-stats-engagement`

| Property | Value |
|----------|-------|
| Child mode | Points total + "Pts" label |
| Adult mode | Items completed today + "Done" label |

---

### Section: Today's Learning

**OBJECT ID:** `dashboard-tasks`

| Property | Value |
|----------|-------|
| Purpose | Prioritized cross-track task list |
| Data source | `allDailyTasksProvider` (runs scheduler per-track, merges, priority-sorts) |
| Max visible | 5 items. "View all (N)" link if more. |

#### Section Title Row

**OBJECT ID:** `dashboard-tasks-header`

| Property | Value |
|----------|-------|
| Left | "Today's Learning" (`titleMedium`) |
| Right | "{remaining} left" (`bodySmall`, `onSurfaceVariant`) |

#### Task Item

**OBJECT ID:** `dashboard-tasks-item`

| Property | Value |
|----------|-------|
| Layout | Row: leading circle checkbox, content column, trailing complete button |
| Line 1 | "{trackLabel} · {contentRef}" (`bodyMedium`, w500) |
| Line 2 | "{stageName}" (`bodySmall`). If overdue: append " · {N} day(s) overdue" in `error` color |
| Trailing | Checkmark `IconButton` (48dp adult / 56dp child touch target) |
| Curriculum color | 4dp left border on the item row |
| Tap row | Navigate to learning screen with `trackId` + `sefariaRef` |
| Tap checkmark | Mark complete (optimistic UI, 5s undo snackbar) |

#### Task Priority Order

| Priority | Color Indicator | Source |
|----------|----------------|--------|
| 1. Overdue program items | `error` left border | Program tracks |
| 2. Today's program items | Curriculum color border | Program tracks |
| 3. Overdue chazara | `error` left border | Any track |
| 4. Scheduled chazara | Curriculum color border | Any track |
| 5. New learning | Curriculum color border | Self-paced tracks |

#### View All Link

**OBJECT ID:** `dashboard-tasks-viewall`

| Property | Value |
|----------|-------|
| Visible | When total tasks > 5 |
| Text | "View all ({total}) ->" |
| Action | Navigate to Scheduler screen |
| Alignment | Center |

---

### Section: Your Tracks

**OBJECT ID:** `dashboard-tracks`

| Property | Value |
|----------|-------|
| Purpose | Per-track progress cards |
| Data source | `activeTracksProvider` + `trackProgressProvider(trackId)` for each |
| Layout | Vertical list of track cards |
| Order | Tracks with tasks today first (most tasks first), then tracks with overdue, then rest |

#### Section Title

**OBJECT ID:** `dashboard-tracks-header`

| Property | Value |
|----------|-------|
| Text | "Your Tracks" |
| Style | `titleMedium` |
| Hidden | When only 1 track (no need for header) |

#### Track Card

**OBJECT ID:** `dashboard-track-card`

See detailed card variant specs: [02-card-program.md](02-card-program.md), [03-card-deadline.md](03-card-deadline.md), [04-card-velocity.md](04-card-velocity.md), [05-card-momentum.md](05-card-momentum.md).

**Common card structure:**

```
┌─ curriculum color border (4dp light / 6dp dark) ─┐
│                                                    │
│  {trackLabel}                    {curriculum chip} │
│  ──────────────────────────────────────────────── │
│  {PRIMARY METRIC — variant-specific}               │
│  {STATUS LINE — variant-specific}                  │
│  ──────────────────────────────────────────────── │
│  {CHAZARA LINE — if applicable}                    │
│  ──────────────────────────────────────────────── │
│  Today: {N} tasks                   [Continue ->]  │
│                                                    │
└────────────────────────────────────────────────────┘
```

| Property | Value |
|----------|-------|
| Component | Material 3 `Card` (elevated) |
| Left border | 4dp light / 6dp dark, curriculum color |
| Padding | `md` (16dp) all sides |
| Corner radius | 12dp (adult) / 16dp (child) |
| Tap body | Navigate to Track Detail screen |
| Tap "Continue" | Navigate to Learning screen with `trackId` |

**Card variant selection logic:**

```dart
TrackProgressVariant variant = track.programId != null
    ? TrackProgressVariant.programCalendar
    : track.goalType == 'deadline'
        ? TrackProgressVariant.deadlineGoal
        : track.goalType == 'pace'
            ? TrackProgressVariant.velocityGoal
            : TrackProgressVariant.momentum;
```

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Default** | 1+ tracks, tasks exist | Full layout as designed | Complete tasks, tap cards |
| **Loading** | Initial data fetch | Shimmer placeholders for stats, tasks, cards | Pull-to-refresh |
| **Empty — no tracks** | Profile has 0 active tracks | Empty state illustration + "Add Your First Track" button | Navigate to TrackManagementHub |
| **Empty — no tasks today** | Active tracks exist but no tasks scheduled | Stats row + track cards visible. Task section: "All done for today!" with celebration (child) or check icon (adult) | View track cards |
| **All complete** | All today's tasks completed | Stats row shows green "Today" stat. Task section: completion celebration | View track cards |
| **Single track** | Exactly 1 active track | No "Your Tracks" header. Tasks don't show track labels. Card can show expanded detail. | Same as default |
| **Error** | Provider error | Error banner with retry | Pull-to-refresh |

---

## Child vs Adult Mode

| Property | Child Mode | Adult Mode |
|----------|-----------|-----------|
| Touch targets | 56dp | 48dp |
| Card corner radius | 16dp | 12dp |
| Stats engagement | Points ("127 Pts") | Items done today ("5 Done") |
| All-complete celebration | Animated trophy + gradient card | Subtle check icon + message |
| Progress framing | Achievement ("3 done!") | Data ("3/5 complete") |
| Streak milestone | Bouncing trophy, 4s auto-dismiss | Subtle fire icon banner |
| Card spacing | `lg` (24dp) | `md` (16dp) |
| Typography scale | Slightly larger body | Standard MD3 |

---

## Recovery Actions (on Track Cards)

Recovery actions surface on track cards when the user is significantly behind. They appear as a subtle text button below the status line.

### Program — "Jump to today"

| Property | Value |
|----------|-------|
| Visible | When program track is 5+ items behind |
| Text | "Jump to today" (subtle, `bodySmall`, `primary` color) |
| Action | Confirmation dialog: "Skip to today's position? Missed items won't be marked as completed." |
| Effect | Updates `startingPosition` to today's calendar position. Status becomes "Caught up." |

### Self-paced — "Reset pace"

| Property | Value |
|----------|-------|
| Visible | When momentum track shows "Paused" or velocity track shows "Below target" for 7+ days |
| Text | "Reset pace" (subtle, `bodySmall`, `primary` color) |
| Action | Confirmation dialog: "Start measuring your pace from today? Overdue reviews will still be scheduled." |
| Effect | Resets velocity/momentum baseline date to today. Does NOT clear overdue chazara. |

---

## Technical Notes

- **Warm resume < 2s** — use `ListView.builder` with cached provider data
- **Pull-to-refresh** invalidates: `activeTracksProvider`, `allDailyTasksProvider`, `dashboardStreakProvider`, all `trackProgressProvider` instances
- **Optimistic UI** for task completion (per Epic 18 story 18.8): synchronous state update before DB write, rollback on failure
- **Scheduler runs per-track** — `allDailyTasksProvider` invokes `SchedulerEngine.generateDailyTasks()` once per active track, merges results, priority-sorts
- **Provider architecture** — `trackProgressProvider(trackId)` returns `TrackProgress` with variant-specific fields; the card widget switches on `variant` to render the correct layout

---

## Open Questions

| # | Question | Context | Status |
|---|----------|---------|--------|
| 1 | Day type indicator per-track or global? | Current dashboard shows "Study Day / Review Day" globally. With per-track study days, Track A might be a study day while Track B is review-only. | 🔴 Open |
| 2 | Streak milestone overlay — still full-screen? | Current implementation shows a full-screen celebration overlay at milestone streaks. With multi-track focus, is this still the right pattern? | 🟡 In Discussion |

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All states documented
- [x] Child/adult mode differences captured
- [x] Recovery actions specified
- [x] Technical constraints noted
- [ ] Card variant specs complete (see 02-05)

---

_Created using Whiteport Design Studio (WDS) methodology_
