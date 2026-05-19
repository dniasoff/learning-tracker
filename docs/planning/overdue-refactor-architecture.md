# Overdue System — Refactor Architecture

| Field | Value |
|---|---|
| **Status** | Draft — for review |
| **Date** | 2026-05-19 |
| **Owner** | Daniel |
| **Scope** | The overdue computation — the "fickle" design, Bug 1, Bug 2, and the "Clear Overdue" feature |
| **Diagnosis source** | `docs/sync-rework-exec-prompt-2026-05-18.md` (Addendum — Bug 1 / Bug 2, with file:line) |
| **Supersedes** | The catch-up & amnesty design — `docs/planning/catchup-and-amnesty-scenarios.md` and `docs/scenarios/evolution/` (see §9) |

---

## 1. Scope & summary

The overdue/scheduler subsystem is unreliable: the dashboard `OVERDUE` count is intermittent (it changed between two app launches with nothing marked done), and Daf Yomi never accrues overdue at all.

The root cause is architectural, not a single bug: **"overdue" is treated as stored state when it should be a derived projection.** This document defines the target — overdue becomes a pure, deterministic function of synced inputs, computed on demand. It covers the redesign, the two confirmed bugs it resolves, the "Clear Overdue" feature, and an incremental migration path.

This is a **design doc for review**, not an implementation plan.

## 2. The problem — overdue is materialized state

Today the dashboard `OVERDUE` count is `count(tasks where isOverdue == true)` (`dashboard_body.dart:161`, `dashboard_helpers.dart:51`). `isOverdue` is a **boolean column** on the `daily_plans` table (`daily_plans.dart:26`) — computed once when the day's plan is built, then stored.

The day's plan is a snapshot: `getOrSnapshotPlan` builds it on the first read of a local day and serves it back verbatim (`daily_plan_repository.dart:39-66`). But the snapshot is **not** immutable — `rebuildPlan` deletes and regenerates it (`:214-233`) whenever a guard trips (`scheduler_providers.dart:294-342`).

Because "overdue" is materialized at build time:

- it can be **stale** — it reflects whatever the local DB held at build time;
- it is **non-deterministic** — the build reads ~15 tables, and `rebuildPlan` re-runs it; if those inputs shift between builds, the stored answer changes;
- it is **local-only** — `daily_plans` is not synced; on reinstall it is gone.

"Overdue" is intrinsically relative to *today* and *what has been completed*. Storing it guarantees drift.

## 3. Root causes

Full diagnosis with file:line is in the Addendum of `docs/sync-rework-exec-prompt-2026-05-18.md`. In brief:

**Bug 1 — program tracks never go overdue.** `_applyProgramCalendarOverrides` (`scheduler_providers.dart:924-944`) treats a plain `tracking_start_ref` (e.g. the live value `"Chullin 18"`) as *today's* unit, then tries to fetch following days gated on `(today+1).isBefore(today)` — always false (`:935-936`). The program freezes on its start ref: it never advances and never accrues a backlog. A deterministic logic error.

**Bug 2 — the plan is computed against a moving target.** The daily plan is snapshotted/rebuilt by `allDailyTasks` while an asynchronous launch sync is still merging `curriculum_tracks`, `profile_programs`, and completions into the DB (confirmed in diagnostic log `diagnostic_logs/3CSalXoTY6rkrgNdZUdD`: offline launch, then a full merge after the dashboard had rendered). `rebuildPlan` regenerates the snapshot when sync-driven DB changes trip `snapshotMissingActiveCurriculum`. The `OVERDUE` count is therefore "whatever the last regeneration produced" — it differs between launches with no user action.

Both bugs are children of §2: a stored, rebuildable `isOverdue` over a DB that sync mutates concurrently.

## 4. Decision — overdue is a pure projection

> **Overdue is a derived projection, not stored state.**

Separate three concepts that are currently tangled:

| Concept | What it is | Where it lives |
|---|---|---|
| **Schedule** | What unit a track expects on each date | A pure function of the track's anchor + calendar/pace |
| **Progress** | What the learner has completed | The completion log — append-only, already synced |
| **View** | Today / overdue / review | A pure projection over Schedule and Progress |

The view is computed, never stored as truth:

```
overdue   = { units scheduled before today } − { completed }
due today = { units scheduled for today }    − { completed }
```

Same inputs → same result, on every launch and every device. When sync delivers new data, the projection re-derives the *correct* answer; it never persists a wrong one. This is what eliminates Bug 2.

## 5. The model

### 5.1 Schedule

- **Program tracks (Daf Yomi, Dirshu, Oraysa)** — the schedule is the program calendar, a deterministic function of the date, anchored at the enrollment start (`profile_programs.tracking_start_date`). The app already has a local, offline calendar engine (`lib/core/services/local_calendar_engine.dart`). The unit for any date is `calendar(program, date)`; the anchor only bounds how far back "overdue" reaches. There is no per-day frozen sequence — fixing Bug 1 means walking the calendar forward, not freezing on `tracking_start_ref`.
- **Self-paced tracks** — `expected_position(date) = pace × elapsed_study_days(start, date)`. `elapsed_study_days` depends only on the date and the study-day pattern, so it is stable within a day.

### 5.2 Progress

The completion log — already append-only, immutable, and synced. No change required. It is the one well-modelled part of the current system.

### 5.3 The derived view

`overdue` / `due today` / `review` are computed by the formula in §4. The current `backfillMissingSnapshots` machinery — synthetic snapshot rows written for days the app was not opened — exists only to *fake* a schedule that spans missed days. A real schedule function spans them intrinsically; backfill disappears.

The "today's list is a contract" property (completions must not reshuffle the day) is preserved automatically: a deterministic projection only changes within a day when the user completes an item (intended) or the date rolls over (intended). The snapshot was a workaround for non-determinism; determinism removes the need for it.

## 6. Durability — every input synced, the snapshot is a disposable cache

**Rule: every input the overdue count depends on must be durable and synced. Nothing it depends on may live only on the device.**

This makes the system correct across **device-off** (the schedule spans the gap with no app run required) and **reinstall** (the projection rebuilds the identical answer from synced data; the lost local snapshot held no unique truth).

| Input | Synced today? |
|---|---|
| Program anchor — `profile_programs` (start date, start ref) | Yes |
| Track config — `curriculum_tracks` (activated_at, pace baseline) | Yes |
| Goals / pace | Yes |
| Study-day configuration | Yes (in the profile settings) |
| Completion log | Yes |
| Ordered curriculum content | Shipped with the app — see §10 |

The local `daily_plans` table is demoted to a **disposable cache** keyed by its inputs. Losing it (reinstall) or finding it stale costs nothing — it is re-derived. It is never the source of truth.

## 7. "Clear Overdue" — a re-anchor

"Clear Overdue" lets the user forgive their backlog and start again from today's real position. Architecturally it is a **re-anchor**: it moves the track's synced anchor to today.

- For a program track: write `tracking_start_date = today` and `tracking_start_ref = <today's calendar unit>` to the synced `profile_programs` row.
- The overdue window `[anchor, today)` collapses to empty → backlog gone, count zero, notifications quiet — all because they derive from the projection (§4).
- It is **synced**, so it survives reinstall. It is **repeatable** — pressing it again later simply moves the anchor again ("again and again, for stragglers"). It uses **existing fields** — no new table, no new schema.
- **Program tracks only.** "Snap to today's real position" is meaningful only for a calendar-driven program. Self-paced recovery is a separate concern (a pace reset) and is out of scope here.
- The button is disabled when the overdue set is empty.

**Dependency:** "Clear Overdue" only works once Bug 1 is fixed. Re-anchoring is inert unless the program then *advances* from its anchor day by day. With Bug 1 present, the button would snap the track to today's daf and then freeze it there permanently. "The anchor is user-movable" and "the schedule advances from the anchor" are one feature, built together.

This deliberately replaces the row-deleting `clearOverdueForTrack` approach (which deletes `daily_plans` rows — the disposable cache — so the clear evaporates on the next rebuild, the next day, or on reinstall). It also replaces the larger amnesty model (§9).

## 8. Notifications — the third consumer

Overdue has three consumers, all of which must derive from the one projection: the dashboard count, the today/plan list, and the **notification schedule**.

The notification system is sound in its reactivity: `reminderSyncEffect` (`notification_providers.dart:286-329`) is `keepAlive` and watches `allDailyTasksProvider`; any change re-drives it, and `scheduleBatchReminders` cancels the old batch before re-queuing (`notification_service.dart:154`). A re-anchor reschedules immediately and correctly.

Its one weakness is the same disease as §2: `scheduleBatchReminders` pushes a **single frozen body** to 14 pre-scheduled OS notifications. Between app runs those carry a stale count; they only re-sync when the app next runs the effect. A pushed-ahead notification can never be fresher than the last app run — an inherent floor, not a bug to "fix" — but the projection model should still be what feeds the reschedule.

Minor pre-existing defects in the same area, worth tickets: the body says "X tasks **today**" but X includes overdue and review; and the reminder still fires "0 tasks today" when the count is zero.

## 9. Superseded — the amnesty / catch-up design

The project carries an unbuilt design for a "catch-up & amnesty" system: a per-item `item_amnesty` ledger (append-only, revocable via "unforgive"), an amnesty-history screen, and a three-variant catch-up sheet (`docs/planning/catchup-and-amnesty-scenarios.md`, `docs/scenarios/evolution/`).

A codebase scan confirms it has **zero implementation** (no `item_amnesty` table, no `rescope`, no recovery service). It is a whole product-evolution feature set — disproportionate to the actual need, which is a single "Clear Overdue" action. The re-anchor in §7 delivers that need simply, with no new data model.

That design is therefore **superseded** and marked obsolete. It may be revisited later as a deliberate product decision, but it is not part of this refactor.

## 10. Resolved decisions

Resolved with Daniel on 2026-05-19.

1. **Content determinism — resolved.** The schedule and projection key on stable `sefariaRef`s, never numeric indices (completions and the calendar already use refs). Curriculum ordering is a versioned, append-mostly artifact: content updates may correct text or append units, but any reordering is a deliberate versioned migration — never silent. *Open implementation check:* confirm curriculum unit ordering is in fact stable across content-DB versions today (the seed / `learning_order` path).
2. **Sync-completeness — resolved.** A persisted **"initial sync complete" flag** is set the first time a full pull finishes. Before it is set, the dashboard shows a *syncing* state and never renders an overdue number. After it is set, the projection runs on local data normally — online or offline; local data is the last-synced, complete truth (offline ≠ incomplete). One flag, not a version/watermark system. This replaces the `dailyTasksAsync.value ?? []` masking at `dashboard_body.dart:134`.
3. **Self-paced "overdue" — resolved.** A self-paced track **must have an explicit pace.** The setup UI forces the user to choose one; a self-paced track cannot exist without it. There is no default — the `kDefaultBackfillPace` constant (5/day) is removed. Overdue for a self-paced track is then always well-defined: units behind the chosen pace and not done. **Migration consequence:** existing self-paced tracks created without a pace (e.g. the current Mishnayos track) are invalid under this rule; on upgrade they must prompt the user to set a pace before the track resumes — no pace is auto-assigned.

## 11. Migration — incremental, no big-bang

Consistent with the project's "incremental over rewrites" rule:

1. **Bug 1 first.** The program-advance fix is a contained logic correction in `_applyProgramCalendarOverrides`. It can land independently, behind its own tests, before the larger projection work.
2. **Build the projection alongside the snapshot.** Implement `overdue = scheduled − completed` as a pure function. Run it next to the existing `daily_plans` path and assert they agree for non-buggy cases — a characterization net.
3. **Cut over.** Make the projection authoritative for the dashboard count, the plan list, and the notification body. Demote `daily_plans` to a pure cache (or remove it).
4. **Retire backfill.** Once the schedule function spans missed days, `backfillMissingSnapshots` / `backfillStudyDaySnapshots` are dead and can be deleted.

## 12. Relationship to the Firebase sync rework

Bug 2 is a sync-timing problem and overlaps the planned Firebase sync rework (`docs/sync-rework-exec-prompt-2026-05-18.md`). The projection model is the *scheduler-side* half of the fix: it makes the overdue computation immune to *when* sync runs. The sync rework is the *sync-side* half. The two must be coordinated — in particular, the §10.2 sync watermark is a shared dependency. Bug 1 is purely scheduler-side and independent of the sync rework.
