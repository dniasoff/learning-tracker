# Goal Setup Screen - Stitch Prompt

## Screen Purpose
Third onboarding screen where user sets their learning goals and completion target.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile goal setup screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Target date highlight: amber (#FFD54F)

**Layout (Top to Bottom):**

1. **Progress Indicator**
   - Step 3 of 3
   - All dots/bars in green (final step)
   - Top margin: 24dp

2. **Header**
   - Back button (top-left, green)
   - Title: "Set Your Learning Goal"
   - Subtitle: "How much do you want to learn?"
   - Padding: 24dp horizontal, 16dp vertical

3. **Goal Type Cards (2 Options)**

   **Option 1: Pages Per Day**
   - Card with radio button
   - Icon: Calendar with page icon
   - Title: "Daily Page Goal"
   - Description: "Complete a set number of pages each day"
   - Number picker below:
     - Label: "Pages per day"
     - Default: 1
     - Range: 1-10
     - Large number display (32sp)
     - +/- buttons (green, 48dp touch target)
   - Card style: #1E1E1E, green border when selected

   **Option 2: Completion Date**
   - Card with radio button
   - Icon: Flag or target icon
   - Title: "Target Completion Date"
   - Description: "Set a date to complete your learning by"
   - Date picker below:
     - Label: "Complete by"
     - Default: 1 year from today
     - Calendar date selector
     - Display format: "January 15, 2027"
     - Amber highlight for selected date
   - Card style: #1E1E1E, green border when selected

4. **Calculation Preview**
   - Elevated card (#1E1E1E)
   - Shows automatic calculation based on selection:
     - If pages/day selected: "You'll complete [curriculum] in ~X months"
     - If date selected: "You'll need to learn ~X pages per day"
   - Icon: calculator or chart
   - Text: 14sp, white
   - Highlighted numbers in green (#13ec13)
   - Padding: 16dp

5. **Additional Options (Collapsible)**
   - Accordion/expandable section
   - Title: "Advanced Options" with chevron down
   - When expanded:
     - "Include weekends" toggle switch (green)
     - "Skip on Yom Tov" toggle switch (green)
     - "Rest day: [dropdown]" selector (None/Shabbos/Sunday)
   - Each option on its own row
   - 48dp row height

6. **Get Started Button**
   - Full width elevated button
   - Background: bright green (#13ec13)
   - Text: "Start Learning!" in black bold
   - Height: 56dp (larger for final CTA)
   - Radius: 28dp
   - Margin: 16dp horizontal, 24dp bottom
   - Always enabled (has default values)

**Card Specifications:**
- Radio button selection (single choice)
- Selected card: 4dp green border, elevated
- Unselected card: no border, flat
- Cards: 16dp horizontal margin
- 24dp vertical spacing between cards
- Corner radius: 12dp

**Number Picker Component:**
- Center aligned
- Minus button (left) | Number display | Plus button (right)
- Buttons: 48dp x 48dp, circular, green (#13ec13)
- Icons: minus/plus in black
- Number: 32sp, bold, white
- Haptic feedback on increment/decrement

**Date Picker Component:**
- Tappable field showing selected date
- Opens Material 3 date picker dialog
- Calendar view in dark mode
- Selected date: green highlight (#13ec13)
- Today's date: amber outline (#FFD54F)
- Min date: tomorrow
- Max date: 5 years in future

**Typography:**
- Progress: 12sp, #B0B0B0
- Screen title: 28sp, bold, white
- Subtitle: 16sp, regular, #B0B0B0
- Card title: 20sp, bold, white
- Card description: 14sp, regular, #B0B0B0
- Picker labels: 14sp, #B0B0B0
- Number display: 32sp, bold, white
- Date display: 18sp, medium, white
- Calculation text: 14sp, regular, white
- Calculation numbers: 14sp, bold, green (#13ec13)
- Advanced options: 14sp, regular, white
- Button: 18sp, medium weight

**Interactive States:**
- Radio buttons: green (#13ec13) when selected
- Toggle switches: green (#13ec13) when on
- +/- buttons: ripple effect, disabled state (gray) at min/max
- Date field: green outline when focused
- Expandable section: smooth animation

**Validation & Feedback:**
- Pages per day: minimum 1, maximum 10
- Date: must be future date
- Show warning if goal is extremely ambitious (>5 pages/day)
- Show encouragement if goal is modest (1-2 pages/day)

**Calculation Logic Display:**
- Dynamically updates as user changes values
- Shows realistic completion time
- Considers selected curricula from previous screen
- Displays in friendly language: "~6 months" not "183 days"

**Accessibility:**
- All controls minimum 48dp touch targets
- Radio button groups properly labeled
- Toggle switches with labels
- Date picker keyboard accessible
- Screen reader support for calculations
