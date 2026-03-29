# Story 18.4: Hebrew Terms for Chazara & Curriculum Names (DNI-169)

Status: review

## Story

As a learner familiar with traditional Jewish learning terminology,
I want the app to use Hebrew terms for review stages and display curriculum names in Hebrew,
so that the interface uses the vocabulary I already know.

## Acceptance Criteria

**AC-1: Default stage names use Hebrew**
**Given** a new track is created (via AddTrackFlow or wizard)
**When** default stages are applied
**Then** they are named: לימוד, חזרה א׳, חזרה ב׳

**AC-2: Curriculum names display in Hebrew**
**Given** the user views curriculum selection, dashboard cards, settings, or scope selection
**When** curriculum names are shown
**Then** they display using `CurriculumId.displayNameHe` (e.g., משניות not Mishnayos)

**AC-3: Dashboard task labels use Hebrew stage names**
**Given** the dashboard shows today's tasks
**When** displaying stage context
**Then** tasks show the `stageName` from the database (now Hebrew)
**And** the hardcoded `'Learn'` fallback in `DailyTaskCard` is removed

**AC-4: Learning process wizard presets use Hebrew**
**Given** the user is configuring chazara stages via the custom builder
**When** viewing the step 3 summary or round timing cards
**Then** stage labels show Hebrew: לימוד, חזרה א׳/ב׳/ג׳

**AC-5: Existing data migrated**
**Given** tracks with English default stage names
**When** the app updates and runs schema migration
**Then** default stage names are migrated to Hebrew equivalents
**And** user-customized stage names are NOT changed
**And** the migration is idempotent

## Tasks / Subtasks

### T1: Create Hebrew Terms Constants (AC: 1-4)

- [x] Create `lib/core/constants/hebrew_terms.dart` with:
  - `getDefaultStageName(int stageOrder)` — returns לימוד, חזרה א׳, חזרה ב׳, etc.
  - `_hebrewNumeral(int n)` helper for dynamic numbering (א׳, ב׳, ג׳, ד׳, ה׳)
  - Hebrew term mapping constants
- [x] Create `test/core/constants/hebrew_terms_test.dart`

### T2: Update Default Stage Names (AC: 1)

- [x] Update `CurriculumDefaults.defaultStages` in `lib/core/constants/curriculum_defaults.dart` to use Hebrew names
- [x] Update `LearningProcessWizardService._applyCustom()` — stage 1 as `'לימוד'`
- [x] Update `LearningProcessWizardService._applyNoReview()` — stage 1 as `'לימוד'`
- [x] Update `_onCustomConfirmed()` in wizard screen — labels like `'חזרה א׳'` instead of `'Chazara 1'`
- [x] Update `_RoundTimingCard` title — Hebrew labels

### T3: Switch UI to displayNameHe (AC: 2)

- [x] Dashboard `_TaskItemCard` — switch to `displayNameHe`
- [x] Dashboard `_CurriculumCard` — switch to `displayNameHe`
- [x] `CurriculumSettingsScreen` AppBar — switch to `displayNameHe`
- [x] 30+ additional files switching `displayNameEn` to `displayNameHe` in UI contexts:
  - Content browsing screens (curriculum list, content hierarchy, content search, breadcrumb navigation)
  - Learning screen (learning screen, bookmark card)
  - Scheduler widgets (daily task card, grouped daily view, study day config)
  - Progress screens (curriculum progress, progress charts, progress screen, journey views)
  - Parent mode screens (parent mode, parent track management, point config, curriculum card, recent completions)
  - Tutor mode (tutor dashboard)
  - Gamification (points display widget)
  - Onboarding (bulk mark, learning process wizard, mode selection)
  - Settings (scope selection)
  - Stages (stage definition repository)
  - Learning order screen

### T4: Remove Hardcoded English Stage Fallback (AC: 3)

- [x] Remove `stageOrder == 1 ? 'Learn' : task.stageName` fallback in `DailyTaskCard` — use `stageName` directly

### T5: Update Seed Data (AC: 4)

- [x] Update `learning_program_seeds.dart` — all label strings to Hebrew
- [x] Update all `stages_config` JSON entries with Hebrew labels

### T6: Schema Migration for Existing Data (AC: 5)

- [x] Add migration step in `app_database.dart` to update English stage names to Hebrew
- [x] Migration maps: Learn -> לימוד, Chazara 1 -> חזרה א׳, Chazara 2 -> חזרה ב׳, etc.
- [x] Custom user names left untouched
- [x] Migration is idempotent (safe to run multiple times)
- [x] Create `test/core/database/hebrew_migration_test.dart`

### T7: Update Tests (AC: 1-5)

- [x] Update `curriculum_defaults_test.dart` for Hebrew stage names
- [x] Update `daily_task_card_test.dart` for removed fallback
- [x] Update `curriculum_list_screen_test.dart` for Hebrew display names
- [x] Update `breadcrumb_navigation_test.dart` for Hebrew names
- [x] Update `points_display_widget_test.dart` for Hebrew names
- [x] Update `journey_widgets_test.dart` for Hebrew names
- [x] Update `daily_schedule_widgets_test.dart` for Hebrew names
- [x] Update `curriculum_picker_step_test.dart` for Hebrew names
- [x] Update `add_track_result_test.dart` for Hebrew names
- [x] Update fixtures in `curriculum_fixtures.dart`
- [x] Update acceptance tests: epic_01, epic_02, epic_05, epic_07, epic_10, epic_11, epic_15, epic_18

## Dev Notes

### Architecture

- **Central constants:** `hebrew_terms.dart` provides all Hebrew term mappings, referenced by all other files
- **displayNameEn stays** — not removed, still used for internal logging/debugging; only UI-facing references switched to `displayNameHe`
- **Seed data is insert-only** — updating seeds only affects fresh installs; existing users need schema migration
- **RTL handling:** Flutter handles bidirectional text natively; no Directionality widget changes needed

### Key Files

| File | Path | Role |
|------|------|------|
| Hebrew Terms | `lib/core/constants/hebrew_terms.dart` | Central Hebrew term constants + helpers |
| Curriculum Defaults | `lib/core/constants/curriculum_defaults.dart` | Default stage definitions (now Hebrew) |
| Wizard Service | `lib/features/onboarding/domain/services/learning_process_wizard_service.dart` | Stage creation logic |
| Wizard Screen | `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | Wizard UI |
| Daily Task Card | `lib/features/scheduler/presentation/widgets/daily_task_card.dart` | Task display |
| Dashboard | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Curriculum cards + task items |
| App Database | `lib/core/database/app_database.dart` | Schema migration |
| Seed Data | `lib/core/database/seed/learning_program_seeds.dart` | Program presets |

### Hebrew Term Mapping

| English | Hebrew |
|---------|--------|
| Learn | לימוד |
| Chazara 1 | חזרה א׳ |
| Chazara 2 | חזרה ב׳ |
| Chazara 3 | חזרה ג׳ |
| Review | חזרה |
| Next-Day Review | חזרה יום למחרת |
| Weekly Review | חזרה שבועית |
| Rolling Back-20 | חזרה מתגלגלת |

### Critical Constraints

- `displayNameHe` already existed on `CurriculumId` enum — this ticket switches all UI-facing references
- 85+ occurrences of `displayNameEn` across 40+ files — all UI-facing ones switched
- Seed data changes only affect fresh installs; migration handles existing users
- `stageName` is a free-text field — display layer renders whatever is stored

### Testing Standards

- Unit tests for hebrew_terms.dart helpers
- Widget tests verifying Hebrew text renders in task cards and curriculum cards
- Migration tests verifying English-to-Hebrew conversion and idempotency

### References

- [Source: docs/developer-guide.md#Jewish Learning Concepts] — Hebrew terminology
- [Source: _bmad-output/project-context.md#Material Design 3 & UI] — RTL support

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Created `hebrew_terms.dart` with `getDefaultStageName()`, `_hebrewNumeral()`, and full term mapping. Tests cover all 9 curricula and stage naming.
- T2: Updated `CurriculumDefaults.defaultStages` to Hebrew. Updated wizard service `_applyCustom()` and `_applyNoReview()`. Updated wizard screen `_onCustomConfirmed()` and `_RoundTimingCard`.
- T3: Switched 35+ files from `displayNameEn` to `displayNameHe` across all UI layers — dashboard, content browsing, learning, scheduler, progress, parent mode, tutor mode, gamification, onboarding, settings, stages.
- T4: Removed hardcoded `'Learn'` fallback from `DailyTaskCard` — now uses `stageName` directly from DB.
- T5: Updated all seed data labels in `learning_program_seeds.dart` to Hebrew.
- T6: Added schema migration in `app_database.dart` — maps English stage names to Hebrew equivalents. Custom names preserved. Idempotent. Migration test created.
- T7: Updated 20+ test files across unit, widget, and acceptance test layers for Hebrew names.

### Change Log

- 2026-03-29: Test fixes for Hebrew display names. Commits `b99ef79`, `7fc3c88`.
- 2026-03-29: Initial implementation — Hebrew terms, UI switchover, migration, seed data. Commit `0be7dc2`.

### File List

**Created:**
- `lib/core/constants/hebrew_terms.dart`
- `test/core/constants/hebrew_terms_test.dart`
- `test/core/database/hebrew_migration_test.dart`

**Modified (35+ files):**
- `lib/core/constants/curriculum_defaults.dart`
- `lib/core/database/app_database.dart`
- `lib/core/database/seed/learning_program_seeds.dart`
- `lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart`
- `lib/features/content_browsing/presentation/screens/content_search_screen.dart`
- `lib/features/content_browsing/presentation/screens/curriculum_list_screen.dart`
- `lib/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart`
- `lib/features/gamification/presentation/widgets/points_display_widget.dart`
- `lib/features/learning/presentation/screens/learning_screen.dart`
- `lib/features/learning/presentation/widgets/bookmark_card.dart`
- `lib/features/learning_order/presentation/screens/learning_order_screen.dart`
- `lib/features/onboarding/domain/services/learning_process_wizard_service.dart`
- `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart`
- `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart`
- `lib/features/parent_mode/presentation/screens/parent_mode_screen.dart`
- `lib/features/parent_mode/presentation/screens/parent_track_management_screen.dart`
- `lib/features/parent_mode/presentation/screens/point_config_screen.dart`
- `lib/features/parent_mode/presentation/widgets/curriculum_card.dart`
- `lib/features/parent_mode/presentation/widgets/recent_completions_list.dart`
- `lib/features/progress/presentation/providers/journey_providers.dart`
- `lib/features/progress/presentation/screens/curriculum_progress_screen.dart`
- `lib/features/progress/presentation/screens/progress_charts_screen.dart`
- `lib/features/progress/presentation/screens/progress_screen.dart`
- `lib/features/progress/presentation/widgets/journey_grouped_view.dart`
- `lib/features/progress/presentation/widgets/journey_timeline_view.dart`
- `lib/features/scheduler/presentation/screens/study_day_config_screen.dart`
- `lib/features/scheduler/presentation/widgets/daily_task_card.dart`
- `lib/features/scheduler/presentation/widgets/grouped_daily_view.dart`
- `lib/features/settings/presentation/screens/curriculum_settings_screen.dart`
- `lib/features/settings/presentation/screens/scope_selection_screen.dart`
- `lib/features/stages/data/repositories/stage_definition_repository_impl.dart`
- `lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart`
- `lib/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart`
- `test/core/constants/curriculum_defaults_test.dart`
- `test/fixtures/curriculum_fixtures.dart`
- 15+ acceptance and widget test files updated
