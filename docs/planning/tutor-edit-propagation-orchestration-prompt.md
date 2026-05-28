# Orchestration Kickoff Prompt — Tutor Edit Propagation (2026-05-28)

> Paste the body of this file as the first message to a fresh Claude Code session (orchestrator = **Opus**). The agent reading it becomes **the Edit-Propagation Orchestrator** and makes tutor edits actually reach the child's Firebase — end-to-end via a parallel **Sonnet** sub-agent squad — then adversarial-review-and-fix until `make ci` is green and a tutor edit verifiably lands in the parent's namespace, without doing code work itself.

---

## 🎯 Goal (one line)

**Make a tutor's permitted edits write to the child's Firebase in real time via the existing tutor Cloud Functions (the parent's device then syncs them), with the tutor's own view reflecting changes immediately through delta listeners on the cached mirror — across all editable features and the full program-enrolment path — via phased parallel Sonnet streams, then review and task-truth-verify until `make ci` is green and a tutor track-edit is confirmed in the parent's Firestore, without writing code yourself.**

---

## Your role

You are the **Edit-Propagation Orchestrator** for the Learning Tracker codebase. You run a **named Sonnet squad team**: you **do not write code, edit source files, run build_runner, deploy functions, or modify implementation** — you **delegate to teammates**. Your direct actions are limited to:

- **Creating** the squad team (`TeamCreate`) and **spawning** each stream as a **named Sonnet teammate** (`Agent` with `model: "sonnet"`, `team_name: "<your squad>"`, stable `name:` like `"S1-routing"`).
- **Coordinating** teammates by name via `SendMessage`.
- **Reading** files (parse plan, verify completion, inspect git/Firebase state).
- **Maintaining** the log + tracker (`Write`/`Edit` on those two files only).
- **Tracking** via `TaskCreate`/`TaskUpdate`.
- **Limited** `Bash` to inspect git/grep/Firebase/device state (never to mutate code).

Run the whole effort as **one persistent squad team** — spawn teammates into it, address them by name, reuse the same teammate across its stream's tasks. Every teammate is **Sonnet**. If you're about to `Edit`/`Write` a source file, **stop and dispatch a teammate.**

---

## Source documents (read these first, in order)

| Path | Purpose |
|---|---|
| `docs/planning/tutor-edit-propagation-plan.md` | **The canonical plan.** Architecture (Option 2 + delta listeners), the push-facade keystone, entity→serializer→CF map, full-parity CFs, phases, risks. |
| `docs/planning/tutor-talmid-view-plan-2026-05-26.md` | Background: the talmid-view design this extends (synthetic profile, tutored pull, mergers, gating). |
| `docs/planning/tutor-talmid-view-log.md` | What the prior squad built + the P2 pivot to full parent-equivalent edits. |
| `docs/product-rules.md` + `docs/hebrew-terms.md` | Canonical product rules (no track types, chazara conditional, Hebrew-terms boundary, offline-first). |
| `learning_tracker/CLAUDE.md` | Layering rules + the 5 non-negotiable invariants (DNI-386/387). |
| `MEMORY.md` (auto-memory) | Durable owner rules — esp. `[[pre-launch-no-live-users]]`, `[[incremental-over-rewrites]]`, `[[minimal-scope]]`, `[[fix-dont-defer]]`, `[[offline-first]]`, `[[no-feature-branches]]`, `[[code-is-source-of-truth]]`, `[[listen-before-troubleshoot]]`, `[[tutor-parent-view]]`, `[[profile-switcher-top]]`, `[[firestore-rules-deploy]]`. |

---

## Current state — what works, what's broken (verify, don't redo)

The talmid-view foundation is **live on `dev`** (verify by reading, don't rebuild):

**Working (this session, on device):**
- Tutor enters a talmid → lands in the talmid's full app with bottom-nav tabs; loading spinner on entry.
- Mirror pull works; the tutored pull gate now requires a live **Firebase session** (not `authState.isCloudBorn`) — see `lib/core/sync/providers/tutored_pull_providers.dart`.
- `ProfileGuard` is tutored-aware; profile switcher sheet has ACCOUNT + Profiles + TALMID PROFILES; own-profile queries exclude `isTutored` mirrors; tutoring state resets on account switch (keyed on firebase uid).

**Broken — the reason this effort exists:**
- **Tutor edits do NOT reach the child.** Confirmed via live Firestore: a tutor-created track is absent from `users/{parentUid}/learner_profiles/{pid}/curriculum_tracks`. Root cause: the 10 tutor CFs (`tutorUpsertTrack`, …) and `TutorWriteService` **exist but have ZERO call sites** (`lib/features/tutoring/data/services/tutor_write_service.dart`). Every edit writes to local Drift (the mirror); the outbox `isTutoredProfile` guard then blocks sync → edits are stranded in the mirror.
- **Profile-less tutor forced into the Create-Profile wizard** — an account with 0 own profiles (only the mirror) drops into profile creation instead of acting as a pure tutor.

**Confirm before dispatching:** read `tutor_write_service.dart` (CF signatures), the entity→serializer→CF map in the plan, and grep for zero call sites of the tutor CFs.

---

## Decisions — ALL RESOLVED with the owner (build to these, don't re-litigate)

- **D1 — Writes via Cloud Functions, real-time.** Permitted tutor edits route through the tutor CFs (Admin SDK, server-side permission + 12-month audit) to `users/{parentUid}/learner_profiles/{profileId}/…`. The parent's device picks them up via normal sync. (NOT client-direct writes to the parent namespace — rules stay read-only for tutors; CF-only.)
- **D2 — Reads stay on the local mirror** so existing Drift-based screens are reused unchanged. Refresh via **Firestore delta listeners** scoped to the child during the session (stream only changed docs).
- **D3 — Keep the cached mirror between sessions**; listeners resync deltas on entry; wipe only on revoke/resign/sign-out (already built).
- **D4 — Keystone: intercept at the push/facade layer.** Route `pushX/deleteX` to the matching CF when `activeTutoredProfileSelectionProvider != null`; controllers stay untouched; reuse existing serializers + doc-id conventions verbatim (they already match CF + parent-side merger shapes).
- **D5 — Full parity.** The program-enrolment path (bookmark, profile_program, curriculum_scope, seeded point_configs) gets new tutor CFs so tutor track-creation propagates completely — no scoped-out edits.
- **D6 — Live forward completion remains barred** in the talmid view regardless of permissions (unchanged from talmid-view D5).

---

## Operating principles (non-negotiable)

- **Pre-launch — no live users.** Schema/Drift/Firestore resets fine; no migration shims/backwards-compat.
- **All work on `dev`.** No feature branches, no worktrees.
- **Incremental under a test net.** Each task = a small commit on `dev` with a regression test.
- **Minimal & proportionate.** Build what the plan names; no opportunistic refactors.
- **Fix in-run, don't defer.**
- **Data isolation is paramount.** Tutored writes go ONLY to the CFs (parent namespace); they must NEVER enter the tutor's own outbox, and non-tutored writes must keep using the outbox unchanged. #1 risk — demand tests.
- **Serialization parity.** CF payloads must match the field names/doc-ids the parent-side mergers read (normalize goal payloads to snake_case). A mismatch silently corrupts the parent's data.
- **Cloud Functions must be deployed** (`firebase deploy --only functions` from `learning_tracker/`) for on-device testing — CI's fake backend does not run them. Treat deploy as a live-backend action: a teammate runs it only at the verification gate, logged.

---

## Outputs you maintain

| File | Format | Lifecycle |
|---|---|---|
| `docs/planning/tutor-edit-propagation-log.md` | Append-only, timestamped | Every dispatch, sync-point, return, finding, fix, verification |
| `docs/planning/tutor-edit-propagation-tracker.md` | Checklist mirroring the streams | Each task: `pending` / `in-progress` / `done` / `verified` |

**Log entry:** `## [YYYY-MM-DD HH:MM] <event-type>` + `stream/sync/review`, `detail`, `next`.

---

## The streams

| Stream | Scope | Key acceptance |
|---|---|---|
| **S1 — Routing foundation (keystone)** | `tutorWriteServiceProvider`; a `TutoredWriteRouter` mapping `(kind, serialized map, docId)` → the matching CF using `grantId/ownerUid/profileId` from `activeTutoredProfileSelectionProvider`; wire BOTH facade chokepoints (`OutboxSyncWriteFacade` + `SyncEngine` push/delete) to consult it. Non-tutored path unchanged. | In a tutored session, a `pushTrack` call invokes `tutorUpsertTrack` (fake invoker test) instead of enqueuing the outbox; non-tutored still enqueues. |
| **S2 — Existing-entity wiring** | Route track / stage-definition / goal / study-day-config push+delete through S1's router to `tutorUpsertTrack`/`tutorDeleteTrack`/`tutorUpsertStageDefinition`/`tutorUpsertGoal`/`tutorDeleteGoal`/`tutorUpsertStudyDayConfig`/`tutorDeleteStudyDayConfig`. Goal payload snake_case. | Tutor adds a basic track → track+stages+goal+study-days appear in the parent's Firestore (live query). |
| **S3 — Parity CFs (program enrolment)** | NEW CFs `tutorUpsertBookmark`, `tutorSetProfileProgram`, `tutorUpsertCurriculumScope` (pattern: auth → active-tutor verify → `can_edit_stages` → write parent namespace → audit). Confirm point_configs propagate via the gamification snapshot; add a CF only if not. Add matching `TutorWriteService` methods + route their pushes. | Tutor creates a track **with program enrolment** → bookmark/profile_program/scope/point_configs all land in the parent's namespace. |
| **S4 — Other edits + UI gating** | Route gamification (rewards+points, `permKey` split) → `tutorUpdateGamificationSettings`; profile edit → `tutorEditProfile`; completion reset → `tutorResetCompletion`. Pre-gate each edit affordance on the active grant's `canEdit*` (CF denies too). | Tutor edits a reward/points/profile/reset → lands in parent namespace; un-permitted affordances hidden + server-denied. |
| **S5 — Delta listeners + caching** | On entry (after initial pull) attach Firestore listeners scoped to the child's collections via the parent-scoped gateway → run existing mergers into the mirror → reactive UI; detach on exit/wipe; keep cross-session cache. | A change in the parent's namespace (or the tutor's own CF write) appears in the talmid view within ~seconds without a full re-pull. |
| **S6 — Profile-less tutor wizard** | An account with 0 own profiles but ≥1 tutor grant lands on the profile picker (TALMID PROFILES) instead of the Create-Profile wizard; profile creation optional. | Signing into a profile-less tutor account shows the picker with the talmid, not the wizard. |

---

## Wave sequencing & sync protocol

Dispatch in waves. **Do not start a wave until every task in the prior wave is verified (read the diff + a device/Firestore trace, not the self-report).**

| Wave | Streams (parallel) | Sync gate |
|---|---|---|
| **Wave 1** | **S1** (+ S6 in parallel — independent) | **P1** — router proven by unit test (tutored→CF, non-tutored→outbox); both facade chokepoints wired. S6: profile-less account reaches the picker. Unblocks S2/S3/S4. |
| **Wave 2** | **S2 + S3 + S4** | **P2 — WRITE CHECKPOINT.** Deploy functions; on device a tutor track-edit (basic + enrolment) + a reward/profile edit land in the parent's Firestore (live query) and show on the parent's app. **Daniel sanity-checks.** |
| **Wave 3** | **S5** | **P3** — delta listeners reflect parent-side + own CF writes in the talmid view live; cache persists between sessions; detaches on exit/wipe. |

Spawn each wave's streams in a single message, one `Agent` per stream (`model: "sonnet"`, `subagent_type: "general-purpose"`, `team_name`, stable `name`), briefed from Appendix A. After dispatch, **sit in receive-mode — do not poll**; teammates report at their gate. Continue a teammate's next task by messaging it (preserves context).

---

## Verification phase (after P3) — sequential

### V1 · CI gate
One agent runs `make ci` from `learning_tracker/` (+ `npm run build`/lint in `functions/`). Red → one fix-agent per failure category, re-run, loop until green.

### V2 · Adversarial review squad (parallel, scope-split)
- **R1 — Data isolation (CRITICAL):** tutored writes go ONLY to CFs (never the tutor's own outbox); non-tutored writes unchanged; no cross-account leak.
- **R2 — Serialization parity (CRITICAL):** every CF payload's field names + doc-id match what the parent-side merger reads; goal snake_case; LWW timestamps present; no field dropped/renamed.
- **R3 — Permissions/rules/CF auth:** each CF verifies grant + `hasActiveTutorAccess` + the right `canEdit*`; UI pre-gating matches; new parity CFs gated correctly; audit entries written.
- **R4 — Listeners + lifecycle + cross-cutting:** listeners detach on exit/wipe (no leak across talmidim/accounts); offline behavior sane; layering invariants; Hebrew-terms; EN+HE.

Each returns CRITICAL/HIGH/MEDIUM/LOW with `file:line`. No fixing.

### V3 · Fix-all — one fix-agent per CRITICAL/HIGH; batch MEDIUM; log LOW.

### V4 · Re-run CI (loop if needed).

### V5 · Task-truth verification ⚠️ **do not skip**
The exact failure mode that created this effort (CFs were "built but never called"). Sample every `done` task; confirm the artifact exists AND is **reachable + effective** — for each edit type, a real tutor action lands in the parent's Firestore (live query), not just a CF that exists. Upgrade `done`→`verified`; demote + re-dispatch otherwise. Loop, then re-run V4.

### V6 · Final smoke — the tutor edit charter flow (device + live Firestore)
Tutor enters talmid → **adds a track (with enrolment)** → confirm in the parent's Firestore AND on the parent's device → **edits points/rewards + renames the profile** → confirm in parent namespace → **a parent-side change appears in the talmid view via the listener** → **still cannot live-mark** → exits → parent revokes → mirror wiped. Spot-check EN+HE; offline edit queues/surfaces sanely. Append the smoke report.

---

## Done definition
- ☑ Every stream task = `verified` (a real tutor edit lands in the parent's namespace, not just code present).
- ☑ Full parity: basic + program-enrolment track creation, goals, study-days, stages, rewards/points, profile edit, completion reset all propagate.
- ☑ Delta listeners reflect changes live; cache persists; detaches on exit/wipe.
- ☑ Tutored writes never pollute the tutor's own cloud; non-tutored writes unchanged.
- ☑ Profile-less tutor reaches the picker, not the wizard.
- ☑ Functions deployed; `make ci` green; V2 zero CRITICAL / zero unaddressed HIGH on the final round.

When all hold, write `# Edit-Propagation complete — <timestamp>` and report to Daniel.

---

## Hard rules
- ❌ **No code work by you.** Tempted to `Edit` a `.dart`/`.ts`/rules file → dispatch. `Write` only the log + tracker.
- ✅ **Sub-agents use Sonnet.**
- ✅ **Stay on `dev`.** No feature branches/force-push/--no-verify. Hook fails → fix root cause.
- ✅ **Build to D1–D6** — don't re-open them.
- ✅ **Deploy functions** at the gate (live action, logged); verify writes on a live device + live Firestore (fake backend hides this).
- ✅ **Don't skip V5 (task-truth) or the P2 write checkpoint.** "CF exists" ≠ "edit reaches the child."
- ❌ **No silent skipping.** Unresolvable blocker → escalate with context + options + recommendation.

---

## Escalation protocol
Escalate to Daniel (log + chat: question + options + recommendation) when: a serializer has no clean reuse path and a parity mismatch is unavoidable; the two facade chokepoints can't be unified without a larger refactor; a parity CF needs a Firestore-rules change with security implications; a smoke surfaces a real regression; or an external system fails (Firebase deploy/quota/Functions). Everything else: decide, proceed, log.

---

## Communication style with Daniel
Wave-level summary first, under 200 words; capture any new bug/rule he surfaces (memory + `docs/product-rules.md`), fold in if cheap, don't argue scope. Rule conflicts with implementation → the rule wins.

---

## Appendix A · Stream briefing template

```
You are Stream **S<n>** of the Edit-Propagation Squad for the Learning Tracker codebase.

**Model:** Sonnet
**Coordinator:** the Edit-Propagation Orchestrator — report via SendMessage at your sync gate.

## Your scope
[Paste the S<n> row + the relevant section of docs/planning/tutor-edit-propagation-plan.md — the entity→serializer→CF map, the keystone, and decisions D1–D6.]

## Read first
- `docs/planning/tutor-edit-propagation-plan.md` (your section + the entity map + keystone)
- `lib/features/tutoring/data/services/tutor_write_service.dart` (CF signatures)
- `docs/product-rules.md`, `docs/hebrew-terms.md`, `learning_tracker/CLAUDE.md`
- the edit-propagation log (append your start entry) + tracker (your tasks)

## Foundation already in place (reuse, don't redo)
- 10 tutor CFs + TutorWriteService exist (unwired). Mirror pull, mergers, serializers (TrackCodec/StageDefinitionCodec/GoalEntity.toFirestore/StudyDayConfigCodec/pushGamificationSettingsSnapshot/_toFirestorePayload) all exist and match merger shapes.
- Tutored pull gate requires a live Firebase session; ProfileGuard is tutored-aware; tutoring state resets on account switch.

## Behaviour
- Execute in dependency order; each task = a small commit on `dev` with a regression test.
- Build to D1–D6 (writes via CF; reads via mirror+listeners; cache; keystone facade routing; full parity; live-mark barred).
- DATA ISOLATION + SERIALIZATION PARITY FIRST: tutored writes go only to CFs; payloads match merger field names/doc-ids. Add tests proving both.
- Offline-first; respect product-rules + hebrew-terms + layering invariants (DNI-386/387).
- At your sync gate: STOP, send a one-line status, wait for `proceed`.

## Hard rules
- Stay on `dev`; no feature branches/force-push/--no-verify. Minimal scope. No deferred TODOs.
- Functions/rules changes are verified by the Orchestrator's deploy gate — note any deploy dependency.
- Genuine blocker → report to the Orchestrator with context.

Begin.
```

## Appendix B · Verification / fix templates

```
[V1 CI] Run `make ci` from learning_tracker/ (+ functions lint/build); return pass/fail + failures with file:line.
[V2 reviewer] Adversarially review your slice (R1–R4) against the plan + product-rules; CRITICAL/HIGH/MEDIUM/LOW + file:line. No fixing.
[V5 task-truth] Sample your `done` tasks; for each edit type prove a real tutor action lands in the parent's Firestore (live query); per-task verdict + demotions. No fixing.
[V6 smoke] Run the tutor edit charter flow end-to-end on device + live Firestore; per-step verdict + regression list.
[V3 fix-agent] Apply ONE finding's fix on `dev` (small commit + regression test); no scope creep; log it.
```

---

## Kickoff
1. Read all source documents; confirm the plan is unchanged and the foundation (CFs unwired, serializers/mergers present) matches.
2. **Create the Sonnet squad team** via `TeamCreate` (e.g. `tutor-edit-squad`).
3. Create the log + tracker; pre-populate from the streams.
4. Create high-level tasks via `TaskCreate`: one per stream (S1–S6), one per sync point (P1–P3), plus `Adversarial review`, `Task-truth`, `Final smoke`.
5. Acknowledge the wave plan to Daniel (under 200 words), flagging the P2 write checkpoint (functions deploy + on-device confirmation) where he sanity-checks.
6. Dispatch **Wave 1 (S1 + S6)** as two named Sonnet teammates in a single message.
7. Sit in receive-mode, awaiting P1.

🪙 **You don't touch the code. The squad delivers. You verify a tutor's edit actually reaches the child's Firebase — isolated, serialization-faithful, and permission-gated.**
