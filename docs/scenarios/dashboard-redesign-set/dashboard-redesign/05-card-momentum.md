# 05 — Track Card: Momentum Variant

**Parent:** [01-dashboard.md](01-dashboard.md) > Section: Your Tracks
**Applies to:** Scenarios S3, S4 (self-paced with no goal set)

---

## Overview

Displays progress for self-paced tracks with no explicit goal. The user is learning at their own rhythm with no deadline or pace target. The primary signal is **personal momentum** — measured against the user's own historical average, never against an arbitrary standard.

**Design principle:** Gentle, never punishing. "Paused" not "stalled." "Slowing" not "failing." The user chose no goal — the system respects that choice and provides soft feedback.

---

## Variant Selection

This card renders when `track.programId == null && track.goalType == null`.

---

## Layout

```
┌─ {curriculum color} border ────────────────────┐
│                                                  │
│  {trackLabel}                  {curriculum chip} │
│                                                  │
│  ████████████░░░░░░░░  {pct}%                    │
│  {completed} / {total} items complete            │
│  {momentumText}                                  │
│  {statusIcon} {statusText}                       │
│  ──────────────────────────────────────────────  │
│  {chazaraLine}              ← only if applicable │
│  ──────────────────────────────────────────────  │
│  Today: {N} tasks                 [Continue ->]  │
│                                                  │
│  {resetPaceAction}       ← only if paused 14d+  │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Content Specification

### Row 1: Track Label + Curriculum

Same as other variants.

### Row 2: Progress Bar + Percentage

Same as deadline/velocity variants. Scope progress bar + percentage.

### Row 3: Item Count

Same as other variants. "{completed} / {total} items complete."

### Row 4: Momentum Text

| Element | Spec |
|---------|------|
| Content | "{recentCount} this week · avg {personalAvg}/week" |
| Examples | "3 this week · avg 2.5/week" or "0 this week · avg 2.5/week" |
| Style | `bodyMedium` (14sp) |
| Note | "week" = last 7 days (rolling, not calendar week) |

**When not enough data (< 3 completions ever):**
- Show: "{completedItems} completed so far" (no average line)

### Row 5: Status

| Status | Condition | Icon | Text | Color |
|--------|-----------|------|------|-------|
| **Getting started** | < 3 completions total | ✦ (sparkle) | "Getting started" | `primary` (blue) |
| **Active** | recentCount >= personalAvg * 0.8 | ✓ | "Active" | `success` (green) |
| **Slowing** | recentCount < personalAvg * 0.8, recentCount > 0 | → | "Slowing" | `warning` (amber) |
| **Paused** | 0 completions in last 3+ days | ⏸ | "Paused · last: {N} days ago" | `onSurfaceVariant` (gray, neutral) |

Style: `bodyMedium` (14sp), w500.

**Momentum calculation:**

```
recentCount = completions in last 7 days (for this track)
personalAvg = average completions per 7-day window over last 30 days
  if track < 14 days old: use all available data
  if < 3 completions ever: status = gettingStarted (skip calculation)

daysSinceLastCompletion = today - lastCompletionDate

Level determination:
  if totalCompletions < 3       → gettingStarted
  if recentCount == 0 && daysSince >= 3 → paused
  if recentCount >= avg * 0.8   → active
  else                          → slowing
```

### Row 6: Chazara Line (conditional)

Same spec as other variants.

### Row 7: Footer

Same spec as other variants.

### Recovery: Reset Pace (conditional)

| Element | Spec |
|---------|------|
| Visible | When status is "Paused" for 14+ days |
| Text | "Reset pace" |
| Style | `TextButton`, `bodySmall`, `primary` color |
| Position | Below footer row, centered |
| Action | Confirmation dialog -> reset momentum baseline |
| Dialog text | "Start measuring your pace from today? Overdue reviews will still be scheduled." |
| Dialog actions | "Cancel" / "Reset Pace" |
| Effect | Clears personal average history. Status becomes "✦ Getting started" while new baseline builds over 14 days. |

---

## States

| State | Condition | Display |
|-------|-----------|---------|
| **Getting started** | < 3 completions total | Blue sparkle status, no momentum line |
| **Active** | Recent >= 80% of personal average | Green status |
| **Slowing** | Recent < 80% of average, but > 0 | Amber status |
| **Paused < 14d** | No completions in 3-13 days | Gray status, no recovery action |
| **Paused 14d+** | No completions in 14+ days | Gray status + "Reset pace" action |
| **Complete** | All scoped items done | "🎉 Complete!" |
| **Rest day** | Review-only day | "Review day" badge |

---

## Tone Guide

The momentum card is the most psychologically sensitive variant. Users chose not to set a goal — they don't want pressure. The language must be:

| DO | DON'T |
|----|-------|
| "Active" | "On track" (implies a track to be on) |
| "Slowing" | "Falling behind" (behind what?) |
| "Paused" | "Stalled" / "Inactive" / "Stopped" |
| "Getting started" | "Not enough data" |
| "3 this week" | "Only 3 this week" |
| "last: 5 days ago" | "5 days since last activity!" |

**No exclamation marks on negative states.** No comparative language ("you used to do X"). Just facts, gently presented.

---

## Data Source

```dart
/// From trackProgressProvider(trackId) when variant == momentum
TrackProgress {
  double scopePercentage;
  int completedItems;
  int totalItems;
  MomentumStatus momentum;
  ChazaraStatus? chazaraStatus;
  int tasksToday;
}

MomentumStatus {
  int recentCount;             // completions in last 7 days
  double personalAverage;      // avg per 7-day window, last 30 days
  MomentumLevel level;         // gettingStarted, active, slowing, paused
  int? daysSinceLastCompletion;
}
```

---

_Created using Whiteport Design Studio (WDS) methodology_
