---
title: 'Adversarial review v2 — Sub-tracks architecture spine'
target: docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
reviewed: '2026-10-01'
method: 'Construct pairs of epic/story-level units that each obey every AD literally yet build incompatibly; reality-check against learning_tracker/ source (lib/, functions/, firestore.rules); re-test every v1 finding'
verdict: 'NOT READY — v2 fixes most of v1 (14 fixed, 7 partly, 0 open), but the app-wide cutover (AD-49) opened new holes: 1 critical, 9 high, 4 medium, 1 low'
---

# Adversarial review v2 — Sub-tracks architecture spine

## Verdict

**NOT READY.** Counts: **1 critical, 9 high, 4 medium, 1 low.**

v2 is a large improvement. Every v1 critical and high finding now has an AD, and the Mishnayos-only parts of the design (AD-31..AD-48) would hold up in epic breakdown. Most of the new holes come from one decision: generalizing to every curriculum (AD-49). The spine still sizes, governs and inventories as if Mishnayos were the only curriculum.

- **Calendar programs and stored main-track position.** These are not part of the engine or the governed set, and AD-49's planner rule forbids the calendar path the code uses today.
- **The retirement inventory.** It misses consumers that reach the old collections by string name. The compiler cannot catch these.
- **Per-leaf events at non-Mishnayos scale.** These break the AD-54 envelope. AD-31 also lets a node ref stand in for its leaf refs.
- **The AD-38 owner rule.** It does not fit multi-doc entities, deterministic-id creates, or the mixed-field profile doc.
- **Points earning.** Earning is decided by each writer's local view, so the AD-50 filter cannot stop a double earn.

Accepted PRD deviations (`spec-sub-tracks/prd-deviations.md` rows 1–9) are not re-flagged.

## v1 findings status

| v1 | Status | Evidence (v2 AD) |
| --- | --- | --- |
| C1 completions cutover scoped to planner | Partly | AD-49 goes app-wide and adds a retirement inventory. The inventory is incomplete (N-H2). |
| C2 ungoverned writers bypass change_log | Partly | AD-38 enumerates governed entities, denies deletes, and reroutes writers. `profile_programs`, `bookmarks` and `learning_order` stay ungoverned (N-C1). Admin hard-deletes remain (N-M4). |
| C3 points diverge from engine | Partly | AD-50 adds `pts_{eventId}`, no reversals and a filtered balance, and AD-31 restricts void targets. Earning is still decided by the writer (N-H6), and the `created_at` skew mismatch is new (N-H7). |
| H1 lock re-evaluated with current settings | Partly | AD-36/37 add `settingsHistory` and pinned constants. The completeness and seeding of `settingsHistory` are undefined (N-H8). |
| H2 streak under-specified | Fixed | AD-40 |
| H3 change_log enforcement unsound | Partly | AD-38 owner rule and AD-46 actor checks. There is no create branch, and the profile doc's mixed fields are unaddressed (N-H4, N-H5). |
| H4 LWW/undo clobber | Fixed | AD-38 (field-level update, per-field undo, tombstone on create-undo). Deterministic-id creates are a new hole (N-H4). |
| H5 engine inputs incomplete | Partly | AD-35 covers the complete event log. `settingsHistory` (from `change_log`) has no completeness rule (N-H8). |
| H6 tutor permission / offline | Partly | AD-53. The legacy per-key permissions are not reconciled (N-M3). |
| H7 two owners of daily target | Partly | AD-49 planner rule. Calendar-program tracks have no compliant path (N-C1). |
| M1 active predicates | Fixed | AD-34 |
| M2 civil-date windows | Fixed | AD-41, AD-44 |
| M3 deadline goal id + scope | Fixed | AD-43, AD-42 |
| M4 siyum once | Fixed | Consistency Conventions → Siyum |
| M5 actor role | Fixed | Consistency Conventions → Roles; AD-46 |
| M6 location two owners | Fixed | AD-37. The window function is still split (N-M1). |
| M7 forecast-vs-actual emit point | Fixed | AD-47 |
| L1 tutor clock verdict | Fixed | AD-36 |
| L2 dangling voids | Fixed | AD-31 |
| L3 curriculum on events | Fixed | AD-52 schema |
| L4 paged history | Fixed | AD-38 |

Inherited-AD table from v1: AD-3/AD-23 is fixed (ports and checker), AD-7 is fixed, and AD-4/AD-22 are amended in the parent. **AD-30 is mis-cited**: see N-H7.

---

## Critical

### N-C1 — Calendar programs and stored main-track intent have no home in the engine

**Pair**

- **Planner epic (AD-49, literal):** "The planner never computes a quantity: it takes `LearnerState.dailyTarget` (or the pace rate) and `schedulableRefs`." The epic deletes the calendar-program path, which today produces Daf Yomi-style tasks from a calendar anchored at `profile_programs.tracking_start_date`. Every calendar-program learner loses their daily plan.
- **Planner epic (keeps the path):** keeps `programCalendarSchedule`. That violates AD-49's "only ordering, FR-12a, layout".
- **Position:** AD-35 says the engine computes "positions". The engine signature has no input for order (`track_learning_order`, `learning_order`), for the program start (`profile_programs.tracking_start_ref`), or for the manual jump pointer (`bookmarks`). `bookmarks` is a stored main-track position that `CompletionOrchestrator` advances, and AD-49 retires the orchestrator.
  - **Story A** derives the position in the engine in ContentIndex order. It ignores the custom order and the jump.
  - **Story B** keeps reading `bookmarks`. Nothing advances it any more, so it freezes.
- **Governance:** `profile_programs`, `bookmarks` and `learning_order` are main-track intent but are not AD-38 governed entities. `tutorSetProfileProgram` and `tutorUpsertBookmark` change what the learner studies with no `change_log`, no history and no FR-27 push. `profile_programs` and `learning_order` still allow owner delete.

**Evidence:**
- `lib/features/scheduler/domain/services/daily_task_projection_service.dart:127-160` (program path; done-check = first-stage completions at :121-125)
- `lib/features/learning/domain/repositories/bookmark_repository.dart` (`advanceBookmark` "called automatically after marking a completion")
- `lib/features/learning/domain/services/completion_orchestrator.dart:86`
- `firestore.rules:486,512-523,615-631`
- `functions/src/tutor_writes.ts:782,842`

**Rule (amend AD-35, AD-38, AD-49):**
> Main-track intent is `mainTrack` (`curriculum_tracks`), `mainTrackOrder` (`track_learning_order` **and** `learning_order`, which merge into one collection in this release), `mainTrackProgram` (`profile_programs`: `program_id`, `tracking_start_date`, `tracking_start_ref`), study days, stages, scope and goal. All of them are AD-38 governed entities and engine inputs. `bookmarks` is retired. The main-track position is derived: the first ref, in the governed order, at or after `tracking_start_ref`, with no counted learn event. A manual jump is a governed `mainTrackProgram.tracking_start_ref` change. For a calendar program, `LearnerState` exposes `programAssignments(today)` (the refs the calendar assigns per civil date, computed in `lib/domain/learner_state/` from the anchor). The planner lays those out, and that is the only quantity source for calendar tracks. AD-39's push set adds `mainTrackProgram`.

---

## High

### N-H1 — Event grain is ambiguous, and per-leaf events break the AD-54 envelope outside Mishnayos

**Pair**

- **Lifetime-marking story:** AD-42 says "a unit is identified by its `sefariaRef`". A masechta or sefer node also has a `sefariaRef`. The story writes **one** `before_tracking` event with `ref = "Arukh HaShulchan"`, mirroring today's unit-scoped `learning_ledger` entry.
- **Engine story:** counts learnt refs per leaf. The node-ref event marks nothing as learnt, so siyum and corpus percentage stay at zero.
- **The leaf-grain alternative:** one sefer is 15k–25k leaves. Arukh HaShulchan alone means 56 batches of ≤ 450 (AD-54) and exceeds AD-54's perf gate of 10,000 events per learner. At about 300 B/doc for 20 learners, the 20 MiB tutor cache (AD-18) overflows. The envelope was sized for Mishnayos (4,192 leaves).

**Evidence:**
- Leaf counts (`isLeaf`) in `assets/content/hierarchy/*.json`: arukh_hashulchan 25,097; mishna_berurah 17,397; nach 17,360; mishneh_torah 15,342; shulchan_arukh 13,397; mishnayos 4,192
- `functions/src/deletes.ts:365` (ledger entries are unit-scoped)
- AD-54 Perf gate and Limits

**Rule (amend AD-31, AD-42, AD-54):**
> A `dated` or `catch_up` event's `ref` is a ContentIndex **leaf**. A `before_tracking` event may carry a node ref plus `level`; the engine expands it with `expandGround`, and it counts as learnt for every leaf it covers. The perf gate is sized on the largest-corpus learner: 20 learners × (40,000 leaf events + 200 node events), with the 20 MiB cache measured on the tutor device.

### N-H2 — The retirement inventory misses consumers the compiler cannot catch

**Pair**

- **"Close the inventory" story (AD-49):** closes the 29 listed consumers and removes the old rules. It is compliant.
- **Untouched string-keyed consumers:** these keep running.
  - `DataExportImportService` exports and imports `completions`, `streak_events` and `learning_ledger` by name. After the cutover, export hits default-deny. `learning_events`, `sub_tracks` and `change_log` are absent from the backup boundary, so every backup silently loses all learning history. A story that adds them makes import a raw batch writer into governed docs and `learning_events`. That breaks the "no other write path" convention and fails AD-38's `!exists(change_log/id)` and `actor.uid` checks on a restore to another account.
  - The `deleteBulkMarkedCompletions` callable writes `completions` and `learning_ledger`.
  - `TutorWriteService.resetCompletion`, `mark_live_completion_use_case` and the `text_display_screen` capture section are not listed.
  - Also unlisted: `streak_milestone_analytics_observer`, `streak_service`, `streak_state_service`, `completion_detection_service`, `track_progress_service` (tier filter), `firestore_notifications_completion_adapter`, `scheduler_completion_repository_impl`, and the points balance and lifetime readers (N-H6).
  - A grep finds about 60 non-generated `lib/` files, against 29 in the inventory.

**Evidence:**
- `lib/features/settings/domain/services/data_export_import_service.dart:77-96,271-321`
- `functions/src/deletes.ts:401`
- `lib/features/tutoring/data/services/tutor_write_service.dart:97`
- `lib/features/content_browsing/presentation/screens/text_display_screen.dart:25-33,651`

**Rule (amend AD-49 and the Retirement Inventory):**
> The inventory is closed by a mechanical check, not a list: a CI grep fails on any occurrence of `'completions'`, `'learning_ledger'` or `'streak_events'`, of the retired types, or of the retired callables, in `lib/`, `functions/src/` or `firestore.rules`. Backup export includes `learning_events`, `sub_tracks` and `change_log`. Import is either removed, or replays through `LearningCommands`: it re-issues events with fresh ULIDs, `actor` = the importer, and `original_recorded_at` preserved, and it re-creates governed docs as logged creates. `deleteBulkMarkedCompletions` and `tutorResetCompletion` are deleted, and their UI becomes a void.

### N-H3 — Multi-doc governed entities vs "at most one governed doc per batch"

**Pair**

- **Owner reorder story (AD-38 literal):** today's reorder writes N `track_learning_order` docs plus `curriculum_tracks.last_reorder_at` in **one** atomic batch. The owner rule (`getAfter(change_log/id).entity_id == docId`) forces N+1 batches with N+1 `change_log` entries. That produces N+1 FCM pushes (`mainTrackOrder` and `mainTrack` are both in the AD-39 set) and N+1 undo rows, and a partial order is visible offline.
- **Tutor reorder story:** `writeWithChangeLog` writes all N docs in one transaction under one entry with `entity_id = curriculumId`.
- The same action now produces incompatible history and undo semantics depending on the actor. Study days (one doc per weekday) and stages (one per stage) split the same way.

**Evidence:**
- `lib/data/repositories/firestore_track_learning_order_repository.dart:379-399`
- `firestore.rules:405-417,536-551,643-653` (per-ref, per-stage and per-weekday doc ids)

**Rule (amend AD-38):**
> A governed **entity** is the unit of one user action, not one document. `change_log.entity_id` is the entity key: `subTrack`=ULID, `goal`=`{c}_deadline`, `mainTrack`/`mainTrackOrder`/`mainTrackStudyDays`/`mainTrackStages`/`mainTrackScope`/`mainTrackProgram`=`curriculumId`, `learnerSettings`=profileId. One batch writes all docs of one entity under one `change_log` entry. Each doc carries the same `last_change_id`. The owner rule checks `getAfter(change_log/id).data.entity` against the collection's entity and `entity_id` against the doc's `curriculum_id` (or its id for `subTrack`/`goal`/`learnerSettings`). `before` and `after` are keyed `docId.field`. Owner and tutor paths produce identical entries.

### N-H4 — Owner rule has no create branch, and deterministic ids make "create" unknowable offline

**Pair**

- **Owner rule story:** implements AD-38 literally: `last_change_id != resource.data.last_change_id`. On create, `resource` is null, so every governed create is denied.
- **Workaround story:** adds `allow create` without the `change_log` check, and creates go unlogged.
- **Offline-create story:** goals (`{c}_deadline`), tracks (`{c}`), stages (`{c}_{order}`) and study days are deterministic ids.
  - Device A offline "creates" the deadline with `set` ("`set` only on create") and logs `before: null`. Device B already created it, so A's `set` lands as an update that replaces every field, which is not per-field LWW.
  - A later undo of A's entry (create-undo = tombstone) ends the goal B made.

**Evidence:** AD-38 owner rule; AD-43 "a second create is structurally an update"; `functions/src/tutor_writes.ts:346,455,562,621` (deterministic refs).

**Rule (amend AD-38):**
> All governed writes, including first writes, are field-level `set(..., merge: true)` of only the changed fields, never a whole-doc `set`. `change_log.before` is the writer's cached value per field, or `null` per field when absent. An entry is a "create" only if the server doc did not exist, which `writeWithChangeLog` checks in its transaction; the owner path never claims create. Undo of an entry whose `before` is all-null sets `ended_at` **only if** the doc's `last_change_id` still equals that entry's id; otherwise it is "changed since". The rules have a create branch: `!exists(change_log/id) && existsAfter(...) && getAfter(...)` with the same entity, actor and id checks, and `resource == null`.

### N-H5 — The learner profile doc mixes governed and ungoverned fields, with whole-entity merge writers

**Pair**

- **Lock-settings story:** applies the AD-38 owner rule to `learner_profiles/{id}` because `learnerSettings` is governed.
- **Existing writers:** `ensureProfile` and `updateProfile` (rename, avatar, mode) write the **whole entity** with `set(merge: true)` and no `last_change_id`. Under the whole-doc rule, every rename or mode switch is denied, and a queued one is permanently rejected.
- **Alternative scoping:** if the rule is scoped to `affectedKeys().hasAny([lat,lng,time_zone,in_israel])`, then once the codec carries those fields a stale-cache rename on device B rewrites the old location. That write is denied too. Either way, ordinary profile edits fail.

**Evidence:**
- `lib/data/repositories/firestore_learner_profile_repository.dart:274-292,299-316`
- `firestore.rules:211-213` (no whitelist)
- `functions/src/tutor_writes.ts:969` (`tutorEditProfile`)

**Rule (amend AD-37, AD-38):**
> The profile rule applies the owner-rule branch only when `request.resource.data.diff(resource.data).affectedKeys().hasAny(['latitude','longitude','time_zone','in_israel','last_change_id'])`. Profile writers outside `LearningCommands` use field-level `update` of their own fields only. The codec never emits the governed fields on a non-settings write. `ensureProfile` writes the seed settings plus a `learnerSettings` create entry in the same batch (see N-H8).

### N-H6 — Points earning is decided by the writer, not the engine

**Pair**

- **Capture on the parent device (offline) and tutor callable (online):** both tick ref X. Each judges "newly makes a ref learnt" from its own view, and each writes `pts_{own id}`. Both events are counted, so AD-50's filter (counted, not voided, not lock-ignored) **pays twice**. The same happens when two devices tick one scheduled review.
- **"Carries a scheduled review stage":** the engine cannot verify that a stage was scheduled. The planner decided that at write time on one device.
- **Point amount:** `point_configs` is keyed by `stage_order`, and free ticks carry no stage (AD-32). One story pays the stage-1 rate; another pays 0.
- **Lifetime earned:** `getLifetimeEarned` feeds achievements and is "monotonic". AD-50 defines only the balance. Unfiltered, a tick → void → re-tick cycle grows it without bound, because each re-tick "newly" learns. Filtered, it is no longer monotonic.

**Evidence:**
- `lib/data/repositories/firestore_points_ledger_repository.dart:297-321`
- `lib/features/gamification/data/repositories/firestore_points_balance_reader_adapter.dart` (not in the inventory)
- `firestore.rules:438-457`

**Rule (replace AD-50's earning sentence and add to AD-35):**
> Writers attach `pts_{eventId}` (amount = `point_configs[curriculum, stage ?? firstStageOrder]`) to **every** `source = main` `dated` or `catch_up` learn event. The **engine** decides earning: `LearnerState.earningEventIds` = for each ref, the earliest-`recorded_at` counted main learn event, plus for each (ref, stage) with stage > first, the earliest counted event carrying that stage, if `LearnerState` scheduled that stage for that ref on `civilDate(recorded_at)`. Balance = Σ entries with `event_id ∈ earningEventIds` + non-event entries, clamped as today. `lifetimeEarned` = the same filtered sum and is not monotonic; achievements latch once unlocked (local key, like siyum). The balance, lifetime and redemption readers are inventory items.

### N-H7 — `pts_` `created_at` is strictly bounded while events get +10 min, and AD-30 is mis-cited

**Pair**

- **Capture story:** co-writes the event plus `pts_{eventId}` (existing shape, `created_at` = the client clock) in one batch (AD-50).
- **Rules story:** applies AD-54's `+ 10 min` skew to `recorded_at` and `at` only, as written. A device 1 min fast passes the event but fails `points_ledger.created_at <= request.time`. The batch is atomic, so the **learning event is rejected**. Offline, it is rejected permanently on sync.
- **Mis-citation:** the spine's Inherited table cites parent AD-30 as "no rule may permanently reject a queued write; rules and client ship together". The parent's AD-30 is "Recovery for non-retryable writes": a per-item recovery affordance, status INCOMPLETE. No AD here supplies that affordance for rejected learning batches.

**Evidence:**
- `firestore.rules:360-365` (strict bound)
- `lib/data/repositories/points_ledger_entry.dart:152` (`created_at` always written)
- `docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md:458-468`

**Rule (amend AD-54, the Inherited table and AD-36):**
> Every client timestamp field written in a learning or governed batch (`recorded_at`, `at`, `points_ledger.created_at`) uses the same rule: `is timestamp && <= request.time + duration.value(10,'m')`. `pts_` takes `created_at = event.recorded_at`. Correct the AD-30 row to the parent text. `LearningCommands` surfaces any permanently rejected batch (SDK `permission-denied` on the pending write) as a per-item "not saved — retry" entry, per parent AD-30.

### N-H8 — `settingsHistory` has no completeness, seed or pre-history rule

**Pair**

- **History story (AD-38):** pages `change_log` 100 at a time.
- **Engine-input story:** builds `settingsHistory` from whatever `change_log` pages are loaded. AD-35's complete-log rule names only `events`, and AD-54 adds no index. Tutor devices therefore see a partial series, and devices compute different lock-ignored sets and different learnt sets.
- **No seed entry:** profiles are created by `ensureProfile`, outside `LearningCommands`, so no seed entry exists. For instants before the first `learnerSettings` entry, one story uses the current profile fields, which is the retroactive re-evaluation H1 forbade. Another uses the AD-36 fail-closed fallback, which needs `time_zone`, and `time_zone` itself comes from the missing history.

**Evidence:** AD-35, AD-37, AD-38 (paging), AD-54 (indexes: none); `firestore_learner_profile_repository.dart:274-292`.

**Rule (amend AD-35, AD-37):**
> `settingsHistory` comes from a complete paged read of `change_log` filtered `entity == 'learnerSettings'` (single-field equality, so no composite index). It has the same loading gate as `watchAll()`. Profile creation writes the seed settings and a `learnerSettings` create entry in one batch; the tutor path does the same in `writeWithChangeLog`. Instants before the first entry use that entry's `after`.

### N-H9 — App-wide generalization leaves the evaluation unit undefined

**Pair**

- **Sub-track story:** `sub_tracks.curriculum_id` is any curriculum, so the story lets a parent create a Bavli sub-track. `ground.level` allows only `masechta|perek|mishna`, and PRD rates are "mishnayos per week".
- **Second sub-track story:** restricts sub-tracks to Mishnayos.
- **AD-45 limits:** "≤ 5 ongoing" and "one school-year per academic year" are counted per profile by one story and per curriculum by another.
- **Engine invocation:** AD-35 takes a single `corpus`. One story runs the engine per (profile, curriculum), which gives a per-curriculum streak. Another runs it per profile, which gives a cross-curriculum streak, matching today's curriculum-agnostic `streak_reducer`. The home streak and FR-29 status differ.

**Evidence:**
- AD-35 signature
- AD-45
- AD-52 `ground.level`
- `lib/features/gamification/streak/streak_reducer.dart`
- PRD FR-5/FR-6 ("mishnayos per week")

**Rule (amend AD-33, AD-35, AD-45):**
> Sub-tracks are Mishnayos-only in this release (`curriculum_id == 'mishnayos'`, checked by the shared validation). The AD-45 limits are per profile. The engine runs once per profile over all curricula. Inputs are keyed by `curriculum_id`, and `corpus` is a map. Streak, points and `countedEventIds` are profile-wide; corpus, forecast, daily target and siyum are per curriculum.

---

## Medium

### N-M1 — The lock overlay and the capture gate use different windows

**Pair:** the capture-gate story uses `lockWindows` (10 / 10). The overlay story keeps `sacredWindowsProvider` → `ZmanimWindowService` (18 / 15), because AD-36 replaces the 18 / 15 constants only "for capture locking". As a result, the UI is locked from candle-lighting − 18 min while capture is allowed until − 10, and it stays locked until tzeis + 15 while capture reopens at + 10. Notification suppression follows the overlay.

**Evidence:** `lib/features/sacred_time/presentation/providers/sacred_windows_provider.dart:19-20`; `zmanim_window_service.dart:36-37`; `notifications/data/services/sacred_window_repository.dart`.

**Rule (amend AD-36):**
> `lockWindows` is the only window function for every surface: capture gate, lock overlay, notification suppression and reminders. `ZmanimWindowService.computeWindows` is deleted.

### N-M2 — Undo-copy launders a lock-ignored event

**Pair:** a child's offline Shabbos tick E is ignored by the engine (AD-36) but is visible in the parent's history (AD-38).
- The parent undoes E, which writes void V. The parent then undoes V, which writes copy C with a fresh `recorded_at` and `original_recorded_at = E.recorded_at`.
- **Engine story:** checks the lock on `recorded_at`, as AD-36 says literally. C counts and earns `pts_C`.
- **Second engine story:** checks the lock on `original_recorded_at`, so C stays ignored.

**Rule (amend AD-36):**
> The lock check uses `original_recorded_at ?? recorded_at`. Undo is not offered for a lock-ignored event; history labels it "not counted — recorded during Shabbos/Yom Tov".

### N-M3 — `can_edit_learning` vs the legacy per-key permissions on rerouted callables

**Pair:** the rerouted `tutorUpsertGoal` keeps `can_edit_goals`, and the rerouted stage, track and study-day callables keep `can_edit_stages` and `can_edit_study_days`. The new sub-track and event callables use `can_edit_learning`. Alternatively, a story moves all of them to `can_edit_learning`, and existing tutors silently lose goal and stage editing, because AD-53 grants the new key only by explicit parent action. The parent's permission screen shows overlapping toggles.

**Evidence:** `functions/src/tutor_writes.ts:343,452,559,618,801,861,924`.

**Rule (amend AD-53):**
> Every callable that touches an AD-38 governed entity or `learning_events` checks `can_edit_learning` only. `can_edit_goals`, `can_edit_stages`, `can_edit_study_days` and `can_reset_completion` are removed from grants and from the permission UI. `can_edit_rewards` and `can_edit_points` remain.

### N-M4 — Track deletion: governed tombstone or Admin hard delete?

**Pair:** the AD-54 story tombstones the curriculum's `sub_tracks` and calls the existing `deleteCurriculumTrack`. That callable hard-deletes `goals`, `stage_definitions`, `study_day_configs`, `curriculum_scopes`, `learning_order`, `profile_programs` and `curriculum_tracks` with the Admin SDK: no `change_log`, no undo, no push. `tutorDeleteTrack`, `tutorDeleteGoal` and `tutorDeleteStudyDayConfig` likewise call `.delete()`. A second story treats track removal as a logged `mainTrack` tombstone, per AD-38's "removal = tombstone". Re-adding the track then differs: the first story starts clean, and the second resurrects the tombstoned config.

**Evidence:** `functions/src/deletes.ts:161-167,209-300`; `tutor_writes.ts:403,510,676`.

**Rule (amend AD-54):**
> Track removal is one logged `mainTrack` change (`ended_at` set on the track and on every governed doc of that curriculum, as one entity per N-H3), plus logged tombstones of its sub-tracks. No Admin hard delete of governed docs remains outside account or profile deletion. Re-adding a curriculum clears `ended_at` through logged changes and keeps the prior config.

---

## Low

### N-L1 — FCM tokens outlive the parent session

AD-39 registers tokens "only while a parent-mode session is unlocked" but never removes them on relock. On a shared device the child receives "Rav Cohen changed the deadline" pushes. One story deletes the token on lock; another keeps it.

**Rule (amend AD-39):**
> The device's `fcm_tokens` entry is deleted when the parent session locks or times out, and re-registered on unlock.
