# Curriculum Selection Screen - Stitch Prompt

## Screen Purpose
Second onboarding screen where user selects which Torah curriculum(s) they want to learn.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile curriculum selection screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Each curriculum has unique color identity
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary

**Layout (Top to Bottom):**

1. **Progress Indicator**
   - Step 2 of 3
   - Green bar/dots for completed + current
   - Gray for remaining
   - Top margin: 24dp

2. **Header**
   - Back button (top-left, green)
   - Title: "Choose Your Learning Path"
   - Subtitle: "Select one or more curricula to track"
   - Padding: 24dp horizontal

3. **Curriculum Cards (5 Scrollable Cards)**

   **Card Layout Template:**
   Each card should have:
   - Left color accent bar (8dp width, curriculum-specific color)
   - Icon/symbol for curriculum (top-right corner)
   - Curriculum name (large, bold)
   - Hebrew name (smaller, below English)
   - Brief description (2 lines)
   - Checkbox (top-right, green when selected)

   **Curriculum 1: Mishnayos**
   - Accent color: Amber (#FF8F00 light, #FFD54F dark)
   - Icon: Simple book symbol
   - English: "Mishnayos"
   - Hebrew: "משניות"
   - Description: "Foundational oral Torah teachings organized by topic"
   - Background: #1E1E1E
   - Selected state: amber glow/outline

   **Curriculum 2: Bavli (Talmud Bavli)**
   - Accent color: Blue (#1565C0 light, #42A5F5 dark)
   - Icon: Layered books or scroll
   - English: "Bavli"
   - Hebrew: "תלמוד בבלי"
   - Description: "Babylonian Talmud - comprehensive analysis and discussion"
   - Selected state: blue glow/outline

   **Curriculum 3: Yerushalmi (Talmud Yerushalmi)**
   - Accent color: Cyan (#00838F light, #4DD0E1 dark)
   - Icon: Ancient scroll
   - English: "Yerushalmi"
   - Hebrew: "תלמוד ירושלמי"
   - Description: "Jerusalem Talmud - concise teachings and discussions"
   - Selected state: cyan glow/outline

   **Curriculum 4: Mishna Berurah**
   - Accent color: Burgundy (#6A1B29 light, #AD1E3D dark)
   - Icon: Open book with candle/light
   - English: "Mishna Berurah"
   - Hebrew: "משנה ברורה"
   - Description: "Practical halacha guide for daily Jewish life"
   - Selected state: burgundy glow/outline

   **Curriculum 5: Chumash**
   - Accent color: Green (#2E7D32 light, #66BB6A dark)
   - Icon: Torah scroll
   - English: "Chumash"
   - Hebrew: "חומש"
   - Description: "Five Books of Torah with classic commentaries"
   - Selected state: green glow/outline

4. **Selection Info**
   - Below cards, centered
   - Text: "You can add or remove curricula anytime in settings"
   - Small text (12sp), #B0B0B0
   - Icon: info circle

5. **Continue Button**
   - Full width elevated button
   - Background: bright green (#13ec13)
   - Text: "Continue" in black bold
   - Height: 48dp
   - Radius: 24dp
   - Disabled (gray) until at least one selected
   - Margin: 16dp horizontal, 24dp bottom

**Card Specifications:**
- Width: screen width - 32dp (16dp margins each side)
- Height: ~140dp each
- Corner radius: 12dp
- 12dp vertical spacing between cards
- Elevation: 2dp (4dp when selected)
- Checkbox: 24dp, green (#13ec13) when checked

**Typography:**
- Progress: 12sp, #B0B0B0
- Title: 28sp, bold, white
- Subtitle: 16sp, regular, #B0B0B0
- Curriculum English name: 22sp, bold, white
- Curriculum Hebrew name: 18sp, regular, #B0B0B0, RTL support
- Description: 14sp, regular, #B0B0B0
- Info text: 12sp, regular, #B0B0B0
- Button: 16sp, medium weight

**Interactive States:**
- Unselected: #1E1E1E, curriculum accent on left bar only
- Selected: curriculum color outline (2dp), checkbox checked
- Multiple selection allowed
- Ripple effect on tap
- Smooth checkbox animation

**Hebrew Text Support:**
- Use Noto Sans Hebrew font
- Right-to-left (RTL) rendering
- Proper Hebrew character support
- Nikud (vowel marks) not required

**Scrolling:**
- Vertical scroll for all 5 cards
- Smooth scrolling behavior
- Cards should scroll within safe area (between header and button)

**Accessibility:**
- Each card fully tappable
- Checkbox state clearly indicated
- Color not the only indicator (use checkmark)
- Screen reader support for curriculum names and descriptions
