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

## Cross-stream issues noted
- Pre-existing errors in `features/tracks/setup/presentation/` (add_track_controller.dart, add_track_flow_screen.dart, track_detail_screen.dart) and `features/stages/data/` (const_with_non_const) — not caused by S5 work
- `stage_definition_repository_impl.dart:66` uses `const` with a non-const constructor — pre-existing, out of scope
