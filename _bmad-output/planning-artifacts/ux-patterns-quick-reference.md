# Learning Tracker — UX Patterns Quick Reference

**Last Updated:** 2026-02-08
**Related:** [Architecture Quick Reference](architecture-quick-reference.md) | [UX Design Specification](ux-design-specification.md)

---

## User Mode Differences (D5)

### Child Mode
- **Gamification:** Full points, streaks, mystery rewards, celebration animations
- **Parent Oversight:** PIN-protected parent mode for reward management, track config, analytics
- **Visual Style:** Playful, colorful, encouraging ("Great job!", "Keep your streak going!")
- **Navigation:** Simple, guided, minimal settings access

### Adult Mode
- **Gamification:** Optional/subdued (points visible but no animations, streaks shown minimally)
- **Self-Directed:** All settings user-accessible, no PIN protection
- **Visual Style:** Clean, professional, progress-focused
- **Navigation:** Full access to all features, advanced settings visible

**Implementation:** Simple conditional rendering based on `userMode` enum:
```dart
if (userMode == UserMode.child) {
  // Show animated celebration
  showRewardUnlockAnimation();
} else {
  // Show subtle notification
  showSnackbar('Goal reached: ${reward.title}');
}
```

---

## Navigation Patterns (auto_route 11.x)

### Primary Navigation (Bottom Navigation Bar)
```
┌──────────────────────────────────┐
│ [Home] [Learn] [Progress] [⚙️]  │
└──────────────────────────────────┘
```

- **Home:** Cross-curriculum dashboard (Epic 7)
- **Learn:** Daily tasks / curriculum selection → content browser
- **Progress:** Charts, statistics, completion history
- **Settings:** Account, notifications, data export

### Deep Navigation Flows

**Learning Flow:**
```
Home → Select Curriculum → Content Browser → Item Detail → Mark Complete → Confirmation
                                                              ↓
                                                         Update Streak
                                                              ↓
                                                      Points Animation (child mode)
```

**Parent Mode Flow:**
```
Settings → Enter Parent PIN → Parent Dashboard → [Rewards | Track Mgmt | Analytics | Point Config]
```

**Onboarding Flow:**
```
Sign In → Welcome → Mode Selection → Curriculum Selection → Goal Setup (per curriculum) → Bulk Mark Prior → Initial Rewards (child) → Home
```

### Route Guards (Story 1.5)
- `AuthGuard` — Requires signed-in user (all routes except auth)
- `ParentPinGuard` — Requires parent PIN entry (child mode only)
- `TutorPinGuard` — Requires tutor PIN entry (both modes)

---

## Data Display Patterns

### Curriculum Cards (Dashboard)
```
┌───────────────────────────────┐
│ 📖 Mishnayos                  │
│ ━━━━━━━━━━━━━━━━━━━ 45%      │
│ 1,890 / 4,192 items           │
│ 🎯 On pace · 23 days ahead    │
│ Next: Berachos 3:1            │
└───────────────────────────────┘
```

**Components:**
- Curriculum icon + name
- Progress bar with percentage
- Item counts (completed / total)
- Pace indicator with color coding (green=ahead, yellow=on-pace, red=behind)
- Next bookmark item

### Hierarchy Browser (Content)
```
Mishnayos
├─ 📂 Seder Zeraim (834 items) ━━━━━━━━━ 30%
│  ├─ 📂 Berachos (453 items) ━━━━━━━━━━━ 100% ✓
│  └─ 📂 Peah (381 items) ━━━━━━ 12%
├─ 📂 Seder Moed (...)
└─ ...
```

**Behavior:**
- Tap container → expand to show children
- Tap leaf item → show item detail with "Mark Complete" button
- Checkmarks for 100% complete containers
- Progress bars for partial completion

### Completion History (Story 3.2)
```
Filter: [All Curricula ▼] [All Tracks ▼] [Last 30 Days ▼]

Today
  Mishnayos · Berachos 3:1 · Chazara 1 · Personal · 10 pts
  Bavli · Berachos 2a · Learn · School · 10 pts

Yesterday
  Mishnayos · Berachos 3:2 · Learn · Personal · 10 pts
```

**Features:**
- Grouped by date (Today, Yesterday, [Date])
- Each row: Curriculum · Item · Stage · Track · Points
- Filter dropdowns: curriculum, track, stage, date range
- Infinite scroll / pagination for long histories

---

## Input Patterns

### PIN Entry (Parent/Tutor Mode)
```
┌──────────────────────┐
│  Enter Parent PIN    │
│  ┌───┬───┬───┬───┐   │
│  │ ● │ ● │ ○ │ ○ │   │
│  └───┴───┴───┴───┘   │
│                      │
│  [1] [2] [3]         │
│  [4] [5] [6]         │
│  [7] [8] [9]         │
│  [←] [0] [✓]         │
└──────────────────────┘
```

**Behavior:**
- 4-digit numeric keypad
- Dots fill as digits entered
- Shake animation on incorrect PIN
- Lock-out after 5 failed attempts (30-min cooldown)

### Date Picker (Gregorian + Hebrew)
```
┌─────────────────────────────┐
│ Set Goal Date               │
│ ┌──────────┬──────────────┐ │
│ │ Gregorian│ Hebrew       │ │
│ └──────────┴──────────────┘ │
│                             │
│ 📅 March 15, 2027           │
│ 🕍 15 Adar II 5787          │
│                             │
│ [Cancel]          [Confirm] │
└─────────────────────────────┘
```

**Features:**
- Tab switch between Gregorian and Hebrew calendars
- Both dates displayed simultaneously (synced via kosher_dart)
- Common presets: "Bar Mitzvah (13th birthday)", "Next Pesach", "End of Year"

### Drag-and-Drop Reorder (Story 5.2)
```
Learning Order: Seder Zeraim
┌─────────────────────────┐
│ ☰ Berachos              │
│ ☰ Peah                  │
│ ☰ Demai      ← dragging │
│ ☰ Kilayim               │
└─────────────────────────┘
```

**Behavior:**
- Long-press handle (☰) to initiate drag
- Item lifts with shadow/elevation
- Other items shift to show drop target
- Release to reorder
- "Reset to Default Order" button at top

---

## Feedback Patterns

### Points Earned (Child Mode)
```
┌──────────────────────┐
│       +10 pts        │
│         ⭐           │
│   Great work!        │
└──────────────────────┘
```

**Animation:**
- Fade in + scale (bounce effect)
- Confetti particles (child mode only)
- Auto-dismiss after 2 seconds
- Haptic feedback (light impact)

### Streak Milestone (Child Mode)
```
┌──────────────────────┐
│    🔥 7-Day Streak!  │
│  You're on fire!     │
│                      │
│      [Awesome!]      │
└──────────────────────┘
```

**Triggers:** 7, 30, 100, 365 days
**Adult Mode:** Subtle banner notification instead of modal

### Sync Status Indicator
```
Bottom bar:
[✓ Synced] | [⟳ Syncing...] | [⚠ Offline] | [✗ Sync Error]
```

**Colors:**
- Green checkmark: All data synced
- Blue spinner: Sync in progress
- Yellow warning: Offline mode (local-only)
- Red X: Sync failed (tap for details)

### Error States

**Empty State (No completions yet):**
```
┌─────────────────────────────┐
│         📚                  │
│                             │
│  Start your learning        │
│  journey today!             │
│                             │
│  [Browse Curricula]         │
└─────────────────────────────┘
```

**Network Error:**
```
┌─────────────────────────────┐
│  ⚠ Couldn't load content    │
│                             │
│  Check your internet        │
│  connection and try again.  │
│                             │
│  [Retry]  [Work Offline]    │
└─────────────────────────────┘
```

---

## Component Library

### Primary Button
- **Child Mode:** Rounded corners (16px), gradient background, large text (18sp), haptic feedback
- **Adult Mode:** Rounded corners (8px), solid color, medium text (16sp), minimal feedback

### Cards
- Material 3 elevated cards (elevation 1)
- 16px padding, 12px corner radius
- Tap feedback: ripple effect
- Swipe actions where applicable (e.g., dismiss tasks)

### Progress Bars
- Height: 8px
- Corner radius: 4px
- Colors: curriculum-specific (configurable in theme)
- Animated fill on state change (300ms ease-out)

### Bottom Sheets
- Used for: filters, quick actions, confirmations
- Drag handle at top (40px tall gray bar)
- Backdrop dim: 40% black overlay
- Swipe down to dismiss

---

## Typography Scale (Material 3)

```
displayLarge:  57sp / 64 line-height  (Headlines, onboarding)
displayMedium: 45sp / 52 line-height  (Epic titles)
displaySmall:  36sp / 44 line-height  (Story titles)

headlineLarge:  32sp / 40 line-height (Section headers)
headlineMedium: 28sp / 36 line-height (Card titles)
headlineSmall:  24sp / 32 line-height (Subsections)

titleLarge:  22sp / 28 line-height (List items)
titleMedium: 16sp / 24 line-height (Buttons, labels)
titleSmall:  14sp / 20 line-height (Chips, tags)

bodyLarge:  16sp / 24 line-height (Body text)
bodyMedium: 14sp / 20 line-height (Secondary text)
bodySmall:  12sp / 16 line-height (Captions, metadata)

labelLarge:  14sp / 20 line-height (Button text)
labelMedium: 12sp / 16 line-height (Tab labels)
labelSmall:  11sp / 16 line-height (Dense UI)
```

**Font:** Roboto (default Material 3) with Hebrew fallback (Noto Sans Hebrew)

---

## Color Scheme

### Light Mode (v1.0 — dark mode deferred)

**Primary Palette:**
- Primary: `#1976D2` (Blue 700) — CTA buttons, active states
- OnPrimary: `#FFFFFF` — Text on primary
- PrimaryContainer: `#BBDEFB` (Blue 100) — Chips, tags
- OnPrimaryContainer: `#0D47A1` (Blue 900) — Text on containers

**Secondary Palette (Accent):**
- Secondary: `#FF6F00` (Orange 800) — Streaks, highlights
- OnSecondary: `#FFFFFF`
- SecondaryContainer: `#FFE0B2` (Orange 100)
- OnSecondaryContainer: `#E65100` (Orange 900)

**Semantic Colors:**
- Success: `#4CAF50` (Green 500) — Ahead of pace, completions
- Warning: `#FF9800` (Orange 500) — On pace, streak at risk
- Error: `#F44336` (Red 500) — Behind pace, errors
- Info: `#2196F3` (Blue 500) — Neutral informational

**Curriculum Colors (Configurable):**
- Mishnayos: Blue (`#2196F3`)
- Bavli: Purple (`#9C27B0`)
- Yerushalmi: Teal (`#009688`)
- Mishna Berurah: Amber (`#FFC107`)
- Chumash: Green (`#4CAF50`)

---

## Accessibility

### Text Contrast
- All text meets WCAG AA contrast ratio (4.5:1 for normal text, 3:1 for large text)
- Error messages meet AAA (7:1) for critical information

### Touch Targets
- Minimum 48x48dp tap targets (Material 3 guideline)
- Spacing between adjacent targets: ≥8dp

### Screen Reader Support
- All interactive elements have semantic labels
- Progress indicators announce percentage changes
- Form validation errors announced immediately

### Font Size Preference (Story 14.1)
- Small: 0.85x scale
- Medium: 1.0x scale (default)
- Large: 1.15x scale

---

## Animation Guidelines

### Duration
- **Micro-interactions:** 100-200ms (button press, checkbox toggle)
- **Transitions:** 200-300ms (screen navigation, modal appearance)
- **Celebrations:** 500-1000ms (reward unlock, streak milestone)

### Easing
- **Standard:** Ease-out (deceleration curve) — most transitions
- **Emphasized:** Ease-in-out — modal entry/exit
- **Bounce:** Overshoot curve — child mode celebrations only

### Reduce Motion (Accessibility)
- Respect system preference for reduced motion
- Replace animations with instant state changes
- Keep critical feedback (e.g., error states) visible longer

---

## Loading States

### Skeleton Screens (Preferred)
```
┌───────────────────────────────┐
│ ████████                      │ (Placeholder for curriculum card)
│ ━━━━━━━━━━━━━━━━━━━━━━        │ (Placeholder for progress bar)
│ ████ / ████                   │ (Placeholder for counts)
└───────────────────────────────┘
```

**Use for:** Content loading, API calls, database queries
**Benefit:** Preserves layout, prevents content shift

### Spinner (Fallback)
```
┌──────────────────────┐
│       ⟳ Loading...   │
└──────────────────────┘
```

**Use for:** Short operations (<1s), button loading states

### Progress Bar (Long Operations)
```
Importing Mishnayos...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 67%
2,804 / 4,192 items
```

**Use for:** Content import (Story 2.1), bulk mark (Story 9.4)

---

## Form Validation

### Inline Validation
- Validate on blur (field loses focus), not on every keystroke
- Show errors below field in red text (Error color)
- Icon prefix: ⚠ for errors, ✓ for success

### Error Messages
- **Email invalid:** "Please enter a valid email address"
- **Password too short:** "Password must be at least 8 characters"
- **PIN incorrect:** "Incorrect PIN. X attempts remaining"
- **Required field:** "[Field name] is required"

### Success Confirmation
- Use snackbar at bottom: "Settings saved" (2s auto-dismiss)
- For critical actions (delete account): modal confirmation with "Are you sure?"

---

## Notification Patterns (Epic 12)

### Push Notification Format
```
🔥 Streak Alert
Your 23-day streak is at risk! Complete one item to keep it going.
```

**Components:**
- Emoji prefix (🔥 streak, 📚 daily reminder, ⭐ reward)
- Bold title (notification type)
- Body text (action-oriented)

### In-App Banner
```
┌─────────────────────────────────────┐
│ ⚠ You have 3 overdue chazara items  │
│                          [View] [✕] │
└─────────────────────────────────────┘
```

**Behavior:**
- Appears at top of screen (non-blocking)
- Tap "View" → navigate to daily tasks
- Tap ✕ → dismiss (don't show again today)

---

## Quick Reference Checklist for Implementation

**For each new screen:**
- [ ] Supports both child and adult modes (conditional rendering)
- [ ] Meets minimum 48x48dp touch targets
- [ ] Loading state (skeleton or spinner)
- [ ] Empty state with helpful CTA
- [ ] Error state with retry action
- [ ] Respects font size preference (Story 14.1)
- [ ] Uses Material 3 theme tokens (not hardcoded colors)
- [ ] Screen reader labels for all interactive elements

**For each form:**
- [ ] Inline validation on blur
- [ ] Clear error messages
- [ ] Success confirmation (snackbar)
- [ ] Keyboard dismissal on submit
- [ ] Loading state on submit button

**For each animation (child mode):**
- [ ] Respects reduced motion preference
- [ ] Duration ≤1s (no long animations)
- [ ] Non-blocking (user can continue interacting)

---

**Questions?** Check [UX Design Specification](ux-design-specification.md) for full rationale and mockups.
