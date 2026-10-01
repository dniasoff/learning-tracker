---
title: 'Adversarial review — Sub-tracks architecture spine'
target: docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
reviewed: '2026-09-30'
method: 'Construct pairs of epic/story-level units that each obey every AD literally yet build incompatibly; reality-check against learning_tracker/ source'
verdict: 'NOT READY — the paradigm is sound, but 3 critical and 7 high holes let compliant epics diverge on data ownership, points, lock evaluation and history'
---

# Adversarial review — Sub-tracks architecture spine

## Verdict

**Not ready for epic breakdown.** The event-sourced paradigm (one log, one reducer, one command layer) is correct and will hold. But the spine is written as if it were greenfield, and the codebase it is going into is not:

- About 40 files consume `completions`.
- Twelve tutor callables already write goals, tracks and study days without any change log.
- The `goals` collection has non-deterministic ids and an owner-delete rule.
- The existing zmanim service disagrees with the PRD's lock parameters and iterates days in the device's local timezone.

Several ADs name an outcome without naming the enforcement point or the exact function. Two teams can therefore satisfy them to the letter and still ship incompatible code. Every finding below has replacement Rule text.

Severity counts: **3 critical, 7 high, 7 medium, 4 low.**

## Evidence base (code reality)

| Fact | Source |
| --- | --- |
| `completions` is read or written by about 40 non-generated files: scheduler engine, daily_task_projection, progress charts, items-learned, lifetime-knowledge, streak_alert_service, notifications completion adapter, bulk-prior onboarding, and `CompletionOrchestrator`, which co-writes `learning_ledger` + `streak_events` + `points_ledger`. | `grep CompletionRepository lib/` |
| The tutor callables `tutorUpsertGoal`, `tutorDeleteGoal`, `tutorUpsertTrack`, `tutorDeleteTrack`, `tutorUpsertStageDefinition`, `tutorUpsertStudyDayConfig`, `tutorDeleteStudyDayConfig`, `tutorUpsertBookmark`, `tutorSetProfileProgram`, `tutorUpsertCurriculumScope` and others write first and then call a **best-effort** `writeAuditLog` into `tutor_grants/{id}/audit_log`. That log is purged after 12 months (`audit_log_purge.ts`). | `functions/src/tutor_writes.ts` |
| Tutor callables gate on per-grant permission keys (`can_edit_goals`, `can_edit_stages`, …). Tutor live completions are blocked by policy (`canMarkLiveCompletion=false`, W3.43). | `tutor_writes.ts:verifyTutorGrant`, `firestore.rules` completions comment |
| `goals`: the field whitelist has no `lastChangeId` and no `type` field (it uses `goal_type`: `deadline` or `pace`). **Owner delete is allowed.** Doc id = `id` or `goal_id` or a fallback, so it is not unique per profile. | `firestore.rules:571`, `doc_ids.dart:goalDocId` |
| Append-only collections cap `list` at 500 (SR-4). The parent AD-4 streak repository streams only a recent window. | `firestore.rules`, parent AD-4 |
| `ZmanimWindowService` uses `candleOffsetMin = 18` and `cushionMin = 15`. It iterates days with `_atMidnightLocal(from)` and `JewishCalendar.fromDateTime(d)`, both in the **device** timezone. The PRD specifies 10 min before candle-lighting and 10 min after tzeis. | `features/sacred_time/domain/services/zmanim_window_service.dart` |
| Location and `inIsrael` live in SharedPreferences (`SacredTimePreferences`) and are read by the notification scheduler (`inIsraelProvider`) and the lock overlay. | `sacred_time_preferences.dart`, `notification_providers.dart:497` |
| `tutorEditProfile` whitelists only `displayName`, `avatar` and `mode`. The owner `learner_profiles` update has no field whitelist. | `tutor_writes.ts:969`, `firestore.rules:211` |
| `tool/check_dependency_direction.dart` gates only `data/firestore/` imports, not `data/repositories/`. | tool source |

---

## Critical

### C1 — Two stores of "learnt": the completions cutover is scoped to the planner only

**Compliant but incompatible pair**

- **Epic A (Capture):** writes `learning_events` only, obeying AD-31 ("`completions` receives no new writes for the Mishnayos goal; the main-track planner reads learnt state from the engine").
- **Epic B (existing Progress / Notifications / Rewards, untouched):** keeps reading `completions`, `learning_ledger` and `streak_events`. That is legal, because AD-31 only redirects *the planner*. Result: progress charts, items-learned, lifetime-knowledge, streak alerts and siyum retraction (`learning_ledger.purged_at`) all show zero or stale values for Mishnayos.
- **Alternative Epic B′:** keeps `CompletionOrchestrator` for ticking main-track tasks and adds a `learning_event` in the same batch. AD-31 does not forbid a dual write for *non*-Mishnayos-goal learners, and "for the Mishnayos goal" is ambiguous (goal-scoped or curriculum-scoped). A learner with a Mishnayos *pace* goal, or no goal at all, is then on completions while a deadline learner is on events. Same curriculum, two stores.

**Also ambiguous:** in a profile with Mishnayos and another curriculum, the planner reads learnt state from the engine for one and from completions for the other. The spine does not say how.

**Proposed new AD-49 — Curriculum-scoped cutover (replaces the last two sentences of AD-31):**
> For the Mishnayos curriculum (`CurriculumId` = Mishnayos), independent of whether any goal exists or its type, `learning_events` is the only write target for learning, and `completions`, `learning_ledger` and `streak_events` receive no writes. Every existing consumer of those three collections that can observe Mishnayos data is listed in the cutover inventory (`docs/planning/architecture/architecture-sub-tracks-2026-09-30/cutover-inventory.md`). Each entry is either rewired to read `LearnerState` or explicitly filtered to non-Mishnayos curricula. The inventory covers at least: scheduler_engine, daily_task_projection_service, progress chart/items-learned/lifetime-knowledge providers, streak_alert_service, notifications completion adapter, bulk_prior_completion_service, CompletionOrchestrator/CompletionPointsAwarder/CompletionStreakRecorder, and siyum/reward milestone readers. The planner reads done-state through one `LearntStateSource` interface: the engine for Mishnayos, the completions repository for other curricula. No surface picks a source itself. The epic plan must include a story that closes the inventory before any capture story ships.

### C2 — "Main-track settings" and the goal have unbounded writers that bypass change_log

**Compliant but incompatible pair**

- **Epic C (Tutor history):** adds the AD-38 `existsAfter(change_log/{lastChangeId})` rule to `goals` and the "main-track settings" collections.
- **Existing surfaces:** `edit_track_screen`, `step_goal`, and the tutor callables `tutorUpsertGoal`, `tutorDeleteGoal`, `tutorUpsertTrack`, `tutorUpsertStudyDayConfig`, `tutorDeleteStudyDayConfig`, `tutorUpsertStageDefinition`, `tutorUpsertCurriculumScope` and `tutorSetProfileProgram` keep writing without `lastChangeId`.
- Owner-side queued writes are then permanently rejected, which violates inherited AD-30. Tutor-side writes bypass rules through the Admin SDK and produce no `change_log`, so there is no history, no undo, and **no AD-39 push** for exactly the deadline and main-track changes FR-27 requires notifications for.
- If Epic C instead does *not* add the rule, AD-38 is unenforced for the goal.
- "Main-track settings" is never defined. It could mean `curriculum_tracks`, `settings`, `stage_definitions`, `study_day_configs`, `track_learning_order`, `learning_order`, `profile_programs`, `curriculum_scopes` or `bookmarks`, and several of those allow owner **delete**. A delete has no `request.resource`, so `lastChangeId` cannot be checked. The same applies to `goals` (owner delete allowed) and `tutorDeleteGoal`.
- Two audit trails now coexist: the best-effort `tutor_grants/{id}/audit_log`, purged at 12 months, and `change_log`.

**Proposed Rule (amend AD-38 and AD-46):**
> **Governed entities** are exactly: `sub_tracks/*`; `goals/{mishnayos_deadline}` (see M3); and, for the Mishnayos curriculum only, `curriculum_tracks/{mishnayosKey}`, `study_day_configs/*` where `curriculum_id` = Mishnayos, `track_learning_order/*` for Mishnayos, `stage_definitions/*` for Mishnayos, `curriculum_scopes/*` for Mishnayos, and the learner-settings fields of AD-37 (location, timezone, `inIsrael`). `change_log.entity` ∈ {`subTrack`, `goal`, `mainTrackOrder`, `mainTrackStudyDays`, `mainTrackStages`, `mainTrackScope`, `learnerSettings`}. For governed entities:
>
> 1. Client `delete` is denied. Removal is a tombstone field written under the same `lastChangeId` rule.
> 2. Each governed collection's field whitelist gains `last_change_id`.
> 3. Every legacy writer (UI and callable) is rerouted through `LearningCommands` or `TutorWriteService`, or removed, in the same release that adds the rule. For the Mishnayos curriculum, the legacy callables `tutorUpsertGoal`, `tutorDeleteGoal`, `tutorUpsertTrack`, `tutorDeleteTrack`, `tutorUpsertStageDefinition`, `tutorUpsertStudyDayConfig`, `tutorDeleteStudyDayConfig` and `tutorUpsertCurriculumScope` reject the request (`failed-precondition`) and the client uses the new callables.
> 4. `change_log` is the only history for governed entities. `tutor_grants/*/audit_log` stays security-audit only, is not shown in FR-27 history, and does not feed AD-39.

### C3 — Points diverge from the engine: lock-ignored events, double reversal, void semantics

**Compliant but incompatible pairs**

1. **Capture story:** writes a `source = main` learn event plus a `points_ledger` earn entry in one batch (Consistency Conventions → Points). The event's `recordedAt` falls inside a lock window (offline tick, clock skew, or a location change; see H1). The engine ignores it (AD-36), but the points balance, derived from `points_ledger` per inherited AD-4, keeps the points. No command ever runs to write a reversal.
2. **Parent's device and tutor's device both void event E offline.** AD-31 lets two void events with different ULIDs exist; the engine is fine because a set of targets is idempotent. Each void co-writes a reversal entry with its own ULID, so **points are reversed twice**. If instead a story gives the reversal a deterministic id (`rev_E`), the second device's payload differs in `created_at` and actor. The append-only rule rejects the changed-value update **permanently**, which violates AD-30.
3. **Void of a void:** AD-31 does not restrict `targetId` to `learn` events. One story implements "undo void" as a void of the void (natural for a reducer). Another follows AD-38 and writes a copy learn event. The reducers and point effects differ.
4. **Tutor voids** through a callable. AD-46 lists "event record/void" callables but never says the callable co-writes the reversal, so a tutor void leaves the points in place.
5. **Which main events earn:** chazara events (source main, already learnt), `beforeTracking` free ticks, and `catchUp` events are all unspecified. Existing policy (`points_ledger` `source`: `bulkInTrack` / `lifetimeOnly` never earn) says before-tracking must not earn. With *up to…* over learnt ground, points can be farmed without limit (compare PRD SM-C1).

**Proposed Rule (replace the Points row; declare an amendment to parent AD-4, points half):**
> A `source = main` learn event with `dateState ∈ {dated, catchUp}` earns points through exactly one `points_ledger` entry with doc id `pts_{eventId}` and field `event_id`, co-written in the event's batch or callable transaction. `beforeTracking` events and sub-track events write no points entry. Chazara earns at the configured chazara rate (or 0; the PRD owner decides, and one value is written in `point_configs`). **No reversal entries are written.** The points balance is Σ of ledger entries, where an entry with `event_id` counts only if `event_id ∈ LearnerState.countedEventIds` (not voided and not lock-ignored). Parent AD-4 is amended: the balance is still derived from `points_ledger`, filtered by the engine's counted set. A void's `targetId` must reference a `learn` event: the command layer and callable reject otherwise, and the engine ignores a void whose target is a void. Undoing a void is always a new `learn` copy (AD-38), which earns under its own `pts_{newEventId}`.

---

## High

### H1 — Lock windows are re-evaluated from *current* settings over *all* history, so the past changes

**Pair**

- **Story "Lock settings" (AD-37):** lets the parent move the profile location from London to Jerusalem, or flip `inIsrael`.
- **The engine (AD-36):** "ignores any event whose `recordedAt` falls inside a lock window." It recomputes windows with the new settings. Years of events recorded on a Friday 18:30 London time, or on the second day of yom tov in chutz la'aretz, are now inside or outside windows differently. The learnt set, streak and points (C3) change retroactively.
- **Cross-device variants:**
  - A device on an older app build with different `kosher_dart` parameters, or the current service's 18/15-minute constants against the PRD's 10/10, marks different events ignored. Two devices show different progress for the same data.
  - The PRD fallback "Friday 12:00 to Sunday 01:00 **local device time**" plus the existing `_atMidnightLocal` device-timezone iteration mean a tutor in New York and a talmid in Jerusalem compute different windows. AD-36 says "learner's settings" but does not say timezone-correct evaluation or which constants.
- Location changes are not logged anywhere (the owner profile update has no whitelist and no change_log), so the engine cannot reconstruct past settings.

**Proposed Rule (amend AD-36 and AD-37):**
> The lock-window function is `lockWindows(settingsHistory, fromUtc, toUtc)` in `lib/domain/learner_state/`. Constants are pinned in one file (`candleOffsetMin = 10` before candle-lighting, `tzeisOffsetMin = 10` after tzeis, per PRD FR-23, replacing the service's 18/15 for capture locking). All calendar-day iteration uses the learner's IANA `timezone` through the `timezone` package, never `DateTime.now().timeZoneOffset`. Profile `timezone` is required (set at profile creation from the creating device, editable), so the fallback window is Fri 12:00 to Sun 01:00 **in the learner's timezone**. Location, timezone and `inIsrael` changes are governed entities (C2, `entity = learnerSettings`). `settingsHistory` is the piecewise-constant series built from those change_log entries. An event is lock-ignored iff its `recordedAt` falls inside a window computed with the settings **in force at `recordedAt`**. Changing any lock constant is a new AD, never an in-place edit.

### H2 — The streak rule is under-specified: backfill through editable dates, and an undefined catch-up window across chained locks

**Pairs**

- **FR-3 free tick (dates editable at capture) vs the streak story.** AD-40 counts non-voided `source = main` `dated` events but never says which day an event counts for, or whether `learnedOn` must match the civil date of `recordedAt`.
  - **Story X** counts by `learnedOn`: a child free-ticks with yesterday's date and repairs a broken streak.
  - **Story Y** counts by `localDate(recordedAt)`: catch-up events are dated to Shabbos but recorded on Sunday, so they would count for Sunday.
  - Both comply.
- **Undo of a void of a `catchUp` event (AD-38 copy).** The copy gets a fresh `recordedAt` outside the catch-up window, so the streak day is lost. If Story X counts by `learnedOn`, it restores a streak day that FR-4 forbids.
- **"That day's catch-up window" is not a defined function.** In yom tov (Wed–Thu), then a non-locked Friday morning, then Shabbos, FR-25 says the window pauses and resumes. One team closes it at Friday candle-lighting; another extends it through Sunday.
- **"Locked day" is not defined.** Friday is civil-dated (AD-41) but partly locked. Does Friday-night learning go on the Shabbos card (`learnedOn` Saturday) or is it Friday?

**Proposed Rule (replace the AD-40 body):**
> `streakDay(e)` for a counted (non-voided, not lock-ignored) `source = main` learn event is:
> - (a) for `dated` events, `e.learnedOn` **iff** `e.learnedOn == civilDate(e.recordedAt, tz)`; otherwise the event counts toward progress but not the streak;
> - (b) for `catchUp` events, `e.learnedOn` iff `e.learnedOn ∈ lockedDays(L)` for the lock `L` immediately preceding `e.recordedAt`, and `e.recordedAt ∈ catchUpWindow(L)`;
> - (c) `beforeTracking` events never count.
>
> Streak-restoring events written by undo keep the original event's `recordedAt` in a field `originalRecordedAt`, and rule (b) is evaluated against it. `lockedDays(L)` = the civil dates D (learner tz) for which `JewishCalendar(D).isAssurBemelacha()`; the day on which the lock starts is not a locked day. `catchUpWindow(L)` = the union of non-locked intervals from `L.end` until the end of the first civil day after `L.end` that contains no locked instant. Consecutive locks' pending cards stack, and each card has its own window computed this way. All three functions live in `lib/domain/learner_state/` and are the only implementation.

### H3 — change_log enforcement is not sound for owners, idempotent for tutors, or spoof-proof

**Pairs and holes**

- `existsAfter(change_log/{lastChangeId})` is satisfied by **reusing an old id**: an owner write can mutate `sub_tracks` with an unchanged or stale `lastChangeId` and log nothing. It is also satisfied by an entry for a *different* entity.
- **Replay:** if a story tightens the rule to "change_log newly created" (`!exists(...)`), the SDK's replay of a committed-but-unacknowledged batch fails, because the log doc now exists. That is a permanent rejection (AD-30).
- **Tutor path:** the Admin SDK bypasses rules entirely, so the rule protects nothing. Callable retries after a client timeout re-run with a server `at` or `recordedAt`: either the second `create()` fails with ALREADY_EXISTS and surfaces as an error, or it produces a duplicate with a new id.
- **Actor spoofing:** an owner batch can write `actor: {role: tutor, displayName: 'Rav Cohen'}` on `change_log` or `learning_events`. History attributes the change to the rebbe, and AD-39 fires a push.

**Proposed Rule (append to AD-38 and AD-46):**
> **Owner rule for a governed doc write:**
>
>     request.resource.data == resource.data                        // identical replay
>     || ( request.resource.data.last_change_id != resource.data.last_change_id
>          && !exists(change_log/$(newId))
>          && existsAfter(change_log/$(newId))
>          && getAfter(change_log/$(newId)).data.entity_id == docId
>          && getAfter(change_log/$(newId)).data.actor.uid == request.auth.uid
>          && getAfter(change_log/$(newId)).data.actor.role == 'owner' )
>
> **Client-created** `change_log` and `learning_events` require `actor.uid == request.auth.uid` and `actor.role == 'owner'`. `role == 'tutor'` is writable only by Admin SDK. `recordedAt` and `at` must be timestamps `<= request.time` (inherited SR-3).
>
> **Tutor callables** run a Firestore transaction that `create`s the log entry and event under the client-supplied ULID and writes the governed doc. If the ULID already exists with the same `actor.uid` and `entity_id`, the callable returns the existing result as success (idempotent retry). Server-stamped fields are taken from the existing doc on retry.

### H4 — LWW and undo semantics clobber concurrent edits and are undefined for creates

**Pairs**

- **Parent edits `ratePerWeek` offline; the tutor edits `ground` online.**
  - **Story P:** writes the full doc with `set(merge:false)` from the parent's cache. The tutor's ground change is silently lost, while history shows both. That is "LWW by sync order" at *document* granularity.
  - **Story T:** uses field `update`, and both survive.
  - Both comply.
- **`before` is stale:** it is the parent's cached pre-image, not the server's. **Undo** (AD-38, "applies `before` as a new logged mutation") of the tutor's change after a later parent edit writes the tutor's `before` over the parent's newer fields. Undo of the parent's offline change writes a `before` that never existed on the server.
- **Undo of a create** (`before = null`): `sub_tracks` forbids delete, and `goals` currently allows it. One story deletes; another tombstones.
- **Undo of a tutor-created learn event** is a void. Undo of that undo is a copy; with C3 unresolved, points diverge.

**Proposed Rule (replace AD-38 sentences 1 and 5):**
> Governed docs are written with field-level `update` (and `set` only on create). `change_log.before` and `after` hold **only the changed fields**. LWW is per field, by server commit order. Undo of entry U writes, as a new logged change, `U.before[f]` for each field f whose current value equals `U.after[f]`. Fields changed since are left alone and listed to the user as "changed since by <actor>". Undo of a create (`before = null`) sets the tombstone (`endedAt` / `ended_at`), never a delete. Undo of a learn event is a void. Undo of a void is a new learn copy with `originalRecordedAt` (H2). There is no void of a void (C3). `ground` is replaced as a whole list. Concurrent ground edits resolve by LWW and both appear in history (accepted per PRD §4.9).

### H5 — Engine inputs are incomplete, unbounded, and differ between devices

**Pairs**

- **Repository story for `learning_events`:** copies the house pattern of SR-4 `list` limit 500 plus the parent AD-4 "recent window" reactive stream.
  - **Engine story:** assumes `events` is the full log (AD-35).
  - Result: past 500 events, the learnt set, tri-state, siyum and forecast silently shrink. A lifetime record is thousands of events per learner.
- **Tutor multi-talmid list (FR-29):** N learners × full logs × lock calendars over full history on one device, inside the tutor's 20 MiB named-app cache (parent AD-18).
- **`today` versus the instant:** the engine takes `today` but not the current instant. FR-23 ("on-track indicator does not change during the lock") and FR-24 (planned list frozen at lock start) need an instant. One team passes the device's `DateTime.now()` date; another passes the learner-timezone date.

**Proposed Rule (amend AD-35 and AD-46):**
> The engine signature is `(events, subTracks, goal, studyDays, settingsHistory, corpus, nowUtc) → LearnerState`. `today = civilDate(nowUtc, learner.tz)`. When `nowUtc` is inside a lock L, the engine evaluates forecast, on-track and the planned list with `nowUtc := L.start` (frozen view). `events` is always the **complete** non-deleted log. The `learning_events` repository exposes `watchAll()`, which pages at SR-4's 500 cap until exhausted and then listens for new docs. It emits nothing (a loading state) until the first full page-through completes. A partial log is never passed to the engine. For FR-29, the list uses the same engine but computes one learner at a time, caches `LearnerState` per learner in memory only, and limits concurrent full-log subscriptions to the visible rows.

### H6 — The tutor permission model contradicts existing policy, and offline tutor capture is impossible

**Pair**

- **Story "Tutor callables" (AD-46):** gates `recordEvent` on some permission key.
  - Existing grants carry per-flag permissions (`can_edit_goals`, `can_edit_stages`) and the W3.43 policy that tutors **cannot** mark live completions.
  - FR-26 says the tutor can do "everything the parent can".
  - One team reuses `can_edit_stages` for sub-tracks; another adds `can_edit_sub_tracks`; a third uses `null` (always allowed). The talmid's parent sees inconsistent permission toggles.
- **Offline:** AD-22 routes tutor mutations through callables, which need the network. PRD §4.9 says "all capture works offline." A tutor ticking on a train either gets an error or (in an optimistic-UI story) a phantom success. AD-22 forbids "pretending to succeed".

**Proposed new AD-50 — Tutor capability and offline posture:**
> A single grant permission `can_edit_learning` (default true on new grants; existing grants migrate to true only by explicit parent action) authorizes every sub-tracks callable: sub-track CRUD, event record and void, goal edit, and governed main-track edits. This supersedes the W3.43 `canMarkLiveCompletion = false` policy **for Mishnayos `learning_events` only**. The supersession is recorded in the parent spine alongside AD-4. Tutor writes are online-only. `TutorWriteService` disables tutor capture controls while offline, with an "online required" message. No optimistic local state is shown for tutor writes. PRD §4.9's offline guarantee applies to owner devices.

### H7 — Two owners of the daily target and the review schedule

**Pair**

- **Engine story (AD-35):** computes `dailyTarget` per FR-19.
- **Planner story:** AD-32 only changes the planner's done-check, so the existing `scheduler_engine` still derives its own daily quota from the goal (`goalType` deadline or pace) and generates that many tasks. The home screen shows the engine's target while the task list has the planner's count.
- **Stage ambiguity:** AD-32 says free-tick events carry no `stage` even when `source = main`, and sub-track events never satisfy a scheduled review.
  - One planner story treats a stage-less learnt mishna as "never entered review" and schedules nothing.
  - Another schedules stage-1 review from the first learn event of any source.

**Proposed Rule (amend AD-32 and AD-35):**
> The planner never computes a quantity. For Mishnayos, it takes `LearnerState.dailyTarget` (deadline goal) or the pace value (pace goal, FR-20) as its per-study-day count, and `LearnerState.schedulableRefs` as its candidate set. It applies only ordering, one masechta at a time (FR-12a), and task generation. Spaced-review stages start only from a `source = main` event carrying `stage = firstStageOrder`. A mishna learnt only through a sub-track, a free tick or before tracking is learnt (not scheduled for new learning) and has no review cycle. `stage` stores `stage_order` (int), not a `stage_definitions` doc id.

---

## Medium

### M1 — Future-start sub-tracks: ground and forecast use different "active" predicates

AD-33 removes from the main schedule only the ground of "sub-tracks active today". FR-6a has a future sub-track contributing capacity from its start date. So a future Rebbe sub-track holding Beitzah leaves Beitzah on the main track now (main-track remaining counts it), *and* its path counts it against capacity. Beitzah is double-counted, and the target is too low. This also silently reverses the PRD's deferred-findings row, "Ground assigned to a future sub-track is unavailable to the main track until then."

**Rule:** define three predicates in `lib/domain/learner_state/` and forbid ad-hoc checks.
- `holdsGround(s, today)` = `!endedAt && today <= windowEnd` (so it includes future sub-tracks, per the PRD).
- `inForecast(s, today)` = `holdsGround` and the capacity interval is non-empty.
- `onHome(s, today)` = `!endedAt && windowStart <= today <= windowEnd`.

Main-track remaining and the schedulable set use `holdsGround`.

### M2 — Window dates are timestamps and day arithmetic is ambiguous

The Consistency Conventions make `windowStart`/`windowEnd` Firestore timestamps, while every day computation is civil-local (AD-41). Converting with the device timezone makes AD-44's `days(...)` differ between a New York tutor and a Jerusalem parent. AD-44 also does not say whether ends are inclusive.

**Rule:** `window_start` and `window_end` are `YYYY-MM-DD` civil dates in the learner's timezone, inclusive on both ends. `days([a,b]) = b − a + 1` for a ≤ b, otherwise 0. `windowLengthDays = windowEnd − windowStart + 1`. With no deadline (FR-20), capacity is not computed.

### M3 — The deadline goal: uniqueness under offline concurrency, and corpus versus curriculum scope

- AD-43's "command layer rejects a second" cannot stop a parent (offline) and a tutor (online) each creating one. `goalDocId` falls back to non-unique ids, so two deadline goals exist, and "the engine reads only that goal" is undefined.
- The existing `goal_type`, `target_percent` and `curriculum_id` fields do not map to AD-43's `type = deadline over whole curriculum`.
- Existing `curriculum_scopes` can restrict a Mishnayos track to a subset. AD-42 says the corpus is the whole Content DB. One epic uses the scope, another does not.

**Rule:** the deadline goal is the doc `goals/mishnayos_deadline` (fixed id), with `goal_type = 'deadline'`, `target_date` (a civil date string), `last_change_id` and `ended_at`. A second create is structurally an update of the same doc (LWW, logged). The engine corpus is `ContentDb.mishnayos ∩ curriculum_scope` if a Mishnayos scope exists, otherwise the whole curriculum. The same set drives FR-14, FR-19 and siyum.

### M4 — "Siyum fires once" needs state that AD-33 forbids storing

A derived masechta-complete flag re-fires on every device and after void-then-relearn. Otherwise one story stores a flag, which violates "nothing else is stored". FR-17 needs an explicit decision.

**Rule:** the engine derives `completedMasechtos` and `firstCompletedAt` (the earliest completion instant from counted events). The celebration shows once per device per masechta, recorded in a profile-scoped local preference key `siyum_seen_<masechta>` (a UI convenience per parent AD-27). Un-completion by a void never retracts a shown celebration.

### M5 — `actor.role` cannot distinguish parent from child

Parent and child share the owner uid. FR-4 ("the child can re-date only within the catch-up window") and FR-27 ("who") need that distinction. One story reads the profile `mode`; another the parent-PIN session.

**Rule:** `actor.role ∈ {parent, child, tutor}`. `parent` is set only while the parent-PIN session is unlocked (existing `ProfileScopedPreferenceKeys` PIN namespace); otherwise the role is `child`. Rules accept `{parent, child}` for owner writes (per H3's owner-actor rule). Child limits are enforced in `LearningCommands`.

### M6 — Location keeps two owners through the transition

AD-37 moves location to the profile, but the notification scheduler (`inIsraelProvider`) and the lock overlay read `SacredTimePreferences`. A story that migrates only the capture gate leaves reminders and the overlay on device prefs. That is two owners, contrary to parent AD-27.

**Rule:** AD-37 also requires that every reader of `SacredTimePreferences` (notification scheduler, lock overlay, `sacred_window_repository`) read the profile fields. The prefs keys are deleted on first run after migration, and there is one provider (`learnerLockSettingsProvider(profileId)`).

### M7 — `subtrack_forecast_vs_actual` has no command to emit from

A sub-track usually ends by its window passing, which is derived and involves no command. `LearningCommands` never sees it. Multiple devices would each emit or none would.

**Rule:** the event is emitted by `LearningCommands` on explicit end/delete, and on *Add next year* for the predecessor. Window expiry without either emits nothing (the metric is measured on explicitly closed years). This is documented as a limitation of SM-5.

---

## Low

- **L1 — Tutor ticks silently ignored.** The tutor's device gate uses the tutor's clock, while the callable stamps server time. With a skewed device, the tutor sees success and the engine ignores the event. **Rule:** the callable returns the stamped `recordedAt`. `TutorWriteService` re-runs `CaptureGate` against it and surfaces "not recorded — Shabbos/Yom Tov at the learner's location" when it is locked.
- **L2 — Dangling voids.** A void can arrive before its target on a device (parent AD-10 is removed). **Rule:** the engine treats voids as a set of `targetId` regardless of whether the target is present. A dangling void is not an error.
- **L3 — `source = 'main'` has no curriculum.** This is safe while only Mishnayos uses `learning_events`. **Rule:** events carry `curriculum_id`, and the engine filters on it.
- **L4 — The history view query.** "`change_log ∪ learning_events` filtered by actor" is unbounded under SR-4. **Rule:** the history view pages both collections by `recordedAt`/`at` descending, 100 per page, merged client-side.

---

## Inherited-AD weakening or contradiction (beyond the declared AD-4 streak supersession)

| Parent AD | How the spine weakens or contradicts it | Required action |
| --- | --- | --- |
| **AD-4 (points half)** | The balance can no longer equal Σ ledger once events are voided or lock-ignored without reversals (C3). | Declare an amendment: the balance is Σ ledger, filtered by the engine's counted events. Record it in the parent spine next to the streak supersession. |
| **AD-6 / SR-4** | AD-46 is silent on the 500-row `list` cap. The engine needs the full log (H5). A story may raise or remove the cap, which weakens SR-4's anti-exfiltration intent. | Keep the cap and page (H5). State it in AD-46. |
| **AD-12 / SR-3** | New timestamp fields (`recordedAt`, `at`) are not declared SR-3-guarded, and `actor` is not guarded (H3). | Add both to the AD-46 rule text. |
| **AD-22** | New callables silently reverse the W3.43 "no live tutor completions" policy. Offline tutor capture risks "pretending to succeed" (H6). | Declare the supersession explicitly (AD-50). Tutor capture is online-only. |
| **AD-3 / AD-23** | The spine's direction is `LearningCommands → data/repositories` concretes from `lib/features/**/domain/`, skipping the feature repository interface layer AD-3 names. The checker will not catch it: it gates only `data/firestore/`. | Either declare the command layer an allowed repository consumer (an amendment) or require `LearningCommands` to depend on interfaces in `lib/domain/learner_state/ports/`. Extend `check_dependency_direction.dart` to gate `data/repositories/` imports from `lib/domain/**`. |
| **AD-27** | Location has two owners during the move (M6). The tutor `audit_log` and `change_log` are two stores of tutor history (C2). | Close as specified in M6 and C2. |
| **AD-30** | Adding the `lastChangeId` rule to collections with unrerouted legacy writers creates permanently rejected queued writes (C2). A `!exists` new-log check breaks replays (H3). | Adopt the C2 same-release reroute and the H3 identical-replay clause. |
| **AD-7** | The spine introduces a deliberate second writer (tutor) without stating the conflict policy. AD-7 says to do so explicitly. | Adopt H4 (per-field LWW by commit order) and reference AD-7 as "remains dormant; conflict policy is AD-38". |

No other inherited AD (AD-1, AD-2, AD-8, AD-9, AD-16, AD-25, AD-26) is contradicted. AD-26 deletion coverage should explicitly include `points_ledger` entries with `event_id` (already profile-scoped, so this is covered once the recursive delete is confirmed).

## Summary of proposed spine edits

| # | Sev | Edit |
| --- | --- | --- |
| C1 | critical | New AD-49: curriculum-scoped cutover plus a consumer inventory and a `LearntStateSource` port |
| C2 | critical | AD-38/46: an enumerated governed-entity set, no client deletes, whitelist `last_change_id`, legacy callables rerouted or rejected, change_log as the only history |
| C3 | critical | Points row plus an AD-4 amendment: `pts_{eventId}`, no reversal docs, balance filtered by the engine's counted set; void targets must be `learn` |
| H1 | high | AD-36/37: pinned constants, learner-timezone iteration, required timezone, lock evaluated with the settings history in force at `recordedAt` |
| H2 | high | AD-40: `streakDay`, `lockedDays` and `catchUpWindow` defined as single functions; `originalRecordedAt` on undo copies |
| H3 | high | AD-38/46: the full owner rule text, spoof-proof actor, idempotent tutor callables |
| H4 | high | AD-38: field-level updates, conditional per-field undo, undo of a create = tombstone |
| H5 | high | AD-35/46: `nowUtc` input, lock-frozen view, complete-log `watchAll()` with a loading gate, FR-29 limits |
| H6 | high | New AD-50: one tutor permission, the W3.43 supersession declared, tutor writes online-only |
| H7 | high | AD-32/35: the planner consumes the engine's target and set; review cycle only from main stage-1 events |
| M1–M7 | medium | Active predicates; civil-date windows; fixed goal id plus scope; siyum-once; actor role; location single owner; the analytics end event |
| L1–L4 | low | Tutor clock verdict; dangling voids; `curriculum_id` on events; paged history |
