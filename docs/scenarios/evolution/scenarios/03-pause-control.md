> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

# Pause Control

## Target

The only silence mechanism in the app. Pause is a first-class track state — distinct from Archive — where the learner deliberately silences a track for a chosen duration. Every recovery flow (Catch-up Sheet, Triage, Returning Learner) offers pause as an explicit companion action, but pause is never imposed automatically. This surface covers the duration picker at pause-time and the resume UI at expiry.

## Current State

Today there is no pause mechanism:
- The only way to stop notifications from a track is to archive it (permanent, requires explicit revival)
- Recovery actions (Reset pace) don't offer any silence period
- A learner who is overwhelmed and wants quiet must either ignore notifications or archive the track entirely
- There is no concept of "I'll be back in a week" — the gap between "active" and "archived" has nothing in between

## Desired State

A lightweight pause system with two surfaces:

### Pause picker (entry)
A compact bottom sheet or inline control that lets the learner:
1. **Choose duration**: preset chips (1 day / 3 days / 1 week / 2 weeks) + custom date picker + indefinite
2. **See what pause means**: one-line explanation — "No notifications. Pace clock stops. Your learning is safe."
3. **Confirm with one tap** on a preset, or two taps for custom/indefinite

### Resume UI (exit)
When a fixed-duration pause expires:
1. **On next app open**: a gentle card at the top of the dashboard or within the track card — "Welcome back to [Track Name]. Ready to continue?"
2. **Tone**: supportive and action-oriented per NQ3 — "Ready to get back on track? Let's see where things stand."
3. **Actions**: `[Resume]` (one-tap, track becomes active) / `[Extend pause]` (reopens duration picker) / `[Archive]` (if they're done)
4. **If debt accumulated during pause**: resume routes to the Catch-up Sheet for that track

For indefinite pause:
- Track stays paused until explicit resume from Track Settings or Track Detail
- No auto-prompt — the learner decides when

## User Journey

### Pause entry points
- **From Catch-up Sheet**: follow-up prompt after any recovery action — "Pause this track for a week?"
- **From Triage Sheet**: per-track action `[Pause track]` — pausing drops the track from triage (NQ4)
- **From Track Detail screen**: explicit pause toggle in the track header or settings section
- **From Track Settings panel**: pause control alongside other per-track settings

### Pause flow

```
1. Learner taps [Pause] from any entry point

2. Pause picker appears (compact bottom sheet):
   ┌─────────────────────────────────────┐
   │  Pause Daf Yomi Bavli               │
   │  No notifications. Pace clock stops. │
   │                                      │
   │  [1 day] [3 days] [1 week] [2 weeks]│
   │  [Custom...]  [Indefinite]           │
   └─────────────────────────────────────┘

3. Learner taps [1 week]:
   → track.paused_at = now
   → track.paused_until = now + 7 days
   → Snackbar: "Paused for 1 week. Resumes [date]." [Undo]
   → Sheet closes

4. Dashboard: track card shows paused state
   - Muted visual treatment (reduced opacity or gray overlay)
   - Badge: "Paused until [date]"
   - Tap opens Track Detail, not the scheduler
```

### Resume flow (auto-expire)

```
1. Pause expires (paused_until reached)

2. On next app open, dashboard shows resume card:
   ┌─────────────────────────────────────┐
   │  ▶ Daf Yomi Bavli is ready          │
   │  "Ready to get back on track?"       │
   │                                      │
   │  [Resume]  [Extend pause]  [Archive] │
   └─────────────────────────────────────┘

3. [Resume] → track.paused_at = null, paused_until = null
   → If debt accumulated during pause: opens Catch-up Sheet
   → Otherwise: track returns to normal dashboard state

4. [Extend pause] → reopens duration picker

5. [Archive] → confirmation dialog → track archived
```

### Resume flow (manual, indefinite pause)

```
1. Learner goes to Track Detail or Track Settings
2. Sees: "This track is paused (indefinite)" with [Resume] button
3. Taps [Resume] → same logic as auto-expire resume
```

## Success Criteria

- Pause is reachable from every recovery flow (Catch-up, Triage, Track Detail, Settings) — max 2 taps from any entry point
- Duration selection completes in one tap (presets) or two taps (custom/indefinite)
- Paused track produces zero notifications until resumed
- Paused track is excluded from triage sequences
- Pace clock stops during pause — `daysBehind` does not increase while paused
- Welcome-back card appears on first app open after pause expiry — never a notification
- Dashboard visually distinguishes paused tracks (muted treatment)
- Undo available for 5 seconds after pausing

## Scope

### Pages affected
- **Dashboard screen** — paused track visual treatment + resume card on expiry
- **Track detail screen** — pause toggle / resume button
- **Track settings panel** — pause control
- **Catch-up sheet** — pause offer after recovery actions
- **Triage sheet** — per-track pause action

### Components touched
- New: `PausePicker` — compact bottom sheet with duration presets + custom + indefinite
- New: `PauseResumeCard` — dashboard card shown on pause expiry
- New: `PausedTrackOverlay` — visual muting for paused track cards on dashboard
- Existing: Track card — conditional paused state rendering
- Existing: `PauseOfferPrompt` (defined in Catch-up Sheet scope) — reused here

### Data changes
- Writes: `paused_at`, `paused_until` on `curriculum_tracks`
- Writes: `track_action_log` entry with action_type `"pause"` / `"resume"`
- Reads: pause state checked in notification system (paused → suppress all), triage system (paused → exclude), debt computation (paused → freeze pace clock)

### Risk level
**Low-Medium** — small, self-contained surface. The data model is simple (two nullable datetime columns). The main integration risk is ensuring all notification paths, triage logic, and debt computation consistently check pause state.

## Design decisions to resolve during specification

1. **Paused track position on dashboard**: keep in place with muted treatment, or move to bottom of track list? (Lean: keep in place but muted — moving creates confusion about track order)
2. **Custom duration**: date picker or "N days" stepper? (Lean: date picker — the learner thinks in terms of "resume after Pesach" not "pause for 12 days")
3. **Resume card persistence**: shown once and dismissed, or persistent until acted on? (Lean: persistent until acted on — the learner needs to make an explicit decision, but dismissible with "not now" which re-shows next session)
4. **Pause from notification**: can the learner pause a track directly from a notification action? (Lean: yes — reduces friction, but only with the default 7-day duration, not the full picker)
