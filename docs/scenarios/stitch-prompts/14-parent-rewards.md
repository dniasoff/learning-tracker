# Parent Rewards Management Screen - Stitch Prompt

## Screen Purpose
Parent interface to configure, manage, and award rewards/points for children's learning achievements.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile parent rewards management screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Reward tier colors: bronze (#CD7F32), silver (#C0C0C0), gold (#FFD700)
- Points: amber (#FFB300)

**Layout (Top to Bottom):**

1. **App Bar**
   - Back button (left, green)
   - Title: "Rewards"
   - Filter/sort icon (right)
   - More menu (right, three dots)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Child Selector**
   - Horizontal scrolling tabs
   - Each child's name + profile picture
   - Selected: green underline
   - Switch child to manage their rewards
   - Margin: 16dp horizontal, 12dp vertical

3. **Points Summary Card**
   - Large elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 20dp
   - Corner radius: 12dp

   **Content:**
   - Child name + picture (small, top-left)
   - Large points display (center):
     - Icon: star or coin (amber, 56dp)
     - Number: "145 points" (36sp, bold, white)
     - Subtext: "Available to spend" (14sp, #B0B0B0)

   **Quick Actions (Bottom Row):**
   - Two buttons, equal width
   - "Award Points" (filled, green)
   - "View History" (outlined, green)
   - Height: 40dp

4. **Active Rewards Section**
   - Section header: "Available Rewards" (18sp, bold)
   - Subtext: "Rewards your child can earn" (14sp, #B0B0B0)
   - Margin: 16dp horizontal, 24dp top

   **Reward Cards (Grid or List):**
   - 2 columns grid (can switch to list)
   - Card width: ~45% screen width each
   - 12dp spacing

   **Each Reward Card:**
   - Background: #1E1E1E
   - Corner radius: 12dp
   - Padding: 12dp
   - Elevation: 2dp
   - Aspect ratio: ~1:1.2

   **Card Content:**
   - Emoji/icon (large, 56dp, top center):
     - 🍦 Ice cream
     - 📺 Screen time
     - 🎮 Game time
     - 📖 Book choice
     - 🎁 Toy
     - Custom emojis
   - Title: "Ice Cream Treat" (16sp, bold, white)
   - Point cost badge (prominent):
     - "50 points"
     - Amber chip/badge
     - 14sp, medium
   - Status:
     - Available: green checkmark + "Can redeem"
     - Needs more: gray + "Need 30 more points"
     - Redeemed: dimmed + "Redeemed 2 days ago"
   - Redeem button (bottom):
     - If affordable: green filled "Redeem"
     - If not: gray outlined "Locked"
   - More menu (top-right, three dots):
     - Edit reward
     - Deactivate
     - Delete

5. **Quick Award Section**
   - Section header: "Quick Award" (18sp, bold)
   - Subtext: "Award points for common achievements" (14sp, #B0B0B0)
   - Margin: 16dp horizontal, 24dp top

   **Quick Award Chips:**
   - Horizontal scrolling chip row
   - Each chip:
     - Icon + text: "✓ Completed Daf" "+5"
     - Pre-set point values
     - Tap to award instantly
     - Confirmation snackbar after tap
   - Examples:
     - "Completed Daf: +5"
     - "Perfect Week: +20"
     - "Helped Sibling: +10"
     - "Extra Study: +15"
     - "Behavior: +5"
   - Chip style: outlined, green accent
   - Height: 40dp

6. **Reward Tiers Card (Optional)**
   - Elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 16dp
   - Corner radius: 12dp

   **Content:**
   - Header: "Reward Tiers" (16sp, bold)
   - Description: "Save up for bigger rewards!"

   **Tier List:**
   - Bronze tier (50-100 points):
     - Icon: bronze medal
     - "Small treats & privileges"
     - Example rewards: 3-4 items
   - Silver tier (100-250 points):
     - Icon: silver medal
     - "Special activities"
     - Example rewards: 3-4 items
   - Gold tier (250+ points):
     - Icon: gold medal
     - "Big rewards & experiences"
     - Example rewards: 3-4 items

   - Each tier: collapsible
   - Tier color indicators
   - Progress to next tier shown

7. **Redemption History**
   - Section header: "Recent Redemptions" (18sp, bold)
   - Margin: 16dp horizontal, 24dp top

   **History Items (List):**
   - Compact timeline view
   - Each item:
     - Date: "Feb 8, 2026" (12sp, #B0B0B0)
     - Reward icon (24dp)
     - Reward: "Ice Cream Treat" (14sp, white)
     - Points: "-50 points" (red text)
     - Status: "Fulfilled ✓" or "Pending"
   - Dividers between items
   - Show last 10 redemptions
   - "View All" link at bottom

8. **Floating Action Button**
   - Bottom-right corner
   - Icon: plus
   - Background: green (#13ec13)
   - Size: 56dp
   - Action: "Create New Reward"
   - Opens reward creation sheet

9. **Create/Edit Reward Bottom Sheet**

   **Sheet Content:**
   - Handle bar (top, centered)
   - Title: "Create New Reward" (20sp, bold)
   - Close button (top-right)

   **Form Fields:**

   **Reward Icon:**
   - Large icon picker
   - Grid of emoji options
   - Categories: Food, Activities, Items, Custom
   - Selected: green border
   - Size: 56dp each

   **Reward Name:**
   - Text input
   - Label: "Reward Name"
   - Placeholder: "e.g., Ice Cream Treat"
   - Material 3 outlined field
   - Max length: 50 characters

   **Point Cost:**
   - Number input
   - Label: "Point Cost"
   - Stepper: -/+ buttons
   - Range: 5-500 points
   - Large number display (24sp)

   **Description (Optional):**
   - Text area
   - Label: "Description"
   - Placeholder: "Any details about this reward..."
   - Multi-line
   - Max length: 200 characters

   **Tier Selection:**
   - Dropdown or chip group
   - Options: Bronze, Silver, Gold
   - Affects color accent on card

   **Availability:**
   - Toggle switches:
     - "Active" (enable/disable)
     - "Unlimited redemptions"
     - If off: "Max redemptions per month" (number)
   - Green toggle color

   **Auto-Award (Optional):**
   - Checkbox: "Auto-award when child achieves:"
   - Dropdown: milestone options
   - E.g., "Completes 10 dafim" → auto-awards this reward

   **Action Buttons:**
   - "Cancel" (text button, left)
   - "Create Reward" (filled button, green, right)
   - Full width buttons, 48dp height

10. **Award Points Dialog**

    **Dialog Content:**
    - Title: "Award Points to [Child Name]"
    - Child profile picture (centered, 64dp)

    **Points Input:**
    - Large number picker
    - +/- buttons (56dp, green)
    - Default: +5
    - Range: 1-100
    - Number display: 32sp, bold

    **Reason (Optional):**
    - Dropdown: common reasons
      - "Completed learning task"
      - "Extra effort"
      - "Helped sibling"
      - "Good behavior"
      - "Custom" → text input
    - Or quick select chips

    **Message (Optional):**
    - Text input
    - Placeholder: "Great job on..."
    - Shows up in child's notifications
    - Max length: 100 characters

    **Buttons:**
    - "Cancel" (text button)
    - "Award [X] Points" (filled, green)
    - Celebration animation on award

11. **Redeem Confirmation Dialog**

    **Dialog Content:**
    - Reward icon (large, 80dp, centered)
    - Reward name: "Ice Cream Treat" (20sp, bold)
    - Cost: "50 points" (18sp, amber)
    - Child's current points: "145 points"
    - After redemption: "95 points remaining"

    **Fulfillment Options:**
    - Radio buttons:
      - "Mark as fulfilled now" (default)
      - "Pending - will fulfill later"
      - "Schedule for [date picker]"

    **Note to Child:**
    - Text input (optional)
    - "Add a message for [child name]..."
    - Max 100 characters

    **Buttons:**
    - "Cancel" (text button)
    - "Confirm Redemption" (filled, green)
    - Success feedback: checkmark animation

**Typography:**
- Screen title: 20sp, bold, white
- Section headers: 18sp, bold, white
- Child name: 16sp, medium, white
- Points (large): 36sp, bold, white
- Points (small): 14sp, medium, amber (#FFB300)
- Reward titles: 16sp, bold, white
- Reward descriptions: 14sp, regular, #B0B0B0
- Quick award chips: 14sp, medium, white
- History items: 14sp, regular, white
- Dates: 12sp, regular, #B0B0B0
- Form labels: 14sp, medium, #B0B0B0
- Input text: 16sp, regular, white

**Interactive Elements:**

**Reward Cards:**
- Tap to view details
- Long-press for options
- Swipe left: edit
- Swipe right: quick redeem

**Quick Award Chips:**
- Tap: instant award with confirmation
- Haptic feedback
- Success snackbar: "+5 points awarded!"

**Points Display:**
- Animated counter when points change
- Confetti on large awards
- Sound effect option

**Context Menus (Reward Card):**
- Edit reward
- Duplicate
- Archive (soft delete)
- Delete permanently
- Set as featured
- Share with other parents

**Filters/Sort (App Bar):**
- Bottom sheet options:
  - Filter by tier
  - Filter by affordable/not affordable
  - Sort by: cost, recent, popular
  - Show inactive rewards

**Empty States:**

**No Rewards:**
```
🎁 No rewards yet

Create rewards to motivate your child's learning.

[Create First Reward] button
```

**No Redemption History:**
```
📜 No redemptions yet

When your child redeems rewards,
they'll appear here.
```

**Accessibility:**
- All cards: 48dp minimum touch target
- Clear labels for inputs
- Screen reader support
- Icon descriptions
- Color not sole indicator
- Haptic feedback on actions

**Animations:**
- Point award: counter animation
- Redemption: celebration (confetti/checkmark)
- Card creation: slide in from bottom
- Filter apply: smooth transition

**Gamification:**
- Progress rings for tier advancement
- Badge unlock animations
- Streak bonuses displayed
- Leaderboard option (if multiple children)
