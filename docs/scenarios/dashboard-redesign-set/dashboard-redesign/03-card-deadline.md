> ⚠️ **Status — 2026-04-19:** Epic 20 (DNI-210) was canceled 2026-04-15 (all 12 child stories). The per-track data infrastructure partially landed via Epic 23 and Epic 21, but the dashboard UI redesign specified in this set is **not shipped**. Use this scenario set as a design reference if Epic 20 is re-scoped.

# 03 — Track Card: Deadline Variant

**Parent:** [01-dashboard.md](01-dashboard.md) > Section: Your Tracks
**Applies to:** Scenario S1 (self-paced with deadline goal)

---

## Overview

Displays progress for self-paced tracks where the user set a deadline ("finish Berachot by Pesach"). The primary metric is **scope progress** with pace measured against the deadline.

---

## Variant Selection

This card renders when `track.programId == null && track.goalType == 'deadline'`.

---

## Layout

```
┌─ {curriculum color} border ────────────────────┐
│                                                  │
│  {trackLabel}                  {curriculum chip} │
│                                                  │
│  ████████████░░░░░░░░  {pct}%                    │
│  {completed} / {total} items complete            │
│  {statusIcon} {statusText}                       │
│  ──────────────────────────────────────────────  │
│  {chazaraLine}              ← only if applicable │
│  ──────────────────────────────────────────────  │
│  Today: {N} tasks                 [Continue ->]  │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Content Specification

### Row 1: Track Label + Curriculum

Same as program variant. Track label left, curriculum chip right.

### Row 2: Progress Bar + Percentage

| Element | Spec |
|---------|------|
| Progress bar | `LinearProgressIndicator`, 8dp height, curriculum color fill |
| Percentage | "{pct}%" appended to the right of the bar |
| Style | `bodyLarge` (16sp) for percentage |

### Row 3: Item Count

| Element | Spec |
|---------|------|
| Content | "{completed} / {total} items complete" |
| Style | `bodyMedium` (14sp), `onSurfaceVariant` |
| Note | "items" = scoped content items with all stages completed |

### Row 4: Status

| Status | Icon | Text | Color |
|--------|------|------|-------|
| On track, no specific date shown | ✓ | "On track for {deadlineHe}" | `success` |
| Ahead | ↑ | "{N} days ahead" | `success` |
| 1-7 days behind | ⚠ | "{N} days behind — may finish {projectedDate}" | `warning` |
| 8+ days behind | ⚠ | "{N} days behind — may finish {projectedDate}" | `error` |
| Deadline passed, not done | ⚠ | "Deadline passed — {pct}% complete" | `error` |

**Date format:** Hebrew date preferred (e.g., "ט״ו ניסן"), Gregorian in parentheses if space allows.

Style: `bodyMedium` (14sp), w500.

**Status calculation:**

```
required_daily_pace = remaining_items / days_to_deadline
actual_pace = 7-day rolling average of daily completions
days_delta = (actual_pace - required_daily_pace) * days_to_deadline / required_daily_pace
projected_date = today + ceil(remaining_items / actual_pace)
```

### Row 5: Chazara Line (conditional)

Same spec as program variant. Show when chazara stages configured.

### Row 6: Footer

Same spec as program variant. Task count + Continue button.

---

## States

| State | Condition | Display |
|-------|-----------|---------|
| **On track** | Projected completion at or before deadline | Green status |
| **Slightly behind** | Projected 1-7 days late | Amber status |
| **Significantly behind** | Projected 8+ days late | Red status |
| **Deadline passed** | Today > deadline, progress < 100% | Red "Deadline passed" status |
| **Complete** | All scoped items, all stages done | "🎉 Complete!" status, progress bar full |
| **New track** | Just created, 0 completions | "0%" + empty progress bar + "✦ Getting started" |
| **Rest day** | Today is review-only for this track | "Review day" badge, only chazara tasks |

---

## Data Source

```dart
/// From trackProgressProvider(trackId) when variant == deadlineGoal
TrackProgress {
  double scopePercentage;     // 0.0 - 1.0
  int completedItems;         // Items with all stages done
  int totalItems;             // Total scoped items
  PaceStatus paceStatus;      // ahead/onPace/behind + daysDelta + projectedDate
  ChazaraStatus? chazaraStatus;
  int tasksToday;
}

PaceStatus {
  PaceStatusType status;      // ahead, onPace, behind
  int daysDelta;              // days ahead (+) or behind (-)
  DateTime projectedCompletionDate;
  double rollingAverage;      // 7-day rolling avg
}
```

---

_Created using Whiteport Design Studio (WDS) methodology_
