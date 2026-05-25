# Tech-Debt & Architecture Remediation Plan (v3.3)

**Date:** 2026-05-20
**Status:** **Finalised** — task-broken-down, bug fixes integrated, parallel squad model overlaid, awaiting execution sign-off
**Supersedes:** v3.2 (earlier today). v3.3 overlays 5 concurrent execution streams on the wave structure with explicit synchronization points, critical path, and compressed wall-clock estimate.
**Branch:** dev
**Execution mode:** **Single continuous sitting**, executed by a **parallel squad of ~5 streams** where dependencies allow. Streams run concurrently; explicit synchronization points (P1-P7 below) coordinate handoffs. The wave structure remains the logical grouping; streams are an orthogonal ownership overlay over ~215 discrete tasks.

---

## Executive summary

Four facts anchor execution:

1. **No live users — no migration safety required.** Drift `DROP TABLE` + rebuild, Firestore wipe, collection renames all acceptable.

2. **Single-sitting wave execution — no safety-net prerequisite.** Tests land *alongside* each task, not in front of it. The sequence runs as one continuous push, top-to-bottom.

3. **Tutor mode is in scope.** Data model and Firestore rules absorb the M:N tutor permission graph natively in Wave 3; domain modelling adds `TutorGrant` + `TutorPermissions` + `SessionRole` in Wave 4; user-facing implementation (invite, accept, manage, audit-log viewer, Tutor PIN, profile picker integration) is Wave 6. Full spec: `docs/planning/tutor-mode-brief.md`.

4. **The unfinished sync cutover is the load-bearing root cause** of the existing quality crisis. v3 collapses v2's cautious six-phase A-track into a single coordinated Wave 2: delete the legacy stack, fill the merger gaps, repoint consumers, ship.

> **Total scope:** 7 waves · ~215 discrete tasks · ~6-8 weeks of focused single-developer work · one continuous sitting.

---

## Constraints

| Concern | Position |
|---|---|
| User data preservation | **Not required** — no live users |
| Migration windows | **Not required** |
| Backwards-compat shims | **Not required** |
| Cutover phasing | **Not required** — single coordinated cutover |
| Safety-net before refactor | **Not required** — tests land per-task |
| Commit hygiene | **Still applies** — small commits per task |
| Behaviour preservation | **Current screens are the spec** (couple of known minor bugs are bugs — fix; everything else stays observably the same) |
| Branch | `dev` only |

---

## Parallel squad execution model

The wave structure is the *logical* decomposition (W1→W7). For squad execution, **overlay 5 concurrent ownership streams** onto it. Wall-clock estimate compresses from ~30-42 dev-days (single-dev sequential) to **~12-15 working days (~2.5-3 weeks)** with 5 parallel devs, or **~5-8 working days (~1-1.5 weeks)** with a 5-agent parallel AI squad coordinated by an orchestrator.

### Stream definitions

| Stream | Lead concern | Approx scope |
|---|---|---:|
| **S1 — Foundation** | App-layer extraction, barrel files, lint enforcement, dead-code purge, AppLogger foot-gun fix, exception/event scaffolding | ~30 tasks · 3-4 d (1 dev) |
| **S2 — Sync & Data** | Missing mergers, single-shot legacy sync deletion, typed IDs, codecs, Drift+Firestore schema rebuild, crisis telemetry | ~57 tasks · 9-12 d (1 dev) — **critical-path stream** |
| **S3 — Account, Profile, Tutor** | Account cluster carving, dissolve parent_mode, tutor schema, tutor mode domain, full tutor mode UI, onboarding fork (FR-8) | ~50 tasks · 8-11 d (1 dev) |
| **S4 — Tracks & Completion** | Tracks cluster carving (4 features merged), tracks-setup rebuild (TrackBlueprint), completion use cases incl. B1 credit policy, ProgramStartingPosition VO incl. B2+B3 | ~32 tasks · 8-10 d (1 dev) |
| **S5 — Domain VOs, Class cleanup, Polish** | Cross-cutting VO rollout, god-screen splits (6 screens), progress + dashboard domain extraction, exception leaves, error UX, Firebase Analytics, final smoke | ~50 tasks · 8-10 d (1 dev) |

### Stream task assignments

**S1 — Foundation**
- All of Wave 1 (W1.1-W1.30)
- W7.20, W7.21 (new lint rules: `no_e_to_string_in_ui`, `no_raw_logevent`)
- W7.22 (delete root Makefile) · W7.23 (CLAUDE.md cleanup)

**S2 — Sync & Data**
- W2.21-W2.25 (core/learning, core/streak, core/services promotions)
- W2.26-W2.30 (missing mergers — closes C3 / H3 / H4 / M1 / M4)
- W2.31-W2.40 (outbox-backed SyncWriteFacade + atomic legacy sync deletion — closes C1 / C2 / H1 / M5)
- W3.1-W3.18 (typed IDs + all codecs — closes T1 / T2 / T3 / T6 / T16)
- W3.19-W3.29 (Drift schema rebuild — closes M3 / T4 / T7 / T9)
- W3.30-W3.37 (Firestore rebuild — closes T8 / T10 / T11)
- W3.45-W3.47 (wipe + verify)
- W7.5-W7.11 (crisis telemetry — closes L2)

**S3 — Account, Profile, Tutor**
- W2.10-W2.15 (account cluster carving)
- W2.16-W2.20 (dissolve parent_mode)
- W2.41 (tutoring feature skeleton)
- W3.38-W3.43 (tutor schema + Cloud Functions, incl. bulk-prior proxy for B1)
- W4.11 (PIN flow domain — `PinFlowMachine`)
- W4.27-W4.35 (tutor mode domain — `TutorGrant`, `TutorPermissions`, `MarkLiveCompletionUseCase`)
- W6.1-W6.25 (tutor mode UI end-to-end — FR-1 through FR-8 incl. onboarding fork)
- W7.19 (PII redaction extended for `tutor_email`)

**S4 — Tracks & Completion**
- W2.1-W2.9 (tracks cluster — merges track_setup + learning_order + track_learning_order + stages)
- W4.6 (PaceTarget sealed VO)
- W4.7 (ProgramStartingPosition VO — **owns B2 + B3 window enforcement**)
- W4.10 (sealed `ScheduleSpec`)
- W4.12-W4.15 (tracks-setup rebuild — `TrackBlueprint` aggregate, draft repository, `ProvisionTrackUseCase`, `TrackOrder`)
- W4.18 (`MarkCompletionUseCase` — **owns B1 three-tier credit policy enforcement**)
- W4.25 (`completion_writer` refactor — credit policy at batch-plan classification)
- W4.26 (`BulkPriorCompletionService` split — confirms credit policy through bulk path)
- W3.44 (goal model collapse — `PaceTarget` sole representation)

**S5 — Domain VOs, Class cleanup, Polish**
- W4.1-W4.5 (SefariaRef, StageOrder, Pin, StudyDayPattern, CalendarSystem)
- W4.8-W4.9 (Scope VO, ProfileMode/AccountTier enums)
- W4.16 (progress domain extraction — **incl. `LifetimeTreeBuilder` which is the lifetime-tier handler for B1**)
- W4.17 (dashboard domain extraction)
- W4.19-W4.24 (misc business-logic relocations)
- W5.1-W5.6 (six god-screen splits in parallel — they share no state, fully concurrent within S5)
- W5.7-W5.22 (sealed unions, primitive obsession sweep, theme cleanup, provider cleanup, naming pass)
- W7.1-W7.4 (exception leaves re-parenting)
- W7.12-W7.18 (Firebase Analytics, Crashlytics gap-fills, `AppErrorView` migration)
- W7.24 (bug-fix integration verification pass)
- W7.25 (final manual smoke — incl. B3 back-dated Daf Yomi catch-up check)

### Synchronization points (P1-P7)

| Point | What synchronizes | Approx wall-clock day | Streams gated |
|---|---|---|---|
| **P1** | Barrel files exist + lint rule active | ~day 1 | S2/S3/S4/S5 wait for this to start their `<feature>.dart` work |
| **P2** | All cluster carving complete (S2's core promotions + S3 account + S4 tracks) | ~day 3-5 | S2's atomic sync deletion (W2.31-40) waits for this so all `syncEngineProvider` consumers are in their final locations |
| **P3** | Legacy sync stack deleted | ~day 5-7 | All sync writes route through `SyncWriteFacade`; gates Drift wipe |
| **P4** | Typed IDs + codecs published | ~day 6-8 | S3/S4/S5 wait for `lib/core/ids/` + `lib/core/sync/codec/` before applying VOs broadly |
| **P5** | Schema + Cloud Functions deployed | ~day 8-10 | S3's tutor UI (W6) can start; S5 begins domain VO rollout across data layer |
| **P6** | Domain layer landed | ~day 10-12 | S3 tutor UI completes; S5 begins god-screen splits + W7 polish |
| **P7** | Final manual smoke | ~day 12-15 | All streams converge for end-to-end validation incl. B3 catch-up verification |

### Critical path

The strict sequence — anything else runs in parallel around it:

```
W1.10 (barrel files exist)                                                    [day 1]
  ↓
W2 cluster carving (S2 promotions + S3 account + S4 tracks IN PARALLEL)       [day 2-4]
  ↓ ← P2: cluster done
W2.31-40 single-shot sync deletion (S2)                                       [day 5-6]
  ↓ ← P3: legacy gone
W3.1-18 typed IDs + codecs (S2)                                               [day 6-8]
  ↓ ← P4: types published
W3.19-43 Drift + Firestore + tutor schema (S2 + S3 IN PARALLEL)               [day 8-10]
  ↓ ← P5: schema deployed
W3.45-47 wipe + verify (S2)                                                   [day 10]
  ↓
W4 domain modelling (S3 + S4 + S5 IN PARALLEL)                                [day 10-12]
  ↓ ← P6: domain landed
W6 tutor UI (S3) + W5 class cleanup (S5) IN PARALLEL                          [day 12-14]
  ↓
W7 polish (S5) + manual smoke (all streams)                                   [day 14-15]
```

Critical path length: **~12-15 working days wall-clock**. Non-critical streams (S1, parts of S5) finish earlier and pivot to picking up tail work or supporting other streams as integration assistants.

### Squad-execution considerations

- **Merge-conflict surface** is highest at:
  - Cluster carving (W2) — *each stream commits to its own subdirectory tree only* to minimise collisions
  - Cross-cutting VO rollout (W4-W5) — *coordinate the SefariaRef migration as a single-developer pass* even if S5 owns it, since 73 files touched
  - Files like `main.dart`, `pubspec.yaml`, `firestore.rules`, `Makefile` — *one stream owns each*, others request edits via same-day handoff
- **Per-stream branch policy:** all on `dev` (per project convention — no feature branches). Rebase frequently; expect to resolve trivial conflicts daily.
- **Per-task commit hygiene** still applies — each `W<n>.<seq>` is one or two commits with its regression test.
- **Code review** can be peer across streams; no separate review stream needed. Self-review acceptable for S/M tasks; L tasks (god screens) warrant peer review.
- **Integration:** nightly merge / morning sync between streams; verify CI green before each P-point.
- **AI agent squad:** with no human coordination latency, parallelism is even higher. ~5-8 working days wall-clock with a 5-agent parallel squad + orchestrator. Each S<n> becomes an agent; orchestrator drives the P-point synchronizations.

---

## Findings — consolidated (informational; addressed by the waves below)

### From v1

**CRITICAL** · C1 Two sync stacks running, 5 collections double-listened · C2 Orchestrator hard-depends on legacy `SyncEngine` · C3 `pullLearningOrder` silently halts · C4 Rule 2 unsatisfiable — 0 facades, 355 cross-feature deep imports · C5 Rule 1 broken — 80+ `core/→features/` imports.

**HIGH** · H1 `SyncEngine` sole `SyncWriteFacade` impl · H2 5 core mergers import legacy merge_rules · H3 Learning-order multi-device sync only works via duplicate-stack bug · H4 `StageDefinitionMerger` dead on pull · H5 `curriculum_imports` typo → PERMISSION_DENIED · H6 CI doesn't fail on layering · H7 custom_lint disabled in-IDE · H8 ~12 dead files.

**MEDIUM** · M1 7 collections only `SyncEngine` covers · M2 `appendEvent` 4-col vs 5-col UNIQUE · M3 Bookmark/Settings/StageDef LWW is last-pull-wins · M4 No `pullStreak` · M5 `FirestoreDataSource` dead-weight · M6 `track_setup` missing `data/` · M7 Anemic domains · M8 ~7 likely-dead single-ref core files · M9 Stale `CLAUDE.md` link.

**LOW** · Dead `pullOnLaunch` guard · No skip-row telemetry · `.gitkeep`-only dirs · 9 screens >800 LOC · `LearningOrderScreen` route possibly dead.

### From v2 — cross-cutting themes (T1-T24)

5 timestamp encodings · 2 field-naming dialects · live legacy field names · Drift `.named()` aliases · no typed IDs · marshaling duplicated 5× per entity · 5 tombstone strategies · `settings/{curriculumId}` cesspool doc · two parallel queues · `learning_ledger` auto-id ignoring ULID · top-level Firestore compat blocks pinned only by a test · primitive obsession · business logic in presentation/data · implicit state machines via booleans · global mutable singletons · 451 `as` casts · invariants enforced in wrong layer · `AppLogger.instance` returns raw `Talker` · 20+ screens render raw `e.toString()` · `firebase_analytics` not in pubspec · story-acceptance tests dead weight · 31 untested screens · 0 golden tests · feature carving wrong (18 → 11) · core/feature misfiles.

### Tutor mode requirements (full brief at `docs/planning/tutor-mode-brief.md`)

FR-1 M:N tutors↔children, only creator-parent invites, single account = parent+tutor · FR-2 Two-phase invite (email + share-link, transactional email), tutor must have account, open-ended grants, 7d pending expiry, decline + resign · FR-3 Tutor inherits parent perms except cannot create live forward completions that credit streak/rewards · FR-4 Child sees tutor list; parent sees per-action audit log; tutors siloed · FR-5 Tutor PIN (NEW, separate from Parent PIN), set during tutor onboarding · FR-6 Subtle AppBar indicator · FR-7 Deletion cascades · FR-8 Onboarding MUST support "skip track setup" path.

---

## Proposed designs (summary)

Detailed designs from v2/v3 carry forward unchanged. Quick map:

- **Data model** — Extension-type IDs (`ProfileId`, `TrackId`, `StageId`, `SefariaRef`, `UserId`, `TutorGrantId`) at `core/ids/`. One codec per entity at `core/sync/codec/`. Drift 26→19 tables. Firestore 17+6→13 collections (snake_case, ULID doc-ids, unified preferences, split stage_definitions out of settings, rename curriculum_import_metadata → import_metadata). New `tutor_grants` + audit_log sub-collection. Unified tombstone via `state` lifecycle. `FirestoreCodec` for `DateTime ⇄ Timestamp`.
- **Domain** — VOs (SefariaRef, StageOrder, Pin, StudyDayPattern, CalendarSystem, PaceTarget, ProgramStartingPosition, Scope). Sealed `ScheduleSpec`. Anemic features rebuilt. Tutor: `TutorGrant` aggregate, `GrantState` sealed, `TutorPermissions` VO, `ProfileSelection { own | tutored }`, `SessionRole { parent/child/tutor }`. `MarkLiveCompletionUseCase` enforces the single invariant.
- **Module structure** — 18 → 11 features. New `lib/app/` composition root. New `features/tutoring/`. Single-barrel `<feature>.dart` (not `providers.dart`).
- **Exceptions** — `AppException` root, 5 category bases (Validation/Conflict/Permission/NotFound/Network/Internal). `TutorWriteForbiddenException` extends `PermissionException`.
- **Logging & telemetry** — Fix `AppLogger.instance` foot-gun. `<subsystem>_<action>` event naming. `firebase_analytics` real backend. Crisis-class telemetry: merge_row_skipped, merge_router_halt, outbox_dead_lettered, listener_error, sync_pull_*, permission_denied. Tutor events: tutor_invite_*, tutor_grant_*, tutor_action_recorded, tutor_pin_set, tutor_live_mark_blocked.
- **Class & function conventions** — 11 patterns enforced; god-screen decomposition (6 screens); ConsumerStatefulWidget→ConsumerWidget where state is trivial; theme literals in `core/theme/` only.
- **Tutor mode UI** — invite, accept, manage (parent + tutor sides), audit log viewer, Tutor PIN setup, profile picker segmentation, subtle AppBar indicator, mark-complete affordance gating.

---

## Execution waves — task-broken-down

Sizing key: **S** = ≤30 min commit · **M** = 30 min – 2 hr · **L** = half-day to full-day (mostly the god-screen splits).
Format: `□ W<n>.<seq> (size) Task description — closes <finding> [if any]`.

### Wave 1 — Foundation & dead code (~3-4 days; ~30 tasks)

Pure scaffolding; doesn't touch sync runtime; doesn't change observable behaviour. The base layer everything else lands on.

```
Phase 1a · lib/app/ extraction
□ W1.1  (S) Create lib/app/ with sub-dirs: router/, bootstrap/, restore/, sync_runtime/
□ W1.2  (S) Move core/navigation/{app_router, app_router.gr, router_provider, app_shell, guards/auth_guard}.dart → lib/app/router/
□ W1.3  (M) Split main.dart bootstrap into lib/app/bootstrap/{firebase, crashlytics, logger, analytics, seed, account, notifications}_bootstrap.dart
□ W1.4  (S) Move features/sync/presentation/screens/device_restore_screen.dart + restore service + restore_providers → lib/app/restore/
□ W1.5  (S) Move SyncLifecycleObserver orchestrator-path → lib/app/sync_runtime/ (legacy path stays until Wave 2)
□ W1.6  (S) Shrink main.dart to ~30 lines (bootstrap() then runApp(App()))

Phase 1b · Core relocations (closes M9 partial, sets up H2)
□ W1.7  (S) Move features/sync/domain/merge_rules.dart → core/sync/merge/merge_rules.dart; update 5 merger imports — closes H2
□ W1.8  (S) Move features/sync/domain/profile_scoped_preference_keys.dart → core/preferences/; update 8 importers
□ W1.9  (S) Move features/settings/presentation/providers/language_provider.dart → core/preferences/

Phase 1c · Barrel-file convention + lint enforcement
□ W1.10 (M) Create empty barrel files features/<feature>.dart for all 18 current features
□ W1.11 (M) Rewrite no_feature_cross_import lint to require features/<x>/<x>.dart instead of providers.dart
□ W1.12 (S) Add make audit grep #14 — no `import 'package:learning_tracker/features/` inside lib/core/**
□ W1.13 (S) Add make audit grep #15 — no cross-feature deep imports (anything not ending <feature>.dart)
□ W1.14 (S) Drop `|| echo "::warning::"` from .github/workflows/ci.yml lint job — hard CI fail — closes H6
□ W1.15 (S) Add unit tests for no_feature_cross_import lint rule — closes H7 partial
□ W1.16 (S) Add unit tests for no_curriculum_display_name_bypass lint rule — closes H7 partial

Phase 1d · Dead code purge (closes H8 + M8)
□ W1.17 (S) Confirm dashboard_model_provider.dart zero refs; delete + .g.dart twin
□ W1.18 (S) Confirm data_export_import_service.dart not parked epic (check git/Linear); delete (946 LOC)
□ W1.19 (S) Delete core/constants/app_assets.dart (0 refs)
□ W1.20 (S) Delete core/database/seed/test_date_seeds.dart (0 refs)
□ W1.21 (S) Delete H8 remainder: bulk_completion_dialog, completion_button, todays_tasks_widget, key_stats_row, content_browser_tree, content_version_check_service, link_provider_dialog, language_provider (Riverpod), add_track_controller (unused legacy)
□ W1.22 (M) Verify-then-delete M8 single-ref files: text_content_config, program_ref_resolver, content_db_health_checker, content_result, curriculum_content_fetcher, profile_creation_use_case, duplicate_completion_exception
□ W1.23 (S) Confirm @RoutePage zombie screens dead before deleting: GoalSetupScreen, LearningOrderScreen, ScopeSelectionScreen
□ W1.24 (S) Delete .gitkeep-only dirs: core/utils/{extensions,formatters,helpers}/, features/parent_mode/domain/{entities,use_cases,repositories}/, features/sync/data/data_sources/

Phase 1e · Foot-gun fixes (T18)
□ W1.25 (M) Rename AppLogger.instance getter → AppLogger.talker; new AppLogger.instance returns singleton AppLogger
□ W1.26 (M) Migrate 29 raw AppLogger.instance.error/info/warning sites to structured API
□ W1.27 (S) Delete 5 defensive wrappers (`final _log = AppLogger(AppLogger.instance);`)

Phase 1f · Exception/event base scaffolding (no leaves yet)
□ W1.28 (S) Create core/exceptions/app_exception.dart with abstract root + 5 category bases
□ W1.29 (S) Create core/logging/log_events.dart constants file
□ W1.30 (S) Update CLAUDE.md — remove link to deleted docs/coding-standards.md — closes M9
```

---

### Wave 2 — Re-carve features + sync stack deletion (~5-7 days; ~41 tasks)

Single-shot re-carving + delete the legacy sync stack. Largest blast radius. The new mergers (W2.26-2.30) MUST land before the deletion step (W2.35-2.39).

```
Phase 2a · Tracks cluster merge
□ W2.1  (M) Create features/tracks/ skeleton (data/, domain/, presentation/)
□ W2.2  (M) Move features/track_setup/** → features/tracks/setup/
□ W2.3  (M) Move features/learning_order/** → features/tracks/whole_curriculum_order/
□ W2.4  (M) Move features/track_learning_order/** → features/tracks/track_order/
□ W2.5  (M) Move features/stages/** → features/tracks/stages/
□ W2.6  (S) Add tracks/data/ layer placeholder — closes M6
□ W2.7  (S) Pull curriculum_activation_service from settings → tracks
□ W2.8  (M) Fill features/tracks/tracks.dart barrel with public surface
□ W2.9  (M) Migrate all importers from deep paths → tracks.dart barrel

Phase 2b · Account cluster merge
□ W2.10 (M) Create features/account/ skeleton
□ W2.11 (M) Move features/auth/** → features/account/
□ W2.12 (M) Move sign-up/magic-link/upgrade halves of features/onboarding/** → features/account/onboarding/ (track-setup half stays for Wave 6)
□ W2.13 (M) Move account_management_service from settings → account
□ W2.14 (S) Fill features/account/account.dart barrel
□ W2.15 (M) Migrate importers

Phase 2c · Dissolve parent_mode/
□ W2.16 (S) Move reward + point config screens → features/gamification/
□ W2.17 (S) Move PIN keypad widget → core/widgets/
□ W2.18 (S) Move parent_dashboard_aggregator → features/dashboard/
□ W2.19 (M) Move pin_service + create PinFlowMachine domain skeleton → features/profiles/ (full domain in W4.11)
□ W2.20 (S) Delete features/parent_mode/ directory

Phase 2d · Core/ misfiled-feature promotions
□ W2.21 (S) Move core/learning/ → features/learning/ (absorb optimistic_completion_provider, completion_writer)
□ W2.22 (S) Move core/streak/ → features/gamification/streak/
□ W2.23 (S) Move core/services/{calendar_program_*, local_calendar_engine, daily_schedule_composer, cross_curriculum_aggregator} → sacred_calendar/ + scheduling/
□ W2.24 (S) Move core/services/pin_service → features/profiles/
□ W2.25 (S) Delete core/services/ (now empty)

Phase 2e · Missing mergers (gate before deletion)
□ W2.26 (M) Add EntityKind.learningOrder + LearningOrderMerger + router case + mergeRouterProvider entry — closes C3/H3
□ W2.27 (M) Add 7 mergers + channels for SyncEngine-only collections (goals, learning_ledger, notif_settings, gamification_settings, ui_preferences, learning_order, profile_programs) — closes M1
□ W2.28 (M) Add pullStreak step in pull_pipeline — closes M4
□ W2.29 (M) Wire real stage_definitions/ push + pull + listener channel + _channelToKind — closes H4
□ W2.30 (S) Make _pullCollection throw on MergeOutcome.halt (after W2.26 lands)

Phase 2f · Single-shot legacy sync deletion
□ W2.31 (M) Add outbox-backed SyncWriteFacade impl + syncWriteFacadeProvider
□ W2.32 (M) Move pushAllLocalData + backfillGoalsForCloudCutover to outbox path
□ W2.33 (M) Move SyncStatus ownership from SyncEngine to SyncOrchestrator (own StreamController); repoint sync_status_providers
□ W2.34 (M) Grep-and-replace 21 syncEngineProvider consumers → syncWriteFacadeProvider — closes H1
□ W2.35 (S) Delete features/sync/data/sync_engine.dart
□ W2.36 (S) Delete features/sync/data/firestore_data_source.dart — closes M5
□ W2.37 (S) Delete features/sync/data/offline_queue.dart
□ W2.38 (S) Delete legacy sync_lifecycle_observer.dart (orchestrator wiring stays)
□ W2.39 (S) Delete legacy features/sync/presentation/providers/sync_providers.dart
□ W2.40 (S) Confirm H5 + M2 gone with deleted files; apply trivial fixes if anything remains in core/sync/

Phase 2g · Tutoring feature skeleton
□ W2.41 (S) Create features/tutoring/ skeleton (data/, domain/, presentation/) + empty tutoring.dart barrel — populated W3/W4/W6
```

---

### Wave 3 — Data model rebuild + tutor schema (~4-6 days; ~44 tasks)

Drop Drift v=1, wipe Firestore, redesign from first principles, fold in tutor_grants.

```
Phase 3a · Typed IDs
□ W3.1  (S) Create lib/core/ids/ directory
□ W3.2  (S) Add extension types: ProfileId, TrackId, StageId, SefariaRef, UserId, TutorGrantId
□ W3.3  (M) Add NaturalKey VO with per-entity constructors

Phase 3b · Codecs (one per entity)
□ W3.4  (S) Create lib/core/sync/codec/ + EntityCodec<E> abstract base
□ W3.5  (S) Add FirestoreCodec time-conversion helper (DateTime ⇄ Timestamp)
□ W3.6  (M) CompletionEventCodec
□ W3.7  (M) BookmarkCodec
□ W3.8  (M) TrackCodec
□ W3.9  (M) StageDefinitionCodec
□ W3.10 (M) LearningOrderCodec
□ W3.11 (M) ProfileProgramCodec
□ W3.12 (M) SettingsCodec (after splitting out stage_definitions)
□ W3.13 (M) StreakEventCodec
□ W3.14 (M) LearnerProfileCodec
□ W3.15 (M) LearningLedgerCodec
□ W3.16 (M) GoalCodec
□ W3.17 (M) TutorGrantCodec
□ W3.18 (M) Migrate mergers to consume codecs (kills 5-way marshaling — T6)

Phase 3c · Drift schema rebuild
□ W3.19 (M) Rewrite Drift schema as v=1 from scratch; drop all onUpgrade migration steps
□ W3.20 (S) Drop tables: completions, streaks, sync_queue
□ W3.21 (M) Add completions_view over completion_events WHERE purged_at IS NULL
□ W3.22 (S) Drop trackType column from curriculum_tracks; UNIQUE → (profileId, curriculumId)
□ W3.23 (M) Add real updatedAt to bookmarks, settings, stage_definitions — closes M3
□ W3.24 (S) Rename SQL columns back: pace_unit→pace_period, learning_unit→pace_granularity, unit_type→entry_scope; drop all .named() aliases — closes T4
□ W3.25 (S) Add missing FKs: learner_profiles→accounts, curriculum_scopes/learning_order/learning_ledger→learner_profiles
□ W3.26 (S) Replace '' defaults with nullable() on calendar_cycles.sefariaRefHe + seed_metadata.contentHash
□ W3.27 (M) Replace stage_definitions schedule quartet with single JSON 'schedule' column (sealed ScheduleSpec materialisation)
□ W3.28 (S) Add unified state ∈ {active, retired, archived, deleted} + stateChangedAt to entities needing tombstones — closes T7
□ W3.29 (S) Drop isActive/deletedAt/deactivatedAt/supersededAt ad-hoc tombstone columns

Phase 3d · Firestore rebuild
□ W3.30 (S) Delete top-level compat blocks from firestore.rules — closes T11
□ W3.31 (M) Rewrite firestore.rules for new snake_case + ULID doc-id shape
□ W3.32 (S) Split stage_definitions/{curriculumId} collection out of settings/{curriculumId} — closes T8 partial
□ W3.33 (S) Unify three preference docs into preferences/{scope} collection
□ W3.34 (S) Rename curriculum_import_metadata → import_metadata
□ W3.35 (S) Change completions/ to ULID doc-ids
□ W3.36 (S) Change learning_ledger/ to use existing ULIDs as doc-ids — closes T10
□ W3.37 (S) Change streak/ from single snapshot doc to streak_events/{ulid} collection

Phase 3e · Tutor mode schema (the M:N permission graph)
□ W3.38 (M) Add tutor_grants/{grantId} top-level collection with deterministic doc-id strategy
□ W3.39 (M) Add Firestore composite indexes: (tutor_uid, state), (parent_uid, child_profile_id, state), (tutor_email, state)
□ W3.40 (M) Add tutor_grants/{grantId}/audit_log/{entryId} sub-collection
□ W3.41 (M) Firestore rules: cross-uid read on users/{ownerUid}/learner_profiles/{pid}/** if active tutor grant; deny live-completion write from non-owner uids
□ W3.42 (M) Cloud Function: scheduled audit-log purge (12-month retention past grant termination)
□ W3.43 (M) Cloud Function: bulk-prior completion write proxy (writes as owner uid after tutor permission check)

Phase 3f · Goal model collapse
□ W3.44 (M) Collapse goal entity: drop goalType/paceValue/pacePeriod/targetDate → PaceTarget? field only; migrate goal_repository_impl + dashboard_providers pace-status logic to sealed PaceTarget

Phase 3g · Wipe and verify
□ W3.45 (S) Wipe Firestore (gcloud firestore delete on users/) + delete dev Drift DBs
□ W3.46 (S) Deploy new Firestore rules + Cloud Functions
□ W3.47 (S) Update or delete Story-27.8 acceptance test against new layout
```

---

### Wave 4 — Domain modelling + value objects + permission model (~5-7 days; ~35 tasks)

Where most of the DDD work lives. Includes the tutor-mode domain layer.

```
Phase 4a · Value objects
□ W4.1  (M) SefariaRef VO with parse + segment ops (bookName, chapter, verse?, isLeaf, coarseUnit); start strangler migration of 73 raw-String sites
□ W4.2  (S) StageOrder VO (≥1, monotonic)
□ W4.3  (S) Pin VO (4 ASCII digits, validates on construction)
□ W4.4  (M) StudyDayPattern VO with dayKindFor(Weekday) + equality
□ W4.5  (S) CalendarSystem { hebrew, english } enum (memory: "English" not "Gregorian")
□ W4.6  (S) PaceTarget sealed = sole goal target representation
□ W4.7  (M) ProgramStartingPosition VO replacing 'offset:N|ref:<sefariaRef>' substring grammar
□ W4.8  (S) Scope(level: ScopeLevel, value: ScopeValue) typed VO
□ W4.9  (S) ProfileMode { adult, child } + AccountTier { local, cloud } enums; deprecation marker on string equality
□ W4.10 (M) Sealed ScheduleSpec { DelaySchedule, WeeklySchedule, RollingSchedule } replacing nullable quartet

Phase 4b · Anemic features rebuilt
□ W4.11 (M) parent_mode PIN → PinFlowMachine pure domain (~100 LOC) + SetParentPinUseCase + VerifyParentPinUseCase; shrink pin_flow_controller.dart to thin Riverpod adapter
□ W4.12 (M) tracks setup → typed TrackBlueprint aggregate replacing Object? fields; sealed GoalIntent, StageConfiguration, BulkMarkIntent, ProgramSelection
□ W4.13 (M) tracks setup → TrackBlueprintDraftRepository (SharedPreferences impl) replacing 7 ad-hoc keys
□ W4.14 (M) tracks setup → ProvisionTrackUseCase replacing TrackCreationService.createTrack
□ W4.15 (S) track_learning_order → TrackOrder aggregate, OrderingLevel { sedarim, masechtos } VO, MasechtaOrderingPolicy domain service
□ W4.16 (M) progress → promote inline LifetimeTreeNode/CurriculumLifetimeSummary/TrackDualProgressMetric to domain/models/; extract LifetimeTreeBuilder/OverlappingCurriculaDeduplicator/TrackDualProgressCalculator
□ W4.17 (M) dashboard → extract NextRewardSelector + ComputePaceStatusUseCase + TrackCompletionService; collapse dashboard_providers.dart to 1-liners

Phase 4c · Business-logic relocations
□ W4.18 (M) completion_repository_impl.markComplete:57-200 → MarkCompletionUseCase
□ W4.19 (M) learning_order_repository_impl.saveOrder:91-129 → SaveLearningOrderUseCase
□ W4.20 (S) parent_dashboard_aggregator._computePaceStatus dup → reuse ComputePaceStatusUseCase
□ W4.21 (M) notification_providers.dart:22-46 → ReminderPreferences + NotificationPreferencesRepository
□ W4.22 (S) track_learning_order_repository_impl._buildMasechtosIndex → MasechtaOrderingPolicy (already W4.15)
□ W4.23 (S) profile_providers.dart:36-47 SelectedProfileId → ProfileSession aggregate in profiles/domain/
□ W4.24 (S) dashboard_providers.dart:289-303 side-effect-in-read-provider → write-path repository method
□ W4.25 (M) core/learning/completion_writer.commitBatch/commit → sealed BatchPlan + _classifyBatch/_applyBatchPlan/_resolveResults
□ W4.26 (M) Split BulkPriorCompletionService.priorMarkOnly off completion_events → separate prior_completion_imports table

Phase 4d · Tutor mode domain
□ W4.27 (M) TutorGrant aggregate root with sealed GrantState (pending, active, declined, rescinded, revokedByParent, revokedByTutor, expired)
□ W4.28 (S) TutorPermissions value object — 8 boolean policy fields, single source of truth
□ W4.29 (M) ProfileSelection { own | tutored } sealed union; SessionRole { parentOfOwn | childSelf | tutor } discriminator
□ W4.30 (S) TutorPin VO + TutorPinService (distinct from existing Parent PIN)
□ W4.31 (M) InviteTutorUseCase, AcceptTutorInviteUseCase, DeclineTutorInviteUseCase, RescindTutorInviteUseCase
□ W4.32 (M) RevokeTutorGrantUseCase, ResignTutorGrantUseCase, ListIncomingTutorAccessUseCase, ListOutgoingTutorGrantsUseCase
□ W4.33 (S) TutorWriteForbiddenException extends PermissionException
□ W4.34 (M) MarkLiveCompletionUseCase — enforces canMarkLiveCompletion boundary; throws TutorWriteForbiddenException on tutor session
□ W4.35 (S) permissionsProvider(session) Riverpod provider as single source of truth for UI affordances
```

---

### Wave 5 — Class cleanup + god-screen decomposition (~5-7 days; ~25 tasks)

```
Phase 5a · God-screen decomposition (6 screens)
□ W5.1  (L) app_intro_screen.dart (1370 LOC) → IntroScaffold + IntroPageView + 3 page widgets + IntroPageIndicator + GlowingCtaButton
□ W5.2  (L) sign_in_screen.dart (1237 LOC) → SignInController:AsyncNotifier<SignInState> + SignInForm + SignInModeCard + SignInActions + EmailVerificationDialog
□ W5.3  (L) gamification_screen.dart (1127 LOC) → 11 private classes promoted to widgets/gamification/
□ W5.4  (L) profile_picker_screen.dart (1059 LOC) → ConsumerWidget + ProfileGrid + AddProfileDialog + segmented sections (tutored section in W6.14)
□ W5.5  (L) onboarding_screen.dart (1030 LOC) → OnboardingPhaseRouter + per-phase step widgets + OnboardingResumeStore
□ W5.6  (L) reward_configuration_screen.dart (1004 LOC) → RewardConfigController:Notifier<RewardForm> + RewardCard + sub-widgets

Phase 5b · Sealed-union state refactors
□ W5.7  (M) Replace 3-8 boolean state machines across feature screens → sealed unions
□ W5.8  (M) SyncOrchestrator state machine → sealed
□ W5.9  (M) OutboxProcessor _flushInProgress/_rerunRequested → sealed FlushState

Phase 5c · Primitive obsession sweep
□ W5.10 (M) Profile mode literals (profile.mode == 'child') → ProfileMode enum across 20+ sites
□ W5.11 (M) Account tier literals (account.tier == 'cloudBorn') → AccountTier enum
□ W5.12 (M) Continue SefariaRef VO migration (started W4.1) across remaining sites
□ W5.13 (S) Ban literal-string mode/tier comparisons via make audit grep

Phase 5d · Theme / visual cleanup
□ W5.14 (M) Move 525 0xFF…… colour literals from features/ → core/theme/app_colors.dart
□ W5.15 (S) Add custom lint to ban Color(0xFF…) outside core/theme/
□ W5.16 (S) Move hard-coded English strings in features/ to l10n/ (memory rule violations)

Phase 5e · Provider/global cleanup
□ W5.17 (M) Replace String activeDbFileName global → accountDbFileNameProvider:AsyncNotifier<String>; gate router on .when
□ W5.18 (S) Remove LearningProgramRepository.instance singleton; route via Riverpod
□ W5.19 (S) Replace 100+ direct DateTime.now() calls with clockProvider.now(); enable make audit grep #6

Phase 5f · Naming + ConsumerWidget conversions
□ W5.20 (M) Rename *Service classes by intent: *Repository, *Gateway, *Notifier, *UseCase, *Renderer
□ W5.21 (M) Convert ~20 worst ConsumerStatefulWidget instances to ConsumerWidget + hooks/notifier (trivial state cases)

Phase 5g · Decision-table replacements
□ W5.22 (M) Replace if any remains: switch-over-strings → Map<EnumKey, Handler> registries (offline_queue already deleted W2.37; pattern for any leftover)
```

---

### Wave 6 — Tutor mode feature implementation (~4-6 days; ~25 tasks)

Land the user-facing tutor experience on top of the clean architecture from Waves 1-5.

```
Phase 6a · Onboarding fork (FR-8)
□ W6.1  (M) Onboarding sign-up flow branches: "track my own learning" / "joining to tutor" / "skip for now"
□ W6.2  (M) Refactor AddTrackFlow from mandatory onboarding step → opt-in entry
□ W6.3  (M) "Skip for now" lands on near-empty dashboard with CTAs (set up a track / accept invites)

Phase 6b · Tutor PIN setup
□ W6.4  (M) Tutor PIN setup screen — triggered at tutor onboarding or first invite acceptance, whichever first
□ W6.5  (S) Tutor PIN entry gate — prompted at every switch into a tutored profile
□ W6.6  (S) Tutor PIN reset flow via email verification

Phase 6c · Invite flow
□ W6.7  (M) Invite tutor screen (parent): email input + copyable share-link + send button
□ W6.8  (M) Transactional email integration (Firebase Extension or SendGrid)
□ W6.9  (M) Accept invite deep-link flow: token validation + sign-up/sign-in if needed + grant activation
□ W6.10 (S) Decline pending invite flow

Phase 6d · Management screens
□ W6.11 (M) Manage tutors screen (parent): per-child active list + pending list + revoke action + audit-log link
□ W6.12 (M) Manage my grants screen (tutor): list of tutored children with parent context + resign action
□ W6.13 (M) Audit log viewer (parent): filter by tutor / action / date range; renders from tutor_grants/{id}/audit_log/

Phase 6e · Profile picker + indicators
□ W6.14 (M) Profile picker segmented "My children" + "Tutored children" sections from active-grant query
□ W6.15 (S) Subtle AppBar indicator (icon + colour accent) when viewing tutored child (mounted in app_shell.dart)
□ W6.16 (S) Exit-to-my-profiles affordance in app shell

Phase 6f · Boundary enforcement
□ W6.17 (M) Disable/hide "Mark complete" affordance when permissions.canMarkLiveCompletion == false
□ W6.18 (S) Tooltip: "Tutors cannot mark live completions" on disabled affordances
□ W6.19 (M) Wire MarkLiveCompletionUseCase throw → UI catches TutorWriteForbiddenException with friendly dialog

Phase 6g · Audit log writing
□ W6.20 (M) Audit-log writer middleware: every tutor-originated mutation writes audit entry in same transaction
□ W6.21 (S) Capture tutor name snapshot at write-time (survives tutor account deletion)
□ W6.22 (S) Per-action audit entries for: config_changed, completion_bulk_prior, completion_reset, bookmark_advanced, profile_edited, goal_changed, stage_changed, reward_changed, study_day_changed

Phase 6h · Cascades + notifications
□ W6.23 (M) Parent-delete → all grants revoked + child profiles deleted (cascade extension)
□ W6.24 (M) Tutor-delete → all grants auto-resign; audit log preserves tutor name as snapshot string
□ W6.25 (S) Notify parent on tutor decline/resign; notify tutor on parent revoke
```

---

### Wave 7 — Exceptions + logging + telemetry + polish (~4-5 days; ~25 tasks)

Final wave — land the cross-cutting contracts after every consumer is in its final home.

```
Phase 7a · Exception leaves
□ W7.1  (M) Re-parent all existing exception classes under the 5 category bases
□ W7.2  (S) Add new exceptions: MergeException, OutboxDeadLetterException, FirestorePermissionDeniedException
□ W7.3  (S) Move BatchPushException → core/sync/exceptions/sync_push_exception.dart under NetworkException
□ W7.4  (S) Rename InvalidOperationException → InvalidTrackOperationException; under ValidationException

Phase 7b · Crisis-class telemetry
□ W7.5  (M) Wire merge_row_skipped event at silent skip sites in DriftMergeStore + ProfileProgramMerger — closes L2
□ W7.6  (S) Wire merge_router_halt event at pull_pipeline.dart halt site
□ W7.7  (S) Wire outbox_dead_lettered event at outbox_processor max-attempts
□ W7.8  (S) Wire listener_error event from ListenerSupervisor._onError callback
□ W7.9  (S) Wire sync_pull_started/completed/failed events at orchestrator boundaries
□ W7.10 (S) Wire permission_denied event from gateway typed FirestorePermissionDeniedException
□ W7.11 (S) Wire tutor-mode events: tutor_invite_sent/accepted/declined, tutor_grant_revoked/resigned, tutor_action_recorded, tutor_pin_set, tutor_live_mark_blocked

Phase 7c · Firebase Analytics + Crashlytics
□ W7.12 (M) Add firebase_analytics to pubspec.yaml
□ W7.13 (M) Create FirebaseAnalyticsService impl; LoggingAnalyticsService becomes fallback
□ W7.14 (S) Route runZonedGuarded errors to Crashlytics (currently Talker-only)
□ W7.15 (S) Fire crash_reported from recordFlutterFatalError
□ W7.16 (S) Route ListenerSupervisor._onError to Crashlytics non-fatal

Phase 7d · Error UX
□ W7.17 (M) Create AppErrorView widget in core/widgets/ consuming AsyncValue.error → category-mapped UI
□ W7.18 (M) Migrate 20+ screens from errorWithMessage(e.toString()) to AppErrorView
□ W7.19 (S) Extend PiiRedactor.sensitiveKeys with displayName, firstName, lastName, city, lat, lon, deviceId, oauthCode, magicLinkUrl, tutor_email
□ W7.20 (S) Add lint no_e_to_string_in_ui (forbids e.toString() inside presentation/)
□ W7.21 (S) Add lint no_raw_logevent (forbids logEvent(name, …) outside analytics_service.dart)

Phase 7e · Polish + final verify
□ W7.22 (S) Delete root Makefile; canonical is learning_tracker/Makefile
□ W7.23 (S) Update CLAUDE.md (any remaining stale references)
□ W7.24 (M) Bug-fix integration pass — apply Daniel's bug list (see "Bug fixes" section below) at their respective wave-appropriate sites
□ W7.25 (M) Final manual smoke across spot-on screens: EN + HE, single device + two-device sync (own children + tutored children); confirm no regression
```

---

## Bug fixes — finalised

Standalone bug fixes / rule clarifications folded into the refactor. Each is slotted into the wave that touches its subject area. **Three bugs captured (B1-B3); list closed.** Bugs surfacing during execution can be added as B4 onwards in the same format.

### B1 · Three-tier completion credit policy — engagement / achievement / lifetime

- **Rule:** Completions credit by tier based on the operation that recorded them.

  | Operation | Engagement<br>(streak, points) | Achievement<br>(siyumim, reports, learn-data) | Lifetime<br>(lifetime data) |
  |---|:---:|:---:|:---:|
  | **Live learning** (real-time mark) | ✅ | ✅ | ✅ |
  | **Bulk-mark in-track** (in-session multi-mark) | ❌ | ✅ | ✅ |
  | **Lifetime-mark** (lifetime-only) | ❌ | ❌ | ✅ |

  Hierarchy: each operation credits its own tier AND every lower tier. Lifetime-only mark is the narrowest; live mark is the full set. This unifies and supersedes DNI-381 (which only addressed streak-on-bulk-prior).

- **Symptom (current vs target):** Verify each tier hits / doesn't hit as the matrix dictates.
  - Bulk-mark-in-track *must* populate siyumim, learn-data, and reports (achievement-tier — confirm not accidentally filtered).
  - Bulk-mark must NOT populate streak (already per DNI-381) or points (likely the active bug — verify).
  - Lifetime-mark must populate lifetime data ONLY — confirm it doesn't leak into siyumim / reports / streak / points.
  - All three operations must populate lifetime data (assumed by hierarchy — confirm with Daniel if lifetime data is actually an orthogonal manual stream rather than a union).

- **Where it manifests:**
  - Completion write path: `core/learning/completion_writer.dart` + `features/learning/data/repositories/completion_repository_impl.dart` (until W4.18 / W4.25 reshape them into use cases).
  - Bulk path: `features/onboarding/domain/services/bulk_prior_completion_service.dart` + any in-track bulk caller (verify all bulk entry points share the same policy).
  - Lifetime path: `features/settings/presentation/screens/lifetime_marking_screen.dart` + whatever service it currently calls (verify the write path emits only the lifetime-tier event).
  - Streak: `features/gamification/streak/...` (post-W2.22 location) — reducer must exclude bulk + lifetime events.
  - Points: `core/learning/` points-award path — must exclude bulk + lifetime events.
  - Achievements / siyumim: must trigger on live + bulk, must NOT trigger on lifetime-only.
  - Reports / learn-data: must include live + bulk, must EXCLUDE lifetime-only.
  - Lifetime data (`features/progress/presentation/providers/lifetime_knowledge_providers.dart` + the new `progress/domain/services/LifetimeTreeBuilder` from W4.16): must reflect ALL three operations.

- **Severity:** HIGH (data-correctness in user-facing reports + gamification fairness)

- **Target wave:** Wave 4 (domain remodelling)
  - **W4.18** `MarkCompletionUseCase` — accepts a `CompletionSource ∈ {live, bulkInTrack, lifetimeOnly}` discriminator; emits domain events tagged with the source. Engagement-tier handlers subscribe only to `live`; achievement-tier handlers subscribe to `live + bulkInTrack`; lifetime-tier handlers subscribe to all three.
  - **W4.25** `completion_writer.commitBatch/commit` refactor — `BatchPlan` classification carries the `CompletionSource`; downstream handlers branch on it. Single source-of-truth for the credit policy.
  - **W4.26** `BulkPriorCompletionService` split — confirms `bulkInTrack` policy applies through the dedicated bulk path. Note: rename if needed to reflect that it covers in-track bulk, not just prior-to-app-adoption setup.
  - **W4.16 (extended)** `LifetimeTreeBuilder` domain service — confirms it consumes the union of live + bulk + lifetime-only events.
  - **W7.11** Add telemetry events `bulk_engagement_skipped`, `lifetime_achievement_skipped` to catch any future regression where a bulk or lifetime event incorrectly triggers a higher tier.

### B2 · Program-track starting position must not allow future dates (back ≤ 30 days, forward = 0)

- **Rule:** When adding a track with a program (Daf Yomi, Amud Yomi, etc.), the starting-position date is constrained to the window **`[today − 30 days, today]`** in the user's local day. Backward limit (30 days) is correct and stays. Forward is not allowed — picking a future start date for a structured program is incoherent.
- **Symptom:** The date picker / starting-position UI currently allows the user to select a future date. The clamp on the upper bound is missing or not enforced.
- **Where it manifests:**
  - UI: program-step widget inside the AddTrack flow (`features/track_setup/presentation/steps/...` — file name TBD on inspection; lives under the umbrella `add_track_flow_screen.dart` 894 LOC + `edit_track_screen.dart` 877 LOC twin).
  - Domain: `TrackCreationService._parseProgramStartingRef:254-289` (the substring grammar that decodes `offset:N|ref:<sefariaRef>`).
  - Where the constraint should be enforced systemically: the `ProgramStartingPosition` VO (introduced by W4.7) — factory throws / refuses to construct if the date is outside the window. Single source of truth; UI consults the VO's allowed window for the picker bounds.
- **Severity:** MEDIUM (mis-configures the program; learner gets a confusing schedule or runtime validation error later)
- **Target wave:** Wave 4 + Wave 6
  - **W4.7** `ProgramStartingPosition` VO — extended scope: also enforces the `[today − 30 days, today]` window. Constructor takes `(referenceDate, today, clock)` and throws `ValidationException` on out-of-range. Replaces both the substring grammar AND the implicit window check.
  - **W6.2** (AddTrackFlow opt-in refactor) — the program-step's date picker reads its allowed window from `ProgramStartingPosition.allowedWindow(today)`; max is clamped to today, min to today − 30 days. No standalone "is this in the past" string check.
- **Confirmed uniform** — the −30-day backward limit applies to every program identically (no per-program override).

### B3 · Back-dated program enrolment must generate correctly-overdue catch-up tasks (verify in code)

- **Rule:** When the user picks a program start date in the past (i.e. `start_date = today − N` with `N ∈ [1, 30]`), the system MUST generate the program's scheduled items for every covered day and surface them on the dashboard as **overdue** tasks. This is the entire purpose of the −30-day back-dating affordance — it is the "I've already started this program N days ago, load me with the items I've covered so I can catch up" semantics. Without correct overdue generation, back-dating is a no-op and B2's window is meaningless.
- **Symptom (verify):** Pick a program (Daf Yomi, Amud Yomi, …) with `start_date = today − 5`. Expect to see ~5 overdue program tasks in today's dashboard. Verify whether this happens today, after Wave 4 reshapes the enrolment + projection paths, AND in every subsequent wave.
- **Where it manifests:**
  - Enrolment path: `features/track_setup/domain/services/track_creation_service.dart` → post-W4.14 `ProvisionTrackUseCase`. Must invoke program-schedule materialisation against the back-dated start.
  - Schedule generation: `features/scheduler/domain/services/scheduler_engine.dart` (~750 LOC pure) + `DailyTaskGenerator`. Walk `[start_date, today]` and emit a task per scheduled day per the program's cadence.
  - Overdue projection: `features/scheduler/presentation/providers/scheduler_providers._buildProjectionTasks:387` (337 LOC, slated for W5 split per funcs-audit W5). Tasks with `scheduled_date < today` must surface as overdue.
  - Dashboard render: confirm overdue widgets actually consume the back-dated tasks (the carousel / "main focus" / overdue lane).
- **Edge cases to verify:**
  - Programs with non-daily cadence (weekly review, every-other-day, etc.) — generation must respect the program's actual schedule, not raw day-count.
  - Hebrew-calendar skip days (Shabbos / Yom Tov when the program pauses, if applicable) — those days don't produce tasks.
  - `N = 0` (today as start) — zero overdue tasks, single live task for today.
  - `N = 30` (max back-dating) — up to ~30 overdue tasks (minus skip days); confirm UI handles the volume gracefully.
  - Timezone — `today` is the user's *local* day per the existing `LocalDayClock` (DNI-331) — not UTC midnight. The schedule walks local days.
- **Severity:** MEDIUM (the −30-day affordance is mooted if this is broken)
- **Target waves:** Verification ride-alongs at three points
  - **W4.14** (`ProvisionTrackUseCase`) — add an integration check: after provisioning with `start_date = today − 5`, the use case's emitted side effects include 5 scheduled items dated in the past.
  - **W4.16** / **W4.17** (progress + dashboard use case extraction) — confirm the overdue projection surfaces the back-dated items.
  - **W7.25** (final manual smoke) — explicit checklist step: add a Daf Yomi track with `start_date = today − 5`, expect ~5 overdue tasks on the dashboard immediately after enrolment.

---

**Bug list closed at B3.** Each is slotted into a specific wave/task. Future bugs encountered during execution can be appended as B4+ in the same format.

---

## Open decisions

1. **H4 stage_definition wiring** — recommended: full push + pull + listener. Confirm before W2.29.
2. **`data_export_import_service.dart` (946 LOC)** — confirm not parked epic before W1.18.
3. **`dashboard_model_provider.dart`** — verify zero refs before W1.17.
4. **Two `Makefile`s** — delete root one (W7.22).
5. **Tutor live-completion blocking implementation** — payload field vs Cloud Function proxy. Cloud Function is cleaner; W3.41 + W3.43 implement.
6. **Pending invite expiry exact value** — 7 days proposed; confirm at W6.9 design.
7. **Tutor PIN recovery flow** — email reset proposed; detail at W6.6.
8. **Offline support for tutored profiles** — W6 ships live-Firestore-only; local mirror deferred.

---

## Risks

- **Wave 2's single-shot sync deletion has no rollback within the wave.** Mitigation: W2.26–W2.30 (new mergers) lands first; W2.41 (manual two-device smoke per entity) verifies before moving on.
- **Wave 3's Drift wipe** destroys local seeded data on dev devices. Acceptable; re-seed.
- **Sealed `ScheduleSpec` refactor (W4.10)** breaks three sites simultaneously. Land them in one PR.
- **`SefariaRef` rollout** (73 files) — strangler with `.raw` escape hatch.
- **God-screen splits without prior golden tests** rely on manual visual verification. Acceptable for pre-launch state.
- **Wave 6 tutor mode** introduces cross-uid Firestore access patterns; security-rule mistakes here are higher-blast-radius. Manual test negative cases: denied tutor reads on non-active grant, tutor live-completion write rejected, revoked tutor immediate access loss.
- **Tutor email-to-uid binding** — same email associated with multiple Firebase Auth accounts is possible. Accept-invite path verifies authed email matches invite email.
- **Onboarding fork (W6.1)** touches AddTrackFlow which has many step files; sequence carefully so existing onboarding still works for the "track my own" branch.

---

## Effort estimate

### Per-wave (informational — work distributes across streams, not sequentially through waves)

| Wave | Tasks | Single-dev effort |
|---|---:|---:|
| 1 — Foundation & dead code | 30 | 3-4 d |
| 2 — Re-carving + sync deletion | 41 | 5-7 d |
| 3 — Data model rebuild + tutor schema | 47 | 4-6 d |
| 4 — Domain modelling + VOs + permission model | 35 | 5-7 d |
| 5 — Class cleanup + god screens | 22 | 5-7 d |
| 6 — Tutor mode feature implementation | 25 | 4-6 d |
| 7 — Exceptions + logging + telemetry + polish | 25 | 4-5 d |
| **Sum** | **~225 tasks** | **~30-42 dev-days** |

### Wall-clock by execution mode

| Mode | Wall-clock | Throughput |
|---|---:|---|
| **Single-dev, sequential** | ~6-8 weeks | 1 task / few hours, no parallelism |
| **5-dev human squad, parallel streams** | **~12-15 working days (~2.5-3 weeks)** | 5 streams concurrent, critical path drives total |
| **5-agent AI squad + orchestrator, parallel streams** | **~5-8 working days (~1-1.5 weeks)** | Agents have no human coordination latency; P-points still constrain throughput |

The 5-dev squad cuts wall-clock roughly 3-4× vs single-dev. The AI squad cuts roughly another 2× on top of that, primarily by collapsing handoff latency at the P-points and running mechanical tasks (relocations, dead-code purges, codec generation) in true parallel.

### Critical-path stream

**S2 (Sync & Data)** is the longest stream and gates the most downstream work. If acceleration is needed, the highest-leverage move is to either (a) split S2 further (e.g. one dev/agent on codecs, another on the schema rebuild) or (b) start S2's typed-IDs + codec work the moment P1 lands rather than waiting for P3.
