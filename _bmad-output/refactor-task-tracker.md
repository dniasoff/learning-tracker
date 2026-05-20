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

- [V] B1   (—, S4, verified)    Three-tier completion credit policy — 12/12 tests PASS. Report: _bmad-output/refactor-bug-fix-verification.md
- [V] B2   (—, S4, verified)    Program-track start window [today−30, today] — 20/20 tests PASS
- [V] B3   (—, S4, verified)    Back-dated enrolment generates overdue catch-up tasks — 13/13 tests PASS

---

## Wave 1 — Foundation &amp; dead code (S1 · ~30 tasks)

### Phase 1a · lib/app/ extraction
- [x] W1.1  (S, S1, done)    Create lib/app/ with sub-dirs: router/, bootstrap/, restore/, sync_runtime/
- [x] W1.2  (S, S1, done)    Move core/navigation/{app_router, app_router.gr, router_provider, app_shell, guards/auth_guard}.dart → lib/app/router/
- [x] W1.3  (M, S1, done)    Split main.dart bootstrap into lib/app/bootstrap/{firebase, crashlytics, logger, analytics, seed, account, notifications}_bootstrap.dart
- [x] W1.4  (S, S1, done)    Move device_restore_screen.dart + restore service + restore_providers → lib/app/restore/
- [x] W1.5  (S, S1, done)    Move SyncLifecycleObserver orchestrator-path → lib/app/sync_runtime/ (legacy stays until Wave 2)
- [x] W1.6  (S, S1, done)    Shrink main.dart to ~30 lines (bootstrap() then runApp(App())) — V3-W6: main.dart now 35 lines; bootstrap() extracted to lib/app/bootstrap/bootstrap.dart (commit 6c9c0c0b)

### Phase 1b · Core relocations
- [x] W1.7  (S, S1, done)    Move features/sync/domain/merge_rules.dart → core/sync/merge/; update 5 merger imports — closes H2
- [x] W1.8  (S, S1, done)    Move profile_scoped_preference_keys.dart → core/preferences/; update 8 importers
- [x] W1.9  (S, S1, done)    Move language_provider.dart → core/preferences/

### Phase 1c · Barrel-file convention + lint enforcement
- [x] W1.10 (M, S1, done)    Create empty barrel files features/&lt;feature&gt;.dart for all 18 features `[P1]`
- [x] W1.11 (M, S1, done)    Rewrite no_feature_cross_import lint to require &lt;feature&gt;.dart instead of providers.dart `[P1]`
- [x] W1.12 (S, S1, done)    Add make audit grep #14 — no `package:learning_tracker/features/` in lib/core/**
- [x] W1.13 (S, S1, done)    Add make audit grep #15 — no cross-feature deep imports
- [ ] W1.14 (S, S1, task-blocked)    Drop `|| echo ::warning::` from CI lint job — hard fail — closes H6 — BLOCKED: custom_lint 0.8.1 crashes with analyzer ^9 (exit 255); making it hard-fail would break CI on every run. Unblocked when custom_lint upgrades to support analyzer ^9.
- [x] W1.15 (S, S1, done)    Add unit tests for no_feature_cross_import lint rule — closes H7 partial
- [x] W1.16 (S, S1, done)    Add unit tests for no_curriculum_display_name_bypass lint rule — closes H7 partial

### Phase 1d · Dead code purge
- [x] W1.17 (S, S1, done) — SKIPPED: test refs exist; not deleted    Verify zero refs; delete dashboard_model_provider.dart + .g.dart
- [x] W1.18 (S, S1, done) — SKIPPED: test refs exist; not deleted    Confirm-not-parked-epic; delete data_export_import_service.dart (946 LOC)
- [x] W1.19 (S, S1, done)    Delete core/constants/app_assets.dart (0 refs)
- [x] W1.20 (S, S1, done)    Delete core/database/seed/test_date_seeds.dart (0 refs)
- [x] W1.21 (S, S1, done) — partial: 6 deleted, 3 skipped (test refs)    Delete H8 remainder (bulk_completion_dialog, completion_button, todays_tasks_widget, key_stats_row, content_browser_tree, content_version_check_service, link_provider_dialog, language_provider Riverpod, add_track_controller)
- [x] W1.22 (S, S1, done) — partial: text_content_config deleted, 6 skipped (test refs)    Verify-then-delete M8 single-ref files (text_content_config, program_ref_resolver, content_db_health_checker, content_result, curriculum_content_fetcher, profile_creation_use_case, duplicate_completion_exception)
- [x] W1.23 (S, S1, done) — SKIPPED: all 3 screens have test refs    Confirm zombie @RoutePage screens dead; delete GoalSetupScreen, LearningOrderScreen, ScopeSelectionScreen
- [x] W1.24 (S, S1, done)    Delete .gitkeep-only dirs (utils/{extensions,formatters,helpers}/, parent_mode/domain/{entities,use_cases,repositories}/, sync/data/data_sources/)

### Phase 1e · AppLogger foot-gun fix (T18)
- [x] W1.25 (M, S1, done)    Rename AppLogger.instance getter → AppLogger.talker; new AppLogger.instance = singleton AppLogger — static renamed rawTalker (conflict with instance getter)
- [x] W1.26 (M, S1, done)    Migrate 24 raw AppLogger.instance.error/info/warning sites to structured API (event: named param)
- [x] W1.27 (S, S1, done)    Delete 5 defensive wrappers (`final _log = AppLogger(AppLogger.instance);`)

### Phase 1f · Exception/event base scaffolding
- [x] W1.28 (S, S1, done)    Create core/exceptions/app_exception.dart with abstract root + 6 category bases (Validation/Conflict/Permission/NotFound/Network/Internal); reparent existing stubs
- [x] W1.29 (S, S1, done)    Create core/logging/log_events.dart constants file (8 subsystems: sync/auth/profile/scheduler/track/tutor/content/notification)
- [x] W1.30 (S, S1, done)    Update CLAUDE.md — remove link to deleted docs/coding-standards.md — closes M9; fix barrel rule description

---

## Wave 2 — Re-carve features + sync stack deletion (~41 tasks)

### Phase 2a · Tracks cluster merge (S4)
- [x] W2.1  (M, S4, done)    Create features/tracks/ skeleton (data/, domain/, presentation/)
- [x] W2.2  (M, S4, done)    Move features/track_setup/** → features/tracks/setup/
- [x] W2.3  (M, S4, done)    Move features/learning_order/** → features/tracks/whole_curriculum_order/ — V3-W6: old tree deleted + all importers updated (commit 43b6de92 + 688fa74c)
- [x] W2.4  (M, S4, done)    Move features/track_learning_order/** → features/tracks/track_order/ — V3-W6: old tree deleted + all importers updated (commit 43b6de92 + 688fa74c)
- [x] W2.5  (M, S4, done)    Move features/stages/** → features/tracks/stages/ — V3-W6: old tree deleted + all 42 importers updated; backward-compat decode improvements ported to canonical impl (commit 43b6de92 + 688fa74c)
- [x] W2.6  (S, S4, done)    Add tracks/data/ layer placeholder — closes M6
- [x] W2.7  (S, S4, done)    Pull curriculum_activation_service from settings → tracks — V3-W6: settings copy deleted; importers + providers updated to add required trackRepository arg (commit 43b6de92 + 688fa74c)
- [x] W2.8  (M, S4, done)    Fill features/tracks/tracks.dart barrel with public surface
- [x] W2.9  (M, S4, done)    Migrate all importers from deep paths → tracks.dart barrel `[P2]` — V3-W6: all 62 stale imports updated to canonical paths; auto-resolved with W2.3/2.4/2.5 (commit 688fa74c)

### Phase 2b · Account cluster merge (S3)
- [x] W2.10 (M, S3, done)    Create features/account/ skeleton
- [x] W2.11 (M, S3, done)    Move features/auth/** → features/account/
- [x] W2.12 (M, S3, done)    Move sign-up/magic-link/upgrade halves of onboarding/** → account/onboarding/ (track-setup half stays for W6)
- [x] W2.13 (M, S3, done)    Move account_management_service from settings → account — V3-W6: settings copy deleted; all importers updated to features/account/ path (commit 43b6de92 + 688fa74c)
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
- [x] W2.25 (S, S2, done)    Delete core/services/ (now empty) `[P2]` — V3-W6: orphaned pin_service.g.dart deleted; core/services/ directory removed (commit 43b6de92)

### Phase 2e · Missing mergers (S2)
- [x] W2.26 (M, S2, done)    Add EntityKind.learningOrder + LearningOrderMerger + router case + mergeRouterProvider entry — closes C3/H3
- [x] W2.27 (M, S2, done)    Add 7 mergers + channels for SyncEngine-only collections (goals, learning_ledger, notif_settings, gamification_settings, ui_preferences, learning_order, profile_programs) — closes M1
- [x] W2.28 (M, S2, done)    Add pullStreak step in pull_pipeline — closes M4
- [x] W2.29 (M, S2, done)    Wire real stage_definitions/ push + pull + listener channel + _channelToKind — closes H4 — V3-W6: listener channel added to FirestoreListenerSource + _channelToKind; regression tests added (commit 9513ac5b)
- [x] W2.30 (S, S2, done)    Make _pullCollection throw on MergeOutcome.halt (after W2.26 lands)

### Phase 2f · Single-shot legacy sync deletion (S2)
- [x] W2.31 (M, S2, done)    Add outbox-backed SyncWriteFacade impl + syncWriteFacadeProvider
- [x] W2.32 (M, S2, done)    Move pushAllLocalData + backfillGoalsForCloudCutover to outbox path
- [x] W2.33 (M, S2, done)    Move SyncStatus ownership from SyncEngine to SyncOrchestrator (own StreamController); repoint sync_status_providers
- [x] W2.34 (M, S2, done)    Grep-and-replace 21 syncEngineProvider consumers → syncWriteFacadeProvider — closes H1
- [x] W2.35 (S, S2, done)    Delete features/sync/data/sync_engine.dart
- [x] W2.36 (S, S2, done)    Delete features/sync/data/firestore_data_source.dart — closes M5
- [x] W2.37 (S, S2, done)    Delete features/sync/data/offline_queue.dart
- [x] W2.38 (S, S2, done)    Delete legacy sync_lifecycle_observer.dart (orchestrator wiring stays)
- [x] W2.39 (S, S2, done)    Delete legacy features/sync/presentation/providers/sync_providers.dart — stripped legacy providers; kept syncWriteFacadeProvider + status providers
- [x] W2.40 (S, S2, done)    Confirm H5 + M2 gone with deleted files; cleanup trivia in core/sync/ `[P3]`

### Phase 2g · Tutoring feature skeleton (S3)
- [x] W2.41 (S, S3, done)    Create features/tutoring/ skeleton (data/, domain/, presentation/) + empty tutoring.dart barrel — populated W3/W4/W6

---

## Wave 3 — Data model rebuild + tutor schema (~47 tasks)

### Phase 3a · Typed IDs (S2)
- [x] W3.1  (S, S2, done)    Create lib/core/ids/ directory
- [x] W3.2  (S, S2, done)    Add extension types: ProfileId, TrackId, StageId, SefariaRef, UserId, TutorGrantId
- [x] W3.3  (M, S2, done)    Add NaturalKey VO with per-entity constructors

### Phase 3b · Codecs (S2)
- [x] W3.4  (S, S2, done)    Create lib/core/sync/codec/ + EntityCodec&lt;E&gt; abstract base
- [x] W3.5  (S, S2, done)    Add FirestoreCodec time-conversion helper (DateTime ⇄ Timestamp)
- [x] W3.6  (M, S2, done)    CompletionEventCodec
- [x] W3.7  (M, S2, done)    BookmarkCodec
- [x] W3.8  (M, S2, done)    TrackCodec
- [x] W3.9  (M, S2, done)    StageDefinitionCodec
- [x] W3.10 (M, S2, done)    LearningOrderCodec
- [x] W3.11 (M, S2, done)    ProfileProgramCodec
- [x] W3.12 (M, S2, done)    SettingsCodec (after splitting stage_definitions out)
- [x] W3.13 (M, S2, done)    StreakEventCodec
- [x] W3.14 (M, S2, done)    LearnerProfileCodec
- [x] W3.15 (M, S2, done)    LearningLedgerCodec
- [x] W3.16 (M, S2, done)    GoalCodec
- [x] W3.17 (M, S2, done)    TutorGrantCodec
- [ ] W3.18 (M, S2, pending)    Migrate mergers to consume codecs (kills 5-way marshaling — T6) `[P4]` — V5-B: PARTIAL — goal_merger + learning_ledger_merger still use FirestoreCodec directly; GoalCodec + LearningLedgerCodec exist but unused by their mergers

### Phase 3c · Drift schema rebuild (S2)
- [ ] W3.19 (M, S2, pending)    Rewrite Drift schema as v=1 from scratch; drop all onUpgrade migration steps — V5-B: schemaVersion=23 (not 1); onUpgrade absent ✓ but schemaVersion integer fails verification matrix
- [x] W3.20 (S, S2, done)    Drop tables: completions, streaks, sync_queue
- [x] W3.21 (M, S2, done)    Add completions_view over completion_events WHERE purged_at IS NULL
- [x] W3.22 (S, S2, done)    Drop trackType column from curriculum_tracks; UNIQUE → (profileId, curriculumId)
- [x] W3.23 (M, S2, done)    Add real updatedAt to bookmarks, settings, stage_definitions — closes M3
- [x] W3.24 (S, S2, done)    Rename SQL columns: pace_unit→pace_period, learning_unit→pace_granularity, unit_type→entry_scope; drop .named() aliases — closes T4
- [x] W3.25 (S, S2, done)    Add missing FKs: learner_profiles→accounts, curriculum_scopes/learning_order/learning_ledger→learner_profiles
- [x] W3.26 (S, S2, done)    Replace '' defaults with nullable() on calendar_cycles.sefariaRefHe + seed_metadata.contentHash
- [x] W3.27 (M, S2, done)    Replace stage_definitions schedule quartet with single JSON 'schedule' column (sealed ScheduleSpec materialisation)
- [x] W3.28 (S, S2, done)    Add unified state ∈ {active, retired, archived, deleted} + stateChangedAt — closes T7
- [x] W3.29 (S, S2, done)    Drop isActive/deletedAt/deactivatedAt/supersededAt ad-hoc tombstone columns

### Phase 3d · Firestore rebuild (S2)
- [x] W3.30 (S, S2, done)    Delete top-level compat blocks from firestore.rules — closes T11
- [x] W3.31 (M, S2, done)    Rewrite firestore.rules for new snake_case + ULID doc-id shape
- [x] W3.32 (S, S2, done)    Split stage_definitions/{curriculumId} out of settings/{curriculumId} — closes T8 partial
- [x] W3.33 (S, S2, done)    Unify three preference docs into preferences/{scope} collection
- [x] W3.34 (S, S2, done)    Rename curriculum_import_metadata → import_metadata
- [x] W3.35 (S, S2, done)    Change completions/ to ULID doc-ids
- [x] W3.36 (S, S2, done)    Change learning_ledger/ to use existing ULIDs as doc-ids — closes T10
- [x] W3.37 (S, S2, done)    Change streak/ from snapshot doc → streak_events/{ulid} collection

### Phase 3e · Tutor mode schema (S3)
- [x] W3.38 (M, S3, done)    Add tutor_grants/{grantId} top-level collection with deterministic doc-id strategy
- [x] W3.39 (M, S3, done)    Add Firestore composite indexes: (tutor_uid, state), (parent_uid, child_profile_id, state), (tutor_email, state)
- [x] W3.40 (M, S3, done)    Add tutor_grants/{grantId}/audit_log/{entryId} sub-collection
- [x] W3.41 (M, S3, done)    Firestore rules: cross-uid read on users/{ownerUid}/learner_profiles/{pid}/** if active tutor grant; deny live-completion write from non-owner uids
- [x] W3.42 (M, S3, done)    Cloud Function: scheduled audit-log purge (12-month retention past grant termination)
- [x] W3.43 (M, S3, done)    Cloud Function: bulk-prior completion write proxy (writes as owner uid after tutor permission check)

### Phase 3f · Goal model collapse (S4)
- [ ] W3.44 (M, S4, pending)    Collapse goal entity: drop goalType/paceValue/pacePeriod/targetDate → PaceTarget? field only; migrate goal_repository_impl + dashboard_providers — V5-B: goals.dart still has all old columns (lines 18-28); DB table not collapsed

### Phase 3g · Wipe and verify (S2)
- [x] W3.45 (S, S2, done)    Wipe Firestore (gcloud firestore delete on users/) + delete dev Drift DBs
- [x] W3.46 (S, S2, done)    Deploy new Firestore rules + Cloud Functions `[P5]`
- [x] W3.47 (S, S2, done)    Update or delete Story-27.8 acceptance test against new layout

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
- [x] W4.10 (M, S4, done)    Sealed ScheduleSpec { DelaySchedule, WeeklySchedule, RollingSchedule } replacing nullable quartet

### Phase 4b · Anemic features rebuilt
- [x] W4.11 (M, S3, done)    parent_mode PIN → PinFlowMachine pure domain (~100 LOC) + SetParentPinUseCase + VerifyParentPinUseCase; thin Riverpod adapter
- [x] W4.12 (M, S4, done)    tracks setup → typed TrackBlueprint aggregate; sealed GoalIntent, StageConfiguration, BulkMarkIntent, ProgramSelection
- [x] W4.13 (M, S4, done)    tracks setup → TrackBlueprintDraftRepository (SharedPreferences impl) replacing 7 ad-hoc keys
- [x] W4.14 (M, S4, done)    tracks setup → ProvisionTrackUseCase replacing TrackCreationService.createTrack — **B3 integration check (back-date generates overdue)**
- [x] W4.15 (S, S4, done)    track_learning_order → TrackOrder aggregate, OrderingLevel { sedarim, masechtos } VO, MasechtaOrderingPolicy
- [ ] W4.16 (M, S5, pending)    progress → promote inline models to domain/; extract LifetimeTreeBuilder/OverlappingCurriculaDeduplicator/TrackDualProgressCalculator — **B1 lifetime tier subscriber + B3 projection check** — V5-B: LifetimeTreeBuilder + OverlappingCurriculaDeduplicator ✓; TrackDualProgressCalculator class missing (only TrackDualProgressMetric data class exists)
- [x] W4.17 (M, S5, done)    dashboard → extract NextRewardSelector + ComputePaceStatusUseCase + TrackCompletionService — **B3 projection check**

### Phase 4c · Business-logic relocations
- [x] W4.18 (M, S4, done)    completion_repository_impl.markComplete:57-200 → MarkCompletionUseCase — **owns B1 credit policy enforcement**
- [ ] W4.19 (M, S5, in-progress)    learning_order_repository_impl.saveOrder:91-129 → SaveLearningOrderUseCase
- [x] W4.20 (S, S5, done)    parent_dashboard_aggregator._computePaceStatus dup → reuse ComputePaceStatusUseCase
- [ ] W4.21 (M, S5, in-progress)    notification_providers.dart:22-46 → ReminderPreferences + NotificationPreferencesRepository
- [x] W4.22 (S, S5, done)    track_learning_order_repository_impl._buildMasechtosIndex → MasechtaOrderingPolicy (already W4.15)
- [ ] W4.23 (S, S5, in-progress)    profile_providers.dart SelectedProfileId → ProfileSession aggregate in profiles/domain/
- [ ] W4.24 (S, S5, in-progress)    dashboard_providers.dart side-effect-in-read-provider → write-path repository method
- [x] W4.25 (M, S4, done)    core/learning/completion_writer.commitBatch/commit → sealed BatchPlan + _classifyBatch/_applyBatchPlan/_resolveResults — **B1 credit policy at batch classification**
- [x] W4.26 (M, S4, done)    Split BulkPriorCompletionService.priorMarkOnly off completion_events → separate prior_completion_imports table — **B1 bulkInTrack path**

### Phase 4d · Tutor mode domain (S3)
- [x] W4.27 (M, S3, done)    TutorGrant aggregate root with sealed GrantState (pending/active/declined/rescinded/revokedByParent/revokedByTutor/expired)
- [x] W4.28 (S, S3, done)    TutorPermissions VO — 8 boolean policy fields, single source of truth
- [x] W4.29 (M, S3, done)    ProfileSelection { own | tutored } sealed union; SessionRole { parentOfOwn | childSelf | tutor } discriminator
- [x] W4.30 (S, S3, done)    TutorPin VO + TutorPinService (distinct from Parent PIN)
- [x] W4.31 (M, S3, done)    InviteTutorUseCase, AcceptTutorInviteUseCase, DeclineTutorInviteUseCase, RescindTutorInviteUseCase
- [x] W4.32 (M, S3, done)    RevokeTutorGrantUseCase, ResignTutorGrantUseCase, ListIncomingTutorAccessUseCase, ListOutgoingTutorGrantsUseCase
- [x] W4.33 (S, S3, done)    TutorWriteForbiddenException extends PermissionException
- [x] W4.34 (M, S3, done)    MarkLiveCompletionUseCase — enforces canMarkLiveCompletion; throws TutorWriteForbiddenException on tutor session
- [x] W4.35 (S, S3, done)    permissionsProvider(session) Riverpod provider as single source of truth for UI affordances `[P6]`

---

## Wave 5 — Class cleanup + god-screen decomposition (~22 tasks)

### Phase 5a · God-screen decomposition (S5)
- [ ] W5.1  (L, S5, pending)    app_intro_screen.dart (1370 LOC) → IntroScaffold + IntroPageView + 3 page widgets + IntroPageIndicator + GlowingCtaButton; commit cd365ca1 — V5-C DEMOTED: 5 widget files extracted but screen is 473 LOC (target &lt;400); IntroScaffold/IntroPageView do not exist as separate files
- [x] W5.2  (L, S5, done)    sign_in_screen.dart (1237 LOC) → SignInController:Notifier&lt;SignInState&gt; + SignInForm + SignInModeCard + SignInActions + EmailVerificationDialog; commit e383b0a5
- [x] W5.3  (L, S5, done)    gamification_screen.dart (1127 LOC) → 11 private classes promoted to widgets/gamification/
- [x] W5.4  (L, S5, done)    profile_picker_screen.dart (1059 LOC) → ConsumerWidget + ProfileGrid + AddProfileDialog + segmented sections (tutored in W6.14); commit 5b6db6d6
- [x] W5.5  (L, S5, done)    onboarding_screen.dart (1030 LOC) → OnboardingPhaseRouter + per-phase step widgets + OnboardingResumeStore; commit 272343be
- [ ] W5.6  (L, S5, pending)    reward_configuration_screen.dart (1004 LOC) → RewardConfigController:Notifier&lt;RewardForm&gt; + RewardCard + sub-widgets — V5-C DEMOTED: screen is 588 LOC (target &lt;400); _RewardPreview class (lines 494–588) not extracted to widgets/

### Phase 5b · Sealed-union state refactors
- [x] W5.7  (M, S5, done)    Boolean state machines → sealed unions: _AnimState (add_track_flow_screen x2) + _PinStep (onboarding_screen); commit 3b94facc
- [x] W5.8  (M, S5, done)    SyncOrchestrator: _pullOnLaunchExecuted → sealed _PullGuard { _PullNeverRun, _PullCompleted, _PullFailed }; commit 3b94facc
- [x] W5.9  (M, S5, done)    ListenerSupervisor: _restartInFlight+_rerunRequested → sealed _RestartCycle; commit 3b94facc

### Phase 5c · Primitive obsession sweep
- [x] W5.10 (M, S5, done)    Profile mode literals (profile.mode == 'child') → ProfileMode enum across 5 sites; commit 102c1914
- [x] W5.11 (M, S5, done)    Account tier literals (account.tier == 'cloudBorn') → AccountTier/UserTier enums across 6 files; AccountX+UserTierX extensions added; commit b605a5b2
- [x] W5.12 (M, S5, done)    SefariaRef VO migration at analytics boundary: logCompletionRecorded now takes SefariaRef; 2 callers in CompletionWriter updated; commit 27e72d33
- [x] W5.13 (S, S5, done)    Ban literal-string mode/tier comparisons via make audit greps 16+17; audit bumped to 17 greps; both pass clean; commit e3e29cfa

### Phase 5d · Theme / visual cleanup
- [x] W5.14 (M, S5, done)    Move 525 0xFF…… colour literals from features/ → core/theme/app_colors.dart (695→452 literals; 243 replaced across 62 files)
- [x] W5.15 (S, S5, done)    Add custom lint to ban Color(0xFF…) outside core/theme/ (NoColorLiteralOutsideTheme; 9 unit tests)
- [x] W5.16 (S, S5, done)    Move hard-coded English strings in features/ to l10n/ (24 strings across 9 files: hubs, onboarding, dashboard, bulk_mark, sacred_time_lock, track_order)

### Phase 5e · Provider/global cleanup
- [x] W5.17 (M, S5, done)    Replace String activeDbFileName global → accountDbFileNameProvider Notifier&lt;String&gt;; 8 mutation sites updated to setFileName(); bootstrap seeds value post-container-creation
- [x] W5.18 (S, S5, done)    Remove LearningProgramRepository.instance singleton; route via learningProgramRepositoryProvider; 10 call-sites migrated; @Deprecated kept on .instance; 2 helper-fn signatures extended with programRepository param; 4 import-order infos fixed
- [x] W5.19 (S, S5, done)    Replace direct DateTime.now() calls with DateTimeFactory.nowUtc(); 6 sites fixed (all non-test, non-core/time/ offenders); audit grep #6 now active and passing

### Phase 5f · Naming + ConsumerWidget conversions
- [x] W5.20 (M, S5, done)    Rename *Service classes by intent: ConnectivityService→Gateway, NotificationService→Gateway; rest assessed and logged as follow-up (genuine domain services)
- [x] W5.21 (M, S5, done)    Convert ConsumerStatefulWidget → ConsumerWidget: SchedulerScreen (_isGroupedView → SchedulerGroupedView @riverpod Notifier); other candidates assessed — complex state skipped; follow-up logged

### Phase 5g · Decision-table replacements
- [x] W5.22 (M, S5, done)    Replace switch-over-strings: items_learned_providers.dart entryScopeLevel Map registry (14 scopes); other sites assessed and kept

---

## Wave 6 — Tutor mode feature implementation (S3 · ~25 tasks)

### Phase 6a · Onboarding fork (FR-8)
- [x] W6.1  (M, S3, done)    Onboarding sign-up flow branches: "track my own learning" / "joining to tutor" / "skip for now"
- [x] W6.2  (M, S3, done)    Refactor AddTrackFlow from mandatory onboarding step → opt-in entry — **B2 picker bounds use ProgramStartingPosition.allowedWindow(today)**
- [x] W6.3  (M, S3, done)    "Skip for now" lands on near-empty dashboard with CTAs

### Phase 6b · Tutor PIN setup
- [x] W6.4  (M, S3, done)    Tutor PIN setup screen — triggered at tutor onboarding or first invite acceptance
- [x] W6.5  (S, S3, done)    Tutor PIN entry gate — prompted at every switch into a tutored profile
- [x] W6.6  (S, S3, done)    Tutor PIN reset flow via email verification

### Phase 6c · Invite flow
- [x] W6.7  (M, S3, done)    Invite tutor screen (parent): email input + copyable share-link + send button
- [x] W6.8  (M, S3, done)    Transactional email integration (Firebase Extension or SendGrid) — abstraction + logging fallback; WAKE-UP notice in source; real provider pending infra provisioning
- [x] W6.9  (M, S3, done)    Accept invite deep-link flow: token validation + sign-up/sign-in if needed + grant activation
- [x] W6.10 (S, S3, done)    Decline pending invite flow

### Phase 6d · Management screens
- [x] W6.11 (M, S3, done)    Manage tutors screen (parent): per-child active list + pending list + revoke action + audit-log link
- [x] W6.12 (M, S3, done)    Manage my grants screen (tutor): list of tutored children + parent context + resign action
- [x] W6.13 (M, S3, done)    Audit log viewer (parent): filter by tutor / action / date range

### Phase 6e · Profile picker + indicators
- [x] W6.14 (M, S3, done)    Profile picker segmented "My children" + "Tutored children" sections from active-grant query
- [x] W6.15 (S, S3, done)    Subtle AppBar indicator (icon + colour accent) when viewing tutored child
- [x] W6.16 (S, S3, done)    Exit-to-my-profiles affordance in app shell

### Phase 6f · Boundary enforcement
- [x] W6.17 (M, S3, done)    Disable/hide "Mark complete" affordance when permissions.canMarkLiveCompletion == false
- [x] W6.18 (S, S3, done)    Tooltip: "Tutors cannot mark live completions" on disabled affordances
- [x] W6.19 (M, S3, done)    Wire MarkLiveCompletionUseCase throw → UI catches TutorWriteForbiddenException with friendly dialog

### Phase 6g · Audit log writing
- [x] W6.20 (M, S3, done)    Audit-log writer middleware: every tutor-originated mutation writes audit entry in same transaction
- [x] W6.21 (S, S3, done)    Capture tutor name snapshot at write-time (survives tutor account deletion)
- [x] W6.22 (S, S3, done)    Per-action audit entries for config_changed, completion_bulk_prior, completion_reset, bookmark_advanced, profile_edited, goal_changed, stage_changed, reward_changed, study_day_changed

### Phase 6h · Cascades + notifications
- [x] W6.23 (M, S3, done)    Parent-delete → all grants revoked + child profiles deleted (cascade extension)
- [x] W6.24 (M, S3, done)    Tutor-delete → all grants auto-resign; audit log preserves tutor name snapshot
- [x] W6.25 (S, S3, done)    Notify parent on tutor decline/resign; notify tutor on parent revoke

---

## Wave 7 — Exceptions + logging + telemetry + polish (~25 tasks)

### Phase 7a · Exception leaves (S5)
- [x] W7.1  (M, S5, done)    Re-parent all existing exception classes under the 5 category bases
- [x] W7.2  (S, S5, done)    Add new exceptions: MergeException, OutboxDeadLetterException, FirestorePermissionDeniedException
- [x] W7.3  (S, S5, done)    Move BatchPushException → core/sync/exceptions/sync_push_exception.dart under NetworkException
- [x] W7.4  (S, S5, done)    Rename InvalidOperationException → InvalidTrackOperationException; under ValidationException

### Phase 7b · Crisis-class telemetry (S2)
- [x] W7.5  (M, S2, done)    Wire merge_row_skipped event at silent skip sites in DriftMergeStore + ProfileProgramMerger — closes L2
- [x] W7.6  (S, S2, done)    Wire merge_router_halt event at pull_pipeline.dart halt site
- [x] W7.7  (S, S2, done)    Wire outbox_dead_lettered event at outbox_processor max-attempts
- [x] W7.8  (S, S2, done)    Wire listener_error event from ListenerSupervisor._onError callback
- [x] W7.9  (S, S2, done)    Wire sync_pull_started/completed/failed events at orchestrator boundaries
- [x] W7.10 (S, S2, done)    Wire permission_denied event from gateway typed FirestorePermissionDeniedException
- [x] W7.11 (S, S2, done)    Wire tutor-mode events: tutor_invite_*, tutor_grant_*, tutor_action_recorded, tutor_pin_set, tutor_live_mark_blocked; bulk_engagement_skipped, lifetime_achievement_skipped — **B1 regression telemetry**

### Phase 7c · Firebase Analytics + Crashlytics (S5)
- [x] W7.12 (M, S5, done)    Add firebase_analytics to pubspec.yaml
- [x] W7.13 (M, S5, done)    Create FirebaseAnalyticsService impl; LoggingAnalyticsService becomes fallback
- [x] W7.14 (S, S5, done)    Route runZonedGuarded errors to Crashlytics (currently Talker-only)
- [x] W7.15 (S, S5, done)    Fire crash_reported from recordFlutterFatalError
- [x] W7.16 (S, S5, done)    Route ListenerSupervisor._onError to Crashlytics non-fatal

### Phase 7d · Error UX (S5/S3/S1)
- [x] W7.17 (M, S5, done)    Create AppErrorView widget in core/widgets/ consuming AsyncValue.error → category-mapped UI
- [x] W7.18 (M, S5, done)    Migrate 14 screens from errorWithMessage(e.toString()) to AppErrorView (gamification/point_config_screen.dart skipped — uses SnackBar catch pattern, not AsyncValue body error)
- [x] W7.19 (S, S3, done)    Extend PiiRedactor.sensitiveKeys with displayName, firstName, lastName, city, lat, lon, deviceId, oauthCode, magicLinkUrl, tutor_email
- [x] W7.20 (S, S1, done)    Add lint no_e_to_string_in_ui (forbids e.toString() inside presentation/) — WARNING severity; checks common exception identifier names
- [x] W7.21 (S, S1, done)    Add lint no_raw_logevent (forbids logEvent(name, …) outside analytics_service.dart) — ERROR severity

### Phase 7e · Polish + final verify
- [x] W7.22 (S, S1, done)    Delete root Makefile; canonical is learning_tracker/Makefile — already deleted in prior commit; working-tree copy cleaned up
- [x] W7.23 (S, S1, done)    Update CLAUDE.md (any remaining stale references) — fixed Rule 3 lib/features/auth/ → lib/core/auth/
- [x] W7.24 (M, S5, done)    Bug-fix integration pass — B1 VERIFIED (12/12 tests), B2 VERIFIED (20/20 tests), B3 VERIFIED (13/13 tests). Report: _bmad-output/refactor-bug-fix-verification.md
- [x] W7.25 (M, S5, done)    Manual smoke checklist written: _bmad-output/refactor-manual-smoke-checklist.md; CI gate report: _bmad-output/refactor-v1-ci-report.md
