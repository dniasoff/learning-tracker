# Dashboard Screen - Stitch Prompt

## Screen Purpose
Main home screen showing today's learning tasks, progress overview, and quick actions.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile dashboard screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surfaces: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Curriculum colors: Amber, Blue, Cyan, Burgundy, Green (for different learning paths)

**Layout (Top to Bottom):**

1. **App Bar**
   - Title: "Learning Tracker" (centered or left-aligned)
   - Hamburger menu icon (left)
   - Notification bell icon (right, green with badge if unread)
   - Profile picture (right, 32dp circle)
   - Height: 56dp
   - Background: slightly elevated #1E1E1E

2. **Greeting Header**
   - "Good morning, [User Name]" (dynamic time-based)
   - Hebrew date below: "ב׳ שבט תשפ״ו" (RTL)
   - Today's date: "February 8, 2026"
   - Padding: 16dp horizontal, 24dp top
   - Text hierarchy: name in white bold, dates in #B0B0B0

3. **Today's Tasks Card**
   - Elevated card (#1E1E1E)
   - Header: "Today's Learning" with green dot indicator
   - Margin: 16dp horizontal
   - Corner radius: 12dp
   - Padding: 16dp

   **Task List (scrollable if >3 tasks):**
   - Each task row:
     - Checkbox (left, 24dp, green when checked)
     - Curriculum color accent bar (4dp, vertical)
     - Task text: "Mishnayos: Berachos 12a-13a" (white, 16sp)
     - Page count badge: "2 pages" (green chip)
     - Chevron right (light gray)
   - Row height: 64dp
   - Dividers between tasks (#2E2E2E, 1dp)
   - Completed tasks: strikethrough, dimmed

   **Bottom summary:**
   - "3 of 5 tasks complete" with progress bar
   - Progress bar: green fill (#13ec13), gray background
   - Height: 8dp, rounded

4. **Quick Stats Row**
   - 3 small stat cards in horizontal row
   - Equal width, 8dp spacing
   - Margin: 16dp horizontal

   **Stat Card 1: Current Streak**
   - Icon: Fire/flame (green)
   - Number: "24 days"
   - Label: "Current Streak"
   - Background: #1E1E1E

   **Stat Card 2: This Week**
   - Icon: Calendar check (green)
   - Number: "87%"
   - Label: "Completion Rate"
   - Background: #1E1E1E

   **Stat Card 3: Total Progress**
   - Icon: Book or chart (green)
   - Number: "423 pages"
   - Label: "Total Learned"
   - Background: #1E1E1E

5. **Active Curricula Section**
   - Section header: "Your Curricula" (white, 18sp, bold)
   - Padding: 16dp horizontal
   - Margin top: 24dp

   **Horizontal scrolling curriculum cards:**
   - Card width: 280dp
   - Height: 140dp
   - 12dp spacing between cards
   - Snap scrolling behavior

   **Each curriculum card:**
   - Gradient background (dark to curriculum color)
   - Curriculum icon (top-left, 32dp)
   - Name: "Mishnayos" (20sp, bold, white)
   - Progress ring (top-right, 48dp)
     - Shows completion percentage
     - Green stroke (#13ec13)
   - Current location: "Seder Zeraim • Berachos 13a"
   - Pages left: "127 pages to complete"
   - Bottom button: "Continue Learning" (green outline)
   - Corner radius: 12dp
   - Elevation: 2dp

6. **Recent Activity**
   - Section header: "Recent Activity" (white, 18sp, bold)
   - Padding: 16dp horizontal
   - Margin top: 24dp

   **Activity list (last 5 items):**
   - Compact timeline view
   - Each item:
     - Time ago: "2 hours ago" (#B0B0B0, 12sp)
     - Green dot connector (vertical line)
     - Activity: "Completed Bavli: Berachos 5a" (white, 14sp)
     - Icon representing action (checkmark, bookmark, etc.)
   - Item height: 56dp

7. **Bottom Navigation Bar**
   - Fixed bottom position
   - 5 navigation items
   - Height: 64dp
   - Background: #1E1E1E, elevated

   **Nav items:**
   - Home (selected - green icon & text)
   - Browse (gray icon)
   - Progress (gray icon)
   - Calendar (gray icon)
   - More (gray icon)
   - Icons: 24dp
   - Text: 11sp
   - Selected state: green (#13ec13)

**Card Specifications:**
- All cards: #1E1E1E background
- Corner radius: 12dp
- Elevation: 2dp (4dp on press)
- Padding: 16dp unless specified
- Margin: 16dp horizontal

**Typography:**
- Greeting name: 24sp, bold, white
- Hebrew date: 14sp, regular, #B0B0B0, RTL
- Section headers: 18sp, bold, white
- Task text: 16sp, regular, white
- Stat numbers: 24sp, bold, white
- Stat labels: 12sp, regular, #B0B0B0
- Curriculum name: 20sp, bold, white
- Progress details: 14sp, regular, #B0B0B0
- Activity text: 14sp, regular, white
- Time stamps: 12sp, regular, #B0B0B0

**Interactive Elements:**
- Checkboxes: 24dp, green fill (#13ec13) when checked
- All cards tappable with ripple effect
- Curriculum cards: swipe left/right
- Task rows: tap to expand details
- Bottom nav: immediate response

**Empty States:**
- If no tasks today: "You're all caught up! 🎉" message
- If no curricula: "Add a curriculum to start learning" with CTA button
- If no activity: "Your learning activity will appear here"

**Loading States:**
- Skeleton screens for cards
- Shimmer effect in green
- Preserve layout structure

**Accessibility:**
- All interactive elements: 48dp minimum
- Task checkboxes: clear focus indicators
- Bottom nav: proper labels for screen readers
- Sufficient contrast for all text
- Hebrew text properly rendered RTL

**Scroll Behavior:**
- Main content scrolls vertically
- Curriculum cards scroll horizontally
- App bar can collapse/expand on scroll (optional)
- Bottom nav always visible
