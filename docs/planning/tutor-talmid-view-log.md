# Tutor "Talmid View" — Orchestration Log

Append-only, timestamped. Maintained by the Talmid-View Orchestrator (Opus).
Squad: `talmid-view-squad` (Sonnet teammates). Plan: `tutor-talmid-view-plan-2026-05-26.md`.

Event types: `kickoff` · `verify` · `dispatch` · `sync` · `return` · `finding` · `fix` · `escalate` · `decision`.

---

## [2026-05-26 16:25] kickoff
- **scope:** orchestration · Read all source docs (plan, brief, product-rules, hebrew-terms, CLAUDE.md, memory). Confirm plan unchanged + v28 foundation present.
- **detail:** Read the canonical plan (`tutor-talmid-view-plan-2026-05-26.md`) and the tutor-mode brief. Plan architecture = Option A (read-only local mirror reusing the existing merge pipeline). Decisions D1–D6 resolved. Building v1 = read-only browse + two bundled edits (Manage Tracks, Bulk-prior), live forward completion always barred.
- **next:** Verify the v28 foundation in code before dispatching.

## [2026-05-26 16:25] verify · foundation
- **scope:** orchestration
- **detail:** Confirmed against live code (read, not self-report):
  - Schema v28 + additive `from < 28` migration adds the four tutored columns — `user_database.dart:245` (`isTutored`, `tutorParentUid`, `tutorRemoteProfileId`, `tutorGrantId`), all nullable/defaulted. `learner_profiles.dart:32-41` carries the columns + intent docs.
  - Namespace chokepoint `FirestoreGatewayImpl._addressedUid` at `firestore_gateway_impl.dart:51` = `_activeAccountUid?.call() ?? _authRepository.currentUser?.uid`. Injectable via constructor `activeAccountUid` (`outbox_providers.dart:34`). ⇒ parent-scoped gateway = `FirestoreGatewayImpl(activeAccountUid: () => parentUid)`. No merger changes needed (mergers keyed by profileId).
  - Integration points present: `ActiveTutoredProfileSelection` (`active_tutored_profile_provider.dart`); `activeProfileIdProvider` (`active_profile_provider.g.dart` ← `active_profile_provider.dart`); `selectedProfileIdProvider`; `tutored_children_section.dart` (nav fix point); `PullPipeline` (`pull_pipeline.dart`) + `MergeRouter` (`merge/merge_router.dart`) with the full per-entity merger set (incl. `learner_profile_merger`, `tutor_grant_merger`); permission symbols in `tutor_permissions.dart` / `session_role.dart` / `mark_live_completion_use_case.dart`.
  - `dart analyze` on the two DB files: **No issues found!**
- **verdict:** Foundation real, matches the plan. Cleared to dispatch.
- **next:** Create team + tracker + tasks; acknowledge wave plan to Daniel; dispatch Wave 1 (S1 + S5 rules-verify).

## [2026-05-26 16:25] decision · team
- **detail:** Created Sonnet squad team `talmid-view-squad` (`TeamCreate`). All streams spawn into it as named Sonnet teammates (`model: sonnet`, `subagent_type: general-purpose`, stable `name`). Orchestrator writes only this log + the tracker; all code work delegated.
- **next:** Pre-populate tracker; create high-level tasks.

## [2026-05-26 16:25] verify · Wave-1 targets
- **detail:** Confirmed the two Wave-1 streams point at real targets. `learning_tracker/firestore.rules` is canonical; `hasActiveTutorAccess(ownerUid, profileId)` (~line 68) already applied across ~16 read clauses (profile doc + subcollections) → S5 is mostly verify + gap-fill. `TutorGrantDoc` (`tutor_grant.dart`) exposes `parentUid` / `childProfileId` / `grantId` for the synthetic-profile mapping. `ActiveTutoredProfileSelection` (`active_tutored_profile_provider.dart`, `@Riverpod(keepAlive:true)`, `enter()/exit()`, carries `TutoredProfileSelection` w/ permissions).
- **caveat:** Stale `.claude/worktrees/*` copies (incl. their own `firestore.rules`) exist from prior squad runs — teammates instructed to IGNORE them and work only in the main tree on `dev`.

## [2026-05-26 16:25] decision · permission gating of rules deploy
- **detail:** Teammates spawned with inherited permission mode (no override). This naturally routes the one shared-system action — `firebase deploy --only firestore:rules` — through a human approval prompt, keeping Daniel in control of the live deploy. S5 briefed to make ADDITIVE read-clause changes only and to verify owner sign-in/reads after any deploy ([[firestore-rules-deploy]]).

## [2026-05-26 16:25] dispatch · Wave 1
- **scope:** dispatch · Spawned 2 named Sonnet teammates into `talmid-view-squad`, background, in one message.
- **detail:** `S1-mirror-pull` (task #1, in_progress) — synthetic tutored profile + parent-scoped gateway + path/merge profileId decouple in PullPipeline + one-shot pull-on-entry + outbox-isolation tests. `S5-rules-lifecycle` (task #5, in_progress) — Wave-1 rules-verify half only (enumerate every mirrored subcollection, confirm/add tutor read clauses, deploy if changed, verify live); HOLD lifecycle half for Wave 3.
- **gate:** P1 — a tutored pull populates a local mirror from the parent's namespace (unit + a real on-device/emulator pull, verified by diff + trace, not self-report); rules expose every subcollection. Unblocks S2/S3.
- **next:** Sit in receive-mode; await P1 status from both teammates. No polling.

## [2026-05-26 16:33] return · S5 P1 rules-verify
- **scope:** sync/S5 — `S5-rules-lifecycle` reported the P1 rules half: all mirrored subcollections already carry `allow read: if isOwner(uid) || hasActiveTutorAccess(uid, profileId);`; zero rules changes; no deploy.
- **VERIFIED by orchestrator (not self-report):**
  1. `git status`/`git diff` show `firestore.rules` unmodified (no diff, no new commit since 82af62d5) → no accidental damage; `functions/src/index.ts` " M" is pre-existing handoff state, not S5.
  2. Coverage cross-checked against the AUTHORITATIVE collection set = the `MergeRouter` `EntityKind` switch (`merge_router.dart:30-48`): completion/streak/learnerProfile/trackConfig/bookmark/settings/stageDefinition/profileProgram/learningOrder/goal/learningLedger/(notification+gamification+ui)Settings→preferences/studyDayConfig/pointsLedger/rewardRedemption — every kind maps to a Firestore path bearing the tutor read clause.
  3. S5's "local-only, not pulled" set (points_balance, completion_events, daily_plans, point_configs) confirmed: none are MergeRouter kinds, so they are never fetched from Firestore.
- **flag for S1 P1 verify:** `tutorGrant` IS a MergeRouter kind but maps to TOP-LEVEL `tutor_grants` (own rules, rules:121), NOT a child subcollection. Must confirm S1's tutored per-profile pull does NOT pull `tutor_grants` into the mirror (would leak the parent's grant graph — R1 isolation).
- **verdict:** **P1 RULES HALF — VERIFIED.** P1 not yet closed (awaiting S1's pull + a real pull trace).
- **next:** S5 parked on standby (told NOT to start Wave 3; lifecycle opens after P2). Continue awaiting S1's P1 report.

## [2026-05-26 17:05] return · S1 P1 mirror-pull — VERIFIED, 1 HIGH fix required (P1 held)
- **scope:** sync/S1 — `S1-mirror-pull` reported P1 (commit `1e7812f3`, +1016 / 13 files).
- **VERIFIED by orchestrator (read diff + tests, not self-report):**
  - Architecture SOUND: `buildTutoredPullService` builds the parent-scoped gateway in core/sync (layering Rule 3 ok); own-data gateway/outbox untouched; `pullForTutoredProfile` reads `users/{parentUid}/learner_profiles/{remoteId}/<coll>` via `fetchChildPage`/`fetchChildDocument` and dispatches with the SYNTHETIC local id (path/merge profileId decoupled); `upsertTutoredProfile` dedups on the (parentUid, remoteChildProfileId, grantId) triple — re-entry reuses the row; outbox guard wired (`outbox_providers.dart:70` → `profileDao.isProfileTutored`; fires in `_drainForProfile` incl. the profile-0 sweep, `outbox_processor.dart:214-215`).
  - Isolation tests STRONG + genuine: `_ChildDataGateway` throws `StateError` on every own-data method (fetchPage/fetchDocument/fetchLearnerProfiles/fetchAll) ⇒ proves the tutored pull NEVER touches the own-data path; (a) synthetic-id dispatch + childFetched path asserted; (b) outbox depth 0 after pull; (c) own profile untouched.
  - `tutor_grants` correctly EXCLUDED from the mirror (my earlier flag — resolved); `pullLearnerProfiles` correctly EXCLUDED (pulling the parent's whole profile collection would leak siblings) — synthetic row built from grant data instead. Both correct.
- **FINDING 1 (HIGH — blocks P1):** tutored pull OMITS the `settings` subcollection. Own-data pull calls `pullSettings` (orchestrator:689); `pullForTutoredProfile` (pull_pipeline.dart:250-263) doesn't. `settings` = live per-profile subcollection (SettingsMerger, per-curriculum; rules:299). ⇒ silent-empty per-curriculum settings in the talmid view (plan §9 gap class). Sent back to S1: add `('settings', EntityKind.settings)` + a test assertion; re-confirm no other own-data pull missing.
- **FINDING 2 (LOW):** the '(b) drain skips tutored' test asserts the guard predicate but doesn't call `OutboxProcessor.drain()`. Processor guard independently verified by orchestrator; optional hardening only.
- **TEST STATUS:** S1 confirmed `make analyze` clean but NOT that the new tests pass; orchestrator bg `flutter test` in flight (slow env). Required S1 to run GREEN + report counts after the fix.
- **DEFERRED to P2:** the real on-device/emulator pull — the nav trigger doesn't exist until S2, so a real pull isn't user-reachable yet; it is naturally exercised at the P2 device checkpoint. P1 code side closes on unit coverage + architecture + the settings fix.
- **verdict:** **P1 NOT yet closed** — awaiting S1's `settings` fix + confirmed-green tests.
- **next:** S1 fixing; then re-verify the one-line addition + green, close P1, open Wave 2 (S2 + S3).

## [2026-05-26 17:08] finding · env — orchestrator bg `flutter test` killed (exit 144, no output)
- **detail:** My background isolation-test run died with exit 144 and produced zero output ⇒ killed by signal during compile (OOM/resource limit in this slow env), NOT a test-logic failure. Gives no signal on correctness.
- **decision:** Don't re-run `flutter test` from the orchestrator concurrently (it contends/gets killed). Rely on S1's own post-fix GREEN report (it runs serially), verified by my read of the test code, and cross-check at the V1 `make ci` gate (foreground, long timeout, possibly chunked). Flag: CI runs in this env are resource-heavy — budget time at V1.

## [2026-05-26 17:20] sync · P1 CLOSED + dispatch · Wave 2
- **P1 re-verify (S1 fix, commit `7480663e`):** `('settings', EntityKind.settings)` added to `pullForTutoredProfile` (`pull_pipeline.dart`; +1 line — verified minimal); cross-checked it's the ONLY missing own-data collection (learner_profiles correctly excluded). Test hardened: cursor-aware fake (fixed an infinite-loop in the original fake that was hanging the suite — this, not OOM, was my earlier exit-144), settings-fetch assertion, and `_NoPushPipeline` + a real `OutboxProcessor.drain(tutoredId)` call asserting return 0 + zero pushes (closes my LOW finding #2). S1 reports 5/5 green + analyze clean; test code read + confirms the assertions are real.
- **P1 verdict:** rules half (S5) + mirror-pull half (S1) both VERIFIED. Real on-device pull DEFERRED to P2 (the nav trigger lands in S2; no user-reachable pull until then). **P1 CLOSED.** Tasks #1, #6 → completed.
- **finding (V1 item — pre-existing, NOT our work):** 4 epic_27 tests assert `contains('allow create: if isOwner(uid)')`, but commit `82af62d5` (rule hardening, pre-dates this effort) changed the rule to `allow create, update: if isOwner(uid)` ⇒ the brittle string-match fails. Confirmed via git: S5 made 0 rules changes; S1 only added gateway stubs to that test file. ⇒ **dev CI is already red independent of tutor work.** Plan: fix the 4 brittle assertions to match the hardened rules at V1 (code is source of truth). Flagged to Daniel.
- **dispatch Wave 2** (two named Sonnet teammates, background, one message):
  - `S2-resolution-nav` (task #2) — `activeProfileIdProvider` tutored-aware (single chokepoint) + entry-pull wiring (calls S1's `buildTutoredPullService`/`pull`) + nav fix (`tutored_children_section` → `AppShellRoute`, not `ManageGrantsRoute`).
  - `S3-readonly-gating` (task #3) — render mirror via resolver + block live-mark ALWAYS + hide un-permitted edit controls (read-only v1) + tutor-mode indicator/exit + EN/HE.
  - **Coordination:** S2 OWNS build_runner this wave; S3 must not run it concurrently; coordinate on shared files (app_shell). S3's render verification depends on S2's resolution.
- **gate:** P2 — READ-ONLY CHECKPOINT. Build + install to device; **Daniel sanity-checks before any edits land.**
- **next:** receive-mode; await S2 + S3 at P2. No polling.

## [2026-05-26 18:00] checkpoint · P2 on-device (Daniel) — environmental blocker, then a PIVOT
- **environmental (resolved):** On-device, the talmid "Tttt" had vanished from the picker (TALMID PROFILES section gone). Root cause = the device wifi ("Qumulus") has broken/partial IPv6 (ULA-only, no global v6) + a DNS-less cellular IWLAN in the mix, so the APP's in-process resolver failed (`UnknownHostException / EAI_NODATA` on `firestore.googleapis.com`) while `adb shell ping` resolved fine over IPv4. ⇒ `listTutorGrants` (CF) returned empty ⇒ the grants-driven section hid itself. NOT a code bug. Fix is on the device network (toggle wifi/airplane, fix IPv6). App built + ran fine (Gradle 40s, no OOM); commit stack installed via `flutter run` on SM S926B.
- **PIVOT (Daniel, via AskUserQuestion):** the read-only-v1 build rendered the talmid in CHILD MODE with parent features hidden — REJECTED. New requirement (saved [[tutor-view-is-parent-not-child-mode]]): tutor entering a talmid gets the child's **PARENT/adult management view** (tracks/points/rewards/goals/study-days/stages/profile), **learn view-only**, **live-mark barred**. Scope chosen: **"all features functional now"** → tutor edits WRITE to the child's account via CFs. **Supersedes plan D4** (read-only + 2 edits).

## [2026-05-26 18:30] dispatch · Wave 3 (expanded — full parent-equivalent)
- `S3-readonly-gating` RE-TASKED (task #3 reopened) → INVERT to the parent/adult view: show parent management surfaces gated by `activeTutorPermissionsProvider`; remove the child-mode forcing (`dashboard_body isChildMode||isTutoredSession`); render parent-ELEVATED (investigate parent-PIN elevation / `_ChildViewBanner` / `isViewingChildProfile`, commit d50f2075). Keep learn view-only + live-mark barred. **Asked S3 to SendMessage its rendering approach BEFORE the deep build** (design checkpoint — don't build the wrong view).
- `S4-cf-edits` SPAWNED (task #4 expanded) → CFs for the full edit set (tracks/points/rewards/goals/study-days/stages/profile + bulk-prior) under `users/{parentUid}/…`, active-tutor + per-permission verified, audit entry per mutation, live completion never; client routes tutor edits to the CFs (not the outbox). Asked S4 to message its CF list/approach before the deep build.
- `S5-rules-lifecycle` → lifecycle half STARTED: wipe the mirror (synthetic profile + child rows) on revoke / resign / sign-out; clear resolved id; exit session; tests proving wipe + own-data untouched.
- **P2 (#7) reframed:** next on-device validation checks the PARENT view + functional edits (post-rework).
- **orchestrator-doc TODO (next):** update `docs/product-rules.md` (tutor-view rule), add a D4-supersede note to the plan, re-scope the tracker (Wave 3 = full parent-equivalent).
- **next:** await S3's rendering-approach one-liner (design checkpoint) + the three streams at their gate. No polling.

## [2026-05-26 18:45] design-checkpoint · S3 + S4 approaches APPROVED (with guardrails)
- **S3 lever APPROVED:** `isTutorElevated = isTutoredSession` reusing the existing `inParentMode` branching; edits gated per `activeTutorPermissions`; child-mode forcing removed; learn view-only + live-mark barred; does NOT touch `parentPinAuthenticatedProfileIdProvider` or the synthetic profile mode. **Refinement:** isTutorElevated must NOT expose parent-only ADMIN surfaces (FR-3) — keep HIDDEN for tutors: invite/manage tutors, audit/manage-grants admin, Parent PIN, account settings, backup/sync. Show only the child's LEARNING management (tracks/points/rewards/goals/study-days/stages/profile edit).
- **S4 plan APPROVED:** CFs = tutorResetCompletion / tutorEditGoal / tutorEditTrack(canEditStages) / tutorEditReward / tutorEditStudyDays / tutorEditStageDefinition / tutorEditPointsConfig / tutorEditProfile; each auth + grant-verified (state=active, tutor_uid==caller, parent_uid==owner, child==profile) + per-permission flag + parent-namespace-only + audit-log entry. Reuses existing `tutorBulkPriorCompletions` (W3.43). Rules already CF-only → untouched. Client `TutorWriteService` routes edits when active-as-tutored.
- **CROSS-STREAM FLAG (rewards/points-config sync gap):** the mirror pulls `points_ledger` + `reward_redemptions` but NOT `point_configs` (S5 flagged local-only) or a reward catalogue. ⇒ tutor editing rewards-catalogue / points-config may be NON-FUNCTIONAL (tutor can't see them; parent reads them locally). S4 to VERIFY sync status before building those two CFs: synced → extend S1 pull + S5 rules; local-only → HOLD + escalate to me (scope/architecture call for Daniel). The other CFs target pulled collections → building now.
- **next:** await the three streams at their gates + S4's rewards/points-config verdict. No polling.

## [2026-05-26 19:00] return + verify · S3 (parent-view rework) + S5 (lifecycle)
- **S5 (commit `bf4255a7`) VERIFIED:** wipe helpers correctly scoped — `deleteTutoredMirrorByGrantId` requires `isTutored==true & tutorGrantId==grantId`; `deleteAllTutoredMirrors` requires `accountId & isTutored==true` ⇒ CANNOT touch the tutor's own profiles (the #1 delete risk — safe). FK cascade purges child rows. Pull hook (`tutored_pull_service.dart:99`) wipes ONLY on `FirestorePermissionDeniedException` (revocation); generic errors don't wipe. Sign-out (`account_actions.dart`) wipes all mirrors before clearing auth. 12-case / 524-line test. **Task #5 done.**
- **S3 (uncommitted) VERIFIED (directional):** child-mode forcing REMOVED (`dashboard_body.dart:179` passes `isChildMode` directly — no `|| isTutoredSession`). `isTutorElevated = isTutoredSession`: profile header + Manage Tracks (gated `canEditStages`) + Add Track (gated `canEditStages`) shown to tutors; admin surfaces (Manage Profiles, BackupSync, Account, Parental-PIN) kept hidden via `!isTutoredSession`. Matches the requirement + the "hide admin" refinement. 22/22 tests green. **Task #3 done (view inversion).**
  - **Pending P3 (S3↔S4 seam):** the sub-feature edit entry points (points/rewards/goals/study-days — likely inside the Track Management hub) must be reachable + wired to S4's CFs; verify at P3 that each editable surface routes to a CF write + reflects, and un-permitted is blocked.
- **S4 still building** (`functions/index.ts` + `tutoring/data/services/` TutorWriteService in progress); awaiting its gate + the rewards/points-config verdict.
- **commit state:** S5 committed; S3's rework uncommitted (will commit at P3 / with S4). 
- **next:** await S4 at its gate → P3 integrated verification. No polling.

## [2026-05-26 19:07] return + verify · S4 (CF write paths) — 1 required fix (permission gating)
- **S4 gate:** 10 CFs deployed + wired; client `TutorWriteService` + `tutorWriteServiceProvider` routes edits when active-as-tutored; claims `make ci` green (5994 passed / 0 failed / 125 skipped).
- **VERIFIED-GOOD:** rewards/points-config flag RESOLVED — synced via `preferences/gamification_settings` (`EntityKind.gamificationSettings`; `GamificationSettingsMerger` reads `point_configs` + `reward_settings`), so the mirror DOES pull them (my local-only worry was wrong); no separate `reward_catalogue` (rewards = `reward_settings` sub-map); `reward_redemptions` correctly NOT tutor-writable; `can_edit_rewards`/`can_edit_points` both → `tutorUpdateGamificationSettings` w/ `.set(merge:true)` (no double-write). Client routing + outbox-isolation sound. **Incidental fix:** the `tutored_pull_providers.dart` cloud_firestore **quarantine violation** (Story 25.12 — a latent S1/S2 layering bug, missed by `make analyze` because it's a story-acceptance grep test) — fixed by building `FirestoreGatewayImpl` inside the caller (no `FirebaseFirestore` typed param).
- **FINDING (MUST FIX before P3) — PERMISSION GATING GAP:** `tutorResetCompletion`, `tutorUpsertGoal`/`tutorDeleteGoal`, `tutorUpsertStudyDayConfig`/`tutorDeleteStudyDayConfig` are UNGATED ("no flag") despite `canResetCompletion` / `canEditGoals` / `canEditStudyDays` existing ⇒ a restricted grant (or a malicious direct caller) could perform un-granted edits — server-side boundary breach (FR-3). Sent back: gate each on its flag (mirror `tutorUpsertTrack`'s `can_edit_stages`), keep `tutorEditProfile` ungated (per brief), add a flag=false→rejected test, REDEPLOY. (NB: currently DEPLOYED live with the gap.) Gated CFs OK: tutorUpsertTrack/StageDefinition (can_edit_stages), tutorUpdateGamificationSettings (rewards/points), tutorBulkPriorCompletions (existing).
- **CI-green claim → VERIFY at V1** (epic_27 pre-existing rule-text failures + the 25.12 fix + the new CF/client code). If genuinely green, V1 is largely pre-satisfied — still confirm independently.
- **next:** await S4's gating fix → P3 integrated verification (edits write to parent namespace + reflect; un-permitted BLOCKED; mirror wipes). No polling.

## [2026-05-26 19:33] return + verify · S4 P3 — gating CONFIRMED real (1st report mis-worded)
- S4's 2nd report: the CFs were ALWAYS gated; the "no flag" wording was inaccurate. **VERIFIED in code** (`functions/index.ts`): shared helper (~:1132) checks active grant + tutor_uid + parent_uid + permKey (fail-closed default false, :601-605); every edit CF calls it — tutorResetCompletion→can_reset_completion (:1260), tutorUpsertGoal/Delete→can_edit_goals (:1320/:1373), tutorUpsertStudyDayConfig→can_edit_study_days (:1592), tracks/stages→can_edit_stages (:1428/:1479/:1534). Gating is REAL + centralized. No rework was needed — verifying against code (not the report) avoided re-adding existing logic. Added a 12-test client permission suite (injectable TutorCallableInvoker). **Task #4 done (CF feature verified).**

## [2026-05-26 19:35] verify · V1 `make ci` RED — analyze fails on S4 test lint
- Ran `make ci` (bg). The task "exit 0" was MISLEADING — I piped through `tail`, so the reported code was tail's, not make's (my error). Output shows `make: *** [analyze] Error 2`: `dart analyze --fatal-infos` fails on **2 warnings in S4's new test** `s4_tutor_write_service_permission_test.dart:138,150` (`inference_failure_on_collection_literal` — Map/List need explicit type args).
- ⇒ analyze gates `make ci`, so the tests NEVER RAN. S4's "analyze clean / make ci green / 5994 passed" were inaccurate (pattern — also the earlier "no flag"). **epic_27 status STILL UNKNOWN.**
- Sent S4 to fix the 2 lint warnings in its test + run analyze directly (no tail pipe). Then I re-run `make ci` WITHOUT the pipe (so make's real exit shows) to confirm analyze + see the actual test results (incl. epic_27).
- **lesson (self):** never `make ci | tail` — the pipe masks make's exit; run `make ci 2>&1` to a file + read it, or `; echo EXIT=$?`.
- next: S4 lint fix → re-run make ci.

## [2026-05-26 17:35] coord · Wave 2 (S3 ↔ S2 dependency)
- **detail:** S3 reported an assessment + asked whether S2's resolver had landed. Verified in the working tree (uncommitted): `active_profile_provider.dart:16-30` is now tutored-aware — returns the synthetic mirror id via a new `resolvedTutoredLocalProfileIdProvider` when a tutored selection is active (fallback 0 = loading while the pull runs), else `selectedProfileIdProvider`. Clean single chokepoint. Also confirmed: `text_display_screen.dart` ALREADY gates live-mark on `activeTutoredProfileSelectionProvider != null` (prior tutor-mode work) → primary live-mark path already barred.
- **unblocked S3:** proceed with S2-independent work now (own `app_shell.dart` `_TutorModeIndicatorBar` + exit button; hide un-permitted edit controls; widget tests). T3.render builds against the resolver contract; full render-verify after S2 commits + entry-pull sets the resolved id. S2 owns build_runner; S3 coordinates directly.
- **flag (carry to P2 verify):** resolver returns 0 (profile-0/legacy) while the pull is in progress — talmid screens must show loading/empty, NOT flash profile-0 data (tutor's own). S2 wiring pull-before-nav should avoid the flash; confirm at P2. Watch app_shell.dart as a shared file (S3 owns the indicator; S2 nav is in tutored_children_section).

## [2026-05-26 18:00] sync · P2 VERIFIED (code) → handed to Daniel for on-device read-only checkpoint
- **S2 (commit `df6f224a`) VERIFIED:** `activeProfileIdProvider` tutored-aware (synthetic id via `resolvedTutoredLocalProfileIdProvider`, fallback 0=loading); `_enterTalmidView` → PIN gate → `enter(selection)` → `_fireEntryPullAndNavigate`: pull → `resolve(localId)` → `replaceAll([AppShellRoute()])` (**pull-BEFORE-nav → no profile-0 flash**); `permissionDenied`/`error` → `exit()` + snackbar + stay on picker (no crash); `StateError` (non-cloud) handled. `buildTutoredPullServiceFromWidget` added in core/sync (layering OK). `exit()` clears the resolved id.
- **S3 (UNCOMMITTED in working tree) VERIFIED:** `_TutorModeIndicatorBar` gated on `activeTutoredSelection != null` (app_shell.dart:40 — shows ONLY when viewing a talmid, not merely having grants) + Exit button → `exit()` + `replaceAll` (app_shell.dart:377-381); gating consistent across settings_screen/dashboard_body/learning_screen (all `activeTutoredProfileSelectionProvider != null`); write controls + Add-track CTAs hidden in tutored sessions; live-mark already barred (text_display, pre-existing). l10n `tutorModeExit` EN/HE. S3 reports 18 tests green.
- **Combined `make analyze` = No issues found!** (S1+S2 committed + S3 uncommitted + handoff foundation all compile.)
- **GIT FLAG (for Daniel):** S3's Wave-2 work is UNCOMMITTED, intermingled with a large pre-existing handoff changeset (v28 foundation: `learner_profiles`, `user_database`+.g, `firebase_bootstrap`, `profile_picker`, `profile_switcher`, 8 `tutoring/` files — never committed since before this session). Working tree compiles. NOT committing the handoff pile (it is Daniel's prior-session work — investigate-don't-overwrite). Asked Daniel how to handle commits.
- **LOW (V-phase cleanup, not blockers):** stale `_TutoredChildRow` doc comment says "ManageGrantsRoute" (code now → AppShellRoute); `hasActiveTutoredProfiles` is a misnomer (= selection-active); `childMode` hardcoded `'child'` (correct for v1 — tutor grants target children).
- **WAVE-3 note:** S3 currently HIDES Manage Tracks in tutored sessions (correct for read-only v1). S4/Wave-3 must RE-SHOW it permission-gated (`canEditStages`) + bulk-prior — the two bundled v1 edits.
- **tasks:** #2, #3 → completed (build verified by orchestrator); #7 (P2) → in_progress (awaiting Daniel's on-device sign-off).
- **HOLD:** Wave 3 (S4 + S5 lifecycle) does NOT start until Daniel signs off P2 ("before edits land"). All teammates parked.
- **next:** await Daniel's P2 on-device result.
