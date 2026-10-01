---
title: 'Adversarial review v3 — Sub-tracks architecture spine'
target: docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
target_version: 'v3 (updated 2026-10-01)'
reviewed: '2026-10-01'
method: 'Build pairs of epic/story units that each obey every AD as written and still build incompatibly. Re-test every v2 adversarial and rubric finding. Check the result against learning_tracker/ (lib/, functions/src/, firestore.rules).'
verdict: 'NOT READY: 0 critical, 5 high, 8 medium, 4 low. Every v2 finding is Closed or Partly closed and none is Open. All new holes are wording-level fixes, and none reopens a user decision.'
---

# Adversarial review v3: Sub-tracks architecture spine

## Verdict

**NOT READY.** Counts: **0 critical, 5 high, 8 medium, 4 low.**

v3 folds in every v2 finding. Twenty-four of the 29 v2 adversarial and rubric findings are now Closed, and the other five are Partly closed. The new holes come from four places where v3 states a decision without saying how it behaves at the boundaries:

1. **"An entity is one user action."** Real user actions span several entities, such as add-track, remove-track and reorder. The `docId.field` key collides across collections.
2. **The merged `learning_order` and the new main-track inputs.** These are named, but the merged order shape is not defined, and neither is how position, remaining and calendar assignments relate to each other.
3. **Backup replay.** Fresh `recorded_at` values collide with the `streakDay` and earning rules. The export list still carries `points_ledger` raw.
4. **Fields and stores the inventory never saw.** Examples are the `curriculum_tracks.state` lifecycle, `last_reorder_at` amnesty and `pace_reset_date`.

None of the fixes needs a new user decision. Each finding below gives replacement Rule text. Accepted deviations (`prd-deviations.md` #1–#11) and the user decisions in `.memlog.md` are not re-flagged.

---

## 1. v2 findings status

### Adversarial v2

| v2 | Status | Closing AD in v3 | Residual |
| --- | --- | --- | --- |
| N-C1 Calendar programs and stored main-track intent | **Partly** | AD-33 (derived position, jump = `tracking_start_ref`), AD-35 (`programAssignments`), AD-38 (`mainTrackOrder`, `mainTrackProgram` governed), AD-39 push set, AD-49 planner | The merged order shape is undefined (A-H2). Position, remaining and schedulable disagree (A-H3). `programAssignments` has no calendar input, backlog or amnesty rule (A-H4). |
| N-H1 Event grain / envelope | Closed | AD-31 (leaf for `dated`/`catch_up`, node only for `before_tracking`), AD-54 perf gate | Un-learning one leaf under a node event (A-M2) |
| N-H2 Inventory misses string-keyed consumers; backup | **Partly** | AD-49 `check_retired_symbols`, backup replay, retired callables; R11, R12 | The replay semantics are contradictory and incomplete (A-H5). `learning_order` is missing from the cutover deny list (A-M8). |
| N-H3 Multi-doc entities | **Partly** | AD-38 "an entity is the unit of one user action", `docId.field` keys | Cross-entity actions and the cross-collection key collision (A-H1). `entity_id` is matched against "the doc's key", not the doc's `curriculum_id` (A-H1). |
| N-H4 Create branch / deterministic-id creates | Closed | AD-38 (merge-set field writes, create only via `writeWithChangeLog`, guarded create-undo) | The owner path still "claims create" in two places (A-L2) |
| N-H5 Mixed profile doc | Closed | AD-37 (owner-rule branch only on settings keys or `last_change_id`) | – |
| N-H6 Earning decided by writer | Closed | AD-50 `earningEventIds` | Stage earning rebuilds past schedules from current config (A-M6). "Earliest main" vs "newly learnt" (A-L3). |
| N-H7 `pts_` skew; AD-30 mis-cited | Closed | AD-54 skew rule, `created_at = recorded_at`, recovery item; Inherited AD-30 row | – |
| N-H8 `settingsHistory` completeness and seed | Closed | AD-35 complete read, AD-37 seed entry | Which `time_zone` a civil date uses (A-M4) |
| N-H9 Evaluation unit | Closed (per user decision) | AD-33, AD-35 (per profile, keyed by curriculum), AD-40 per-curriculum streak, AD-45 per curriculum | Surfaces that need one profile-level streak (A-M5) |
| N-M1 Overlay vs gate windows | Closed | AD-36 `lockWindows` is the only window function | Whose lock covers a device that serves several learners (A-M7) |
| N-M2 Undo launders a lock-ignored event | Closed | AD-36 `original_recorded_at ?? recorded_at`, no undo | `streakDay` still uses raw `recorded_at` (A-H5) |
| N-M3 Legacy permission keys | Closed | AD-53 | – |
| N-M4 Track deletion | **Partly** | AD-38 track removal is a logged `mainTrack` tombstone | It crosses entities and its keys collide (A-H1). The `state` retired/archived lifecycle runs in parallel (A-M1). |
| N-L1 FCM tokens after relock | Closed | AD-39 (`pin_flow_controller` / `pin_guard`) | – |

### Rubric v2

| v2 | Status | Closing AD in v3 | Residual |
| --- | --- | --- | --- |
| N1 Points for counted, not earning, events | Closed | AD-50, AD-46 `pts_` rules | A-M6, A-L3 |
| N2 AD-49 enforcement and sequencing | **Partly** | AD-49 Epic 1 order, cutover release, `check_retired_symbols`; R1–R15 with Action | The rules deploy timing within Epic 1 is undefined. `retirement-inventory-v3.md` contradicts R-row actions (A-M8). |
| N3 Null `window_end` | Closed | AD-34 | – |
| N4 Limits not computable | Closed | AD-45, schema `academic_year`, `end_reason` | – |
| N5 `settingsHistory` seed | Closed | AD-37 | A-L2 (seed shown as an undoable "create") |
| N6 Parent consistency | Closed | Inherited table, Amendments list | – |
| N7 Client-asserted role | Closed | Consistency → Roles | – |
| N8 Tutor analytics owner | Closed | AD-47 | – |
| N9 AD-52 wording | Closed | AD-52; ADs now use `dated` / `catch_up` / `before_tracking` | – |
| N10 AD-51 duplicate | Closed | AD-51 retired | – |
| N11 Owner files | Closed | AD-36, AD-39, AD-45, AD-53, Reminders | `functions/src/notifications.ts` and `lib/features/learning/domain/commands/` are targets that do not exist yet. That is acceptable. |
| N12 ER diagram | Closed | `GOVERNED_DOC` edge | – |
| R12 Numerator / study days | Closed | AD-44 | – |
| R13 Track deletion owner | Closed | AD-38 track removal | A-H1 |

---

## 2. New findings

### A-H1 — High — An "entity = one user action" rule cannot log actions that span entities, and `docId.field` keys collide across collections

**The two units**

- **Add-track story.** It follows AD-38 and the current flow, `TrackCreationService.createTrack`, which in one user action writes `curriculum_tracks`, `stage_definitions`, `study_day_configs`, `curriculum_scopes` and `profile_programs` (and today also `bookmarks`). The story logs one `mainTrack` entry for all of them, because "an entity is the unit of one user action". The owner rule then rejects the batch: "the logged entry's `entity` matches the collection" fails for `stage_definitions` and the other non-track docs.
- **Second add-track story.** It writes five entries, one per entity, in one batch. That passes the rules. It produces five history rows and five separate undos. On the tutor path it sends four FCM pushes (`mainTrack`, `mainTrackProgram`, `mainTrackStudyDays`, and `goal` if set; AD-39). A partial undo leaves a track with no stages.
- **Track removal.** This is the same contradiction written into the spine itself. AD-38 calls it "one logged `mainTrack` change" that sets `ended_at` on every governed doc of the curriculum, but the owner rule ties each doc to an entry whose `entity` matches that doc's collection.
- **Reorder.** Today the reorder writes `track_learning_order` docs **and** `curriculum_tracks.last_reorder_at` in one batch. That is two entities, `mainTrackOrder` and `mainTrack`, so the same choice between one entry and several comes up again.
- **Key collision.** `curriculum_tracks/{c}` and `profile_programs/{c}` both have doc id = `curriculumId`. A track-removal entry keyed `docId.field` holds `mishnayos.ended_at` twice, so before/after cannot be restored and undo is ambiguous.
- **Entity-key check.** For `mainTrack*` "the key is the `curriculumId`", but multi-doc entities have ids such as `{c}_{order}` and `{c}_{ref}`. One rules story compares against the doc id, which denies every multi-doc write. Another compares against `request.resource.data.curriculum_id`.

**Evidence:**
- `lib/features/tracks/setup/domain/services/track_creation_service.dart:76-160`
- `lib/data/repositories/firestore_track_learning_order_repository.dart:370-399` ("Co-writes `curriculum_tracks.last_reorder_at` in the same atomic batch")
- `lib/data/firestore/doc_ids.dart:218,374` (both ids are `curriculum_id`)
- AD-38 owner rule and the track-removal bullet

**Replacement Rule (AD-38, replaces the "An entity is the unit…" bullet and the owner-rule entity check):**
> - **Entry and action.** A `change_log` entry covers exactly one governed entity. A user action that touches several entities writes one entry per entity in **one** batch or callable transaction. All of those entries carry the same `action_id`, which is the ULID of the first entry. History groups entries by `action_id` into one row. Undo is offered per `action_id` and writes one new action that undoes each member entry under the per-field rule. AD-39 sends at most one push per `action_id`.
> - **Keys.** `before` and `after` are keyed `{collection}/{docId}.{field}`.
> - **Owner-rule entity check.** The logged entry's `entity` matches the doc's collection. Its `entity_id` equals the doc id for `subTrack`, `goal` and `learnerSettings`. For `mainTrack*` it equals `request.resource.data.curriculum_id`, which is required and immutable on those docs.
> - **Named multi-entity actions.** Add track, remove track (with its `subTrack` tombstones), re-add track, and reorder. Reorder logs `mainTrackOrder`. `last_reorder_at` is retired (see A-H4).
>
> Schema: `change_log` adds `action_id` (ULID, required).

---

### A-H2 — High — "`learning_order` merges into `track_learning_order`" has no defined shape, and the two doc-id formulas collide

**The two units**

- **Order-merge story (R13).** It copies `learning_order` writes into `track_learning_order` using the existing formula `{c}_{ref}`. `DocIds.learningOrderDocId` and `trackLearningOrderDocId` produce **identical** ids for the same `(curriculum, ref)`. That is why the two were split into separate collections; the rules comment says "a shared collection would compute identical doc-ids". A whole-curriculum reorder now overwrites the `user_sort_order` of the sedarim/masechtos order for the same ref, and the reverse also happens.
- **Engine story.** It implements "first leaf in the governed `mainTrackOrder`". Today the scheduler reads **only** `learning_order` (`SchedulerEngine._buildOrderedRefs`), while `track_learning_order` holds per-level (seder, masechta) positions. With both in one collection and no discriminator, one engine sorts leaves by a flat `user_sort_order`. Another applies the order per level, with parents ordered before children. Their positions and daily plans differ.
- **Reset.** `learning_order` reset today deletes every doc, and AD-38 denies deletes. One story tombstones every doc. Another writes `user_sort_order = null`.

**Evidence:**
- `lib/data/firestore/doc_ids.dart:289-343`
- `firestore.rules:512-551`
- `lib/features/scheduler/domain/services/scheduler_engine.dart:636-660`
- `lib/data/repositories/firestore_learning_order_repository.dart` (reset deletes)

**Replacement Rule (AD-33, plus the AD-52 schema row):**
> `mainTrackOrder` docs are `track_learning_order/{c}_{level}_{ref}` with `curriculum_id`, `level` (ContentIndex level), `ref` and `user_sort_order`.
>
> The governed order is computed by one function, `orderedLeaves(corpus, orderDocs)`, in `lib/domain/learner_state/`. At each level it sorts siblings by `user_sort_order` when a non-ended doc exists for that level. Siblings without a doc follow in ContentIndex order. It then recurses into each child level.
>
> Reset to default is one logged `mainTrackOrder` change that sets `ended_at` on every order doc of the curriculum.
>
> `learning_order` is a retired collection. It is listed in AD-49's cutover deny list and in `check_retired_symbols`, and it is removed in the release after.

---

### A-H3 — High — Main-track position, remaining and the schedulable set are three definitions that disagree

**The two units**

- **Forecast story (AD-44, PRD FR-19).** `mainTrackRemaining` = corpus leaves not learnt and not `holdsGround`. This includes unlearnt leaves **before** `tracking_start_ref`.
- **Position/planner story (AD-33).** Position = the first unlearnt leaf "at or after `tracking_start_ref`". The planner schedules from the position, so leaves skipped by a manual jump are never offered again. Yet they stay in the numerator. The daily target is inflated for good, and "on track" never comes back.
- **Position vs held ground.** AD-33's position does not exclude `holdsGround` ground, but `schedulableRefs` does. The home row shows position = Berakhos 2:1 (held by school) while the planner schedules Shabbos 1:1.
- **`schedulableRefs`** is named in AD-35 and AD-49 but never defined. Is it every unlearnt, unheld leaf, or only those at or after the position?

**Evidence:** AD-33 (position bullets), AD-34 ("Main-track remaining and the schedulable set use `holdsGround`"), AD-44 numerator, PRD FR-19 ("Main-track remaining = mishnayos not learnt and not assigned to any active sub-track").

**Replacement Rule (AD-33, replaces both position bullets):**
> Per curriculum, with `O = orderedLeaves(corpus, mainTrackOrder)` and `start = tracking_start_ref`:
> - `schedulableRefs` = leaves of `O` at or after `start`, with no counted learn event, and not in the ground of any `holdsGround` sub-track. They keep `O` order.
> - **Main-track position** = the first element of `schedulableRefs`.
> - `mainTrackRemaining` = `|schedulableRefs|`.
> - Unlearnt leaves before `start` are **skipped**: they appear in progress as unlearnt, but are excluded from the forecast and the plan until a governed `tracking_start_ref` change brings them back.
>
> All four are computed only by the engine.

---

### A-H4 — High — `programAssignments(date)` has no calendar input, no leaf grain, no backlog or amnesty rule, and no interaction with sub-tracks or the deadline

**The two units**

- **Engine story.** It computes `programAssignments` in `lib/domain/learner_state/`. The calendar tables come from `CalendarProgramService` / `LocalCalendarEngine`, a data-layer source, and the engine signature has no calendar input. One story injects a port, which is forbidden in a pure engine. Another precomputes the calendar in the provider, which puts a second quantity source outside the engine.
- **Grain.** Daf Yomi assigns `"Chullin 25"`, a node, and today's projection resolves it to leaves (`resolvedOrFallbackProgramRefs`). One engine returns node refs, and the capture story then writes `dated` events with a node ref, which AD-31 forbids. Another returns leaves.
- **Backlog and amnesty.** Today the planner emits overdue program days, minus those before `curriculum_tracks.last_reorder_at` (reorder amnesty, clamped to the anchor), and anchors on `activated_at` when there is no `tracking_start_date`. AD-49's planner "never computes a quantity". One planner story drops the overdue and amnesty logic, so missed days vanish. Another keeps it, which makes the planner a second owner of program quantity.
- **Sub-tracks.** If school holds Berakhos and Daf Yomi assigns Berakhos 2, `schedulableRefs` excludes it but `programAssignments` includes it. One planner shows it and another hides it.
- **Deadline.** If a deadline goal exists on a calendar curriculum, the engine still computes `dailyTarget` and on-track status (FR-18/FR-29) from AD-44, while the planner shows the calendar's assignment. The tutor list and the home screen then give different "on track" verdicts.

**Evidence:**
- `lib/features/scheduler/domain/services/daily_task_projection_service.dart:80-95,130-260`
- `lib/features/scheduler/domain/projection/amnesty_cutoff.dart`
- AD-35 signature
- AD-49 planner bullet

**Replacement Rule (AD-35, plus the R4 row):**
> - **Calendar input.** The engine takes `calendars`, a map `program_id → [(civilDate, nodeRef)]`, loaded by the provider from `CalendarProgramService` and passed in as data.
> - **Assignment grain.** `programAssignments(date)` returns **leaves**: each assigned node expanded by `expandGround`, intersected with the corpus. Ground held by `holdsGround` sub-tracks is **not** removed; calendar programs ignore sub-tracks.
> - **Backlog.** `programBacklog(today)` = assigned leaves dated before `today` and on or after `amnestyFrom`, with no counted learn event. `amnestyFrom = max(tracking_start_date, civilDate(at of the latest mainTrackOrder or mainTrackProgram change_log entry))`.
> - **Retired anchors.** `curriculum_tracks.last_reorder_at` and `activated_at` are no longer anchors. A missing `tracking_start_date` is a validation error.
> - **No deadline arithmetic.** For a curriculum with a calendar program, `dailyTarget`, shortfall and on-track come from the calendar (assigned − learnt through today), and AD-44 is not computed. A deadline goal on such a curriculum is rejected by validation.
> - **The planner** lays out `programAssignments(today) ∪ programBacklog(today)` and computes nothing else.
>
> Engine input addition: the `mainTrackOrder` and `mainTrackProgram` entries' `at`, which come from the same complete `change_log` read as `settingsHistory`, widened to those entities.

---

### A-H5 — High — Backup replay (and undo copies) break streak and earning because `recorded_at` is fresh, and the import boundary is undefined

**The two units**

- **Import story (AD-49).** It replays events through `LearningCommands`: fresh ULID, `actor` = importer, `original_recorded_at` kept. It also re-creates governed docs as logged creates.
- **Streak story (AD-40).** A `dated` event counts iff `learned_on == civilDate(recorded_at)`, using the raw `recorded_at`. Every imported `dated` event now has `recorded_at` = import time, so **every restored streak drops to 0**. AD-36 already uses `original_recorded_at ?? recorded_at` for the lock, but AD-40's dated branch, AD-50's earning order "(`recorded_at`, id)", AD-50's `pts_ created_at`, and AD-35's velocity do not. The undo copy of a void (AD-38) has the same defect: undoing yesterday's mistaken void does not restore yesterday's streak day.
- **Points story.** `DataExportImportService._profileCollectionNames` still exports `points_ledger`, `reward_redemptions` and the governed collections raw. One import story restores `points_ledger` raw. The `pts_{oldId}` entries fail AD-46's `existsAfter(learning_events/{event_id})` because the ids are fresh, so the whole batch is rejected. Another story drops `points_ledger`, so spends are lost and the balance is inflated.
- **Id remapping.** With fresh ULIDs, a void's `target_id`, an event's `source` (a sub-track ULID) and `change_log.entity_id` must be remapped. AD-49 does not say they are. One story remaps them. Another leaves voids dangling, which AD-31 tolerates silently, so voided learning is resurrected.
- **`change_log` on import.** It is "exported" but its import is unspecified. Replayed `learnerSettings` entries get a fresh `at`, so the lock history before the import collapses to the import-time seed (AD-37: "instants before the first entry use that entry's `after`"). That is the retroactive re-evaluation that v1-H1 ruled out.
- **"Logged creates" on the owner path** contradicts AD-38's "the owner path never claims create" (see A-L2).

**Evidence:**
- `lib/features/settings/domain/services/data_export_import_service.dart:77-96,216-226`
- AD-40 `streakDay`
- AD-50 earning order
- AD-46 `pts_` rule
- AD-37 pre-history rule

**Replacement Rule:**

AD-31, add:
> `at(e) = original_recorded_at ?? recorded_at` is the event's effective instant. Every rule that reads an event's time uses `at(e)`: the lock (AD-36), `streakDay` and `catchUpWindow` (AD-40), earning order (AD-50), velocity (AD-35) and history order. `recorded_at` is used only by the AD-54 skew rule.

AD-49 backup, replace:
> **Export.** `learning_events`, `sub_tracks`, `change_log`, the governed collections, and non-event `points_ledger` entries (spends and adjustments), plus `reward_redemptions`.
>
> **Import** is one replay in `LearningCommands`, in this order:
> 1. `learnerSettings` entries in original order, each written with `original_at`, as an update to the import-time seed;
> 2. governed entities, as logged updates (never claimed as creates);
> 3. sub-tracks, with fresh ULIDs and an id map;
> 4. `learn` events, with fresh ULIDs, `source` remapped, `original_recorded_at = at(old)`, and `pts_` attached per AD-50;
> 5. `void` events, with `target_id` remapped, dropping any void whose target is unmapped;
> 6. non-event `points_ledger` entries, as new entries.
>
> `pts_` entries from the export are never imported. Other `change_log` entries are not replayed; the importing action's own entries are the history.

Schema: `change_log` adds `original_at` (timestamp, import only). `settingsHistory` orders entries by `original_at ?? at`.

---

### A-M1 — Medium — `curriculum_tracks` has a second lifecycle (`state`) and stored or derived fields the spine never names

**The two units:** the track-removal story sets `ended_at` (AD-38). The existing `retireTrack` / `archiveTrack` set `state = retired|archived` ("hidden, sibling data untouched"), and `activeTracks` filters on `state`.

- One engine story treats a curriculum as active iff `!ended_at`. Another treats it as active iff `state == active`. A retired track's sub-tracks keep `holdsGround`, and its streak and forecast keep computing in one build but not the other.
- `pace_reset_date` (the "Recovery Action") feeds today's pace calculators. AD-35 velocity ignores it. One story drops the button; another keeps writing a field nothing reads.
- `progress_model`, `program_progress`, `self_paced_progress` and `progress_computed_at` are stored derived progress. They are whitelisted in rules and `tutor_writes.ts`, which contradicts AD-33's "never persisted".

**Evidence:**
- `lib/data/repositories/firestore_curriculum_track_repository.dart:336-395`
- `firestore.rules:459-480`
- `functions/src/tutor_writes.ts:55-57`

**Replacement Rule (AD-38 `mainTrack`, plus the R13/R14 rows):**
> `curriculum_tracks` lifecycle is `ended_at` only. `state`, `state_changed_at`, `pace_reset_date`, `last_reorder_at`, `activated_at` (except as display), `progress_*`, `program_progress` and `self_paced_progress` are retired fields. They are removed from the codec, the rules whitelist and `tutor_writes.ts` in the cutover release, and listed in `check_retired_symbols`.
>
> Retire, archive and remove are one action, *end track*: a logged `mainTrack` change per A-H1. The engine evaluates only curricula whose `curriculum_tracks` doc is not ended. Their sub-tracks, forecast and streak are not computed; their events still count for lifetime and siyum.
>
> "Reset pace" is retired. If it is kept, it is a governed `mainTrack` field that AD-35 velocity uses as a lower bound on its window.

---

### A-M2 — Medium — No rule for un-learning one leaf covered by a node `before_tracking` event

**The two units:** lifetime marking writes one `before_tracking` node event for Masechta Berakhos (AD-31). Later the parent un-marks perek 3, or uses the old "reset completion" UI, which AD-49 says "becomes a void".

- **Story A** voids only leaf events for the perek-3 leaves. The node event still covers them, so they stay learnt and the action silently does nothing.
- **Story B** voids the node event, which un-learns all nine perakim, and stops there.
- **Story C** voids the node event and re-adds nodes for perakim 1–2 and 4–9. Only this one is correct, and nothing requires it.

**Replacement Rule (AD-31, add):**
> `unlearn(curriculum, leafSet S)` is the only un-learn command. It voids every counted learn event whose ref is in `S`. For each counted node event `N` covering some of `S`, it voids `N` and writes `before_tracking` events for the maximal ContentIndex nodes covering `expand(N) \ S`, copying `N`'s `original_recorded_at ?? recorded_at`. All of this is one batch, chunked per AD-54. Undo of `unlearn` voids the re-issued events and re-copies the voided ones.

---

### A-M3 — Medium — `completion_number` and the siyum "shown" key are underdefined

**The two units:** AD-49 says the engine derives `completion_number` per unit, but gives no rule. Today it comes from unit-scoped ledger entries ("2nd siyum of Mishnayos").

- **Story A** sets completion k when every leaf has ≥ k counted learn events. Stage reviews inflate the count, so chazara cycles become "siyumim".
- **Story B** counts only non-stage events.
- **Lifetime marking** cannot express "finished twice before" unless two node events for the same node count as two.
- **The shown key.** It is cleared "when the unit leaves the set". A device that is offline across void → re-complete never sees the unit leave the set, so it never re-celebrates, while the parent's phone does.

**Replacement Rule (Consistency → Siyum, add):**
> For unit U, `count(U, leaf)` = the number of counted learn events covering the leaf, with node events counting once per covered leaf. `completion_number` k is reached when `min over leaves of count ≥ k`, and `first_completed_at(k)` is the `at(e)` of the event that achieved it.
>
> Celebration fires only for k = 1 (FR-17). Higher k appear only in the siyumim timeline.
>
> The per-device shown key is `(profileId, U, first_completed_at(1))`, so a new completion after a void has a new key and celebrates on every device, observed or not.

---

### A-M4 — Medium — Civil dates do not say which `time_zone` they use

**The two units:** AD-41 says civil dates are "in the learner's `time_zone`", and AD-36 says the lock uses "settings in force".

- **Streak story A** computes `civilDate(recorded_at)` and `lockedDays` with the **current** `time_zone`. A family that moves from Jerusalem to New York retroactively shifts every past event's day, and streaks break or merge.
- **Streak story B** uses the zone in force at `at(e)`.
- The same split affects AD-50's "scheduled on `civilDate(recorded_at)`" and the validation of `learned_on` at capture.

**Replacement Rule (AD-41, add):**
> `civilDate(instant)` uses the `time_zone` in force at that instant per `settingsHistory`. `today` uses the current `time_zone`. `lockedDays(L)` uses the settings in force at `L.start`.

---

### A-M5 — Medium — Per-curriculum streak, but today's profile-level streak consumers have no rule

**The two units:** AD-40 makes the streak per curriculum (user decision). R6 rewires `streak_service`, `streak_alert_service` and `streak_milestone_analytics_observer` "→ `LearnerState` streak", and none of them has a curriculum today.

- **Dashboard story** shows the max across curricula.
- **Alert story** fires one "streak at risk" notification per curriculum.
- **Analytics story** emits milestones without a curriculum key.
- **FR-29 tutor row** picks the first curriculum.

All four comply, and they show the child four different "streak" numbers.

**Replacement Rule (AD-40, add):**
> `LearnerState` has no profile-wide streak. Every streak surface (home, alert, milestone analytics, tutor row, report) is rendered per curriculum and keyed by `curriculum_id`. The streak-at-risk alert fires per curriculum whose main track is not ended, at most once per civil day per curriculum. The milestone analytics payload carries the `curriculum_id` enum.

---

### A-M6 — Medium — Stage earning rebuilds past schedules from today's config

**The two units:** AD-50 says a stage > first event earns "if the engine scheduled that stage for that leaf on `civilDate(recorded_at)`". The engine has only the current `mainTrackStages`, study days and order; only `learnerSettings` has history.

- The planner on day D showed stage 2 of X under the old intervals, and the child did it.
- A week later the parent edits the stage intervals. The engine now decides X was not scheduled on D, so `pts_` stops earning and the balance and `lifetimeEarned` drop retroactively.
- A different points story caches "scheduled" at write time. That contradicts "the engine is the only authority".

**Replacement Rule (AD-50, replace the stage bullet):**
> Per (leaf, stage k > first): the earliest counted main event carrying stage k earns iff a counted main event carrying stage k−1 for that leaf has an earlier `at(e)`. Eligibility depends only on events, never on config or schedule.

---

### A-M7 — Medium — Whose lock covers a device that serves several learners

**The two units:** AD-36 says the full-screen overlay covers "the app" and that every reader uses `learnerLockSettingsProvider(profileId)`. The Reminders convention scopes to "each profile active on the device" and excludes tutor devices, but the overlay has no such scoping.

- **Overlay story A** locks on the **selected** profile, so switching to a sibling in another zone escapes the lock.
- **Overlay story B** locks on the union of all profiles on the device.
- **On a tutor device** with 20 learners, story A locks per viewed learner, so the tutor's whole app goes dark on one learner's Shabbos. Story B locks on any of them.

**Replacement Rule (AD-36, add):**
> **Owner devices:** the overlay window is the union of `lockWindows` over every learner profile of the signed-in account. **Tutor devices:** there is no overlay. `CaptureGate` blocks writes per learner, and a learner whose lock is active renders as "locked" in FR-29 and on that learner's screens.

---

### A-M8 — Medium — Epic 1 deploy staging and the inventory file contradict the R-rows

**The two units:**

- **Deploy timing.** AD-49 story 2 ships "AD-46 rules, `writeWithChangeLog`, rerouted callables". AD-54 deploys rules in a gated CI step before "the app release that depends on it". The R13 owner-repository reroute is a later story (step 3). If story 2's governed-collection rules deploy when it merges, every existing owner write to `goals`, `curriculum_tracks` and the rest lacks `last_change_id` and is denied until R13 lands. One team deploys per story; another holds everything for the cutover release.
- **The inventory file contradicts the spine.** `retirement-inventory-v3.md` (named as "the full file-level list") says:
  - governed-collection rules → "remove match (release after cutover)", where R14 says "amended";
  - bookmarks, sentinel and `streak_events` → "rewire → LearningCommands", where R6, R8 and R10 say delete;
  - `ZmanimWindowService` → "rewire → LearnerState", where R9 says `lockWindows`.

  A story following the file deletes the governed rules.
- **`learning_order`** is retired by the merge but is not among AD-49's four retired collections, its cutover deny rule, or `check_retired_symbols`.

**Replacement Rule (AD-49 sequencing, add):**
> Stories 1–3 deploy nothing to production. Their rules and functions are verified on the emulator only, and AD-54's deploy step runs once, in the cutover release (story 4). The R-table Actions are binding over `reviews/retirement-inventory-v3.md`, which is a file locator only. Retired collections are `completions`, `learning_ledger`, `streak_events`, `bookmarks` and `learning_order`.

---

### A-L1 — Low — Achievement latch is per device

AD-50 latches an achievement "using a profile-scoped local key". The parent's phone latched "Gold" before a void lowered `lifetimeEarned`. The child's tablet, which was not open, never latched it, and the tutor view has no key, so the three show different achievement states. Today unlock is a pure threshold check with "no historical unlock records" (`achievements_overview_provider.dart:80-89`).

**Rule (AD-50):**
> The latch is a record, not a convenience (AD-27). `LearningCommands` appends the unlocked achievement id to `preferences/gamification_settings.unlocked_achievement_ids` (array union) the first time the threshold is crossed on any device. Every surface reads that list.

### A-L2 — Low — The owner path still claims "create"

AD-38 says "the owner path never claims create". Yet AD-37's profile creation writes "a `learnerSettings` **create** entry", and AD-49's import writes "logged creates". Undo of a create sets `ended_at`, and the profile doc has no `ended_at`. One history story offers *Undo* on the seed entry and another hides it.

**Rule (AD-37 / AD-38):**
> The seed is an ordinary entry with `before` all-null. Undo is never offered for an entry whose `entity == learnerSettings` and whose `before` is all-null. Import writes updates (A-H5).

### A-L3 — Low — "Earliest counted main event" vs "newly makes the ref learnt"

AD-50 earns "the earliest counted **main** learn event" per leaf. `prd-deviations` #5 says an event earns only if it "newly makes a ref learnt". Take a leaf learnt at school (sub-track) and later ticked at home. One points story pays, following AD-50, and another does not, following #5.

**Rule (AD-50):**
> Per leaf, the earliest counted learn event of **any** source, by `at(e)`. It earns only if its `source = main`.
>
> If the intent is that home learning after school still earns, amend deviations #5 instead. Either way, state one of the two.

### A-L4 — Low — The merged `mainTrackOrder` and `mainTrackProgram` need `change_log` history as engine input, but AD-35's read covers only `learnerSettings`

This follows from A-H4's `amnestyFrom`. If amnesty is instead dropped, delete A-H4's backlog clause and this item.

**Rule (AD-35):**
> `settingsHistory` becomes `intentHistory`: the complete paged read of `change_log` where `entity in ['learnerSettings','mainTrackOrder','mainTrackProgram']`. That is a single `in` filter, so no composite index is needed.

---

## 3. Reality checks performed

| Claim | Source |
| --- | --- |
| `learning_order` and `track_learning_order` ids collide by design | `lib/data/firestore/doc_ids.dart:289-343`; `firestore.rules:527-535` |
| The scheduler reads only `learning_order` | `scheduler_engine.dart:636-660` |
| Reorder co-writes `curriculum_tracks.last_reorder_at`; amnesty is planner logic | `firestore_track_learning_order_repository.dart:379-399`; `daily_task_projection_service.dart:80-95,205-235` |
| Program days are node refs resolved to leaves in the planner | `daily_task_projection_service.dart:170-245` |
| Add-track writes 5 or more governed collections | `track_creation_service.dart:76-160` |
| `curriculum_tracks/{c}` and `profile_programs/{c}` share doc id | `doc_ids.dart:218,374` |
| Track `state` lifecycle, `resetPace`, stored `progress_*` | `firestore_curriculum_track_repository.dart:336-395`; `firestore.rules:459-480`; `tutor_writes.ts:55-57` |
| Backup exports `points_ledger`, `learning_order` and governed collections raw | `data_export_import_service.dart:77-96` |
| Today's streak is profile-wide with a consecutive-local-day rule | `streak_reducer.dart` |
| Achievements are a pure threshold over lifetime earned, with no stored unlocks | `achievements_overview_provider.dart:80-130` |
| `tutorEditProfile` rewrites the whole profile doc in a transaction (no settings clobber; not a finding) | `tutor_writes.ts:1012-1037` |
