# V2-R1 — Sync & Data Layer Adversarial Review

**Date:** 2026-05-20
**Reviewer:** V2-R1 (Sonnet 4.6, post-refactor adversarial pass)
**Branch:** dev
**Scope:** sync + data + Firestore rules + Cloud Functions + codecs

---

## CRITICAL findings (4)

### C1 — LearningLedgerMerger uses legacy camelCase field names; all ledger pull rows silently discarded

- **File:** `learning_tracker/lib/core/sync/merge/learning_ledger_merger.dart:41-44`
- **Issue:** `LearningLedgerMerger.merge()` reads camelCase fields (`curriculumId`, `unitIdentifier`, `trackType`, `completedAt`) from Firestore rows. After W3.37 / W3.18 the Firestore schema is snake_case. The field-not-found checks (`if (curriculumId == null || …) continue`) will silently skip every pulled row. The `LearningLedgerCodec` (W3.15) was written for snake_case (`curriculum_id`, `sefaria_ref`, etc.) but the merger was never updated to use it.
- **Evidence:** Merger source reads `row['curriculumId']`, `row['unitIdentifier']`, `row['trackType']`, `row['completedAt']`. The codec (learning_ledger_codec.dart:41-47) reads `raw['curriculum_id']`, `raw['sefaria_ref']`, `raw['entry_type']`, `raw['created_at']`. These are different field names.
- **Impact:** After a device restore or first install, `pullLearningLedger` runs but inserts zero rows — the learner's entire lifetime completion history (siyumim, reports) is lost on any new device. This is a data-loss regression introduced in W3.19+.
- **Recommended fix:** Wire `LearningLedgerCodec` into the merger (matching the pattern used in `CompletionEventMerger`, `ProfileProgramMerger`). Replace the inline field reads in `merge()` with `_codec.decode(row)` and use the typed `LearningLedgerRow` to populate `LearningLedgerCompanion`. The codec already has the correct snake_case decode path.

---

### C2 — StreakEventMerger reads old field names (`event_timestamp`, `event_type`) after W3.37 renamed them; all streak pull rows silently dropped

- **File:** `learning_tracker/lib/core/sync/merge/streak_event_merger.dart:40-41`
- **Issue:** `StreakEventMerger.merge()` reads `row['event_type']` and `row['event_timestamp']`. W3.37 changed the Firestore streak shape from a single snapshot document to `streak_events/{ulid}` collection with fields `study_date`, `created_at`, `event_type` (retained), and `profile_id`. The field `event_timestamp` no longer exists; the date is now `study_date`. The `StreakEventCodec` (W3.13) correctly reads `study_date` and `created_at`, but the merger was never updated to use the codec.
- **Evidence:** `streak_event_merger.dart:40` reads `row['event_type']`; `streak_event_merger.dart:41` reads `FirestoreCodec.parseDateTime(row['event_timestamp'])`. The `StreakEventCodec.decode()` reads `raw['study_date']`. Since `event_timestamp` is absent in the new schema, `ts` is always `null`, and the `if (eventType == null || ts == null) continue` guard skips every row.
- **Impact:** Streak data never arrives from pull. Any cross-device scenario (new install, device restore) starts with a blank streak. Severity is CRITICAL because streaks are a primary engagement metric.
- **Recommended fix:** Wire `StreakEventCodec` into the merger. Replace inline field reads with `_codec.decode(row)` → `StreakEventRow`. Append to `_log` using `StreakEvent(profileId: decoded.profileId, eventType: decoded.eventType, eventTimestamp: decoded.studyDate, …)`.

---

### C3 — FirestoreListenerSource still listens to the deleted `streak/data` document path after W3.37

- **File:** `learning_tracker/lib/core/sync/firestore_listener_source.dart:57-61`
- **Issue:** `openChannels()` opens a `listenToDocument(collection: 'streak', docId: 'data')` channel. W3.37 deleted the `streak/data` snapshot document and replaced it with `streak_events/{ulid}` collection. The old document no longer exists; the listener emits `null` on first subscribe and then never fires again. No real-time streak updates reach `_onListenerEvent`.
- **Evidence:** `firestore_listener_source.dart:57-61` opens `gateway.listenToDocument(profileId: profileId, collection: 'streak', docId: 'data')`. The S2 log confirms W3.37 changed Firestore to `streak_events/{ulid}`.
- **Impact:** Any real-time streak event synced from another device is never delivered to the local listener path. The pull-on-launch path (C2) is also broken. Combined, streak sync is entirely non-functional cross-device.
- **Recommended fix:** Replace the single-document listener with a collection listener: `'streak_events': gateway.listenToCollection(profileId: profileId, collection: 'streak_events')`. Add `'streak_events' => EntityKind.streak` to `_channelToKind`.

---

### C4 — `profile_programs` allow delete is `false` in Firestore rules but `removeProfileProgramAssignment` calls `.delete()` from client code; all program-unenrolment writes will be PERMISSION_DENIED

- **File:** `learning_tracker/firestore.rules:331-340` + `learning_tracker/lib/features/tracks/setup/domain/services/track_creation_service.dart:236`
- **Issue:** The rules block `allow delete: if false` for `profile_programs`. However, `TrackCreationService` calls `_gateway?.removeProfileProgramAssignment(...)`, which resolves to `FirestoreGatewayImpl.removeProfileProgramAssignment` → `collection.doc(key).delete()`. This is a client-initiated delete on a collection whose rules unconditionally deny delete. Every unenrolment or track-recreation workflow that calls this path will throw `FirestorePermissionDeniedException` when the user is online.
- **Evidence:** `firestore_gateway_impl.dart:457-463` calls `collection.doc(curriculumStorageKey).delete()`. `firestore.rules:339` says `allow delete: if false`.
- **Impact:** Track deletion / unenrolment silently fails (the local Drift row is removed but the Firestore document persists). On next sync the deleted program re-appears from Firestore. Data integrity bug — deleted programs resurrect.
- **Recommended fix:** Either change the rules to `allow delete: if isOwner(uid)` for `profile_programs`, or route the deletion through a callable Cloud Function. The rules comment says "unenrolment flows through a state field update" — if that is the intent, the gateway and service must be updated to perform an update (set a `status: 'unenrolled'` field) instead of a hard delete, and the pull side must filter accordingly.

---

## HIGH findings (7)

### H1 — `pushTrack` constructs Firestore doc ID using `track_type` which was removed by W3.22; all track pushes land at the wrong document path

- **File:** `learning_tracker/lib/core/sync/firestore_gateway_impl.dart:297-303`
- **Issue:** `pushTrack` builds `docId = '${curriculumId}_$trackType'` where `trackType = data['track_type']?.toString() ?? ''`. After W3.22 removed `trackType` from `curriculum_tracks`, all callers (`TrackRepositoryImpl`, `CurriculumActivationService`, `LocalDataUploadService`) no longer include `track_type` in the payload. `trackType` is therefore always `''` and every document lands at `"curriculumId_"`. If a learner has multiple curricula, each track overwrites the previous one at the same path.
- **Evidence:** `track_repository_impl.dart:46-54` builds the push payload with no `track_type` field. `firestore_gateway_impl.dart:297-299` reads `data['track_type']?.toString() ?? ''`.
- **Impact:** In a multi-curriculum account, only the last-pushed curriculum track survives at its correct Firestore path. Earlier curricula are overwritten. On pull, `_upsertTrack` uses `curriculumId` as the natural key so the DB gets the correct row, but the Firestore document is wrong. Bidirectional data corruption on multi-curriculum accounts.
- **Recommended fix:** Since W3.22 establishes one track per (profileId, curriculumId), use `curriculumId` alone as the document ID: `docId = curriculumId`. Update `deleteCurriculumTrack` Cloud Function (see H2) correspondingly.

---

### H2 — `deleteCurriculumTrack` Cloud Function builds doc ID using `trackType` which no longer exists in the client schema after W3.22

- **File:** `learning_tracker/functions/src/index.ts:141`
- **Issue:** `deleteCurriculumTrack` requires `trackType` as a request parameter and constructs `docId = ${curriculumId}_${trackType}`. W3.22 removed `trackType` from `curriculum_tracks`. The client no longer has a `trackType` to pass. If the client passes empty string or omits the field it receives `invalid-argument` (line 137-139), blocking the delete. If H1 is fixed (doc ID = curriculumId only), this function also needs updating.
- **Evidence:** `index.ts:130-141`. W3.22 confirmed by S2 log: "trackType column dropped from CurriculumTracks."
- **Impact:** The `deleteCurriculumTrack` callable is permanently broken. Learner-profile deletions that depend on track cleanup (`deleteLearnerProfile` handles this recursively so it still works) are unaffected, but any other callers of `deleteCurriculumTrack` will fail.
- **Recommended fix:** Remove the `trackType` parameter requirement and rebuild `docId = curriculumId` to match the fix in H1.

---

### H3 — `GoalMerger` reads `pace_unit` field but `GoalEntity.toFirestore()` writes `pacePeriod`; pace goals are silently stored with null pace period after sync

- **File:** `learning_tracker/lib/core/sync/merge/goal_merger.dart:49` + `learning_tracker/lib/features/scheduler/domain/models/goal_entity.dart:175`
- **Issue:** `GoalMerger.merge()` extracts `pacePeriod: row['pace_unit'] as String?`. The actual Firestore field written by `GoalEntity.toFirestore()` is `'pacePeriod'` (camelCase). The merge read always returns `null`. The `GoalCodec.encode()` writes `'pace_period'` (snake_case), a third inconsistency.
- **Evidence:** `goal_merger.dart:49` reads `row['pace_unit']`. `goal_entity.dart:175` writes `'pacePeriod': pacePeriod`. `goal_codec.dart:87` writes `'pace_period': model.pacePeriod`.
- **Impact:** After a sync or restore, goals with a pace period (items/week, items/day) lose their pace configuration. The goal survives but is silently demoted to a deadline-only goal with no pace. The learner's configured study pace is lost on any new device.
- **Recommended fix:** Change `GoalMerger` to read `row['pacePeriod'] as String? ?? row['pace_period'] as String? ?? row['pace_unit'] as String?` to cover all three naming variants. The correct long-term fix is to wire `GoalCodec` into `GoalMerger` and standardise on snake_case at the push boundary.

---

### H4 — B1 policy violation: `CompletionDetectionService.checkAndRecordCompletions` fires for `lifetimeOnly` source, incorrectly creating siyum ledger entries

- **File:** `learning_tracker/lib/features/learning/data/repositories/completion_repository_impl.dart:172-183`
- **Issue:** The `checkAndRecordCompletions` call at line 173 is not gated on `awardGamificationPoints`. Per the B1 three-tier policy, `lifetimeOnly` completions must NOT trigger achievement side-effects (siyum detection, study-report indexing). `completionDetectionService.checkAndRecordCompletions` creates a `learning_ledger` row (a siyum record) when it detects full unit completion. For `lifetimeOnly` historical imports, this means the learner gets siyumim credited for historical data, which is incorrect.
- **Evidence:** `completion_repository_impl.dart:172-183` calls `_completionDetectionService.checkAndRecordCompletions(...)` unconditionally for all `isNew` completions. The `CompletionSource.creditsAchievement` predicate (`completion_source.dart:59-60`) returns `false` for `lifetimeOnly` but is never consulted here.
- **Impact:** Historical imports (`lifetimeOnly` source) incorrectly generate siyumim and inflate reports. The B1 policy specified in `completion_source.dart` is documented correctly but not enforced in the repository.
- **Recommended fix:** Gate the `completionDetectionService` call on `awardGamificationPoints` (or better, pass the `CompletionSource` down to the repository and gate on `source.creditsAchievement`): `if (awardGamificationPoints && _completionDetectionService != null)`.

---

### H5 — `purgeExpiredAuditLogs` missing composite index on `tutor_grants(state, updated_at)`; function will fail or full-scan at scale

- **File:** `learning_tracker/functions/src/index.ts:225-228` + `learning_tracker/firestore.indexes.json`
- **Issue:** `purgeExpiredAuditLogs` runs: `.where("state", "==", state).where("updated_at", "<=", cutoffTs).limit(100)`. This compound query requires a composite index on `(state, updated_at)` for `tutor_grants`. The `firestore.indexes.json` contains three indexes for `tutor_grants` (on `tutor_uid+state`, `parent_uid+child_profile_id+state`, `tutor_email+state`) but no `(state, updated_at)` index.
- **Evidence:** `firestore.indexes.json` — no entry with `state` + `updated_at` fields on `tutor_grants`. Firestore will auto-create single-field indexes but NOT composite ones, so the query will fail with a "The query requires an index" error in production.
- **Impact:** The purge function fails on every daily run, meaning audit log entries are never cleaned up. The 12-month retention policy is silently not enforced, leading to unbounded Firestore storage growth for audit logs.
- **Recommended fix:** Add a composite index to `firestore.indexes.json`: `{ "collectionGroup": "tutor_grants", "fields": [{"fieldPath": "state", "order": "ASCENDING"}, {"fieldPath": "updated_at", "order": "ASCENDING"}] }`.

---

### H6 — `purgeExpiredAuditLogs` processes at most 100 grants per terminal state per run; grants beyond the first page are never purged

- **File:** `learning_tracker/functions/src/index.ts:220-250`
- **Issue:** The function queries `.limit(PURGE_BATCH_SIZE)` (100) per terminal state but never paginates. If more than 100 grants are in a given terminal state and past the retention cutoff, only the first 100 are processed per daily run. This is not catastrophic immediately but creates an unbounded accumulation for high-traffic deployments.
- **Evidence:** `index.ts:220-250` — the `for (const grantDoc of snapshot.docs)` loop runs once per state with a `limit(100)` query. No `startAfter()` pagination.
- **Impact:** Audit log cleanup is incomplete beyond 100 records per state per day. In a production deployment with many tutors the effective purge rate may fall far behind the accumulation rate.
- **Recommended fix:** Wrap each terminal state query in a pagination loop (do-while with `startAfter(snapshot.docs.last)`) until `snapshot.empty`. Increase `PURGE_BATCH_SIZE` to 200-500 if memory allows.

---

### H7 — `LocalDataUploadService.enqueueStreakPayload` pushes a snapshot payload (current_count, max_count) into the `streak_events` collection; the field shape is entirely wrong for the W3.37 per-event schema

- **File:** `learning_tracker/lib/features/sync/data/local_data_upload_service.dart:161-168`
- **Issue:** After W3.37, the Firestore `streak_events` collection expects per-event documents with fields `event_type`, `study_date`, `created_at`, `profile_id`. `LocalDataUploadService.enqueueStreakPayload` enqueues a single document with snapshot-style fields `current_count`, `max_count`, `last_completion_date`. This document will be written to `streak_events` (via `pushStreak`) and immediately become garbage — it carries none of the required event fields. Worse, on pull the `StreakEventMerger` will skip it (C2), so it does not cause corruption but it is permanently useless data in Firestore.
- **Evidence:** `local_data_upload_service.dart:161-168` builds `{'current_count': ..., 'max_count': ..., 'last_completion_date': ...}`. `firestore_gateway_impl.dart:257-274` calls `collection.doc(ulid).set(...)` — no `ulid` in the payload means `collection.doc()` (auto-ID). `streak_event_merger.dart:40-41` reads `event_type` / `event_timestamp` neither of which is present.
- **Impact:** The streak upload path in `pushAllLocalData` writes garbage to Firestore and does not actually migrate streak history. Cross-device streak restoration via this path fails completely.
- **Recommended fix:** Replace the snapshot enqueue with a per-event enqueue: iterate `StreakEventLog.getByProfile(profileId)` and enqueue one outbox row per event with the correct per-event fields (`event_type`, `study_date`, `created_at`, `profile_id`, `ulid`).

---

## MEDIUM findings (5)

### M1 — `GoalCodec` defined but never wired into `GoalMerger`; codec is dead code

- **File:** `learning_tracker/lib/core/sync/codec/goal_codec.dart` + `learning_tracker/lib/core/sync/merge/goal_merger.dart`
- **Issue:** `GoalCodec` was added in W3.16 with a full `decode()`/`encode()` cycle. `GoalMerger` reads fields directly from raw Firestore rows (inline field access, not via the codec). The codec provides no value in its current state.
- **Evidence:** No `import` of `goal_codec.dart` in `goal_merger.dart`. The codec's `decode()` requires `firestore_id` as a required field; the merger uses `track_id` as the natural key; the two are architecturally decoupled.
- **Impact:** Inconsistent codec usage across mergers (11 mergers use their codec; GoalMerger does not). Future maintainers will be confused about which is authoritative. No runtime impact beyond the H3 pace_unit issue.
- **Recommended fix:** Wire `GoalCodec` into `GoalMerger` as done for `CompletionEventMerger` and `ProfileProgramMerger`, or remove the codec if the merger's inline approach is preferred. The two must be reconciled.

---

### M2 — `isActiveTutorGrant` Firestore rules helper function is defined but never called; tutor subcollection read access is undocumented and silently missing

- **File:** `learning_tracker/firestore.rules:60-67`
- **Issue:** `isActiveTutorGrant(ownerUid, profileId, grantId)` is defined to enable tutor reads of a learner's profile subcollections. The comment on the `learner_profiles` rule (line 154-157) says "Subcollection reads for tutors require the grantId path — not yet wired at the subcollection level." The function exists but no rule body calls it, so there is currently NO tutor read path at the subcollection level.
- **Evidence:** `grep isActiveTutorGrant firestore.rules` returns only the function definition. The `learner_profiles` match block only has `allow read: if isOwner(uid)`.
- **Impact:** Tutors cannot read any subcollection documents (completions, streak_events, etc.) through Firestore rules. In V1 this is by design (reads go through Cloud Functions). The risk is that future code accidentally adds a direct-read path without wiring the helper, creating an implicit deny that looks like a bug.
- **Recommended fix:** Add a comment on the `isActiveTutorGrant` function body explicitly stating it is reserved for V2 tutor-direct-read wiring. Or add a `@Deprecated`-style comment if the function will be removed in favour of a different pattern.

---

### M3 — `DriftMergeStore._upsertSettings` and `_upsertStageDefinition` both replace stages for curriculum but neither increments a version counter; concurrent calls can race

- **File:** `learning_tracker/lib/core/sync/merge/drift_merge_store.dart:411-455`
- **Issue:** `_upsertSettings` calls `_db.stageDao.replaceStagesForCurriculum(curriculumId, companions)` which does a DELETE-then-INSERT. If two pull workers (unlikely but possible with listener + pull-on-launch firing simultaneously for the same profile) both call this, the second DELETE can delete rows just inserted by the first, leaving an empty stage set briefly. This is a TOCTOU gap.
- **Evidence:** `drift_merge_store.dart:454` calls `replaceStagesForCurriculum`. `sync_orchestrator.dart:355-444` creates a `PullPipeline` per pull but the listener path (`_onListenerEvent`) can also dispatch `settings` rows concurrently.
- **Impact:** Slim race window but if it fires the stage list briefly empties, potentially breaking the dashboard during a pull. For most users the window is sub-millisecond. Non-critical in practice but worth noting.
- **Recommended fix:** Wrap `replaceStagesForCurriculum` inside a Drift transaction that acquires a write lock, or use an optimistic LWW `updatedAt` guard to skip the replace if the incoming `updatedAt` is not newer than the stored one.

---

### M4 — `MergeRouter` switch case `EntityKind.learnerProfile` is present but `EntityKind.stageDefinition` routes to the same merger as `EntityKind.settings` via `DriftMergeStore.upsert`; dedicated `StageDefinitionMerger` is bypassed via listener path

- **File:** `learning_tracker/lib/core/sync/merge/merge_router.dart:29-57` + providers
- **Issue:** The `MergeRouter` switch lists `EntityKind.stageDefinition` as a valid case (line 36), but the actual merger in `_mergers[EntityKind.stageDefinition]` routes to `StageDefinitionMerger`. The listener path for `settings` collection also fires `EntityKind.settings` through `DriftMergeStore.upsert → _upsertSettings` which re-derives stage definitions from the settings document. These two paths can conflict: a settings listener update triggers `replaceStagesForCurriculum`, overwriting any `StageDefinitionMerger` changes from the pull path. This is a design inconsistency rather than a bug, but can cause surprising overwrites.
- **Evidence:** `drift_merge_store.dart:155-163` — `EntityKind.settings` case calls `_upsertSettings` which calls `replaceStagesForCurriculum`. `stage_definition_merger.dart` also writes to `stageDefinitions` table. Two paths write the same table.
- **Impact:** Pull via `pullStageDefinitions` (kind=stageDefinition) applies upserts. A subsequent settings listener event (kind=settings) calls `replaceStagesForCurriculum`, potentially deleting stage_definition rows that were upserted by the pull. Low probability but genuine inconsistency.
- **Recommended fix:** Consolidate: settings documents should not carry stage definitions if `stage_definitions` is a separate collection (W3.32). If settings docs no longer embed stages in production, remove the `stagesList` handling from `_upsertSettings`.

---

### M5 — `LearnerProfileMerger` insert path uses `insertOnConflictUpdate` but the FK guard block has a logic inversion: `if (existing == null) → insertOnConflictUpdate` is correct but redundant

- **File:** `learning_tracker/lib/core/sync/merge/drift_merge_store.dart:269-295`
- **Issue:** `_upsertLearnerProfile` calls `_db.into(_db.learnerProfiles).insertOnConflictUpdate(...)` only inside the `if (existing == null)` branch. The `else` branch performs a targeted UPDATE. Using `insertOnConflictUpdate` when the row is known not to exist is functionally correct (it inserts) but wastes an extra conflict-check cycle. More importantly, the account_id (FK to accounts) is only written on insert, never on update — if the `account_id` changes on the remote, the local row's FK stays stale.
- **Evidence:** `drift_merge_store.dart:272-282` — `insertOnConflictUpdate` runs only when `existing == null`. The update at line 285-293 does not write `accountId`.
- **Impact:** If a learner profile's `account_id` ever changes (e.g., account migration), the local FK is never updated. Low probability edge case, not data loss, but a latent integrity bug.
- **Recommended fix:** Use a single `insertOnConflictUpdate` call with all fields (including `accountId`), removing the `existing == null` branch. Or document the `accountId` immutability assumption explicitly.

---

## LOW findings (3)

### L1 — `isActiveTutorGrant` performs an extra Firestore document read on every tutor read check; if wired in the future it will count as a billed document read per request

- **File:** `learning_tracker/firestore.rules:61`
- **Issue:** The `get(...)` call inside `isActiveTutorGrant` will be billed as one document read per rules evaluation. If the function is wired to gate subcollection reads in a future V2, every tutor read of a learner's data will incur +1 Firestore read for the grant doc.
- **Evidence:** `firestore.rules:61` — `let grant = get(/databases/$(database)/documents/tutor_grants/$(grantId)).data`.
- **Impact:** Billing and latency concern only. No security or correctness issue.
- **Recommended fix:** Accept for V1 (function is not yet called). When wired in V2, document the read cost and consider caching the grant check in a session token claim via a custom token to avoid per-request reads.

---

### L2 — `LearningOrderCodec` `encode()` outputs `position` field but `DriftMergeStore._upsertLearningOrder` reads `user_sort_order`; push/pull field name inconsistency

- **File:** `learning_tracker/lib/core/sync/codec/learning_order_codec.dart` (encode) + `learning_tracker/lib/core/sync/merge/drift_merge_store.dart:596-624`
- **Issue:** `LearningOrderCodec.decode()` reads `raw['position']` into `LearningOrderRow.position`. However `DriftMergeStore._upsertLearningOrder` reads `fields['user_sort_order']`. The codec is not wired into the merger (same pattern as GoalCodec). Additionally `learning_order_codec.dart` encodes to `'position'` while the gateway's `pushLearningOrder` and the DB column both use `user_sort_order`.
- **Evidence:** `learning_order_codec.dart` (implied by S2 log: "LearningOrderCodec + LearningOrderRow — decodes curriculumId, sefariaRef, position, updatedAt"). `drift_merge_store.dart:602` reads `fields['user_sort_order']`.
- **Impact:** If the codec were wired into the merger, the field `position` would decode correctly but the DB write would fail to find the field. Currently the merger bypasses the codec so there is no active bug, but the codec is wrong.
- **Recommended fix:** Align the codec to decode `'user_sort_order'` instead of `'position'`, or rename the codec's field to match the actual Firestore field name.

---

### L3 — `deleteUserData` in `FirestoreGatewayImpl` enumerates legacy collection names that no longer exist and misses new ones added by the refactor

- **File:** `learning_tracker/lib/core/sync/firestore_gateway_impl.dart:595-613`
- **Issue:** `deleteUserData` (fallback manual-delete path) iterates a hardcoded list of subcollections including `'streaks'`, `'profiles'`, `'sync_queue'` (all deleted by refactor) and is missing `'streak_events'`, `'preferences'`, `'goals'`, `'import_metadata'`, `'stage_definitions'`, `'profile_programs'` (all added by refactor). This method is a best-effort safety net (the real delete is done via `deleteAccountData` Cloud Function which uses Admin SDK `recursiveDelete`), but the fallback path is now stale.
- **Evidence:** `firestore_gateway_impl.dart:595-613` lists `'streaks'`, `'profiles'`, `'sync_queue'` (removed) but not the new collections.
- **Impact:** The Admin SDK Cloud Function (`deleteAccountData`) correctly uses `recursiveDelete` and is the primary path. The manual fallback would leave orphaned data if ever used. Low impact given the Cloud Function is primary.
- **Recommended fix:** Update the hardcoded list to match the current v1 layout, or remove the fallback entirely since `deleteAccountData` provides the authoritative delete.

---

## Summary

- **CRITICAL:** 4
- **HIGH:** 7
- **MEDIUM:** 5
- **LOW:** 3
- **Total:** 19
- **Verdict:** BLOCK SHIP

### Critical path to ship

**C1 (LearningLedger pull drop)** and **C2 (Streak pull drop)** are pure data-loss regressions introduced by the W3.18/W3.37 codec migration that was never completed. Both will cause silent permanent data loss on any new-device or device-restore scenario. **C3 (Streak listener dead path)** compounds C2. **C4 (profile_programs delete denied)** means any track-removal workflow will fail silently in production.

All four CRITICAL findings and HIGH findings H1/H2 (track push schema) and H4 (B1 achievement gate) must be fixed before ship. H5 (missing index) will cause the daily purge to hard-fail on first execution post-deploy.
