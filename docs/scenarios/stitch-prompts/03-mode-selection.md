> ⚠️ **Status — 2026-07-13 (AUD-docs-22):** This prompt describes a superseded early-concept IA — a dedicated 3-way Self-Learner/Parent/Tutor mode-selection screen. The shipped app has no such screen or 3-way split: mode selection is a **Child Mode / Adult Mode** card pair embedded inline within the profile-creation step (`childModeCardTitle`/`adultModeCardTitle`, `lib/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart`), alongside the profile name field and preferences — not a standalone screen. Do not re-run this prompt for the current app without a fresh design pass against that file; treat everything below as inspiration-only, not a spec.

# Mode Selection Screen - Stitch Prompt

## Screen Purpose
First onboarding screen where user selects their learning mode (Self-Learner, Parent, or Tutor).

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile mode selection screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent color: bright green (#13ec13)
- Card surface: #1E1E1E
- Text colors: white primary, #B0B0B0 secondary
- Selected state: green outline (#13ec13)

**Layout (Top to Bottom):**

1. **Progress Indicator**
   - Step 1 of 3 indicator
   - Green dots/bars for current step
   - Gray dots for upcoming steps
   - Top margin: 24dp

2. **Header Section**
   - Title: "Who are you learning for?"
   - Subtitle: "Choose your learning mode"
   - Centered text
   - Padding: 24dp horizontal, 32dp below progress

3. **Mode Cards (3 Cards)**

   **Card 1: Self-Learner Mode**
   - Icon: Book or person reading (simple line icon, male figure)
   - Title: "Self-Learner"
   - Description: "Track your own Torah learning journey"
   - Features list:
     - "Personal progress tracking"
     - "Custom learning goals"
     - "Flexible schedules"
   - Card style: Material 3 elevated card (#1E1E1E)
   - Padding: 16dp
   - Border: 2dp transparent (4dp green when selected)
   - Tap to select interaction

   **Card 2: Parent Mode**
   - Icon: Two people or family (simple line icon, male figures)
   - Title: "Parent"
   - Description: "Manage learning for your children"
   - Features list:
     - "Multiple child profiles"
     - "Reward management"
     - "Progress monitoring"
   - Same card styling as above

   **Card 3: Tutor Mode**
   - Icon: Person with book or teaching icon (simple line icon, male figure)
   - Title: "Tutor/Rebbi"
   - Description: "Guide students through their learning"
   - Features list:
     - "Student management"
     - "Assignment tracking"
     - "Progress reports"
   - Same card styling as above

4. **Next Button**
   - Full width elevated button
   - Background: bright green (#13ec13)
   - Text: "Continue" in black bold text
   - Height: 48dp
   - Rounded corners (24dp radius)
   - Disabled (gray) until mode selected
   - Bottom margin: 24dp
   - Side margin: 16dp

**Card Spacing:**
- 16dp vertical spacing between cards
- 16dp horizontal margin for each card
- Cards should be equal height
- Icon centered at top of card
- Text left-aligned below icon

**Typography:**
- Progress text: 12sp, #B0B0B0
- Screen title: 28sp, bold, white
- Subtitle: 16sp, regular, #B0B0B0
- Card title: 20sp, bold, white
- Card description: 14sp, regular, #B0B0B0
- Feature items: 12sp, regular, white
- Button text: 16sp, medium weight

**Interactive States:**
- Unselected card: #1E1E1E background, no border
- Selected card: #1E1E1E background, 4dp green border (#13ec13), slight elevation increase
- Hover/press: ripple effect in green
- Card icons in green (#13ec13)

**Icons:**
- Size: 48dp x 48dp
- Color: green (#13ec13)
- Simple line style, Material Design icons
- Male figures only (Orthodox Jewish cultural sensitivity)

**Accessibility:**
- Each card is a single tap target (full card clickable)
- Radio button semantics (single selection)
- Clear visual feedback for selection
- Descriptive content for screen readers

**Behavior:**
- Single selection (radio button behavior)
- Tapping card selects it and deselects others
- Continue button enables when any mode selected
- Smooth transition to next screen on Continue
