# Phase 3 wave-ordered execution plan

Produced by a 9-agent read-only research workflow, 2026-08-11. Supersedes the callee-first ordering sketch in phase3-handoff-5.md section 7 with a verified, file-by-file, wave-ordered plan plus a full spec for the owner-approved point_configs restoration.

---

# Phase 3 handoff — execution order, risk register, blockers, and the approved point-override restoration

All Dart paths are relative to `/home/daniel/repos/learning-tracker/learning_tracker/`. All rules/functions/tool paths are **also** under `learning_tracker/` (verified: `learning_tracker/firestore.rules`, `learning_tracker/firestore.indexes.json`, `learning_tracker/functions/test/firestore_rules.test.mjs`, `learning_tracker/tool/…`) — **not** the repo root.

**Path corrections made against the source plan (verified on disk):**
- `reward_config_controller.dart` is at `lib/features/gamification/presentation/providers/reward_config_controller.dart` — there is no `presentation/controllers/` directory.
- `lib/features/scheduler/data/providers/` and `lib/features/scheduler/data/repositories/projection_tasks_repository.dart` (present as untracked in the opening `git status`) are **absent now**. A concurrent agent removed them.
- `lib/features/profiles/domain/models/profile_model.dart` and its `.freezed.dart` are **deleted in the working tree right now** (git ` D`). B1's first half is already in flight.
- `lib/features/gamification/data/repositories/` **already exists** (`firestore_gamification_ledger_repository.dart`, `firestore_points_repository.dart`, `firestore_streak_state_repository.dart`), so new adapters land in an existing directory.

**Standing ordering rules:**
1. **Callee before caller.** A Drift-era class taking its deps as constructor arguments blocks every caller, because a caller would otherwise have to reach the data ring itself, which AD-23/AD-28 forbids. Converting the callee to take `Ref` unblocks all callers at once. Never order by error count.
2. **Layering.** Only the path segment `/data/repositories/` is exempt in `tool/check_dependency_direction.dart`. Files under `features/**/presentation/**` and `features/**/domain/**` may not import `package:learning_tracker/data/firestore/…` or `package:learning_tracker/data/repositories/…`. Reference shape: `features/progress/data/repositories/firestore_progress_repository_adapter.dart`, constructed at `progress_providers.dart:39`.
3. **Silent callers ship in the same commit as their callee** — they carry 0 errors today and break the moment the callee's signature changes.
4. **Two independent trunks.** Trunk A (AD-25 curriculum key) and Trunk B (AD-24 ULID identity) share almost nothing until C1. Two agents can run them in parallel.
5. **Inventory corrections:** `tutored_children_section.dart` appears twice in the inventory (14 and 7) — one file, treat the 14-error row as authoritative. `goal_repository_impl.dart` is a real callee of `track_creation_service.dart:287` and `edit_track_screen.dart:284`, both of which wrongly list `blockedBy: []`.

**Concurrency (live in this session):** agents `main`, `consumer-fields`, `consumer-fields-2`, `docid-and-eventlog`. Confirm ownership before touching `auth_state.dart`, `repository_providers.dart`, `daily_task_projection_service.dart`, `scheduler_providers.dart`, `profile_repository_impl.dart`, `profile_providers.dart`, `profile_repository.dart`, `database_provider.dart`, `tutored_write_router.dart`, `manage_tutors_screen.dart` — all currently dirty.

---

## Execution order

### 1. WAVE 0 — free deletions (~33 errors, 13 files) · risk: mechanical (3 carve-outs)

`features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart` (2), `features/learning/data/repositories/bookmark_repository_impl.dart` (2), `features/learning/presentation/providers/completion_providers.dart` (1), `core/preferences/preference_providers.dart` (1), `features/sacred_time/presentation/providers/sacred_location_provider.dart` (3), `features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart` (5), `features/gamification/streak/streak_event_log.dart` (3), `features/gamification/streak/streak_restorer.dart` (2), `features/tutoring/data/routers/tutored_write_router.dart` (4), `app/sync_runtime/sync_lifecycle_observer.dart` (2) + the unwrap at `app/learning_tracker_app.dart:67`, `features/learning/presentation/providers/track_providers.dart` (3), `features/gamification/presentation/widgets/reward_form.dart` (3), `features/learning/domain/use_cases/bulk_mark_completion_use_case.dart` (2).

**One unit:** every entry is a dead-import / dead-class / dead-push deletion or a one-line body swap. Zero design content. Doing it first removes ~33 errors of noise from every later `dart analyze`.
**Unblocks:** nothing structurally — debt clearance.
**Carve-outs:** `tutored_write_router.dart` is **auth-relevant** (see blocker 15). `bulk_mark_completion_use_case.dart` is **achievement** — copy the B1 three-tier engagement/achievement gating verbatim; only the return type changes to `List<CompletionEntity>`. `reward_form.dart` needs `build_runner` afterwards (its analyzer-excluded `.freezed.dart` still names `CurriculumTrack`).

---

### TRUNK A — the AD-25 curriculum-key axis

### 2. WAVE A1 — track-identity keystone (7 errors, 3 files + 2 silent) · risk: configuration, **except one destructive file**

`features/tracks/setup/presentation/providers/track_management_providers.dart` (3); `features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart` (3) + silent `features/tracks/track_order/presentation/providers/track_learning_order_providers.dart` + `features/tracks/track_order/presentation/screens/track_learning_order_screen.dart`; `features/scheduler/data/repositories/goal_repository_impl.dart` (1).

**One unit:** all three abolish `int trackId` at a *public* surface — `activeTracksProvider`'s element type, the `TrackLearningOrderRepository` interface, and `goalEntityFromRow`'s row identity. Landing them together re-keys every downstream file onto `CurriculumId.storageKey` exactly once instead of twice.
**Unblocks (largest fan-out in the migration):** `track_info_card`, `learning_track_card`, `track_management_body`, `edit_track_screen`, `track_detail_screen`, `parent_track_management_screen`, `curriculum_settings_screen`, `point_config_screen`, `achievements_overview_provider`, `child_redemption_screen`, `track_creation_service`.
**Risk:** the track *list* may legitimately be empty (configuration) — but `goalEntityFromRow` is **destructive**: a wrong id mapping makes `_deleteExistingGoals` delete the wrong goal.

### 3. WAVE A2 — ledger, progress, per-track achievement reads (17 errors, 5 files) · risk: **achievement (high)**

`features/progress/domain/services/lifetime_tree_builder.dart` (3), `features/progress/presentation/providers/chart_providers.dart` (3), `features/progress/presentation/providers/progress_providers.dart` (3 — understated, `db` is `dynamic`), `features/tracks/domain/services/track_progress_service.dart` (3), `features/learning/domain/use_cases/manual_completion_use_case.dart` (5).

**One unit:** all five consume completions/ledger entries, all five are where owner ruling D-E bites, and all five need the same new artifact — a `Ref`-based Firestore completion/ledger feed under `features/*/data/repositories/` — plus one policy applied consistently.
**Unblocks:** `lifetime_knowledge_providers.dart`, `items_learned_providers.dart`, `settings/lifetime_marking_screen.dart`, `active_track_card`, the whole dashboard wave.

### 4. WAVE A3 — track read UI (11 errors, 5 files) · risk: achievement + destructive

`features/tracks/setup/presentation/widgets/track_info_card.dart` (4), `features/tracks/setup/presentation/widgets/learning_track_card.dart` (2), `features/tracks/setup/presentation/widgets/track_management_body.dart` (2), `features/profiles/presentation/screens/parent_track_management_screen.dart` (2), `features/settings/presentation/screens/curriculum_settings_screen.dart` (1).

**One unit:** one type swap (`CurriculumTrack` → `CurriculumTrackEntity`) propagating through one widget tree, plus the same `track.id` → `curriculumId` re-key in each. Splitting them re-opens the same three provider families repeatedly.
**Unblocks:** the track hub and parent screen compile; the dashboard wave can start.
**Risk:** cards render completion percentage and required-vs-actual pace (achievement); `track_management_body` / `parent_track_management_screen` reach `curriculumActivationServiceProvider.purgeTrackHistory` (destructive).

### 5. WAVE A4 — dashboard (23 errors, 5 files) · risk: **achievement (high)**

`features/dashboard/presentation/providers/dashboard_providers.dart` (7), `features/dashboard/presentation/widgets/dashboard_body.dart` (2), `features/dashboard/presentation/widgets/active_tracks_carousel_section.dart` (2), `features/dashboard/presentation/screens/dashboard_screen.dart` (9), `features/dashboard/presentation/widgets/active_track_card.dart` (3).

**One unit:** 14 providers and their four consumers hang off one type (`List<CurriculumTrackEntity>`) and one key (`CurriculumId.storageKey`). `dashboard_providers` is the callee; the other four are mechanical fallout that must ship with it.
**Unblocks:** the app's main screen. Nothing downstream.
**Blocked-on-missing inside this wave:** blockers 9 and 10.

### 6. WAVE A5 — stage-definition & study-day write seam (16 errors, 4 files) · risk: **destructive (high)**

`features/scheduler/domain/services/study_day_toggle_service.dart` (3) + `features/scheduler/presentation/screens/study_day_config_screen.dart` (2), `features/scheduler/data/repositories/scheduler_stage_repository_impl.dart` (4), `features/onboarding/domain/services/learning_process_wizard_service.dart` (7).

**One unit:** all four read or write *stage definitions and study-day configs*, and all four need the same new artifact — a **stage-set replace API** on `FirestoreStageDefinitionRepository` (delete-and-replace of a track's stages), which does not exist today. Build it once, here.
**Unblocks:** `scheduler_providers.dart:139`, `track_creation_service`, `track_edit_service`, silent callers `onboarding_providers.dart:59` and `curriculum_settings_screen.dart:175`.

### 7. WAVE A6 — track write services and their screens (51 errors, 5 files) · risk: **destructive (highest in the migration)**

`features/tracks/setup/domain/services/track_creation_service.dart` (9), `features/tracks/setup/domain/services/track_edit_service.dart` (3), `features/tracks/setup/presentation/providers/add_track_providers.dart` (4), `features/tracks/setup/presentation/screens/edit_track_screen.dart` (10), `features/tracks/setup/presentation/screens/track_detail_screen.dart` (25).

**One unit:** one constructor change (`UserDatabase`/`FirestoreGateway`/`SyncWriteFacade` → `Ref`) on the two services unblocks all three UI files at once; the two screens also perform their own direct DAO writes against the *same* repositories, so the repository set is resolved once for the whole cluster.
**Unblocks:** the last of the tracks feature.

### 8. WAVE A7 — scheduler projection (9 errors, 2 files) · risk: **achievement (high)**

`features/scheduler/domain/services/daily_task_projection_service.dart` (5), `features/scheduler/presentation/providers/scheduler_providers.dart` (4 — understated, `db` degrades to `dynamic`).

**One unit:** the service takes `UserDatabase` positionally in three methods; converting it is the only way its provider stops watching `userDatabaseProvider`. `DailyTask` still carries an `int trackId`, so the `Map<CurriculumId, int trackId>` re-key happens here and nowhere else.
**Unblocks:** the daily plan; `active_track_card`'s `DailyTask.trackId` filter.
**Concurrency:** both files are dirty — confirm ownership first.

### 9. WAVE A8 — gamification points ports (20 errors, 4 files) · risk: **achievement (high), partly decision-blocked**

`features/gamification/presentation/providers/gamification_service_providers.dart` (3), `features/gamification/presentation/providers/points_providers.dart` (11), `features/gamification/presentation/providers/achievements_overview_provider.dart` (4), `features/gamification/presentation/providers/reward_config_controller.dart` (2).

**One unit:** `PointsService` and `RewardMilestoneService` are already migrated onto three named ports declared in `features/gamification/domain/services/points_service.dart` — `CurriculumRewardEligibility` (:28), `PointConfigProvider` (:33), `PointsBalanceReader` (:45). **Verified: nothing in `lib/` implements any of the three.** Writing those adapters under `features/gamification/data/repositories/` is one job that unblocks all four files simultaneously.
**Unblocks:** `child_redemption_screen`, the dashboard reward tiles, `gamification_screen`, `track_filter_row`.
**Decision-blocked:** blocker 4 and blocker 5.

### 10. POINT-OVERRIDE RESTORATION (owner approved) — 9 errors on `point_config_screen.dart` + new data-ring surface · risk: **achievement (high) + destructive-by-omission**

New: `lib/data/repositories/point_config_entry.dart`, `lib/data/repositories/firestore_point_config_repository.dart`, a provider appended to `lib/data/firestore/repository_providers.dart`, `lib/features/gamification/data/repositories/point_config_repository_adapter.dart`; edits to `lib/features/learning/data/repositories/completion_points_awarder.dart`, `lib/features/gamification/presentation/screens/point_config_screen.dart`, `firestore.rules`, `firestore.indexes.json`. Full spec in the last section.

**One unit:** the collection, the rules block, the repository, the awarder wiring and the screen are a single contract — the 1..100 cap and the single `defaultPointsForStage` ladder must land in the same commit in all three places or they drift apart immediately.
**Ordering:** independent of both trunks; runnable any time after Wave 0. It **collides with cluster 9** in `features/gamification/` — do not run them concurrently in the same tree.
**Unblocks:** `point_config_screen.dart` (previously held back by owner decision 6.2d, `docs/planning/phase3-handoff-4.md`), which is live and routed from `parent_settings_screen.dart:211`.

---

### TRUNK B — the AD-24 ULID identity axis (parallel with Trunk A)

### 11. WAVE B1 — profile shape decision (2 errors, 2 files) · risk: auth

`features/profiles/domain/models/profile_model.dart` (1) — **already deleted in the working tree by a concurrent agent**; `features/account/domain/models/auth_state.dart` (1).

**One unit:** both are one-error files every identity consumer waits on, and both are *shape* decisions rather than code volume. `ProfileModel` (int `id`/`accountId`, `fromDriftRow`) is superseded by the existing `LearnerProfileEntity` (String `profileId`, `ProfileMode`, `avatar`). `auth_state.dart` is already re-pointed by a concurrent agent and needs only `build_runner` (`auth_state.freezed.dart` still declares `profileId`).
**Unblocks:** the entire identity trunk.
**Coordinate before touching either file.**

### 12. WAVE B2 — profile repository and providers (19 errors, 2 files) · risk: **destructive + auth (high)**

`features/profiles/data/repositories/profile_repository_impl.dart` (17), `features/profiles/presentation/providers/profile_providers.dart` (2). Both dirty.

**One unit:** the impl takes both dead deps as constructor arguments, so its sole call site cannot be fixed first; the `Ref`-based `FirestoreProfileRepositoryAdapter` already living in the same file is the shape it collapses into.
**Unblocks:** both navigation guards, `active_profile_provider`, `sign_in_controller`, `lifetime_marking_screen`.

### 13. WAVE B3 — navigation guards and router (14 errors, 4 files) · risk: **auth (high)**

`core/navigation/guards/profile_guard.dart` (3), `core/navigation/guards/child_mode_guard.dart` (3), `app/router/app_router.dart` (4), `app/router/router_provider.dart` (4).

**One unit:** both guards take `UserDatabase Function() getDatabase`; `router_provider` feeds that lambda to three guards and passes `restoreGuard:` to `app_router`. Nothing compiles until all four constructor shapes settle together. Placed after B2 so the guards are touched once, not twice.
**Unblocks:** app startup; `app/router/app_router.gr.dart` regeneration (analyzer-excluded, 3 hidden errors incl. `CurriculumTrack`).

### 14. WAVE B4 — account lifecycle, sign-in, pickers (51 errors, 7 files) · risk: **destructive + auth (high)**

`features/account/domain/services/account_lifecycle_service.dart` (5), `features/account/domain/services/account_management_service.dart` (3), `features/account/account.dart` (1), `features/account/onboarding/presentation/screens/signup_screen.dart` (8), `features/account/presentation/screens/account_picker_screen.dart` (9), `features/account/presentation/notifiers/sign_in_controller.dart` (23), `features/settings/presentation/utils/account_actions.dart` (2).

**One unit:** all seven are the sign-in / switch-identity / remove-account surface and all seven break on the same two removals (the outbox engine and the pull/push reconciliation model). `signup_screen` and `account_picker_screen` are pure caller fallout from already-landed callees (`LocalAuthService(registry/accountId/dbFileName)`, `setLocalBornSession(account:)`).
**Unblocks:** `upgrade_to_cloud_screen` (partly), and the `userDatabaseProvider` reads that block the final wave.
**Internal ordering:** `sign_in_controller` takes only Strings publicly, so nothing is blocked behind it — defer its 23 errors to the end of the wave.

### 15. WAVE B5 — tutoring mirror demolition (24 errors, 5 files) · risk: **auth (high)**

`features/tutoring/presentation/providers/active_tutored_profile_provider.dart` (2), `features/tutoring/presentation/providers/manage_tutors_providers.dart` (4), `features/tutoring/presentation/screens/manage_tutors_screen.dart` (2, dirty), `features/tutoring/presentation/screens/manage_grants_screen.dart` (2), `features/profiles/presentation/widgets/tutored_children_section.dart` (14).

**One unit:** one obsolete model (the pull-into-local-Drift-mirror engine) dies across all five. `active_tutored_profile_provider` is the ordering pin — it is imported by 16 files including the data ring's `repository_providers.dart`, and its int `resolvedTutoredLocalProfileIdProvider` is what breaks `active_profile_provider` and `tutored_children_section`.
**Unblocks:** `repository_providers.dart` consumers; the parent profile screen.

### 16. WAVE B6 — audit log (5 errors, 2 files) · risk: auth

`features/tutoring/data/repositories/firestore_audit_log_read_repository.dart` (3), `features/tutoring/presentation/providers/audit_log_providers.dart` (2).

**One unit:** the repository already sits under `/data/repositories/`, so per AD-23/AD-28 it may legally take `Ref` and resolve `activeAccountFirebaseProvider` itself; converting it is the only legal way its presentation-layer provider stops reaching the data ring.

---

### CONVERGENCE

### 17. WAVE C1 — settings leftovers (17 errors, 3 files) · risk: achievement

`features/settings/presentation/utils/send_logs_service.dart` (2) + `features/settings/presentation/screens/settings_screen.dart` (2) — callee-then-caller, one parameter change. `features/settings/presentation/screens/lifetime_marking_screen.dart` (13) — needs **both** trunks (ledger entity from A2, profile ULID from B2).

### 18. WAVE C2 — the last file (4 errors, 1 file) · risk: mechanical, but strictly last

`core/providers/database_provider.dart` (4). Delete `AccountDbFileName` / `userDatabaseProvider` / `appDatabaseProvider` and the `user_database` import; **keep** `contentDbPath` / `contentDatabase` (the content Drift DB stays). Genuinely last: ~50 files across `lib/` still read `userDatabaseProvider` and compile today only because this broken provider still exists. Do not attempt it until `rg userDatabaseProvider lib/` returns nothing but this file. (Currently dirty — a concurrent agent is in it.)

**Verification per wave:** `cd learning_tracker && dart analyze --fatal-infos <changed paths>`; then `rg 'userDatabaseProvider|core/database|core/sync' lib/` to confirm the wave removed the seam rather than moving it; then `dart tool/check_dependency_direction.dart`.
**Codegen gates:** `build_runner` is required after `reward_form.dart` (1), `auth_state.dart` (11), `app_router.dart` (13), and any `@riverpod` provider whose signature changes. Analyzer-excluded generated files hide errors until then — a green `dart analyze` on a hand-written file is not proof.

---

## High-risk clusters — what must not be fabricated

**Governing rule (owner ruling D-E, applied at BRANCH granularity, never method granularity):** a read that reports what the learner has *completed or earned* must **throw** when the backend is not ready, because `0` / `[]` / `{}` is indistinguishable from a truthful answer. A *configuration* read (which tracks exist, which rules are enabled) may legitimately return empty. Whether zero is legitimate is a property of the branch.

**Cluster 2 (A1) — `goal_repository_impl.dart`, destructive.** A wrong id mapping makes `_deleteExistingGoals` delete the wrong goal. Replace `goalEntityFromRow` with a `GoalEntity`-native path over `FirestoreGoalRepositoryAdapter.getGoals(CurriculumId)`. **Do not synthesise ids.**

**Cluster 3 (A2) — ledger/progress, achievement.**
- No `return 0.0`, `yield 0`, `?? 0.0`, `?? []` or `{}` on **any** not-ready branch of a learner-completion read. Throw.
- `lifetime_tree_builder`'s newest-first ordering precondition must be **re-verified against Firestore ledger doc-id ordering** before the signature swap is called done — the tie-break decides what counts as learned. Do not assume it survives.
- `getCompletionsByTier` exists on `lib/data/repositories/firestore_completion_repository.dart` and is **absent** from the `CompletionRepository` interface at `lib/features/learning/domain/repositories/completion_repository.dart` (verified). Widen the interface; do not re-implement tier filtering in the service.
- `manual_completion_use_case` keeps the `ChildSelfMarkException` gate and keeps the int `_activeProfileId` — it only feeds the same-id PIN comparison, so `learning_ledger_providers.dart:74` needs no change.

**Cluster 4 (A3) — track cards, achievement + destructive.** Cards must not render a silent zero for completion percentage or required-vs-actual pace; unready renders as loading/error. The archive/wipe visibility pre-check in `track_management_body` / `parent_track_management_screen` currently keys on `track.profileId`; re-key on `curriculumId` + the active profile ULID and **confirm the gate still fails closed**.

**Cluster 5 (A4) — dashboard, achievement.** Replace the existing `return 0.0` / `yield 0` not-ready fallbacks with throws. Three things are *missing*, not merely unmigrated (blockers 9, 10): no provider is wired for `FirestoreCurriculumTrackRepositoryAdapter` (`features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart:116`), no `ProfileProgramEntity` adapter exists, and `trackDualProgressMetricsProvider` (`features/progress/presentation/providers/lifetime_knowledge_providers.dart:537`) throws `UnsupportedError` at :542. **Leave `active_track_card`'s cycle/lifetime percentages unavailable — do not paper over with `?? 0.0`.**

**Clusters 6 and 7 (A5, A6) — atomicity, destructive.** The wizard, the study-day toggle and `restoreOrCreate` currently delete-then-replace inside a Drift transaction. **There is no transactional equivalent in Firestore and none may be simulated or claimed.** Seven DAO writes become seven independent Firestore writes. Order the writes so a mid-sequence failure leaves the *old* config intact rather than half-deleted, and make partial failure **detectable and reported**, not silently half-applied.

**Cluster 7 (A6) — specific deletes, destructive.** `track_detail_screen`'s `trackDao.purgeHistory` wipe, `edit_track_screen`'s `_clearOverdue` (overwrites the program tracking anchor) and the clear-scopes / clear-stages / delete-existing-goals sequence must be **re-pointed at the real repository operations, never re-derived from memory of what they used to delete**. Re-type the now-null-unsafe `Goal` / `StudyDayConfig` / `StageDefinition` locals explicitly; do not `!` them.

**Cluster 8 (A7) — overdue bucket, achievement.** An empty overdue bucket reads to the child as "all caught up". A not-ready read must **throw**, never yield `[]`.

**Cluster 9 (A8) — points, achievement.** Verified in `features/gamification/domain/services/reward_milestone_service.dart`: `getGlobalLifetimeEarnedForRewards` (:67) `return 0;` and `getTrackPointsTotalForRewards` (:312) `return 0;`. Live callers: `achievements_overview_provider.dart:122` and `:169`, `dashboard_providers.dart:356`. Mechanically clearing the four errors renders every milestone as locked at 0 points. **Do not compile this cluster green while those stubs stand** — implement them over `FirestorePointsLedgerRepository` in this wave, or leave the cluster red and escalate. A stubbed `0` for `globalPointsProvider` silently zeroes the child's entire points UI. (`getTrackPointsTotal` at :302 already throws correctly — that is the model.)

**Cluster 10 (point overrides) — achievement.** Branch A (repository resolved null) must throw; the ladder fallback is legal **only** for Branch B (repository resolved, no document). Full reasoning in the last section.

**Cluster 12 (B2) — profile repository, destructive + auth.** `deleteProfile` cascade-wipes 14 Drift tables in one transaction; `FirestoreLearnerProfileRepository` deliberately exposes **no delete**. **Do not invent one** (blocker 11). `currentAccountIdProvider`'s silent `?? 1` fallback must go — a wrong account id reads another family's data.

**Cluster 13 (B3) — `ChildModeGuard`, auth.** It **fails closed**: a mistake locks parent-mode routes. Verify the closed-failure behaviour survives the callback re-shape.

**Cluster 14 (B4) — pending-write guard, destructive.** `pendingOutboxDepth` and its `UndrainedOutboxException` guard ("your cloud data is safe") are meaningless with the outbox gone. **Do not silently drop the guard** — account removal would then destroy unsynced data with no warning (blocker 12). Same for `account_management_service`'s `PRAGMA foreign_keys = OFF` full-table wipe: the local-wipe path must be **redefined, not deleted** (blocker 13).

**Cluster 15 (B5) — tutoring, auth.** `manage_tutors_providers` currently unions the CF grant list with local mirror rows; returning only the CF result **silently drops a tutor's talmidim when offline**. Decide explicitly what an offline tutor sees and make it visible; do not default to an empty list. `tutored_children_section` is a behavioural rewrite ("set the selection and enter"), not a compile fix — do not force it green.

**Cluster 16 (B6) — audit log, auth.** `_UnauthenticatedAuditLogRepository` returning `[]` hides a **security record**. Surface not-ready instead.

**Cluster 17 (C1) — `lifetime_marking_screen`, achievement.** It writes what the learner has completed. Its `LedgerEntryDraft.markedBy` is a profile ULID — **do not stringify the legacy int to make it compile.**

**Wave 0 — `tutored_write_router.dart`, auth.** Deleting it removes the last client-side routing of tutor edits into the permission-checked `TutorWriteService` CFs. Delete it, but **record in the handoff that tutor writes now have no path to the talmid's tree** (T-37 owner-uid seam). Do not invent a replacement router.

---

## Blocked on a missing Firestore capability (owner decisions, not engineering)

These are not "unmigrated" — there is no Firestore counterpart anywhere in `lib/`. An agent cannot compile them correctly. Escalate before touching.

1. **Reward redemptions.** `features/gamification/presentation/screens/child_redemption_screen.dart` (2, badly understated) and `features/gamification/presentation/screens/parent_pending_redemptions_screen.dart` (8) need a `FirestoreRewardRedemptionRepository`. Verified: `firestore.rules:377` has a `reward_redemptions` block, and `lib/data/repositories/` contains **no** redemption repository (16 files, none matching); `firestore_points_ledger_repository.dart` carries only a `redemptionUlid` *reference* and declares redemptions out of scope. The point-debiting write and the decline-refund have nothing to call. **Decision: build the repository, or mark the redemption flow unavailable.**
2. **Upgrade-to-cloud.** `UpgradeToCloudService` and its three exception types were archived by commit `04897ebc` and exist nowhere in `lib/`. Blocks `features/settings/presentation/screens/upgrade_to_cloud_screen.dart` (15), `features/account/account.dart` (1), part of `sign_in_controller.dart` (23). The owner has confirmed the credential-less offline-account → convert-on-reconnect model is **not** obsolete, so deleting the export is not automatically correct. **Decision: re-author on Firestore, or remove the feature.**
3. **Tutored mirror replacement.** `TutoredPullResult`, `buildTutoredGateway`, `buildTutoredPullServiceFromWidget`, `buildTutoredMirrorWipeServiceFromWidget`, `tutoredListenerSupervisorProvider` — all gone, no replacement. `tutored_children_section.dart` (14) needs the entry flow redesigned as a direct Firestore read of the talmid's docs. **Decision: define the tutor-entry flow.**
4. **Gamification ports.** Verified: `CurriculumRewardEligibility`, `PointConfigProvider` and `PointsBalanceReader` are declared at `features/gamification/domain/services/points_service.dart:28/33/45` and **nothing implements any of them**. Plus `RewardMilestoneService`'s two hardcoded `0` returns (:67, :312). **Decision: implement over `FirestorePointsLedgerRepository`, or accept milestones as unavailable.**
5. **Reward catalogue persistence.** `features/gamification/presentation/providers/reward_config_controller.dart` (2): the catalogue lives in SharedPreferences with a cloud copy at `preferences/gamification_settings`; **no repository exists**. Deleting the push makes every parent reward edit silently device-local. **Decision required.**
6. ~~Point configs~~ — **RESOLVED. Owner approved; spec in the next section.** Supersedes decision 6.2d in `docs/planning/phase3-handoff-4.md`.
7. **Stage-set write API.** `FirestoreStageDefinitionRepository` exposes no set-replace operation, and there is no `ProfileProgram` domain interface. Required by A5/A6. This is engineering, but it is *new surface* — **flag the API shape for review before four callers depend on it.**
8. **Chart data adapter.** `FirestoreChartDataRepositoryAdapter` does not exist. It owns the D-E policy the `ChartDataRepository` interface documents (throw on the two completion reads; empty allowed for `getGoals`).
9. **Profile-program adapter + curriculum-track provider.** `dashboard_providers` needs a `ProfileProgramEntity` adapter (does not exist) and a provider for `FirestoreCurriculumTrackRepositoryAdapter` (the adapter exists at `features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart:116`; verified it is referenced only by doc comments and by `features/tracks/domain/services/curriculum_activation_service.dart`, which takes it as a constructor argument — **no provider constructs it**). Note the similarly-named data-ring `firestoreCurriculumTrackRepositoryProvider` at `lib/data/firestore/repository_providers.dart:329` is a *different* object (the raw `FirestoreCurriculumTrackRepository`) and does not satisfy this.
10. **`trackDualProgressMetricsProvider` throws.** Defined at `features/progress/presentation/providers/lifetime_knowledge_providers.dart:537`, throwing `UnsupportedError` at :542. `active_track_card`'s cycle/lifetime percentages cannot be made correct in A4. **Leave unavailable.** (Tracked separately as "recover from git".)
11. **Profile deletion.** `FirestoreLearnerProfileRepository` deliberately exposes no delete; `ProfileRepositoryImpl.deleteProfile` cascade-wipes 14 tables. **Decision: what does deleting a profile mean now?**
12. **Pending-write guard.** No replacement for `pendingOutboxDepth` / `UndrainedOutboxException` exists. Gates `account_lifecycle_service` (5) and `account_picker_screen`'s swipe-to-remove (9).
13. **Local wipe semantics.** `account_management_service` (3) exists only to wipe every Drift table. Both provider call sites stay broken until the wipe is redefined against Firestore / the device registry.
14. **Diagnostic logs — the source plan's claim is WRONG; corrected here.** `users/{uid}/diagnostic_logs` **does** have a rule: `firestore.rules:194-199`, owner-only, `read`+`create` allowed, `update`/`delete` denied, and it is listed in the LIVE LAYOUT header at `firestore.rules:9`. The actual blocker for `send_logs_service.dart` (2) is that it takes `required FirestoreGateway? gateway` from the dead `core/sync/firestore_gateway.dart` (line 3 of the file) — it needs a **diagnostic-log write path in the data ring**, not a rules change. Note `send_logs_service.dart:84` references a TTL policy on `expires_at`, which the rules block does not require; carry that field forward. **Decision: write the small append-only repository, or drop the tile.**
15. **Tutor writes.** Deleting `tutored_write_router.dart` (Wave 0) leaves tutor **writes** with no client path to the talmid's tree — the T-37 owner-uid handle seam. Record it; do not invent a replacement.

---

## Restoring per-curriculum point overrides (OWNER APPROVED)

Restores the retired Drift-only `point_configs` table. This is the task the awarder's own doc comment defers to.

### Collection path

```
users/{uid}/learner_profiles/{profileId}/point_configs/{configId}
```

Profile-scoped, sibling of `stage_definitions` / `study_day_configs`; the name matches the retired Drift table and the snake_case-plural convention. Add a line for it to the LIVE LAYOUT header comment at the top of `firestore.rules`. `configId = DocIds.pointConfigDocId`.

**REJECTED alternative:** `preferences/gamification_settings` with a nested `points_config` array (the dead `buildGamificationSnapshot` shape, still referenced at `lib/features/tutoring/data/routers/tutored_write_router.dart:266`). Two reasons: (1) `preferences/{scope}` is deliberately **not** key-whitelisted (`firestore.rules:508-527`, verified — it is guarded only by `request.resource.data.size() <= 50`) and Rules cannot type/range-check a value nested in an array inside a map, so `points=5000` or `"10"` lands unvalidated and is then stamped onto a completion doc, where the `points <= 100` rule rejects the **whole** completion write; (2) one bag doc for all curricula is an LWW clobber hazard, whereas per-key docs merge.

### Document shape

Fields, snake_case, mirroring `StudyDayConfigEntryFirestoreCodec.toFirestore`:

| field | type | notes |
|---|---|---|
| `curriculum_id` | String | `CurriculumId.storageKey`; AD-25 canonical stable track key; equality half of the list query |
| `stage_order` | int, 1-based | second half of the natural key; matches `stage_definitions.stage_order`, which is how the screen joins them |
| `points` | int, **1..100** | the override |
| `updated_at` | ISO-8601 UTC String via `FirestoreCodec.encodeDateTime` | LWW field, same as `study_day_configs`. Not a `Timestamp` — this is not an event collection, so SR-3 does not apply |
| `synced_at` | server stamp | written only by a tutor-proxy CF; whitelisted for parity with every sibling |

**The upper bound is 100, not 9999.** `CompletionOrchestrator.markComplete` stamps `calculatePoints`' result onto the completion document (`completion_orchestrator.dart:228-244`; `completion_entity.dart:127` writes `'points'`) and `firestore.rules:249-256` caps `completions.points` at `<= 100` (verified). An override above 100 makes **every completion write for that stage** `PERMISSION_DENIED`. The lower bound 1 mirrors the Drift `CHECK (points > 0)`.

**Deliberately absent:** `profile_id` (the path carries it — the same choice the study-day codec documents), `track_id` and the Drift autoincrement `id` (AD-25; writing `track_id` would also trip the MCF-11 ratchet), `is_default` (absence of the document **is** "no override").

**Doc-id — new formula in `lib/data/firestore/doc_ids.dart`, alongside `stageDefinitionDocId` (:466):**

```dart
static String pointConfigDocId(Map<String, dynamic> data) {
  final curriculumId = data['curriculum_id']?.toString() ?? '';
  final stageOrder = data['stage_order']?.toString() ?? '';
  if (curriculumId.isEmpty || stageOrder.isEmpty) {
    throw ArgumentError(
      'pointConfigDocId requires non-empty curriculum_id and stage_order',
    );
  }
  return [
    encodeKeyComponent(curriculumId),
    encodeKeyComponent(stageOrder),
  ].join('_');
}
```

That deterministically encodes the Drift unique key `(profileId, curriculumId, stageOrder, trackId)`: `profileId` is the path, `trackId` collapses into `curriculumId` under AD-25, leaving `(curriculum_id, stage_order)`.

It uses `encodeKeyComponent` (`doc_ids.dart:99`), unlike the raw joins in `stageDefinitionDocId` (`return '${curriculumId}_$stageOrder';`, :475 — verified) and `studyDayConfigDocId` (:535-545 — verified), because two `CurriculumId` storage keys contain a literal `_`: `mishnehTorah('mishneh_torah')` and `mishnaBerurah('mishna_berurah')` (`lib/core/enums/curriculum_id.dart:23-24`, verified) — exactly the collision surface `learningOrderDocId`'s doc comment says never to reopen. Same choice as the other genuinely-new formulas (`curriculumScopeDocId`, `trackLearningOrderDocId`). **Flag in the doc comment that the same logical key therefore renders differently here than in `stage_definitions`.**

**CRITICAL: nothing is ever seeded.** A missing document means "no override, use the ladder". The Drift original seeded a row per stage (`PointConfigDao.seedDefaults` / `PointConfigMaintenanceController`) — **do not reproduce that**: a seeded row makes the ladder branch permanently dead and silently pins a stale default if the ladder ever changes.

**`firestore.indexes.json`:** add `collectionGroup: point_configs`, fields `curriculum_id ASC` + `stage_order ASC` — same shape as the existing `stage_definitions` entry (`firestore.indexes.json:92`).

### `firestore.rules` block (verbatim)

Insert immediately after the `study_day_configs` block, which occupies `firestore.rules:601-609` (verified; the file is 613 lines), inside `match /learner_profiles/{profileId}`, at 8-space indent:

```
        // point_configs — per-(curriculum, stage) point-value OVERRIDES for
        // the completion award ladder (restores the retired Drift-only
        // `point_configs` table). Doc-id: `DocIds.pointConfigDocId`,
        // "{curriculum_id}_{stage_order}" percent-encoded. The ABSENCE of a
        // document means "no override — use the hardcoded ladder", so
        // nothing is ever seeded here and a stored `points` value is always
        // a parent's explicit choice.
        //
        // `points` is capped at 100 to match the `completions` create rule
        // above: the awarded value is stamped onto the completion document,
        // so an override above 100 would make every completion write for
        // that stage permission-denied.
        match /point_configs/{configId} {
          // SR-4: single-doc reads are unrestricted; `list` queries are
          // capped at 500 (the app's kListenerPageSize), matching
          // `track_learning_order` above. The repository's own
          // curriculum-scoped query always carries `.limit(500)`.
          allow get: if isOwner(uid) || hasActiveTutorAccess(uid, profileId);
          allow list: if (isOwner(uid) || hasActiveTutorAccess(uid, profileId))
            && request.query.limit <= 500;
          // SR-2: stable, fully-enumerable payload, so a key whitelist —
          // plus a type/range check on `points`, the one field whose value
          // can miscredit a learner, and a size cap on `curriculum_id`
          // matching the `bookmarks` block above.
          allow create: if isOwner(uid)
            && request.resource.data.keys().hasOnly([
              'curriculum_id', 'stage_order', 'points',
              'updated_at', 'synced_at'
            ])
            && request.resource.data.points is int
            && request.resource.data.points >= 1
            && request.resource.data.points <= 100
            && request.resource.data.stage_order is int
            && request.resource.data.stage_order >= 1
            && request.resource.data.curriculum_id is string
            && request.resource.data.curriculum_id.size() <= 100;
          // The natural key IS the doc-id, so `curriculum_id`/`stage_order`
          // must stay immutable: a changed key field would silently re-point
          // an existing override at a different stage while the doc-id still
          // claimed the old one. Only the value and its stamps may move. An
          // idempotent identical replay still passes — affectedKeys() is
          // empty and hasOnly([]) is true. The range guard is re-asserted
          // here so an update cannot escape the 1..100 bound `create`
          // enforces.
          allow update: if isOwner(uid)
            && request.resource.data.diff(resource.data).affectedKeys()
                 .hasOnly(['points', 'updated_at', 'synced_at'])
            && request.resource.data.points is int
            && request.resource.data.points >= 1
            && request.resource.data.points <= 100;
          // Owner delete permitted — deleting the document is exactly how a
          // parent RESTORES the default ladder for a stage, and `create`/
          // `update` are already owner-writable here, so forbidding removal
          // protects nothing (the same rationale the `goals`,
          // `learning_order` and `study_day_configs` blocks state). A tutor
          // (different uid) is still rejected by isOwner.
          allow delete: if isOwner(uid);
        }
```

**Note on `allow delete`:** this diverges from the `if false` default and follows the `study_day_configs` / `goals` / `profile_programs` precedent for MUTABLE config collections. An attacker who can delete can already set `points` to 1 via the owner-writable update, so delete adds no attack surface, and it is the only honest "remove the override" operation. If the owner overrules and wants `allow delete: if false`, `clearOverride` must instead write `points = defaultPointsForStage(stageOrder)`; the cost is a permanently pinned value that no longer tracks the ladder.

**Tutor writes** are denied by `isOwner`, as everywhere else. Tutors with `can_edit_points` currently write through `tutorUpdateGamificationSettings` into `preferences/gamification_settings`, which nothing will read for points — so either add a `tutorUpsertPointConfig` CF proxy (model it on `tutorUpsertStudyDayConfig`, `functions/src/tutor_writes.ts:599`, permKey `can_edit_points` — **UNVERIFIED line number; the file was not opened**) or accept that tutors can no longer edit points and gate the UI accordingly.

### Repository API

Two new files in the data ring (both exempt from `tool/check_dependency_direction.dart`).

**1. `lib/data/repositories/point_config_entry.dart`** — value type + codec + the shared ladder. It lives here, not in a feature's domain, because **both** `features/learning` (the awarder) and `features/gamification` (the screen) need it, and a model in either one would be a Rule-2 cross-feature deep import.

```dart
const kMinPointConfigPoints = 1;
const kMaxPointConfigPoints = 100;

/// The single source of truth for the default ladder.
int defaultPointsForStage(int stageOrder) => switch (stageOrder) {
      1 => 10,
      2 => 5,
      3 => 3,
      _ => 1,
    };

@freezed
abstract class PointConfigEntry with _$PointConfigEntry {
  const factory PointConfigEntry({
    required int stageOrder,
    required int points,
  }) = _PointConfigEntry;
}

extension PointConfigEntryFirestoreCodec on PointConfigEntry {
  Map<String, dynamic> toFirestore({
    required CurriculumId curriculumId,
    required DateTime updatedAt,
  });
}

PointConfigEntry pointConfigEntryFromFirestore(Map<String, dynamic> data);
// throws FormatException on a missing/unparseable stage_order or points,
// or on a points value outside 1..100 — never defaults.
```

**2. `lib/data/repositories/firestore_point_config_repository.dart`**

```dart
class FirestorePointConfigRepository {
  FirestorePointConfigRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  });

  static const int maxPageSize = 500;

  Future<List<PointConfigEntry>> getConfigsForCurriculum(CurriculumId curriculumId);
  Stream<List<PointConfigEntry>> watchConfigsForCurriculum(CurriculumId curriculumId);
  Future<Map<int, int>> getPointsByStageOrder(CurriculumId curriculumId);
  Future<PointConfigEntry?> getConfig({
    required CurriculumId curriculumId,
    required int stageOrder,
  });
  Future<void> setPoints({
    required CurriculumId curriculumId,
    required int stageOrder,
    required int points,
  });
  Future<void> clearOverride({
    required CurriculumId curriculumId,
    required int stageOrder,
  });
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, int> pointsByStageOrder,
  });
}
```

Load-bearing contract notes:
- **No `initializeDefaults` / `seedDefaults`.** Deliberate — see document shape.
- The list query is `_configs.where('curriculum_id', isEqualTo: …).orderBy('stage_order').limit(maxPageSize)`. **The `.limit()` is mandatory, not an optimisation:** the SR-4 `list` rule denies an unbounded list. `FirestoreStudyDayConfigRepository._queryForCurriculum` (`firestore_study_day_config_repository.dart:139-142`) omits it and gets away with it only because `study_day_configs` uses a plain `allow read` (verified at `firestore.rules:602`).
- **`getConfig` returns null ONLY when `!snapshot.exists`. It does not catch.** A permission-denied, a network error or a decode failure **propagates**. Do not give it the `_decodeAll` "skip a malformed doc and log a warning" leniency the sibling repositories use — on this read a swallowed error degrades silently to the ladder and under-credits a child. The LIST reads keep the leniency (configuration display; one bad row must not blank the screen); the single-doc AWARD read does not. Different branches, different rules — exactly D-E's shape.
- `setPoints` asserts 1..100 client-side (`ArgumentError`) so the failure is a Dart error at the call site, not an opaque `PERMISSION_DENIED` from the rules.
- Writes use `SetOptions(merge: true)` + `.orQueuedOffline`; `clearOverride` / `replaceAllForCurriculum` use batch delete + `commit().orQueuedOffline`, mirroring `FirestoreStudyDayConfigRepository.replaceAllForCurriculum` (:219).

**3. Provider**, appended to `lib/data/firestore/repository_providers.dart` in the same shape as the other 13 (`_watchActiveAccountAndProfile` is defined at :166):

```dart
final firestorePointConfigRepositoryProvider =
    FutureProvider<FirestorePointConfigRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestorePointConfigRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });
```

### Awarder wiring — ladder fallback vs throw, explicitly

In `FirestoreCompletionPointsAwarder.calculatePoints`, replace the final line `return pointsForStage(stageOrder);` (`lib/features/learning/data/repositories/completion_points_awarder.dart:163`) with the override lookup. It goes **after both existing gates**, so an adult profile / a goal-less curriculum still short-circuits to 0 without ever touching the new collection.

```dart
    // --- Per-curriculum point override (restores `point_configs`) ---
    final pointConfigRepository =
        await _ref.read(firestorePointConfigRepositoryProvider.future);
    if (pointConfigRepository == null) {
      throw UnsupportedError(
        'FirestoreCompletionPointsAwarder.calculatePoints: the point-config '
        'repository resolved to null while computing an award for '
        'curriculumId=$curriculumId stageOrder=$stageOrder; refusing to fall '
        'back to the default ladder when a parent-configured override may '
        'exist and could not be read.',
      );
    }
    final override = await pointConfigRepository.getConfig(
      curriculumId: curriculum,
      stageOrder: stageOrder,
    );
    return override?.points ?? defaultPointsForStage(stageOrder);
```

**Branch A — repository resolved null (backend not ready): THROW.** Control is already past the profile gate and the goal gate, both of which throw for exactly this reason, so an active account and profile are provably present and a null here is contradictory, not empty. Falling back to the ladder would silently under-credit a child whose parent set Learn=25 — and **permanently**: the returned value is written into the completion doc's `points` **and** into the points_ledger delta, and neither is ever recomputed. Nothing downstream can distinguish "the parent set no override" from "we could not read the overrides".

**Branch B — repository resolved, no document for `(curriculum, stage_order)`: return `defaultPointsForStage(stageOrder)`.** This is the CONFIGURATION branch and empty is a truthful answer: absence of a doc **is** "this parent never set an override", and the ladder is the documented default. The dangerous version of this branch — an empty result caused by a not-ready backend — is already excluded by Branch A, which throws before any empty result can be observed.

**Branch C — the read itself fails (permission-denied, offline error, malformed document): PROPAGATES out of `getConfig`.** Same reasoning as Branch A; `getConfig` must not catch.

**Blast radius that must be accepted and documented.** `calculatePoints` is called at `completion_orchestrator.dart:230` and `:344` (verified), in both cases **before** the completion write and **not** wrapped in `_safeStep` (which is defined at `:630` and used at `:274-277` for `_creditPointsIfAny`, at `:281`, `:293`, `:398`, `:410`). A throw therefore aborts the whole `markComplete` / `bulkMarkComplete` — the completion is never recorded. That is the correct trade under D-E (a loud, retriable failure beats an invisible, permanent under-credit), **but the awarder's existing doc comment at `completion_points_awarder.dart:117-119` asserts "Safe to throw: `CompletionOrchestrator._safeStep` wraps this call, so the already-durable completion write is not rolled back" — that claim is FALSE for `calculatePoints`.** It is true only of `creditCompletion`, wrapped at the `_creditPointsIfAny` `_safeStep`. **Fix that comment as part of this work**; it currently understates the blast radius of the two throws already there and of the third this adds.

Also update the class doc comment's numbered "Behaviour changes from the Drift original" item stating that per-curriculum overrides no longer apply and that a Firestore `point_configs` table "would be the separate task to restore them" — **this is that task**.

`creditCompletion` is unchanged: it already receives the computed points and already throws when the ledger repository is null.

### Screen changes — `lib/features/gamification/presentation/screens/point_config_screen.dart`

The screen cannot import the data ring (AD-23/AD-28: it is under `presentation/`). Add **`lib/features/gamification/data/repositories/point_config_repository_adapter.dart`** taking `Ref` — `PointConfigRepositoryAdapter({required Ref ref})` — modelled on `features/progress/data/repositories/firestore_progress_repository_adapter.dart` / the existing `features/gamification/data/repositories/firestore_points_repository.dart`. The screen's providers talk only to the adapter.

The adapter composes three data-ring providers: `firestoreCurriculumTrackRepositoryProvider` (`repository_providers.dart:329`) `.getActiveTracks()` for the curricula, `firestoreStageDefinitionRepositoryProvider` (:407) `.getStagesForCurriculum()` for the stage list, and `firestorePointConfigRepositoryProvider` `.getPointsByStageOrder()` for the overrides. **All three are CONFIGURATION reads, so a null repository legitimately yields an empty screen ("no active tracks") — the opposite of the awarder's rule.** Say so in a comment.

Concrete edits (line numbers verified in the current file):
- Delete every Drift import: `package:drift/drift.dart` (:5), `core/database/user/user_database.dart` (:9), `core/providers/database_provider.dart` (:13), `features/sync/presentation/providers/sync_providers.dart` (:17), and the `activeProfileIdProvider` usage from `features/profiles/presentation/providers/active_profile_provider.dart` (:16, read at :93, :174, :280).
- `pointConfigDataProvider`: rebuild on the adapter. `_TrackPointData` (:56) drops `profileId` and `trackId` (AD-25) and is keyed by `CurriculumId`. `_StagePointConfig` (:48) holds the domain `StageDefinition` plus an `int points` and a `bool isOverride`, not a Drift `PointConfig` row.
- `_pendingPrimaryByTrackId` (:244) becomes `Map<CurriculumId, int>` (or keyed on `storageKey`); update its uses at :267 and :284.
- **DELETE `_defaultPointsForStageOrder` (:42) and its `[10, 5, 3, 2, 1]` table.** It disagrees with the awarder at stage 4 today — `FirestoreCompletionPointsAwarder.pointsForStage` (:76) is `10/5/3/…else 1`, so the screen shows **2** and the child earns **1**. Both must read `defaultPointsForStage` from `point_config_entry.dart`. This is a live display-vs-award mismatch, not a hypothetical.
- Displayed value when no override doc exists: `defaultPointsForStage(stageOrder)`, rendered as the default and **not persisted** (the same "unpersisted view-model default" idea the file already documents, minus the `id: -1` sentinel).
- `_savePending`: for each pending edit call `setPoints(...)`; if the new value equals `defaultPointsForStage(stageOrder)`, call `clearOverride(...)` instead so the document is removed and the ladder resumes. Drop the `sync?.pushGamificationSettingsSnapshot()` call (:223) — `SyncWriteFacade` is gone.
- `_bumpPrimary` (:325): `math.max(1, math.min(9999, current + delta))` becomes `math.max(kMinPointConfigPoints, math.min(kMaxPointConfigPoints, current + delta))` — i.e. **100**, not 9999.
- **DELETE `PointConfigMaintenanceController` (:168), `seedMissingDefaultsIfNeeded` (:172), `pointConfigMaintenanceControllerProvider` (:229) and the `initState` post-frame call (:260-261).** Nothing is seeded any more. The stage-definition seeding half of it, if still wanted, belongs on the track-activation path, not on a settings screen's `initState`.
- Tutor gating: keep the `canEditPoints` read, but a tutor's write now hits `isOwner` and fails. Either add the `tutorUpsertPointConfig` CF proxy or set `canEdit = (tutorPerms == null)` so the UI does not offer an action guaranteed to fail. **Do not leave the buttons enabled with no proxy behind them.**
- The screen still edits only the PRIMARY (lowest `stage_order`) row, as today. The repository API supports per-stage editing if the owner wants it later; that is a UI decision, not a data one.

### Tests

1. **`test/data/firestore/doc_ids_test.dart`** (exists) — new `pointConfigDocId` group: exact formula pin; the `mishneh_torah` case proving the encoded form stays injective where the raw join is only accidentally so; `ArgumentError` on an empty `curriculum_id` or `stage_order`.
2. **`test/data/repositories/firestore_point_config_repository_test.dart`** (NEW; AG-5 mirrors the lib path). Cases: `setPoints` lands on `DocIds.pointConfigDocId`; the written doc contains no `profile_id` / `track_id` / `id` (AD-25, MCF-11); `getConfig` returns null when absent and the value when present; **`getConfig` PROPAGATES a decode failure instead of returning null** (the anti-silent-fallback test — assert it throws, do not assert null); `getConfigsForCurriculum` filters by curriculum, orders by `stage_order` and carries `limit(500)`; `watchConfigsForCurriculum` emits on change; `clearOverride` deletes the doc; `replaceAllForCurriculum` does delete-then-upsert; `setPoints` throws `ArgumentError` at 0 and at 101; the LIST path skips one malformed doc while the single-doc path does not.
3. **`test/features/learning/data/repositories/completion_points_awarder_test.dart`** (NEW path). The existing `test/features/learning/data/completion_points_awarder_test.dart` (verified present) tests the deleted `DriftCompletionPointsAwarder` against an in-memory Drift DB and cannot compile — **delete it and re-home here.** Build a `ProviderContainer` overriding `firestoreLearnerProfileRepositoryProvider` / `firestoreGoalRepositoryProvider` / `firestorePointConfigRepositoryProvider`. Cases: an override present returns the override, not the ladder; no override doc returns 10/5/3/1 for stages 1/2/3/4; **`firestorePointConfigRepositoryProvider` resolving null THROWS and does not return the ladder** (the load-bearing test — assert the throw **and** assert the message names the curriculum and stage); a repository read that throws propagates; an adult profile and a goal-less curriculum still return 0 and never read the point-config repository at all (verify zero interactions, so the gate ordering is pinned); an override of exactly 100 is accepted and the return value is never > 100.
4. **`functions/test/firestore_rules.test.mjs`** (exists) — new `point_configs` describe block, modelled on the `study_day_configs` block (**UNVERIFIED line number — the source design cites `:952`; the file was not opened**). Cases: owner write + tutor read (`expectOwnerWriteTutorRead`); tutor cannot write or delete; an unknown key rejected; `points` of 0, 101, `"10"` and 10.5 rejected on create AND on update; an update changing `curriculum_id` or `stage_order` rejected; an identical replay allowed (`affectedKeys` empty); list with limit 501 rejected and 500 allowed; owner delete allowed. Add a `point_configs` entry to `tool/emit_fixture_payloads.dart` (exists) so `functions/test/fixtures/write_payloads.json` (exists) stays codec-derived rather than hand-written.
5. **`test/features/gamification/presentation/screens/point_config_screen_test.dart`** (NEW; the directory exists) — widget: the ladder default renders when no doc exists; edit + save writes a doc; setting the value back to the ladder default clears it; the +/- clamp stops at 100, not 9999.
6. **`test/features/gamification/presentation/screens/point_config_data_provider_purity_test.dart`** (exists) — keep the purity property (watching the read provider performs no writes); it becomes trivially true once the maintenance controller is deleted, which is the point.

**`fake_cloud_firestore` limits that MUST be stated in the test file doc comments**, because each hides a real defect class:
- No offline/cache semantics at all. The offline-read miscredit in risk 1 is **untestable in Dart**. `orQueuedOffline`'s timeout path is likewise unexercisable.
- No composite-index enforcement, so the new `firestore.indexes.json` entry is unproven by any test and fails only in production.
- `request.query.limit` is not enforced, so the SR-4 `limit(500)` requirement is unproven in Dart — only the `.mjs` emulator suite covers it.
- `createFakeFirestore(strictRules: true)` cannot validate this block: `fake_firebase_security_rules` does not support `request.resource` / `resource`, so every `hasOnly`, `diff().affectedKeys()` and points-range clause evaluates to deny. **All rules coverage must live in `firestore_rules.test.mjs`.**

### Risks

1. **OFFLINE CACHE MISCREDIT (highest, and untestable with `fake_cloud_firestore`).** `getConfig`'s plain `.get()` defaults to `serverAndCache`: offline it falls back to the local cache, and a doc that was never cached reads as `!exists` — which Branch B correctly interprets as "no override" and awards the ladder. So a parent setting Learn=25 on their phone, followed by the child completing offline on a tablet that never cached that doc, silently under-credits, and the wrong value is durable in **both** the completion doc and the ledger. `Source.server` would trade this for "no completions at all while offline", which is worse. Mitigation: keep `watchConfigsForCurriculum` subscribed for the active profile so the override is cache-warm before any completion; document the residual gap.
2. **`completions` `points <= 100` CEILING.** `calculatePoints`' return value is stamped onto the completion document and `firestore.rules:249-256` caps `completions.points` at 100. Any override above 100 makes every completion write for that stage `PERMISSION_DENIED`. The 1..100 cap must be enforced in three places that can drift apart: the `point_configs` rules block, `setPoints`' client-side assert, and the screen's clamp (currently 9999). Relax one without the others and completions start failing.
3. **LADDER DIVERGENCE ALREADY LIVE.** `point_config_screen.dart:42` `_defaultPointsForStageOrder` is `[10,5,3,2,1]`; `FirestoreCompletionPointsAwarder.pointsForStage` (:76) is `10/5/3/1`. At stage 4 the screen shows 2 and the child earns 1 **today**. If the restoration reuses either table instead of collapsing both onto one `defaultPointsForStage`, the screen becomes a lying display of what a completion is worth.
4. **SEEDING WOULD KILL THE FALLBACK.** Reproducing `PointConfigDao.seedDefaults` (a doc per stage at the default value) makes the "no override" branch permanently dead, silently overrides every future ladder change with stale seeds, and destroys the distinction between "no doc" and "never configured". The design depends on absence-means-default. **Do not seed.**
5. **THROW BLOCKS THE COMPLETION.** `calculatePoints` runs pre-write and unwrapped at `completion_orchestrator.dart:230` and `:344`, so Branch A's throw aborts the entire `markComplete` — no completion is recorded. This is the intended D-E trade (loud beats silent), but the awarder's doc comment at `:117-119` currently claims `_safeStep` protects this call, which is false and will mislead the next reader into adding more throws here.
6. **TUTOR WRITE PATH BREAKS SILENTLY.** `can_edit_points` tutors write via `tutorUpdateGamificationSettings` into `preferences/gamification_settings`, which nothing will read for points. Without a `tutorUpsertPointConfig` CF, a tutor's save either fails with permission-denied or appears to succeed while changing nothing a learner will ever earn. **Decide explicitly: add the proxy, or disable the UI for tutors.**
7. **STALE READS THROUGH THE PROVIDER.** `firestorePointConfigRepositoryProvider` returns null during a tutored session and whenever no profile is active (`_watchActiveAccountAndProfile`). Branch A throws on null, which is correct, but it means a completion attempted in a tutored context now fails loudly where it previously awarded ladder points. **Confirm with the owner that this is wanted before shipping.**
8. **DOC-ID ENCODING SPLIT.** `point_configs` uses `encodeKeyComponent` while `stage_definitions` uses a raw join, so the same `(curriculum, stage)` pair renders as two different ids across the two collections (`mishneh%5Ftorah_1` vs `mishneh_torah_1`). Harmless — they are joined on the `stage_order` field, not the id — but a maintainer eyeballing the console may assume one is corrupt. **Call it out in both doc comments.**
9. **PARTIAL SAVE.** The screen saves per curriculum in a loop with no batch, so a mid-loop failure leaves some curricula overridden and others not, with no rollback and no marker. `replaceAllForCurriculum` batches within one curriculum but not across them.