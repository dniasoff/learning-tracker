# Story 15.11 — Profile-Scoped Providers & Sync (DNI-119)

## Story Overview

**As a** user with multiple learner profiles,
**I want** all data providers and Firestore sync to be scoped to the active profile,
**So that** each profile sees only its own completions, bookmarks, streaks, goals, rewards, and settings — and switching profiles cleanly loads the correct data without stale state.

**Depends on:** Story 15.1 (DNI-109) — Multi-Profile Data Model (provides `LearnerProfiles` table, `LearnerProfileDao`, `ActiveProfileService`, and `activeProfileProvider`), Story 15.2 (DNI-110) — Profile Picker & Management UI.

**Epic:** 15 — Multi-Profile Support

---

## Acceptance Criteria

- [ ] **AC1:** An `activeProfileProvider` (keepAlive) holds the currently selected `LearnerProfile`. All profile-scoped providers depend on it directly or transitively.
- [ ] **AC2:** All data providers (completions, bookmarks, stages, goals, rewards, streaks, active curricula, learning order, tracks, points, charts, progress, scheduler tasks) return data filtered to the active profile's `profileId`.
- [ ] **AC3:** When the active profile changes (via profile picker or switch), every profile-scoped provider is invalidated and reloads fresh data from the local database.
- [ ] **AC4:** The sync engine is scoped to the active profile. Firestore paths include `profileId`: `users/{uid}/profiles/{profileId}/completions`, etc.
- [ ] **AC5:** On profile switch, the sync engine detaches all Firestore listeners for the old profile and attaches new listeners scoped to the new profile.
- [ ] **AC6:** Only the active profile syncs in the foreground. Background profiles do not consume Firestore listener quota.
- [ ] **AC7:** The offline queue includes `profileId` in each queued operation payload, ensuring queued writes go to the correct Firestore path on flush.
- [ ] **AC8:** Profile switch navigates to the dashboard (or profile picker). No screen displays stale data from the previous profile during the transition.
- [ ] **AC9:** SharedPreferences keys used by notification providers, skipped-tasks, and learning-order preferences are namespaced by `profileId` to prevent cross-profile leakage.
- [ ] **AC10:** The `SyncLifecycleObserver` respects the active profile when attaching/detaching listeners.
- [ ] **AC11:** Pull-on-launch fetches data for the active profile only.
- [ ] **AC12:** Push-on-write operations include the active profile's `profileId` in Firestore document paths.

---

## Architecture & Design Notes

### Provider Dependency Graph

```
activeProfileProvider (keepAlive, StateNotifier<LearnerProfile?>)
  |
  +-- firestoreDataSourceProvider (reconstructed with profileId)
  |     |
  |     +-- syncEngineProvider (reinitializes on profile change)
  |     |     |
  |     |     +-- offlineQueueProvider
  |     |     +-- syncStatusStreamProvider
  |     |     +-- syncStatusProvider
  |     |
  |     +-- firestoreDataSourceProvider
  |           +-- curriculumActivationServiceProvider
  |           +-- deviceRestoreServiceProvider
  |
  +-- completionRepositoryProvider (watches activeProfileProvider)
  |     +-- isStageCompletedProvider
  |     +-- completionCountProvider
  |     +-- markCompletionUseCaseProvider
  |     +-- bulkMarkCompletionUseCaseProvider
  |
  +-- bookmarkRepositoryProvider (watches activeProfileProvider)
  |     +-- bookmarkProvider (family)
  |     +-- bookmarkActionsProvider
  |
  +-- stageDefinitionRepositoryProvider (family, watches activeProfileProvider)
  |     +-- stageListProvider
  |     +-- stageEditorProvider
  |
  +-- trackRepositoryProvider (watches activeProfileProvider)
  |     +-- activeTracksProvider
  |     +-- isTrackActiveProvider
  |
  +-- All dashboard providers (dashboardUserMode, dashboardActiveCurricula, etc.)
  +-- All scheduler providers (schedulerEngine, dailyTasks, allDailyTasks, paceStatus, skippedTasks)
  +-- All gamification providers (pointsService, curriculumPoints, globalPoints, rewardService, etc.)
  +-- All progress providers (progressRepository, trackBreakdown, curriculumProgress, etc.)
  +-- All chart providers (chartDataService)
  +-- learningOrderRepositoryProvider, learningOrderProvider
  +-- parentDashboardAggregatorProvider, parentDashboardDataProvider
  +-- tutorDashboardAggregatorProvider, tutorDashboardDataProvider
  +-- notificationProviders (reminderSyncEffect, streakAlertSyncEffect — indirectly via allDailyTasks)
```

### Invalidation Strategy

**Option: Centralized invalidation via `activeProfileProvider` watcher**

1. `activeProfileProvider` is a keepAlive `StateNotifier<LearnerProfile?>`.
2. Create a `profileSwitchNotifierProvider` that watches `activeProfileProvider` and, on change:
   - Calls `syncEngine.detachListeners()` on the old engine.
   - Invalidates `firestoreDataSourceProvider` (triggers reconstruction with new profileId).
   - Invalidates `syncEngineProvider` (triggers new engine creation + `initialize()`).
   - Invalidates every profile-scoped provider in a single batch (see full list below).
   - Navigates to dashboard or profile picker.
3. Providers that use `ref.watch(activeProfileProvider)` will auto-invalidate when the profile changes. This is the preferred approach for most providers.
4. For providers that do NOT watch `activeProfileProvider` directly (e.g., family providers with curriculum keys), the centralized invalidation explicitly calls `ref.invalidate(...)`.

**Why not ProviderScope overrides?** The app uses a single global ProviderContainer. Nested ProviderScopes would require significant widget tree restructuring and break the current auto_route guard/shell pattern. Watching `activeProfileProvider` is simpler and consistent with the existing architecture.

### Profile-Scoped Database Queries

Two approaches (choose during implementation):

**Approach A — Add `profileId` column to all profile-scoped tables:**
- Add a `profileId TEXT NOT NULL DEFAULT 'default'` column to: `Completions`, `Bookmarks`, `Goals`, `Rewards`, `Streaks`, `ActiveCurricula`, `StageDefinitions`, `LearningOrder`, `PointConfigs`, `CurriculumTracks`.
- Update all DAO query methods to accept and filter by `profileId`.
- Requires a Drift schema migration adding the column with a default value for existing data.

**Approach B — Filter at the provider/repository layer:**
- DAOs remain unchanged; repositories accept `profileId` and add it as a WHERE clause.
- Less invasive but means DAOs return unfiltered data that repositories must post-filter.

**Recommendation:** Approach A is correct. The `profileId` column ensures data integrity at the database level and enables efficient indexed queries. The migration is straightforward with a default value.

---

## Complete Provider Inventory

Every provider file listed below needs modification to become profile-scoped. The column "Change Type" indicates what must be done.

### Core Providers (lib/core/providers/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `database_provider.dart` | `appDatabaseProvider` | **No change** — database is shared across profiles. Profile scoping happens at the DAO/query level. |
| `firebase_providers.dart` | `firebaseAuthProvider`, `firebaseFirestoreProvider` | **No change** — auth and Firestore instances are global. |
| `talker_provider.dart` | `talkerProvider` | **No change** — logging is global. |
| `network_providers.dart` | `connectivityServiceProvider` | **No change** — connectivity is global. |

### Sync Providers (lib/features/sync/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/sync_providers.dart` | `firestoreDataSourceProvider` | **Modify** — watch `activeProfileProvider`, pass `profileId` to `FirestoreDataSource` constructor. |
| `presentation/providers/sync_providers.dart` | `offlineQueueProvider` | **Modify** — ensure offline queue payloads include `profileId`. |
| `presentation/providers/sync_providers.dart` | `syncEngineProvider` | **Modify** — watch `activeProfileProvider`; on profile change, old engine is disposed, new engine created and initialized for the new profile. |
| `presentation/providers/sync_providers.dart` | `syncStatusStreamProvider`, `syncStatusProvider` | **Indirect** — auto-invalidated when `syncEngineProvider` rebuilds. |
| `presentation/providers/restore_providers.dart` | `deviceRestoreServiceProvider`, `restoreStatusStreamProvider`, `restoreStatusProvider` | **Modify** — pass `profileId` to restore service for profile-scoped restore. |
| `data/firestore_data_source.dart` | `FirestoreDataSource` class | **Modify** — accept `profileId` in constructor; change all collection references from `users/{uid}/completions` to `users/{uid}/profiles/{profileId}/completions` (and similarly for all other collections). |
| `data/sync_engine.dart` | `SyncEngine` class | **Modify** — accept `profileId` for SharedPreferences key namespacing (`_lastSyncKey` and settings timestamps must include profileId). |
| `data/offline_queue.dart` | `OfflineQueue` class | **Modify** — ensure all enqueued payloads include `profileId`; flush must route to the correct Firestore path. |
| `presentation/widgets/sync_lifecycle_observer.dart` | `SyncLifecycleObserver` | **Modify** — read `activeProfileProvider` to ensure listeners are attached for the correct profile. |

### Learning Providers (lib/features/learning/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/completion_providers.dart` | `completionRepositoryProvider` | **Modify** — watch `activeProfileProvider`, pass `profileId` to repository. |
| `presentation/providers/completion_providers.dart` | `isStageCompletedProvider` | **Indirect** — auto-invalidated via `completionRepositoryProvider`. |
| `presentation/providers/completion_providers.dart` | `markCompletionUseCaseProvider` | **Indirect** — auto-invalidated via `completionRepositoryProvider`. |
| `presentation/providers/completion_providers.dart` | `bulkMarkCompletionUseCaseProvider` | **Indirect** — auto-invalidated via `completionRepositoryProvider`. |
| `presentation/providers/completion_providers.dart` | `completionCountProvider` | **Modify** — watch `activeProfileProvider`, filter DAO query by `profileId`. |
| `presentation/providers/bookmark_providers.dart` | `bookmarkRepositoryProvider` | **Modify** — watch `activeProfileProvider`, pass `profileId` to repository. |
| `presentation/providers/bookmark_providers.dart` | `bookmarkProvider` (family) | **Indirect** — auto-invalidated via `bookmarkRepositoryProvider`. |
| `presentation/providers/bookmark_providers.dart` | `bookmarkActionsProvider` | **Indirect** — auto-invalidated via `bookmarkRepositoryProvider`. |
| `presentation/providers/track_providers.dart` | `trackRepositoryProvider` | **Modify** — watch `activeProfileProvider`, pass `profileId` to repository. |
| `presentation/providers/track_providers.dart` | `activeTracksProvider`, `isTrackActiveProvider` | **Indirect** — auto-invalidated via `trackRepositoryProvider`. |

### Stage Providers (lib/features/stages/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/stage_providers.dart` | `stageDefinitionRepositoryProvider` | **Modify** — watch `activeProfileProvider`, pass `profileId` to repository. |
| `presentation/providers/stage_providers.dart` | `stageListProvider` | **Indirect** — auto-invalidated via repository. |
| `presentation/providers/stage_providers.dart` | `stageEditorProvider` (AsyncNotifier) | **Modify** — read `activeProfileProvider` in `build()` to scope queries. |

### Scheduler Providers (lib/features/scheduler/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/scheduler_providers.dart` | `schedulerEngineProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to the completion/stage/learning-order repositories it constructs. |
| `presentation/providers/scheduler_providers.dart` | `dailyTaskGeneratorProvider` | **Indirect** — auto-invalidated via `schedulerEngineProvider`. |
| `presentation/providers/scheduler_providers.dart` | `dailyTasksProvider` | **Indirect** — auto-invalidated via `schedulerEngineProvider`. |
| `presentation/providers/scheduler_providers.dart` | `allDailyTasksProvider` | **Modify** — watch `activeProfileProvider`; DAO calls (`activeCurriculumDao.getActiveCurricula()`, `goalDao.getGoalsByCurriculum()`) must filter by `profileId`. |
| `presentation/providers/scheduler_providers.dart` | `paceStatusProvider` | **Modify** — watch `activeProfileProvider`; filter completions by `profileId`. |
| `presentation/providers/scheduler_providers.dart` | `skippedTasksProvider` (StateNotifier) | **Modify** — namespace SharedPreferences keys by `profileId` (e.g., `skipped_tasks_date_{profileId}`). |
| `presentation/providers/scheduler_providers.dart` | `previouslySkippedRefsProvider` | **Modify** — namespace SharedPreferences key by `profileId`. |

### Dashboard Providers (lib/features/dashboard/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/dashboard_providers.dart` | `dashboardUserModeProvider` | **Modify** — watch `activeProfileProvider`; resolve user mode from the active profile's `userMode` field, not from the first UserProfile row. |
| `presentation/providers/dashboard_providers.dart` | `dashboardActiveCurriculaProvider` | **Modify** — watch `activeProfileProvider`; filter `activeCurriculumDao` by `profileId`. |
| `presentation/providers/dashboard_providers.dart` | `dashboardActiveCurriculaStreamProvider` | **Modify** — watch `activeProfileProvider`; filter watch stream by `profileId`. |
| `presentation/providers/dashboard_providers.dart` | `dashboardCompletionPercentageProvider` | **Modify** — watch `activeProfileProvider`; filter completions and stages by `profileId`. |
| `presentation/providers/dashboard_providers.dart` | `dashboardLastCompletionProvider` | **Modify** — watch `activeProfileProvider`; filter completions by `profileId`. |
| `presentation/providers/dashboard_providers.dart` | `dashboardStreakProvider` | **Modify** — watch `activeProfileProvider`; filter streaks by `profileId`. |
| `presentation/providers/dashboard_providers.dart` | `dashboardGlobalPointsProvider` | **Modify** — watch `activeProfileProvider`; filter completions by `profileId`. |

### Gamification Providers (lib/features/gamification/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/points_providers.dart` | `pointsServiceProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to `PointsService`. |
| `presentation/providers/points_providers.dart` | `curriculumPointsProvider`, `globalPointsProvider`, `curriculumBreakdownProvider`, `pointsHistoryProvider` | **Indirect** — auto-invalidated via `pointsServiceProvider`. |
| `presentation/providers/reward_providers.dart` | `rewardServiceProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to `RewardService`. |
| `presentation/providers/reward_providers.dart` | `allRewardsStreamProvider` | **Modify** — watch `activeProfileProvider`; filter `rewardDao.watchAllRewards()` by `profileId`. |
| `presentation/providers/reward_providers.dart` | `nextRewardProvider`, `rewardProgressProvider`, `earnedRewardsProvider`, `allRewardsProvider` | **Indirect** — auto-invalidated via `rewardServiceProvider` and `allRewardsStreamProvider`. |

### Progress Providers (lib/features/progress/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/progress_providers.dart` | `progressRepositoryProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to repository. |
| `presentation/providers/progress_providers.dart` | `trackBreakdownProvider`, `aggregateCountProvider` | **Indirect** — auto-invalidated via `progressRepositoryProvider`. |
| `presentation/providers/progress_providers.dart` | `completionHistoryForCurriculumProvider`, `allCompletionHistoryProvider` | **Indirect** — auto-invalidated via `progressRepositoryProvider`. |
| `presentation/providers/progress_providers.dart` | `curriculumProgressProvider` | **Modify** — watch `activeProfileProvider`; filter DAO queries by `profileId`. |
| `presentation/providers/progress_providers.dart` | `curriculumPaceStatusProvider` | **Modify** — watch `activeProfileProvider`; filter DAO queries by `profileId`. |
| `presentation/providers/chart_providers.dart` | `chartDataServiceProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to `ChartDataService`. |

### Learning Order Providers (lib/features/learning_order/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/learning_order_providers.dart` | `learningOrderRepositoryProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to repository. |
| `presentation/providers/learning_order_providers.dart` | `learningOrderProvider` | **Indirect** — auto-invalidated via repository. |
| `presentation/providers/learning_order_providers.dart` | `parentControlsOrderingProvider` | **Modify** — namespace SharedPreferences key by `profileId`. |
| `presentation/providers/learning_order_providers.dart` | `userModeProvider` | **Modify** — derive from `activeProfileProvider` instead of querying `userProfileDao`. |
| `presentation/providers/learning_order_providers.dart` | `orderingRestrictedProvider` | **Indirect** — auto-invalidated via `userModeProvider`. |

### Settings Providers (lib/features/settings/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/curriculum_activation_providers.dart` | `curriculumActivationServiceProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to service. |
| `presentation/providers/curriculum_activation_providers.dart` | `activeCurriculaProvider`, `activeCurriculaStreamProvider`, `isCurriculumActiveProvider` | **Modify** — watch `activeProfileProvider`; filter DAO queries by `profileId`. |
| `presentation/providers/account_management_providers.dart` | `accountManagementServiceProvider` | **No change** — account management is user-level, not profile-level. |

### Onboarding Providers (lib/features/onboarding/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/onboarding_providers.dart` | `userProfileServiceProvider` | **Modify** — accept `profileId` for profile-scoped initial setup. |
| `presentation/providers/onboarding_providers.dart` | `curriculumImportServiceProvider` | **Modify** — pass `profileId` so imported curricula are associated with the correct profile. |
| `presentation/providers/onboarding_providers.dart` | `goalRepositoryProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to repository. |
| `presentation/providers/onboarding_providers.dart` | `bulkPriorCompletionServiceProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to service. |

### Notification Providers (lib/features/notifications/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/notification_providers.dart` | `reminderEnabledProvider`, `reminderTimeProvider` | **Modify** — namespace SharedPreferences keys by `profileId`. |
| `presentation/providers/notification_providers.dart` | `streakAlertEnabledProvider`, `streakAlertTimeProvider` | **Modify** — namespace SharedPreferences keys by `profileId`. |
| `presentation/providers/notification_providers.dart` | `rewardNotificationEnabledProvider` | **Modify** — namespace SharedPreferences key by `profileId`. |
| `presentation/providers/notification_providers.dart` | `shabbosModeEnabledProvider` and related Shabbos providers | **No change** — Shabbos mode is device-level (same timezone/location regardless of profile). |
| `presentation/providers/notification_providers.dart` | `reminderSyncEffectProvider` | **Indirect** — auto-invalidated via `allDailyTasksProvider`. |
| `presentation/providers/notification_providers.dart` | `streakAlertSyncEffectProvider` | **Indirect** — auto-invalidated via streak data providers. |
| `presentation/providers/reward_milestone_providers.dart` | `rewardMilestoneNotificationServiceProvider` | **No change** — stateless service, profile scoping comes from reward data. |

### Parent Mode Providers (lib/features/parent_mode/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/parent_dashboard_providers.dart` | `parentDashboardAggregatorProvider`, `parentDashboardDataProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to aggregator so it scopes DB queries. |
| `presentation/providers/parent_track_providers.dart` | `parentTrackCurriculaProvider` | **Modify** — watch `activeProfileProvider`; filter `activeCurriculumDao` by `profileId`. |

### Tutor Mode Providers (lib/features/tutor_mode/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `domain/tutor_mode_provider.dart` | `tutorModeProvider` | **No change** — tutor mode is device-local session state, not profile-scoped. |
| `presentation/providers/tutor_dashboard_providers.dart` | `tutorDashboardAggregatorProvider`, `tutorDashboardDataProvider` | **Modify** — watch `activeProfileProvider`; pass `profileId` to aggregator. |

### Auth Providers (lib/features/auth/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/auth_providers.dart` | `authRepositoryProvider`, `authStateProvider`, `googleSignInProvider` | **No change** — auth is user-level. |

### Content Browsing Providers (lib/features/content_browsing/)

| File | Providers | Change Type |
|------|-----------|-------------|
| `presentation/providers/content_providers.dart` | `contentRepositoryProvider`, `curriculumContentProvider`, etc. | **No change** — content is curriculum-level static data, not profile-scoped. |
| `presentation/providers/text_display_providers.dart` | `textCacheRepositoryProvider`, `textContentProvider`, `textDownloadServiceProvider` | **No change** — text cache is shared across profiles. |
| `presentation/providers/text_display_providers.dart` | `fontSizeNotifierProvider`, `showNikudProvider` | **Consider** — if display preferences should be per-profile, namespace SharedPreferences keys. Otherwise no change. |

### Core Services (lib/core/services/)

| File | Change Type |
|------|-------------|
| `pin_service.dart` | **No change** — PINs are device-level, not profile-scoped. |
| `track_service.dart` | **Modify** — if it queries DB directly, must accept `profileId`. |
| `daily_schedule_composer.dart` | **Modify** — pass `profileId` for DB queries. |
| `cross_curriculum_aggregator.dart` | **Modify** — accept `profileId` for scoped aggregation. |
| `duplicate_prevention_service.dart` | **Modify** — filter by `profileId`. |

---

## Firestore Path Changes

### Current Structure (single-user)

```
users/{uid}/
  profile/data
  completions/{autoId}
  bookmarks/{curriculumId}_{trackType}
  settings/{curriculumId}
  streak/data
  goals/{goalId}
  rewards/{rewardId}
  active_curricula/data
  curriculum_imports/{curriculumId}
```

### New Structure (multi-profile)

```
users/{uid}/
  profiles/{profileId}/
    profile/data
    completions/{autoId}
    bookmarks/{curriculumId}_{trackType}
    settings/{curriculumId}
    streak/data
    goals/{goalId}
    rewards/{rewardId}
    active_curricula/data
    curriculum_imports/{curriculumId}
```

### Migration Strategy

1. On first launch after upgrade, if `users/{uid}/completions` exists (old path) and `users/{uid}/profiles/` does not:
   - Create a default profile document under `users/{uid}/profiles/default/profile/data`.
   - Move (copy + delete) all existing subcollections from `users/{uid}/` to `users/{uid}/profiles/default/`.
   - Mark migration complete in a `users/{uid}/meta/migration` document.
2. `FirestoreDataSource` always uses the new path structure after migration.
3. The migration can run as part of `DeviceRestoreService` or a new `ProfileMigrationService`.

### FirestoreDataSource Changes

The `FirestoreDataSource` class currently derives all paths from `_userDoc`:

```dart
// BEFORE
DocumentReference? get _userDoc =>
    _firestore.collection('users').doc(_auth.currentUser?.uid);

CollectionReference? get _completionsCollection =>
    _userDoc?.collection('completions');
```

Must change to:

```dart
// AFTER
final String? _profileId;

DocumentReference? get _profileDoc =>
    _userDoc?.collection('profiles').doc(_profileId);

CollectionReference? get _completionsCollection =>
    _profileDoc?.collection('completions');
```

All getters (`_completionsCollection`, `_bookmarksCollection`, `_settingsCollection`, `_streakDoc`, `_profileDoc`, `_activeCurriculaDoc`, goals collection, rewards collection, curriculum_imports collection) must be updated to use `_profileDoc` as the base.

---

## Implementation Steps

### Phase 1: Database Schema Migration

1. Add `profileId TEXT NOT NULL DEFAULT 'default'` column to these tables:
   - `Completions`
   - `Bookmarks`
   - `Goals`
   - `Rewards`
   - `Streaks`
   - `ActiveCurricula`
   - `StageDefinitions`
   - `LearningOrder`
   - `PointConfigs`
   - `CurriculumTracks`
   - `SyncQueue`
2. Write Drift migration (increment schema version).
3. Run `dart run build_runner build --delete-conflicting-outputs`.
4. Update all DAO methods to accept and filter by `profileId`.

### Phase 2: FirestoreDataSource Scoping

5. Add `profileId` parameter to `FirestoreDataSource` constructor.
6. Update all collection/document reference getters to use `users/{uid}/profiles/{profileId}/...` path.
7. Write `ProfileFirestoreMigrationService` to move existing data to the `profiles/default/` subcollection.

### Phase 3: SyncEngine + OfflineQueue Scoping

8. Add `profileId` to `SyncEngine` constructor; namespace SharedPreferences keys (`_lastSyncKey`, settings timestamps) with profileId.
9. Add `profileId` field to offline queue payloads.
10. Add `detachAndReattach(String newProfileId)` method to `SyncEngine` for clean profile switching.

### Phase 4: Provider Scoping

11. Add `activeProfileProvider` watch to `firestoreDataSourceProvider` — reconstruct with new `profileId`.
12. Add `activeProfileProvider` watch to `syncEngineProvider` — dispose old engine, create new.
13. Update each repository provider to watch `activeProfileProvider` and pass `profileId`:
    - `completionRepositoryProvider`
    - `bookmarkRepositoryProvider`
    - `trackRepositoryProvider`
    - `stageDefinitionRepositoryProvider`
    - `learningOrderRepositoryProvider`
    - `progressRepositoryProvider`
    - `goalRepositoryProvider`
14. Update each service provider to watch `activeProfileProvider`:
    - `pointsServiceProvider`
    - `rewardServiceProvider`
    - `curriculumActivationServiceProvider`
    - `chartDataServiceProvider`
    - `parentDashboardAggregatorProvider`
    - `tutorDashboardAggregatorProvider`
    - `schedulerEngineProvider`
15. Update direct-DAO providers to filter by `profileId`:
    - `completionCountProvider`
    - `dashboardCompletionPercentageProvider`
    - `dashboardLastCompletionProvider`
    - `dashboardStreakProvider`
    - `dashboardGlobalPointsProvider`
    - `dashboardActiveCurriculaProvider` / `dashboardActiveCurriculaStreamProvider`
    - `allDailyTasksProvider`
    - `paceStatusProvider`
    - `curriculumProgressProvider`
    - `curriculumPaceStatusProvider`
    - `allRewardsStreamProvider`
    - `activeCurriculaProvider` / `activeCurriculaStreamProvider` / `isCurriculumActiveProvider`
    - `parentTrackCurriculaProvider`

### Phase 5: SharedPreferences Namespacing

16. Namespace these SharedPreferences keys with `profileId`:
    - `skipped_tasks_date`, `skipped_tasks_refs`, `skipped_tasks_previous_refs` (scheduler)
    - `daily_reminder_enabled`, `daily_reminder_hour`, `daily_reminder_minute` (notifications)
    - `streak_alert_enabled`, `streak_alert_hour`, `streak_alert_minute` (notifications)
    - `reward_notification_enabled` (notifications)
    - `settings_ts_{curriculumId}` (sync engine) -> `settings_ts_{profileId}_{curriculumId}`
    - `sync_engine_last_synced_at` -> `sync_engine_last_synced_at_{profileId}`
    - `parent_controls_ordering` (learning order preferences)

### Phase 6: Navigation & Profile Switch

17. Update `SyncLifecycleObserver` to read `activeProfileProvider`.
18. Create `ProfileSwitchService` that orchestrates:
    - Detach old sync listeners
    - Update `activeProfileProvider`
    - (Providers auto-invalidate from the watch chain)
    - Navigate to dashboard
19. Ensure no widget can render between invalidation and fresh data load (use loading states).

### Phase 7: Onboarding & Restore

20. Update `userProfileServiceProvider` and `curriculumImportServiceProvider` to accept `profileId`.
21. Update `DeviceRestoreService` to restore into a specific profile.
22. Update `bulkPriorCompletionServiceProvider` to write completions with `profileId`.

---

## Dev Notes

### Race Conditions on Profile Switch

**Problem:** If a user switches profiles while a sync merge is in progress, the merge could write data to the wrong profile's local DB rows.

**Mitigation:**
- `SyncEngine.detachListeners()` cancels all Firestore snapshot subscriptions immediately.
- Each merge guard (`_mergingCompletions`, etc.) prevents concurrent merges.
- The sync engine's `dispose()` method should await any in-flight merges before returning.
- Add a `_disposed` flag to `SyncEngine`; check it at the top of each merge callback to bail out if the engine was disposed during an in-flight Firestore snapshot delivery.

### Listener Cleanup

- `SyncEngine.detachListeners()` already cancels all 7 subscriptions and nulls the references.
- On profile switch, the old `SyncEngine` is fully disposed (via `ref.onDispose`).
- A new `SyncEngine` is created for the new profile with fresh subscriptions.
- The `SyncLifecycleObserver` must NOT hold a stale reference to the old engine. Since it reads `syncEngineProvider` via `ref.read()`, it will get the new engine after invalidation.

### Stale Data Prevention

- Between profile switch (invalidation) and fresh data load, all data providers will be in `AsyncLoading` state.
- Screens using `AsyncValue.when()` will show loading indicators automatically.
- The router should navigate to the dashboard (which handles loading states) before invalidation completes.
- Consider adding a brief splash/loading overlay during the switch to prevent flash of stale content.

### Offline Queue Considerations

- Queued operations from profile A must still flush to profile A's Firestore path, even if the user switched to profile B.
- The `SyncQueue` table should store `profileId` per row.
- `OfflineQueue.flush()` must construct the Firestore path using each operation's stored `profileId`, not the current active profile.
- This means `FirestoreDataSource` may need a method variant that accepts an explicit `profileId` override for queue flushing.

### SharedPreferences Key Migration

- Existing SharedPreferences keys (without profileId suffix) should be migrated to the `default` profile on first launch.
- Create a `PreferencesMigrationService` that checks for un-namespaced keys and renames them.

---

## Test Plan

### Unit Tests

- [ ] `FirestoreDataSource` with profileId produces correct Firestore paths (`users/{uid}/profiles/{profileId}/completions`, etc.)
- [ ] `SyncEngine` with profileId namespaces SharedPreferences keys correctly.
- [ ] `OfflineQueue` stores and flushes operations with correct profileId.
- [ ] Each DAO filters by profileId correctly (completions, bookmarks, goals, rewards, streaks, active_curricula, stages, learning_order, point_configs, tracks).
- [ ] Database migration adds `profileId` column with `'default'` value to all existing rows.

### Integration Tests

- [ ] Profile switch invalidates all scoped providers (verify via provider container listener).
- [ ] Profile switch detaches old Firestore listeners and attaches new ones.
- [ ] Data written under profile A is not visible under profile B.
- [ ] Offline queue operations flushed to correct profile path after profile switch.
- [ ] Pull-on-launch fetches data for the active profile only.
- [ ] Push-on-write uses the active profile's Firestore path.
- [ ] SharedPreferences keys are namespaced by profileId.

### Acceptance Tests

- [ ] Create two profiles. Complete items under profile A. Switch to profile B. Verify B has zero completions.
- [ ] Switch back to A. Verify A's completions are intact.
- [ ] Set a bookmark under profile A. Switch to B. Verify B has no bookmark for that curriculum/track.
- [ ] Configure rewards under profile A. Switch to B. Verify B has no rewards.
- [ ] Set notification preferences under A. Switch to B. Verify B has default notification settings.
- [ ] Go offline, make completions under A, switch to B, go online. Verify A's completions sync to A's Firestore path.
- [ ] Kill and restart the app with profile B active. Verify pull-on-launch fetches B's data.

### Edge Cases

- [ ] Profile switch while offline — sync engine skips listener operations gracefully.
- [ ] Profile switch during in-flight merge — merge completes or is discarded without corruption.
- [ ] Delete a profile while its offline queue has pending items — items should be discarded or flushed first.
- [ ] First launch after upgrade — migration moves existing data to `default` profile correctly.

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/sync/data/profile_firestore_migration_service.dart` | Migrates existing Firestore data from `users/{uid}/` to `users/{uid}/profiles/default/`. |
| `lib/core/services/profile_switch_service.dart` | Orchestrates sync teardown, provider invalidation, and navigation on profile switch. |
| `lib/core/services/preferences_migration_service.dart` | Migrates un-namespaced SharedPreferences keys to `default` profile namespace. |

## Files to Modify

| File | Summary of Changes |
|------|-------------------|
| `lib/core/database/tables/completions.dart` | Add `profileId` column. |
| `lib/core/database/tables/bookmarks.dart` | Add `profileId` column. |
| `lib/core/database/tables/goals.dart` | Add `profileId` column. |
| `lib/core/database/tables/rewards.dart` | Add `profileId` column. |
| `lib/core/database/tables/streaks.dart` | Add `profileId` column. |
| `lib/core/database/tables/active_curricula.dart` | Add `profileId` column (update primary key to include it). |
| `lib/core/database/tables/stage_definitions.dart` | Add `profileId` column. |
| `lib/core/database/tables/learning_order.dart` | Add `profileId` column. |
| `lib/core/database/tables/point_configs.dart` | Add `profileId` column. |
| `lib/core/database/tables/curriculum_tracks.dart` | Add `profileId` column (update primary key to include it). |
| `lib/core/database/tables/sync_queue.dart` | Add `profileId` column. |
| `lib/core/database/app_database.dart` | Increment schema version, add migration. |
| `lib/core/database/daos/completion_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/bookmark_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/goal_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/reward_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/streak_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/active_curriculum_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/stage_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/learning_order_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/point_config_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/track_dao.dart` | Add `profileId` parameter to all query methods. |
| `lib/core/database/daos/sync_queue_dao.dart` | Add `profileId` column support. |
| `lib/features/sync/data/firestore_data_source.dart` | Accept `profileId`, change all paths to `users/{uid}/profiles/{profileId}/...`. |
| `lib/features/sync/data/sync_engine.dart` | Accept `profileId`, namespace SharedPreferences keys, add `_disposed` guard. |
| `lib/features/sync/data/offline_queue.dart` | Store `profileId` per operation, flush to correct path. |
| `lib/features/sync/presentation/providers/sync_providers.dart` | Watch `activeProfileProvider`, reconstruct data source/engine on switch. |
| `lib/features/sync/presentation/providers/restore_providers.dart` | Pass `profileId` to restore service. |
| `lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart` | Read `activeProfileProvider` for listener management. |
| `lib/features/learning/presentation/providers/completion_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/learning/presentation/providers/bookmark_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/learning/presentation/providers/track_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/stages/presentation/providers/stage_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/scheduler/presentation/providers/scheduler_providers.dart` | Watch `activeProfileProvider`, namespace SharedPrefs, pass `profileId` to DAOs. |
| `lib/features/dashboard/presentation/providers/dashboard_providers.dart` | Watch `activeProfileProvider`, pass `profileId` to all DAO queries. |
| `lib/features/gamification/presentation/providers/points_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/gamification/presentation/providers/reward_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/progress/presentation/providers/progress_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/progress/presentation/providers/chart_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/learning_order/presentation/providers/learning_order_providers.dart` | Watch `activeProfileProvider`, pass `profileId`, namespace SharedPrefs. |
| `lib/features/settings/presentation/providers/curriculum_activation_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | Pass `profileId` to services. |
| `lib/features/notifications/presentation/providers/notification_providers.dart` | Namespace SharedPreferences keys by `profileId`. |
| `lib/features/parent_mode/presentation/providers/parent_dashboard_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/parent_mode/presentation/providers/parent_track_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/tutor_mode/presentation/providers/tutor_dashboard_providers.dart` | Watch `activeProfileProvider`, pass `profileId`. |
| `lib/features/learning/data/repositories/completion_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/learning/data/repositories/bookmark_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/learning/data/repositories/track_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/stages/data/repositories/stage_definition_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/progress/data/repositories/progress_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/scheduler/data/repositories/goal_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/gamification/domain/services/points_service.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/gamification/domain/services/reward_service.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/features/gamification/domain/services/streak_service.dart` | Accept `profileId`, pass to DAO calls. |
| `lib/core/services/cross_curriculum_aggregator.dart` | Accept `profileId`. |
| `lib/core/services/daily_schedule_composer.dart` | Accept `profileId`. |
| `lib/core/services/duplicate_prevention_service.dart` | Accept `profileId`. |
| `lib/features/parent_mode/domain/services/parent_dashboard_aggregator.dart` | Accept `profileId`. |
| `lib/features/tutor_mode/domain/services/tutor_dashboard_aggregator.dart` | Accept `profileId`. |
| `lib/features/sync/domain/services/device_restore_service.dart` | Accept `profileId` for profile-scoped restore. |
| `lib/features/settings/domain/services/curriculum_activation_service.dart` | Accept `profileId`. |
| `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart` | Accept `profileId`. |
| `lib/features/onboarding/domain/services/curriculum_import_service.dart` | Accept `profileId`. |
| `lib/features/onboarding/domain/services/user_profile_service.dart` | Accept `profileId`. |
| `lib/features/notifications/domain/services/streak_alert_service.dart` | Accept `profileId` for streak queries. |
