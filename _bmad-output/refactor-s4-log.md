# Refactor S4 Log — Tracks & Completion Stream

Stream: S4 (Tracks & Completion)
Plan: docs/planning/tech-debt-remediation-plan.md v3.3
Tracker: _bmad-output/refactor-task-tracker.md

---

## [2026-05-20 03:30] task-complete
- task: W2.1-W2.9
- commit: 798013e6 / 8ea02b0b
- detail: Created features/tracks/ cluster by copying track_setup→tracks/setup, learning_order→tracks/whole_curriculum_order, track_learning_order→tracks/track_order, stages→tracks/stages. Updated internal cross-references (all `features/track_setup/**`, `features/learning_order/**`, `features/track_learning_order/**`, `features/stages/**` import paths replaced within the new cluster). Added curriculum_activation_service.dart to tracks/domain/services (W2.7). Created tracks.dart barrel exporting the full public surface (W2.8). Original directories preserved until P2 gate. W2.9 (importer migration) deferred to when the barrel lint is enforced by S1's W1.11.
- next: W4.6 (PaceTarget sealed VO — already partially done in goal_entity.dart)

## [2026-05-20] task-complete
- task: W4.7 (ProgramStartingPosition VO + B2 enforcement)
- commit: c5b78eff
- detail: Created core/domain/value_objects/program_starting_position.dart with `create({startDate, today, sefariaRef})` factory (throws StartDateWindowException outside [today-30, today]), `allowedWindow(today)` static, `daysFromToday(today)`, `fromLegacyGrammar` bridge, `toLegacyGrammar` compat. Created core/exceptions/validation_exception.dart abstract base. 20 B2 regression tests all pass.

## [2026-05-20] task-complete
- task: W4.10 (ScheduleSpec sealed VO)
- commit: 55918c7a
- detail: Created core/domain/value_objects/schedule_spec.dart with sealed class ScheduleSpec { DelaySchedule, WeeklySchedule, RollingSchedule } + ScheduleSpec.fromParts() bridge. Updated all three affected sites: (1) StageDefinitionRepository.addStage() now takes `ScheduleSpec schedule` param; (2) DefaultStageDefinition carries `ScheduleSpec schedule`; (3) StageDefinition exposes `.schedule` via StageDefinitionScheduleSpec extension. All 43 relevant tests pass (stage unit + integration + epic_05 acceptance + new ScheduleSpec.fromParts round-trip group). step_chazara namespace fix included.
- next: W3.44 (goal model collapse)

## [2026-05-20] task-complete
- task: W3.44 (goal model collapse — PaceTarget sealed VO)
- commit: (pending)
- detail: Collapsed GoalRepository interface: createGoal/updateGoal now accept `PaceTarget?` (DeadlineTarget | PacePeriodTarget | null) instead of the raw quartet (goalType/paceValue/pacePeriod/targetDate). GoalRepositoryImpl._decomposePaceTarget() decomposes back to raw DB columns on write. ComputePaceStatusUseCase now takes PaceTarget? in PaceStatusInput (removed Goal row dependency). dashboard_providers + parent_dashboard_aggregator reconstruct PaceTarget from raw Drift Goal row. TrackEditService.editTrack signature updated to PaceTarget? / clearPaceTarget. edit_track_screen (both copies) build PaceTarget from screen state. 21 W3.44 regression tests all pass (12 goal_repository_impl + 9 compute_pace_status_use_case). 434 affected-suite tests pass with no regressions.
- next: W4.12 (TrackBlueprint aggregate)
