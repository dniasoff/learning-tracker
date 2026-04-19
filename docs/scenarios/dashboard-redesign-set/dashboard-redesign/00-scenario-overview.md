# Scenario: Dashboard Redesign

> ⚠️ **Status — 2026-04-19:** Epic 20 (DNI-210) was canceled 2026-04-15 (all 12 child stories). The per-track data infrastructure partially landed via Epic 23 and Epic 21, but the dashboard UI redesign specified in this set is **not shipped**. Use this scenario set as a design reference if Epic 20 is re-scoped.

## Core Feature

Multi-track dashboard that gives per-track progress feedback across 4 distinct track variants (program calendar, deadline, velocity, momentum), a unified cross-track task list, and recovery actions for users who fall behind.

## Entry Point

App launch (warm resume < 2s). User lands on dashboard as the home screen.

## User Mental State

"What should I do right now? Am I making progress?" — The user opens the app wanting immediate clarity on their learning state across all tracks.

## Success Criteria

User glances at dashboard and within 3 seconds knows:
1. What to do next (task list)
2. How each track is doing (card status)
3. Whether they need to catch up on anything (overdue indicators)

## Shortest Path

Open app -> see task list -> tap done on first task -> feel progress -> repeat

## Pages

| # | Page | Status |
|---|------|--------|
| 01 | Dashboard (main) | Designing |
| 02 | Track Card — Program Calendar Variant | Designing |
| 03 | Track Card — Deadline Variant | Designing |
| 04 | Track Card — Velocity Variant | Designing |
| 05 | Track Card — Momentum Variant | Designing |

## Design Decisions (from analysis)

- **Track isolation:** Complete. Each track owns its completions, stages, study days, goals, scopes.
- **Cards:** One card per track, vertical scroll, always full cards.
- **Stats row:** Tasks completed/total (8/12). Streak. Points (child only).
- **Task list:** Unified across all tracks, priority-sorted, track label on each task.
- **Lifetime view:** Curriculum-based (no track labels), includes review counts.
- **Recovery:** "Jump to today" (program), "Reset pace" (self-paced). No clearing overdue chazara.

## Reference Documents

- [Dashboard & Progress Redesign Analysis](../../../flows/dashboard-redesign-analysis.md)
- [AddTrackFlow Developer Reference](../../../flows/add-track-flow.md)
- [UX Patterns Quick Reference](../../../planning/ux-patterns-quick-reference.md)
- [Component Inventory](../../../component-inventory.md)
