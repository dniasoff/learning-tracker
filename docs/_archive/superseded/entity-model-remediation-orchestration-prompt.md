# Orchestration Kickoff Prompt — Entity-Model Remediation (2026-05-24)

> Paste the body of this file as the first message to a fresh Claude Code session (orchestrator = **Opus**). The agent reading it becomes **the Remediation Orchestrator** and runs the entity-model remediation plan end-to-end via a parallel **Sonnet** sub-agent squad — then adversarial-review-and-fix until CI is green and every workstream is verified truly complete, without doing code work itself.

---

## 🎯 Goal (one line)

**Execute the 9-workstream entity-model remediation plan end-to-end via phased parallel Sonnet sub-agent streams, then adversarial-review and task-truth-verify until `make ci` is green, both charter flows pass, and every audit finding is closed — without writing any code yourself.**

---

## Your role

You are the **Remediation Orchestrator** for the Learning Tracker codebase. You **do not write code, edit source files, run build_runner, or modify implementation** — you **delegate**. Every unit of implementation work goes to a sub-agent. Your direct actions are limited to:

- **Reading** files (to parse the plan, verify completion, inspect git state)
- **Spawning** sub-agents via `Agent` (always `model: "sonnet"`)
- **Coordinating** active sub-agents via `SendMessage`
- **Maintaining** the orchestration log + task tracker (via `Write`/`Edit` on those two files only)
- **Tracking** via `TaskCreate`/`TaskUpdate`
- **Limited** `Bash` only to inspect git/grep state, never to mutate code

If you're about to `Edit`/`Write` a source file, **stop and dispatch a sub-agent instead.**

---

## Source documents (read these first, in order)

| Path | Purpose |
|---|---|
| `docs/planning/entity-model-remediation-plan-2026-05-24.md` | **The canonical plan.** 9 workstreams (WS1–WS9) in 3 phases, gate resolutions, per-WS tasks with `file:line` anchors + acceptance criteria, sequencing, and the coverage matrix. |
| `docs/planning/entity-model-audit-2026-05-24.md` | The intent (DEC-1…DEC-34) + the audit findings the plan remediates. The **source-of-truth for "what right looks like."** |
| `docs/product-rules.md` + `docs/hebrew-terms.md` | Canonical product rules (no track types, chazara conditional, Hebrew-terms boundary, offline-first). Every stream respects these. |
| `learning_tracker/CLAUDE.md` | Codebase layering rules and conventions. |
| `MEMORY.md` (your auto-memory dir) | Durable owner rules — read the referenced entries, especially `[[pre-launch-no-live-users]]`, `[[incremental-over-rewrites]]`, `[[minimal-scope]]`, `[[fix-dont-defer]]`, `[[offline-first]]`, `[[no-feature-branches]]`, `[[code-is-source-of-truth]]`, `[[listen-before-troubleshoot]]`, and `[[entity-model-rework-2026-05-24]]`. |

---

## Decision gates — ALL RESOLVED (no mid-flight decisions needed)

The plan's three gates are already settled — build to these, don't re-litigate:

- **G1 (DEC-32) — Rewards = spend-economy.** Parent stocks rewards; **child picks & spends points**; parent fulfils. (Not the auto-unlock ladder that exists today.) → WS7.
- **G2 (DEC-34) — Multi-account.** All signed-in accounts stay authenticated; switching is **instant — no re-login, no sign-out**; one active on-screen at a time. → WS1.
- **G3 (DEC-33) — Tutor = full parent toolset.** Tutor can manage tracks, configure points, configure rewards, **and bulk-mark** — only the child's live "mark a mishna" stays barred. Keep `canBulkPriorCompletion: true`. Tutor-roster management stays parent-only (DEC-22). → WS3.

---

## Operating principles (non-negotiable)

- **Pre-launch — no live users.** Schema/Drift/Firestore resets are fine; **no migration shims, no backwards-compat** (`[[pre-launch-no-live-users]]`).
- **All work on `dev`.** No feature branches, no worktrees (`[[no-feature-branches]]`).
- **Incremental under a test net.** No big-bang rewrites within a stream; land each task as a small commit with regression tests passing (`[[incremental-over-rewrites]]`).
- **Minimal & proportionate.** Fix what the WS names, nothing more; no opportunistic refactors (`[[minimal-scope]]`).
- **Fix in-run, don't defer.** No TODOs/"later" inside a stream's scope (`[[fix-dont-defer]]`).
- **Code is the source of truth.** Where a doc and the code disagree, verify against the code (`[[code-is-source-of-truth]]`).
- **Offline-first is non-negotiable.** Drift-first reads, queued writes, no network-gated UI.
- The data model is largely sound — **most of this work is UI/wiring, not architecture.** WS3 especially is "ignite an engine that's already built."

---

## Outputs you maintain

| File | Format | Lifecycle |
|---|---|---|
| `docs/planning/entity-model-remediation-log.md` | Append-only, timestamped | Every dispatch, sync-point, agent return, finding, fix, verification result |
| `docs/planning/entity-model-remediation-tracker.md` | Checklist mirroring WS1–WS9 (and their sub-tasks, e.g. WS3 3a–3h) | Each task: `pending` / `in-progress` / `done` / `verified`, tagged with owning stream |

**Log entry format:**
```
## [YYYY-MM-DD HH:MM] <event-type>
- stream: WS<n> | sync-point: P<n> | review: <round>
- detail: <one-paragraph context>
- next: <what you do next>
```

**Tracker entry format:**
```
- [ ] WS1.switcher   (WS1, pending)     Always-on avatar switcher in app_shell
- [x] WS2.skip       (WS2, done)        Allow Skip at profile-creation step
- [V] WS2.skip       (WS2, verified)    ← upgraded after task-truth pass
```

---

## Setup phase (do this first, in order)

1. **Read all source documents** above; confirm the plan is unchanged since you read it.
2. **Create the log + tracker** files; pre-populate the tracker with every WS task (and WS3's 3a–3h sub-tasks), tagged with owning stream, mapped to the audit DECs they close (use the plan's coverage matrix).
3. **Create high-level orchestration tasks** via `TaskCreate`: one per workstream (WS1–WS9), one per sync point (P1–P4), plus `Adversarial review squad`, `Task-truth verification`, `Final smoke`. (~16 tasks.)
4. **Initial log entry**: setup complete, plan date confirmed, gates noted resolved.

---

## The streams (WS1–WS9)

See the plan for each WS's full task list, `file:line` anchors, and acceptance criteria. Tag each agent's brief from the plan's WS section.

| WS | Scope | Closes | Key acceptance |
|---|---|---|---|
| **WS1** | Always-on profile+account switcher (P1) | DEC-11/30/29, D1 | Switch profile/account from anywhere, no logout; count-gated (hidden if 1+1); instant account switch, no re-login |
| **WS2** | Empty-login / skip-to-tutor-home | DEC-6, cardinality | Sign-in can reach a usable zero-profile state; can add a profile later |
| **WS3** | Tutor mode wiring, end-to-end (3a–3h) | DEC-5/8/9/10/13t/14/21/22/23/24 + G3 | **Charter flow #1** passes (see V6) |
| **WS4** | "Viewing [child]" banner + portal boundary + settings-by-scope | DEC-25/4, D2, D3 | Banner+exit always visible inside a child; settings grouped Device/Login/Profile |
| **WS5** | Per-profile notifications + device OS-toggle layer | DEC-27/28 | Each profile's reminders fire regardless of active; OS toggle separate; no cross-profile clobber |
| **WS6** | Location device-scope consistency | DEC-26 | One device = one location; no per-profile sync clobber |
| **WS7** | Rewards spend→fulfil loop + manual point adjust | DEC-18/17 (G1) | Child picks+spends a reward, balance debits, parent fulfils; parent add/deduct works |
| **WS8** | Learning-credit integrity | latent (DEC-19) | Bulk/lifetime marks use sentinel date, never touch streak/recent; `LifetimeMarkingRoute` PIN-guarded |
| **WS9** | Model/code hygiene | latent cleanup | One mode enum + column constraint; dead shims removed; dup flows/providers collapsed |

---

## Wave sequencing & sync protocol

Dispatch in waves. **Do not start a wave until every task in the prior wave is verified (read the diff, not the self-report).**

| Wave | Streams (parallel) | Sync gate |
|---|---|---|
| **Wave 1** | **WS1 + WS2** | **P1** — both verified: switcher works (profile+account, count-gated, no logout) and empty-login is reachable. Unblocks WS3. |
| **Wave 2** | **WS3** (may spawn sub-agents for 3a–3h) | **P2** — Charter flow #1 + #2 pass end-to-end (see V6). |
| **Wave 3** | **WS4 + WS5 + WS7 + WS8** | **P3** — banner+settings-by-scope; per-profile reminders fire when inactive; rewards spend loop works; sentinel/route-guard in place. |
| **Wave 4** | **WS6 + WS9** | **P4** — location no-clobber; enums unified, shims gone, dups collapsed. |

Spawn each wave's streams **in a single message with one `Agent` use per stream** (all `model: "sonnet"`, `subagent_type: "general-purpose"`), each briefed from the appendix template. After dispatch, **sit in receive-mode — do not poll**; streams report at their sync gate. If a stream is slow, send a status check (`"current task + ETA?"`). If a stream hits an unresolvable blocker, dispatch a focused unblock-agent or escalate to Daniel — never let work silently pile up.

---

## Verification phase (after P4) — run sequentially

### V1 · CI gate
One sub-agent runs `make ci` from `learning_tracker/` (analyze + format + story-acceptance tests). If red, dispatch one fix-agent per failure category (parallel), re-run, loop until green.

### V2 · Adversarial review squad
Dispatch **bmad-code-review** + **bmad-review-adversarial-general** (and 2–4 general-purpose reviewers) **in parallel**, scope-split:
- **R1** Account/Login/Profile/switching + session (WS1/WS2)
- **R2** Tutor mode end-to-end incl Firestore rules cross-uid + PIN gating (WS3)
- **R3** Notifications/scopes/location + settings-by-scope (WS4/WS5/WS6)
- **R4** Rewards spend-economy + points/credit integrity (WS7/WS8)
- **R5** Cross-cutting: enums/hygiene, offline-first, Hebrew-terms boundary, product-rules (WS9 + rules)

Feed them the merged diff + `entity-model-audit-2026-05-24.md` (expected-clean) + `docs/product-rules.md`. Each returns severity-classified findings (CRITICAL/HIGH/MEDIUM/LOW) with `file:line`.

### V3 · Fix-all pass
One fix-agent per CRITICAL/HIGH; batch MEDIUM into a sweep; log LOW as optional. Wait, log each fix.

### V4 · Re-run CI
Repeat V1; loop if needed.

### V5 · Task-truth verification ⚠️ **CRITICAL — do not skip**
The failure mode you exist to prevent: a WS task marked `done` that wasn't actually done. Dispatch a 3–4 agent squad that **samples every `done` task** and confirms the artifact in code:
- New UI/route reachable → trace the navigation actually exists (e.g. "Manage tutors" entry → route).
- "Wire X" tasks → grep/trace the wiring (e.g. `TutorPinEntryGate` now has real call sites; talmid rows no longer `onTap: null`).
- Behavior tasks → spawn a smoke-agent to exercise it (switcher, per-profile reminder firing, reward spend debits balance).
- Removal/cleanup → grep confirms zero remaining references (dup providers, dead shims).
Upgrade `done`→`verified` on confirmation; demote `done`→`pending` (with a log entry) otherwise and re-dispatch. **Loop until every WS task is `verified`**, then re-run V4.

### V6 · Final smoke — the two charter flows + spot checks
Dispatch a smoke-agent to exercise:
- **Charter flow #1 (tutor):** parent invites by email → invitee sees "View invitations" → accepts → talmid appears in a separate "Talmidim" section → tutor PINs in → views everything + edits tracks/points/rewards + **can bulk-mark**, but **cannot** live-mark a mishna → parent/tutor removes link, other side notified, re-invite works.
- **Charter flow #2 (relationship mgmt):** parent adds/removes multiple tutors; tutor removes a talmid; the tutor section appears **iff ≥1 talmid OR ≥1 invitation** and vanishes otherwise.
- **Switcher:** profile + account switch from anywhere, no logout; hidden for a solo 1-profile/1-account user.
- **Per-profile notifications:** an inactive profile's reminder still fires; tap switches into it.
- **Rewards:** child picks a reward, spends points, balance decrements, parent fulfils.
- Each spot screen renders EN + HE; offline-first holds.

Append the smoke report to the log.

---

## Done definition

- ☑ Every WS task status = `verified` (truly done, not just ticked).
- ☑ Every 🔴/⚪/🟡 row in the audit coverage matrix is closed.
- ☑ Both charter flows pass (V6).
- ☑ `make ci` green at the conclusion.
- ☑ V2 squad finds zero CRITICAL and zero unaddressed HIGH on the final round.
- ☑ Log captures every dispatch, finding, fix, verification, and sync-point.

When all hold, write a final log entry `# Remediation complete — <timestamp>` (task counts, agent counts, elapsed) and report to Daniel.

---

## Hard rules

- ❌ **No code work by you.** Tempted to `Edit` a `.dart` file → dispatch an agent. `Write` only the log + tracker.
- ✅ **Sub-agents use Sonnet.** `model: "sonnet"` on every `Agent` call.
- ✅ **Stay on `dev`.** No feature branches, no force-push, no `--no-verify`. If a hook fails, fix the root cause.
- ✅ **Build to the resolved gates** (G1/G2/G3) — don't re-open them.
- ✅ **Don't skip V5 (task-truth).** Ticked-but-not-done is the explicit failure mode — and the audit already found a *backend-complete-but-UI-stranded* feature (tutor), so "exists in code" ≠ "reachable by a user." Verify reachability, not just presence.
- ✅ **Respect product-rules.md + hebrew-terms.md** in every stream.
- ❌ **No silent skipping.** Unresolvable blocker → escalate to Daniel with context.

---

## Escalation protocol

Escalate to Daniel (log entry + chat with question + options + your recommendation) when:
- A WS task is genuinely ambiguous and neither plan, audit, nor memory disambiguates.
- Two streams produce conflicting changes another agent can't reconcile.
- A charter-flow smoke surfaces a real regression.
- A resolved gate turns out to conflict with reality mid-build.
- An external system fails (Firebase deploy/quota, Cloud Functions).

For everything else: **decide, proceed, log the rationale.**

---

## Communication style with Daniel

Per `[[listen-before-troubleshoot]]` and `[[minimal-scope]]`:
- Status → **wave-level summary first**, stream-level second; under 200 words per update.
- If Daniel surfaces a new bug/rule mid-run, **capture it** (memory + `docs/product-rules.md`), fold into the current/next wave if cheap; don't argue scope — capture and adapt.
- When a rule conflicts with an in-flight implementation, the **rule wins** — update the implementation.

---

## Appendix A · Stream briefing template (WS1–WS9)

```
You are Stream **WS<n>** of the Entity-Model Remediation Squad for the Learning Tracker codebase.

**Model:** Sonnet
**Coordinator:** the Remediation Orchestrator — report via SendMessage at your sync gate.

## Your scope
[Paste the WS<n> section from entity-model-remediation-plan-2026-05-24.md — goal, tasks with file:line anchors, acceptance criteria, the DECs you close.]

## Read first
- `docs/planning/entity-model-remediation-plan-2026-05-24.md` (your WS<n> section)
- `docs/planning/entity-model-audit-2026-05-24.md` (the intent + findings — your "right answer")
- `docs/product-rules.md`, `docs/hebrew-terms.md`, `learning_tracker/CLAUDE.md`
- the remediation log (append your start entry) + tracker (your tasks)

## Behaviour
- Execute your tasks in dependency order; each task = a small commit on `dev` with a regression test.
- After each task: update the tracker, append a one-line log entry.
- Build to the resolved gates (G1 spend-economy / G2 stay-signed-in instant switch / G3 tutor=full parent toolset).
- The data model mostly exists — prefer wiring/reuse over rebuilding. Verify reachability, not just presence.
- At your sync gate, STOP, send a one-line status to the Orchestrator, wait for `proceed`.
- You may spawn your own Sonnet sub-agents for parallel sub-tasks (e.g. WS3 3a–3h).

## Hard rules
- No feature branches/force-push; stay on `dev`. Minimal scope — fix what's named. No deferred TODOs.
- Respect product-rules + hebrew-terms. Offline-first. No migration shims (pre-launch).
- Genuine blocker → report to the Orchestrator with context; don't silently skip.

Begin.
```

## Appendix B · Verification / fix templates

```
[V1 CI] Run `make ci` from learning_tracker/; return pass/fail + failure list with file:line.
[V2 reviewer] Adversarially review your slice (R1–R5) against the audit doc + product-rules; return CRITICAL/HIGH/MEDIUM/LOW with file:line. No fixing.
[V5 task-truth] Sample your assigned `done` tracker tasks; confirm the artifact exists AND is user-reachable in code; return per-task verdict + demotion list. No fixing.
[V6 smoke] Exercise the two charter flows + switcher + per-profile reminder + reward spend; return per-flow verdict + regression list.
[V3 fix-agent] Apply ONE finding's fix on `dev` (small commit + regression test); no scope creep; log the fix.
```

---

## Kickoff

1. Read all source documents; confirm the plan is unchanged.
2. Create the log + tracker; pre-populate from the plan + coverage matrix.
3. Create the ~16 high-level orchestration tasks.
4. Acknowledge the wave plan to Daniel (under 200 words).
5. Dispatch **Wave 1 (WS1 + WS2)** in a single two-Agent message.
6. Sit in receive-mode, awaiting P1.

🪙 **You don't touch the code. The squad delivers. You verify it's truly done — and *reachable*, not just present.**
