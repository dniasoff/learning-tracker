# Sync Subsystem — Architecture Plan

Goal: reliable (no data loss), quick, efficient, low-bandwidth, low-CPU/battery, minimum Firestore cost.
Status: pre-launch (no live users — `project_pre_launch_status` memory).
Author: architecture review 2026-05-21.

This document has six parts:
- **A. Current-state audit** — what exists, with file:line refs and a ranked findings list.
- **B. NFR targets** — quantified.
- **C. Target architecture** — the smallest set of changes that lands all NFRs.
- **D. Trigger graph + cost model** — exactly when sync runs and what each run costs.
- **E. Risk register** — what can still go wrong and how we'd notice.
- **F. Rollout plan** — phased, each phase independently verifiable.

---

# Part A — Current-state audit

Scope: map the live code in `learning_tracker/lib/` so the design brief can name every gap. All file paths absolute under that root.

## 1. Write paths (table)

| Entity | UI/use-case entry | Drift target | Outbox enqueue? | Idempotent? | Notes |
|---|---|---|---|---|---|
| Completion (mark) | `CompletionRepositoryImpl._createCompletion` → `CompletionWriter.commit`/`commitBatch` (`lib/features/learning/data/completion_writer.dart:546,82`) | `completion_events` (INSERT OR IGNORE on natural key) | **Yes** kind=`completion`, in same transaction (`completion_writer.dart:218,687`) | Yes — Firestore doc id derived from `(profileId, sefariaRef, stageId, trackType, curriculumId)` via `_completionDocId` in `firestore_gateway_impl.dart:93` | The only path that touches `outbox` in the same `db.transaction()` as the write. Streak tee write right next to it is NOT in the outbox (see streak row). |
| Completion (resurrect after tombstone) | Same writer, `_resurrectTombstone` (`completion_writer.dart:452`) | Clears `purgedAt` | Yes — one outbox row per resurrection | Same key derivation | OK. |
| Completion (B8 upgrade) | `_upgradePriorMarkRow` (`completion_writer.dart:484`) | Updates `eventTimestamp` | Yes | Idempotent | OK. |
| Completion (tombstone via expunge) | `BulkPriorCompletionService.expungePriorCompletions` (`lib/features/onboarding/domain/services/bulk_prior_completion_service.dart:334`) | Sets `purgedAt` | Yes — one outbox row per tombstoned event (`bulk_prior_completion_service.dart:414`) — but ONLY when `_outboxDao != null` | Yes | Conditional: tests can construct the service without the DAO and tombstones never propagate. |
| Bookmark (set) | `BookmarkRepositoryImpl.setBookmark` → `_syncEngine?.pushBookmark` (`lib/features/learning/data/repositories/bookmark_repository_impl.dart:322`) | `bookmarks` upsert (DAO does the write before the push) | Via outbox (`OutboxSyncWriteFacade.pushBookmark`, kind=`bookmark`) | Doc id = `${curriculumId}_${trackType}` (`firestore_gateway_impl.dart:337`) | Drift write + outbox insert are not in one transaction (separate awaits). |
| Bookmark (set during track creation) | `TrackCreationService` → direct `_gateway?.pushBookmark` (`lib/features/tracks/setup/domain/services/track_creation_service.dart:317`) | bookmarks upsert | **NO outbox — direct Firestore** | Yes (same doc id) | **Bypasses outbox.** Silent loss if offline at create time. |
| Curriculum track (create/edit/delete) | `TrackRepositoryImpl._pushCurriculumTrackIfCloud` (`lib/features/learning/data/repositories/track_repository_impl.dart:35`) and `CurriculumActivationService._pushCurriculumTrack` (`lib/features/tracks/domain/services/curriculum_activation_service.dart:179`) | `curriculum_tracks` | Via outbox kind=`track` | Doc id = `curriculumId` (`firestore_gateway_impl.dart:304`) | OK. Track-soft-delete also writes directly via `TrackDao.deleteTrack` → `outbox` (`lib/core/database/daos/track_dao.dart:215`). |
| Goal (create/update) | `GoalRepositoryImpl._syncGoal` (`lib/features/scheduler/data/repositories/goal_repository_impl.dart:208`) | `goals` | Via outbox kind=`goal` | Doc id from payload `id`/`goal_id` (`firestore_gateway_impl.dart:529`); fallback to `collection.add()` (non-idempotent if `id` missing) | One-time `LocalDataUploadService.backfillGoalsForCloudCutover` (`lib/features/sync/data/local_data_upload_service.dart:239`) catches missed pre-cutover goals on first launch. |
| Goal (delete) | `GoalRepositoryImpl._syncDeleteGoal` (`goal_repository_impl.dart:224`) | local row deleted | Via outbox kind=`goal_delete` | Yes | OK. |
| Streak event (tee on completion) | `CompletionRepositoryImpl._appendStreakEvent` (`lib/features/learning/data/repositories/completion_repository_impl.dart:698`) | `streak_events` (insertOrIgnore on `(profileId,eventTimestamp,eventType)`) | **NO outbox** | Locally idempotent | **Silent gap.** Cloud only gets streak events via `LocalDataUploadService.pushAllLocalData` (upgrade-to-cloud only). Day-to-day streak events never replicate. |
| Streak event (restorer) | `StreakRestorer` via `StreakEventLog` (`lib/features/gamification/streak/streak_event_log.dart`) | `streak_events` | **NO outbox** | Yes | Same gap. |
| Learning ledger entry | `LearningLedgerRepositoryImpl.recordCompletion` → `_firestoreGateway?.pushLedgerEntry` (`lib/features/learning/data/repositories/learning_ledger_repository_impl.dart:58`) | `learning_ledger` insert | **NO outbox — direct Firestore** | Doc id = ULID from payload (`firestore_gateway_impl.dart:415`) | **Bypasses outbox.** Silent if offline. Batch variant `pushLedgerEntriesBatch` has the same problem. |
| Notification settings | `_persistNotificationSettingsToCloud` → `gateway.pushNotificationSettings` (`lib/features/notifications/presentation/providers/notification_providers.dart:230`) | SharedPreferences | **NO outbox — direct Firestore** | Doc = `preferences/notification_settings` (`firestore_gateway_impl.dart:347`) | **Bypasses outbox.** |
| Profile program (assignment) | `TrackCreationService._gateway?.pushProfileProgram` (`track_creation_service.dart:327`) and `edit_track_screen.dart:326` | `profile_programs` | **NO outbox — direct Firestore** | Doc id = `curriculumId` | **Bypasses outbox.** Reanchor flow same gap. |
| Learner profile (create/update) | `ProfileRepositoryImpl` → `_syncEngine?.pushLearnerProfile` (`lib/features/profiles/data/repositories/profile_repository_impl.dart:100,152`) | `learner_profiles` | Via outbox kind=`learner_profile` | Doc id = `profileId` (`firestore_gateway_impl.dart:797`) | OK. |
| Learner profile (delete) | `ProfileRepositoryImpl.deleteProfile` → `_syncEngine?.deleteLearnerProfile` | Tombstone in SharedPrefs locally | Via outbox kind=`learner_profile_delete` | Cloud Function `deleteLearnerProfile` | OK but recursive Cloud-Function cost. |
| Gamification settings (point configs, milestones) | Many sites: `dashboard_providers.dart:301`, `reward_config_controller.dart:147`, `point_config_screen.dart:151,202`, `completion_repository_impl.dart:207,291`, `achievements_overview_provider.dart:91` — all call `syncWriteFacade.pushGamificationSettingsSnapshot()` | `point_configs` + `RewardMilestoneService` state | Via outbox kind=`gamification_settings` (snapshot rebuilt every call) | Doc = `preferences/gamification_settings` | Snapshot rebuilds on every change → potentially many full-snapshot writes per session. |
| UI preferences (locale, Hebrew terms, nikud, font size, learning-order parent ctrls, Hebrew calendar) | `core/preferences/preference_providers.dart:75 (_writeAndPushSnapshot)` for nearly every preference; plus `sacred_location_provider.dart:89,114` | SharedPreferences | Via outbox kind=`ui_preferences` (snapshot) | Doc = `preferences/ui_preferences` | Snapshot rebuild on every toggle. |
| Learning order | `LearningOrderRepositoryImpl` → `_syncEngine?.pushLearningOrder` (`lib/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart:150,172`) | `track_learning_order` | Via outbox kind=`learning_order` — **one row per item** (`outbox_sync_write_facade.dart:84-94`) | Doc id = `${curriculumId}_${ref}` | High-cost: a 100-item curriculum reorder = 100 outbox rows + 100 Firestore writes. No batching. |
| Stage definitions | `StageDefinitionRepositoryImpl._pushSettings` (`lib/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart:379`) | `stage_definitions` | Routes through `pushSettings` (kind=`settings`) — semantics overlap. There is *also* a `stage_definition` outbox kind / `pushStageDefinition` path but the actual repo uses `pushSettings`. Sync orchestrator pulls both `stage_definitions` and `settings` so the merge happens, but the push path is doubled-up. | Doc id derived from `curriculum_id` for settings or `${trackId}_${stageOrder}` for stage_definitions | **Confusing duplication** — stage_definitions push is dead code in production? Worth verifying. |
| Tutor grant | Tutor feature uses `FirestoreTutorGrantRepository` (Cloud-Functions / direct Firestore, `lib/features/tutoring/presentation/providers/manage_tutors_providers.dart:17`). No outbox. No Drift row. | n/a | **NO outbox** | Server-driven | Tutor grants live in Firestore only; merge is a no-op (`TutorGrantMerger`) and the listener for the `tutor_grants` collection is NOT registered in `FirestoreListenerSource`. |
| Study-day config | `TrackCreationService._saveStudyDays` (`track_creation_service.dart:339`) → `studyDayConfigDao.upsertDayConfig` | `study_day_configs` | **NO outbox** | n/a | **Silent gap.** No push or pull path. Per-curriculum/per-track study-day pattern is local-only. |
| Sacred-time prefs (lat/lon/city/in_israel) | `core/preferences/preference_providers.dart` → bundled into UI prefs snapshot ONLY for profileId == 0 (`outbox_sync_write_facade.dart:217-233`) | SharedPreferences | Indirect via UI prefs snapshot | profileId == 0 only | Multi-profile users on the same device lose sacred-time prefs across reinstall. |
| Account profile (users/{uid}) | `pushAccountProfile`/`pushAccountUserProfile` — direct via gateway | n/a | **NO outbox** | Doc id = uid | Direct Firestore write. Low frequency but offline-fragile. |
| Diagnostic logs | `pushDiagnosticLog` direct via gateway | n/a | **NO outbox** | Doc id auto | Acceptable (best-effort telemetry). |
| Prior-completion imports | Co-written with completions in `CompletionWriter`; expunged via `BulkPriorCompletionService` | `prior_completion_imports` table | **NO outbox** (the tombstone-only `completion_events` rows enqueue, but the import provenance row itself does not) | Local provenance only | Local-only by design; no cloud counterpart. |

## 2. Pull paths (table)

Pull collection layout: `users/{uid}/learner_profiles/{profileId}/<collection>` (see `firestore_gateway_impl.dart:847`).

| Collection | Pull-on-launch | Listener? | Merger | Conflict rule | Notes |
|---|---|---|---|---|---|
| `completions` | Yes (paged, 200/page) — `pullCompletions` `sync_orchestrator.dart:506` | Yes — `FirestoreListenerSource:46` | `CompletionEventMerger` (`merge/completion_event_merger.dart`) — `insertIfAbsent` on natural key | Append-only; duplicate = no-op. **No LWW** — first writer wins; reactivation via `purged_at`. | Paginates ordered by `FieldPath.documentId`. |
| `bookmarks` | Yes | Yes | `BookmarkMerger` (LWW on `updated_at`) | LWW client-timestamp | `DriftMergeStore.currentUpdatedAt(bookmark)` always returns null (`drift_merge_store.dart:80`) — **remote always wins on first sync, even when local is newer.** |
| `settings` | Yes | Yes | `SettingsMerger` (LWW) | Client-timestamp LWW | `currentUpdatedAt(settings)` returns null too — same staleness risk. |
| `curriculum_tracks` | Yes | Yes | `TrackConfigMerger` (LWW on `state_changed_at`) | Client-timestamp LWW | OK. |
| `stage_definitions` | Yes | Yes (added W2.29) | `StageDefinitionMerger` | Pulled doc carries `updated_at` from enclosing settings doc | Merger logic reads `currentUpdatedAt → null` — remote-wins. |
| `streak_events` | Yes | Yes | `StreakEventMerger` — append-only via `StreakEventLog` | Idempotent on UNIQUE `(profileId,eventTimestamp,eventType)` | No client streak push (gap above) means listener only ever sees old data. |
| `goals` | Yes | **No real-time listener** | `GoalMerger` | LWW client `updated_at` | Real-time gap — second device sees goal changes only on next pull-on-launch. |
| `learning_ledger` | Yes | **No real-time listener** | `LearningLedgerMerger` | Append-only on ULID | Listener missing. |
| `preferences/notification_settings` | Yes (single doc) | **No real-time listener** | `NotificationSettingsMerger` | LWW on `updated_at` | Listener missing. |
| `preferences/gamification_settings` | Yes (single doc) | **No real-time listener** | `GamificationSettingsMerger` (without `onRewardSettings` — wired `null` in `merge_router_provider.dart:67`) | LWW on `updated_at` | **Reward settings merge is a no-op** — see Findings. |
| `preferences/ui_preferences` | Yes (single doc) | **No real-time listener** | `UiPreferencesMerger` | LWW client `updated_at` | Listener missing. |
| `learner_profiles` (account-level) | Yes (special-case in `pullLearnerProfiles`) | **No listener** | `LearnerProfileMerger` (LWW) | LWW | Fetched as a single batch from `users/{uid}/learner_profiles/`. |
| `learning_order` | Yes | **No listener** (intentional — comment in `firestore_listener_source.dart:28`) | `LearningOrderMerger` | LWW | Real-time gap; non-batched push exacerbates cost. |
| `profile_programs` | Yes | **No listener** | `ProfileProgramMerger` | LWW client `updated_at` | Listener missing. |
| `tutor_grants` (root collection) | **Not pulled in the standard pipeline** | **No listener** | `TutorGrantMerger` (no-op) | Read live via `FirestoreTutorGrantRepository` | Tutor data flows outside the sync subsystem entirely. |
| `audit_log/{grantId}` | On-demand read via `fetchAuditLogEntries` | No listener | No merger | n/a | Used by tutor audit screen. |
| Server timestamps | All push paths add `synced_at: FieldValue.serverTimestamp()` (`firestore_gateway_impl.dart:210, 235, 271, 287, …`) | n/a | n/a | **Not consulted by mergers** — every LWW path uses the client `updated_at`. `synced_at` is metadata only. |

## 3. Listener footprint

Six subcollection listeners are opened by `FirestoreListenerSource.openChannels` (`lib/core/sync/firestore_listener_source.dart:40-77`):

- `completions`, `bookmarks`, `settings`, `streak_events`, `curriculum_tracks`, `stage_definitions`.

Lifetime:
- Opened on `ListenerSupervisor.start()` invoked from `SyncOrchestratorImpl.start()` (`sync_orchestrator.dart:339`).
- Closed only on `SyncOrchestratorImpl.dispose()` — the orchestrator is a `keepAlive` Riverpod singleton (`sync_orchestrator_providers.dart:51`). In practice listeners stay open **for the entire app session, including while the app is backgrounded** — Flutter does not detach Firestore listeners on background; they continue to consume Firestore reads.
- A profile switch triggers `restartListeners()` (`sync_orchestrator.dart:691`) — listeners get rebound to the new profile but the previous set is cancelled first.

Pagination / limits:
- `listenToCollection` uses unfiltered `ref.snapshots()` (`firestore_gateway_impl.dart:681`) — **no `.limit()`**. Every doc in the subcollection arrives in every snapshot. For a heavy user (10k+ completions over years) that is a 10k-doc snapshot on every change.
- The implementation suppresses local echoes by examining `hasPendingWrites` per doc; suppression is per-snapshot, not per-event.

Indexes:
- `firestore_gateway_impl.dart:472` documents "no composite Firestore index is required" — `fetchPage` orders by `FieldPath.documentId`; queries do not combine `.where()` with `.orderBy()` on non-documentId fields. **No missing indexes.**

Channels NOT listened to:
- `goals`, `learning_ledger`, `learning_order`, `profile_programs`, `learner_profiles`, `preferences/*` (notification/gamification/ui). Multi-device changes to these only show up on next pull-on-launch (gated by `pullOnResumeMinInterval = 5 min` for resume-triggered pulls).

## 4. Outbox state machine

`OutboxProcessor.drain(profileId)` (`lib/core/sync/outbox/outbox_processor.dart:123`):
- Phase 1 — completions: collect up to `_completionDrainCeiling = 100000` pending completion rows; filter out those with `attempts >= _maxAttempts = 10` (dead-lettered) and those whose `_nextAttemptAt` is in the future. **De-duplicate by `entityKey`** before dispatch (multiple rows with same key all collapsed to one push because doc-id is deterministic). One call to `PushPipeline.pushCompletionsBatch` chunked into ≤500-op `WriteBatch`es. Partial-failure path uses `BatchPushException.committed` to delete only the rows that genuinely landed.
- Phase 2 — non-completion kinds (deterministic order `streak, track, learning_order, bookmark, settings, stage_definition, goal, goal_delete, learner_profile, learner_profile_delete, gamification_settings, notification_settings, ui_preferences, profile_program, learning_ledger_entry`): drain ≤50 rows per kind (`_batchSize`); one push per row.
- Backoff: `_backoffBase = 30 s × 2^(attempts-1)`, capped at `_maxBackoff = 1 h`, ±20% jitter (`_backoffJitter`). Dead-letter at 10 attempts — silently skipped forever, fires `outbox_dead_lettered` analytics.
- Dedup logic: at-call de-dup by `entityKey` for completions. Non-completion rows have **no dedup** — re-enqueuing the same key (e.g. snapshot rebuilds on prefs change) piles up rows; each is a separate push.

**The headline bug:** `outboxProcessorProvider` is registered (`lib/core/sync/providers/outbox_providers.dart:40`) but `drain()` is never invoked from production code. `grep` for `\.drain(` in `lib/` returns zero matches outside `outbox_processor.dart` itself. Every entity ever written to the outbox table since the W2.31/W2.32 cutover sits there until either (a) something else triggers a drain (nothing does), or (b) the device is reinstalled and the local DB is wiped. Tests call `drain()` directly. **The outbox is a write-only sink in production.**

Other concerns:
- `markAttempted` does a read-modify-write outside a transaction (`outbox_dao.dart:46`) — race with a concurrent drain could miscount attempts (no concurrent drain today, but a future scheduled drain must serialise).
- `outbox` table has no UNIQUE index on `entityKey` (`outbox_table.dart:23` — comment confirms). Completion pre-existence is guarded in `CompletionWriter`; non-completion kinds have no guard, so repeated calls (e.g. `pushUiPreferencesSnapshot` triggered on every toggle in `preference_providers.dart`) leak duplicate rows.
- Snapshot kinds (`gamification_settings`, `ui_preferences`, `notification_settings`) carry the full state each time — every toggle queues a full snapshot.

## 5. Cost-per-action estimates

Operations per user action (Firestore writes/reads), based on the wiring above. "If drain runs" is the relevant qualifier because production never drains.

- **Mark one completion (single section, single stage):**
  - 1 outbox row (completion). On drain → 1 batched Firestore write to `completions/{docId}`.
  - The streak tee writes to local `streak_events` but never to Firestore (gap).
  - Gamification snapshot push fires for child-mode + awardGamificationPoints (`completion_repository_impl.dart:207, 291`) → 1 outbox row → 1 Firestore write to `preferences/gamification_settings` (full-snapshot doc).
  - Net (cloud-born child profile, points awarded): **2 outbox rows → 2 Firestore writes**. Plus the listener echo (suppressed).
- **Mark one completion (track with 3 stages, all auto-marked):** 3 completion outbox rows → 1 batched WriteBatch (3 doc sets). Streak tee local-only. Plus 1 gamification snapshot push.
- **Bulk-mark prior 100 items × 3 stages:** 300 outbox rows in one `CompletionWriter.commitBatch` → 1 batch commit (300 doc sets, well under the 500-op chunk size). No streak/points snapshot (engagement suppressed). Plus the tombstone propagation path runs separately if items are later un-ticked: one outbox row per tombstoned event.
- **Toggle one UI preference (e.g. nikud):** 1 SharedPrefs write + 1 full UI-prefs snapshot outbox row → 1 Firestore write to `preferences/ui_preferences`. Multiple toggles in rapid succession queue multiple snapshots — none are de-duplicated.
- **Pull-on-launch (typical mid-account):** 14 sequential entity pulls (`sync_orchestrator.dart:502-563`). For each pull, paginated 200/page until empty. Light account ≈ 14 reads; heavy account with 5000 completions ≈ 25 page reads for completions alone + others. Order: completions, bookmarks, settings, tracks, learner_profiles, learning_order, profile_programs, stage_definitions, streak_events, goals, learning_ledger, notification_settings, gamification_settings, ui_preferences.
- **Pull-on-launch (fresh install / restore):** Full read of every subcollection. For a user with N completions, M streak events, the bulk of reads is `N + M`. Documented restore flow (`lib/app/restore/device_restore_service.dart:169`) calls `pullOnLaunch` then issues an additional `fetchAll(curriculum_tracks)` to compute active curricula (`device_restore_service.dart:186`) — duplicates a read that already happened in the pull pipeline.
- **Listener cost (idle user with 5000 completions, app foreground):** every Firestore snapshot pushes the full 5000-doc set into Dart (no listener limit). Even with no remote changes, foreground revalidations and any local write fires an echo snapshot. Real-time-listener reads are billed: a single change on the user's own device triggers a snapshot that reads N docs from cache, but server-side reads are bounded — still, **session-long listeners on six unbounded collections** keep a heavy gRPC stream open while backgrounded.
- **Restore (cold install with existing cloud data):** pull-on-launch with all 14 entity kinds, plus a duplicate `fetchAll('curriculum_tracks')`, plus content imports.

## 6. Scheduled / periodic work in production

- `grep -rn "Timer\.periodic" lib/` — zero matches.
- `grep -rn "Workmanager\|workmanager\|BackgroundFetch\|background_service"` — zero matches.
- The only `Timer` is `_connectivityResetDebounce` in `SyncOrchestratorImpl` (`sync_orchestrator.dart:368`) — a single-shot 1.5 s debounce on network-reset, not periodic.
- No FCM-driven wake events; no push notifications carry data payloads.

There is **no scheduled outbox drain, no scheduled goal-progress recompute, no scheduled cleanup**. The only sync triggers are: app launch (`pullOnLaunch`), lifecycle resume (resume-throttled), profile switch (`restartListeners`), explicit "tap to retry" (`retryPull` from `backup_sync_section.dart`), and connectivity transitions (network reset only, no drain).

## 7. Sync-skip / local-only paths

Explicit local-only:
- `TransliterationVariantPreference.write` — `preference_providers.dart:188` comment says "Transliteration variant is local-only — no Firestore push." Deliberate.
- `prior_completion_imports` table — provenance only.
- `pace_reset_date`, daily plans, curriculum scope — local schedule artefacts, recomputed.

Silent (no comment, no design intent):
- **Streak events on completion** (`completion_repository_impl.dart:698`) — written to Drift `streak_events`, no outbox.
- **Study-day configs** (`track_creation_service.dart:350`) — write to `study_day_configs`, no outbox, no merger.
- **Learning ledger** writes through `_firestoreGateway?.pushLedgerEntry` directly (`learning_ledger_repository_impl.dart:58`) instead of the outbox — fails silently when offline.
- **Notification settings** push directly (`notification_providers.dart:230`) — bypasses outbox.
- **Profile program assignment** writes directly through gateway (`track_creation_service.dart:327`, `edit_track_screen.dart:326`) — bypasses outbox.
- **Bookmark write during track creation** (`track_creation_service.dart:317`) — direct gateway, bypasses outbox.
- **Sacred-time prefs** only sync for `profileId == 0` (`outbox_sync_write_facade.dart:217`).
- **Reward-settings merge** is wired with `onRewardSettings: null` (`merge_router_provider.dart:67`) — comment promises this is "moved to features/sync in W2.31" but the override never landed; reward-milestone deltas pulled from the cloud are silently dropped.

## 8. Initial-sync / restore flow

`SyncOrchestratorImpl.pullOnLaunch` (`sync_orchestrator.dart:429`) is the single entry point. Production callers (all `ref.read`):
- `sign_in_controller.dart:376, 425, 492` — sign-in / select profile.
- `device_restore_service.dart:169` — restore flow.
- `upgrade_to_cloud_screen.dart:109` — upgrade.
- `backup_sync_section.dart:60` — `retryPull`.

The `_pullGuard` state machine prevents duplicate pulls; `_PullCompleted` skips further launches except via `retryPull()` which resets it.

`DeviceRestoreService.restore` (`lib/app/restore/device_restore_service.dart:136`): three steps — (1) `pullOnLaunch`, (2) `fetchAll('curriculum_tracks')` (already pulled in step 1 — duplicate cost), (3) re-import bundled content for active curricula. `isNewDevice` check examines `restore_state` SharedPref + checks if any local completions exist; can be bypassed by `retry()`.

`initialSyncCompleteProvider` (`lib/core/sync/initial_sync_state.dart`) — written exactly once on first successful pull; dashboard gates count-tile readiness on this flag.

Upgrade-to-cloud: `LocalDataUploadService.pushAllLocalData` (`lib/features/sync/data/local_data_upload_service.dart:59`) iterates every entity kind and queues outbox rows. Order: completions → bookmarks → goals → profile_programs → streak events → ledger entries → curriculum tracks → notification settings → gamification snapshot → UI prefs snapshot. **Outbox-queued but never drained** in production (same drain gap).

## 9. Observability

Structured logs (via `AppLogger`, `lib/core/logging/log_events.dart:33-65`): pull lifecycle (`pull_on_launch_started/completed/failed`), listener (`listener_attached/detached/error`), push (`push_started/completed/failed`), outbox (`outbox_item_enqueued`, `outbox_dead_lettered`), merge (`merge_row_skipped`, `merge_router_halt`, `merge_failed`), conflict (`permission_denied`, `conflict_resolved`).

Analytics events fired: `pull_started/completed/failed` (sync_orchestrator), `permission_denied`, `listener_error`, `outbox_dead_lettered`, `merge_router_halt`, `merge_row_skipped`, `completion_recorded` (`CompletionWriter`).

Crashlytics: `_onListenerError` forwards as non-fatal (`sync_orchestrator.dart:776`).

`SyncStatus` UI states (`features/sync/domain/models/sync_status.dart`): `localOnly`, `synced`, `syncing`, `pending`, `offline`, `error`, `degraded`. Emitted from `SyncOrchestratorImpl._safeEmitStatus` on pull start/success/error. **`pending` and `offline` states with pending-changes count are exposed by the indicator (`sync_status_indicator.dart:38-49`) but no production code ever emits those states from the orchestrator** — pending count is wired through but never populated. The status UI shows only the pull dimension; outbox backlog is invisible.

Missing observability:
- No metric for outbox depth (rows pending, attempts, oldest age).
- No metric for listener snapshot size or read-per-hour.
- No "drain attempted" event — drain doesn't run, so there is nothing to log.

## 10. Test coverage

Integration:
- `test/sync/sync_orchestrator_connectivity_test.dart` — connectivity-driven network reset.
- `test/sync/sync_rework_engine_test.dart`, `sync_rework_orchestrator_test.dart`, `sync_rework_push_test.dart`, `sync_rework_writepath_test.dart`, `sync_rework_curriculum_completion_doc_id_test.dart`, `sync_rework_profile_programs_pull_test.dart` — covers the W2 cutover paths and doc-id derivation.
- `test/sync/two_device_sync_test.dart`, `test/integration/two_device_sync_test.dart` — two-device merge scenarios.
- `test/integration/stage_sync_test.dart` — stage definitions.
- `test/core/sync/outbox/outbox_processor_test.dart` — extensive `drain()` tests (the only place `drain()` is exercised).
- `test/story_acceptance/epic_13_cloud_sync_test.dart`, `epic_25_story_12_sync_decomp_part1_test.dart`, `epic_27_story_27_8_rules_and_offline_flush_test.dart` — story-level coverage.

Gaps:
- **No test asserts that production code actually triggers `drain()`** — the bug would be caught by a test that does `repository.markComplete(...)` and then verifies the outbox row is gone or that `pushCompletionsBatch` was called (without the test invoking `drain()` directly).
- No test for the streak-event tee never enqueuing outbox.
- No test for study-day configs not syncing.
- No test for the learning-ledger / notification / profile-program direct-gateway bypasses queueing into outbox.
- No multi-device test for `gamification_settings` reward-milestone merge (since the wiring is `null`).
- No load test for listener snapshot size on a heavy account.

---

## Findings — ranked

1. **Outbox never drains (CRITICAL, data-loss).** `OutboxProcessor.drain()` has zero production callers. Every entity ever queued via `CompletionWriter` / `OutboxSyncWriteFacade` / `BulkPriorCompletionService.expungePriorCompletions` since the W2.31/W2.32 cutover sits in the local `outbox` table forever. Upgrade-to-cloud's `LocalDataUploadService.pushAllLocalData` similarly enqueues then disappears. The only reason any cloud data reaches Firestore today is because of the direct-gateway bypass paths (item 2 below) — and those are partial and offline-fragile. A reinstall before a successful direct push = total data loss for that mutation. Required: a drain trigger (write-tee, periodic, lifecycle-hook, or connectivity-on-transition).

2. **Direct-gateway bypass paths skip outbox entirely (HIGH, data-loss when offline).** Five production write paths call `firestoreGateway.push*` without an outbox row: learning ledger (`learning_ledger_repository_impl.dart:58, 169`), notification settings (`notification_providers.dart:230`), profile program (`track_creation_service.dart:327`, `edit_track_screen.dart:326`), bookmark during track creation (`track_creation_service.dart:317`). Offline failures throw and are caught with a warning at best, more often silently. Required: route everything through the outbox uniformly.

3. **Streak events written on completion never reach the cloud (HIGH).** `CompletionRepositoryImpl._appendStreakEvent` (`completion_repository_impl.dart:698`) inserts directly into Drift `streak_events`, no outbox row. The orchestrator pulls `streak_events` and there is a per-event Firestore collection, but the only writer is `LocalDataUploadService.enqueueStreakPayload` in the once-per-upgrade `pushAllLocalData`. Day-to-day streaks never replicate; second device sees a frozen streak. Required: add a streak outbox enqueue in the tee path (or fold streak into `CompletionWriter`'s transaction).

4. **Study-day configs have no sync path at all (MEDIUM).** Locally written by `TrackCreationService._saveStudyDays`; no outbox, no merger, no listener. A user editing study days then reinstalling loses them. Required: enrol in the sync pipeline (push + pull + merger).

5. **LWW client timestamps + `currentUpdatedAt` returning null = "remote always wins" for several kinds (MEDIUM, correctness).** `DriftMergeStore.currentUpdatedAt` returns null for `bookmark`, `settings`, `stageDefinition`, `learningOrder` (`drift_merge_store.dart:80-117`). `remoteIsNewer(localUpdatedAt: null, remoteUpdatedAt: …)` is unconditionally true — local edits made between two pulls are silently overwritten on the next pull. `synced_at: FieldValue.serverTimestamp()` is added on every push but never read by mergers. Required: persist remote `updated_at` per entity or switch to server-timestamp + monotonic-clock arbitration.

6. **Reward-milestone merge is a no-op (MEDIUM).** `GamificationSettingsMerger(... onRewardSettings: null)` (`merge_router_provider.dart:67`) — wiring comment says "supplied by an override in features/sync once W2.31 moves this wiring" but the override never landed. Reward-milestone changes on device A do not propagate to device B. Required: wire `RewardMilestoneService.applyCloudPayload` from `features/sync/`.

7. **Unbounded real-time listener snapshot size (MEDIUM, cost/battery).** `listenToCollection` issues `ref.snapshots()` with no `.limit()`. A user with 10k completions receives a 10k-doc snapshot for every change. Listeners run for the entire session including backgrounded. Required: add `.limit()` + `.orderBy(updated_at desc)`, or convert hot collections to "deltas only" via a server-timestamp watermark.

8. **No outbox dedup on snapshot kinds (LOW-MEDIUM, cost).** Every UI preference toggle calls `_writeAndPushSnapshot` (`preference_providers.dart:82`) which enqueues a full `ui_preferences` snapshot. Same for `gamification_settings`. The outbox has no UNIQUE on `entityKey`, so rapid toggles pile up rows; if drain ever runs, every snapshot copy is pushed. Required: coalesce by `entityKey` at enqueue time (delete-prior-of-same-key) or at drain time (keep latest only).

9. **Listener gap on collections without real-time channels (MEDIUM, UX).** `goals`, `learning_ledger`, `learning_order`, `profile_programs`, `learner_profiles`, all `preferences/*` are pull-only. Second-device changes are invisible until the resume-throttled pull (5 min minimum interval). Required: add listeners for `goals` and `preferences/*` at minimum, accept the cost.

10. **Restore flow has a duplicate read (LOW, cost).** `DeviceRestoreService.restore` calls `pullOnLaunch` (which pulls `curriculum_tracks`) then immediately `fetchAll('curriculum_tracks')` to compute active curricula (`device_restore_service.dart:186`). Required: derive active curricula from the just-merged local DB instead.

11. **No backpressure or scheduling on outbox snapshot pushes (LOW).** When drain is wired, `pushGamificationSettingsSnapshot` rebuilds the full snapshot on every call (queries point configs, total points, reward service). On a hot path (every points-earning completion) this is N+1 queries before enqueue. Required: debounce-then-snapshot at the facade boundary.

12. **`SyncStatus.pending`/`offline` states wired in UI but never emitted (LOW, observability).** Indicator shows pending-changes count and offline state with queued count (`sync_status_indicator.dart:38-49`), but no orchestrator code emits these — they are only used by tests / dead status writers. Required: derive pending-count from outbox depth and emit `degraded`/`offline` when applicable.

13. **`outbox_dao.markAttempted` is read-modify-write outside a transaction (LOW, race).** `outbox_dao.dart:46` reads the row, increments `attempts`, writes. A future concurrent drain could lose increments. Required: use a single SQL `UPDATE ... SET attempts = attempts + 1` or transaction.

14. **Stage-definition push has dual paths (LOW, dead code).** Outbox kind `stage_definition` and gateway `pushStageDefinition` exist (`outbox_processor.dart:25,280`, `firestore_gateway_impl.dart:746`), but the repository writes through `pushSettings` (`stage_definition_repository_impl.dart:379`). Either the dedicated path is dead code or the repository is misrouted. Required: pick one.

15. **Sacred-time prefs only sync for `profileId == 0` (LOW, multi-profile).** `outbox_sync_write_facade.dart:217-233` gates sacred-time block by `_profileId == 0`. Documented memories say child profiles have no adult sacred-time, but adult-secondary profiles also fall through. Required: confirm intent or always include.

---

# Part B — NFR targets (quantified)

Every architectural decision below traces back to one of these targets. Numbers picked for a typical mobile session and a "heavy" account = 5,000 completions + 500 streak events + multi-curriculum.

## B.1 Reliability — no data loss

| Metric | Target |
|---|---|
| Pending-row count after ≥ 30 s of healthy network | **0** |
| p99 push latency, local commit → Firestore `synced_at` | **≤ 30 s** while online |
| Data preserved across uninstall, given ≥ 1 prior online session ≥ 30 s | **100%** |
| Outbox row max age before delivery OR dead-letter | **7 days** (matches `diagnostic_logs` TTL) |
| Drain attempts per row before dead-letter | **10** (existing) |
| Two-device convergence after both come online | **≤ 60 s** for the slower device to observe the other's writes |

## B.2 Quick — perceived latency

| Metric | Target |
|---|---|
| Local write → UI reflection | **≤ 16 ms** (one frame). Already met by Drift-first. |
| Pull-on-launch → dashboard ready | **≤ 3 s** warm cache, **≤ 8 s** cold pull (typical account) |
| Push to Firestore on healthy network | **≤ 5 s** from local commit |
| Listener echo back to UI | **≤ 200 ms** (Firestore latency floor) |
| Sign-in → "Syncing…" disappears | **≤ 10 s** for a typical account |

## B.3 Efficient — low CPU / memory

| Metric | Target |
|---|---|
| Drain when outbox is empty | **O(1)** — a single SELECT COUNT, then return |
| Drain batch size (non-completion) | **≤ 50 rows per call** (existing) |
| Mergers | Streaming per-row apply (no full-collection materialisation) |
| Periodic timer while backgrounded | **None** — observe Doze |
| RAM held by listener snapshots | **≤ 2 MB** per listener (forced by `.limit()`) |

## B.4 Low bandwidth

| Metric | Target |
|---|---|
| p95 outbound bytes per active session (foreground use) | **≤ 50 KB** |
| Outbound bytes per completion mark | **≤ 1 KB** (one batched WriteBatch op) |
| Listener delta size | Delta-only, not full collection. Snapshot must use `.limit()` + `orderBy(updated_at desc)`. |
| Snapshot-kind dedup | 10 rapid UI-prefs toggles → **1** push, not 10. |
| Initial-sync read volume (heavy account) | **≤ 200 KB** download |

## B.5 Low battery

| Metric | Target |
|---|---|
| Wake-locks | **None** |
| Foreground-only listeners | Detach when `AppLifecycleState.paused` ≥ 60 s; reattach on resume + pull-delta. |
| Periodic work cadence (foreground) | Drain timer every 60 s **only while orchestrator started AND online** |
| Connectivity debounce | 1.5 s (existing) |

## B.6 Minimum Firestore cost

Pricing reference (Firestore native): writes ≈ $0.18/100k, reads ≈ $0.06/100k.

| Op class | Target per typical user/month | Notes |
|---|---|---|
| Writes | **≤ 200** | 5 completions × 30 days + settings/streak snapshots, deduped |
| Document reads (initial sync + listeners) | **≤ 1,500** | Listeners with `.limit(500)` + delta-only |
| Total cost per active user/month | **≤ $0.01** | 100k users ≈ $1k/month — sustainable runway |
| Storage | **≤ 1 MB / user** | Completions dominate; everything else negligible |
| Cloud Functions invocations | **≤ 10 / user / month** | Tutor invite + account-delete cascade only |

---

# Part C — Target architecture

The current design is fundamentally sound: outbox-as-WAL, deterministic doc IDs, real-time listeners. The fixes are wiring + scope, not redesign. Boring tech wins.

## C.1 Core invariants (already exist — preserve)

1. **Drift-first.** Every user-visible mutation commits to Drift in a transaction. UI re-renders from Drift. Network is informational.
2. **Outbox is the WAL.** Every write that should reach the cloud lands in a `outbox` row in the same Drift transaction as the data write. Atomic with the local mutation.
3. **Idempotent push.** Deterministic doc IDs from natural keys (`(profileId, sefariaRef, stageId, …)`), so retry never duplicates.
4. **Single source of truth per session.** `SyncOrchestrator` is a `keepAlive` Riverpod singleton. One observer, one listener set per profile.

## C.2 New invariants

5. **No bypass paths.** Every cloud-relevant write goes through `OutboxSyncWriteFacade`. The `FirestoreGateway` is accessed only by the `OutboxProcessor` / `PushPipeline`. Verified by a lint rule (a `no-direct-gateway-push` grep in `make audit`).
6. **Drain runs.** `OutboxProcessor.drain()` fires on five triggers (Part D). A single-flight guard prevents stampede.
7. **Listeners are bounded.** Every `listenToCollection` includes `.orderBy('updated_at', descending: true).limit(N)`. Reads grow O(updates), not O(history).
8. **Snapshot kinds dedup at enqueue.** `OutboxSyncWriteFacade._enqueue` for `ui_preferences` / `gamification_settings` / `notification_settings` deletes any prior pending row with the same `entityKey` before insert. Outbox depth is O(distinct entities), not O(toggle count).
9. **Mergers persist `updated_at`.** `DriftMergeStore.currentUpdatedAt` returns a real value for every kind, so LWW is symmetric. Local edits between pulls are NOT overwritten when local is newer.
10. **Lifecycle parks listeners.** After 60 s in `paused`/`hidden`/`detached`, listeners detach. Reopen on `resumed` is paired with a pull-delta so the local DB catches up before listeners stream.

## C.3 Component diagram (post-fix)

```
                ┌──────────────────────────────────────────────────┐
                │           UI / Use-case / Repository             │
                └────────────────────────┬─────────────────────────┘
                                         ▼
                ┌──────────────────────────────────────────────────┐
                │  Drift transaction (atomic):                     │
                │   • local table write                            │
                │   • outbox row insert (snapshot kinds: dedup)    │
                └────────────────────────┬─────────────────────────┘
                                         ▼
                ┌──────────────────────────────────────────────────┐
                │  Best-effort kick: outboxProcessor.drain(pid)    │
                │  (fire-and-forget; single-flight inside drain)   │
                └────────────────────────┬─────────────────────────┘
                                         ▼
                ┌──────────────────────────────────────────────────┐
                │  PushPipeline → FirestoreGateway → Firestore     │
                │  • completions: batched WriteBatch (≤500 ops)    │
                │  • everything else: ≤50 rows / drain             │
                │  • deterministic doc IDs                         │
                └──────────────────────────────────────────────────┘

  Pull / listener path (unchanged shape, scoped):

                ┌──────────────────────────────────────────────────┐
                │  FirestoreGateway.listenToCollection(            │
                │     collection,                                  │
                │     limit: 500,                                  │
                │     orderBy: updated_at desc)                    │
                └────────────────────────┬─────────────────────────┘
                                         ▼
                ┌──────────────────────────────────────────────────┐
                │  ListenerSupervisor (per-collection routing)     │
                └────────────────────────┬─────────────────────────┘
                                         ▼
                ┌──────────────────────────────────────────────────┐
                │  MergeRouter → per-kind Merger (LWW + dedup)     │
                │  + DriftMergeStore.persistUpdatedAt(kind, ts)    │
                └────────────────────────┬─────────────────────────┘
                                         ▼
                                  Drift (local DB)
```

## C.4 Entity coverage matrix (post-fix)

Every entity gets the same treatment: outbox enqueue + listener (where multi-device matters) + persisted `updated_at` for LWW arbitration.

| Entity | Outbox kind | Listener | Merger persists updated_at |
|---|---|---|---|
| completion | `completion` | yes (limit 500) | n/a (append-only) |
| bookmark | `bookmark` | yes | **yes (new)** |
| settings | `settings` | yes | **yes (new)** |
| curriculum_track | `track` | yes | yes |
| stage_definition | `stage_definition` (single path — kill `pushSettings` dual) | yes | **yes (new)** |
| streak_event | **`streak` (new — tee into outbox on every `_appendStreakEvent`)** | yes | n/a |
| goal / goal_delete | `goal` / `goal_delete` | **add listener** | yes |
| learning_ledger | **route through outbox (was direct gateway)** | **add listener** | n/a |
| notification_settings | **route through outbox** | **add listener** | yes |
| gamification_settings | `gamification_settings` (dedup) | **add listener** | yes + wire `onRewardSettings` |
| ui_preferences | `ui_preferences` (dedup) | **add listener** | yes |
| learner_profile / delete | `learner_profile` / delete | yes | yes |
| learning_order | `learning_order` (**batched** — current is row-per-item) | optional | yes |
| profile_program | **route through outbox** | optional | yes |
| study_day_config | **`study_day_config` (new)** | **add listener** | yes |
| tutor_grant | n/a (lives in Firestore, server-driven) | **add listener** for client-visible state changes | n/a |

---

# Part D — Trigger graph + cost model

## D.1 Drain triggers (the headline fix)

`OutboxProcessor.drain(profileId)` runs on five triggers, in order of typical responsiveness:

1. **Write-tee** — `OutboxSyncWriteFacade._enqueue` schedules `unawaited(drain())` at the end (after the Drift transaction commits). Best-case 1-RTT: write → drain → Firestore in seconds.
2. **Pull-complete** — at the tail of `pullOnLaunch` success: pull pulls down, then drain pushes up. Same TCP/HTTP2 channel — efficient.
3. **Connectivity online transition** — already wired for network reset (Bug 6 fix). Append a drain call after the reset settles. Catches anything queued while offline.
4. **Lifecycle resume** — `LifecycleObserver.triggerPull` already runs pull on resume; append drain immediately after.
5. **Periodic safety net** — `Timer.periodic(60 s)` inside `SyncOrchestratorImpl`, scheduled only while `_started == true` AND last-known-connectivity is online. Cancelled in `dispose`. Catches anything missed by the other four (e.g. write-tee dropped during a process suspension).

### Single-flight guard

Inside `OutboxProcessor`:

```dart
bool _draining = false;
Future<int> drain(int profileId) async {
  if (_draining) return 0;  // skip if another drain is already running
  _draining = true;
  try {
    return await _doDrain(profileId);
  } finally {
    _draining = false;
  }
}
```

Prevents the thundering-herd risk when multiple triggers fire in quick succession (write-tee + connectivity + lifecycle resume can all coincide). The guard is per-process, fine for a single-Isolate Flutter app.

## D.2 Cost-per-action (post-fix)

Numbers below assume the proposed coalescing + listener-limit changes are in place.

| Action | Outbox rows | Firestore writes | Firestore reads | Bytes |
|---|---|---|---|---|
| Mark one completion (1 stage, child mode, points awarded) | 1 (completion) + 1 (gamification, coalesced) | 2 (1 completion + 1 gamification snapshot) | 0 (idempotent set) | ~1 KB out |
| Mark one completion (3 stages auto, adult) | 3 (completions) | 1 batched WriteBatch (3 ops) | 0 | ~2 KB out |
| Bulk-mark 100 items × 3 stages | 300 → 1 WriteBatch chunk | 1 batched (300 ops) | 0 | ~50 KB out |
| Toggle UI pref 10 times in 10 s | 1 (dedup) | 1 | 0 | ~1 KB out |
| Pull-on-launch, typical | 0 | 0 | ~50 (limit 500/collection, delta only) | ~30 KB in |
| Listener idle while foreground 1 h | 0 | 0 | ~5–10 (heartbeat + own echoes) | < 5 KB in |
| Backgrounded, listeners detached | 0 | 0 | 0 | 0 |

Per-user-month at typical use: **~150 writes + ~1,200 reads = $0.0024 + $0.0007 ≈ $0.003/user/month.** Hits the $0.01 target with a 3× safety factor.

## D.3 What we do NOT change

- The pull-pipeline ordering and pagination — already correct.
- The deterministic doc ID derivation — correct.
- Drift schema — no migrations needed beyond the new `study_day_config` outbox kind (no table changes, just enrolment).
- Firebase SDK version — current is fine.

---

# Part E — Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Drain stampede on app start (5 triggers fire near-simultaneously) | MED | LOW | Single-flight guard inside `OutboxProcessor`. Tested by a "fire 5 drains in 10 ms" unit test. |
| R2 | Periodic timer keeps Doze from kicking in (battery) | LOW | MED | Cancel timer on `paused`; only start on `resumed` + online. |
| R3 | Snapshot-kind dedup loses an earlier snapshot that contained needed delta | LOW | MED | Snapshot kinds carry full state (not delta), so the latest snapshot supersedes older — safe by construction. Verified by a test: "enqueue v1, enqueue v2, drain → v2 lands, v1 deleted." |
| R4 | Listener `.limit(500)` truncates a user with > 500 changes between pulls | LOW | MED | Pair listener with a recovery pull when the snapshot returns 500 docs (signal that there may be more). |
| R5 | `updated_at` clock-skew between two devices causes mis-merging | MED | LOW | Use Firestore `synced_at` server-timestamp as tie-breaker when client `updated_at` is within ±5 s. |
| R6 | Drain triggered before auth ready (sign-in race) | MED | LOW | `OutboxProcessor` provider already null-guards on `isCloudBorn`. Drain returns 0 immediately if gateway is null. |
| R7 | Drain-after-write tee fires synchronously on the UI thread | LOW | LOW | `unawaited(drain())` — fire-and-forget. The local commit already returned. |
| R8 | Removed direct-gateway paths break offline behaviour during the rollout window | LOW | HIGH | Phase 1 is enumerated; each conversion ships with a "queues offline, drains on reconnect" integration test. Pre-launch buffer means there's no live user impact even if a regression slips. |
| R9 | Listener detach on background leaves stale UI on resume | MED | LOW | Already covered by `_PullCompleted` re-pull on resume; listener re-attach is idempotent. |
| R10 | `studyDayConfig` enrolment adds a new Firestore collection — security rule gap | LOW | MED | Update `firestore.rules` in the same PR; review tested by `epic_27_story_27_8_rules_and_offline_flush_test`. |
| R11 | Pre-launch refactor breaks an undocumented assumption in `LocalDataUploadService` | LOW | LOW | Pre-launch — `feedback_no_feature_branches` says we go straight on dev; `make ci` + manual smoke before push. |

---

# Part F — Rollout plan

Six phases. Each is independently shippable, independently verifiable, independently revertible. Order matters because earlier phases unblock later ones.

## Phase 0 — Stop the bleeding (target: this week)

**Estimate:** 4–8 hours of focused work.
**Outcome:** Outbox drains in production. Data written from this point forward reaches Firestore.

Deliverables:
1. `OutboxProcessor.drain()` exposed via `outboxProcessorProvider` is invoked from `SyncOrchestratorImpl` on all five triggers (D.1).
2. Single-flight guard inside the processor.
3. Periodic timer (60 s) with foreground+online guard.
4. Write-tee added in `OutboxSyncWriteFacade._enqueue` and `CompletionWriter.commit/commitBatch`.
5. Drain attempt + result events logged (`AppLogger event=outbox_drain_started/completed/failed`).
6. Tests:
   - 5 trigger tests (each fires drain).
   - Single-flight unit test.
   - "Mark complete → outbox row disappears within 5 s" integration test (mock Firestore).

Acceptance: `git pull origin dev`, mark a completion, watch `outbox` table go to 0 rows within seconds.

## Phase 1 — Bypass cleanup (target: next week)

**Estimate:** 8–12 hours.
**Outcome:** Every cloud-relevant write is in the outbox. No path bypasses.

Deliverables:
1. Route through outbox (and remove direct-gateway calls):
   - `LearningLedgerRepositoryImpl` — add `OutboxEntityKind.learningLedgerEntry` enqueue.
   - `notification_providers.dart` — route via `OutboxSyncWriteFacade.enqueueNotificationSettings`.
   - `TrackCreationService._gateway.pushProfileProgram` + `edit_track_screen.dart` → outbox.
   - `TrackCreationService._gateway.pushBookmark` → outbox.
2. **Streak-event tee**: `CompletionRepositoryImpl._appendStreakEvent` enqueues a `streak` outbox row in the same transaction.
3. **Study-day config** enrolment: add to outbox, write merger, register listener.
4. Lint rule (`make audit` grep): no `_firestoreGateway.push*` outside `core/sync/`.
5. Tests: offline integration test per converted path — go offline, write, come online, verify Firestore got it.

## Phase 2 — Cost / efficiency (target: week 3)

**Estimate:** 8–12 hours.
**Outcome:** Listener cost is bounded. Snapshot kinds don't pile up.

Deliverables:
1. `FirestoreGatewayImpl.listenToCollection` adds `.orderBy('updated_at', descending: true).limit(500)`. Listener recovery pull when snapshot size == limit.
2. Listener parking: `ListenerSupervisor.detach()` on paused ≥ 60 s; `restart()` on resumed.
3. Snapshot-kind dedup at enqueue (`ui_preferences`, `gamification_settings`, `notification_settings`).
4. Debounced gamification snapshot rebuild (1 s debounce) at the facade boundary.
5. Listener-snapshot-size telemetry: log `listener_snapshot_size` per collection per snapshot for the first 10 sessions, then disable.
6. Tests: 10-rapid-toggle test → 1 outbox row + 1 push.

## Phase 3 — Conflict-resolution correctness (target: week 4)

**Estimate:** 4–8 hours.
**Outcome:** Multi-device works correctly; reward settings actually merge.

Deliverables:
1. Each merger calls `DriftMergeStore.persistUpdatedAt(kind, entityKey, remoteTs)` after successful apply.
2. `currentUpdatedAt` reads persisted values instead of returning null.
3. `onRewardSettings` wired into `GamificationSettingsMerger` from `features/sync/` via the merge router provider.
4. Server-timestamp tie-breaker for ±5 s clock skew.
5. Tests: existing `two_device_sync_test.dart` extended for gamification reward merge; new "local newer than remote" cases per merger.

## Phase 4 — Restore + observability (target: week 5)

**Estimate:** 4–6 hours.
**Outcome:** User sees backlog and offline state. Restore doesn't double-read. First sign-in on a fresh device with existing cloud profiles bypasses the onboarding wizard.

Deliverables:
1. Drop duplicate `fetchAll('curriculum_tracks')` in `DeviceRestoreService.restore`; derive active curricula from Drift after the merge.
2. Emit `SyncStatus.pending` / `offline` / `degraded` from the orchestrator based on outbox depth + connectivity.
3. `SyncStatusIndicator` shows backlog (already wired in UI — just emit).
4. Outbox-depth gauge + oldest-row-age gauge logged every 60 s on drain.
5. **Restore-then-skip-onboarding.** First sign-in on a clean install must await `DeviceRestoreService` and inspect post-restore Drift state: if ≥ 1 `learner_profile` exists locally after restore, route to `ProfilePickerRoute` (multi-profile) or `AppShellRoute` (single profile), **never** to the onboarding wizard. The current `_tryResumeFromSavedState` in `OnboardingScreen` only checks a saved snapshot — it does not observe a freshly-restored DB. Either gate the onboarding entry point on `profileRepository.countProfilesForAccount > 0` before pushing `OnboardingRoute`, or insert a "restore complete → reroute" handler in the sign-in controller's post-pull step.

## Phase 5 — Cleanup + minor (target: week 6)

**Estimate:** 2–4 hours.
**Outcome:** Codebase hygiene.

Deliverables:
1. Pick one of `stage_definition` vs `settings` push paths; delete the other. Update `StageDefinitionRepositoryImpl`.
2. Multi-profile sacred-time prefs — confirm intent with PM, then include or formally local-only-document.
3. Add a `no-direct-gateway-push` grep to `make audit`.
4. Delete `LocalDataUploadService.backfillGoalsForCloudCutover` if telemetry confirms it has fired zero times since the cutover.

---

## Confirmed decisions (locked 2026-05-21)

1. **Listener parking on paused** — **Detach after 60 s in `paused`/`hidden`/`detached` state.** Reattach on `resumed`, paired with a pull-delta so the local DB catches up before the listener stream resumes. Trade-off accepted: ≤ 200 ms of staleness on resume in exchange for zero gRPC stream + zero Firestore reads while backgrounded.

2. **LWW arbitration** — **Local wins when `localUpdatedAt > remoteUpdatedAt`.** Symmetric LWW. Mergers persist remote `updated_at` per entity via `DriftMergeStore.persistUpdatedAt(kind, key, ts)` after every successful apply; `currentUpdatedAt` reads back that value. Server-timestamp (`synced_at`) is the tie-breaker when client clocks are within ±5 s.

3. **Listener page size** — **500 docs per snapshot, `orderBy(updated_at desc)`.** When a snapshot returns exactly 500 docs (the "may be more" signal), the supervisor triggers a recovery pull for that collection so older changes are still consumed.

4. **Tutor grants listener** — **Add it.** Tutor invite-accept / revoke shows up live on the affected device. Cost is negligible (tutor relationships change rarely).

5. **Cloud Functions for fan-out** — **Out of scope for this plan.** Some snapshots (gamification, UI prefs) could be derived server-side from raw events instead of pushed as a snapshot. Filed as future cost optimisation; revisit when per-user write volume becomes a measurable cost line.
