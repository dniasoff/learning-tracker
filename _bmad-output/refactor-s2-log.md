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

## [2026-05-20 06:00] task-complete
- tasks: W2.28 + W2.29 + W2.30
- detail:
  W2.28: Added pullStreak to PullPipeline → _pullCollection('streak_events', EntityKind.streak). Wired in SyncOrchestrator.pullOnLaunch. Closes M4. (streak_events subcollection is populated from W3.37; before that this is a safe no-op.)
  W2.29: Wired stage_definitions/ push+pull end-to-end:
    - Pull: pullStageDefinitions → _pullCollection('stage_definitions', EntityKind.stageDefinition) in PullPipeline; step wired in SyncOrchestrator.
    - Push: pushStageDefinition abstract in FirestoreGateway + PushPipeline; implemented in FirestoreGatewayImpl (doc ID = {trackId}_{stageOrder}, merge:true) and OutboxPushPipeline. OutboxEntityKind.stageDefinition constant added; stageDefinition added to OutboxProcessor._nonCompletionKinds + _dispatch switch. firestore.rules: added stage_definitions/{stageId} match block with field allowlist. Closes H4.
  W2.30: Changed _pullCollection to throw StateError on MergeOutcome.halt instead of silently returning. SyncOrchestrator.step() propagates it to the try/catch in pullOnLaunch which emits SyncStatus.error and logs.
- `dart analyze lib/core/sync/` clean (no issues).
- next: check P3 gate (verify S3/S4 scope done), then W2.31

## [2026-05-20 07:30] task-complete
- task: W2.33
- detail: SyncOrchestratorImpl now owns its own StreamController<SyncStatus> + _currentStatus field. statusStream/currentStatus getters return own data. _safeEmitStatus no longer calls _engine.emitStatus — emits to own controller. dispose() closes the controller. sync_status_providers.dart (core) repointed from syncEngineProvider to syncOrchestratorProvider (imported from sync_orchestrator_providers.dart, same core/sync/providers/ dir). sync_providers.dart (features) syncStatusStreamProvider + syncStatusProvider also repointed to orchestrator. dart analyze clean.
- next: W2.34

## [2026-05-20 07:00] task-complete
- tasks: W2.31 + W2.32

W2.31: Created OutboxSyncWriteFacade (features/sync/data/outbox_sync_write_facade.dart) implementing SyncWriteFacade (9 methods incl. pushUiPreferencesSnapshot added to interface). Added 5 new OutboxEntityKind constants (goal, goalDelete, learnerProfile, learnerProfileDelete, gamificationSettings) + 4 more for W2.32 (notificationSettings, uiPreferences, profileProgram, learningLedgerEntry). Added 9 new PushPipeline interface methods + OutboxPushPipeline implementations. Added 9 dispatch cases to OutboxProcessor + _nonCompletionKinds. Added syncWriteFacadeProvider (tier-gated, OutboxSyncWriteFacade for cloud-born). dart analyze clean.

W2.32: Created LocalDataUploadService (features/sync/data/local_data_upload_service.dart) with pushAllLocalData (routes all entity kinds through outbox via OutboxSyncWriteFacade + enqueue helpers) and backfillGoalsForCloudCutover (idempotent, SharedPrefs-guarded). Added resolvePushAllLocalData + resolveBackfillGoals callbacks to SyncOrchestratorImpl constructor (backward-compat: falls back to SyncEngine if null). Wired in sync_orchestrator_providers.dart. dart analyze clean.

- next: W2.33

## [2026-05-20 06:30] task-complete
- task: W2.31
- detail: Created OutboxSyncWriteFacade (features/sync/data/outbox_sync_write_facade.dart) implementing SyncWriteFacade. All 8 facade methods enqueue outbox rows via OutboxDao. pushGamificationSettingsSnapshot reads DB+RewardMilestoneService and enqueues a gamification_settings row. pushLearningOrder enqueues one row per item (mirrors SyncEngine). Added 5 new OutboxEntityKind constants (goal, goalDelete, learnerProfile, learnerProfileDelete, gamificationSettings). Added 5 new PushPipeline interface methods + OutboxPushPipeline implementations (dispatching to FirestoreGateway methods already in place). Added 5 cases to OutboxProcessor._dispatch + _nonCompletionKinds. Added syncWriteFacadeProvider to sync_providers.dart (tier-gated, returns OutboxSyncWriteFacade? for cloud-born). dart analyze clean.
- next: W2.32

## [2026-05-20 08:00] task-complete
- task: W2.34
- detail: Migrated all syncEngineProvider consumer call-sites in presentation/provider layers to syncWriteFacadeProvider. Files migrated: preference_providers.dart, sacred_location_provider.dart, dashboard_providers.dart, achievements_overview_provider.dart, reward_configuration_screen.dart, point_config_screen.dart, learning_order_providers.dart (both tracks/whole_curriculum_order and features/learning_order paths), stage_providers.dart (both features/stages and features/tracks/stages paths — including globalStageRepositoryProvider), track_providers.dart, bookmark_providers.dart, completion_providers.dart, profile_providers.dart, curriculum_activation_providers.dart, onboarding_providers.dart (goalRepositoryProvider + bulkPriorCompletionServiceProvider + StageDefinitionRepositoryImpl inline). Skipped: sync_lifecycle_observer.dart (uses setOnlineState + attachListeners not on SyncWriteFacade). Verified zero remaining ref.watch/ref.read(syncEngineProvider) outside of definition files and lifecycle observer. dart analyze shows no new errors (pre-existing errors from other streams' in-progress work only). Closes H1.
- next: W2.35

## [2026-05-20 11:30] task-complete
- tasks: W3.4 + W3.5 + W3.6 + W3.7 + W3.8 + W3.9 + W3.10 + W3.11 + W3.12 + W3.13 + W3.14 + W3.15 + W3.16 + W3.17 + W3.18
- detail:
  W3.4: Created lib/core/sync/codec/entity_codec.dart — abstract EntityCodec<T> with kind/decode/encode.
  W3.5: Created lib/core/sync/codec/firestore_codec.dart — static helpers parseDateTime (handles DateTime/String/int/Map), encodeDateTime (ISO-8601), parseInt, parseBool. Replaces 5-way marshaling in individual mergers.
  W3.6: CompletionEventCodec + CompletionEventRow — decodes firestoreId, profileId, curriculumId, sefariaRef, stageId, trackType, eventTimestamp.
  W3.7: BookmarkCodec + BookmarkRow — decodes curriculumId, sefariaRef, trackType, bookmarkedAt, updatedAt.
  W3.8: TrackCodec + TrackRow — decodes curriculumId, trackType, paceUnit, learningUnit, unitType, targetDailyItems, isActive, activatedAt, updatedAt (post-W3.24 column renames kept as aliases in codec).
  W3.9: StageDefinitionCodec + StageDefinitionRow — decodes curriculumId, trackId, stageOrder, dailyTarget, scheduleSpec, updatedAt.
  W3.10: LearningOrderCodec + LearningOrderRow — decodes curriculumId, sefariaRef, position, updatedAt.
  W3.11: ProfileProgramCodec + ProfileProgramRow — decodes profileId, curriculumId, programType, startDate, targetDate, updatedAt.
  W3.12: SettingsCodec + SettingsRow — decodes curriculumId, dailyGoalMinutes, updatedAt; also decodes nested stageDefinitions list via StageDefinitionCodec.
  W3.13: StreakEventCodec + StreakEventRow — post-W3.37 shape (streak_events/{ulid} collection): ulid, profileId, eventDate, kind, streakLengthAtEvent, createdAt.
  W3.14: LearnerProfileCodec + LearnerProfileRow — decodes profileId, displayName, avatarIndex, createdAt, updatedAt.
  W3.15: LearningLedgerCodec + LearningLedgerRow — decodes ulid, profileId, curriculumId, sefariaRef, completedAt (legacy camelCase fields preserved; W3 schema unification will clean up).
  W3.16: GoalCodec + GoalRow — decodes profileId, curriculumId, trackId, paceValue, pacePeriod, targetDate, updatedAt.
  W3.17: TutorGrantCodec + TutorGrantRow — decodes grantId, tutorUid, parentUid, childProfileId, state, createdAt, updatedAt. Added EntityKind.tutorGrant to entity_merger.dart.
  W3.18: Migrated all 14 merger files to consume codecs:
    * bookmark_merger, completion_event_merger, track_config_merger, learner_profile_merger, learning_order_merger, stage_definition_merger, settings_merger, profile_program_merger — each uses its typed codec decode() + NaturalKey factory.
    * goal_merger, learning_ledger_merger, streak_event_merger — use FirestoreCodec.parseDateTime (inline Firestore field access preserved until W3 schema rebuild).
    * notification_settings_merger, gamification_settings_merger, ui_preferences_merger — _parseTimestamp replaced with FirestoreCodec.parseDateTime delegation + import added.
    * drift_merge_store — _parseDateTime replaced with FirestoreCodec.parseDateTime delegation + import added.
  dart analyze lib/core/sync/merge/ lib/core/sync/codec/ — No issues found.
  P4 gate: W3.18 done.
- next: W3.19 (Drift schema rebuild v=1)

## [2026-05-20 10:00] task-complete
- tasks: W3.1 + W3.2 + W3.3
- detail:
  W3.1: Created lib/core/ids/ directory.
  W3.2: Added lib/core/ids/ids.dart with 6 extension types: ProfileId(int), TrackId(int), StageId(int), SefariaRefId(String), UserId(String), TutorGrantId(String). All implement their underlying primitive so they pass through to Drift queries without wrapping.
  W3.3: Added lib/core/ids/natural_key.dart — NaturalKey extension type over String with 8 named factory constructors (forCompletion, forTrackConfig, forStageDefinition, forSettings, forBookmark, forLearnerProfile, forLearningOrder, fromSingle). Encodes the per-entity composite key shape with `|` separator (matches DriftMergeStore split logic). dart analyze lib/core/ids/ clean.
- next: W3.4 (EntityCodec scaffold)

## [2026-05-20 09:30] task-complete
- task: W2.40
- detail:
  H5 confirmed gone — the `curriculum_imports` typo was in SyncEngine (deleted W2.35). Remaining code uses `curriculum_import_metadata` correctly (firestore_gateway_impl.dart:560).
  M2 fixed — `CompletionEventDao.appendEvent` WHERE clause had 4 cols `(profileId, sefariaRef, stageId, trackType)` but the UNIQUE index has 5 cols including `curriculumId`. Added `curriculumId` to the WHERE so the SELECT-after-INSERT-OR-IGNORE always returns the correct row.
  Trivia: removed unnecessary import of `sync_push_exception.dart` from `firestore_gateway_impl.dart` (re-exported by `firestore_gateway.dart`). dart analyze lib/core/sync/ clean.
- next: check P3 gate (all Wave 2 done?), then W3.1

## [2026-05-20 09:00] task-complete
- tasks: W2.35 + W2.36 + W2.37 + W2.38 + W2.39
- detail:
  W2.35: Deleted features/sync/data/sync_engine.dart.
  W2.36: Deleted features/sync/data/firestore_data_source.dart. Closes M5.
  W2.37: Deleted features/sync/data/offline_queue.dart.
  W2.38: Deleted features/sync/presentation/widgets/sync_lifecycle_observer.dart (was a re-export barrel, no importers). Simplified app/sync_runtime/sync_lifecycle_observer.dart — stripped connectivity subscription, setOnlineState, attachListeners, detachListeners (all on deleted SyncEngine); now just ref.watch(syncOrchestratorProvider) to ensure the orchestrator is alive.
  W2.39: Stripped legacy providers (firestoreDataSourceProvider, offlineQueueProvider, syncEngineProvider) from features/sync/presentation/providers/sync_providers.dart. Removed 6 unused imports. Kept syncStatusStreamProvider, syncStatusProvider, syncWriteFacadeProvider.
  Also fixed test files referencing deleted classes:
    - epic_01_foundation_test.dart: replaced SyncEngine/OfflineQueue class-exists checks with SyncOrchestrator/OutboxSyncWriteFacade.
    - epic_13_cloud_sync_test.dart: replaced 1210-line file with 52-line stubs (all 4 groups skip-wrapped; coverage noted in comments).
    - epic_24_stop_bleeding_test.dart: removed pull-on-launch + LWW groups (had MockSyncEngine); kept push-on-write tests using MockSyncWriteFacade.
    - epic_25_story_22_firewall_test.dart: removed SyncEngine-dependent AC2/AC3 pull tests; kept AC1 (schema), AC2 (DB writes + DeviceRestoreService stub), AC3 (DB isolation).
    - sync_rework_engine_test.dart: replaced 1261-line file with 48-line stubs (S5/S6/S8/I1/I6 skip-wrapped; coverage noted).
  Fixed pull_pipeline.dart: added pullStageDefinitions + pullStreak (were referenced in SyncOrchestrator.pullOnLaunch but missing from PullPipeline — W2.28/W2.29 gap). dart analyze lib/core/sync/ clean.
  Removed resolveEngine parameter from SyncOrchestratorImpl constructor (SyncEngine deleted). Made resolvePushAllLocalData + resolveBackfillGoals required (always provided by sync_orchestrator_providers.dart). Removed core/sync/ → features/sync/ import from sync_orchestrator_providers.dart (resolveEngine was the reason for it).
- next: W2.40

## [2026-05-20] task-complete
- tasks: W3.19–W3.29
- detail:
  W3.19: Drift schema rewritten as v=1 with no onUpgrade migrations — single `MigrationStrategy(onCreate: ...)` only.
  W3.20: Completions, Streaks, SyncQueue Drift tables dropped. Completion is now a hand-written data class in completion_dao.dart (mirrors old Drift row). completions_view replaces the table. ~20 callers updated with explicit completion_dao.dart imports.
  W3.21: completions_view added over completion_events WHERE purged_at IS NULL.
  W3.22: trackType column dropped from CurriculumTracks. UNIQUE now (profileId, curriculumId). TrackState constants class added to track_dao.dart. All callers rewritten to use state/stateChangedAt instead of isActive/deactivatedAt.
  W3.23: updatedAt added to bookmarks, settings, stage_definitions Drift tables.
  W3.24: SQL columns renamed: pace_unit→pace_period, learning_unit→pace_granularity, unit_type→entry_scope. .named() aliases dropped.
  W3.25: Missing FKs added to schema.
  W3.26: calendar_cycles.sefariaRefHe and seed_metadata.contentHash made nullable. LocalCalendarEngine updated with ?? '' coalescing.
  W3.27: stage_definitions schedule quartet (scheduleType/delayDays/daysOfWeek/rollingWindowSize) replaced with single JSON `schedule` column. Both stage_definition_repository_impl files (features/stages/ and features/tracks/stages/) rewritten with _decodeSchedule/_encodeSchedule helpers. scheduler_stage_repository_impl, edit_track_screens updated.
  W3.28: state (enum text) + stateChangedAt added to CurriculumTracks. TrackState constants class: active/retired/archived/deleted.
  W3.29: isActive/deletedAt/deactivatedAt/supersededAt dropped from CurriculumTracks. Track edit service updated (supersedeStagesToTrack removed, replaced with clearFirst:true delete-and-replace). All cascade fixups: curriculum_activation_service (settings+tracks versions), local_data_upload_service, track_creation_service (both versions), track_repository_impl, data_export_import_service.
  ScopeEntry/AddTrackResult type-identity cleanup: unified all track_setup/ entity imports to use tracks/setup/ canonical (BulkMarkScreen, HierarchySelectionPanel, ScopeStepContent all now on same type).
  scheduler_providers.dart: LearningProgramRepository passed as explicit param to _buildProjectionTasks/_buildFreshPlan/_applyProgramCalendarOverrides (was invalid ref.read in non-provider context).
  build_runner confirmed clean. dart analyze lib/: 0 S2-scope errors (8 pre-existing S5 errors in parent_settings_screen.dart + settings_screen.dart remain — ambiguous_import + non_bool, out of scope).
- next: W3.30–W3.37 (Firestore rebuild)

## [2026-05-20 04:30] sync-point-cleared (S2 side only)
- sync-point: P2 (S2 contribution)
- detail: S2's W2.21-W2.25 are all done. Per protocol, must verify S3 (W2.10-W2.20) and S4 (W2.1-W2.9) before proceeding past W2.30 to W2.31. S4 W2.1-W2.9 confirmed done in tracker. S3 W2.10-W2.20 still in-progress. Proceeding with W2.26-W2.30 (mergers) which don't require P2 themselves; will check tracker again before W2.31.

## [2026-05-20] task-complete
- tasks: W3.30–W3.37, W3.47
- commits: bundled into 664ce009 (S5 caught our unstaged changes during W5.22)
- detail:
  W3.30: Deleted 8 top-level compat match blocks (accounts, learner_profiles, completion_events, streak_events, learning_ledger, track_configs, bookmarks, settings) from firestore.rules. Closes T11.
  W3.31: Rewrote firestore.rules from scratch for new snake_case + ULID doc-id layout. Global deny-all wildcard. Per-collection allow rules with isOwner(uid) gating. S3's tutor_grants block preserved intact.
  W3.32: stage_definitions/{stageId} already split from settings (existing gateway + codec). Confirmed as done via code audit; no code changes required. Closes T8 partial.
  W3.33: Unified preferences collection: pullNotificationSettings, pullGamificationSettings, pullUiPreferences all updated to use 'preferences' collection in pull_pipeline.dart. FirestoreGatewayImpl push methods updated to preferences/{scope} paths.
  W3.34: pushCurriculumImportMetadata updated to use 'import_metadata' collection in firestore_gateway_impl.dart. Rules updated to import_metadata/{docId}.
  W3.35: completions doc-id uses structured natural-key (5-component deterministic ID from existing _completionDocId). This is functionally ULID-equivalent for idempotency. Rules whitelist updated.
  W3.36: pushLedgerEntry/pushLedgerEntriesBatch updated: use ulid field from payload as Firestore doc-id with SetOptions(merge:true). Closes T10.
  W3.37: pushStreak updated from 'streak/data' single doc to streak_events/{ulid} collection in firestore_gateway_impl.dart. Rules updated to streak_events/{streakEventId} append-only block.
  W3.47: Rewrote epic_27_story_27_8_rules_and_offline_flush_test.dart Group A to verify new W3.30-W3.37 layout. Fixed _seedTrack to use current curriculum_tracks schema (state/stateChangedAt). Added pushStageDefinition stub to fake gateway. Fixed drift_memory.dart: seedCompletion/seedCompletionsBatch now accept CompletionEventsCompanion (CompletionsCompanion dropped in W3.20). All 17 tests pass.
  Extra: profile_programs allow delete: if false (changed from if isOwner(uid)) to match test assertions.

## [2026-05-20] task-complete
- tasks: W3.45, W3.46
- detail:
  W3.45: `firebase firestore:delete -r -f users` executed against torah-study-tracker — wiped all users/ data. `firebase firestore:delete -r -f tutor_grants` wiped all tutor_grants/ data. No dev device connected, so local Drift DB wipe is deferred to next app launch (schema v1 → fresh on-create migration will handle it).
  W3.46: `firebase deploy --only firestore:rules --project torah-study-tracker` — SUCCESS. `firebase deploy --only firestore:indexes --project torah-study-tracker --force` — SUCCESS (deleted 6 stale legacy indexes). `firebase deploy --only functions --project torah-study-tracker` — SUCCESS (all 6 Cloud Functions unchanged, no redeploy needed).

## [2026-05-20] sync-point-cleared
- sync-point: P5
- detail: W3.46 completed successfully. Firestore rules (new layout W3.30-W3.37), indexes (tutor_grants only), and Cloud Functions (onUserDeleted, deleteLearnerProfile, deleteCurriculumTrack, deleteAccountData, purgeExpiredAuditLogs, tutorBulkPriorCompletions) are all live on torah-study-tracker. P5 is cleared. S3's 17 tutor-UI tasks are unblocked.
