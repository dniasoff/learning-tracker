# Tutor Edit Propagation — Tracker

Mirror of the streams + sync points + verification phase.
Status legend: `pending` · `in-progress` · `done` · `verified`.

Plan: `tutor-edit-propagation-plan.md` · Log: `tutor-edit-propagation-log.md`.

---

## Streams

### S1 — Routing foundation (keystone) — **done** (P1 PASS; HIGH advisory bundled to S2)
- [x] `tutorWriteServiceProvider` integration (resolved via the router constructor)
- [x] **`TutoredWriteRouter`** mapping `(kind, serialized map, docId)` → matching CF call using `grantId/ownerUid/profileId` from `activeTutoredProfileSelectionProvider` (commit `f1861516`)
- [x] Wire `OutboxSyncWriteFacade` (push/delete entry points) to consult the router BEFORE enqueueing — via `syncWriteFacadeProvider` wrap
- [x] Wire `SyncEngine`/`PushPipeline` push/delete paths to consult the router — `_syncEngine` typed as `SyncWriteFacade?`, injected from `syncWriteFacadeProvider` in both `goalRepositoryProvider` and `completionRepositoryProvider`
- [x] Non-tutored path unchanged (regression test in AC2 × 5 entity kinds)
- [x] Unit test: tutored session → CF; non-tutored → outbox (AC1 + AC2, 14 tests total)
- [x] Outbox isolation hardening: tutored writes NEVER reach the outbox (AC3 totalEnqueueCount=0 across all intercepted kinds)
- ⚠️ **HIGH advisory carried to S2:** direct readers of `outboxSyncWriteFacadeProvider` BYPASS the router wrap. Scope-relevant cases: `add_track_providers.dart:21`, `study_day_config_screen.dart:186`, `edit_track_screen.dart:330`. S2 must refactor these to read `syncWriteFacadeProvider`.

### S2 — Existing-entity wiring — **done** (commit `9ccdcd61`; 1 persistent gap → fix-agent)
- [x] Route `pushTrack` / `deleteTrack` → `tutorUpsertTrack` / `tutorDeleteTrack` (existed in S1; verified)
- [x] Route `pushStageDefinitions` → `tutorUpsertStageDefinition` (existed; verified)
- [x] Route `pushGoal` / `deleteGoal` → `tutorUpsertGoal` / `tutorDeleteGoal` (existed; **`GoalEntity.toFirestore` normalized to snake_case** — R2 critical fix landed)
- [x] Route `pushStudyDayConfig` / `deleteStudyDayConfig` → `tutorUpsertStudyDayConfig` (existed; verified)
- [x] Serializer field names + doc-id parity tests for all 5 kinds (7 tests in `s2_entity_parity_test.dart` + 290 lines in router test)
- [x] Refactor `outboxSyncWriteFacadeProvider` direct readers: `study_day_config_screen.dart` (done) + `TrackCreationService`/`add_track_providers.dart` (done, facade split)
- ⚠️ **GAP — fix-agent after S4:** `edit_track_screen.dart:330` left on `enqueueProfileProgram` (outbox-only helper). `tutorSetProfileProgram` CF remains unreachable until `pushProfileProgram` is added to `SyncWriteFacade` + routed.
- 🔍 **R2-GOAL-TRACK-ID (V2 candidate):** `GoalEntity` has no `trackId` → merger skips rows. Pre-existing in own-device path too. Out of S2 scope; carry to V2 R2 review.
- [ ] On-device + live Firestore — verified at integrated P2 (after S4 + fix-agent).

### S3 — Parity CFs (program enrolment) — **done** (commit `dbc36599`; 2 of 3 CFs awaiting client paths)
- [x] **NEW CF** `tutorUpsertBookmark` → `bookmarks/{curriculumId}_{trackType}` (can_edit_stages); REACHABLE via S3's new `pushBookmark` route ✅
- [x] **NEW CF** `tutorSetProfileProgram` → `profile_program/{id}` (can_edit_stages); ⚠️ UNREACHABLE until fix-agent lands `pushProfileProgram` interface
- [x] **NEW CF** `tutorUpsertCurriculumScope` → `curriculum_scopes/{id}` (can_edit_stages); ⚠️ UNREACHABLE — no client push path exists today (pre-existing gap); kept as future-proofing
- [x] **`point_configs` propagation verified** via gamification snapshot (GamificationSettingsMerger reads `points_config` list); no dedicated CF needed
- [x] Add `TutorWriteService.upsertBookmark` / `setProfileProgram` / `upsertCurriculumScope`
- [x] CF tests + router unit tests (5 new bookmark tests + AC3 6-kind isolation)
- [ ] Deploy CFs — HELD; will deploy once after S4 + fix-agent complete.

### S3 — Parity CFs (program enrolment) — pending
- [ ] **NEW CF** `tutorUpsertBookmark` → `users/{uid}/learner_profiles/{pid}/bookmarks/{id}` (`can_edit_stages`)
- [ ] **NEW CF** `tutorSetProfileProgram` → `users/{uid}/learner_profiles/{pid}/profile_program/{id}` (`can_edit_stages`)
- [ ] **NEW CF** `tutorUpsertCurriculumScope` → `users/{uid}/learner_profiles/{pid}/curriculum_scopes/{id}` (`can_edit_stages`)
- [ ] Verify `point_configs` propagate via existing gamification snapshot CF (else add a parity CF) — confirm before building
- [ ] Add `TutorWriteService` methods for each parity CF; route their pushes through the router
- [ ] CF tests: auth → active-tutor-verify → permission → write → audit (pattern mirrors `tutorUpsertTrack`)
- [ ] End-to-end: tutor creates a track **with program enrolment** → bookmark + profile_program + curriculum_scope + point_configs all land in the parent's namespace

### S4 — Other edits + UI gating — **done** (commits `2b1af2d4` + `d954a41f`)
- [x] Route gamification snapshot → `tutorUpdateGamificationSettings` via injected `buildGamificationSnapshot` builder; `permKey` = `can_edit_rewards` (catch-all — CF accepts both flags and uses `.set(merge:true)`)
- [x] Route profile edit (snake + camel key extraction; early-return if all fields null) → `tutorEditProfile`
- [x] Route completion reset (new `deleteCompletion(String)` added to `SyncWriteFacade` interface) → `tutorResetCompletion`
- [x] `deleteLearnerProfile` stays pass-through (talmid profile deletion is not a tutor right; defense in depth via outbox guard)
- [x] Permission-denied snackbar: `tutorPermissionDenied` localization EN+HE; wired in 4 edit surfaces (`point_config_screen`, `reward_configuration_screen`, `study_day_config_screen`, `profile_edit_delete_actions`)
- [x] 14 new tests (S4-A gamification × 4, S4-B profile × 6, S4-C completion × 4)
- [x] `d954a41f` chore commit: `dart format` session residue cleaned (10 files)
- [ ] On-device + live Firestore: verified at integrated P2 (post-F1+F2).

---

## Wave-2 fix-agents (ALL LANDED — make ci GREEN)

### F1 — onReorder → onReorderItem migration (CI unblock) — **done** (swept into commit `06998374`)
- [x] 4 call sites migrated; manual `newIndex` adjustment removed to avoid double-correction

### F2 — `pushProfileProgram` interface + route + caller refactor — **done** (commits `06998374` + `b31914a4`)
- [x] `pushProfileProgram(payload)` added to `SyncWriteFacade` interface
- [x] Implemented in `OutboxSyncWriteFacade` (delegates to `enqueueProfileProgram`)
- [x] Routed in `TutoredWriteRouter` → `tutorSetProfileProgram` CF
- [x] `edit_track_screen.dart:328` + `TrackCreationService` callers refactored
- [x] Tests proving tutored→CF / non-tutored→delegate / 7-kind isolation; fake delegate updated in `s2_entity_parity_test.dart`
- [x] **`tutorSetProfileProgram` CF is now REACHABLE**

### F3 — Auth-watch root cause fix — **done** (commit `25e39be2`)
- [x] Moved `authStateProvider` watch from `ActiveTutoredProfileSelection.build` + `ResolvedTutoredLocalProfileId.build` to `AppShellScreen` `ref.listen`
- [x] Account-switch reset behaviour preserved + tested
- [x] **211 → 53 test failures**

### F4 — ListTile/Material wrapping fix — **done** (commit `ca3a038f`)
- [x] Wrapped ListTiles in `Material(color: transparent)` inside `_SurfaceCard`/`_SettingsGroupCard` and `ProfileSwitcherSheet` rows
- [x] **Real prod UI bug fixed** (ink splashes were invisible on device, not just in tests)
- [x] ~30+ widget test failures resolved

### F5 — Goal entity snake_case test assertion fix — **done** (commit `461e2284`)
- [x] Updated 3 toFirestore assertions in `goal_entity_test.dart` to snake_case (`goal_type`, `pace_value`, `pace_unit`, `target_date`)
- [x] Note: `pacePeriod` maps to `pace_unit` (S2's mapping was correct)

### F6 — Mop-up (tutored_pull_isolation + T5.lifecycle wipe + drift shader + profile_switcher_sheet_test + track_detail + epic_16) — **done** (commit `7c0850f3`)
- [x] **BONUS BUG FIX:** `wipeAllMirrors` was silently no-op after polish `7e5f6eb5` because `getProfilesByAccount` excludes mirrors — added `getTutoredMirrorsForAccount` DAO method + fixed `TutoredMirrorWipeService`. Data-isolation HIGH for V2.
- [x] Drift shader stale-cache deleted (`build/unit_test_assets/shaders/ink_sparkle.frag`) — root cause of ~48 widget failures (format version mismatch)
- [x] `profile_switcher_sheet_test` `authStateProvider` override added
- [x] `track_detail_screen` Material wrap
- [x] `epic_16_pace_dashboard_test` snake_case fix

### final `make ci` — **GREEN** (6062 passed / 125 skipped / 0 failed / EXIT=0) verified at `/tmp/edit-prop-makeci-5.log`

### S5 — Delta listeners + caching — pending
- [ ] On entry (after the initial pull) attach Firestore listeners scoped to the child's collections via the parent-scoped gateway
- [ ] Run changed docs through the existing per-entity mergers into the mirror (reuses `MergeRouter`)
- [ ] Reactive UI reflects deltas within seconds (both parent-side change and tutor's own CF write)
- [ ] Detach on exit / revoke / sign-out / wipe (no leak across talmidim or accounts — R4 critical)
- [ ] Cache persists between sessions (already built; verify listeners resync deltas on re-entry, no full re-pull)
- [ ] Tests: listener attach/detach lifecycle, merge into mirror, isolation across accounts

### S6 — Profile-less tutor wizard — **done** (P1 PASS)
- [x] Account with 0 own profiles but ≥1 active tutor grant lands on the profile picker — `sign_in_controller.dart` checks `listIncomingGrants()` (4 s timeout, offline-safe) when count==0; ≥1 active → `ProfilePickerRoute` + onboarding marked complete (commit `e5045281`)
- [x] Profile creation remains available but optional — picker shows Add Profile path; not forced
- [x] Tests: 6 `ProfileGuard` unit tests covering the four branches (tutored-session bypass / count==0 → picker / single-profile auto-select / valid-selection short-circuit)
- ⚠️ **LOW carried to V3:** new `SignInController` grant-check branch not directly unit-tested (only `ProfileGuard` is). Add a SignInController test if V3 budget allows.

---

## Sync points

- **P1** (Wave 1 gate) — **CLOSED 2026-05-28 10:30** — Router proven by 14 unit tests (S1 commit `f1861516`); profile-less tutor reaches picker via `sign_in_controller` grant-check + picker default routing (S6 commit `e5045281`). HIGH advisory bundled to S2: refactor `outboxSyncWriteFacadeProvider` direct readers.
- **P2 — WRITE CHECKPOINT** (Wave 2 gate) — pending — Functions deployed; on device a tutor edit (track + enrolment, reward, profile) lands in the parent's Firestore (live query) AND shows on the parent's app. **Daniel sanity-checks before Wave 3.**
- **P3** (Wave 3 gate) — pending — Delta listeners reflect parent-side + own CF writes in the talmid view live; cache persists between sessions; detaches on exit/wipe.

---

## Verification phase (after P3, sequential)

- **V1** — CI gate (`make ci` + `npm run build`/lint in `functions/`) — pending
- **V2** — Adversarial review squad (R1 isolation · R2 serialization · R3 permissions · R4 listeners/lifecycle) — pending
- **V3** — Fix-all (one fix-agent per CRITICAL/HIGH; batch MEDIUM; log LOW) — pending
- **V4** — Re-run CI (loop) — pending
- **V5** — Task-truth verification (sample every `done`; confirm a real tutor action lands in the parent's Firestore for each edit type) — pending
- **V6** — Final smoke (tutor edit charter flow on device + live Firestore: enter talmid → add track w/ enrolment → edits → parent-side delta visible → cannot live-mark → exit → parent revokes → mirror wiped) — pending

---

## Done definition
- ☑ Every stream task = `verified` (a real tutor edit lands in the parent's namespace, not just code present)
- ☑ Full parity: basic + program-enrolment track creation, goals, study-days, stages, rewards/points, profile edit, completion reset all propagate
- ☑ Delta listeners reflect changes live; cache persists; detaches on exit/wipe
- ☑ Tutored writes never pollute the tutor's own cloud; non-tutored writes unchanged
- ☑ Profile-less tutor reaches the picker, not the wizard
- ☑ Functions deployed; `make ci` green; V2 zero CRITICAL / zero unaddressed HIGH on the final round
