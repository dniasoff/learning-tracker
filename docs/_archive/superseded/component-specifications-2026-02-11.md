---
project_name: "Learning Tracker"
document_type: "Component Specifications"
author: "Daniel"
date: "2026-02-08"
version: "1.0"
related_docs:
  - "ux-design-specification.md"
  - "ux-patterns-quick-reference.md"
  - "architecture.md"
---

# Learning Tracker - Component Specifications

**Purpose:** Detailed specifications for all UI components with Flutter implementation guidance. Combines Material Design 3 foundation with Learning Tracker-specific requirements.

**Target Platform:** Android mobile (Flutter 3.38.6, Material Design 3)

---

## Table of Contents

1. [Design Tokens](#design-tokens)
2. [Base Components](#base-components)
3. [Learning Tracker Specific Components](#learning-tracker-specific-components)
4. [Feature Module Component Mapping](#feature-module-component-mapping)
5. [Implementation Guidelines](#implementation-guidelines)

---

## Design Tokens

### Color System

**Curriculum Identity Colors** (immutable, never overridden by Dynamic Color):

```dart
enum CurriculumColor {
  mishnayos(
    light: Color(0xFFFF8F00),  // Amber
    dark: Color(0xFFFFD54F),
    name: 'Amber',
    feel: 'Traditional, foundational'
  ),
  bavli(
    light: Color(0xFF1565C0),  // Blue
    dark: Color(0xFF42A5F5),
    name: 'Blue',
    feel: 'Depth, scholarship'
  ),
  yerushalmi(
    light: Color(0xFF0097A7),  // Cyan
    dark: Color(0xFF4DD0E1),
    name: 'Cyan',
    feel: 'Distinctive, exploratory'
  ),
  mishnaBerurah(
    light: Color(0xFFAD1457),  // Burgundy
    dark: Color(0xFFF06292),
    name: 'Burgundy',
    feel: 'Precision, halachic gravity'
  ),
  chumash(
    light: Color(0xFF2E7D32),  // Green
    dark: Color(0xFF66BB6A),
    name: 'Green',
    feel: 'Living, growing'
  );
}
```

**Semantic Colors** (Material 3 roles):

```dart
class AppColors {
  // Success (completions, ahead of pace)
  static const success = Color(0xFF2E7D32);  // Light
  static const successDark = Color(0xFF66BB6A);

  // Warning (on pace, attention needed)
  static const warning = Color(0xFFF57F17);
  static const warningDark = Color(0xFFFFD54F);

  // Error (behind pace, failures)
  static const error = Color(0xFFC62828);
  static const errorDark = Color(0xFFEF5350);

  // Surface (cards, sheets)
  static const surface = Color(0xFFFFFBFE);
  static const surfaceDark = Color(0xFF1C1B1F);
}
```

**Mode Overlays**:

```dart
class ModeOverlay {
  // Child mode: warmer surfaces (+4% primary tint)
  static const childWarmth = 0.04;

  // Adult mode: neutral (no overlay)
  static const adultWarmth = 0.0;

  // Parent mode: subtle blue-grey tint
  static const parentTint = Color(0xFF607D8B);
}
```

### Typography

**Font Family:** Noto Sans Hebrew (for Hebrew) + Noto Sans (for Latin)

```dart
class AppTextStyles {
  // Headlines
  static const headlineLarge = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.25,  // 40/32 = 1.25
  );

  static const headlineMedium = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.29,  // 36/28
  );

  // Titles
  static const titleLarge = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.27,  // 28/22
  );

  static const titleMedium = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,  // 24/16
  );

  // Body
  static const bodyLarge = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,  // 20/14
  );

  // Labels
  static const labelLarge = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
  );

  static const labelSmall = TextStyle(
    fontFamily: 'Noto Sans Hebrew',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.45,  // 16/11
  );
}
```

**Font Weight Adaptive Rule:**
```dart
// Weight 500 for rendered size ≤ 14sp
// At system font scale 150%+, labelSmall reverts to w400
FontWeight adaptiveWeight(double baseSize, double renderScale) {
  final rendered = baseSize * renderScale;
  return rendered <= 14 ? FontWeight.w500 : FontWeight.w400;
}
```

### Spacing & Layout

**Base unit:** 4dp

```dart
class AppSpacing {
  static const xs = 4.0;   // Icon-to-label, inline gaps
  static const sm = 8.0;   // Intra-component padding
  static const md = 16.0;  // Card padding, list item height
  static const lg = 24.0;  // Section gaps
  static const xl = 32.0;  // Screen-level margins (phone)

  static const bottomNavHeight = 80.0;  // Bottom navigation bar
}
```

**Border Widths:**

```dart
class AppBorders {
  static double curriculumBorder(bool isDark) {
    return isDark ? 6.0 : 4.0;  // Increased in dark mode for contrast
  }
}
```

**Elevation:**

```dart
class AppElevation {
  static const level1 = 1.0;   // Task cards, list tiles
  static const level2 = 3.0;   // Bottom nav, app bar
  static const level3 = 6.0;   // Bottom sheets, snackbars
  static const level4 = 8.0;   // Dialogs, pickers
  static const level5 = 12.0;  // Celebration overlays, confetti
}
```

**Responsive Breakpoints:**

```dart
class AppBreakpoints {
  static const phone = 600.0;

  static double screenMargin(double width) {
    return width < phone ? 16.0 : 24.0;
  }

  static double maxCardWidth(double width) {
    return width < phone ? width - 32.0 : 480.0;
  }
}
```

### Illustration Guidelines

**Cultural Standards:**
- All character illustrations must depict boys or men (Orthodox Jewish cultural sensitivity)
- Use provided character styles as reference (see design assets)
- Character features: kippah, payos, appropriate clothing (vest, white shirt, black pants)
- Age-appropriate representation: boys (10-13) for child mode illustrations, adult men for general use

---

## Base Components

### 1. Primary Button

**Purpose:** Main call-to-action button for critical actions (mark complete, save, confirm)

**Variants:**
- Child mode: Rounded (16px), gradient background, large text (18sp), haptic feedback
- Adult mode: Rounded (8px), solid color, medium text (16sp), minimal feedback

**States:**
- Default
- Pressed (scale 0.97, shadow reduced)
- Disabled (50% opacity)
- Loading (spinner replaces text)

**Props:**
```dart
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final UserMode mode;  // child | adult

  // ...
}
```

**Implementation:**
```dart
ElevatedButton(
  style: ButtonStyle(
    shape: MaterialStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          mode == UserMode.child ? 16.0 : 8.0
        ),
      ),
    ),
    textStyle: MaterialStateProperty.all(
      TextStyle(
        fontSize: mode == UserMode.child ? 18.0 : 16.0,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  onPressed: isLoading ? null : () {
    if (mode == UserMode.child) {
      HapticFeedback.lightImpact();
    }
    onPressed?.call();
  },
  child: isLoading
    ? CircularProgressIndicator(color: Colors.white)
    : Text(text),
)
```

### 2. Card Component

**Purpose:** Container for content sections (curriculum cards, task cards, stat cards)

**Specs:**
- Material 3 elevated card (elevation 1)
- 16px padding
- 12px corner radius
- Ripple effect on tap
- Optional swipe actions

**Props:**
```dart
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<SwipeAction>? swipeActions;
  final Color? borderColor;  // For curriculum-colored borders
  final double? borderWidth;

  // ...
}
```

**Curriculum-Colored Card:**
```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(
      color: curriculumColor,
      width: isDark ? 6.0 : 4.0,
    ),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Card(
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: child,
    ),
  ),
)
```

### 3. Progress Bar

**Purpose:** Visual progress indication (completion percentage, reward progress, etc.)

**Specs:**
- Height: 8px
- Corner radius: 4px
- Animated fill (300ms ease-out)
- Curriculum-colored fill

**Props:**
```dart
class AppProgressBar extends StatelessWidget {
  final double value;  // 0.0 to 1.0
  final Color? color;  // Curriculum color or semantic color
  final double height;
  final bool animate;

  // ...
}
```

**Implementation:**
```dart
AnimatedContainer(
  duration: Duration(milliseconds: animate ? 300 : 0),
  curve: Curves.easeOut,
  height: height,
  decoration: BoxDecoration(
    color: color?.withOpacity(0.2),
    borderRadius: BorderRadius.circular(height / 2),
  ),
  child: FractionallySizedBox(
    widthFactor: value,
    alignment: Alignment.centerLeft,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    ),
  ),
)
```

### 4. Bottom Sheet

**Purpose:** Modal overlays for filters, quick actions, confirmations

**Specs:**
- Drag handle at top (40px tall, gray bar)
- Backdrop dim: 40% black overlay
- Swipe down to dismiss
- Padding: 16px horizontal, 24px vertical

**Props:**
```dart
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool isDismissible;

  // ...
}
```

**Usage:**
```dart
showModalBottomSheet(
  context: context,
  isDismissible: true,
  backgroundColor: Colors.transparent,
  builder: (context) => AppBottomSheet(
    title: 'Filter Tasks',
    child: FilterOptions(),
  ),
);
```

### 5. PIN Keypad

**Purpose:** 4-digit numeric PIN entry for parent/tutor modes

**Specs:**
- 4-digit display with dots (● ● ○ ○)
- Numeric keypad (1-9, 0, backspace, confirm)
- Shake animation on incorrect PIN
- Lock-out after 5 failed attempts (30-min cooldown)

**Props:**
```dart
class PinKeypad extends StatefulWidget {
  final Function(String) onComplete;
  final PinMode mode;  // parent | tutor

  // ...
}
```

**Layout:**
```
┌──────────────────────┐
│  Enter Parent PIN    │
│  ┌───┬───┬───┬───┐   │
│  │ ● │ ● │ ○ │ ○ │   │
│  └───┴───┴───┴───┘   │
│                      │
│  [1] [2] [3]         │
│  [4] [5] [6]         │
│  [7] [8] [9]         │
│  [←] [0] [✓]         │
└──────────────────────┘
```

### 6. Date Picker (Dual Calendar)

**Purpose:** Select dates using Gregorian or Hebrew calendar

**Specs:**
- Tab switch between calendars
- Both dates displayed simultaneously (synced via kosher_dart)
- Common presets available

**Props:**
```dart
class DualDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  final Function(DateTime) onDateSelected;
  final List<DatePreset>? presets;  // "Bar Mitzvah", "Next Pesach", etc.

  // ...
}
```

**Layout:**
```
┌─────────────────────────────┐
│ Set Goal Date               │
│ ┌──────────┬──────────────┐ │
│ │ Gregorian│ Hebrew       │ │
│ └──────────┴──────────────┘ │
│                             │
│ 📅 March 15, 2027           │
│ 🕍 15 Adar II 5787          │
│                             │
│ [Cancel]          [Confirm] │
└─────────────────────────────┘
```

---

## Learning Tracker Specific Components

### 7. Curriculum Summary Card

**Purpose:** Dashboard card showing per-curriculum progress overview

**Location:** `lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart`

**Specs:**
```
┌───────────────────────────────┐
│ 📖 Mishnayos                  │  ← Curriculum icon + name
│ ━━━━━━━━━━━━━━━━━━━ 45%      │  ← Progress bar (amber colored)
│ 1,890 / 4,192 items           │  ← Completed / Total
│ 🎯 On pace · 23 days ahead    │  ← Pace indicator (color-coded)
│ Next: Berachos 3:1            │  ← Current bookmark
└───────────────────────────────┘
```

**Props:**
```dart
class CurriculumSummaryCard extends StatelessWidget {
  final CurriculumId curriculumId;
  final String curriculumName;
  final int completedItems;
  final int totalItems;
  final double progressPercent;
  final PaceStatus paceStatus;  // ahead | on-pace | behind
  final int daysDifference;     // ±N days
  final String nextBookmark;    // Hebrew text display

  // ...
}
```

**Pace Indicator Colors:**
- Ahead: Success green (`#2E7D32`)
- On pace: Warning amber (`#F57F17`)
- Behind: Error red (`#C62828`)

**Border:** Curriculum-colored, 4dp light / 6dp dark

### 8. Daily Task Card

**Purpose:** Individual task in daily task list (scheduled completions)

**Location:** `lib/features/scheduler/presentation/widgets/task_card.dart`

**Specs:**
```
┌─────────────────────────────────────┐
│ ■ Mishnayos · Berachos 3:1         │  ← Curriculum color dot + item
│   Chazara 1 · Personal             │  ← Stage + Track
│   +10 pts                           │  ← Points (child mode)
└─────────────────────────────────────┘
```

**Props:**
```dart
class DailyTaskCard extends StatelessWidget {
  final DailyTask task;
  final VoidCallback onTap;       // Mark complete
  final bool isCompleted;
  final UserMode mode;

  // ...
}
```

**States:**
- Default (white background, curriculum-colored border)
- Completed (green check, faded)
- Overdue (red accent)

**Interaction:**
- Single tap → Mark complete
- Completion triggers:
  - Instant state change (optimistic UI)
  - Points animation (child mode)
  - Streak update
  - Next task surfaces

### 9. Hebrew Text Display

**Purpose:** Properly formatted Hebrew text with RTL support

**Location:** `lib/core/widgets/hebrew_text.dart`

**Specs:**
- RTL text direction
- Noto Sans Hebrew font
- BiDi algorithm handling for mixed Hebrew/English
- Proper line breaking

**Props:**
```dart
class HebrewText extends StatelessWidget {
  final String text;           // Can contain Hebrew + English
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool forceLTR;        // For mixed content override

  // ...
}
```

**Implementation:**
```dart
Text(
  text,
  textDirection: forceLTR ? TextDirection.ltr : TextDirection.rtl,
  style: (style ?? AppTextStyles.bodyMedium).copyWith(
    fontFamily: 'Noto Sans Hebrew',
  ),
  textAlign: textAlign ?? TextAlign.right,  // RTL default
)
```

### 10. Streak Counter

**Purpose:** Display current and max streak with milestone indicators

**Location:** `lib/features/gamification/presentation/widgets/streak_counter.dart`

**Child Mode:**
```
┌──────────────────────┐
│   🔥 23-Day Streak   │
│   Best: 47 days      │
└──────────────────────┘
```

**Adult Mode:**
```
┌──────────────────────┐
│ Current: 23 days     │
│ Best: 47 days        │
└──────────────────────┘
```

**Props:**
```dart
class StreakCounter extends StatelessWidget {
  final int currentStreak;
  final int maxStreak;
  final UserMode mode;
  final bool showMilestone;  // Highlight at 7, 30, 100, 365

  // ...
}
```

**Milestone Triggers:**
- 7 days: "Week streak!" badge
- 30 days: "Month streak!" celebration (child mode)
- 100 days: "Century!" special animation
- 365 days (Jewish year): "Full year!" pinnacle achievement

### 11. Points Display & Animation

**Purpose:** Show points earned on completion (child mode)

**Location:** `lib/features/gamification/presentation/widgets/points_popup.dart`

**Child Mode Animation:**
```
┌──────────────────────┐
│       +10 pts        │  ← Scales in, bounces
│         ⭐           │  ← Star particle effect
│   Great work!        │  ← Encouraging message
└──────────────────────┘
```

**Specs:**
- Fade in + scale (300ms)
- Bounce effect (overshoot curve)
- Confetti particles (child mode only)
- Auto-dismiss after 2 seconds
- Optional haptic feedback

**Props:**
```dart
class PointsPopup extends StatefulWidget {
  final int points;
  final String message;
  final UserMode mode;

  // ...
}
```

**Adult Mode:** Subtle snackbar instead of modal overlay

### 12. Mystery Reward Progress Bar

**Purpose:** Show progress toward next mystery reward (child mode)

**Location:** `lib/features/parent_mode/presentation/widgets/reward_progress_bar.dart`

**Specs:**
```
┌─────────────────────────────────────┐
│ Mystery Reward                      │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 67%    │
│ 670 / 1,000 points                  │
└─────────────────────────────────────┘
```

**Props:**
```dart
class RewardProgressBar extends StatelessWidget {
  final int currentPoints;
  final int targetPoints;
  final String rewardTitle;  // "Mystery Reward" until revealed

  // ...
}
```

**Behavior:**
- Progress bar animates as points accumulate
- At 100%: Triggers reward notification
- Parent reveals reward title on unlock

### 13. Hierarchy Browser (Expandable Tree)

**Purpose:** Navigate curriculum content hierarchy (up to 4 levels deep)

**Location:** `lib/features/content_browsing/presentation/widgets/hierarchy_browser.dart`

**Specs:**
```
Mishnayos
├─ 📂 Seder Zeraim (834 items) ━━━━━━━━━ 30%
│  ├─ 📂 Berachos (453) ━━━━━━━━━━━ 100% ✓
│  └─ 📂 Peah (381) ━━━━━━ 12%
├─ 📂 Seder Moed (...)
└─ ...
```

**Props:**
```dart
class HierarchyBrowser extends StatefulWidget {
  final CurriculumId curriculumId;
  final List<ContentItem> items;
  final Function(ContentItem) onItemTap;

  // ...
}
```

**Behavior:**
- Tap container → Expand to show children
- Tap leaf item → Navigate to item detail
- Show checkmarks for 100% complete sections
- Show progress bars for partial completion
- Hebrew text with RTL layout

### 14. Completion History List

**Purpose:** Filterable list of past completions

**Location:** `lib/features/learning/presentation/widgets/completion_history_list.dart`

**Specs:**
```
Filter: [All Curricula ▼] [All Tracks ▼] [Last 30 Days ▼]

Today
  Mishnayos · Berachos 3:1 · Chazara 1 · Personal · 10 pts
  Bavli · Berachos 2a · Learn · School · 10 pts

Yesterday
  Mishnayos · Berachos 3:2 · Learn · Personal · 10 pts
```

**Props:**
```dart
class CompletionHistoryList extends StatelessWidget {
  final List<Completion> completions;
  final CurriculumFilter curriculumFilter;
  final TrackFilter trackFilter;
  final DateRangeFilter dateFilter;

  // ...
}
```

**Features:**
- Grouped by date (Today, Yesterday, [Hebrew Date])
- Each row: Curriculum · Item (Hebrew) · Stage · Track · Points
- Infinite scroll / pagination
- Filter chips at top

### 15. Drag-and-Drop Reorder List

**Purpose:** Customize learning order for curriculum content

**Location:** `lib/features/settings/presentation/widgets/reorder_list.dart`

**Specs:**
```
Learning Order: Seder Zeraim
┌─────────────────────────┐
│ ☰ Berachos              │
│ ☰ Peah                  │
│ ☰ Demai      ← dragging │
│ ☰ Kilayim               │
└─────────────────────────┘
```

**Props:**
```dart
class ReorderList extends StatefulWidget {
  final List<ContentItem> items;
  final Function(List<ContentItem>) onReorder;
  final VoidCallback onReset;  // Reset to default order

  // ...
}
```

**Behavior:**
- Long-press drag handle (☰) to initiate
- Item lifts with elevation increase
- Other items animate to show drop target
- Release to commit reorder
- "Reset to Default Order" button at top

### 16. Pace Status Indicator

**Purpose:** Visual indicator of pace vs goal deadline

**Location:** `lib/features/progress/presentation/widgets/pace_indicator.dart`

**Specs:**
```
🎯 23 days ahead        (Green)
🎯 On pace              (Amber)
🎯 5 days behind        (Red)
```

**Props:**
```dart
class PaceIndicator extends StatelessWidget {
  final PaceStatus status;  // ahead | on-pace | behind
  final int daysDifference;
  final DateTime projectedDate;  // Hebrew date primary
  final DateTime goalDate;

  // ...
}
```

**Color Coding:**
- Ahead: `AppColors.success` (green)
- On pace: `AppColors.warning` (amber)
- Behind: `AppColors.error` (red)

### 17. Sync Status Indicator

**Purpose:** Show sync status in bottom bar

**Location:** `lib/features/sync/presentation/widgets/sync_status.dart`

**States:**
```
[✓ Synced]         (Green)
[⟳ Syncing...]     (Blue spinner)
[⚠ Offline]        (Yellow)
[✗ Sync Error]     (Red)
```

**Props:**
```dart
class SyncStatus extends StatelessWidget {
  final SyncState state;  // synced | syncing | offline | error
  final DateTime? lastSyncTime;
  final String? errorMessage;

  // ...
}
```

**Behavior:**
- Tap on error → Show error details
- Auto-hide after 3s when synced
- Persistent when offline or error

---

## Feature Module Component Mapping

### Auth Module (`lib/features/auth/`)
- **Sign In Screen:**
  - Email input field
  - Password input field
  - Primary button ("Sign In")
  - Google Sign-In button
  - Error message display

### Onboarding Module (`lib/features/onboarding/`)
- **Mode Selection Screen:**
  - Large selection cards (Child / Adult)
  - Illustration (boy/man character)
  - Primary button ("Continue")

- **Curriculum Selection Screen:**
  - Checkbox list (5 curricula)
  - Curriculum cards with icons
  - Primary button ("Import Content")

- **Goal Setup Screen (per curriculum):**
  - Dual date picker (Gregorian/Hebrew)
  - Toggle: "No deadline" option
  - Primary button ("Continue")

- **Bulk Mark Screen:**
  - Hierarchy browser (multi-select)
  - Stage selector dropdown
  - Progress bar (during bulk write)
  - Primary button ("Mark Selected")

### Dashboard Module (`lib/features/dashboard/`)
- **Dashboard Screen:**
  - Curriculum summary cards (grid)
  - Streak counter
  - Sync status indicator
  - Bottom navigation

### Content Browsing Module (`lib/features/content_browsing/`)
- **Hierarchy Screen:**
  - Hierarchy browser widget
  - Breadcrumb navigation
  - Search bar
  - Hebrew text display

### Learning Module (`lib/features/learning/`)
- **Learning Screen:**
  - Daily task cards
  - Mark complete button
  - Points popup (child mode)
  - Completion animation

- **Completion History:**
  - Completion history list
  - Filter chips
  - Date group headers

### Scheduler Module (`lib/features/scheduler/`)
- **Daily Tasks Screen:**
  - Task card list
  - "All done" success state
  - Curriculum filter tabs

### Progress Module (`lib/features/progress/`)
- **Progress Screen:**
  - Progress charts (line, bar)
  - Hierarchy breakdown
  - Pace indicator
  - Date range selector

### Gamification Module (`lib/features/gamification/`)
- **Rewards Screen:**
  - Mystery reward progress bars
  - Points summary
  - Streak milestones list

### Parent Mode Module (`lib/features/parent_mode/`)
- **Parent Dashboard:**
  - PIN keypad (entry)
  - Analytics cards
  - Reward management list

- **Reward Management:**
  - CRUD form (create/edit reward)
  - Point threshold input
  - Primary/secondary buttons

### Tutor Mode Module (`lib/features/tutor_mode/`)
- **Tutor Dashboard:**
  - PIN keypad (entry)
  - Read-only completion history
  - Chazara queue list

### Settings Module (`lib/features/settings/`)
- **Settings Screen:**
  - List tiles with navigation
  - Toggle switches
  - User profile card

- **Stage Editor:**
  - Stage definition list
  - Add/Edit/Delete/Reorder stages
  - Delay days input

- **Learning Order Screen:**
  - Drag-and-drop reorder list
  - Reset button

---

## Implementation Guidelines

### Component Organization

Each component should live in the appropriate feature module's `presentation/widgets/` directory:

```
lib/features/{feature_name}/presentation/widgets/
  ├── {component_name}.dart
  └── README.md  (component documentation)
```

Shared base components live in:
```
lib/core/widgets/
  ├── app_card.dart
  ├── app_progress_bar.dart
  ├── primary_button.dart
  ├── hebrew_text.dart
  └── ...
```

### State Management

All components use **Riverpod** for state:

```dart
// Family provider for curriculum-scoped components
@riverpod
Future<List<ContentItem>> contentItems(Ref ref, String curriculumId) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getAllForCurriculum(curriculumId);
}

// In widget:
class CurriculumCard extends ConsumerWidget {
  final CurriculumId curriculumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(contentItemsProvider(curriculumId.storageKey));

    return itemsAsync.when(
      data: (items) => _buildCard(items),
      loading: () => SkeletonCard(),
      error: (err, stack) => ErrorCard(message: err.toString()),
    );
  }
}
```

### Mode-Based Rendering

Use simple conditionals for child/adult mode differences:

```dart
Widget build(BuildContext context) {
  final userMode = ref.watch(userModeProvider);

  if (userMode == UserMode.child) {
    return AnimatedCompletionFeedback(
      points: 10,
      message: 'Great work!',
      onComplete: () {},
    );
  } else {
    return SnackBar(
      content: Text('Item marked complete'),
      duration: Duration(seconds: 2),
    );
  }
}
```

### RTL / Hebrew Support

Always use `HebrewText` widget for Hebrew content:

```dart
HebrewText(
  'ברכות פרק ג משנה א',
  style: AppTextStyles.titleMedium,
  textAlign: TextAlign.right,
)
```

For mixed content (Hebrew + English), use `Directionality`:

```dart
Directionality(
  textDirection: TextDirection.rtl,
  child: Text('Berachos 3:1 · ברכות פרק ג משנה א'),
)
```

### Accessibility

Every interactive component must have:

1. **Semantic labels:**
```dart
Semantics(
  label: 'Mark Berachos 3:1 as complete',
  button: true,
  child: PrimaryButton(...),
)
```

2. **Minimum touch targets:** 48dp (child) or 56dp (adult)

3. **WCAG AA contrast:** All text meets 4.5:1 (body) or 3:1 (large)

4. **Reduced motion support:**
```dart
final disableAnimations = MediaQuery.disableAnimationsOf(context);

AnimatedContainer(
  duration: disableAnimations ? Duration.zero : Duration(milliseconds: 300),
  // ...
)
```

### Testing

Each component should have:

1. **Widget tests** (golden tests for visual regression):
```dart
testWidgets('CurriculumCard displays correctly', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: CurriculumSummaryCard(
          curriculumId: CurriculumId.mishnayos,
          completedItems: 1890,
          totalItems: 4192,
          // ...
        ),
      ),
    ),
  );

  expect(find.text('Mishnayos'), findsOneWidget);
  expect(find.text('1,890 / 4,192 items'), findsOneWidget);

  // Golden test
  await expectLater(
    find.byType(CurriculumSummaryCard),
    matchesGoldenFile('goldens/curriculum_card.png'),
  );
});
```

2. **Interaction tests:**
```dart
testWidgets('DailyTaskCard marks complete on tap', (tester) async {
  bool tapped = false;

  await tester.pumpWidget(
    MaterialApp(
      home: DailyTaskCard(
        task: mockTask,
        onTap: () => tapped = true,
      ),
    ),
  );

  await tester.tap(find.byType(DailyTaskCard));
  await tester.pump();

  expect(tapped, isTrue);
});
```

### Performance Considerations

1. **Use `const` constructors** where possible:
```dart
const HebrewText(
  'ברכות',
  style: AppTextStyles.titleMedium,
)
```

2. **Optimize list rendering** with `ListView.builder`:
```dart
ListView.builder(
  itemCount: tasks.length,
  itemBuilder: (context, index) => DailyTaskCard(task: tasks[index]),
)
```

3. **Cache complex widgets** with `AutomaticKeepAliveClientMixin` for tabs

4. **Lazy load images** and use `CachedNetworkImage` for Sefaria content

---

## Next Steps for Implementation

1. ✅ Design tokens defined
2. ✅ Base components specified
3. ✅ Learning Tracker components designed
4. ✅ Feature module mapping complete
5. ⏭️ **Begin implementation:**
   - Start with `lib/core/widgets/` base components
   - Implement design tokens in `lib/core/theme/`
   - Build feature-specific components per module
   - Write widget tests alongside implementation
   - Create golden test snapshots

---

**Related Documents:**
- [UX Design Specification](ux-design-specification.md) - Full design rationale
- [UX Patterns Quick Reference](ux-patterns-quick-reference.md) - Quick implementation patterns
- [Architecture Quick Reference](architecture-quick-reference.md) - Technical architecture
- [Architecture](architecture.md) - Full architectural decisions

**Questions?** Reference this document for all component implementation decisions.
