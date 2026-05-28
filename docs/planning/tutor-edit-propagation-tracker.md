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

### S2 — Existing-entity wiring — pending
- [ ] Route `pushTrack` / `deleteTrack` → `tutorUpsertTrack` / `tutorDeleteTrack` (`can_edit_stages`)
- [ ] Route `pushStageDefinitions` → `tutorUpsertStageDefinition` (`can_edit_stages`)
- [ ] Route `pushGoal` / `deleteGoal` → `tutorUpsertGoal` / `tutorDeleteGoal` (`can_edit_goals`) — **goal payload normalized to snake_case** (R2 critical)
- [ ] Route `pushStudyDayConfig` / `deleteStudyDayConfig` → `tutorUpsertStudyDayConfig` / `tutorDeleteStudyDayConfig` (`can_edit_study_days`)
- [ ] Verify serializer field names + doc-id conventions match merger expectations end-to-end (R2 parity check per entity)
- [ ] On-device + live Firestore: tutor adds basic track → track + stages + goal + study-days appear in the parent's namespace

### S3 — Parity CFs (program enrolment) — pending
- [ ] **NEW CF** `tutorUpsertBookmark` → `users/{uid}/learner_profiles/{pid}/bookmarks/{id}` (`can_edit_stages`)
- [ ] **NEW CF** `tutorSetProfileProgram` → `users/{uid}/learner_profiles/{pid}/profile_program/{id}` (`can_edit_stages`)
- [ ] **NEW CF** `tutorUpsertCurriculumScope` → `users/{uid}/learner_profiles/{pid}/curriculum_scopes/{id}` (`can_edit_stages`)
- [ ] Verify `point_configs` propagate via existing gamification snapshot CF (else add a parity CF) — confirm before building
- [ ] Add `TutorWriteService` methods for each parity CF; route their pushes through the router
- [ ] CF tests: auth → active-tutor-verify → permission → write → audit (pattern mirrors `tutorUpsertTrack`)
- [ ] End-to-end: tutor creates a track **with program enrolment** → bookmark + profile_program + curriculum_scope + point_configs all land in the parent's namespace

### S4 — Other edits + UI gating — pending
- [ ] Route gamification (rewards + points, with `permKey` split = `can_edit_rewards` vs `can_edit_points`) → `tutorUpdateGamificationSettings`
- [ ] Route profile edit (display_name / avatar / mode) → `tutorEditProfile`
- [ ] Route completion reset → `tutorResetCompletion` (`can_reset_completion`)
- [ ] Pre-gate each edit affordance in the talmid view on the active grant's `canEdit*` flag (CF denies too, defense in depth)
- [ ] Un-permitted affordances hidden; permission-denied surfaces a clear snackbar (never silently strand)
- [ ] Tests: per-permission UI gating + per-permission CF denial
- [ ] On-device + live Firestore: tutor edits a reward / points / profile / reset → lands in parent namespace; restricted grant → blocked

### S5 — Delta listeners + caching — pending
- [ ] On entry (after the initial pull) attach Firestore listeners scoped to the child's collections via the parent-scoped gateway
- [ ] Run changed docs through the existing per-entity mergers into the mirror (reuses `MergeRouter`)
- [ ] Reactive UI reflects deltas within seconds (both parent-side change and tutor's own CF write)
- [ ] Detach on exit / revoke / sign-out / wipe (no leak across talmidim or accounts — R4 critical)
- [ ] Cache persists between sessions (already built; verify listeners resync deltas on re-entry, no full re-pull)
- [ ] Tests: listener attach/detach lifecycle, merge into mirror, isolation across accounts

### S6 — Profile-less tutor wizard — pending
- [ ] Account with 0 own profiles but ≥1 tutor grant lands on the profile picker (TALMID PROFILES section visible) instead of the Create-Profile wizard
- [ ] Profile creation remains available but optional (act as a pure tutor)
- [ ] Tests: profile-less account routing (`ProfileGuard` + picker behaviour)

---

## Sync points

- **P1** (Wave 1 gate) — pending — Router proven by unit test (tutored → CF, non-tutored → outbox); both facade chokepoints wired. S6: profile-less account reaches the picker. **Unblocks S2/S3/S4.**
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
