# Stage Editor Screen - Stitch Prompt

## Screen Purpose
Advanced configuration screen for creating and editing custom learning stages (seders, masechtos, custom learning orders).

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile stage editor screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Curriculum-specific accent colors
- Edit mode: blue (#42A5F5)
- Delete: red (#EF5350)

**Layout (Top to Bottom):**

1. **App Bar**
   - Back/Close button (left, green or X if in edit mode)
   - Title: "Stage Editor" or "[Stage Name]" (if editing)
   - Save button (right, "Save", green) - only visible in edit mode
   - More menu (right, three dots)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Mode Indicator (Edit Mode)**
   - If in edit mode, show banner below app bar
   - Background: blue (#42A5F5) with 10% opacity
   - Icon: pencil (blue)
   - Text: "Editing: [Stage Name]" (14sp, blue)
   - "Cancel" button (right)
   - Height: 40dp
   - Dismissible by tap or "Cancel"

3. **Curriculum Selector**
   - Sticky below app bar
   - Horizontal chip group
   - Select which curriculum to edit stages for
   - Chips: "Mishnayos" "Bavli" "Yerushalmi" etc.
   - Selected: curriculum color background
   - Margin: 16dp horizontal, 12dp vertical

4. **Stage List (View Mode)**

   **List Header:**
   - Title: "Learning Stages" (18sp, bold)
   - Subtitle: "Customize your learning order" (14sp, #B0B0B0)
   - "Add Stage" button (right, green, small)
   - Margin: 16dp horizontal

   **Each Stage Card:**
   - Full-width card
   - Background: #1E1E1E
   - Margin: 16dp horizontal, 8dp vertical
   - Padding: 16dp
   - Corner radius: 12dp
   - Elevation: 2dp

   **Card Layout:**

   **Left Section:**
   - Drag handle (icon: grip-vertical, 24dp, gray)
     - Only visible when "Reorder" mode active
     - 48dp touch target
   - Stage number badge:
     - Circle (32dp)
     - Curriculum color background
     - Number: "1" (16sp, bold, white)

   **Middle Section:**
   - Stage name: "Seder Zeraim" (18sp, bold, white)
   - Hebrew name: "סדר זרעים" (16sp, regular, white, RTL)
   - Content summary:
     - "11 Masechtos • 429 pages"
     - Icon row: 11 small book icons
     - 14sp, #B0B0B0
   - Custom note (if set):
     - Icon: note
     - "Start with easier masechtos"
     - 12sp, italic, #B0B0B0

   **Right Section:**
   - Edit button (icon: pencil, 24dp, green)
   - More menu (three dots)
     - Duplicate stage
     - Move up/down
     - Archive
     - Delete

   **Expansion (Optional):**
   - Tap card to expand
   - Shows list of masechtos in order
   - Each masechta:
     - Name
     - Page count
     - Reorder handle
     - Quick edit icon

5. **Edit Mode Interface**

   **Stage Editor Card (Full Screen or Large Bottom Sheet):**

   **Header:**
   - Title: "Edit Stage" or "Create Stage"
   - Close button (X, top-right)

   **Form Fields:**

   **Stage Name:**
   - Text input
   - Label: "Stage Name"
   - Placeholder: "e.g., Seder Zeraim"
   - Material 3 outlined field
   - Green border when focused
   - Max length: 50 characters
   - Character counter

   **Hebrew Name (Optional):**
   - Text input
   - Label: "Hebrew Name (Optional)"
   - Placeholder: "סדר זרעים"
   - RTL text support
   - Noto Sans Hebrew font
   - Max length: 50 characters

   **Stage Number:**
   - Number picker or dropdown
   - Label: "Stage Order"
   - Shows position in sequence: "1st", "2nd", etc.
   - +/- buttons to adjust
   - Reordering automatically updates other stages
   - Note: "This will be the Xth stage in your learning path"

   **Content Selection:**
   - Section header: "Select Content" (16sp, bold)
   - Expandable masechta list
   - Multi-select checkboxes
   - Search/filter bar at top:
     - Placeholder: "Search masechtos..."
     - Icon: magnifying glass
   - Each masechta item:
     - Checkbox (left)
     - Masechta name: "Berachos"
     - Hebrew: "ברכות" (RTL)
     - Page count: "64 dafim"
     - Already used indicator: "(In Seder Moed)" (amber)
   - "Select All" / "Deselect All" buttons
   - Shows count: "5 masechtos selected"

   **Content Order:**
   - Section header: "Masechta Order" (16sp, bold)
   - Only shows selected masechtos
   - Drag-and-drop list:
     - Each item:
       - Drag handle (left)
       - Masechta name
       - Page count
       - Remove button (X icon, right)
     - Reorder by dragging
     - Smooth animation
   - Default order: traditional/canonical
   - Custom order: user-defined

   **Stage Notes (Optional):**
   - Text area
   - Label: "Notes (Optional)"
   - Placeholder: "Add notes about this stage..."
   - Multi-line
   - Max length: 200 characters
   - Character counter
   - Helper text: "These notes are private and only for you"

   **Difficulty (Optional):**
   - Dropdown or chip group
   - Options: "Beginner" "Intermediate" "Advanced"
   - Icon indicators
   - Helps with recommendation engine

   **Estimated Duration:**
   - Auto-calculated based on:
     - Total pages
     - User's pace (pages/day)
     - Rest days
   - Display: "~6 months at your current pace"
   - Editable override option

   **Action Buttons:**
   - Bottom of sheet, sticky
   - "Cancel" (text button, left)
   - "Save Stage" (filled button, green, right)
   - Full width buttons, 48dp height

6. **Reorder Mode**

   **Activated By:**
   - "Reorder" button in app bar or list header
   - Changes mode indicator to show reordering active

   **Visual Changes:**
   - Drag handles appear on all cards
   - Simplified card view (less info shown)
   - Blue accent color for active mode
   - Cards slightly elevated

   **Interaction:**
   - Long-press card: pick up
   - Drag to new position
   - Other cards shift to make room
   - Drop to place
   - Haptic feedback during drag
   - Auto-renumbers stages

   **Exit Reorder:**
   - "Done" button (green) in app bar
   - Or back button
   - Saves new order automatically

7. **Quick Actions Bar (Optional)**
   - Floating bar above FAB
   - Horizontal row of quick action chips
   - Actions:
     - "Import from Template"
     - "Reset to Default"
     - "Export Order"
     - "Share Configuration"
   - Each chip: icon + label
   - Scrollable if many options

8. **Templates Bottom Sheet (Import)**

   **Sheet Content:**
   - Header: "Import Template" (20sp, bold)
   - Description: "Choose a pre-configured learning order"

   **Template Cards:**
   - Traditional Order:
     - Icon: book-classic
     - Name: "Traditional Seder Order"
     - Description: "Follow the classic Mishna/Talmud order"
     - "Import" button

   - Beginner Friendly:
     - Icon: star-beginner
     - Name: "Beginner's Path"
     - Description: "Start with easier masechtos"
     - Recommended badge
     - "Import" button

   - By Size:
     - Icon: sort-size
     - Name: "Shortest First"
     - Description: "Begin with smaller masechtos for quick wins"
     - "Import" button

   - Custom Imported:
     - Icon: download
     - Name: "Import from File"
     - Description: "Load a shared configuration"
     - "Choose File" button

   **Confirmation:**
   - Warning: "This will replace your current stages"
   - Option: "Merge with existing" checkbox
   - "Cancel" / "Import" buttons

9. **Floating Action Button**
   - Bottom-right corner
   - Icon: plus
   - Background: green (#13ec13)
   - Size: 56dp
   - Action: "Create New Stage"
   - Opens edit mode with empty form

10. **Empty State**

**No Stages:**
```
📚 No custom stages yet

Learning stages help you organize your curriculum
in the order that works best for you.

[Create First Stage] button
[Import Template] button (text button)
```

11. **Preview Mode**

**Activated From:** More menu → "Preview Learning Path"

**Content:**
- Full-screen visualization
- Timeline view showing all stages in order
- Each stage:
  - Number + name
  - Masechtos list
  - Estimated duration
  - Connecting lines/arrows
- Total summary at bottom:
  - "Total: 2,711 pages"
  - "Estimated: 3.5 years at 2 pages/day"
- Share button
- Print/Export button

**Typography:**
- Screen title: 20sp, bold, white
- Section headers: 18sp, bold, white
- Stage name (large): 18sp, bold, white
- Stage name (small): 16sp, bold, white
- Hebrew names: 16sp, regular, white, RTL
- Content summary: 14sp, regular, #B0B0B0
- Form labels: 14sp, medium, #B0B0B0
- Input text: 16sp, regular, white
- Helper text: 12sp, regular, #B0B0B0
- Character counters: 11sp, regular, #B0B0B0
- Button text: 16sp, medium
- Placeholder text: 16sp, regular, #757575

**Interactive Elements:**

**Drag and Drop:**
- Long-press to pick up
- Drag preview: elevated, slightly larger
- Drop zones: highlighted
- Smooth animations
- Haptic feedback
- Cancel: drag outside or ESC

**Multi-Select:**
- Checkboxes: Material 3 style
- Select all/none: batch actions
- Selection count indicator
- Clear selections button

**Search/Filter:**
- Real-time filtering
- Highlight matching text
- Clear button (X) in search field
- No results message

**Context Menus:**
- Stage options:
  - Edit
  - Duplicate
  - Move to position
  - Export
  - Archive
  - Delete (red)

**Confirmations:**
- Delete stage: "Are you sure? This cannot be undone"
- Reset to default: "This will remove all custom stages"
- Import template: "Replace existing stages?"

**Validation:**
- Stage name required
- At least one masechta required
- No duplicate stage names
- Warning if masechta used in multiple stages

**Error Handling:**
- Invalid input: inline error messages
- Save failure: retry option
- Import failure: error details
- Conflict resolution: user choice dialog

**Accessibility:**
- Drag handles: keyboard navigation alternative
- All inputs: proper labels
- Checkbox states announced
- Reorder: arrow key support
- Screen reader: describes stage structure
- Minimum 48dp touch targets

**Animations:**
- Stage creation: slide in from bottom
- Reorder: smooth position changes
- Delete: fade out + collapse
- Expand/collapse: height animation
- Drag preview: elevation + scale

**Loading States:**
- Initial load: skeleton cards
- Import: progress indicator
- Save: button loading state
- Preserve layout during load

**Export Options:**
- JSON file (for backup/sharing)
- Plain text (readable format)
- Share link (if cloud sync enabled)
- QR code (quick share)

**Special Features:**

**Bulk Operations:**
- Long-press for multi-select mode
- Select multiple stages
- Actions: delete, reorder, merge

**Undo/Redo:**
- Undo last change
- Snackbar with undo button
- History stack (last 10 actions)

**Templates:**
- Save current order as template
- Share template with others
- Community templates (optional)
