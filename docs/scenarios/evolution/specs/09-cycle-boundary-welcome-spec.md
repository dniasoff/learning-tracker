# 09 — Cycle Boundary Welcome

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Cycle Boundary Welcome Flow |
| **Route** | `/cycle-boundary/{trackId}` (full-screen interstitial, pushed above shell) |
| **Platform** | Mobile (Flutter / Android) |
| **Page Type** | Full-screen interstitial route (not dismissible via back gesture) |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |
| **Scenario doc** | `../scenarios/09-cycle-boundary-welcome.md` |

---

## Overview

**Surface Purpose:** Celebrate the completion of a program track cycle and let the learner choose how to transition into the next cycle — start fresh (default), carry forward previous amnesty items, or review before deciding.

**User Situation:** Learner opens the app after a program track's cycle boundary has passed (e.g., Daf Yomi Cycle 13 ended, Cycle 14 begins). This is a rare, significant moment (once every ~7.5 years for Daf Yomi). Two variants: active participant (has completions in previous cycle) and non-participant (zero completions). The flow must feel celebratory for participants and welcoming for non-participants.

**Success Criteria:**
- Flow triggers exactly once per cycle boundary per track — never repeats
- "Start fresh" completes in one tap (default, easiest path)
- Previous cycle amnesty records are preserved (never deleted), scoped to old `cycle_tag`
- Cycle tag update is atomic — no inconsistent state between old and new cycle
- Celebratory tone for active participants; neutral/welcoming for non-participants
- Multiple simultaneous cycle boundaries handled sequentially, one flow per track

**Entry Points:**
- App open auto-trigger: `CycleDetector` compares `current_cycle_tag` with computed current cycle from program metadata
- Push notification deep link: "A new Daf Yomi cycle begins today!" taps into this flow

**Exit Points:**
- [Start fresh] / [Start tracking from today] -> Dashboard (cycle tag updated)
- [Carry forward skipped items] -> Dashboard (amnesty records duplicated + cycle tag updated)
- [Review previous cycle] -> AmnestyHistoryScreen (filtered) -> return to this screen
- [Set up from a different point] -> SetupSeedingScreen (S14 variant)

---

## Design Decisions (Resolved)

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| 1 | Cycle detection source | **Program metadata with computed boundaries** | Daf Yomi has a fixed ~7.5-year schedule computable from its known start date. Server-side program metadata stores cycle start dates; the app computes which cycle is current from the date. No hardcoded dates in client code. |
| 2 | Carry-forward granularity | **All-or-nothing default; per-item selection via review path** | [Carry forward skipped items] duplicates all previous cycle amnesty records. Learner who wants per-item control taps [Review previous cycle] first, selects specific items, then confirms carry-forward of selection only. |
| 3 | Multiple tracks at cycle boundary | **Sequential flows in triage order** | Each track gets its own full-screen interstitial. If two program tracks hit cycle boundary simultaneously, the learner completes one flow before seeing the next. Order follows existing triage priority (most urgent track first). |
| 4 | Push notification | **One celebratory push per cycle boundary with deep link** | Notification text: "A new {programName} cycle begins today!" Deep link opens this interstitial. Notification fires on the computed cycle start date regardless of app open state. |

---

## Layout Structure

### Active Participant Variant

```
┌──────────────────────────────────────┐
│                                      │
│           (celebration icon)         │
│                                      │
│      A new cycle begins.             │
│      Welcome to {programName}        │
│      Cycle {newCycleNumber}.         │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  CYCLE {prevCycleNumber} STATS │  │
│  │  {completedCount} dapim        │  │
│  │  {masechtoCount} masechtos     │  │
│  └────────────────────────────────┘  │
│                                      │
│  Your {skippedCount} skipped items   │
│  from Cycle {prevCycleNumber} are    │
│  archived. This cycle starts         │
│  fresh — nothing is "behind."        │
│                                      │
│  ┌────────────────────────────────┐  │
│  │       Start fresh              │  │
│  │  Clean slate. Cycle {N}, day 1.│  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │   Carry forward skipped items  │  │
│  │  Keep previous amnesty active  │  │
│  │  in Cycle {N}.                 │  │
│  └────────────────────────────────┘  │
│                                      │
│  [Review previous cycle]             │
│   Browse what you skipped before     │
│   deciding.                          │
│                                      │
└──────────────────────────────────────┘
```

### Non-Participant Variant

```
┌──────────────────────────────────────┐
│                                      │
│           (welcome icon)             │
│                                      │
│  A new {programName} cycle           │
│  is starting.                        │
│  Cycle {newCycleNumber}, day 1.      │
│                                      │
│                                      │
│  ┌────────────────────────────────┐  │
│  │   Start tracking from today    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Set up from a different point  │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

**Scroll behavior:** Content fits single viewport in both variants. If device height is constrained (< 600dp), wrap in `SingleChildScrollView` to prevent overflow.

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `lg` (24dp) |
| Page padding (vertical) | `xl` (32dp) top, `lg` (24dp) bottom |
| Icon to headline gap | `lg` (24dp) |
| Headline to stats card gap | `lg` (24dp) |
| Stats card to explanation gap | `md` (16dp) |
| Explanation to primary button gap | `xl` (32dp) |
| Button gap (between action cards) | `md` (16dp) |
| Tertiary link below buttons gap | `md` (16dp) |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Style | Size | Weight |
|---------|-------|------|--------|
| Headline ("A new cycle begins.") | `headlineSmall` | 24sp | bold |
| Cycle name ("Welcome to...Cycle 14.") | `titleLarge` | 22sp | normal |
| Stats number | `headlineMedium` | 28sp | bold |
| Stats label ("dapim", "masechtos") | `bodyMedium` | 14sp | normal |
| Explanation paragraph | `bodyLarge` | 16sp | normal |
| Primary button label | `labelLarge` | 14sp | w500 |
| Button subtitle | `bodySmall` | 12sp | normal |
| Tertiary link text | `bodyMedium` | 14sp | w500 |
| Non-participant headline | `headlineSmall` | 24sp | normal |

---

## Page Sections

### Section: Celebration Icon

**OBJECT ID:** `cycle-boundary-icon`

| Property | Value |
|----------|-------|
| Active variant | Decorative celebration icon (e.g., sparkles or scroll motif). Static PNG or Lottie if available. |
| Non-participant variant | Neutral welcome icon (e.g., sunrise or calendar) |
| Size | 80dp x 80dp |
| Alignment | Center |
| Semantics | Decorative — `excludeFromSemantics: true` |

---

### Section: Headline

**OBJECT ID:** `cycle-boundary-headline`

| Property | Value |
|----------|-------|
| Active variant, line 1 | "A new cycle begins." (`headlineSmall`, bold) |
| Active variant, line 2 | "Welcome to {programName} Cycle {newCycleNumber}." (`titleLarge`) |
| Non-participant, line 1 | "A new {programName} cycle is starting." (`headlineSmall`) |
| Non-participant, line 2 | "Cycle {newCycleNumber}, day 1." (`titleLarge`) |
| Alignment | Center |
| Color | `onSurface` |

---

### Section: Cycle Stats Card (Active Variant Only)

**OBJECT ID:** `cycle-boundary-stats`

| Property | Value |
|----------|-------|
| Visible | Active participant variant only |
| Component | Material 3 `Card` (filled, `surfaceContainerLow`) |
| Layout | Column with two stat rows, center-aligned |
| Padding | `md` (16dp) all sides |
| Corner radius | 12dp |
| Data source | `LifetimeProgressSummary` scoped to `previous_cycle_tag` |

#### Stat Row: Dapim Completed

**OBJECT ID:** `cycle-boundary-stats-completed`

| Property | Value |
|----------|-------|
| Number | `{completedCount}` formatted with thousands separator |
| Label | "dapim" (or curriculum-appropriate unit from program metadata) |
| Layout | Number (`headlineMedium`, bold) + label (`bodyMedium`) in a row |

#### Stat Row: Masechtos Completed

**OBJECT ID:** `cycle-boundary-stats-masechtos`

| Property | Value |
|----------|-------|
| Number | `{masechtoCount}` |
| Label | "masechtos" (or curriculum-appropriate grouping label) |
| Layout | Number (`headlineMedium`, bold) + label (`bodyMedium`) in a row |

---

### Section: Explanation Text (Active Variant Only)

**OBJECT ID:** `cycle-boundary-explanation`

| Property | Value |
|----------|-------|
| Visible | Active participant variant only |
| Text | "Your {skippedCount} skipped items from Cycle {prevCycleNumber} are archived. This cycle starts fresh — nothing is \"behind.\"" |
| Style | `bodyLarge`, `onSurfaceVariant` color |
| Alignment | Center |
| Max width | 320dp (prevents overly wide lines on tablets) |

**Edge case — zero skipped items:** If the learner has zero amnesty records in the previous cycle, replace with: "You completed Cycle {prevCycleNumber} with nothing left behind. Cycle {newCycleNumber} starts fresh."

---

### Section: Action Buttons

#### Primary Action: Start Fresh (Active Variant)

**OBJECT ID:** `cycle-boundary-action-fresh`

| Property | Value |
|----------|-------|
| Component | Material 3 `FilledButton` (full width) |
| Label | "Start fresh" (`labelLarge`, w500) |
| Subtitle | "Clean slate. Cycle {newCycleNumber}, day 1." (`bodySmall`, `onPrimary` 70% opacity) |
| Padding | `md` (16dp) vertical |
| Corner radius | 12dp |
| Autofocus | `true` — this is the default action |
| Action | Update `current_cycle_tag` to new cycle. Previous amnesty records retain old `cycle_tag` (inert). Log `cycle_transition` action with `decision: "fresh_start"`. Show snackbar: "Cycle {N} started. Clean slate." Navigate to Dashboard. |

#### Secondary Action: Carry Forward (Active Variant)

**OBJECT ID:** `cycle-boundary-action-carry`

| Property | Value |
|----------|-------|
| Component | Material 3 `OutlinedButton` (full width) |
| Label | "Carry forward skipped items" (`labelLarge`, w500) |
| Subtitle | "Keep previous amnesty decisions active in Cycle {newCycleNumber}." (`bodySmall`, `onSurfaceVariant`) |
| Padding | `md` (16dp) vertical |
| Corner radius | 12dp |
| Action | Bulk duplicate all `item_amnesty` records from previous cycle with new `cycle_tag`. Update `current_cycle_tag`. Log `cycle_transition` action with `decision: "carry_forward", item_count: N`. Show snackbar: "{N} items carried forward. Cycle {newCycleNumber} started." Navigate to Dashboard. |

#### Tertiary Action: Review Previous Cycle (Active Variant)

**OBJECT ID:** `cycle-boundary-action-review`

| Property | Value |
|----------|-------|
| Component | `TextButton` (full width) |
| Label | "Review previous cycle" (`bodyMedium`, w500, `primary` color) |
| Subtitle | "Browse what you skipped before deciding." (`bodySmall`, `onSurfaceVariant`) |
| Action | Push `AmnestyHistoryScreen` filtered to `cycle_tag = previous_cycle_tag`. On return, learner is back on this screen with any per-item selections available. If items were selected, [Carry forward] label updates to "Carry forward {N} selected items". |

#### Primary Action: Start Tracking (Non-Participant Variant)

**OBJECT ID:** `cycle-boundary-action-start`

| Property | Value |
|----------|-------|
| Component | Material 3 `FilledButton` (full width) |
| Label | "Start tracking from today" (`labelLarge`, w500) |
| Corner radius | 12dp |
| Autofocus | `true` |
| Action | Update `current_cycle_tag` to new cycle. Log `cycle_transition` action with `decision: "start_tracking"`. Navigate to Dashboard. |

#### Secondary Action: Set Up From Different Point (Non-Participant Variant)

**OBJECT ID:** `cycle-boundary-action-setup`

| Property | Value |
|----------|-------|
| Component | Material 3 `OutlinedButton` (full width) |
| Label | "Set up from a different point" (`labelLarge`, w500) |
| Corner radius | 12dp |
| Action | Navigate to `SetupSeedingScreen` (S14 variant) with `trackId` and `cycleTag` context. On completion, cycle tag is updated as part of the seeding flow. |

---

## States & Conditions

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Active participant** | `current_cycle_tag` != computed current cycle AND learner has >0 completions in previous cycle | Full celebration layout: icon, headline, stats card, explanation, 3 action buttons | Start fresh, Carry forward, Review |
| **Non-participant** | `current_cycle_tag` != computed current cycle AND learner has 0 completions in previous cycle | Neutral layout: welcome icon, headline, 2 action buttons. No stats card, no explanation. | Start tracking, Set up from different point |
| **Loading** | Cycle stats being computed | Shimmer placeholder for stats card area. Headline visible. Buttons disabled. | None — wait for data |
| **Processing** | Learner tapped an action, write in progress | Tapped button shows circular progress indicator. All buttons disabled. | Non-interactive until complete |
| **Error** | Cycle tag update or carry-forward write fails | Error banner below explanation: "Something went wrong. Your data is safe." + [Try again] button | Retry the failed operation |
| **Review return** | Learner returns from AmnestyHistoryScreen with per-item selections | [Carry forward] button label updates to "Carry forward {N} selected items". If 0 selected, label reverts to default. | Start fresh, Carry forward (selected), Review |
| **Multi-track queue** | Multiple tracks have cycle boundaries | After completing one flow, the next track's flow is immediately presented. A subtle "1 of {N}" indicator appears top-right. | Sequential completion |

---

## Data Sources

| Provider / Query | Returns | Used By |
|------------------|---------|---------|
| `cycleDetectorProvider(trackId)` | `CycleBoundaryInfo`: `previousCycleTag`, `newCycleTag`, `newCycleNumber`, `programName` | Headline, all actions |
| `cycleStatsProvider(trackId, cycleTag)` | `CycleStats`: `completedCount`, `masechtoCount`, `skippedCount` | Stats card, explanation text |
| `previousCycleAmnestyProvider(trackId, cycleTag)` | `List<ItemAmnesty>` — amnesty records from previous cycle | Carry-forward action, review screen filter |
| `LifetimeProgressSummary` (cycle-scoped) | Aggregate completion stats scoped to a single cycle | Stats card |
| `programMetadataProvider(programId)` | `ProgramMetadata`: cycle start dates, cycle duration, unit labels ("dapim", "masechtos") | Cycle detection, display labels |

### Cycle Detection Logic

```
currentCycle = programMetadata.computeCurrentCycle(today)
// For Daf Yomi: known cycle start dates (Cycle 1: 1923-09-11),
// each cycle = 2,711 dapim at 1/day => ~7 years 5 months
// Cycle 14 starts: 2027-01-05 (computed from schedule)

if (track.currentCycleTag != currentCycle.tag) {
  // Trigger cycle boundary flow
  hasPreviousCompletions = cycleStats.completedCount > 0
  variant = hasPreviousCompletions ? ACTIVE : NON_PARTICIPANT
}
```

### Write Operations

| Operation | Trigger | Data Change |
|-----------|---------|-------------|
| Fresh start | [Start fresh] or [Start tracking from today] | `UPDATE curriculum_tracks SET current_cycle_tag = {newTag} WHERE id = {trackId}` |
| Carry forward (all) | [Carry forward skipped items] | `INSERT INTO item_amnesty (new records with new cycle_tag)` from previous cycle records + `UPDATE current_cycle_tag` — **atomic transaction** |
| Carry forward (selected) | [Carry forward] after review selection | Same as above but only for selected item IDs |
| Action log | All transitions | `INSERT INTO track_action_log (track_id, action_type, payload, created_at)` with `action_type = "cycle_transition"` |

---

## Animations

| Element | Animation | Duration | Easing |
|---------|-----------|----------|--------|
| Screen entrance | Fade in + slide up from 24dp | 400ms | `Curves.easeOutCubic` |
| Celebration icon | Subtle scale pulse (1.0 -> 1.05 -> 1.0) on mount | 600ms | `Curves.easeInOut` |
| Stats card | Fade in with 100ms stagger after headline | 300ms | `Curves.easeOut` |
| Button processing spinner | Cross-fade from label to `CircularProgressIndicator` | 200ms | `Curves.easeInOut` |
| Screen exit | Fade out | 200ms | `Curves.easeIn` |
| Multi-track transition | Cross-fade between flows | 300ms | `Curves.easeInOut` |

---

## Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Screen reader announcement | On mount: "Cycle boundary. {programName} Cycle {newCycleNumber}." |
| Celebration icon | `excludeFromSemantics: true` (decorative) |
| Stats card | `Semantics(label: "In Cycle {N}, you completed {X} dapim and {Y} masechtos")` |
| Explanation text | Default text semantics (readable) |
| Button labels | Semantic labels include subtitle context: e.g., "Start fresh. Clean slate. Cycle {N}, day 1." |
| Focus order | Icon (skipped) -> Headline -> Stats -> Explanation -> Start fresh -> Carry forward -> Review |
| Minimum touch targets | 48dp (adult mode), 56dp (child mode) |
| High contrast | All text meets WCAG AA contrast on `surface` background |
| Reduced motion | Skip celebration icon pulse; instant fade transitions |

---

## Notification

| Property | Value |
|----------|-------|
| Trigger | Computed cycle start date, scheduled via local notification on program track setup |
| Title | "A new {programName} cycle begins today!" |
| Body | Active participant: "Cycle {prevN} complete. Tap to see your stats." / Non-participant: "Cycle {newN}, day 1. Start tracking today." |
| Deep link | `/cycle-boundary/{trackId}` |
| Channel | Celebratory (higher priority, default sound) |
| Frequency | One notification per cycle boundary per track. Never repeated. |
| Fallback | If notification is missed, the interstitial still triggers on next app open |

---

## Edge Cases

| Case | Handling |
|------|----------|
| App opened offline | Cycle detection uses locally cached program metadata. All writes are local-first. Flow proceeds normally. |
| Learner force-kills app mid-flow | Cycle tag not yet updated, so flow re-triggers on next app open. No data corruption — writes are atomic. |
| Multiple tracks at boundary | Sequential flows. Track order follows triage priority. "1 of {N}" indicator shown. Each flow is independent. |
| Track with 0 amnesty items but has completions | Active variant shown (celebratory) but explanation text uses the zero-skipped variant: "You completed Cycle {N} with nothing left behind." |
| Carry-forward with very large item count (100+) | Show count in confirmation: "Carry forward {N} items into Cycle {newN}?" Processing state with progress indicator. |
| Learner reviews but selects 0 items | On return, [Carry forward] label reverts to default (all items). Learner can still tap [Start fresh]. |
| Cycle boundary detected but track is paused | Queue the flow. Present it when the learner resumes the track (after PauseResumeCard flow completes). |
| Program metadata missing cycle info | Do not trigger flow. Log warning. Cycle detection is a no-op for programs without defined cycle boundaries. |

---

## Acceptance Criteria

- [ ] Flow triggers exactly once per cycle boundary per program track
- [ ] Active participant variant shows celebration headline, stats card with correct counts, explanation with skipped count, and three action buttons
- [ ] Non-participant variant shows neutral headline and two action buttons (no stats, no explanation)
- [ ] [Start fresh] updates `current_cycle_tag` atomically, preserves previous amnesty records with old `cycle_tag`, navigates to Dashboard, shows snackbar
- [ ] [Carry forward skipped items] duplicates all previous cycle amnesty records with new `cycle_tag` in atomic transaction, updates `current_cycle_tag`, navigates to Dashboard
- [ ] [Review previous cycle] opens `AmnestyHistoryScreen` filtered to previous `cycle_tag`; returning updates carry-forward button with selected item count
- [ ] Per-item carry-forward works: after review, only selected items are duplicated
- [ ] [Start tracking from today] (non-participant) updates `current_cycle_tag` and navigates to Dashboard
- [ ] [Set up from a different point] (non-participant) navigates to `SetupSeedingScreen` (S14 variant)
- [ ] Multiple simultaneous cycle boundaries present sequential flows with "1 of N" indicator
- [ ] Paused tracks defer cycle boundary flow until resume
- [ ] `track_action_log` records `cycle_transition` with decision type and item count
- [ ] Push notification fires on cycle start date with correct text and deep link
- [ ] Flow is not dismissible via back gesture or system back — learner must choose an action
- [ ] Error state shows retry option; no data corruption on failure
- [ ] All buttons meet minimum touch target (48dp adult / 56dp child)
- [ ] Screen reader announces cycle boundary context on mount
- [ ] Reduced motion preference disables icon animation

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined (both variants)
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All states documented
- [x] Data sources and write operations defined
- [x] Cycle detection logic specified
- [x] Design decisions resolved
- [x] Edge cases covered
- [x] Animations specified
- [x] Accessibility requirements defined
- [x] Acceptance criteria complete
- [x] Notification behavior specified

---

_Created using Whiteport Design Studio (WDS) methodology_
