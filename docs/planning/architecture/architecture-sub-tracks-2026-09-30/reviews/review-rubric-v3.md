---
title: Review — Sub-tracks architecture spine v3 (good-spine rubric)
target: docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
reviewed: 2026-10-01
lenses: [good-spine rubric, internal consistency, brownfield ratification]
inputs:
  - ARCHITECTURE-SPINE.md (v3)
  - .memlog.md (decisions through 2026-10-01; the tail is treated as settled)
  - reviews/review-rubric-v2.md (N1–N12, R5, R8, R12, R13)
  - reviews/retirement-inventory-v3.md
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md (parent, incl. 2026-09-30 / 10-01 amendments)
  - docs/planning/specs/spec-sub-tracks/SPEC.md, prd-deviations.md
  - docs/planning/prds/prd-sub-tracks-2026-09-30/prd.md (§4)
  - code: learning_tracker/firestore.rules, functions/src/*.ts, lib/data/firestore/doc_ids.dart, lib/data/repositories/*, lib/features/scheduler/**
---

# Review — Sub-tracks spine v3: good-spine rubric

## Verdict

**READY WITH FIXES.** Counts: **Critical 0 · High 4 · Medium 14 · Low 11.**

Every v2 rubric finding is closed (table below). v3 also folds in all of Daniel's settled decisions (#10 unreadable lock, #11 siyum, N-C1 engine-owned programs and position, N-H9 any-curriculum sub-tracks). The memlog decisions are not re-opened here.

Four High gaps would still let Epic 1 stories, or Epic 1 and the sub-track epic, diverge:

- **H1:** the main-track position and schedulable set are not defined consistently with `holdsGround`, FR-12a and `mainTrackRemaining`.
- **H2:** nobody owns spaced-review scheduling, yet AD-50 depends on it.
- **H3:** the AD-38 owner rule can't be enforced for multi-doc `mainTrack*` entities or for the track-removal cascade.
- **H4:** the AD-49 cutover gate contradicts the cutover release it gates.

Each one is fixed by replacement text. No redesign is needed.

Severity: Critical = epics will diverge or lose data. High = real divergence or enforcement hole. Medium = silent area or ambiguous rule. Low = precision, duplication or drift outside the target.

## v2 findings status

| v2 # | Status | Evidence in v3 |
| --- | --- | --- |
| N1 | Closed | AD-50 makes the engine authoritative through `earningEventIds`. AD-46 requires `docId == 'pts_' + event_id` and `existsAfter`. `lifetimeEarned` is filtered and achievements latch. The earning definition has a residual issue (M6), and the review-schedule source is open (H2). |
| N2 | Closed | AD-49 adds binding sequencing (stories 1–4), the cutover release, `check_retired_symbols.dart` and next-release removal. The inventory has an Action column and rows for rules, indexes, `deletes.ts` and tests. Residual issues: the gate is self-contradictory (H4), and `learning_order` is missing (M3). |
| N3 | Closed | AD-34: "A null `window_end` is +∞ in every predicate". |
| N4 | Closed | Schema has `academic_year` and `end_reason`. AD-45 sets limits per profile and curriculum, and *Add next year* sets `academic_year + 1`. |
| N5 | Closed | AD-37 seeds the history at profile creation and falls back to the doc's current values. |
| N6 | Closed | The AD-30 and AD-13 rows are corrected. The AD-8 carve-out and AD-6 Binds are recorded in the parent (parent lines 178–180 and 204–207). A new unrecorded relaxation is raised as M12. |
| N7 | Closed | The Roles convention says the role is a client assertion and an accepted risk. |
| N8 | Closed | AD-47 has one `LearningAnalytics` emitter, including the `TutorWriteService` path. |
| N9 | Closed | AD-52 says storage names and storage enum forms. The ADs use `dated`, `catch_up` and `before_tracking` consistently. |
| N10 | Closed | AD-51 is a retired stub and nothing in the spine references it as live. SPEC CAP-11 still cites it (L9). |
| N11 | Closed | Owner files are named: `lock_constants.dart`, `CatchUpReminderScheduler`, `notifications.ts`, `pin_flow_controller` / `pin_guard` (these match the code), the fixtures path, `writeWithChangeLog` grant check, and the `tutor_grants` schema row. |
| N12 | Closed | The ER edge now reads `CHANGE_LOG }o--|| GOVERNED_DOC : "entity_id / last_change_id"`. |
| R5 | Closed | Via N7. |
| R8 | Closed | Via N11 (`CatchUpReminderScheduler`). |
| R12 | Closed | AD-44 defines `numerator`, `studyDaysToDeadline` and the zero divisor. One FR-19 clause is missing (M14). |
| R13 | Closed in substance | AD-38 track removal is one logged `mainTrack` change plus sub-track tombstones, and never touches events or points. The owner rule can't admit this cascade as written (H3). |

## Checklist walk

| Check | Result |
| --- | --- |
| Fixes the real divergence points for epics | Mostly. Gaps: main-track position (H1), review schedule (H2), erev planned list (M7), calendar programs with sub-tracks (M4), non-deadline goals (M1), track lifecycle fields (M2), tutor-device lock (M10). |
| Every Rule is enforceable and prevents its divergence | AD-38 owner rule (H3). AD-49 gate (H4). AD-46 has no event/log whitelist (M8). AD-53 has no write path for the grant (M9). |
| Nothing Deferred lets two units diverge | Pass. Metric aggregation has one owner (the analytics story). UI behaviours bind through the spec. |
| Ratifies the brownfield codebase | Partly. These are unaddressed: `learning_order` vs `track_learning_order` doc-id separation (M3); `curriculum_tracks.state` / `purged` / `pace_reset_date` / `progress_*` (M2); goals `target_percent` and pace goals (M1); multi-doc governed ids (H3); `tutorEditProfile` (L10); `completion_points_awarder` (M13). |
| Covers CAP-1..CAP-13 | Yes, mapped. CAP-4 depends on H1, CAP-5 on H2 and M6. The capability map lacks a CAP-13 row (L7). |
| Covers prd-deviations #1–#11 | Yes. #7 and #9 have drifted on the spec side (L9). |
| No new AD weakens a parent AD | M12: the AD-54 skew rule relaxes parent SR-3 `created_at <= request.time` on the existing `points_ledger`, and this isn't recorded. L2: AD-15 is relied on but not inherited. |
| Every owned dimension decided, deferred or open | Operations: observability and read cost are undecided (M11). Data retention of `change_log` is unstated (L6). |
| Internal consistency | The AD cross-references resolve. AD-51 is not live. The schema covers AD fields, except that `change_log.entity` values aren't enumerated and the `tutor_grants` scope is mislabelled (L1). The capability map is current except for L7. |

## High

### H1 — High — Main-track position and the schedulable set contradict `holdsGround`, FR-12a and `mainTrackRemaining`

**Evidence:**

- AD-33 says "Main-track position = the first leaf in the governed `mainTrackOrder`, at or after `mainTrackProgram.tracking_start_ref`, with no counted `learn` event."
  - This doesn't exclude leaves that a `holdsGround` sub-track holds. If School holds the next masechta, the home position points into School's ground (FR-10).
  - It doesn't apply FR-12a's "returned ground that lies before the current masechta is scheduled next, *after the current masechta completes*". As soon as earlier ground returns, it becomes "first unlearnt" and takes over the position mid-masechta.
  - Leaves before `tracking_start_ref` (after a manual jump) are never positions. Yet `mainTrackRemaining` (AD-44 / PRD FR-19 "not learnt and not assigned") still counts them, so the daily target includes leaves the planner never schedules.
- `schedulableRefs` is listed as an engine output (AD-35) but is never defined.
- AD-49 gives the planner "FR-12a's one-masechta rule", so the engine (position) and the planner (current masechta) each decide which masechta is current.

The home row, the planner and the forecast epics will each pick a different reading.

**Replacement (AD-33 Rule, replace the "Main-track position" and "manual jump" bullets):**

> - `schedulableRefs` (per curriculum) = the leaves of the AD-42 corpus, in governed `mainTrackOrder`, that have no counted `learn` event and are not held by any `holdsGround` sub-track. `mainTrackRemaining = |schedulableRefs|`.
> - The **current unit** is the FR-12a unit (the `ContentIndex` level FR-12a schedules one at a time: masechta for Mishnayos) containing the later, by time, of:
>   - the leaf of the latest counted `source = main` `dated` / `catch_up` learn event (by `original_recorded_at ?? recorded_at`);
>   - `tracking_start_ref` (by its last `change_log.at`).
>
>   It applies only while that unit still has a schedulable leaf.
> - **Main-track position** = the first schedulable leaf of the current unit. If there is none: the first schedulable leaf at or after `tracking_start_ref`. If there is none: the first schedulable leaf in `mainTrackOrder`.
> - The engine is the only implementation of the current unit and the position. The planner takes them from `LearnerState` and applies only layout (AD-49).
> - A manual jump is a governed change to `tracking_start_ref`. Ordering is at node-entry granularity only.

**AD-49 Planner bullet, replace "applies only ordering, FR-12a's one-masechta rule and task layout" with:**

> "applies only task layout over `LearnerState`'s position, current unit and `schedulableRefs`"

### H2 — High — Spaced-review scheduling has no single owner, but AD-50 points depend on it

**Evidence:**

- AD-50: a stage > first earns "if the engine scheduled that stage for that leaf on `civilDate(recorded_at)`".
- AD-35's output list has no review schedule (learnt set, positions, `schedulableRefs`, `programAssignments`, `dailyTarget`, …).
- AD-49 gives the planner no review input either.
- Today `scheduler_engine.dart` computes due reviews from `stage_definitions` (`delay_days`, `schedule_type`) and completions.

After cutover, either the planner keeps its own review scheduler (a second implementation, which AD-35 forbids) or nobody computes reviews. Points eligibility and the today list will disagree on which reviews were due.

**Replacement (AD-35 Rule, "Per curriculum" bullet, add an output):**

> …, `reviewsDue(date)`: the (leaf, `stage_order`) pairs that `mainTrackStages` schedules on that civil date, from AD-32 cycles. This is the only review scheduler. …

**AD-49 Planner bullet, add:**

> It takes `reviewsDue(today)` for chazara tasks.

**AD-50, second earning bullet:**

> per (leaf, stage > first), the earliest counted `source = main` event carrying that stage whose `learned_on` is a date on which `reviewsDue` contained (leaf, stage).

### H3 — High — The AD-38 owner rule can't be enforced for multi-doc entities or for the track-removal cascade

**Evidence:**

- The owner rule requires "the logged entry's `entity` matches the collection and its `entity_id` matches the doc's key", with key = `curriculumId` for `mainTrack*`.
- In the code, `track_learning_order`, `study_day_configs`, `stage_definitions` and `curriculum_scopes` docs are keyed `{curriculumId}_{ref | day | stage_order | level_value}` (`doc_ids.dart` `trackLearningOrderDocId`, `studyDayConfigDocId`, `stageDefinitionDocId`, `curriculumScopeDocId`). The doc id is never the curriculum id.
- AD-38 track removal writes `ended_at` on goals, stages, study days and so on under one `mainTrack` entry, so `entity` ≠ the collection's entity.
- One entity = one batch, but nothing bounds the doc count. A track removal, or a reorder of a per-ref `track_learning_order`, can exceed Firestore's 500-write batch. `existsAfter` can't span chunks.

A rules author must either loosen the check or reject legitimate writes. The capture epic and the tutor epic will choose differently.

**Replacement (AD-38 Rule, Owner rule third bullet):**

> - the logged entry's `entity` is the one owning the collection (`subTrack`↔`sub_tracks`, `goal`↔`goals`, `mainTrack`↔`curriculum_tracks`, `mainTrackOrder`↔`track_learning_order`, `mainTrackProgram`↔`profile_programs`, `mainTrackStudyDays`↔`study_day_configs`, `mainTrackStages`↔`stage_definitions`, `mainTrackScope`↔`curriculum_scopes`, `learnerSettings`↔`learner_profiles`). Its `entity_id` equals the doc id for `subTrack` and `goal`, `profileId` for `learnerSettings`, and `request.resource.data.curriculum_id` for every `mainTrack*` entity. Every `mainTrack*` doc carries `curriculum_id`.

**Replacement (AD-38 Rule, Track removal bullet):**

> - **Track removal** is one logged `mainTrack` change that sets `ended_at` on the `curriculum_tracks` doc only, plus one logged `subTrack` tombstone per non-ended sub-track of that curriculum. While a curriculum's track has `ended_at`, the engine and every reader treat its other governed docs as ended. Re-adding clears the track's `ended_at` through a logged change and keeps the prior config. It never touches `learning_events` or `points_ledger`. No Admin hard delete of governed docs remains outside account or profile deletion.

**Add to AD-38 "An entity is the unit of one user action":**

> One entity write, including its `change_log` entry, fits one batch (≤ 450 docs). `mainTrackOrder` is stored at node-entry granularity (AD-33), so it fits. Sub-track tombstones from a track removal chunk at ≤ 450, each chunk carrying its own entries.

### H4 — High — The AD-49 cutover gate contradicts the cutover release

**Evidence:**

- AD-49 says that in the cutover release, `firestore.rules` "denies all client writes to the retired collections" (so the `match /completions` and other blocks remain).
- The same release's `check_retired_symbols.dart` "fails on any retired collection-name string … in `lib/`, `functions/src/` or `firestore.rules`".
- The rules matches, `deletes.ts` entries and indexes are removed only "in the release after". The gate therefore fails on the release it gates.
- One story will weaken the checker. Another will delete the matches early, which leaves the collections under the catch-all deny, so the "deny then remove" step has no meaning.

**Replacement (AD-49 Rule, cutover release, third sub-bullet):**

> - `tool/check_retired_symbols.dart` (CI) fails on any retired collection name, type, service or callable in `lib/`, `functions/src/` or `firestore.rules`, except a checked-in allowlist that holds exactly: the deny-all `match` blocks for the retired collections in `firestore.rules`, and their entries in `functions/src/deletes.ts` and `firestore.indexes.json`. The release after empties the allowlist.

## Medium

### M1 — Medium — Goals other than the deadline goal are undefined (pace goals, `target_percent`)

**Evidence:**

- The code's `goals` carry `goal_type` (`deadline` / `pace` / `none`), `target_percent` (default 100), `pace_value`, `pace_unit` and `pace_granularity`. A curriculum may have several goals (`firestore_goal_repository.dart`).
- AD-43 fixes only the deadline goal's id. Pace goals still use random ids, so concurrent offline creates give two pace goals.
- AD-49's planner takes "`LearnerState.dailyTarget` (or the pace rate)", but AD-35 outputs no pace rate.
- AD-44's `numerator` assumes the whole corpus, so a 50% `target_percent` deadline is silently ignored by one epic and honoured by another.

**Replacement (AD-43 Rule, append):**

> A curriculum has at most one pace goal, at `goals/{curriculumId}_pace` (`goal_type = 'pace'`, `pace_value`, `pace_unit`, `pace_granularity`). `LearnerState` outputs `paceRate` (leaves per study day) from it. The planner uses `dailyTarget` when a deadline exists, else `paceRate`, else nothing. `target_percent` is retired: a deadline goal always covers the whole AD-42 corpus. The codec and the `goals` whitelist drop it in Epic 1 (R13).

Add `goals/{curriculumId}_pace` to the Storage Schema.

### M2 — Medium — `curriculum_tracks` lifecycle and stored-progress fields are not addressed

**Evidence:**

- `curriculum_tracks` carries `state` (`active` / `retired` / `archived`), `state_changed_at`, `purged` / `purged_at` (a tombstone), `pace_reset_date`, `last_reorder_at` (reorder amnesty), and stored `progress_*` / `program_progress` / `self_paced_progress` (rules whitelist; `tutor_writes.ts:55-57`).
- AD-38 introduces `ended_at` as the tombstone, and AD-33 forbids persisted derived state.
- Nothing says whether an `archived` track is "removed", whether `pace_reset_date` resets AD-35 velocity, or whether `progress_*` is still written.

**Replacement (AD-38 Rule, append to Track removal):**

> `curriculum_tracks.state` remains the user-facing lifecycle (`active` / `retired` / `archived`) and is a `mainTrack` field. The engine computes only for curricula whose track is `active` and not ended. `ended_at` replaces `purged` / `purged_at`. `pace_reset_date`, `last_reorder_at`, `progress_schema_version`, `progress_computed_at`, `progress_model`, `program_progress` and `self_paced_progress` are retired. AD-35 velocity has no reset. They leave the codec, the whitelist and `tutor_writes.ts` in R13.

### M3 — Medium — The `learning_order` merge has no semantics, and the collection is never retired

**Evidence:**

- The rules comment says `learning_order` (curriculum-scoped, used by `scheduler_engine` and `whole_curriculum_order`) and `track_learning_order` (per-track sedarim/masechtos) were deliberately kept separate because they share a doc-id universe (`{curriculumId}_{ref}`).
- AD-38 and R13 "merge" them but never say which order wins for a (curriculum, ref) present in both, or at what level.
- `learning_order` appears neither in AD-49's retired list, nor in R14 / the cutover deny, nor in the checker. Its match keeps allowing owner `create, update, delete`.

**Replacement (AD-38 Rule, `mainTrackOrder` line):**

> `mainTrackOrder` (`track_learning_order/*`, one doc per (curriculum, node ref) at the node-entry level, field `user_sort_order`). In Epic 1, `learning_order` is retired: its writers and readers move to `track_learning_order`. Greenfield, so no data is carried over.

**AD-49 "The one write target", add `learning_order` to the retired list.** Add it to R14 (deny writes in the cutover release, remove in the release after) and to `check_retired_symbols`.

### M4 — Medium — Calendar-program curricula with sub-tracks are undefined

**Evidence:**

- Sub-tracks are allowed on any curriculum (memlog N-H9).
- `programAssignments(date)` is "refs a calendar program assigns per civil date".
- FR-10 says held ground is not scheduled by the main track. Neither AD-34 nor AD-35 says whether `holdsGround` removes refs from `programAssignments`, or whether `dailyTarget` / shortfall apply to a calendar-program curriculum.

**Replacement (AD-35, append to `programAssignments`):**

> For a curriculum on a calendar program, `programAssignments(date)` is the program's fixed assignment and is not reduced by `holdsGround`. Held refs render greyed in that day's list. `dailyTarget`, capacity and shortfall are not computed for that curriculum (the program sets the pace). Sub-tracks there affect only learnt state, positions and reports.

(This is a decision. If Daniel prefers the opposite, replace the text with "reduced by `holdsGround`", but the spine must say one or the other.)

### M5 — Medium — `original_recorded_at` is applied in AD-36 but not in AD-40, AD-50 or import

**Evidence:**

- AD-36 tests a lock against `original_recorded_at ?? recorded_at`.
- AD-40's `dated` rule uses `civilDate(recorded_at)`. An undo-of-void copy, or an imported event (fresh `recorded_at`, `original_recorded_at` preserved, AD-49), therefore loses its streak day.
- AD-50 orders earning by (`recorded_at`, id), so an undo copy moves behind later events.
- AD-49 import gives "fresh ULIDs", but void `target_id`s still point at the old ids.

**Replacement:** define once in AD-31:

> `effectiveAt(e) = original_recorded_at ?? recorded_at`. Every derivation that uses an event's time (AD-36 lock, AD-40 `streakDay`, AD-50 ordering, AD-35 projection) uses `effectiveAt`.

Edit AD-40 to "`learned_on == civilDate(effectiveAt(e))`" and AD-50 to "by (`effectiveAt`, id)".

**AD-49 Backup, append:**

> Import remaps each void's `target_id` to the fresh ULID of its imported target. Exported `change_log` is kept for the record and not re-imported.

### M6 — Medium — AD-50's first-learn earning disagrees with "newly makes a ref learnt"

**Evidence:**

- AD-50 says "per leaf, the earliest counted **main** learn event". A leaf first learnt via a sub-track and later on the main track earns on the main event.
- prd-deviations #5 and SPEC CAP-5 say an event earns only if it "newly makes a ref learnt".
- For `before_tracking` the two readings coincide (no `pts_` exists). For sub-track-first leaves they differ, so the points and capture epics will disagree.

**Replacement (AD-50, first earning bullet):**

> per leaf, the earliest counted learn event of any source and date state, by (`effectiveAt`, id), but only if that event is `source = main` and `dated` or `catch_up`.

### M7 — Medium — The erev planned list has two owners

**Evidence:**

- AD-35 makes the engine output "the erev planned list for upcoming locked days".
- AD-49 makes the planner the only owner of task layout.
- The erev list (screens #09, with live controls) and the planner's day list for the same date can differ.

**Replacement (AD-35, "Per curriculum" bullet):** delete "and the erev planned list for upcoming locked days".

**Add to AD-49 Planner:**

> The erev planned list for each upcoming locked day is the planner's task list for that date, evaluated live over the current `LearnerState`.

### M8 — Medium — `learning_events` and `change_log` have no field whitelist or type checks in rules

**Evidence:**

- AD-46 gives `sub_tracks` a `hasOnly` whitelist but gives `learning_events` / `change_log` only create-only and actor checks.
- AD-52's "exact" field set therefore holds only in codecs. One rules story will add whitelists and one won't, and a client can write arbitrary fields or a non-enum `kind` / `date_state`.

**Replacement (AD-46 Rule, second bullet, append):**

> Both use a `hasOnly` whitelist per AD-52 and type checks: `kind ∈ {learn, void}`, `date_state ∈ {dated, catch_up, before_tracking}`, `recorded_at` / `at` timestamps, `learned_on` matching `^\d{4}-\d{2}-\d{2}$` or null, and `target_id` present iff `kind == void`.

### M9 — Medium — AD-53's "explicit parent action" has no write path

**Evidence:**

- `tutor_grants` client writes are denied (`firestore.rules` `allow create/update/delete: if false`).
- `tutor_invites.ts` sets `permissions` only in `inviteTutor`. No callable updates an existing grant's permissions.
- AD-53 requires existing grants to gain `can_edit_learning` by parent action.
- prd-deviations #7 says "default true on new grants", while AD-53 says "only by explicit parent action, for new and existing grants alike". One epic will pre-check the invite box and another won't.

**Replacement (AD-53, "One permission" bullet, append):**

> It is set by the parent through `inviteTutor` (the checkbox on the invite form, pre-checked, per prd-deviations #7) or through a new parent-only callable, `updateTutorGrantPermissions`, in `functions/src/tutor_invites.ts`. That callable also removes the legacy keys from existing grants.

### M10 — Medium — The lock on a tutor device with many learners is undefined

**Evidence:**

- AD-36 says "the app is covered by the full-screen `SacredTimeLockOverlay`" using the learner's settings.
- A tutor device shows up to 20 learners (FR-29), possibly in different time zones. Nothing says whether the overlay covers the whole app, one learner's screens, or how FR-29 rows behave for a locked learner. The lock epic and the tutor epic will each choose.

**Replacement (AD-36, "During a lock", append):**

> On a tutor device, a learner's screens are covered while that learner is locked. The FR-29 list shows a locked learner's row as "Shabbos / Yom Tov" with no data or controls. The tutor's own active profile, if any, locks the whole app on its own settings.

### M11 — Medium — Operations: observability and read cost are undecided

**Evidence:**

AD-54 covers environments, deploy, tests, indexes, limits, skew, recovery and perf. It does not decide:

- **Observability.** Nothing says how `writeWithChangeLog` failures, `onChangeLogCreated` push failures, permanently rejected batches, or engine loading stalls are logged or alerted. Crashlytics exists (`crashlytics_service.dart`).
- **Read cost.** FR-29 does complete paged reads: 20 learners × ~40,000 events is ~800k document reads per cold list open. That can't fit the 20 MiB cache the perf gate cites. `billing_kill_switch.ts` exists, so cost is a live operational concern.

The perf gate also doesn't say whether network fetch counts toward its "< 1 s per learner".

**Replacement (AD-54 Rule, add bullets):**

> - **Observability:** callables and the trigger log structured errors (entity, error code, no learner data) to Cloud Logging. Client-side rejected batches, callable failures and engine load timeouts go to Crashlytics as non-fatal errors with enums only. No alerting beyond the existing billing kill switch.
> - **Read cost:** the engine reads a learner's full log once per app session, then listens only for newer events (`recorded_at > last seen`). The perf gate measures recompute from a warm in-memory log. A cold first load is measured separately and recorded, not gated. This read cost is accepted.

### M12 — Medium — AD-54's skew rule relaxes parent SR-3 on an existing collection without recording it

**Evidence:**

- The current `points_ledger` rule requires `created_at <= request.time` (parent AD-12 posture, SR-3).
- AD-54 changes it to `<= request.time + 10 min`. That weakens an inherited bound, and "Amendments to the parent" doesn't list it.
- The `ended_at` stamped by owner writes (AD-38 tombstones) is a client timestamp but isn't in the skew list.
- Legacy `updated_at` on governed docs has no stated fate.

**Replacement (Amendments to the parent, add, and record in the parent at AD-12):**

> - **AD-12 / SR-3** → relaxed by AD-54 for learning and governed batches: client timestamps may be up to `request.time + 10 min`.

**AD-54 Clock skew:** replace the list with "(`recorded_at`, `at`, `ended_at`, `points_ledger.created_at`)".

**Append to AD-38 Writes:**

> `updated_at` and `synced_at` are retired from governed docs (LWW is by commit order).

### M13 — Medium — The spine inventory and `retirement-inventory-v3.md` disagree, and a points writer is missing

**Evidence:**

- The spine calls `reviews/retirement-inventory-v3.md` "the full file-level list", but the two disagree on Actions:
  - The file's line 39 says governed-collection rules "remove match (release after cutover)"; spine R14 says "amended".
  - The file marks repositories the spine deletes (R1, R5, R8) as "rewire → LearningCommands".
  - The file marks TypeScript `tutor_writes.ts` as "rewire → LearningCommands".
- Neither lists `lib/features/learning/data/repositories/completion_points_awarder.dart`, today's `points_ledger` writer at completion, which AD-50 replaces.

**Replacement (Retirement Inventory intro, append):**

> Where the review file's "Proposed Action" differs from a row here, this table wins.

Add to R2: `completion_points_awarder` → "rewire → `LearningCommands` (AD-50 `pts_` attach), then delete".

### M14 — Medium — AD-44 drops ground held by a sub-track that isn't `inForecast`, and omits one FR-19 clause

**Evidence:**

- A future sub-track starting after the deadline is `holdsGround` but not `inForecast`. Its ground leaves `mainTrackRemaining` (AD-34) and is in no shortfall sum (AD-44 sums over `inForecast`). Those leaves vanish from the target.
- FR-19's "not counted if another active sub-track holding it is forecast to reach it" is missing from AD-44, which only says "counted once".

**Replacement (AD-44, `numerator` bullet):**

> `numerator = mainTrackRemaining − Σ expectedNewGround(s) + Σ shortfall(s)` over `holdsGround` sub-tracks of the curriculum. A sub-track whose capacity interval is empty has capacity 0. A shortfall leaf is counted once, and not at all if another `holdsGround` sub-track holding it reaches it within capacity.

## Low

### L1 — Low — Schema gaps

**Evidence:** `change_log.entity` values aren't enumerated in the Storage Schema. They appear only in AD-38, in camelCase, while other enums are snake_case. The `tutor_grants/{grantId}` row sits under "profile-scoped unless noted", but the collection is top-level (`firestore.rules:140`).

**Replacement:**

- Schema `change_log` row: `entity` | `subTrack`\|`goal`\|`mainTrack`\|`mainTrackOrder`\|`mainTrackProgram`\|`mainTrackStudyDays`\|`mainTrackStages`\|`mainTrackScope`\|`learnerSettings` | ✓.
- `tutor_grants` row: prefix "(top-level) `tutor_grants/{grantId}`".

### L2 — Low — AD-15 is relied on but not inherited

**Evidence:** the siyum "profile-scoped local key", the achievement latch key and the Roles convention ("parent AD-15") depend on parent AD-15, which is absent from the inheritance table and `binds`.

**Replacement (inheritance table row; add AD-15 to `binds`):**

> AD-15 | Siyum-shown and achievement-latch keys use `ProfileScopedPreferenceKeys` (`*_p<profileId>`). The parent-PIN session is the role source.

### L3 — Low — `settingsHistory` query shape vs "no indexes"

**Evidence:** AD-35 says "complete read of `change_log` where `entity == 'learnerSettings'`". Paged by `at`, that needs a composite index, which AD-54 says is not added.

**Replacement (AD-35):**

> …`where entity == 'learnerSettings'`, paged by document id (ULID order; no composite index).

### L4 — Low — AD-40 calendar inputs are under-specified

**Replacement (AD-40):**

> `lockedDays(L)` = civil dates D with `JewishCalendar(D, inIsrael: in_israel in force at L.start).isAssurBemelacha()`. `civilDate(t)` uses the `time_zone` in force at t (AD-37).

### L5 — Low — Backup import semantics

Covered by the M5 replacement (void remap; `change_log` not re-imported). It's listed separately so the AD-49 story can cite it.

### L6 — Low — `change_log` retention is unstated

**Evidence:** `tutor_grants/*/audit_log` has a 12-month purge (`audit_log_purge.ts`). Without a rule, someone may extend the purge to `change_log`, which would break undo.

**Replacement (AD-38 History, append):**

> `change_log` is kept for the profile's lifetime and deleted only with the profile or account (AD-26). No purge job touches it.

### L7 — Low — Capability map gaps

**Replacement rows / edits:**

- Add: `| One learning store (CAP-13) | Epic 1, Retirement Inventory, check_retired_symbols | AD-49, AD-52, AD-54 |`.
- Capture: add AD-47, AD-50, AD-53.
- Tutor: add AD-35, AD-54.

### L8 — Low — Points amount integrity is undeclared

**Evidence:** AD-46 checks the `pts_` id and the event's existence but not the `amount`. Non-event entries are unconstrained. AD-50 claims to prevent "points farming".

**Replacement (Roles convention, append):**

> `points_ledger` amounts are client-asserted under the same accepted risk.

Alternatively, AD-46 can require `amount == get(point_configs/{curriculum}_{stage}).points`.

### L9 — Low — Spec-side drift (outside this target; for the spec update)

- SPEC CAP-11 cites AD-51. Use "AD-38, AD-39 and AD-54".
- SPEC Constraints: "20 learners × 10,000 events" → "20 learners × (40,000 leaf + 200 node) events".
- SPEC Constraints: the "spine v2 review fixes" line is stale.
- SPEC CAP-13 lists three collections. Add `bookmarks`.
- SPEC Open Questions are both resolved by AD-36 / Siyum convention. Remove them.
- prd-deviations #9: the set should add `mainTrackProgram` (memlog N-C1).
- prd-deviations #7: align with M9.

### L10 — Low — `tutorEditProfile` is not covered

**Evidence:** `tutorEditProfile` (`tutor_writes.ts:969`) rewrites the full learner-profile doc (`set(merge:false)`), which now holds the AD-37 settings. AD-38's reroute list omits it.

**Replacement (AD-38, Tutor path, append):**

> `tutorEditProfile` writes only `display_name`, `avatar` and `mode` with a field-level merge, and never writes AD-37 settings keys. Settings changes use `writeWithChangeLog` (`learnerSettings`).

### L11 — Low — Siyum unit levels per curriculum are undefined

**Evidence:** AD-49 says "per unit (seder, masechta, sefer)", and SPEC CAP-5 says "once per masechta". Nothing says which `ContentIndex` levels celebrate in each curriculum.

**Replacement (Siyum convention, append):**

> Celebrated units are the `ContentIndex` levels marked as siyum levels in the curriculum's hierarchy asset (Mishnayos: masechta and seder).
