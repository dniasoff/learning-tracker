> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

# Returning Learner Onboarding

## Target

A session-level welcome-back experience for learners who return after 14+ days of dormancy (S9). This is not a standalone screen — it is a **wrapper flow** that intercepts the normal app-open experience, shows a warm welcome, and then routes into Triage (if multi-track) or the Catch-up Sheet (if single-track). The emotional framing is the point: the learner should feel welcomed, not shamed.

Per NQ3 (resolved): dormancy-return tone is warm re-engagement with no judgement — "Great to see you again!" — and routes to triage. Distinct from pause-return, which is supportive and action-oriented.

## Current State

Today:
- A learner who returns after weeks of absence sees the normal dashboard with accumulated debt counters
- No welcome-back experience — the app behaves identically whether the learner was gone 1 day or 60 days
- The streak recovery banner shows if the streak was protected, but there is no broader re-engagement flow
- Multiple behind-counters across tracks create the "panic attack" dashboard (S11 narrative)
- No lifetime progress summary to anchor the learner's confidence

## Desired State

A one-time interstitial that:

1. **Detects dormancy on app open**: `daysDormant > 14` on at least one track AND this is the first session after the gap
2. **Shows a warm welcome** with zero debt numbers:
   - Greeting: "Great to see you again!"
   - Lifetime progress summary: "You've learned X items across Y tracks" — factual, understated, not praise
   - No behind-counts, no red, no banners
3. **Offers a gentle onramp** with clear next steps:
   - If multi-track (≥ 2 tracks in debt): route to Triage Sheet
   - If single track: route to Catch-up Sheet for that track
   - Always available: "Just browse" — dismiss and explore the dashboard with no forced actions
4. **Offers pause as an explicit choice**: "Pause everything for a week while you get re-oriented?" — with duration options, but not imposed
5. **Shows once per dormancy gap** — if the learner dismisses without acting, the welcome does not reappear (but triage banner persists on dashboard if conditions still hold)

## User Journey

### Entry point
- **Auto-trigger on app open**: detected by comparing last session timestamp (or last completion timestamp across all tracks) with a 14-day threshold

### Flow — Multi-track

```
1. App opens → dormancy detected (14+ days gap)

2. Welcome screen (full-screen interstitial):
   ┌──────────────────────────────────────┐
   │                                      │
   │     Great to see you again!          │
   │                                      │
   │     You've learned 142 items         │
   │     across 3 tracks.                 │
   │     That's real progress.            │
   │                                      │
   │  ┌────────────────────────────────┐  │
   │  │ Let's get you sorted.          │  │
   │  │ Quick triage: 3 tracks need    │  │
   │  │ a decision — takes ~2 min.     │  │
   │  │                                │  │
   │  │ [Start triage]                 │  │
   │  └────────────────────────────────┘  │
   │                                      │
   │  [Pause everything for a week]       │
   │  [Just browse]                       │
   │                                      │
   └──────────────────────────────────────┘

3a. [Start triage] → Triage Sheet opens → normal triage flow

3b. [Pause everything for a week] → PausePicker for all tracks 
    (bulk pause with default 7 days, customizable)
    → All tracks paused → dashboard shows paused state
    → Welcome dismissed

3c. [Just browse] → Welcome dismissed → normal dashboard
    → Triage banner visible at top if conditions still hold
```

### Flow — Single-track

```
1. Same welcome screen but instead of triage:

   ┌──────────────────────────────────────┐
   │                                      │
   │     Great to see you again!          │
   │                                      │
   │     You've learned 38 dapim          │
   │     of Bavli Berachos.               │
   │                                      │
   │  [Quick reboot]     — fresh start    │
   │  [Gentle resume]    — rescope only   │
   │  [Ambitious catch-up] — close gap    │
   │  [Just browse]                       │
   │                                      │
   └──────────────────────────────────────┘

2. Any action → opens Catch-up Sheet pre-configured for that choice
   Or [Just browse] → dismiss → dashboard
```

### Pause-return variant (NQ3 — distinct tone)

```
When a fixed-duration pause expires and the learner opens the app:

   ┌──────────────────────────────────────┐
   │                                      │
   │  Ready to get back on track?         │
   │  Let's see where things stand.       │
   │                                      │
   │  [Start triage]                      │
   │  [Extend pause]                      │
   │  [Just browse]                       │
   │                                      │
   └──────────────────────────────────────┘

Same skeleton as dormancy return, but:
- Tone: supportive + action-oriented (not warm re-engagement)
- No lifetime stats (the learner knows what they've done — they paused deliberately)
- Routes to triage or catch-up sheet same as dormancy variant
```

## Success Criteria

- Welcome screen appears within 1 second of app open when dormancy threshold is met
- Zero debt numbers visible on the welcome screen
- Lifetime progress stats are shown (factual, understated)
- Triage route is offered for multi-track; Catch-up Sheet for single-track
- "Just browse" always available — learner is never trapped
- Pause offer is explicit, with duration choice, never automatic
- Welcome shows once per dormancy gap — no repeat on next session
- Dormancy-return and pause-return are visually similar but tonally distinct (per NQ3)

## Scope

### Pages affected
- New: **Returning Learner Welcome screen** (full-screen interstitial — the primary new surface)
- New: **Pause-Return Welcome card** (variant — may be same screen with different content, or a dashboard card)
- Existing: **Dashboard screen** — interstitial injection point on app open
- Composes: **Triage Sheet**, **Catch-up Sheet**, **Pause Picker** (all defined in other scenarios)

### Components touched
- New: `ReturningLearnerScreen` — full-screen welcome interstitial
- New: `PauseReturnCard` — dashboard card variant for pause expiry
- New: `LifetimeProgressSummary` — reusable stat block (total items, tracks, masechtos)
- New: `DormancyDetector` — session-level check on app open (provider or service)
- Reuses: `TriageSheet`, `CatchupSheet`, `PausePicker` (all from other scenarios)

### Data changes
- Reads: last session timestamp, `TrackDebt` for all tracks, lifetime completion counts
- Writes: session flag ("welcome shown for this dormancy gap" — prevents repeat)
- No direct data mutations — this screen routes to other surfaces that do the actual writes

### Risk level
**Low** — the welcome screen itself is a simple interstitial with routing logic. The complexity lives in the surfaces it routes to (Triage, Catch-up, Pause), which are scoped separately. The main risk is the dormancy detection logic and the "show once per gap" state management.

## Design decisions to resolve during specification

1. **Interstitial vs. overlay**: full-screen route (replaces dashboard on first load) or overlay/modal on top of dashboard? (Lean: full-screen route — the dashboard behind would look alarming with all the debt, defeating the purpose)
2. **Lifetime stats selection**: which stats to show? Total items learned, masechtos completed, days tracked, longest streak? (Lean: total items + tracks active — the most universally meaningful, avoid streak if it's broken)
3. **"Show once" persistence**: flag stored where? SharedPreferences with last-welcome timestamp? (Lean: SharedPreferences — lightweight, survives app restart, clears naturally when the user generates new activity)
4. **Pause-return as same screen or different**: share the screen component with dormancy-return, or separate widgets? (Lean: same screen with a `WelcomeVariant` enum controlling content and tone — DRY, easy to maintain)
