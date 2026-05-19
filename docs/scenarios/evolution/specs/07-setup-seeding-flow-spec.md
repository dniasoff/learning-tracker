> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

# 07 — Setup Seeding Flow

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Setup Seeding Flow (S14 / S15) |
| **Route** | `/track/setup-seeding` (pushed from Add Track flow) |
| **Platform** | Mobile (Flutter / Android) |
| **Page Type** | Full-screen multi-step flow (PageView with step indicator) |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |
| **Replaces** | `BulkMarkScreen` (`/features/onboarding/presentation/screens/bulk_mark_screen.dart`) |
| **Risk Level** | High — most complex new surface |

---

## Overview

**Page Purpose:** Allow learners with pre-existing learning state to seed their track with historical completions, amnesty decisions, and optional chazara declarations before they begin active tracking.

**User Situation:** The learner has just created a new track and either (a) is joining a program mid-cycle (S14 — Program Launch Day) or (b) is importing existing self-study into a personal track (S15 — Personal Track Retrofit). They need to declare what they have already learned, what they want to skip, and what remains ahead — then set a goal.

**Success Criteria:**
- S14 "Align with program" completes in under 30 seconds (3 taps)
- S15 batch marking completes in under 2 minutes for 2-3 completed units
- "Start minimal" escape is always available as 1 tap
- All records created with `completedAt = now` and `source = "retrofit_seeding"`

**Entry Points:**
- Add Track flow: after selecting curriculum and scope, when learner toggles "I've already started this" (S15) or joins a mid-cycle program (S14)

**Exit Points:**
- Flow completion -> Dashboard with new track active
- "Start minimal" escape -> Goal Setup step -> Dashboard
- Back / cancel -> Add Track flow (no records written)

---

## Flow Structure

The flow uses a `PageView` with a linear step indicator. Steps vary by variant.

### S14 — Program Launch Day

```
Step 1: Quick Path Selection
Step 2: Confirmation / Custom Browser (conditional)
Step 3: Cross-Credit Prompt (conditional — only if shared curriculum exists)
Step 4: Goal Setup
Step 5: Done
```

### S15 — Personal Track Retrofit

```
Step 1: Unit Type Selection (conditional — skipped if default is appropriate)
Step 2: Hierarchy Browser (batch + drill-in)
Step 3: Summary Confirmation
Step 4: Goal Setup
Step 5: Done
```

---

## Layout Structure

### Step Indicator (shared — all steps)

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│ ●───●───○───○                        │
└──────────────────────────────────────┘
```

### S14 Step 1 — Quick Path Selection

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ●───○───○───○                        │
├──────────────────────────────────────┤
│                                      │
│  Daf Yomi Bavli is on                │
│  Daf 87 of Berachos                  │
│                                      │
│  Where would you like to start?      │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ★ Align with program          │  │
│  │   Start from today's daf.     │  │
│  │   86 dapim marked as skipped. │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │   Start from the beginning    │  │
│  │   You'll be 86 dapim behind.  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │   Custom start point          │  │
│  │   Choose where to begin.      │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

### S14 Step 2a — Align Confirmation

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ●───●───○───○                        │
├──────────────────────────────────────┤
│                                      │
│  86 dapim will be marked as          │
│  skipped (amnesty).                  │
│                                      │
│  You'll start tracking from          │
│  Daf 87 — Berachos.                  │
│                                      │
│           [Confirm]                  │
│                                      │
└──────────────────────────────────────┘
```

### S14 Step 2b — Start From Beginning Warning

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ●───●───○───○                        │
├──────────────────────────────────────┤
│                                      │
│  You'll be 86 dapim behind the       │
│  program. You can amnesty items      │
│  later as you go.                    │
│                                      │
│           [Confirm]                  │
│                                      │
└──────────────────────────────────────┘
```

### S14 Step 2c — Custom Start Point Browser

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ●───●───○───○                        │
├──────────────────────────────────────┤
│  Pick your starting daf:            │
│  ┌────────────────────────────────┐  │
│  │ Daf 2a                   ░░   │  │
│  │ Daf 2b                   ░░   │  │
│  │ ...                           │  │
│  │ Daf 44a                  ░░   │  │
│  └────────────────────────────────┘  │
│                                      │
│  Everything before your start:       │
│  ( ) Mark as learned                 │
│  (●) Mark as skipped (amnesty)       │
│                                      │
│           [Continue]                 │
│                                      │
└──────────────────────────────────────┘
```

### S14 Step 3 — Cross-Credit Prompt

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ●───●───●───○                        │
├──────────────────────────────────────┤
│                                      │
│  You have a personal Bavli track.    │
│                                      │
│  Cross-credit future completions     │
│  between both tracks?                │
│                                      │
│  [Yes]  [No]  [Decide later]        │
│                                      │
└──────────────────────────────────────┘
```

### S15 Step 1 — Unit Type Selection

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ●───○───○───○                        │
├──────────────────────────────────────┤
│                                      │
│  How do you organize your learning?  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ (●) By masechta              │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ( ) By perek                  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ( ) By seder                  │  │
│  └────────────────────────────────┘  │
│                                      │
│           [Continue]                 │
│                                      │
└──────────────────────────────────────┘
```

### S15 Step 2 — Hierarchy Browser

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ○───●───○───○                        │
├──────────────────────────────────────┤
│  What have you already learned?      │
│                                      │
│  Seder Zeraim                        │
│  ┌────────────────────────────────┐  │
│  │ ██ Berachos     [Learned  ▼] >│  │
│  │ ██ Peah         [Learned  ▼]  │  │
│  │ ▒▒ Demai       [Partial...▼] >│  │
│  │ ░░ Kilayim     [Defer     ▼]  │  │
│  │ ░░ Sheviis     [Defer     ▼]  │  │
│  └────────────────────────────────┘  │
│                                      │
│  Seder Moed                          │
│  ┌────────────────────────────────┐  │
│  │ ░░ Shabbos     [Defer     ▼]  │  │
│  │ ░░ Eruvin      [Defer     ▼]  │  │
│  │ ...                            │  │
│  └────────────────────────────────┘  │
│                                      │
│  3 learned · 0 amnestied · 8 deferred│
│           [Continue]                 │
│                                      │
└──────────────────────────────────────┘
```

### S15 Step 2 — Drill-In (Inline Expand)

```
┌──────────────────────────────────────┐
│  ▒▒ Demai       [Partial...▼]       │
│  ┌──────────────────────────────┐   │
│  │  ██ Perek 1  [Learned]       │   │
│  │  ██ Perek 2  [Learned]       │   │
│  │  ██ Perek 3  [Learned]       │   │
│  │  ░░ Perek 4  [Defer]         │   │
│  │  ░░ Perek 5  [Defer]         │   │
│  │  ░░ Perek 6  [Defer]         │   │
│  │  ░░ Perek 7  [Defer]         │   │
│  └──────────────────────────────┘   │
└──────────────────────────────────────┘
```

### S15 Chazara Declaration (Bottom Sheet)

```
┌──────────────────────────────────────┐
│  How many times have you reviewed    │
│  Berachos?                           │
│                                      │
│  [None] [Once] [Twice] [3+]         │
│                                      │
│           [Done]                     │
└──────────────────────────────────────┘
```

### S15 Step 3 — Summary Confirmation

```
┌──────────────────────────────────────┐
│ [<-]  Setup Your Track    [Skip]     │
│ ○───○───●───○                        │
├──────────────────────────────────────┤
│                                      │
│  Your Learning Journey               │
│                                      │
│  ██  3 masechtos learned             │
│  ▓▓  0 amnestied                     │
│  ░░  8 deferred                      │
│  ♻   12 chazara stages declared      │
│                                      │
│  [Confirm]        [Back to edit]     │
│                                      │
└──────────────────────────────────────┘
```

### Step 4 — Goal Setup (Shared — both variants)

Delegates to the existing `GoalSetupScreen` embedded as a step within the PageView. See existing Goal Setup spec.

### Step 5 — Done (Shared)

```
┌──────────────────────────────────────┐
│                                      │
│        ✓ You're all set!             │
│                                      │
│  Your track is ready. Learning       │
│  starts now.                         │
│                                      │
│        [Go to Dashboard]             │
│                                      │
└──────────────────────────────────────┘
```

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `md` (16dp) |
| Step indicator top padding | `sm` (8dp) |
| Section gap (between title and content) | `lg` (24dp) |
| Quick-path card gap | `md` (16dp) |
| Unit row gap | `zero` (divided by 1dp separator) |
| Drill-in indent | `lg` (24dp) left padding |
| Action button bottom padding | `xl` (32dp) from bottom edge |
| Summary stat row gap | `md` (16dp) |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Size | Weight |
|---------|------|--------|
| Step title ("Setup Your Track") | `titleMedium` (16sp) | w500 |
| Context headline ("Daf Yomi Bavli is on...") | `titleLarge` (22sp) | normal |
| Prompt question ("Where would you like to start?") | `titleMedium` (16sp) | w500 |
| Quick-path card title | `titleSmall` (14sp) | w500 |
| Quick-path card description | `bodySmall` (12sp) | normal |
| Seder header | `labelLarge` (14sp) | w500 |
| Unit row label | `bodyMedium` (14sp) | w500 |
| Unit row action chip | `labelMedium` (12sp) | w500 |
| Drill-in item label | `bodySmall` (12sp) | normal |
| Summary stat number | `headlineMedium` (28sp) | bold |
| Summary stat label | `bodyMedium` (14sp) | normal |
| Footer tally ("3 learned...") | `bodySmall` (12sp) | normal |
| "Skip" button | `labelMedium` (12sp) | w500 |

---

## Page Sections

### Section: App Bar / Step Header

**OBJECT ID:** `seeding-header`

| Property | Value |
|----------|-------|
| Purpose | Navigation, step progress, escape hatch |
| Layout | Row: back arrow (left), title (center), "Skip" text button (right) |
| Back arrow | Navigates to previous step. On Step 1, navigates back to Add Track flow. |
| "Skip" button | Always visible. Triggers "Start minimal" — skips to Goal Setup with no seeding. |
| Step indicator | Linear dot indicator below app bar. Filled dots for completed steps, outlined for remaining. |

---

### Section: S14 Quick Path Selection

**OBJECT ID:** `seeding-s14-quickpaths`

| Property | Value |
|----------|-------|
| Purpose | Let program joiners choose a seeding strategy in 1 tap |
| Layout | Vertical stack of 3 tappable cards |
| Data source | `programPositionProvider(programId)` for current daf number and label |

#### Quick-Path Card

**OBJECT ID:** `seeding-s14-quickpath-card`

| Property | Value |
|----------|-------|
| Component | Material 3 `Card` (outlined) |
| Layout | Column: title + description |
| Corner radius | 12dp |
| Padding | `md` (16dp) all sides |
| Tap | Advances to the variant-specific confirmation step |

**Card variants:**

| Variant | Title | Description | Badge |
|---------|-------|-------------|-------|
| Align with program | "Align with program" | "Start from today's daf. {N} dapim marked as skipped." | Star icon (recommended) |
| Start from beginning | "Start from the beginning" | "You'll be {N} dapim behind the program." | None |
| Custom start point | "Custom start point" | "Choose where to begin." | None |

**States:**

| State | Appearance |
|-------|------------|
| Default | Cards with outlined border |
| Tapped | Ripple + filled primary-container background briefly before advancing |

---

### Section: S14 Confirmation

**OBJECT ID:** `seeding-s14-confirm`

| Property | Value |
|----------|-------|
| Purpose | Show what will happen before committing |
| Layout | Centered text block + single "Confirm" button |

**Variants:**

| Quick Path | Confirmation Text |
|------------|-------------------|
| Align | "{N} dapim will be marked as skipped (amnesty). You'll start tracking from {dafLabel}." |
| Beginning | "You'll be {N} dapim behind the program. You can amnesty items later as you go." |
| Custom | After browser selection: "{N} items before {selectedDaf} will be marked as {learned/amnesty}. You'll start tracking from {selectedDaf}." |

---

### Section: S14 Custom Start Point Browser

**OBJECT ID:** `seeding-s14-custom-browser`

| Property | Value |
|----------|-------|
| Purpose | Let the learner pick a starting daf and choose what to do with earlier items |
| Layout | Scrollable list of curriculum items + radio group for bulk action |
| Data source | `curriculumItemsProvider(trackId)` |
| Item row height | 48dp |
| Selected item | Highlighted with `primaryContainer` background |
| Radio group | "Everything before your start:" with options "Mark as learned" / "Mark as skipped (amnesty)" |
| Default radio | "Mark as skipped (amnesty)" |
| Continue button | Disabled until a starting item is selected |

---

### Section: S14 Cross-Credit Prompt

**OBJECT ID:** `seeding-s14-crosscredit`

| Property | Value |
|----------|-------|
| Purpose | Offer cross-credit if another track shares the same curriculum |
| Visible | Only when `sharedCurriculumTracksProvider(curriculumId)` returns 1+ other active tracks |
| Skipped | When no shared curriculum tracks exist — flow advances directly to Goal Setup |
| Layout | Centered text + 3 action buttons (horizontal row) |
| Buttons | "Yes" (filled primary), "No" (outlined), "Decide later" (text) |
| "Decide later" effect | Sets `crossCreditDecision = deferred` on the track; surfaces as a reminder in Settings later |

---

### Section: S15 Unit Type Selector

**OBJECT ID:** `seeding-s15-unittype`

| Property | Value |
|----------|-------|
| Purpose | Let the learner choose their primary unit type for the curriculum hierarchy (per NQ1) |
| Visible | Only when the curriculum supports multiple unit types. Skipped otherwise. |
| Layout | Prompt text + vertical radio list + "Continue" button |
| Options | Determined by `curriculumUnitTypesProvider(curriculumId)` — typically "By masechta", "By perek", "By seder" |
| Default selection | The curriculum's default `primary_unit_type` |
| Data write | Updates `primary_unit_type` on `curriculum_tracks` if changed |

---

### Section: S15 Hierarchy Browser

**OBJECT ID:** `seeding-s15-browser`

| Property | Value |
|----------|-------|
| Purpose | Batch-mark units and optionally drill in for individual item overrides |
| Layout | Scrollable list grouped by parent (seder), with per-unit action rows |
| Data source | `curriculumHierarchyProvider(trackId, primaryUnitType)` |
| Adaptive depth | Small curricula (<20 items total): show items directly, no unit grouping. Large curricula (>=20 items): show units first, drill-in for items. |
| Footer | Running tally: "{N} learned, {N} amnestied, {N} deferred" |
| Continue button | Always enabled (all items default to "Defer") |

#### Seder Header Row

**OBJECT ID:** `seeding-s15-browser-seder`

| Property | Value |
|----------|-------|
| Layout | Full-width text header |
| Style | `labelLarge`, `onSurfaceVariant` color, `sm` (8dp) vertical padding |

#### Unit Row

**OBJECT ID:** `seeding-s15-browser-unit`

| Property | Value |
|----------|-------|
| Layout | Row: status icon (leading), unit label (center), action dropdown (trailing), chevron (far trailing, conditional) |
| Status icon | Filled square (learned), half-filled square (partial), empty square (defer), strikethrough square (amnesty) |
| Action dropdown | `DropdownButton` with options: Learned, Amnesty, Defer, Partial... |
| Default action | Defer |
| Chevron | Visible when action is "Learned" or "Partial...". Tapping expands the inline drill-in. |
| Chazara trigger | When a unit is set to "Learned" and the chevron is tapped, a "How many times reviewed?" prompt appears as a bottom sheet before expanding items. |
| Batch behavior | Selecting "Learned" or "Amnesty" on a unit applies that action to ALL items within the unit. |
| "Partial..." behavior | Sets the unit action to "Partial", expands the inline drill-in showing all items with individual action toggles. |
| Height | 56dp |
| Separator | 1dp `outlineVariant` between rows |

**Unit Row States:**

| State | Icon | Row Background | Action Label |
|-------|------|----------------|--------------|
| Defer (default) | `░░` empty | Default surface | "Defer" |
| Learned | `██` filled | `primaryContainer` at 10% opacity | "Learned" |
| Amnesty | `▓▓` strikethrough | `tertiaryContainer` at 10% opacity | "Amnesty" |
| Partial | `▒▒` half-filled | `secondaryContainer` at 10% opacity | "Partial..." |

#### Drill-In Item Row

**OBJECT ID:** `seeding-s15-browser-item`

| Property | Value |
|----------|-------|
| Layout | Indented row (24dp left padding): item label + action toggle |
| Action toggle | `SegmentedButton` with 3 segments: Learned / Amnesty / Defer |
| Default | Inherits from parent unit action (Learned or Defer) |
| Height | 48dp |
| Separator | 1dp `outlineVariant` between rows |
| Per-item chazara | When an individual item is set to "Learned" on drill-in, no automatic chazara prompt. Chazara is per-unit only on batch. Per-item chazara available via long-press -> bottom sheet. |

---

### Section: Chazara Declaration Sheet

**OBJECT ID:** `seeding-chazara-sheet`

| Property | Value |
|----------|-------|
| Purpose | Optional declaration of review history for learned units |
| Trigger | Tapping chevron on a "Learned" unit row |
| Component | `BottomSheet` (modal) |
| Layout | Prompt text + horizontal chip row + "Done" button |
| Prompt | "How many times have you reviewed {unitLabel}?" |
| Options | `ChoiceChip` row: "None" (default), "Once", "Twice", "3+" |
| Data effect | Creates N additional completion records per item in the unit, with `source = "retrofit_seeding"` and sequential `completedAt` timestamps (all set to now) |
| Granularity decision | Per-unit when triggered from unit row. Per-item chazara only available on individual items within drill-in (long-press). |
| Skip | Dismissing the sheet without selecting = "None" (no chazara records) |

---

### Section: S15 Summary Confirmation

**OBJECT ID:** `seeding-s15-summary`

| Property | Value |
|----------|-------|
| Purpose | Final review before committing bulk writes |
| Layout | Stat cards column + action buttons row |

#### Summary Stats

| Stat | Icon | Description |
|------|------|-------------|
| Learned | `██` filled square | "{N} {unitLabel}s learned" |
| Amnestied | `▓▓` strikethrough square | "{N} amnestied" |
| Deferred | `░░` empty square | "{N} deferred" |
| Chazara | Cycle icon | "{N} chazara stages declared" |

#### Action Buttons

| Button | Style | Action |
|--------|-------|--------|
| "Confirm" | Filled primary, full-width | Commit all records, advance to Goal Setup |
| "Back to edit" | Text button, below Confirm | Return to Hierarchy Browser with state preserved |

---

### Section: Goal Setup (Shared)

**OBJECT ID:** `seeding-goal-setup`

| Property | Value |
|----------|-------|
| Purpose | Set pace or deadline goal so PaceCalculator has a baseline |
| Implementation | Embeds existing `GoalSetupScreen` as a step within the PageView |
| Data | Receives the newly seeded track's `trackId` |
| On complete | Advances to Done step |

---

### Section: Done Screen (Shared)

**OBJECT ID:** `seeding-done`

| Property | Value |
|----------|-------|
| Purpose | Confirmation that the track is ready |
| Layout | Centered: success icon + message + "Go to Dashboard" button |
| Icon | Animated checkmark (Lottie or custom), 64dp |
| Message | "You're all set! Your track is ready. Learning starts now." |
| Button | "Go to Dashboard" — filled primary, navigates to Dashboard with `trackId` as active track |
| Auto-advance | After 3 seconds if no tap, auto-navigates to Dashboard |

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **S14 Default** | Program track, mid-cycle join | Quick Path Selection (Step 1) | Select path, skip |
| **S14 No-gap** | Program is at beginning (no items before current) | Skip seeding entirely, go straight to Goal Setup | Goal setup |
| **S15 Default** | Personal track, "I've already started" toggled | Unit Type (if applicable) -> Hierarchy Browser | Browse, batch-mark, skip |
| **S15 Small Curriculum** | Curriculum has <20 items | Hierarchy Browser shows items directly (no unit grouping) | Mark individual items, skip |
| **S15 Large Curriculum** | Curriculum has >=20 items | Hierarchy Browser shows units first, drill-in available | Batch-mark units, drill-in, skip |
| **Loading** | Curriculum data loading | Shimmer placeholders in browser area | Skip still available |
| **Processing** | Committing bulk records (>50 items) | Full-screen progress overlay with progress bar and item count | Cancel (with confirmation dialog) |
| **Processing (small)** | Committing bulk records (<=50 items) | Optimistic UI — advance to next step immediately, write in background | None (seamless) |
| **Error** | Bulk write failure | Error banner: "Something went wrong. Your selections are saved." + "Retry" button | Retry, Back to edit |

---

## Data Sources

| Provider | Purpose | Used By |
|----------|---------|---------|
| `programPositionProvider(programId)` | Current daf number, label, total items in cycle | S14 Quick Paths |
| `sharedCurriculumTracksProvider(curriculumId)` | Other active tracks sharing this curriculum | S14 Cross-Credit |
| `curriculumUnitTypesProvider(curriculumId)` | Available unit type options for the curriculum | S15 Unit Type Selector |
| `curriculumHierarchyProvider(trackId, primaryUnitType)` | Hierarchical curriculum structure (seder -> unit -> item) | S15 Browser, S14 Custom Browser |
| `curriculumItemsProvider(trackId)` | Flat list of all curriculum items | S14 Custom Browser |

### Data Writes (on Confirm)

| Record Type | Fields | Condition |
|-------------|--------|-----------|
| `completions` | `completedAt = now`, `source = "retrofit_seeding"`, `stageIndex = 0` | Each item marked "Learned" |
| `completions` (chazara) | `completedAt = now`, `source = "retrofit_seeding"`, `stageIndex = 1..N` | Each declared chazara stage per learned item |
| `item_amnesty` | `amnestyAt = now`, `source = "retrofit_seeding"` | Each item marked "Amnesty" |
| `primary_unit_type` | Updated on `curriculum_tracks` | If S15 unit type was changed from default |
| `track_action_log` | `action = "setup_seeding"`, `source = "setup_seeding"`, details JSON | Always (audit trail) |
| `cross_credit_config` | `enabled = true/false`, `decision = "yes"/"no"/"deferred"` | If S14 cross-credit prompt was shown |
| Goal configuration | Via existing `GoalSetupScreen` write path | Always (final step) |

### Transaction Handling

| Batch Size | Strategy |
|------------|----------|
| <= 50 items | Optimistic UI: advance to next step immediately, write in background. Rollback on failure with error snackbar + "Retry". |
| > 50 items | Progress overlay: modal progress bar showing "{N}/{total} items processed". All writes wrapped in a single DB transaction (all-or-nothing). Cancel button shows confirmation dialog ("Your selections will be saved but not committed. Continue?"). |

---

## Animations

| Element | Animation | Duration | Easing |
|---------|-----------|----------|--------|
| Step transition | PageView slide (horizontal) | 300ms | `Curves.easeInOut` |
| Step indicator dot fill | Color fill left-to-right | 200ms | `Curves.easeIn` |
| Unit row action change | Background color crossfade | 150ms | `Curves.easeOut` |
| Drill-in expand | Height expand with content fade-in | 250ms | `Curves.easeInOut` |
| Drill-in collapse | Height collapse with content fade-out | 200ms | `Curves.easeOut` |
| Chazara bottom sheet | Slide up from bottom | 250ms | `Curves.easeOut` |
| Processing progress bar | Linear indeterminate -> determinate on commit | Continuous | Linear |
| Done checkmark | Lottie check animation | 800ms | Built-in |
| Summary stat entrance | Staggered fade + slide up (50ms delay between stats) | 300ms each | `Curves.easeOut` |

---

## Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Touch targets | Minimum 48dp (56dp in child mode) for all interactive elements |
| Screen reader — step progress | Step indicator announces "Step {N} of {total}" on focus |
| Screen reader — unit row | Announces "{unitLabel}, current action {action}, tap to change, double-tap to expand" |
| Screen reader — action dropdown | Standard `DropdownButton` semantics. Options announced individually. |
| Screen reader — drill-in items | Each item row announces "{itemLabel}, current action {action}" |
| Screen reader — chazara sheet | Modal sheet announced. Chip selection announced on change. |
| Screen reader — summary | Each stat announced: "{count} {unitLabel}s {action}" |
| Screen reader — processing | Progress bar announces percentage. Completion announced. |
| Focus order | Top-to-bottom: header -> step indicator -> content -> action buttons |
| High contrast | All status icons use both color and shape (filled/empty/strikethrough) — not color-only |
| Reduced motion | Step transitions use instant swap (no slide). Drill-in expand/collapse instant. Done screen skips Lottie animation. |
| RTL support | Layout mirrors. Hebrew text renders naturally RTL. Step indicator direction reverses. |

---

## Acceptance Criteria

### S14 — Program Launch Day

- [ ] Quick path "Align with program" creates `item_amnesty` records for all items before current program position with `source = "retrofit_seeding"`
- [ ] Quick path "Align with program" completes in 3 taps (select -> confirm -> goal done) in under 30 seconds
- [ ] Quick path "Start from beginning" creates no seeding records and shows behind-count warning
- [ ] Quick path "Custom start point" allows selecting a starting item and choosing learned vs amnesty for earlier items
- [ ] Cross-credit prompt appears ONLY when another track shares the curriculum, AFTER seeding is complete
- [ ] Cross-credit "Decide later" stores a deferred decision (not a "No")
- [ ] When program is at beginning (no gap), seeding flow is skipped entirely — routes straight to Goal Setup

### S15 — Personal Track Retrofit

- [ ] Unit type selector appears only when curriculum supports multiple unit types
- [ ] Unit type change persists as `primary_unit_type` on `curriculum_tracks`
- [ ] Hierarchy browser shows units grouped by seder for large curricula (>=20 items)
- [ ] Hierarchy browser shows items directly for small curricula (<20 items)
- [ ] Batch-marking a unit as "Learned" applies to all items in the unit
- [ ] Batch-marking a unit as "Amnesty" applies to all items in the unit
- [ ] "Partial..." on a unit expands inline drill-in with per-item action toggles
- [ ] Drill-in items inherit parent unit action as default
- [ ] Chazara declaration bottom sheet appears when tapping chevron on a "Learned" unit
- [ ] Chazara declaration is optional — dismissing sheet defaults to "None"
- [ ] Chazara creates additional completion records with `source = "retrofit_seeding"` and sequential `stageIndex` values
- [ ] Summary screen shows accurate counts of learned, amnestied, deferred, and chazara stages
- [ ] "Back to edit" from summary returns to browser with all selections preserved
- [ ] "Confirm" writes all records in a single transaction

### Shared

- [ ] All completion records have `completedAt = now` and `source = "retrofit_seeding"`
- [ ] All amnesty records have `source = "retrofit_seeding"`
- [ ] "Skip" (Start minimal) is available on every step — routes to Goal Setup with no seeding records
- [ ] Goal Setup appears as the penultimate step in both variants
- [ ] Done screen auto-advances to Dashboard after 3 seconds
- [ ] Back navigation from Step 1 returns to Add Track flow with no records written
- [ ] Batch writes >50 items show progress overlay with progress bar
- [ ] Batch writes <=50 items use optimistic UI (no blocking overlay)
- [ ] Write failure shows error with "Retry" — selections are not lost
- [ ] Replaces `BulkMarkScreen` — old route redirects to new flow
- [ ] `track_action_log` entry created with `source = "setup_seeding"` for every completed flow

---

## Design Decisions (Resolved)

| # | Decision | Resolution |
|---|----------|------------|
| 1 | Hierarchy depth | Adaptive. Small curricula (<20 items) show items directly with no unit grouping. Large curricula (>=20 items) show units first with drill-in for items. |
| 2 | Batch-then-override UX | Unit row shows a chevron when action is "Learned" or "Partial...". Tapping chevron expands items inline beneath the unit row. No separate screen. |
| 3 | Chazara declaration granularity | Per-unit on batch (bottom sheet triggered from unit chevron). Per-item only available on drill-in via long-press. Keeps the common case fast. |
| 4 | Transaction handling | Progress bar overlay for >50 items (single DB transaction, all-or-nothing). Optimistic UI for <=50 items (background write, rollback on failure). |
| 5 | Cross-credit timing | After seeding completes, before Goal Setup. Does not interrupt the seeding flow. |

---

## Open Questions

| # | Question | Context | Status |
|---|----------|---------|--------|
| 1 | Cycle-boundary amnesty tagging | When a new cycle begins, should old amnesties from seeding be tagged with the previous cycle? The scenario mentions this but the mechanism is unclear. | Open |
| 2 | Maximum batch size | Is there an upper bound on items that can be seeded in one transaction? Bavli has ~2,700 dapim. | Open |

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined (ASCII art for all steps)
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All states documented
- [x] Both variants (S14, S15) fully specified
- [x] Component properties and behaviors defined
- [x] Data sources and write operations documented
- [x] Transaction handling strategy defined
- [x] Animations specified
- [x] Accessibility requirements documented
- [x] Acceptance criteria comprehensive
- [x] Design decisions resolved with rationale
- [x] Open questions tracked

---

_Created using Whiteport Design Studio (WDS) methodology_
