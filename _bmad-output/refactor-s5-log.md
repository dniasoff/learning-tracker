# Refactor S5 Log — Domain VOs, Class Cleanup, Polish

Stream: S5 (Domain VOs, Class Cleanup, Polish)
Plan: docs/planning/tech-debt-remediation-plan.md v3.3
Tracker: _bmad-output/refactor-task-tracker.md

---

## S5 / S5-continuation-A (2026-05-20)

### W4.19 — Extract SaveLearningOrderUseCase [DONE]
- Created `features/tracks/whole_curriculum_order/domain/use_cases/save_learning_order_use_case.dart`
- Added `saveLearningOrderUseCaseProvider` to `learning_order_providers.dart`
- Updated `learning_order_screen.dart` to call the use case instead of the repository directly
- Commit: `refactor(W4.19): extract SaveLearningOrderUseCase from LearningOrderRepositoryImpl`

### W4.21 — Fix notification_providers.dart to use constants [DONE]
- Replaced 8 undefined string-literal keys with `NotificationPreferencesRepository.*Key` static constants
- Added `show NotificationPreferencesRepository` import; removed unused import
- Commit: `refactor(W4.21): wire notification_providers.dart to NotificationPreferencesRepository constants`

### W4.22 — Move _buildMasechtosIndex → MasechtaOrderingPolicy [BLOCKED]
- Blocked: depends on W4.15 (S4 task, not yet done). Logged as task-blocked in tracker.

### W4.23 — Add ProfileSession aggregate [DONE]
- Created `features/profiles/domain/models/profile_session.dart` with `ProfileSession` value class
- Added `profileSessionProvider` Riverpod provider (keepAlive: true) wrapping `selectedProfileIdProvider`
- Regenerated `profile_providers.g.dart`
- Commit: `refactor(W4.23): introduce ProfileSession domain aggregate for SelectedProfileId`

### W4.24 — Move side-effect from read provider to write-path [DONE]
- Extracted `stripStockMilestonesEffectProvider` as separate `@riverpod Future<void>` write-path provider
- Removed inline `milestoneService.stripStockTemplateMilestones()` from `dashboardChildNextReward` read provider
- Read provider now awaits the effect provider's future
- Regenerated `dashboard_providers.g.dart`
- Commit: `refactor(W4.24): move strip-stock-milestones side-effect out of read provider`

### W7.1 + W7.4 — Re-parent exceptions under AppException hierarchy [DONE]
- Re-parented 18 exception classes across 16 files under the 6 AppException category bases
- `DuplicateCompletionException` → ConflictException
- `SeedManagerException` → InternalException
- `MaxAccountsReachedException` → ValidationException
- `SefariaApiException` → NetworkException (cause field from NetworkException)
- `ContentDownloadException`, `ContentLoadException` → NetworkException
- `DuplicateEmailException` → ConflictException; `InvalidCredentialsException` → PermissionException; `InvalidInputException` → ValidationException
- `EmailCollisionException` → ConflictException; `UpgradePasswordMismatchException` → PermissionException; `UpgradeEmailNotVerifiedException` → ValidationException
- `MaxProfilesExceededException`, `LastProfileException` → ValidationException; `DuplicateProfileNameException` → ConflictException
- `PinLockoutException` → PermissionException
- `ParentControlException` (both locations) → PermissionException
- `StageProgressionException` → ValidationException; `ChildSelfMarkException` → PermissionException
- `ProtectedStageException`, `StageLimitExceededException` (both locations) → ValidationException
- `LastActiveCurriculumException` → ValidationException
- W7.4: Created `core/exceptions/invalid_track_operation_exception.dart` (extends ValidationException); `track_repository.dart` re-exports it; `track_dao.dart` throws it directly; removed local `InvalidOperationException` class
- Commit: `refactor(W7.1+W7.4): re-parent exception classes under AppException hierarchy`

### W7.2 — Add MergeException, OutboxDeadLetterException, FirestorePermissionDeniedException [DONE]
- Created `core/sync/exceptions/merge_exception.dart` (extends InternalException)
- Created `core/sync/exceptions/outbox_dead_letter_exception.dart` (extends NetworkException)
- Created `core/sync/exceptions/firestore_permission_denied_exception.dart` (extends PermissionException)
- Commit: `refactor(W7.2): add MergeException, OutboxDeadLetterException, FirestorePermissionDeniedException`

### W7.3 — Move BatchPushException → SyncPushException [DONE]
- Created `core/sync/exceptions/sync_push_exception.dart` (extends NetworkException)
- `firestore_gateway.dart`: added import + re-export of SyncPushException; `typedef BatchPushException = SyncPushException` for backward compat
- `firestore_gateway_impl.dart`: throws SyncPushException directly
- Key fix: `export` alone doesn't bring a symbol into scope within the file; needed both `import` and `export`
- Commit: `refactor(W7.3): move BatchPushException → SyncPushException under NetworkException`

---

## S5-continuation-B (2026-05-20)

### W7.12 — Add firebase_analytics to pubspec.yaml [DONE]
- Added `firebase_analytics: ^12.3.0` under Firebase dependencies (after `firebase_crashlytics: ^5.2.0`)
- First attempt with `^11.4.0` failed due to `firebase_core_platform_interface` version conflict with `firebase_crashlytics ^5.2.0`; fixed by using `^12.3.0`
- Commit: `feat(W7.12): add firebase_analytics ^12.3.0 to pubspec.yaml`

### W7.13 — Create FirebaseAnalyticsService [DONE]
- Created `core/analytics/firebase_analytics_service.dart` wrapping `FirebaseAnalytics.instance`
- Type fix: Firebase requires `Map<String, Object>` (non-nullable values); converts `Object?` → `Object` by substituting `''` for nulls
- Updated `core/analytics/analytics_provider.dart`: uses `FirebaseAnalyticsService` in release/profile, `LoggingAnalyticsService` in debug
- Updated `app/bootstrap/analytics_bootstrap.dart`: same kDebugMode guard
- Commit: `feat(W7.13): create FirebaseAnalyticsService; LoggingAnalyticsService as debug fallback`

### W7.14 — Route runZonedGuarded errors to Crashlytics [DONE]
- Added module-level `CrashlyticsService _crashlytics = const NullCrashlyticsService()` in `main.dart` so zone error handler can reference it before async init completes
- Set `_crashlytics = crashlytics` after bootstrap; zone handler calls `_crashlytics.recordError(error, stack, fatal: true)`
- Added `crashlyticsServiceProvider.overrideWithValue(crashlytics)` to ProviderContainer overrides
- Commit: `feat(W7.14-W7.16): route zone errors + FlutterFatalError to Crashlytics; non-fatal listener errors`

### W7.15 — Fire crash_reported from recordFlutterFatalError [DONE]
- Modified `FirebaseCrashlyticsService.recordFlutterFatalError` to call `unawaited(_analytics.logCrashReported(fatal: true))` before delegating to Firebase
- Same commit as W7.14

### W7.16 — Route ListenerSupervisor._onError to Crashlytics non-fatal [DONE]
- Created `core/providers/crashlytics_provider.dart` with default `NullCrashlyticsService`
- Added `CrashlyticsService? crashlytics` parameter to `SyncOrchestratorImpl`; `_onListenerError` calls `_crashlytics?.recordError(error, stackTrace, fatal: false)`
- Updated `sync_orchestrator_providers.dart` to read `crashlyticsServiceProvider` and pass it to the impl
- Same commit as W7.14

### W7.17 — Create AppErrorView widget [DONE]
- Created `core/widgets/app_error_view.dart` with `AppErrorView` widget and `AppErrorView.fromAsyncValue` convenience constructor
- `_configFor(Object error)` maps 5 AppException categories to icons/titles/subtitles/retry/bug-report
- NetworkException → wifi_off_outlined + retry; ValidationException → error_outline + message; PermissionException → lock_outline; NotFoundException → search_off_outlined + retry; catch-all → bug_report_outlined + retry + "Report this issue"
- Commit: `feat(W7.17): create AppErrorView widget with 5-category error mapping`

### W7.18 — Migrate 14 screens to AppErrorView [DONE]
- Replaced `Center(child: Text(l10n.errorXxx(e.toString())))` patterns with `AppErrorView(error: e, stackTrace: st, onRetry: () => ref.refresh(provider))` in 14 files:
  - `features/dashboard/presentation/screens/dashboard_screen.dart`
  - `features/learning/presentation/screens/learning_screen.dart`
  - `features/profiles/presentation/screens/profile_picker_screen.dart`
  - `features/profiles/presentation/screens/parent_track_management_screen.dart`
  - `features/profiles/presentation/screens/manage_learners_screen.dart`
  - `features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart`
  - `features/learning_order/presentation/screens/learning_order_screen.dart`
  - `features/tracks/setup/presentation/widgets/track_management_body.dart`
  - `features/track_setup/presentation/widgets/track_management_body.dart`
  - `features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart`
  - `features/content_browsing/presentation/widgets/content_item_tile.dart`
  - `features/onboarding/presentation/screens/bulk_mark_screen.dart`
  - `features/scheduler/presentation/screens/study_day_config_screen.dart`
  - `features/settings/presentation/screens/scope_selection_screen.dart`
- Skipped: `gamification/presentation/screens/point_config_screen.dart` — uses SnackBar error pattern in catch block, not AsyncValue body error
- Key fix: `directives_ordering` lint is fatal (--fatal-infos); required moving `app_error_view` import before `features/` imports in every file
- Removed unused `l10n` variables + `app_localizations` imports in `dashboard_screen.dart`, `profile_picker_screen.dart`, `content_item_tile.dart`
- Commit: `feat(W7.18): migrate 14 screens from raw error text to AppErrorView`

---

## S5-continuation-E (2026-05-20)

### W4.22 — Move _buildMasechtosIndex → MasechtaOrderingPolicy [DONE]
- Updated both `track_learning_order_repository_impl.dart` (legacy `track_learning_order/` and canonical `tracks/track_order/`)
- Both impls now delegate to `const MasechtaOrderingPolicy().buildIndex(allItems:, sedarimIndex:, savedSederOrder:)` — 40-line inline closure removed from each
- `savedSederOrder` extracted by filtering DAO rows to only seder-matching refs, in row order
- Commit: `refactor(W4.22): replace _buildMasechtosIndex inline logic with MasechtaOrderingPolicy`

### W5.19 — Replace DateTime.now() calls with DateTimeFactory.nowUtc() [DONE]
- 6 sites fixed across 5 files:
  - `core/sync/merge/notification_settings_merger.dart` — LWW fallback timestamp
  - `core/sync/merge/gamification_settings_merger.dart` — LWW fallback timestamp
  - `core/sync/merge/ui_preferences_merger.dart` — LWW fallback timestamp
  - `features/tutoring/domain/services/tutor_audit_log_writer.dart` — audit entry ID generation
  - `core/domain/value_objects/study_day_pattern.dart` — doc comment example updated
- Audit grep #6 (No DateTime.now() outside core/time/) now active and passing
- Note: codebase had already been mostly cleaned up; only 6 real offenders remained (plan said "100+" — earlier streams addressed most)
- Commit: `refactor(W5.19): replace DateTime.now() calls with DateTimeFactory.nowUtc()`

### W5.20 — Rename *Service → *Gateway for platform-adapter classes [DONE]
- `ConnectivityService` → `ConnectivityGateway` (core/network/) — wraps InternetAddress.lookup
- `NotificationService` → `NotificationGateway` (features/notifications/domain/services/) — wraps FlutterLocalNotificationsPlugin
- 7 importers updated across bootstrap + presentation + domain service files
- ~30 remaining *Service classes assessed: most are genuine domain-orchestration services (PinService, StreakAlertService, etc.) or already wrapped by a UseCase; renaming would not add clarity
- Commit: `refactor(W5.20): rename *Service → *Gateway for platform-adapter classes`

### W5.21 — Convert ConsumerStatefulWidget → ConsumerWidget [DONE]
- Converted `SchedulerScreen`: `_isGroupedView: bool` → `SchedulerGroupedView @riverpod Notifier` (auto-dispose)
- `skipTask()` became a local function in `build()`; no lifecycle or initState needed
- Added `schedulerGroupedViewProvider` to `scheduler_providers.dart`; regenerated `.g.dart`
- Other candidates assessed: TrackLearningOrderScreen (complex state + race seqno), LearningOrderScreen (async seeding), TrackManagementHubScreen (dialog + mounted checks), GoalSetupForm (TextEditingController + 6 fields) — all skipped
- Commit: `refactor(W5.21): convert SchedulerScreen ConsumerStatefulWidget → ConsumerWidget`

### W5.22 — Replace switch-over-strings with Map registries [DONE]
- `items_learned_providers.dart._learnedLeafRefs`: 14-case switch over entry-scope strings replaced with `const entryScopeLevel = <String, int>{...}` registry + `switch (entryScopeLevel[resolvedType])` dispatch
- Other switch-over-string sites assessed: stage_definition_codec.dart (complex per-case logic), sign_in_screen.dart / signup_screen.dart (l10n parameter dependency), manage_learners_screen.dart (2-case too simple), gamification_screen.dart (UI display strings not dispatch) — all kept as-is
- Commit: `refactor(W5.22): replace switch-over-strings with Map registry in _learnedLeafRefs`

---

## S5-godscreens-B (2026-05-20)

### W5.3 — Split gamification_screen.dart [DONE]
- Extracted 10 private widget classes and 1 data class (TierStyle) from the 1127-LOC god screen into separate files under `presentation/widgets/`:
  - `achievements_header.dart` — AchievementsHeader (was `_AchievementsHeader`)
  - `progress_summary_card.dart` — ProgressSummaryCard (was `_ProgressSummaryCard`)
  - `track_filter_row.dart` — TrackFilterRow + AchievementFilterChip (was `_TrackFilterRow` + `_FilterChip`)
  - `tier_style.dart` — TierStyle with forTitle factory (was `_TierStyle`)
  - `tier_icon_box.dart` — TierIconBox (was `_TierIconBox`)
  - `track_tag_chip.dart` — TrackTagChip (was `_TrackTagChip`)
  - `locked_achievement_shell.dart` — LockedAchievementShell (was `_LockedAchievementShell`)
  - `achievement_tier_card.dart` — AchievementTierCard (was `_AchievementTierCard`)
  - `pro_tip_card.dart` — ProTipCard (was `_ProTipCard`)
- GamificationScreen is now a thin orchestrator importing the above; observable behaviour preserved
- Fixed `prefer_const_constructors` in TierStyle default case; fixed `directives_ordering` in locked_achievement_shell.dart
- Commit: `refactor(W5.3): split gamification_screen.dart into widgets/`

### W5.6 — Split reward_configuration_screen.dart [DONE]
- Extracted `RewardForm` immutable state class, `RewardConfigController extends Notifier<RewardForm>` (Riverpod @riverpod codegen), and sub-widgets:
  - `widgets/reward_form.dart` — RewardForm immutable snapshot with copyWith (nullable sentinel pattern)
  - `providers/reward_config_controller.dart` — RewardConfigController Notifier + RewardSaveResult sealed union
  - `providers/reward_config_controller.g.dart` — generated by build_runner
  - `widgets/reward_config_header.dart` — RewardConfigHeader (was `_RewardConfigHeader`)
  - `widgets/avatar_picker_row.dart` — AvatarPickerRow + AvatarTile (was `_AvatarTile`)
  - `widgets/reward_type_segmented.dart` — RewardTypeSegmented + _Seg (was `_RewardTypeSegmented` + `_Seg`)
  - `widgets/manage_rewards_list.dart` — ManageRewardsList + RewardCard (was `_ManageRewardsList` + `_ManageRewardsListState`)
- Screen is now a thin ConsumerStatefulWidget orchestrator; controller holds all data mutations; screen owns BuildContext-dependent UI (dialogs, snackbars)
- RewardSaveResult sealed union lets screen switch on outcome without touching business logic
- Text controllers synced to notifier state via _syncControllersFromState to avoid loops during clearForm / applyMilestoneToForm
- `dart analyze` reports no issues in all new files
- Commit: `refactor(W5.6): split reward_configuration_screen.dart into controller + widgets`

---

## Cross-stream issues noted
- Pre-existing errors in `features/tracks/setup/presentation/` (add_track_controller.dart, add_track_flow_screen.dart, track_detail_screen.dart) and `features/stages/data/` (const_with_non_const) — not caused by S5 work
- `stage_definition_repository_impl.dart:66` uses `const` with a non-const constructor — pre-existing, out of scope
