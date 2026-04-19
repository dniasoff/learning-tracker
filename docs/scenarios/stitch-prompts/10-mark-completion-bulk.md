# Bulk Mark Completion Screen - Stitch Prompt

## Screen Purpose
Interface for quickly marking multiple pages/dafim as complete at once, useful for catching up or logging completed learning.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile bulk completion screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Warning colors: amber (#FFB300) for caution states

**Layout (Top to Bottom):**

1. **App Bar**
   - Close button (left, X icon, green)
   - Title: "Bulk Mark Complete"
   - Help icon (right, ? in circle)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Info Card (Top)**
   - Elevated card (#1E1E1E)
   - Icon: info or lightbulb (green)
   - Message: "Quickly log multiple pages you've already learned"
   - Dismissible (X button in corner)
   - Margin: 16dp
   - Padding: 12dp
   - Corner radius: 8dp
   - Optional: "Don't show again" checkbox

3. **Curriculum Selector**
   - Section header: "Select Curriculum" (16sp, bold)
   - Horizontal chip group
   - Each chip:
     - Curriculum name
     - Curriculum color accent
     - Single selection (radio behavior)
     - Selected: solid curriculum color background
     - Unselected: outlined
   - Margin: 16dp horizontal, 24dp top
   - Example chips: "Mishnayos" "Bavli" "Yerushalmi" etc.

4. **Range Selection Card**
   - Large elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 20dp
   - Corner radius: 12dp

   **Selection Method Tabs:**
   - Two tabs at top of card:
     - "By Range" (default, selected - green underline)
     - "Custom Selection"
   - Tab indicator: 4dp green line

   **By Range View:**

   **Masechta Selector:**
   - Label: "Masechta"
   - Dropdown/picker:
     - Shows list of masechtos in selected curriculum
     - Current selection: "Berachos"
     - Curriculum color accent
   - Material 3 exposed dropdown menu style

   **Start Page Field:**
   - Label: "Start Page"
   - Input format: "12a" or "12b"
   - Number picker with amud toggle:
     - Number stepper (1-999)
     - Amud toggle: "Alef (a)" / "Bet (b)"
     - Green buttons
   - Helper text: "First page to mark complete"

   **End Page Field:**
   - Label: "End Page"
   - Same format as start page
   - Number picker with amud toggle
   - Helper text: "Last page to mark complete"
   - Validation: must be after start page

   **Range Preview:**
   - Below fields, highlighted box
   - Shows calculated range:
     - "Berachos: Daf 12a through 18b"
     - "Total: 13 pages"
   - Large text: "13 pages" in green
   - Icon: checkmark list

   **Custom Selection View (Alternative Tab):**
   - Masechta dropdown (same as above)
   - Multi-select list of dafim:
     - Scrollable list (max height: 300dp)
     - Each item: checkbox + "Daf 12a"
     - Already completed: disabled, dimmed
     - Group select options: "Select All" "Select None"
   - Count at bottom: "15 pages selected"

5. **Date Assignment**
   - Section within card
   - Label: "When did you complete these?"
   - Radio button options:
     - "Today" (selected by default)
     - "Specific date" → opens date picker
     - "Mark as complete, no specific date"
   - Selected option: green radio button

6. **Optional Details (Expandable)**
   - Accordion section: "Additional Details" with chevron
   - When expanded:
     - Notes field:
       - Label: "Add notes (optional)"
       - Placeholder: "E.g., 'Caught up on missed learning'"
       - Multi-line text input
       - Character limit: 500
     - Time spent field:
       - Label: "Total time spent (optional)"
       - Number input with unit dropdown: "2.5 hours"
     - Mark for review checkbox:
       - "I want to review these later"
       - Green checkbox

7. **Warning Messages (Conditional)**
   - Shows amber warning card if:
     - Range is very large (>20 pages): "This is a lot of pages. Are you sure?"
     - Dates overlap with existing: "Some pages already marked complete"
     - Future date selected: "Date is in the future"
   - Icon: warning triangle (amber)
   - Background: amber with 10% opacity
   - Dismissible but reappears if condition persists

8. **Action Buttons (Bottom, Fixed)**
   - Elevated surface (#1E1E1E)
   - Padding: 16dp
   - Two buttons, equal width

   **Cancel Button:**
   - Outlined style
   - Text: "Cancel"
   - Green outline
   - Height: 48dp

   **Mark Complete Button:**
   - Filled style
   - Background: green (#13ec13)
   - Text: "Mark X Pages Complete" (X = calculated count)
   - Black text, bold
   - Height: 48dp
   - Disabled if:
       - No curriculum selected
       - Invalid range
       - No pages selected (custom mode)
   - Disabled state: gray

**Typography:**
- Screen title: 20sp, bold, white
- Info message: 14sp, regular, white
- Section headers: 16sp, bold, white
- Labels: 14sp, medium, #B0B0B0
- Input text: 16sp, regular, white
- Helper text: 12sp, regular, #B0B0B0
- Range preview main: 18sp, bold, green (#13ec13)
- Range preview detail: 14sp, regular, white
- Page count: 24sp, bold, green
- Warning text: 14sp, medium, amber
- Button text: 16sp, medium
- Notes: 14sp, regular, white

**Input Specifications:**

**Number Picker:**
- Circular buttons for +/- (48dp)
- Number display: 24sp, centered
- Green buttons (#13ec13)
- Haptic feedback on increment
- Long-press for rapid increment

**Amud Toggle:**
- Segmented button group
- "א (a)" | "ב (b)"
- Selected: green background
- Unselected: gray outline
- Width: equal segments
- Height: 40dp

**Dropdown Menu:**
- Material 3 exposed dropdown
- Max visible items: 6
- Scrollable
- Search/filter for long lists
- Selected item: green checkmark

**Date Picker:**
- Material 3 date picker dialog
- Calendar view
- Selected date: green highlight
- Today: outlined
- Min date: 6 months ago (or app install date)
- Max date: today

**Validation & Feedback:**

**Real-time Validation:**
- End page before start page: red error message
- "End page must be after start page"
- Invalid daf number: red error
- "Daf number must be between 1 and [max]"
- Range preview updates immediately

**Confirmation Dialog:**
- Shows after "Mark Complete" tapped
- Title: "Confirm Bulk Completion"
- Summary:
  - Curriculum: Bavli
  - Masechta: Berachos
  - Range: 12a - 18b
  - Count: 13 pages
  - Date: Today
- Buttons:
  - "Cancel" (text button)
  - "Confirm" (green button)

**Success Feedback:**
- Green checkmark animation
- Message: "13 pages marked complete!"
- Auto-dismiss after 2 seconds
- Returns to previous screen

**Error Handling:**
- Network error: show retry option
- Partial success: "10 of 13 pages marked" with details
- Duplicate pages: skip with notification

**Accessibility:**
- All inputs: proper labels
- Number pickers: keyboard input option
- Dropdowns: searchable for screen readers
- Clear focus indicators
- Error messages announced
- Haptic feedback for all interactions

**Interactive Behaviors:**
- Tab switching: smooth transition
- Dropdown opening: animation
- Number picker: rapid increment on long-press
- Range preview: updates live as inputs change
- Validation: real-time, non-blocking

**Edge Cases:**

**Already Completed Pages:**
- Show warning: "5 pages in this range already complete"
- Option: "Skip duplicates" (default) or "Overwrite"
- List duplicates in expandable section

**Missing Masechta Data:**
- Error: "This masechta is not yet in our database"
- Option: "Report missing content"

**Large Ranges:**
- Warning at >20 pages: "Large range - double check"
- Confirmation required at >50 pages
- Recommend splitting into smaller batches
