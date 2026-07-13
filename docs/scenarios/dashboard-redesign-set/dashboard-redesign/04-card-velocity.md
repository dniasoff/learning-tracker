> ⚠️ **Status — 2026-04-19:** Epic 20 (DNI-210) was canceled 2026-04-15 (all 12 child stories). The per-track data infrastructure partially landed via Epic 23 and Epic 21, but the dashboard UI redesign specified in this set is **not shipped**. Use this scenario set as a design reference if Epic 20 is re-scoped.

# 04 — Track Card: Velocity Variant

**Parent:** [01-dashboard.md](01-dashboard.md) > Section: Your Tracks
**Applies to:** Scenarios S2, S5 (self-paced with velocity/pace goal)

---

## Overview

Displays progress for self-paced tracks where the user set a pace target ("2 mishnayos per day" or "10 per week"). The primary metric is **current rate vs target rate**.

---

## Variant Selection

This card renders when `track.programId == null && track.goalType == 'pace'`.

---

## Layout

```
┌─ {curriculum color} border ────────────────────┐
│                                                  │
│  {trackLabel}                  {curriculum chip} │
│                                                  │
│  ████████████░░░░░░░░  {pct}%                    │
│  {completed} / {total} items complete            │
│  {rateIcon} {actualRate}/{unit} — target: {target}/{unit} │
│  {statusIcon} {statusText}                       │
│  ──────────────────────────────────────────────  │
│  {chazaraLine}              ← only if applicable │
│  ──────────────────────────────────────────────  │
│  Today: {N} tasks                 [Continue ->]  │
│                                                  │
│  {resetPaceAction}      ← only if below for 7d+ │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Content Specification

### Row 1: Track Label + Curriculum

Same as other variants.

### Row 2: Progress Bar + Percentage

Same as deadline variant. Scope progress bar + percentage.

### Row 3: Item Count

Same as deadline variant. "{completed} / {total} items complete."

### Row 4: Rate Line

| Element | Spec |
|---------|------|
| Content | "{actualRate}/{unit} — target: {targetRate}/{unit}" |
| Examples | "2.3/day — target: 2.0/day" or "12/week — target: 10/week" |
| Style | `bodyMedium` (14sp) |
| Rate icon | ↑ if above target, → if on pace, ↓ if below |
| Icon color | Green (above), default (on pace), amber (below) |

**Rate unit:** Matches the user's goal unit. If goal is "per_day", show daily rate. If "per_week", show weekly rate. Rolling 7-day window for both.

**Rate calculation:**

```
actual_rate_daily = completions_last_7_days / 7
if unit == 'per_week':
  actual_rate = completions_last_7_days
  target_rate = paceValue
else:  // per_day
  actual_rate = actual_rate_daily
  target_rate = paceValue
```

### Row 5: Status

| Status | Icon | Text | Color |
|--------|------|------|-------|
| Above target (rate >= target) | ✓ | "Above target" | `success` |
| On pace (rate within 10% of target) | ✓ | "On pace" | `success` |
| Below target (rate < 90% of target) | ⚠ | "Below target" | `warning` |
| Significantly below (rate < 50% of target) | ⚠ | "Below target" | `error` |

Style: `bodyMedium` (14sp), w500.

**Threshold math:**

```
ratio = actual_rate / target_rate
if ratio >= 1.0  → aboveTarget
if ratio >= 0.9  → onPace
if ratio >= 0.5  → belowTarget (warning)
if ratio < 0.5   → belowTarget (error)
```

### Row 6: Chazara Line (conditional)

Same spec as other variants.

### Row 7: Footer

Same spec as other variants.

### Recovery: Reset Pace (conditional)

| Element | Spec |
|---------|------|
| Visible | When status is "Below target" for 7+ consecutive days |
| Text | "Reset pace" |
| Style | `TextButton`, `bodySmall`, `primary` color |
| Position | Below footer row, centered |
| Action | Confirmation dialog -> reset velocity baseline to today |
| Dialog text | "Start measuring your pace from today? Overdue reviews will still be scheduled." |
| Dialog actions | "Cancel" / "Reset Pace" |
| Effect | Clears rolling average history. Next 7 days build a fresh baseline. Status shows "✦ Getting started" until enough data. |

---

## States

| State | Condition | Display |
|-------|-----------|---------|
| **Above target** | Rate >= target | Green status + rate line |
| **On pace** | Rate within 10% of target | Green status |
| **Below target** | Rate < 90% of target, < 7 days | Amber status |
| **Persistently below** | Below target for 7+ days | Red status + "Reset pace" action |
| **Complete** | All scoped items done | "🎉 Complete!" |
| **New track** | < 7 days old, not enough data | Progress bar + "✦ Getting started" + target shown but no actual rate yet |
| **Rest day** | Review-only day | "Review day" badge |

---

## Data Source

```dart
/// From trackProgressProvider(trackId) when variant == velocityGoal
TrackProgress {
  double scopePercentage;
  int completedItems;
  int totalItems;
  PaceStatus paceStatus;       // status type + daysDelta (weekly surplus/deficit)
  double actualRate;            // current rolling average in goal units
  double targetRate;            // user's target in goal units
  String rateUnit;              // 'per_day' or 'per_week'
  ChazaraStatus? chazaraStatus;
  int tasksToday;
}
```

---

_Created using Whiteport Design Studio (WDS) methodology_
