# Story 18.1: Add Track Flow — 8 Screens, One Concept Each (DNI-180 REDO)

Status: review

## Story

As a learner (or parent setting up a child),
I want a standalone "Add Track" flow with 8 screens — each asking ONE question — that can be launched from onboarding, settings, or empty states,
so that I get a clean, focused setup experience whether I'm creating my first track or my fifth.

## Acceptance Criteria

**AC-1:** `AddTrackFlow` is standalone — NO dependency on OnboardingScreen
**AC-2:** Exactly 8 screens, each with ONE concept
**AC-3:** **Program (screen 2) comes BEFORE Scope (screen 3)** — selecting a program skips scope
**AC-4:** Program screen auto-skips when no programs exist for the curriculum
**AC-5:** Content loading from bundled assets is invisible — no "import" screen
**AC-6:** Track name defaults: program name > scope name > curriculum name
**AC-7:** Bulk mark marks ALL stages complete by default, with option to mark stages separately
**AC-8:** Back navigation preserves all selections
**AC-9:** State persists across app interruption (SharedPreferences)
**AC-10:** On completion, creates track in DB with all settings applied (in transaction)
**AC-11:** No rewards step
**AC-12:** Study days uses **vertical layout** (each day on its own row)
**AC-13:** Study days (screen 4) BEFORE chazara (screen 5)
**AC-14:** Program selected → study days **auto-filled read-only** from program metadata
**AC-15:** Program **defines** chazara → stages **shown read-only**
**AC-16:** Program **leaves chazara open** → user offered **optional setup**
**AC-17:** Goal step **skipped for all program tracks**
**AC-18:** Track name **auto-fills from program displayName**
**AC-19:** Screen 8 program mode: show starting position in Hebrew from calendar (Epic 19 dependency — placeholder OK)
**AC-20:** Self-paced tracks go through full flow unchanged
**AC-21:** `ProgramSelectionStep` loads from DB via DAO — no hardcoded IDs
**AC-22:** Default study days = **all 7 days active**. Saturday displayed as "Shabbos"

## Tasks / Subtasks

### T1: Fix AddTrackStep Enum Order (AC: 3, 13)

- [x] Reorder enum in `add_track_result.dart`: `curriculum`, `program`, `scope`, `studyDays`, `chazaraSetup`, `goal`, `trackName`, `bulkMark`
- [x] Update `_buildStep()` switch statement in `add_track_flow.dart` to match new order
- [x] Run `dart run build_runner build --delete-conflicting-outputs`

### T2: Rewrite _activeSteps for Program-Aware Skipping (AC: 3, 4, 14-17, 20)

- [x] Add `_isProgramTrack` getter: `_state.programId != null`
- [x] Add `_programHasChazara` getter: parse `stagesConfig` JSON from selected program
- [x] New `_activeSteps` logic:
  - Always include: `curriculum`, `program` (auto-skip if no programs), `studyDays`, `trackName`
  - Skip `scope` if program selected
  - Skip `goal` if program selected
  - Include `chazaraSetup` always (behavior changes: read-only vs ask vs offer)
  - Include `bulkMark` always (behavior changes: bulk mark vs starting position)
- [x] Program auto-skip: use `LearningProgramDao.getProgramsByCurriculumType()` instead of hardcoded check

### T3: Rewrite ProgramSelectionStep — DB Lookup (AC: 21)

- [x] Replace hardcoded `_availablePrograms` with async DB query
- [x] Use `LearningProgramDao.getProgramsByCurriculumType(curriculum.storageKey)`
- [x] Display: program `displayName` (Hebrew) + English name from `name` field
- [x] Include "Self-paced" option at bottom
- [x] On select: store `programId`, `programName`, AND full `LearningProgram` object (for stagesConfig access)
- [x] Add `LearningProgram? selectedProgram` to `AddTrackState`

### T4: Update kDefaultStudyDays — All 7 Days Active (AC: 22)

- [x] Change `kDefaultStudyDays` to all 7 days = 'study' (no review days by default)
- [x] Update all references in `add_track_flow.dart`

### T5: Rewrite Study Days Step — Vertical + Read-Only + Shabbos (AC: 12, 14, 22)

- [x] Replace `_StudyDaysStepAdapter` horizontal FilterChips with **vertical ListTile rows**
- [x] Each row: day name on left, toggle on right
- [x] Day labels: Sun, Mon, Tue, Wed, Thu, Fri, **Shabbos** (not "Sat")
- [x] Day order: Sunday first (Jewish week)
- [x] Default: all 7 active
- [x] **Program mode:** Auto-fill from program metadata (`frequency` field in stagesConfig), display read-only with informational header "Study days set by [program name]"

### T6: Rewrite Chazara Step — Show/Offer/Ask (AC: 15, 16)

- [x] Three modes based on program:
  - **No program (self-paced):** Ask — launch `LearningProcessWizardScreen` (current behavior)
  - **Program with defined chazara (Oraysa, Dirshu*):** Show read-only — display stages from `stagesConfig` in a non-editable list
  - **Program with open chazara (Daf Yomi, Mishnah Yomis, Nach Yomi):** Offer optional — "Would you like to add review stages?" with Configure/Skip buttons
- [x] Parse `stagesConfig` JSON: if any stage has `"stage": "chazara_*"` → fully prescribed; otherwise → open

### T7: Skip Goal for Program Tracks (AC: 17)

- [x] In `_activeSteps`, remove `goal` when `_isProgramTrack`
- [x] Self-paced: show goal step as before

### T8: Auto-fill Track Name for Programs (AC: 18)

- [x] `_getSmartDefault()` already handles this (priority: programName > scope > curriculum)
- [x] Verify program displayName is stored in `_state.programName`

### T9: Screen 8 — Dual Mode: Bulk Mark vs Starting Position (AC: 7, 19)

- [x] **Self-paced mode:** Bulk mark with option to mark stages separately (enhance current behavior)
- [x] **Program mode:** Show starting position placeholder — "Today: [current daf] — Start here?" with adjust option
  - Epic 19 dependency for actual calendar position — for now show placeholder: "Starting from today's position"
  - Store starting position in `AddTrackResult` (new field: `startingRef`)

### T10: Store Program Link in DB (AC: 10)

- [x] In `TrackCreationService.createTrack()`, after transaction:
  - If `result.programId != null`, call `profileProgramDao.setProfileProgram(profileId, curriculumType, programId)`
- [x] Add `startingRef` field to `AddTrackResult` for program starting position

### T11: Fix Scope Step — Conditional + Real Hierarchy (AC: 3, 5)

- [x] Scope step only shown when `_state.programId == null`
- [x] Replace placeholder "Track All" button with real `ScopeSelectionScreen` integration (or keep placeholder if hierarchy browser not ready)

### T12: Tests (AC: 1-22)

- [x] Unit test: enum order is `curriculum, program, scope, studyDays, chazaraSetup, goal, trackName, bulkMark`
- [x] Unit test: program auto-skip when no programs for curriculum
- [x] Unit test: scope skipped when program selected
- [x] Unit test: goal skipped when program selected
- [x] Unit test: default study days = all 7 active
- [x] Widget test: study days vertical layout with "Shabbos" label
- [x] Widget test: ProgramSelectionStep loads from DB (mock DAO)
- [x] Widget test: chazara read-only mode for prescribed programs
- [x] Widget test: chazara offer mode for open programs
- [x] Unit test: smart track name defaults
- [x] Unit test: program-aware _activeSteps filtering

## Dev Notes

### Architecture

- **Feature module:** `lib/features/track_setup/` — clean architecture (data/domain/presentation)
- **Pattern:** PageView + NeverScrollableScrollPhysics, PopScope for back nav, local AddTrackState (Freezed)
- **Key principle:** Each screen = ONE concept. "Show don't ask" for program-defined settings.

### Step Order (CORRECTED)

```
curriculum → program → scope → studyDays → chazaraSetup → goal → trackName → bulkMark
```

Program before scope. If program selected: skip scope, auto-fill study days, show/offer chazara, skip goal, auto-fill name.

### Program Prescription Levels

| Program | Curriculum | Chazara | Behavior |
|---------|-----------|---------|----------|
| Oraysa | bavli | 4 stages (next-day, weekly, rolling) | Fully prescribed |
| Dirshu Kinyan Torah | bavli | 3 stages (1d, 7d, 21d) | Fully prescribed |
| Dirshu Amud HaYomi | bavli | 3 stages (1d, 7d, 21d) | Fully prescribed |
| Dirshu Kinyan Yerushalmi | yerushalmi | 3 stages (1d, 7d, 21d) | Fully prescribed |
| Dirshu DhYB | mishna_berurah | 1 stage (7d) | Fully prescribed |
| Dirshu Kinyan Chochma | mussar | 2 stages (1d, 7d) | Fully prescribed |
| Daf Yomi | bavli | none (learn only) | Open chazara |
| Mishnah Yomis | mishnayos | none (learn only) | Open chazara |
| Nach Yomi | nach | none (learn only) | Open chazara |

### Key Files to Modify

| File | Change |
|------|--------|
| `lib/features/track_setup/domain/entities/add_track_result.dart` | Reorder enum, add `selectedProgram` and `startingRef` fields |
| `lib/features/track_setup/presentation/screens/add_track_flow.dart` | Rewrite `_activeSteps`, `_buildStep`, adapters |
| `lib/features/track_setup/presentation/widgets/program_selection_step.dart` | DB lookup instead of hardcoded |
| `lib/features/track_setup/domain/services/track_creation_service.dart` | Add profile_programs insert, update kDefaultStudyDays |

### Key Files to Read (DO NOT modify unless required)

| File | Why |
|------|-----|
| `lib/core/database/daos/learning_program_dao.dart` | `getProgramsByCurriculumType()` method |
| `lib/core/database/daos/profile_program_dao.dart` | `setProfileProgram()` for linking profile to program |
| `lib/core/database/seed/learning_program_seeds.dart` | All 9 programs with stagesConfig JSON |
| `lib/core/database/tables/learning_programs.dart` | Schema: stagesConfig, isCalendarProgram |

### stagesConfig JSON Structure

```json
// Daf Yomi (open chazara — learn only):
[{"stage": "learn", "pace": "one_daf", "frequency": "daily"}]

// Dirshu Kinyan Torah (fully prescribed):
[
  {"stage": "learn", "pace": "one_daf", "frequency": "daily"},
  {"stage": "chazara_1", "delay_days": 1},
  {"stage": "chazara_2", "delay_days": 7},
  {"stage": "chazara_3", "delay_days": 21}
]
```

**Detecting chazara:** `stages.any((s) => s['stage'].toString().startsWith('chazara'))` → fully prescribed if true, open if false.

### Critical Constraints

- All DB writes in transaction (already done in TrackCreationService)
- Completions are append-only
- DateTime always UTC
- Domain entity must NOT import presentation files (use `Object?` for opaque types)
- No cross-feature module imports
- `_finishFlow()` must have try/catch, clear state only on success (already done)
- Study days stored as ISO weekday (1=Mon...7=Sun)

### Previous Implementation Issues (from code review)

1. Step order was scope→program (now program→scope)
2. Study days were Mon-Fri (now all 7 active)
3. Study days were horizontal chips (now vertical list)
4. ProgramSelectionStep was hardcoded (now DB lookup)
5. No program-aware mode (now show-don't-ask pattern)
6. Blank grey screen from Hub (PageView null guard added in `bc8565a`)

### References

- [Source: docs/developer-guide.md] — Domain concepts, curricula, track model, programs
- [Source: _bmad-output/project-context.md] — Coding standards, patterns
- [Source: _bmad-output/planning-artifacts/architecture.md] — Architecture decisions
- [Linear: DNI-180] — Full ticket with program-aware behavior summary

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
