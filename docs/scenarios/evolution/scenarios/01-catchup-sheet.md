> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

# Catch-up Sheet

## Target

The core recovery surface for a single track. When a learner is behind — mildly, meaningfully, or severely — and the app needs to present options, this is the sheet that appears. It replaces the current `RecoveryActionButton` (a bare TextButton + AlertDialog confirmation) with a richer, scenario-aware bottom sheet that adapts its content to the severity of the debt and the track's catchup mode.

Covers scenarios S2 (Rescope Moment), S3 (Pace Reboot), and S4 (Program Debt Pileup). Also the anchor surface for S1 (Gentle Drift) when the learner taps the inline catch-up suggestion.

## Current State

Today the learner sees:
- A `RecoveryActionButton` beneath the track card footer offering "Jump to today" or "Reset pace"
- Tapping shows a bare `AlertDialog` with a one-line confirmation ("Reset pace to today?") and Cancel / Confirm buttons
- No context about what the action means for their data
- No awareness of debt severity — same dialog whether 2 days or 60 days behind
- No option to amnesty items, set a stretch goal, or pause
- No visibility into what the pace reset actually changes
- Program tracks get the same "Reset pace" dialog as self-paced tracks — no amnesty path at all

## Desired State

A modal bottom sheet that:

1. **Adapts to severity and mode** — three distinct layouts sharing one shell:
   - **Mild (S1/S2)**: compact, one-screen, quick decision
   - **Severe (S3)**: warm welcome-back framing, more options, explicit pause offer
   - **Program (S4)**: item-level debt list with per-item amnesty/catch-up choices

2. **Shows what matters, hides what demoralizes** — leads with positive framing ("You've learned 24 dapim"), never leads with a behind-count. Severity determines what's shown, not raw numbers.

3. **Provides the right actions per mode**:
   - Self-paced mild: Rescope | Stretch goal (catch up over N days) | Not now
   - Self-paced severe: Full reboot (rescope + amnesty all chazara) | Rescope + keep chazara | Rescope only | Archive | Pause offer
   - Program: Bulk amnesty all | Amnesty selected | Catch up (mark as learned now) | Split decision | Decide later

4. **Previews the outcome** before confirming — "Your new finish date would be [date]" or "8 items will be marked as skipped"

5. **Offers Pause as an explicit companion** (never automatic) — after any recovery action, a follow-up prompt: "Pause this track for a week while you settle in?"

6. **Logs to track_action_log** with the surface source `"catchup_sheet"`

## User Journey

### Entry points
- **From dashboard track card**: tap the recovery action area (replaces current RecoveryActionButton)
- **From inline S1 note**: tap "Want to catch up?" on the Gentle Drift inline prompt
- **From triage sheet**: each triage card's "Details" action opens this sheet for that track
- **From track detail screen**: recovery section opens this sheet

### Flow — Self-paced mild/meaningful (S2)

```
1. Sheet rises with track name + curriculum color stripe
2. Header: "Adjust your plan" — one-line context: "12 days behind your pace"
3. Preview: "At current pace, finish [date]. Rescope to [new date]?"
4. Actions:
   [Rescope]  →  confirms, snackbar "Pace reset", sheet closes
   [Catch up over N days]  →  shows stretch calculator, confirm
   [Not now]  →  sheet closes, prompt suppressed 7 days
```

### Flow — Self-paced severe (S3)

```
1. Sheet rises — taller, warm framing
2. Header: "Let's restart fresh" — positive stat: "You've learned X items — that's real."
3. No behind-counter shown
4. Actions (vertical list, each with one-line explanation):
   [Full reboot]  →  "Rescope + amnesty all overdue chazara. Clean slate."
   [Rescope + keep chazara]  →  "Reset pace, keep chazara debt visible in Review Debt"
   [Rescope only]  →  "Reset pace, don't touch chazara"
   [Archive]  →  "Stop tracking. Your learning is preserved."
5. After any rescope action → follow-up prompt:
   "Pause this track for a week while you get settled?"
   [Yes, pause 7 days]  [No, start now]
6. Confirm → snackbar with undo (5 sec) → sheet closes
```

### Flow — Program debt (S4)

```
1. Sheet rises — item-list layout
2. Header: "Missing [items]" — track name + program context
3. Scrollable list of missed items grouped by date range
   Each item row: [ref label]  [Learned]  [Amnesty]
4. Bulk actions at bottom:
   [Amnesty all N]  [Catch up all]  [Decide later]
5. For "Split decision": learner marks per-item, then confirms
6. Confirm → snackbar summary ("5 amnestied, 3 marked learned") → sheet closes
```

### Common patterns across all variants
- Sheet dismissible by swipe-down or back gesture
- "Not now" / "Decide later" always available — never trapped
- All destructive-feeling actions (archive, bulk amnesty) get a one-line explanation + confirm
- Undo snackbar after every action (5 sec window)

## Success Criteria

- Learner can resolve any single-track debt state from one surface in under 30 seconds (mild) or 60 seconds (severe/program)
- No behind-counter is ever the first thing shown
- Program track learners have a path to per-item amnesty decisions (not just bulk reset)
- Every action previews its outcome before confirmation
- Recovery action is logged in `track_action_log` with source `"catchup_sheet"`
- After action, dashboard track card immediately reflects the new state (no stale debt numbers)

## Scope

### Pages affected
- **Dashboard screen** — track card recovery action area (trigger point)
- **Track detail screen** — recovery section (trigger point)
- New: **Catch-up sheet** (modal bottom sheet — the primary new surface)

### Components touched
- `RecoveryActionButton` — reworked into scenario-aware trigger that opens the sheet
- New: `CatchupSheet` widget (modal bottom sheet with 3 variant layouts)
- New: `CatchupSheetHeader` — severity-adaptive header
- New: `ProgramDebtList` — scrollable item list with per-item amnesty/learned toggles
- New: `StretchGoalCalculator` — inline pace preview for catch-up-over-N-days
- New: `PauseOfferPrompt` — reusable follow-up prompt (shared with Triage, Returning Learner)
- Existing: `SnackBar` pattern for undo feedback

### Data changes
- Reads: `TrackDebt` computed view (learningDebt, reviewDebt, daysBehind, daysDormant, primaryScenario)
- Writes: `rescope()` service call, `item_amnesty` inserts, `track_action_log` entries
- New: `PauseOfferPrompt` writes `paused_at` / `paused_until` on `curriculum_tracks`

### Risk level
**Medium** — behavior change (new recovery flows replace existing simple confirm dialog), new data writes (amnesty records, action log). No structural schema change beyond what the scenarios doc already specifies.

## Design decisions to resolve during specification

1. **Sheet height**: fixed peek height with scroll, or adaptive to content? (Lean: adaptive — mild variant is compact, program variant scrolls)
2. **Stretch goal calculator**: slider, stepper, or text input for "catch up over N days"? (Lean: stepper with preset options — 3 days / 1 week / 2 weeks / custom)
3. **Program debt list**: flat list or grouped by date range / masechta? (Lean: grouped by date range per S4 spec, with expandable sections per Q18 resolution)
4. **Undo scope**: can the learner undo a bulk amnesty as a single undo, or only per-item? (Lean: single undo for bulk, individual undo for per-item — matches gesture weight principle)
