# Story 15.2 — Profile Picker & Management UI (DNI-110)

## Story Overview

**As a** parent or adult user with multiple learner profiles,
**I want** a profile picker on launch and a management screen for learner profiles,
**So that** each learner sees a personalized experience ("Moshe's Dashboard") and I can manage all learners from one device.

**Depends on:** Story 15.1 (DNI-109) — Multi-Profile Data Model (must provide `LearnerProfiles` table, `LearnerProfileDao`, `ActiveProfileService`, and `activeProfileProvider`).

**Epic:** 15 — Multi-Profile Support

---

## Acceptance Criteria

- [ ] **AC1:** When the app launches with 2+ learner profiles, the Profile Picker screen is shown before the dashboard.
- [ ] **AC2:** When only 1 learner profile exists, the picker is skipped and the app navigates directly to the dashboard.
- [ ] **AC3:** When 0 profiles exist (fresh install / post-onboarding), the app creates a default profile from the Firebase user and proceeds to the dashboard.
- [ ] **AC4:** The Profile Picker displays a "Who's learning today?" header and a grid of profile cards showing name and avatar/icon.
- [ ] **AC5:** Tapping a profile card selects that profile as active and navigates to the dashboard.
- [ ] **AC6:** The dashboard AppBar displays the active learner's name (e.g., "Moshe's Dashboard").
- [ ] **AC7:** Tapping the profile avatar/name in the dashboard AppBar returns to the Profile Picker for quick-switching.
- [ ] **AC8:** The Manage Learners screen is accessible from parent mode and from adult mode settings.
- [ ] **AC9:** The Manage Learners screen lists all profiles with name, mode (child/adult), and curriculum count.
- [ ] **AC10:** A user can add a new learner profile with a name and mode selection.
- [ ] **AC11:** A user can edit a learner profile's name and avatar.
- [ ] **AC12:** A user can delete a learner profile with a confirmation dialog that warns about data loss.
- [ ] **AC13:** Deleting the last remaining profile is prevented (button disabled or hidden).
- [ ] **AC14:** After profile selection, all data queries (completions, bookmarks, streaks, points) are scoped to the active profile.

---

## Architecture & Design Notes

### Routing Changes

The app uses auto_route 11.x with `AppRouter` defined in `lib/core/navigation/app_router.dart`. The `AppShellRoute` wraps the bottom-nav tabs (Dashboard, Learn, Progress, Settings) and is guarded by `AuthGuard` and `RestoreGuard`.

**New routes to add:**

| Route | Path | Page | Guards | Notes |
|-------|------|------|--------|-------|
| `ProfilePickerRoute` | `/profile-picker` | `ProfilePickerScreen` | `[authGuard]` | Shown after auth, before app shell |
| `ManageLearnersRoute` | `/manage-learners` | `ManageLearnersScreen` | `[authGuard]` | Accessed from settings or parent mode |
| `AddLearnerRoute` | `/manage-learners/add` | `AddLearnerScreen` | `[authGuard]` | Modal-style or full screen |
| `EditLearnerRoute` | `/manage-learners/edit/:profileId` | `EditLearnerScreen` | `[authGuard]` | Takes profile ID param |

**New guard to add:**

`ProfileGuard` — inserted before the `AppShellRoute`. On navigation:
1. Reads all learner profiles from the database.
2. If 0 profiles exist: creates a default profile from the Firebase user, sets it active, and continues.
3. If 1 profile exists: sets it active (if not already) and continues.
4. If 2+ profiles exist and no profile is currently active: redirects to `ProfilePickerRoute`.
5. If 2+ profiles exist and one is active: continues.

This guard replaces direct entry to the app shell and must run after `AuthGuard` and `RestoreGuard`.

### Widget Tree

```
MaterialApp.router
  └─ AppRouter
       ├─ /sign-in → SignInScreen
       ├─ /welcome → WelcomeScreen
       ├─ /profile-picker → ProfilePickerScreen (NEW)
       ├─ / → AppShellRoute [authGuard, restoreGuard, profileGuard]
       │    ├─ dashboard → DashboardScreen (MODIFIED — personalized AppBar)
       │    ├─ learn → LearningScreen
       │    ├─ progress → ProgressScreen
       │    └─ settings → SettingsScreen (MODIFIED — "Manage Learners" link)
       ├─ /manage-learners → ManageLearnersScreen (NEW)
       ├─ /manage-learners/add → AddLearnerScreen (NEW)
       ├─ /manage-learners/edit/:profileId → EditLearnerScreen (NEW)
       ├─ /parent-mode → ParentModeScreen (MODIFIED — "Manage Learners" action)
       └─ ... (existing routes)
```

### State Management

All new state uses Riverpod with `@riverpod` code-gen annotations, consistent with `dashboard_providers.dart` and `onboarding_providers.dart`.

**Key providers (from DNI-109 data layer, consumed here):**

- `activeProfileProvider` — `StateNotifier<LearnerProfile?>` or equivalent; holds the currently selected learner profile. Set by profile picker or auto-selection logic.
- `allLearnerProfilesProvider` — `FutureProvider<List<LearnerProfile>>` or `StreamProvider` watching the learner_profiles table.
- `learnerProfileCountProvider` — derived from `allLearnerProfilesProvider`.

**New providers (this story):**

- `profilePickerStateProvider` — manages picker UI state (loading, error, profiles list).
- `manageLearnersProvider` — manages CRUD operations for the manage screen.

### Data Flow for Active Profile

Once a profile is selected, the `activeProfileProvider` emits the selected `LearnerProfile`. Downstream providers that currently read `profiles.first` (e.g., `dashboardUserModeProvider`, `ChildModeGuard`) must be updated to read from `activeProfileProvider` instead. This is a cross-cutting concern that affects:

- `lib/features/dashboard/presentation/providers/dashboard_providers.dart` — `dashboardUserModeProvider`
- `lib/core/navigation/guards/child_mode_guard.dart` — reads `profiles.first`
- Any provider that calls `db.userProfileDao.getAllUserProfiles()` and picks `.first`

---

## Screen Specifications

### Profile Picker Screen

**Layout:**
- Full-screen, no bottom navigation bar
- AppBar with app logo/title, no back button
- Header text: "Who's learning today?" (using `headlineSmall` from `AppTextStyles`)
- Responsive grid of profile cards: 2 columns on phone, 3 on tablet
- Each card: circular avatar (colored icon with initial letter), name below, subtle border
- Bottom action: "Manage Learners" text button (navigates to Manage Learners screen)

**Avatar system:**
- Default: colored `CircleAvatar` with first letter of name
- Color derived from profile index using a predefined palette (similar to curriculum colors in `AppTheme`)
- Future: allow custom avatar selection (out of scope for this story; use icon placeholder)

**Behavior:**
- On tap: set active profile via `activeProfileProvider`, then `context.router.replace(AppShellRoute())`
- Loading state while profiles load from DB
- Error state with retry button

### Manage Learners Screen

**Layout:**
- Standard Scaffold with AppBar: "Manage Learners"
- `ListView` of learner cards
- Each card shows:
  - Avatar (same as picker)
  - Name (bold)
  - Mode badge: "Child" or "Adult" chip
  - Curriculum count: "3 curricula" subtitle
  - Edit icon button (trailing)
- FAB or "Add Learner" button at bottom

**Add Learner flow:**
- Name text field (required, 1-30 chars)
- Mode selection: child/adult radio or segmented button (reuse `_ModeCard` pattern from `ModeSelectionScreen`)
- "Create" button — inserts into DB, returns to list

**Edit Learner flow:**
- Pre-filled name field
- Avatar selection (future — placeholder for now)
- "Save" button

**Delete Learner flow:**
- Triggered via long-press or edit screen's delete action
- `AlertDialog` with warning: "Delete [Name]? All learning data for this profile will be permanently lost. This cannot be undone."
- Two actions: "Cancel" (dismiss) and "Delete" (red, destructive)
- Cannot delete the last remaining profile — disable/hide delete option

### Dashboard Screen Modifications

**AppBar changes:**
- Replace `const Text('Dashboard')` with dynamic title: `Text("${activeProfile.displayName}'s Dashboard")`
- Add leading `GestureDetector` wrapping a `CircleAvatar` with the learner's initial
- Tapping the avatar calls `context.router.push(ProfilePickerRoute())` (or clears active profile and redirects)

---

## Implementation Steps

### Step 1: Create Profile Guard

**File:** `lib/core/navigation/guards/profile_guard.dart`

Create `ProfileGuard extends AutoRouteGuard` that:
- Takes `AppDatabase` and a reference to `ActiveProfileService` (from DNI-109)
- Implements the 0/1/2+ profile logic described above
- Redirects to `ProfilePickerRoute` when selection is needed

### Step 2: Create Profile Picker Screen

**Files:**
- `lib/features/profile/presentation/screens/profile_picker_screen.dart`
- `lib/features/profile/presentation/widgets/profile_card.dart`
- `lib/features/profile/presentation/widgets/profile_avatar.dart`
- `lib/features/profile/presentation/providers/profile_providers.dart`
- `lib/features/profile/presentation/providers/profile_providers.g.dart` (generated)

The `ProfilePickerScreen` is a `@RoutePage()` `ConsumerWidget` that:
- Watches `allLearnerProfilesProvider`
- Renders a `GridView.builder` with `ProfileCard` widgets
- On card tap: calls `ref.read(activeProfileProvider.notifier).setActive(profile)` then navigates

The `ProfileCard` widget:
- `Card` with `InkWell`
- `ProfileAvatar` (circular, initial letter, color from palette)
- `Text` name below avatar
- Selected state highlight if profile matches current active

The `ProfileAvatar` widget (reusable):
- `CircleAvatar` with `radius` parameter
- Background color from a profile-color palette
- Child: first letter of `displayName`, white, bold

### Step 3: Create Manage Learners Screen

**Files:**
- `lib/features/profile/presentation/screens/manage_learners_screen.dart`
- `lib/features/profile/presentation/screens/add_learner_screen.dart`
- `lib/features/profile/presentation/screens/edit_learner_screen.dart`
- `lib/features/profile/presentation/widgets/learner_list_tile.dart`
- `lib/features/profile/presentation/widgets/delete_learner_dialog.dart`

`ManageLearnersScreen`:
- `@RoutePage()` `ConsumerWidget`
- Watches `allLearnerProfilesProvider`
- `ListView.builder` with `LearnerListTile` widgets
- FAB: `FloatingActionButton.extended(label: Text('Add Learner'), icon: Icon(Icons.add))`
- FAB navigates to `AddLearnerRoute`

`AddLearnerScreen`:
- `@RoutePage()` `ConsumerStatefulWidget`
- `Form` with name `TextFormField` (validator: non-empty, max 30 chars)
- Mode selection using segmented button or radio tiles
- "Create" `FilledButton` — calls service to insert, then `context.router.maybePop()`

`EditLearnerScreen`:
- `@RoutePage()` `ConsumerStatefulWidget`
- Takes `@pathParam int profileId`
- Pre-fills form from loaded profile
- "Save" and "Delete" actions
- Delete triggers `DeleteLearnerDialog`

### Step 4: Update Router Configuration

**File:** `lib/core/navigation/app_router.dart`

Add imports for new screens and add routes:

```dart
// New route: profile picker
AutoRoute(path: '/profile-picker', page: ProfilePickerRoute.page, guards: [authGuard]),

// New routes: manage learners
AutoRoute(path: '/manage-learners', page: ManageLearnersRoute.page, guards: [authGuard]),
AutoRoute(path: '/manage-learners/add', page: AddLearnerRoute.page, guards: [authGuard]),
AutoRoute(path: '/manage-learners/edit/:profileId', page: EditLearnerRoute.page, guards: [authGuard]),
```

Add `ProfileGuard` to the `AppShellRoute`:
```dart
AutoRoute(
  path: '/',
  page: AppShellRoute.page,
  guards: [authGuard, restoreGuard, profileGuard],
  children: [ ... ],
),
```

Update `AppRouter` constructor to accept `ProfileGuard`.

### Step 5: Update Router Provider

**File:** `lib/core/navigation/router_provider.dart`

Instantiate `ProfileGuard` with the database and active-profile service, pass it to `AppRouter`.

### Step 6: Modify Dashboard Screen

**File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

- Watch `activeProfileProvider` to get the current learner name
- Change AppBar title from `const Text('Dashboard')` to dynamic `Text("${profile.displayName}'s Dashboard")`
- Add leading avatar widget that navigates to profile picker on tap:

```dart
appBar: AppBar(
  title: Text("${activeProfile?.displayName ?? ''}'s Dashboard"),
  leading: GestureDetector(
    onTap: () => context.router.push(const ProfilePickerRoute()),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: ProfileAvatar(name: activeProfile?.displayName ?? '', radius: 18),
    ),
  ),
),
```

### Step 7: Modify Settings Screen

**File:** `lib/features/settings/presentation/screens/settings_screen.dart`

Add a "Manage Learners" `ListTile` in the "More Settings" section:

```dart
ListTile(
  leading: const Icon(Icons.people_outlined),
  title: const Text('Manage Learners'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.pushRoute(const ManageLearnersRoute()),
),
```

### Step 8: Modify Parent Mode Screen

**File:** `lib/features/parent_mode/presentation/screens/parent_mode_screen.dart`

Add a "Manage Learners" action button to the AppBar:

```dart
IconButton(
  icon: const Icon(Icons.people),
  tooltip: 'Manage Learners',
  onPressed: () => context.router.push(const ManageLearnersRoute()),
),
```

### Step 9: Run Code Generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

This regenerates `app_router.gr.dart` (new route classes) and any `*.g.dart` files for new Riverpod providers.

### Step 10: Write Tests

See Test Plan below.

---

## Dev Notes

### UX Considerations

- **Name possessive:** Use `"${name}'s Dashboard"` for English. For names ending in 's', this still reads naturally ("James's Dashboard"). A future i18n pass could handle this with ICU message format.
- **Profile colors:** Define a palette of 6-8 distinct, accessible colors in `AppTheme` for profile avatars. Assign based on `profileId % paletteLength` for consistency.
- **Animation:** Consider a subtle scale animation on the profile card tap for tactile feedback. `AnimatedScale` or `InkWell` splash is sufficient.
- **Empty state:** The Manage Learners screen should never be truly empty (at least 1 profile always exists), but show a helpful message if it somehow occurs.

### Edge Cases

1. **Concurrent profile deletion:** If a profile is deleted on another device via sync, and it was the active profile, the `activeProfileProvider` should detect the missing profile and redirect to the picker (or auto-select the remaining one).
2. **Profile name uniqueness:** Not strictly required, but the Add Learner form should warn if a duplicate name is entered (confusing in the picker).
3. **Active profile invalidation:** When the active profile is edited (name change), the dashboard AppBar title should update reactively via the provider.
4. **Deep linking:** If a user deep-links to `/dashboard` without an active profile, the `ProfileGuard` should intercept and redirect to the picker.
5. **Onboarding flow:** After onboarding completes (mode selection + curriculum setup), a default learner profile should be created automatically using the Firebase user's display name. This ties into the `ProfileGuard`'s "0 profiles" logic.

### Dependencies on DNI-109

This story assumes DNI-109 provides:
- A `learner_profiles` Drift table (separate from the existing `user_profiles` which stores Firebase auth info)
- `LearnerProfileDao` with CRUD operations
- `ActiveProfileService` to get/set the active profile (persisted in shared_preferences or DB)
- `activeProfileProvider` (Riverpod) — the reactive source of truth for the selected profile
- `allLearnerProfilesProvider` — watches the learner_profiles table

If DNI-109 instead extends the existing `UserProfiles` table with a multi-row model (one row per learner under the same Firebase UID), the DAO calls in this story should adapt accordingly.

---

## Test Plan

### Widget Tests

| Test | File | What it verifies |
|------|------|-----------------|
| Profile picker shows all profiles | `test/features/profile/presentation/screens/profile_picker_screen_test.dart` | Grid renders N profile cards for N profiles |
| Profile picker navigates on tap | same | Tapping a card calls `setActive` and navigates to AppShellRoute |
| Profile picker shows header | same | "Who's learning today?" text is present |
| Manage Learners lists profiles | `test/features/profile/presentation/screens/manage_learners_screen_test.dart` | ListView renders all profiles with name, mode, curriculum count |
| Add Learner validates name | `test/features/profile/presentation/screens/add_learner_screen_test.dart` | Empty name shows error; 31-char name shows error |
| Add Learner creates profile | same | Valid submission calls DAO insert and pops |
| Edit Learner pre-fills data | `test/features/profile/presentation/screens/edit_learner_screen_test.dart` | Name field shows existing name |
| Delete Learner shows warning | same | Confirmation dialog appears with data loss warning |
| Delete Learner blocked for last profile | same | Delete button disabled when only 1 profile exists |
| Dashboard shows active profile name | `test/features/dashboard/presentation/screens/dashboard_screen_test.dart` | AppBar title matches active profile's display name |
| ProfileAvatar renders initial | `test/features/profile/presentation/widgets/profile_avatar_test.dart` | CircleAvatar shows first letter of name |

### Guard Tests

| Test | File | What it verifies |
|------|------|-----------------|
| ProfileGuard continues with 1 profile | `test/core/navigation/guards/profile_guard_test.dart` | `resolver.next()` called, no redirect |
| ProfileGuard redirects with 2+ profiles, none active | same | Redirects to `ProfilePickerRoute` |
| ProfileGuard continues with 2+ profiles, one active | same | `resolver.next()` called |
| ProfileGuard creates default for 0 profiles | same | Inserts profile from Firebase user, then continues |

### Story Acceptance Tests

**File:** `test/story_acceptance/epic_15_multi_profile_test.dart`

Tests tagged `@Tags(['epic_15'])` with group `tags: ['story_15_2']`:

1. Profile picker shown when multiple profiles exist
2. Profile picker skipped for single profile
3. Manage Learners CRUD operations (add, edit, delete)
4. Dashboard title reflects active profile name
5. Profile switch returns to picker

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/core/navigation/guards/profile_guard.dart` | Route guard for profile selection |
| `lib/features/profile/presentation/screens/profile_picker_screen.dart` | Profile selection on launch |
| `lib/features/profile/presentation/screens/manage_learners_screen.dart` | List/manage all profiles |
| `lib/features/profile/presentation/screens/add_learner_screen.dart` | Add new learner form |
| `lib/features/profile/presentation/screens/edit_learner_screen.dart` | Edit existing learner |
| `lib/features/profile/presentation/widgets/profile_card.dart` | Card widget for picker grid |
| `lib/features/profile/presentation/widgets/profile_avatar.dart` | Reusable circular avatar |
| `lib/features/profile/presentation/widgets/learner_list_tile.dart` | List tile for manage screen |
| `lib/features/profile/presentation/widgets/delete_learner_dialog.dart` | Confirmation dialog |
| `lib/features/profile/presentation/providers/profile_providers.dart` | Riverpod providers for profile UI |
| `test/core/navigation/guards/profile_guard_test.dart` | Guard unit tests |
| `test/features/profile/presentation/screens/profile_picker_screen_test.dart` | Picker widget tests |
| `test/features/profile/presentation/screens/manage_learners_screen_test.dart` | Manage screen widget tests |
| `test/features/profile/presentation/screens/add_learner_screen_test.dart` | Add form widget tests |
| `test/features/profile/presentation/screens/edit_learner_screen_test.dart` | Edit/delete widget tests |
| `test/features/profile/presentation/widgets/profile_avatar_test.dart` | Avatar widget tests |
| `test/story_acceptance/epic_15_multi_profile_test.dart` | Story acceptance tests |

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/navigation/app_router.dart` | Add `ProfileGuard` field, add 4 new routes, add guard to `AppShellRoute` |
| `lib/core/navigation/router_provider.dart` | Instantiate `ProfileGuard`, pass to `AppRouter` |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Personalized AppBar with active profile name + avatar tap-to-switch |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Add "Manage Learners" ListTile |
| `lib/features/parent_mode/presentation/screens/parent_mode_screen.dart` | Add "Manage Learners" action in AppBar |
| `lib/core/navigation/guards/child_mode_guard.dart` | Read from active profile instead of `profiles.first` |
| `lib/features/dashboard/presentation/providers/dashboard_providers.dart` | `dashboardUserModeProvider` reads from active profile |
| `lib/core/theme/app_theme.dart` | Add profile avatar color palette |
