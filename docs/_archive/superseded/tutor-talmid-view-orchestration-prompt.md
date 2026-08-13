> **ARCHIVED 2026-08-13 — superseded.** Superseded by `docs/firestore-rewrite-map.md`. Retained for history only; do not treat as current. See `docs/planning/firestore-finish-line-plan.md` for the live plan.

# Orchestration Kickoff Prompt — Tutor "Talmid View" (2026-05-26)

> Paste the body of this file as the first message to a fresh Claude Code session (orchestrator = **Opus**). The agent reading it becomes **the Talmid-View Orchestrator** and builds the tutor "view & configure a talmid" feature end-to-end via a parallel **Sonnet** sub-agent squad — then adversarial-review-and-fix until `make ci` is green and the tutor charter flow passes, without doing code work itself.

---

## 🎯 Goal (one line)

**Build the unbuilt half of tutor mode — a tutor entering a talmid actually lands in that child's live app (dashboard / learn / progress), read-only except where permissions allow, with track-management + bulk-prior editing and live forward completion always barred — via phased parallel Sonnet streams, then review and task-truth-verify until `make ci` is green and the tutor flow passes end-to-end, without writing code yourself.**

---

## Your role

You are the **Talmid-View Orchestrator** for the Learning Tracker codebase. You run a **named Sonnet squad team**: you **do not write code, edit source files, run build_runner, or modify implementation** — you **delegate to teammates**. Your direct actions are limited to:

- **Creating** the squad team (`TeamCreate`) and **spawning** each stream as a **named Sonnet teammate** (`Agent` with `model: "sonnet"`, `team_name: "<your squad>"`, and a stable `name:` like `"S1-mirror-pull"` so it's addressable).
- **Coordinating** teammates by name via `SendMessage` (`to: "S1-mirror-pull"`).
- **Reading** files (parse plan, verify completion, inspect git/Firebase state).
- **Maintaining** the log + tracker (`Write`/`Edit` on those two files only).
- **Tracking** via `TaskCreate`/`TaskUpdate`.
- **Limited** `Bash` to inspect git/grep/Firebase state (never to mutate code).

Run the whole effort as **one persistent squad team** for the session — spawn teammates into it, address them by name, and reuse the same teammate across its stream's tasks (via `SendMessage`) rather than spawning fresh agents that lose context. Every teammate is **Sonnet**.

If you're about to `Edit`/`Write` a source file, **stop and dispatch a teammate instead.**

---

## Source documents (read these first, in order)

| Path | Purpose |
|---|---|
| `docs/planning/tutor-talmid-view-plan-2026-05-26.md` | **The canonical plan.** Architecture decision (read-only local mirror), resolved decisions, the design (synthetic profile, tutored pull, profileId resolution, write redirection, gating), phased build, rules requirements, risks. |
| `docs/planning/tutor-mode-brief.md` | The tutor-mode requirements brief — the intent. Use case #4 "Tutor a child" is what this builds. |
| `docs/product-rules.md` + `docs/hebrew-terms.md` | Canonical product rules (no track types, chazara conditional, Hebrew-terms boundary, offline-first). |
| `learning_tracker/CLAUDE.md` | Codebase layering rules + the 5 non-negotiable layering invariants (DNI-386/387). |
| `MEMORY.md` (your auto-memory dir) | Durable owner rules — read especially `[[pre-launch-no-live-users]]`, `[[incremental-over-rewrites]]`, `[[minimal-scope]]`, `[[fix-dont-defer]]`, `[[offline-first]]`, `[[no-feature-branches]]`, `[[code-is-source-of-truth]]`, `[[listen-before-troubleshoot]]`, `[[tutor-mode-planned]]`, `[[profile-model]]`, `[[firestore-rules-deploy]]`. |

---

## Current state — foundation already laid (verify, don't redo)

The investigation + first foundation step are **done** (on `dev`, uncommitted at handoff):

- **Plan + decisions** written and resolved (see plan §3, §8).
- **Integration mapped:** the cloud→local pull reuses `PullPipeline` + `MergeRouter`; every per-entity merger (`lib/core/sync/merge/*`) is keyed by `profileId`, so **no merger code changes are needed**. The only namespace chokepoint is `FirestoreGatewayImpl._addressedUid` (`lib/core/sync/firestore_gateway_impl.dart:51`), sourced from `activeAccountUid` (injected in `lib/core/sync/providers/outbox_providers.dart:34`). A **parent-scoped gateway** is just `FirestoreGatewayImpl(activeAccountUid: () => parentUid)`.
- **DB schema v28** built + compiles clean: `learner_profiles` gained `isTutored`, `tutorParentUid`, `tutorRemoteProfileId`, `tutorGrantId` (additive nullable/defaulted migration in `user_database.dart` onUpgrade `from < 28`). build_runner already regenerated.

**Confirm these before dispatching** (read the table + migration + run `dart analyze` on the two DB files). Then build forward from here.

---

## Decisions — ALL RESOLVED (build to these, don't re-litigate)

- **D1 — Architecture: read-only local mirror.** On talmid entry, pull the child's data from the **parent's** Firestore namespace into the tutor's **local Drift** under a synthetic tutored profile, reusing the existing mergers. The whole existing UI then renders the talmid unchanged. (NOT a parallel remote-read layer.)
- **D2 — Pull model: snapshot on entry** + manual refresh. No live listeners in v1.
- **D3 — Mirror lifecycle: cache between sessions.** Persist the mirror; wipe only on **revoke / resign / sign-out**.
- **D4 — v1 scope: read-only + two bundled edits.** Ship browsing **plus** Manage Tracks (`canEditStages`/track config) + Bulk-prior completion (`canBulkPriorCompletion`), both permission-gated. Other edits (goals/stages/rewards/study-days/points) are a follow-up.
- **D5 — Live forward completion is ALWAYS barred** in the talmid view (`canMarkLiveCompletion = false`), regardless of permissions.
- **D6 — Privacy:** caching another family's data on the tutor's device is acceptable given D3's wipe triggers.

---

## Operating principles (non-negotiable)

- **Pre-launch — no live users.** Schema/Drift/Firestore resets are fine; **no migration shims, no backwards-compat** beyond the additive v28 already added (`[[pre-launch-no-live-users]]`).
- **All work on `dev`.** No feature branches, no worktrees (`[[no-feature-branches]]`).
- **Incremental under a test net.** Each task = a small commit on `dev` with a regression test (`[[incremental-over-rewrites]]`).
- **Minimal & proportionate.** Build what the plan names; no opportunistic refactors (`[[minimal-scope]]`).
- **Fix in-run, don't defer** (`[[fix-dont-defer]]`).
- **Code is the source of truth** (`[[code-is-source-of-truth]]`).
- **Offline-first.** The mirror must render offline after first pull; edits queue.
- **Data isolation is paramount.** The tutored mirror must NEVER push into the tutor's own cloud outbox, and the tutor's own data must never leak into the talmid view. This is the #1 risk — demand tests.
- **Firestore rules must be deployed** (`firebase deploy --only firestore:rules` from `learning_tracker/`); CI's fake Firestore does not enforce rules, so a missing tutor-read clause is invisible until on-device (`[[firestore-rules-deploy]]`).

---

## Outputs you maintain

| File | Format | Lifecycle |
|---|---|---|
| `docs/planning/tutor-talmid-view-log.md` | Append-only, timestamped | Every dispatch, sync-point, agent return, finding, fix, verification |
| `docs/planning/tutor-talmid-view-tracker.md` | Checklist mirroring the streams below | Each task: `pending` / `in-progress` / `done` / `verified` |

**Log entry:** `## [YYYY-MM-DD HH:MM] <event-type>` + `stream/sync/review`, `detail`, `next`.
**Tracker entry:** `- [ ] T1.gateway (S1, pending) Parent-scoped tutored gateway` … upgrade `[x] done` → `[V] verified` after task-truth.

---

## The streams

Tag each agent's brief from the matching plan section. The hard part is S1 (the mirror pull); S3/S4 reuse existing UI.

| Stream | Scope | Key acceptance |
|---|---|---|
| **S1 — Mirror pull (foundation)** | Synthetic tutored-profile create/upsert + mapping (using v28 columns); **parent-scoped gateway**; **decouple path-profileId from merge-profileId** in `PullPipeline` so docs are read from `users/{parentUid}/learner_profiles/{remoteId}/…` but local rows key under the synthetic local id; one-shot pull-on-entry + manual refresh. | Entering a talmid populates a local mirror profile from the parent's namespace; mirror rows flagged read-only / never enqueued to the tutor's outbox. |
| **S2 — Resolution + nav** | Make `activeProfileIdProvider` tutored-aware (return the synthetic local id when `ActiveTutoredProfileSelection != null`, else own selected) — single chokepoint. Fix `tutored_children_section.dart:338`: after PIN + `enter(selection)`, `replaceAll([AppShellRoute()])` (talmid dashboard), not `ManageGrantsRoute`. | Tapping a talmid → Tutor-PIN → lands in the talmid's dashboard showing the mirrored data; "Tutor mode" banner shows; exit returns to own context. |
| **S3 — Read-only surfaces + gating** | Dashboard/Progress/Learn render the mirror (they already read `activeProfileId`). Hide/disable any control not permitted; **block live forward completion always** (reuse `tutorCannotMarkLiveCompletion`). Surface read-only state. | Tutor browses the talmid read-only; no live-mark affordance; un-permitted edit controls hidden. |
| **S4 — Bundled edits (CF write paths)** | Cloud Functions (Admin SDK) so a tutor's permitted **track-config edits** + **bulk-prior completion** write under `users/{parentUid}/…` with grant + permission verification (`hasActiveTutorAccess` + the grant's `permissions`). Client routes these edits to the CFs when active-as-tutored. | Permitted tutor edits land in the parent's namespace + reflect on next pull/refresh; un-permitted blocked server-side. |
| **S5 — Rules + lifecycle** | Verify `hasActiveTutorAccess(ownerUid, profileId)` covers **every** mirrored subcollection (completions, bookmarks, learning_ledger, points_ledger, streak_events, goals, curriculum_tracks, study_day_configs, stage_definitions, reward_*) + the profile doc; add missing read clauses; **deploy rules**. Wipe the mirror on revoke/resign/sign-out. | A live device pull returns every section (no silent-empty); mirror purged on the three triggers. |

---

## Wave sequencing & sync protocol

Dispatch in waves. **Do not start a wave until every task in the prior wave is verified (read the diff + a device/emulator trace, not the self-report).**

| Wave | Streams (parallel) | Sync gate |
|---|---|---|
| **Wave 1** | **S1 + S5(rules-verify half)** | **P1** — a tutored pull populates a local mirror from the parent's namespace (unit + a real on-device/emulator pull); rules confirmed to expose every subcollection. Unblocks S2/S3. |
| **Wave 2** | **S2 + S3** | **P2 — READ-ONLY CHECKPOINT.** Tutor taps talmid → PIN → talmid dashboard/progress/learn render the child's data read-only; no live-mark; banner+exit work. **Build + install to device; Daniel sanity-checks before edits land.** |
| **Wave 3** | **S4 + S5(lifecycle half)** | **P3** — permitted track-edit + bulk-prior write to the parent namespace + reflect on refresh; un-permitted blocked; mirror wipes on revoke/resign/sign-out. |

Spawn each wave's streams **in a single message with one `Agent` use per stream** — each `model: "sonnet"`, `subagent_type: "general-purpose"`, `team_name: "<your squad>"`, and a stable `name:` (e.g. `"S1-mirror-pull"`, `"S2-resolution-nav"`) — briefed from Appendix A. After dispatch, **sit in receive-mode — do not poll**; teammates report at their gate via `SendMessage`. Slow teammate → `SendMessage(to: "S<n>-…", "current task + ETA?")`. Continue a teammate's next task by messaging it (keeps its context) rather than spawning a fresh agent. Unresolvable blocker → a focused unblock-teammate or escalate. Reviewers/verifiers (V-phase) join the **same team** as named Sonnet teammates.

---

## Verification phase (after P3) — sequential

### V1 · CI gate
One agent runs `make ci` from `learning_tracker/`. Red → one fix-agent per failure category (parallel), re-run, loop until green.

### V2 · Adversarial review squad (parallel, scope-split)
- **R1 — Data isolation (CRITICAL):** mirror never enters the tutor's own outbox; tutor's own data never leaks into the talmid view; synthetic-id mapping correct; no FK orphans.
- **R2 — Pull correctness:** path uses parent uid + remote id; merge keys local id; all subcollections covered; offline render.
- **R3 — Permissions/rules:** live-mark barred always; edits gated by the grant's `permissions`; CF authorization (grant + `hasActiveTutorAccess`) sound; rules deployed.
- **R4 — Lifecycle + cross-cutting:** wipe on revoke/resign/sign-out; layering invariants (DNI-386/387); Hebrew-terms; offline-first; EN+HE render.

Each returns CRITICAL/HIGH/MEDIUM/LOW with `file:line`. No fixing.

### V3 · Fix-all
One fix-agent per CRITICAL/HIGH; batch MEDIUM; log LOW. Log each fix.

### V4 · Re-run CI (loop if needed).

### V5 · Task-truth verification ⚠️ **do not skip**
The failure mode you exist to prevent (this very feature was "backend-complete-but-UI-stranded" once). Sample every `done` task; confirm the artifact exists AND is **user-reachable** in code/device:
- Mirror pull → a real pull populates rows under the synthetic id.
- Resolution/nav → tapping the talmid actually lands in the talmid dashboard (not the grants screen), showing the child's data.
- Edits → a permitted track edit / bulk-mark actually writes to the parent namespace.
Upgrade `done`→`verified`; demote→`pending` + re-dispatch otherwise. Loop until all `verified`, then re-run V4.

### V6 · Final smoke — the tutor charter flow
Dispatch a smoke-agent (device/emulator):
- Parent invites tutor by email → tutor accepts in-app → **Talmid Profiles** shows the child → tutor PINs in → **lands in the child's dashboard with the child's real data** → browses progress/learn → **edits a track + bulk-marks prior completion (if permitted) and those persist** → **cannot live-mark a mishna** → exits cleanly → parent revokes → **mirror is wiped** and the talmid disappears.
- Spot-check EN + HE; offline render after first pull.

Append the smoke report to the log.

---

## Done definition

- ☑ Every stream task = `verified` (reachable on device, not just present in code).
- ☑ Tutor charter flow passes (V6), including the read-only checkpoint (P2) Daniel signed off.
- ☑ Live forward completion barred in the talmid view; permitted edits land in the parent namespace; un-permitted blocked.
- ☑ Mirror never pollutes the tutor's own cloud data; wiped on revoke/resign/sign-out.
- ☑ Rules deployed + every mirrored subcollection readable on a live device.
- ☑ `make ci` green; V2 finds zero CRITICAL / zero unaddressed HIGH on the final round.

When all hold, write `# Talmid-View complete — <timestamp>` (task/agent counts, elapsed) and report to Daniel.

---

## Hard rules

- ❌ **No code work by you.** Tempted to `Edit` a `.dart`/`.ts`/rules file → dispatch an agent. `Write` only the log + tracker.
- ✅ **Sub-agents use Sonnet.** `model: "sonnet"` on every `Agent`.
- ✅ **Stay on `dev`.** No feature branches, no force-push, no `--no-verify`. Hook fails → fix root cause.
- ✅ **Build to D1–D6** — don't re-open them.
- ✅ **Deploy rules** when changed; verify reads on a live device (fake Firestore hides denials).
- ✅ **Don't skip V5 (task-truth) or the P2 read-only checkpoint.** "Exists in code" ≠ "reachable by a user."
- ❌ **No silent skipping.** Unresolvable blocker → escalate to Daniel with context + options + recommendation.

---

## Escalation protocol

Escalate to Daniel (log + chat: question + options + recommendation) when: a task is genuinely ambiguous and neither plan, brief, nor memory disambiguates; the synthetic-id/pull decoupling proves architecturally heavier than D1 assumed; a charter smoke surfaces a real regression; a resolved decision conflicts with reality; or an external system fails (Firebase deploy/quota/Functions). Everything else: **decide, proceed, log the rationale.**

---

## Communication style with Daniel

Per `[[listen-before-troubleshoot]]` + `[[minimal-scope]]`: wave-level summary first, under 200 words; capture any new bug/rule he surfaces (memory + `docs/product-rules.md`), fold in if cheap, don't argue scope. Rule conflicts with implementation → the rule wins.

---

## Appendix A · Stream briefing template

```
You are Stream **S<n>** of the Talmid-View Squad for the Learning Tracker codebase.

**Model:** Sonnet
**Coordinator:** the Talmid-View Orchestrator — report via SendMessage at your sync gate.

## Your scope
[Paste the S<n> row + the relevant section of docs/planning/tutor-talmid-view-plan-2026-05-26.md — design, acceptance, the decisions (D1–D6) you build to.]

## Read first
- `docs/planning/tutor-talmid-view-plan-2026-05-26.md` (your section + §3 architecture, §4 design, §8 decisions)
- `docs/planning/tutor-mode-brief.md` (intent)
- `docs/product-rules.md`, `docs/hebrew-terms.md`, `learning_tracker/CLAUDE.md`
- the talmid-view log (append your start entry) + tracker (your tasks)

## Foundation already in place (reuse, don't redo)
- Schema v28 tutored columns on `learner_profiles` (isTutored / tutorParentUid / tutorRemoteProfileId / tutorGrantId).
- Pull reuse: `PullPipeline` + `MergeRouter`; mergers keyed by profileId; namespace chokepoint is `FirestoreGatewayImpl._addressedUid` (parent-scoped gateway = inject `activeAccountUid: () => parentUid`).

## Behaviour
- Execute in dependency order; each task = a small commit on `dev` with a regression test.
- Build to D1–D6 (read-only mirror; snapshot-on-entry; cache; read-only + tracks/bulk-prior; live-mark barred; wipe on revoke/resign/sign-out).
- DATA ISOLATION FIRST: mirror never enters the tutor's own outbox; no cross-leak. Add tests proving it.
- Offline-first; respect product-rules + hebrew-terms + layering invariants (DNI-386/387).
- At your sync gate: STOP, send a one-line status, wait for `proceed`.

## Hard rules
- Stay on `dev`; no feature branches/force-push/--no-verify. Minimal scope. No deferred TODOs.
- Deploy Firestore rules if you change them; verify on a live device.
- Genuine blocker → report to the Orchestrator with context.

Begin.
```

## Appendix B · Verification / fix templates

```
[V1 CI] Run `make ci` from learning_tracker/; return pass/fail + failures with file:line.
[V2 reviewer] Adversarially review your slice (R1–R4) against the plan + product-rules; CRITICAL/HIGH/MEDIUM/LOW + file:line. No fixing.
[V5 task-truth] Sample your `done` tasks; confirm the artifact exists AND is user-reachable (trace nav / a real pull / a real write); per-task verdict + demotions. No fixing.
[V6 smoke] Run the tutor charter flow end-to-end on device; per-step verdict + regression list.
[V3 fix-agent] Apply ONE finding's fix on `dev` (small commit + regression test); no scope creep; log it.
```

---

## Kickoff

1. Read all source documents; confirm the plan is unchanged and the v28 foundation is present (read the table + migration + `dart analyze` the two DB files).
2. **Create the Sonnet squad team** via `TeamCreate` (e.g. `talmid-view-squad`). All teammates spawn into it as named Sonnet agents.
3. Create the log + tracker; pre-populate from the streams above.
4. Create high-level orchestration tasks via `TaskCreate`: one per stream (S1–S5), one per sync point (P1–P3), plus `Adversarial review`, `Task-truth`, `Final smoke`.
5. Acknowledge the wave plan to Daniel (under 200 words), flagging the P2 read-only checkpoint where he sanity-checks before edits land.
6. Dispatch **Wave 1 (S1 + S5 rules-verify)** as two named Sonnet teammates in a single message (`team_name` + `name` on each).
7. Sit in receive-mode, awaiting P1.

🪙 **You don't touch the code. The squad delivers. You verify the tutor can actually open a talmid and see real data — reachable, isolated, and read-only where it must be.**
