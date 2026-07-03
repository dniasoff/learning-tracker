# Epic 27 Adversarial Review — DNI-315 (Discipline & Closure)

**Reviewer:** Claude Sonnet 4.6 (adversarial mode)
**Date:** 2026-05-14
**Git HEAD:** f367942a (actual HEAD — task spec cited fdc2d4f1 which is stale)
**Review scope:** Codebase as it exists on disk including staged changes (all files readable)

> **Important staging caveat:** Most Epic 27 deliverables are **staged but not yet committed** (present in git index, `A` in `git status`, not in `HEAD`). The files are physically present on disk and reviewable. Where an AC requires something that only exists in a worktree (`.claude/worktrees/dev-dni-386-b/`), it is marked FAIL.

---

## DNI-377 — 27.1: Test infrastructure — fake_cloud_firestore, golden scaffolding, real-Drift in-memory helper

**Status:** ✅ PASS

**AC checks:**

- `test/helpers/firestore_fake.dart` provides configured `FakeFirebaseFirestore` with rules pre-loaded: PASS — `learning_tracker/test/helpers/firestore_fake.dart` exists (staged). Provides `createFakeFirestore({authenticatedUid, strictRules})` that loads `firestore.rules` from either `../firestore.rules` or `firestore.rules`. Strict-mode authenticated test present in acceptance suite at `epic_27_test_infrastructure_test.dart:70-90`.
- `test/helpers/golden_runner.dart` provides `goldenTest(name, build)` with automatic Hebrew/English variants: PASS — `learning_tracker/test/helpers/golden_runner.dart` exists (staged). `goldenTest()` loops over `[Locale('en'), Locale('he')]` and emits two `testWidgets` entries per call (line 43–76).
- `test/helpers/drift_memory.dart` provides `inMemoryDb()` returning fresh schema-v1 Drift DB: PASS — `learning_tracker/test/helpers/drift_memory.dart` exists (staged). Returns `UserDatabase(NativeDatabase.memory())` at current `schemaVersion`. Acceptance test `epic_27_test_infrastructure_test.dart:115-170` asserts `schemaVersion >= 13` and independence between instances.
- At least one consumer of each helper exists: PASS — `epic_27_test_infrastructure_test.dart` consumes all three; `epic_27_story_06_streak_reconciles_test.dart` imports `drift_memory.dart` and `firestore_fake.dart`; `epic_27_story_4_widget_golden_test.dart` imports `golden_runner.dart`.
- `fake_cloud_firestore` dev dependency added: PASS — `pubspec.yaml` diff shows `fake_cloud_firestore: ^4.1.0` added to dev_dependencies.

**Gaps:** None material. The `epicore_27_test_infrastructure_test.dart` acceptance test also covers 27.3 AC checks inline, which is an unusual coupling but functional.

---

## DNI-378 — 27.2: Unit test suite for pure functions

**Status:** ⚠️ PARTIAL

**AC checks:**

- Each of the seven pure functions has a unit test file covering branches: PARTIAL
  - `PaceCalculator`: PASS — `test/features/scheduler/domain/services/pace_calculator_test.dart` (committed). Multiple branches: deadline, velocity, nil-days edge cases.
  - `StreakReducer`: FAIL — `test/features/sync/domain/reducers/streak_reducer_test.dart` contains **only a skip stub**: `test('StreakReducer coverage placeholder', () {}, skip: 'DNI-337 pending')`. DNI-337 **has** landed (`5423d95f`) but the stub was never updated to real tests.
  - `CrossCurriculumAggregator`: PASS — `test/core/services/cross_curriculum_aggregator_test.dart` (committed, multiple cases).
  - `CurriculumLabelRenderer`: PASS — `test/core/labels/curriculum_label_renderer_test.dart` (committed).
  - `ProgramRefResolver`: PASS — `test/core/content/program_ref_resolver_test.dart` (committed, 10 test cases).
  - `StageValidator`: PASS — `test/features/stages/domain/services/stage_validator_test.dart` (found, committed).
  - `LocalDayClock`: PASS — `test/core/time/local_day_clock_test.dart` (committed, covers `SystemLocalDayClock` and `FakeLocalDayClock`).
- Combined unit-test coverage ≥ 90%: CANNOT VERIFY — the `StreakReducer` file is entirely skipped, so coverage for that class is 0%.
- Tests are pure (no DB, no Firestore, no I/O): PASS for the five functioning tests.

**Gaps:** The `StreakReducer` skip stub (`test/features/sync/domain/reducers/streak_reducer_test.dart:11`) was committed with message "replace StreakReducer tests with skipped stub pending DNI-337" (5a608d5e). DNI-337 subsequently landed (5423d95f), relocating the reducer to `core/streak/streak_reducer.dart`, but the stub was **never updated to activate the real tests**. There is no `test/core/streak/streak_reducer_test.dart`. The 90% coverage AC cannot be met with one of seven functions at 0% coverage.

---

## DNI-379 — 27.3: DAO and repository test suite using real in-memory Drift

**Status:** ✅ PASS

**AC checks:**

- Every DAO has at least one test per public method using `inMemoryDb()`: PASS — 22 DAO source files exist in `lib/core/database/daos/` (excluding `.g.dart`); 23 test files exist in `test/core/database/daos/` (one extra: `track_scoped_dao_test.dart`). All 22 source DAOs have matching `_test.dart` files. Verified by filesystem diff: no missing test files.
- All 18 DAOs are covered: PASS (the AC says 18; the actual count is 22 DAOs, but all are covered — the story was authored when fewer DAOs existed).
- `MockUserDatabase` references are deleted: PASS — `grep -r "MockUserDatabase" test/` returns zero results (verified, excluding the self-referential epic_27_test_infrastructure_test.dart which only mentions it in string literals).
- Per-method branch coverage ≥ 80% across DAOs: CANNOT INDEPENDENTLY VERIFY without running coverage, but the test infrastructure is in place. The `epic_27_test_infrastructure_test.dart:AC2` test itself asserts that each DAO test file uses `inMemoryDb()` from `drift_memory.dart` — this runs at test time and would catch violations.

**Gaps:** The 80% coverage floor is a runtime assertion that cannot be verified statically. The acceptance test for 27.3 (embedded in `epic_27_test_infrastructure_test.dart`) checks file-level structure but not method-level coverage depth.

---

## DNI-380 — 27.4: Widget + golden test suite (canonical screens) with Hebrew variants

**Status:** ⚠️ PARTIAL

**AC checks:**

- Golden tests exist for TrackCard (4 data shapes), StatCard, StreakHero, CurriculumPicker, ProgressOverview: PASS — `epic_27_story_4_widget_golden_test.dart` (staged) registers `goldenTest()` calls for all five widget categories. TrackCard has a loop over 4 shapes. All use `skipGolden: true`.
- Each test ships an `en` and `he` variant (RTL): PASS — `goldenTest()` helper automatically produces both variants. The test file registers `4×2 + 5×2 = 18` widget test entries (TrackCard 4 shapes × 2 locales + 5 others × 2 locales).
- Interaction tests cover `CompletionButton`, `BulkMarkScreen`, `DraggableOrderItem`: PARTIAL
  - `CompletionButton`: only a type-existence check (`expect(CompletionButton, isNotNull)`), not a real interaction test.
  - `BulkMarkScreen`: same — only a type-existence check.
  - `DraggableOrderItem`: PASS — three real `testWidgets` tests covering drag-handle visibility and RTL directionality (lines 179–247).
- Golden diffs upload to CI artifacts on failure: PASS — `ci.yml` has `Upload golden failure artifacts` and `Upload golden test failures (diffs)` steps that run on failure and upload to artifacts with 7/14-day retention.
- Locale-named PNG baselines exist (`name.en.png`, `name.he.png`): FAIL — `test/golden/goldens/` contains only 5 phone-screen PNGs without locale suffixes (`phone_1_dashboard.png` etc.). No `*.en.png` or `*.he.png` files exist anywhere in the test tree. All 27.4 golden tests use `skipGolden: true`, so no baselines have been generated.

**Gaps:** (1) `CompletionButton` and `BulkMarkScreen` interaction tests are stub type-checks, not real widget interaction tests. (2) Golden PNG baselines with locale-name convention (`name.en.png`, `name.he.png`) do not exist because `skipGolden: true` is used throughout. The AC says "golden tests exist" — the test code exists, but the golden image files themselves don't, so a CI run without `--update-goldens` would fail if `skipGolden` were ever removed.

---

## DNI-381 — 27.5: Integration test — bulk_mark_prior_does_not_credit_streak (any stage)

**Status:** ⚠️ PARTIAL

**AC checks:**

- Creates a fresh in-memory DB, simulates bulk-mark-prior over 50 items across stages 1, 2, and 3: PARTIAL — `epic_27_story_05_bulk_mark_prior_test.dart` (staged) does simulate 50 refs × 3 stages = 150 completions, but uses `createTestDatabase()` from `test/helpers/test_database.dart`, NOT `inMemoryDb()` from `test/helpers/drift_memory.dart` as specified by the 27.1 scaffolding contract.
- Asserts `StreakStateProvider.read()` returns `currentStreak == 0` and `maxStreak == 0`: PARTIAL — The test asserts `reducerState.currentStreak == 0` and `reducerState.maxStreak == 0`, but it does this by calling `const StreakReducer().reduce(const <StreakEvent>[], today: today)` — reducing over an **empty list hardcoded in the test**, not reading back from `StreakStateProvider` over the actual database rows created by `bulkMarkComplete`. The DAO-level assertion (zero rows) is correct, but the reducer call is disconnected from what actually happened in the DB.
- Asserts `streak_events` table contains zero rows attributable to the bulk-mark batch: PASS — `db.select(db.streakEvents)` returns zero rows before `StreakStateProvider` is called (the comment explains this is deliberate to avoid `StreakRestorer` pollution).
- 150 completion rows persisted: PASS — `expect(completionRows, hasLength(150))` at line 137.
- Happy-path guard test (awardGamificationPoints=true does credit streak): PASS — second test at lines 170–197 asserts `streakRows hasLength(1)` and `maxStreak == 1`.

**Gaps:** (1) Uses `createTestDatabase()` instead of `inMemoryDb()` — technically both create in-memory Drift DBs but the former predates the 27.1 helper contract. (2) The `StreakStateProvider.read()` AC is only partially met: the reducer call with an empty list proves the reducer math, but doesn't prove that `StreakStateProvider` over the actual data returns zeros.

---

## DNI-382 — 27.6: Integration tests — streak_reducer_reconciles + cloud_restore_preserves_streak

**Status:** ✅ PASS

**AC checks:**

- Appends a known sequence of streak events and asserts reducer's `(currentStreak, maxStreak)` matches expectation: PASS — `epic_27_story_06_streak_reconciles_test.dart:AC1` (staged). Appends 6 events over May 1–10 with a 4-day gap, fixes today at May 10, asserts `currentStreak == 3`, `maxStreak == 3`, `lastCompletionDayUtc == 2026-05-10`.
- Cloud restore: fresh device with empty `streak_events` pulls `completion_events`, reducer reconstitutes events per distinct UTC day, correct streak computed: PASS — AC2 test seeds 3 completion_events to fake Firestore (2 on May 9, 1 on May 10), mirrors them into `completions`, runs `StreakRestorer.restoreIfEmpty`, asserts exactly 2 `streak_events` rows for the correct UTC days, then asserts `currentStreak == 2`, `maxStreak == 2`.
- Idempotency: PASS — third test asserts second call to `restoreIfEmpty` is a no-op (still 1 row after two calls).
- Uses `inMemoryDb()` from 27.1 scaffolding: PASS — `import '../helpers/drift_memory.dart'` at line 38; `setUp(() => db = inMemoryDb())`.
- Uses `createFakeFirestore()` from 27.1 scaffolding: PASS — `import '../helpers/firestore_fake.dart'` at line 37; AC2 calls `createFakeFirestore(authenticatedUid: _uid)`.

**Gaps:** None material.

---

## DNI-383 — 27.7: Integration tests — multi_profile_isolation + track_card_canonical_layout

**Status:** ⚠️ PARTIAL

**AC checks:**

- Creates Profile A and B, records completion in A, asserts every cross-profile-aware query for B returns empty: PASS — `epic_27_story_7_isolation_and_canonical_layout_test.dart` (staged). 14 distinct isolation assertions covering `getCompletionsByProfile`, `getCompletionsByCurriculumAndProfile`, `getCompletionsForContentAndProfile`, `getAggregateCountByProfile`, `getTrackBreakdownByProfile`, `completionExistsByProfile`, `getCompletionsByDateRangeAndProfile`, `hasCompletionsInDateRangeByProfile`, `getReviewCountsByItem`, `getExistingSefariaRefsForBulkStage`, `getCompletionsByProfileForSefariaRefs`, dashboard provider surfaces, and cross-table isolation for bookmarks and goals.
- Dashboard provider for B does not surface A's completion: PASS — tested via DAO-layer assertions (lines 214–245).
- Track-card canonical layout — all 4 shapes produce same runtime type: PASS — constructs `TrackCardViewModel` for all 4 shapes, asserts `runtimeType.toSet().length == 1` and shape-specific fields are non-null.
- Widget-tree comparison (`Widget` traversal comparison): FAIL — this test is explicitly skipped: `skip: 'Deferred to widget-test story — TrackCard widget integration tests not yet in scope'` (line 228).
- Uses `createTestDatabase()` not `inMemoryDb()`: NOTE — same as 27.5, uses older helper.

**Gaps:** The widget-tree `Widget` traversal comparison AC is skipped/deferred. The test correctly documents this as intentional but it represents an unmet AC item.

---

## DNI-384 — 27.8: Integration tests — firestore_rules (emulator) + offline_completion_flushes

**Status:** ⚠️ PARTIAL

**AC checks:**

- Allowed cases pass and denied cases (negative points, future completedAt, arbitrary fields, deletes) are rejected: PARTIAL — `epic_27_story_27_8_rules_and_offline_flush_test.dart` (staged). The delete-rejection tests work dynamically via `fake_firebase_security_rules`. However, the `negative points`, `future completedAt`, and `arbitrary fields` denials are tested **statically** (string-matching against the `firestore.rules` file content) because `fake_firebase_security_rules` does not evaluate `request.resource.data` clauses. This is a documented limitation in `firestore_fake.dart`.
- 50 offline commits land 50 outbox rows and zero Firestore docs; drain flushes all 50: PASS — `_ToggleableFakeGateway` simulation. Test asserts 50 outbox rows while offline, 0 Firestore docs, then 50 Firestore docs and 0 outbox rows after drain.
- Single broken row is retained for retry while siblings flush: PASS — second drain test with `failOn = {1}` asserts `flushed == 2`, 1 remaining outbox row with `attempts == 1` and `lastError != null`.

**Gaps:** The `negative points`, `future completedAt`, and field-whitelist violations cannot be dynamically exercised in the in-process fake — they rely on static rule-text assertions. A true `firestore-rules` emulator test (as planned in `test/firestore-rules/`) would fully satisfy the AC; that directory does not exist in the main branch.

---

## DNI-385 — 27.9: Integration tests — pin_lockout_cycle + log_redaction + bookmark_advance_atomic

**Status:** ✅ PASS

**AC checks:**

- 5 failed attempts trigger 15-minute cooldown; cooldown rejects at 14m59s boundary; correct PIN accepted after 15 minutes; counter resets after success: PASS — `epic_27_integration_lockout_redaction_atomic_test.dart` (staged). Three tests with `FakeLocalDayClock.advance()`. Boundary tested at 14m59s (still locked), exactly 15m (unlocked). Post-unlock counter reset verified with 4 additional bad PINs.
- Field-allowlist redaction applied; event names preserved verbatim; `'PIN setup screen opened'` NOT redacted by substring match: PASS — Four redaction tests. `PiiRedactor.sensitiveKeys` sweep; legacy string API test; substring-safe event name test.
- Bookmark-advance atomicity — simulated failure rolls back completion: PASS — Drift `db.transaction()` test: completion insert + throw in bookmark step = 0 completions persisted. Success path = 1 completion persisted.

**Gaps:** None material.

---

## DNI-386 — 27.10: Custom lints Part 1 — no-curriculum-display-name-bypass, no-feature-cross-import

**Status:** ❌ FAIL

**AC checks:**

- `no-curriculum-display-name-bypass` exists: FAIL — The file `packages/custom_lints/lib/src/rules/no_curriculum_display_name_bypass.dart` does **not exist** in the main working tree or in the staged index. It only exists in the worktree `.claude/worktrees/dev-dni-386-b/`.
- `no-feature-cross-import` exists: FAIL — Same issue. `packages/custom_lints/lib/src/rules/no_feature_cross_import.dart` does not exist in the main branch or staging area.
- The `learning_tracker_lints.dart` entrypoint (staged) **imports both missing files** (`import 'src/rules/no_curriculum_display_name_bypass.dart'` and `import 'src/rules/no_feature_cross_import.dart'`), meaning the `custom_lint` package would **fail to compile** if run from the main branch.
- Both lints have a one-page README explaining the rule and remediation: PARTIAL — `packages/custom_lints/README.md` (staged) covers Rules 1–5 including explanations for both `no_curriculum_display_name_bypass` and `no_feature_cross_import`, but the rules themselves are absent.
- Fails CI on violations: FAIL — Lints cannot run if the package fails to compile.
- `custom_lint` is in the learning_tracker `pubspec.yaml` dev_dependencies: FAIL — `grep custom_lint learning_tracker/pubspec.yaml` returns nothing. The package is not wired into the Flutter project.

**Gaps:** DNI-386 work exists in worktree `dev-dni-386-b` but was not merged to `dev`. The entrypoint file imports non-existent sources — this is a broken staged artifact. The Flutter app's `pubspec.yaml` has no `custom_lint` dependency.

---

## DNI-387 — 27.11: Custom lints Part 2 — no-firebase-outside-core, no-raw-talker, RTL discipline

**Status:** ⚠️ PARTIAL

**AC checks:**

- `no-firebase-outside-core` exists: PASS — `packages/custom_lints/lib/src/rules/no_firebase_outside_core.dart` exists (staged). Test at `packages/custom_lints/test/no_firebase_outside_core_test.dart`.
- `no-raw-talker` exists: PASS — `packages/custom_lints/lib/src/rules/no_raw_talker.dart` exists (staged). Test at `packages/custom_lints/test/no_raw_talker_test.dart`.
- Direction-aware lints fail on `EdgeInsets.only(left:|right:)`, `Alignment.centerLeft|centerRight`, `TextAlign.left|right`: PASS — `packages/custom_lints/lib/src/rules/no_hardcoded_text_direction.dart` exists (staged). Test at `packages/custom_lints/test/no_hardcoded_text_direction_test.dart`.
- Each lint has a one-page README: PASS — `packages/custom_lints/README.md` covers all three rules.
- Fails CI on violations: FAIL — `custom_lint` is not in the `learning_tracker/pubspec.yaml` dev_dependencies (confirmed: `grep custom_lint learning_tracker/pubspec.yaml` → no output). The CI lint job conditionally skips if `custom_lint` is absent from `dart pub deps`.
- `no-curriculum-display-name-bypass` and `no-feature-cross-import` missing: FAIL — Entrypoint imports them but they don't exist (see DNI-386). The package cannot compile.

**Gaps:** Three of the five rules exist, but the package cannot compile due to the two missing DNI-386 imports. CI will skip custom_lint entirely because it's not in `pubspec.yaml`. The Part 2 rules are implemented but cannot be deployed without fixing Part 1.

---

## DNI-388 — 27.12: CI matrix — analyze, format, audit, lint, test, coverage-floor, firestore-rules, golden, arb-parity

**Status:** ⚠️ PARTIAL

**AC checks:**

- CI runs `dart analyze --fatal-infos`: PASS — `analyze` job at `.github/workflows/ci.yml:analyze` step.
- CI runs `dart format --set-exit-if-changed lib/ test/`: PASS — `format-check` job runs `dart format --set-exit-if-changed .` (slightly broader than spec: `.` not `lib/ test/`).
- CI runs `make audit` (all PART-4 greps): PASS — `audit` job runs `make audit`. However it **skips gracefully** if target absent (`if make -n audit`). This is a soft guard, not a hard block.
- CI runs `custom_lint`: PARTIAL — `lint` job runs `dart run custom_lint` but only if `custom_lint` is in `pubspec deps`. Since it's NOT in `pubspec.yaml`, the job will print `::notice::custom_lint not in pubspec — skipping` on every PR.
- CI runs `flutter test` (full suite): PASS — `test` job runs `make ci` which calls `test-all`.
- CI runs line-coverage floor at 60%: PASS — coverage floor enforced in `test` job after `make ci` using `lcov --summary`.
- CI runs `firestore-rules` (emulator): PARTIAL — job exists but skips gracefully if `test/firestore-rules/` directory absent. That directory does not exist on the main branch.
- CI runs golden tests and uploads diffs on failure: PASS — `Upload golden failure artifacts` and `Upload golden test failures (diffs)` steps both present.
- CI runs `tool/arb_parity_check.dart`: PASS — `arb-parity` job runs `dart run tool/arb_parity_check.dart` but also skips gracefully if file absent.
- Any failure blocks merge: PARTIAL — Some gates use graceful skip instead of hard fail (lint, firestore-rules, audit, arb-parity — all have `|| true` or `if-exists` guards).

**Gaps:** (1) `custom_lint` is not in `pubspec.yaml` so the lint job always skips — effectively the lint gate doesn't block merge. (2) `test/firestore-rules/` doesn't exist so the firestore-rules emulator job also always skips. (3) Several jobs use "skip gracefully if absent" rather than hard-failing, meaning the CI matrix has soft gates rather than hard enforcement.

---

## DNI-389 — 27.13: `make audit` Makefile target + tool/arb_parity_check.dart

**Status:** ✅ PASS

**AC checks:**

- `make audit` runs all 12 enforcement greps from PART 4: PASS — `Makefile` (staged) at `audit:` target runs exactly 12 labeled greps (`[1/12]` through `[12/12]`) covering: FirebaseAuth.instance.signOut, raw talker import, withDefault Constant(0), hebrewTermsScriptProvider, displayName(En|He), DateTime.now(), package:firebase_auth, debugPrint/print(), currentAccountId=1, empty catch blocks, EdgeInsets.only(left/right), package:cloud_firestore outside sync/auth.
- Target exits non-zero on any violation, printing file:line: PASS — `FAIL=1` set on any match; `exit 1` at end if `FAIL != 0`.
- Also runs `custom_lint`: PASS — `cd learning_tracker && dart run custom_lint` appended after the 12 greps.
- `tool/arb_parity_check.dart` reads both `.arb` files and exits non-zero on missing Hebrew keys: PASS — `tool/arb_parity_check.dart` (staged) reads `app_en.arb` and `app_he.arb`, reports missing keys, exits 0/1/2.

**Gaps:** Minor note: `coding-standards.md` states "All 5 layering greps" in the CI matrix table (line 260), contradicting the actual 12-grep implementation. This is a doc inconsistency, not a code gap.

---

## DNI-390 — 27.14: 12 analytics events wired + Crashlytics user ID set everywhere

**Status:** ⚠️ PARTIAL

**AC checks:**

- 12 events fire at the right moments:
  - `app_launch`: PASS — `main.dart:178` calls `analytics.logAppLaunch()` during app initialization.
  - `completion_recorded`: PASS — `CompletionWriter.commit()` calls `logCompletionRecorded()` on new rows. Verified at `lib/core/learning/completion_writer.dart` (indirectly through test assertions).
  - `bulk_mark_prior_used`: PASS — `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart:169` calls `logBulkMarkPriorUsed(...)`.
  - `track_added`: PASS — `lib/features/track_setup/domain/services/track_creation_service.dart:250` calls `logTrackAdded(...)`.
  - `streak_milestone_reached`: PASS — `lib/core/analytics/streak_milestone_analytics_observer.dart:51` calls `logStreakMilestoneReached(...)`.
  - `sync_failed`: PASS — `lib/features/sync/data/sync_engine.dart:408` calls `logSyncFailed(...)`.
  - `pin_locked_out`: PASS — `lib/core/services/pin_service.dart:284` calls `logPinLockedOut(...)`.
  - `parent_mode_entered`: PASS — `lib/features/parent_mode/presentation/widgets/parent_pin_keypad_dialog.dart:33` calls `logParentModeEntered(...)`.
  - `notification_fired`: PASS — `notification_scheduler.dart:65` and `streak_alert_service.dart:66` both call `logNotificationFired(...)`.
  - `notification_suppressed_sacred_time`: PASS — `notification_providers.dart:358` and `notification_scheduler.dart:101` both call `logNotificationSuppressedSacredTime(...)`.
  - `cloud_restore_completed`: PASS — `lib/features/sync/domain/services/device_restore_service.dart:225` calls `logCloudRestoreCompleted(...)`.
  - `crash_reported`: PASS — `lib/core/logging/crashlytics_service.dart:58` calls `logCrashReported(fatal: fatal)`.
- `setUserIdentifier(profileId)` called from a single observer: PASS — `main.dart:199-201`: comment explicitly states "Single observer — no scattered setUserIdentifier call sites (Story 27.14)". The observer listens to active-profile changes and calls `crashlytics.setUserIdentifier(id)`.
- An integration test asserts each event fires once per trigger: PARTIAL — `epic_27_story_14_analytics_test.dart` (staged, modified) covers 11 of 12 events with `FakeAnalyticsService` assertions. However, `sync_failed` event is tested only via the service method itself (`analytics.logSyncFailed(reason: 'network_timeout')`), not by firing the actual `SyncEngine` failure path through the wire-up. Several events are tested at the service interface level only, not through the full call stack.

**Gaps:** (1) The AC asks for an integration test asserting "each event fires once per trigger" via the real call stack; several tests only assert the `AnalyticsService` method directly (e.g., `logBulkMarkPriorUsed`, `logTrackAdded`, `logCloudRestoreCompleted`), not the trigger code path. (2) `parent_mode_entered` analytics event: the test calls `analytics.logParentModeEntered(profileId: 42)` directly, not through the `ParentPinKeypadDialog` widget.

---

## DNI-391 — 27.15: `docs/architecture.md` rewrite to match rebuild reality

**Status:** ⚠️ PARTIAL

**AC checks:**

- Doc reflects rebuild reality: PASS — `docs/architecture.md` (staged) describes schema v14 (actual is v13/14), 7-class SyncEngine (named), single CompletionWriter, single StreakReducer, single ContentIndex, locale auto-detection, 16 active features.
- Zombie features (`tutor_mode`, `test_tracking`) removed: PASS — line 190: "zombie features `tutor_mode` and `test_tracking` removed in Epic 25/26".
- 4 custom lints described: PARTIAL — line 38: "**4 guardrail lints** (planned, Stories 27.10–27.11)". The word "planned" is inaccurate; Stories 27.10 and 27.11 are marked Done in Linear. Three of four lints exist on disk (Part 2), but the doc still labels them as planned future work rather than delivered.
- 10 named integration tests listed: PARTIAL — `docs/architecture.md:582-590` lists the integration tests by story, but enumerates them by story label, not as 10 specific named tests. The CI matrix section (line 564) exists.
- Table list generated from Drift annotations via `tool/gen_arch_tables.dart`: PASS — `tool/gen_arch_tables.dart` (staged) exists; `docs/architecture.md:520` states "Generated by `tool/gen_arch_tables.dart`"; Makefile has `gen-arch-tables` target. The table itself appears at architecture.md:552.
- Doc passes markdown lint and renders correctly: NOT VERIFIED — no linter output available; doc appears structurally sound.

**Gaps:** The "planned" label on the 4 custom lints in architecture.md is inaccurate given the stories are marked Done. Also, the doc lists `schemaVersion` contextually (mentions v14 in one place, v13 in the `inMemoryDb()` AC check) — this is a minor drift.

---

## DNI-392 — 27.16: CLAUDE.md and docs/coding-standards.md updated with layering rules and enforcement greps

**Status:** ⚠️ PARTIAL

**AC checks:**

- Layering rules from Principle P2 documented with directionality `app → features → core`: PASS — `docs/coding-standards.md` (staged) opens with "The dependency direction is strictly `app → features → core`." Five numbered rules documented. `learning_tracker/CLAUDE.md` (staged) also contains the layering rules section with all five rules.
- 12 enforcement greps listed with explanations: FAIL — `docs/coding-standards.md` contains only **5** "Quick grep" sections (one per layering rule), not 12. The `make audit` target in the Makefile implements 12 greps, but the coding-standards doc explicitly says "All 5 layering greps (see above)" in the Enforcement section (line 260). The AC requirement for "12 enforcement greps listed with explanations" is not met in the doc.
- 4 custom lints listed with READMEs cross-referenced: PARTIAL — `docs/coding-standards.md:Custom Lints Reference` section (lines 269-277) lists all 4 lints in a table with DNI references. However, the entry for `no-curriculum-display-name-bypass` and `no-feature-cross-import` note "not yet merged to `origin/dev`" (line 269), which contradicts their Done status. The READMEs exist in `packages/custom_lints/README.md` but are not individually cross-referenced with URLs.

**Gaps:** (1) The doc documents only 5 of the 12 enforcement greps that `make audit` actually runs — 7 greps are missing from the doc. (2) The custom lints documentation notes they are "not yet merged to `origin/dev`" despite being marked Done.

---

## Epic 27 Summary

| Story | Title | Status |
|-------|-------|--------|
| DNI-377 (27.1) | Test infrastructure helpers | ✅ PASS |
| DNI-378 (27.2) | Unit tests for pure functions | ⚠️ PARTIAL |
| DNI-379 (27.3) | DAO/repo tests with real Drift | ✅ PASS |
| DNI-380 (27.4) | Widget + golden tests | ⚠️ PARTIAL |
| DNI-381 (27.5) | bulk_mark_prior_does_not_credit_streak | ⚠️ PARTIAL |
| DNI-382 (27.6) | streak_reducer_reconciles + cloud_restore | ✅ PASS |
| DNI-383 (27.7) | multi_profile_isolation + canonical_layout | ⚠️ PARTIAL |
| DNI-384 (27.8) | firestore_rules + offline_completion_flushes | ⚠️ PARTIAL |
| DNI-385 (27.9) | pin_lockout + log_redaction + bookmark_atomic | ✅ PASS |
| DNI-386 (27.10) | Custom lints Part 1 (display-name, cross-import) | ❌ FAIL |
| DNI-387 (27.11) | Custom lints Part 2 (firebase, talker, RTL) | ⚠️ PARTIAL |
| DNI-388 (27.12) | CI matrix | ⚠️ PARTIAL |
| DNI-389 (27.13) | `make audit` + arb_parity_check | ✅ PASS |
| DNI-390 (27.14) | 12 analytics events + Crashlytics user ID | ⚠️ PARTIAL |
| DNI-391 (27.15) | `docs/architecture.md` rewrite | ⚠️ PARTIAL |
| DNI-392 (27.16) | CLAUDE.md + coding-standards.md | ⚠️ PARTIAL |

**Result: 4/16 PASS, 11/16 PARTIAL, 1/16 FAIL**

---

## Cross-Cutting Issues

### Issue 1 — DNI-386 rules missing from main branch (Critical)
`no_curriculum_display_name_bypass.dart` and `no_feature_cross_import.dart` do not exist in `packages/custom_lints/lib/src/rules/`. The `learning_tracker_lints.dart` entrypoint (staged) imports them, making the entire `custom_lint` package fail to compile. This blocks DNI-386, DNI-387, and DNI-388 from delivering their key value.

### Issue 2 — `custom_lint` not in `learning_tracker/pubspec.yaml` (Critical for DNI-387/388)
The lint package is built but not wired into the Flutter project. The CI `lint` job silently skips because `dart pub deps` doesn't find `custom_lint`. No lint rule can catch violations at CI time.

### Issue 3 — StreakReducer unit test still a skip stub (DNI-378)
`test/features/sync/domain/reducers/streak_reducer_test.dart` contains only `test('...', () {}, skip: 'DNI-337 pending')`. DNI-337 landed on commit `5423d95f` but the stub was never activated. There is no `test/core/streak/streak_reducer_test.dart`. The StreakReducer has zero unit test coverage from Story 27.2.

### Issue 4 — Most deliverables are staged but not committed (Process)
All helpers, integration tests, custom lint rules, CI changes, and documentation are in the git index (staged) but not committed to `HEAD` (f367942a). Linear shows these stories as Done. The reviewer interprets "delivered in the codebase" as including staged changes — but the deliverables cannot be reviewed in isolation from each other since they haven't been committed as separate atomic units.

### Issue 5 — `test/firestore-rules/` emulator directory absent (DNI-388)
The CI job for `firestore-rules` has a hard directory check and skips if absent. This gate never runs.

### Issue 6 — coding-standards.md documents 5 greps, Makefile implements 12 (DNI-392)
The documentation promises "12 enforcement greps" in the AC but the doc only has 5 Quick grep sections. Developers reading the doc get an incomplete picture of what `make audit` actually enforces.
