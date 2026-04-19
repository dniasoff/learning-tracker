# Daily Tasks Screen - Stitch Prompt

## Screen Purpose
Detailed view of today's learning tasks with ability to mark completion and view task details.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile daily tasks screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Curriculum-specific accent colors for each task

**Layout (Top to Bottom):**

1. **App Bar**
   - Back button (left, green icon)
   - Title: "Today's Learning"
   - Date subtitle: "February 8, 2026 • ב׳ שבט תשפ״ו" (RTL Hebrew)
   - Calendar icon (right) - tap to change date
   - Height: 64dp (two-line app bar)
   - Background: #1E1E1E, elevated

2. **Progress Summary Card**
   - Elevated card (#1E1E1E)
   - Margin: 16dp horizontal, 16dp top
   - Padding: 16dp
   - Corner radius: 12dp

   **Content:**
   - Large circular progress indicator (center)
     - Size: 120dp diameter
     - Green stroke (#13ec13), 8dp width
     - Shows completion percentage: "60%"
     - Center text: "3 of 5 complete"
   - Below circle:
     - "12 pages remaining today"
     - Small text, #B0B0B0
   - Time estimate: "~30 minutes left" (green text)

3. **Filter/Sort Bar**
   - Horizontal chip group
   - Margin: 16dp
   - Chips:
     - "All" (selected - green)
     - "Pending"
     - "Completed"
     - Sort dropdown: "By Time" / "By Curriculum"
   - Chip height: 32dp
   - 8dp spacing between chips

4. **Task List (Scrollable)**

   **Each Task Card:**
   - Full-width card, 16dp horizontal margin
   - 12dp vertical spacing between cards
   - Background: #1E1E1E
   - Corner radius: 12dp
   - Padding: 16dp
   - Elevation: 2dp (4dp when pressed)

   **Card Layout:**

   **Left Section:**
   - Checkbox (24dp)
     - Unchecked: gray outline
     - Checked: green fill (#13ec13) with white checkmark
     - 48dp touch target

   **Middle Section:**
   - Curriculum color accent bar (4dp width, 100% height, left edge)
   - Curriculum badge: "Mishnayos" (small chip, curriculum color)
   - Main text (16sp, bold, white):
     - "Berachos: Daf 12a - 13a"
   - Subtext (14sp, #B0B0B0):
     - "2 pages • 8-10 minutes"
     - Siyum indicator if applicable: "🎉 Last daf of Masechta!"

   **Right Section:**
   - Chevron right icon (24dp, #B0B0B0)
   - "Go to page" affordance

   **Bottom Section (if expanded):**
   - Details toggle: "Show details" / "Hide details"
   - When expanded:
     - Full reference: "Seder: Zeraim • Masechta: Berachos • Perek: 2"
     - Content type: "Standard daf" or "Review" or "Chazarah"
     - Assigned by: "Self" or "Tutor: Rabbi Cohen" (if applicable)
     - Notes section (if any custom notes)

   **Task States:**
   - **Pending**: normal appearance
   - **Completed**:
     - Checkmark checked
     - Text slightly dimmed (80% opacity)
     - Green success indicator: "Completed at 2:30 PM"
     - Strikethrough optional
   - **Overdue** (if from previous day):
     - Red accent indicator
     - "Overdue" badge in red
   - **Optional** (if marked as optional):
     - Dashed outline instead of solid
     - "Optional" badge

5. **Bulk Actions Button (FAB)**
   - Floating action button (bottom-right)
   - Background: green (#13ec13)
   - Icon: checkmark-all or fast-forward
   - Size: 56dp diameter
   - Elevation: 6dp
   - Label on long-press: "Bulk Mark"
   - Margin: 16dp from bottom-right corner (above nav bar if present)

6. **Quick Add Button**
   - Small FAB (secondary)
   - Position: above main FAB
   - Background: #1E1E1E with green outline
   - Icon: plus sign (green)
   - Size: 48dp diameter
   - Tooltip: "Add custom task"

**Empty States:**
- **All tasks complete:**
  ```
  ✅ You're all done for today!

  Great work completing all 5 tasks.
  See you tomorrow for more learning.

  [View Progress] button
  ```

- **No tasks today:**
  ```
  📚 No tasks scheduled for today

  You can add custom learning or adjust your schedule.

  [Add Task] [View Schedule] buttons
  ```

**Typography:**
- App bar title: 20sp, bold, white
- Date subtitle: 14sp, regular, #B0B0B0
- Progress percentage: 32sp, bold, white
- Progress subtext: 14sp, regular, #B0B0B0
- Time estimate: 14sp, medium, green (#13ec13)
- Filter chips: 14sp, medium
- Task curriculum badge: 11sp, uppercase, medium
- Task main text: 16sp, bold, white
- Task subtext: 14sp, regular, #B0B0B0
- Details text: 13sp, regular, #B0B0B0
- Completion time: 12sp, regular, green

**Interactive Behaviors:**
- Tap checkbox: toggle completion (with haptic feedback)
- Tap card: navigate to learning screen for that task
- Long-press card: show context menu (edit, delete, reschedule)
- Swipe right: quick complete
- Swipe left: skip/postpone options
- Pull-to-refresh: refresh task list

**Animations:**
- Checkbox: scale + checkmark draw animation
- Completion: confetti or subtle celebration for last task
- Card removal: fade + slide when marked complete
- Progress circle: animated fill

**Context Menu Options (long-press):**
- Mark as complete / Mark as incomplete
- Skip for today
- Reschedule to tomorrow
- Edit task details
- Delete task
- Add notes

**Accessibility:**
- All checkboxes: 48dp touch target
- Clear visual distinction between states
- Screen reader announces completion count
- Haptic feedback on actions
- Color is not sole indicator (use icons + text)

**Bottom Sheet (on FAB press):**
- Bulk Mark Complete sheet
- Options:
  - "Mark all remaining as complete"
  - "Mark specific range (e.g., Daf 12a-15a)"
  - "Skip remaining for today"
- Confirmation required
- Dismissible by swipe down or outside tap
