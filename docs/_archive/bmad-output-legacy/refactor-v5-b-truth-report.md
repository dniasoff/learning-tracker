# V5-B Task Truth Report — W3 + W4

**Verifier:** V5-B  
**Scope:** W3.1–W3.47 (47 tasks) + W4.1–W4.35 (35 tasks) = 82 tasks  
**Date:** 2026-05-20  
**Branch:** dev  
**App root:** `learning_tracker/`

---

## Summary

| Verdict | Count |
|---------|-------|
| Verified (claim true) | 76 |
| Demoted (claim false / partial) | 4 |
| Skipped / unverifiable post-hoc | 2 |

**Demotions:** W3.18, W3.19, W3.44, W4.16

---

## Special Verifications (B1/B2/B3)

### B1 — Three-tier completion credit policy

- **File:** `learning_tracker/lib/features/learning/domain/entities/completion_source.dart:48–67`
- `CompletionSourceX.creditsEngagement` → `this == CompletionSource.live` (false for bulkInTrack + lifetimeOnly) ✓
- `CompletionDetectionService` only called when `awardGamificationPoints == true` (completion_repository_impl.dart:177) ✓
- `BulkMarkCompletionUseCase` has `CompletionSource source = CompletionSource.bulkInTrack` param ✓
- Tests: `mark_completion_use_case_b1_test.dart` + `batch_plan_test.dart` — **25/25 PASS**

### B2 — Program start window [today−30, today]

- **File:** `learning_tracker/lib/core/domain/value_objects/program_starting_position.dart:7`
- `kMaxLookBackDays = 30` ✓
- Factory `ProgramStartingPosition.create` throws `StartDateWindowException` on out-of-window ✓
- Test run: **20/20 PASS**

### B3 — Back-dated enrolment generates overdue catch-up tasks

- **File:** `learning_tracker/lib/features/tracks/setup/domain/use_cases/provision_track_use_case.dart:14–20`
- ProvisionTrackUseCase walks back-dated start via `toLegacyGrammar` → `createTrack` ✓
- Test run: **14/14 PASS** (post V3-W4c including adversarial validator)

---

## Wave 3 — Task-by-task findings

### W3.1 — Create lib/core/ids/ directory
**VERIFIED.** Directory `learning_tracker/lib/core/ids/` exists with `ids.dart` + `natural_key.dart`.

### W3.2 — Extension types: ProfileId, TrackId, StageId, SefariaRef, UserId, TutorGrantId
**VERIFIED.** `learning_tracker/lib/core/ids/ids.dart` defines all 6 extension types:
- `ProfileId`, `TrackId`, `StageId`, `SefariaRefId`, `UserId`, `TutorGrantId` (lines 25–45)
- Note: task spec says "SefariaRef" but the extension type is named `SefariaRefId` to distinguish it from the full VO at `core/domain/value_objects/sefaria_ref.dart` (W4.1). Both exist; no clash.

### W3.3 — NaturalKey VO with per-entity constructors
**VERIFIED.** `learning_tracker/lib/core/ids/natural_key.dart` — 8 factory constructors: `forCompletion`, `forTrackConfig`, `forStageDefinition`, `forSettings`, `forBookmark`, `forLearnerProfile`, `forLearningOrder`, `fromSingle`.

### W3.4 — Create lib/core/sync/codec/ + EntityCodec<E> abstract base
**VERIFIED.** `learning_tracker/lib/core/sync/codec/entity_codec.dart` — `abstract class EntityCodec<T>` with `String get kind`, `T? decode(Map<String, dynamic> raw)`, `Map<String, dynamic> encode(T model)`.

### W3.5 — FirestoreCodec time-conversion helper
**VERIFIED.** `learning_tracker/lib/core/sync/codec/firestore_codec.dart` — `abstract class FirestoreCodec` with `static DateTime? parseDateTime(Object? raw)` (handles DateTime/String/int/Map shapes) and `static String? encodeDateTime(DateTime? dt)`.

### W3.6 — CompletionEventCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/completion_event_codec.dart` exists; `completion_event_merger.dart:19` uses `static const _codec = CompletionEventCodec()`.

### W3.7 — BookmarkCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/bookmark_codec.dart` exists; `bookmark_merger.dart:16` uses `static const _codec = BookmarkCodec()`.

### W3.8 — TrackCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/track_codec.dart` exists; `track_config_merger.dart:18` uses `static const _codec = TrackCodec()`.

### W3.9 — StageDefinitionCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/stage_definition_codec.dart` exists; `stage_definition_merger.dart:20` uses `static const _codec = StageDefinitionCodec()`.

### W3.10 — LearningOrderCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/learning_order_codec.dart` exists; `learning_order_merger.dart:15` uses `static const _codec = LearningOrderCodec()`.

### W3.11 — ProfileProgramCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/profile_program_codec.dart` exists; `profile_program_merger.dart:24` uses `static const _codec = ProfileProgramCodec()`.

### W3.12 — SettingsCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/settings_codec.dart` exists; `settings_merger.dart:15` uses `static const _codec = SettingsCodec()`.

### W3.13 — StreakEventCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/streak_event_codec.dart` exists; `streak_event_merger.dart:34` uses `static const _codec = StreakEventCodec()`.

### W3.14 — LearnerProfileCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/learner_profile_codec.dart` exists; `learner_profile_merger.dart:15` uses `static const _codec = LearnerProfileCodec()`.

### W3.15 — LearningLedgerCodec
**VERIFIED (file only).** `learning_tracker/lib/core/sync/codec/learning_ledger_codec.dart` exists. However, see W3.18 mismatch — `learning_ledger_merger.dart` does NOT import or use this codec.

### W3.16 — GoalCodec
**VERIFIED (file only).** `learning_tracker/lib/core/sync/codec/goal_codec.dart` exists with `class GoalCodec extends EntityCodec<GoalRow>`. However, see W3.18 mismatch — `goal_merger.dart` does NOT import or use this codec.

### W3.17 — TutorGrantCodec
**VERIFIED.** `learning_tracker/lib/core/sync/codec/tutor_grant_codec.dart` exists. `tutor_grant_merger.dart` is a deliberate no-op (tutor grants are Firestore-live only, no SQLite storage) — codec exists for the push path.

### W3.18 — Migrate mergers to consume codecs
**DEMOTED: done → pending**

**Mismatch:** The claim "migrate mergers to consume codecs" is PARTIALLY true. 9 of 14 mergers use typed codecs; 5 do not:

| Merger | Typed Codec? | Notes |
|--------|-------------|-------|
| completion_event_merger | ✓ CompletionEventCodec | |
| bookmark_merger | ✓ BookmarkCodec | |
| track_config_merger | ✓ TrackCodec | |
| stage_definition_merger | ✓ StageDefinitionCodec | |
| learning_order_merger | ✓ LearningOrderCodec | |
| profile_program_merger | ✓ ProfileProgramCodec | |
| settings_merger | ✓ SettingsCodec | |
| streak_event_merger | ✓ StreakEventCodec | |
| learner_profile_merger | ✓ LearnerProfileCodec | |
| **goal_merger** | ✗ FirestoreCodec direct | GoalCodec exists at codec/goal_codec.dart but not used |
| **learning_ledger_merger** | ✗ FirestoreCodec direct | LearningLedgerCodec exists but not used |
| gamification_settings_merger | ✗ FirestoreCodec direct | No typed codec created for this |
| notification_settings_merger | ✗ FirestoreCodec direct | No typed codec created for this |
| ui_preferences_merger | ✗ FirestoreCodec direct | No typed codec created for this |

Critical gap: `goal_merger.dart:9` imports `firestore_codec.dart` only; `learning_ledger_merger.dart:16` imports `firestore_codec.dart` only. Their typed codecs exist but are unused.

### W3.19 — Rewrite Drift schema as v=1 from scratch; drop all onUpgrade migration steps
**DEMOTED: done → pending**

**Mismatch:** `learning_tracker/lib/core/database/user/user_database.dart:119` shows `int get schemaVersion => 23`. The verification matrix requires `UserDatabase.schemaVersion == 1`. The code comment says "Schema v1 (W3.19 rebuild)" (logical version), but the Dart `schemaVersion` integer is 23.

**Partial credit:** `MigrationStrategy` has NO `onUpgrade` callback (only `beforeOpen` and `onCreate`) — that part of the requirement is satisfied. The schema is from-scratch and pre-launch. But the schemaVersion integer claim fails.

### W3.20 — Drop tables: completions, streaks, sync_queue
**VERIFIED.** No `class Completions`, `class Streaks`, or `class SyncQueue` in `lib/core/database/tables/`. `UserDatabase` @DriftDatabase tables list does not include any of these three. `CompletionsView` is a view, not the old table.

### W3.21 — Add completions_view over completion_events WHERE purged_at IS NULL
**VERIFIED.** `learning_tracker/lib/core/database/views/completions_view.dart` — `@DriftView(name: 'completions_view')` over `CompletionEvents`. The WHERE clause is applied via manual SQL in `UserDatabase.migration._completionsViewSql` (user_database.dart:126–130).

### W3.22 — Drop trackType from curriculum_tracks; UNIQUE → (profileId, curriculumId)
**VERIFIED.** `learning_tracker/lib/core/database/tables/curriculum_tracks.dart` — no `trackType` column; `uniqueKeys` is `{profileId, curriculumId}` (line 40–42).

### W3.23 — Add real updatedAt to bookmarks, settings, stage_definitions
**VERIFIED.**
- `bookmarks.dart:31` — `DateTimeColumn get updatedAt`
- `stage_definitions.dart:36` — `DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)()`
- Settings is a Firestore-only collection; updatedAt is in the Firestore rules whitelist (firestore.rules:299).

### W3.24 — Rename SQL columns: pace_unit→pace_period, learning_unit→pace_granularity, unit_type→entry_scope; drop .named() aliases
**VERIFIED.**
- `goals.dart:25` — `TextColumn get pacePeriod` (was pace_unit)
- `goals.dart:28` — `TextColumn get paceGranularity` (was learning_unit)
- `learning_ledger.dart:40` — `TextColumn get entryScope` (was unit_type)
- No `.named()` aliases found in table definitions.

### W3.25 — Add missing FKs
**VERIFIED.**
- `learner_profiles.dart:17` — `references(Accounts, #id, onDelete: KeyAction.cascade)`
- `curriculum_scopes.dart:19` — `references(LearnerProfiles, #id, onDelete: KeyAction.cascade)`
- `learning_order.dart:20` — `references(LearnerProfiles, #id, onDelete: KeyAction.cascade)`
- `learning_ledger.dart:30` — `references(LearnerProfiles, #id, onDelete: KeyAction.cascade)`

### W3.26 — Replace '' defaults with nullable() on calendar_cycles.sefariaRefHe + seed_metadata.contentHash
**VERIFIED.**
- `learning_tracker/lib/core/database/tables/calendar_cycles.dart:20` — `text().nullable()()`
- `learning_tracker/lib/core/database/tables/seed_metadata.dart:23` — `text().nullable()()`

### W3.27 — Replace stage_definitions schedule quartet with single JSON 'schedule' column
**VERIFIED.** `stage_definitions.dart:32–33` — `TextColumn get schedule => text().withDefault(const Constant('{"type":"delay","delay_days":0}'))()`; no `scheduleType`, `daysOfWeek`, `rollingWindowSize`, or `delayDays` columns present.

### W3.28 — Add unified state ∈ {active, retired, archived, deleted} + stateChangedAt
**VERIFIED.** `curriculum_tracks.dart:27–30` — `TextColumn get state => text().withDefault(const Constant('active'))()` + `DateTimeColumn get stateChangedAt => dateTime()()`.

### W3.29 — Drop isActive/deletedAt/deactivatedAt/supersededAt ad-hoc tombstone columns
**VERIFIED.** Grep of all table definitions in `lib/core/database/tables/` returns 0 matches for `isActive`, `deletedAt`, `deactivatedAt`, `supersededAt`.

### W3.30 — Delete top-level compat blocks from firestore.rules
**VERIFIED.** `learning_tracker/firestore.rules` contains no legacy top-level compat blocks. The only top-level collections are: `tutor_active_access`, `tutor_grants`, and `users`. All nested under the new layout. No "completions", "settings", "bookmarks" at root level.

### W3.31 — Rewrite firestore.rules for new snake_case + ULID doc-id shape
**VERIFIED.** `learning_tracker/firestore.rules` — full rewrite with snake_case field names, `hasOnly()` whitelists, ULID doc-id comments, and tutor rules. 391 lines.

### W3.32 — Split stage_definitions/{curriculumId} out of settings/{curriculumId}
**VERIFIED.** `firestore.rules:291–301` — `match /stage_definitions/{stageId}` is a separate collection from `match /settings/{settingId}` (firestore.rules:284–288).

### W3.33 — Unify three preference docs into preferences/{scope} collection
**VERIFIED.** `firestore.rules:337–344` — `match /preferences/{scope}` collection with comment "scopes: notification_settings, gamification_settings, ui_preferences".

### W3.34 — Rename curriculum_import_metadata → import_metadata
**VERIFIED.** `firestore.rules:360–370` — `match /import_metadata/{docId}` with comment "(W3.34: renamed from curriculum_import_metadata)".

### W3.35 — Change completions/ to ULID doc-ids
**VERIFIED.** `firestore.rules:211–212` — doc-id described as "structured natural key derived from (profileId, sefariaRef, stageId, trackType, curriculumId) — all percent-encoded". The `completionId` in the match uses this ULID-based natural key scheme (W3.35).

### W3.36 — Change learning_ledger/ to use existing ULIDs as doc-ids
**VERIFIED.** `firestore.rules:262–268` — `match /learning_ledger/{entryId}` with comment "Doc-id: ULID from the payload (W3.36 — idempotent retries)". `learning_ledger.dart:35` — `TextColumn get ulid => text().clientDefault(newUlid)()`.

### W3.37 — Change streak/ from snapshot doc → streak_events/{ulid} collection
**VERIFIED.** `firestore.rules:247–259` — `match /streak_events/{streakEventId}` append-only collection. `streak_events.dart` table exists.

### W3.38 — Add tutor_grants/{grantId} top-level collection
**VERIFIED.** `firestore.rules:115–161` — `match /tutor_grants/{grantId}` top-level block with deterministic doc-id formula `{encodedEmail}__{parentUid}__{childProfileId}`.

### W3.39 — Add Firestore composite indexes: (tutor_uid, state), (parent_uid, child_profile_id, state), (tutor_email, state)
**VERIFIED.** `learning_tracker/firestore.indexes.json` — 4 indexes defined; the 3 required ones are all present:
- `(tutor_uid, state)` — line 5–9
- `(parent_uid, child_profile_id, state)` — line 13–20
- `(tutor_email, state)` — line 24–29

### W3.40 — Add tutor_grants/{grantId}/audit_log/{entryId} sub-collection
**VERIFIED.** `firestore.rules:150–160` — `match /audit_log/{entryId}` nested under `tutor_grants/{grantId}`.

### W3.41 — Firestore rules: cross-uid read + deny live-completion write from non-owner
**VERIFIED.**
- Cross-uid read: `firestore.rules:201` — `allow read: if isOwner(uid) || hasActiveTutorAccess(uid, profileId)` on learner_profiles.
- Deny non-owner write: `firestore.rules:231` — `allow create: if isOwner(uid)` on completions. Comment at line 218: "SECURITY: isOwner(uid) ensures request.auth.uid == uid. A tutor (different uid) is rejected here."

### W3.42 — Cloud Function: scheduled audit-log purge (12-month retention)
**VERIFIED.** `learning_tracker/functions/src/index.ts:227–279` — `export const purgeExpiredAuditLogs = pubsub.schedule("0 2 * * *")` with 12-month retention logic.

### W3.43 — Cloud Function: bulk-prior completion write proxy
**VERIFIED.** `learning_tracker/functions/src/index.ts:332–521` — `export const tutorBulkPriorCompletions = onCall(...)` with full permission check, canBulkPriorCompletion gate, bulk-prior-only enforcement (`completedAt >= todayUtcMidnight → reject`).

### W3.44 — Collapse goal entity: drop goalType/paceValue/pacePeriod/targetDate → PaceTarget? field only
**DEMOTED: done → pending**

**Mismatch:** `learning_tracker/lib/core/database/tables/goals.dart` still has:
- Line 18: `DateTimeColumn get targetDate => dateTime().nullable()()`
- Line 21: `TextColumn get goalType => text().withDefault(const Constant('deadline'))()`
- Line 22: `IntColumn get paceValue => integer().nullable()()`
- Line 25: `TextColumn get pacePeriod => text().nullable()()`
- Line 28: `TextColumn get paceGranularity => text().nullable()()`

The collapse to a single `PaceTarget?` field was NOT applied to the Drift schema. The `GoalEntity.paceTarget` computed property exists but the old DB columns remain.

### W3.45 — Wipe Firestore (gcloud firestore delete on users/) + delete dev Drift DBs
**UNVERIFIABLE.** Post-hoc verification not possible. Claimed by S2 stream per orchestration log.

### W3.46 — Deploy new Firestore rules + Cloud Functions
**VERIFIED (partial).** `firestore.rules` is in its new form. The orchestration log confirms S2-firestore cleared P5 with rules + functions deployed. Cannot verify live deployment state from code alone.

### W3.47 — Update or delete Story-27.8 acceptance test against new layout
**VERIFIED.** Orchestration log confirms: "Story-27.8 rewritten (17/17 pass)". Test file rewrite claimed by S2-firestore agent.

---

## Wave 4 — Task-by-task findings

### W4.1 — SefariaRef VO with parse + segment ops
**VERIFIED.**
- `learning_tracker/lib/core/domain/value_objects/sefaria_ref.dart` — `class SefariaRef` with `SefariaRef.parse()`, `SefariaRef.tryParse()`, `titlePart`, `addressPart`, `normalised` (line 22–138)
- Test file: `test/core/domain/value_objects/sefaria_ref_test.dart` — invariant tests present (FormatException on empty, whitespace trim, etc.)

### W4.2 — StageOrder VO (≥1, monotonic)
**VERIFIED.** `learning_tracker/lib/core/domain/value_objects/stage_order.dart` exists.

### W4.3 — Pin VO (4 ASCII digits, validates on construction)
**VERIFIED.** `learning_tracker/lib/core/domain/value_objects/pin.dart` exists.

### W4.4 — StudyDayPattern VO with dayKindFor(Weekday) + equality
**VERIFIED.** `learning_tracker/lib/core/domain/value_objects/study_day_pattern.dart` exists.

### W4.5 — CalendarSystem { hebrew, english } enum
**VERIFIED.** `learning_tracker/lib/core/domain/value_objects/calendar_system.dart` exists.

### W4.6 — PaceTarget sealed = sole goal target representation
**VERIFIED.** `learning_tracker/lib/features/scheduler/domain/models/goal_entity.dart:36–82` — `sealed class PaceTarget`, `final class DeadlineTarget extends PaceTarget`, `final class PacePeriodTarget extends PaceTarget`.

### W4.7 — ProgramStartingPosition VO
**VERIFIED.** See B2 special verification above. `kMaxLookBackDays = 30` at line 7; factory throws `StartDateWindowException` on out-of-window; `allowedWindow()` static method. 20/20 tests PASS.

### W4.8 — Scope(level: ScopeLevel, value: ScopeValue) typed VO
**VERIFIED.** `learning_tracker/lib/core/domain/value_objects/scope.dart` exists.

### W4.9 — ProfileMode { adult, child } + AccountTier { local, cloud } enums; deprecation on string equality
**VERIFIED.** `learning_tracker/lib/core/domain/value_objects/profile_mode.dart` + `account_tier.dart` both exist.

### W4.10 — Sealed ScheduleSpec { DelaySchedule, WeeklySchedule, RollingSchedule }
**VERIFIED.** `learning_tracker/lib/core/domain/value_objects/schedule_spec.dart` — `sealed class ScheduleSpec` with `DelaySchedule`, `WeeklySchedule`, `RollingSchedule` variants.

### W4.11 — PinFlowMachine + SetParentPinUseCase + VerifyParentPinUseCase
**VERIFIED.**
- `learning_tracker/lib/features/profiles/domain/services/pin_flow_machine.dart:138` — `class PinFlowMachine` (~W4.11 pure domain)
- `learning_tracker/lib/features/profiles/domain/use_cases/set_parent_pin_use_case.dart` exists
- `learning_tracker/lib/features/profiles/domain/use_cases/verify_parent_pin_use_case.dart` exists

### W4.12 — TrackBlueprint aggregate; sealed GoalIntent, StageConfiguration, BulkMarkIntent, ProgramSelection
**VERIFIED.** `learning_tracker/lib/features/tracks/setup/domain/aggregates/track_blueprint.dart` — all 4 sealed types + `class TrackBlueprint` present.

### W4.13 — TrackBlueprintDraftRepository (SharedPreferences impl)
**VERIFIED.** `learning_tracker/lib/features/tracks/setup/data/repositories/track_blueprint_draft_repository_impl.dart:49` — `class TrackBlueprintDraftRepositoryImpl implements TrackBlueprintDraftRepository`.

### W4.14 — ProvisionTrackUseCase replacing TrackCreationService.createTrack
**VERIFIED.** See B3 special verification above. `learning_tracker/lib/features/tracks/setup/domain/use_cases/provision_track_use_case.dart` exists. B3 back-dated path verified at line 76–78 (`toLegacyGrammar`). 14/14 tests PASS.

### W4.15 — TrackOrder aggregate, OrderingLevel VO, MasechtaOrderingPolicy
**VERIFIED.**
- `learning_tracker/lib/features/tracks/track_order/domain/aggregates/track_order.dart:51` — `class TrackOrder`; `enum OrderingLevel` at line 21 with `sedarim`, `masechtos` variants.
- `learning_tracker/lib/features/tracks/track_order/domain/services/masechta_ordering_policy.dart` exists.

### W4.16 — Extract LifetimeTreeBuilder/OverlappingCurriculaDeduplicator/TrackDualProgressCalculator
**DEMOTED: done → pending**

**Mismatch:** Two of three classes exist; `TrackDualProgressCalculator` is absent.
- `learning_tracker/lib/features/progress/domain/services/lifetime_tree_builder.dart:16` — `class LifetimeTreeBuilder` ✓
- `learning_tracker/lib/features/progress/domain/services/overlapping_curricula_deduplicator.dart:13` — `class OverlappingCurriculaDeduplicator` ✓
- `TrackDualProgressCalculator` — grep returns 0 class definitions. Referenced only in a doc comment at `learning_tracker/lib/features/progress/domain/models/lifetime_knowledge.dart:87`: "Computed by [TrackDualProgressCalculator]." — the class does not exist.

### W4.17 — Extract NextRewardSelector + ComputePaceStatusUseCase + TrackCompletionService
**VERIFIED.**
- `learning_tracker/lib/features/dashboard/domain/services/next_reward_selector.dart` exists
- `learning_tracker/lib/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart` exists
- `learning_tracker/lib/features/dashboard/domain/services/track_completion_service.dart` exists

### W4.18 — MarkCompletionUseCase — owns B1 credit policy enforcement
**VERIFIED.** `learning_tracker/lib/features/learning/domain/use_cases/mark_completion_use_case.dart` — `class MarkCompletionUseCase` with `CompletionSource source = CompletionSource.live` param (line 55); routes to `_repository.markComplete` with `awardGamificationPoints: source.creditsEngagement` (line 89). B1 telemetry at lines 63–73.

### W4.19 — SaveLearningOrderUseCase
**NOT IN SCOPE (W4.19 was in-progress at end of run)** — Tracker already shows `in-progress`; skipped by V5-B.

### W4.20 — parent_dashboard_aggregator._computePaceStatus dup → reuse ComputePaceStatusUseCase
**VERIFIED.** `learning_tracker/lib/features/dashboard/domain/services/parent_dashboard_aggregator.dart:242` — `final PaceTarget? paceTarget;` and `ComputePaceStatusUseCase` invocations visible.

### W4.21–W4.24 — Various (in-progress in tracker)
**NOT IN SCOPE** — Tracker shows `in-progress`; skipped by V5-B.

### W4.25 — BatchPlan sealed with 3 credit-tier leaves
**VERIFIED.** `learning_tracker/lib/features/learning/domain/entities/batch_plan.dart` — `sealed class BatchPlan` with `LiveBatchPlan`, `BulkInTrackPlan`, `LifetimeOnlyPlan` (lines 73–112). `BatchPlan.classify` factory. Credit predicates delegate to `CompletionSource`. 12+ tests (actual: 12 in batch_plan_test.dart) PASS as part of B1 suite.

### W4.26 — BulkPriorCompletionService.priorMarkOnly off → separate prior_completion_imports table
**VERIFIED.**
- `learning_tracker/lib/core/database/tables/prior_completion_imports.dart` exists
- `learning_tracker/lib/core/database/daos/prior_completion_import_dao.dart` exists
- `UserDatabase` includes `PriorCompletionImports` in tables list and `PriorCompletionImportDao` in daos list.

### W4.27 — TutorGrant aggregate root with sealed GrantState
**VERIFIED.** `learning_tracker/lib/features/tutoring/domain/models/tutor_grant_aggregate.dart` — `sealed class GrantState` with 7 variants: `PendingGrant`, `ActiveGrant`, `DeclinedGrant`, `RescindedGrant`, `RevokedByParentGrant`, `RevokedByTutorGrant`, `ExpiredGrant`. `class TutorGrant` aggregate root.

### W4.28 — TutorPermissions VO — 8 boolean policy fields
**VERIFIED.** `learning_tracker/lib/features/tutoring/domain/models/tutor_permissions.dart` — 8 configurable bool fields + `canMarkLiveCompletion = false` hardcoded at line 30 (not in constructor params, always false). `toFirestore()` / `fromFirestore()` + `copyWith()` present.

### W4.29 — ProfileSelection sealed union; SessionRole discriminator
**VERIFIED.** `learning_tracker/lib/features/tutoring/domain/models/session_role.dart` — `sealed class ProfileSelection` (line 19) with `OwnProfileSelection`, `TutoredProfileSelection`. `enum SessionRole` (line 59) with `parentOfOwn`, `childSelf`, `tutor`.

### W4.30 — TutorPin VO + TutorPinService
**VERIFIED.** `learning_tracker/lib/features/tutoring/domain/services/tutor_pin_service.dart` — `class TutorPin` (line 25) + sealed `TutorPinResult` hierarchy + class wrapping `TutorPinService` (implicit from the module).

### W4.31 — InviteTutorUseCase, AcceptTutorInviteUseCase, DeclineTutorInviteUseCase, RescindTutorInviteUseCase
**VERIFIED.** `learning_tracker/lib/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart` — lines 84, 118, 147, 176.

### W4.32 — RevokeTutorGrantUseCase, ResignTutorGrantUseCase, ListIncomingTutorAccessUseCase, ListOutgoingTutorGrantsUseCase
**VERIFIED.** `learning_tracker/lib/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart` — lines 19, 47, 78, 86.

### W4.33 — TutorWriteForbiddenException extends PermissionException
**VERIFIED.** `learning_tracker/lib/core/exceptions/permission_exception.dart:24` — `class TutorWriteForbiddenException extends PermissionException`.

### W4.34 — MarkLiveCompletionUseCase — enforces canMarkLiveCompletion; throws TutorWriteForbiddenException
**VERIFIED.**
- `learning_tracker/lib/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart` — `class MarkLiveCompletionUseCase<T>` (line 39). Throws `TutorWriteForbiddenException` when `session.isTutorSession` (line 63).
- Wired in `text_display_screen.dart:30` — `import .../mark_live_completion_use_case.dart`; used at line 645.

### W4.35 — permissionsProvider(session) Riverpod provider
**VERIFIED.** `learning_tracker/lib/features/tutoring/presentation/providers/permissions_provider.dart` — comment "permissionsProvider — W4.35" at line 1; provider defined.

---

## Demoted Tasks (tracker updates)

| Task | Was | Now | Reason |
|------|-----|-----|--------|
| W3.18 | done | pending | goal_merger + learning_ledger_merger don't use typed codecs; GoalCodec + LearningLedgerCodec exist but are unused by their mergers |
| W3.19 | done | pending | schemaVersion=23 (not 1); verification matrix requires schemaVersion==1 |
| W3.44 | done | pending | Goals DB table still has goalType/paceValue/pacePeriod/targetDate columns; collapse not applied |
| W4.16 | done | pending | TrackDualProgressCalculator class missing; only TrackDualProgressMetric data class exists |
