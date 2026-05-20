# Refactor Task Tracker

Running tracker for the v3.3 tech-debt remediation: 225 W-tasks across 7 waves + 3 B-tasks, mapped to 5 streams.

**Legend:**
- Checkbox: `[ ]` pending/in-progress · `[x]` done (claimed by sub-agent) · `[V]` verified (confirmed by V5)
- Status column: `pending` · `in-progress` · `done` · `verified`
- Sizes: `S` ≤30 min · `M` 30 min–2 h · `L` half-day to full-day
- Streams: `S1` Foundation · `S2` Sync &amp; Data · `S3` Account/Profile/Tutor · `S4` Tracks/Completion · `S5` Domain VOs/Cleanup/Polish

Sync-point trigger tags: `[P1]` `[P2]` `[P3]` `[P4]` `[P5]` `[P6]` `[P7]`

---

## Bug fixes — B1-B3 (integration verifications)

- [ ] B1   (—, S4, pending)    Three-tier completion credit policy — verified at W4.18, W4.25, W4.26, W4.16, W7.11
- [ ] B2   (—, S4, pending)    Program-track start window [today−30, today] — verified at W4.7, W6.2
- [ ] B3   (—, S4, pending)    Back-dated enrolment generates overdue catch-up tasks — verified at W4.14, W4.16/W4.17, W7.25

---

## Wave 1 — Foundation &amp; dead code (S1 · ~30 tasks)

### Phase 1a · lib/app/ extraction
- [x] W1.1  (S, S1, done)    Create lib/app/ with sub-dirs: router/, bootstrap/, restore/, sync_runtime/
- [x] W1.2  (S, S1, done)    Move core/navigation/{app_router, app_router.gr, router_provider, app_shell, guards/auth_guard}.dart → lib/app/router/
- [x] W1.3  (M, S1, done)    Split main.dart bootstrap into lib/app/bootstrap/{firebase, crashlytics, logger, analytics, seed, account, notifications}_bootstrap.dart
- [x] W1.4  (S, S1, done)    Move device_restore_screen.dart + restore service + restore_providers → lib/app/restore/
- [x] W1.5  (S, S1, done)    Move SyncLifecycleObserver orchestrator-path → lib/app/sync_runtime/ (legacy stays until Wave 2)
- [x] W1.6  (S, S1, done)    Shrink main.dart to ~30 lines (bootstrap() then runApp(App()))

### Phase 1b · Core relocations
- [x] W1.7  (S, S1, done)    Move features/sync/domain/merge_rules.dart → core/sync/merge/; update 5 merger imports — closes H2
- [x] W1.8  (S, S1, done)    Move profile_scoped_preference_keys.dart → core/preferences/; update 8 importers
- [ ] W1.9  (S, S1, in-progress)    Move language_provider.dart → core/preferences/

### Phase 1c · Barrel-file convention + lint enforcement
- [ ] W1.10 (M, S1, pending)    Create empty barrel files features/&lt;feature&gt;.dart for all 18 features `[P1]`
- [ ] W1.11 (M, S1, pending)    Rewrite no_feature_cross_import lint to require &lt;feature&gt;.dart instead of providers.dart `[P1]`
- [ ] W1.12 (S, S1, pending)    Add make audit grep #14 — no `package:learning_tracker/features/` in lib/core/**
- [ ] W1.13 (S, S1, pending)    Add make audit grep #15 — no cross-feature deep imports
- [ ] W1.14 (S, S1, pending)    Drop `|| echo ::warning::` from CI lint job — hard fail — closes H6
- [ ] W1.15 (S, S1, pending)    Add unit tests for no_feature_cross_import lint rule — closes H7 partial
- [ ] W1.16 (S, S1, pending)    Add unit tests for no_curriculum_display_name_bypass lint rule — closes H7 partial

### Phase 1d · Dead code purge
- [ ] W1.17 (S, S1, pending)    Verify zero refs; delete dashboard_model_provider.dart + .g.dart
- [ ] W1.18 (S, S1, pending)    Confirm-not-parked-epic; delete data_export_import_service.dart (946 LOC)
- [ ] W1.19 (S, S1, pending)    Delete core/constants/app_assets.dart (0 refs)
- [ ] W1.20 (S, S1, pending)    Delete core/database/seed/test_date_seeds.dart (0 refs)
- [ ] W1.21 (S, S1, pending)    Delete H8 remainder (bulk_completion_dialog, completion_button, todays_tasks_widget, key_stats_row, content_browser_tree, content_version_check_service, link_provider_dialog, language_provider Riverpod, add_track_controller)
- [ ] W1.22 (M, S1, pending)    Verify-then-delete M8 single-ref files (text_content_config, program_ref_resolver, content_db_health_checker, content_result, curriculum_content_fetcher, profile_creation_use_case, duplicate_completion_exception)
- [ ] W1.23 (S, S1, pending)    Confirm zombie @RoutePage screens dead; delete GoalSetupScreen, LearningOrderScreen, ScopeSelectionScreen
- [ ] W1.24 (S, S1, pending)    Delete .gitkeep-only dirs (utils/{extensions,formatters,helpers}/, parent_mode/domain/{entities,use_cases,repositories}/, sync/data/data_sources/)

### Phase 1e · AppLogger foot-gun fix (T18)
- [ ] W1.25 (M, S1, pending)    Rename AppLogger.instance getter → AppLogger.talker; new AppLogger.instance = singleton AppLogger
- [ ] W1.26 (M, S1, pending)    Migrate 29 raw AppLogger.instance.error/info/warning sites to structured API
- [ ] W1.27 (S, S1, pending)    Delete 5 defensive wrappers (`final _log = AppLogger(AppLogger.instance);`)

### Phase 1f · Exception/event base scaffolding
- [ ] W1.28 (S, S1, pending)    Create core/exceptions/app_exception.dart with abstract root + 5 category bases
- [ ] W1.29 (S, S1, pending)    Create core/logging/log_events.dart constants file
- [ ] W1.30 (S, S1, pending)    Update CLAUDE.md — remove link to deleted docs/coding-standards.md — closes M9

---

## Wave 2 — Re-carve features + sync stack deletion (~41 tasks)

### Phase 2a · Tracks cluster merge (S4)
- [x] W2.1  (M, S4, done)    Create features/tracks/ skeleton (data/, domain/, presentation/)
- [x] W2.2  (M, S4, done)    Move features/track_setup/** → features/tracks/setup/
- [x] W2.3  (M, S4, done)    Move features/learning_order/** → features/tracks/whole_curriculum_order/
- [x] W2.4  (M, S4, done)    Move features/track_learning_order/** → features/tracks/track_order/
- [x] W2.5  (M, S4, done)    Move features/stages/** → features/tracks/stages/
- [x] W2.6  (S, S4, done)    Add tracks/data/ layer placeholder — closes M6
- [x] W2.7  (S, S4, done)    Pull curriculum_activation_service from settings → tracks
- [x] W2.8  (M, S4, done)    Fill features/tracks/tracks.dart barrel with public surface
- [x] W2.9  (M, S4, done)    Migrate all importers from deep paths → tracks.dart barrel `[P2]`

### Phase 2b · Account cluster merge (S3)
- [x] W2.10 (M, S3, done)    Create features/account/ skeleton
- [x] W2.11 (M, S3, done)    Move features/auth/** → features/account/
- [x] W2.12 (M, S3, done)    Move sign-up/magic-link/upgrade halves of onboarding/** → account/onboarding/ (track-setup half stays for W6)
- [x] W2.13 (M, S3, done)    Move account_management_service from settings → account
- [x] W2.14 (S, S3, done)    Fill features/account/account.dart barrel
- [x] W2.15 (M, S3, done)    Migrate importers `[P2]`

### Phase 2c · Dissolve parent_mode (S3)
- [x] W2.16 (S, S3, done)    Move reward + point config screens → features/gamification/
- [x] W2.17 (S, S3, done)    Move PIN keypad widget → core/widgets/
- [x] W2.18 (S, S3, done)    Move parent_dashboard_aggregator → features/dashboard/
- [x] W2.19 (M, S3, done)    Move pin_service + create PinFlowMachine domain skeleton → features/profiles/ (full domain in W4.11)
- [x] W2.20 (S, S3, done)    Delete features/parent_mode/ directory

### Phase 2d · Core/ misfiled-feature promotions (S2)
- [x] W2.21 (S, S2, done)    Move core/learning/ → features/learning/ (absorb optimistic_completion_provider, completion_writer)
- [x] W2.22 (S, S2, done)    Move core/streak/ → features/gamification/streak/
- [x] W2.23 (S, S2, done)    Move core/services/{calendar_program_*, local_calendar_engine, daily_schedule_composer, cross_curriculum_aggregator} → sacred_calendar/ + scheduling/
- [x] W2.24 (S, S2, done)    Move core/services/pin_service → features/profiles/
- [x] W2.25 (S, S2, done)    Delete core/services/ (now empty) `[P2]`

### Phase 2e · Missing mergers (S2)
- [x] W2.26 (M, S2, done)    Add EntityKind.learningOrder + LearningOrderMerger + router case + mergeRouterProvider entry — closes C3/H3
- [ ] W2.27 (M, S2, in-progress)    Add 7 mergers + channels for SyncEngine-only collections (goals, learning_ledger, notif_settings, gamification_settings, ui_preferences, learning_order, profile_programs) — closes M1
- [ ] W2.28 (M, S2, pending)    Add pullStreak step in pull_pipeline — closes M4
- [ ] W2.29 (M, S2, pending)    Wire real stage_definitions/ push + pull + listener channel + _channelToKind — closes H4
- [ ] W2.30 (S, S2, pending)    Make _pullCollection throw on MergeOutcome.halt (after W2.26 lands)

### Phase 2f · Single-shot legacy sync deletion (S2)
- [ ] W2.31 (M, S2, pending)    Add outbox-backed SyncWriteFacade impl + syncWriteFacadeProvider
- [ ] W2.32 (M, S2, pending)    Move pushAllLocalData + backfillGoalsForCloudCutover to outbox path
- [ ] W2.33 (M, S2, pending)    Move SyncStatus ownership from SyncEngine to SyncOrchestrator (own StreamController); repoint sync_status_providers
- [ ] W2.34 (M, S2, pending)    Grep-and-replace 21 syncEngineProvider consumers → syncWriteFacadeProvider — closes H1
- [ ] W2.35 (S, S2, pending)    Delete features/sync/data/sync_engine.dart
- [ ] W2.36 (S, S2, pending)    Delete features/sync/data/firestore_data_source.dart — closes M5
- [ ] W2.37 (S, S2, pending)    Delete features/sync/data/offline_queue.dart
- [ ] W2.38 (S, S2, pending)    Delete legacy sync_lifecycle_observer.dart (orchestrator wiring stays)
- [ ] W2.39 (S, S2, pending)    Delete legacy features/sync/presentation/providers/sync_providers.dart
- [ ] W2.40 (S, S2, pending)    Confirm H5 + M2 gone with deleted files; cleanup trivia in core/sync/ `[P3]`

### Phase 2g · Tutoring feature skeleton (S3)
- [x] W2.41 (S, S3, done)    Create features/tutoring/ skeleton (data/, domain/, presentation/) + empty tutoring.dart barrel — populated W3/W4/W6

---

## Wave 3 — Data model rebuild + tutor schema (~47 tasks)

### Phase 3a · Typed IDs (S2)
- [ ] W3.1  (S, S2, pending)    Create lib/core/ids/ directory
- [ ] W3.2  (S, S2, pending)    Add extension types: ProfileId, TrackId, StageId, SefariaRef, UserId, TutorGrantId
- [ ] W3.3  (M, S2, pending)    Add NaturalKey VO with per-entity constructors

### Phase 3b · Codecs (S2)
- [ ] W3.4  (S, S2, pending)    Create lib/core/sync/codec/ + EntityCodec&lt;E&gt; abstract base
- [ ] W3.5  (S, S2, pending)    Add FirestoreCodec time-conversion helper (DateTime ⇄ Timestamp)
- [ ] W3.6  (M, S2, pending)    CompletionEventCodec
- [ ] W3.7  (M, S2, pending)    BookmarkCodec
- [ ] W3.8  (M, S2, pending)    TrackCodec
- [ ] W3.9  (M, S2, pending)    StageDefinitionCodec
- [ ] W3.10 (M, S2, pending)    LearningOrderCodec
- [ ] W3.11 (M, S2, pending)    ProfileProgramCodec
- [ ] W3.12 (M, S2, pending)    SettingsCodec (after splitting stage_definitions out)
- [ ] W3.13 (M, S2, pending)    StreakEventCodec
- [ ] W3.14 (M, S2, pending)    LearnerProfileCodec
- [ ] W3.15 (M, S2, pending)    LearningLedgerCodec
- [ ] W3.16 (M, S2, pending)    GoalCodec
- [ ] W3.17 (M, S2, pending)    TutorGrantCodec
- [ ] W3.18 (M, S2, pending)    Migrate mergers to consume codecs (kills 5-way marshaling — T6) `[P4]`

### Phase 3c · Drift schema rebuild (S2)
- [ ] W3.19 (M, S2, pending)    Rewrite Drift schema as v=1 from scratch; drop all onUpgrade migration steps
- [ ] W3.20 (S, S2, pending)    Drop tables: completions, streaks, sync_queue
- [ ] W3.21 (M, S2, pending)    Add completions_view over completion_events WHERE purged_at IS NULL
- [ ] W3.22 (S, S2, pending)    Drop trackType column from curriculum_tracks; UNIQUE → (profileId, curriculumId)
- [ ] W3.23 (M, S2, pending)    Add real updatedAt to bookmarks, settings, stage_definitions — closes M3
- [ ] W3.24 (S, S2, pending)    Rename SQL columns: pace_unit→pace_period, learning_unit→pace_granularity, unit_type→entry_scope; drop .named() aliases — closes T4
- [ ] W3.25 (S, S2, pending)    Add missing FKs: learner_profiles→accounts, curriculum_scopes/learning_order/learning_ledger→learner_profiles
- [ ] W3.26 (S, S2, pending)    Replace '' defaults with nullable() on calendar_cycles.sefariaRefHe + seed_metadata.contentHash
- [ ] W3.27 (M, S2, pending)    Replace stage_definitions schedule quartet with single JSON 'schedule' column (sealed ScheduleSpec materialisation)
- [ ] W3.28 (S, S2, pending)    Add unified state ∈ {active, retired, archived, deleted} + stateChangedAt — closes T7
- [ ] W3.29 (S, S2, pending)    Drop isActive/deletedAt/deactivatedAt/supersededAt ad-hoc tombstone columns

### Phase 3d · Firestore rebuild (S2)
- [ ] W3.30 (S, S2, pending)    Delete top-level compat blocks from firestore.rules — closes T11
- [ ] W3.31 (M, S2, pending)    Rewrite firestore.rules for new snake_case + ULID doc-id shape
- [ ] W3.32 (S, S2, pending)    Split stage_definitions/{curriculumId} out of settings/{curriculumId} — closes T8 partial
- [ ] W3.33 (S, S2, pending)    Unify three preference docs into preferences/{scope} collection
- [ ] W3.34 (S, S2, pending)    Rename curriculum_import_metadata → import_metadata
- [ ] W3.35 (S, S2, pending)    Change completions/ to ULID doc-ids
- [ ] W3.36 (S, S2, pending)    Change learning_ledger/ to use existing ULIDs as doc-ids — closes T10
- [ ] W3.37 (S, S2, pending)    Change streak/ from snapshot doc → streak_events/{ulid} collection

### Phase 3e · Tutor mode schema (S3)
- [ ] W3.38 (M, S3, in-progress)    Add tutor_grants/{grantId} top-level collection with deterministic doc-id strategy
- [ ] W3.39 (M, S3, pending)    Add Firestore composite indexes: (tutor_uid, state), (parent_uid, child_profile_id, state), (tutor_email, state)
- [ ] W3.40 (M, S3, pending)    Add tutor_grants/{grantId}/audit_log/{entryId} sub-collection
- [ ] W3.41 (M, S3, pending)    Firestore rules: cross-uid read on users/{ownerUid}/learner_profiles/{pid}/** if active tutor grant; deny live-completion write from non-owner uids
- [ ] W3.42 (M, S3, pending)    Cloud Function: scheduled audit-log purge (12-month retention past grant termination)
- [ ] W3.43 (M, S3, pending)    Cloud Function: bulk-prior completion write proxy (writes as owner uid after tutor permission check)

### Phase 3f · Goal model collapse (S4)
- [ ] W3.44 (M, S4, pending)    Collapse goal entity: drop goalType/paceValue/pacePeriod/targetDate → PaceTarget? field only; migrate goal_repository_impl + dashboard_providers

### Phase 3g · Wipe and verify (S2)
- [ ] W3.45 (S, S2, pending)    Wipe Firestore (gcloud firestore delete on users/) + delete dev Drift DBs
- [ ] W3.46 (S, S2, pending)    Deploy new Firestore rules + Cloud Functions `[P5]`
- [ ] W3.47 (S, S2, pending)    Update or delete Story-27.8 acceptance test against new layout

---

## Wave 4 — Domain modelling + value objects + permission model (~35 tasks)

### Phase 4a · Value objects
- [x] W4.1  (M, S5, done)    SefariaRef VO with parse + segment ops; start strangler migration of 73 raw-String sites
- [x] W4.2  (S, S5, done)    StageOrder VO (≥1, monotonic)
- [x] W4.3  (S, S5, done)    Pin VO (4 ASCII digits, validates on construction)
- [x] W4.4  (M, S5, done)    StudyDayPattern VO with dayKindFor(Weekday) + equality
- [x] W4.5  (S, S5, done)    CalendarSystem { hebrew, english } enum
- [x] W4.6  (S, S4, done)    PaceTarget sealed = sole goal target representation
- [x] W4.7  (M, S4, done)    ProgramStartingPosition VO replacing 'offset:N|ref:&lt;sefariaRef&gt;' grammar — **owns B2 + B3 window enforcement**
- [x] W4.8  (S, S5, done)    Scope(level: ScopeLevel, value: ScopeValue) typed VO
- [x] W4.9  (S, S5, done)    ProfileMode { adult, child } + AccountTier { local, cloud } enums; deprecation on string equality
- [ ] W4.10 (M, S4, pending)    Sealed ScheduleSpec { DelaySchedule, WeeklySchedule, RollingSchedule } replacing nullable quartet

### Phase 4b · Anemic features rebuilt
- [ ] W4.11 (M, S3, pending)    parent_mode PIN → PinFlowMachine pure domain (~100 LOC) + SetParentPinUseCase + VerifyParentPinUseCase; thin Riverpod adapter
- [ ] W4.12 (M, S4, pending)    tracks setup → typed TrackBlueprint aggregate; sealed GoalIntent, StageConfiguration, BulkMarkIntent, ProgramSelection
- [ ] W4.13 (M, S4, pending)    tracks setup → TrackBlueprintDraftRepository (SharedPreferences impl) replacing 7 ad-hoc keys
- [ ] W4.14 (M, S4, pending)    tracks setup → ProvisionTrackUseCase replacing TrackCreationService.createTrack — **B3 integration check (back-date generates overdue)**
- [ ] W4.15 (S, S4, pending)    track_learning_order → TrackOrder aggregate, OrderingLevel { sedarim, masechtos } VO, MasechtaOrderingPolicy
- [ ] W4.16 (M, S5, in-progress)    progress → promote inline models to domain/; extract LifetimeTreeBuilder/OverlappingCurriculaDeduplicator/TrackDualProgressCalculator — **B1 lifetime tier subscriber + B3 projection check**
- [ ] W4.17 (M, S5, pending)    dashboard → extract NextRewardSelector + ComputePaceStatusUseCase + TrackCompletionService — **B3 projection check**

### Phase 4c · Business-logic relocations
- [ ] W4.18 (M, S4, pending)    completion_repository_impl.markComplete:57-200 → MarkCompletionUseCase — **owns B1 credit policy enforcement**
- [ ] W4.19 (M, S5, pending)    learning_order_repository_impl.saveOrder:91-129 → SaveLearningOrderUseCase
- [ ] W4.20 (S, S5, pending)    parent_dashboard_aggregator._computePaceStatus dup → reuse ComputePaceStatusUseCase
- [ ] W4.21 (M, S5, pending)    notification_providers.dart:22-46 → ReminderPreferences + NotificationPreferencesRepository
- [ ] W4.22 (S, S5, pending)    track_learning_order_repository_impl._buildMasechtosIndex → MasechtaOrderingPolicy (already W4.15)
- [ ] W4.23 (S, S5, pending)    profile_providers.dart SelectedProfileId → ProfileSession aggregate in profiles/domain/
- [ ] W4.24 (S, S5, pending)    dashboard_providers.dart side-effect-in-read-provider → write-path repository method
- [ ] W4.25 (M, S4, pending)    core/learning/completion_writer.commitBatch/commit → sealed BatchPlan + _classifyBatch/_applyBatchPlan/_resolveResults — **B1 credit policy at batch classification**
- [ ] W4.26 (M, S4, pending)    Split BulkPriorCompletionService.priorMarkOnly off completion_events → separate prior_completion_imports table — **B1 bulkInTrack path**

### Phase 4d · Tutor mode domain (S3)
- [ ] W4.27 (M, S3, pending)    TutorGrant aggregate root with sealed GrantState (pending/active/declined/rescinded/revokedByParent/revokedByTutor/expired)
- [ ] W4.28 (S, S3, pending)    TutorPermissions VO — 8 boolean policy fields, single source of truth
- [ ] W4.29 (M, S3, pending)    ProfileSelection { own | tutored } sealed union; SessionRole { parentOfOwn | childSelf | tutor } discriminator
- [ ] W4.30 (S, S3, pending)    TutorPin VO + TutorPinService (distinct from Parent PIN)
- [ ] W4.31 (M, S3, pending)    InviteTutorUseCase, AcceptTutorInviteUseCase, DeclineTutorInviteUseCase, RescindTutorInviteUseCase
- [ ] W4.32 (M, S3, pending)    RevokeTutorGrantUseCase, ResignTutorGrantUseCase, ListIncomingTutorAccessUseCase, ListOutgoingTutorGrantsUseCase
- [ ] W4.33 (S, S3, pending)    TutorWriteForbiddenException extends PermissionException
- [ ] W4.34 (M, S3, pending)    MarkLiveCompletionUseCase — enforces canMarkLiveCompletion; throws TutorWriteForbiddenException on tutor session
- [ ] W4.35 (S, S3, pending)    permissionsProvider(session) Riverpod provider as single source of truth for UI affordances `[P6]`

---

## Wave 5 — Class cleanup + god-screen decomposition (~22 tasks)

### Phase 5a · God-screen decomposition (S5)
- [ ] W5.1  (L, S5, pending)    app_intro_screen.dart (1370 LOC) → IntroScaffold + IntroPageView + 3 page widgets + IntroPageIndicator + GlowingCtaButton
- [ ] W5.2  (L, S5, pending)    sign_in_screen.dart (1237 LOC) → SignInController:AsyncNotifier&lt;SignInState&gt; + SignInForm + SignInModeCard + SignInActions + EmailVerificationDialog
- [ ] W5.3  (L, S5, pending)    gamification_screen.dart (1127 LOC) → 11 private classes promoted to widgets/gamification/
- [ ] W5.4  (L, S5, pending)    profile_picker_screen.dart (1059 LOC) → ConsumerWidget + ProfileGrid + AddProfileDialog + segmented sections (tutored in W6.14)
- [ ] W5.5  (L, S5, pending)    onboarding_screen.dart (1030 LOC) → OnboardingPhaseRouter + per-phase step widgets + OnboardingResumeStore
- [ ] W5.6  (L, S5, pending)    reward_configuration_screen.dart (1004 LOC) → RewardConfigController:Notifier&lt;RewardForm&gt; + RewardCard + sub-widgets

### Phase 5b · Sealed-union state refactors
- [ ] W5.7  (M, S5, pending)    Replace 3-8 boolean state machines across feature screens → sealed unions
- [ ] W5.8  (M, S5, pending)    SyncOrchestrator state machine → sealed
- [ ] W5.9  (M, S5, pending)    OutboxProcessor _flushInProgress/_rerunRequested → sealed FlushState

### Phase 5c · Primitive obsession sweep
- [ ] W5.10 (M, S5, pending)    Profile mode literals (profile.mode == 'child') → ProfileMode enum across 20+ sites
- [ ] W5.11 (M, S5, pending)    Account tier literals (account.tier == 'cloudBorn') → AccountTier enum
- [ ] W5.12 (M, S5, pending)    Continue SefariaRef VO migration (started W4.1) across remaining sites
- [ ] W5.13 (S, S5, pending)    Ban literal-string mode/tier comparisons via make audit grep

### Phase 5d · Theme / visual cleanup
- [ ] W5.14 (M, S5, pending)    Move 525 0xFF…… colour literals from features/ → core/theme/app_colors.dart
- [ ] W5.15 (S, S5, pending)    Add custom lint to ban Color(0xFF…) outside core/theme/
- [ ] W5.16 (S, S5, pending)    Move hard-coded English strings in features/ to l10n/

### Phase 5e · Provider/global cleanup
- [ ] W5.17 (M, S5, pending)    Replace String activeDbFileName global → accountDbFileNameProvider:AsyncNotifier&lt;String&gt;; gate router on .when
- [ ] W5.18 (S, S5, pending)    Remove LearningProgramRepository.instance singleton; route via Riverpod
- [ ] W5.19 (S, S5, pending)    Replace 100+ direct DateTime.now() calls with clockProvider.now(); enable make audit grep #6

### Phase 5f · Naming + ConsumerWidget conversions
- [ ] W5.20 (M, S5, pending)    Rename *Service classes by intent: *Repository, *Gateway, *Notifier, *UseCase, *Renderer
- [ ] W5.21 (M, S5, pending)    Convert ~20 worst ConsumerStatefulWidget instances to ConsumerWidget + hooks/notifier

### Phase 5g · Decision-table replacements
- [ ] W5.22 (M, S5, pending)    Replace any remaining switch-over-strings → Map&lt;EnumKey, Handler&gt; registries

---

## Wave 6 — Tutor mode feature implementation (S3 · ~25 tasks)

### Phase 6a · Onboarding fork (FR-8)
- [ ] W6.1  (M, S3, pending)    Onboarding sign-up flow branches: "track my own learning" / "joining to tutor" / "skip for now"
- [ ] W6.2  (M, S3, pending)    Refactor AddTrackFlow from mandatory onboarding step → opt-in entry — **B2 picker bounds use ProgramStartingPosition.allowedWindow(today)**
- [ ] W6.3  (M, S3, pending)    "Skip for now" lands on near-empty dashboard with CTAs

### Phase 6b · Tutor PIN setup
- [ ] W6.4  (M, S3, pending)    Tutor PIN setup screen — triggered at tutor onboarding or first invite acceptance
- [ ] W6.5  (S, S3, pending)    Tutor PIN entry gate — prompted at every switch into a tutored profile
- [ ] W6.6  (S, S3, pending)    Tutor PIN reset flow via email verification

### Phase 6c · Invite flow
- [ ] W6.7  (M, S3, pending)    Invite tutor screen (parent): email input + copyable share-link + send button
- [ ] W6.8  (M, S3, pending)    Transactional email integration (Firebase Extension or SendGrid)
- [ ] W6.9  (M, S3, pending)    Accept invite deep-link flow: token validation + sign-up/sign-in if needed + grant activation
- [ ] W6.10 (S, S3, pending)    Decline pending invite flow

### Phase 6d · Management screens
- [ ] W6.11 (M, S3, pending)    Manage tutors screen (parent): per-child active list + pending list + revoke action + audit-log link
- [ ] W6.12 (M, S3, pending)    Manage my grants screen (tutor): list of tutored children + parent context + resign action
- [ ] W6.13 (M, S3, pending)    Audit log viewer (parent): filter by tutor / action / date range

### Phase 6e · Profile picker + indicators
- [ ] W6.14 (M, S3, pending)    Profile picker segmented "My children" + "Tutored children" sections from active-grant query
- [ ] W6.15 (S, S3, pending)    Subtle AppBar indicator (icon + colour accent) when viewing tutored child
- [ ] W6.16 (S, S3, pending)    Exit-to-my-profiles affordance in app shell

### Phase 6f · Boundary enforcement
- [ ] W6.17 (M, S3, pending)    Disable/hide "Mark complete" affordance when permissions.canMarkLiveCompletion == false
- [ ] W6.18 (S, S3, pending)    Tooltip: "Tutors cannot mark live completions" on disabled affordances
- [ ] W6.19 (M, S3, pending)    Wire MarkLiveCompletionUseCase throw → UI catches TutorWriteForbiddenException with friendly dialog

### Phase 6g · Audit log writing
- [ ] W6.20 (M, S3, pending)    Audit-log writer middleware: every tutor-originated mutation writes audit entry in same transaction
- [ ] W6.21 (S, S3, pending)    Capture tutor name snapshot at write-time (survives tutor account deletion)
- [ ] W6.22 (S, S3, pending)    Per-action audit entries for config_changed, completion_bulk_prior, completion_reset, bookmark_advanced, profile_edited, goal_changed, stage_changed, reward_changed, study_day_changed

### Phase 6h · Cascades + notifications
- [ ] W6.23 (M, S3, pending)    Parent-delete → all grants revoked + child profiles deleted (cascade extension)
- [ ] W6.24 (M, S3, pending)    Tutor-delete → all grants auto-resign; audit log preserves tutor name snapshot
- [ ] W6.25 (S, S3, pending)    Notify parent on tutor decline/resign; notify tutor on parent revoke

---

## Wave 7 — Exceptions + logging + telemetry + polish (~25 tasks)

### Phase 7a · Exception leaves (S5)
- [ ] W7.1  (M, S5, pending)    Re-parent all existing exception classes under the 5 category bases
- [ ] W7.2  (S, S5, pending)    Add new exceptions: MergeException, OutboxDeadLetterException, FirestorePermissionDeniedException
- [ ] W7.3  (S, S5, pending)    Move BatchPushException → core/sync/exceptions/sync_push_exception.dart under NetworkException
- [ ] W7.4  (S, S5, pending)    Rename InvalidOperationException → InvalidTrackOperationException; under ValidationException

### Phase 7b · Crisis-class telemetry (S2)
- [ ] W7.5  (M, S2, pending)    Wire merge_row_skipped event at silent skip sites in DriftMergeStore + ProfileProgramMerger — closes L2
- [ ] W7.6  (S, S2, pending)    Wire merge_router_halt event at pull_pipeline.dart halt site
- [ ] W7.7  (S, S2, pending)    Wire outbox_dead_lettered event at outbox_processor max-attempts
- [ ] W7.8  (S, S2, pending)    Wire listener_error event from ListenerSupervisor._onError callback
- [ ] W7.9  (S, S2, pending)    Wire sync_pull_started/completed/failed events at orchestrator boundaries
- [ ] W7.10 (S, S2, pending)    Wire permission_denied event from gateway typed FirestorePermissionDeniedException
- [ ] W7.11 (S, S2, pending)    Wire tutor-mode events: tutor_invite_*, tutor_grant_*, tutor_action_recorded, tutor_pin_set, tutor_live_mark_blocked; bulk_engagement_skipped, lifetime_achievement_skipped — **B1 regression telemetry**

### Phase 7c · Firebase Analytics + Crashlytics (S5)
- [ ] W7.12 (M, S5, pending)    Add firebase_analytics to pubspec.yaml
- [ ] W7.13 (M, S5, pending)    Create FirebaseAnalyticsService impl; LoggingAnalyticsService becomes fallback
- [ ] W7.14 (S, S5, pending)    Route runZonedGuarded errors to Crashlytics (currently Talker-only)
- [ ] W7.15 (S, S5, pending)    Fire crash_reported from recordFlutterFatalError
- [ ] W7.16 (S, S5, pending)    Route ListenerSupervisor._onError to Crashlytics non-fatal

### Phase 7d · Error UX (S5/S3/S1)
- [ ] W7.17 (M, S5, pending)    Create AppErrorView widget in core/widgets/ consuming AsyncValue.error → category-mapped UI
- [ ] W7.18 (M, S5, pending)    Migrate 20+ screens from errorWithMessage(e.toString()) to AppErrorView
- [ ] W7.19 (S, S3, pending)    Extend PiiRedactor.sensitiveKeys with displayName, firstName, lastName, city, lat, lon, deviceId, oauthCode, magicLinkUrl, tutor_email
- [ ] W7.20 (S, S1, pending)    Add lint no_e_to_string_in_ui (forbids e.toString() inside presentation/)
- [ ] W7.21 (S, S1, pending)    Add lint no_raw_logevent (forbids logEvent(name, …) outside analytics_service.dart)

### Phase 7e · Polish + final verify
- [ ] W7.22 (S, S1, pending)    Delete root Makefile; canonical is learning_tracker/Makefile
- [ ] W7.23 (S, S1, pending)    Update CLAUDE.md (any remaining stale references)
- [ ] W7.24 (M, S5, pending)    Bug-fix integration pass — verify B1, B2, B3 at their respective wave-appropriate sites
- [ ] W7.25 (M, S5, pending)    Final manual smoke across spot-on screens: EN + HE, single device + two-device sync (own + tutored); add Daf Yomi start_date=today−5, expect ~5 overdue tasks — **B3 verification** `[P7]`
