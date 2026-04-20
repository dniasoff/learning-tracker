# 02 — Track Card: Program Calendar Variant

**Parent:** [01-dashboard.md](01-dashboard.md) > Section: Your Tracks
**Applies to:** Scenarios P1-P4 (all program tracks)

---

## Overview

Displays progress for tracks joined to a structured learning program (Daf Yomi, Oraysa, Dirshu, etc.). The primary metric is **calendar position** — where you are in the cycle vs where you should be.

**Design principle:** "Show don't ask" — program-defined configuration is displayed as fact, not as editable options.

---

## Variant Selection

This card renders when `track.programId != null`.

---

## Layout

```
┌─ {curriculum color} border ────────────────────┐
│                                                  │
│  {trackLabel}                  {curriculum chip} │
│                                                  │
│  {todayDisplayHe}                                │
│  Day {currentDay} / {totalDays}                  │
│  {statusIcon} {statusText}                       │
│  ──────────────────────────────────────────────  │
│  {chazaraLine}              ← only if applicable │
│  ──────────────────────────────────────────────  │
│  Today: {N} tasks                 [Continue ->]  │
│                                                  │
│  {recoveryAction}           ← only if 5+ behind │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Content Specification

### Row 1: Track Label + Curriculum

| Element | Spec |
|---------|------|
| Track label | `titleMedium` (16sp), w500. Value: track's user-defined label (e.g., "דף היומי") |
| Curriculum chip | `labelSmall` (11sp), outlined chip. Value: curriculum `displayNameHe` (e.g., "בבלי") |
| Alignment | Label left, chip right |

### Row 2: Today's Content Reference

| Element | Spec |
|---------|------|
| Content | `todayDisplayHe` from `CalendarPosition` (e.g., "בבא קמא דף מ״ב") |
| Style | `bodyLarge` (16sp), normal weight |
| Direction | RTL |

### Row 3: Cycle Position

| Element | Spec |
|---------|------|
| Content | "Day {currentDay} / {totalDays}" |
| Style | `bodyMedium` (14sp), `onSurfaceVariant` color |

### Row 4: Status

| Status | Icon | Text | Color |
|--------|------|------|-------|
| Caught up | ✓ (check circle) | "Caught up" | `success` (green) |
| Ahead | ↑ (arrow up) | "{N} ahead" | `success` (green) |
| 1-4 behind | ⚠ (warning) | "{N} behind" | `warning` (amber) |
| 5+ behind | ⚠ (warning) | "{N} behind" | `error` (red) |

Style: `bodyMedium` (14sp), weight w500.

### Row 5: Chazara Line (conditional)

**Show when:** Track has chazara configured (prescribed or user-added).
**Hide when:** No chazara stages defined.

| Chazara State | Content | Color |
|--------------|---------|-------|
| All caught up | "חזרה: caught up ✓" | `success` |
| Due today, none overdue | "חזרה: {N} due today" | Default |
| Overdue exist | "חזרה: {N} overdue" | `warning` |
| 5+ overdue | "חזרה: {N} overdue ⚠" | `error` |

Style: `bodySmall` (12sp).

### Row 6: Footer

| Element | Spec |
|---------|------|
| Left | "Today: {N} tasks" (`bodySmall`, `onSurfaceVariant`) |
| Right | "Continue ->" (`FilledTonalButton`, `labelMedium`) |

### Recovery: Jump to Today (conditional)

| Element | Spec |
|---------|------|
| Visible | When delta <= -5 (5+ items behind) |
| Text | "Jump to today" |
| Style | `TextButton`, `bodySmall`, `primary` color |
| Position | Below footer row, centered |
| Action | Confirmation dialog -> reset calendar position to today |
| Dialog text | "Skip to today's position? Missed items won't be marked as completed." |
| Dialog actions | "Cancel" / "Jump to Today" |

---

## States

| State | Condition | Display |
|-------|-----------|---------|
| **Normal** | Caught up or slightly ahead/behind | Standard layout |
| **Behind** | 1-4 items behind | Status in amber |
| **Severely behind** | 5+ items behind | Status in red, "Jump to today" action visible |
| **New track** | Track just created, no completions | "Day 1 / {total}" + "✦ Ready to start" status |
| **Cycle complete** | currentDay >= totalDays | "🎉 Cycle complete!" status, no tasks |
| **Rest day** | Today is not a study day for this track | "Review day" badge, only chazara tasks shown |

---

## Data Source

```dart
/// From trackProgressProvider(trackId) when variant == programCalendar
CalendarPosition {
  int currentDay;          // User's actual position in cycle
  int totalDays;           // Total days in program cycle
  String todayRef;         // Sefaria ref for today's expected item
  String todayDisplayHe;   // Hebrew display text
  int delta;               // positive = ahead, negative = behind
  CalendarStatus status;   // caughtUp, ahead, behind
}
```

---

## Program Examples

| Program | Curriculum | totalDays | Chazara | Card Shows |
|---------|-----------|-----------|---------|-----------|
| Daf Yomi | bavli | 2,711 | None (open) | Position + no chazara line |
| Oraysa | bavli | 2,711 | 4 stages (prescribed) | Position + chazara compliance |
| Dirshu Kinyan Torah | bavli | 2,711 | 3 stages (prescribed) | Position + chazara compliance |
| Mishnah Yomis | mishnayos | ~2,000 | None (open) | Position + no chazara line |
| Nach Yomi | nach | ~929 | None (open) | Position + no chazara line |

---

_Created using Whiteport Design Studio (WDS) methodology_
