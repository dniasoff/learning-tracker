# Story 18.4: Hebrew Terms for Chazara & Curriculum Names

Status: ready-for-dev

## Story

As a learner familiar with traditional Jewish learning terminology,
I want the app to use חזרה (not "Review") for review stages and display curriculum names in Hebrew,
so that the interface uses the vocabulary I already know.

## Acceptance Criteria

**AC-1: Default stage names use Hebrew**
**Given** a new track is created
**When** default stages are applied
**Then** they are named: לימוד, חזרה א׳, חזרה ב׳

**AC-2: Curriculum names display in Hebrew**
**Given** the user views curriculum selection, dashboard, or settings
**When** curriculum names are shown
**Then** they display in Hebrew (e.g., משניות not Mishnayos)

**AC-3: Dashboard task labels use Hebrew stage names**
**Given** the dashboard shows today's tasks
**When** displaying stage context
**Then** tasks show "חזרה א׳" not "Chazara 1" or "Review 1"

**AC-4: Learning process wizard presets use Hebrew**
**Given** the user is configuring חזרה stages
**When** viewing preset options
**Then** presets use Hebrew stage names (עיון, בקיאות, etc.)

**AC-5: Existing data migrated**
**Given** tracks with English default stage names
**When** the app updates
**Then** default stage names are migrated to Hebrew equivalents
**And** user-customized stage names are NOT changed

## Tasks / Subtasks

### T1: Create Hebrew Terms Constants (AC: 1-4)

- [ ] Create `lib/core/constants/hebrew_terms.dart` with:
  - Stage name map: `{'Learn': 'לימוד', 'Chazara 1': 'חזרה א׳', 'Chazara 2': 'חזרה ב׳', 'Iyun': 'עיון', 'Bekius': 'בקיאות'}`
  - Curriculum display name map: `{'mishnayos': 'משניות', 'bavli': 'תלמוד בבלי', 'yerushalmi': 'תלמוד ירושלמי', 'chumash': 'חומש', 'nach': 'נ"ך', 'tanach': 'תנ"ך', 'mishna_berurah': 'משנה ברורה', 'mussar': 'מוסר', 'torah': 'תורה'}`
  - Helper: `String getCurriculumDisplayName(CurriculumId id)` returns Hebrew name
  - Helper: `String getDefaultStageName(int stageIndex)` returns Hebrew name

### T2: Update Default Stage Definitions (AC: 1)

- [ ] Update default stage names in `LearningProcessWizardService` or wherever defaults are created
- [ ] Default stages: Stage 0 = "לימוד", Stage 1 = "חזרה א׳", Stage 2 = "חזרה ב׳"
- [ ] Update wizard presets to use Hebrew names

### T3: Update Curriculum Display Names (AC: 2)

- [ ] Find all places `CurriculumId` is displayed as text (dashboard, settings, onboarding, scope selection)
- [ ] Replace English display names with Hebrew using `getCurriculumDisplayName()`
- [ ] Keep English IDs (`mishnayos`, `bavli`, etc.) unchanged — only display names change
- [ ] Key files to update:
  - Dashboard widgets showing curriculum names
  - Settings/CurriculumList screen
  - Onboarding curriculum selection
  - `getCurriculumColor()` helper (if it uses display names)

### T4: Update Dashboard Task Labels (AC: 3)

- [ ] Update task display widgets to show Hebrew stage names
- [ ] Tasks should show "חזרה א׳" not "Chazara 1" or "Review 1"
- [ ] Ensure RTL handling for Hebrew text in mixed-language context

### T5: Update Learning Process Wizard Presets (AC: 4)

- [ ] Update preset definitions in `learning_process_wizard_screen.dart`:
  - Standard preset stages: לימוד → חזרה א׳ → חזרה ב׳
  - In-depth presets: עיון, בקיאות
- [ ] Update any hardcoded English stage names in wizard UI

### T6: Data Migration for Existing Users (AC: 5)

- [ ] Write schema migration that updates existing stage definitions:
  - Find stage definitions where name matches English defaults: "Learn", "Chazara 1", "Chazara 2", "Review 1", "Review 2"
  - Replace with Hebrew equivalents
  - Leave user-customized names untouched (anything not matching defaults)
- [ ] Migration detection: compare against known English default names
- [ ] Bump schema version

### T7: Tests (AC: 1-5)

- [ ] Unit tests for `hebrew_terms.dart` helpers
- [ ] Unit tests for data migration (English defaults → Hebrew)
- [ ] Unit tests: user-customized names NOT changed by migration
- [ ] Widget tests: curriculum names display in Hebrew on dashboard
- [ ] Widget tests: stage names display in Hebrew in task labels
- [ ] Visual verification: no layout breakage from Hebrew characters (RTL handling)

## Dev Notes

### Scope Boundaries

**IN scope:** Domain-specific terms (stage names, curriculum names)
**NOT in scope:** UI labels (buttons, headers), "Track", "Goal", "Pace", "Streak", i18n framework

### Key Files to Modify

| File | Change |
|------|--------|
| `lib/core/constants/hebrew_terms.dart` | Create — central Hebrew terms |
| Stage definition seed/defaults | Update default names |
| `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | Preset names |
| Dashboard task widgets | Stage name display |
| Curriculum display helpers | Hebrew names |
| `lib/core/database/app_database.dart` | Schema migration |

### Critical Constraints

- Keep English IDs everywhere (database, Firestore, code) — only change display strings
- RTL handling: Hebrew text in widgets needs `Directionality` or proper `TextDirection`
- Migration must be idempotent (safe to run multiple times)

### References

- [Source: docs/developer-guide.md#jewish-learning-concepts-for-the-uninitiated]
- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
