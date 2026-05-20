# Refactor S2 Log — Sync & Data Stream

Stream: S2 (Sync & Data)
Plan: docs/planning/tech-debt-remediation-plan.md v3.3
Tracker: _bmad-output/refactor-task-tracker.md

---

## [2026-05-20 04:00] task-complete
- task: W2.21
- commit: ec458dbd
- detail: Moved core/learning/ → features/learning/. CompletionCommand → features/learning/domain/entities/. CompletionWriter → features/learning/data/. completion_writer_providers → features/learning/presentation/providers/. Updated all 11 import sites. core/learning/ directory removed.
- next: W2.22

## [2026-05-20 04:10] task-complete
- task: W2.22
- commit: 92125f82
- detail: Moved 5 streak files (StreakEvent, StreakEventLog, StreakReducer, StreakRestorer, StreakStateProvider) from core/streak/ to features/gamification/streak/. Updated 4 external import sites. core/streak/ directory removed.
- next: W2.23

## [2026-05-20 04:25] task-complete
- task: W2.23
- commit: 21e9c357
- detail: Moved CalendarProgramRegistry, CalendarProgramService, LocalCalendarEngine, DailyScheduleComposer, CrossCurriculumAggregator from core/services/ to features/scheduler/domain/services/. Updated all import sites. "sacred_calendar" in the plan maps to scheduler/domain/services (no dedicated feature existed for these files).
- next: W2.24

## [2026-05-20 04:30] task-complete
- task: W2.24 + W2.25
- commit: f99aee14
- detail: Moved PinService → features/profiles/domain/services/ and LearningProgramService → features/scheduler/domain/services/ (also needed for W2.25). Updated all import sites. core/services/ directory is now empty and removed. P2 trigger from S2 side complete (W2.25 done).
- next: W2.26

## [2026-05-20 05:00] task-complete
- task: W2.26
- commit: (part of prior session)
- detail: Added LearningOrderMerger in core/sync/merge/. Added EntityKind.learningOrder constant. Added case in MergeRouter switch. Added _upsertLearningOrder helper + currentUpdatedAt case in DriftMergeStore. Added LearningOrderMerger to mergeRouterProvider. Closes C3/H3.
- next: W2.27

## [2026-05-20 05:30] task-complete
- task: W2.27
- detail: Created 5 new mergers + 5 new PullPipeline channels:
  * GoalMerger (core/sync/merge/goal_merger.dart) — injects UserDatabase, delegates to goalDao.upsertGoalByTrack, LWW by updatedAt inside DAO.
  * LearningLedgerMerger (core/sync/merge/learning_ledger_merger.dart) — append-only, uses learningLedgerDao.insertEntry (INSERT OR IGNORE on ulid). FK-guards against orphaned profileIds.
  * NotificationSettingsMerger (core/sync/merge/notification_settings_merger.dart) — SharedPreferences-backed, LWW, writes daily_reminder/streak_alert/reward_notification keys.
  * GamificationSettingsMerger (core/sync/merge/gamification_settings_merger.dart) — merges points_config rows into Drift via pointConfigDao; reward_settings delegated via RewardSettingsMergeDelegate callback (null for now; features-layer wiring deferred to W2.31 to avoid core→features import).
  * UiPreferencesMerger (core/sync/merge/ui_preferences_merger.dart) — SharedPreferences-backed, uses ProfileScopedPreferenceKeys, handles sacred_time for profileId==0.
  Added 5 EntityKind constants (goal, learningLedger, notificationSettings, gamificationSettings, uiPreferences). Added 5 case labels to MergeRouter. Added 5 pull methods to PullPipeline (pullGoals, pullLearningLedger via _pullCollection; pullNotificationSettings, pullGamificationSettings, pullUiPreferences via new _pullDocument helper wrapping fetchDocument). Wired all 5 in mergeRouterProvider.
  Also fixed 30+ test files with stale import paths from W2.21-W2.25 moves (core/learning/, core/streak/, core/services/ → new features/ locations). Updated allow-list in epic_25_story_25_9_lints_test.dart for S4-added files.
  Closes M1.
- next: W2.28

## [2026-05-20 04:30] sync-point-cleared (S2 side only)
- sync-point: P2 (S2 contribution)
- detail: S2's W2.21-W2.25 are all done. Per protocol, must verify S3 (W2.10-W2.20) and S4 (W2.1-W2.9) before proceeding past W2.30 to W2.31. S4 W2.1-W2.9 confirmed done in tracker. S3 W2.10-W2.20 still in-progress. Proceeding with W2.26-W2.30 (mergers) which don't require P2 themselves; will check tracker again before W2.31.
