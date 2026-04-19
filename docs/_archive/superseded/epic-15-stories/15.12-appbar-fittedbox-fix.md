# Story 15.12 — UI Polish: AppBar FittedBox & Title Handling (DNI-120)

## Story Overview

Several screens in the app display dynamic text in the AppBar title that can exceed the available width, causing truncation with ellipsis. The primary offender is the Bulk Mark screen ("Mark Prior Completions — Mishnayos"), but any screen that interpolates a curriculum name or Sefaria reference into its title is affected.

The fix is twofold:
1. Introduce a shared `ScalingAppBarTitle` widget that wraps content in `FittedBox` with a minimum font size floor.
2. Apply it consistently across **all** screens that have an AppBar title.

---

## Acceptance Criteria

- [ ] All AppBar titles auto-scale to fit available width instead of truncating with ellipsis.
- [ ] Text never scales below ~12sp (remains readable on small devices).
- [ ] For titles that would scale below the 12sp floor, the text is truncated with ellipsis at that minimum size (graceful degradation).
- [ ] No visual regression on screens with short, static titles (they should render identically to before).
- [ ] The fix uses a single shared widget so future screens get the behavior automatically.
- [ ] Existing widget tests continue to pass.

---

## Complete Screen Inventory

### Screens with Dynamic Titles (HIGH PRIORITY — truncation-prone)

| # | Screen File | Current Title | Risk |
|---|------------|---------------|------|
| 1 | `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` | `'Mark Prior Completions — ${widget.curriculumId.displayNameEn}'` | **HIGH** — reported bug |
| 2 | `lib/features/stages/presentation/screens/stage_editor_screen.dart` | `'Manage Stages — ${_curriculum.displayNameEn}'` | **HIGH** — em-dash + curriculum name |
| 3 | `lib/features/settings/presentation/screens/track_management_screen.dart` | `'Manage Tracks - ${curriculum.displayNameEn}'` | **HIGH** — prefix + curriculum name |
| 4 | `lib/features/learning_order/presentation/screens/learning_order_screen.dart` | `'${widget.curriculumId.displayNameEn} Order'` | **MEDIUM** — curriculum name |
| 5 | `lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart` | `Text(curriculum.displayNameEn)` | **MEDIUM** — curriculum name |
| 6 | `lib/features/content_browsing/presentation/screens/text_display_screen.dart` | `Text(sefariaRef)` | **MEDIUM** — Sefaria refs can be long |
| 7 | `lib/features/progress/presentation/screens/curriculum_progress_screen.dart` | `'Progress - $curriculumName'` | **MEDIUM** — prefix + curriculum name |
| 8 | `lib/features/settings/presentation/screens/curriculum_settings_screen.dart` | `'Settings - $curriculumId'` | **MEDIUM** — prefix + curriculum id |
| 9 | `lib/features/learning/presentation/screens/curriculum_learning_screen.dart` | `'Learn - $curriculumId'` | **MEDIUM** — prefix + curriculum id |
| 10 | `lib/features/content_browsing/presentation/screens/content_search_screen.dart` | `TextField` with hint `'Search ${curriculum.displayNameEn}…'` | **LOW** — TextField, not Text; but hint could clip |

### Screens with Static Titles (LOW PRIORITY — still apply for consistency)

| # | Screen File | Current Title |
|---|------------|---------------|
| 11 | `lib/features/auth/presentation/screens/sign_in_screen.dart` | `'Sign In'` |
| 12 | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | `'Dashboard'` |
| 13 | `lib/features/gamification/presentation/screens/gamification_screen.dart` | `'Gamification'` |
| 14 | `lib/features/learning/presentation/screens/learning_screen.dart` | `'Learn'` |
| 15 | `lib/features/notifications/presentation/screens/notifications_screen.dart` | `'Notifications'` |
| 16 | `lib/features/onboarding/presentation/screens/account_creation_screen.dart` | `'Create Account'` |
| 17 | `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | `'Select Curricula'` |
| 18 | `lib/features/onboarding/presentation/screens/mode_selection_screen.dart` | `'Choose Your Mode'` |
| 19 | `lib/features/onboarding/presentation/screens/rewards_setup_screen.dart` | `'Set Up Rewards'` |
| 20 | `lib/features/parent_mode/presentation/screens/parent_mode_screen.dart` | `'Parent Dashboard'` |
| 21 | `lib/features/parent_mode/presentation/screens/parent_track_management_screen.dart` | `'Manage Tracks'` |
| 22 | `lib/features/parent_mode/presentation/screens/pin_entry_screen.dart` | `'Enter Parent PIN'` |
| 23 | `lib/features/parent_mode/presentation/screens/pin_setup_screen.dart` | `'Set Parent PIN'` |
| 24 | `lib/features/parent_mode/presentation/screens/pin_change_screen.dart` | `'Change Parent PIN'` |
| 25 | `lib/features/parent_mode/presentation/screens/point_config_screen.dart` | `'Point Configuration'` |
| 26 | `lib/features/parent_mode/presentation/screens/reward_catalog_screen.dart` | `'Reward Catalog'` |
| 27 | `lib/features/progress/presentation/screens/progress_screen.dart` | `'Progress'` |
| 28 | `lib/features/progress/presentation/screens/progress_charts_screen.dart` | `'Progress Charts'` |
| 29 | `lib/features/progress/presentation/screens/completion_history_screen.dart` | `'Completion History'` |
| 30 | `lib/features/scheduler/presentation/screens/scheduler_screen.dart` | `'Daily Tasks'` |
| 31 | `lib/features/scheduler/presentation/screens/goal_setup_screen.dart` | `'Edit Goal'` / `'New Goal'` |
| 32 | `lib/features/settings/presentation/screens/settings_screen.dart` | `'Settings'` |
| 33 | `lib/features/sync/presentation/screens/sync_screen.dart` | `'Sync'` |
| 34 | `lib/features/tutor_mode/presentation/screens/tutor_mode_screen.dart` | `'Tutor Mode'` |
| 35 | `lib/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart` | `'Tutor Dashboard'` |
| 36 | `lib/features/tutor_mode/presentation/screens/tutor_pin_entry_screen.dart` | `'Enter Tutor PIN'` |
| 37 | `lib/features/tutor_mode/presentation/screens/tutor_pin_setup_screen.dart` | `'Set Tutor PIN'` |
| 38 | `lib/features/tutor_mode/presentation/screens/tutor_pin_change_screen.dart` | `'Change Tutor PIN'` |
| 39 | `lib/features/content_browsing/presentation/screens/curriculum_list_screen.dart` | `'Browse Content'` |
| 40 | `lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart` (error state) | `'Unknown Curriculum'` |

### Special Case

- **`content_search_screen.dart`** (#10): The AppBar title is a `TextField`, not a `Text` widget. FittedBox should NOT be applied here. The hint text scaling is handled by the TextField itself.

**Total: 40 AppBar instances across 35 screen files** (content_hierarchy_screen and content_search_screen each have 2).

---

## Architecture & Design Notes

### Recommended Approach: Shared `ScalingAppBarTitle` Widget

Rather than modifying each screen's AppBar individually (error-prone, hard to maintain), create a reusable widget:

```dart
// lib/core/widgets/scaling_app_bar_title.dart

import 'package:flutter/material.dart';

/// Wraps an AppBar title so it auto-scales to fit, with a minimum font size floor.
class ScalingAppBarTitle extends StatelessWidget {
  const ScalingAppBarTitle(this.text, {super.key});

  final String text;

  static const double _minFontSize = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.appBarTheme.titleTextStyle ??
        theme.textTheme.titleLarge ??
        const TextStyle(fontSize: 20);
    final defaultFontSize = defaultStyle.fontSize ?? 20.0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,   // matches centerTitle: true in theme
      child: Text(
        text,
        style: defaultStyle.copyWith(
          fontSize: defaultFontSize,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
```

**Why FittedBox with `BoxFit.scaleDown`?**
- It only scales *down*, never up — short titles remain at their normal size.
- Combined with `maxLines: 1` and `TextOverflow.ellipsis`, if the text still overflows at the minimum scale, it gracefully truncates.

**Minimum font size enforcement:**
Flutter's `FittedBox` does not natively support a minimum font size. Two options:

1. **Option A — `LayoutBuilder` + manual calculation**: Wrap in `LayoutBuilder`, measure text at default size, compute the scale factor, clamp at `_minFontSize / defaultFontSize`, and either apply FittedBox or manually set fontSize + ellipsis. More complex but precise.

2. **Option B — Use the `auto_size_text` package**: `AutoSizeText` supports `minFontSize` natively. Adds a small dependency but is battle-tested.

3. **Option C (Recommended) — LayoutBuilder approach without extra deps**:
```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final defaultStyle = /* ... resolve style ... */;
  final defaultFontSize = defaultStyle.fontSize ?? 20.0;
  final minScale = _minFontSize / defaultFontSize;

  return ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: kToolbarHeight),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: ConstrainedBox(
        // Prevent FittedBox from scaling below minScale
        // by limiting the logical width the text can occupy
        constraints: BoxConstraints(
          minWidth: 0,
          maxWidth: MediaQuery.of(context).size.width / minScale,
        ),
        child: Text(
          text,
          style: defaultStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
```

### Alternative Considered: Theme-Level `titleTextStyle` with overflow

Setting `overflow: TextOverflow.ellipsis` in `AppBarTheme.titleTextStyle` globally would prevent clipping but would NOT auto-scale. Rejected because it doesn't meet the auto-scale requirement.

### Why NOT a Custom AppBar Wrapper?

A full `LtAppBar` wrapper around `AppBar(...)` would be heavier and require changing every `Scaffold(appBar: AppBar(...))` call to `Scaffold(appBar: LtAppBar(...))`. The `ScalingAppBarTitle` widget is lighter — it only replaces the `title:` parameter value, which is a smaller diff and easier to review.

---

## Implementation Steps

### Step 1: Create the Shared Widget
- Create `lib/core/widgets/scaling_app_bar_title.dart`
- Implement `ScalingAppBarTitle` with FittedBox + min font size logic
- Export from `lib/core/widgets/widgets.dart` barrel file (if one exists, otherwise add import directly)

### Step 2: Update High-Priority Dynamic-Title Screens (1-9)
For each, replace `title: Text('...')` with `title: ScalingAppBarTitle('...')`:

1. `bulk_mark_screen.dart` — line 173-175
2. `stage_editor_screen.dart` — line 43
3. `track_management_screen.dart` — line 37
4. `learning_order_screen.dart` — line 41
5. `content_hierarchy_screen.dart` — line 106
6. `text_display_screen.dart` — line 28
7. `curriculum_progress_screen.dart` — line 30
8. `curriculum_settings_screen.dart` — line 17
9. `curriculum_learning_screen.dart` — line 16

### Step 3: Update Static-Title Screens (11-40)
Same replacement for all remaining screens. Even though these won't truncate now, applying `ScalingAppBarTitle` ensures consistency and future-proofs against localization or dynamic title changes.

### Step 4: Skip Special Cases
- `content_search_screen.dart` — title is a `TextField`, leave as-is.

### Step 5: Run Tests & Validate
- `make ci` to ensure no regressions
- Manual verification on a narrow device / emulator with long curriculum names

---

## Dev Notes

### FittedBox Constraints
- `FittedBox(fit: BoxFit.scaleDown)` is key — `scaleDown` means "shrink if needed, but never enlarge."
- The AppBar's title area width is constrained by the AppBar's leading/actions widgets. `FittedBox` works within whatever space is left.
- `centerTitle: true` is set in the app's `AppBarTheme`, so `alignment: Alignment.center` on the FittedBox is consistent.

### Minimum Font Size (~12sp)
- 12sp is the Material Design minimum for body text readability.
- With a default title size of 20sp, the minimum scale factor is `12/20 = 0.6`, meaning titles can shrink to 60% of normal before truncating.
- For the worst case ("Mark Prior Completions — Mishnayos" at ~40 chars), 60% scaling should be sufficient on most phone widths (360dp+).

### Testing with Long Strings
Use these test strings to validate:
- `"Mark Prior Completions — Mishnayos"` (35 chars) — the reported bug
- `"Manage Stages — Talmud Bavli"` (29 chars) — another em-dash case
- `"Mark Prior Completions — Talmud Yerushalmi"` (44 chars) — stress test
- `"AAAA..."` (80 chars) — extreme stress test for min-size fallback

### Edge Cases
- RTL text (Hebrew curriculum names): FittedBox handles directionality correctly via the `Directionality` widget in the tree.
- AppBar with many action buttons: reduces available title width further. The `content_hierarchy_screen` has 2 action buttons — test this.

---

## Test Plan

### Unit Test: `ScalingAppBarTitle` Widget
File: `test/core/widgets/scaling_app_bar_title_test.dart`

```dart
// Test cases:
// 1. Short text renders at normal size (no scaling)
// 2. Long text scales down (verify via RenderBox size or textScaleFactor)
// 3. Extremely long text hits min font size and shows ellipsis
// 4. Widget renders inside a MaterialApp with AppBarTheme
```

### Widget Tests: Per-Screen Smoke Tests
For each high-priority screen, add or update a widget test that:
- Pumps the screen with a very long curriculum name
- Verifies the AppBar title widget is a `ScalingAppBarTitle`
- Verifies no overflow errors (Flutter test framework reports these as exceptions)

### Manual / Visual QA
- Run on a narrow emulator (320dp width, e.g. iPhone SE)
- Navigate to Bulk Mark screen with "Mishnayos" curriculum
- Navigate to Stage Editor with "Talmud Yerushalmi"
- Verify text scales down but remains readable
- Verify short titles ("Settings", "Dashboard") look identical to before

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/core/widgets/scaling_app_bar_title.dart` | Shared FittedBox title widget |
| `test/core/widgets/scaling_app_bar_title_test.dart` | Widget tests for the new component |

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` | Replace `Text(...)` title with `ScalingAppBarTitle(...)` |
| `lib/features/stages/presentation/screens/stage_editor_screen.dart` | Same |
| `lib/features/settings/presentation/screens/track_management_screen.dart` | Same |
| `lib/features/learning_order/presentation/screens/learning_order_screen.dart` | Same |
| `lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart` | Same (line 106 only; line 74 is short static text but update for consistency) |
| `lib/features/content_browsing/presentation/screens/text_display_screen.dart` | Same |
| `lib/features/progress/presentation/screens/curriculum_progress_screen.dart` | Same |
| `lib/features/settings/presentation/screens/curriculum_settings_screen.dart` | Same |
| `lib/features/learning/presentation/screens/curriculum_learning_screen.dart` | Same |
| `lib/features/auth/presentation/screens/sign_in_screen.dart` | Same (consistency) |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Same |
| `lib/features/gamification/presentation/screens/gamification_screen.dart` | Same |
| `lib/features/learning/presentation/screens/learning_screen.dart` | Same |
| `lib/features/notifications/presentation/screens/notifications_screen.dart` | Same |
| `lib/features/onboarding/presentation/screens/account_creation_screen.dart` | Same |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Same |
| `lib/features/onboarding/presentation/screens/mode_selection_screen.dart` | Same |
| `lib/features/onboarding/presentation/screens/rewards_setup_screen.dart` | Same |
| `lib/features/parent_mode/presentation/screens/parent_mode_screen.dart` | Same |
| `lib/features/parent_mode/presentation/screens/parent_track_management_screen.dart` | Same |
| `lib/features/parent_mode/presentation/screens/pin_entry_screen.dart` | Same |
| `lib/features/parent_mode/presentation/screens/pin_setup_screen.dart` | Same |
| `lib/features/parent_mode/presentation/screens/pin_change_screen.dart` | Same |
| `lib/features/parent_mode/presentation/screens/point_config_screen.dart` | Same |
| `lib/features/parent_mode/presentation/screens/reward_catalog_screen.dart` | Same |
| `lib/features/progress/presentation/screens/progress_screen.dart` | Same |
| `lib/features/progress/presentation/screens/progress_charts_screen.dart` | Same |
| `lib/features/progress/presentation/screens/completion_history_screen.dart` | Same |
| `lib/features/scheduler/presentation/screens/scheduler_screen.dart` | Same |
| `lib/features/scheduler/presentation/screens/goal_setup_screen.dart` | Same |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Same |
| `lib/features/sync/presentation/screens/sync_screen.dart` | Same |
| `lib/features/tutor_mode/presentation/screens/tutor_mode_screen.dart` | Same |
| `lib/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart` | Same |
| `lib/features/tutor_mode/presentation/screens/tutor_pin_entry_screen.dart` | Same |
| `lib/features/tutor_mode/presentation/screens/tutor_pin_setup_screen.dart` | Same |
| `lib/features/tutor_mode/presentation/screens/tutor_pin_change_screen.dart` | Same |

**Total: 1 new widget + 1 new test file + 37 screen files modified**
