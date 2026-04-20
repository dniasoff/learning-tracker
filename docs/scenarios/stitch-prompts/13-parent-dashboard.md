# Parent Dashboard Screen - Stitch Prompt

## Screen Purpose
Parent/guardian interface to monitor multiple children's learning progress and manage reward systems.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile parent dashboard screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Child profile colors: distinct pastels for each child
- Alert colors: amber (#FFB300), red (#EF5350)

**Layout (Top to Bottom):**

1. **App Bar**
   - Hamburger menu (left)
   - Title: "Parent Dashboard"
   - Add child button (right, + icon, green)
   - Notifications bell (right, with badge)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Child Selector (Horizontal Scroll)**
   - Tabs/chips for each child
   - Shows all children + "All" option
   - Margin: 16dp horizontal, 16dp top

   **Each Child Tab:**
   - Profile picture (32dp circle)
   - Name: "Yaakov" (14sp, medium)
   - Status indicator dot:
     - Green: on track today
     - Amber: behind today
     - Gray: no activity
   - Selected: green underline, elevated
   - Unselected: outlined
   - Width: auto, padding: 12dp horizontal
   - Height: 56dp

   **"All" Tab:**
   - Shows overview of all children
   - Icon: family or group
   - Same styling as child tabs

3. **Quick Summary Card (for selected child)**
   - Elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 16dp
   - Corner radius: 12dp

   **Child Header:**
   - Profile picture (56dp circle, left)
   - Name + age: "Yaakov, 12" (20sp, bold)
   - Mode badge: "Self-Learner" (small chip)
   - Quick actions (right):
     - Message child (chat icon)
     - View full profile (person icon)

   **Today's Status:**
   - Progress ring (80dp, centered)
     - Shows today's completion: "3 of 4 tasks"
     - Green stroke for progress
     - Percentage in center: "75%"
   - Below ring:
     - "On track for today! 🎯"
     - Or "1 task remaining" (amber)
     - Or "2 tasks overdue" (red)

   **Weekly Summary (Row):**
   - Three mini-stats:
     - "This week: 18/20 pages"
     - "Streak: 12 days 🔥"
     - "Rewards: 45 points"
   - Icons for each
   - 14sp text, #B0B0B0

4. **Active Curricula (for selected child)**
   - Section header: "Learning Progress" (18sp, bold)
   - Margin: 16dp horizontal

   **Curriculum Cards (List):**
   - Each card shows one curriculum:
     - Curriculum icon + name: "Mishnayos" (16sp, bold)
     - Current location: "Berachos: Daf 12a"
     - Progress bar:
       - Shows pages completed / total
       - Curriculum color
       - "24 of 64 pages • 37%"
     - Last activity: "2 hours ago"
     - Chevron right to drill down
   - Background: #1E1E1E
   - Margin: 16dp horizontal, 8dp vertical
   - Padding: 12dp
   - Corner radius: 8dp

5. **Recent Activity Feed**
   - Section header: "Recent Activity" (18sp, bold)
   - Margin: 16dp horizontal, 24dp top

   **Activity Items (Timeline):**
   - Vertical timeline with dots/line
   - Each item:
     - Time: "2 hours ago" (12sp, #B0B0B0)
     - Green connecting line (2dp)
     - Activity icon (24dp):
       - Checkmark: completed task
       - Star: earned reward
       - Trophy: milestone
       - Book: started new masechta
     - Description: "Completed Bavli: Berachos 5a" (14sp, white)
     - Points earned (if applicable): "+5 points" (green)
   - Item height: 64dp
   - Shows last 10 activities

6. **Rewards Status Card**
   - Elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 16dp
   - Corner radius: 12dp

   **Header:**
   - Title: "Reward Points" (16sp, bold)
   - Manage button (right, text button, green)

   **Points Display:**
   - Large number: "145 points" (28sp, bold, white)
   - Progress to next reward:
     - "55 points until 'Extra Screen Time'"
     - Progress bar (green)
     - Percentage: "73%"

   **Quick Rewards (Horizontal Scroll):**
   - Small reward cards:
     - Icon/emoji for reward
     - Name: "Ice Cream" (12sp)
     - Cost: "50 points"
     - Available badge (green) or Locked (gray)
   - Card size: 100dp x 120dp
   - 8dp spacing
   - Tap to redeem

7. **Weekly Goals Card**
   - Elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 16dp
   - Corner radius: 12dp

   **Content:**
   - Header: "This Week's Goal" (16sp, bold)
   - Goal description: "Complete 20 pages" (14sp)
   - Progress:
     - "18 of 20 pages" (16sp, bold, white)
     - Progress bar (green)
     - "90% complete"
   - Days remaining: "2 days left" (12sp, #B0B0B0)
   - Celebration message if complete: "Goal achieved! 🎉"

8. **All Children View (when "All" tab selected)**

   **Overview Stats:**
   - Total children: "3 children"
   - Active today: "2 of 3 learning today"
   - Combined pages: "45 pages this week"
   - Combined points: "387 points"

   **Child Summary Cards:**
   - One card per child (compact)
   - Each card:
     - Profile picture (40dp)
     - Name + age (16sp, bold)
     - Today's status:
       - "✓ 4 of 4 complete" (green)
       - or "2 of 4 complete" (amber)
       - or "Not started" (gray)
     - Streak: "12 days 🔥"
     - Tap to switch to that child's view
   - Background: #1E1E1E
   - Height: 80dp
   - Margin: 16dp horizontal, 8dp vertical

9. **Floating Action Button**
   - Bottom-right corner
   - Icon: plus or add-task
   - Background: green (#13ec13)
   - Size: 56dp
   - Action: "Add Task for Child"
   - Menu on tap:
     - Add learning task
     - Award bonus points
     - Set new goal
     - Schedule reminder

10. **Bottom Navigation**
    - Fixed bottom
    - 4 tabs for parent mode:
      - "Children" (selected - green)
      - "Rewards"
      - "Reports"
      - "Settings"
    - Icons: 24dp
    - Text: 11sp
    - Selected: green (#13ec13)
    - Height: 64dp
    - Background: #1E1E1E

**Typography:**
- Screen title: 20sp, bold, white
- Section headers: 18sp, bold, white
- Child name (large): 20sp, bold, white
- Child name (small): 16sp, bold, white
- Curriculum name: 16sp, bold, white
- Progress text: 14sp, regular, white
- Stats: 16sp, medium, white
- Stats labels: 12sp, regular, #B0B0B0
- Activity text: 14sp, regular, white
- Time stamps: 12sp, regular, #B0B0B0
- Points: 28sp, bold, white
- Reward names: 12sp, medium, white

**Interactive Elements:**

**Child Tabs:**
- Swipe left/right to switch children
- Tap to select
- Long-press for child options menu

**Progress Cards:**
- Tap curriculum card: view detailed progress
- Tap activity item: view full details
- Swipe activity: options (share, delete)

**Rewards:**
- Tap reward: confirm redemption dialog
- Manage button: opens reward configuration

**Context Menus:**
- Child profile options:
  - Edit profile
  - Adjust goals
  - View full history
  - Pause learning
  - Remove child

**Add Child Flow:**
- Tap + button
- Bottom sheet with form:
  - Name
  - Age
  - Grade
  - Profile picture
  - Initial curriculum selection
  - Learning goal
- Create button (green)

**Empty States:**

**No Children:**
```
👨‍👦 No children added yet

Add your first child to start tracking
their Torah learning journey.

[Add Child] button
```

**No Activity:**
```
📚 No recent activity

Your child's learning activity will appear here.

[View All History] button
```

**Alerts & Notifications:**

**Notification Types:**
- Child completed milestone (trophy icon)
- Child behind on goals (amber warning)
- Reward points earned (star icon)
- New achievement unlocked (badge icon)
- Weekly summary ready (chart icon)

**Alert Cards (if applicable):**
- Amber background for warnings
- Red background for urgent
- Icon + message
- Dismissible
- Action button if needed

**Accessibility:**
- All tabs: 48dp touch target
- Profile pictures: proper alt text
- Progress rings: text alternative
- Color not sole indicator
- Screen reader support
- Clear focus indicators

**Loading States:**
- Skeleton for child selector
- Skeleton for cards
- Shimmer effect (green)
- Preserve layout

**Pull-to-Refresh:**
- Material refresh indicator
- Green color
- Updates all child data
- Haptic feedback

**Sharing Options:**
- Share child's progress
- Weekly summary image
- Achievement celebration
- Social media friendly format
