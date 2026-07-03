---
title: "UI Component & State Management Inventory"
description: "Technical reference for all screens, widgets, providers, navigation, and theming in the Learning Tracker application."
date: 2026-03-18
---

# UI Component & State Management Inventory

Technical reference for all screens, widgets, providers, and navigation in the Learning Tracker application.

---

## Table of Contents

- [State Management](#state-management)
  - [Core Providers](#core-providers-libcoreproviders)
  - [Provider Patterns](#provider-patterns)
- [Navigation](#navigation)
  - [Shell Structure](#shell-structure)
  - [Route Guards](#route-guards-7)
- [Screens (45)](#screens-45)
- [Reusable Widgets](#reusable-widgets)
  - [Core Widgets](#core-widgets-libcorewidgets)
  - [Feature Widgets](#feature-widgets-48)
- [Theme](#theme)
  - [Color Palette](#color-palette)
  - [Curriculum Colors](#curriculum-colors-9)
  - [Track-Type Colors](#track-type-colors)
  - [Typography](#typography)
  - [Theme Variants](#theme-variants)
- [How to Create a New Screen](#how-to-create-a-new-screen)
- [How to Create a New Provider](#how-to-create-a-new-provider)

---

## State Management

**Framework:** Riverpod 3.x (code-generated providers)

### Core Providers (`lib/core/providers/`)

| Provider | Lifecycle | Purpose |
|---|---|---|
| `appDatabaseProvider` | keepAlive | Drift database instance |
| `firebaseAuthProvider` | keepAlive | `FirebaseAuth.instance` |
| `firebaseFirestoreProvider` | keepAlive | `FirebaseFirestore.instance` |
| `firebaseStorageProvider` | keepAlive | `FirebaseStorage.instance` |
| `dioProvider` | autoDispose | HTTP client |
| `talkerProvider` | autoDispose | Logging |

### Provider Patterns

#### 1. Family Providers -- Per-Curriculum Scoping (P3)

Parameterized by curriculum ID for multi-curriculum isolation.

- `contentRepositoryProvider`
- `dailyTasksProvider`
- `paceStatusProvider`
- `trackBreakdownProvider`

#### 2. Stream Providers -- Reactive Database Watches

Live-updating streams backed by Drift reactive queries.

- `activeCurriculaStreamProvider`
- `profileListStreamProvider`
- `syncStatusProvider`
- `restoreStatusProvider`

#### 3. Future Providers -- Async Data Fetching

One-shot async loads, auto-disposed when listeners drop.

- `curriculumProgressProvider`
- `parentDashboardDataProvider`
- `tutorDashboardDataProvider`

#### 4. Notifier / Class Providers -- Mutable State

Stateful controllers exposing methods to modify state.

- `skippedTasksNotifier`
- `activeProfileIdProvider`
- `tutorModeProvider`
- `journeySortModeNotifier`

#### 5. KeepAlive Providers -- Long-Lived Singletons

Persist for the lifetime of the app process.

- Repositories
- Services
- Database

---

## Navigation

**Framework:** auto_route 11.x

### Shell Structure

`AppShell` provides a 4-tab bottom navigation bar:

| Tab | Destination |
|---|---|
| Dashboard | `DashboardScreen` |
| Learn | `LearningScreen` |
| Progress | `ProgressScreen` |
| Settings | `SettingsScreen` |

### Route Guards (7)

| Guard | Role |
|---|---|
| `AuthGuard` | Unified onboarding + multi-account gate. Routes to `AppIntroRoute` (intro not seen), `AccountPickerRoute` (accounts on device), or `WelcomeRoute` (first launch). Epic 23 collapsed the old Firebase-only `AuthGuard` and the short-lived `LocalAuthGuard` into this single guard. |
| `ProfileGuard` | Requires an active learner profile |
| `RestoreGuard` | Blocks navigation during device-restore flow |
| `ChildModeGuard` | Restricts access to screens not permitted inside child mode |
| `PinGuard` | Base class for PIN verification (used by the two below) |
| `ParentPinGuard` | PIN challenge for parent-mode screens |
| `TutorPinGuard` | PIN challenge for tutor-mode screens |

**Total routes:** 40+

---

## Screens (45)

### Auth (3)

| Screen | Notes |
|---|---|
| `SignInScreen` | Firebase authentication entry |
| `AccountCreationScreen` | New account registration |
| `WelcomeScreen` | First-launch landing |

### Content Browsing (4)

| Screen | Notes |
|---|---|
| `CurriculumListScreen` | All available curricula |
| `ContentHierarchyScreen` | Breadcrumb navigation with drill-down |
| `ContentSearchScreen` | Full-text search across content |
| `TextDisplayScreen` | Rendered content viewer |

### Dashboard (1)

| Screen | Notes |
|---|---|
| `DashboardScreen` | Cross-curriculum overview, streak, points, today's tasks |

### Gamification (1)

| Screen | Notes |
|---|---|
| `GamificationScreen` | Placeholder for future gamification features |

### Learning (2)

| Screen | Notes |
|---|---|
| `LearningScreen` | Top-level learn tab |
| `CurriculumLearningScreen` | Per-curriculum learning view |

### Learning Order (1)

| Screen | Notes |
|---|---|
| `LearningOrderScreen` | `ReorderableListView` drag-and-drop ordering |

### Notifications (1)

| Screen | Notes |
|---|---|
| `NotificationsScreen` | Toggle controls, time pickers, Shabbos mode |

### Onboarding (6)

| Screen | Notes |
|---|---|
| `WelcomeScreen` | Onboarding entry |
| `ModeSelectionScreen` | Choose learner/parent/tutor mode |
| `OnboardingScreen` | Guided setup flow |
| `BulkMarkScreen` | Bulk-mark prior completions |
| `LearningProcessWizardScreen` | Step-by-step learning config |
| `RewardsSetupScreen` | Initial rewards configuration |

### Parent Mode (7)

| Screen | Notes |
|---|---|
| `ParentModeScreen` | Analytics dashboard |
| `ParentTrackManagementScreen` | Manage child's tracks |
| `PinSetupScreen` | Create parent PIN |
| `PinChangeScreen` | Change parent PIN |
| `PinEntryScreen` | Enter parent PIN |
| `PointConfigScreen` | Configure point values |
| `RewardCatalogScreen` | Manage available rewards |

### Profiles (2)

| Screen | Notes |
|---|---|
| `ProfilePickerScreen` | Select active learner profile |
| `ManageLearnersScreen` | Add/edit/remove learner profiles |

### Progress (5)

| Screen | Notes |
|---|---|
| `ProgressScreen` | Top-level progress tab |
| `ProgressChartsScreen` | Visualization charts |
| `CurriculumProgressScreen` | Per-curriculum progress detail |
| `CompletionHistoryScreen` | Historical completion log |
| `LearningJourneyScreen` | Grouped/timeline views |

### Scheduler (2)

| Screen | Notes |
|---|---|
| `SchedulerScreen` | Daily task list |
| `GoalSetupScreen` | Configure daily/weekly goals |

### Settings (4)

| Screen | Notes |
|---|---|
| `SettingsScreen` | Top-level settings tab |
| `TrackManagementScreen` | Add/remove/reorder tracks |
| `CurriculumSettingsScreen` | Per-curriculum settings |
| `ScopeSelectionScreen` | Select content scope |

### Sync (2)

| Screen | Notes |
|---|---|
| `SyncScreen` | Cloud sync status and controls |
| `DeviceRestoreScreen` | Restore data to new device |

### Tutor Mode (5)

| Screen | Notes |
|---|---|
| `TutorModeScreen` | Tutor feature entry |
| `TutorDashboardScreen` | Tutor analytics dashboard |
| `TutorPINEntryScreen` | Enter tutor PIN |
| `TutorPINSetupScreen` | Create tutor PIN |
| `TutorPINChangeScreen` | Change tutor PIN |

---

## Reusable Widgets

### Core Widgets (`lib/core/widgets/`)

| Widget | Purpose |
|---|---|
| `AnimatedProgressBar` | Progress visualization with animation |
| `AppBarTitle` | Styled app bar title |
| `CurriculumIndicator` | Curriculum identification badge |
| `EmptyState` | No-data placeholder |
| `ErrorDisplay` | Error message display |
| `HebrewText` | RTL-aware Hebrew text rendering |
| `LoadingIndicator` | Loading spinner |
| `PinEntryWidget` | 4-digit PIN input with lockout |
| `TrackProgressBar` | Segmented per-track progress |
| `TrackSelectorChip` | Track selection chip |
| `CompletionButton` | Item completion with animations |

### Feature Widgets (48)

#### Content Browsing

- `BreadcrumbNavigation` -- Hierarchical path display
- `ContentItemTile` -- Content list item

#### Dashboard

- `CurriculumSummaryCard` -- Per-curriculum summary
- `PointsSummaryWidget` -- Aggregated points display
- `TodaysTasksWidget` -- Today's scheduled tasks

#### Gamification

- `StreakWidget` -- Current streak display
- `PointsDisplayWidget` -- Point total with formatting
- `RewardProgressWidget` -- Progress toward next reward
- `EarnedRewardsWidget` -- Earned rewards list

#### Learning

- `PointsPopup` -- Points-earned overlay
- `TrackSelectorBottomSheet` -- Track selection modal
- `BookmarkCard` -- Bookmarked item card
- `BulkCompletionDialog` -- Bulk completion confirmation

#### Learning Order

- `DraggableOrderItem` -- Drag handle list item
- `ResetOrderDialog` -- Reset order confirmation

#### Progress

- `CompletionsBarChart` -- Bar chart of completions
- `CumulativeLineChart` -- Cumulative progress line chart
- `PointsOverTimeChart` -- Points trend chart
- `StreakCalendar` -- Calendar heatmap of streaks
- `HierarchyProgressCard` -- Nested progress display
- `OverallStatsCard` -- Aggregate statistics card
- `PaceIndicator` -- On-pace / behind / ahead indicator

#### Scheduler

- `DailyTaskCard` -- Individual task card
- `PaceIndicatorWidget` -- Pace status badge

#### Parent Mode

- `KeyStatsRow` -- Key metrics horizontal row
- `EngagementCard` -- Engagement summary card
- `CurriculumCard` -- Curriculum overview card
- `RecentCompletionsList` -- Recent completions feed

#### Profiles

- `ProfileAvatar` -- Learner avatar display

---

## Theme

**Design System:** Material Design 3 (Material You)

### Color Palette

| Role | Color | Hex |
|---|---|---|
| Primary | Deep blue-purple | `#2E4057` |
| Secondary | Warm amber | `#F4A261` |
| Tertiary | Soft green | `#6B9080` |

### Curriculum Colors (9)

Each curriculum receives a distinct color for visual differentiation across cards, progress bars, and indicators. The `AppTheme.getCurriculumColor()` method maps `CurriculumId` enum values to these colors.

| Curriculum | Color Name | Hex |
|---|---|---|
| Mishnayos | Blue | `#4A90E2` |
| Bavli | Purple | `#8B4789` |
| Yerushalmi | Green | `#2ECC71` |
| Mishna Berurah | Orange | `#E67E22` |
| Mishneh Torah | Brown | `#8D6E63` |
| Chumash | Red | `#E74C3C` |
| Nach | Teal | `#1ABC9C` |
| Tanach | Deep Teal | `#0E9384` |
| Mussar | Violet | `#9B59B6` |

> **Note:** Nach and Tanach share the teal family; verify exact values in `lib/core/theme/` before copying into new widgets. **Mishneh Torah** (Maimonides' legal code) is a distinct curriculum — do not confuse with Chumash/Torah.

### Track-Type Colors

| Track Type | Color |
|---|---|
| Personal | Blue |
| School | Green |
| Tutor | Orange |

### Typography

Bidirectional text support with two font families:

| Script | Font |
|---|---|
| Latin (LTR) | Roboto |
| Hebrew (RTL) | Noto Sans Hebrew |

### Theme Variants

Light theme only in v1. No dark mode.

---

## How to Create a New Screen

Follow these steps to add a new screen to the application:

1. **Create the screen file.** Place it in the appropriate feature directory under `lib/features/<feature>/presentation/screens/`. Name the file using snake_case matching the screen class name (e.g., `my_new_screen.dart`).

2. **Define the screen widget.** Create a `ConsumerWidget` (or `ConsumerStatefulWidget` if local state is necessary). Wrap the body in a `SafeArea` widget to protect against device notches and system UI.

   ```dart
   @RoutePage()
   class MyNewScreen extends ConsumerWidget {
     const MyNewScreen({super.key});

     @override
     Widget build(BuildContext context, WidgetRef ref) {
       return Scaffold(
         appBar: AppBar(title: const AppBarTitle(text: 'My New Screen')),
         body: SafeArea(
           child: // ... screen content
         ),
       );
     }
   }
   ```

3. **Register the route.** Add an `AutoRoute` entry in the app's router configuration. Apply any necessary route guards (e.g., `AuthGuard`, `ProfileGuard`).

4. **Run code generation.** Execute `dart run build_runner build --delete-conflicting-outputs` to generate the route page mixin.

5. **Add navigation.** Wire up navigation from the calling screen using `context.router.push(MyNewRoute())`.

6. **Update this inventory.** Add the screen to the appropriate feature section in this document.

---

## How to Create a New Provider

Follow these steps to add a new Riverpod provider:

1. **Choose the provider type.** Select based on the data pattern:
   - **`@riverpod` function** -- for derived/computed values (auto-disposed by default).
   - **`@riverpod` class** -- for mutable state that exposes methods.
   - **`@Riverpod(keepAlive: true)`** -- for singletons like repositories and services.
   - **Family parameter** -- add a parameter to the function/class for per-curriculum or per-profile scoping.

2. **Create the provider file.** Place it in `lib/features/<feature>/presentation/providers/` for UI-layer providers, or `lib/core/providers/` for shared infrastructure providers. Use the `part` directive for code generation:

   ```dart
   part 'my_provider.g.dart';

   @riverpod
   Future<MyData> myData(Ref ref, String curriculumId) async {
     final repo = ref.watch(myRepositoryProvider);
     return repo.getData(curriculumId);
   }
   ```

3. **Run code generation.** Execute `dart run build_runner build --delete-conflicting-outputs` to generate the `.g.dart` file.

4. **Consume in widgets.** Use `ref.watch(myDataProvider(curriculumId))` in any `ConsumerWidget` to subscribe to the provider. Use `ref.read()` for one-shot access in callbacks.

5. **Handle async states.** For `FutureProvider` and `StreamProvider`, use `.when()` to handle loading, error, and data states in the widget tree:

   ```dart
   ref.watch(myDataProvider(curriculumId)).when(
     data: (data) => MyWidget(data: data),
     loading: () => const LoadingIndicator(),
     error: (err, stack) => ErrorDisplay(message: err.toString()),
   );
   ```

6. **Update this inventory.** Add the provider to the appropriate pattern section in this document.
