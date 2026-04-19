# Learning History Screen - Stitch Prompt

## Screen Purpose
View complete learning history with timeline, filters, and ability to edit or delete past entries.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile learning history screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Curriculum-specific colors for entries
- Edit actions: blue (#42A5F5)
- Delete actions: red (#EF5350)

**Layout (Top to Bottom):**

1. **App Bar**
   - Back button (left, green)
   - Title: "Learning History"
   - Search icon (right, green)
   - Filter icon (right, green with badge if active)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Summary Stats Bar**
   - Horizontal scrolling mini-cards
   - Each stat card (compact):
     - Icon (green)
     - Number (24sp, bold, white)
     - Label (12sp, #B0B0B0)
   - Cards: 120dp wide, 80dp tall
   - 8dp spacing

   **Stats:**
   - Total pages: "423 pages learned"
   - This month: "87 pages this month"
   - Streak: "24 day streak"
   - Most studied: "Berachos" (curriculum icon)

   - Margin: 16dp horizontal
   - Background: #1E1E1E
   - Corner radius: 8dp

3. **Filter/View Controls**
   - Sticky below app bar
   - Background: #121212 (main bg)
   - Padding: 16dp horizontal, 12dp vertical

   **View Mode Tabs:**
   - Chip group, horizontal
   - Chips:
     - "Timeline" (selected - green)
     - "By Masechta"
     - "Calendar View"
   - Selected: solid green background
   - Unselected: outlined

   **Active Filters Indicator:**
   - Shows if filters applied
   - Chip: "Filters (3)" with X to clear
   - Amber color to indicate active state

4. **Main Content Area (Timeline View - Default)**

   **Month Headers:**
   - Sticky headers as user scrolls
   - Format: "February 2026"
   - 18sp, bold, white
   - Background: #121212
   - Padding: 16dp horizontal, 12dp vertical
   - Border bottom: 1dp #2E2E2E

   **Date Group:**
   - Sub-header for each date
   - Format: "February 8, 2026 • Friday • ה׳ שבט"
   - 14sp, medium, #B0B0B0
   - Hebrew date RTL
   - Padding: 16dp horizontal, 8dp top

   **Entry Cards (per completion):**
   - Full-width card
   - Margin: 16dp horizontal, 8dp vertical
   - Background: #1E1E1E
   - Corner radius: 12dp
   - Padding: 16dp
   - Elevation: 1dp

   **Card Layout:**

   **Left Section:**
   - Curriculum color accent bar (4dp width, full height)
   - Curriculum badge chip:
     - Small (20dp height)
     - Curriculum color background
     - White text (11sp)
     - Example: "Mishnayos" or "Bavli"

   **Middle Section:**
   - Main text (16sp, bold, white):
     - "Berachos: Daf 12a"
   - Sub-info row (14sp, #B0B0B0):
     - Time: "Completed at 2:30 PM"
     - Duration (if logged): "• 8 minutes"
   - Notes (if present):
     - Icon: note/document (small)
     - Preview: "Challenging sugya about..." (truncated)
     - "Read more" link (green)
     - Expandable on tap

   **Right Section:**
   - More menu (three dots vertical)
   - Options:
     - Edit completion details
     - Add/edit notes
     - Change date
     - Delete entry
   - Touch target: 48dp

   **Bottom Indicators (Optional):**
   - Tags/badges if present:
     - "Review" badge
     - "Siyum" badge (special celebration icon)
     - "Make-up" badge
   - Small chips, 24dp height
   - Appropriate colors

5. **By Masechta View (Alternative Tab)**

   **Masechta Group Cards:**
   - Larger cards grouping by masechta
   - Header:
     - Masechta name: "Berachos" (20sp, bold)
     - Hebrew: "ברכות" (16sp, RTL)
     - Curriculum badge
   - Summary stats:
     - "24 pages completed"
     - "Last studied: 2 days ago"
     - Progress bar showing % complete
   - Expandable to show individual entries
   - Chevron down/up indicator
   - Background: #1E1E1E
   - Margin: 16dp

   **Expanded Entry List:**
   - Nested compact entries
   - Each entry:
     - Daf reference: "Daf 12a"
     - Date: "Feb 8"
     - Checkmark icon (green)
   - Slightly indented from masechta card
   - Lighter background (#262626)

6. **Calendar View (Alternative Tab)**

   **Month Calendar:**
   - Material 3 calendar component
   - Full month grid
   - Each day cell:
     - Date number
     - Dot indicators for completions (curriculum colors)
     - Multiple dots if multiple curricula that day
     - Green highlight for days with learning
     - Gray for no learning
     - Today: outline
   - Cell size: ~48dp square
   - Tappable

   **Selected Day Detail:**
   - Below calendar
   - Shows entries for selected day
   - Same entry card format as timeline
   - Scrollable if many entries

7. **Empty States**

   **No History:**
   ```
   📚 No learning history yet

   Your completed pages will appear here.
   Start learning to build your history!

   [Start Learning] button
   ```

   **No Results (after filter):**
   ```
   🔍 No entries found

   Try adjusting your filters or search.

   [Clear Filters] button
   ```

8. **Filter Bottom Sheet (on filter icon tap)**

   **Filter Options:**

   **Date Range:**
   - Quick options:
     - Today
     - This week
     - This month
     - Last 30 days
     - Custom range (date pickers)
   - Selected: green checkmark

   **Curricula (Multi-select):**
   - Checkboxes for each curriculum
   - Curriculum color indicators
   - "Select All" / "Clear All" buttons

   **Masechtos (Multi-select):**
   - Dependent on curriculum selection
   - Searchable dropdown
   - Shows only masechtos from selected curricula

   **Entry Type:**
   - Regular completion
   - Review
   - Make-up
   - Siyum

   **Has Notes:**
   - Toggle: "Only show entries with notes"

   **Action Buttons:**
   - "Reset" (text button, left)
   - "Apply Filters" (filled button, right, green)

9. **Search Overlay (on search icon tap)**
   - Full-screen search
   - Search bar at top
   - Placeholder: "Search by masechta, daf, or notes..."
   - Recent searches shown
   - Results update as you type
   - Results grouped by date
   - Highlight search terms in results

10. **Floating Action Button (Optional)**
    - Bottom-right corner
    - Icon: download or export
    - Action: "Export History"
    - Green background (#13ec13)
    - Size: 56dp
    - Options:
      - Export as CSV
      - Export as PDF
      - Share summary

**Typography:**
- Screen title: 20sp, bold, white
- Month headers: 18sp, bold, white
- Date headers: 14sp, medium, #B0B0B0
- Hebrew date: 14sp, regular, #B0B0B0, RTL
- Curriculum badge: 11sp, uppercase, white
- Entry main text: 16sp, bold, white
- Entry sub-info: 14sp, regular, #B0B0B0
- Notes preview: 14sp, regular, white
- Masechta group name: 20sp, bold, white
- Stats numbers: 24sp, bold, white
- Stats labels: 12sp, regular, #B0B0B0
- Filter options: 16sp, regular, white

**Interactive Elements:**

**Swipe Actions:**
- Swipe right on entry: Quick edit
- Swipe left on entry: Delete
- Color-coded backgrounds:
  - Edit: blue background
  - Delete: red background
- Undo snackbar after delete

**Long Press:**
- Multi-select mode
- Checkbox appears on entries
- Bottom action bar:
  - "Delete selected"
  - "Export selected"
  - "Bulk edit"
- Exit: X button or tap outside

**Context Menu (three dots):**
- Edit entry
- View full details
- Add to review list
- Share this entry
- Delete entry

**Edit Dialog:**
- Bottom sheet or full screen
- Fields:
  - Daf/page (editable)
  - Date picker
  - Time picker
  - Notes (full editor)
  - Duration
- Save/Cancel buttons

**Delete Confirmation:**
- Dialog or snackbar
- Message: "Delete this entry?"
- Warning: "This cannot be undone"
- Buttons:
  - "Cancel"
  - "Delete" (red)
- Undo option in snackbar after delete

**Accessibility:**
- All entries: minimum 48dp touch target
- Swipe actions: alternative menu option
- Screen reader support
- Date formats respect locale
- Hebrew dates properly rendered
- Clear focus indicators
- Color not sole indicator

**Loading States:**
- Initial load: skeleton cards
- Infinite scroll: loading spinner at bottom
- Pull-to-refresh: Material refresh indicator (green)

**Animations:**
- Entry expand/collapse: smooth height animation
- Filter apply: fade transition
- Delete: fade out + slide
- Month header scroll: sticky positioning
- Swipe actions: reveal animation

**Performance:**
- Infinite scroll (paginated)
- Load 20 entries at a time
- Cache loaded data
- Optimize for large histories
