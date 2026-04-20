# Tutor Dashboard Screen - Stitch Prompt

## Screen Purpose
Tutor/Rebbi interface to manage multiple students, assign learning tasks, and track class progress.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile tutor dashboard screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Status colors: green (on track), amber (needs attention), red (urgent)
- Student colors: distinct pastel accents for identification

**Layout (Top to Bottom):**

1. **App Bar**
   - Hamburger menu (left)
   - Title: "My Students"
   - Search icon (right, green)
   - Add student icon (right, + in circle, green)
   - Notifications bell (right, with badge)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Class/Group Selector**
   - Horizontal scrolling chips
   - Shows all classes/groups + "All Students"
   - Margin: 16dp horizontal, 12dp vertical

   **Each Class Chip:**
   - Class name: "Shiur Alef" (14sp, medium)
   - Student count badge: "12 students"
   - Status indicator:
     - Green dot: all on track
     - Amber dot: some behind
     - Red dot: urgent attention needed
   - Selected: green background
   - Unselected: outlined
   - Height: 48dp
   - Padding: 12dp horizontal

3. **Quick Stats Bar**
   - Three stat cards (horizontal)
   - Equal width, 8dp spacing
   - Margin: 16dp horizontal

   **Stat 1: Total Students**
   - Number: "24" (24sp, bold, white)
   - Label: "Students" (12sp, #B0B0B0)
   - Icon: people group (green)
   - Background: #1E1E1E
   - Padding: 12dp
   - Corner radius: 8dp

   **Stat 2: Active Today**
   - Number: "18 of 24" (24sp, bold, white)
   - Label: "Active Today" (12sp, #B0B0B0)
   - Icon: checkmark circle (green)
   - Percentage: "75%" (small, green)

   **Stat 3: Needs Attention**
   - Number: "3" (24sp, bold, amber or red if urgent)
   - Label: "Need Follow-up" (12sp, #B0B0B0)
   - Icon: alert circle (amber)

4. **Attention Required Section (If Applicable)**
   - Only shows if students need attention
   - Elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 16dp
   - Corner radius: 12dp
   - Amber left border (4dp)

   **Header:**
   - Icon: warning triangle (amber)
   - Title: "Students Needing Attention" (16sp, bold)
   - Count badge: "3 students"

   **Student List (Compact):**
   - Each student row:
     - Profile picture (32dp circle)
     - Name: "Moshe Cohen" (14sp, medium, white)
     - Issue: "3 days behind" or "No activity this week"
     - Quick action button: "Check In" (text button, green)
   - Row height: 56dp
   - Dividers between rows

5. **Student List**
   - Section header: "All Students" (18sp, bold)
   - Filter/sort buttons (right):
     - Grid/List toggle
     - Sort dropdown: "Name • Progress • Last Active"
   - Margin: 16dp horizontal, 24dp top

   **Each Student Card:**
   - Full width card
   - Background: #1E1E1E
   - Margin: 16dp horizontal, 8dp vertical
   - Padding: 16dp
   - Corner radius: 12dp
   - Elevation: 2dp

   **Card Layout:**

   **Left Section:**
   - Profile picture (56dp circle)
   - Status indicator dot (bottom-right of picture):
     - Green: on track
     - Amber: slightly behind
     - Red: significantly behind
     - Gray: no recent activity

   **Middle Section:**
   - Name: "Yaakov Levi" (18sp, bold, white)
   - Grade/Class: "Shiur Alef • 8th Grade" (14sp, #B0B0B0)
   - Current learning:
     - "Bavli: Berachos 12a"
     - Curriculum color accent
     - 14sp, white
   - Progress indicator:
     - "24 of 64 pages • 37%"
     - Small progress bar (curriculum color)
     - 12sp, #B0B0B0

   **Right Section:**
   - Last active: "2h ago" (12sp, #B0B0B0)
   - This week: "18/20 pages ✓" (green) or "12/20 pages" (amber)
   - Chevron right icon (24dp)

   **Quick Actions (Swipe or Long-Press):**
   - Message student
   - Assign task
   - View full progress
   - Mark attendance

6. **Class Progress Overview (Alternative View)**
   - When class selected instead of "All"
   - Shows aggregated class data

   **Class Stats Card:**
   - Background: #1E1E1E
   - Margin: 16dp
   - Padding: 16dp

   **Content:**
   - Class name: "Shiur Alef" (20sp, bold)
   - Student count: "12 students" (14sp, #B0B0B0)
   - Overall completion rate:
     - Large circular progress (100dp)
     - "85% on track"
     - Green stroke
   - Weekly stats:
     - "Total pages: 156 this week"
     - "Average: 13 pages/student"
     - "Class streak: 18 days 🔥"

   **Top Performers:**
   - Sub-section: "Top Learners This Week"
   - Horizontal scrolling cards
   - Each card:
     - Rank badge: "1st", "2nd", "3rd"
     - Profile picture (40dp)
     - Name
     - Pages completed
     - Trophy icon (gold, silver, bronze)
   - Card size: 120dp wide

   **Needs Support:**
   - Sub-section: "Students to Check On"
   - List of 3-5 students
   - Same format as attention required

7. **Recent Activity Feed**
   - Section header: "Recent Activity" (18sp, bold)
   - Margin: 16dp horizontal, 24dp top

   **Activity Timeline:**
   - Vertical timeline with connecting line
   - Each item:
     - Time: "10 minutes ago" (12sp, #B0B0B0)
     - Student picture (24dp circle)
     - Activity: "Moshe completed Bavli: Berachos 5a" (14sp, white)
     - Icon: checkmark, milestone, question, etc.
     - Class tag (if class view): "Shiur Alef"
   - Item height: 64dp
   - Shows last 15 activities

8. **Floating Action Button**
   - Bottom-right corner
   - Icon: plus
   - Background: green (#13ec13)
   - Size: 56dp
   - Speed dial menu on tap:
     - Add student
     - Assign group task
     - Create announcement
     - Schedule class
   - Each option: icon + label

9. **Bottom Navigation**
   - Fixed bottom
   - 4 tabs for tutor mode:
     - "Students" (selected - green)
     - "Assignments"
     - "Reports"
     - "Messages"
   - Icons: 24dp
   - Text: 11sp
   - Selected: green (#13ec13)
   - Height: 64dp
   - Background: #1E1E1E

**Additional Screens/Dialogs:**

**Add Student Dialog:**
- Bottom sheet or full screen
- Form fields:
  - Full name
  - Email (optional, for older students)
  - Grade/Class dropdown
  - Curriculum selection (multi-select)
  - Learning goal
  - Parent contact info (optional)
- "Add Student" button (green)
- Option to "Send invite link"

**Assign Task Dialog:**
- Bottom sheet
- Student selector (if not from student card)
- Curriculum dropdown
- Masechta/section selector
- Page range:
  - Start daf: picker
  - End daf: picker
- Due date: date picker
- Priority: radio buttons (Normal, High, Optional)
- Notes: text area
- "Assign" button (green)
- Option to "Assign to multiple students"

**Student Detail View (tap student card):**
- Full screen or large bottom sheet
- Tabs:
  - Progress
  - Assignments
  - History
  - Notes
- Detailed charts and stats
- Message button
- Edit button

**Quick Check-In Dialog:**
- For students needing attention
- Student name + picture
- Quick note field: "How can I help?"
- Send message button
- Mark as resolved checkbox
- Schedule follow-up option

**Typography:**
- Screen title: 20sp, bold, white
- Section headers: 18sp, bold, white
- Class name: 20sp, bold, white
- Student name (large): 18sp, bold, white
- Student name (small): 14sp, medium, white
- Stats numbers: 24sp, bold, white
- Stats labels: 12sp, regular, #B0B0B0
- Progress text: 14sp, regular, white
- Progress numbers: 12sp, regular, #B0B0B0
- Activity text: 14sp, regular, white
- Time stamps: 12sp, regular, #B0B0B0
- Issue text: 14sp, medium, amber/red
- Button text: 14sp, medium

**Interactive Elements:**

**Student Cards:**
- Tap: view student detail
- Long-press: quick actions menu
- Swipe right: quick message
- Swipe left: assign task

**Status Indicators:**
- Color-coded dots
- Icon overlays for special states
- Animated pulse for urgent items

**Filters/Search:**
- Search: real-time filtering
- Filters bottom sheet:
  - By class
  - By curriculum
  - By status (on track, behind, etc.)
  - By activity (active today, this week, inactive)
  - Sort options

**Context Menus (Student):**
- View full profile
- Send message
- Assign task
- View history
- Edit student info
- Archive student
- Export report

**Empty States:**

**No Students:**
```
👨‍🏫 No students yet

Add your first student to start
tracking their learning.

[Add Student] button
```

**No Activity:**
```
📚 No recent activity

Student activity will appear here
as they complete their learning.
```

**Alerts & Notifications:**

**Notification Types:**
- Student completed milestone (trophy)
- Student behind schedule (amber warning)
- Question from student (? icon)
- Parent message (message icon)
- Assignment due soon (calendar icon)
- Class goal achieved (celebration)

**Priority Indicators:**
- Urgent: red badge with count
- Important: amber badge
- Info: blue badge
- Badge on bell icon in app bar

**Bulk Actions:**
- Long-press to enter selection mode
- Checkboxes appear on cards
- Bottom action bar:
  - "Assign task to selected"
  - "Send group message"
  - "Export selected"
  - "Archive selected"
- Exit: X button or tap outside

**Accessibility:**
- All cards: 48dp minimum touch target
- Status colors + icons (not color alone)
- Screen reader support for all students
- Clear focus indicators
- Profile pictures: alt text with names
- Charts: text alternatives

**Loading States:**
- Skeleton for student cards
- Shimmer effect (green)
- Preserve layout
- Loading indicator for long operations

**Pull-to-Refresh:**
- Material refresh indicator (green)
- Updates student statuses
- Syncs recent activity
- Haptic feedback

**Performance:**
- Infinite scroll for large student lists
- Load 20 students at a time
- Cache student data
- Optimize for classes of 30+ students
