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

## [2026-05-28 10:08] commit · clean baseline before squad runs
- **scope:** orchestration · honoured Daniel's `1st commit and ensure git is clean` instruction.
- **commits on `dev`:**
  - `7e5f6eb5` `feat(tutor): own/mirror profile split + tutored guard bypass + switcher account row + talmid-entry loading` (14 files, +184/-83). Substantive changes: `profile_dao.dart` `getProfilesByAccount` / `countProfilesForAccount` / `watchProfilesByAccount` now exclude `isTutored==true` mirrors (own queries return own-only); `profile_guard.dart` short-circuits when `_isTutoredSession()` (resolver.next() through the talmid view path); `profile_switcher_sheet.dart` adds an ACCOUNT row at top with current email + `AccountPickerRoute`; `tutored_children_section.dart` shows a blocking progress dialog during the entry pull (dismissed on success / permission-denied / error); `tutored_pull_providers.dart`, `active_tutored_profile_provider.dart`, `manage_tutors_providers.dart`, `settings_screen.dart`, `user_profile_header_card.dart`, `app_shell.dart`, `router_provider.dart`, `gradle.properties`, `pubspec.lock`, `app_shell_test.dart` smaller follow-ons.
  - `462e5a2d` `docs(tutor): edit-propagation plan + orchestration prompt, log, tracker` (4 files, +435).
- **git status:** CLEAN at HEAD `462e5a2d`. `dart analyze` not re-run by the orchestrator (the changes are Daniel's prior-session polish, already analyze-clean per his pre-handoff state); squad will exercise it at their own commits + V1.
- **S6 OVERLAP NOTE (carry to S6 briefing):** the polish already implements PART of S6's mechanism — own-profile queries correctly exclude mirrors, so a profile-less tutor's `countProfilesForAccount` returns 0 and `ProfileGuard` allows tutored sessions through. The remaining S6 gap is the **initial routing decision** when `count==0` + ≥1 active grant → must route to the picker (TALMID PROFILES visible), not the Create-Profile wizard.
- **next:** SendMessage S1 → `proceed <SHA>`; dispatch S6 with the overlap note.
