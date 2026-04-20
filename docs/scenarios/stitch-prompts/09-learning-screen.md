# Learning Screen - Stitch Prompt

## Screen Purpose
Main learning interface where users read and mark their current daf/page as complete.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile learning screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Current curriculum color as subtle accent

**Layout (Top to Bottom):**

1. **App Bar**
   - Back button (left, green)
   - Curriculum indicator chip: "Mishnayos" (small, curriculum color)
   - Bookmark icon (right, toggleable - empty/filled)
   - Share icon (right)
   - More menu (three dots, right)
   - Height: 56dp
   - Background: #1E1E1E with slight transparency
   - Elevation: 0dp (blends with content)

2. **Learning Header Card**
   - Full width, elevated card
   - Background: #1E1E1E
   - Padding: 16dp
   - Margin: 16dp horizontal
   - Corner radius: 12dp

   **Content:**
   - Full reference (18sp, bold, white):
     - "Berachos, Perek 2, Daf 12a"
   - Hebrew reference (16sp, regular, white, RTL):
     - "ברכות, פרק ב׳, דף י״ב ע״א"
   - Progress indicator:
     - "Page 12 of 64 in Berachos"
     - Small linear progress bar (curriculum color)
     - Percentage: "18% complete"
   - Time estimate: "~8 minutes to read" (small text, #B0B0B0)

3. **Content Area (Scrollable)**

   **Primary Content:**
   - Large, readable text area
   - Background: slightly lighter than screen (#1A1A1A)
   - Padding: 20dp
   - Margin: 16dp horizontal

   **Content Display Options:**

   **Option A: Link to External Text**
   - Card with message:
     - Icon: book or link icon
     - Title: "Read This Daf"
     - Description: "Tap to open in Sefaria or your preferred Torah text app"
     - Button: "Open Text" (green, outlined)
     - Alternative: "I have my own sefer" (text button)
   - Margin: 16dp

   **Option B: Notes/Commentary Area** (if external)
   - Text input field:
     - Label: "Learning Notes"
     - Placeholder: "Add your notes, insights, or questions here..."
     - Multi-line, auto-expanding
     - Material 3 outlined style
     - Green border when focused
   - Character count (if needed)
   - Voice input button (microphone icon, green)

4. **Study Aids Section (Collapsible)**
   - Expandable card (#1E1E1E)
   - Header: "Study Resources" with chevron
   - When expanded shows:
     - Links to commentaries (Rashi, Tosafos, etc.)
     - Audio shiurim if available
     - Relevant sources/cross-references
     - Each resource as a list item with icon + title
   - Margin: 16dp

5. **Bottom Action Area (Fixed)**
   - Elevated surface (#1E1E1E)
   - Padding: 16dp
   - Elevation: 8dp (floating above content)

   **Content:**

   **Completion Status:**
   - Large checkbox (48dp touch target)
   - Text: "Mark as Complete" (16sp, medium)
   - When checked: "Completed! ✓" (green)

   **Navigation Buttons Row:**
   - Two button layout, equal width
   - 8dp spacing between

   **Previous Button:**
   - Outlined button
   - Text: "← Previous"
   - Subtext: "Daf 11b"
   - Height: 56dp
   - Green outline
   - Disabled if first page

   **Next Button:**
   - Filled button (or outlined if not complete)
   - Text: "Next →"
   - Subtext: "Daf 12b"
   - Height: 56dp
   - Background: green (#13ec13) if current page complete
   - Black text
   - Ripple effect

   **Quick Stats (Optional):**
   - Above buttons, small text
   - "Session time: 6 minutes"
   - "Streak: 24 days 🔥"
   - Centered, #B0B0B0, 12sp

**Context Menu Options (three dots):**
- Add bookmark
- Set reminder
- Mark for review
- Report issue with text
- View history
- Share progress

**Completion Dialog (when marking complete):**
- Bottom sheet or dialog
- Title: "Complete Daf 12a?"
- Optional fields:
  - "How was this daf?" (emoji rating: easy/medium/hard)
  - "Add quick note" (single line input)
  - "Mark for future review" (checkbox)
- Buttons:
  - "Cancel" (text button)
  - "Mark Complete" (green button)
- Celebration on confirm: confetti or checkmark animation

**Typography:**
- App bar curriculum: 12sp, medium, curriculum color
- Reference English: 18sp, bold, white
- Reference Hebrew: 16sp, regular, white, RTL
- Progress text: 14sp, regular, #B0B0B0
- Percentage: 14sp, medium, curriculum color
- Time estimate: 12sp, regular, #B0B0B0
- Content area: 16sp, regular, white (readable body text)
- Notes placeholder: 14sp, regular, #757575
- Notes text: 16sp, regular, white
- Section headers: 16sp, bold, white
- Resource links: 14sp, regular, white
- Button text: 16sp, medium
- Button subtext: 12sp, regular, #B0B0B0
- Stats: 12sp, regular, #B0B0B0

**Interactive Elements:**
- Bookmark: toggle animation (empty ↔ filled)
- Completion checkbox: checkmark animation, haptic feedback
- Navigation buttons: disabled state when appropriate
- Swipe gestures:
  - Swipe right: go to previous page
  - Swipe left: go to next page (if current complete)
- Long-press text: copy/select functionality

**Accessibility:**
- All buttons: 48dp minimum touch target
- Clear focus indicators
- Screen reader support for all content
- Text size respects system settings
- Hebrew text properly rendered RTL
- Audio description support

**Additional Features:**

**Reading Mode Toggle:**
- Button in app bar or bottom sheet
- Options:
  - "Focus Mode" (hide all UI except text)
  - "Split View" (text + notes side-by-side, landscape)
  - "Night Mode" (even darker, sepia text option)

**Timer (Optional):**
- Small floating timer button
- Shows elapsed reading time
- Tap to pause/resume
- Logs time per daf for analytics

**Offline Support:**
- Clear indicator when offline
- Cached content available
- Sync pending indicator

**Empty State (if no external text):**
- Message: "This content is not yet available"
- Option: "Notify me when added"
- Alternative: "I'm using a physical sefer" → skip to completion

**Loading State:**
- Skeleton for header card
- Shimmer for content area
- Preserve layout structure
