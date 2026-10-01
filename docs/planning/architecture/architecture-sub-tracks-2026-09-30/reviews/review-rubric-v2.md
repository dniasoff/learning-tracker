---
title: Review — Sub-tracks architecture spine v2 (good-spine rubric)
target: docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
reviewed: 2026-10-01
lenses: [good-spine rubric]
inputs:
  - ARCHITECTURE-SPINE.md (v2)
  - reviews/review-rubric-currency.md (v1; rubric lens and R-findings only)
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md (parent, incl. uncommitted 2026-09-30 amendments)
  - docs/planning/specs/spec-sub-tracks/prd-deviations.md (accepted; not findings)
  - docs/planning/prds/prd-sub-tracks-2026-09-30/prd.md (FR-5, FR-6, FR-8, FR-19)
  - bmad-architecture references/reviewer-gate.md (good-spine checklist); scripts/lint_spine.py
---

# Review — Sub-tracks spine v2: good-spine rubric

Out of scope here: currency and code facts. A separate job covers those.

## Verdict

**READY WITH FIXES.** Counts: **Critical 0 · High 2 · Medium 6 · Low 4.**

v2 closes every v1 Critical and High finding. Each AD now has Binds, Prevents and Rule. `lint_spine.py` reports only false-positive `{ulid}`/`{uid}` placeholder hits.

Two High gaps would still let epics diverge:

- **N1:** the AD-50 points filter lets duplicate or ineligible entries count.
- **N2:** AD-49 has no enforcement point, and the Retirement Inventory gives no epic order that can be cut cleanly.

Both are fixed by the replacement text below. No redesign is needed.

Severity follows v1: Critical = epics will diverge or lose data; High = real divergence or enforcement hole; Medium = silent area or ambiguous rule; Low = precision or duplication.

## v1 R-findings status

| R# | Status | Evidence in v2 |
| --- | --- | --- |
| R1 | Fixed | AD-49 and the Retirement Inventory retire `completions`, `learning_ledger`, `streak_events`, `pace_calculator`, `streak_reducer`, the sentinel and both callables. AD-13 greenfield, so no migration. Sequencing and enforcement remain open as **N2**. |
| R2 | Fixed | AD-49: "The planner never computes a quantity: it takes `LearnerState.dailyTarget` … and `schedulableRefs`." |
| R3 | Fixed | AD-35: inside lock L, forecast, on-track and the planned list are evaluated at `L.start`. |
| R4 | Fixed | AD-40 `streakDay(e)`: `dated` counts only if `learned_on == civilDate(recorded_at)`. |
| R5 | Partly | `actor.role ∈ {parent, child, tutor}` (AD-46, schema). The Roles convention gives a single source. FR-4 limits are in AD-45. However, the parent/child role is client-asserted and that trust boundary is undeclared (**N7**). |
| R6 | Fixed | AD-37 adds settings history. AD-36 says "settings in force at that `recorded_at`". The history seed is open as **N5**. |
| R7 | Fixed | AD-36 declares config writes stamped inside a lock an accepted risk. |
| R8 | Partly | The Reminders convention and AD-36 fail-closed are present. The scheduler has no named owner file (**N11**). |
| R9 | Fixed (superseded) | AD-43 uses the fixed id `goals/{curriculumId}_deadline`. |
| R10 | Fixed | AD-53 makes tutor writes online-only. AD-38 makes `writeWithChangeLog` idempotent on the client ULID. |
| R11 | Fixed | AD-35 pages ≤ 500 and runs one learner at a time. AD-54 adds a perf gate at 20 × 10k within 20 MiB. |
| R12 | Partly | AD-44 defines inclusive days, floor and ceil. It leaves `numerator` and `studyDaysToDeadline` undefined, so epics will choose different terms. Replacement text is given below the table. |
| R13 | Partly | `curriculum_id` is on events and sub-tracks. AD-54 keeps events and tombstones sub-tracks. It names no owner, and it doesn't say whether the tombstones co-write `change_log` (AD-38). Replacement text is given below the table. |
| T2 (v1 top 2) | Fixed | AD-38 owner rule (`!exists`, `existsAfter`, ULID regex, `entity_id == docId`); named governed docs; `writeWithChangeLog`. |
| T3 (v1 top 3) | Fixed | AD-52 plus the Storage Schema table. AD-52's own wording is now wrong (**N9**). |
| T4 (v1 top 4) | Fixed | AD-54 operational envelope. |

**R12 replacement (append to AD-44 Rule):**
> `numerator = mainTrackRemaining − Σ expectedNewGround(s) + Σ shortfall(s)` over `inForecast` sub-tracks (PRD FR-19 terms, each shortfall ref counted once). `studyDaysToDeadline` = count of dates D in `[today, target_date]` whose weekday is a study day in the curriculum's `study_day_configs`. When it is 0, `dailyTarget = numerator`.

**R13 replacement (AD-54 "Track deletion" bullet):**
> **Track deletion** (`deleteCurriculumTrack` callable) keeps `learning_events` and sets `ended_at` on that curriculum's non-ended `sub_tracks` through `writeWithChangeLog`, one `change_log` entry per sub-track. It never touches `learning_events` or `points_ledger`.

## New findings

### N1 — High — AD-50 counts points for any counted event, not for earning events

**Evidence:** AD-50 sets the balance to Σ entries "whose `event_id` … is in `LearnerState.countedEventIds`". The earning decision ("newly makes a ref learnt") is made at write time by `LearningCommands` or the callable. Three cases go wrong:

- Two owner devices offline, or an owner and a tutor, tick the same ref. Each sees it as "newly learnt", each writes `pts_{eventId}`, and both events are counted, so both pay.
- An owner-written `pts_` entry for a sub-track event passes AD-46-style rules and is counted.

Two epics (capture and points) can each comply and still disagree on the balance.

**Replacement (AD-50 Rule, last sentence):**
> The engine is the only authority on eligibility. It outputs `LearnerState.earningEventIds`: per ref, the first counted `source = main` non-`beforeTracking` learn event in (`recorded_at`, id) order, plus every counted `source = main` event whose `stage` matches a scheduled review due for that ref. Balance = Σ entries whose `event_id` ∈ `earningEventIds`, plus non-event entries. The write-time check in `LearningCommands` / `writeWithChangeLog` only avoids writing obviously ineligible entries; it is not authoritative. Rules require `docId == 'pts_' + event_id` and `existsAfter(learning_events/{event_id})`.

### N2 — High — AD-49 has no enforcement point, and retirement cannot be cut as the first epic

**Evidence:**

- AD-49 says the old collections "receive no writes" and are "removed … after cutover". The inventory says each consumer is "rewired … before capture ships". Neither names an enforcement point (rule or checker), and "after cutover" is undated.
- Every inventory row is rewired *to* `LearnerState` / `LearningCommands`, so a retirement epic cannot come first unless it also builds the engine, the command layer, the schema and the rules.
- The inventory lists only Dart symbols. It omits the `firestore.rules` matches, `functions/src` writers of these collections, the `deletes.ts` collection list, `firestore.indexes.json` entries for them, and their tests and fixtures.
- It has no action column, so one epic may rewire `points_service` while another deletes it.

**Replacement (AD-49 Rule, replace the last sentence):**
> **Sequencing (binding).** Epic 1, *Learning-event cutover*, ships no sub-track UI. Its stories, in order:
>
> (a) AD-52 schema codecs, the `lib/domain/learner_state/` engine and predicates, and `LearningCommands` / `CaptureGate` with ports;
> (b) AD-46 rules, `writeWithChangeLog`, rerouted callables (AD-51) and their emulator tests;
> (c) one story per Retirement Inventory row, rewiring or deleting per the row's Action;
> (d) the cutover release.
>
> In the cutover release, `firestore.rules` denies all client writes to `completions`, `learning_ledger` and `streak_events`; the retired callables are undeployed; and `tool/check_retired_symbols.dart` (CI) fails on any reference to a symbol in the inventory. Rules matches, repositories and the collections' `deletes.ts` entries are removed in the release after. No sub-track story starts before story (d) ships.

**Replacement (Retirement Inventory):** add columns `Action (rewire → <target> | delete)` and `Story`. Add these rows:

- `firestore.rules` matches for the three collections: deny writes in the cutover release, remove them in the release after.
- `functions/src` writers of the three collections: delete.
- `deletes.ts` explicit collection list: drop the three collections, add `sub_tracks` (R13).
- `firestore.indexes.json` entries on the three collections: remove.
- Tests and fixtures referencing the retired symbols: delete or port.

### N3 — Medium — `window_end = null` has no meaning in the AD-34 predicates

**Evidence:**

- The schema allows `window_end` null for an open ongoing sub-track.
- AD-34's `holdsGround = today ≤ window_end` and `onHome` compare against it.
- AD-44 substitutes `target_date` only for capacity.

One epic will treat null as "ended", another as "forever".

**Replacement (append to AD-34 Rule):**
> In every predicate a null `window_end` is +∞. Only AD-44 capacity substitutes `target_date` for it; with no deadline, capacity is not computed.

### N4 — Medium — AD-45 limits are not computable from the schema

**Evidence:**

- PRD FR-5 picks an *academic year* with editable start and end months. FR-7 "Add next year" means "the following academic year". The schema stores only `window_start` / `window_end`, so "one school-year sub-track per academic year" has no key, and edited months make window overlap a poor proxy.
- "≤ 5 ongoing" doesn't say whether the scope is per profile or per curriculum.
- FR-8 *delete* and explicit *end* both set `ended_at`. AD-47 reports them separately, but nothing stored distinguishes them.

**Replacement:**

Schema, `sub_tracks` rows:

| | `academic_year` | int (civil year in which the academic year starts), `school_year` only | school ✓ |
| | `end_reason` | `ended` \| `deleted` \| `undo` \| `track_deleted`, set with `ended_at` | – |

AD-45 Rule:
> per learner profile and curriculum: ≤ 5 non-ended ongoing sub-tracks whose `onHome` or future-start holds; ≤ 1 non-ended school-year sub-track per `academic_year`; "Add next year" sets `academic_year + 1`.

### N5 — Medium — `settingsHistory` has no seed

**Evidence:** AD-37 defines `settingsHistory` as "the piecewise-constant series from their `change_log` entries". Profile creation, where `time_zone` is seeded from the device, isn't a `LearningCommands` path and isn't said to log anything. Before the first logged change, `lockWindows` and `civilDate` therefore have no settings. One epic will fall back to the current doc and another to "unlocked".

**Replacement (append to AD-37 Rule):**
> Profile creation co-writes a `learnerSettings` `change_log` entry (`before: null`) in the same batch. If a profile has no such entry, `settingsHistory` treats the profile doc's current values as in force from the beginning of time.

### N6 — Medium — The inherited and amended parent ADs are not fully consistent

**Evidence:**

- **AD-30:** the inheritance row ("No rule may permanently reject a queued write … rules and client ship together") is not what parent AD-30 says. The parent requires a recovery affordance for non-retryable writes.
- **AD-8 carve-out:** the spine declares one (AD-54 chunking), but the parent was amended only at AD-4 and AD-22.
- **AD-6:** parent AD-6 Binds still names completions, learning ledger and streak events.
- **AD-13:** this is `[REMOVED]` in the parent but is cited as an inherited invariant.

**Replacement:**

Inheritance table, AD-30 row:
> AD-30 | A genuinely non-retryable write gets an explicit recovery affordance. This spine adds (AD-51/AD-54) that rules and client ship together, so supported clients never hit one by design.

AD-13 row:
> AD-13 (removed in parent; its *current rule* binds) | Greenfield: …

Add to "Amendments to the parent" (and record each in the parent spine):
> - **AD-8** → carve-out by AD-54: bulk captures chunk at ≤ 450 docs per batch, each chunk self-contained (event + its `pts_` entry together).
> - **AD-6 Binds** → after AD-49 cutover, the list is `learning_events`, `change_log`, `points_ledger`.

### N7 — Medium — `actor.role` parent/child is client-asserted; the trust boundary is undeclared

**Evidence:** parent and child share one auth uid. AD-46 rules can check only `role ∈ {parent, child}`, so a child client can stamp `parent`. The FR-4 child limits (AD-45) and parent-only surfaces depend on this role. Without a declared trust boundary, one epic will write rules that try to enforce the distinction and another will treat it as UI-only.

**Replacement (append to Consistency Conventions → Roles):**
> `parent`/`child` is a client assertion from the parent-PIN session (parent AD-15), not an authorization boundary. Rules enforce only `uid` and `role ≠ tutor`. FR-4 child limits are enforced in `LearningCommands` alone. This is an accepted risk, like a forged `recorded_at`.

### N8 — Medium — Analytics for tutor writes have no owner

**Evidence:** AD-47 says "`LearningCommands` emits …". Tutor captures and sub-track lifecycle changes go through `TutorWriteService`, so SM-1–SM-5 either undercount or get a second, divergent emitter.

**Replacement (AD-47 Rule, first sentence):**
> `LearningCommands`, and `TutorWriteService` after a successful callable result, emit `capture`, … through one shared `LearningAnalytics` emitter in `lib/features/learning/domain/commands/`. Callables emit nothing.

### N9 — Low — AD-52 misdescribes the ADs

**Evidence:** AD-52 says "ADs use Dart names". The ADs actually use storage names (`learned_on`, `recorded_at`, `ended_at`, `last_change_id`) mixed with Dart enum values (`catchUp`, `beforeTracking` in AD-40 and AD-49, against the schema's `catch_up` / `before_tracking`).

**Replacement (AD-52 Rule):**
> ADs use Firestore storage field names; enum values in ADs are Dart names whose storage form is the snake_case value in the table. Storage names and types are exactly the Storage Schema table below. Adding a field means editing that table.

### N10 — Low — AD-51 duplicates AD-38 and AD-54

**Evidence:**

- AD-38's tutor-path bullet already says the rerouted writers ship "in the **same release** as the rules".
- AD-54 owns deploy ordering.
- AD-51 adds only "no supported older clients", which duplicates AD-13.

**Replacement:** delete AD-51. Append to AD-38's tutor-path bullet:
> (no supported older clients, AD-13; deploy order per AD-54).

Repoint AD-51 references (Capability map "Operations", the N6 AD-30 row) to AD-38/AD-54.

### N11 — Low — Several rules name no owner file

**Evidence:** these are each "one X" with no location, so two epics can each create one:

- AD-36 lock constants: "one file".
- The Reminders scheduler.
- AD-39's Cloud Function and token registrar.
- AD-45's shared fixture suite.
- AD-53's per-callable grant re-check.
- The `can_edit_learning` row ("grant permissions"), which is not a path.

**Replacement (one line each, in the respective ADs):**
> - Lock constants: `lib/domain/learner_state/lock_constants.dart`.
> - Reminders: `CatchUpReminderScheduler` in `lib/features/sacred_time/`.
> - AD-39: trigger `onChangeLogCreated` in `functions/src/notifications.ts`; tokens registered and removed only by `ParentSessionController` on PIN unlock and lock.
> - AD-45: fixtures at `test/fixtures/sub_track_limits/*.json`, consumed by the Dart and `functions/` test suites.
> - AD-53: `writeWithChangeLog` performs the grant and `can_edit_learning` check; no callable checks separately.
> - Schema: `tutor_grants/{grantId}` `permissions.can_edit_learning`.

Verify these paths against the code; that is the code-facts job's scope.

### N12 — Low — The ER diagram is partly decorative

**Evidence:** `CHANGE_LOG }o--|| SUB_TRACK : "last_change_id"` shows one governed entity of eight. The diagram adds nothing the schema table doesn't already say.

**Replacement:** relabel the edge `CHANGE_LOG }o--|| GOVERNED_DOC : "entity_id / last_change_id"`, or drop the erDiagram and keep the schema table as the single source (AD-52).
