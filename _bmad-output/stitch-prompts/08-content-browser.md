# Content Browser Screen - Stitch Prompt

## Screen Purpose
Browse and navigate Torah learning content by curriculum, with hierarchical navigation (Seder → Masechta → Perek → Daf).

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile content browser screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Curriculum-specific colors: Amber (Mishnayos), Blue (Bavli), Cyan (Yerushalmi), Burgundy (Mishna Berurah), Green (Chumash)

**Layout (Top to Bottom):**

1. **App Bar**
   - Back button (left, green) or Hamburger menu
   - Title: "Browse Content"
   - Search icon (right, green)
   - Filter icon (right, green)
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **Breadcrumb Navigation**
   - Shows current location in hierarchy
   - Examples:
     - "All Curricula" (root level)
     - "Mishnayos > Seder Zeraim" (level 2)
     - "Bavli > Seder Nezikin > Bava Kamma" (level 3)
     - "Mishnayos > Seder Zeraim > Berachos > Perek 2" (level 4)
   - Tappable breadcrumbs to navigate back
   - Horizontal scroll if too long
   - Padding: 16dp
   - Text: 14sp, #B0B0B0, separator: ">"
   - Current location: white, bold

3. **Quick Stats Bar (if curriculum selected)**
   - Horizontal scrolling mini-stats
   - Shows for current context:
     - Progress: "24 of 63 dapim complete"
     - Last studied: "2 hours ago"
     - Time estimate: "~6 months to complete"
   - Chips style, 8dp spacing
   - Green accents for numbers

4. **Content Grid/List**

   **View Mode Toggle:**
   - Grid view (2 columns) or List view (single column)
   - Toggle button in top-right of content area
   - Default: List view

   **Root Level - Curriculum Selection (5 Cards):**
   Each card:
   - Large card (full width if list, half width if grid)
   - Height: 160dp (list) or 180dp (grid)
   - Curriculum color gradient background
   - Curriculum icon (48dp, top-left)
   - Name: "Mishnayos" (24sp, bold, white)
   - Hebrew name: "משניות" (18sp, regular, white, RTL)
   - Progress ring (top-right, 56dp)
     - Shows overall completion %
     - Curriculum color stroke
   - Stats row (bottom):
     - "63 Masechtos"
     - "2,711 pages"
     - "24% complete"
   - Corner radius: 16dp
   - Margin: 16dp horizontal, 12dp vertical
   - Tap: drill into curriculum

   **Seder Level (for Mishnayos/Bavli):**
   Each Seder card:
   - Medium height: 120dp
   - Left accent bar (8dp, curriculum color)
   - Seder name: "Seder Zeraim" (20sp, bold)
   - Hebrew: "סדר זרעים" (16sp, RTL)
   - Masechta count: "11 Masechtos"
   - Progress bar (bottom, 4dp height)
   - Grid icon showing masechta layout
   - Background: #1E1E1E

   **Masechta Level:**
   Each Masechta card:
   - Height: 100dp
   - Curriculum color accent (left bar, 8dp)
   - Masechta name: "Berachos" (18sp, bold)
   - Hebrew: "ברכות" (16sp, RTL)
   - Page count: "64 dafim"
   - Progress: "12 of 64 complete" with small progress bar
   - Last studied indicator (if applicable): green dot + "2 days ago"
   - Bookmark icon (right) if bookmarked
   - Background: #1E1E1E
   - Tap: show Perek list or Daf list

   **Perek Level (for some curricula):**
   Each Perek item:
   - Compact row, 72dp height
   - Number circle (left): "1" (curriculum color background)
   - Perek name: "Perek 1" or custom name if available
   - Page range: "2a - 13a"
   - Completion status: "Complete" or "3 of 12 pages"
   - Chevron right
   - Background: #1E1E1E
   - Divider between items

   **Daf/Page Level:**
   - List of individual pages
   - Compact rows, 64dp height
   - Checkbox (left): completed or not (green when checked)
   - Daf reference: "Daf 12a" (16sp)
   - Side badge: "Amud Alef" / "Amud Bet"
   - Status indicators:
     - Completed: green checkmark
     - In progress: partially filled circle
     - Not started: empty circle
     - Reviewed: star icon
   - Date completed (if applicable): "Feb 6" (12sp, #B0B0B0)
   - Quick actions (swipe):
     - Swipe right: mark complete
     - Swipe left: add to custom list
   - Divider between items

5. **Floating Action Button**
   - Bottom-right, 56dp diameter
   - Background: green (#13ec13)
   - Icon: play arrow or book-open
   - Action: "Start Learning" from current context
   - Only visible when curriculum/masechta selected
   - Margin: 16dp from edges

6. **Bottom Sheet (on Filter tap):**
   - Filter options:
     - Show: All / Completed / In Progress / Not Started
     - Sort by: Name / Progress / Last Studied / Pages
     - Curricula: Multi-select checkboxes
   - Apply button (green)
   - Reset button (text button)

7. **Search Overlay (on Search tap):**
   - Full-screen search
   - Search bar at top
   - Recent searches
   - Search suggestions as you type
   - Results grouped by curriculum
   - Result format:
     - Masechta name
     - Full path: "Bavli > Seder Moed > Shabbos"
     - Page count
   - Tap result: navigate directly to that content

**Typography:**
- Breadcrumbs: 14sp, regular, #B0B0B0
- Current breadcrumb: 14sp, bold, white
- Curriculum name (card): 24sp, bold, white
- Hebrew curriculum name: 18sp, regular, white, RTL
- Seder name: 20sp, bold, white
- Masechta name: 18sp, bold, white
- Perek name: 16sp, medium, white
- Daf name: 16sp, regular, white
- Stats: 14sp, regular, #B0B0B0
- Progress numbers: 14sp, medium, green
- Completion dates: 12sp, regular, #B0B0B0

**Card Specifications:**
- All cards: #1E1E1E background
- Curriculum cards: gradient from dark to curriculum color
- Corner radius: 12dp
- Elevation: 2dp (4dp on press)
- Margin: 16dp horizontal, 12dp vertical (list view)
- Grid margin: 8dp all sides (grid view)
- Ripple effect on tap

**Progress Indicators:**
- Progress bars: curriculum color fill, gray background
- Height: 4dp, rounded ends
- Progress rings: curriculum color stroke, 6dp width
- Percentage text: white or curriculum color

**Status Icons:**
- Completed: green checkmark (#13ec13)
- In progress: partially filled circle (curriculum color)
- Not started: empty circle (#757575)
- Bookmarked: bookmark icon (amber #FFD54F)
- Last studied: small green dot

**Empty States:**
- No curricula selected: "Select a curriculum to start browsing"
- No content: "No content available"
- No search results: "No results found for '[query]'"

**Loading States:**
- Skeleton cards with shimmer
- Preserve layout structure
- Green shimmer color

**Accessibility:**
- All cards: minimum 72dp touch target
- Breadcrumbs: tappable with clear focus
- Screen reader support for hierarchy
- RTL Hebrew text support
- Color not sole indicator (use icons + text)

**Interactive Behaviors:**
- Tap card: drill down one level
- Tap breadcrumb: navigate back to that level
- Long-press card: show context menu (bookmark, add to custom list, share)
- Swipe refresh: refresh content
- Grid/List toggle: smooth transition animation
