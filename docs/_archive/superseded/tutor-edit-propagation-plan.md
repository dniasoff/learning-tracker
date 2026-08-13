> **ARCHIVED 2026-08-13 — superseded.** Superseded by `docs/firestore-rewrite-map.md`. Retained for history only; do not treat as current. See `docs/planning/firestore-finish-line-plan.md` for the live plan.

# Tutor Edit Propagation — Implementation Plan (2026-05-28)

## Objective
Make tutor edits write to the child's Firebase in real time (via the existing
tutor Cloud Functions), have the parent's device pick them up through normal
sync, and have the tutor's own view reflect the change immediately — without
rewriting the Drift-based read layer.

Execution mode: **single shot** — build all phases + full parity in one pass,
validate comprehensively at the end (analyze, build, deploy CFs, device test +
live-Firestore confirmation).

## Architecture (Option 2 + delta listeners)
- **Writes** → Cloud Functions (Admin SDK, server-side permission checks +
  12-month audit). Real-time to `users/{parentUid}/learner_profiles/{profileId}/…`.
- **Reads** → keep the local mirror so existing screens work unchanged; refresh
  via Firestore **delta listeners** scoped to the child during the session
  (streams only changed docs).
- **Caching** → keep the cached mirror between sessions; listeners resync deltas
  on entry. Wiped only on revoke/resign/sign-out (already built).

## Keystone: intercept at the push/facade layer
Every edit controller already does "write local Drift → call a push method"
(`syncWriteFacade.pushX()` / `syncEngine.pushX()` / `deleteX()`). Instead of
branching each controller, route the push/delete calls to the matching
`TutorWriteService` CF when `activeTutoredProfileSelectionProvider != null`. The
local Drift write still happens (instant mirror reflection); the CF write
propagates to the parent. Existing serializers and doc-id conventions are reused
verbatim (they already match CF + parent-side merger expectations). The outbox
`isTutoredProfile` guard remains the safety net.

## Entity → serializer → CF map
| Entity | Serializer | Doc-id | Collection | CF | Permission |
|---|---|---|---|---|---|
| Track | `TrackCodec.encode` | curriculumId | curriculum_tracks | tutorUpsertTrack / tutorDeleteTrack | can_edit_stages |
| Stage def | `StageDefinitionCodec.encode` | {trackId}_{stageOrder} | stage_definitions | tutorUpsertStageDefinition | can_edit_stages |
| Goal | `GoalEntity.toFirestore` (+id) | goalId | goals | tutorUpsertGoal / tutorDeleteGoal | can_edit_goals |
| Study day | `StudyDayConfigCodec.encode` | {curr}_{dow}_{track} | study_day_configs | tutorUpsertStudyDayConfig / tutorDeleteStudyDayConfig | can_edit_study_days |
| Gamification | `pushGamificationSettingsSnapshot` | gamification_settings | preferences | tutorUpdateGamificationSettings | can_edit_rewards / can_edit_points |
| Profile | `_toFirestorePayload` | profileId | learner_profiles | tutorEditProfile | (parent-equivalent) |
| Completion reset | — | — | completions | tutorResetCompletion | can_reset_completion |

## Full parity — NEW Cloud Functions (program enrolment path)
Track creation with program enrolment also writes: bookmark, profile_program,
curriculum_scope, and seeds point_configs. For complete parity add:
- `tutorUpsertBookmark` → users/{uid}/learner_profiles/{pid}/bookmarks/{id}
- `tutorSetProfileProgram` → users/{uid}/learner_profiles/{pid}/profile_program/{id}
- `tutorUpsertCurriculumScope` → users/{uid}/learner_profiles/{pid}/curriculum_scopes/{id}
- point_configs propagate via the gamification snapshot (verify) — add a dedicated
  CF only if they do not.
Each mirrors the existing tutor CF pattern: auth → active-tutor verify →
per-permission check (`can_edit_stages` for enrolment-related writes) → write to
parent namespace → audit-log entry.

## Phases
- **Phase 0 — Routing foundation:** `tutorWriteServiceProvider`,
  `TutoredWriteRouter` (kind + serialized map + docId → CF call), wire
  `OutboxSyncWriteFacade` + `SyncEngine` push/delete to consult it.
- **Phase 1 — Tracks slice:** route track/stage/goal/study-day pushes; validate.
- **Phase 1b — Parity CFs:** bookmark / profile_program / curriculum_scope (+
  point_configs); route their pushes; full track-create propagates.
- **Phase 2 — Other edits:** rewards/points, profile edit, completion reset.
  Pre-gate UI affordances on the active grant's `canEdit*`.
- **Phase 3 — Delta listeners:** scoped Firestore listeners → mergers → mirror;
  attach on entry, detach on exit; keep cross-session cache.
- **Phase 4 — Profile-less tutor wizard:** account with 0 own profiles but ≥1
  tutor grant lands on the picker (TALMID PROFILES), not the create wizard.

## Cross-cutting
- Error/UX: permission-denied / offline → clear snackbar; never silently strand.
- Goal payloads normalized to snake_case for merger safety.
- Tests: router kind→CF mapping + payloads (fake invoker); non-tutored writes
  still use the outbox; per-permission denial.
- Verify: `make analyze` clean; `make ci`; deploy functions; device validation +
  live-Firestore confirmation that edits land in the parent namespace.

## Risks
- Two facade entry points (`OutboxSyncWriteFacade` + `SyncEngine`) — both must
  consult the router or be unified at one chokepoint.
- Conflict semantics resolve via existing LWW (`updated_at`/`state_changed_at`).
- CF deploy is a live-backend action — required for on-device testing.
