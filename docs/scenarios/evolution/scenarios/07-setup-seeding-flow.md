> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

# Setup Seeding Flow

## Target

The onboarding surface for learners who create a new track with pre-existing learning state. Replaces the current "mark done" bulk UX (`BulkMarkScreen`) with a first-class per-item flow offering three choices: learned / amnesty / defer. Used by S14 (Program Launch Day — joining a program mid-cycle) and S15 (Personal Track Retrofit — importing existing self-study into tracking).

This is positioned as a **user-visible improvement** (not just a new onboarding surface) because the existing bulk-mark experience is clunky and does not support amnesty or per-stage declarations.

## Current State

The existing `BulkMarkScreen` (`/features/onboarding/presentation/screens/bulk_mark_screen.dart`):
- Multi-phase selection flow: selection → stage selection → confirmation → processing → done
- Hierarchy browser with drill-down navigation and search
- Per-stage marking with separate stage selection per item
- Content item grid with selection checkboxes
- Complex, slow — requires many taps to mark even a small number of items
- Only supports "mark as done" — no amnesty option, no "defer" option
- No concept of "I learned this but haven't reviewed it"
- No batch mode for marking an entire masechta at once
- No integration with the recovery model (amnesty, rescope, pause)

## Desired State

A streamlined onboarding flow that:

1. **Presents the curriculum hierarchy** at the unit level first (masechta / seder / perek per `primary_unit_type`, with per-track override available per NQ1)
2. **Three per-item choices** with clear visual language:
   - **Learned** — creates completion records (`completedAt = now`, `source = "retrofit_seeding"` per NQ2)
   - **Amnesty** — creates `item_amnesty` records (item exists in curriculum but learner is not doing it)
   - **Defer** — no action; item remains unstarted, part of future learning plan
3. **Batch mode** (the fast path): tap a whole unit → mark all items in it as learned/amnesty/defer in one action
4. **Individual override**: after batch-marking a unit, drill in to override specific items (e.g., "I learned all of Berachos except daf 12b")
5. **Optional chazara declaration** (for items marked learned): "Reviewed once / twice / N times" — creates completion records with `source = "retrofit_seeding"` per NQ2. Not required — the learner can skip this and start fresh chazara from today.
6. **Quick-path shortcuts** for common patterns:
   - Program Launch Day (S14): "Align with program" — bulk amnesty everything before today's daf, start tracking from today
   - Personal Retrofit (S15): "Start minimal" — skip seeding entirely, track from today forward
7. **Goal setup integrated**: after seeding, the flow prompts for pace/deadline goal (so PaceCalculator has a baseline)
8. **Primary unit type choice**: if the learner is setting up a children's track, offer the unit type override here (per NQ1 — available at creation, editable later in Settings)

### Variant: Program Launch Day (S14)

The flow is anchored to the program's current position:
- "The program is on [daf 87]. Where would you like to start?"
- Quick paths: Align with program now / Start from beginning / Custom start point
- "Align with program" auto-amnesty everything before the current daf
- Cross-credit prompt if another track shares the same curriculum (links to S12)
- Cycle-boundary note: when a new cycle begins, old amnesties are tagged with the previous cycle

### Variant: Personal Track Retrofit (S15)

The flow is learner-directed — no external position to align with:
- "Tell us what you've already learned"
- Hierarchy browser: batch-mark units, drill into individual items
- Review declaration: "How many times have you reviewed [unit]?" (optional)
- "Start minimal" shortcut: skip seeding, track from today

## User Journey

### Entry point
- **Track creation flow**: after selecting curriculum and scope, if the learner toggles "I've already started this" (S15) or joins a mid-cycle program (S14)

### Flow — Program Launch Day (S14)

```
1. "Daf Yomi Bavli is on Daf 87 of Berachos"
   "Where would you like to start?"

2. Quick paths:
   [Align with program — start from today's daf]
     → Preview: "86 dapim will be marked as skipped. 
        You'll start tracking from Daf 87."
     → Confirm → bulk item_amnesty inserts → done
   
   [Start from the beginning]
     → Warning: "You'll be 86 dapim behind the program. 
        You can amnesty items later as you go."
     → Confirm → no seeding → done
   
   [Custom start point]
     → Curriculum browser: pick a daf
     → Everything before: [Learned] or [Amnesty]?
     → Per-item overrides available
     → Confirm → bulk inserts → done

3. Cross-credit prompt (if applicable):
   "You have a personal Bavli track. Cross-credit future completions?"
   [Yes] [No] [Decide later]

4. Goal setup:
   "Set a daily goal?" → pace/deadline picker → done

5. → Navigate to dashboard with new track active
```

### Flow — Personal Track Retrofit (S15)

```
1. "What have you already learned?"
   
   Primary unit type choice (if not default):
   "How do you organize your learning?"
   [By masechta] [By perek] [By seder]

2. Hierarchy browser — top level units:
   ┌──────────────────────────────────────┐
   │  Seder Zeraim                        │
   │                                      │
   │  ██ Berachos    [Learned ▼]          │
   │  ██ Peah        [Learned ▼]          │
   │  ▒▒ Demai      [Partial... ▼]        │
   │  ░░ Kilayim    [Defer]               │
   │  ░░ Sheviis    [Defer]               │
   │  ...                                 │
   └──────────────────────────────────────┘

3. Tap "Partial..." on Demai → drill in:
   ┌──────────────────────────────────────┐
   │  Demai — 7 perakim                   │
   │                                      │
   │  ██ Perek 1  [Learned]               │
   │  ██ Perek 2  [Learned]               │
   │  ██ Perek 3  [Learned]               │
   │  ░░ Perek 4  [Defer]                 │
   │  ░░ Perek 5  [Defer]                 │
   │  ░░ Perek 6  [Defer]                 │
   │  ░░ Perek 7  [Defer]                 │
   └──────────────────────────────────────┘

4. Optional chazara declaration (for learned units):
   "How many times have you reviewed Berachos?"
   [None] [Once] [Twice] [3+ times]
   → Creates completion records per stage with source = "retrofit_seeding"

5. Summary screen:
   "3 masechtos learned, 0 amnestied, 8 deferred"
   "12 chazara stages declared"
   [Confirm] [Back to edit]

6. Goal setup → done → dashboard
```

### "Start minimal" shortcut

```
Available at any point in the S15 flow:
[Skip seeding — start tracking from today]
→ No completions, no amnesty — everything is deferred
→ Go straight to goal setup → done
```

## Success Criteria

- Program launch seeding (S14 "Align with program") completes in under 30 seconds — 3 taps
- Personal retrofit seeding (S15 with batch marking) completes in under 2 minutes for a learner with 2-3 completed units
- "Start minimal" is always available as a 1-tap escape
- Batch mode: marking a whole masechta as learned is 1 tap, not N taps
- Individual override after batch is available but not required
- All created records have honest timestamps (`completedAt = now`) and `source = "retrofit_seeding"` tags
- Chazara declaration is optional — learner is never forced to declare review history
- The flow replaces `BulkMarkScreen` — the old UI is retired

## Scope

### Pages affected
- New: **Setup Seeding flow** (multi-step screen — the primary new surface)
- Existing: **Add Track flow** (`add_track_flow.dart`) — integrates seeding as a step
- Existing: **BulkMarkScreen** — to be replaced/retired
- Existing: **Goal Setup screen** — integrated at end of seeding

### Components touched
- New: `SetupSeedingScreen` — main flow controller with step management
- New: `SeedingQuickPaths` — S14 quick-path selection (align / beginning / custom)
- New: `SeedingHierarchyBrowser` — unit-level curriculum browser with batch/individual modes
- New: `SeedingItemRow` — per-item row with learned/amnesty/defer toggle
- New: `SeedingUnitRow` — per-unit row with batch action + drill-in
- New: `ChazaraDeclarationSheet` — optional review history declaration
- New: `SeedingSummary` — confirmation screen before commit
- New: `UnitTypeSelector` — primary_unit_type choice (per NQ1)
- Existing: hierarchy/curriculum data providers — reused for browsing
- Existing: `GoalSetupScreen` — final step of the flow

### Data changes
- Writes: bulk `completions` inserts with `source = "retrofit_seeding"` (for learned items + declared chazara)
- Writes: bulk `item_amnesty` inserts with `source = "retrofit_seeding"` (for amnestied items)
- Writes: `primary_unit_type` on `curriculum_tracks` (if overridden)
- Writes: `track_action_log` with source `"setup_seeding"`
- Writes: goal configuration (pace/deadline via existing goal setup)

### Risk level
**High** — this is the most complex new surface. Multi-step flow with batch data operations, hierarchy navigation, optional chazara declaration, and two distinct variants (S14 vs S15). The bulk insert operations must be transactional (all-or-nothing on confirm). The hierarchy browser must handle curricula of very different sizes (Mishnayos Berachos: 9 perakim vs. Bavli: 37 masechtos × 100+ dapim each). Also replaces an existing screen, so migration testing is needed.

## Design decisions to resolve during specification

1. **Hierarchy depth**: always show two levels (unit + item), or adaptive to curriculum size? (Lean: adaptive — small curricula show items directly, large ones show units first)
2. **Batch-then-override UX**: how to signal that individual overrides are available after batch? (Lean: batch row shows a "customize" chevron; tapping expands inline to show items)
3. **Chazara declaration granularity**: per-unit or per-item? (Lean: per-unit for batch, per-item only on drill-in — keeps the common case fast)
4. **Transaction handling**: show a progress indicator during bulk inserts, or optimistic UI? (Lean: progress indicator for large batches (>50 items), optimistic for small ones)
5. **Cross-credit prompt timing** (S14): before or after seeding? (Lean: after — don't interrupt the seeding flow with a secondary decision)
