# Tutor Edit Propagation — Orchestration Log

Append-only, timestamped. Maintained by the Edit-Propagation Orchestrator (Opus).
Squad: `tutor-edit-squad` (Sonnet teammates). Plan: `tutor-edit-propagation-plan.md`.

Event types: `kickoff` · `verify` · `dispatch` · `sync` · `return` · `finding` · `fix` · `escalate` · `decision`.

---

## [2026-05-28 09:58] kickoff
- **scope:** orchestration · Read all source docs (plan, talmid-view plan + log, product-rules §1–9, hebrew-terms, CLAUDE.md, MEMORY.md). Confirm plan unchanged + foundation matches.
- **detail:** Plan = **Option 2** (CF writes via existing tutor CFs to `users/{parentUid}/learner_profiles/{profileId}/…`) **+ delta listeners**. Keystone = intercept at the push/facade layer when `activeTutoredProfileSelectionProvider != null`; reuse existing serializers + doc-id conventions verbatim. Decisions **D1–D6 resolved** (the prompt locks them — don't re-litigate). 6 streams; 3 waves; V1–V6 verification.
- **next:** Verify foundation in code (CFs unwired; serializers + facades present).

## [2026-05-28 09:58] verify · foundation
- **scope:** orchestration
- **detail:** Confirmed against live code (read, not self-report):
  - **TutorWriteService** at `lib/features/tutoring/data/services/tutor_write_service.dart` — all 10 wrappers present (resetCompletion / upsertGoal / deleteGoal / upsertTrack / deleteTrack / upsertStageDefinition / upsertStudyDayConfig / deleteStudyDayConfig / updateGamificationSettings / editProfile) + `TutorCallableInvoker` typedef for test injection.
  - `tutorWriteServiceProvider` exists (`lib/features/tutoring/presentation/providers/tutor_grant_providers.dart:90`) — but **zero consumer call sites** (grep returns only the provider itself, generated `.g.dart`, and the test file). ⇒ The gap is real: CFs wired but unconnected.
  - **Both facade chokepoints present** — keystone D4 is reachable:
    - `OutboxSyncWriteFacade` (`lib/features/sync/data/outbox_sync_write_facade.dart`) — `pushGoal`/`deleteGoal`/`pushStageDefinitions`/`pushStudyDayConfig`/`pushGamificationSettingsSnapshot`.
    - `SyncEngine`/`PushPipeline` — `goal_repository_impl.dart:221,230` calls `_syncEngine.pushGoal/deleteGoal` directly; `completion_repository_impl.dart:216,288` calls `_syncEngine?.pushGamificationSettingsSnapshot()`.
  - **Serializers/codecs exist:** `lib/core/sync/codec/{track_codec,stage_definition_codec,study_day_config_codec,settings_codec}.dart` + `pushGamificationSettingsSnapshot` snapshot method. (R2 parity targets confirmed reachable.)
  - **Functions source:** single file `learning_tracker/functions/src/index.ts` (Wave-3 of talmid-view added the 10 tutor CFs; parity CFs to be added here).
  - **Outbox guard:** `outbox_providers.dart:70` calls `profileDao.isProfileTutored`; outbox processor (`outbox_processor.dart:214-215`) blocks tutored profiles — safety net intact.
  - **Branch:** `dev`. **Working tree:** 14 uncommitted files from Daniel's recent polish (gradle.properties, app_shell.dart, router_provider.dart, profile_dao.dart, profile_guard.dart, tutored_pull_providers.dart, profile_switcher_sheet.dart, tutored_children_section.dart, settings_screen.dart, user_profile_header_card.dart, active_tutored_profile_provider.dart, manage_tutors_providers.dart, pubspec.lock, app_shell_test.dart). Teammates must investigate-not-overwrite; rebase their changes on this state, do not revert Daniel's polish.
- **verdict:** Foundation real, matches the plan. Cleared to dispatch.
- **next:** Create team + log + tracker; create tasks; acknowledge Daniel; dispatch Wave 1 (S1 + S6 parallel).

## [2026-05-28 09:58] decision · team
- **detail:** Created Sonnet squad team `tutor-edit-squad` (`TeamCreate`). All streams spawn into it as named Sonnet teammates (`model: sonnet`, `subagent_type: general-purpose`, stable `name`). Orchestrator writes only this log + the tracker; all code work delegated. Permission mode inherited (so `firebase deploy --only functions` at the P2 gate naturally routes through human approval — Daniel stays in control of the live deploy [[firestore-rules-deploy]]).
- **next:** Pre-populate tracker; create high-level tasks; dispatch Wave 1.

## [2026-05-28 10:00] dispatch · S1 — then HELD
- **scope:** dispatch · Spawned `S1-routing` (Sonnet, background, `tutor-edit-squad`, task #1 in_progress, owner=`S1-routing`). Briefing: build `TutoredWriteRouter`, wire BOTH facade chokepoints (`OutboxSyncWriteFacade` + `SyncEngine`/`PushPipeline` direct calls from repos), preserve non-tutored path, unit tests proving tutored→CF / non-tutored→outbox / outbox depth-0 hardening. Gate = P1.
- **interrupt:** Daniel paused immediately after S1 dispatch with `1st commit and ensure git is clean`. **S6 dispatch held** (Wave 1 incomplete).
- **action:** `SendMessage` S1 → `HOLD — cleanup commit in flight; continue reading, no edits; await proceed`.
- **next:** commit the 14-file polish on the working tree + this log + tracker; verify clean; release S1; dispatch S6.

## [2026-05-28 10:25] return + verify · S1 P1 keystone — PASS with one HIGH advisory carried to S2
- **scope:** sync/S1 · `S1-routing` reported P1 ready (commit `f1861516` — `feat(tutor): S1 — TutoredWriteRouter keystone`, 4 files, +707/-1, 14 tests).
- **VERIFIED by orchestrator (read diff + code + tests, not self-report):**
  - **Router DESIGN sound:** `TutoredWriteRouter` (`lib/features/tutoring/data/routers/tutored_write_router.dart`, +225) is a `SyncWriteFacade` decorator. When `selection != null`, intercepts entity writes (`pushGoal`/`deleteGoal`/`pushCurriculumTrack`/`pushStageDefinitions`/`pushStudyDayConfig`) → calls matching CF via `TutorWriteService` with `grantId + ownerUid + profileId + payload`. Delegate (outbox) NEVER called for intercepted kinds. CF failure → `TutorWriteException` (clean exception type so callers can surface a snackbar). Pass-through (delegate) for non-intercepted kinds (`pushGamificationSettingsSnapshot`, `pushUiPreferencesSnapshot`, `pushBookmark`, `pushSettings`, `pushLearningOrder`, `pushLearnerProfile`, `deleteLearnerProfile`) — those are S4's scope.
  - **Provider WRAP sound:** `syncWriteFacadeProvider` in `sync_providers.dart:69+` now returns a `TutoredWriteRouter` wrapping `OutboxSyncWriteFacade` when `activeTutoredProfileSelectionProvider != null`; returns the bare outbox facade otherwise.
  - **TESTS GENUINE + COMPREHENSIVE:** 14 unit tests in `test/features/tutoring/s1_tutored_write_router_test.dart` (+462). AC1 (tutored→CF + outbox depth 0) × 5 entity kinds; AC2 (non-tutored→outbox + CF not called) × 5 kinds; AC3 (5-call isolation: `totalEnqueueCount` stays 0; pass-through still reaches delegate); AC4 (CF failure → `TutorWriteException`) × 2. Real `TutorWriteService` + recording invoker + real `SyncWriteFacade` impl as delegate. No mocked assertions, no skipped cases.
  - **Chokepoint coverage (the key correctness Q):** `_syncEngine` is typed as `SyncWriteFacade?` in `GoalRepositoryImpl` (`goal_repository_impl.dart:12,17,20`) + `CompletionRepositoryImpl` (`completion_repository_impl.dart:32,43,52`); BOTH providers inject from `syncWriteFacadeProvider` (`goalRepositoryProvider` at `onboarding_providers.dart:35`; `completionRepositoryProvider` at `completion_providers.dart:62`). ⇒ `goal_repository_impl:221,230` (`_syncEngine.pushGoal/deleteGoal`) AND `completion_repository_impl:216,288` (`_syncEngine?.pushGamificationSettingsSnapshot()`) DO flow through the wrapped router. **Both originally-named chokepoints covered.**
- **HIGH ADVISORY (do NOT close P1 with this glossed — carry to S2):** a **THIRD path** exists — direct readers of `outboxSyncWriteFacadeProvider` BYPASS the wrap. The two providers are deliberately separate (comment at `sync_providers.dart:107-108`: "the instance and the one returned by `syncWriteFacadeProvider` are NOT shared on purpose"). Direct readers in S2/S3/S4 scope:
  - `add_track_providers.dart:21` — track creation ⚠️ (S2 scope)
  - `study_day_config_screen.dart:186` — study day config push ⚠️ (S2 scope)
  - `edit_track_screen.dart:330` — track edit ⚠️ (S2 scope)
  - `completion_providers.dart:81` — completion repo tee (legitimate; outbox-only by design — for own-data ledger writes)
  - `learning_ledger_providers.dart:33`, `notification_providers.dart:256`, `bulk_mark_screen.dart`, child/parent redemption screens — gamification/ledger surfaces (S4 territory, watch in their wiring).
  → **S2 MUST refactor the entity-push call sites (track / stages / study-day) to read `syncWriteFacadeProvider` (the wrapped router)** — the `SyncWriteFacade` interface has drop-in equivalents. Without this, a tutor adding/editing a track via these UIs would still write to the local outbox + the `isProfileTutored` guard would block sync ⇒ edit STRANDED (the exact failure mode that created this effort).
- **MINOR (LOW, log only):** S1 reported "analyze clean (4 pre-existing onReorder infos unchanged)" — not independently verified at this gate (V1 will catch). Pattern note: talmid-view squad previously made repeated false analyze-clean claims — verify before believing.
- **verdict:** **S1 PASS for the router-keystone scope as briefed.** Task #1 → `completed` (its scope is done). P1 NOT closed (still awaiting S6 + the HIGH advisory must land in the S2 briefing).
- **next:** acknowledge S1 (it's idle); await S6 at P1; fold S1's HIGH advisory into S2's Wave-2 briefing.

## [2026-05-28 10:16] dispatch · S6 — Profile-less tutor wizard fix
- **scope:** S6 start.
- **investigation:** `ProfileGuard.onNavigation` already routes `count==0` to `ProfilePickerRoute` (the picker, not a wizard). The picker shows `TutoredChildrenSection` which displays active grants. The actual gap was in `sign_in_controller.dart` post-login routing: the `finalProfileCount==0 && !cloudAccountHasProfiles` branch routed to `EmptyLoginRoute` (for skipped users) or `OnboardingRoute` (for new users) without checking grants.
- **fix — 3 files:**
  1. `sign_in_controller.dart` — added grant check before `EmptyLoginRoute`/`OnboardingRoute` branch: calls `tutorGrantRepositoryProvider.listIncomingGrants()` with 4s timeout; if ≥1 active grant → `ProfilePickerRoute`. Falls back to original behavior offline/error.
  2. `empty_login_screen.dart` — wired "I'm a tutor" button to `ProfilePickerRoute` (was: snackbar stub).
  3. `test/core/navigation/profile_guard_test.dart` — new file, 6 unit tests covering: tutored-session bypass (count==0 and count≥1), zero-own-profiles → picker (both genuine first-run and profile-less tutor scenarios), single-profile auto-select, valid-selection short-circuit.
- **analyze:** 4 pre-existing onReorder infos only — no new issues.
- **tests:** 6/6 pass (`flutter test test/core/navigation/profile_guard_test.dart`). Pre-existing `app_shell_test.dart` 2 failures confirmed pre-existing (same failure on baseline before my changes).

## [2026-05-28 10:08] commit · clean baseline before squad runs
- **scope:** orchestration · honoured Daniel's `1st commit and ensure git is clean` instruction.
- **commits on `dev`:**
  - `7e5f6eb5` `feat(tutor): own/mirror profile split + tutored guard bypass + switcher account row + talmid-entry loading` (14 files, +184/-83). Substantive changes: `profile_dao.dart` `getProfilesByAccount` / `countProfilesForAccount` / `watchProfilesByAccount` now exclude `isTutored==true` mirrors (own queries return own-only); `profile_guard.dart` short-circuits when `_isTutoredSession()` (resolver.next() through the talmid view path); `profile_switcher_sheet.dart` adds an ACCOUNT row at top with current email + `AccountPickerRoute`; `tutored_children_section.dart` shows a blocking progress dialog during the entry pull (dismissed on success / permission-denied / error); `tutored_pull_providers.dart`, `active_tutored_profile_provider.dart`, `manage_tutors_providers.dart`, `settings_screen.dart`, `user_profile_header_card.dart`, `app_shell.dart`, `router_provider.dart`, `gradle.properties`, `pubspec.lock`, `app_shell_test.dart` smaller follow-ons.
  - `462e5a2d` `docs(tutor): edit-propagation plan + orchestration prompt, log, tracker` (4 files, +435).
- **git status:** CLEAN at HEAD `462e5a2d`. `dart analyze` not re-run by the orchestrator (the changes are Daniel's prior-session polish, already analyze-clean per his pre-handoff state); squad will exercise it at their own commits + V1.
- **S6 OVERLAP NOTE (carry to S6 briefing):** the polish already implements PART of S6's mechanism — own-profile queries correctly exclude mirrors, so a profile-less tutor's `countProfilesForAccount` returns 0 and `ProfileGuard` allows tutored sessions through. The remaining S6 gap is the **initial routing decision** when `count==0` + ≥1 active grant → must route to the picker (TALMID PROFILES visible), not the Create-Profile wizard.
- **next:** SendMessage S1 → `proceed <SHA>`; dispatch S6 with the overlap note.

## [2026-05-28 10:30] sync · P1 CLOSED + return+verify S6

### return + verify · S6 (profile-less tutor wizard) — PASS
- **scope:** sync/S6 · `S6-profile-less` reported P1 (commit `e5045281` — `feat(tutor): S6 — profile-less tutor routes to picker, not wizard`, 3 files, +215/-5). S6 wrote its own dispatch entry at [10:16] (commit `e5045281`).
- **VERIFIED by orchestrator (read diff + code + tests, not self-report):**
  - **Acceptance branches:**
    1. ✅ **Profile-less tutor (count==0 + ≥1 active grant):** `sign_in_controller.dart:489+` inside the existing `finalProfileCount == 0 && !cloudAccountHasProfiles` branch adds a `listIncomingGrants()` call with a 4 s timeout + try/catch; if ≥1 grant is `active` → `prefs.setBool(kOnboardingComplete, true)` + `router.replaceAll([ProfilePickerRoute()])`. Picker's `TutoredChildrenSection` then surfaces the talmid.
    2. ✅ **Genuine new user (count==0 + zero grants):** falls through the new branch to the existing path (`OnboardingRoute` or `EmptyLoginRoute` per `kOnboardingSkipped` history) — wizard preserved.
    3. ✅ **Active tutor with own profiles:** the new logic is inside the `count == 0` branch only — the count≥1 path is untouched.
  - **`ProfileGuard` (UNCHANGED by S6):** `core/navigation/guards/profile_guard.dart:89-98` already routes any `count==0` non-tutored navigation to `ProfilePickerRoute` (introduced in the polish commit `7e5f6eb5`). S6's added test file `test/core/navigation/profile_guard_test.dart` (+187) asserts this + the `_isTutoredSession()` short-circuit + auto-select branch + already-selected branch (6 tests).
  - **Offline-first:** the new grant-check is wrapped in try/catch + 4 s timeout — offline users fall through to the existing offline-safe path. Aligns with [[offline-first]].
  - **`empty_login_screen.dart`:** "I'm a tutor" button changed from snackbar stub → `router.replaceAll([ProfilePickerRoute()])`. (Bonus minor fix; bundled.)
- **LOW (V3 candidate):** the NEW grant-check branch in `sign_in_controller.dart` is NOT directly unit-tested (the 6 new tests cover `ProfileGuard`, a related but distinct code path). Change is small + linear; V1 + V6 charter smoke will catch regressions.
- **MINOR (LOW, log only):** S6 reported "4 pre-existing onReorder infos only — no new issues" for analyze + 6/6 pass for its new test file. Pre-existing `app_shell_test.dart` 2 failures were confirmed pre-existing on baseline before S6's changes (S6 verified). Not blocking P1 — V1 will catch all suite breakage.
- **verdict:** **S6 PASS.** Task #6 → `completed`.

### sync · P1 CLOSED
- Both Wave-1 streams done. Tasks #1, #6, #7 → completed. P1's `blockedBy=[1,6]` resolved.
- **carry forward to Wave 2:** S1's HIGH advisory (refactor `outboxSyncWriteFacadeProvider` direct readers in S2 scope: `add_track_providers.dart:21`, `study_day_config_screen.dart:186`, `edit_track_screen.dart:330`). Briefed into S2.
- **commit hygiene incident:** at 10:16 my `git add docs/...` + commit inadvertently swept up S6's 3 staged files (race between S6 staging and my docs commit). I `git reset --soft HEAD~1`'d, `git restore --staged`'d S6's 3 files, re-committed docs alone (`2479d60e`), and notified S6. S6 then committed its own work cleanly at `e5045281`. **Procedure tightened:** I will only `git add` files under `docs/planning/tutor-edit-propagation-*` going forward; teammates stage + commit their own code. Cost: one wasted commit (`8df293c4`, now orphaned).
- **HEAD:** `a0b8c028` (after this commit) on `dev`. Working tree clean.
- **next:** acknowledge S6 + Daniel; dispatch Wave 2 (S2 + S3 + S4 in parallel) with coordination plan: S2 owns the `outboxSyncWriteFacadeProvider` refactor (3 call-sites). S3 + S4 will both touch the `TutoredWriteRouter` class and `tutor_write_service.dart` — coordinate via SendMessage; no concurrent build_runner.

## [2026-05-28 10:38] return + verify · S3 (parity CFs) — PASS for scope; reachability gaps deferred to S2
- **scope:** sync/S3 · `S3-parity-cfs` reported P2 ready (commit `dbc36599`, 4 files, +389/-18, "deploy pending approval").
- **VERIFIED (S3's scope):**
  - **3 NEW CFs in `functions/src/index.ts`:** `tutorUpsertBookmark` / `tutorSetProfileProgram` / `tutorUpsertCurriculumScope`. All gated `can_edit_stages`; mirror `tutorUpsertTrack` (auth → `assertActiveTutorAndPermission` → `set(payload, {merge:true})` → `auditTutorAction`). Read side-by-side with `tutorUpsertTrack` — pattern correct.
  - **3 NEW `TutorWriteService` methods:** `upsertBookmark` / `setProfileProgram` / `upsertCurriculumScope`. Mirror existing wrappers via `_call` helper.
  - **`pushBookmark` route** in router (was pass-through). Doc-id `{curriculum_id}_{track_type}` matches `firestore_gateway_impl` doc-id; fallback to `curriculum_id` when `track_type` absent.
  - **`deleteCompletion` pass-through** added (interface already has `deleteCompletion(String)` at `sync_write_facade.dart:80`). Interface-satisfier; actual interception is S4's work-in-flight.
  - **5 new bookmark tests** + AC3 isolation now 6 kinds.
  - **Task A — `point_configs` investigation RESOLVED:** `GamificationSettingsMerger` reads `points_config` list → propagate via gamification snapshot; no dedicated CF needed. ✅
  - **MINOR (LOW):** the router's top-of-file doc-comment lists `pushGamificationSettingsSnapshot → tutorUpdateGamificationSettings (S4)` / `pushLearnerProfile → tutorEditProfile (S4)` / `deleteCompletion → tutorResetCompletion (S4)` as intercepted — but the actual code in S3's commit only has the bookmark intercept + `deleteCompletion` pass-through. The S4 intercepts are S4's responsibility (now in S4's uncommitted working tree). S3's comment is optimistic; S4 will either match it or revise on commit.
- **GAP — REACHABILITY ANALYSIS (2 of 3 new CFs not yet reachable):**
  - **`tutorSetProfileProgram` UNREACHABLE today:** client pushes `profile_program` via `edit_track_screen.dart:330` calling `outboxFacade?.enqueueProfileProgram(...)`. `enqueueProfileProgram` is a "package-visible enqueue helper for `LocalDataUploadService`" (`outbox_sync_write_facade.dart:317-321`) — **NOT on `SyncWriteFacade`** → router can't intercept → tutor profile_program writes would land in the outbox and be blocked by `isProfileTutored`. **Resolution path (best fit for S2's scope):** add `pushProfileProgram` to `SyncWriteFacade`, impl in `OutboxSyncWriteFacade` (delegate to `enqueueProfileProgram`), route in `TutoredWriteRouter`, refactor `edit_track_screen.dart:330` to use it. S2's working tree currently has `sync_write_facade.dart`, `outbox_sync_write_facade.dart`, AND `edit_track_screen.dart` modified — likely doing exactly this. **Verify at S2's return.**
  - **`tutorUpsertCurriculumScope` UNREACHABLE today:** the client does NOT push `curriculum_scope` to Firestore at all (`track_creation_service.dart:393` writes Drift; no `lib/core/sync/` path). Pre-existing gap (parent app's own curriculum_scope edits don't propagate either) — NOT S3's fault. **Resolution path:** either (a) S2 adds a full push path (interface + impl + outbox kind + push pipeline + caller refactor — larger scope); (b) leave the CF as "future-proofing" (deploying unused CFs is harmless). I'll decide based on S2's reach.
- **DEPLOY HELD** — S3 awaits approval. Holding until S2 + S4 land so we deploy ONCE at P2 with the full client side in place. S3's server side is ready.
- **`make ci`:** not run by S3 (functions `npm run build` + S3's 4 files analyzer clean; full suite reserved for P2 integrated verification).
- **commit hygiene:** clean commit, no in-flight sweep. ✅
- **verdict:** **S3 PASS for stated scope.** Task #3 → `completed`. P2 NOT closed (awaiting S2 + S4 + integrated verification + functions deploy).
- **next:** SendMessage S3 (verdict + HOLD on deploy); await S2 + S4. No polling.

## [2026-05-28 10:42] return + verify · S2 (existing-entity wiring + outbox refactor + R2 parity) — PASS for scope, ONE persistent gap deferred to fix-agent
- **scope:** sync/S2 · `S2-existing-entities` committed `9ccdcd61` (7 files, +740/-55) while I was writing S3's verdict. (Independent commits — no sweep, clean hygiene.)
- **VERIFIED (S2's scope):**
  - **Task A (outbox refactor) — 2 of 3 sites done:**
    1. ✅ `study_day_config_screen.dart`: pushStudyDayConfig → `syncWriteFacadeProvider`.
    2. ✅ `track_creation_service.dart` + `add_track_providers.dart`: facade SPLIT — `SyncWriteFacade?` (bookmark + study-day → routed for tutored) + `OutboxSyncWriteFacade?` (enqueueProfileProgram → outbox-only).
    3. ⚠️ **`edit_track_screen.dart:330` LEFT AS-IS.** S2's commit message: "edit_track_screen:330 calls `enqueueProfileProgram` (outbox-specific, not on SyncWriteFacade interface); left on outboxSyncWriteFacadeProvider — S3 owns tutorSetProfileProgram." But S3 did NOT add `pushProfileProgram` to the interface or refactor the caller — S2 ↔ S3 coordination miss.
  - **Task B (serialization parity):**
    1. ✅ **`GoalEntity.toFirestore` normalized to snake_case** (`curriculum_id`, `target_percent`, `target_date`, `date_type`, `goal_type`, `pace_value`, `pace_unit`, `created_at`, `updated_at`) — matches `GoalMerger` field reads. `fromFirestore` accepts both keys for back-compat (good — back-compat at the read boundary, modern format at the write boundary).
    2. 🔍 **R2-GOAL-TRACK-ID finding (HIGH, V2 candidate, out-of-scope):** `GoalEntity` has no `trackId` field → `GoalMerger` skips rows. **Same gap exists in the own-device outbox path** — so this is NOT a tutor regression, it's a pre-existing data-model issue. S2 documented it in the parity test and flagged out-of-scope. Carry into V2 R2 review.
    3. ✅ **7 parity tests in `s2_entity_parity_test.dart`** (track / stage / study-day / goal × field names + doc-id conventions; goal camelCase leakage check; round-trip test). +290 lines added to `s1_tutored_write_router_test.dart`.
  - **Bonus cleanup:** `profile_guard_test.dart` S6-introduced analyze warnings fixed (unused imports, underscore locals, `prefer_final_locals`). Added `deleteCompletion` no-op to test `_FakeDelegate` (S4 added `deleteCompletion` to `SyncWriteFacade` interface — important signal that S4 is actively reshaping the interface).
- **PERSISTENT GAP — `tutorSetProfileProgram` STILL UNREACHABLE:** the `edit_track_screen.dart:330` site (and any tutor-track-creation re-anchor flow) still calls `outboxFacade?.enqueueProfileProgram` → blocked by `isProfileTutored` → STRANDED. The fix requires adding `pushProfileProgram(payload)` to `SyncWriteFacade` + impl in `OutboxSyncWriteFacade` (delegate to `enqueueProfileProgram`) + route in `TutoredWriteRouter` → `_writeService.setProfileProgram` + refactoring `edit_track_screen.dart:330` (and possibly other callers). **Decision: dispatch a fix-agent AFTER S4 commits**, so the work doesn't conflict with S4's in-flight router changes. Track as a Wave-2 fix, NOT V3 (must land before P2 deploy/verification).
- **PERSISTENT GAP — `tutorUpsertCurriculumScope` STILL UNREACHABLE:** the client doesn't push `curriculum_scope` to Firestore at all (pre-existing — also true for parents). **Decision: leave the CF as future-proofing; do NOT add a full push path in this wave** (would balloon scope into a sync-pipeline change). Document in P2 report.
- **`make ci`** not run by S2 (correct — reserved for the P2 integrated gate with S4).
- **commit hygiene:** clean commit; no in-flight sweep. ✅
- **verdict:** **S2 PASS for stated scope** (the gap is a coordination issue, not an S2 failure). Task #2 → `completed`.
- **next:** SendMessage S2 (verdict + R2-GOAL-TRACK-ID logged); await S4 at P2; dispatch fix-agent for `pushProfileProgram` after S4 commits; integrated P2 verification + functions deploy.
