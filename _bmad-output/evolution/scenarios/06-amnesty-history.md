# Amnesty History / Skipped View

## Target

A cross-cutting view that answers: "What have I deliberately skipped, and can I change my mind?" Every amnesty action across the app (from Catch-up Sheet, Triage, Review Debt, Learning Journey, or inline swipe) creates `item_amnesty` records. This view surfaces them in one browsable, filterable list with unforgive capability.

Per Q20 lean: two access points — track settings panel and inside Review Debt / Learning Journey views. Plus an undo snackbar after each amnesty action.

## Current State

Today there is no amnesty mechanism at all, so there is no history to show. Once amnesty is implemented, this view ensures the learner can always answer "what did I skip and when?" — upholding the governing principle that data is sacred and amnesty is visible and revocable.

## Desired State

A full-screen view that:

1. **Lists all active amnesty records** for a track (or across tracks), showing: item ref, stage (if stage-scoped), amnesty date, source (manual / bulk / triage / cycle-boundary), and optional reason
2. **Grouped by source** or **by unit** (toggle) — so the learner can see "everything I amnestied during last week's triage" or "everything skipped in Masechta Berachos"
3. **Per-item unforgive**: tap to revoke amnesty → item returns to the active queue → snackbar with undo
4. **Bulk unforgive**: multi-select → "Put N items back in queue" with confirmation
5. **Filter by**: active vs. revoked amnesty, stage-scoped vs. whole-item, source, date range
6. **Cycle-aware for program tracks**: amnesty records tagged with the current cycle are shown prominently; previous-cycle amnesty is available under a "Previous cycles" collapsible section
7. **Embedded in context surfaces**: Review Debt view shows a "Skipped" section; Learning Journey shows amnestied items in structural position. Both link here for the full list.

## User Journey

### Entry points
- **From Track Settings panel**: "Skipped items" or "Amnesty history" link
- **From Review Debt view**: "Skipped" section → "See all" link
- **From Learning Journey view**: tap an amnestied (striped) item → detail includes "See all skipped"
- **From undo snackbar**: after any amnesty action, snackbar says "Skipped [ref]. [Undo] [See all skipped]"

### Flow

```
1. View opens with track name (or "All tracks" if cross-track)

2. Header: "N items skipped" — filter chips below:
   [All] [This cycle] [Manual] [Bulk] [Triage]

3. Grouped by unit (default) or by source (toggle):
   ┌─ Berachos (4 skipped) ──────────────┐
   │  Daf 4b  · all stages · Apr 8       │
   │    "missed-traveling" · manual       │  [Unforgive]
   │  Daf 11a · stage 2 only · Apr 8     │
   │    triage · bulk                     │  [Unforgive]
   │  Daf 15b · all stages · Apr 10      │
   │    manual                            │  [Unforgive]
   │  Daf 22a · stage 1 only · Apr 12    │
   │    manual · "too advanced"           │  [Unforgive]
   └──────────────────────────────────────┘

4. Multi-select mode (long-press to enter):
   Select items → [Unforgive N items] → confirmation → snackbar

5. "Previous cycles" (collapsed, for program tracks):
   ┌─ Cycle 13 (42 skipped) ─────────────┐
   │  These items were skipped in the     │
   │  previous Daf Yomi cycle and are no  │
   │  longer active.                      │
   │  [Expand to browse]                  │
   └──────────────────────────────────────┘
```

### Unforgive flow

```
1. Learner taps [Unforgive] on a row
2. Brief inline confirmation: "Put Daf 4b back in your queue?"
   [Yes] [Cancel]
3. → item_amnesty.revoked_at = now
4. → Item reappears in Review Debt or Learning Journey as active debt
5. → Snackbar: "Daf 4b restored" [Undo]
```

## Success Criteria

- Every amnesty in the system is visible and browsable from this view
- Unforgive is 2 taps (tap + confirm) — the same gesture weight as amnesty per the governing principle
- Cycle-scoped amnesty is clearly distinguished from current-cycle amnesty
- Source attribution (manual / bulk / triage / cycle-boundary) is shown per record
- Optional reason text is displayed when present
- Bulk unforgive is available for efficient reversal of bulk amnesty decisions
- The view is reachable from both Track Settings and from contextual surfaces (Review Debt, Learning Journey)

## Scope

### Pages affected
- New: **Amnesty History screen** (full-screen route — the primary new surface)
- **Track settings panel** — new link to this view
- **Review Debt view** — "Skipped" section links here via "See all"
- **Learning Journey view** — amnestied item detail links here

### Components touched
- New: `AmnestyHistoryScreen` — full-screen browsable list
- New: `AmnestyRecordRow` — per-record display (ref, stage, date, source, reason)
- New: `AmnestyFilterChips` — filter by source, cycle, date range
- New: `AmnestyGroupHeader` — collapsible unit or source grouping
- New: `CycleSectionCollapsible` — previous-cycle amnesty (program tracks only)
- Existing: `SkippedReviewsSection` (from Review Debt) — links to this full view

### Data changes
- Reads: `item_amnesty` records (with joins to curriculum metadata for ref labels)
- Writes: `revoked_at` on `item_amnesty` (unforgive), `track_action_log` with action_type `"unforgive"`
- No schema changes — reads/writes existing `item_amnesty` table

### Risk level
**Low** — primarily a read-heavy view with simple write operations (set `revoked_at`). The main complexity is the joins needed to display human-readable item labels from `sefaria_ref` values. Cross-track mode adds a minor query complexity increase.

## Design decisions to resolve during specification

1. **Default grouping**: by unit or by date? (Lean: by unit — matches how the learner thinks about their curriculum, with date sort within each group)
2. **Cross-track mode**: toggle at top or separate route? (Lean: toggle — same as Review Debt, consistent pattern)
3. **Revoked amnesty**: show in this view (with "re-amnesty" option) or hide entirely? (Lean: hide from default view, available under a "Show revoked" toggle for audit purposes)
4. **Empty state**: what shows when no amnesty records exist? (Lean: brief explanation of what amnesty is and where to use it — educational, not blank)
