# 06 — Progress Screen

**Parent scenario:** [00-scenario-overview.md](00-scenario-overview.md)

---

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Dashboard Redesign |
| **Route** | Bottom nav "Progress" tab |
| **Platform** | Mobile (Flutter) |
| **Page Type** | Full page (tab in bottom nav shell) |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |

---

## Overview

**Page Purpose:** Deeper progress views than the dashboard cards. Per-track detail, charts, lifetime learning journey, and completion history.

**User Situation:** Wants to understand their learning trajectory beyond "am I on track today." Looking at trends, totals, or specific track details.

**Success Criteria:** User finds the progress view they need within 2 taps. Per-track data is clear and unambiguous.

**Entry Points:**
- Bottom nav "Progress" tab
- Track card tap (from dashboard) -> Track Detail (see [07-track-detail.md](07-track-detail.md))
- "View Charts" / "View History" links from track detail

**Exit Points:**
- Tap track tile -> Track Detail screen
- Tap "Charts" -> Progress Charts (filtered by track)
- Tap "Learning Journey" -> Lifetime curriculum view
- Tap "Completion History" -> Filterable history

---

## Layout Structure

```
┌──────────────────────────────────────┐
│ PROGRESS                    AppBar   │
├──────────────────────────────────────┤
│ OVERVIEW STATS                       │
│ ┌────────┐ ┌────────┐ ┌────────┐   │
│ │ 47     │ │ 1,284  │ │ 4      │   │
│ │ Streak │ │ Learned│ │ Tracks │   │
│ └────────┘ └────────┘ └────────┘   │
│ ┌────────┐                          │
│ │ 127    │  ← child mode only       │
│ │ Points │                          │
│ └────────┘                          │
├──────────────────────────────────────┤
│ QUICK ACCESS                         │
│ ┌──────────────────────────────────┐ │
│ │ 📊 Charts                    →  │ │
│ ├──────────────────────────────────┤ │
│ │ 📖 Learning Journey          →  │ │
│ ├──────────────────────────────────┤ │
│ │ 📋 Completion History        →  │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ BY TRACK                             │
│ ┌──────────────────────────────────┐ │
│ │ Track tile 1 (variant summary)  │ │
│ ├──────────────────────────────────┤ │
│ │ Track tile 2 (variant summary)  │ │
│ ├──────────────────────────────────┤ │
│ │ Track tile 3 (variant summary)  │ │
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
| Stat item gap | `md` (16dp) |
| Track tile gap | `zero` (divided by 1dp separator) |

---

## Typography

| Element | Size | Weight |
|---------|------|--------|
| AppBar title ("Progress") | `titleLarge` (22sp) | normal |
| Section title | `titleMedium` (16sp) | w500 |
| Stat number | `headlineMedium` (28sp) | bold |
| Stat label | `labelSmall` (11sp) | normal |
| Quick access item | `bodyLarge` (16sp) | normal |
| Track tile title | `titleSmall` (14sp) | w500 |
| Track tile subtitle | `bodySmall` (12sp) | normal |

---

## Page Sections

### Section: Overview Stats

**OBJECT ID:** `progress-overview`

| Property | Value |
|----------|-------|
| Purpose | Global lifetime stats across all tracks |
| Layout | Wrap row of stat items (3 for adult, 4 for child) |

#### Stat: Streak

| Property | Value |
|----------|-------|
| Number | Current streak (with max streak as subtitle: "max: 62") |
| Label | "Streak" |

#### Stat: Learned

| Property | Value |
|----------|-------|
| Number | Total completions (lifetime, all tracks, all time) |
| Label | "Learned" |
| Note | Counts learn-stage completions only, not chazara. This is "how many things have I learned" not "how many database rows." |

#### Stat: Tracks

| Property | Value |
|----------|-------|
| Number | Active (non-archived) track count |
| Label | "Tracks" |

#### Stat: Points (child mode only)

| Property | Value |
|----------|-------|
| Number | Lifetime points total |
| Label | "Points" |
| Visible | Child mode only |

**"Learned" definition:** A content item counts as "learned" when its learn stage (לימוד) is completed for the **first time ever** on any track (deduplicated by `sefariaRef`). This number only grows when the user encounters genuinely new content. Any subsequent completion of the same content — whether marked as "לימוד" on a second track or as explicit חזרה on any track — counts as **review** in the lifetime view.

---

### Section: Quick Access

**OBJECT ID:** `progress-quickaccess`

| Property | Value |
|----------|-------|
| Purpose | Navigation to detailed views |
| Layout | Vertical list of `ListTile` items |
| Component | Material 3 `Card` containing `ListTile` items with dividers |

#### Charts

| Property | Value |
|----------|-------|
| Leading icon | Bar chart icon |
| Title | "Charts" |
| Trailing | Chevron right |
| Action | Navigate to Progress Charts screen (with track filter selector) |

#### Learning Journey

| Property | Value |
|----------|-------|
| Leading icon | Book open icon |
| Title | "Learning Journey" |
| Trailing | Chevron right |
| Action | Navigate to Learning Journey screen (curriculum-based lifetime view) |

#### Completion History

| Property | Value |
|----------|-------|
| Leading icon | List icon |
| Title | "Completion History" |
| Trailing | Chevron right |
| Action | Navigate to Completion History screen (filterable by track) |

---

### Section: By Track

**OBJECT ID:** `progress-tracks`

| Property | Value |
|----------|-------|
| Purpose | Per-track progress summaries with navigation to detail |
| Layout | Vertical list of track tiles |
| Data source | `activeTracksProvider` + `trackProgressProvider(trackId)` |
| Order | Same as dashboard (tasks today first, then overdue, then rest) |

#### Track Progress Tile

**OBJECT ID:** `progress-track-tile`

Each tile shows a condensed version of the track card's progress info. Tapping navigates to the Track Detail screen.

**Common structure:**

```
┌─ {curriculum color} left border ───────────────┐
│  {trackLabel}              {statusBadge}        │
│  {variantSummaryLine}                           │
│  {progressBar}  {pct}%                          │
└─────────────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Track label | `titleSmall` (14sp), w500 |
| Status badge | Small chip: "✓ Caught up" / "⚠ 3 behind" / "✓ Active" etc. Colors match card variant status colors. |
| Variant summary line | See below per variant |
| Progress bar | `LinearProgressIndicator`, 4dp height, curriculum color |
| Percentage | `bodySmall` (12sp) |
| Left border | 4dp, curriculum color |
| Tap action | Navigate to Track Detail screen with `trackId` |
| Trailing | Chevron right |

**Variant summary lines:**

| Variant | Summary Line |
|---------|-------------|
| Program Calendar | "Day {N} / {total} · {programName}" |
| Deadline | "{completed}/{total} · due {deadlineHe}" |
| Velocity | "{actualRate}/{unit} (target: {target})" |
| Momentum | "{recentCount} this week · avg {avg}/week" |

---

## Sub-Screens

### Progress Charts (existing, needs track filter)

**Route:** `ProgressChartsRoute`

**Changes from current:**
- Add **track selector** at the top (dropdown or chip group)
- Options: "All tracks" + one entry per active track (by label)
- "All tracks" shows aggregated data across all tracks
- Per-track shows only that track's completions
- All chart queries (`getDailyCompletions`, `getCumulativeProgress`, `getDailyPoints`, `getStreakCalendar`) pass `trackId` when filtering

**Charts available:**
1. Completions over time (bar chart, daily counts)
2. Cumulative progress (line chart, optional target line for deadline/velocity tracks)
3. Points earned (child mode, bar chart)
4. Streak calendar (heat map — always global, ignores track filter)

**Target line on cumulative chart:**
- Deadline track: linear interpolation from start to deadline
- Velocity track: linear from start at target rate
- Program track: linear at program pace (1/day for daily programs)
- Momentum track: no target line (no goal)

---

### Learning Journey (existing, redesigned)

**Route:** `LearningJourneyRoute`

**Key change:** This is a **curriculum-based lifetime view**. No track labels. Shows what you have learned and how many times you reviewed it, regardless of which track you were using.

**View modes:**
1. **By Curriculum** (default) — grouped by curriculum, then hierarchy levels
2. **Timeline** — chronological, grouped by month

**By Curriculum view:**

```
LEARNING JOURNEY

בבלי
├── ברכות
│   ├── דף ב׳ — learned 1x, reviewed 3x
│   ├── דף ג׳ — learned 1x, reviewed 2x
│   └── דף ד׳ — learned 1x, reviewed 0x
├── שבת
│   └── (not started)
└── ...

משניות
├── זרעים
│   ├── ברכות פ״א — learned 1x, reviewed 1x
│   └── ...
```

**Per-item detail:**
- Content ref (Hebrew)
- Learn count: always "learned 1x" (first-ever completion of learn stage on any track)
- Review count: "reviewed {N}x" — ALL subsequent completions of this content across all tracks and all stages. This includes: learn-stage completions on second/third tracks (conceptually review, not new learning) + explicit חזרה completions on any track.

**Example:** User learns Berachot 3:4 on Daf Yomi (1st encounter), then learns it again on personal Berachot track, then completes חזרה א׳ and חזרה ב׳ on the personal track:
- Lifetime view: "learned 1x, reviewed 3x"

**Milestones:** Inline celebration markers when a masechta/seder/sefer is fully completed.

**No track labels shown.** The journey is about content mastery, not organizational structure.

---

### Completion History (existing, needs track filter)

**Route:** `CompletionHistoryRoute`

**Changes from current:**
- Replace `TrackType` filter (personal/school/tutor) with **track filter** (by track label)
- Filter options: "All tracks" + one entry per track (active and archived)
- Each completion row shows:
  - Content ref (Hebrew)
  - Stage name (Hebrew: לימוד / חזרה א׳ / etc.)
  - Track label (e.g., "דף היומי")
  - Date + time
  - Points awarded (child mode)
- Sort: Most recent first (date descending)
- Show archived track completions (grayed track label) when "All tracks" selected

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Default** | 1+ tracks with data | Full layout | Navigate to sub-screens |
| **Loading** | Initial fetch | Shimmer on stats + track tiles | Wait |
| **Empty — no tracks** | 0 active tracks | Illustration + "Add Your First Track" button | Navigate to TrackManagementHub |
| **Empty — no completions** | Tracks exist but 0 completions | Stats show zeros, tiles show "✦ Getting started" | Encourage "Start Learning" |
| **Error** | Provider error | Error banner with retry | Pull-to-refresh |

---

## Child vs Adult Mode

| Property | Child | Adult |
|----------|-------|-------|
| Stats shown | 4 (streak, learned, tracks, points) | 3 (streak, learned, tracks) |
| Touch targets | 56dp | 48dp |
| Progress framing | Achievement-oriented | Data-oriented |
| Quick access icons | Slightly larger | Standard |

---

## Technical Notes

- **"Learned" count is deduplicated by sefariaRef** — first-ever learn-stage completion on any track = 1 learned item. All subsequent completions of that content (including learn-stage on other tracks) count as review.
- **Learning Journey queries ignore trackId** — curriculum-scoped, cross-track
- **Completion History queries include trackId** — for per-track filtering and label display
- **Charts track selector** should default to "All tracks" and remember the user's last selection per session
- **Streak calendar is always global** — doesn't filter by track even when track filter is active on other charts

---

## Open Questions

_No open questions._

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined
- [x] Spacing tokens specified
- [x] Typography mapped
- [x] All states documented
- [x] Child/adult differences captured
- [x] Sub-screen changes documented (Charts, Journey, History)
- [x] Track filter behavior specified
- [x] "Learned" count definition clarified
- [x] Technical constraints noted

---

_Created using Whiteport Design Studio (WDS) methodology_
