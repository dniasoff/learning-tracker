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
