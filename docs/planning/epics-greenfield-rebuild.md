---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - /home/daniel/.claude/plans/learning-tracker-greenfield-rebuild.md
  - docs/architecture.md
epicNumberingStart: 24
linearTeam: DNI
linearProject: learning-tracker
date: 2026-05-13
---

# learning-tracker — Greenfield Rebuild Epic Breakdown (Epics 24–27)

## Overview

This document decomposes the **Greenfield Rebuild Plan** into 4 ship-slice epics (E24–E27) with stories ready to push to Linear (team `DNI`, project `learning-tracker`).

The rebuild is brownfield with greenfield permission: backwards compatibility OFF, Firebase wipe acceptable, local DB schema reset, internal testers wipe-install. Hebrew UI is in scope and threaded across E25–E27.

The 4 ship-slice epics map to the 8 phases (P0–P7) in the rebuild plan as follows:

| Epic | Phase coverage | Scope |
|---|---|---|
| **E24 — Stop-the-Bleeding** | P0 | Critical fixes under existing schema. No new architecture. Ships first to close data-loss / security holes immediately. |
| **E25 — Schema + Core Foundation** | P1 + P2 | Wipe-install boundary. Local DB v1, Firestore v1, ten rebuilt core subsystems. Hebrew UI core infrastructure. |
| **E26 — Feature Rebuilds + Cleanups** | P3 + P4 | Eight feature areas reorganized to consume the new core. Label/ARB/naming/dead-code sweep. RTL audit. Hebrew translation completion. |
| **E27 — Discipline & Closure** | P5 + P6 + P7 | Test pyramid, CI gates (greps + lints + custom_lint + emulator rules + coverage floor + arb parity + goldens), observability (Crashlytics + analytics + structured logging), docs reconciliation. |

## Requirements Inventory

### Functional Requirements

Functional requirements describe what the rebuilt system MUST DO. Most are reframed from Tier-1 critical findings in the rebuild plan (the defect closes when the FR is satisfied).

- **FR1: Multi-profile data isolation.** Every profile-scoped DAO query MUST require a `profileId` parameter; cross-profile queries MUST NOT exist in production code paths. Cascade-delete MUST clean up all profile-scoped tables atomically. (Closes T1.1)
- **FR2: Single streak system.** Streak value MUST be computed by one canonical `StreakReducer` over the `streak_events` event log, with one day-boundary convention (UTC), and read through one provider (`StreakStateProvider`). Synchronous `StreakService.recordCompletion` writes MUST be removed. (Closes T1.2)
- **FR3: Streak round-trip sync.** `streak_events` MUST push and merge through the sync engine. On cloud restore with empty local log, the reducer MUST reconstitute events from `completion_events`. (T1.2)
- **FR4: Firestore rules enforcement.** Rules MUST be per-collection: event collections allow `create` only with field validators (points 0–100, completedAt ≤ request.time); snapshot collections allow `update` with field whitelists; `delete` MUST be denied except via Cloud Functions. (Closes T1.3)
- **FR5: Append-only invariant.** `completion_events`, `streak_events`, `learning_ledger` MUST have no public delete API. Track deletion MUST NOT cascade into these tables; track delete becomes soft (`deletedAt` column). (Closes T1.4)
- **FR6: Auth single source.** All sign-out MUST flow through `AuthRepository.signOut`, which signs out both Firebase Auth and Google Sign-In. Direct `FirebaseAuth.instance.*` calls outside `core/auth/` MUST be eliminated. (Closes T1.5)
- **FR7: Crash reporting.** System MUST report uncaught errors to Crashlytics with `profileId` as the user ID (numeric, no PII). (T1.6)
- **FR8: Structured logging.** All log calls MUST use `AppLogger` with structured field-level PII redaction (no substring matching); no raw `package:talker/talker.dart` imports outside `core/logging/`. (T1.6)
- **FR9: Numerically correct displays.** Pace card, scheduler, progress dashboard, and stat cards MUST display values computed from real data (real `totalItems`, real day-counts, removed fake `+XP`). All seven enumerated wrong-number sites in T1.7 MUST be corrected.
- **FR10: Sacred-time-aware notifications.** Daily reminders MUST check sacred-time windows at FIRE time. Reminders MUST be scheduled as a rolling 14-day batch of pre-filtered one-shots. Timezone MUST be re-detected on app resume, with `SacredWindow` invalidation and reschedule. (Closes T1.8)
- **FR11: Sacred lock scope.** `SacredTimeLockOverlay` MUST be scoped to the post-auth shell only; MUST NOT cover onboarding routes. (T1.8)
- **FR12: Stage definition fidelity.** Weekly/rolling stage fields (`scheduleType`, `daysOfWeek`, `rollingWindowSize`) MUST sync across devices with full fidelity. The stage repository MUST be the only write path; the 16 DAO-bypass call sites MUST be migrated. (Closes T1.9)
- **FR13: Stage reorder safety.** Stage reorder MUST be transactional. The protected `Learn` stage MUST be guarded at position 1 on every mutation (reorder, delete, move). (T1.9)
- **FR14: Portable data export.** Export MUST include `profileId` on every row, cover all 23 user-DB tables, strip Firebase identity (email/UID), and round-trip through import preserving data exactly per profile. Export-import MUST be per-profile (not whole-account). (Closes T1.10)
- **FR15: Single completion writer.** All completion writes MUST go through `CompletionWriter.commit(CompletionCommand)`. The writer's transaction MUST insert event-log row + projection row + outbox rows atomically. No fire-and-forget side effects; no provider-cascade invalidation lists in screens. (T2.7, Principle P3)
- **FR16: Single program-ref resolver.** Program calendar refs MUST be resolved through one `ProgramRefResolver` in `core/content/`; dashboard, scheduler, and reader MUST consume the same matcher. Broken-reader navigation (persisted human-readable strings) MUST NOT be possible. (T1.7)
- **FR17: Streak-suppressed bulk-mark-prior at all stages.** Bulk-mark-prior MUST suppress streak ticks for any stage (currently only stage 1 abstains). (T1.7 / streak fix Layer 1 from v1.0.60 plan)
- **FR18: Hebrew UI as a locale.** Hebrew MUST be a first-class app locale (`he`) alongside English (`en`). Locale MUST be auto-detected from the device / Google Play locale via Flutter's standard `MaterialApp(supportedLocales: [en, he])` resolver — NOT user-selectable. (PART 6.5)
- **FR19: Hebrew-terms preference per profile.** Curriculum/track/level names MUST be renderable in Hebrew script vs transliterated English independently of app locale, controlled by a per-profile preference. (PART 6.5)
- **FR20: Hebrew-date preference per profile.** Hebrew calendar vs English (Gregorian) date display MUST be controlled by a per-profile preference, independent of app locale and Hebrew-terms toggle. (PART 6.5)
- **FR21: Schema-v1 wipe-install boundary.** Wipe-install MUST produce a clean schema-v1 user DB and Firestore-v1 documents. No migration code from v9 (or earlier) is retained. (Phase 1)
- **FR22: Multi-account threading.** `currentAccountId` MUST be threaded through the 8 hardcoded `= 1` sites; the existing `DeviceAccounts` table (up to 5 accounts/device) MUST be the real source of account context. (PART 6.3, T1.1)
- **FR23: Completion idempotency at storage.** Concurrent two-device completions on the same natural key MUST collapse into the same row (composite-natural-key UNIQUE in SQLite + deterministic Firestore doc IDs). (T1.2 collision corollary, Principle P3)
- **FR24: Outbox-based post-write events.** Cross-feature event cascade (gamification → progress → sync → streak) MUST be driven by an `OutboxProcessor` from the local outbox table, not by ad-hoc provider-invalidation lists in screens. (T2.7)

### Non-Functional Requirements

Non-functional requirements describe quality attributes the rebuilt system must satisfy. These are derived from the five principles (P1–P5) and the Tier-2/Tier-3 architecture-and-consistency findings.

- **NFR1 (P1 — Single source of truth).** Every concept in the rebuild plan's truth-table MUST have exactly one authoritative implementation accessed through one entry point: curriculum/track/item display text via `core/labels/`; locale-toggle via `core/preferences/`; streak via `StreakReducer`; pace via `PaceCalculator`; day boundary via `LocalDayClock`; completion write via `CompletionWriter`; auth via `AuthRepository`; Firestore mutation via `FirestoreGateway`; outbox via `OutboxProcessor`; hierarchy via `ContentTree`; curriculum-from-string via `CurriculumId.fromStorageKey`.
- **NFR2 (P2 — Strict layering).** `app → features → core` only. `core/` MUST NOT import from `features/`; `features/X/` MUST import `features/Y/` only via `features/Y/providers.dart`; `presentation/` MUST NOT import `data/` within a feature. Enforced by custom_lint. (T2.2)
- **NFR3 (P2 — Firebase confinement).** No Firebase symbol (`FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`) MUST appear outside `core/sync/` and `core/auth/`. Enforced by `no-firebase-outside-core` custom lint. (T1.5, T2.2)
- **NFR4 (P3 — Event-sourced for write-heavy).** Completions and streaks use event log + projection; settings, profile metadata, bookmarks, and track config use snapshot with versioned `lastModified`.
- **NFR5 (P3 — Idempotent writes).** Event-sourced tables MUST have composite-natural-key UNIQUE indexes in SQLite and deterministic Firestore doc IDs of the form `{uid}_{profileId}_{kind}_{naturalKey}`. Two devices writing the same natural key MUST land on the same row.
- **NFR6 (P4 — No half-finished).** Banned (CI-fails on any): `// TODO: refactor later`, `// FIXME: hardcoded for now`, `// XXX: temporary`, dead enum values, dead tables, dead providers, dead widgets, dead ARB keys, empty catch blocks (`catch (_) {}`), and any dead-code stubs left from prior refactors.
- **NFR7 (P5 — Observable).** Every write path emits a structured log event (`{event, profileId, accountTier, durationMs, status}`). Every uncaught error reports to Crashlytics with a redacted user id. ≥12 named analytics events tracked (see PART 4 of rebuild plan). PII redaction is field-based with a per-key allowlist, NEVER substring matching.
- **NFR8 (god-object cap).** `source-lines-of-code` cap of 600 per file enforced by lint; cyclomatic-complexity cap of 15; max parameter count of 5. (T2.1) — these break up `sync_engine.dart` (2921), `add_track_flow.dart` (4403), `dashboard_screen.dart` (2211), `scheduler_providers.dart` (1269).
- **NFR9 (DAO consistency).** Generic `BaseDao<T>` with `getById`, `getByProfile`, `count`, `exists` replaces the `getAllX` / `getXByProfile` / `getXByCurriculumAndProfile` triplet drift. `TrackScope({trackId, profileId, curriculumId})` record threaded through queries. (T2.6, T1.1)
- **NFR10 (real FKs).** Bookmark MUST use `trackId` FK, not `trackType` string. All track-bound tables MUST have real foreign keys. (Phase 1)
- **NFR11 (performance).** Hot-path queries MUST have composite indexes (enumerated in Phase 1). All list fetchers MUST paginate. All multi-row writes (stage reorder, learning-order saveOrder) MUST be transactional. (T2.10)
- **NFR12 (test pyramid).** Test composition target: ~60% unit, 25% DAO/repo, 10% widget+golden, 5% integration/E2E. Line-coverage floor of 60% enforced in CI; coverage MUST NOT drop on a PR. (T3.1, Principle P5)
- **NFR13 (named integration tests).** Ten named integration tests required pre-launch: bulk-mark-prior-no-streak, reducer-reconciles-from-event-log, multi-profile-isolation, track-card-canonical-layout, firestore-rules (emulator), offline-completion-flushes, pin-lockout-cycle, log-redaction, bookmark-advance-atomic-with-completion, cloud-restore-preserves-streak.
- **NFR14 (ARB parity).** No hardcoded user-facing text in `lib/features/`. Both `app_en.arb` and `app_he.arb` MUST have parity (every key in en is in he); CI gate via `tool/arb_parity_check.dart`. Plurals MUST use `{count, plural, ...}` form. (T3.3, T3.4, PART 6.5)
- **NFR15 (naming consistency).** One name per concept: `unit` → `pacePeriod` / `paceGranularity` / `entryScope` (three distinct things); `Profiles`/`UserProfiles` → `LearnerProfiles`/`Accounts`; "Gregorian" → "English" (display); single notification taxonomy (no "Reminder"/"Alert"/"Milestone"/"Notification" drift). (T3.2)
- **NFR16 (RTL discipline).** Direction-aware widgets only: `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`. `EdgeInsets.only(left:|right:)`, `Alignment.centerLeft|centerRight`, `TextAlign.left|right` banned by lint. (PART 6.5)
- **NFR17 (custom lints).** Four custom lints MUST live in CI: `no-curriculum-display-name-bypass`, `no-feature-cross-import`, `no-firebase-outside-core`, `no-raw-talker`. (PART 4)
- **NFR18 (CI surface).** CI MUST run: `analyze --fatal-infos`, `format-check`, `audit` (greps), `lint` (custom_lint), `test` (full suite), `coverage-floor`, `firestore-rules` (emulator), `golden` (with diff upload on failure), `arb-parity`.
- **NFR19 (local audit).** `make audit` Makefile target MUST run every grep/lint check locally so developers can verify before push.
- **NFR20 (SyncEngine decomposition).** `sync_engine.dart` (2921 lines) MUST be split into 7 focused classes: `FirestoreGateway`, `PushPipeline`, `PullPipeline`, `MergeRouter`, `EntityMerger<T>` (sealed per-kind strategies), `ListenerSupervisor`, `LifecycleObserver`. `MergeRules` MUST be load-bearing, not vestigial. (T2.9)
- **NFR21 (time discipline).** No `DateTime.now()` outside `core/time/`. All "today's local date" reads go through `LocalDayClock` with test-override capability. (P2.3)
- **NFR22 (content index).** `ContentIndex` keepAlive provider serves indexed `Map<sefariaRef, ContentItem>` lookups for all 9 curricula. `CurriculumLabel.breadcrumb()` MUST NOT scan content lists per lookup. (T2.3)
- **NFR23 (no empty catches).** `catch (_) {}` banned in production code; every catch must either rethrow or log structured context. (PART 4 grep)
- **NFR24 (no raw print/debugPrint).** `print(`/`debugPrint` banned in production code; logging goes through `AppLogger`. (PART 4 grep)
- **NFR25 (UTC storage).** All persisted timestamps MUST be UTC; locale-aware display through `LocalDayClock`. (Existing architecture Pattern P5, preserved.)
- **NFR26 (Firestore doc-id determinism).** Firestore doc IDs MUST follow `{uid}_{profileId}_{kind}_{naturalKey}` for event collections and `{uid}_{profileId}[_{scope}]` for snapshot collections. One composite Firestore index per query path. (Phase 1)

### Additional Requirements

These are infrastructure, tooling, and setup items derived from the rebuild plan (Architecture is being rewritten — current `docs/architecture.md` reflects the OLD architecture being replaced).

- **AR1: Greenfield permission scope.** Backwards compatibility OFF. Firebase data can be wiped at cutover. Local DB schema reset (no v9→v(n) migration paths retained). Internal testers wipe-install. No backwards-read shims; no import-from-old-export tooling.
- **AR2: Firestore v1 layout.** Top-level collections, no `users/{uid}/` nesting. Collections: `accounts/{uid}`, `learner_profiles/{uid}_{profileId}`, `completion_events/{uid}_{profileId}_{sefariaRef}_{stageId}_{trackType}`, `streak_events/{uid}_{profileId}_{dayUtc}_{kind}`, `learning_ledger/{uid}_{profileId}_{ulid}`, `track_configs/{uid}_{profileId}_{trackId}`, `bookmarks/{uid}_{profileId}_{trackId}`, `settings/{uid}_{profileId}`.
- **AR3: Local DB v1 schema.** Tables renamed (`Profiles` → `LearnerProfiles`, `UserProfiles` → `Accounts`). Every profile-scoped table has `(profileId, ...)` in PK with NO default value. Append-only tables (`completion_events`, `streak_events`, `learning_ledger`) declare composite-natural-key uniques and have no public delete API. Snapshot tables have versioned `lastModified`.
- **AR4: Composite indexes (hot paths).** `completions(profileId, curriculumId, completedAt DESC)`; `completions(profileId, sefariaRef, stageId, trackType)` UNIQUE; `learning_ledger(profileId, createdAt)`; `streak_events(profileId, dayUtc, eventType)` UNIQUE.
- **AR5: Schema check tooling.** `tool/schema_check.dart` runs in CI; parses Drift table annotations and asserts every profile-scoped table has `profileId` in PK and at least one composite index. Drift migration tests run all v(n−1)→v(n) paths against fixture DBs.
- **AR6: Firestore emulator rules tests.** Rules tests run in CI against the Firestore emulator covering: per-collection create-only enforcement, field-validator clamps (points 0–100, completedAt ≤ now), field-whitelist enforcement on updates, delete denial except via Cloud Functions.
- **AR7: Crashlytics provisioning.** Crashlytics wired in `main.dart` BEFORE any other init so early-init crashes are captured. User ID = `profileId.toString()` (numeric).
- **AR8: Analytics provisioning.** ≥12 named analytics events: `app_launch`, `completion_recorded`, `bulk_mark_prior_used`, `track_added`, `streak_milestone_reached`, `sync_failed`, `pin_locked_out`, `parent_mode_entered`, `notification_fired`, `notification_suppressed_sacred_time`, `cloud_restore_completed`, `crash_reported`.
- **AR9: ARB parity tooling.** `tool/arb_parity_check.dart` runs in CI; asserts every key in `app_en.arb` has a corresponding key in `app_he.arb`. Hebrew translation review by a native Hebrew reviewer (the user) is the source of truth for religious-curriculum terminology.
- **AR10: Cloud Functions for deletes.** Any necessary delete operations (account deletion, GDPR-style data removal) flow through Cloud Functions; direct client deletes denied by rules.
- **AR11: Outbox table.** Local SQLite `outbox` table tracks pending sync items per entity kind. `OutboxProcessor` drains; `PushPipeline.pushX` performs Firestore mutation. Outbox row written inside the same transaction as the event-log + projection write.
- **AR12: Sacred window persistence.** `SacredWindow` rows persisted in SQLite so background notification fires can read them without the Flutter engine running. `TimezoneLifecycleObserver` parallels `SyncLifecycleObserver` to invalidate on resume.
- **AR13: Pub spec changes.** Noto Sans Hebrew font bundled in `pubspec.yaml` (currently declared but not bundled per core review). `flutter_localizations` retains both `en` and `he` (reversal of original Phase 4 plan).
- **AR14: Linear epic numbering.** Rebuild epics start at Epic 24 (continuing after Epic 23 hard-tier auth). Linear team `DNI`, project `learning-tracker`.

### UX Design Requirements

UX-DRs describe interaction patterns, UX scope items, and visual standardization needs derived from the rebuild plan. Hebrew UI scope (PART 6.5) is the largest cluster.

- **UX-DR1 (locale auto-detection).** App locale auto-resolves from `WidgetsBinding.window.locale` against `supportedLocales: [en, he]`. NO locale picker in UI, NO locale step in onboarding.
- **UX-DR2 (direction-aware rendering).** `CurriculumLabel.curriculum(curriculumId)` returns a `Text` widget whose direction is picked from `Directionality.of(context)`, not from any toggle. UI code MUST NOT use inline `useHebrew ? a : b` ternaries — instead read `Localizations.localeOf(context)` or `Directionality.of(context)`.
- **UX-DR3 (preference placement).** Hebrew-terms toggle and Hebrew-date toggle appear under Settings as per-profile preferences with documented defaults (`hebrewTerms: false`, `useHebrewDate: false`). NOT presented during onboarding.
- **UX-DR4 (theme correctness).** Real `AppTheme.darkTheme()` implementation (currently a verbatim alias for light theme). 20+ heritage*/child* color aliases consolidated.
- **UX-DR5 (RTL widget audit).** ~80–100 sites migrated from `EdgeInsets.only(left:|right:)` → `EdgeInsetsDirectional`; `Alignment.centerLeft|centerRight` → `AlignmentDirectional`; `TextAlign.left|right` → `TextAlign.start|end`.
- **UX-DR6 (date pickers).** `_pickGregorianDate` / `_pickHebrewDate` renamed to `_pickEnglishDate` / `_pickHebrewDate`. Default driven by `useHebrewDate` per-profile preference. "Gregorian" terminology eliminated from UI strings (preserved in DB storage keys only with documented exception).
- **UX-DR7 (notification locale at fire time).** Notification body strings translated to Hebrew. Locale resolved at FIRE time (not schedule time), so a device traveling into an `he` locale starts receiving Hebrew reminders without app intervention.
- **UX-DR8 (PIN keypad).** PIN numeric digits unchanged; surrounding labels ("Confirm PIN", "Try again") render from ARB and flip with locale automatically.
- **UX-DR9 (Hebrew ARB completion).** Every key in `app_en.arb` has a corresponding Hebrew translation in `app_he.arb`. Religious-curriculum terminology reviewed and corrected by the user (native Hebrew speaker). Hardcoded Hebrew literal stage names (`לימוד`, `חזרה א׳`, `חזרה ב׳`) sourced from ARB, not seed data.
- **UX-DR10 (track-card canonical layout).** All 4 data shapes (programCalendar, deadlineGoal, velocityGoal, momentum) MUST render through one widget tree. `TrackCard` + 5 subcomponents (`TrackCardHeader`, `NextTaskBreadcrumb`, `TrackStatGrid`, `LifetimeLearningLine`, `TrackContinueButton`) + `TrackCardViewModel` (freezed). `TrackProgressVariant` enum deleted; variant data flows via `BreadcrumbLabelKind`.
- **UX-DR11 (Progress overview tappable stats).** `_OverviewStatCard` on the Progress overview is tappable and navigates to the relevant detail screen. Stat-card primitive shared with `TaskCategoryStatBox` via `core/widgets/StatCard`.
- **UX-DR12 (StreakCalendar honors ranges).** `StreakCalendar` widget honors `startDate`/`endDate` parameters across all 3 caller ranges (7-day, 29-day, all-time). Hardcoded 14-day loop removed. All 3 callers render correctly.
- **UX-DR13 (StreakHistoryScreen).** New `StreakHistoryScreen` created for navigation from the streak hero card. (P3.6)
- **UX-DR14 (mixed-script cleanup).** Mixed-script strings such as `'Pick a preset or build your own חזרה schedule.'` resolved per locale: English locale uses transliterated `chazara` (or `HebrewTerms.uiChazara` value depending on the Hebrew-terms toggle); Hebrew locale renders fully in Hebrew.
- **UX-DR15 (no fake "+XP").** Daily task card MUST NOT display the fake `+XP = estimatedEffortMinutes * 3` value (xp_events table was deleted in migration v3→v4). Either points are displayed from a real source or the field is removed.
- **UX-DR16 (dashboard decomposition).** All 20 private classes in `dashboard_screen.dart` extracted to `widgets/`. Dashboard screen consumes `dashboardModelProvider`; cards consume sub-models.
- **UX-DR17 (add-track flow decomposition).** `add_track_flow.dart` (4403 lines, 26 classes) decomposed into one file per step under `presentation/steps/` + `AddTrackController` (state machine) + `AddTrackFlowScreen` (shell). All hardcoded English strings extracted to ARB.
- **UX-DR18 (onboarding decomposition).** `onboarding_screen.dart` 7-phase god-screen replaced with `OnboardingController` + list of `OnboardingStep` (each step a `ConsumerWidget` with `(load, save, validate)`). Profile creation becomes one transactional `ProfileCreationUseCase`. Dead resume code (language/calendar phases) deleted.
- **UX-DR19 (reader purity).** Reader (`text_display_screen.dart`) becomes a pure render. Completion flow goes through `CompletionWriter`. 14-provider invalidation cascade replaced with one `completionCommittedProvider` notifier from the outbox.
- **UX-DR20 (offline UX parity).** Offline indicator: subtle top banner for cloud-born users temporarily offline; persistent "no backup" badge in profile area for local-born users. (Inherited UX-DR4-v2 from Epic 19; preserved.)
- **UX-DR21 (PreferenceListTile primitive).** One `PreferenceListTile` and one `PreferenceSegmentedTile<T>` replace the family of bespoke preference tiles across Settings.
- **UX-DR22 (PIN flow consolidation).** One `PinFlowController` + `PinFlowScreen` configured by `PinFlowMode.{setup, change, verify}` replaces the 3 near-identical PIN screens (parent setup, parent change, parent verify).
- **UX-DR23 (curriculum activation guard).** Curriculum minimum-1 enforced at `CurriculumActivationService.deactivate` (throws `LastActiveCurriculumException`). UI surfaces the constraint clearly when the user attempts to deactivate their last curriculum.

### FR Coverage Map

This map asserts every functional, non-functional, additional, and UX requirement has at least one covering epic. Story-level coverage is added in Step 3.

#### Functional Requirements (24)

| FR | Covered by | Notes |
|---|---|---|
| FR1 — Multi-profile data isolation | **E24** (band-aid: runtime assertions) + **E25** (real fix: profileId in PK, no `withDefault(Constant(0))`) | Two-phase: E24 buys breathing room under the existing schema; E25 fixes at the schema level. |
| FR2 — Single streak system | **E25** | `StreakReducer`, UTC days, `StreakStateProvider` single read path. |
| FR3 — Streak round-trip sync | **E25** | `StreakEventMerger`, reconstitute-from-completion-events on empty-log restore. |
| FR4 — Firestore rules per-collection | **E24** (split wildcard, validators on create) + **E25** (full shape, snapshot whitelists) + **E27** (emulator test gate) | |
| FR5 — Append-only invariant | **E24** (delete `completionDao.deleteByTrack`; soft-delete tracks) + **E25** (schema-level: no public delete API) | |
| FR6 — Auth single source | **E24** | All 8 `FirebaseAuth.instance.*` call sites migrated to `AuthRepository`. |
| FR7 — Crash reporting | **E24** (wired in `main.dart`) + **E27** (full surface, redacted user ID) | |
| FR8 — Structured logging | **E24** (152 Talker call sites migrated to `AppLogger`; PII redactor rewrite) + **E27** (`no-raw-talker` lint) | |
| FR9 — Numerically correct displays | **E26** | All 7 enumerated wrong-number sites from T1.7. |
| FR10 — Sacred-time-aware notifications | **E26** | 14-day rolling batch + fire-time sacred check + timezone re-detect on resume. |
| FR11 — Sacred lock scope | **E26** | `SacredTimeLockOverlay` confined to post-auth shell. |
| FR12 — Stage definition fidelity | **E25** | Repository as only write path; weekly/rolling/delay fields all sync. |
| FR13 — Stage reorder safety | **E26** | Transactional reorder + Learn-at-position-1 guard. |
| FR14 — Portable data export | **E26** | All 23 tables, profileId on every row, no PII, per-profile import. |
| FR15 — Single completion writer | **E25** | `CompletionWriter.commit(CompletionCommand)`; one transaction; outbox-driven side effects. |
| FR16 — Single program-ref resolver | **E25** | `core/content/ProgramRefResolver`. |
| FR17 — Bulk-mark-prior streak abstention at all stages | **E26** | Stages 2 and 3 stop ticking streak (currently only stage 1 abstains). |
| FR18 — Hebrew UI as a locale | **E25** (`MaterialApp` infrastructure) + **E26** (translation completion) | |
| FR19 — Hebrew-terms preference per profile | **E25** | `core/preferences/HebrewTermsPreference`. |
| FR20 — Hebrew-date preference per profile | **E25** | `core/preferences/HebrewDatePreference`. |
| FR21 — Schema-v1 wipe-install boundary | **E25** | Wipe-install cutover; no v9→v(n) migration retained. |
| FR22 — Multi-account threading | **E25** (`currentAccountId` plumbing) + **E26** (account-picker UX) | |
| FR23 — Completion idempotency at storage | **E25** | Composite-natural-key UNIQUE + deterministic Firestore doc IDs. |
| FR24 — Outbox-based post-write events | **E25** | `OutboxProcessor`; replaces ad-hoc provider-invalidation lists. |

#### Non-Functional Requirements (26)

| NFR | Covered by | Notes |
|---|---|---|
| NFR1 — Single source of truth | **E25** (establishes the truth-table); enforced across all epics | Principle P1. |
| NFR2 — Strict layering | **E25** (refactor) + **E27** (`no-feature-cross-import` lint) | Principle P2. |
| NFR3 — Firebase confinement | **E24** (initial extraction) + **E27** (`no-firebase-outside-core` lint) | Principle P2 + T1.5. |
| NFR4 — Event-sourced vs snapshot pattern | **E25** | Principle P3. |
| NFR5 — Idempotent writes | **E25** | Principle P3 + T1.2 collision corollary. |
| NFR6 — No half-finished | **E26** (dead code purge) + **E27** (CI grep gates) | Principle P4. |
| NFR7 — Observability | **E24** (Crashlytics) + **E27** (analytics, structured logging, lint) | Principle P5. |
| NFR8 — God-object cap | **E26** (refactor 4 god-objects) + **E27** (SLOC + complexity lints) | T2.1. |
| NFR9 — DAO consistency | **E25** | `BaseDao<T>` + `TrackScope`. |
| NFR10 — Real FKs | **E25** | Bookmark uses `trackId` FK. |
| NFR11 — Performance | **E25** (composite indexes) + **E26** (remaining pagination) | T2.10. |
| NFR12 — Test pyramid | **E27** | 60% unit / 25% DAO / 10% widget+golden / 5% E2E. |
| NFR13 — 10 named integration tests | **E27** | |
| NFR14 — ARB parity | **E26** (Hebrew translation completed) + **E27** (parity CI gate) | |
| NFR15 — Naming consistency | **E26** | unit→3 names; Profiles→Accounts/LearnerProfiles; Gregorian→English. |
| NFR16 — RTL discipline | **E26** (audit) + **E27** (direction-aware lint) | |
| NFR17 — Custom lints (4) | **E27** | |
| NFR18 — CI surface | **E27** | |
| NFR19 — `make audit` | **E27** | |
| NFR20 — SyncEngine decomposition | **E25** | 7 focused classes. |
| NFR21 — Time discipline (`LocalDayClock`) | **E25** | |
| NFR22 — ContentIndex (indexed map lookup) | **E25** | |
| NFR23 — No empty catches | **E26** (cleanup) + **E27** (lint gate) | |
| NFR24 — No print/debugPrint | **E27** | |
| NFR25 — UTC storage | **E25** (preserves existing Pattern P5) | |
| NFR26 — Firestore doc-id determinism | **E25** | |

#### Additional Requirements (14)

| AR | Covered by | Notes |
|---|---|---|
| AR1 — Greenfield permission scope | **E25** (cutover) | |
| AR2 — Firestore v1 layout | **E25** | |
| AR3 — Local DB v1 schema | **E25** | |
| AR4 — Composite indexes (hot paths) | **E25** | |
| AR5 — Schema check tooling | **E27** | `tool/schema_check.dart`. |
| AR6 — Firestore emulator rules tests | **E27** | |
| AR7 — Crashlytics provisioning | **E24** | |
| AR8 — Analytics events (≥12) | **E27** | |
| AR9 — ARB parity tooling | **E26** (translations) + **E27** (CI gate) | |
| AR10 — Cloud Functions for deletes | **E25** (rules deny direct deletes); Cloud Function implementation deferred to first use case | |
| AR11 — Outbox table | **E25** | |
| AR12 — Sacred window persistence | **E26** | |
| AR13 — Pubspec changes (Noto Sans Hebrew bundled) | **E25** | |
| AR14 — Linear epic numbering | **meta** (governs this document; rebuild epics = 24–27) | |

#### UX Design Requirements (23)

| UX-DR | Covered by | Notes |
|---|---|---|
| UX-DR1 — Locale auto-detection | **E25** | |
| UX-DR2 — Direction-aware rendering | **E25** | `CurriculumLabel` reads `Directionality.of(context)`. |
| UX-DR3 — Preference placement (Settings, not onboarding) | **E26** | |
| UX-DR4 — Theme correctness (real darkTheme; color aliases) | **E26** | |
| UX-DR5 — RTL widget audit | **E26** | ~80–100 sites. |
| UX-DR6 — Date pickers (English/Hebrew) | **E26** | |
| UX-DR7 — Notification locale at fire time | **E26** | |
| UX-DR8 — PIN keypad ARB labels | **E26** | |
| UX-DR9 — Hebrew ARB completion | **E26** | |
| UX-DR10 — Track-card canonical layout | **E26** | All 4 data shapes → one widget tree. |
| UX-DR11 — Progress overview tappable stats | **E26** | |
| UX-DR12 — StreakCalendar honors ranges | **E26** | |
| UX-DR13 — StreakHistoryScreen | **E26** | |
| UX-DR14 — Mixed-script cleanup | **E26** | |
| UX-DR15 — No fake "+XP" | **E26** | |
| UX-DR16 — Dashboard decomposition | **E26** | |
| UX-DR17 — Add-track flow decomposition | **E26** | |
| UX-DR18 — Onboarding decomposition | **E26** | |
| UX-DR19 — Reader purity | **E26** | |
| UX-DR20 — Offline UX parity | **E26** | Inherited from Epic 19; preserved. |
| UX-DR21 — `PreferenceListTile` primitive | **E26** | |
| UX-DR22 — PIN flow consolidation | **E26** | |
| UX-DR23 — Curriculum activation guard surfaced in UI | **E26** | |

**Coverage assertion:** 24/24 FRs, 26/26 NFRs, 14/14 ARs, 23/23 UX-DRs — 87/87 requirements covered by at least one epic.

## Epic List

### Epic 24 — Stop-the-Bleeding (Phase 0)

**User outcome:** Internal testers stop being silently exposed to the highest-severity defects — cross-profile data bleed, weak Firestore rules, lost Google sessions on sign-out, untraceable crashes, and silent track-deletion data loss. The app keeps running under the existing schema; no wipe-install required for this epic.

**Why it ships first:** All E24 fixes can land under the v9 schema with no migration. They close data-loss and security holes immediately, giving us a safer baseline for the E25 wipe-install. None of them require the new core to be built first.

**FRs covered:** FR1 (band-aid), FR4 (Phase-0 split), FR5 (delete cascading + soft-delete tracks), FR6, FR7, FR8.
**NFRs covered:** NFR3 (initial extraction), NFR7 (Crashlytics wired).
**ARs covered:** AR7.

**Definition of done:**
- `firestore.rules` per-collection split, emulator tests pass.
- `completionDao.deleteByTrack` deleted; track delete is soft-delete only.
- Zero `FirebaseAuth.instance.*` calls outside `lib/core/auth/`.
- Zero `import 'package:talker/talker.dart'` outside `lib/core/logging/`.
- PII redactor rewritten to extract structured fields (no substring matching).
- Crashlytics wired in `main.dart` before any other init; first crash from a tester device appears in Crashlytics.
- Runtime profileId assertions added to all 6 `CompletionDao` cross-profile methods.

**Sizing:** 2–3 days. ~6–8 stories.

**Dependencies:** None. Ships first under existing schema.

---

### Epic 25 — Schema + Core Foundation (Phases 1 + 2)

**User outcome:** A clean, profile-isolated, locale-aware foundation. After the wipe-install at the start of this epic, the app has correct data ownership, idempotent two-device sync, single-source-of-truth labels, locale auto-detection (English and Hebrew), a single completion writer, an event-sourced streak system, and a SyncEngine that's no longer a 2921-line god-object. Features still LOOK the same to users (E26 reorganizes the UI on top), but the bones underneath are now right.

**Why it ships second:** This is where the rebuild's "model project" property is established. Wipe-install testers re-onboard end-to-end onto schema v1 + Firestore v1. All of E26's feature work depends on E25's core being correct, so E25 must complete before E26 begins (E26 stories may scaffold in parallel but cannot merge until E25 lands).

**FRs covered:** FR1 (real fix), FR2, FR3, FR4 (full shape), FR5 (schema-level), FR12, FR15, FR16, FR18 (infrastructure), FR19, FR20, FR21, FR22 (core), FR23, FR24.
**NFRs covered:** NFR1, NFR2 (refactor), NFR4, NFR5, NFR9, NFR10, NFR11 (composite indexes), NFR20, NFR21, NFR22, NFR25 (preserves), NFR26.
**UX-DRs covered:** UX-DR1, UX-DR2.
**ARs covered:** AR1, AR2, AR3, AR4, AR10 (rules deny), AR11, AR13.

**Definition of done:**
- Local DB v1 schema lives in `lib/core/database/`; v9 schema deleted; one tester wipe-installs and re-onboards end-to-end successfully.
- Firestore emulator rules tests pass against v1 rules.
- `core/` builds with zero `features/` imports.
- Every Tier-1 critical (T1.1–T1.10) has a passing unit and/or integration test.
- `sync_engine.dart` replaced by 7 focused classes (`FirestoreGateway`, `PushPipeline`, `PullPipeline`, `MergeRouter`, sealed `EntityMerger<T>` strategies, `ListenerSupervisor`, `LifecycleObserver`).
- Hebrew UI infrastructure live: `MaterialApp(supportedLocales: [en, he])`, `Directionality.of(context)`-aware `CurriculumLabel`, Noto Sans Hebrew bundled and rendering.
- `CompletionWriter.commit()` is the only completion write path; one transaction; outbox-driven side effects.

**Sizing:** 8–12 days. ~18–22 stories.

**Dependencies:** Blocked by Epic 24 (must close the worst data-loss holes before wipe-install). Blocks Epic 26.

---

### Epic 26 — Feature Rebuilds + Cleanups (Phases 3 + 4)

**User outcome:** Users get a coherent UI without fake numbers, broken navigation, inconsistent naming, mixed-script untranslated strings, or RTL bugs. The dashboard shows correct totals; the track card has one canonical layout for all 4 data shapes; the streak calendar honors its date range; Progress overview stats are tappable; the add-track flow is no longer 4400 lines; notifications respect sacred time at fire time; Hebrew UI is fully translated end-to-end; dead code is gone.

**Why it ships third:** Features in this epic consume the new core from E25. The 8 feature areas (P3.1–P3.8) plus the cross-cutting cleanups (P4: label bypasses, ARB completion, naming sweep, dead-code purge) all depend on `core/` being in its final shape. Hebrew translation completes here on top of the locale infrastructure from E25.

**FRs covered:** FR9, FR10, FR11, FR13, FR14, FR17, FR18 (translation), FR22 (UX).
**NFRs covered:** NFR2 (continues), NFR6 (dead code purge), NFR8 (god-object refactors), NFR11 (remaining pagination), NFR14 (Hebrew completion), NFR15, NFR16 (audit), NFR23 (cleanup).
**UX-DRs covered:** UX-DR3 through UX-DR23 (all except UX-DR1, UX-DR2 which are in E25).
**ARs covered:** AR9 (translations), AR12.

**Definition of done:**
- All 8 feature areas refactored (P3.1 Scheduler, P3.2 Dashboard, P3.3 Add-track, P3.4 Onboarding, P3.5 Learning+Content+Reader, P3.6 Progress+Lifetime+Gamification+Streak UI, P3.7 Settings+Profiles+Parent, P3.8 Notifications+Sacred+Stages).
- 4 god-objects below 600 SLOC each.
- Zero hardcoded `Text('...')` strings outside whitelist; `app_en.arb` and `app_he.arb` have parity.
- Zero `EdgeInsets.only(left:|right:)`, `Alignment.centerLeft|centerRight`, `TextAlign.left|right` (per the RTL discipline).
- All 7 wrong-number sites from T1.7 corrected.
- ≥10 000 LOC of dead code deleted.
- Naming sweep complete: `unit` → 3 distinct names, `Profiles`/`UserProfiles` → `LearnerProfiles`/`Accounts`, "Gregorian" → "English" in UI, single notification taxonomy.

**Sizing:** 13–19 days. ~26–32 stories.

**Dependencies:** Blocked by Epic 25. Partially overlaps with Epic 27 scaffolding.

---

### Epic 27 — Discipline & Closure (Phases 5 + 6 + 7)

**User outcome:** Future development on this project — especially AI-agent-driven — stays correct and consistent. The test pyramid catches regressions before they ship. CI lint+grep+coverage gates prevent the kind of drift the rebuild had to fix. Observability surfaces real problems in production. The architecture doc finally matches the code. This is the epic that locks the "model project" property in.

**Why it ships fourth (but partly parallel):** Test scaffolding, lint rules, and CI jobs can be authored in parallel with Epic 26; the coverage floor and arch-doc rewrite are the tail. Crashlytics was wired in E24 — this epic completes the observability surface (analytics, structured-logging adoption, custom lints).

**FRs covered:** FR4 (emulator gate), FR7 (full surface), FR8 (lint enforcement).
**NFRs covered:** NFR2 (lint), NFR3 (lint), NFR6 (CI gates), NFR7 (analytics + lint), NFR8 (SLOC + complexity lints), NFR12, NFR13, NFR14 (parity gate), NFR16 (direction-aware lint), NFR17, NFR18, NFR19, NFR23 (lint gate), NFR24.
**ARs covered:** AR5, AR6, AR8, AR9 (CI gate).

**Definition of done:**
- 10 named integration tests passing (bulk-mark-prior-no-streak, reducer-reconciles, multi-profile-isolation, track-card-canonical-layout, firestore-rules, offline-completion-flush, pin-lockout-cycle, log-redaction, bookmark-advance-atomic, cloud-restore-preserves-streak).
- 4 custom lints landed and enforced (`no-curriculum-display-name-bypass`, `no-feature-cross-import`, `no-firebase-outside-core`, `no-raw-talker`).
- Test pyramid composition target met: ~60% unit / 25% DAO / 10% widget+golden / 5% integration; line-coverage floor of 60% enforced; coverage cannot drop on a PR.
- CI matrix complete: `analyze`, `format-check`, `audit` (greps), `lint` (custom_lint), `test`, `coverage-floor`, `firestore-rules` (emulator), `golden`, `arb-parity`.
- `make audit` Makefile target runs every grep/lint check locally.
- 12 analytics events wired and firing.
- `docs/architecture.md` rewritten to match the rebuild reality; zombie features (`tutor_mode`, `test_tracking`) removed; schema version / guard count / aggregator count corrected; table list generated from Drift annotations where possible.

**Sizing:** 6–10 days. ~12–16 stories.

**Dependencies:** Blocked by Epic 25 (core must be in shape before tests pin it down). Partially overlaps with Epic 26.

---

### Epic dependency graph

```
E24 ── ships first, unblocks ──▶ E25 ── wipe-install, unblocks ──▶ E26 ─┐
                                          └──── unblocks ────▶ E27 ◀────┘  (E27 may overlap with E26 in the second half)
```

## Epic 24: Stop-the-Bleeding (Phase 0)

Close the highest-severity data-loss / security holes under the existing schema. No migration. Each story is independently shippable in 2–8 hours.

### Story 24.1: Per-collection Firestore rules with field validators and emulator test job

As an internal tester relying on Firestore-side integrity,
I want Firestore rules rewritten per-collection with create-only event collections, field-validator clamps, snapshot-whitelist updates, and delete denial,
So that an authenticated user cannot inject `points: 999_999`, future-dated completions, arbitrary fields, or delete history — closing T1.3.

**Acceptance Criteria:**

**Given** `firestore.rules` currently ships one wildcard `learner_profiles/{profileId}/{document=**}` rule with `allow read, write: if isOwner(uid)`,
**When** the rules are rewritten,
**Then** `completions/{id}` allows `create` only when `request.resource.data.points >= 0 && request.resource.data.points <= 100 && request.resource.data.completedAt <= request.time`
**And** `streak_events/{id}` and `learning_ledger/{id}` allow `create` only with timestamp clamps to `request.time`
**And** `settings/{id}` allows `update` with a field whitelist (`hebrewTerms`, `useHebrewDate`, etc.)
**And** every collection denies `delete` (deletes go through Cloud Functions)
**Given** the Firestore emulator is configured in CI,
**When** the `firestore-rules` CI job runs,
**Then** each rule's allowed and denied cases pass in the emulator test suite
**And** the CI pipeline fails on any rule regression.

### Story 24.2: Soft-delete tracks; stop cascading into append-only tables

As a learner whose track I deleted by mistake,
I want my completion history, streak events, and learning ledger preserved when I delete a track,
So that the delete doesn't get silently rolled back by Firestore on next sync (T1.4) and my cross-curriculum stats survive — closing the append-only invariant violation.

**Acceptance Criteria:**

**Given** `completionDao.deleteByTrack` exists and `trackDao.deleteTrack` calls it,
**When** this story lands,
**Then** `completionDao.deleteByTrack` is deleted entirely
**And** `trackDao.deleteTrack` performs a soft delete by setting a non-null `deletedAt` timestamp on `curriculum_tracks`
**And** `trackDao.getActiveTracks` filters out rows where `deletedAt IS NOT NULL`
**Given** a Drift migration adds the `deletedAt` column to `curriculum_tracks`,
**When** existing rows are migrated,
**Then** all existing rows get `deletedAt = NULL`
**Given** a user deletes a track,
**When** the deletion completes,
**Then** the user's prior completions remain in `completions` and continue to feed `CrossCurriculumAggregator`
**And** no rows are deleted from `streak_events` or `learning_ledger`.

### Story 24.3: Centralize sign-out through AuthRepository

As an internal tester signing in with Google,
I want Sign Out to clear my Google session in addition to my Firebase session,
So that the next Google sign-in shows the account picker rather than silently re-authenticating me as the previously-signed-out user — closing T1.5.

**Acceptance Criteria:**

**Given** 8 production call sites directly invoke `FirebaseAuth.instance.signOut()` (`sign_in_screen.dart`, `account_picker_screen.dart`, `signup_screen.dart`, `auth_state_provider.dart`, `magic_link_service.dart`, `device_restore_service.dart`, and 2 others),
**When** this story lands,
**Then** every call site invokes `AuthRepository.signOut()` instead
**And** `AuthRepository.signOut()` performs `FirebaseAuth.instance.signOut()` followed by `_googleSignIn.signOut()`
**And** `grep -rn 'FirebaseAuth\.instance\.signOut' lib/ --exclude-dir=core/auth` returns zero results
**Given** a user signed in with Google taps Sign Out,
**When** they later return to the Google sign-in flow,
**Then** the Google account picker appears (rather than auto-selecting the cached account).

### Story 24.4: Wire Crashlytics in main.dart before any other init

As an operator monitoring tester crashes,
I want uncaught Flutter and Dart errors reported to Crashlytics with profileId as the user identifier,
So that I have something to investigate when a tester's device crashes beyond Talker's 2000-entry ring buffer — closing the worst gap from T1.6.

**Acceptance Criteria:**

**Given** Firebase Crashlytics is enabled in the Firebase console for both Android apps,
**When** `main.dart` is restructured,
**Then** `await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true)` runs before any other init that can throw
**And** `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError` is set
**And** `PlatformDispatcher.instance.onError = (err, st) { FirebaseCrashlytics.instance.recordError(err, st, fatal: true); return true; }` is set
**Given** a user is signed in with `profileId = 5`,
**When** an uncaught error occurs,
**Then** `FirebaseCrashlytics.instance.setUserIdentifier('5')` has been called previously (numeric profileId only, no email or other PII)
**And** the crash appears in the Crashlytics dashboard within 5 minutes of fire
**Given** the user has not yet signed in,
**When** an uncaught error occurs,
**Then** the crash is reported with no user identifier set (rather than re-crashing during reporting).

### Story 24.5: Migrate sync_engine and OfflineQueue to AppLogger; rewrite PII redactor

As an operator reviewing production logs,
I want all 152 sync-engine and offline-queue log sites flowing through `AppLogger` with structured field-level redaction,
So that emails, profile IDs, completion payloads, and Firestore IDs stop leaking, and operational logs that mention "pin" or "email" stop being silently nuked — closing the redactor inversion in T1.6.

**Acceptance Criteria:**

**Given** `sync_engine.dart` and `OfflineQueue` currently import `package:talker/talker.dart` directly and call `talker.info/warning/error` at 152 sites,
**When** this story lands,
**Then** every site is migrated to `AppLogger.info(event: '...', fields: {...})` with structured fields
**And** `grep -rn "import 'package:talker/talker\.dart'" lib/ --exclude-dir=core/logging` returns zero results
**Given** the existing PII redactor does substring-matching on rendered messages,
**When** the redactor is rewritten,
**Then** it operates on the `fields` map with a per-key allowlist (e.g. `userEmail`, `pinHash`, `accessToken`, `firebaseUid` are redacted; `event` and arbitrary other fields are preserved)
**And** the previously-dead `pinPattern` regex is either invoked correctly or removed entirely
**And** a unit test asserts: logging `{event: 'PIN setup screen opened'}` preserves the event verbatim
**And** logging `{event: 'sign_in_attempted', fields: {userEmail: 'foo@bar.com', method: 'google'}}` redacts only the email value, preserving the event and `method`.

### Story 24.6: Multi-profile leak band-aid via cross-profile scope assertions

As a parent of a child learner sharing a device,
I want all `CompletionDao` cross-profile methods to require an explicit scope justification at call time,
So that Profile A's completions cannot silently surface in Profile B's dashboard until E25 closes the leak at the schema level — band-aid for T1.1.

**Acceptance Criteria:**

**Given** `CompletionDao` exposes 6 cross-profile methods (`getAllCompletions`, `getCompletionsByCurriculum`, `getCompletionsForContent`, `getCompletionsByDateRange`, `hasCompletionsInDateRange`, `getAggregateCount`, `getTrackBreakdown`),
**When** this story lands,
**Then** each method gains a required `CrossProfileScope` parameter with values `{adultAggregation, parentAnalytics, dataExport, syncRestore}`
**And** each method asserts the scope is non-null at call time (in debug throws `AssertionError`; in release logs a structured warning to Crashlytics breadcrumbs)
**And** in debug builds, a structured event `{event: 'cross_profile_read', scope, callerHash}` is logged on every cross-profile call
**Given** every existing call site in `sync_engine.dart`, `device_restore_service.dart`, `data_export_import_service.dart`, `restore_guard.dart`, `progress_repository_impl.dart` is reviewed,
**When** the migration completes,
**Then** each call site passes an explicit `CrossProfileScope` value matching its purpose
**And** a unit test asserts calling a cross-profile method without a scope throws `AssertionError` in debug mode.

---

## Epic 25: Schema + Core Foundation (Phases 1 + 2)

The wipe-install boundary. After E25 ships, the user DB and Firestore are at schema v1, the 10 `core/` subsystems are rebuilt, and the Hebrew UI locale infrastructure is live. Features still look the same to users — E26 reorganizes the UI on top of this foundation.

### Story 25.1: Schema-v1 user DB skeleton (renamed tables, profileId PKs, no defaults, FKs)

As a developer building on the rebuilt data layer,
I want the user DB at schema v1 with `LearnerProfiles`/`Accounts` table names, `profileId` in every profile-scoped primary key with no default value, and real foreign keys on track-bound tables,
So that the multi-profile leak (T1.1) is closed at the schema level and callers physically cannot forget a `profileId`.

**Acceptance Criteria:**

**Given** the v9 schema exists with `withDefault(const Constant(0))` on 8 profile-scoped tables,
**When** schema v1 lands,
**Then** `Profiles` is renamed to `LearnerProfiles` and `UserProfiles` to `Accounts` (architecture-doc-correct names)
**And** every profile-scoped table has `(profileId, ...)` as part of its primary key with NO `withDefault` clause
**And** `grep -rn '\.withDefault(const Constant(0))' lib/core/database/tables/` returns zero results
**And** `Bookmarks` uses a `trackId` foreign key (not a `trackType` string)
**And** all track-bound tables have real Drift `@References` annotations
**Given** the v9 schema is deleted (no migration code retained per AR1),
**When** the schema-v1 build runs against a fresh device,
**Then** all DAOs compile and basic CRUD smoke tests pass.

### Story 25.2: Append-only event tables with composite-natural-key UNIQUEs

As the data-integrity invariant,
I want `completion_events`, `streak_events`, and `learning_ledger` to be append-only at the schema level with composite-natural-key UNIQUE indexes,
So that two devices writing the same logical event collapse to one row (closing the streak collision corollary of T1.2) and no public delete API exists (FR5).

**Acceptance Criteria:**

**Given** schema v1 is in place,
**When** the three event tables are defined,
**Then** `completion_events` has a UNIQUE composite index on `(profileId, sefariaRef, stageId, trackType)`
**And** `streak_events` has a UNIQUE composite index on `(profileId, dayUtc, eventType)`
**And** `learning_ledger` has a UNIQUE composite index on `(profileId, ulid)`
**And** none of the three DAOs expose a `delete*` method publicly (private helpers permitted for testing)
**Given** two simulated devices write the same natural key concurrently,
**When** both writes commit,
**Then** SQLite's `INSERT OR IGNORE ON CONFLICT` lands one row, not two
**And** a unit test asserts that duplicate inserts return the same `id` rather than throwing.

### Story 25.3: Composite indexes on hot-path queries

As a user opening the dashboard,
I want hot-path queries (dashboard load, scheduler analysis, lifetime aggregation) to be served by composite indexes,
So that startup and dashboard interactions stay under their performance budget (T2.10).

**Acceptance Criteria:**

**Given** the dashboard reads `completions` filtered by `profileId` and `curriculumId` ordered by `completedAt DESC`,
**When** this story lands,
**Then** a composite index `completions_pidx_pid_cur_completed` exists on `(profileId, curriculumId, completedAt DESC)`
**And** a composite index on `(profileId, sefariaRef, stageId, trackType)` exists and is UNIQUE (also satisfies Story 25.2)
**And** an index on `learning_ledger(profileId, createdAt)` exists
**And** an index on `streak_events(profileId, dayUtc, eventType)` exists and is UNIQUE
**Given** the indexes are queried via `EXPLAIN QUERY PLAN`,
**When** dashboard load runs,
**Then** the plan reports `SEARCH ... USING INDEX` rather than `SCAN TABLE` for the three hot-path queries.

### Story 25.4: Firestore v1 collection layout and per-collection rules

As a developer building the sync layer,
I want top-level Firestore collections with deterministic doc IDs and per-collection security rules,
So that the rules enforce create-only event collections, snapshot whitelists, and delete denial — completing FR4 to its final shape and replacing the Phase-0 split from Story 24.1.

**Acceptance Criteria:**

**Given** Firestore v1 is provisioned (no `users/{uid}/` nesting),
**When** the collections are defined,
**Then** top-level collections exist: `accounts`, `learner_profiles`, `completion_events`, `streak_events`, `learning_ledger`, `track_configs`, `bookmarks`, `settings`
**And** every event collection uses a deterministic doc ID of the form `{uid}_{profileId}_{kind}_{naturalKey}` (e.g. `{uid}_{profileId}_{sefariaRef}_{stageId}_{trackType}`)
**And** every snapshot collection uses `{uid}_{profileId}[_{scope}]`
**Given** rules are rewritten,
**When** the emulator test suite runs,
**Then** snapshot collections (`settings`, `learner_profiles`, `bookmarks`, `track_configs`) allow `update` with field whitelists
**And** event collections allow `create` only with field validators (per Story 24.1)
**And** all collections deny `delete` (route through Cloud Functions)
**And** every rule has at least one allowed-case and one denied-case test in the emulator suite.

### Story 25.5: Outbox table and OutboxProcessor scaffolding

As the sync-write invariant,
I want a local `outbox` table that captures pending Firestore mutations atomically with the local write,
So that the cross-feature event cascade (gamification → progress → sync → streak) is outbox-driven rather than provider-cascade-driven (FR24, T2.7).

**Acceptance Criteria:**

**Given** schema v1 is in place,
**When** this story lands,
**Then** an `outbox` table exists with columns `(id, profileId, entityKind, entityKey, payload, createdAt, attempts, lastError, lastAttemptAt)`
**And** an `OutboxProcessor` class drains pending rows by `entityKind` and dispatches to the appropriate `PushPipeline.pushX` method (built in Story 25.12)
**Given** a write commits an event row,
**When** the same DB transaction completes,
**Then** an outbox row is inserted in the same transaction (no fire-and-forget)
**And** if the outbox insert fails, the entire transaction rolls back (the event row is not committed)
**Given** the device is offline,
**When** the user marks 50 completions,
**Then** 50 outbox rows accumulate
**And** when the device reconnects, the OutboxProcessor drains them in batches.

### Story 25.6: Schema-check tool to enforce profileId-in-PK and composite-index invariants

As a developer trusting that future PRs cannot reintroduce the multi-profile leak,
I want a `tool/schema_check.dart` script that parses Drift table annotations and asserts every profile-scoped table has `profileId` in the primary key and at least one composite index,
So that Story 25.1's gains are protected by tooling (NFR1, AR5).

**Acceptance Criteria:**

**Given** `tool/schema_check.dart` exists,
**When** it runs against the v1 schema,
**Then** it parses every `@DataClassName` and `@TableIndex` annotation in `lib/core/database/tables/`
**And** asserts every table whose name appears in a whitelist of profile-scoped tables has `profileId` declared in `primaryKey`
**And** asserts every such table has at least one composite `@TableIndex` (or composite `UNIQUE` constraint)
**And** exits with non-zero status on violation, printing the offending table names
**Given** a developer adds a new profile-scoped table missing `profileId` in the PK,
**When** the schema-check runs locally or in CI,
**Then** the violation is reported with the table name and a remediation hint.

### Story 25.7: `core/preferences/` — six ProfileScopedPreference primitives

As a developer needing to read user preferences without coupling to feature code,
I want six `ProfileScopedPreference<T>` primitives (`HebrewTerms`, `TransliterationVariant`, `Nikud`, `AppLocale`, `TextDisplay`, `HebrewDate`) living in `core/preferences/`,
So that `core/labels/` and other core modules can depend on preferences without inverting the layering (T2.2).

**Acceptance Criteria:**

**Given** the six preference concepts currently live in `features/settings/` or as hardcoded provider defaults,
**When** this story lands,
**Then** each preference is a class `ProfileScopedPreference<T>` with `(read, write, observe)` methods backed by a versioned snapshot column in `profile_settings`
**And** all six preference classes live in `lib/core/preferences/`
**And** the `profileId == 0 ? mirror : true` Hebrew-terms hardcode in `hebrew_terms_provider.dart:32` and `hebrew_date_provider.dart:31` is deleted
**And** new profiles default to `hebrewTerms: false` and `useHebrewDate: false`
**And** `grep -rn 'hebrewTermsScriptProvider' lib/ --exclude-dir=core/labels --exclude-dir=core/preferences --exclude=settings/.*_screen\.dart` returns zero results (the toggle is read only from `core/`)
**Given** a per-profile preference is changed in Settings,
**When** the user switches profiles,
**Then** the new profile loads its own preference values (no global leakage).

### Story 25.8: `core/content/ContentIndex` — indexed lookup for 9 curricula

As any code path that needs a `ContentItem` by `sefariaRef`,
I want a single `ContentIndex` keepAlive provider serving `Map<sefariaRef, ContentItem>` lookups across all 9 curricula,
So that `CurriculumLabel.breadcrumb()` and similar lookups become O(1) instead of walking 52K rows (T2.3, NFR22).

**Acceptance Criteria:**

**Given** content for 9 curricula is currently loaded lazily by separate per-curriculum providers,
**When** this story lands,
**Then** `core/content/ContentIndex` is a `keepAlive` Riverpod provider holding `Map<String /* sefariaRef */, ContentItem>` populated from all 9 curricula's content lists at first access
**And** `ContentIndex.lookup(sefariaRef)` returns the item or null in O(1)
**And** `ContentIndex.adjacent(sefariaRef)` returns previous/next items without walking 9 curricula lists
**And** `core/content/ProgramRefResolver` (built on `ContentIndex`) exposes `resolve(programId, dayOffset)` → `sefariaRef` so dashboard, scheduler, and reader share one matcher — closing T1.7's "fall back to human-readable display string persisted as a sefariaRef → broken reader" bug (FR16)
**Given** the dashboard and reader perform breadcrumb lookups,
**When** they read through `ContentIndex`,
**Then** the prior O(N×9) scan in `CurriculumLabel.breadcrumb()` is eliminated
**And** a benchmark unit test asserts lookup completes in < 1ms after first cache warmup.

### Story 25.9: `core/labels/` rebuild — three new modes, ContentIndex consumer, static API deleted

As any UI code rendering a curriculum / track / level / item label,
I want one `CurriculumLabel` widget with modes `curriculum(CurriculumId)`, `trackType(TrackType)`, `calendarProgram(CalendarProgramId)`, `learningProgram(LearningProgramId)`, `level(...)`, `breadcrumb(sefariaRef)` — all picking direction from `Directionality.of(context)`,
So that the three parallel dual-field families (`TrackType.displayName*`, `CalendarProgramEntry.displayName*`, `LearningProgram.displayName*`) and the old static API are collapsed into one source of truth (NFR1).

**Acceptance Criteria:**

**Given** the existing static `CurriculumLabels.curriculumName(useHebrew:)` API is still used in 13 call sites and 17 files still read `hebrewTermsScriptProvider` directly,
**When** this story lands,
**Then** `CurriculumLabel` widget exposes the six modes above
**And** every mode reads direction from `Directionality.of(context)` and Hebrew-terms preference via `HebrewTermsPreference`, never via inline ternaries
**And** the static `CurriculumLabels.*` API is deleted
**And** `grep -rn '\bdisplayName\(En\|He\)\b' lib/ --exclude-dir=core/labels` returns only generated-file matches (`.g.dart`, `.freezed.dart`)
**Given** a label is requested via `CurriculumLabel.trackType(TrackType.personal)`,
**When** the locale is `en` with Hebrew-terms off,
**Then** the rendered text is the transliterated English name
**And** when locale is `he` (or Hebrew-terms is on), the rendered text is the Hebrew script with RTL directionality.

### Story 25.10: `core/time/LocalDayClock` — single time provider

As any code that reads "today's local date",
I want one `LocalDayClock` provider with test-override capability,
So that day-boundary semantics are consistent across streak, scheduler, dashboard, and tests (NFR21, root cause of T1.2's timezone divergence).

**Acceptance Criteria:**

**Given** the codebase currently calls `DateTime.now()`, `DateTimeFactory.nowUtc().toLocal()`, and `DateUtils.extractLocalDate` from many sites,
**When** this story lands,
**Then** `LocalDayClock` is the only public provider for "today's local date"
**And** the clock takes a deterministic test seed via Riverpod override
**And** `grep -rn 'DateTime\.now\(\)' lib/ --exclude-dir=core/time` returns zero results
**Given** a test overrides the clock to `2026-05-13 23:30 Asia/Jerusalem`,
**When** the streak reducer reads today's date,
**Then** it reads `2026-05-13` consistently regardless of the host machine's timezone.

### Story 25.11: `core/auth/AuthRepository` — sole Firebase Auth consumer

As the only entry point for authentication,
I want `core/auth/AuthRepository` to be the only file in the project importing `package:firebase_auth/firebase_auth.dart`,
So that NFR3 (Firebase confinement) holds at the source level and Story 24.3's gains are locked in.

**Acceptance Criteria:**

**Given** Story 24.3 migrated 8 sign-out call sites,
**When** this story extends to all auth operations,
**Then** `AuthRepository` exposes `signIn(email, password)`, `signInWithGoogle()`, `signOut()`, `currentUser`, `onAuthStateChanged`
**And** `grep -rn 'package:firebase_auth' lib/ --exclude-dir=core/auth` returns zero results
**And** the `magic_link_service.dart`, `account_picker_screen.dart`, `auth_state_provider.dart` consume `AuthRepository` only
**Given** a developer adds a new sign-in surface,
**When** they need Firebase Auth,
**Then** they extend `AuthRepository` (not import `firebase_auth` directly).

### Story 25.12: SyncEngine decomposition Part 1 — FirestoreGateway, PushPipeline, PullPipeline

As a developer testing sync logic,
I want the 2921-line `sync_engine.dart` split into `FirestoreGateway` (only Firestore-symbol holder), `PushPipeline` (outbox drain + single-flight), `PullPipeline` (pagination + merge dispatch),
So that the sync subsystem becomes testable in isolation and the god-object is broken up (NFR20, T2.9).

**Acceptance Criteria:**

**Given** `sync_engine.dart` is 2921 lines with merged push, pull, listener, gateway, and lifecycle concerns,
**When** this story lands,
**Then** `core/sync/firestore_gateway.dart` is the only file importing `cloud_firestore`
**And** `core/sync/push_pipeline.dart` drains the `outbox` table per `entityKind`, with single-flight semantics (no overlapping pushes for the same kind)
**And** `core/sync/pull_pipeline.dart` paginates Firestore queries and dispatches results to the `MergeRouter` (Story 25.13)
**And** all three classes have unit tests using `fake_cloud_firestore`
**Given** the old `sync_engine.dart` exists,
**When** the migration completes,
**Then** the file is either deleted or thinned to a coordinator < 300 lines.

### Story 25.13: SyncEngine decomposition Part 2 — MergeRouter and sealed EntityMerger strategies

As a developer adding a new sync-able entity,
I want `MergeRouter` to dispatch to per-kind `EntityMerger<T>` sealed strategy classes,
So that adding a new entity is a one-file addition rather than a 12-touch sprawl (NFR20, T2.9).

**Acceptance Criteria:**

**Given** Story 25.12 produced `PullPipeline.handleBatch(List<Map<String,dynamic>>)`,
**When** this story lands,
**Then** `MergeRouter` dispatches by entity kind to an `EntityMerger<T>` implementation
**And** sealed strategies exist for `CompletionEventMerger`, `StreakEventMerger`, `LearnerProfileMerger`, `TrackConfigMerger`, `BookmarkMerger`, `SettingsMerger`, `StageDefinitionMerger`, each in its own file
**And** `StageDefinitionMerger` merges all fields (`scheduleType`, `daysOfWeek`, `rollingWindowSize`) — not just `delayDays` (closes T1.9)
**And** `MergeRules` is load-bearing (consulted by every merger), not vestigial
**Given** a new entity is added,
**When** a developer creates the merger,
**Then** they touch only the new merger file and the `MergeRouter` switch.

### Story 25.14: SyncEngine decomposition Part 3 — ListenerSupervisor and LifecycleObserver

As an offline-aware app,
I want `ListenerSupervisor` to own Firestore real-time listeners and `LifecycleObserver` to handle resume-time work (timezone re-detect, sacred-window recompute, trigger pull),
So that lifecycle behavior is testable and decoupled from the sync engine core (NFR20, T1.8 timezone re-detection).

**Acceptance Criteria:**

**Given** the old `sync_engine.dart` mixes listener setup with merge logic,
**When** this story lands,
**Then** `ListenerSupervisor` owns all `_listenerX` fields and exposes `start()` / `stop()` / `restart()`
**And** `LifecycleObserver` registers as a `WidgetsBindingObserver` and, on resume, re-detects timezone, invalidates `SacredWindow` cache (E26.24 dependency), and triggers `PullPipeline.pullLatest()`
**And** a unit test asserts `LifecycleObserver` correctly resets state on resume in a `WidgetsBinding` test harness
**Given** the device goes offline and back online,
**When** `ListenerSupervisor.restart()` runs,
**Then** listeners reattach without duplicate firing.

### Story 25.15: `core/learning/CompletionWriter` — single transactional commit path

As any UI that records a completion,
I want one `CompletionWriter.commit(CompletionCommand)` call that inserts the event-log row, the projection row, and the outbox row in one DB transaction,
So that completions are atomic, idempotent, and side-effect-driven via the outbox rather than via 14-provider invalidation cascades (FR15, T2.7).

**Acceptance Criteria:**

**Given** completion writes currently happen in multiple repositories with fire-and-forget side effects,
**When** this story lands,
**Then** `CompletionWriter.commit(CompletionCommand)` is the only path that writes completion data
**And** `CompletionCommand` is a freezed value type carrying `(profileId, sefariaRef, stageId, trackType, completedAt, points)` with no nullable identity fields
**And** the writer's transaction inserts: (1) one `completion_events` row, (2) one `completions` projection row (or updates if already present), (3) one or more `outbox` rows per affected downstream
**And** if any of the three inserts fails, the entire transaction rolls back
**Given** `text_display_screen.dart` and `completion_button.dart` currently maintain divergent 14-provider invalidation lists,
**When** the migration completes,
**Then** both screens invalidate a single `completionCommittedProvider` notifier (driven by the outbox) instead.

### Story 25.16: `core/streak/` — event log + reducer + round-trip sync

As the streak invariant holder,
I want `StreakEventLog` + `StreakReducer` (UTC days only) + `StreakStateProvider` + `StreakEventMerger`,
So that streak is computed deterministically from an append-only event log, syncs round-trip across devices, and reconstitutes from `completion_events` on empty-log restore (FR2, FR3).

**Acceptance Criteria:**

**Given** the v1.0.60 plan's reducer/sync work was partial and broken (reducer dead, UTC vs local-tz divergence, sync no-op),
**When** this story lands,
**Then** `StreakEventLog` is a thin wrapper over the `streak_events` DAO with a single `append(StreakEvent)` method
**And** `StreakReducer` reads `streak_events` and returns `(currentStreak, maxStreak)` using UTC day boundaries from `LocalDayClock`
**And** `StreakStateProvider` is the only read path for streak values (the synchronous `StreakService.recordCompletion` writes are removed)
**And** `StreakEventMerger` (from Story 25.13) pushes and pulls `streak_events` round-trip
**Given** a user signs in on a new device with an empty local `streak_events` log,
**When** restore runs,
**Then** the reducer reconstitutes events from `completion_events` (a `streak_events` row per distinct UTC day) before computing the value
**Given** two devices write completions on the same UTC day,
**When** both reach `streak_events`,
**Then** the UNIQUE constraint from Story 25.2 collapses them to one row.

### Story 25.17: `core/database/BaseDao<T>` and TrackScope; delete cross-profile DAO methods

As a developer writing a new DAO,
I want a generic `BaseDao<T>` providing `getById`, `getByProfile`, `count`, `exists`, plus a `TrackScope({trackId, profileId, curriculumId})` record threaded through queries,
So that the `getAllX` / `getXByProfile` / `getXByCurriculumAndProfile` triplet drift is eliminated and all cross-profile reads are intentional (NFR9, FR1).

**Acceptance Criteria:**

**Given** every DAO currently re-implements the same three query shapes,
**When** this story lands,
**Then** `BaseDao<T>` is a Dart mixin or generic base offering the four common methods
**And** every DAO that needs them uses `BaseDao<T>` (no duplicated implementations)
**And** the 6 cross-profile methods on `CompletionDao` are deleted (their callers now use the per-profile equivalents)
**And** `TrackScope` is a freezed record threaded through track-aware queries
**Given** a caller explicitly needs cross-profile aggregation (e.g. parent analytics),
**When** they query,
**Then** they use a dedicated `parentAnalyticsRepository` method that takes a `CrossProfileScope` parameter (per Story 24.6, now schema-enforced).

### Story 25.18: `core/navigation/` — typed auto_route + PinScope-parameterized guard

> ℹ️ **Historical framing.** Story 25.18 shipped as DNI-339 (Epic 25, Done 2026-05-14 — see `docs/linear-status.md`). The "Given" clause and the `ParentPinGuard`/`TutorPinGuard` names below describe the pre-story state this story replaced; those classes no longer exist in code. See `docs/stories/implementation/DNI-339-typed-auto-route-pinscope-guard.md` for the implementation record and `lib/core/navigation/guards/pin_guard.dart` for the current single `PinGuard(PinScope)`.

As a developer adding a new gated route,
I want typed auto_route generation and one composable `PinGuard(PinScope.{parent(profileId), tutor(profileId)})` rather than separate `ParentPinGuard`/`TutorPinGuard`,
So that guard duplication is removed and adding a new PIN-gated route is one line (NFR1, simplification of architecture-doc's 7 guards).

**Acceptance Criteria:**

**Given** the current router declares `ParentPinGuard` and `TutorPinGuard` separately,
**When** this story lands,
**Then** one `PinGuard` class takes a `PinScope` value and dispatches verification to `PinService`
**And** route declarations parameterize the guard via `PinGuard(PinScope.parent(profileId))`
**And** the count of distinct guards in `core/navigation/` is audited against the architecture doc's claim
**And** route declarations are fully typed (no string-based navigation in feature code).

### Story 25.19: `core/logging/` — finalize structured AppLogger and migrate remaining production logs

As an operator,
I want every production log call routed through `AppLogger.info(event, fields)` with the field-based redactor from Story 24.5 now applied across the whole app,
So that no raw `print` / `debugPrint` / `talker.X` survives outside `core/logging/` (NFR7, NFR24).

**Acceptance Criteria:**

**Given** Story 24.5 migrated 152 sites in sync-engine and offline-queue,
**When** this story extends the migration to the remaining production logs,
**Then** every `log` / `print` / `debugPrint` / direct `Talker` call outside `core/logging/` is migrated
**And** `grep -rn 'debugPrint\|^\s*print(' lib/ --include='*.dart' | grep -v '\.g\.dart'` returns zero results
**And** `grep -rn "import 'package:talker/talker\.dart'" lib/ --exclude-dir=core/logging` returns zero results across the entire codebase
**And** structured log events follow the `{event, profileId, accountTier, durationMs, status, ...}` shape per NFR7.

### Story 25.20: MaterialApp locale auto-detection + Noto Sans Hebrew bundling + direction-aware CurriculumLabel

As a user installing the app on a Hebrew-locale device,
I want the app UI to auto-resolve to Hebrew without me choosing a language,
So that Hebrew users get a native experience without any onboarding-time picker (FR18, UX-DR1, UX-DR2).

**Acceptance Criteria:**

**Given** `_selectedLanguage = 'en'` is hardcoded in `onboarding_screen.dart:78`,
**When** this story lands,
**Then** the hardcode is deleted (no replacement; Flutter handles locale resolution)
**And** `MaterialApp.supportedLocales = [Locale('en'), Locale('he')]` and `locale: null` (auto-resolution from `WidgetsBinding.window.locale`)
**And** `flutter_localizations` retains both `en` and `he`
**And** Noto Sans Hebrew font is bundled in `pubspec.yaml` (file actually included, not just declared)
**And** `AppTextStyles` uses `Noto Sans Hebrew` for Hebrew script with RTL directionality
**Given** a user installs the app on an Israeli phone,
**When** the app launches,
**Then** all `Localizations.localeOf(context)` calls return `he`
**And** `CurriculumLabel.curriculum(...)` renders Hebrew script with RTL directionality without any toggle being set
**Given** `AppTheme.darkTheme()` is currently a verbatim alias for `_lightTheme` and 20+ heritage*/child* color aliases coexist,
**When** a real dark theme is authored as part of theme-infrastructure work,
**Then** `AppTheme.darkTheme()` returns a Material 3 dark palette distinct from the light theme
**And** the 20+ heritage*/child* color aliases are consolidated into the new theme palette (light + dark)
**And** the app respects `MediaQuery.platformBrightnessOf(context)` to select theme (system-driven) (UX-DR4).

### Story 25.21: Multi-account threading — replace eight hardcoded currentAccountId = 1 sites

As a user with multiple accounts on one device,
I want the active account to be properly threaded through the data layer,
So that switching accounts (or having multiple accounts on a shared family device) actually loads the right account's data (FR22, completes Epic 21 plumbing).

**Acceptance Criteria:**

**Given** 8 call sites currently hardcode `currentAccountId = 1` with a `TODO(DNI-110)`,
**When** this story lands,
**Then** each site reads the active account from a `currentAccountProvider` backed by the `DeviceAccounts` table (already at v1 supporting 5 accounts/device)
**And** `grep -rn 'currentAccountId.*=.*1\b' lib/` returns zero results
**And** the account-picker screen wires through `currentAccountProvider`
**And** profile queries downstream of account context are filtered by both `accountId` and `profileId`
**Given** a device has 2 accounts (parent's and grandparent's),
**When** the user switches between them via the account picker,
**Then** profiles, completions, settings, and bookmarks load from the active account's user DB file (per Epic 19's per-account DB split)
**Given** Epic 19's offline UX (subtle top banner for cloud-born users temporarily offline; persistent "no backup" badge for local-born users) is being preserved through the rebuild,
**When** the rebuilt `AppShell` is wired,
**Then** the cloud-born offline banner appears only when the device is offline AND the active account tier is `cloudBorn`
**And** the "no backup" badge appears persistently in the profile area only when the active account tier is `localBorn` (UX-DR20, inherits from Epic 19).

### Story 25.22: Wipe-install cutover end-to-end verification

As an internal tester migrating to schema v1,
I want a full wipe-install onboarding to complete end-to-end without errors,
So that the migration cliff at the start of E26 is safe (FR21, AR1).

**Acceptance Criteria:**

**Given** schema v1 (user DB, content DB, device registry) and Firestore v1 are deployed,
**When** an internal tester wipes the app and reinstalls,
**Then** the onboarding flow completes (account creation, profile creation, curriculum activation, optional bulk-mark-prior)
**And** the dashboard renders with real data after onboarding
**And** sign-in on a second device pulls the freshly-created data from Firestore v1 collections
**And** all Crashlytics breadcrumbs from the onboarding flow are clean (no thrown exceptions)
**Given** the wipe-install tester runs for 24 hours,
**When** they record completions, mark prior items, and configure stages,
**Then** every write succeeds and reflects on the second device on next pull
**And** an integration test asserts the full flow against the emulator stack (Firebase Auth + Firestore + emulator rules).

---

## Epic 26: Feature Rebuilds + Cleanups (Phases 3 + 4)

Features consume the new core. Cross-cutting cleanups (label bypasses, hardcoded strings, naming sweep, dead code purge) and Hebrew translation completion land here.

### Story 26.1: Scheduler strategy pattern — SchedulerInput → SchedulerAnalysis → TaskAssembly

As a developer extending the scheduler,
I want `SchedulerInput` (value type) → `SchedulerAnalysis` (value type) → `TaskAssembly` produced by a `SchedulingStrategy` sealed class with cases `SelfPacedSnapshot`, `DeadlineGoal`, `LegacyAdaptive`, `ProgramCalendar`,
So that the 1269-line `scheduler_providers.dart` god-object becomes an ~80-line engine plus per-strategy modules (NFR8, T2.1).

**Acceptance Criteria:**

**Given** `scheduler_providers.dart` is currently 1269 lines mixing all four strategy paths,
**When** this story lands,
**Then** `SchedulerInput` and `SchedulerAnalysis` are freezed value types
**And** `SchedulingStrategy` is a sealed class with the four named cases
**And** `ChazaraScheduleType` strategies (delay/weekly/rolling) operate on `SchedulerAnalysis`
**And** the engine entry point is ~80 lines and selects the strategy by goal type
**And** unit tests cover each strategy in isolation.

### Story 26.2: Fix dashboardPaceStatusProvider with real total-items math

As a learner viewing my dashboard pace card,
I want the pace card to reflect real total-item counts (not `totalItems = personalCompletions.length + 100`),
So that the displayed pace status is meaningful — closing the first wrong-number site in T1.7.

**Acceptance Criteria:**

**Given** `dashboardPaceStatusProvider` currently computes `totalItems = personalCompletions.length + 100`,
**When** this story lands,
**Then** total items comes from the per-curriculum content tree size (or per-track scope's content count)
**And** pace status (ahead / on-track / behind) is computed from real `(completed / totalItems)` and real elapsed days
**And** a unit test asserts that for a learner with 200 completions out of 1000 items expected at day 100 of 500, the pace status is "behind" with the correct delta.

### Story 26.3: Scheduler classification + chazara-load + isStudyDay + day-1 rolling-window fixes

As a learner with a long backlog of items due for chazara,
I want the scheduler to not silently collapse my new-learning rate to 1/day, to classify brand-new items correctly (not as `overdueChazara`), to respect `isStudyDay`, and to handle the rolling-window day-1 case,
So that I get sane daily tasks — closing five more wrong-number sites in T1.7.

**Acceptance Criteria:**

**Given** the chazara-load math currently collapses to 1 new item/day for deep-backlog users,
**When** this story lands,
**Then** `_calculateNewItemsPerDay` is rewritten with explicit zero-floor handling
**And** a unit test asserts: a learner with 500-item backlog and a 50-item daily chazara load gets correct new-learning numbers (with a "deep backlog locks new learning to 1/day" boundary case)
**And** brand-new never-completed items in the snapshot path are classified as `dueNewLearning`, not `overdueChazara`
**And** the snapshot path checks `isStudyDay(today)` and emits empty task list on non-study days
**And** rolling-average windows handle day-1 correctly (no projection until ≥1 event exists)
**And** pace-goal `daysDelta` (`PaceDelta`) and deadline `daysDelta` (`DateDelta`) are distinct typed values; UI claims "5 days behind" only when it's actually 5 days, not "5 items/week behind."

### Story 26.4: GoalEntity replaces GoalFormResult; sealed PaceTarget; typed PaceGranularity

As a developer working with goals,
I want one `GoalEntity` (freezed) with sealed `PaceTarget` (deadline / pacePeriod) and typed `PaceGranularity` enum (perek / daf / seif),
So that the three goal models drift (`GoalEntity`, `GoalFormResult`, `Goals` row) collapses to one and `updateGoal` stops dropping `learningUnit`/`paceGranularity` (T2.5).

**Acceptance Criteria:**

**Given** three parallel goal models exist (`GoalEntity` freezed, `GoalFormResult` plain, `Goals` Drift row),
**When** this story lands,
**Then** `GoalEntity` is the single domain type; `GoalFormResult` is deleted; the Drift row maps to `GoalEntity` via a converter
**And** `PaceTarget` is a sealed class with `deadline(date)` and `pacePeriod(quantity, period)` cases
**And** `PaceGranularity` is a typed enum (perek / daf / seif)
**And** `GoalRepositoryImpl.updateGoal` no longer drops `paceGranularity` (the parameter is mandatory in the entity)
**And** the two upsert methods (`upsertGoal`, `upsertGoalByTrack`) consolidate to one with consistent keying.

### Story 26.5: Extract 20 private classes from dashboard_screen.dart into widgets/

As a developer maintaining the dashboard,
I want `dashboard_screen.dart` (2211 lines, 20 private classes) decomposed into `widgets/` files,
So that the screen drops below the 600-line lint cap (NFR8).

**Acceptance Criteria:**

**Given** `dashboard_screen.dart` currently contains 20 private classes,
**When** this story lands,
**Then** every private class becomes a public widget file under `lib/features/dashboard/presentation/widgets/`
**And** `dashboard_screen.dart` is < 600 lines (passes the upcoming SLOC lint)
**And** each extracted widget has a single, named purpose (no junk dumps).

### Story 26.6: TrackCard + 5 subcomponents + TrackCardViewModel

As a learner glancing at my dashboard track cards,
I want all 4 data shapes (program calendar / deadline goal / velocity goal / momentum) rendered through one canonical track-card widget tree with five subcomponents,
So that the card layout is consistent and not driven by the broken `TrackProgressVariant` abstraction (UX-DR10, T2.4).

**Acceptance Criteria:**

**Given** the v1.0.60 plan claimed `track_card.dart` exists but the directory doesn't,
**When** this story lands,
**Then** `lib/features/dashboard/presentation/widgets/track_card/` contains `TrackCard.dart` plus `TrackCardHeader`, `NextTaskBreadcrumb`, `TrackStatGrid`, `LifetimeLearningLine`, `TrackContinueButton`
**And** `TrackCardViewModel` is a freezed value type composing the data each subcomponent needs
**And** all 4 data shapes render through the same widget tree (golden test: 4 viewmodels → 4 visually-consistent cards differing only by their variable data)
**And** `firstTaskInTrackForCategoryProvider((trackId, category))` lives in scheduler providers and is consumed by `NextTaskBreadcrumb`.

### Story 26.7: dashboardModelProvider composition; centralized after-track-change invalidation

As a dashboard screen,
I want one `dashboardModelProvider` composing all leaf providers into a single sub-model for each card,
So that after-track-change invalidation is centralized (delete the two divergent invalidation lists) and the screen consumes typed sub-models, not raw providers.

**Acceptance Criteria:**

**Given** track creation/deletion currently triggers parallel invalidation lists in `text_display_screen.dart:642-667` and `completion_button.dart`,
**When** this story lands,
**Then** `dashboardModelProvider` is the sole composition point
**And** one `onTrackChanged()` helper centralizes all dependent invalidations
**And** both parallel lists in `text_display_screen.dart` and `completion_button.dart` are deleted
**And** a unit test asserts that creating/deleting a track invalidates exactly the providers in the centralized list (no more, no fewer).

### Story 26.8: Delete TrackProgressVariant and supporting dead code

As a developer trusting that the codebase contains no dead abstractions,
I want `TrackProgressVariant` and its 6 supporting files (`track_progress_providers.dart`, `program_calendar_providers.dart`, `chazara_status.dart`, `momentum_status.dart`, `calendar_position.dart`, `mock_program_cycles.dart`) deleted,
So that ~700 LOC of unused code stops misleading future contributors (T2.8, NFR6).

**Acceptance Criteria:**

**Given** the supporting files exist with zero production callers (per the rebuild plan's reality check),
**When** this story lands,
**Then** all 7 files are deleted
**And** `BreadcrumbLabelKind` (or equivalent) carries any variant-specific rendering data into `TrackCardViewModel`
**And** `flutter analyze --fatal-infos` passes after deletion
**And** no test references the deleted code.

### Story 26.9: AddTrackController state machine + AddTrackFlowScreen shell

As a learner adding a new track,
I want the add-track flow to be a clean state machine with a thin shell screen,
So that the 4403-line monolith decomposes into testable, navigable steps (UX-DR17, T2.1).

**Acceptance Criteria:**

**Given** `add_track_flow.dart` is currently 4403 lines with 26 inline classes,
**When** this story lands,
**Then** `AddTrackController` is a state machine (`AddTrackState` sealed class with `welcome`, `curriculumChoice`, `scopeChoice`, `stagesChoice`, `goalChoice`, `studyDays`, `confirmation`, `complete` states)
**And** `AddTrackFlowScreen` is a thin shell reading `AddTrackController` and rendering the current state's widget
**And** `AddTrackFlowScreen.dart` is < 300 lines.

### Story 26.10: Decompose AddTrackFlow steps into per-step files

As a developer touching one step of add-track,
I want each step (welcome, curriculum, scope, stages, goal, study days, confirmation) in its own file under `presentation/steps/`,
So that step modifications don't risk 4400 lines of merge conflicts (UX-DR17).

**Acceptance Criteria:**

**Given** Story 26.9 split out the controller,
**When** this story lands,
**Then** 7+ files exist under `lib/features/track_setup/presentation/steps/`, one per step
**And** every hardcoded English string in the steps is extracted to `app_en.arb`
**And** each step file is < 400 lines
**And** the original `add_track_flow.dart` is deleted.

### Story 26.11: OnboardingController + OnboardingStep list pattern

As a developer extending onboarding,
I want the 7-phase `onboarding_screen.dart` god-screen replaced with `OnboardingController` + a list of `OnboardingStep` (each a `ConsumerWidget` with `(load, save, validate)`),
So that adding/removing/reordering onboarding steps is a list edit (UX-DR18).

**Acceptance Criteria:**

**Given** `onboarding_screen.dart` is currently a god-screen with a 7-phase switch,
**When** this story lands,
**Then** `OnboardingController` advances/retreats through a `List<OnboardingStep>`
**And** each step is a `ConsumerWidget` with a `(load, save, validate)` triple
**And** dead resume code (language/calendar phases from before they were defaulted) is deleted
**And** the LearningProcessWizard is decomposed similarly.

### Story 26.12: ProfileCreationUseCase (one transactional)

As a user finishing onboarding,
I want my profile, curriculum activations, stage defaults, and initial settings created in one transaction,
So that an interrupted onboarding never leaves half-created state (UX-DR18).

**Acceptance Criteria:**

**Given** profile creation currently happens across multiple repository calls,
**When** this story lands,
**Then** `ProfileCreationUseCase.execute(ProfileCreationCommand)` writes the profile row, curriculum activations, default stage definitions, and default settings in one DB transaction
**And** if any insert fails, the whole transaction rolls back
**And** a unit test asserts that a simulated mid-transaction failure leaves zero new rows in any table.

### Story 26.13: Reader purity — pure render, CompletionWriter, completionCommittedProvider

As a reader screen displaying text,
I want to be a pure render with completion writes flowing through `CompletionWriter` and downstream invalidations triggered by one `completionCommittedProvider` notifier from the outbox,
So that the 14-provider invalidation cascade in `text_display_screen.dart:642-667` is gone (UX-DR19, T2.7).

**Acceptance Criteria:**

**Given** the reader currently invalidates 14 providers manually after a completion,
**When** this story lands,
**Then** completion writes call `CompletionWriter.commit(...)` (from Story 25.15)
**And** an `OutboxProcessor` event causes `completionCommittedProvider` to notify
**And** every consumer that needs to react to a completion listens to `completionCommittedProvider` (or its derived listeners)
**And** the reader screen contains zero direct provider invalidations
**And** the 14-item invalidation list in `completion_button.dart` is also deleted.

### Story 26.14: ContentTree indexed lookup replaces 4-level _currentLevel ladders

As a content-hierarchy screen and a bookmark/content repository,
I want indexed `ContentTree` lookups for child/parent/adjacent traversal,
So that the 4-level `_currentLevel*` ladders and the prev/next walks across 9 curricula are eliminated (NFR22, T2.10).

**Acceptance Criteria:**

**Given** `content_hierarchy_screen.dart`, `bookmark_repository_impl.dart`, and `content_repository_impl.dart` currently use 4-level ladders,
**When** this story lands,
**Then** `ContentTree` (built on the `ContentIndex` from Story 25.8) exposes `children(ref)`, `parent(ref)`, `adjacent(ref)`
**And** the ladders are replaced with `ContentTree` calls
**And** Hebrew nikud stripping is cached per curriculum so it isn't recomputed on every keystroke.

### Story 26.15: CompositeCurriculumStrategy + transactional saveOrder + parent-control at repository

As a learner reordering my learning order,
I want the reorder to be transactional and parent-control restrictions enforced at the repository level,
So that mid-loop crashes don't leave half-shuffled state and parents alone can change child orders (T2.10, T1.9-ish).

**Acceptance Criteria:**

**Given** `_compositeSources` and `_tanachTorahContainer` hardcoded specifics live in feature code,
**When** this story lands,
**Then** `CompositeCurriculumStrategy` is a data-driven strategy class consumed by the relevant feature code
**And** `learning_order.saveOrder` is wrapped in a DB transaction (no half-shuffled state on crash)
**And** parent-control restriction is enforced inside `LearningOrderRepository`, not at UI
**And** the 24-line stub `curriculum_learning_screen.dart` is deleted (it's dead).

### Story 26.16: Tappable Progress overview stats + StatCard primitive

As a learner glancing at my Progress overview,
I want the stat cards to be tappable and navigate to the relevant detail (units done, streak, etc.),
So that the overview is a launchpad, not just a wall of numbers (UX-DR11; Fix-C from v1.0.60 plan).

**Acceptance Criteria:**

**Given** `_OverviewStatCard` currently renders but is not tappable,
**When** this story lands,
**Then** each stat card has an `onTap` callback wired to the appropriate detail route
**And** `_OverviewStatCard` and `TaskCategoryStatBox` are both implemented in terms of a new `core/widgets/StatCard` primitive
**And** golden tests cover the StatCard primitive in 3 visual variants.

### Story 26.17: StreakCalendar honors startDate/endDate; StreakHistoryScreen created

As a learner reviewing my streak history,
I want the streak calendar to actually render the date range its callers pass (not a hardcoded 14-day loop) and to have a dedicated history screen,
So that the three different ranges (7-day, 29-day, all-time) all render correctly (UX-DR12, UX-DR13, T1.2).

**Acceptance Criteria:**

**Given** `StreakCalendar` ignores its `startDate`/`endDate` parameters,
**When** this story lands,
**Then** the widget renders exactly the date range its caller passed (7-day, 29-day, all-time all render correctly)
**And** the dashboard, profile, and history callers each render their respective ranges
**And** a new `StreakHistoryScreen` exists, navigated to from the streak hero card.

### Story 26.18: Lifetime providers split — per-curriculum lazy family + collapsed summaries

As a learner viewing lifetime stats,
I want lifetime providers split into per-curriculum lazy `family` providers plus a collapsed `lifetimeSummariesProvider`,
So that loading lifetime data for one curriculum doesn't fan out 9 curricula's worth of work (T2.10).

**Acceptance Criteria:**

**Given** `globalLifetimeCurriculaProvider` currently composes all 9 curricula eagerly,
**When** this story lands,
**Then** lifetime data is read per-curriculum via a `family<CurriculumId>` provider
**And** `lifetimeSummariesProvider` is the only aggregation surface and reads from the per-curriculum providers lazily
**And** a tap on a single-curriculum lifetime card loads only that curriculum's data.

### Story 26.19: UnitCompletion model + achievementsOverviewProvider autoDispose

As a journey/lifetime view rendering completion entries,
I want `UnitCompletion` to drop its dual `displayNameHe`/`displayNameEn` and carry `(entryScope, entryKey, parentL1Key)` so `CurriculumLabel` renders,
So that another parallel dual-field family is collapsed (T3.4).

**Acceptance Criteria:**

**Given** `UnitCompletion` currently carries `displayNameHe` and `displayNameEn`,
**When** this story lands,
**Then** `UnitCompletion` carries `(entryScope, entryKey, parentL1Key)` only
**And** `CurriculumLabel` (from Story 25.9) renders the displayed text from those fields
**And** `journey_timeline_view` and `journey_grouped_view` share one row component (no parallel copies)
**And** `achievementsOverviewProvider` becomes `autoDispose`
**And** live milestone-unlock writes are moved to a dedicated event handler triggered by the completion outbox
**And** `AchievementUnlockCelebration` static globals are replaced with a proper Riverpod notifier.

### Story 26.20: PreferenceListTile + PreferenceSegmentedTile primitives

As a Settings screen author,
I want one `PreferenceListTile` and one `PreferenceSegmentedTile<T>` primitive replacing the family of bespoke preference tiles,
So that adding a new preference is one line, not a custom widget (UX-DR21, NFR1).

**Acceptance Criteria:**

**Given** Settings currently has multiple bespoke preference-tile widgets,
**When** this story lands,
**Then** `PreferenceListTile({title, subtitle, leading, trailing, onTap})` and `PreferenceSegmentedTile<T>({title, options, value, onChanged})` exist under `core/widgets/`
**And** every existing preference tile in Settings is rewritten using one of the two primitives
**And** the bespoke widgets are deleted
**And** the Hebrew-terms toggle and Hebrew-date toggle are surfaced in the Settings screen using `PreferenceListTile` (with documented defaults `hebrewTerms: false`, `useHebrewDate: false`)
**And** onboarding does NOT present either toggle as a step — the toggles appear only in Settings (UX-DR3, PART 6.5 of rebuild plan).

### Story 26.21: PinFlowController + PinFlowScreen + PinFlowMode (3 PIN screens → 1)

As a parent setting up / changing / verifying my PIN,
I want one PIN screen with three modes,
So that the 3 near-identical PIN screens collapse to a single component (UX-DR22, NFR1).

**Acceptance Criteria:**

**Given** 3 PIN screens currently exist (parent setup, parent change, parent verify),
**When** this story lands,
**Then** one `PinFlowScreen` configured by `PinFlowMode.{setup, change, verify}` replaces all three
**And** `PinFlowController` owns transitions and lockout state
**And** the labels around the keypad ("Confirm PIN", "Try again") render from ARB and flip with locale (per UX-DR8)
**And** the previous three screens are deleted.

### Story 26.22: Shared TrackManagementBody + curriculum-minimum-1 guard

As a parent managing tracks and as a curriculum minimum-1 invariant,
I want one `TrackManagementBody` shared between parent and child track-management screens, and `CurriculumActivationService.deactivate` enforcing minimum-1,
So that the two near-identical track screens collapse and users can't deactivate their last curriculum (UX-DR23, NFR1).

**Acceptance Criteria:**

**Given** parent and child track-management screens are two near-identical files,
**When** this story lands,
**Then** one `TrackManagementBody` widget is shared between both screens (only role-specific actions differ)
**And** `CurriculumActivationService.deactivate(curriculumId)` throws `LastActiveCurriculumException` when the user has exactly one active curriculum
**And** the UI catches and surfaces the constraint message clearly (no silent failure).

### Story 26.23: Data export rewrite — all 23 tables, profileId on every row, no PII, round-trip test

As a user exporting my data,
I want every row to carry `profileId`, all 23 user-DB tables included, no Firebase identity, and a round-trip test asserting export→import preserves data exactly,
So that the import doesn't destroy multi-profile data or leak my email (FR14, T1.10).

**Acceptance Criteria:**

**Given** the current export uses `formatVersion: '1'` and `appVersion: '1.0.0'` hardcoded and omits 8 tables,
**When** this story lands,
**Then** `formatVersion: 'schemaV1'`, `appVersion` reads from `package_info_plus`
**And** export includes all 23 user-DB tables enumerated
**And** every row carries `profileId`
**And** export omits `firebaseUid` / `email` fields entirely
**And** import is per-profile (does not wipe the entire user DB)
**And** a round-trip integration test asserts `import(export(state))` == `state` for a non-trivial multi-profile fixture.

### Story 26.24: Sacred-time-aware notifications — rolling 14-day batch + fire-time check + SacredWindow persistence

As a Shabbos-observant user,
I want my daily reminder to not fire during Shabbos or Yom Tov, and to fire at the right local time after I travel,
So that notifications stop firing during sacred time and stop firing at JLM 05:00 because my timezone was stale (FR10, T1.8).

**Acceptance Criteria:**

**Given** the current daily reminder is one repeating schedule with sacred-quiet checked at schedule-time only,
**When** this story lands,
**Then** the reminder is scheduled as a rolling 14-day batch of pre-filtered one-shots
**And** each fire-time is pre-checked against a persisted `SacredWindow` table (so a background fire can read it without the Flutter engine running)
**And** `TimezoneLifecycleObserver` (a sibling of `SyncLifecycleObserver` from Story 25.14) re-detects timezone on resume, invalidates `SacredWindow` cache, and reschedules the 14-day batch
**And** notification body strings have Hebrew translations and resolve locale at FIRE time (UX-DR7)
**Given** an integration test simulates Erev Shabbos at 18:30 with a 19:00 reminder scheduled,
**When** the schedule windows include Shabbos,
**Then** the 19:00 fire is suppressed (or replaced with a post-Shabbos fire).

### Story 26.25: SacredTimeLockOverlay scoped to post-auth shell

As a user installing the app on Erev Yom Kippur,
I want to be able to complete onboarding without the sacred-time overlay locking me out for 25 hours,
So that the overlay still blocks reader/completion screens during sacred time but doesn't block account creation (FR11, T1.8).

**Acceptance Criteria:**

**Given** `SacredTimeLockOverlay` currently wraps every route with `PopScope(canPop: false)`,
**When** this story lands,
**Then** the overlay is mounted inside the post-auth `AppShell` only
**And** onboarding, sign-in, and account-picker routes render without the overlay
**And** an integration test asserts that during sacred time the dashboard is blocked but onboarding/sign-in are accessible.

### Story 26.26: Stage repository as only path; full params; transactional reorder + Learn-at-1 guard

As a stage editor and as the Learn-at-position-1 invariant,
I want `StageDefinitionRepository.addStage` to accept `scheduleType`/`daysOfWeek`/`rollingWindowSize`, `reorderStages` to be transactional with a Learn-at-1 guard, and the 16 DAO-bypass call sites migrated,
So that weekly/rolling stages survive the round-trip (FR12) and the protected `Learn` stage cannot be displaced (FR13).

**Acceptance Criteria:**

**Given** `addStage` currently lacks params for `scheduleType`/`daysOfWeek`/`rollingWindowSize` (only `learning_process_wizard_service.dart` writes those via DAO),
**When** this story lands,
**Then** `addStage` accepts the full set of params and writes through the repository (no DAO bypass)
**And** the 16 production call sites that hit `db.stageDao.*` directly are migrated to `StageDefinitionRepository`
**And** `reorderStages` runs in a single transaction; mid-loop crash leaves stages in their original positions
**And** `reorderStages` and `deleteStage` both guard against displacing the Learn stage from position 1 (throws `ProtectedStageException`)
**And** `StageValidator` is consulted on every write (becomes load-bearing).

### Story 26.27: Bulk-mark-prior streak abstention at all stages

As a learner running bulk-mark-prior on stage 2 or stage 3,
I want streak ticks to be suppressed regardless of which stage I'm bulk-marking,
So that fresh-install bulk-mark-prior doesn't artificially inflate my streak (FR17).

**Acceptance Criteria:**

**Given** the current implementation only suppresses streak for `stageId == 1`,
**When** this story lands,
**Then** all bulk-mark-prior writes route through a streak-suppressing path regardless of stage
**And** an integration test marks 50 prior completions across stages 1, 2, and 3 on a fresh install and asserts that `StreakStateProvider` returns `currentStreak == 0` afterward.

### Story 26.28: Label bypass elimination — 17 files + TrackType + Calendar/LearningProgram + locale-named locals

As the labels-are-one-source-of-truth invariant,
I want the 17 files still reading `hebrewTermsScriptProvider`, every `TrackType.displayName*` callsite, every `CalendarProgramEntry/LearningProgram` dual-field site, and every `useHebrew`/`hebrewOnly`/`hebrewTerms` local renamed,
So that all label rendering flows through `CurriculumLabel.*` only (NFR1, T3.4).

**Acceptance Criteria:**

**Given** 17 files still read `hebrewTermsScriptProvider` outside the labels module,
**When** this story lands,
**Then** every such file is migrated to consume `CurriculumLabel.*` (or, for non-UI code, to read `HebrewTermsPreference` directly via `core/preferences/`)
**And** the `TrackType.displayName*` family in 5 files is migrated
**And** the `CalendarProgramEntry` / `LearningProgram` dual-field set (`core/services/calendar_program_service.dart`, `learning_program_service.dart`) is migrated
**And** every `useHebrew` / `hebrewOnly` / `hebrewTerms` local is renamed to `useHebrew` (one name) inside `core/labels/`/`core/preferences/`
**And** the enforcement greps from PART 4 (hebrewTermsScriptProvider grep, displayName grep, useHebrew/hebrewOnly grep) return clean.

### Story 26.29: Hardcoded strings → ARB extraction

As an internationalization gate,
I want every hardcoded English string in `lib/features/` extracted to `app_en.arb`,
So that NFR14 (ARB parity) and the Hebrew translation in Story 26.30 have a complete English source (T3.3).

**Acceptance Criteria:**

**Given** there are ~132 raw `Text('English')` strings, 19 hardcoded SnackBars, and hardcoded Hebrew literal stage names in feature files,
**When** this story lands,
**Then** every hardcoded English string in `lib/features/` is replaced with `AppLocalizations.of(context).keyName`
**And** every hardcoded Hebrew literal (`לימוד`, `חזרה א׳`, `חזרה ב׳`) is sourced from ARB (not seed-data or repository)
**And** mixed-script strings (`'Pick a preset or build your own חזרה schedule.'`) are split: English locale uses transliterated `chazara` (or the Hebrew-terms-preference-aware variant), Hebrew locale renders fully Hebrew (UX-DR14)
**And** pluralization uses `{count, plural, ...}` form (not `count == 1 ? 'task' : 'tasks'`)
**And** 173 orphaned ARB keys are triaged: kept if reachable, deleted otherwise.

### Story 26.30: Hebrew ARB translation completion

As a Hebrew-locale user,
I want every key in `app_en.arb` to have a Hebrew translation in `app_he.arb`,
So that the Hebrew UI is end-to-end (FR18, UX-DR9, NFR14).

**Acceptance Criteria:**

**Given** Story 26.29 produced a complete `app_en.arb`,
**When** this story lands,
**Then** every key in `app_en.arb` has a corresponding key in `app_he.arb`
**And** religious-curriculum terminology has been reviewed by the user (native Hebrew speaker) for correctness
**And** the `tool/arb_parity_check.dart` script (built in E27) returns clean
**And** golden tests render a representative set of screens in Hebrew (RTL) and pass visual review.

### Story 26.31: RTL widget audit — direction-aware variants across ~80–100 sites

As a Hebrew-locale user,
I want every layout site that currently uses LTR-only widgets (`EdgeInsets.only(left:|right:)`, `Alignment.centerLeft|centerRight`, `TextAlign.left|right`) migrated to the directional variants,
So that the Hebrew UI renders correctly with mirrored padding, alignment, and text direction (UX-DR5, NFR16).

**Acceptance Criteria:**

**Given** ~80–100 sites use LTR-only widgets,
**When** this story lands,
**Then** every such site uses `EdgeInsetsDirectional`, `AlignmentDirectional`, or `TextAlign.start/end`
**And** the upcoming direction-aware lint (Story 27.11) passes
**And** golden tests confirm representative screens render correctly in both `en` and `he` locales.

### Story 26.32: Naming sweep — unit→3 names, Profiles→Accounts/LearnerProfiles, Gregorian→English, notification taxonomy

As a developer reading the codebase a year from now,
I want `unit` split into `pacePeriod` / `paceGranularity` / `entryScope` (three distinct concepts), `Profiles`/`UserProfiles` renamed to `LearnerProfiles`/`Accounts` (architecture-doc-correct), "Gregorian" → "English" in UI strings, and the notification taxonomy consolidated,
So that there is one name per concept (NFR15, T3.2).

**Acceptance Criteria:**

**Given** the v1.0.61 plan's flat `unit*` rename was wrong on two of three axes,
**When** this story lands,
**Then** `paceUnit` is renamed to `pacePeriod` (semantic: period of time over which pace is measured)
**And** `learningUnit` is renamed to `paceGranularity` (semantic: granularity at which pace is targeted — perek/daf/seif)
**And** `learning_ledger.unitType` is renamed to `entryScope` (semantic: milestone scope — seder/masechta/sefer)
**And** the `Profiles` and `UserProfiles` tables (already renamed in Story 25.1) have their model classes and provider names updated to match
**And** "Gregorian" is replaced with "English" in every UI-visible string (DB storage keys preserved with documented exception)
**And** the date-picker method `_pickGregorianDate` is renamed `_pickEnglishDate` (keeping `_pickHebrewDate` for the Hebrew branch); the default branch is driven by the `useHebrewDate` per-profile preference (UX-DR6)
**And** the four overlapping notification taxonomies ("Reminder" / "Alert" / "Milestone" / "Notification") collapse to one
**And** "Shabbos quiet" is renamed `SacredTimeActive` (covers Yom Tov / Yom Kippur).

### Story 26.33: Dead code purge — ≥10 000 LOC across reducers, services, tables, widgets, ARB keys, themes, network modules

As a developer maintaining the codebase,
I want every dead reducer, service, table, widget, ARB key, theme alias, network module deleted in one PR,
So that the codebase reflects what's actually used (NFR6, T2.8).

**Acceptance Criteria:**

**Given** the rebuild plan enumerates dead features (`tutor_mode/`, `test_tracking/`), reducers/services (`streak_reducer.dart` (dead), `DuplicatePreventionService`, `TrackService`, `DailyScheduleComposer`, `StageValidator` — now load-bearing from Story 26.26), widgets (`UnifiedDailyView`, `DailyScheduleHeader`, `GoalProgressCard`, `BookmarkCard`, `curriculum_learning_screen.dart` stub), network code (`core/network/dio_provider.dart`, sefaria fetcher), dead tables (`learning_order` vs `track_learning_order`, `text_download_status`), dead notification channel (`showRewardMilestone`), dead UI math (`+XP` rendering on daily task card per UX-DR15), dead theme (`AppTheme.darkTheme()` alias, 20+ heritage/child color aliases),
**When** this story lands,
**Then** every enumerated dead element is deleted
**And** ≥10 000 LOC reduction is observed in a `cloc` diff
**And** `flutter analyze --fatal-infos` and the full test suite pass after deletion
**And** `docs/architecture.md`'s feature list is updated to remove `tutor_mode` and `test_tracking` (Story 27.15 does the full rewrite).

---

## Epic 27: Discipline & Closure (Phases 5 + 6 + 7)

Test pyramid, CI gates, observability completion, docs reconciliation. Locks the "model project" property in for future development.

### Story 27.1: Test infrastructure — fake_cloud_firestore, golden scaffolding, real-Drift in-memory helper

As a test author,
I want a shared test infrastructure offering `fake_cloud_firestore`, a golden-test runner, and a real-Drift in-memory database helper,
So that integration tests can run against a faked Firestore and golden tests can detect visual regressions (NFR12, NFR13).

**Acceptance Criteria:**

**Given** the existing test suite has only 2 real integration tests,
**When** this story lands,
**Then** `test/helpers/firestore_fake.dart` provides a configured `FakeFirebaseFirestore` and matching emulator rules pre-loaded
**And** `test/helpers/golden_runner.dart` provides `goldenTest(name, build)` with automatic Hebrew/English variants
**And** `test/helpers/drift_memory.dart` provides `inMemoryDb()` returning a fresh schema-v1 Drift DB
**And** at least one consumer of each helper exists (the integration tests in Stories 27.5–27.9 will use them).

### Story 27.2: Unit test suite for pure functions

As a developer changing a pure function,
I want unit tests covering `PaceCalculator`, `StreakReducer`, `CrossCurriculumAggregator`, `CurriculumLabelRenderer`, `ProgramRefResolver`, `StageValidator`, `LocalDayClock`,
So that pure logic is covered before integration tests run (NFR12 60%-unit target).

**Acceptance Criteria:**

**Given** the seven pure functions exist after Phase 2 rebuild,
**When** this story lands,
**Then** each has a unit test file covering its branches (success cases, edge cases, error cases)
**And** combined unit-test coverage of these functions is ≥ 90%
**And** the tests are pure (no DB, no Firestore, no I/O).

### Story 27.3: DAO and repository test suite using real in-memory Drift

As a developer changing a DAO,
I want every DAO method covered by a test running against a real in-memory Drift DB (no `MockUserDatabase`),
So that schema-level invariants (Story 25.1's no-default profileIds, Story 25.2's UNIQUEs) are validated against the real engine (NFR12).

**Acceptance Criteria:**

**Given** Story 27.1 provides `inMemoryDb()`,
**When** this story lands,
**Then** every DAO has at least one test per public method using `inMemoryDb()`
**And** all 18 DAOs are covered
**And** `MockUserDatabase` references are deleted from the test suite
**And** per-method branch coverage is ≥ 80% across DAOs.

### Story 27.4: Widget + golden test suite (canonical screens) with Hebrew variants

As a UI designer preventing visual regression,
I want golden tests for `TrackCard` (all 4 data shapes → one canonical layout), `StatCard`, `StreakHero`, `CurriculumPicker`, `ProgressOverview` plus Hebrew variants,
So that visual changes require explicit golden updates (UX-DR10, NFR12, NFR14).

**Acceptance Criteria:**

**Given** Story 27.1's `goldenTest(...)` helper exists,
**When** this story lands,
**Then** golden tests exist for `TrackCard` (4 data shapes) and `StatCard`, `StreakHero`, `CurriculumPicker`, `ProgressOverview`
**And** each test ships an `en` and a `he` variant (RTL)
**And** interaction tests cover `CompletionButton`, `BulkMarkScreen`, `DraggableOrderItem`
**And** golden diffs upload to CI artifacts on failure.

### Story 27.5: Integration test — bulk_mark_prior_does_not_credit_streak (any stage)

As a developer trusting Story 26.27,
I want an integration test asserting that bulk-mark-prior does not credit streak at any stage,
So that future changes can't silently reintroduce the bug (NFR13).

**Acceptance Criteria:**

**Given** the test scaffolding from Story 27.1 is available,
**When** the test runs,
**Then** it creates a fresh in-memory DB, simulates a bulk-mark-prior over 50 items across stages 1, 2, and 3,
**And** asserts `StreakStateProvider.read()` returns `currentStreak == 0` and `maxStreak == 0`
**And** asserts the `streak_events` table contains zero rows attributable to the bulk-mark batch.

### Story 27.6: Integration tests — streak_reducer_reconciles + cloud_restore_preserves_streak

As a developer trusting Stories 25.16 and 25.17,
I want integration tests proving the reducer reconciles correctly from the event log and cloud restore preserves streak,
So that the streak-restore-from-completions reconstitution is verified (NFR13, FR2, FR3).

**Acceptance Criteria:**

**Given** the test scaffolding is available,
**When** the reducer test runs,
**Then** it appends a known sequence of streak events and asserts the reducer's `(currentStreak, maxStreak)` matches expectation
**Given** the cloud-restore test runs,
**When** a fresh device pulls `completion_events` but the local `streak_events` log is empty,
**Then** the reducer reconstitutes events from `completion_events` (one event per distinct UTC day) and computes the correct streak.

### Story 27.7: Integration tests — multi_profile_isolation + track_card_canonical_layout

As a developer trusting Stories 25.1 and 26.6,
I want integration tests asserting Profile A's completion never surfaces in Profile B's anything, and all 4 track-card data shapes render through one canonical widget tree,
So that the data isolation and UI canonical-layout invariants are pinned down (NFR13, FR1, UX-DR10).

**Acceptance Criteria:**

**Given** the test scaffolding is available,
**When** the isolation test runs,
**Then** it creates Profile A and Profile B, records a completion in A, and asserts every cross-profile-aware query for B returns empty
**And** the dashboard provider for B does not surface A's completion
**Given** the track-card canonical layout test runs,
**When** each of the 4 data shapes (programCalendar / deadlineGoal / velocityGoal / momentum) is fed to `TrackCardViewModel`,
**Then** the resulting widget tree differs only in text/data, not in structure (`Widget` traversal comparison).

### Story 27.8: Integration tests — firestore_rules (emulator) + offline_completion_flushes

As a developer trusting Stories 24.1, 25.4, and 25.5,
I want integration tests asserting the Firestore rules enforce per-collection semantics and offline completions flush when back online,
So that security and offline-queue behavior are pinned down (NFR13, FR4, FR24).

**Acceptance Criteria:**

**Given** the Firestore emulator is configured,
**When** the rules test runs,
**Then** allowed cases pass and denied cases (negative points, future completedAt, arbitrary fields, deletes) are rejected
**Given** the offline-flush test runs,
**When** the device is offline and the user records 50 completions,
**Then** 50 outbox rows exist
**And** when the device "reconnects" (test toggles a flag), the OutboxProcessor drains all 50 and the corresponding Firestore docs exist.

### Story 27.9: Integration tests — pin_lockout_cycle + log_redaction + bookmark_advance_atomic

As a developer trusting PIN/logging/bookmark invariants,
I want integration tests for the PIN lockout cycle, log-redaction field-based behavior, and bookmark advancing atomically with completion,
So that those harder-to-spot regressions are caught (NFR13).

**Acceptance Criteria:**

**Given** the test scaffolding is available,
**When** the PIN lockout test runs,
**Then** 5 failed attempts trigger a 15-minute cooldown; the cooldown expires on time; a successful attempt during cooldown is rejected
**Given** the redaction test runs,
**When** various structured log calls are made,
**Then** field-allowlist redaction is applied (emails redacted, event names preserved)
**And** the previously-broken substring-match cases (`'PIN setup screen opened'`) are preserved verbatim
**Given** the bookmark-atomic test runs,
**When** a completion is committed and the bookmark advance is wired in the same transaction,
**Then** if a simulated failure occurs during bookmark advance, the completion is also rolled back (no permanent completion with stale bookmark).

### Story 27.10: Custom lints Part 1 — no-curriculum-display-name-bypass, no-feature-cross-import

As the labels and layering invariants,
I want two custom_lint rules: `no-curriculum-display-name-bypass` (fails on `.displayNameEn`/`.displayNameHe` outside whitelist) and `no-feature-cross-import` (fails on `features/X/...` → `features/Y/...` deep imports),
So that future agents cannot regress Stories 25.9 and 25.18 / NFR2 (NFR17).

**Acceptance Criteria:**

**Given** `custom_lint` is configured for the project,
**When** this story lands,
**Then** `no-curriculum-display-name-bypass` exists, fails CI on `\bdisplayName(En|He)\b` outside `core/labels` and generated files
**And** `no-feature-cross-import` exists, fails CI on any import from `features/X/` to `features/Y/...` not going through `features/Y/providers.dart`
**And** both lints have a one-page README explaining the rule and the remediation.

### Story 27.11: Custom lints Part 2 — no-firebase-outside-core, no-raw-talker, RTL discipline

As the Firebase-confinement and logging invariants,
I want `no-firebase-outside-core` (fails on Firebase symbols outside `core/auth`/`core/sync`), `no-raw-talker` (fails on `package:talker/talker.dart` imports outside `core/logging`), and direction-aware widget lints,
So that NFR3, NFR8 redactor invariant, and UX-DR5/NFR16 RTL discipline are enforced (NFR17).

**Acceptance Criteria:**

**Given** custom_lint is configured,
**When** this story lands,
**Then** `no-firebase-outside-core` fails CI on `FirebaseAuth`/`FirebaseFirestore`/`FirebaseStorage` outside whitelist directories
**And** `no-raw-talker` fails CI on `import 'package:talker/talker.dart'` outside `core/logging`
**And** direction-aware lints fail on `EdgeInsets.only(left:|right:)`, `Alignment.centerLeft|centerRight`, `TextAlign.left|right`
**And** each lint has a one-page README.

### Story 27.12: CI matrix — analyze, format, audit, lint, test, coverage-floor, firestore-rules, golden, arb-parity

As an operator running CI,
I want a complete CI matrix that runs all gates on every PR,
So that regressions are caught at the CI boundary, not in production (NFR18).

**Acceptance Criteria:**

**Given** the project has a CI configuration (e.g. `.github/workflows/ci.yml`),
**When** this story lands,
**Then** CI runs: `dart analyze --fatal-infos`, `dart format --set-exit-if-changed lib/ test/`, `make audit` (all PART-4 greps), `custom_lint`, `flutter test` (full suite), line-coverage floor at 60% (and coverage cannot drop on a PR), `firestore-rules` (emulator), golden tests (upload diffs on failure), `tool/arb_parity_check.dart`
**And** any failure blocks merge.

### Story 27.13: `make audit` Makefile target + tool/arb_parity_check.dart

As a developer wanting to validate changes before push,
I want one `make audit` command that runs every grep and lint check locally,
So that I get the same answer locally that CI would give me (NFR19, AR9).

**Acceptance Criteria:**

**Given** a `Makefile` exists at the project root,
**When** this story lands,
**Then** `make audit` runs all 12 enforcement greps from PART 4 of the rebuild plan plus `custom_lint`
**And** the make target exits non-zero on any violation, printing offending file:line locations
**And** `tool/arb_parity_check.dart` reads both `app_en.arb` and `app_he.arb` and exits non-zero if any English key is missing in Hebrew.

### Story 27.14: 12 analytics events wired + Crashlytics user ID set everywhere

As an operator monitoring production,
I want 12 named analytics events firing on the right triggers and `FirebaseCrashlytics.setUserIdentifier(profileId)` called on every profile switch,
So that I can answer product questions ("how often is bulk-mark-prior used?") and crash reports are correctly attributed (NFR7, AR8).

**Acceptance Criteria:**

**Given** Story 24.4 wired Crashlytics initialization,
**When** this story lands,
**Then** the 12 events from PART 4 (`app_launch`, `completion_recorded`, `bulk_mark_prior_used`, `track_added`, `streak_milestone_reached`, `sync_failed`, `pin_locked_out`, `parent_mode_entered`, `notification_fired`, `notification_suppressed_sacred_time`, `cloud_restore_completed`, `crash_reported`) fire at the right moments
**And** `setUserIdentifier(profileId)` is called from a single observer that listens to active-profile changes (no scattered call sites)
**And** an integration test asserts each event fires once per trigger.

### Story 27.15: `docs/architecture.md` rewrite to match rebuild reality

As a contributor onboarding to the project,
I want `docs/architecture.md` to describe the post-rebuild state accurately, with feature lists and table lists generated from source where possible,
So that the doc stops drifting from the code (NFR-meta).

**Acceptance Criteria:**

**Given** the current `docs/architecture.md` describes the pre-rebuild architecture (18 features including dead `tutor_mode` and `test_tracking`, schema v4 specifics, etc.),
**When** this story lands,
**Then** the doc reflects the rebuild reality: schema v1, 7-class SyncEngine, single CompletionWriter, single StreakReducer, single ContentIndex, locale auto-detection, the 4 custom lints, the full CI matrix, the 10 named integration tests
**And** zombie features (`tutor_mode`, `test_tracking`) are removed from the feature list
**And** the table list is generated from Drift annotations via a small `tool/gen_arch_tables.dart` (or similar) so future drift is mechanically detected
**And** the doc passes a markdown lint and renders correctly.

### Story 27.16: CLAUDE.md and docs/coding-standards.md updated with layering rules and enforcement greps

As an AI agent or developer contributing to this project,
I want `CLAUDE.md` and `docs/coding-standards.md` to capture the new layering rules, enforcement greps, and the 4 custom lints,
So that the project's discipline is discoverable from the docs, not just the CI logs (NFR-meta).

**Acceptance Criteria:**

**Given** `CLAUDE.md` and `docs/coding-standards.md` exist,
**When** this story lands,
**Then** the layering rules from Principle P2 are documented (with the directionality `app → features → core`)
**And** the 12 enforcement greps are listed with explanations
**And** the 4 custom lints are listed with their READMEs cross-referenced
**And** `docs/_archive/` is updated with the Phase-0 retired material per Phase 7 of the rebuild plan.
