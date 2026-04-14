# Review Debt View

## Target

A dedicated surface for browsing and resolving overdue chazara. Handles two distinct severity levels: S6 (Chazara Archipelago — sporadic, 1-15 missed reviews scattered across units) and S7 (Chazara Collapse — systematic neglect, 15+ missed reviews with declining review velocity). The dashboard only shows a subtle badge; this view is the place where chazara debt becomes actionable.

Also serves as one of the two access points for amnesty history (per Q20 lean) — amnestied reviews are visible here with an "unforgive" option.

## Current State

Today:
- `ChazaraStatusLine` on the track card shows a text summary ("3 reviews due") but is not tappable
- There is no dedicated view for browsing overdue chazara
- No way to amnesty a specific review stage
- No way to see which items have overdue chazara vs. which are clean
- No distinction between "missed a few scattered reviews" and "systematically stopped reviewing"
- The learner has no path to clear chazara debt without doing every review or ignoring the counter

## Desired State

A full-screen view (pushed route, not a sheet) that:

1. **Groups overdue chazara by unit** (masechta, perek, siman — per `primary_unit_type`) with expandable sections
2. **Shows each overdue item** with: ref label, which stage is overdue, how old the debt is
3. **Adapts framing to severity**:
   - **Archipelago (S6)**: matter-of-fact — "7 reviews waiting" — browse and pick
   - **Collapse (S7)**: warm reframing — "Your learning is strong. Chazara stopped around [date]. Want to restart?" — leads with restart options before individual items
4. **Per-item actions** (following Q19 gesture vocabulary):
   - Swipe left on a single-stage row → amnesty that stage (lightweight, snackbar undo)
   - Tap a row → open item detail / launch review
   - Long-press or multi-select → bulk amnesty selected items
5. **Bulk actions** at the top:
   - **Amnesty all** — one-tap clean slate for chazara
   - **Schedule into rotation** — spread overdue reviews across the next N days' daily plans
   - **Restart reviews from today** (S7 only) — bulk amnesty old debt, fresh chazara schedule going forward
   - **Disable chazara on this track** (S7 only) — learner opts into learn-only mode
6. **Shows amnestied items** in a collapsible "Skipped" section at the bottom — each with an "unforgive" action to put it back in queue (per Q20)
7. **Cross-track mode** (optional): toggle to show chazara debt across all tracks with a track filter — or stay single-track (default)

## User Journey

### Entry points
- **From dashboard track card**: tap the chazara status badge → opens Review Debt for that track
- **From track detail screen**: chazara section link
- **From weekly chazara digest notification**: deep link to this view
- **From Learning Journey view**: "N reviews overdue in this section" links here filtered to that unit

### Flow — Archipelago (S6, 1-15 items)

```
1. View opens with track name + "7 reviews waiting"

2. Grouped by unit:
   ┌─ Berachos (3 reviews) ──────────────┐
   │  Daf 4b  · Stage 2 · 12 days ago    │  ← swipe to amnesty
   │  Daf 11a · Stage 1 · 8 days ago     │
   │  Daf 15b · Stage 3 · 5 days ago     │
   └──────────────────────────────────────┘
   ┌─ Shabbos (4 reviews) ──────────────┐
   │  ...                                │
   └──────────────────────────────────────┘

3. Actions:
   - Swipe item → "Skipped" snackbar with [Undo]
   - Tap item → review launcher
   - Top bar: [Amnesty all] [Schedule into rotation]

4. "Skipped" section (collapsed by default):
   ┌─ Skipped (2 amnestied) ─────────────┐
   │  Daf 2a · Stage 1 · skipped Apr 8   │  [Unforgive]
   │  Daf 7b · Stage 2 · skipped Apr 10  │  [Unforgive]
   └──────────────────────────────────────┘
```

### Flow — Collapse (S7, 15+ items)

```
1. View opens with warm framing:
   "Your learning is strong. Chazara paused around [date]."
   "Reviews help retention — here are some options."

2. Restart options (prominent, before the item list):
   [Restart reviews from today]  — amnesty old debt, fresh schedule
   [Small commitment — 5 reviews this week]
   [Amnesty all chazara debt]
   [Disable chazara on this track]

3. Below: same grouped item list as Archipelago, 
   but collapsed by default (learner can expand to browse)

4. After a restart action → snackbar → view updates in place
```

## Success Criteria

- Learner can find and act on any specific overdue chazara in under 10 seconds (archipelago)
- S7 collapse framing never leads with a number — leads with acknowledgement of learning strength
- Single-stage amnesty is one swipe + snackbar (per Q19 lean)
- Bulk amnesty shows a count confirmation before executing
- Amnestied items are visible in the "Skipped" section with unforgive capability (per Q20)
- "Schedule into rotation" spreads reviews across the daily plan without overloading any single day
- Cross-track toggle shows debt across all tracks (secondary, not default)

## Scope

### Pages affected
- New: **Review Debt view** (full-screen route — the primary new surface)
- **Dashboard screen** — chazara status badge becomes a tappable link
- **Track detail screen** — chazara section links here
- **Learning Journey view** — unit-level review debt links here

### Components touched
- New: `ReviewDebtScreen` — full-screen view with severity-adaptive framing
- New: `ReviewDebtUnitGroup` — expandable unit section with item rows
- New: `ReviewDebtItemRow` — swipeable row with stage label, age, amnesty gesture
- New: `ReviewCollapseHeader` — warm framing + restart options for S7
- New: `SkippedReviewsSection` — collapsible list of amnestied chazara with unforgive
- Existing: `ChazaraStatusLine` — becomes tappable, routes to this view
- Reuses: swipe-to-amnesty pattern, snackbar undo

### Data changes
- Reads: `TrackDebt.reviewDebt` (per-stage overdue list), `item_amnesty` records (for skipped section)
- Writes: `item_amnesty` inserts (stage-scoped, `source = "user_manual"`), revocations (`revoked_at` set on unforgive)
- Writes: scheduler adjustments for "schedule into rotation"
- Writes: `track_action_log` entries

### Risk level
**Medium** — new full-screen view with per-stage data operations. The swipe-to-amnesty gesture needs careful implementation to avoid accidental amnesty. The "schedule into rotation" action touches the scheduler's daily plan computation.

## Design decisions to resolve during specification

1. **Swipe direction**: left-to-amnesty only, or bidirectional (left = amnesty, right = do now)? (Lean: left-only for amnesty — "do now" is a tap action, not a swipe)
2. **Age display**: relative ("12 days ago") or absolute ("Apr 1")? (Lean: relative for recent, absolute for >30 days)
3. **"Schedule into rotation" algorithm**: even spread or weighted by age (oldest first)? (Lean: oldest-first, capped at 2 extra reviews per day to avoid overload)
4. **Cross-track toggle**: tab bar, filter chip, or separate route? (Lean: filter chip at top — keeps it lightweight)
5. **Empty state**: what does this view show when all chazara is clean? (Lean: celebratory message — "All caught up on chazara!" with illustration, accessed only if the learner navigates here explicitly)
