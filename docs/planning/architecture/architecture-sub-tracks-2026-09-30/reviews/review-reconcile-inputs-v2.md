---
title: Reconciliation: Sub-tracks PRD inputs against architecture spine v2
target: docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md (v2, AD-31..AD-54)
reviewed: 2026-10-01
method: Reconcile every PRD §4 FR and testable consequence, §§4.9–4.10, §7, and addendum §§2–3 note against named ADs; carry forward v1 findings and treat all nine registered deviations as accepted.
---

# Reconciliation: Sub-tracks PRD and addendum against architecture spine v2

Scope: every FR and every “Consequences (testable)” bullet in PRD §4, all items in §§4.9–4.10 and §7, and each technical note in addendum §§2–3, reconciled against spine v2 (AD-31–AD-54). “Home” means the spine names an architectural owner/rule; “UI/story-level” leaves presentation or interaction to feature design; “Dropped” means no corresponding rule; “Contradicted” means incompatible behavior. Where the approved deviations register records a deliberate difference, classify it as “Accepted deviation (prd-deviations #N)”.

Verdict (one primary class per scoped source row; withdrawn FR-22 shown separately): Home: 125; UI/story-level: 20.
Dropped: 25; Contradicted: 0; Accepted deviation: 7.
Scoped source rows: 177; withdrawn: 1.

## PRD §4: Functional requirements and testable consequences

| Source item | Spine reconciliation |
|---|---|
| FR-1 — Active sub-track rows beneath main tasks, name/current position | Home: AD-33 derives current position/active state; capability map assigns rows to `features/sub_tracks`. Row layout is UI-level. |
| FR-1 C1 — Exactly one row per active sub-track, regardless of masechtos | UI/story-level; feature surface is named in the capability map. AD-33 stores one sub-track document and ordered ground. |
| FR-1 C2 — Main-track today list unchanged | UI/story-level; planner preservation is noted in addendum §1, but no spine invariant explicitly guarantees unchanged task generation. |
| FR-1 C3 — Ended sub-tracks absent from home | Home: AD-33 defines activity by window/tombstone; rendering is UI-level. |
| FR-2 — +1 / up-to capture on sub-track row | Home: AD-31 events, AD-33 position, AD-34 expansion, AD-36 command path; gesture is UI-level. |
| FR-2 C1 — Up-to creates one event per mishna through selected point in order | Home: AD-31 (one event per learn), AD-34 (ordered expanded refs), AD-36. |
| FR-2 C2 — Position advances to next un-ticked mishna in that sub-track | Home: AD-33 explicitly derives source-specific position from non-voided events. |
| FR-2 C3 — Source inferred from row, no prompt | Home: AD-31 source field; Consistency Conventions “Source” and “Writes”. Prompt omission is UI-level. |
| FR-2 C4 — Empty-ground row prompts parent/tutor, child cannot tick; capacity still forecast | Capacity home: AD-33/44. Prompt and disabled child control are UI-level; no explicit authorization rule for child tick is stated (AD-36 is lock/command validation only). |
| FR-2a — Up-to with individual tick adjustment on sub-track, main list, catch-up | Home: AD-36 funnels writes through `LearningCommands`; surfaces/interaction are in capability map and UI-level. |
| FR-2a C1 — Main today list offers up-to without changing generated tasks | UI/story-level; unchanged task-generation constraint is not explicit in spine. |
| FR-2a C2 — Only selected items create events | Home: AD-31/36 event write path; selection behavior is UI-level. |
| FR-3 — Browser free-tick / tick-to-here at any corpus level | Home: AD-34 expands nodes; AD-42 owns corpus identity/order; capture UI belongs to feature layer. |
| FR-3 C1 — Ask source once per batch, default main | Home: AD-31 source; UI default/prompt is UI-level. |
| FR-3 C2 — Batch may be before-tracking; excluded from streak/velocity | Home: AD-31 dateState, AD-40 streak filter, AD-35 engine (velocity); exclusion from velocity is bound but not repeated as an explicit AD-35 formula. |
| FR-3 C3 — Date defaults today and is editable at capture | Home: AD-41 local-date semantics; editable control/default is UI-level. |
| FR-3 C4 — Free ticks count toward streak only for main source and counted day | Accepted deviation (prd-deviations #8): AD-40 requires a dated event’s learned_on to equal civilDate(recorded_at); a backdated free tick does not fill a streak day. |
| FR-4 — Child/parent/tutor can undo or correct event | Home: AD-31 void/learn, AD-36 command path, AD-38 append-only undo/history. Available controls are UI-level. |
| FR-4 C1 — Corrected/removed event no longer affects progress, streak, velocity | Home: AD-31 voids; AD-35 reducer; AD-40 streak. |
| FR-4 C2 — Target and positions recompute immediately | Home: AD-33/35 derive rather than store; “immediately” is not given a latency bound here. |
| FR-4 C3 — Void original, optional replacement; hidden from child lifetime but retained in parent history | Home: AD-31/38 preserve events and history. **DROPPED:** the child-facing lifetime filter/hiding of voids is not specified (AD-48 only says reports use engine output). |
| FR-4 C4 — Child may re-date only in catch-up window; older child correction is removal-only | **DROPPED:** AD-36 gates on lock windows but does not define role-sensitive correction/date-edit limits or connect them to FR-25’s catch-up window. |
| FR-4 C5 — Correction cannot create/restore a streak day other than the child’s eligible corrected date | **DROPPED:** AD-40 defines streak input filtering, not this correction-specific restriction. |
| FR-4a — Optional feature in menu; onboarding mention, never prompted | UI/story-level; there is no architectural requirement for onboarding/menu placement. |
| FR-4a C1 — One onboarding mention, no setup fields/steps | UI/story-level. |
| FR-4a C2 — App never prompts to create a sub-track | UI/story-level. |
| FR-4a C3 — No sub-track section when none exist | UI/story-level; AD-33 defines sub-track state, not empty-state rendering. |
| FR-5 — Create school-year track, editable academic-year months, rate/weeks | Home: AD-33 fields and AD-44 capacity; form defaults and picker are UI-level. |
| FR-5 C1 — Picker years: current through deadline year, or current + next two without deadline | UI/story-level; no year-picker rule in spine. |
| FR-5 C2 — Cannot choose academic year already assigned | Home: AD-45 one school-year track per academic year. Picker presentation is UI-level. |
| FR-5 C3 — Month edits carry into next year; windows may not overlap | Home: AD-33 stores windows, AD-45 prohibits overlap; carry-forward is UI/story-level and not stated. |
| FR-5 C4 — 39 prefill, editable; no exclusion checkboxes | UI/story-level/config default; absent from spine. |
| FR-5 C5 — Current part-elapsed year capacity prorated over remaining window | Home: AD-44 explicitly prorates active weeks over window. |
| FR-6 — Create ongoing track with optional dates, rate/weeks and bein-hazmanim choice | Home: AD-33 fields, AD-44 capacity; form and toggle interaction UI-level. |
| FR-6 C1 — At most five active ongoing tracks; ended ones excluded | Home: AD-45. |
| FR-6 C2 — Bein-hazmanim toggle changes prefilled weeks only and never overwrites edited value | **DROPPED:** spine stores `weeksPerYear` but does not specify prefill/toggle behavior or preserve-manual-edit semantics. |
| FR-6a — Optional future start date | Home: AD-33 `windowStart`, AD-44. |
| FR-6a C1 — Before start, forecast from start and no home row | Home: AD-33/44 forecast from the future interval; Accepted deviation (prd-deviations #4): AD-34 holds future ground out of the main track immediately on assignment, before the start date. Home-row visibility is UI/story-level. |
| FR-6b — Optional learns-on-Shabbos/Yom-Tov flag | Home: AD-33 explicitly stores `learnsOnShabbos`. |
| FR-6b C1 — Only flagged tracks appear on catch-up card | **DROPPED:** AD-33 stores the flag, but no AD specifies that only flagged tracks are included on a catch-up card. |
| FR-7 — Add next school year by copying name/rate/weeks, editable before save | UI/story-level workflow over AD-33 fields; cloning behavior itself is not specified. |
| FR-7 C1 — Window is following academic year | UI/story-level; AD-33 stores windows but does not define this action. |
| FR-7 C2 — New ground empty | Home: AD-33 ground is explicit intent; empty initialization is UI/workflow-level and not stated. |
| FR-8 — Edit any field/delete track | Home: AD-33/38, AD-46 (tombstone, no physical delete). |
| FR-8 C1 — Rate edit recomputes daily target immediately | Home: AD-35/44 derive forecast; latency/UI refresh is not specified. |
| FR-8 C2 — Delete returns unfinished ground; events remain in lifetime | Home: AD-33 tombstone/active-set derivation, AD-31 events retained; AD-34 expansion. |
| FR-9 — Detail shows ordered ground and tri-state progress across masechtos | Home: AD-33/34/35/42; detail rendering is UI-level. |
| FR-9 C1 — Position, count ticked in this track, capacity vs remaining path | Home: AD-33/35/44. |
| FR-9 C2 — Learnt elsewhere renders learnt but does not move this position | Home: AD-32 global learnt semantics; AD-33 source-specific position. |
| FR-10 — Add any masechta/perek/mishna incrementally | Home: AD-33 `ground`, AD-34, AD-42. |
| FR-10 C1 — Assigned ground excluded from main schedule and greyed out there | Home: AD-33 defines schedulable set; grey display is UI-level. |
| FR-10 C2 — Same mishna can be assigned to multiple sub-tracks | Home: AD-33 per-track ground; AD-34 deduplicates during expansion, not across tracks. |
| FR-10 C3 — Already-learnt ground allowed; learning there is chazara | Home: AD-31/32/33; chazara derived per AD-32. |
| FR-10 C4 — No duplicate mishna within one sub-track | Home: AD-34 drops already-emitted refs. |
| FR-10 C5 — Main track holds each mishna at most once | Home: AD-33 corpus-based schedulable set; no explicit persisted main-track ground list. |
| FR-11 — Parent/tutor orders ground; exactly one position | Home: AD-33/34. |
| FR-11 C1 — Added ground appends by default and may be moved | Home: AD-33 ordered list; append default/edit affordance is UI-level and not explicit. |
| FR-11 C2 — Reorder preserves ticks; position is first unticked in new order | Home: AD-33 derived position and AD-31 immutable events. |
| FR-11 C3 — Reorder recomputes forecast | Home: AD-35/34. |
| FR-12 — Track end (year/end-date/delete) returns unfinished ground | Home: AD-33 active-state/return-on-end; AD-34/35 derive planner. |
| FR-12 C1 — Only never-learnt by any source returns | Home: AD-32 learnt definition and AD-33 schedulable set. |
| FR-12 C2 — Returned ground resumes original main order, not appended | **DROPPED:** spine does not define the main-track ordering/re-entry rule. |
| FR-12 C3 — Schedule and target recompute on return | Home: AD-33/35. |
| FR-12 C4 — Ground still held by another active sub-track does not return until none holds it | Home: AD-33 schedulable set subtracts ground of active tracks; this implements the exclusion, though “return” timing is not a stored transfer. |
| FR-12a — Main track works one masechta at a time | Home: AD-49 explicitly requires the planner to apply FR-12a’s one-masechta rule. |
| FR-12a C1 — No two masechtos same day, except boundary completion day | **DROPPED:** no task-generation/day-boundary rule in spine. |
| FR-12a C2 — Returned ground before current masechta queues next, after current completes | **DROPPED:** no main-track insertion/order rule in spine. |
| FR-13 — Learning in one track never advances another track position | Home: AD-33 source-specific current position and AD-31 source attribution. |
| FR-13 C1 — Example: other sub-track tick leaves this position unchanged | Home: AD-33 derives each position from events whose source is that track. |
| FR-13 C2 — Same mishna is globally learnt for goal regardless of source | Home: AD-32. |
| FR-14 — Goal counts distinct corpus mishnayos learnt from all sources/states | Home: AD-31/32/42; AD-35 computes totals. |
| FR-14 C1 — Chazara does not increase goal progress | Home: AD-32. |
| FR-14 C2 — Before-tracking events count toward goal progress | Home: AD-31/32. |
| FR-15 — Tri-state at all named corpus surfaces | Home: AD-35 shared reducer and AD-42 corpus; surfaces are UI-level. |
| FR-15 C1 — One mishna makes ancestor nodes partial | Home: AD-35; rendering is UI-level. |
| FR-16 — Streak counts main/home learning only | Home: AD-40. |
| FR-16 C1 — Sub-track-only day does not extend streak; learning still celebrated; no child-facing “doesn’t count” message | Streak computation home: AD-40. Celebration/tone rule is UI/story-level; spine does not prescribe copy. |
| FR-16 C2 — Lock day streak preserved by catch-up within window | Home: AD-40 defines the eligible preceding lock, locked days and per-card catch-up window. |
| FR-17 — One siyum when masechta becomes fully learnt, any source | Home: AD-35/42 derive completion; Siyum convention derives first completion and completion number, with a profile-scoped once-per-device celebration key. |
| FR-17 C1 — Chazara does not re-fire siyum | Home: Siyum convention shows once per device; a later void does not retract a shown celebration. |
| FR-17 C2 — Completion entirely in sub-track fires siyum | Home: AD-32/35 are source-agnostic for learnt state; AD-42 defines the same corpus set for siyum. |
| FR-18 — Parent sees deadline status, child encouragement only | Computation home: AD-35/43; parent/child presentation is UI/story-level. |
| FR-18 C1 — Projected finish extrapolates distinct new all-source velocity over trailing 4 weeks, excluding backfill/chazara | **DROPPED:** AD-35 owns projection but does not define observed-velocity algorithm or trailing-4-week window/exclusions. |
| FR-18 C2 — Parent sees projected finish date | UI/story-level; projection value has AD-35 owner. |
| FR-18 C3 — One unusually large day only changes status if four-week projection crosses deadline | **DROPPED:** no smoothing/status transition rule. |
| FR-18 C4 — Child never sees “behind/off track”; sees today progress and streak | UI/story-level tone/presentation; spine has no child-copy rule. |
| FR-18 C5 — <2 weeks says “too early”; 2–4 weeks uses all history | **DROPPED:** no history threshold/fallback algorithm. |
| FR-19 — Daily target is adjusted remaining divided by days to deadline | Home: AD-35 says implement exact PRD formula; AD-43 provides the whole-corpus deadline goal; AD-44 capacity rule. |
| FR-19 definition 1 — Capacity = weekly rate × active weeks left in window before deadline | Home: AD-44. |
| FR-19 definition 2 — Path = ordered ground from current position to end, including learnt items | Home: AD-33/34; AD-35 promises the exact PRD formula. |
| FR-19 definition 3 — Shortfall = unlearnt path beyond capacity, returning at sub-track end | Home: AD-33/35. |
| FR-19 definition 4 — Expected new ground = max(0, capacity − path length); empty path means full capacity | Home: AD-35 promises exact FR-19 formula. |
| FR-19 definition 5 — Main remaining excludes learnt ground and active sub-track assignments; denominator uses main study days (default seven) | Home: AD-33 schedulable set; AD-35 engine inputs/exact formula. |
| FR-19 C1 — Never-negative target; zero shows “all covered” bonus copy | Numeric rule home: AD-35; child-facing copy is UI/story-level. |
| FR-19 C2 — Adding entered ground when capacity exceeds path leaves target unchanged | Home: AD-35 exact PRD formula, AD-44 capacity. |
| FR-19 C3 — Shortfall only unlearnt ground; learnt path consumes capacity | Home: AD-35 exact PRD formula plus AD-32 learnt set. |
| FR-19 C4 — Count shortfall once; omit if another active holder is forecast to reach it | Home: AD-35 expressly says cross-sub-track shortfall counted once. |
| FR-19 C5 — Main order/ground/rate/learning changes recompute target | Home: AD-35 single reducer; AD-36 command boundary. |
| FR-19 C6 — Expected new ground counts fully for each track even if future overlap | Home: AD-35 exact PRD formula; independence in AD-33. |
| FR-20 — No deadline gives projected finish date, no target/status | Home: AD-35/43; display is UI-level. |
| FR-20 C1 — Rates have no effect with no deadline | Home: AD-43 says engine reads only deadline goal; AD-35 computation. |
| FR-21 — Parent warning names track, ground, end, approximate return | Shortfall home: AD-35; warning content/visibility is UI/story-level. |
| FR-21 C1 — Warning iff shortfall > 0 | Home: AD-35; display rule UI-level. |
| FR-21 C2 — Displayed number equals FR-19 shortfall | Home: AD-35. |
| FR-21 C3 — Child never sees warning | UI/story-level. |
| FR-22 — Withdrawn requirement | Explicitly withdrawn in PRD; no architecture home expected. Not counted as a dropped requirement. |
| FR-23 — No writes during Shabbos/Yom-Tov lock; readable; fail closed | Home: AD-36 defines `CaptureGate`, learner-local lock windows and fail-closed missing-location/Yom-Tov/high-latitude fallbacks; AD-37 owns learner settings. |
| FR-23 C1 — Disable every capture/edit control on every owner/tutor device | Home: AD-36 all writes through gate and learner settings; UI disablement is an affordance, with gate authoritative. |
| FR-23 C2 — Lock -10 min candle lighting through +10 min tzeis | Accepted deviation (prd-deviations #6): AD-36 sets 10/10-minute capture margins, replacing existing 18/15-minute behavior. |
| FR-23 C3 — Israel setting per learner, defaulted from location/changeable; location for zmanim | Home: AD-37 profile location/timezone/inIsrael; default/change controls UI-level. |
| FR-23 C4 — Missing zmanim fallback Friday noon–Sunday 1 local + Yom Tov and prompt parent | Home: AD-36 specifies Friday 12:00–Sunday 01:00 learner-local and Yom Tov equivalent; parent prompt is UI/story-level. |
| FR-23 C5 — High-latitude tzeis conservative fixed fallback | Home: AD-36 requires a conservative fixed high-latitude window. |
| FR-23 C6 — Offline writes dated to action time; lock-window writes rejected at sync | Accepted deviation (prd-deviations #2): AD-30/36 retain the queued document and exclude it from derived state when `recorded_at` is inside the lock; sync rejection is intentionally not implemented. |
| FR-23 C7 — On-track indicator does not change during lock | Home: AD-35 evaluates on-track at `L.start` while inside lock L. |
| FR-24 — Same planned view before/during lock | UI/story-level view placement; no specific architectural view owner beyond feature UI. |
| FR-24 C1 — Planned list freezes at lock start until lock ends | Home: AD-35 evaluates the planned list at `L.start` while inside lock L. |
| FR-24 C2 — Locked view has no tappable controls | UI/story-level, supported generally by AD-36 gate but no view-specific rule. |
| FR-25 — Post-lock catch-up card with all/adjust, one plan per locked day | Home: AD-36 catch-up event semantics; card interaction is UI-level. |
| FR-25 C1 — Availability through first full non-locked day; pause across next lock; cards stack | Home: AD-40 defines each `catchUpWindow(L)` through the end of the first civil day after L.end with no locked instant and gives pending cards their own windows. |
| FR-25 C2 — Events dated to locked day(s), catch-up date state | Home: AD-36 expressly defines `dateState=catchUp`, `learnedOn` locked day, `recordedAt` entry time; AD-41 local date. |
| FR-25 C3 — Covers up to three consecutive locked days | **DROPPED:** no maximum coverage rule. |
| FR-25 C4 — Reminder fires when card available | Home: AD-37/Reminders convention assign a scheduler derived from `lockWindows`; **DROPPED:** the trigger time “when the card becomes available” is not specified. |
| FR-25 C5 — Main plus marked tracks included with up-to per locked days | **DROPPED:** AD-33 stores the flag and AD-36 governs writes, but no rule specifies the main/marked-track card composition. The per-day adjustment is UI/story-level. |
| FR-25 C6 — Unmarked tracks never appear | **DROPPED:** flag is stored (AD-33), but no explicit exclusion rule in AD-36. |
| FR-26 — Tutor can do parent operations on main, deadline and sub-tracks | Home: AD-22/53/46 grant-scoped callables; Accepted deviation (prd-deviations #7): existing grants gain `can_edit_learning` only after explicit parent action. |
| FR-26 C1 — Tutor change identity and time recorded | Home: AD-38 actor/time change log; AD-31 event actor/time. |
| FR-26 C2 — Tutor sees only granted learner, no family data | Home: AD-12/22/46 authorization boundary; scope rule applies to new data/callables. |
| FR-27 — Parent sees and can undo tutor changes | Home: AD-38 history and append-only undo. |
| FR-27 C1 — History entry shows who/what/when | Home: AD-38 schema `{actor, entity, entityId, before, after, at}` and actor snapshot convention. |
| FR-27 C2 — Undo restores prior state as new recorded change | Home: AD-38 explicitly applies prior value as new logged mutation. |
| FR-27 C3 — Notify parent for tutor deadline/main-track edit, not sub-track edit | Accepted deviation (prd-deviations #9): AD-39 sends for `{goal, mainTrack, mainTrackOrder, mainTrackStudyDays}` to parent-mode sessions; stage/scope/settings changes stay history-only. |
| FR-28 — Parent revokes tutor at any time | Home: AD-46 says reads by active tutor; no explicit revoke mutation flow. |
| FR-28 C1 — Access removed immediately on next sync | Home: AD-46/53 enforce active-grant reads and recheck grants on every callable; **DROPPED:** next-sync client cache/list refresh timing is unspecified. |
| FR-28 C2 — Tutor-created sub-tracks and events remain unchanged | Home: AD-31/33/46 retention/tombstone; revocation-specific retention is not stated but follows append-only model. |
| FR-29 — Tutor list of granted learners with on-track status, open learner | Home: AD-35 explicitly runs engine per learner client-side; list UI is UI-level. |
| FR-29 C1 — Only active grants; revoked learner disappears | Home: AD-46 active tutor read scope; list refresh/render behavior is UI-level. |
| FR-30 — Any mishna shows every event date/source/count | Home: AD-31 event schema, AD-42 identity, AD-35 shared read state. History screen is UI-level. |
| FR-30 C1 — Count equals non-voided events | Home: AD-31 void target and AD-35 reducer. |
| FR-30 C2 — Deleted-track events remain labelled by track name | Home: AD-33 tombstoned doc retains name; AD-31 retains source and AD-46 forbids physical track delete. |
| FR-31 — Parent lifetime report/export continues after goal; same-name school tracks roll up by year | Home: AD-48 report/PDF output, AD-31 append-only events. **UI/story-level:** roll-up/expand layout. |
| FR-31 C1 — Distinct learnt, total events, source totals | Home: AD-35/48. |
| FR-31 C2 — Recording continues after goal | Home: AD-31/36; no goal-complete write lock. |
| FR-32 — Parent can export PDF velocity by source and on-track | Home: AD-35 shared calculations, AD-48 PDF. Report presentation is UI-level. |
| FR-32 C1 — Before-tracking excluded from velocity | Home: AD-31 dateState and AD-35 engine; the explicit velocity filter is **not spelled out** in spine (AD-40’s filter is for streak only). |
| FR-32 C2 — Catch-up counts on learned day, not entry day | Home: AD-36 `learnedOn` vs `recordedAt`; AD-41. |

## PRD §4.9 — Offline and concurrent edits

| Source item | Spine reconciliation |
|---|---|
| §4.9-1 — Capture offline; events from devices never overwrite | Home for owner devices: inherited AD-8, AD-31 and AD-46. Accepted deviation (prd-deviations #3): AD-53 makes tutor writes online-only. |
| §4.9-2 — Concurrent parent/tutor config edits: later wins; both in history | Home: AD-38 says last-write-wins by sync order and same-batch/transaction append-only change log. |
| §4.9-3 — Recompute target visible on same screen, assumed <1s mid-range | Home: AD-35 owns recomputation; AD-54 adds a <1 s mid-range benchmark for FR-19 and FR-29. Same-screen presentation remains UI/story-level. |

## PRD §4.10 — Children’s data

| Source item | Spine reconciliation |
|---|---|
| §4.10-1 — Follow existing child-data rules; parent creates account; account deletion removes all feature data | Home: inherited AD-26/27, AD-46 includes all three collections in owner-scoped recursive deletion. Parent account creation is inherited policy/product behavior, not restated. |
| §4.10-2 — Update privacy policy before release to disclose tutor access/editing and parent-visible tutor history | **DROPPED as a release artifact:** spine covers access (AD-46), history (AD-38) and analytics privacy (AD-47), but contains no privacy-policy update or release gate. This is a release/documentation task rather than a runtime architecture rule. |

## PRD §7 — Success and counter-metrics

| Source item | Spine reconciliation |
|---|---|
| SM-1 — ≥80% capture days among non-locked days over 4 weeks | Instrumentation home: AD-47 capture event with count/taps; **DROPPED (metric definition):** denominator window and locked-day exclusion are not defined in architecture. |
| SM-2 — Active sub-track with events in last 14 days among multi-source learners | Instrumentation home: AD-47 `subtrack_lifecycle`/`capture`; **DROPPED (metric definition):** population, active status, and 14-day query are not specified. |
| SM-3 — ≥90% locked days caught up within catch-up window | Instrumentation home: AD-47 `catchup_completed`; **DROPPED (metric definition):** locked-day denominator/window calculation is unspecified and catch-up window itself is omitted. |
| SM-4 — Median taps to record full day ≤4 | Instrumentation home: AD-47 capture event includes taps/count; **DROPPED (metric definition):** session/day aggregation and median are unspecified. |
| SM-5 — Forecast vs actual distinct learnt per source over school year | Instrumentation home: AD-47 `subtrack_forecast_vs_actual`; **DROPPED (metric definition):** school-year period and actual/forecast matching method are unspecified. |
| SM-C1 — Do not optimize events/day; raw count can inflate | Home: AD-47 only sends enums/counts (no refs/profile ids); **DROPPED:** explicit non-optimization guardrail is not carried into architecture. |
| SM-C2 — Do not optimize streak length; avoid Shabbos pressure/false logs | Computation source home: AD-40; **DROPPED:** the product/analytics guardrail is not stated in spine. |

## Addendum §2 — Technical notes carried from brainstorm

| Source item | Spine reconciliation |
|---|---|
| T2-1 — Keep plan/backlog derived; recompute on any input change | Home: AD-33/35 (intent stored, state derived by one reducer). |
| T2-2 — Append-only learning log; distinct learnt separate from event count | Home: AD-31/32/35. |
| T2-3 — Infer source from capture context; row supplies source | Home: AD-31 and Consistency Conventions “Source”. |
| T2-4 — Tri-state through corpus hierarchy shared by browser, picker, progress, backfill | Home: AD-35/42; feature surfaces consume same reducer. |
| T2-5 — Forecast remaining capacity before deadline with partial-window proration | Home: AD-35/44. |
| T2-6 — Ordered ground, one position, type/window/rate/weeks; share concepts with main track | Home for sub-track fields/position: AD-33/34/44. AD-49 requires the existing planner to apply ordering and FR-12a’s one-masechta rule; returned-ground placement in that ordering remains Dropped. |
| T2-7 — `kosher_dart` Shabbos/Yom-Tov/Israel rules; optional weeks prefill | Home: AD-36/37 names sacred_time/kosher_dart and learner Israel settings. **DROPPED:** optional weeks prefill behavior is not specified (see FR-6 C2). |
| T2-8 — `flutter_local_notifications` motzei reminder | Home: AD-37 shares learner lock settings with the notification scheduler; Consistency Conventions specifies one per-profile catch-up reminder scheduler derived from `lockWindows`. |
| T2-9 — Gate writes but allow reads; bias locked if lock unknown | Home: AD-36 defines fail-closed missing-location Friday–Sunday and Yom Tov equivalents, plus a conservative high-latitude fixed fallback; reads remain available. |
| T2-10 — Clone/shift prior year; derive eligible academic years | UI/workflow-level over AD-33 fields and AD-45 constraint; specific clone/year eligibility rules are absent. |
| T2-11 — PDF reports | Home: AD-48. |
| T2-12 — Existing backfill uses 2000-01-01 sentinel; verify no tap-dated production backfill before migration | Home: AD-49 retires the sentinel in favor of `beforeTracking`; inherited AD-13 makes the cutover greenfield with no migration. Legacy production-data verification is inapplicable under that accepted cutover. |

## Addendum §3 — Forecast computation notes

| Source item | Spine reconciliation |
|---|---|
| T3-1 — FR-19 only applies to whole-corpus main-track deadline goal | Home: AD-43 (one whole-corpus deadline goal), AD-35. |
| T3-2 — Each active track capacity = rate × active weeks to deadline, prorated | Home: AD-44. |
| T3-3 — Path is ordered ground from position to end, including already-learnt items | Home: AD-33/34/35; AD-35 promises exact PRD formula. |
| T3-4 — Shortfall is unlearnt path beyond capacity and returns at track end | Home: AD-35 exact PRD formula, AD-33 return-on-end. |
| T3-5 — Expected new ground = max(0, capacity − path length); empty path means full capacity | Home: AD-35 promises exact FR-19 formula. |
| T3-6 — Subtract expected new ground from main remaining; add shortfall | Home: AD-35 promises exact FR-19 formula. |
| T3-7 — Main remaining excludes learnt and ground held by active tracks; do not subtract capacity again | Home: AD-33 schedulable-set rule, AD-35 exact formula. |
| T3-8 — Count shortfall once; omit where another active holder is forecast to reach item | Home: AD-35 expressly specifies this. |
| T3-9 — Divide adjusted remaining by main-track remaining study days (default all seven) | Home: AD-35 exact PRD formula; study-day input/default is in function signature and FR-19 binding. |

## v1 findings status

| v1 Dropped/Contradicted finding | v2 status |
|---|---|
| FR-23 C6 — queued lock-window write rejected on sync (v1 Contradicted) | Fixed as an approved classification: Accepted deviation (prd-deviations #2); AD-30/36 retain then ignore the event. |
| FR-12 / FR-12a — preserve main order, one-masechta schedule, boundary-day exception and return placement | Partly fixed, therefore Still open: AD-49 explicitly retains planner ordering and one-masechta scheduling; the boundary-day exception and returned-ground placement remain unspecified. |
| FR-18 / FR-32 C1 — trailing-four-week projection, smoothing, history threshold and exact velocity filter | Still open: AD-35 owns projection but does not set the velocity window, exclusions, smoothing or minimum-history formula. |
| FR-23 / addendum T2-9 — fail-closed missing-zmanim and high-latitude fallback intervals | Fixed: AD-36 gives learner-local missing-location Friday–Sunday/Yom Tov fallback and a conservative high-latitude fallback. |
| FR-24 C1 — planned-list freeze from lock start through lock end | Fixed: AD-35 evaluates the planned list at `L.start` while inside lock L. |
| FR-25 C1/C3/C4/C6 — catch-up window/stacking, three-day cap, reminder trigger and unmarked-track exclusion | Partly fixed, therefore Still open: AD-40 defines the window and per-card windows, and AD-37/Reminders assigns a scheduler; the three-day cap, trigger timing and main/marked-only composition (also Dropped in v2 FR-25 C5) remain unspecified. |
| FR-4 C4/C5 — child re-date/removal permissions and correction-specific streak protection | Still open: AD-45 references shared FR-4 limits but the role-sensitive correction/date rules and streak restriction are not specified. |
| FR-28 C1 — revocation visibility/cache/access removal timing at next sync | Still open for next-sync propagation: AD-46/53 enforce active-grant reads and recheck grants in every callable, but do not state client cache invalidation or list refresh timing. |
| FR-6 C2 — bein-hazmanim toggle changes prefill only and preserves manual edits | Still open: no prefill/toggle semantics are added. |
| FR-17 — one-time siyum trigger and no refire on chazara | Fixed: AD-35/42 plus the Siyum convention derive completion and show once per device. |
| §4.9-3 — under-one-second, same-screen recomputation | Fixed for performance budget: AD-54 requires a <1 s mid-range benchmark for FR-19/FR-29; same-screen presentation stays UI/story-level. |
| §4.10-2 — release-time privacy-policy update and disclosure | Still open: AD-47 adds an analytics privacy release precondition, not the requested privacy-policy update/disclosure. |
| §7 SM-1–SM-5 / SM-C1–SM-C2 — metric aggregation definitions and counter-metric guardrails | Still open: AD-47 names event payloads but not the metric populations/windows/aggregation or explicit non-optimization guardrails. |
| Addendum T2-8/T2-12 — motzei reminder and legacy backfill sentinel/migration verification | Fixed for reminder ownership and sentinel: AD-37 plus Reminders convention define the scheduler; AD-49 replaces the sentinel and AD-13 establishes no migration. |

## Accepted deviations (prd-deviations.md)

| # | Reconciliation |
|---|---|
| 1 | Accepted deviation (prd-deviations #1): AD-49 replaces the event stack app-wide for every curriculum, extending the PRD’s Mishnayos/sub-track scope. |
| 2 | Accepted deviation (prd-deviations #2): AD-30/36 retain lock-stamped queued writes and exclude them from derived state instead of rejecting on sync. |
| 3 | Accepted deviation (prd-deviations #3): AD-53 limits offline capture guarantee to owner devices; tutor writes require online access. |
| 4 | Accepted deviation (prd-deviations #4): AD-34 removes future-assigned ground from main scheduling immediately, before its sub-track window begins. |
| 5 | Accepted deviation (prd-deviations #5): AD-50 adds deterministic, engine-filtered points behavior where the PRD is silent. |
| 6 | Accepted deviation (prd-deviations #6): AD-36 changes existing capture-lock margins from 18/15 to 10/10 minutes and removes the fail-open path. |
| 7 | Accepted deviation (prd-deviations #7): AD-53 requires explicit parent opt-in before existing tutor grants receive `can_edit_learning`. |
| 8 | Accepted deviation (prd-deviations #8): AD-40 does not let backdated dated events repair a streak; only date-consistent events count. |
| 9 | Accepted deviation (prd-deviations #9): AD-39’s tutor-change notification set also includes main-track order and study-day changes, and targets parent-mode sessions. |

## Open items for the architect

- **Dropped — FR-4 C3:** specify the child-facing lifetime/history treatment of voided events while retaining them in parent history.
- **Dropped — FR-12/FR-12a C1/C2:** specify returned-ground placement in original main order, the completion-boundary day exception, and when returned earlier ground is queued relative to the current masechta; AD-49 already preserves one-masechta scheduling.
- **Dropped — FR-18 C1/C3/C5 and FR-32 C1:** define observed-velocity window, before-tracking/chazara exclusions, unusual-day smoothing, minimum-history threshold, and velocity date attribution.
- **Dropped — FR-25 C3/C4/C5/C6 and FR-6b C1:** specify the consecutive locked-day cap, reminder trigger, inclusion of main and marked tracks, and exclusion of unmarked tracks.
- **Dropped — FR-4 C4/C5:** specify child correction/date-edit permissions and correction-specific streak eligibility.
- **Dropped — FR-28 C1:** define revocation propagation/cache invalidation and learner-list refresh timing.
- **Dropped — FR-6 C2/T2-7:** define bein-hazmanim weeks prefill/toggle behavior and preservation of edited weeks.
- **Dropped — §4.10-2:** add the tutor-access/history privacy-policy disclosure and release gate.
- **Dropped — §7 SM-1–SM-5/SM-C1/SM-C2:** define metric populations, periods, calculations and counter-metric guardrails.
