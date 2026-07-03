# V2-R4 Class & Function Quality Adversarial Review

**Reviewer:** V2-R4 (Class & Function Quality)
**Date:** 2026-05-20
**Branch:** dev
**Scope:** `lib/` — class size, function complexity, god-screen split outcomes (W5.1-W5.6), sealed unions (W5.7-W5.9), primitive obsession (W5.10-W5.13), naming conventions (W5.20), ConsumerWidget conversions (W5.21), DateTime.now() hygiene (W5.19)
**References:** tech-debt-remediation-plan.md v3.3 · refactor-s5-log.md

---

## Executive Summary

The god-screen decomposition delivered solid structural improvement: all six split files land well under 600 LOC with extracted widgets in proper `widgets/` subfolders. The sealed-union work and ConsumerWidget conversion are also good. The main damage zones are (1) two entire feature trees left as exact duplicates (`track_setup/` vs `tracks/setup/`, `signup_screen.dart` in two locations), (2) `signup_screen.dart` at 939 LOC was not split at all despite being on the same scale as the six god screens, (3) `scheduler_providers.dart` at 1154 LOC is a god-provider containing substantive orchestration logic, (4) `sign_in_controller.dart` at 635 LOC is a heavy controller with a 110-line navigation function, and (5) primitive obsession on `goalType` string literals is still widely spread across the codebase.

**Verdict: CONDITIONAL PASS.** Critical and High findings must be resolved before the refactor is declared complete. Medium findings are important but do not break observable behaviour today.

---

## CRITICAL

### CR1 — Two complete feature trees are duplicated: `track_setup/` vs `tracks/setup/` (and `signup_screen.dart` in two locations)

**Files (track_setup):**
- `lib/features/track_setup/` — 928-LOC `add_track_flow_screen.dart`, 891-LOC `edit_track_screen.dart`, full `domain/services/` tree, full `presentation/` tree
**Files (tracks/setup):**
- `lib/features/tracks/setup/` — identical copies, import paths updated to point at `tracks/setup/` variants

**Files (signup_screen):**
- `lib/features/onboarding/presentation/screens/signup_screen.dart` — 939 LOC
- `lib/features/account/onboarding/presentation/screens/signup_screen.dart` — 939 LOC (byte-for-byte identical, diff output: 0 lines)

W2 cluster carving was supposed to move `track_setup` content into `features/tracks/setup/` and then delete `features/track_setup/`. The new canonical location was created and populated, but the old `features/track_setup/` directory was never deleted. Both trees are actively imported in different call sites. The same applies to `signup_screen.dart`: the canonical version lives in `features/account/onboarding/` but the original in `features/onboarding/` was never removed.

Consequence: every bug fix and refactor must be applied twice. The `track_creation_service.dart` copies already have a one-line divergence (different import path for `stage_definition_repository`). The two trees will drift further with every subsequent commit.

**Required action:** Delete `features/track_setup/` and `features/learning_order/` (also duplicated into `features/tracks/whole_curriculum_order/`) after verifying all imports point to canonical paths. Delete `features/onboarding/presentation/screens/signup_screen.dart` in favour of `features/account/onboarding/presentation/screens/signup_screen.dart`.

---

## HIGH

### H1 — `signup_screen.dart` (939 LOC) was never split — it is on the same scale as the six god screens and was not in scope

**File:** `lib/features/onboarding/presentation/screens/signup_screen.dart` (939 LOC)
**Also:** `lib/features/account/onboarding/presentation/screens/signup_screen.dart` (939 LOC)

The plan's W5 wave named six god screens. `signup_screen.dart` was not on that list, but at 939 LOC it exceeds every one of the six targets in their post-split state. It contains a single `_SignupScreenState` class with form handling, validation, multi-step async auth flows, cloud/local routing, and navigation wiring all inline. No controller, no extracted widgets, one boolean `_isLoading` driving a loading spinner.

This was an oversight of scope, not an intentional deferral. The S5 log does not mention it.

---

### H2 — `scheduler_providers.dart` at 1154 LOC is a god-provider containing two substantive orchestration functions

**File:** `lib/features/scheduler/presentation/providers/scheduler_providers.dart` (1154 LOC)

This file contains:
- Two top-level async functions of ~340 LOC each: `_buildProjectionTasks` (lines 405–741) and `_buildFreshPlan` (lines 742–942), both with nested for-loops, conditional calendar routing, and per-curriculum branching.
- A third `_applyProgramCalendarOverrides` function at ~150 LOC (line 979).
- Seven provider registrations, two `@riverpod` Notifier classes, and a `programCalendarSchedule` helper.

`_buildProjectionTasks` alone is ~337 LOC — exceeding the 200-LOC function threshold. It fetches active curricula, iterates per-curriculum, resolves calendar entries, calls `project()`, maps refs to `DailyTask` objects, and handles the program-track vs self-paced-track branch. This is orchestration-level logic that belongs in a domain service, not a provider file.

Plan task W5 does not explicitly call this file out, but the plan's description of W4.17 says "collapse dashboard_providers.dart to 1-liners" — the identical principle applies here and was not applied.

---

### H3 — `sign_in_controller.dart` (635 LOC): `_navigateAfterSignIn` is 100+ LOC with full orchestration logic inline

**File:** `lib/features/account/presentation/notifiers/sign_in_controller.dart` (635 LOC)

`_navigateAfterSignIn` (lines 284–386, ~103 LOC) performs: registry lookup, session persistence, account DB swap, `promoteToCloud`, two `pullOnLaunch` calls with separate timeouts, a remote profile count check, a second sync cycle if zero local profiles, profile-count-based routing, and `setBool(kOnboardingComplete, true)`. This is auth domain orchestration embedded in a Riverpod Notifier.

The `signInWithEmail` method (lines 391–543, ~153 LOC) has a tri-branch structure (local-born, cloud-born with online check, not-on-device) with deeply nested async logic in each branch. Both functions exceed the 200-LOC-function threshold for complexity even if not strictly LOC.

The `SignInController` class as a whole is 570 lines of business logic (excluding imports). Per the plan's naming convention, this controller is doing UseCase-level work.

---

### H4 — `reward_configuration_screen.dart` still has 7 raw `Color(0xFF...)` literals at file scope despite W5.14

**File:** `lib/features/gamification/presentation/screens/reward_configuration_screen.dart` (lines 22–28, 277)

W5.14 specifies moving colour literals from `features/` to `core/theme/app_colors.dart`. The god-screen split created this file but left seven module-level colour constants (`_kNavy`, `_kOrange`, `_kPageBg`, `_kFieldFill`, `_kPreviewBg`, `_kMutedLabel`, `_kCardWhite`) and one inline `Color(0x1200218D)` in place. The same pattern exists in `app_intro_screen.dart` (lines 34–35) with two file-level colour constants.

These are not legacy files — they were freshly generated by the S5 refactor. Having `Color(0xFF...)` literals in a file written during W5 shows the W5.14 lint and enforcement did not catch them in this batch.

A broader count shows 498 raw `Color(0xFF...)` occurrences in `lib/features/` (excluding `core/theme/`), confirming W5.14 was not completed at scale.

---

### H5 — `goalType` primitive obsession: 15+ string literal comparisons remain post-W5.10/W5.11

**Files:**
- `lib/features/scheduler/presentation/providers/scheduler_providers.dart` (lines 205, 231, 625, 788, 820)
- `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (lines 418, 420)
- `lib/features/track_setup/presentation/screens/track_detail_screen.dart` (lines 276, 284, 295, 296)
- `lib/features/tracks/setup/presentation/screens/edit_track_screen.dart` (lines 200, 216, 486, 487)
- `lib/features/dashboard/domain/services/parent_dashboard_aggregator.dart` (lines 244, 246)

W5.10 and W5.11 addressed `ProfileMode` and `AccountTier` string comparisons. However `goalType` — equally a primitive-obsession candidate — was not included. Strings `'deadline'` and `'pace'` are scattered across 5+ files. The plan's W3.44 collapsed the goal entity to use `PaceTarget?`, which should have killed the `goalType` field, but it persists in the Drift schema and is being compared as raw strings. The `paceStatus` provider (line 205) even accepts `String goalType = 'deadline'` as a named parameter, embedding the string into the provider's public API.

---

## MEDIUM

### M1 — `OnboardingScreen` persists `_profileMode` as a raw `String` field despite ProfileMode enum being available (W5.10)

**File:** `lib/features/onboarding/presentation/screens/onboarding_screen.dart` (lines 85, 118, 148, 175, 230)

`_ScreenPhaseState` holds `String _profileMode = 'adult'` and makes comparisons like `_profileMode == 'child'`. `ProfileMode` enum exists at `lib/core/domain/value_objects/profile_mode.dart` with the `@Deprecated` doc comment explicitly asking callers to stop doing string comparisons. The onboarding screen was refactored in W5.5 but the `_profileMode` string field was not converted.

---

### M2 — `tutor_notification_service.dart` contains `TutorNotificationGateway` — file name and class name disagree

**File:** `lib/features/tutoring/domain/services/tutor_notification_service.dart`

The file is named `tutor_notification_service.dart` but the class inside is `TutorNotificationGateway`. Per W5.20 naming rules, a class wrapping a platform API (push notifications) should be named `*Gateway`. The file name was not updated to match the class rename, creating a naming inconsistency that will confuse future readers.

---

### M3 — `AccountManagementService` and `CurriculumActivationService` each exist in two separate feature directories

**Files:**
- `lib/features/account/domain/services/account_management_service.dart`
- `lib/features/settings/domain/services/account_management_service.dart` (byte-for-byte identical — diff output: 0 lines)

- `lib/features/tracks/domain/services/curriculum_activation_service.dart`
- `lib/features/settings/domain/services/curriculum_activation_service.dart` (1 diverging comment line)

W2.12-W2.15 intended to move the account cluster out of `settings/` into `features/account/`. `account_management_service.dart` was copied but the original not deleted. Same for `curriculum_activation_service.dart` during W2.7.

---

### M4 — `IntroPageIndicator` extracted but never wired into `AppIntroScreen` (W5.1 incomplete)

**File:** `lib/features/onboarding/presentation/screens/app_intro_screen.dart` (lines 22–23)

The S5 log explicitly notes: "`IntroPageIndicator` (animated dot-row; new widget per plan spec, not yet wired into screen to preserve observable behaviour)." The widget is re-exported from the screen file but is not used inside it — the `PageView` has no visible page indicator. The plan (W5.1) lists `IntroPageIndicator` as a required extraction deliverable. Extracting a widget and re-exporting it without wiring it is half-done work.

---

### M5 — `scheduler_providers.dart` uses raw string `goalType` in its public API

**File:** `lib/features/scheduler/presentation/providers/scheduler_providers.dart` (line 205)

```dart
Future<PaceStatus?> paceStatus(
  Ref ref, {
  ...
  String goalType = 'deadline',   // ← raw string in @riverpod provider signature
  ...
}) async {
```

A `@riverpod` provider with a raw string parameter in its signature bakes the `'deadline'` / `'pace'` distinction into the public provider API. Every consumer must pass one of these magic strings. This is primitive obsession embedded in an API boundary rather than internal logic.

---

### M6 — `DataExportImportService` is 933 LOC with two giant methods — a god-class in domain/services

**File:** `lib/features/settings/domain/services/data_export_import_service.dart` (933 LOC)

`exportData()` (line 97) and `importData()` (line 505) are each ~200–400 LOC with long sequential DAO calls. The class has no clear single responsibility: it handles export serialisation, import deserialisation, schema validation, table-by-table migration, and the `_resolveScheduleJson` decode helper. This is the same data-layer monolith pattern the plan called out for other services.

The plan task W1.18 noted this file should be verified and potentially deleted ("data_export_import_service.dart (946 LOC) — confirm not parked epic before W1.18"). It was not deleted — it appears to be live functionality used by settings. However its internal decomposition was also not done as part of W5.

---

### M7 — `DateTime.now()` still raw in 7 sites in `features/tutoring/`

**Files:**
- `lib/features/tutoring/presentation/screens/decline_invite_screen.dart:80`
- `lib/features/tutoring/presentation/screens/accept_invite_screen.dart:153`
- `lib/features/tutoring/presentation/screens/tutor_audit_log_screen.dart:79, 81, 90, 92, 473`

W5.19 fixed 6 sites and the S5 log states "Audit grep #6 (No DateTime.now() outside core/time/) now active and passing." However, all 7 tutoring screen sites still use `DateTime.now()`. These files were generated by S3 (tutor mode UI) after W5.19 ran — the make audit grep either does not cover `presentation/screens/` or S3's tutor work was committed after the grep was enabled without a final clean pass.

Note: `tutor_audit_log_screen.dart` lines 79, 81, 90, 92 are passed to `showDatePicker(initialDate: DateTime.now())` — a Flutter API that does not accept the `DateTimeFactory` abstraction. Those four are arguably acceptable. Lines 80 (decline), 153 (accept), and 473 (audit log) are business-logic uses that should use `DateTimeFactory.nowUtc()`.

---

### M8 — `LocalAuthService` is misnamed — it is a domain service that orchestrates auth, not a repository-level service

**File:** `lib/features/account/domain/services/local_auth_service.dart`

Per the W5.20 naming intent: a class that validates input, hashes passwords, and issues sign-in/sign-up operations is more precisely a `*UseCase` or domain-service orchestrator than a `*Service`. The name `LocalAuthService` is not categorically wrong, but the plan's 11-pattern convention would name the sign-in operation `LocalSignInUseCase` and sign-up `LocalSignUpUseCase`. The class mixes two distinct use-case operations (signUp, signIn) and two validation helpers into one class.

This is a LOW-severity naming finding elevated to MEDIUM only because it combines with `SignInController` (H3) to suggest the auth domain still has muddled responsibility boundaries.

---

## LOW

### L1 — `app_intro_screen.dart` still contains two file-scope `Color(0xFF...)` constants after W5.1 split

**File:** `lib/features/onboarding/presentation/screens/app_intro_screen.dart` (lines 34–35)

`const _kNavy = Color(0xFF1A36A5)` and `const _kBg = Color(0xFFF8F9FB)` are defined at module scope in a presentation screen. Per W5.14/W5.15, colour literals outside `core/theme/` are banned. These are minor but demonstrate that the no-inline-colour rule was not applied during the W5.1 split.

---

### L2 — `SignInController` builds `AppLocalizations`-dependent error maps via a switch-over-string pattern that W5.22 targeted

**File:** `lib/features/account/presentation/notifiers/sign_in_controller.dart` (lines 87–113)

`_mapAuthError(code, l10n)` is a 25-case switch over Firebase auth error code strings. W5.22 targeted switch-over-strings for conversion to `Map<EnumKey, Handler>` registries. Firebase error codes are not an enum (they are external strings), but the pattern of a raw string dispatch table in the controller is the same smell the plan wanted removed from business logic. At minimum the dispatch table belongs in a dedicated `AuthErrorMapper` helper.

---

### L3 — `SessionPersistenceService` is more accurately a `SessionRepository` or `SessionGateway`

**File:** `lib/features/account/domain/services/session_persistence_service.dart`

This class wraps `SharedPreferences` (a platform persistence gateway) and `DeviceRegistryDatabase` (a local data store). By the W5.20 naming rules, a class that sits between the domain and a persistence backend is a `*Repository` or `*Gateway`, not a `*Service`. `SessionRepository` would be the cleaner name.

---

### L4 — `sign_in_screen.dart` `_profileMode` persistence round-trips through string even though `OnboardingResumeStore.load()` returns `String? profileMode`

**File:** `lib/features/onboarding/presentation/screens/onboarding_screen.dart` (lines 85, 116–118)

`OnboardingResumeStore` stores and loads `profileMode` as a `String`. Converting `_profileMode` to `ProfileMode` enum (M1 above) requires fixing the `OnboardingResumeStore` serialisation layer too. The snapshot value object `OnboardingSnapshot` at `lib/features/onboarding/presentation/providers/onboarding_resume_store.dart` still has `String? profileMode` — so the fix requires coordinating two files.

This is a LOW finding because it is a natural consequence of M1 and requires a two-file change rather than indicating a systemic pattern.

---

### L5 — `_IntroPage` in `app_intro_screen.dart` (473 LOC total) holds three switch-variant-dispatch methods that duplicate the enum branch

**File:** `lib/features/onboarding/presentation/screens/app_intro_screen.dart`

`_IntroPage` has `_buildHero()`, `_titleRich()`, `_subtitleRich()`, and `_buildProgressArea()` — each containing a `switch (data.variant)` over `_IntroPageVariant`. The three-value enum is dispatched four times in the same class. This is a violation of the open/closed principle: adding a fourth intro page requires adding four switch arms in four separate methods. A `_IntroPageContent` data class holding hero/title/subtitle/progress widgets per variant would collapse all four dispatches.

This is LOW because the screen is now well under 400 LOC and the duplication is contained. But it is the kind of structural debt that accumulates as pages are added.

---

## God-Screen Split Summary

| Screen | Pre-split LOC | Post-split LOC | Under 400? | Widgets in `widgets/`? | Notes |
|---|---:|---:|:---:|:---:|---|
| `app_intro_screen.dart` (W5.1) | 1370 | 473 | No (but <600) | Yes (`widgets/` 5 files) | `IntroPageIndicator` extracted but not wired (M4) |
| `sign_in_screen.dart` (W5.2) | 1237 | 317 | Yes | Yes (`widgets/` 4 files + notifier) | Clean split |
| `gamification_screen.dart` (W5.3) | 1127 | 294 | Yes | Yes (`widgets/` 9 files) | Clean split |
| `profile_picker_screen.dart` (W5.4) | 1059 | 354 | Yes | Yes (`widgets/` 7 files) | Clean split |
| `onboarding_screen.dart` (W5.5) | 1030 | 423 | No (borderline) | Yes (`steps/` 5 files) | `_profileMode` string field persists (M1) |
| `reward_configuration_screen.dart` (W5.6) | 1004 | 588 | No | Yes (`widgets/` 6 files) | Color literals not migrated (H4); largest remaining screen |

`reward_configuration_screen.dart` at 588 LOC is the only split outcome that concerns me for size. The file still contains a full `_RewardPreview` widget class (lines 494–588), `_openManageRewardsSheet` (52 LOC inline), `_confirmDelete` (26 LOC inline), `_saveReward` (43 LOC inline), and `_syncControllersFromState` (12 LOC). The inline methods could be moved to the controller; the `_RewardPreview` widget could be its own file.

---

## Naming Convention Assessment

The W5.20 naming pass correctly renamed `ConnectivityService → ConnectivityGateway` and `NotificationService → NotificationGateway`. The following issues remain:

| Class | Current name | Issue | Correct name per plan |
|---|---|---|---|
| `TutorNotificationGateway` | `class TutorNotificationGateway` in `tutor_notification_service.dart` | File name doesn't match class name (M2) | Rename file to `tutor_notification_gateway.dart` |
| `LocalAuthService` | Domain auth orchestrator | Mixes sign-in and sign-up use cases (M8) | `LocalSignInUseCase` + `LocalSignUpUseCase` |
| `SessionPersistenceService` | Wraps SharedPrefs + registry | Platform-adapter role should be Gateway/Repository (L3) | `SessionRepository` or `SessionGateway` |
| `UserProfileService` | Two methods: `setUserMode` / `getUserMode` | Single-purpose DAO wrapper is a Repository | `UserProfileRepository` |

Genuinely correct uses of `*Service`: `StreakService`, `PinService`, `PointsService`, `RewardMilestoneService`, `BulkPriorCompletionService`, `CurriculumImportService`, `TrackCreationService`, `TrackEditService`, `DataExportImportService` — all are cross-cutting domain orchestrators. The plan asked to rename only those that are "actually" Repositories/Gateways/UseCases, and the above four qualify.

---

## ConsumerWidget Conversion Assessment (W5.21)

The S5 log documents converting `SchedulerScreen` from `ConsumerStatefulWidget` to `ConsumerWidget` + a `@riverpod` Notifier for `isGroupedView`. Four other candidates were assessed and correctly deferred (complex lifecycle state). The `GamificationScreen` was left as `ConsumerStatefulWidget` holding `int? _trackFilterId` — a single value that could be a provider but is also a legitimate single-field local UI state. Acceptable.

---

## Sealed Union / Boolean State Machine Assessment (W5.7-W5.9)

- W5.8 (SyncOrchestrator): `_PullGuard` sealed union is correctly implemented (`_PullNeverRun`, `_PullCompleted`, `_PullFailed`). The `bool _started` field (line 204) is a simple lifecycle guard, not a state machine — acceptable.
- W5.9 (OutboxProcessor `_flushInProgress`/`_rerunRequested`): The `ListenerSupervisor` has the `_RestartCycle` sealed union. The `OutboxProcessor` has no boolean state fields visible in the file — resolved.
- W5.7 (feature screen boolean state machines): `signup_screen.dart` still has `bool _isLoading` as a single-boolean spinner driver (H1, not converted). All other surveyed screens use either a sealed controller state or a single UI-only boolean (acceptable for simple loading guards).

`upgrade_to_cloud_screen.dart` (752 LOC) is a positive example: it uses the sealed `_UpgradePhase` union (`_PhaseForm`, `_PhaseVerifying`, `_PhaseCollision`, `_PhaseSuccess`) correctly and has no multi-boolean state machine.
