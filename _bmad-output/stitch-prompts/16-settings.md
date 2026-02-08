# Settings Screen - Stitch Prompt

## Screen Purpose
Main settings and preferences screen for configuring app behavior, account, notifications, and appearance.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile settings screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent: bright green (#13ec13)
- Card/surface: #1E1E1E
- Text: white primary, #B0B0B0 secondary
- Dividers: #2E2E2E
- Destructive actions: red (#EF5350)

**Layout (Top to Bottom):**

1. **App Bar**
   - Back button (left, green)
   - Title: "Settings"
   - Height: 56dp
   - Background: #1E1E1E, elevated

2. **User Profile Section**
   - Elevated card (#1E1E1E)
   - Margin: 16dp
   - Padding: 16dp
   - Corner radius: 12dp
   - Tappable (navigates to full profile)

   **Content:**
   - Profile picture (64dp circle, left)
   - Edit icon overlay on picture (camera icon)
   - Name: "Moshe Cohen" (20sp, bold, white)
   - Email: "moshe@example.com" (14sp, #B0B0B0)
   - Mode badge: "Self-Learner" or "Parent" or "Tutor" (small chip, green)
   - Chevron right (indicating tappable)

3. **Settings Groups (Scrollable List)**

**Group 1: Learning Preferences**
- Group header: "LEARNING" (12sp, uppercase, #B0B0B0)
- Padding: 16dp horizontal, 8dp vertical

**Setting Items:**

**Curricula Management:**
- Icon: book stack (green, 24dp)
- Title: "My Curricula" (16sp, white)
- Subtitle: "3 active • Mishnayos, Bavli, Chumash" (14sp, #B0B0B0)
- Chevron right
- Tap: navigate to curriculum selection screen

**Learning Goals:**
- Icon: target (green, 24dp)
- Title: "Learning Goals" (16sp, white)
- Subtitle: "2 pages per day • Complete by Dec 2026" (14sp, #B0B0B0)
- Chevron right
- Tap: opens goal configuration

**Daily Reminder:**
- Icon: clock (green, 24dp)
- Title: "Daily Reminder" (16sp, white)
- Subtitle: "9:00 PM • Every day" (14sp, #B0B0B0) or "Off"
- Toggle switch (right):
  - On: green
  - Off: gray
- Tap row or switch: toggles
- If on, tap subtitle: configure time

**Rest Days:**
- Icon: calendar-x (green, 24dp)
- Title: "Rest Days" (16sp, white)
- Subtitle: "Shabbos • Yom Tov" (14sp, #B0B0B0) or "None"
- Chevron right
- Tap: multi-select dialog for rest days

**Hebrew Calendar:**
- Icon: calendar-hebrew (green, 24dp)
- Title: "Show Hebrew Dates" (16sp, white)
- Toggle switch (right):
  - On: green (shows Hebrew dates throughout app)
  - Off: gray

**Divider** (1dp, #2E2E2E)

**Group 2: Appearance**
- Group header: "APPEARANCE" (12sp, uppercase, #B0B0B0)

**Theme:**
- Icon: palette (green, 24dp)
- Title: "Theme" (16sp, white)
- Subtitle: "Dark" (14sp, #B0B0B0)
- Chevron right
- Tap: bottom sheet with options:
  - Light
  - Dark (selected)
  - System default

**Accent Color:**
- Icon: color-fill (green, 24dp)
- Title: "Accent Color" (16sp, white)
- Subtitle: "Green" (14sp, #B0B0B0)
- Color preview circle (right, 32dp, green)
- Tap: color picker dialog:
  - Green (default)
  - Blue
  - Purple
  - Teal
  - Amber

**Font Size:**
- Icon: text-size (green, 24dp)
- Title: "Text Size" (16sp, white)
- Subtitle: "Medium" (14sp, #B0B0B0)
- Chevron right
- Tap: slider dialog (Small, Medium, Large, Extra Large)

**Language:**
- Icon: globe (green, 24dp)
- Title: "Language" (16sp, white)
- Subtitle: "English" (14sp, #B0B0B0)
- Chevron right
- Tap: language selector:
  - English
  - Hebrew (עברית)
  - Yiddish (if supported)

**Divider**

**Group 3: Notifications**
- Group header: "NOTIFICATIONS" (12sp, uppercase, #B0B0B0)

**Push Notifications:**
- Icon: bell (green, 24dp)
- Title: "Push Notifications" (16sp, white)
- Toggle switch (right)
- When off: disables all below

**Learning Reminders:**
- Icon: book-clock (green, 24dp)
- Title: "Learning Reminders" (16sp, white)
- Subtitle: "Remind me to learn" (14sp, #B0B0B0)
- Toggle switch (right)

**Milestone Celebrations:**
- Icon: trophy (green, 24dp)
- Title: "Milestones & Achievements" (16sp, white)
- Subtitle: "Celebrate when I complete goals" (14sp, #B0B0B0)
- Toggle switch (right)

**Streak Alerts:**
- Icon: fire (green, 24dp)
- Title: "Streak Alerts" (16sp, white)
- Subtitle: "Notify when streak is at risk" (14sp, #B0B0B0)
- Toggle switch (right)

**Parent/Tutor Updates (if applicable):**
- Icon: people (green, 24dp)
- Title: "Parent/Tutor Updates" (16sp, white)
- Subtitle: "Progress updates sent to Rabbi Cohen" (14sp, #B0B0B0)
- Toggle switch (right)

**Notification Sound:**
- Icon: volume (green, 24dp)
- Title: "Notification Sound" (16sp, white)
- Subtitle: "Default" (14sp, #B0B0B0)
- Chevron right
- Tap: sound picker

**Divider**

**Group 4: Data & Privacy**
- Group header: "DATA & PRIVACY" (12sp, uppercase, #B0B0B0)

**Sync Settings:**
- Icon: cloud-sync (green, 24dp)
- Title: "Cloud Sync" (16sp, white)
- Subtitle: "Last synced: 5 minutes ago" (14sp, #B0B0B0) or "Syncing..." with spinner
- Toggle switch (right)
- Tap: sync options:
  - Auto-sync
  - WiFi only
  - Manual sync button

**Data Usage:**
- Icon: chart-bar (green, 24dp)
- Title: "Data Usage" (16sp, white)
- Subtitle: "Storage: 45 MB • Network: 12 MB this month" (14sp, #B0B0B0)
- Chevron right
- Tap: detailed breakdown

**Export Data:**
- Icon: download (green, 24dp)
- Title: "Export My Data" (16sp, white)
- Subtitle: "Download your learning history" (14sp, #B0B0B0)
- Chevron right
- Tap: export options (CSV, PDF, JSON)

**Clear Cache:**
- Icon: trash (green, 24dp)
- Title: "Clear Cache" (16sp, white)
- Subtitle: "45 MB cached" (14sp, #B0B0B0)
- Tap: confirmation dialog, then clear

**Divider**

**Group 5: Account**
- Group header: "ACCOUNT" (12sp, uppercase, #B0B0B0)

**Email & Password:**
- Icon: key (green, 24dp)
- Title: "Email & Password" (16sp, white)
- Subtitle: "Change email or password" (14sp, #B0B0B0)
- Chevron right

**Connected Accounts:**
- Icon: link (green, 24dp)
- Title: "Connected Accounts" (16sp, white)
- Subtitle: "Google" (14sp, #B0B0B0) or "None"
- Chevron right
- Tap: manage connections (link/unlink Google, Apple)

**Subscription (if applicable):**
- Icon: star (green, 24dp)
- Title: "Premium Subscription" (16sp, white)
- Subtitle: "Active until Dec 2026" (14sp, #B0B0B0) or "Upgrade to Premium"
- Badge: "PRO" (gold)
- Chevron right

**Divider**

**Group 6: Support & About**
- Group header: "SUPPORT & ABOUT" (12sp, uppercase, #B0B0B0)

**Help Center:**
- Icon: question-circle (green, 24dp)
- Title: "Help Center" (16sp, white)
- Subtitle: "FAQs and guides" (14sp, #B0B0B0)
- Chevron right

**Contact Support:**
- Icon: mail (green, 24dp)
- Title: "Contact Support" (16sp, white)
- Subtitle: "Get help from our team" (14sp, #B0B0B0)
- Chevron right
- Tap: opens email or in-app support form

**Share Feedback:**
- Icon: message-square (green, 24dp)
- Title: "Share Feedback" (16sp, white)
- Subtitle: "Help us improve" (14sp, #B0B0B0)
- Chevron right

**Rate App:**
- Icon: star-outline (green, 24dp)
- Title: "Rate Learning Tracker" (16sp, white)
- Subtitle: "Show your support" (14sp, #B0B0B0)
- Chevron right
- Tap: opens Play Store rating

**Privacy Policy:**
- Icon: shield (green, 24dp)
- Title: "Privacy Policy" (16sp, white)
- Chevron right

**Terms of Service:**
- Icon: document (green, 24dp)
- Title: "Terms of Service" (16sp, white)
- Chevron right

**About:**
- Icon: info (green, 24dp)
- Title: "About" (16sp, white)
- Subtitle: "Version 1.0.0 (Build 42)" (14sp, #B0B0B0)
- Chevron right
- Tap: about screen with:
  - App icon
  - Version info
  - Credits
  - Open source licenses
  - Copyright

**Divider**

**Group 7: Danger Zone (Bottom)**
- Group header: "ACCOUNT ACTIONS" (12sp, uppercase, red)
- Background: slightly different (#1A1A1A) to separate

**Sign Out:**
- Icon: log-out (red, 24dp)
- Title: "Sign Out" (16sp, red)
- No subtitle
- Tap: confirmation dialog

**Delete Account:**
- Icon: trash-x (red, 24dp)
- Title: "Delete Account" (16sp, red)
- Subtitle: "Permanently delete your account" (14sp, #B0B0B0)
- Tap: multi-step confirmation:
  1. Warning dialog
  2. Type "DELETE" to confirm
  3. Enter password
  4. Final confirmation

4. **Bottom Padding**
   - Extra space (80dp) for comfortable scrolling

**Typography:**
- Screen title: 20sp, bold, white
- Group headers: 12sp, bold, uppercase, #B0B0B0
- Setting title: 16sp, medium, white
- Setting subtitle: 14sp, regular, #B0B0B0
- Dialog titles: 20sp, bold, white
- Dialog text: 16sp, regular, white
- Button text: 16sp, medium

**Interactive Elements:**

**List Items:**
- Each row: minimum 64dp height
- Padding: 16dp horizontal
- Ripple effect on tap
- Clear touch feedback
- Icon: 24dp (left, 16dp from edge)
- Text: starts 56dp from left
- Toggle/chevron: right, 16dp from edge

**Toggle Switches:**
- Material 3 switch component
- On: green (#13ec13)
- Off: gray (#757575)
- 48dp touch target
- Haptic feedback on toggle
- Smooth animation

**Dialogs/Bottom Sheets:**
- Modal dialogs for confirmations
- Bottom sheets for selections
- Material 3 styling
- Backdrop dim: 50% black
- Dismiss: tap outside or swipe down (sheets)

**Confirmation Dialogs:**
- Title
- Message
- Two buttons:
  - "Cancel" (text button, left)
  - "Confirm" (filled button, right)
- Destructive actions: red confirm button

**Selection Dialogs:**
- Radio buttons for single select
- Checkboxes for multi-select
- Search bar if many options
- "Done" button at bottom

**Empty States:**
Not typically applicable for settings, but:
- Sync error: show error message with retry
- No connected accounts: "Tap to connect"

**Loading States:**
- Sync in progress: spinning icon
- Data export: progress bar
- Account operations: full-screen loader

**Error Handling:**
- Inline errors below fields
- Snackbar for operation failures
- Retry options for network issues

**Accessibility:**
- All items: proper labels
- Toggles: state announced
- Minimum 48dp touch targets
- Clear focus indicators
- Screen reader support
- Settings grouped logically
- Keyboard navigation (if supported)

**Animations:**
- Smooth scrolling
- Toggle switches: slide animation
- Page transitions: shared element
- Dialog entry: scale + fade
- Bottom sheet: slide up

**Special Screens (from Settings):**

**Profile Edit:**
- Full screen
- Fields: name, email, phone, profile picture
- Save button (fixed top-right)

**Curriculum Manager:**
- List of available curricula
- Add/remove with smooth animation
- Reorder by drag handle

**Goal Configuration:**
- Goal type selection
- Number pickers
- Date pickers
- Preview calculation
- Save button

**Theme Preview:**
- Live preview of theme change
- Switch between light/dark
- See example cards in chosen theme

**Color Picker:**
- Color swatches grid
- Selected: border indicator
- Preview: shows UI elements in chosen color
