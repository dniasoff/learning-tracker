# 08 — Returning Learner Welcome

## Page Metadata

| Property | Value |
|----------|-------|
| **Scenario** | Returning Learner Onboarding (S9) |
| **Route** | `/welcome-back` (full-screen interstitial, pushed before dashboard) |
| **Platform** | Mobile (Flutter) |
| **Page Type** | Full-screen interstitial route |
| **Interaction** | Touch-first |
| **Visibility** | Authenticated |
| **Component** | `ReturningLearnerScreen` |
| **Variant enum** | `WelcomeVariant { dormancyReturn, pauseReturn }` |

---

## Overview

**Page Purpose:** Provide a warm, zero-shame re-entry point for learners returning after a significant absence. Intercepts app open before the dashboard so the learner never sees accumulated debt counters cold.

**User Situation:** Learner opens the app for the first time in 14+ days (dormancy return) or after a fixed-duration pause expires (pause return). They may feel guilt or overwhelm. This screen reframes the moment positively and offers clear, low-pressure next steps.

**Success Criteria:** Learner feels welcomed (not shamed), understands their options within 5 seconds, and can act or dismiss freely. Zero debt numbers visible.

**Entry Points:**
- App open with `daysDormant > 14` on any track AND no prior welcome for this dormancy gap
- App open after a fixed-duration pause expires AND no prior welcome for this pause expiry

**Exit Points:**
- [Start triage] -> `TriageSheet` (multi-track dormancy or pause return)
- [Quick reboot] / [Gentle resume] / [Ambitious catch-up] -> `CatchupSheet` (single-track dormancy)
- [Pause everything for a week] -> `PausePicker` (bulk mode)
- [Extend pause] -> `PausePicker` (extend mode, pause-return only)
- [Just browse] -> Pop route, reveal dashboard (triage banner persists if conditions hold)

---

## Layout Structure

### Dormancy Return — Multi-track

```
┌──────────────────────────────────────┐
│                                      │
│              (illustration)          │
│                                      │
│      Great to see you again!         │
│                                      │
│  ┌──────────────────────────────────┐│
│  │  LifetimeProgressSummary        ││
│  │  You've learned 142 items       ││
│  │  across 3 tracks.               ││
│  └──────────────────────────────────┘│
│                                      │
│  ┌──────────────────────────────────┐│
│  │  Let's get you sorted.          ││
│  │  Quick triage: 3 tracks need    ││
│  │  a decision — takes ~2 min.     ││
│  │                                 ││
│  │  [  Start triage  ]  (primary)  ││
│  └──────────────────────────────────┘│
│                                      │
│  [Pause everything for a week] (txt) │
│  [Just browse]                 (txt) │
│                                      │
└──────────────────────────────────────┘
```

### Dormancy Return — Single-track

```
┌──────────────────────────────────────┐
│                                      │
│              (illustration)          │
│                                      │
│      Great to see you again!         │
│                                      │
│  ┌──────────────────────────────────┐│
│  │  LifetimeProgressSummary        ││
│  │  You've learned 38 dapim        ││
│  │  of Bavli Berachos.             ││
│  └──────────────────────────────────┘│
│                                      │
│  [Quick reboot]        (primary btn) │
│  [Gentle resume]       (outlined)    │
│  [Ambitious catch-up]  (outlined)    │
│  [Just browse]         (text btn)    │
│                                      │
└──────────────────────────────────────┘
```

### Pause Return

```
┌──────────────────────────────────────┐
│                                      │
│              (illustration)          │
│                                      │
│  Ready to get back on track?         │
│  Let's see where things stand.       │
│                                      │
│  [  Start triage  ]    (primary btn) │
│  [  Extend pause  ]    (outlined)    │
│  [Just browse]         (text btn)    │
│                                      │
└──────────────────────────────────────┘
```

**Scroll behavior:** Content is vertically centered if it fits the viewport. If content overflows (unlikely on standard screens), wraps in a `SingleChildScrollView` with center alignment.

---

## Spacing

**Scale:** Design system tokens (4dp base)

| Property | Token |
|----------|-------|
| Page padding (horizontal) | `lg` (24dp) |
| Page padding (vertical) | `xl` (32dp) top, `lg` (24dp) bottom |
| Illustration to greeting | `lg` (24dp) |
| Greeting to stats block | `md` (16dp) |
| Stats block to triage card | `lg` (24dp) |
| Triage card to secondary actions | `md` (16dp) |
| Between action buttons | `sm` (8dp) |
| Between secondary text buttons | `xs` (4dp) |

---

## Typography

**Scale:** Noto Sans Hebrew (primary) + Noto Sans (fallback)

| Element | Style | Size | Weight |
|---------|-------|------|--------|
| Greeting headline | `headlineSmall` | 24sp | bold |
| Greeting subtitle (pause variant) | `bodyLarge` | 16sp | normal |
| Stats summary text | `bodyLarge` | 16sp | normal |
| Triage card heading | `titleMedium` | 16sp | w500 |
| Triage card body | `bodyMedium` | 14sp | normal |
| Primary action button | `labelLarge` | 14sp | w500 |
| Secondary action button | `labelLarge` | 14sp | normal |
| Text button (Just browse) | `bodyMedium` | 14sp | normal |

---

## Page Sections

### Section: Illustration

**OBJECT ID:** `welcome-illustration`

| Property | Value |
|----------|-------|
| Purpose | Warm visual anchor, sets tone before text |
| Asset | Soft illustration (no characters — abstract warmth). Same asset for both variants. |
| Size | 120dp x 120dp max |
| Alignment | Center |

---

### Section: Greeting

**OBJECT ID:** `welcome-greeting`

| Property | Value |
|----------|-------|
| Layout | Column, center-aligned |

#### Greeting — Dormancy Return

**OBJECT ID:** `welcome-greeting-dormancy`

| Property | Value |
|----------|-------|
| Headline | "Great to see you again!" |
| Style | `headlineSmall`, bold, `onSurface` color |
| Subtitle | None (stats block carries the warmth) |

#### Greeting — Pause Return

**OBJECT ID:** `welcome-greeting-pause`

| Property | Value |
|----------|-------|
| Headline | "Ready to get back on track?" |
| Style | `headlineSmall`, bold, `onSurface` color |
| Subtitle | "Let's see where things stand." |
| Subtitle style | `bodyLarge`, `onSurfaceVariant` color |

---

### Section: Lifetime Progress Summary

**OBJECT ID:** `welcome-stats`

| Property | Value |
|----------|-------|
| Component | `LifetimeProgressSummary` (reusable) |
| Visible | Dormancy return variant ONLY. Hidden for pause return. |
| Layout | Material 3 `Card` (filled, `surfaceContainerLow`), center-aligned text |
| Corner radius | 12dp |
| Padding | `md` (16dp) all sides |

#### Stats Content — Multi-track

| Property | Value |
|----------|-------|
| Template | "You've learned {totalItems} items across {activeTrackCount} tracks." |
| Data | `totalItemsLearned` from aggregate completion count, `activeTrackCount` from active tracks |
| Style | `bodyLarge`, `onSurface` color |

#### Stats Content — Single-track

| Property | Value |
|----------|-------|
| Template | "You've learned {totalItems} {unitLabel} of {trackName}." |
| Data | Track-specific completion count + content unit label (e.g., "dapim", "perakim") |
| Style | `bodyLarge`, `onSurface` color |

#### Stats Rules

- Never show streak count (likely broken — would feel punitive)
- Never show debt / behind counts
- Use content-native units where possible (dapim, perakim), fall back to "items"
- Numbers are factual and understated — no superlatives ("Amazing!" etc.)

---

### Section: Triage Card (Multi-track Dormancy + Pause Return)

**OBJECT ID:** `welcome-triage-card`

| Property | Value |
|----------|-------|
| Visible | Multi-track dormancy return OR any pause return |
| Layout | Material 3 `Card` (outlined), vertically stacked |
| Corner radius | 12dp |
| Padding | `md` (16dp) all sides |

#### Triage Card — Dormancy Variant

| Property | Value |
|----------|-------|
| Heading | "Let's get you sorted." (`titleMedium`, w500) |
| Body | "Quick triage: {N} tracks need a decision — takes ~2 min." (`bodyMedium`, `onSurfaceVariant`) |
| Primary action | [Start triage] — `FilledButton`, full width |

#### Triage Card — Pause Variant

| Property | Value |
|----------|-------|
| Card | Not used — actions are standalone buttons (no card wrapper) |

---

### Section: Single-track Actions (Single-track Dormancy Only)

**OBJECT ID:** `welcome-single-actions`

| Property | Value |
|----------|-------|
| Visible | Single-track dormancy return ONLY |
| Layout | Column of buttons, full width, vertically stacked |

#### Action: Quick Reboot

**OBJECT ID:** `welcome-action-reboot`

| Property | Value |
|----------|-------|
| Text | "Quick reboot" |
| Subtext | "Fresh start from today" |
| Style | `FilledButton` (primary) |
| Action | Open `CatchupSheet` with `CatchupMode.reboot` for the single track |

#### Action: Gentle Resume

**OBJECT ID:** `welcome-action-resume`

| Property | Value |
|----------|-------|
| Text | "Gentle resume" |
| Subtext | "Rescope to a comfortable pace" |
| Style | `OutlinedButton` |
| Action | Open `CatchupSheet` with `CatchupMode.rescope` for the single track |

#### Action: Ambitious Catch-up

**OBJECT ID:** `welcome-action-catchup`

| Property | Value |
|----------|-------|
| Text | "Ambitious catch-up" |
| Subtext | "Close the gap over time" |
| Style | `OutlinedButton` |
| Action | Open `CatchupSheet` with `CatchupMode.amnesty` for the single track |

---

### Section: Secondary Actions

**OBJECT ID:** `welcome-secondary-actions`

| Property | Value |
|----------|-------|
| Layout | Column, center-aligned text buttons |

#### Action: Pause Everything (Dormancy Only)

**OBJECT ID:** `welcome-action-pause`

| Property | Value |
|----------|-------|
| Visible | Dormancy return variant ONLY |
| Text | "Pause everything for a week" |
| Style | `TextButton`, `onSurfaceVariant` color |
| Action | Open `PausePicker` in bulk mode (all tracks), default 7 days |
| Post-action | All tracks paused -> dismiss welcome -> dashboard shows paused state |

#### Action: Extend Pause (Pause Return Only)

**OBJECT ID:** `welcome-action-extend`

| Property | Value |
|----------|-------|
| Visible | Pause return variant ONLY |
| Text | "Extend pause" |
| Style | `OutlinedButton` |
| Action | Open `PausePicker` in extend mode |
| Post-action | Pause extended -> dismiss welcome -> dashboard shows paused state |

#### Action: Just Browse (Always)

**OBJECT ID:** `welcome-action-browse`

| Property | Value |
|----------|-------|
| Visible | Always — both variants, all track configurations |
| Text | "Just browse" |
| Style | `TextButton`, `onSurfaceVariant` color |
| Action | Pop route -> dashboard. Triage banner persists on dashboard if conditions still hold. |

---

## Page States

| State | When | Appearance | Actions |
|-------|------|------------|---------|
| **Dormancy — Multi-track** | `daysDormant > 14` on 2+ tracks, first session after gap | Greeting + stats + triage card + pause + browse | Start triage, pause all, browse |
| **Dormancy — Single-track** | `daysDormant > 14` on exactly 1 track, first session after gap | Greeting + stats + four action buttons | Reboot, resume, catch-up, browse |
| **Pause return** | Fixed-duration pause expired, first session after expiry | Action-oriented greeting + triage/extend/browse (no stats) | Start triage, extend pause, browse |
| **Loading** | Stats or track data still resolving | Skeleton shimmer for stats block; action buttons visible but disabled | None until loaded |
| **Error** | Provider failure fetching stats/tracks | Greeting still shown (hardcoded). Stats block replaced with subtle error text. Actions still functional. | All actions available (routing works independently of stats) |

---

## States & Conditions

### Variant Resolution Logic

```dart
enum WelcomeVariant { dormancyReturn, pauseReturn }

// Resolved by DormancyDetector on app open:
WelcomeVariant resolveVariant({
  required bool hasPauseExpired,
  required int daysDormant,
}) {
  if (hasPauseExpired) return WelcomeVariant.pauseReturn;
  if (daysDormant > 14) return WelcomeVariant.dormancyReturn;
  throw StateError('Welcome screen shown without valid trigger');
}
```

### Track Configuration Resolution

```dart
enum TrackConfig { multiTrack, singleTrack }

TrackConfig resolveTrackConfig(List<Track> tracksInDebt) {
  return tracksInDebt.length >= 2
      ? TrackConfig.multiTrack
      : TrackConfig.singleTrack;
}
```

### Content Matrix

| Variant | Track Config | Greeting | Stats | Primary Actions | Secondary Actions |
|---------|-------------|----------|-------|-----------------|-------------------|
| `dormancyReturn` | `multiTrack` | "Great to see you again!" | `LifetimeProgressSummary` | [Start triage] | [Pause everything], [Just browse] |
| `dormancyReturn` | `singleTrack` | "Great to see you again!" | `LifetimeProgressSummary` (single-track template) | [Quick reboot], [Gentle resume], [Ambitious catch-up] | [Just browse] |
| `pauseReturn` | any | "Ready to get back on track?" + subtitle | Hidden | [Start triage] | [Extend pause], [Just browse] |

---

## Data Sources

| Data | Provider / Source | Notes |
|------|-------------------|-------|
| Days dormant | `DormancyDetector` — compares `lastSessionTimestamp` (SharedPreferences) with current date | Computed on app open, before route decision |
| Pause expiry state | `pauseStateProvider` — checks if any bulk/track pause has expired | Checked alongside dormancy |
| Total items learned | `lifetimeStatsProvider` — aggregate completion count across all tracks | Query: `SELECT COUNT(*) FROM completions` |
| Active track count | `activeTracksProvider` — count of non-archived tracks | Existing provider |
| Tracks in debt | `tracksInDebtProvider` — tracks with `daysDormant > 14` | Used for variant + track config resolution |
| Single-track details | `trackProgressProvider(trackId)` — name, completion count, content unit label | Only fetched when `singleTrack` config |
| Show-once flag | `SharedPreferences` key: `welcome_last_shown_ts` | Timestamp of last welcome display |

### Show-Once Persistence

| Key | Type | Value |
|-----|------|-------|
| `welcome_last_shown_ts` | `int` (epoch ms) | Timestamp when welcome was last displayed |
| `welcome_last_dormancy_start` | `int` (epoch ms) | Start of the dormancy gap that triggered this welcome |

**Logic:** Welcome shows if `welcome_last_dormancy_start != currentDormancyStart`. After display, both keys are written. This ensures:
- Welcome shows once per dormancy gap (not once ever)
- If learner goes dormant again after recovery, a new welcome appears
- Survives app restart (SharedPreferences)
- No server round-trip required

---

## Animations

| Element | Animation | Duration | Curve |
|---------|-----------|----------|-------|
| Screen entrance | Fade in + slide up (32dp) | 400ms | `easeOutCubic` |
| Illustration | Fade in, slight scale (0.9 -> 1.0) | 500ms | `easeOutCubic`, 100ms delay |
| Greeting text | Fade in | 300ms | `easeOut`, 200ms delay |
| Stats card | Fade in + slide up (16dp) | 300ms | `easeOut`, 350ms delay |
| Action buttons | Fade in, staggered (50ms between each) | 250ms each | `easeOut`, 500ms base delay |
| Dismiss (Just browse) | Fade out + slide down (16dp) | 250ms | `easeInCubic` |
| Dismiss (action taken) | Fade out, then push to target route | 200ms fade, standard push transition | `easeIn` |

**Performance:** All animations use `AnimationController` with `vsync`. No heavy assets; illustration is a static vector (SVG via `flutter_svg` or pre-rendered asset).

---

## Accessibility

| Requirement | Implementation |
|-------------|---------------|
| Screen reader order | Illustration (decorative, excluded) -> greeting -> stats -> primary action -> secondary actions |
| Illustration | `Semantics(excludeSemantics: true)` — decorative only |
| Greeting | `Semantics(header: true)` for landmark navigation |
| Stats summary | Full text read as single phrase: "You've learned 142 items across 3 tracks" |
| Action buttons | Standard button semantics; subtexts merged as `Semantics(label: 'Quick reboot. Fresh start from today.')` |
| [Just browse] | `Semantics(label: 'Just browse. Dismiss and go to dashboard.')` |
| Focus order | Matches visual top-to-bottom order |
| Touch targets | Minimum 48dp (adult) / 56dp (child mode) per Material 3 guidelines |
| Motion | Respect `MediaQuery.disableAnimations` — skip entrance animations if true |
| Color contrast | All text meets WCAG 2.1 AA (4.5:1 for body, 3:1 for large text) |

---

## Acceptance Criteria

### Trigger & Display

- [ ] Welcome screen appears within 1 second of app open when `daysDormant > 14` on any track and no prior welcome for this dormancy gap
- [ ] Welcome screen appears when a fixed-duration pause expires and the learner opens the app
- [ ] Welcome screen is a full-screen route (not an overlay) — dashboard is not visible behind it
- [ ] Welcome does NOT appear on subsequent app opens after initial display for the same dormancy gap
- [ ] Welcome DOES appear again if a new dormancy gap forms after recovery
- [ ] Show-once flag persists across app restart (SharedPreferences)

### Dormancy Return — Multi-track

- [ ] Greeting reads "Great to see you again!"
- [ ] `LifetimeProgressSummary` shows total items learned and active track count
- [ ] Zero debt numbers are visible anywhere on the screen
- [ ] Triage card shows track count needing decisions and estimated time
- [ ] [Start triage] opens `TriageSheet`
- [ ] [Pause everything for a week] opens `PausePicker` in bulk mode with 7-day default
- [ ] [Just browse] dismisses to dashboard; triage banner persists on dashboard

### Dormancy Return — Single-track

- [ ] Greeting reads "Great to see you again!"
- [ ] `LifetimeProgressSummary` shows track-specific stats with content-native units
- [ ] [Quick reboot] opens `CatchupSheet` with reboot mode
- [ ] [Gentle resume] opens `CatchupSheet` with rescope mode
- [ ] [Ambitious catch-up] opens `CatchupSheet` with amnesty mode
- [ ] [Just browse] dismisses to dashboard

### Pause Return

- [ ] Greeting reads "Ready to get back on track?" with subtitle "Let's see where things stand."
- [ ] NO lifetime stats are shown
- [ ] [Start triage] opens `TriageSheet`
- [ ] [Extend pause] opens `PausePicker` in extend mode
- [ ] [Just browse] dismisses to dashboard

### General

- [ ] Learner is never trapped — [Just browse] is always visible and functional
- [ ] No streak counts shown (would feel punitive if broken)
- [ ] Screen entrance animation completes within 600ms
- [ ] Animations are skipped when `disableAnimations` is true
- [ ] All action buttons meet minimum 48dp touch target
- [ ] Screen reader can navigate all elements in logical order
- [ ] Loading state shows shimmer for stats, buttons visible but disabled
- [ ] Error state still shows greeting and all action buttons (stats replaced with subtle error text)

---

## Design Decisions (Resolved)

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| 1 | Interstitial vs overlay | Full-screen route | Dashboard behind would show alarming debt counters, defeating the warm re-entry purpose |
| 2 | Stats selection | Total items learned + tracks active | Most universally meaningful; avoids streak (likely broken) and debt (explicitly excluded) |
| 3 | Show-once persistence | SharedPreferences with timestamp | Lightweight, survives restart, no server dependency, clears naturally with new activity |
| 4 | Same component for both variants | `WelcomeVariant` enum controlling content/tone | DRY, easy to maintain, shared layout skeleton with conditional content blocks |

---

## Checklist

- [x] Page purpose clear
- [x] All section IDs assigned
- [x] Layout structure defined (all three variant layouts)
- [x] Spacing tokens specified
- [x] Typography scale mapped
- [x] All states documented
- [x] Variant resolution logic specified
- [x] Content matrix for all variant x track-config combinations
- [x] Data sources and providers identified
- [x] Show-once persistence mechanism defined
- [x] Animations specified
- [x] Accessibility requirements documented
- [x] Acceptance criteria comprehensive
- [x] Design decisions resolved with rationale

---

_Created using Whiteport Design Studio (WDS) methodology_
