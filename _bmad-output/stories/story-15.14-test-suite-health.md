# Story 15.14 -- Test Suite Health: Fix Failures, Audit Coverage & Harden

**Ticket**: DNI-122
**Epic**: 15 (Multi-Profile & Expanded Curricula)
**Priority**: P0 -- must complete before any Epic 15 implementation work

---

## Story Overview

Epic 15 touches 65+ files for profile scoping, new curricula, and revised onboarding. Before that work begins, the test suite must be comprehensive and green. Currently there are 14 known pre-existing failures across `app_shell_test.dart` and `settings_screen_test.dart`, and significant coverage gaps across core business logic layers.

This story ensures:
1. Every existing test passes
2. Coverage gaps are identified and filled for all critical paths
3. Test infrastructure is robust enough to support 65+ file changes without regressions

---

## Acceptance Criteria

- [ ] `make ci` passes with zero failures (analyze + format + all tests)
- [ ] All 14 failures in `app_shell_test.dart` and `settings_screen_test.dart` are fixed
- [ ] No other failing tests exist anywhere in the suite
- [ ] `flutter test --coverage` generates lcov report with documented coverage percentages
- [ ] Every DAO has dedicated unit tests
- [ ] Every domain service has dedicated unit tests
- [ ] Every repository implementation has dedicated unit tests
- [ ] Critical widget screens have widget tests
- [ ] Test helpers cover all common mock patterns (database, Firebase, Riverpod providers)
- [ ] Flaky tests (async timing, stream providers) are stabilized
- [ ] Root cause documented for each fixed failure

---

## Phase 1: Fix All Failing Tests

### File: `test/core/navigation/app_shell_test.dart`

**Location**: `/home/daniel/repos/learning-tracker/learning_tracker/test/core/navigation/app_shell_test.dart`

The file contains 7 test cases across 3 groups:

#### Group: "AppShellScreen bottom navigation" (4 tests)
1. **"renders exactly 4 tabs: Dashboard, Learn, Progress, Settings"**
2. **"tapping Learn tab navigates to learn route"**
3. **"tapping Progress tab navigates to progress route"**
4. **"tapping Settings tab navigates to settings route"**

#### Group: "Curriculum-scoped routes" (1 test)
5. **"content browsing route accepts curriculumId parameter"**

#### Group: "Auth flow" (2 tests)
6. **"unauthenticated user is redirected to sign-in"**
7. **"authenticated user sees dashboard with bottom navigation"**

**Likely Root Causes**:
- The test overrides `dashboardStreakProvider` but the production `SettingsScreen` depends on `firebaseAuthProvider`, `activeCurriculaStreamProvider`, `curriculumActivationServiceProvider`, `accountManagementServiceProvider`, and `userProfileServiceProvider` -- none of which are overridden in the `ProviderScope`.
- The `_pumpDashboard` helper pumps 500ms which may be insufficient for auto_route navigation + Riverpod async provider resolution.
- The `DashboardScreen` likely reads from providers (streak, completions, active curricula) that need database seeding or additional overrides.
- For test 4 (Settings tab), a `FlutterError.onError` override suppresses `ProviderException` but the screen also uses `firebaseAuthProvider` which is not overridden -- the `ref.watch(firebaseAuthProvider)` call will throw because there is no Firebase app initialized in tests.
- For test 5 (curriculum-scoped route), `ContentHierarchyScreen` likely needs content providers overridden.

**Fix Approach**:
- Add provider overrides for all providers that `SettingsScreen`, `DashboardScreen`, `LearningScreen`, and `ProgressScreen` depend on.
- Create a shared `createTestProviderScope()` helper that includes all necessary overrides.
- Override `firebaseAuthProvider` with a mock `FirebaseAuth` instance.
- Override `activeCurriculaStreamProvider` with a test stream.
- Override `curriculumActivationServiceProvider` with the test service (as done in `settings_screen_test.dart`).
- Override `accountManagementServiceProvider` and `userProfileServiceProvider` with mocks.
- Increase pump durations or switch to targeted pump loops for navigation.

### File: `test/features/settings/presentation/screens/settings_screen_test.dart`

**Location**: `/home/daniel/repos/learning-tracker/learning_tracker/test/features/settings/presentation/screens/settings_screen_test.dart`

The file contains 7 test cases in group "SettingsScreen Widget Tests":

1. **"renders all 5 curricula with toggle switches"**
2. **"shows active curricula with green status"**
3. **"shows inactive curricula with grey status"**
4. **"toggles on an inactive curriculum"**
5. **"toggles off an active curriculum (when not last)"**
6. **"disables toggle for last active curriculum"**
7. **"section header displays correctly"**

**Likely Root Causes**:
- The test creates `SettingsScreen` directly in a `MaterialApp` but `SettingsScreen` is a `ConsumerWidget` that calls `ref.watch(firebaseAuthProvider)` on line 29 and `ref.watch(activeCurriculaStreamProvider)` on line 28. The test only overrides `appDatabaseProvider` and `curriculumActivationServiceProvider`.
- `firebaseAuthProvider` is not overridden -- it requires a Firebase app to be initialized, which does not happen in unit tests. This will throw an unhandled exception.
- `activeCurriculaStreamProvider` is not overridden -- it depends on `appDatabaseProvider` (which IS overridden) but the stream may not emit synchronously.
- The `SettingsScreen` also depends on `accountManagementServiceProvider`, `userProfileServiceProvider`, and `onboardingProviders` (via the `_UserModeSection`). The `_UserModeSection` calls `ref.read(userProfileServiceProvider)` in `initState`.
- `pumpAndSettle` will hang if any stream provider keeps emitting or never completes.

**Fix Approach**:
- Override `firebaseAuthProvider` with a mock `FirebaseAuth` that returns a mock `User`.
- Override `activeCurriculaStreamProvider` with a test stream that emits the expected active curricula.
- Override `userProfileServiceProvider` with a mock that returns a test profile.
- Override `accountManagementServiceProvider` with a mock.
- Consider extracting just the curricula toggle section into a separate widget test that does not require the full `SettingsScreen` dependency tree.
- Replace `pumpAndSettle()` with targeted `pump()` calls to avoid hangs on stream providers.

---

## Phase 2: Coverage Audit Plan

### Commands to Run

```bash
cd learning_tracker

# Generate coverage data
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# Check coverage percentage
lcov --summary coverage/lcov.info

# Find files with zero coverage
lcov --summary coverage/lcov.info 2>&1 | grep -E '^\s+0\.0%'
```

### What to Look For
- **Line coverage below 60%**: Critical paths that need tests
- **Zero coverage files**: Source files with no test coverage at all
- **Branch coverage gaps**: Conditional logic (error handling, edge cases) not exercised

### Gap Categories to Audit
1. Core database (DAOs, migrations, tables)
2. Sync engine (push, pull, merge, conflict resolution, offline queue)
3. Onboarding flow (screens, state transitions, import service)
4. Stage progression logic (stage definitions, stage editor)
5. Completion tracking (repository, duplicate prevention)
6. Auth flow and guards (auth guard, child mode guard, restore guard)
7. Settings and account management (curricula activation, account deletion)
8. Dashboard (providers, aggregation, widgets)
9. Progress tracking (charts, curriculum progress, history)
10. Gamification (points, streaks, rewards)
11. Notifications (scheduler, streak alerts, shabbos mode)
12. Parent mode (PIN guards, dashboard, track management)
13. Tutor mode (PIN guards, dashboard, read-only enforcement)
14. Scheduler (engine, pace calculator, daily tasks, goals)

---

## Phase 3: Gap Analysis

### Legend
- HAS TEST = test file exists
- NO TEST = no test file found for this source file
- Generated files (`.g.dart`, `.freezed.dart`, `.gr.dart`) are excluded

### Core Database Layer

| Source File | Test Status |
|---|---|
| `lib/core/database/app_database.dart` | HAS TEST (epic_01 story 1.2; basic CRUD) |
| `lib/core/database/daos/active_curriculum_dao.dart` | HAS TEST (`test/core/database/daos/active_curriculum_dao_test.dart`) |
| `lib/core/database/daos/bookmark_dao.dart` | NO TEST (only tested indirectly via `bookmark_repository_impl_test.dart`) |
| `lib/core/database/daos/completion_dao.dart` | NO TEST (tested indirectly via `completion_repository_impl_test.dart`) |
| `lib/core/database/daos/goal_dao.dart` | NO TEST |
| `lib/core/database/daos/learning_order_dao.dart` | HAS TEST (`test/core/database/daos/learning_order_dao_test.dart`) |
| `lib/core/database/daos/point_config_dao.dart` | NO TEST |
| `lib/core/database/daos/reward_dao.dart` | NO TEST |
| `lib/core/database/daos/stage_dao.dart` | HAS TEST (`test/core/database/daos/stage_dao_test.dart`) |
| `lib/core/database/daos/streak_dao.dart` | NO TEST (tested indirectly via `streak_service_test.dart`) |
| `lib/core/database/daos/sync_queue_dao.dart` | NO TEST (tested indirectly via `offline_queue_test.dart`) |
| `lib/core/database/daos/text_cache_dao.dart` | HAS TEST (`test/core/database/text_cache_dao_test.dart`) |
| `lib/core/database/daos/text_download_status_dao.dart` | HAS TEST (`test/core/database/daos/text_download_status_dao_test.dart`) |
| `lib/core/database/daos/track_dao.dart` | NO TEST (tested indirectly via `track_repository_test.dart`) |
| `lib/core/database/daos/user_profile_dao.dart` | NO TEST (tested indirectly via `user_profile_service_test.dart`) |

### Core Services

| Source File | Test Status |
|---|---|
| `lib/core/services/daily_schedule_composer.dart` | HAS TEST (`test/core/services/daily_schedule_composer_test.dart`) |
| `lib/core/services/track_service.dart` | HAS TEST (`test/core/services/track_service_test.dart`) |
| `lib/core/services/duplicate_prevention_service.dart` | HAS TEST (`test/core/services/duplicate_prevention_service_test.dart`) |
| `lib/core/services/pin_service.dart` | HAS TEST (epic_01 story 1.11) |
| `lib/core/services/cross_curriculum_aggregator.dart` | NO TEST |

### Core Navigation & Guards

| Source File | Test Status |
|---|---|
| `lib/core/navigation/app_shell.dart` | HAS TEST (`test/core/navigation/app_shell_test.dart`) -- FAILING |
| `lib/core/navigation/app_router.dart` | HAS TEST (via app_shell_test.dart) -- FAILING |
| `lib/core/navigation/router_provider.dart` | NO TEST |
| `lib/core/navigation/guards/auth_guard.dart` | HAS TEST (`test/core/auth/auth_guard_test.dart`) |
| `lib/core/navigation/guards/child_mode_guard.dart` | HAS TEST (`test/features/parent_mode/child_mode_guard_test.dart`) |
| `lib/core/navigation/guards/parent_pin_guard.dart` | HAS TEST (`test/core/navigation/guards/parent_pin_guard_test.dart`) |
| `lib/core/navigation/guards/tutor_pin_guard.dart` | HAS TEST (`test/core/navigation/guards/tutor_pin_guard_test.dart`) |
| `lib/core/navigation/guards/restore_guard.dart` | NO TEST |
| `lib/core/navigation/guards/pin_guard.dart` | NO TEST |

### Core Utils

| Source File | Test Status |
|---|---|
| `lib/core/utils/date_utils.dart` | HAS TEST |
| `lib/core/utils/hebrew_calendar_utils.dart` | HAS TEST |
| `lib/core/utils/hebrew_utils.dart` | HAS TEST |

### Core Widgets

| Source File | Test Status |
|---|---|
| `lib/core/widgets/empty_state.dart` | HAS TEST |
| `lib/core/widgets/loading_indicator.dart` | HAS TEST |
| `lib/core/widgets/track_progress_bar.dart` | HAS TEST |
| `lib/core/widgets/track_selector_chip.dart` | HAS TEST |
| `lib/core/widgets/pin_entry_widget.dart` | HAS TEST |
| `lib/core/widgets/error_display.dart` | HAS TEST |
| `lib/core/widgets/curriculum_indicator.dart` | HAS TEST |
| `lib/core/widgets/hebrew_text.dart` | NO TEST |
| `lib/core/widgets/animated_progress_bar.dart` | NO TEST |

### Core Other

| Source File | Test Status |
|---|---|
| `lib/core/constants/curriculum_defaults.dart` | HAS TEST |
| `lib/core/constants/text_content_config.dart` | NO TEST |
| `lib/core/enums/track_type.dart` | HAS TEST |
| `lib/core/enums/curriculum_id.dart` | HAS TEST (via fixtures, epic_01) |
| `lib/core/enums/user_mode.dart` | HAS TEST (via epic_01 story 1.7) |
| `lib/core/logging/logger.dart` | HAS TEST |
| `lib/core/logging/riverpod_observer_test.dart` | HAS TEST |
| `lib/core/network/dio_provider.dart` | NO TEST |
| `lib/core/network/connectivity_service.dart` | HAS TEST |
| `lib/core/network/sefaria/curriculum_content_fetcher.dart` | HAS TEST (`test/core/network/sefaria/fetcher_test.dart`) |
| `lib/core/network/sefaria/models/content_item.dart` | NO TEST (tested via fixtures) |
| `lib/core/network/sefaria/models/curriculum_hierarchy_config.dart` | NO TEST |
| `lib/core/theme/app_theme.dart` | HAS TEST (epic_01 story 1.6) |
| `lib/core/theme/text_styles.dart` | NO TEST |
| `lib/core/preferences/text_display_preferences.dart` | NO TEST |
| `lib/core/providers/database_provider.dart` | NO TEST (simple provider, low priority) |
| `lib/core/providers/firebase_providers.dart` | NO TEST (simple provider, low priority) |
| `lib/core/providers/network_providers.dart` | NO TEST |
| `lib/core/providers/talker_provider.dart` | NO TEST (simple provider, low priority) |
| `lib/core/exceptions/duplicate_completion_exception.dart` | NO TEST (tested via duplicate_prevention_service) |

### Feature: Auth

| Source File | Test Status |
|---|---|
| `lib/features/auth/domain/repositories/auth_repository.dart` | Interface only |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | NO TEST (wraps Firebase -- mock-heavy) |
| `lib/features/auth/presentation/screens/sign_in_screen.dart` | NO TEST |
| `lib/features/auth/presentation/providers/auth_providers.dart` | NO TEST |

Integration test exists: `test/features/auth/auth_integration_test.dart`

### Feature: Content Browsing

| Source File | Test Status |
|---|---|
| `lib/features/content_browsing/domain/repositories/content_repository.dart` | Interface only |
| `lib/features/content_browsing/data/repositories/content_repository_impl.dart` | HAS TEST |
| `lib/features/content_browsing/data/repositories/text_cache_repository.dart` | HAS TEST |
| `lib/features/content_browsing/data/services/text_download_service.dart` | HAS TEST |
| `lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart` | HAS TEST |
| `lib/features/content_browsing/presentation/screens/curriculum_list_screen.dart` | HAS TEST |
| `lib/features/content_browsing/presentation/screens/text_display_screen.dart` | HAS TEST |
| `lib/features/content_browsing/presentation/screens/content_search_screen.dart` | NO TEST |
| `lib/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart` | HAS TEST |
| `lib/features/content_browsing/presentation/widgets/content_item_tile.dart` | HAS TEST |
| `lib/features/content_browsing/presentation/providers/content_providers.dart` | NO TEST |
| `lib/features/content_browsing/presentation/providers/text_display_providers.dart` | NO TEST |

Integration tests: `hierarchy_navigation_test.dart`, `text_display_integration_test.dart`

### Feature: Dashboard

| Source File | Test Status |
|---|---|
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | NO TEST |
| `lib/features/dashboard/presentation/providers/dashboard_providers.dart` | NO TEST |
| `lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart` | NO TEST |
| `lib/features/dashboard/presentation/widgets/points_summary_widget.dart` | NO TEST |
| `lib/features/dashboard/presentation/widgets/todays_tasks_widget.dart` | NO TEST |

### Feature: Gamification

| Source File | Test Status |
|---|---|
| `lib/features/gamification/domain/services/points_service.dart` | HAS TEST |
| `lib/features/gamification/domain/services/streak_service.dart` | HAS TEST |
| `lib/features/gamification/domain/models/reward_model.dart` | NO TEST |
| `lib/features/gamification/presentation/screens/gamification_screen.dart` | NO TEST |
| `lib/features/gamification/presentation/providers/points_providers.dart` | NO TEST |
| `lib/features/gamification/presentation/widgets/streak_widget.dart` | HAS TEST |
| `lib/features/gamification/presentation/widgets/points_display_widget.dart` | HAS TEST |
| `lib/features/gamification/presentation/widgets/reward_progress_widget.dart` | NO TEST |
| `lib/features/gamification/presentation/widgets/earned_rewards_widget.dart` | NO TEST |

### Feature: Learning

| Source File | Test Status |
|---|---|
| `lib/features/learning/domain/repositories/track_repository.dart` | Interface only |
| `lib/features/learning/domain/repositories/bookmark_repository.dart` | Interface only |
| `lib/features/learning/domain/repositories/completion_repository.dart` | Interface only |
| `lib/features/learning/domain/entities/completion_request.dart` | NO TEST |
| `lib/features/learning/domain/entities/bookmark.dart` | NO TEST |
| `lib/features/learning/data/repositories/track_repository_impl.dart` | HAS TEST |
| `lib/features/learning/data/repositories/bookmark_repository_impl.dart` | HAS TEST |
| `lib/features/learning/data/repositories/completion_repository_impl.dart` | HAS TEST |
| `lib/features/learning/presentation/screens/learning_screen.dart` | NO TEST |
| `lib/features/learning/presentation/screens/curriculum_learning_screen.dart` | NO TEST |
| `lib/features/learning/presentation/providers/track_providers.dart` | NO TEST |
| `lib/features/learning/presentation/widgets/completion_feedback_controller.dart` | NO TEST |
| `lib/features/learning/presentation/widgets/completion_animation.dart` | NO TEST |
| `lib/features/learning/presentation/widgets/points_popup.dart` | NO TEST |
| `lib/features/learning/presentation/widgets/track_selector_bottom_sheet.dart` | HAS TEST |
| `lib/features/learning/presentation/widgets/bookmark_card.dart` | NO TEST |
| `lib/features/learning/presentation/widgets/bulk_completion_dialog.dart` | NO TEST |
| `lib/features/learning/presentation/widgets/completion_feedback_widget.dart` | HAS TEST (`completion_feedback_widget_test.dart`) |

### Feature: Learning Order

| Source File | Test Status |
|---|---|
| `lib/features/learning_order/domain/repositories/learning_order_repository.dart` | Interface only |
| `lib/features/learning_order/domain/models/learning_order_item.dart` | NO TEST |
| `lib/features/learning_order/data/repositories/learning_order_repository_impl.dart` | HAS TEST |
| `lib/features/learning_order/data/preferences/learning_order_preferences.dart` | NO TEST |
| `lib/features/learning_order/presentation/screens/learning_order_screen.dart` | NO TEST |
| `lib/features/learning_order/presentation/providers/learning_order_providers.dart` | NO TEST |
| `lib/features/learning_order/presentation/widgets/reset_order_dialog.dart` | NO TEST |
| `lib/features/learning_order/presentation/widgets/draggable_order_item.dart` | NO TEST |

### Feature: Onboarding

| Source File | Test Status |
|---|---|
| `lib/features/onboarding/domain/services/user_profile_service.dart` | HAS TEST |
| `lib/features/onboarding/domain/services/curriculum_import_service.dart` | HAS TEST |
| `lib/features/onboarding/domain/services/suggested_thresholds_service.dart` | NO TEST |
| `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart` | NO TEST |
| `lib/features/onboarding/domain/validators/auth_validators.dart` | NO TEST (tested indirectly via `account_creation_validation_test.dart`) |
| `lib/features/onboarding/presentation/screens/mode_selection_screen.dart` | HAS TEST |
| `lib/features/onboarding/presentation/screens/account_creation_screen.dart` | HAS TEST |
| `lib/features/onboarding/presentation/screens/welcome_screen.dart` | HAS TEST |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | HAS TEST |
| `lib/features/onboarding/presentation/screens/rewards_setup_screen.dart` | NO TEST |
| `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` | NO TEST |
| `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | NO TEST |

### Feature: Notifications

| Source File | Test Status |
|---|---|
| `lib/features/notifications/domain/services/notification_scheduler.dart` | HAS TEST |
| `lib/features/notifications/domain/services/streak_alert_service.dart` | HAS TEST |
| `lib/features/notifications/domain/services/notification_service.dart` | NO TEST |
| `lib/features/notifications/domain/services/reward_milestone_notification_service.dart` | NO TEST |
| `lib/features/notifications/domain/services/notification_initializer.dart` | NO TEST |
| `lib/features/notifications/domain/services/shabbos_time_service.dart` | NO TEST |
| `lib/features/notifications/presentation/screens/notifications_screen.dart` | NO TEST |
| `lib/features/notifications/presentation/providers/notification_providers.dart` | NO TEST |
| `lib/features/notifications/presentation/providers/reward_milestone_providers.dart` | NO TEST |

### Feature: Parent Mode

| Source File | Test Status |
|---|---|
| `lib/features/parent_mode/domain/services/parent_dashboard_aggregator.dart` | NO TEST |
| `lib/features/parent_mode/presentation/screens/pin_entry_screen.dart` | NO TEST |
| `lib/features/parent_mode/presentation/screens/pin_setup_screen.dart` | NO TEST |
| `lib/features/parent_mode/presentation/screens/pin_change_screen.dart` | NO TEST |
| `lib/features/parent_mode/presentation/screens/parent_mode_screen.dart` | NO TEST |
| `lib/features/parent_mode/presentation/screens/reward_catalog_screen.dart` | NO TEST |
| `lib/features/parent_mode/presentation/screens/point_config_screen.dart` | NO TEST |
| `lib/features/parent_mode/presentation/screens/parent_track_management_screen.dart` | NO TEST |
| `lib/features/parent_mode/presentation/providers/parent_dashboard_providers.dart` | NO TEST |
| `lib/features/parent_mode/presentation/providers/parent_track_providers.dart` | NO TEST |
| `lib/features/parent_mode/presentation/widgets/engagement_card.dart` | NO TEST |
| `lib/features/parent_mode/presentation/widgets/key_stats_row.dart` | NO TEST |
| `lib/features/parent_mode/presentation/widgets/curriculum_card.dart` | NO TEST |
| `lib/features/parent_mode/presentation/widgets/recent_completions_list.dart` | NO TEST |

Unit tests exist: `pin_service_test.dart`, `child_mode_guard_test.dart`

### Feature: Progress

| Source File | Test Status |
|---|---|
| `lib/features/progress/domain/repositories/progress_repository.dart` | Interface only |
| `lib/features/progress/domain/services/curriculum_progress_service.dart` | HAS TEST |
| `lib/features/progress/domain/services/chart_data_service.dart` | NO TEST |
| `lib/features/progress/domain/models/curriculum_progress_data.dart` | NO TEST |
| `lib/features/progress/domain/models/chart_data.dart` | NO TEST |
| `lib/features/progress/data/repositories/progress_repository_impl.dart` | HAS TEST (via `progress_repository_test.dart`) |
| `lib/features/progress/presentation/screens/progress_screen.dart` | NO TEST |
| `lib/features/progress/presentation/screens/curriculum_progress_screen.dart` | NO TEST |
| `lib/features/progress/presentation/screens/completion_history_screen.dart` | NO TEST |
| `lib/features/progress/presentation/screens/progress_charts_screen.dart` | NO TEST |
| `lib/features/progress/presentation/providers/progress_providers.dart` | NO TEST |
| `lib/features/progress/presentation/providers/chart_providers.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/streak_calendar.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/stage_breakdown_row.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/cumulative_line_chart.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/points_over_time_chart.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/completions_bar_chart.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/hierarchy_progress_card.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/pace_indicator.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/overall_stats_card.dart` | NO TEST |
| `lib/features/progress/presentation/widgets/progress_widgets_test.dart` | HAS TEST |

### Feature: Scheduler

| Source File | Test Status |
|---|---|
| `lib/features/scheduler/domain/services/scheduler_engine.dart` | HAS TEST |
| `lib/features/scheduler/domain/services/pace_calculator.dart` | HAS TEST |
| `lib/features/scheduler/domain/services/goal_progress_calculator.dart` | HAS TEST |
| `lib/features/scheduler/domain/services/daily_task_generator.dart` | HAS TEST |
| `lib/features/scheduler/domain/repositories/scheduler_stage_repository.dart` | Interface only |
| `lib/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart` | Interface only |
| `lib/features/scheduler/domain/repositories/scheduler_content_repository.dart` | Interface only |
| `lib/features/scheduler/domain/repositories/scheduler_completion_repository.dart` | Interface only |
| `lib/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart` | NO TEST |
| `lib/features/scheduler/data/repositories/scheduler_content_repository_impl.dart` | NO TEST |
| `lib/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart` | NO TEST |
| `lib/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart` | NO TEST |
| `lib/features/scheduler/presentation/screens/scheduler_screen.dart` | HAS TEST |
| `lib/features/scheduler/presentation/widgets/goal_progress_card.dart` | HAS TEST |
| `lib/features/scheduler/presentation/widgets/hebrew_date_picker.dart` | HAS TEST |
| `lib/features/scheduler/presentation/widgets/pace_indicator.dart` | HAS TEST |
| `lib/features/scheduler/presentation/widgets/daily_schedule_header.dart` | NO TEST |
| `lib/features/scheduler/presentation/widgets/daily_schedule_widgets.dart` (or similar) | HAS TEST |
| `lib/features/scheduler/presentation/widgets/daily_task_card.dart` (or similar) | HAS TEST |
| `lib/features/scheduler/presentation/widgets/grouped_daily_view.dart` | NO TEST |
| `lib/features/scheduler/presentation/widgets/unified_daily_view.dart` | NO TEST |

Integration tests: `scheduler_engine_integration_test.dart`, `scheduler_engine_performance_test.dart`

### Feature: Settings

| Source File | Test Status |
|---|---|
| `lib/features/settings/domain/services/curriculum_activation_service.dart` | HAS TEST |
| `lib/features/settings/domain/services/account_management_service.dart` | NO TEST (tested indirectly via epic_14 story 14.3) |
| `lib/features/settings/presentation/screens/settings_screen.dart` | HAS TEST -- FAILING |
| `lib/features/settings/presentation/screens/track_management_screen.dart` | HAS TEST |
| `lib/features/settings/presentation/screens/curriculum_settings_screen.dart` | NO TEST |
| `lib/features/settings/presentation/providers/curriculum_activation_providers.dart` | NO TEST |
| `lib/features/settings/presentation/providers/account_management_providers.dart` | NO TEST |
| `lib/features/settings/presentation/widgets/change_password_dialog.dart` | NO TEST |
| `lib/features/settings/presentation/widgets/delete_account_dialog.dart` | NO TEST |
| `lib/features/settings/presentation/widgets/link_provider_dialog.dart` | NO TEST |
| `lib/features/settings/presentation/widgets/reauthenticate_dialog.dart` | NO TEST |

### Feature: Stages

| Source File | Test Status |
|---|---|
| `lib/features/stages/domain/models/stage_definition.dart` | HAS TEST |
| `lib/features/stages/domain/repositories/stage_definition_repository.dart` | Interface only |
| `lib/features/stages/domain/exceptions/protected_stage_exception.dart` | NO TEST |
| `lib/features/stages/domain/exceptions/stage_limit_exceeded_exception.dart` | NO TEST |
| `lib/features/stages/data/repositories/stage_definition_repository_impl.dart` | HAS TEST |
| `lib/features/stages/presentation/screens/stage_editor_screen.dart` | HAS TEST |
| `lib/features/stages/presentation/widgets/stage_row_widget.dart` | NO TEST |
| `lib/features/stages/presentation/providers/stage_providers.dart` | NO TEST |

### Feature: Sync

| Source File | Test Status |
|---|---|
| `lib/features/sync/data/sync_engine.dart` | HAS TEST |
| `lib/features/sync/data/offline_queue.dart` | HAS TEST |
| `lib/features/sync/data/firestore_data_source.dart` | NO TEST |
| `lib/features/sync/domain/models/sync_status.dart` | HAS TEST |
| `lib/features/sync/domain/models/restore_status.dart` | NO TEST |
| `lib/features/sync/domain/services/device_restore_service.dart` | NO TEST |
| `lib/features/sync/presentation/screens/sync_screen.dart` | NO TEST |
| `lib/features/sync/presentation/screens/device_restore_screen.dart` | NO TEST |
| `lib/features/sync/presentation/providers/sync_providers.dart` | NO TEST |
| `lib/features/sync/presentation/providers/restore_providers.dart` | NO TEST |
| `lib/features/sync/presentation/widgets/sync_status_indicator.dart` | NO TEST |
| `lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart` | NO TEST |

Integration test: `test/integration/stage_sync_test.dart`

### Feature: Tutor Mode

| Source File | Test Status |
|---|---|
| `lib/features/tutor_mode/domain/tutor_mode_provider.dart` | NO TEST |
| `lib/features/tutor_mode/domain/services/tutor_dashboard_aggregator.dart` | NO TEST |
| `lib/features/tutor_mode/presentation/screens/tutor_mode_screen.dart` | NO TEST |
| `lib/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart` | NO TEST |
| `lib/features/tutor_mode/presentation/screens/tutor_pin_setup_screen.dart` | NO TEST |
| `lib/features/tutor_mode/presentation/screens/tutor_pin_entry_screen.dart` | NO TEST |
| `lib/features/tutor_mode/presentation/screens/tutor_pin_change_screen.dart` | NO TEST |
| `lib/features/tutor_mode/presentation/providers/tutor_dashboard_providers.dart` | NO TEST |

Unit test exists: `test/features/tutor_mode/tutor_mode_read_only_test.dart`

### Story Acceptance Tests

| Test File | Status |
|---|---|
| `epic_01_foundation_test.dart` | Active, 12 stories |
| `epic_02_content_test.dart` | Needs verification |
| `epic_03_learning_cycle_test.dart` | Needs verification |
| `epic_04_multi_track_test.dart` | Active |
| `epic_05_stages_order_test.dart` | Active |
| `epic_06_scheduler_test.dart` | Active |
| `epic_07_dashboard_test.dart` | Active |
| `epic_08_gamification_test.dart` | Active |
| `epic_09_onboarding_test.dart` | Active |
| `epic_10_parent_mode_test.dart` | Active |
| `epic_11_tutor_mode_test.dart` | Active |
| `epic_12_notifications_test.dart` | Active |
| `epic_13_cloud_sync_test.dart` | Active |
| `epic_14_settings_test.dart` | Active |

---

## Phase 4: Test Infrastructure

### What Exists

| File | Purpose |
|---|---|
| `test/helpers/test_database.dart` | `createTestDatabase()`, `createTestDatabaseWithExecutor()`, `batchInsert()` |
| `test/fixtures/curriculum_fixtures.dart` | `CurriculumFixtures`, `TrackTypeFixtures`, `StageFixtures` constants |
| `test/fixtures/content_fixtures.dart` | `ContentItemFixtures` factory (mishna, daf, pasuk, container) |
| `test/fixtures/completion_fixtures.dart.skip` | Skipped / incomplete completion fixtures |
| `test/fixtures/sefaria/*.json` | Raw Sefaria API response fixtures |
| `test/mocks/mock_repositories.dart` | `MockAuthRepository`, `MockContentRepository` |
| `test/mocks/mock_services.dart` | `MockConnectivityService` |
| `test/infrastructure_test.dart` | Verifies mocks, fixtures, and DB helper work |

### What is Missing

1. **`test/helpers/test_providers.dart`** -- A shared helper to create `ProviderScope` overrides for widget tests. Should include overrides for:
   - `appDatabaseProvider`
   - `firebaseAuthProvider` (mock)
   - `activeCurriculaStreamProvider`
   - `curriculumActivationServiceProvider`
   - `accountManagementServiceProvider`
   - `userProfileServiceProvider`
   - `dashboardStreakProvider`
   - `firestoreDataSourceProvider`
   - `tutorModeProvider`

2. **`test/helpers/test_pump.dart`** -- Shared pump helpers for widget tests with auto_route and stream providers, avoiding `pumpAndSettle` hangs.

3. **`test/helpers/test_router.dart`** -- Shared authenticated/unauthenticated router factory (currently duplicated in `app_shell_test.dart`).

4. **`test/mocks/mock_firebase.dart`** -- Shared mocks for `FirebaseAuth`, `User`, `FirebaseFirestore`, `CollectionReference`, `DocumentReference`, `QuerySnapshot` (currently re-declared ad-hoc in multiple test files).

5. **`test/mocks/mock_providers.dart`** -- Shared mock Riverpod providers for common overrides.

6. **`test/fixtures/completion_fixtures.dart`** -- Completion test data factory (currently `.skip`).

7. **`test/fixtures/user_fixtures.dart`** -- Firebase User mock with configurable providerData, email, displayName.

### Recommended Patterns

- **Database tests**: Use `createTestDatabase()` in `setUp`, `db.close()` in `tearDown`. No shared state between tests.
- **Widget tests**: Use shared `createTestProviderScope(overrides: [...])` wrapper. Never use `pumpAndSettle` with stream providers -- use `pump()` + `pump(Duration)` instead.
- **Service tests**: Inject in-memory database, mock external dependencies (Firestore, Firebase Auth). Verify state changes via direct DAO queries.
- **Navigation tests**: Use `_createAuthenticatedRouter()` / `_createUnauthenticatedRouter()` from shared helper. Override all providers that screens read.
- **Mock pattern**: Use `mocktail` (no codegen). Declare mock classes in `test/mocks/` for reuse. Declare test-file-specific mocks inline only if truly one-off.

---

## Implementation Steps

### Phase 1: Fix Failures (estimated: 1-2 hours)

1. **Create shared test infrastructure first**:
   - `test/mocks/mock_firebase.dart` -- MockFirebaseAuth, MockUser, MockFirebaseFirestore, etc.
   - `test/helpers/test_providers.dart` -- createTestProviderScope() with all common overrides
   - `test/helpers/test_router.dart` -- createAuthenticatedRouter(), createUnauthenticatedRouter()
   - `test/helpers/test_pump.dart` -- pumpNavigation(), pumpProviders()

2. **Fix `settings_screen_test.dart`**:
   - Add `firebaseAuthProvider` override with mock User
   - Add `activeCurriculaStreamProvider` override
   - Add `userProfileServiceProvider` override
   - Replace `pumpAndSettle` with targeted `pump()` calls
   - Verify all 7 tests pass

3. **Fix `app_shell_test.dart`**:
   - Add missing provider overrides for each screen that gets navigated to
   - Override `firebaseAuthProvider`, `activeCurriculaStreamProvider`, etc.
   - Verify all 7 tests pass

4. **Run full suite**: `make ci` -- fix any other failures discovered

### Phase 2: Coverage Audit (estimated: 30 minutes)

1. Run `flutter test --coverage`
2. Generate HTML report
3. Document per-file coverage percentages
4. Prioritize gaps by business criticality

### Phase 3: Fill Gaps (estimated: 4-6 hours)

Priority order (highest business risk first):

1. **Core DAOs without tests** (completion_dao, bookmark_dao, goal_dao, point_config_dao, reward_dao, streak_dao, track_dao, user_profile_dao):
   - Create `test/core/database/daos/<dao>_test.dart` for each
   - Test CRUD operations, edge cases, constraints

2. **Sync layer gaps** (firestore_data_source, device_restore_service, restore_status):
   - `test/features/sync/data/firestore_data_source_test.dart`
   - `test/features/sync/domain/services/device_restore_service_test.dart`

3. **Dashboard** (dashboard_screen, dashboard_providers, widgets):
   - `test/features/dashboard/presentation/screens/dashboard_screen_test.dart`
   - `test/features/dashboard/presentation/providers/dashboard_providers_test.dart`

4. **Onboarding gaps** (bulk_prior_completion_service, suggested_thresholds_service):
   - `test/features/onboarding/domain/services/bulk_prior_completion_service_test.dart`
   - `test/features/onboarding/domain/services/suggested_thresholds_service_test.dart`

5. **Account management** (account_management_service, settings dialogs):
   - `test/features/settings/domain/services/account_management_service_test.dart`

6. **Notifications gaps** (notification_service, shabbos_time_service, reward_milestone_notification_service):
   - `test/features/notifications/domain/services/notification_service_test.dart`
   - `test/features/notifications/domain/services/shabbos_time_service_test.dart`

7. **Parent mode** (parent_dashboard_aggregator):
   - `test/features/parent_mode/domain/services/parent_dashboard_aggregator_test.dart`

8. **Tutor mode** (tutor_dashboard_aggregator, tutor_mode_provider):
   - `test/features/tutor_mode/domain/services/tutor_dashboard_aggregator_test.dart`

9. **Navigation guards** (restore_guard, pin_guard):
   - `test/core/navigation/guards/restore_guard_test.dart`
   - `test/core/navigation/guards/pin_guard_test.dart`

10. **Progress domain** (chart_data_service):
    - `test/features/progress/domain/services/chart_data_service_test.dart`

11. **Scheduler repositories** (all 4 impl files):
    - Tests for each scheduler repository impl

12. **Remaining screens** (lower priority -- screens that are simple wrappers):
    - learning_screen, progress_screen, gamification_screen, etc.

### Phase 4: Infrastructure Hardening (estimated: 1 hour)

1. Verify `test/helpers/test_providers.dart` covers all common provider overrides
2. Complete `test/fixtures/completion_fixtures.dart` (remove `.skip` suffix)
3. Add `test/fixtures/user_fixtures.dart`
4. Verify `test/mocks/` covers all commonly-mocked classes
5. Update `test/infrastructure_test.dart` to verify new helpers
6. Run `make ci` -- confirm green

---

## Dev Notes: Testing Gotchas in This Codebase

### Async Riverpod Providers
- Stream providers (`StreamProvider`, `@riverpod Stream<T>`) never "settle" -- `pumpAndSettle()` will time out after 10 seconds.
- Use `pump()` followed by `pump(Duration(milliseconds: 500))` followed by `pump()` instead.
- The existing `_pumpDashboard` pattern in `app_shell_test.dart` is the right approach, but 500ms may not be enough for deeply-nested async chains.

### Drift In-Memory Database
- Always use `NativeDatabase.memory()` -- fast, isolated, no file cleanup.
- Always call `db.close()` in `tearDown` to avoid "database already closed" errors in subsequent tests.
- The `createTestDatabase()` helper in `test/helpers/test_database.dart` handles this correctly.
- Database schema version is 9 (with migrations). In-memory databases get the full schema via `onCreate`.

### Firebase Mocking
- `FirebaseAuth` cannot be used directly in tests without `Firebase.initializeApp()`.
- Always mock `firebaseAuthProvider` in the `ProviderScope` overrides.
- For `User` objects, mock `providerData`, `email`, `displayName`, `uid` properties.
- `FirebaseFirestore` requires full mock chains: `collection() -> doc() -> collection() -> get()` etc.

### Widget Test Pumping with auto_route
- `AutoTabsScaffold` navigation is asynchronous -- need multiple `pump()` calls after tab taps.
- `DeepLink.path('/dashboard')` works in tests to set initial route.
- Navigation guards are evaluated asynchronously -- pump after router creation.

### Provider Dependencies in Widget Tests
- `SettingsScreen` has deep provider dependency chain: `firebaseAuthProvider` -> `activeCurriculaStreamProvider` -> `curriculumActivationServiceProvider` -> `appDatabaseProvider` + `firestoreDataSourceProvider` + `trackRepositoryProvider` + `tutorModeProvider`.
- Missing ANY provider in the chain will cause `ProviderException` at runtime.
- Use `.overrideWith()` for providers with dependencies, `.overrideWithValue()` for simple values.

### Test Tags
- Story acceptance tests use `@Tags(['epic_N'])` at file level and `tags: ['story_N_M']` on groups.
- Filter with `flutter test --tags story_1_2` or `make test-story-1.2`.

### Code Generation
- After changing Drift tables, Freezed models, or Riverpod providers: `dart run build_runner build --delete-conflicting-outputs`
- Generated files must be committed -- tests import `.g.dart` and `.freezed.dart` files.

---

## Files to Create

| File | Purpose |
|---|---|
| `test/mocks/mock_firebase.dart` | SharedMockFirebaseAuth, MockUser, MockFirebaseFirestore, MockCollectionReference, MockDocumentReference, MockQuerySnapshot |
| `test/helpers/test_providers.dart` | `createTestProviderScope()` with common overrides |
| `test/helpers/test_router.dart` | `createAuthenticatedRouter()`, `createUnauthenticatedRouter()` |
| `test/helpers/test_pump.dart` | `pumpNavigation()`, `pumpProviders()` |
| `test/fixtures/completion_fixtures.dart` | Rename from `.skip`, implement completion factories |
| `test/fixtures/user_fixtures.dart` | Mock Firebase User factory |
| `test/core/database/daos/completion_dao_test.dart` | DAO unit tests |
| `test/core/database/daos/bookmark_dao_test.dart` | DAO unit tests |
| `test/core/database/daos/goal_dao_test.dart` | DAO unit tests |
| `test/core/database/daos/point_config_dao_test.dart` | DAO unit tests |
| `test/core/database/daos/reward_dao_test.dart` | DAO unit tests |
| `test/core/database/daos/streak_dao_test.dart` | DAO unit tests |
| `test/core/database/daos/track_dao_test.dart` | DAO unit tests |
| `test/core/database/daos/user_profile_dao_test.dart` | DAO unit tests |
| `test/core/navigation/guards/restore_guard_test.dart` | Guard unit tests |
| `test/core/navigation/guards/pin_guard_test.dart` | Guard unit tests |
| `test/features/dashboard/presentation/screens/dashboard_screen_test.dart` | Widget tests |
| `test/features/dashboard/presentation/providers/dashboard_providers_test.dart` | Provider unit tests |
| `test/features/sync/data/firestore_data_source_test.dart` | Data source unit tests |
| `test/features/sync/domain/services/device_restore_service_test.dart` | Service unit tests |
| `test/features/onboarding/domain/services/bulk_prior_completion_service_test.dart` | Service unit tests |
| `test/features/onboarding/domain/services/suggested_thresholds_service_test.dart` | Service unit tests |
| `test/features/settings/domain/services/account_management_service_test.dart` | Service unit tests |
| `test/features/notifications/domain/services/notification_service_test.dart` | Service unit tests |
| `test/features/notifications/domain/services/shabbos_time_service_test.dart` | Service unit tests |
| `test/features/parent_mode/domain/services/parent_dashboard_aggregator_test.dart` | Service unit tests |
| `test/features/tutor_mode/domain/services/tutor_dashboard_aggregator_test.dart` | Service unit tests |
| `test/features/progress/domain/services/chart_data_service_test.dart` | Service unit tests |

## Files to Modify

| File | Changes |
|---|---|
| `test/core/navigation/app_shell_test.dart` | Add missing provider overrides, use shared helpers, fix all 7 tests |
| `test/features/settings/presentation/screens/settings_screen_test.dart` | Add firebaseAuthProvider override, replace pumpAndSettle, fix all 7 tests |
| `test/mocks/mock_repositories.dart` | Add missing mock repository classes |
| `test/mocks/mock_services.dart` | Add missing mock service classes |
| `test/infrastructure_test.dart` | Add tests for new helpers and fixtures |

---

## Summary of Gaps by Severity

### Critical (blocks Epic 15)
- **14 failing tests** in app_shell_test.dart and settings_screen_test.dart
- **8 untested DAOs** -- these are the data foundation for everything
- **Dashboard has zero tests** -- the primary screen users see
- **Account management service** untested directly

### High (high business risk)
- **Firestore data source** -- sync reliability
- **Device restore service** -- data recovery
- **Bulk prior completion service** -- onboarding flow
- **Parent/tutor dashboard aggregators** -- mode-specific dashboards
- **Chart data service** -- progress visualization

### Medium (should have before Epic 15)
- Missing test helpers and shared mocks
- Notification services (notification_service, shabbos_time_service)
- Scheduler repository implementations
- Navigation guards (restore_guard, pin_guard)

### Low (nice to have)
- Simple widget wrappers (screens that just compose other widgets)
- Provider files (tested indirectly via widget tests)
- Domain entities/models (data classes with no logic)
- Generated code (`.g.dart`, `.freezed.dart`)
