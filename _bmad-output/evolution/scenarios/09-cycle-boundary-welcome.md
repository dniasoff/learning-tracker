# Cycle-boundary Welcome Flow

## Target

A one-time flow shown when a program track's cycle ends and a new one begins (e.g., a new Daf Yomi cycle starting every ~7.5 years). The default behavior is **auto-fresh slate** — old amnesties remain in the data tagged with the previous cycle but are no longer active. This flow gives the learner the explicit option to carry forward previous amnesties or start clean.

This is a rare event (once per cycle per program track) but a significant moment in the learner's journey — it deserves a deliberate, clear experience rather than silent automatic behavior.

## Current State

Today there is no cycle concept in the app:
- No `current_cycle_tag` on tracks
- No cycle-scoped amnesty records
- No awareness that a program like Daf Yomi has a multi-year cycle
- If this existed today, the learner would have no way to distinguish "skipped in cycle 13" from "skipped in cycle 14"

## Desired State

A one-time interstitial (similar in spirit to Returning Learner) that:

1. **Triggers on first engagement after a cycle boundary**: detected by comparing `current_cycle_tag` on the track with the program's computed current cycle
2. **Celebrates the cycle completion** (if the learner participated in the previous cycle): "Cycle 13 complete. You learned X dapim and completed Y masechtos."
3. **Explains the fresh slate default**: "Your skipped items from Cycle 13 are archived. Cycle 14 starts with a clean slate."
4. **Offers carry-forward option**: "Want to carry any previous amnesty decisions into the new cycle?" — the learner can choose to re-amnesty specific items from the previous cycle (so they don't get counted as debt again in the new cycle)
5. **Updates the cycle tag**: sets `current_cycle_tag` to the new cycle identifier

## User Journey

### Entry point
- **Auto-trigger on app open**: when a program track's `current_cycle_tag` doesn't match the program's computed current cycle

### Flow

```
1. App opens → cycle boundary detected on [Daf Yomi Bavli]

2. Cycle-boundary welcome screen:
   ┌──────────────────────────────────────┐
   │                                      │
   │  A new cycle begins.                 │
   │  Welcome to Daf Yomi Cycle 14.       │
   │                                      │
   │  In Cycle 13, you learned 1,842      │
   │  dapim and completed 12 masechtos.   │
   │                                      │
   │  Your 42 skipped items from Cycle 13 │
   │  are archived. This cycle starts     │
   │  fresh — nothing is "behind."        │
   │                                      │
   │  [Start fresh]                       │
   │     Clean slate. Cycle 14, day 1.    │
   │                                      │
   │  [Carry forward skipped items]       │
   │     Keep previous amnesty decisions  │
   │     active in Cycle 14.              │
   │                                      │
   │  [Review previous cycle]             │
   │     Browse what you skipped before   │
   │     deciding.                        │
   │                                      │
   └──────────────────────────────────────┘

3a. [Start fresh] → 
    track.current_cycle_tag = "cycle-14"
    → Previous amnesty records keep their old cycle_tag (inert)
    → Snackbar: "Cycle 14 started. Clean slate."
    → Dashboard

3b. [Carry forward] → 
    Bulk copy: previous cycle's amnesty records duplicated with new cycle_tag
    → Learner can optionally review/edit the list before confirming
    → track.current_cycle_tag = "cycle-14"
    → Dashboard

3c. [Review previous cycle] → 
    Opens Amnesty History view filtered to previous cycle
    → Learner browses, optionally selects items to carry forward
    → Returns to this screen → then [Start fresh] or [Carry forward selected]
```

### Edge case: learner who didn't participate in previous cycle

```
If the learner has zero completions in the previous cycle 
(e.g., joined mid-cycle or was dormant for the entire cycle):

   ┌──────────────────────────────────────┐
   │                                      │
   │  A new Daf Yomi cycle is starting.   │
   │  Cycle 14, day 1.                    │
   │                                      │
   │  [Start tracking from today]         │
   │  [Set up from a different point]     │
   │     → Routes to Setup Seeding (S14)  │
   │                                      │
   └──────────────────────────────────────┘
```

## Success Criteria

- Flow triggers exactly once per cycle boundary per track — never repeats
- Previous cycle's amnesty records are preserved in the data (never deleted), just scoped to the old cycle
- "Start fresh" is the default and easiest path (one tap)
- "Carry forward" is available for learners who want continuity
- "Review previous cycle" links to Amnesty History with appropriate filter
- Cycle tag update is atomic — no inconsistent state between old and new cycle
- Celebratory tone for learners who participated; neutral for new/dormant learners

## Scope

### Pages affected
- New: **Cycle Boundary Welcome screen** (full-screen interstitial — the primary new surface)
- Composes: **Amnesty History view** (for "review previous cycle" drill-down)
- Composes: **Setup Seeding flow** (for the "set up from a different point" edge case)

### Components touched
- New: `CycleBoundaryScreen` — full-screen interstitial with cycle stats and choices
- New: `CycleDetector` — service that compares `current_cycle_tag` with computed current cycle
- New: `CycleCarryForwardSheet` — optional list editor for selecting which amnesty records to carry forward
- Reuses: `AmnestyHistoryScreen` (filtered to previous cycle), `SetupSeedingScreen` (S14 variant)

### Data changes
- Reads: `current_cycle_tag`, previous cycle's `item_amnesty` records, lifetime completion stats per cycle
- Writes: `current_cycle_tag` update on `curriculum_tracks`
- Writes (carry-forward only): new `item_amnesty` records duplicated with new `cycle_tag`
- Writes: `track_action_log` with action_type `"cycle_transition"`

### Risk level
**Low** — rare event, simple interstitial, small data operations. The main complexity is the cycle detection logic (computing current cycle from program metadata) and the carry-forward bulk copy. Testing is harder because the event is rare — needs synthetic test scenarios.

## Design decisions to resolve during specification

1. **Cycle detection source**: where does the app learn that a new Daf Yomi cycle has started? Hardcoded dates? Server-side program metadata? (Lean: program metadata with known cycle boundaries — Daf Yomi has a fixed 7.5-year schedule computed from the start date)
2. **Carry-forward granularity**: all-or-nothing, or per-item selection? (Lean: default is all-or-nothing, with "Review previous cycle" as the path to per-item selection)
3. **Multiple program tracks**: if the learner has two program tracks hitting cycle boundaries at the same time, sequential flows or combined? (Lean: sequential — each track gets its own welcome, in triage order)
4. **Notification**: should the cycle boundary trigger a notification if the learner hasn't opened the app? (Lean: yes, one celebratory push — "A new Daf Yomi cycle begins today!" — with deep link to this flow)
