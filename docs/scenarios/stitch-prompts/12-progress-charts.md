# Progress Charts Screen - Stitch Prompt

## Screen Purpose
Visual analytics and charts showing learning progress, trends, and achievements over time.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile progress charts screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Chart colors: green primary, curriculum colors for segments
- Grid lines: #2E2E2E

**Layout (Top to Bottom):**

1. **App Bar**
   - Back button (left, green)
   - Title: "Progress"
   - Time range dropdown (right): "This Month ▼"
   - Share icon (right, green)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Time Range Selector**
   - Below app bar, sticky
   - Horizontal scrolling chips
   - Options:
     - "This Week"
     - "This Month" (selected - green)
     - "Last 30 Days"
     - "This Year"
     - "All Time"
     - "Custom" (opens date range picker)
   - Selected: solid green background
   - Unselected: outlined
   - Padding: 16dp horizontal, 12dp vertical

3. **Key Metrics Row**
   - Three stat cards
   - Equal width, 8dp spacing
   - Margin: 16dp horizontal

   **Card 1: Total Pages**
   - Large number: "423" (32sp, bold, white)
   - Label: "Pages Learned" (12sp, #B0B0B0)
   - Trend indicator: "↑ 12% vs last month" (green, 11sp)
   - Icon: book (green)
   - Background: #1E1E1E
   - Padding: 16dp
   - Corner radius: 12dp

   **Card 2: Completion Rate**
   - Large number: "87%" (32sp, bold, white)
   - Label: "Completion Rate" (12sp, #B0B0B0)
   - Trend: "↑ 5% vs last month" (green)
   - Icon: target/bullseye (green)
   - Background: #1E1E1E

   **Card 3: Current Streak**
   - Large number: "24" (32sp, bold, white)
   - Label: "Day Streak" (12sp, #B0B0B0)
   - Icon: fire emoji or flame (green)
   - Longest streak: "Best: 31 days" (11sp, #B0B0B0)
   - Background: #1E1E1E

4. **Daily Activity Chart**
   - Section header: "Daily Learning" (18sp, bold, white)
   - Margin: 16dp horizontal, 24dp top

   **Chart Card:**
   - Background: #1E1E1E
   - Padding: 16dp
   - Corner radius: 12dp
   - Margin: 16dp horizontal

   **Bar Chart:**
   - X-axis: Days of week or dates
   - Y-axis: Pages completed
   - Bars: green (#13ec13)
   - Height: 200dp
   - Grid lines: horizontal, #2E2E2E, dashed
   - Current day: highlighted border
   - Bar labels: page count on top
   - Touch interaction:
     - Tap bar: show tooltip with details
     - Tooltip: "Tuesday • 6 pages"

   **Chart Controls (Below):**
   - Toggle buttons:
     - "Pages" (selected)
     - "Time"
     - "Sessions"
   - Affects Y-axis metric

5. **Curriculum Breakdown Chart**
   - Section header: "By Curriculum" (18sp, bold, white)
   - Margin: 16dp horizontal, 24dp top

   **Donut Chart Card:**
   - Background: #1E1E1E
   - Padding: 16dp
   - Corner radius: 12dp
   - Margin: 16dp horizontal

   **Chart:**
   - Donut/pie chart showing distribution
   - Center: "423 total pages"
   - Segments: curriculum colors
     - Mishnayos: Amber
     - Bavli: Blue
     - Yerushalmi: Cyan
     - etc.
   - Size: 180dp diameter
   - Centered in card

   **Legend (Below Chart):**
   - List of curricula with:
     - Color square (curriculum color)
     - Name: "Mishnayos"
     - Count: "187 pages"
     - Percentage: "44%"
     - Mini progress bar
   - Row height: 48dp
   - Touch: highlight corresponding segment

6. **Weekly Heatmap**
   - Section header: "Weekly Activity" (18sp, bold, white)
   - Margin: 16dp horizontal, 24dp top

   **Heatmap Card:**
   - Background: #1E1E1E
   - Padding: 16dp
   - Corner radius: 12dp
   - Margin: 16dp horizontal

   **Grid:**
   - 7 columns (days of week)
   - Multiple rows (weeks going back)
   - Each cell:
     - 40dp square
     - 4dp spacing
     - Color intensity based on pages:
       - 0 pages: #1E1E1E (dark)
       - 1-2 pages: light green
       - 3-5 pages: medium green
       - 6+ pages: bright green (#13ec13)
   - Day labels: M T W T F S S (top)
   - Week labels: "Week 1" "Week 2" (left)
   - Touch: tooltip with date + count

   **Legend:**
   - "Less" [gray][light][medium][bright] "More"
   - Below grid
   - Small squares showing scale

7. **Streak Calendar**
   - Section header: "Streak History" (18sp, bold, white)
   - Margin: 16dp horizontal, 24dp top

   **Calendar Card:**
   - Background: #1E1E1E
   - Padding: 16dp
   - Corner radius: 12dp
   - Margin: 16dp horizontal

   **Month Calendar Grid:**
   - Current month
   - Each day:
     - 32dp square
     - Date number
     - Background:
       - Learned: green (#13ec13)
       - Skipped: gray (#2E2E2E)
       - Today: outlined
       - Future: dimmed
   - Streak lines connecting consecutive days
   - Touch: show details for that day

   **Streak Info:**
   - Current: "24 days"
   - Longest: "31 days (Jan 1-31)"
   - This month: "18 of 28 days"

8. **Progress Over Time (Line Chart)**
   - Section header: "Cumulative Progress" (18sp, bold, white)
   - Margin: 16dp horizontal, 24dp top

   **Line Chart Card:**
   - Background: #1E1E1E
   - Padding: 16dp
   - Corner radius: 12dp
   - Margin: 16dp horizontal

   **Chart:**
   - X-axis: Time (dates/months)
   - Y-axis: Total pages completed (cumulative)
   - Line: green (#13ec13), 3dp stroke
   - Gradient fill below line (green, fade to transparent)
   - Height: 220dp
   - Grid: both axes, #2E2E2E
   - Data points: circles on line
   - Touch:
     - Drag to see values
     - Crosshair indicator
     - Tooltip: "Feb 8: 423 pages"

   **Goal Line (Optional):**
   - Dashed line showing projected goal
   - Amber color (#FFD54F)
   - Label: "Goal pace"
   - Shows if on track or behind

9. **Achievements Section**
   - Section header: "Recent Achievements" (18sp, bold, white)
   - Margin: 16dp horizontal, 24dp top

   **Achievement Cards (Horizontal Scroll):**
   - Card width: 200dp
   - Height: 120dp
   - 12dp spacing
   - Background: gradient (#1E1E1E to curriculum color)

   **Each Achievement:**
   - Icon/badge (48dp, centered top)
   - Title: "Siyum Berachos!" (16sp, bold)
   - Date earned: "Feb 1, 2026" (12sp, #B0B0B0)
   - Share button (bottom)

   **Achievement Types:**
   - Siyum (completed masechta)
   - Streak milestones (7, 30, 100 days)
   - Page milestones (100, 500, 1000)
   - Speed records
   - Consistency awards

10. **Bottom Action Button**
    - Sticky at bottom
    - Full width
    - "View Detailed Report" button
    - Green (#13ec13)
    - Height: 48dp
    - Opens comprehensive report screen

**Typography:**
- Screen title: 20sp, bold, white
- Section headers: 18sp, bold, white
- Stat numbers: 32sp, bold, white
- Stat labels: 12sp, regular, #B0B0B0
- Trend indicators: 11sp, medium, green/red
- Chart labels: 12sp, regular, #B0B0B0
- Chart values: 14sp, medium, white
- Legend items: 14sp, regular, white
- Tooltip text: 13sp, medium, white
- Achievement titles: 16sp, bold, white
- Achievement dates: 12sp, regular, #B0B0B0

**Chart Specifications:**

**All Charts:**
- Smooth animations on load
- Touch interactions enabled
- Responsive to time range changes
- Empty state handling
- Loading skeletons

**Colors:**
- Primary data: green (#13ec13)
- Secondary data: curriculum colors
- Grid lines: #2E2E2E
- Background: #1E1E1E
- Text: white/#B0B0B0
- Goal/target: amber (#FFD54F)

**Tooltips:**
- Background: #2E2E2E
- Text: white
- Padding: 8dp
- Corner radius: 4dp
- Elevation: 4dp
- Arrow pointing to data point

**Interactive Behaviors:**
- Tap chart: show tooltip
- Drag on line chart: scrub through data
- Tap legend: highlight/filter data
- Pinch-zoom on charts (optional)
- Swipe between time ranges

**Empty States:**
- No data for period: "No learning data for this period"
- Icon: empty chart illustration
- Message: suggestion to adjust time range
- CTA: "View all time" or "Start learning"

**Loading States:**
- Skeleton charts with shimmer
- Preserve chart shapes
- Green shimmer color
- Smooth transition when data loads

**Export/Share:**
- Share button generates:
  - Image of current chart
  - PDF report
  - Social media friendly format
- Options:
  - Save to photos
  - Share to social
  - Email report

**Accessibility:**
- Chart data available as table
- Screen reader descriptions
- Touch targets: 48dp minimum
- Color + pattern for distinctions
- High contrast mode support
- Alt text for all charts

**Performance:**
- Lazy load charts as user scrolls
- Cache chart images
- Optimize for large datasets
- Smooth 60fps animations
