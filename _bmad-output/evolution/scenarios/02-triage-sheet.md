# Triage Sheet

## Target

The multi-track recovery surface. When a learner is behind on 3+ tracks (S11 Multi-Track Overload) or returns after 14+ days of dormancy (S9 Returning Learner), the app presents a guided sequence that walks through each out-of-sync track and collects a quick decision per track. Triage replaces the current dashboard's undifferentiated display of multiple struggling tracks with a structured, bounded workflow that completes in ~90 seconds for a 4-track user.

## Current State

Today, a multi-track learner who is behind on several tracks sees:
- Each track card independently showing its own recovery action button
- No coordination between tracks — no awareness that the learner is overwhelmed
- No ordering logic — tracks appear in creation order, not by urgency
- No way to batch decisions across tracks
- No consolidated "you're back" experience after dormancy
- The dashboard looks like "a panic attack" (per S11 narrative) when multiple tracks are in debt

## Desired State

A full-screen or near-full-screen modal sheet that:

1. **Presents one track at a time** in a card-swipe or vertical-scroll sequence
2. **Orders tracks by triage priority**: program tracks first (amnesty decisions are heavier), smallest-debt-first within each group, then self-paced tracks smallest-debt-first
3. **Offers per-track quick actions** — 2-3 buttons per card, adapted to track mode:
   - Program track: `[Amnesty all]` `[Catch up]` `[Skip for now]`
   - Self-paced with goal: `[Rescope]` `[Push harder]` `[Skip for now]`
   - Dormant 60+ days (ghosted): `[Revive]` `[Archive]` `[Skip for now]`
4. **Allows drill-down** — "Details" opens the Catch-up Sheet for that specific track
5. **Supports pause-during-triage** — pausing a track drops it from the sequence immediately (NQ4 resolved)
6. **Tracks progress** — "3 of 4 tracks handled" indicator
7. **Supports interruption** — "Pause triage" saves progress; next app open resumes where the learner left off
8. **Offers bulk actions** as a secondary option — "Reset pace on all self-paced" / "Amnesty all chazara debt older than 60 days" with per-track confirmation chips

## User Journey

### Entry points
- **Auto-trigger on app open**: when `count(tracks where primary != "normal") >= 3` (S11) or `sessionIsFirstAfterGap(>14 days)` (S9)
- **Manual from dashboard**: triage banner card at top of dashboard when conditions met
- **From Returning Learner onboarding**: welcome-back screen routes into triage

### Flow

```
1. Triage banner appears atop dashboard (or auto-opens on dormancy return)
   "Quick triage: handle all 4 tracks in 2 minutes"
   [Start triage]  [Not now]

2. Full-screen triage view opens
   Progress: "Track 1 of 4"

3. First card (program track, smallest debt):
   ┌─────────────────────────────────────┐
   │  Daf Yomi Bavli — 5 dapim behind   │
   │  (program · smallest debt)          │
   │                                     │
   │  [Amnesty all 5]  [Catch up]        │
   │  [Details...]     [Skip for now]    │
   └─────────────────────────────────────┘
   
   Learner taps [Amnesty all 5] → brief confirmation → card slides left

4. Second card (program track, larger debt):
   ┌─────────────────────────────────────┐
   │  School Gemara — 18 dapim behind    │
   │  (program)                          │
   │                                     │
   │  [Amnesty all 18]  [Catch up]       │
   │  [Details...]      [Pause track]    │
   └─────────────────────────────────────┘

   Learner taps [Pause track] → duration picker → track paused, 
   drops from triage immediately → "Track 2 of 3" (count adjusts)

5. Third card (self-paced):
   ┌─────────────────────────────────────┐
   │  Personal Mishna Berurah — 6 days   │
   │  (self-paced · pace goal)           │
   │                                     │
   │  [Rescope]  [Push harder]           │
   │  [Details...]  [Skip for now]       │
   └─────────────────────────────────────┘

6. After last card → summary screen:
   "Triage complete — 3 tracks handled"
   Per-track summary of actions taken
   [Done]  [Undo last]

7. Dashboard refreshes with updated debt states
```

### Bulk action flow (alternative path)

```
At any point during triage, a "Bulk actions" button is available:

[Bulk actions]
  → "Reset pace on all self-paced tracks" — shows affected tracks as chips, 
     learner confirms per-track by tapping ✓/✗ on each chip
  → "Amnesty all chazara debt > 60 days" — same chip confirmation pattern
  → [Apply]  [Cancel]
```

### Interruption flow

```
Learner swipes down or taps [Pause triage]:
  → Progress saved (which tracks handled, which skipped)
  → Next app open: "Resume triage? 2 tracks remaining" banner
  → Or: triage conditions re-evaluated — if debt resolved, banner disappears
```

## Success Criteria

- 4-track triage completes in ≤ 90 seconds (measured as time from triage open to summary screen)
- Program tracks always appear before self-paced tracks
- Within each group, smallest-debt-first ordering
- Pausing a track during triage drops it from the sequence immediately
- "Skip for now" is always available — learner is never trapped
- Bulk actions require per-track confirmation (chips, not automatic)
- Interrupted triage can resume on next session
- Dashboard debt counts update immediately after triage completion
- All actions logged to `track_action_log` with source `"triage"`

## Scope

### Pages affected
- **Dashboard screen** — triage banner injection point (top of screen, above track cards)
- New: **Triage sheet** (full-screen modal or route — the primary new surface)
- New: **Triage summary screen** (end-of-triage recap)
- Existing: **Catch-up sheet** — opened via "Details" drill-down from triage cards

### Components touched
- New: `TriageBanner` — dashboard-level card that triggers triage
- New: `TriageSheet` — full-screen modal with card sequence
- New: `TriageTrackCard` — per-track decision card with mode-adaptive actions
- New: `TriageProgress` — "N of M tracks" indicator
- New: `TriageSummary` — completion recap with per-track action log
- New: `BulkActionPanel` — chip-based per-track confirmation for bulk operations
- Reuses: `PauseOfferPrompt` (from Catch-up Sheet), `CatchupSheet` (drill-down)

### Data changes
- Reads: `TrackDebt` for all active tracks, sorted by triage priority
- Writes: per-track `rescope()`, `item_amnesty` bulk inserts, `paused_at`/`paused_until`, `track_action_log` entries with source `"triage"`
- New: triage session state (in-memory or lightweight persistence for resume-after-interrupt)

### Risk level
**Medium-High** — new full-screen flow with session state, ordering logic, and multi-track writes. The card-per-track pattern is straightforward, but the bulk action confirmation and triage interruption/resume add complexity.

## Design decisions to resolve during specification

1. **Card navigation**: horizontal swipe (like onboarding pages) or vertical scroll list? (Lean: horizontal swipe — enforces one-at-a-time focus, matches the "quick decision per track" mental model)
2. **Triage session persistence**: in-memory only (lost on app kill) or persisted to local storage? (Lean: lightweight local storage — triage is precious state the learner shouldn't have to redo)
3. **"Skip for now" semantics**: does skipped track appear in next triage, or only if conditions still hold on next session? (Lean: re-evaluated on next session — skipping isn't a decision, just a deferral)
4. **Bulk action placement**: always visible, or revealed after first manual action? (Lean: available from start as a secondary action, but visually deemphasized until the learner has seen at least one card)
5. **Notification suppression during pending triage**: S11 says all per-track notifications are suppressed while triage is pending and replaced by a single "triage awaits" nudge. How does this interact with pause? (Lean: triage-pending suppression is session-scoped, not persisted — if the learner doesn't open the app for days, the "triage awaits" nudge fires once daily max)
