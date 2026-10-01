---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - docs/planning/specs/spec-sub-tracks/SPEC.md
  - docs/planning/specs/spec-sub-tracks/prd-deviations.md
  - docs/planning/specs/spec-sub-tracks/screens.md
  - docs/planning/prds/prd-sub-tracks-2026-09-30/prd.md
  - docs/planning/prds/prd-sub-tracks-2026-09-30/addendum.md
  - docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
  - docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md
  - docs/planning/ux-designs/ux-learning-tracker-2026-09-30/DESIGN.md
  - docs/planning/ux-designs/ux-learning-tracker-2026-09-30/EXPERIENCE.md
---

# Learning Tracker — Sub-tracks and the learning-event stack - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Learning Tracker — Sub-tracks and the learning-event stack, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR-1: Show one home-screen row per active sub-track beneath main-track tasks with its name and current position; preserve the main-track task list; hide ended tracks.
FR-2: Let the child record the sub-track current position with +1 or a range through a chosen later mishna with up to…; create one sourced event per included mishna and advance only that track's position; groundless rows prompt parent/tutor to add ground, disable child capture, and still contribute capacity.
FR-2a: Offer up to… with per-mishna include/exclude adjustment on sub-track rows, main-track today tasks, and catch-up; create events only for included mishnayos, without changing task generation.
FR-3: Let child/parent free-tick any corpus node and tick-to-here within its masechta; ask source once (Home default), permit Before tracking, default editable date to today; before-tracking events do not affect streak/velocity, and dated Home ticks affect streak only when learned_on matches the civil date of recorded_at [dev #8].
FR-4: Let child/parent/tutor undo or correct event place, source, or date; void originals and optionally replace them, recompute positions/target, hide voids from child but retain audit attribution; child may re-date only in catch-up window and otherwise only remove; correction cannot create/restore other streak days.
FR-4a: Make sub-tracks optional, menu-found, never prompted; mention once in onboarding without setup fields; omit Learn section when none exist.
FR-5: Let parent/tutor create school-year track with name, selectable year, editable start/end months, weekly rate, and editable weeks (prefill 39); offer current through deadline year or current plus two without deadline; enforce one per year and nonoverlapping windows; carry edited months forward; no exclusion checkboxes; prorate current part-elapsed window.
FR-6: Let parent/tutor create ongoing track with name, rate, optional bein-hazmanim toggle, editable weeks, and optional end date; allow at most five active; toggle changes only prefilled weeks and never overwrites edited weeks.
FR-6a: Allow an optional future start date; hide the track on home until then, but forecast from that date; its assigned ground leaves home scheduling immediately [dev #4].
FR-6b: Let any sub-track opt into catch-up inclusion for Shabbos/yom tov (default off); include only opted-in tracks.
FR-7: Create next academic year's school track in one action, copying name/rate/weeks and edited month bounds with all fields editable; set following-year window and empty ground.
FR-8: Let parent/tutor edit any track field or delete a track; rate edits immediately recompute target; deletion returns unfinished ground and retains events in lifetime record.
FR-9: Let child/parent/tutor view ordered ground and tri-state progress across masechtos, current position, track-ticked count, and capacity versus remaining path; outside-source learning displays as learnt without moving this position.
FR-10: Let parent/tutor incrementally assign any curriculum ground node to a sub-track; assigned ground is greyed and unscheduled on main track; allow overlapping tracks and already-learnt ground, but no duplicate node within one track or main track; scope ground levels and rates to curriculum units; reject calendar-program curricula [dev #12].
FR-11: Let parent/tutor order a sub-track's ground; append additions by default; reorder retains ticks, resets position to first unticked in new order, and recomputes forecast.
FR-12: On track end, end-date passage, or deletion, return only ground unlearnt by every source to its original main-track position; retain learnt ground; defer return while another active track holds it; recompute schedule and target.
FR-12a: Keep main-track scheduling to one masechta at a time, except a completion-day transition may span two; schedule earlier returned ground after the current masechta completes.
FR-13: Keep each track's position independent when another track learns the same mishna; any such event still marks it learnt for goal progress.
FR-14: Count distinct learnt corpus nodes across sources/date states for goal progress; repeats do not increase progress and before-tracking events do; apply learning-ledger behavior app-wide across curricula [dev #1].
FR-15: Render each corpus node empty, partial, or complete in main corpus view, browser, ground picker, and every sub-track detail; one learnt descendant makes each ancestor partial.
FR-16: Keep a separate streak per curriculum, shown for the curriculum in view; main-track/Home learning keeps it, sub-track learning does not; celebrate sub-track learning without implying it counts less; completed in-window catch-up preserves locked-day streak [dev #13].
FR-17: Celebrate once when a masechta becomes fully learnt from any source, including backfill/correction; voiding that makes it incomplete retracts the siyum, and re-completion celebrates again; chazara on a complete masechta does not fire it [dev #11].
FR-18: Show parent/tutor goal-level on-track status and projected finish on home/dashboard using distinct new learning velocity across sources excluding before-tracking/chazara over trailing four weeks; too early under two weeks, use all history at two-to-four weeks; child sees encouragement, today-vs-target and streak only, never behind/off-track; one large day alone cannot flip status.
FR-19: With deadline, compute nonnegative daily target as (main remaining − expected new ground + shortfall) / existing study days to deadline; capacity is rate × active weeks left, path is ordered remaining track ground, shortfall is unlearnt path beyond capacity, expected new ground is capacity beyond path; account for overlapping shortfall once and expected new ground fully per independent track; recompute after order, ground, rate, return, or learning changes; show zero-target bonus copy.
FR-20: Without deadline, show projected finish only, with no daily target/status and no rate-estimate effect.
FR-21: Show parent/tutor warning for each positive shortfall naming track, ground, window end and approximate returned count; clear at zero; never show child.
FR-22: Withdrawn.
FR-23: Fail closed for sacred-time capture lock across learner and tutor devices; start 10 minutes before candle-lighting and end 10 minutes after tzeis, with learner Israel/diaspora setting, location-based zmanim, and conservative fallback; retain lock-stamped events but exclude them from derived state rather than reject sync [dev #2, #6, #10]; freeze on-track status during lock.
FR-24: Show live planned learning view on erev only; during lock cover all app content with the existing opaque, unreadable, non-interactive full-screen overlay; no locked planned view [dev #10].
FR-25: After lock, offer one-tap all or adjustable per-day catch-up for up to three consecutive lock days; date events to locked days as catch-up-dated; include main track and opted-in sub-tracks only; keep card through first full unlocked day, pause across another lock, stack pending oldest first, and send one reminder when available.
FR-26: Tutor with explicit can_edit_learning grant can edit learner goal/tracks; pre-checked at invite for new grants; existing grants require parent opt-in; tutor edits require online connection and show no optimistic offline state [dev #7, #3].
FR-27: Let parent inspect and undo tutor changes with who/what/when; record undo; later concurrent edit wins and both appear; notify parent for tutor changes to goal, main track, main-track order, or study days via FCM to parent-mode sessions only; other scope/stage/learner-setting changes are history-only [dev #9].
FR-28: Let parent revoke tutor at any time; access ends on next sync while tutor-created tracks/events remain.
FR-29: Let tutor list/open all currently granted learners with on-track status; revoked learners disappear.
FR-30: Let child/parent/tutor open any mishna history with date or Before tracking, source and event count; count nonvoid events; preserve deleted track name.
FR-31: Let parent view/export continuing lifetime report with distinct learnt count, all learning events, totals by source, and same-name tracks rolled up with expandable years.
FR-32: Let parent view/export PDF of per-source velocity since tracking and on-track status; exclude before-tracking and count catch-up events on learned date.

Where `[dev #N]` appears, `spec-sub-tracks/prd-deviations.md` overrides the PRD text.

### NonFunctional Requirements

NFR-1: Owner-device learning capture works offline and syncs later; events from separate devices merge without overwriting one another (PRD §4.9; dev #14).
NFR-2: Tutor capture/edit is online-only; disable tutor UI while offline and show no optimistic state (dev #3).
NFR-3: Governed changes exceeding roughly 10 Firestore-governed documents (e.g. long reorder/order reset) require online write through writeWithChangeLog (dev #14).
NFR-4: Concurrent parent/tutor edits resolve to the later change and retain both in change history (PRD §4.9).
NFR-5: Daily-target recomputation completes in under one second on a mid-range device; updated value appears on the same screen (PRD §4.9 assumption).
NFR-6: Lock fails closed: false lock is acceptable; false unlock is not; use conservative local-time fallback if zmanim/location/window unavailable, including high latitudes (PRD §4.6; dev #6).
NFR-7: Sacred-time lock is 10 minutes before candle-lighting through 10 minutes after tzeis; use learner-level Israel/chutz-la'aretz setting and location-based zmanim (PRD §4.6; dev #6).
NFR-8: Lock-time recorded_at events remain stored but never contribute to derived state; capture lock applies on all learner and tutor devices (dev #2, #10).
NFR-9: Freeze on-track status during the lock; child-facing surfaces never expose behind/off-track/shortfall judgment (PRD FR-16, FR-18, FR-21).
NFR-10: Learner data and tutor access follow existing children's-data rules; parent creates account and deletion removes all associated tracks, events and history (PRD §4.10).
NFR-11: Before release, privacy policy discloses parent-granted tutor read/edit access and parent-visible tutor change history (PRD §4.10).
NFR-12: SM-1: any learning captured on at least 80% of non-locked days per learner over four weeks.
NFR-13: SM-2: at least one active sub-track with events in last 14 days for multi-source learners adopting sub-tracks.
NFR-14: SM-3: at least 90% of locked days caught up within catch-up window.
NFR-15: SM-4: median taps per source captured is at most four [dev #15].
NFR-16: SM-5: measure forecast error against actual distinct mishnayos per source over a school year.
NFR-17: Do not optimize raw events/day; it can be inflated by up-to ranges and chazara (SM-C1).
NFR-18: Do not optimize streak length; do not pressure children to log on sacred days or fabricate learning (SM-C2).
NFR-19: Persist tutor grant permission can_edit_learning pre-checked at invite for new grants; existing grants become editable only after explicit parent action (dev #7).
NFR-20: Enforce sub-track support only for non-calendar-program curricula; use that curriculum's own units and per-curriculum limits (dev #12).

### Additional Requirements

- AR-1: No starter template (brownfield Flutter app `learning_tracker/`). The first epic is the **learning-event cutover** (AD-49). It ships no sub-track UI and runs in a fixed order: (1) AD-52 codecs, the pure engine and predicates in `lib/domain/learner_state/`, and `LearningCommands`/`CaptureGate` with ports (Stories 1.1–1.8); (2) AD-46 rules, `writeWithChangeLog` and the rerouted callables with emulator tests (1.9–1.10); (3) one story per Retirement Inventory group R1–R16 (1.11–1.22, then R12 in 1.26 and R15 in 1.27, after the tutor stories 1.23–1.25 that their deletions depend on; R14 is split by the spine into its deny part in the cutover release 1.28 and its remove part in 1.29); (4) the cutover release (1.28). No sub-track story starts before that release ships.
- AR-2: Prerequisite: production named-app Auth wiring (parent AD-1/AD-24) is complete before any epic ships a new repository.
- AR-3: Stack bump in Epic 1: Dart SDK ^3.12.0, Flutter ≥ 3.41.6, the FlutterFire packages as one atomic bump (firebase_core ^4.15.0, cloud_firestore ^6.10.0, firebase_auth ^6.7.0, cloud_functions ^6.5.0, firebase_analytics ^12.6.0), plus new firebase_messaging ^16.7.0 and pdf ^3.13.1, with kosher_dart ^2.0.20, flutter_local_notifications ^22.3.1 and share_plus ^13.3.0.
- AR-4: New collections `learning_events`, `sub_tracks` and `change_log` (profile-scoped), with field names exactly as in the AD-52 Storage Schema table. Greenfield, so no data migration (AD-13): the old collections are retired, not converted.
- AR-5: One pure `LearnerStateEngine`, run per profile over all curricula, is the only source of every derived number. That covers learnt set, positions, schedulable set, `programAssignments`, reviews due, daily target, shortfall, projection, streak, siyumim and `earningEventIds`. There is no server-side summary (AD-35). The planner only lays out work (AD-49).
- AR-6: One write path: owner devices use `LearningCommands`; tutor devices use `TutorWriteService` → callables → the shared `writeWithChangeLog` helper. That helper applies Admin-SDK auth, grant and permission checks, a server-derived actor and full payload validation (AD-38, AD-53).
- AR-7: Governed entities (subTrack, goal, mainTrack, mainTrackOrder, mainTrackProgram, mainTrackStudyDays, mainTrackStages, mainTrackScope, learnerSettings) co-write `change_log` entries grouped by `action_id`. Writes are field-level merges, client deletes are denied (tombstones only), and undo is a new logged change per field (AD-38). `learning_order` merges into `track_learning_order`, and `bookmarks` is retired.
- AR-8: Capture lock: `lockWindows` is the only window function (10 min before candle-lighting, 10 min after tzeis), computed in the learner's IANA time zone with the settings in force at the time. The app fails closed. The full-screen overlay makes the app unreadable during a lock, and the engine ignores events recorded inside one (AD-36, AD-37). `ZmanimWindowService.computeWindows` and `SacredTimePreferences` are deleted.
- AR-9: Firestore rules: create-only plus identical replay on `learning_events`/`change_log`; field whitelists and type checks; the AD-38 owner rule with a create branch; `pts_{eventId}` doc ids. Owner batches are sized to the Rules access-call budget (≤ 20 per batch, 2 per governed doc), and larger entity writes go online through `writeWithChangeLog`. Client timestamps (`recorded_at`, `at`, `points_ledger.created_at`, `ended_at`) may be up to 10 min ahead of server time (AD-46, AD-54).
- AR-10: Operations: the local Firebase Emulator Suite plus one production project, with no staging. CI deploys rules, indexes and functions, and that step must pass before the dependent app release. Rules tests cover every AD-38 owner-rule branch, `writeWithChangeLog` has emulator tests, and an instrumented test proves an offline batch lands atomically. No new indexes (AD-54).
- AR-11: Perf gate: an engine benchmark of 20 learners × (40,000 leaf events + 200 node events) on a tutor device within the 20 MiB cache must render the tutor list (FR-29) and recompute the daily target (FR-19) in < 1 s per learner (AD-54).
- AR-12: CI checks: extend `tool/check_dependency_direction.dart` so `lib/domain/**` can't import Firestore, Riverpod or Flutter. Add `tool/check_retired_symbols.dart`, which fails on any retired symbol from the cutover release on. `tool/check_analytics_catalog.dart` covers the new analytics events.
- AR-13: Retirement Inventory R1–R16 (the spine table is the single source): completions repos and write paths, readers, planner, learning_ledger, streak, points readers, bookmarks, lock windows and settings, sentinel, notifications and backup, retired callables, governed writers, rules/indexes/deletion list, tests, retired fields.
- AR-14: Backup: export includes `learning_events`, `sub_tracks` and `change_log`. Import replays through `LearningCommands`: ids are remapped, `original_recorded_at` is kept, and `pts_` entries are not imported (AD-49).
- AR-15: Points: writers attach `pts_{eventId}` to every main dated or catch-up learn event, and only the engine's `earningEventIds` count toward the balance and lifetime total. Achievements latch (AD-50).
- AR-16: Push: the `onChangeLogCreated` function in `functions/src/notifications.ts` sends FCM to parent-mode sessions when a tutor changes the goal or main track. Tokens are registered on PIN unlock and deleted on lock. iOS needs an APNs key (AD-39).
- AR-17: Analytics: one `LearningAnalytics` emitter shared by the owner and tutor paths, sending enums and counts only. AAID, ad personalization and Google Signals are disabled (AD-47).
- AR-18: Release preconditions: the legal check on GA4 for under-13 users (bead `learning-tracker-h3f`), and a privacy-policy update disclosing tutor access and change history (bead `learning-tracker-bpo`).
- AR-19: Reports render client-side from `LearnerState` with `pdf`, an embedded Hebrew font, and unpointed Hebrew text (no nikud), and are shared via share_plus (AD-48).
- AR-20: Tutor permission `can_edit_learning` is granted only by explicit parent action, through a new `updateTutorGrantPermissions` callable and the invite checkbox. The legacy edit keys are removed (AD-53).

### UX Design Requirements

UX-DR-1: Use Learning Tracker's existing Material 3 brand: royal blue actions, cool cream canvas, flat white outlined cards; no new brand direction or photography; any human illustration is male (DESIGN §Brand & Style).
UX-DR-2: Use brand blue #1442B8 light / #7CA0FF dark for actions; blue-soft #E4EBFA / #16233F for informational fills (DESIGN §Colors).
UX-DR-3: Use cream canvas/card/recessed fills #F7F8FB/#FFFFFF/#EFF2F7 and dark #0B0F1A/#151A26/#1E2532 (DESIGN §Colors).
UX-DR-4: Use outline #D4DCE8 light / #263041 dark for 1px borders and dividers; no shadows for feature cards (DESIGN §Colors; §Elevation & Depth).
UX-DR-5: Apply ink ramp #101828 → #2B3444 → #5A6474 → #6A7484 and dark values #EAEEF5 → #C3CBD8 → #98A2B3 → #828D9E for heading/body/secondary/hints (DESIGN §Colors).
UX-DR-6: Use warning soft/deep amber #FBF0DC/#8A5306 and dark #2E220E/#F0C883 only for parent/tutor warnings/status, never child status; deep text/icons maintain stated contrast (DESIGN §Colors).
UX-DR-7: Use success green #EAF5EA/#3A7C3A and dark #173017/#9ACA9A for on-track/no-shortfall; complete tri-state uses #3BDD87/#72DEA4 (DESIGN §Colors).
UX-DR-8: Use partial tint #FFD26A, checkbox accent #FFD26A light / #E6B96A dark; empty tint #B8C0CC/#36425A with #6A7484 outline; state also shown by checkbox, count and semantics (DESIGN §Colors).
UX-DR-9: Use tutor badge fill #FFF3E0/#332713 with warning-deep label/icon/edge; use coral-soft #FDE9E2/#2E1C14 for catch-up tag and gold-soft #E3EDD3/#1B2A12 with curriculum green for Before tracking badge (DESIGN §Colors).
UX-DR-10: Maintain ≥4.5:1 text and ≥3:1 non-text contrast; tri-state row tint is decorative at 12% alpha (DESIGN §Colors).
UX-DR-11: Use Plus Jakarta Sans for Latin; Noto Sans Hebrew for Hebrew script at 16px/1.6; Hebrew Terms controls Hebrew-script vs transliteration (DESIGN §Typography).
UX-DR-12: Apply headline-small 24/600/1.4, title-medium 18/600/1.4, title-small 16/600/1.4, body-medium 14/400/1.5, body-small 12/400/1.5, label-large 14/500/1.4, label-small 11/500/1.4; app-bar title 18/700/0.3px; buttons 15/600 and chips 13 inherited (DESIGN §Typography).
UX-DR-13: Use radii checkbox 4, tag 6, text button 8, input 12, card 18, chip 20, sheet top 24, app dialog 28, pill 9999 (button actual 30) (DESIGN §Shapes).
UX-DR-14: Use 12px / 24px spacing, 16dp phone gutters, 48dp minimum target, 6dp progress bar, 480px dialog max, 600px form max, 240px nav rail, and 20dp tree indent (DESIGN §Layout & Spacing; frontmatter).
UX-DR-15: Keep all new cards/surfaces elevation 0 with 1px outlines and tone steps; do not reuse shadowed StatCard without flat variant (DESIGN §Elevation & Depth).
UX-DR-16: Render each active sub-track as an outlined card with source icon, title, next-position text, optional Hebrew reference, then exactly Up to… and +1 actions; show section header/count; groundless rows replace position with helper text and disabled actions, without source/rate/pace badges (DESIGN §Components; EXPERIENCE §Component Patterns).
UX-DR-17: Style +1 as blue filled pill and Up to… as blue text button, both ≥48dp high (DESIGN §Components).
UX-DR-18: Present up-to picker as rounded-top sheet on phone or centered rounded dialog on tablet; include title/close, instruction, ordered rows with checkbox and Included/Skipped/Next up state, highlighted target, Cancel and live-count Record button (DESIGN §Components).
UX-DR-19: Tri-state row uses complete checked / partial dash / empty checkbox, 12% tint, 20dp indentation per depth, expand chevron, counts, and Complete·Partial·Empty legend in picker (DESIGN §Components).
UX-DR-20: Free-tick browser rows share tri-state styling; long-press a mishna for Tick up to here; confirm batch via source radios (Home default, active tracks, Before tracking), editable today-default date and Record count (DESIGN §Components).
UX-DR-21: Source chips are display-only rounded tags with icon/label, keyed by Home/school-year/ongoing source type; deleted tracks retain event-time name (DESIGN §Components; EXPERIENCE §Component Patterns).
UX-DR-22: Shortfall card uses amber soft fill/deep icon and text, warning icon, message, View School action; full width under on-track card, parent/tutor only (DESIGN §Components).
UX-DR-23: On-track card shows icon and text status, projected finish and daily target; status variants On track, Behind pace, Too early to tell (DESIGN §Components).
UX-DR-24: Status chips use success, neutral, and amber pill treatments for on-track, too-early, behind-pace (DESIGN §Components).
UX-DR-25: Dashboard sub-track summary card shows name, next position, ticked count, animated progress bar, Sub-tracks count header and Manage action (DESIGN §Components).
UX-DR-26: Capacity bar shows Capacity vs Path, numerator/denominator, 6dp bar, remaining-path/total-capacity caption, no-shortfall tag or parent/tutor-only shortfall tag (DESIGN §Components).
UX-DR-27: Ground row shows drag handle, tri-state checkbox, name/Hebrew, learnt count/range, chevron, and other-source learnt attribution; child view is read-only (DESIGN §Components; EXPERIENCE §Component Patterns).
UX-DR-28: Add-next-year action is outlined pill and remains visibly disabled if year already used (DESIGN §Components).
UX-DR-29: Delete action opens existing confirm dialog with warning icon, consequence copy, destructive confirm and Cancel (DESIGN §Components).
UX-DR-30: Ground picker is full-screen on phone with search, scope/availability/Hebrew filters, corpus tri-state tree, in-use and Chazara tags, sticky reset/add footer and home-schedule explanation (DESIGN §Components).
UX-DR-31: Sub-track forms use filled inputs, rate stepper/helper, weeks field/helper, sacred-day and (ongoing only) bein-hazmanim switches, info note and Save pill (DESIGN §Components).
UX-DR-32: Academic-year picker is a horizontal single-select year-chip row with Used (disabled), Active or Open labels (DESIGN §Components; EXPERIENCE §Component Patterns).
UX-DR-33: Info note is static blue-soft card with info icon and one sentence; onboarding mention is one such note, no link/button, setup or repeat (DESIGN §Components).
UX-DR-34: Erev view shows blue-soft Shabbos banner with English/Hebrew label and lock time, then live Planned for Shabbos main-track rows and live Also learning rows; this is not shown during lock (DESIGN §Components; EXPERIENCE §Shabbos & Yom Tov; dev #10).
UX-DR-35: During lock, show the opaque existing SacredTimeLockOverlay across app with sacred-time background, white icon/greeting; block back navigation and all screen-reader access behind it (DESIGN §Components; dev #10).
UX-DR-36: Disabled actions remain visible at 40% opacity without ripple, muted label, full touch size, and disabled semantics for groundless child actions, used years, unavailable next year (DESIGN §Components).
UX-DR-37: Catch-up card sits at Learn top, calendar icon, question and availability caption, Yes all primary and Adjust outlined; Adjust expands in place into per-source/day groups with Up to…, individual ticks and Record count (DESIGN §Components; EXPERIENCE §Shabbos & Yom Tov).
UX-DR-38: Tutor-mode bar is full-width beneath app bar with tutor label and Switch action, amber accessible accent (DESIGN §Components).
UX-DR-39: Talmid row is outlined card with initials avatar, name, status chip, next-position/no-ground detail, chevron; append access-boundary info note (DESIGN §Components).
UX-DR-40: Change-history timeline groups by day and shows actor/avatar/role/time/action, Undo, Undone state, bell when parent notified, and All/Tutor/Parent/Learning filters (DESIGN §Components).
UX-DR-41: Mishna history header shows Learnt and event count; newest-first numbered event rows include date/Before-tracking badge, source chip, catch-up and chazara tags; footer explains repeats don't add goal progress (DESIGN §Components).
UX-DR-42: Per-source pace row shows source chip, measured weekly value, estimate caption and Last 30 days; omit On pace/Steady labels (DESIGN §Components).
UX-DR-43: Lifetime school-year row rolls same-name tracks into expandable total and per-year lines; totals use headline numerals; Export PDF primary pill (DESIGN §Components).
UX-DR-44: Manage tracks ends with collapsed Ended sub-tracks count and muted ended rows (DESIGN §Components).
UX-DR-45: Tablet navigation rail uses card surface, right border, labeled Dashboard/Learn/Progress/Settings destinations and blue selected indicator (DESIGN §Components).
UX-DR-46: Keep Learn tab Also learning section beneath today's tasks for child, parent and tutor (EXPERIENCE §Information Architecture).
UX-DR-47: Open Up-to picker from sub-track row, main-track list or catch-up Adjust (EXPERIENCE §Information Architecture).
UX-DR-48: Show Dashboard on-track/shortfall surface only to parent/tutor (EXPERIENCE §Information Architecture).
UX-DR-49: Show Dashboard sub-track summary cards to child, parent and tutor (EXPERIENCE §Information Architecture).
UX-DR-50: Place Manage tracks hub under Settings for parent/tutor (EXPERIENCE §Information Architecture).
UX-DR-51: Provide new/edit school-year sub-track form and Add next year flow (EXPERIENCE §Information Architecture).
UX-DR-52: Provide new/edit ongoing sub-track form (EXPERIENCE §Information Architecture).
UX-DR-53: Open sub-track detail from hub, Learn row, summary card or warning (EXPERIENCE §Information Architecture).
UX-DR-54: Open ground picker from detail or groundless row (EXPERIENCE §Information Architecture).
UX-DR-55: Show erev planned view in Learn from erev window until lock (EXPERIENCE §Information Architecture).
UX-DR-56: Apply existing lock overlay automatically app-wide on every signed-in device (EXPERIENCE §Information Architecture).
UX-DR-57: Show catch-up card at top of Learn after lock (EXPERIENCE §Information Architecture).
UX-DR-58: Provide tutor My talmidim surface on tutor device (EXPERIENCE §Information Architecture).
UX-DR-59: Provide new parent-scoped Change history across parent and all tutors (EXPERIENCE §Information Architecture).
UX-DR-60: Open Mishna history from any mishna in browser, lifetime tree, detail or ground row (EXPERIENCE §Information Architecture).
UX-DR-61: Put Lifetime report and per-source report under Progress → Lifetime → Report for parent (EXPERIENCE §Information Architecture).
UX-DR-62: Keep Corpus browser free-tick flow under existing Browse (EXPERIENCE §Information Architecture).
UX-DR-63: Grey assigned ground in existing corpus progress/browse views (EXPERIENCE §Information Architecture).
UX-DR-64: Put one static sub-track info note in existing onboarding step for parent (EXPERIENCE §Information Architecture).
UX-DR-65: Retain existing Manage tutors revoke flow (EXPERIENCE §Information Architecture).
UX-DR-66: Keep optional sub-tracks absent from Learn and Dashboard without active tracks; no nudges or creation prompts (EXPERIENCE §Foundation; §State Patterns).
UX-DR-67: Child copy is warm, brief and forward-looking: counts/next steps only; never imply outside learning doesn't count or show judgment/behind/shortfall (EXPERIENCE §Voice and Tone).
UX-DR-68: Parent copy uses plain named track/ground, approximate counts and explains consequence as return to home learning; tutor copy uses parent register scoped to their track and repeats access boundary (EXPERIENCE §Voice and Tone).
UX-DR-69: Use approved strings for Learn section, position, actions, picker labels, encouragement, status, zero target and shortfall, plus hub, forms, detail, picker, erev, catch-up, tutor, history and report (EXPERIENCE §Voice and Tone).
UX-DR-70: Use “Learning events” as total-record label; avoid “Reviews”; call ended tracks “Ended sub-tracks,” not completed where unfinished ground remains (EXPERIENCE §Voice and Tone).
UX-DR-71: Order active rows by hub order; hide future-start and ended tracks; absent section when no active tracks; tap row opens detail; groundless child actions disabled, parent/tutor Add ground; no source picker (EXPERIENCE §Component Patterns).
UX-DR-72: Up-to picker starts at current position, target tap includes through target; allow individual untick/retick, live count, Cancel/swipe dismiss, write only included events and set position to first unticked (EXPERIENCE §Component Patterns).
UX-DR-73: Derive tri-state from all-source learned descendants; checkbox selects/ticks, label expands parent or opens leaf history (EXPERIENCE §Component Patterns).
UX-DR-74: Free-tick batch asks source once, defaults Home, supports Before tracking, editable date, and excludes before-tracking from streak/velocity (EXPERIENCE §Component Patterns).
UX-DR-75: Parent/tutor Dashboard hides status from child, shows projection variants and no-deadline projection-only; freeze during lock (EXPERIENCE §Component Patterns).
UX-DR-76: Show one shortfall warning per positive-shortfall track, clear at zero, View action opens detail, hide from child (EXPERIENCE §Component Patterns).
UX-DR-77: Summary card opens detail, Manage opens hub; progress ratio follows stated ticked/(ticked+remaining) assumption (EXPERIENCE §Component Patterns).
UX-DR-78: Reorder ground by drag; preserve ticks, reset position, recompute forecast/main schedule/today tasks; append new ground; removal returns unlearnt ground at original home position (EXPERIENCE §Component Patterns).
UX-DR-79: Ground picker multi-selects any level and descendants; prechecks/disables same-track nodes; allows other-track and chazara assignments with tags; Available only filters those; footer count live; confirm appends and recomputes schedule/target; Reset clears pending selection (EXPERIENCE §Component Patterns).
UX-DR-80: Validate forms on blur/save; disable used year rather than hide; enforce year boundaries/nonoverlap and five-active limit; bein-hazmanim changes only unedited prefilled weeks; save rate edit recomputes target (EXPERIENCE §Component Patterns).
UX-DR-81: Delete confirmation states unfinished ground returns and events remain; confirm returns to hub, recomputes and shows snackbar; cancel/dismiss closes (EXPERIENCE §Component Patterns).
UX-DR-82: Ended tracks group is collapsed, read-only, excluded from five-track limit (EXPERIENCE §Component Patterns).
UX-DR-83: Tutor row opens learner context through configured PIN gate; revoked learner disappears next sync; Add ground deep-links to learner picker (EXPERIENCE §Component Patterns).
UX-DR-84: History Undo records a new Reverted change entry, marks original Undone and prevents repeat undo; log concurrent changes; notification rules follow FR-27 (EXPERIENCE §Component Patterns).
UX-DR-85: Offline owner capture shows shell offline banner as applicable and merges events; tutor writes disabled offline; large governed multi-document changes require connection and no optimistic state (EXPERIENCE §State Patterns; dev #3, #14).
UX-DR-86: Use existing loading/error/retry widgets; no target spinner because recompute is under one second (EXPERIENCE §Foundation; §State Patterns).
UX-DR-87: With no sub-tracks, omit Learn section and Dashboard summaries; show no invitation to create (EXPERIENCE §State Patterns).
UX-DR-88: Groundless Learn row says No ground yet and disables child actions; parent/tutor sees Add ground; forecast still counts capacity (EXPERIENCE §State Patterns).
UX-DR-89: Hide future-start track from Learn; show Starts {date} in hub (EXPERIENCE §State Patterns).
UX-DR-90: Hide ended track from Learn and list it under Ended sub-tracks (EXPERIENCE §State Patterns).
UX-DR-91: Show partial/complete/empty corpus state; outside-source ground says learnt at home/source without changing position (EXPERIENCE §State Patterns).
UX-DR-92: Tag overlapping ground as {name} · In use and keep positions independent (EXPERIENCE §State Patterns).
UX-DR-93: Keep assigned main-track ground visible but grey/unscheduled with holding-track tag; queue earlier returned ground after current masechta (EXPERIENCE §State Patterns).
UX-DR-94: Show Too early to tell below two weeks and Behind pace only to parent/tutor (EXPERIENCE §State Patterns).
UX-DR-95: With no deadline, show projected finish only (EXPERIENCE §State Patterns).
UX-DR-96: For zero target, show All covered — any extra learning is a bonus (EXPERIENCE §State Patterns).
UX-DR-97: Show shortfall warning and capacity tag only to parent/tutor; clear at zero (EXPERIENCE §State Patterns).
UX-DR-98: Erev state has banner and live planned list; locked state has overlay and frozen on-track status (EXPERIENCE §State Patterns; dev #10).
UX-DR-99: If location/zmanim unavailable, use conservative fallback lock and prompt parent to set location after lock (EXPERIENCE §State Patterns).
UX-DR-100: Show catch-up pending, stacked or expired state on Learn per catch-up rules (EXPERIENCE §State Patterns).
UX-DR-101: Show shell offline banner for owner capture where applicable; tutor capture disabled offline and large governed changes require connection (EXPERIENCE §State Patterns; dev #3, #14).
UX-DR-102: Use existing LoadingIndicator, AppErrorView and InlineAsyncError with retry; don't show target spinner for sub-second recompute (EXPERIENCE §State Patterns).
UX-DR-103: At ongoing limit, disable Add sub-track → Ongoing and show five-in-use message (EXPERIENCE §State Patterns).
UX-DR-104: Trigger siyum celebration when distinct learning completes masechta; chazara does not repeat it (EXPERIENCE §State Patterns).
UX-DR-105: Learn/Also learning empty state omits section when there are no active tracks (EXPERIENCE §State Patterns · Per surface).
UX-DR-106: Learn/Also learning load or error state uses inline retry; main tasks remain unaffected (EXPERIENCE §State Patterns · Per surface).
UX-DR-107: Learn rejected-sync state explains lock-time event or missing track in snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-108: Up-to picker empty state says no more mishnayos in the track's ground (EXPERIENCE §State Patterns · Per surface).
UX-DR-109: Up-to picker load/error state shows inline retry and disables confirm (EXPERIENCE §State Patterns · Per surface).
UX-DR-110: Up-to picker rejected-sync state uses Learn rollback snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-111: Dashboard status empty state shows no deadline or Too early to tell; no shortfall means no warning (EXPERIENCE §State Patterns · Per surface).
UX-DR-112: Dashboard status load/error state shows inline error with retry (EXPERIENCE §State Patterns · Per surface).
UX-DR-113: Dashboard status rejected-sync state is not applicable because surface is read-only (EXPERIENCE §State Patterns · Per surface).
UX-DR-114: Dashboard summary empty state omits cards when no active tracks (EXPERIENCE §State Patterns · Per surface).
UX-DR-115: Dashboard summary load/error state shows inline error per section (EXPERIENCE §State Patterns · Per surface).
UX-DR-116: Dashboard summary rejected-sync state is not applicable because surface is read-only (EXPERIENCE §State Patterns · Per surface).
UX-DR-117: Manage tracks empty state shows group header and Add sub-track only (EXPERIENCE §State Patterns · Per surface).
UX-DR-118: Manage tracks load/error state uses existing TrackManagementBody error state (EXPERIENCE §State Patterns · Per surface).
UX-DR-119: Manage tracks rejected edit rolls back with Your change couldn't be saved snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-120: Sub-track form load/error save failure retains values and shows retryable error snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-121: Sub-track form rejected-sync removes created track and shows save-failure snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-122: Sub-track detail groundless state shows empty ground list and Add ground (EXPERIENCE §State Patterns · Per surface).
UX-DR-123: Sub-track detail load/error state uses AppErrorView with retry (EXPERIENCE §State Patterns · Per surface).
UX-DR-124: Sub-track detail rejected reorder/remove rolls back with snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-125: Ground picker empty Available only state says everything is assigned or learnt (EXPERIENCE §State Patterns · Per surface).
UX-DR-126: Ground picker load/error state uses AppErrorView with retry (EXPERIENCE §State Patterns · Per surface).
UX-DR-127: Ground picker rejected assignment rolls back with snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-128: Erev empty state shows banner without planned list (EXPERIENCE §State Patterns · Per surface).
UX-DR-129: Erev load/error state follows Learn inline retry treatment (EXPERIENCE §State Patterns · Per surface).
UX-DR-130: Erev rejected-sync state follows Learn rollback snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-131: Catch-up empty state omits card when nothing planned and no source opted in (EXPERIENCE §State Patterns · Per surface).
UX-DR-132: Catch-up load/error state shows inline error while keeping card available (EXPERIENCE §State Patterns · Per surface).
UX-DR-133: Catch-up rejected-sync state says Couldn't save — try again before the card expires (EXPERIENCE §State Patterns · Per surface).
UX-DR-134: My talmidim empty state says a parent must grant access (EXPERIENCE §State Patterns · Per surface).
UX-DR-135: My talmidim load/error state uses AppErrorView with retry (EXPERIENCE §State Patterns · Per surface).
UX-DR-136: My talmidim revoked-access state discards edits and says access has ended (EXPERIENCE §State Patterns · Per surface).
UX-DR-137: Change history empty state says No changes yet (EXPERIENCE §State Patterns · Per surface).
UX-DR-138: Change history load/error state uses AppErrorView with retry (EXPERIENCE §State Patterns · Per surface).
UX-DR-139: Change history rejected undo rolls back with snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-140: Mishna history empty/unlearnt state shows Not learnt yet and empty list (EXPERIENCE §State Patterns · Per surface).
UX-DR-141: Mishna history load/error state uses AppErrorView with retry (EXPERIENCE §State Patterns · Per surface).
UX-DR-142: Mishna history rejected correction rolls back with snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-143: Lifetime report empty state shows zero totals and only Distinct · 0 (EXPERIENCE §State Patterns · Per surface).
UX-DR-144: Lifetime report load/error state uses AppErrorView with retry (EXPERIENCE §State Patterns · Per surface).
UX-DR-145: Lifetime export failure offers Retry, keeps report visible and shares no partial file (EXPERIENCE §Key Flows UJ-6).
UX-DR-146: Corpus browser free-tick load/error state uses existing browse error treatment (EXPERIENCE §State Patterns · Per surface).
UX-DR-147: Corpus browser rejected free-tick state follows Learn rollback snackbar (EXPERIENCE §State Patterns · Per surface).
UX-DR-148: In UJ-1, child records main tasks in morning then sub-track ranges at bedtime from Learn without source picker; count/progress/streak/siyum update and parent sees status (EXPERIENCE §Key Flows UJ-1).
UX-DR-149: In UJ-2, tutor opens My talmidim, creates ongoing track, adds ground, corrects history, and sees each learner's standing (EXPERIENCE §Key Flows UJ-2).
UX-DR-150: In UJ-3, parent creates school-year track without ground, adds ground later, sees warning if shortfall, then next year flow (EXPERIENCE §Key Flows UJ-3).
UX-DR-151: In UJ-4, erev controls stay live, lock overlay blocks app, then catch-up records locked-day events and streak (EXPERIENCE §Key Flows UJ-4; dev #10).
UX-DR-152: In UJ-5, onboarding mentions where tracks live once; families without tracks see no Learn/Dashboard section or nudges (EXPERIENCE §Key Flows UJ-5).
UX-DR-153: In UJ-6, mishna history preserves repeats by source/date while goal counts distinct; parent exports lifetime/per-source report to system share/save (EXPERIENCE §Key Flows UJ-6).
UX-DR-154: Provide undo snackbar after +1, range record, catch-up all and free-tick batch; undo voids events; parent undoes tutor changes in history (EXPERIENCE §Interaction Primitives).
UX-DR-155: Support tree/group expansion, reorder with drag and accessible move alternatives, no hover-only controls or modal stacks beyond one deep (EXPERIENCE §Interaction Primitives).
UX-DR-156: Make all interactive targets ≥48×48dp and honor platform text scaling; rows stack name/position above actions at large sizes and Hebrew marks never clip (EXPERIENCE §Accessibility Floor).
UX-DR-157: Expose accessible labels for sub-track rows/actions, tri-state values, picker included/skipped and live count; status communicated as text, not color alone (EXPERIENCE §Accessibility Floor).
UX-DR-158: Keep disabled controls in accessibility tree; announce disabled state (EXPERIENCE §Accessibility Floor).
UX-DR-159: Make erev banner first focusable element after app bar, announce lock start; lock greeting announced and no content behind reachable (EXPERIENCE §Accessibility Floor).
UX-DR-160: Follow reading-order focus; tablet list precedes detail; picker opens focused on title and returns focus to trigger; provide non-drag reorder control (EXPERIENCE §Accessibility Floor).
UX-DR-161: Respect reduce-motion for progress and siyum; inherit Hebrew locale RTL and mirror drag handles/chevrons/next direction with directional insets (EXPERIENCE §Accessibility Floor).
UX-DR-162: Use phone layout below 600dp with bottom nav, 600–839dp rail/single pane, ≥840dp rail/two-pane; form max width and adjacent summary panel as specified (EXPERIENCE §Responsive & Platform).
UX-DR-163: In tablet two-pane, retain list selection and update detail in place; up-to picker is centered dialog (EXPERIENCE §Responsive & Platform).
UX-DR-164: Provide dedicated tablet composition for Learn, dashboard, hub/detail, forms, ground picker, catch-up, talmidim, histories and reports (DESIGN §Layout & Spacing; EXPERIENCE §Responsive & Platform).
UX-DR-165: Follow system dark mode using each token's dark value; apply dark phone mock palettes and same tokens to tablet (DESIGN §Colors; EXPERIENCE §Foundation; §Responsive & Platform).
UX-DR-166: Provide iOS/Android parity; platform back pops one level and dismisses picker without recording; during lock back is blocked (EXPERIENCE §Responsive & Platform).
UX-DR-167: Keep main task generation unchanged; sub-tracks optional, no prompts/gap questions, no new school calendars/imports/accounts, no cross-track position sync/deduplication (EXPERIENCE §Foundation; PRD §5).

The UX contract (DESIGN.md / EXPERIENCE.md) is a draft; where it conflicts with the spec or spine, they win.

### FR Coverage Map

FR-1: Epic 2 - home-screen sub-track rows
FR-2: Epic 2 - +1 and up to… on sub-track rows
FR-2a: Epic 2 - up to… with individual adjustment on sub-track rows and the main-track list (the catch-up card variant lands in Epic 3)
FR-3: Epic 1 - free tick, tick-to-here and before-tracking capture in the corpus browser (Story 1.11); sub-tracks as a free-tick source in Epic 2 (Story 2.10)
FR-4: Epic 1 - void/replace corrections with child limits (Stories 1.7, 1.13); sub-tracks as a correction source in Epic 2 (Story 2.10)
FR-4a: Epic 2 - optional sub-tracks found in the menu; onboarding mention
FR-5: Epic 2 - school-year sub-track
FR-6: Epic 2 - ongoing sub-track
FR-6a: Epic 2 - future start
FR-6b: Epic 2 - learns-on-shabbos flag (stored and edited; consumed by Epic 3)
FR-7: Epic 2 - add next year
FR-8: Epic 2 - edit and delete
FR-9: Epic 2 - sub-track detail
FR-10: Epic 2 - assign ground
FR-11: Epic 2 - order ground
FR-12: Epic 2 - return ground when a sub-track ends
FR-12a: Epic 1 - one masechta at a time on the main track (engine plus planner)
FR-13: Epic 2 - tracks are independent
FR-14: Epic 1 - distinct-count goal progress
FR-15: Epic 1 - tri-state everywhere (extended to the ground picker and sub-track detail in Epic 2)
FR-16: Epic 1 - per-curriculum streak from home learning
FR-17: Epic 1 - siyum fires, retracts on void, re-celebrates
FR-18: Epic 2 - on track at a glance (parent) and encouragement only (child)
FR-19: Epic 2 - daily target credits sub-track capacity and shortfall
FR-20: Epic 2 - no deadline: projection only
FR-21: Epic 2 - shortfall warning
FR-22: withdrawn
FR-23: Epic 1 - fail-closed unreadable capture lock on lockWindows (10/10); FR-23 freeze clause (on-track status frozen during the lock): Story 2.3
FR-24: Epic 3 - erev planned view
FR-25: Epic 3 - catch-up card, reminder and streak preservation
FR-26: Epic 4 - tutor edits (online, can_edit_learning)
FR-27: Epic 4 - parent change history, undo and push (the change_log infrastructure lands in Epic 1)
FR-28: Epic 4 - revoking a tutor
FR-29: Epic 4 - multi-talmid list
FR-30: Epic 1 - mishna history
FR-31: Epic 5 - lifetime report
FR-32: Epic 5 - per-source report (PDF)

## Epic List

### Epic 1: One learning record, everywhere (learning-event cutover)
Every curriculum's progress, tri-state fill, per-curriculum streak, siyumim, points, plan and calendar programs are computed from one append-only learning-event log by one engine. Corrections, free ticks and before-tracking backfill work everywhere. The shabbos and yom tov lock is unreadable and fails closed on the new 10/10 windows. Main-track settings changes are recorded in the change log. Ships no sub-track UI. Stories follow AR-1: (1) engine, codecs and command layer (1.1–1.8); (2) rules, writeWithChangeLog and rerouted callables (1.9–1.10); (3) Retirement Inventory groups R1–R16, one story per group (1.11–1.22, 1.26–1.27), with tutor basics (1.23–1.25) before the R12/R15 stories; (4) the cutover release (1.28), then the release-after cleanup (1.29).
**FRs covered:** FR-3, FR-4, FR-12a, FR-14, FR-15, FR-16, FR-17, FR-23, FR-30
**NFRs:** NFR-1, NFR-3, NFR-4, NFR-5, NFR-6, NFR-7, NFR-8, NFR-10 · **ARs:** AR-1–AR-15, AR-17, AR-20

### Epic 2: Sub-tracks and an honest daily target
Parents (and, from Epic 4, tutors) add optional school-year and ongoing sub-tracks on any non-calendar curriculum. Children capture on them from home rows with +1 and up to…. Parents and tutors assign and order ground (children read-only), and unfinished ground returns when a sub-track ends. The main-track daily target credits sub-track capacity and adds back the shortfall. The parent sees on-track status, the projected finish and shortfall warnings; the child sees encouragement only.
**FRs covered:** FR-1, FR-2, FR-2a, FR-4a, FR-5, FR-6, FR-6a, FR-6b, FR-7, FR-8, FR-9, FR-10, FR-11, FR-12, FR-13, FR-18, FR-19, FR-20, FR-21
**NFRs:** NFR-9, NFR-12, NFR-13, NFR-15, NFR-16, NFR-20 · depends on Epic 1's cutover release

### Epic 3: Erev and catch-up
On erev the learner sees what is planned for the locked days. After shabbos or yom tov, a catch-up card (one tap, or Adjust…) records that learning dated to the locked days, with a reminder notification, and keeps the streak.
**FRs covered:** FR-24, FR-25
**NFRs:** NFR-14, NFR-18

### Epic 4: Rebbe on their own phone, with parent history and undo
A tutor granted `can_edit_learning` maintains a talmid's main track, deadline and sub-tracks online, and sees all their talmidim with status in one list. The parent sees every change, undoes field by field, gets a push on goal or main-track changes, grants permission, and can revoke access.
**FRs covered:** FR-26, FR-27, FR-28, FR-29 (tutor learning capture/correction and the grant toggle ship in Epic 1, Stories 1.23–1.25)
**NFRs:** NFR-2, NFR-11, NFR-19 · **ARs:** AR-16, AR-18

### Epic 5: Lifetime record and reports
The parent views and exports a lifetime report and a per-source velocity report as PDF, with same-named sub-tracks rolled up by year.
**FRs covered:** FR-31, FR-32
**ARs:** AR-19

Release preconditions, tracked as beads rather than stories: the GA4 under-13 legal check (`learning-tracker-h3f`) and the privacy-policy update (`learning-tracker-bpo`).

## Epic 1: One learning record, everywhere (learning-event cutover)

Every curriculum's progress, tri-state fill, per-curriculum streak, siyumim, points, plan and calendar programs are computed from one append-only learning-event log by one pure engine. Corrections, free ticks and before-tracking backfill work everywhere. The shabbos and yom tov lock is unreadable and fails closed on the new 10/10 windows. Main-track settings changes are recorded in the change log. Tutors keep capturing and correcting learning and editing the main track through the cutover, behind one parent-granted `can_edit_learning` permission. Ships no sub-track UI. There are no existing users, so nothing is migrated (AD-13). Stories follow AR-1 / AD-49 sequencing: (1) engine, codecs and command layer (1.1–1.8); (2) rules, `writeWithChangeLog` and rerouted callables (1.9–1.10); (3) Retirement Inventory groups, one story per group: R2+R10 (1.11), R3 (1.12), mishna history on the engine (1.13), R13 (1.14), R4 (1.15), R8 (1.16), R5+R6 (1.17), R7 (1.18), R9 (1.19), R11 (1.20), R1 (1.21), R16 (1.22); (4) tutor basics on the new record (1.23–1.25); then R12 (1.26) and R15 (1.27), which depend on the tutor callables; (5) the cutover release (1.28, R14 deny part), then the release-after cleanup (1.29, R14 remove part). Each Retirement Inventory story ports or deletes the tests of the code it deletes, so the suite stays green after every story. Stories 1.1–1.27 deploy nothing to production; rules and functions are verified on the emulator only.

**Release precondition:** parent AD-1/AD-24 production named-app Auth wiring (AR-2; bead `learning-tracker-gd7`) is complete before Story 1.2 starts and before this epic's release.

Paths are relative to `learning_tracker/` unless noted. Spine = `docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md`; dev #N = `docs/planning/specs/spec-sub-tracks/prd-deviations.md` row N.

### Story 1.1: Stack bump and pure-domain guard

As a developer,
I want the FlutterFire stack and SDK floor bumped in one step and a CI guard that keeps `lib/domain/**` pure,
So that the engine every learner's numbers come from can never quietly depend on Firestore, Riverpod or Flutter, and later stories build on the target stack.

**Requirements:** AR-3, AR-12 (dependency-direction part); spine Stack table; AD-35 (purity), parent AD-23/AD-28

**Acceptance Criteria:**

**Given** `pubspec.yaml` today (`sdk: ^3.10.8`, `firebase_core ^4.4.0`, `cloud_firestore ^6.1.2`, `firebase_auth ^6.1.4`, `cloud_functions ^6.2.0`, `firebase_analytics ^12.3.0`)
**When** the bump lands
**Then** `environment.sdk` is `^3.12.0`, the Flutter floor is 3.41.6, and `firebase_core ^4.15.0`, `cloud_firestore ^6.10.0`, `firebase_auth ^6.7.0`, `cloud_functions ^6.5.0`, `firebase_analytics ^12.6.0` change in the same commit
**And** `firebase_messaging ^16.7.0` and `pdf ^3.13.1` are added, and `kosher_dart ^2.0.20`, `flutter_local_notifications ^22.3.1`, `share_plus ^13.3.0` are set; iOS/macOS deployment targets are raised to 13.0/10.15 as `share_plus` 13 requires.

**Given** the bumped stack
**When** `flutter analyze`, the full `flutter test` suite, `make test-rules` and `make test-functions` run
**Then** all pass with no behaviour change: every existing screen, the main-track today list and notifications behave exactly as before
**And** any breaking API change in the bumped packages is fixed at the call site, not by pinning a package back.

**Given** `tool/check_dependency_direction.dart`
**When** it is extended
**Then** it fails on any `lib/domain/**/*.dart` import of `package:cloud_firestore`, `package:firebase_*`, `package:flutter/`, `package:flutter_riverpod`, `package:riverpod*`, or `package:learning_tracker/data/**`
**And** it is a hard gate (no baseline), with unit tests in `test/tool/` covering one passing and one failing fixture per forbidden import family.

**Given** the empty `lib/domain/learner_state/` and `lib/domain/learner_state/ports/` directories are created with a placeholder library
**When** CI runs
**Then** the extended checker passes on the tree and is wired into `ci.yml` / `make ci`.

### Story 1.2: Learning-event model, codecs and repositories

As a developer,
I want the AD-52 types and codecs, the `learning_events` and `sub_tracks` repositories and the ports `LearningCommands` will depend on,
So that every learner's record is read and written with exactly the storage field names, and the engine always receives a complete log.

**Requirements:** AD-31, AD-38 (sub-track governed write), AD-41, AD-46, AD-52, AD-35 (complete inputs), AR-2, AR-4, AR-9 (codec half); parent AD-1/AD-2/AD-24, AD-5, AD-9

**Acceptance Criteria:**

**Given** the parent AD-1/AD-24 production named-app Auth wiring (AR-2)
**When** this story starts
**Then** it is verified complete (bead id recorded here); if not, this story is blocked.

**Given** the Storage Schema table
**When** the Dart types are added under `lib/domain/learner_state/` (`LearningEvent`, `NodeEntry`, `ChangeLogEntry`, `LearnerSettings`, `MainTrackIntent`, `SubTrack`, `Actor`)
**Then** each codec round-trips exactly the AD-52 field names (`kind`, `curriculum_id`, `ref`, `level`, `source`, `date_state`, `learned_on`, `stage`, `target_id`, `original_recorded_at`, `recorded_at`, `actor{uid, role, display_name}`; `entity`, `entity_id`, `action_id`, `reverts_action_id`, `before`, `after`, `at`, `original_at`) and emits no other key
**And** a golden-map test per type fails if a field is added, renamed or dropped without editing the schema table.

**Given** a `learn` event
**When** it is encoded
**Then** encoding rejects: `void` without `target_id`; `learn` with `target_id`; `level` on a non-`before_tracking` event; `stage` on a `source != main` event; `learned_on` not matching `^\d{4}-\d{2}-\d{2}$`; `learned_on == null` unless `date_state == before_tracking`; `actor.role` outside `{parent, child, tutor}`.

**Given** any event
**When** `effectiveAt(e)` is evaluated
**Then** it returns `original_recorded_at ?? recorded_at`, and it is the only time accessor exported for rule code (raw `recorded_at` is reachable only by the skew-rule helper).

**Given** `LearningEventRepository` (port in `lib/domain/learner_state/ports/`, implementation `lib/data/repositories/firestore_learning_event_repository.dart`)
**When** `watchAll(profileId)` is subscribed
**Then** it resolves the path through `activeAccountFirebaseProvider` and the profile ULID (`users/{uid}/learner_profiles/{profileId}/learning_events`), pages by document id at ≤ 500 per query until exhausted, emits a loading state until the last page arrives, and only then emits the complete list
**And** it uses the resilient stream wrapper (AD-9); a test with 1,201 fake events proves three pages, one loading emission and one complete emission.

**Given** a client write
**When** a new event is built
**Then** its id is a client-generated ULID created before the write and reused verbatim on retry, and no retry payload contains a freshly stamped time or `serverTimestamp()` (AD-46).

**Given** the AD-52 `sub_tracks/{ulid}` row
**When** `SubTrackRepository` (port in `lib/domain/learner_state/ports/` + `lib/data/repositories/firestore_sub_track_repository.dart`) is added
**Then** it reads the profile's sub-tracks (`users/{uid}/learner_profiles/{profileId}/sub_tracks`) via paged reads at ≤ 500 per query, emitting loading until complete, and exposes a governed write port (field-level merges and tombstones via `ended_at` + `end_reason`) that `LearningCommands.applyGovernedChange` uses with `entity = subTrack`; it never issues a client `delete`
**And** the `SubTrack` / `NodeEntry` codec round-trips exactly the AD-52 fields (`curriculum_id`, `name`, `type`, `academic_year`, `window_start`, `window_end`, `rate_per_week`, `weeks_per_year`, `learns_on_shabbos`, `ground`, `ended_at`, `end_reason`, `last_change_id`) and emits no other key; no sub-track UI or create/edit command is added in this epic.

**Given** the new repository file
**When** `tool/check_firebase_confinement.dart` and `tool/check_dependency_direction.dart` run
**Then** both pass (Firestore code only in `lib/data/repositories/**`).

### Story 1.3: Engine core — learnt set, progress, tri-state, main-track position, completed units

As a learner,
I want the app to know exactly which units I have learnt, from any source, and to celebrate a completed masechta once,
So that repeats never inflate my progress and a siyum is earned honestly.

**Requirements:** FR-14, FR-15, FR-17, AD-31, AD-32, AD-33 (current unit, position), AD-34 (`expandGround`), AD-35, AD-42; spine Siyum convention; dev #1, #11

**Acceptance Criteria:**

**Given** `LearnerStateEngine(events, subTracks, mainTrackIntent, goals, intentHistory, calendars, corpora, nowUtc)` in `lib/domain/learner_state/learner_state_engine.dart`
**When** it runs
**Then** it is a pure function returning `LearnerState` keyed by `curriculum_id`, with no I/O, clock read or global state (a test runs it twice on identical inputs and asserts deep equality)
**And** only curricula whose `curriculum_tracks` doc has `state == active` and no `ended_at` are evaluated for plan and streak, while events of every curriculum count for the learnt set and siyum.

**Given** learn events and voids
**When** the counted set is built
**Then** a leaf is learnt iff it has ≥ 1 counted `learn` event (not voided, not lock-ignored — lock filtering is a hook filled by the engine time-rules story) from any source, stage or `date_state`
**And** a void whose target is a void is ignored, a void whose target is absent is not an error, and two voids of the same target equal one.

**Given** a `before_tracking` event with node `ref` + `level`
**When** it is counted
**Then** `expandGround([{level, ref}])` (in `lib/domain/learner_state/expand_ground.dart`: entries in list order, each in ContentIndex order, later duplicates dropped) marks every covered leaf learnt.

**Given** a learner with 3 events on Berachos 1:1 (main dated, main chazara stage 2, sub-track) and 1 on Berachos 1:2 (before_tracking)
**When** distinct progress is read for Mishnayos
**Then** `distinctLearnt == 2` (FR-14: repeats add nothing; before-tracking counts)
**And** the corpus is `ContentIndex(curriculum) ∩ curriculum_scope` when a scope exists.

**Given** one learnt mishna in Berachos perek 2
**When** `triState(node)` is read for its perek, masechta and seder
**Then** each returns `partial`; a node with all leaves learnt returns `complete`; with none, `empty` (FR-15).

**Given** `mainTrackIntent` with `tracking_start_ref` and no sub-tracks
**When** position is derived
**Then** the current unit is the FR-12a unit (Mishnayos: masechta) containing the later, by time, of the latest counted `source = main` `dated`/`catch_up` event (by `effectiveAt`) and `tracking_start_ref` (by `at` of its last `mainTrackProgram` entry), only while it has a schedulable leaf
**And** main-track position = first schedulable leaf of the current unit, else the first of `schedulableRefs`; a sub-track or free-tick event elsewhere does not move it.

**Given** siyum units (Mishnayos masechta and seder; other curricula their ContentIndex equivalents)
**When** completed units are derived
**Then** `count(U, leaf)` excludes events with `stage` > first and counts a node event once per covered leaf; `completion_number` k is reached when the minimum over U's leaves is ≥ k; `first_completed_at(1)` = `effectiveAt` of the event that achieved it
**And** fixtures prove: completion by a sub-track or by backfill fires (k = 1 present); a void that un-completes U removes it from completed units; a later re-completion re-adds it with a new `first_completed_at(1)`; a chazara pass over a complete unit never yields a new k = 1 (dev #11).

### Story 1.4: Engine time rules — lock windows, lock-ignored events, locked days, catch-up window, streak day

As a learner,
I want shabbos and yom tov computed for my own location and time zone, and my streak counted only from honest same-day home learning,
So that nothing recorded during a lock counts and a backdated tick can never repair a streak.

**Requirements:** FR-16, FR-23, AD-36, AD-40, AD-41, NFR-6, NFR-7, NFR-8; dev #2, #6, #8, #13

**Acceptance Criteria:**

**Given** `lib/domain/learner_state/lock_constants.dart`
**When** it is read
**Then** it defines exactly `lockStartBeforeCandleLighting = 10 min` and `lockEndAfterTzeis = 10 min`; no other file defines lock offsets (the old 18/15 values are not referenced by the engine).

**Given** `lockWindows(settingsHistory, fromUtc, toUtc)` in `lib/domain/learner_state/lock_windows.dart`
**When** it computes shabbos and yom tov windows
**Then** it iterates days in the learner's IANA `time_zone` in force (never the device offset), uses `latitude`/`longitude` and `in_israel` in force at each instant to decide one- vs two-day yom tov, and returns `[candle-lighting − 10 min, tzeis + 10 min]` windows
**And** a settings change mid-range (move from New York to Jerusalem) changes only windows after the change instant.

**Given** settings with no location
**When** windows are computed
**Then** the fail-closed fallback applies: Fri 12:00 → Sun 01:00 learner-local and the yom tov equivalent
**And** at a latitude where tzeis cannot be computed, a fixed conservative window applies; a test asserts no input yields an open interval narrower than the computed window (false unlock impossible).

**Given** an event whose `effectiveAt` falls inside a window computed with the settings in force at that instant
**When** the engine runs
**Then** the event is lock-ignored: it is excluded from the learnt set, progress, position, streak, siyum and points, and is exposed as `LearnerState.lockIgnoredEventIds` for history labelling ("kept, not counted — recorded during Shabbos/Yom Tov").

**Given** a lock L
**When** `lockedDays(L)` and `catchUpWindow(L)` are evaluated
**Then** `lockedDays` = learner-local civil dates D (tz in force at `L.start`) for which `JewishCalendar` with `inIsrael` (in force at `L.start`) gives `isAssurBemelacha()`, excluding the day the lock starts on
**And** `catchUpWindow(L)` = non-locked time from `L.end` to the end of the first civil day after `L.end` containing no locked instant; a two-day yom tov followed by shabbos yields one lock with 3 locked days.

**Given** `streakDay(e)` in `lib/domain/learner_state/streak.dart`
**When** a curriculum's streak is computed from counted `source = main` learn events
**Then** a `dated` event counts on `learned_on` iff `learned_on == civilDate(effectiveAt(e))`; a `catch_up` event counts iff `learned_on ∈ lockedDays(L)` of the preceding lock and `effectiveAt(e) ∈ catchUpWindow(L)`; `before_tracking` never counts; sub-track events never count
**And** the streak is per curriculum (`LearnerState` has no profile-wide streak), and a day in `lockedDays` does not break the streak when its catch-up was completed in-window (FR-16, dev #8, #13).

### Story 1.5: Engine planning outputs

As a learner,
I want my plan, reviews and calendar-program tasks computed by the same engine as my progress,
So that my today list never disagrees with what I have actually learnt and the main track stays on one masechta at a time.

**Requirements:** FR-12a, AD-33, AD-34 (predicates), AD-35, AD-43, AD-44 (no-sub-track case), AD-45 (calendar program exclusion); dev #14

**Acceptance Criteria:**

**Given** `orderedLeaves(corpus, orderDocs)` in `lib/domain/learner_state/ordered_leaves.dart`
**When** order docs exist for some siblings
**Then** at each level siblings with a non-ended doc sort by `user_sort_order`, siblings without one follow in ContentIndex order, then it recurses; docs with `ended_at` are ignored (reset to default = all ended).

**Given** `holdsGround`, `inForecast`, `onHome` in `lib/domain/learner_state/predicates.dart`
**When** a sub-track has `window_end == null`
**Then** it is treated as +∞ in every predicate, and `holdsGround` is true for a future-start sub-track (fixtures cover ended, future, active, open-ended).

**Given** `O = orderedLeaves(...)` and `start = tracking_start_ref`
**When** `schedulableRefs` is derived
**Then** it is leaves of `O` with no counted learn event and not in the ground of any `holdsGround` sub-track, ordered as leaves at/after `start` then leaves before `start`; `mainTrackRemaining == schedulableRefs.length`
**And** with returned (earlier) ground present, those leaves come only after the current masechta's remaining leaves (FR-12a).

**Given** a calendar-program curriculum with `calendars[program_id] = [(civilDate, nodeRef)]`
**When** `programAssignments(date)` and `programBacklog(today)` are read
**Then** assignments are leaves (`expandGround` ∩ corpus); backlog = assigned leaves dated before `today` and on/after `amnestyFrom = max(tracking_start_date, civilDate(at) of latest mainTrackOrder or mainTrackProgram entry)` with no counted learn event; `dailyTarget` = assigned through today − learnt
**And** a missing `tracking_start_date` yields a validation error, not a default; `last_reorder_at` and `activated_at` are never read.

**Given** AD-32 review cycles
**When** `reviewsDue(date)` is computed
**Then** cycles start only from a `source = main` event with `stage = firstStageOrder`; each step uses the `mainTrackStages`/`mainTrackStudyDays` in force at the `effectiveAt` of the event completing the previous step; a leaf learnt only via sub-track, free tick or before-tracking has no cycle.

**Given** a deadline goal at `goals/{c}_deadline` and no sub-tracks
**When** `dailyTarget` is computed
**Then** `numerator = mainTrackRemaining`, `studyDaysToDeadline` counts dates in `[today, target_date]` on study days, and `dailyTarget = max(0, ceil(numerator ÷ studyDaysToDeadline))` (or `numerator` when the divisor is 0)
**And** with no deadline `paceRate` comes from `goals/{c}_pace`; with neither, both are null; `target_percent` is never read.

**Given** ≥ 14 days of tracked history
**When** the projection is computed
**Then** velocity = distinct leaves newly learnt per `learned_on` day from `dated`/`catch_up` events, excluding chazara and before-tracking, over the trailing 28 days (all history at 14–27 days); under 14 days no projection is produced; there is no pace-reset input.

### Story 1.6: Engine points — counted and earning events, filtered balance, achievement latch

As a child,
I want points only for genuinely new main-track learning or a scheduled review,
So that points can't be farmed by repeat ticks and every device shows the same balance.

**Requirements:** AD-50, AR-15, FR-4 (void effect on points); dev #5

**Acceptance Criteria:**

**Given** the engine output
**When** it runs
**Then** `LearnerState.countedEventIds` (profile-wide) = learn events not voided and not lock-ignored.

**Given** a leaf with a sub-track event at 09:00 and a main dated event at 18:00
**When** `earningEventIds` is computed
**Then** per leaf only the earliest counted learn event by (`effectiveAt`, id) can earn, and only if it is `source = main` and `dated`/`catch_up` — here neither earns
**And** a `before_tracking` earliest event also blocks earning for that leaf.

**Given** a main event with `stage` > first on (leaf, stage)
**When** `earningEventIds` is computed
**Then** it earns only if it is the earliest counted such event and (leaf, stage) ∈ `reviewsDue(civilDate(effectiveAt(e)))` under the stage settings in force at `effectiveAt(e)`; changing stage settings later does not change past earning.

**Given** `points_ledger` entries (`pts_{eventId}` and non-event spends/adjustments)
**When** `pointsBalance` and `lifetimeEarned` are computed by `lib/domain/learner_state/points.dart`
**Then** both sum only `pts_` entries whose `event_id` ∈ `earningEventIds` plus non-event entries, clamped as today; voiding an earning event lowers both (lifetime is not monotonic); an orphan `pts_` entry counts nothing.

**Given** achievement thresholds and `preferences/gamification_settings.unlocked_achievement_ids`
**When** `newlyCrossedAchievements(state, unlocked)` is evaluated
**Then** it returns only ids whose threshold is crossed and not already in the list; an id already in the list stays unlocked even if the balance later drops (latch).

### Story 1.7: LearningCommands and CaptureGate

As a child or parent,
I want every tick, correction and backfill to be saved the same way, refused during a lock, and recoverable if it fails,
So that my record is complete offline, never contains a shabbos write that counts, and nothing is silently lost.

**Requirements:** FR-3, FR-4, AD-31, AD-36, AD-40 (child re-date window), AD-46, AD-47, AD-50, AD-54 (batching, recovery, skew), AR-6, AR-15, AR-17, NFR-1, NFR-8; parent AD-8, AD-30

**Acceptance Criteria:**

**Given** `LearningCommands` and `CaptureGate` in `lib/features/learning/domain/commands/`, depending only on `lib/domain/learner_state/ports/`
**When** any command is issued
**Then** `CaptureGate.check(targetProfileSettingsHistory, nowUtc)` runs first and, inside any `lockWindows` window, the command writes nothing and returns `CaptureResult.locked`.

**Given** `capture(curriculum, refs, source, dateState, learnedOn, stage?)`
**When** `dateState` is `dated`, `catch_up` or `before_tracking`
**Then** one `learn` event per leaf is written (a `before_tracking` node may be one node event with `level`); `learned_on` defaults to today's civil date and is editable; `before_tracking` writes `learned_on = null`
**And** every `source = main` `dated`/`catch_up` event gets `points_ledger/pts_{eventId}` (amount `point_configs[curriculum, stage ?? firstStageOrder]`, `created_at = recorded_at`, `event_id`) in the same batch; no reversal entry is ever written.

**Given** a capture of 1,000 leaves
**When** it is committed
**Then** it is chunked at ≤ 450 writes per batch, each chunk self-contained (an event and its `pts_` entry never split)
**And** every client timestamp is ≤ now; ids and timestamps are fixed before the first attempt and reused on retry.

**Given** `voidEvent(targetId)` and `replace(targetId, newEvent)`
**When** the target is a `void`, or a lock-ignored event
**Then** the command is rejected (void targets only a `learn`; undo is not offered for lock-ignored events)
**And** a replacement that changes only `ref` or `source` keeps the original `learned_on`/`date_state` and carries `original_recorded_at = effectiveAt(original)`, so it creates no new streak day (FR-4).

**Given** role `child` (parent-PIN session locked)
**When** the child re-dates an event
**Then** it is allowed only while now ∈ `catchUpWindow(L)` for the locked day being corrected; otherwise only removal (void) is allowed and re-date returns `CaptureResult.childLimit`; `parent` has no such limit.

**Given** `unlearn(curriculum, leafSet S)`
**When** a counted node event N covers part of S
**Then** N is voided and `before_tracking` events are written for the maximal ContentIndex nodes covering `expand(N) \ S`, each with `original_recorded_at = effectiveAt(N)`; leaf events in S are voided; undo of `unlearn` voids the re-issues and re-copies the voided events.

**Given** a batch permanently rejected by the server (e.g. `permission-denied`)
**When** the SDK reports it
**Then** `LearningCommands` exposes a per-item "not saved — retry" entry via `pendingFailures` with a retry action reusing the same ids, and reports a Crashlytics non-fatal with enums only (AD-30, AD-54).

**Given** a successful capture
**When** analytics fire
**Then** `LearningAnalytics` emits `capture` with enums (`curriculum_id`, `source_kind` main/sub_track, `date_state`) and counts only; the event is registered in `AnalyticsEvent` (`lib/core/analytics/analytics_service.dart`) and `tool/check_analytics_catalog.dart` passes.

**Given** the device is offline
**When** a capture is issued
**Then** it is queued by the SDK and returns success locally; this story asserts the queued-success result with a fake port, and the offline-queue atomicity instrumented test is owned by the Firestore rules story.

### Story 1.8: Change log, governed owner writes and learner settings on the profile

As a parent,
I want every change to my child's goal, main track and location settings recorded with who and when, and undoable field by field,
So that I can trust and reverse changes, and the lock always uses the learner's own location.

**Requirements:** AD-37, AD-38, AD-54 (batch sizing), AR-7, NFR-3, NFR-4; dev #14

**Acceptance Criteria:**

**Given** `ChangeLogRepository` (port + `lib/data/repositories/firestore_change_log_repository.dart`)
**When** `watchIntentHistory(profileId)` is subscribed
**Then** it reads `change_log` where `entity in ['learnerSettings','mainTrackOrder','mainTrackProgram','mainTrackStages','mainTrackStudyDays']`, paged by document id at ≤ 500 until exhausted, emitting loading until complete; no composite index is added.

**Given** a governed change through `LearningCommands.applyGovernedChange(action)`
**When** it touches entity docs
**Then** each doc is written with `set(..., merge: true)` of changed fields only plus `last_change_id`; one `change_log` entry per entity carries `before`/`after` keyed `{collection}/{docId}.{field}` (cached value or `null` when absent), `at`, `actor` and `action_id` (= id of the action's first entry)
**And** an entity's docs and its entry are in one batch; a multi-entity action spans batches in action order, each self-contained.

**Given** an entity write touching more than 10 governed docs
**When** it is issued
**Then** it is not batched; it is dispatched to the `OversizedGovernedWritePort`, is online-only, and offline returns `CaptureResult.onlineRequired` with no optimistic state (UX-DR-85, UX-DR-101)
**And** in this story the port is exercised with a fake; its online implementation (the `ownerOversizedGovernedWrite` callable) is verified by the `writeWithChangeLog` story.

**Given** an undo of action A
**When** it runs
**Then** for each member entry U and field f whose current value equals `U.after[f]`, it writes `U.before[f]` as a new logged action whose every entry carries `reverts_action_id = A`; other fields are returned as "changed since by <actor>"
**And** undo of a create sets `ended_at` only if `last_change_id` still equals U's id; undo is not offered for a `learnerSettings` entry whose `before` is all-null.

**Given** an action whose entries carry `reverts_action_id` (an undo)
**When** an undo of it is requested
**Then** the command rejects it and writes nothing (an undo is final)
**And** `ChangeLogRepository` exposes, for any action A, whether an entry with `reverts_action_id == A` exists, so every device can mark A "Undone".

**Given** profile creation (owner path)
**When** a learner profile is created
**Then** `latitude`, `longitude`, `time_zone` (IANA from `flutter_timezone`, required) and `in_israel` are written on `learner_profiles/{profileId}` together with a `learnerSettings` seed entry (`before` all-null) in one batch
**And** other profile writers use field-level `update` of their own fields only, and the profile codec never emits settings keys on a non-settings write.

**Given** `learnerLockSettingsProvider(profileId)`
**When** a reader asks for settings history
**Then** it returns the reconstructed history (current doc + `learnerSettings` entries ordered by `original_at ?? at`; instants before the first entry use its `after`; no entries = current values forever) and is the only settings source for `CaptureGate` and `lockWindows`.

**Given** two devices editing different fields of one governed doc
**When** both sync
**Then** each field resolves LWW by commit order and both entries appear in `change_log` (NFR-4).

### Story 1.9: Firestore rules and emulator tests

As a parent,
I want the server to accept only well-formed, attributed learning and history writes from my own devices,
So that my child's record and history can't be forged or erased by a client.

**Requirements:** AD-46, AD-38 (owner rule), AD-37 (profile rule), AD-54 (tests, budget, skew, deploy gate), AR-9, AR-10; parent AD-12, AD-29

**Acceptance Criteria:**

**Given** `firestore.rules`
**When** `learning_events/{id}` and `change_log/{id}` are written by a client
**Then** create-only plus SR-1 identical replay is allowed; update and delete are denied; a `hasOnly` whitelist per AD-52 and type checks apply (`kind ∈ {learn, void}`, `date_state ∈ {dated, catch_up, before_tracking}`, `entity` in the AD-38 enum, `learned_on` matching `^\d{4}-\d{2}-\d{2}$` or null, `target_id` present iff `kind == void`)
**And** `actor.uid == request.auth.uid` and `actor.role ∈ {parent, child}` (a `tutor` role is denied); these matches make no document-access calls; list queries are capped at 500.

**Given** a governed doc (`sub_tracks`, `goals`, `curriculum_tracks`, `track_learning_order`, `profile_programs`, `study_day_configs`, `stage_definitions`, `curriculum_scopes`, settings keys on `learner_profiles`)
**When** a client writes it
**Then** the AD-38 owner rule applies, and `sub_tracks/{id}` additionally has a `hasOnly` whitelist of exactly the AD-52 fields with type checks (`type ∈ {school_year, ongoing}`, `end_reason ∈ {ended, deleted, undo, track_deleted}` or absent): identical replay, or ULID `last_change_id` differing from stored (or `resource == null`), `!exists(change_log/id) && getAfter(change_log/id)` exists, entry `entity`/`entity_id` matching the collection and doc id / profileId / `curriculum_id`, actor uid/role checks; client `delete` is denied
**And** on `learner_profiles` the owner-rule branch applies only when affected keys include a settings key or `last_change_id`.

**Given** `points_ledger/{docId}` event entries
**When** created
**Then** `docId == 'pts_' + event_id` is required with no access call.

**Given** any client timestamp in a learning or governed batch (`recorded_at`, `at`, `ended_at`, `points_ledger.created_at`)
**When** it is > `request.time + 10 min`
**Then** the write is denied; ≤ 10 min ahead is allowed.

**Given** `functions/test/firestore_rules.test.mjs`
**When** the suite runs on the emulator
**Then** it covers every AD-38 owner-rule branch (create, replay, stale `last_change_id`, missing entry, wrong entity, wrong `entity_id`, tutor role, delete), a `sub_tracks` write with an extra field is denied, and a 10-governed-doc batch passes while an 11th doc in the same batch is denied
**And** an instrumented test (`integration_test/`) proves an offline batch of events + `pts_` + `change_log` lands atomically on reconnect (AD-29).

**Given** existing rules for retired collections and unrelated collections
**When** this story lands
**Then** they are unchanged (denial happens in the cutover release story) and the existing rules tests still pass.

**Given** CI
**When** the workflow is extended
**Then** a gated deploy job (`firebase deploy --only firestore:rules,firestore:indexes,functions`) exists that requires the rules and functions test jobs and must succeed before any app-release job that depends on it; in this story it runs against the emulator/dry-run only and deploys nothing to production.

### Story 1.10: writeWithChangeLog, rerouted tutor callables and ownerOversizedGovernedWrite

As a parent,
I want every server-side write to my child's goal and main track to pass the same checks and land in the same history as my own edits,
So that a tutor can never write what the rules would deny, and revoked access stops at once.

**Requirements:** AD-38 (callable contract, rerouting), AD-53, AD-54 (observability), AD-45 (calendar-program goal rejection), AR-6

**Acceptance Criteria:**

**Given** `writeWithChangeLog` in `functions/src/` (shared helper)
**When** any callable uses it
**Then** it requires `request.auth`; verifies the caller owns the profile path or holds an active `tutor_grants` grant with `permissions.can_edit_learning == true`; derives `actor` server-side (`role = tutor` and `display_name` from the grant for grant callers; owner `parent`/`child` accepted as asserted)
**And** validates the full payload against AD-52, the AD-38 entity mapping, AD-31 void targets and AD-45/AD-43 (goal on a calendar-program curriculum rejected), all in one transaction, idempotent on the client ULID (same ULID, actor and entity returns the stored result).

**Given** a create
**When** `writeWithChangeLog` writes it
**Then** it claims the create only after verifying in-transaction that the doc did not exist; otherwise it writes an ordinary update entry.

**Given** the 10 legacy callables `tutorUpsertGoal`, `tutorDeleteGoal`, `tutorUpsertTrack`, `tutorDeleteTrack`, `tutorUpsertStudyDayConfig`, `tutorDeleteStudyDayConfig`, `tutorUpsertStageDefinition`, `tutorUpsertCurriculumScope`, `tutorSetProfileProgram` (`functions/src/tutor_writes.ts`) and `deleteCurriculumTrack` (`functions/src/deletes.ts`)
**When** they are rerouted
**Then** each writes only through `writeWithChangeLog`, emits field-level merges plus `change_log` entries identical in shape to the owner path, writes tombstones (`ended_at`) instead of deletes, and returns the server-stamped `recorded_at`/`at`
**And** `deleteCurriculumTrack` performs the remove-track action (one `mainTrack` entry setting `ended_at` + one `subTrack` tombstone entry per non-ended sub-track, shared `action_id`) and no longer hard-deletes governed docs.

**Given** `tutorEditProfile`
**When** it is called
**Then** it writes only `display_name`, `avatar` and `mode` with a field-level merge.

**Given** the owner path's `OversizedGovernedWritePort` from Story 1.8
**When** this story lands
**Then** it is implemented by a new callable `ownerOversizedGovernedWrite` wrapping `writeWithChangeLog` for owner callers, and a reorder of 25 order docs succeeds online in one transaction with one `mainTrackOrder` entry
**And** `ownerOversizedGovernedWrite` is exported from `functions/src/index.ts`, covered by `make test-functions`, and included in the gated deploy job.

**Given** the emulator suites (`functions/test/cf_tutor_goals_tracks.test.mjs`, `cf_tutor_settings_profile.test.mjs`, `cf_deletes.test.mjs`, new `cf_write_with_change_log.test.mjs`)
**When** they run
**Then** every callable-contract rejection is covered (no auth, no grant, revoked grant, missing `can_edit_learning`, bad payload, bad void target, calendar-program goal, idempotent replay), and failures log structured `{entity, code}` with no learner data.

### Story 1.11: Capture paths onto LearningCommands; sentinel retired

As a child,
I want ticking, tick-to-here, backfill and undo to all record learning the same way,
So that whatever screen I use, my learning counts once and correctly.

**Requirements:** R2, R10, R15 (tests of deleted code), FR-3, FR-4 (undo snackbar), AD-31, AD-49, AD-50; UX-DR-20, UX-DR-62, UX-DR-74, UX-DR-107, UX-DR-147, UX-DR-154, UX-DR-157; dev #8

**Acceptance Criteria:**

**Given** the R2 writers — `CompletionOrchestrator`, `completion_streak_recorder`, `completion_points_awarder`, `bulk_mark_completion_use_case`, `manual_completion_use_case`, `mark_live_completion_use_case`, `bulk_prior_completion_service`, the `text_display_screen` capture section and `completion_command` (except the tutor branch of `mark_live_completion_use_case`, see below)
**When** they are rewired
**Then** every call site uses `LearningCommands.capture` / `voidEvent` / `unlearn`, and the old services and `CompletionCommand` are deleted
**And** the main-track today list renders and completes tasks exactly as before (same tasks, same order, same tap count).

**Given** `kBulkPriorSentinelDate` (`lib/core/learning/completion_constants.dart`)
**When** R10 lands
**Then** every former sentinel write is a `before_tracking` capture (`learned_on = null`), the constant and its consumers are deleted, and onboarding `bulk_mark_screen` / settings `lifetime_marking_screen` write `before_tracking` events (node events with `level` where a whole node is marked).

**Given** the corpus browser under Browse (`content_hierarchy_screen.dart`)
**When** the child or parent selects any node or long-presses a mishna for "Tick up to here" (that mishna and every earlier one in corpus order within its masechta)
**Then** a confirm sheet asks the source once (Home default; Before tracking), shows an editable date defaulting to today, and a "Record {count}" button; one capture is issued per batch
**And** a Home tick dated to an earlier day is stored as `dated` with that `learned_on` and does not count for the streak (dev #8); a Before-tracking batch writes no `learned_on`.

**Given** a recorded free-tick batch or main-task completion
**When** the snackbar appears
**Then** it offers Undo, which voids exactly the events just written (UX-DR-154).

**Given** a permanently rejected capture
**When** `pendingFailures` reports it
**Then** the screen shows a snackbar explaining "not saved" with Retry and rolls back optimistic state (UX-DR-107, UX-DR-147); during a lock the commands return `locked` and nothing is written.

**Given** `mark_live_completion_use_case`
**When** R2 lands
**Then** its owner branch calls `LearningCommands.capture`, and its tutor branch is left on the legacy callable path, unchanged, until the tutor-capture story later in this epic reroutes it to `TutorWriteService`; the tutor branch is excluded from this story's deletions.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.12: Progress readers and siyum onto LearnerState

As a child or parent,
I want every progress number, fill and siyum to come from one engine,
So that screens never disagree and repeats never inflate progress.

**Requirements:** R3, R15 (tests of deleted code), FR-14, FR-15, FR-17, AD-35, AD-15 (siyum key); UX-DR-7, UX-DR-8, UX-DR-19, UX-DR-73, UX-DR-91, UX-DR-104, UX-DR-146, UX-DR-157, UX-DR-161; dev #11

**Acceptance Criteria:**

**Given** a new `learnerStateProvider(profileId)` composing the learning-event, sub-track, change-log, governed-intent and calendar reads with `LearnerStateEngine`
**When** any input is still paging
**Then** it emits loading (existing `LoadingIndicator`), and errors render `AppErrorView`/`InlineAsyncError` with retry.

**Given** the R3 readers — `progress_providers`, `lifetime_knowledge_providers`, `items_learned_providers`, `journey_providers`, `chart_data_service`, `curriculum_progress_service`, `lifetime_tree_builder`, `track_completion_service`, `track_progress_service`, `completion_detection_service`, `track_detail_screen`, `lifetime_marking_screen`, and both `pace_calculator`s
**When** they are rewired
**Then** each reads only `LearnerState`; both `pace_calculator`s and `completion_detection_service` are deleted; no file outside `lib/data/repositories/` queries `learning_events`.

**Given** a learner with repeat events
**When** progress screens show goal progress
**Then** they show the distinct learnt count (FR-14), and every corpus node in `curriculum_progress_screen`, `lifetime_knowledge_screen` and the Browse tree renders empty/partial/complete (checkbox complete/dash/empty, 12% tint, count, semantic label "{name}, partial, 3 of 12 learnt") per UX-DR-19/UX-DR-157.

**Given** a masechta enters the engine's completed units with k = 1
**When** the app is foregrounded on any device
**Then** the siyum celebration fires once per per-device key `(profileId, U, first_completed_at(1))` stored via `ProfileScopedPreferenceKeys`; a void that removes U clears that key; re-completion celebrates again; chazara never re-fires; reduce-motion is respected
**And** the siyumim timeline (`siyumim_milestones_screen`) lists completion numbers from the engine.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.13: Mishna history and corrections on the engine

As a child or parent,
I want to see the full history of any mishna and fix a wrong tick from there,
So that repeats are visible without inflating progress and mistakes are easy to correct.

**Requirements:** FR-30, FR-4 (correction surface), AD-31, AD-35, AD-36; UX-DR-9, UX-DR-21, UX-DR-41, UX-DR-60, UX-DR-67, UX-DR-70, UX-DR-140, UX-DR-141, UX-DR-142, UX-DR-153, UX-DR-157, UX-DR-161

**Acceptance Criteria:**

**Given** any mishna in Browse or the lifetime tree
**When** it is tapped
**Then** a Mishna history screen opens: header shows Learnt state and "Learning events" count = non-voided events (FR-30); rows newest-first show date or Before tracking badge, source chip (a deleted or ended track keeps its stored `name`, read from its tombstoned doc), catch-up and chazara tags; footer explains repeats don't add goal progress
**And** an unlearnt mishna shows "Not learnt yet" with an empty list; voided events are hidden in child mode; lock-ignored events show "kept, not counted — recorded during Shabbos/Yom Tov" with no Undo
**And** a load failure shows `AppErrorView` with retry (UX-DR-141).

**Given** a history row
**When** the user removes or corrects it (place, source among Home and Before tracking, or date)
**Then** the action calls `LearningCommands.voidEvent` / `replace` under the Story 1.7 child limits, and a rejected correction rolls back with a snackbar (UX-DR-142).

**Given** a screen reader, Hebrew locale or dark mode
**When** the history renders
**Then** rows announce date, source and tags as text, layout mirrors in RTL, and dark tokens apply (UX-DR-157, UX-DR-161).

### Story 1.14: Owner governed writers, learning order and track removal through the change log

As a parent,
I want every change I make to goals, tracks, order, study days, stages and scope recorded in one history, and removing a track to be reversible,
So that nothing changes my child's plan without a trace and no learning is ever deleted.

**Requirements:** R13 (owner side; the tutor callables are rerouted in Story 1.10), R15 (tests of deleted code), FR-12a (order), AD-38 (track lifecycle, owner path), AD-43, AD-45, AR-7; dev #14

**Acceptance Criteria:**

**Given** the owner repositories for `goals`, `curriculum_tracks`, `profile_programs`, `study_day_configs`, `stage_definitions`, `curriculum_scopes` and `TrackCreationService`
**When** they are rerouted
**Then** every write goes through `LearningCommands.applyGovernedChange` with field-level merges, `last_change_id`, `curriculum_id` (immutable) and a co-written `change_log` entry; no client `delete` remains.

**Given** `learning_order` readers and writers (`firestore_learning_order_repository`, including the `scheduler_engine` order build)
**When** R13's order part lands
**Then** all order reads use `track_learning_order/{c}_{level}_{ref}` via `orderedLeaves`, reorder writes are one logged `mainTrackOrder` change through `LearningCommands.applyGovernedChange` (oversized reorders go online per Story 1.8), "reset to default" sets `ended_at` on every order doc of the curriculum, and `firestore_learning_order_repository` is deleted.

**Given** a deadline or pace goal
**When** it is created twice offline on two devices
**Then** both write `goals/{c}_deadline` (or `_pace`) and resolve LWW per field; a goal on a calendar-program curriculum is rejected by validation.

**Given** "Remove track"
**When** the parent confirms
**Then** one action writes a `mainTrack` entry setting `ended_at` on `curriculum_tracks/{c}` plus one `subTrack` tombstone entry per non-ended sub-track, through the Story 1.2 `SubTrackRepository` governed write port (shared `action_id`); every reader treats that curriculum's other governed docs as ended; `learning_events` and `points_ledger` are untouched
**And** "Re-add" clears `ended_at` through a logged change and restores the prior config, progress and history.

**Given** "Add track" (`add_track_flow_screen`)
**When** it completes
**Then** it is one named action whose entities share an `action_id`, chunked at ≤ 10 governed docs per batch.

**Given** tutor-only and rewards writers outside the governed set
**When** this story lands
**Then** their behaviour is unchanged.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.15: Planner onto LearnerState

As a child,
I want my daily tasks laid out from the same engine that knows what I've learnt,
So that my plan always starts where I really am, one masechta at a time.

**Requirements:** R4, R15 (tests of deleted code), FR-12a, AD-33, AD-35, AD-43, AD-49 (planner rule); dev #14

**Acceptance Criteria:**

**Given** `daily_task_projection_service` and `scheduler_engine`
**When** they are rewired
**Then** the planner lays out `LearnerState` position, current unit and `schedulableRefs` up to `dailyTarget` (deadline) else `paceRate` else nothing; calendar programs use `programAssignments(today) ∪ programBacklog(today)`; chazara tasks come from `reviewsDue(today)`
**And** the planner computes no quantity of its own: the due-review computation in `scheduler_engine` and `lib/features/scheduler/domain/projection/amnesty_cutoff.dart` are deleted.

**Given** a non-calendar curriculum mid-masechta
**When** today's tasks are generated
**Then** they never span two masechtos except on the day one finishes and the next begins (FR-12a)
**And** for a fixture learner with no sub-tracks, the generated task list equals the pre-cutover list for the same learnt set (golden parity test), and task generation is otherwise unchanged.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.16: Bookmarks retired; position derived

As a child,
I want "where I am" to be worked out from what I've learnt, not from a separately saved bookmark,
So that my position is never out of step with my record on any device.

**Requirements:** R8, R15 (tests of deleted code), AD-33, AD-49

**Acceptance Criteria:**

**Given** R8 — `firestore_bookmark_repository`, `bookmark_repository_impl`, `bookmark_providers`, `TutorWriteService.upsertBookmark` and the `tutorUpsertBookmark` callable
**When** R8 lands
**Then** they are deleted (callable source and its `functions/src/index.ts` export included; its production deletion runs in the cutover release deploy step), and "current position" everywhere is the engine's derived position.

**Given** a screen or tutor surface that set or read a bookmark
**When** this story lands
**Then** it reads the engine's position and offers no "set position" action of its own; behaviour is otherwise unchanged.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite and `make test-functions` pass.

### Story 1.17: Per-curriculum streak onto the engine; learning_ledger and streak_events retired

As a child,
I want a streak for each curriculum kept by my home learning,
So that my streak is fair and the same on every device.

**Requirements:** R5, R6, R15 (tests of deleted code), FR-16, AD-40 (surfaces), AD-47; dev #13

**Acceptance Criteria:**

**Given** the home/dashboard streak display
**When** a curriculum is in view
**Then** it shows that curriculum's `LearnerState` streak; switching curricula switches the streak; a day with only sub-track or before-tracking learning does not extend it.

**Given** `streak_alert_service`
**When** a curriculum's streak is at risk today
**Then** one alert fires per evaluated curriculum at most once per civil day per curriculum, and none fires inside a `lockWindows` window.

**Given** `streak_milestone_analytics_observer`
**When** a milestone is reached
**Then** the event carries the `curriculum_id` enum and counts only.

**Given** R6 (`firestore_streak_event_repository`, `firestore_streak_state_repository`, `streak_state_service`, `streak_service`, `streak_reducer`) and R5 (`firestore_learning_ledger_repository`, `learning_ledger_repository_impl`, `learning_ledger_providers`, `firestore_gamification_ledger_repository`, `LearningLedgerEntry`)
**When** they land
**Then** they are deleted and nothing writes `streak_events` or `learning_ledger`.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.18: Points and achievements onto the engine

As a child,
I want points and achievements that agree on every device,
So that my rewards are fair and can't be farmed by repeat ticks.

**Requirements:** R7, R15 (tests of deleted code), AD-47, AD-50, AR-15; dev #5

**Acceptance Criteria:**

**Given** R7 readers (`points_service`, `points_providers`, `firestore_points_balance_reader_adapter`, lifetime-earned and redemption readers, `achievements_overview_provider`)
**When** they are rewired
**Then** balance and lifetime show the AD-50 filtered sums; voiding an earning event lowers both on every device; redemptions still deduct as today.

**Given** an achievement threshold crossed on any device
**When** `LearningCommands` detects it after a write
**Then** it array-unions the id into `preferences/gamification_settings.unlocked_achievement_ids`, and every achievement surface reads only that list.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.19: Lock surfaces on lockWindows; old window service and prefs deleted

As a parent,
I want the app fully covered from 10 minutes before candle-lighting until 10 minutes after tzeis, on every device, even without a location,
So that my child can't use it on shabbos or yom tov and nothing recorded then ever counts.

**Requirements:** R9, R15 (tests of deleted code), FR-23, AD-36, AD-37, NFR-6, NFR-7, NFR-8; UX-DR-35, UX-DR-56, UX-DR-99, UX-DR-159, UX-DR-166; dev #6, #10

**Acceptance Criteria:**

**Given** `SacredTimeLockOverlay` (`lib/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart`)
**When** now is inside the union of `lockWindows` over every learner profile of the signed-in account
**Then** the opaque overlay covers the whole app with the existing sacred-time background, icon and greeting; back navigation is blocked; nothing behind it is reachable by touch or screen reader; the greeting is announced
**And** it appears at 10 min before candle-lighting and lifts at 10 min after tzeis (not the old 18/15).

**Given** a learner profile with no location
**When** windows are computed
**Then** the fallback Fri 12:00 → Sun 01:00 learner-local (and yom tov equivalent) applies, and after the lock the parent sees a prompt to set the learner's location.

**Given** the location/Israel settings screen
**When** a parent changes location, time zone or Israel/chutz la'aretz
**Then** it is written as a logged `learnerSettings` change via `LearningCommands`, and past windows are unaffected.

**Given** R9 — `ZmanimWindowService.computeWindows`, `sacred_windows_provider`, `sacred_window_repository` (with its fail-open path), `SacredTimePreferences`, `sacred_location_provider`
**When** R9 lands
**Then** every reader uses `lockWindows` + `learnerLockSettingsProvider`; `computeWindows`, `SacredTimePreferences` (and its keys) and the fail-open path are deleted
**And** nothing reads or copies device prefs into the profile; a profile's settings come only from its creation-time `learnerSettings` seed entry (Story 1.8) and later logged changes.

**Given** notification scheduling
**When** a notification would fire inside a `lockWindows` window
**Then** it is suppressed (same function as the overlay).

**Given** a capture issued in the seconds before the overlay renders
**When** `CaptureGate` evaluates it
**Then** it returns `locked` and writes nothing; an event with a locked `effectiveAt` that reached the store anyway is excluded by the engine.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.20: Backup export/import replay; notifications from LearnerState

As a parent,
I want my backup to restore my child's full learning record and history correctly, and reminders to reflect real progress,
So that a restore never double-counts, mis-dates or awards points twice.

**Requirements:** R11, R15 (tests of deleted code), AR-14, AD-49 (backup), AD-50, AD-31

**Acceptance Criteria:**

**Given** `DataExportImportService` (`lib/features/settings/domain/services/data_export_import_service.dart`)
**When** a backup is exported
**Then** it contains `learning_events`, `sub_tracks` (read through the Story 1.2 `SubTrackRepository`), `change_log`, the governed collections, non-event `points_ledger` entries and `reward_redemptions`, and no `pts_` entries.

**Given** a backup file
**When** it is imported
**Then** `LearningCommands` replays in order: (1) `learnerSettings` entries with `original_at = at(old)` as updates to the import-time seed; (2) governed entities as logged updates, never creates; (3) sub-tracks with fresh ULIDs and an id map, written through the Story 1.2 `SubTrackRepository` governed write port; (4) `learn` events with fresh ULIDs, remapped `source`, `original_recorded_at = effectiveAt(old)` and `pts_` re-derived per AD-50; (5) `void` events with remapped `target_id`, dropping voids whose target is unmapped; (6) non-event points entries as new entries
**And** other `change_log` entries are not replayed.

**Given** an export → import round-trip of a fixture learner (including two sub-tracks written directly through the repository, one tombstoned)
**When** the engine runs on the imported profile
**Then** distinct count, tri-state, per-curriculum streak, completed units, `earningEventIds`-based balance and lock-ignored set equal the source profile's.

**Given** an import of a large log
**When** it is written
**Then** it is chunked per AD-54 (≤ 450 writes, ≤ 10 governed docs per batch) and any rejected chunk surfaces as "not saved — retry".

**Given** `firestore_notifications_completion_adapter`
**When** notifications decide whether today's learning is done
**Then** they read `LearnerState` only, and the adapter's completions query is deleted.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.21: Completion repositories and CompletionEntity retired

As a developer,
I want the old completion repositories and entity removed once nothing reads or writes them,
So that no screen can quietly fall back to the retired `completions` store.

**Requirements:** R1, R15 (tests of deleted code), AD-49

**Acceptance Criteria:**

**Given** the R1 repositories — `firestore_completion_repository`, `completion_repository_impl`, `scheduler_completion_repository_impl`, `firestore_progress_repository_adapter`, `firestore_chart_data_repository_adapter` — and their writers and readers already rewired (Stories 1.11, 1.12, 1.15, 1.20)
**When** R1 lands
**Then** they and `CompletionEntity` are deleted with no remaining import, and no file in `lib/` queries `completions`.

**Given** the tutor branch of `mark_live_completion_use_case` (still on the legacy callable path, Story 1.11)
**When** this story lands
**Then** if it imports `CompletionEntity`, it is switched to a plain request payload with behaviour unchanged.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported to engine/command tests or deleted in this story (R15), and the full suite passes.

### Story 1.22: Retired fields and Reset pace removed

As a developer,
I want the retired track and goal fields and the "Reset pace" button removed everywhere,
So that no code reads or writes a field the engine no longer uses.

**Requirements:** R16, R15 (tests of deleted code), AD-43, AD-49

**Acceptance Criteria:**

**Given** the "Reset pace" button
**When** this story lands
**Then** it is removed from every screen, no code writes `pace_reset_date`, and pace is read from `goals/{c}_pace`.

**Given** R16 retired fields — `curriculum_tracks.state_changed_at`, `purged`, `purged_at`, `pace_reset_date`, `last_reorder_at`, `progress_schema_version`, `progress_computed_at`, `progress_model`, `program_progress`, `self_paced_progress`; `goals.target_percent`; governed `updated_at`/`synced_at`
**When** this story lands
**Then** they are removed from Dart codecs and entities, the rules whitelists, and the `functions/src/tutor_writes.ts` whitelists, and are listed for `check_retired_symbols` (enforced from the cutover release)
**And** `activated_at` is kept only if a screen displays it, and is never an engine anchor.

**Given** the code this story deletes
**When** it lands
**Then** the tests and fixtures of deleted code are ported or deleted in this story (R15), and the full suite, `make test-rules` and `make test-functions` pass.

### Story 1.23: Tutor learning callables

As a tutor (rebbe),
I want server-checked calls that record, correct and remove a talmid's learning and log who did what,
So that my edits are authorized by the parent's grant and land in the same record as the family's own.

**Requirements:** FR-26 (learning record), FR-3, FR-4, NFR-8 (server side), AR-6 (tutor half); AD-31, AD-36, AD-38 (callable contract, idempotency), AD-46, AD-50, AD-52, AD-53, AD-54; dev #2

**Acceptance Criteria:**

**Given** `writeWithChangeLog` and the 10 rerouted governed callables (Story 1.10)
**When** this story lands
**Then** three new callables in `functions/src/tutor_learning.ts` cover every tutor learning write: `tutorRecordLearning` (`learn` events with `date_state` `dated` or `before_tracking`, leaf or node with `level`; task tick, tick-to-here, before-tracking marking), `tutorVoidLearning` (`void`, or replace = void + learn copy in one transaction) and `tutorUnlearn(curriculum, leafSet)` (AD-31 re-issue semantics); in this epic `source` must be `main` (a later epic extends this to sub-track sources)
**And** each writes only through `writeWithChangeLog`, performs no grant or permission check of its own (AD-53), writes `pts_{eventId}` for every `source = main` `dated` learn event in the same transaction (AD-50), and emits no analytics
**And** they are exported from `functions/src/index.ts`, covered by `make test-functions`, included in the gated deploy job, and not flagged by `tool/check_retired_symbols.dart`.

**Given** an online `tutorRecordLearning` call for Berachos 2:1–2:3
**When** it succeeds
**Then** one transaction writes three `learn` events with `source = main`, `date_state = dated`, `actor = {uid, role: tutor, display_name}` derived on the server, a server-stamped `recorded_at`, the client-supplied ULIDs as document ids, and their `pts_` entries.

**Given** a callable call whose client ULID already exists with the same actor and entity (retry after a timeout)
**When** it is replayed
**Then** the stored result is returned and no duplicate event, `pts_` entry or `change_log` entry is written.

**Given** a caller with no active grant, `can_edit_learning` false or absent, or a grant for another profile
**When** `tutorRecordLearning`, `tutorVoidLearning` or `tutorUnlearn` is invoked
**Then** it fails with `permission-denied`, writes nothing, and logs `{entity, code}` with no learner data (AD-54)
**And** emulator tests cover each rejection plus an AD-52 whitelist violation, a void whose target is not a `learn` event, and idempotent replay.

**Given** a `tutorRecordLearning` call whose server-stamped `recorded_at` falls inside the learner's lock window
**When** it is processed
**Then** the event is stored, not rejected (AD-36, dev #2), and the response returns the stamped `recorded_at` so the client can label it.

### Story 1.24: TutorWriteService and tutor capture surfaces

As a tutor (rebbe),
I want to record, correct and remove a talmid's learning and keep his main track right from my own phone,
So that I keep working through the cutover and nothing I do exists as phantom offline state.

**Requirements:** FR-26 (main track and learning record), FR-28 (write side), FR-3, FR-4, NFR-2, NFR-8 (tutor devices), AR-6 (tutor half), AR-17; R2 (tutor branch of `mark_live_completion_use_case`); AD-36 (tutor lock behaviour), AD-47, AD-53, AD-54; UX-DR-85, UX-DR-101, UX-DR-142; dev #2, #3

**Acceptance Criteria:**

**Given** `TutorWriteService` (`lib/features/tutoring/data/services/tutor_write_service.dart`)
**When** this story lands
**Then** it exposes one typed method per command (`recordLearning`, `voidLearning`, `replaceLearning`, `unlearn` calling the Story 1.23 callables, plus the main-track governed methods calling the Story 1.10 callables), and the existing tutor surfaces (tutor before-tracking marking, tutor reset/unmark, tutor goal/track/study-day/stage/scope/program editing) call only these methods
**And** the tutor branch of `mark_live_completion_use_case` (left on the legacy callable path by Story 1.11) is rerouted to `TutorWriteService.recordLearning`, and the legacy branch and its call are deleted
**And** after a successful callable it emits the already-registered `capture` event through `LearningAnalytics` (AD-47), and `tool/check_analytics_catalog.dart` passes.

**Given** a tutor with an active grant and `permissions.can_edit_learning == true`, online
**When** he ticks Berachos 2:1–2:3 for the talmid
**Then** position, distinct count, tri-state and streak change on screen only after the callable returns success.

**Given** the tutor opens Mishna history for a wrongly ticked mishna
**When** he corrects the place, source or date, or removes the event
**Then** the correction runs through `tutorVoidLearning`, and count, position and target recompute after success
**And** a rejected correction leaves the list unchanged and shows the rollback snackbar (UX-DR-142).

**Given** the grant has `can_edit_learning` false
**When** the tutor opens capture, Mishna history or main-track editing for that learner
**Then** he can read what the grant's view permissions allow, every write control is visible but disabled (40% opacity, disabled semantics), and one note says "{learner}'s parent hasn't given you editing access".

**Given** the tutor device is offline (no connectivity, or a probe failure from the existing connectivity provider)
**When** any tutor write control is shown
**Then** it is disabled with "Online required", nothing is queued, and no optimistic state is shown (NFR-2, AD-53); it re-enables when connectivity returns
**And** a call that times out mid-flight shows the existing retryable error, changes nothing on screen, and a retry reuses the same ULIDs.

**Given** the target learner's `CaptureGate`, computed with the learner's settings in force (not the tutor device's), reports a lock window
**When** the tutor attempts any capture or governed write for that learner
**Then** it is blocked on the client before any callable is invoked
**And** that learner's screens on the tutor device are covered by the lock overlay with no data or controls readable, while the tutor's own app and other learners stay usable (AD-36 multi-learner rule).

**Given** a `tutorRecordLearning` call started just before the learner's lock began
**When** it returns a server-stamped `recorded_at` inside the learner's lock window
**Then** the client re-runs `CaptureGate` on that `recorded_at` and shows "Kept, not counted — Shabbos / Yom Tov had started", and no position or count changes for that event (AD-36, dev #2).

**Given** the tutor and the parent edit the same main-track field at about the same time
**When** both commit
**Then** the later server commit wins for that field (LWW, NFR-4), both `change_log` entries remain, and the tutor screen shows the winning value after its next read with no merge prompt.

### Story 1.25: Parent grants and withholds tutor edit permission

As a parent,
I want one clear "Can edit learning" permission, pre-checked when I invite a tutor and switchable at any time,
So that I decide explicitly who can change my child's main track and learning record.

**Requirements:** FR-26, NFR-19, AR-20; AD-53; dev #7; UX-DR-36, UX-DR-65, UX-DR-68, UX-DR-156, UX-DR-158

**Acceptance Criteria:**

**Given** `updateTutorGrantPermissions` in `functions/src/tutor_invites.ts`
**When** the owning parent calls it
**Then** it sets `permissions.can_edit_learning`, and the grant holds none of `can_edit_goals`, `can_edit_stages`, `can_edit_study_days`, `can_reset_completion`, `can_bulk_prior_completion` afterwards
**And** it is exported from `functions/src/index.ts`, covered by `make test-functions`, and included in the gated deploy job.

**Given** a tutor, a non-owner, or a parent-account device in child role (PIN locked)
**When** it calls `updateTutorGrantPermissions`
**Then** the callable rejects with `permission-denied` (emulator test), and the toggle is not reachable from the child role in the UI.

**Given** a parent (PIN session unlocked) on the Invite tutor screen
**When** the screen opens
**Then** a "Can edit learning" checkbox is shown pre-checked, with one line explaining that the tutor can change tracks, the deadline and learning records, and that every change is recorded
**And** the legacy toggles `can_edit_goals`, `can_edit_stages`, `can_edit_study_days`, `can_reset_completion` and `can_bulk_prior_completion` are not shown, while `can_view_progress`, `can_view_content`, `can_edit_rewards` and `can_edit_points` keep their controls.

**Given** the parent sends the invite with the box checked, or unchecked
**When** `inviteTutor` runs and the tutor accepts
**Then** the grant's `permissions.can_edit_learning` is `true`, or `false`, and the grant contains none of the legacy edit keys
**And** with `false`, the tutor's write controls for that learner are read-only (Story 1.24).

**Given** the parent switches "Can edit learning" on or off in Manage tutors, online
**When** the toggle is confirmed
**Then** `updateTutorGrantPermissions` runs, the toggle shows its new state only after success, and a failure restores the prior state with a retryable snackbar
**And** while offline the toggle is disabled with "Online required".

**Given** the parent switches it off while the tutor has the learner open
**When** the tutor next taps any write control
**Then** the callable is rejected on that call (AD-53), nothing is written, and the tutor sees "{learner}'s parent has turned off editing" while his read access stays as granted.

### Story 1.26: Retired completion callables deleted

As a developer,
I want the old reset and bulk-completion callables removed once their tutor and owner uses run through `unlearn` and the new tutor callables,
So that no server path can write to the retired `completions` store.

**Requirements:** R12, R15 (tests of deleted code), AD-31 (`unlearn`), AD-49

**Acceptance Criteria:**

**Given** the retired callables `tutorResetCompletion`, `tutorBulkPriorCompletions` (`functions/src/tutor_bulk_completions.ts`), `deleteBulkMarkedCompletions` (`deletes.ts`) and the client call `TutorWriteService.resetCompletion`
**When** R12 lands
**Then** their source, `functions/src/index.ts` exports and client calls are deleted; tutor reset and bulk-prior marking are served by the Story 1.23 callables through `TutorWriteService` (Story 1.24), and the owner "remove bulk-marked" action calls `LearningCommands.unlearn`
**And** their production deletion runs in the cutover release deploy step.

**Given** the code this story deletes
**When** it lands
**Then** their emulator tests and fixtures are deleted or ported to `tutorUnlearn` / `unlearn` tests in this story (R15), and `make test-functions` and the full suite pass.

### Story 1.27: Retired-stack test and fixture sweep

As a developer,
I want proof that no test or fixture of the retired stack is left behind,
So that the cutover release ships with a suite that tests only the new learning record.

**Requirements:** R15, AD-49

**Acceptance Criteria:**

**Given** the R15 list (repository, entity, orchestrator, sentinel, streak, pace, bookmark, order and export/import tests and fixtures)
**When** this story lands
**Then** no R15 test remains unported: each is ported to an engine/command test or deleted, and a search of `test/`, `integration_test/` and `functions/test/` finds no reference to a symbol deleted by Stories 1.11–1.26
**And** the full suite, `make test-rules` and `make test-functions` pass.

### Story 1.28: Cutover release

As a parent,
I want the old learning stores switched off in one release with the server ready first,
So that my family's devices all move to the single learning record together, with nothing written to the old stores again.

**Requirements:** R14 (deny part), AD-13 (no migration), AD-49 (cutover release), AD-54 (deploy, perf gate), AR-10, AR-11 (engine half), AR-12 (`check_retired_symbols`), NFR-5, CAP-13

**Acceptance Criteria:**

**Given** Stories 1.11–1.27
**When** the release is built
**Then** every Retirement Inventory group except R14 is done, and this story adds no further retirement work.

**Given** `firestore.rules`
**When** the release is built
**Then** every client write to `completions`, `learning_ledger`, `streak_events`, `bookmarks` and `learning_order` is denied (the matches remain as deny-all blocks), and rules tests assert the denial for each.

**Given** the callables whose source was deleted in Stories 1.16 and 1.26 (`tutorResetCompletion`, `tutorBulkPriorCompletions`, `deleteBulkMarkedCompletions`, `tutorUpsertBookmark`)
**When** the release pipeline runs
**Then** the gated CI deploy step deletes them from production explicitly with `firebase functions:delete tutorResetCompletion tutorBulkPriorCompletions deleteBulkMarkedCompletions tutorUpsertBookmark --force` before `firebase deploy`, and fails if any of them is still deployed afterwards (not merely omitted from the source).

**Given** `tool/check_retired_symbols.dart` and its checked-in allowlist
**When** CI runs
**Then** it fails on any retired collection name, field (R16), type, service or callable in `lib/`, `functions/src/` or `firestore.rules`, except the allowlist holding exactly the deny-all `match` blocks for the five retired collections, their `functions/src/deletes.ts` entries and the `streak_events` index in `firestore.indexes.json`
**And** it has unit tests and is wired into `ci.yml`.

**Given** the engine benchmark (`test/benchmark/learner_state_engine_benchmark_test.dart`) with 20 learners × (40,000 leaf events + 200 node events) on the largest corpus
**When** it runs from a warm in-memory log
**Then** engine recompute and `dailyTarget` take < 1 s per learner on the reference mid-range device, and the benchmark runs in CI as a gate for this release; a cold first load is measured and recorded, not gated.

**Given** the release pipeline
**When** it runs
**Then** the gated `firebase deploy --only firestore:rules,firestore:indexes,functions` step runs once and must pass before the app release job; the app release fails if it did not.

**Given** the shipped release
**When** production traffic runs
**Then** `completions`, `learning_ledger`, `streak_events`, `bookmarks` and `learning_order` receive zero writes; every learner sees a per-curriculum streak, distinct progress and the new 10/10 lock
**And** a tutor with `can_edit_learning` can still capture, correct and edit the main track for a granted learner (Stories 1.23–1.25 smoke test on the release build).

### Story 1.29: Release-after cleanup

As a developer,
I want the deny-all leftovers of the retired stores removed in the release after the cutover,
So that no trace of the old learning stack remains and the retired-symbol gate runs with an empty allowlist.

**Requirements:** R14 (remove part), AD-49, AD-26

**Acceptance Criteria:**

**Given** the cutover release (Story 1.28) is live in production
**When** this release is built
**Then** the deny-all `match` blocks for `completions`, `learning_ledger`, `streak_events`, `bookmarks` and `learning_order` are removed from `firestore.rules` (default deny still applies), their entries are removed from `functions/src/deletes.ts`, and the `streak_events` index is removed from `firestore.indexes.json`.

**Given** `tool/check_retired_symbols.dart`
**When** CI runs
**Then** the allowlist is empty and the check passes.

**Given** governed-collection matches in `firestore.rules`
**When** this release is built
**Then** they are untouched (amended per AD-38, never removed).

**Given** account or profile deletion (`onUserDeleted`, `deleteLearnerProfile`, `deleteAccountData`)
**When** it runs after this release
**Then** it still removes `learning_events`, `sub_tracks`, `change_log` and all governed docs recursively (emulator test), and nothing references the removed collections.

**Given** the gated deploy step
**When** it runs
**Then** it passes before the app release and drops the `streak_events` index in production.

## Epic 2: Sub-tracks and an honest daily target

Parents can add optional school-year and ongoing sub-tracks on any curriculum except one whose main track follows a calendar program. Children record sub-track learning from rows on the Learn tab with *+1* and *Up to…*. Only a parent (and, from Epic 4, a granted tutor) assigns and orders a sub-track's ground; the child sees ground read-only (FR-10, FR-11). Unfinished ground returns to the main track when the sub-track ends. The main-track daily target credits each sub-track's full capacity and adds back the shortfall. The parent sees on-track status, the projected finish and shortfall warnings. The child sees only encouragement.

**FRs covered:** FR-1, FR-2, FR-2a, FR-4a, FR-5, FR-6, FR-6a, FR-6b, FR-7, FR-8, FR-9, FR-10, FR-11, FR-12, FR-13, FR-18, FR-19, FR-20, FR-21
**NFRs:** NFR-9, NFR-12, NFR-13, NFR-15, NFR-16, NFR-20
**Depends on:** Epic 1's cutover release (AD-49). That release provides `learning_events`, `LearnerStateEngine`, `LearningCommands`/`CaptureGate`, `change_log` with the owner rule, `writeWithChangeLog`, the `SubTrack` types, codec and `SubTrackRepository` (Story 1.2), the Story 1.9 `sub_tracks` rules whitelist, the per-curriculum streak, siyum, the tri-state tree, mishna history and the FR-4 correction flow.
**Binding:** SPEC-sub-tracks CAP-1, CAP-3, CAP-4, CAP-6 and CAP-7; spine AD-33, AD-34, AD-35, AD-38, AD-41 to AD-45, AD-47, AD-52 and AD-54; and `prd-deviations.md` #3, #4, #12 and #14. If the PRD or the UX draft disagrees, the spec and spine win.
**Roles:** "parent" means the parent-PIN session (spine Roles convention). Ground assignment and ordering are parent/tutor only; the child is read-only (FR-10, FR-11). In this epic, sub-track surfaces on a tutor device are read-only (Story 2.9); a later epic adds tutor sub-track writes through `TutorWriteService` → callable → `writeWithChangeLog`. Tutor main-track learning capture already works from Epic 1 (Story 1.24). Epic 2 builds the owner path and the shared validation a later epic reuses.

### Story 2.1: Sub-track intent: model, repository and governed commands

As a parent,
I want sub-tracks stored as governed, validated intent,
So that every later surface creates, edits and ends sub-tracks through one audited, offline-safe path that enforces the same limits on every device.

**Requirements:** FR-5, FR-6, FR-6a, FR-6b, FR-7, FR-8 (data); NFR-20; AD-33, AD-38, AD-41, AD-45, AD-46, AD-52, AD-54; UX-DR-85

**Acceptance Criteria:**

**Given** the AD-52 Storage Schema row for `sub_tracks/{ulid}`
**When** the existing `SubTrack` types, codec and `SubTrackRepository` from Story 1.2 are extended with create/edit/end/delete commands, AD-45 validation and UI-facing read APIs (watch by curriculum, active/ended split), without re-creating any type
**Then** the codec still reads and writes exactly `curriculum_id`, `name`, `type` (`school_year`|`ongoing`), `academic_year` (school-year only), `window_start`, `window_end` (null = open), `rate_per_week`, `weeks_per_year`, `learns_on_shabbos`, `ground` (ordered `{level, ref}` list), `ended_at`, `end_reason` (`ended`|`deleted`|`undo`|`track_deleted`) and `last_change_id`
**And** dates are `YYYY-MM-DD` civil dates in the learner's `time_zone` (AD-41), and `rate_per_week` is stored in the curriculum's leaf units (`prd-deviations` #12)
**And** a round-trip codec test passes, and a rules test verifies that the Story 1.9 `sub_tracks` `hasOnly` whitelist rejects an extra field on the emulator

**Given** `LearningCommands` gains `createSubTrack`, `editSubTrack` (any field, including `ground` replaced whole), `endSubTrack` and `deleteSubTrack`
**When** a parent invokes any of them on an owner device
**Then** each command writes a field-level merge of only the changed fields, plus one `change_log` entry (`entity = subTrack`, `entity_id` = doc ULID, `before`/`after` keyed `sub_tracks/{id}.{field}`) in one batch, with the doc's `last_change_id` set to the entry id (AD-38)
**And** `endSubTrack` writes `ended_at` with `end_reason = ended`, and `deleteSubTrack` writes `ended_at` with `end_reason = deleted`. No client `delete` is ever issued (tombstones only).
**And** a create's `before` is `null` per field, and only `writeWithChangeLog` may claim a create (AD-38 Create)

**Given** the AD-45 limits apply per learner profile **and** curriculum
**When** a create or edit would leave more than 5 non-ended ongoing sub-tracks that are `onHome` or future-start, a second non-ended school-year sub-track for the same `academic_year`, or two school-year windows that overlap
**Then** `LearningCommands` rejects it with a typed validation error that names the violated limit, and nothing is written
**And** ended sub-tracks and sub-tracks whose window has passed don't count toward any limit
**And** the cases live in `test/fixtures/sub_track_limits/*.json` and run unchanged in the Dart suite and the `functions/` TypeScript suite against `writeWithChangeLog` validation. Both suites must agree on every fixture.

**Given** a curriculum whose main track follows a calendar program (`profile_programs.program_id` set)
**When** a sub-track create is attempted on it, or a calendar program is set on a curriculum that has a non-ended sub-track
**Then** both are rejected by `LearningCommands` and by `writeWithChangeLog` (AD-45, NFR-20), and fixtures cover both directions

**Given** a sub-track whose ground has a duplicate node entry, or a node from a different curriculum, or a `window_start` after `window_end`, or a negative or zero `rate_per_week`/`weeks_per_year`
**When** it is saved
**Then** validation rejects it before any write

**Given** the owner device is offline
**When** a parent creates or edits a sub-track
**Then** the batch is queued (one sub-track doc + one entry = 2 access calls, inside the AD-54 budget), the change is visible immediately from the local cache, and it syncs later without loss
**And** a permanently rejected batch surfaces as AD-54's per-item "not saved — retry" entry

**Given** functions or rules changed in this story
**When** the epic's first release is cut
**Then** the AD-54 gated `firebase deploy --only firestore:rules,firestore:indexes,functions` step passes before the app release, and no index is added

### Story 2.2: Engine: ground expansion, sub-track positions and ground return

As a learner,
I want each sub-track to keep its own position while assigned ground leaves the home schedule and returns when the sub-track ends,
So that the main track never schedules learning another source is covering, and nothing a source didn't finish gets lost.

**Requirements:** FR-2 (position), FR-6a, FR-9 (derived data), FR-10 (schedule effect), FR-12, FR-12a (interaction with returned ground), FR-13; AD-33, AD-34, AD-35, AD-42; UX-DR-91, UX-DR-92, UX-DR-93 (data)

**Acceptance Criteria:**

**Given** `lib/domain/learner_state/` is the only home for `expandGround`, `holdsGround`, `inForecast` and `onHome` (AD-34). If Epic 1 shipped them, this story wires them to sub-tracks; it does not create second copies.
**When** `expandGround(entries)` runs over entries at any ContentIndex level
**Then** it returns leaves in list order, each entry's leaves in ContentIndex order, with later duplicates dropped
**And** `holdsGround = !ended_at && today ≤ window_end`, `onHome = !ended_at && window_start ≤ today ≤ window_end`, and `inForecast = holdsGround && capacity interval non-empty`, where a null `window_end` is +∞
**And** `tool/check_dependency_direction.dart` still passes, so nothing under `lib/domain/**` imports Flutter, Riverpod or Firestore

**Given** a sub-track S with ground and some learn events
**When** the engine computes `LearnerState`
**Then** S's position is the first leaf in `expandGround(S.ground)` with no counted `learn` event whose `source == S.id`, or none if every leaf is ticked in S
**And** S's ticked count is the number of distinct leaves of S's ground with a counted event from source S
**And** S's remaining path is the leaves of `expandGround` from S's position to the end, learnt or not
**And** nothing about positions or remaining is persisted (AD-33)

**Given** School and Rebbe both hold Berachos 2:3
**When** a learn event for Berachos 2:3 is recorded with `source = Rebbe`
**Then** Rebbe's position advances, School's position is unchanged (FR-13), and Berachos 2:3 is in the learnt set for goal progress and tri-state

**Given** a sub-track S that `holdsGround`, including one with a future `window_start` (`prd-deviations` #4)
**When** the engine derives `schedulableRefs` and `mainTrackRemaining` for S's curriculum
**Then** every leaf in `expandGround(S.ground)` is excluded from both, and the planner's today tasks contain none of them

**Given** S ends (explicit end, `deleted`, or `today > window_end`)
**When** the engine recomputes
**Then** S's unlearnt leaves (no counted event from any source) re-enter `schedulableRefs` at their `orderedLeaves` position, not appended, and learnt leaves aren't rescheduled (FR-12)
**And** a leaf still held by another `holdsGround` sub-track stays excluded until no such sub-track holds it
**And** returned leaves that come before the current FR-12a unit are scheduled only after the current unit's schedulable leaves are exhausted (FR-12a; AD-33 current unit)
**And** S's past learn events remain counted (deletion never touches `learning_events`)

**Given** a sub-track on a curriculum whose `curriculum_tracks` doc is not `active` or has `ended_at`
**When** the engine runs
**Then** that sub-track contributes no position, no exclusion and no forecast (AD-35 evaluated curricula), while its events still count for lifetime and siyum

**Given** pure-function tests in `test/domain/learner_state/`
**When** the suite runs
**Then** it covers overlapping ground across two tracks, ground already learnt (chazara), node entries at masechta, perek and leaf levels, a future-start track, an ended track with partly learnt ground, return deferral by a second holder, and a non-Mishnayos curriculum fixture whose ground and units are not masechta/mishna (`prd-deviations` #12)

### Story 2.3: Engine: capacity, honest daily target, shortfall and projection

As a parent,
I want the daily target to credit what each sub-track will really cover and add back what it won't,
So that my child isn't told every day that he's behind, and ground a source won't finish doesn't land on him at the end.

**Requirements:** FR-18 (projection/status data), FR-19, FR-20, FR-21 (shortfall data), FR-6a (forecast from start), FR-8 (rate recompute); NFR-5, NFR-9; AD-35, AD-43, AD-44, AD-54; addendum §3; UX-DR-86, UX-DR-102

**Acceptance Criteria:**

**Given** a curriculum with a deadline goal `goals/{curriculumId}_deadline` (AD-43) and `holdsGround` sub-tracks
**When** the engine computes the forecast
**Then** for each sub-track `activeWeeksLeft = weeks_per_year × days([max(today, window_start), min(window_end ?? target_date, target_date)]) ÷ windowLengthDays`, where `windowLengthDays` is `days([window_start, window_end])` for school-year and 365 for ongoing, and `capacity = floor(rate_per_week × activeWeeksLeft)` in leaf units, or 0 when the interval is empty
**And** `path` = remaining path (Story 2.2), `expectedNewGround = max(0, capacity − |path|)`, and shortfall = the unlearnt leaves of `path` at indices ≥ capacity
**And** `numerator = mainTrackRemaining − Σ expectedNewGround + Σ shortfall`, with each shortfall leaf counted once, and not at all if another `holdsGround` sub-track holding it reaches it within its capacity
**And** `dailyTarget = max(0, ceil(numerator ÷ studyDaysToDeadline))`, or `numerator` when the divisor is 0, where `studyDaysToDeadline` counts dates in `[today, target_date]` that are study days in `study_day_configs` (all seven by default)

**Given** the FR-19 fixture: deadline 2029-03-14, today 2026-10-01, School school-year 2026 (`window_start` 2026-09-01, `window_end` 2027-07-31), 10/wk, 39 weeks, no ground, all of Berachos unlearnt
**When** the target is computed, then Berachos perakim 1–3 (n leaves from ContentIndex) are added as School's ground and the target is recomputed
**Then** capacity is `floor(10 × 39 × 304 ÷ 334) = 354` both times, `mainTrackRemaining` drops by n, `Σ expectedNewGround` drops by n, and **the daily target is unchanged**
**And** a sibling fixture where k of those n leaves were already learnt shows `mainTrackRemaining` dropping by n − k and the target rising accordingly, because chazara on the path uses capacity (FR-19)

**Given** fixtures for: a shortfall (today 2026-10-01; Rebbe ongoing, 2/wk, 52 weeks, `window_start` 2026-10-01, `window_end` null; deadline `target_date` 2026-12-09 = today + 69, so days([2026-10-01, 2026-12-09]) = 70 and capacity = floor(2 × 52 × 70 ÷ 365) = 19; 40 unlearnt ground leaves → shortfall 21, expectedNewGround 0); overlapping shortfall on two tracks (counted once); overlap where the other track reaches the leaf (not counted); two tracks' expected new ground both counted in full; a groundless track (whole capacity is expected new ground); a part-elapsed school year (prorated); a future-start ongoing track (capacity from `window_start`); an ongoing window crossing the deadline (capped at `target_date`); a numerator ≤ 0 (target 0); and zero study days left (target = numerator)
**When** the engine suite runs
**Then** every fixture matches its expected `dailyTarget`, per-track `capacity`, `expectedNewGround` and `shortfall` exactly

**Given** a per-track shortfall
**When** `LearnerState` is read
**Then** it exposes, per sub-track, the shortfall count, the shortfall leaves, the window end, and the last ground node entry containing a shortfall leaf (for FR-21 copy)
**And** the shortfall count equals the FR-19 shortfall term exactly

**Given** no deadline goal for the curriculum
**When** the engine runs
**Then** capacity, shortfall and `dailyTarget` are not computed, and the planner uses `paceRate` or nothing (AD-43). No sub-track rate affects any value (FR-20).

**Given** dated and catch-up events across all sources
**When** the projection is computed
**Then** velocity = distinct leaves newly learnt per civil day (`learned_on`), excluding chazara and `before_tracking`, over the trailing 28 days; with 14–27 days of tracked history it uses all of it; under 14 days, status is `tooEarly` with no projection (AD-35)
**And** projected finish = today + ⌈remaining corpus ÷ velocity⌉, status `onTrack` iff projected finish ≤ `target_date`, else `behindPace`
**And** one 60-leaf day after 27 quiet days flips status only if the trailing-28-day projection crosses the deadline (FR-18 fixture)
**And** while a lock (`lockWindows`) is active, the engine returns the status and projection evaluated at the lock's start, re-evaluating after the lock ends (NFR-9, FR-23)

**Given** a change to main-track order, ground (add, reorder, remove), a rate, a window, a return, or a new learn or void event
**When** the change lands in the local cache
**Then** `LearnerState` recomputes and the new target is shown on the same screen in < 1 s on a mid-range device, with no spinner on the target (NFR-5, UX-DR-86, UX-DR-102)
**And** the AD-54 benchmark (20 learners × 40,000 leaf events + 200 node events, each with 2 sub-tracks) recomputes FR-19 in < 1 s per learner

**Given** a calendar-program curriculum
**When** the engine runs
**Then** AD-44 isn't computed for it, and `dailyTarget` comes from the calendar (AD-35)

### Story 2.4: Manage tracks hub, school-year sub-track form and the onboarding mention

As a parent,
I want to find sub-tracks in Settings → Manage tracks and set up this year's school track in a short form,
So that I can record school learning when I choose to, and the app never pushes it on families who don't need it.

**Requirements:** FR-4a, FR-5, FR-6b, FR-8 (edit); NFR-20; AD-38, AD-43, AD-45; screens.md #04, #05; UX-DR-1, UX-DR-2, UX-DR-3, UX-DR-4, UX-DR-5, UX-DR-6, UX-DR-7, UX-DR-8, UX-DR-10, UX-DR-11, UX-DR-12, UX-DR-13, UX-DR-14, UX-DR-15, UX-DR-31, UX-DR-32, UX-DR-33, UX-DR-36, UX-DR-45, UX-DR-50, UX-DR-51, UX-DR-64, UX-DR-66, UX-DR-68, UX-DR-69, UX-DR-80, UX-DR-85, UX-DR-117, UX-DR-118, UX-DR-119, UX-DR-120, UX-DR-121, UX-DR-150, UX-DR-152, UX-DR-156, UX-DR-158, UX-DR-162, UX-DR-164, UX-DR-165, UX-DR-167

**Acceptance Criteria:**

**Given** a parent opens Settings → Manage tracks (`/settings/tracks`, `/parent-mode/tracks`) on a non-calendar curriculum
**When** the hub renders
**Then** below the main-track card it shows a "Sub-tracks · {n} active" group with the helper "Learning that happens outside home — school, a rebbe, a chavrusa.", one outlined row per non-ended sub-track, and an *Add sub-track* action offering School year and Ongoing (screens.md #04)
**And** with no sub-tracks, the group shows only its header text and *Add sub-track* (UX-DR-117)
**And** a load error uses the existing `TrackManagementBody` error state (UX-DR-118)
**And** tapping a row opens that sub-track's edit form (a later story in this epic changes this to open the detail)

**Given** the curriculum's main track follows a calendar program
**When** the hub renders
**Then** the Sub-tracks group and *Add sub-track* are absent (`prd-deviations` #12, AD-45)

**Given** the child (no parent-PIN session)
**When** the child navigates anywhere
**Then** no hub sub-track action, form or create entry point is reachable

**Given** the parent taps *Add sub-track* → School year
**When** the form opens
**Then** it shows filled inputs: "Sub-track name"; an "Academic year" single-select chip row; "Start month" / "End month" (default September / July); "{Leaf unit} per week" stepper (e.g. "Mishnayos per week"), labelled in the curriculum's leaf unit (`prd-deviations` #12), with the per-school-day helper; "Weeks per year" prefilled at 39 with "Prefilled — edit if the school year is shorter"; the "Learns on shabbos / yom tov" switch (default off) with "Include this source on the catch-up card after shabbos"; the info note "You can add ground later — the school's masechtos don't need to be known yet."; and the *Save sub-track* pill (screens.md #05)
**And** there are no exclusion checkboxes and no bein-hazmanim switch

**Given** the academic-year picker
**When** it renders
**Then** it offers academic years from the current one (the year Y with today in [1 Sep Y, 31 Aug Y+1]) through the year containing the deadline's `target_date`, or the current year plus the next two when there is no deadline
**And** each chip is labelled *Used* (disabled, still in the semantics tree and announced "disabled"), *Active* or *Open*. A year with a non-ended school-year sub-track is *Used* (UX-DR-32, UX-DR-36, UX-DR-158).

**Given** the curriculum has no deadline goal
**When** either sub-track form renders
**Then** an inline note says that without a deadline a sub-track can't lower the daily target, with a link that opens the existing deadline/goal setup for this curriculum (SPEC CAP-3)
**And** saving is still allowed

**Given** the parent saves a school-year form
**When** validation runs (on blur and on save)
**Then** `window_start` = the 1st of the start month and `window_end` = the last day of the end month, spanning `academic_year` → `academic_year + 1`, and overlapping windows, a used year, an empty name or a non-positive rate or weeks block save with inline field errors (UX-DR-80)
**And** on success, `createSubTrack` (Story 2.1) runs, the hub shows the new row at once (also offline, UX-DR-85), and the daily target recomputes on the same screen (Story 2.3)
**And** a save failure keeps the form values and shows a retryable error snackbar (UX-DR-120). A batch rejected at sync removes the row and shows "Your change couldn't be saved." (UX-DR-119, UX-DR-121).

**Given** an existing school-year sub-track
**When** the parent edits any field and saves
**Then** only the changed fields are written through `editSubTrack`, with the same validation (its own year is not counted as *Used*), and a rate edit recomputes the daily target immediately (FR-8)

**Given** onboarding runs for a new family
**When** the parent reaches the existing main-track/goal step
**Then** exactly one static info note says that school and rebbe sub-tracks can be added later from Settings → Manage tracks. It has no button, link, field or extra step, and it never repeats (FR-4a, UX-DR-33, UX-DR-64, UX-DR-152).
**And** nowhere else in the app prompts, nudges or suggests creating a sub-track (UX-DR-66, UX-DR-167)

**Given** dark mode, a tablet ≥ 600dp, platform text scaling at maximum, or the Hebrew locale
**When** the hub and the form render
**Then** they use the AppPalette tokens with their dark values (UX-DR-2 to UX-DR-8, UX-DR-165), flat 1px-outlined cards at elevation 0 (UX-DR-15), the type scale, radii and spacing (UX-DR-11 to UX-DR-14), and ≥ 48dp targets with no clipping at large text (UX-DR-156)
**And** on tablets the form is capped at 600px next to a summary panel listing the learner's sub-tracks and "Capacity {n} … ({rate}/wk × {weeks} weeks)" (no projections, badges or tips), and the shell uses the navigation rail at ≥ 600dp (UX-DR-45, UX-DR-162, UX-DR-164)
**And** RTL mirrors with `EdgeInsetsDirectional` (UX-DR-161)

### Story 2.5: Ongoing sub-track form with future start and the five-track limit

As a parent,
I want to create an ongoing sub-track for a rebbe or chavrusa, optionally starting later,
So that a source with no school calendar is still forecast honestly.

**Requirements:** FR-6, FR-6a, FR-6b, FR-8 (edit); AD-34, AD-44, AD-45; screens.md #06; UX-DR-31, UX-DR-36, UX-DR-52, UX-DR-80, UX-DR-82, UX-DR-89, UX-DR-103, UX-DR-120, UX-DR-121, UX-DR-158, UX-DR-164, UX-DR-165

**Acceptance Criteria:**

**Given** the parent taps *Add sub-track* → Ongoing
**When** the form opens
**Then** it shows "Sub-track name", the rate stepper (leaf units), "Not learning during bein hazmanim" (off by default) with "Lowers weeks per year", "Weeks per year" prefilled (52 [ASSUMPTION]), "Start date (optional)", "End date (optional)", the "Learns on shabbos / yom tov" switch (default off), the limit line "You can have up to 5 ongoing sub-tracks. {n} in use.", and *Save sub-track* (screens.md #06)

**Given** the weeks field has not been edited by the user
**When** the bein-hazmanim switch is toggled
**Then** only the prefilled weeks value changes (52 ↔ 44 [ASSUMPTION per mock]), and the helper reads "Prefilled from bein hazmanim toggle — edit if needed"
**And** once the user has typed a weeks value, toggling the switch never overwrites it, and the switch itself is not stored (FR-6)

**Given** no start date is entered
**When** the form is saved
**Then** `window_start` = the learner's civil today and `window_end` = the end date or null (open). An end date before the start date blocks save inline.

**Given** a future start date
**When** the sub-track is saved
**Then** it is absent from Learn until `window_start` (`onHome` false), the hub row shows "Starts {date}" (UX-DR-89), its ground leaves the main schedule at once (`holdsGround`, `prd-deviations` #4), and its capacity counts only from `window_start` (FR-6a, Story 2.3)

**Given** the profile has 5 non-ended ongoing sub-tracks on this curriculum that are `onHome` or future-start
**When** the parent opens *Add sub-track*
**Then** Ongoing is visible but disabled and announced "disabled", with "You can have up to 5 ongoing sub-tracks. 5 in use." (UX-DR-103, UX-DR-36)
**And** ended sub-tracks and those whose `window_end` has passed don't count (UX-DR-82)
**And** a sixth create that arrives anyway (for example, two offline devices) is rejected by the AD-45 validation where it runs. If two offline creates both sync, the engine tolerates the excess without error (AD-45).

**Given** an existing ongoing sub-track
**When** the parent edits it, including setting an end date in the past
**Then** the change is written via `editSubTrack`, the daily target recomputes on save, and a sub-track whose `window_end` is now before today leaves Learn and returns its unlearnt ground (Story 2.2)

**Given** save failure, sync rejection, dark mode or tablet
**When** the form is used
**Then** it behaves as the school-year form in Story 2.4 (UX-DR-120, UX-DR-121, UX-DR-164, UX-DR-165)

### Story 2.6: Sub-track detail with capacity, ordered ground and reorder

As a learner or parent,
I want to open a sub-track and see its ground in order, its progress and how much it can still cover,
So that everyone sees where this source stands, and the parent can fix its order.

**Requirements:** FR-9, FR-11, FR-13 (display), FR-15 (detail), FR-12 (remove-ground return); AD-33, AD-34, AD-38, AD-44, AD-54; screens.md #07; UX-DR-19, UX-DR-26, UX-DR-27, UX-DR-53, UX-DR-67, UX-DR-73, UX-DR-78, UX-DR-91, UX-DR-92, UX-DR-97, UX-DR-122, UX-DR-123, UX-DR-124, UX-DR-155, UX-DR-157, UX-DR-160, UX-DR-161, UX-DR-163, UX-DR-164, UX-DR-165

**Acceptance Criteria:**

**Given** any role opens a sub-track (from a hub row, which now opens the detail instead of the form, with Edit moving to ⋮)
**When** the detail renders
**Then** it shows the window, "Up next" with the current position (or none when all ground is ticked), "{n} ticked" (distinct leaves ticked in this track), the capacity bar, and "Ground (in order)" (screens.md #07)
**And** load failure shows `AppErrorView` with retry (UX-DR-123)

**Given** a deadline exists
**When** the capacity bar renders
**Then** it shows "Capacity vs Path", "{remaining path} / {capacity}", a 6dp bar and "Remaining path: {p} · Total capacity: {c}", using the engine's values from Story 2.3 (UX-DR-26)
**And** when shortfall = 0 the tag reads "No shortfall" (success token). When shortfall > 0, the parent sees the shortfall count in a warning tag, and the child sees the bar and caption with **no** tag or count (UX-DR-97, NFR-9).
**And** with no deadline the bar is hidden [ASSUMPTION], and the parent sees the Story 2.4 no-deadline note with its link

**Given** the ground list
**When** it renders
**Then** each node entry is a tri-state row (complete / partial dash / empty, 12% tint, 20dp indent per depth, chevron, "{learnt} of {total} learnt") derived from all-source learning (UX-DR-19, UX-DR-27, UX-DR-73)
**And** leaves learnt from another source render learnt with "learnt at home" / "learnt at {source name}" and don't move this track's position (FR-9, FR-13, UX-DR-91)
**And** ground also held by another non-ended sub-track shows "{name} · In use" (UX-DR-92)
**And** tapping a leaf label opens the Epic 1 mishna history (Story 1.13). Tapping a non-leaf label expands it.

**Given** a groundless sub-track
**When** the detail renders
**Then** the ground list is empty and shows the groundless state (UX-DR-122); *+ Add ground* is added by the ground-picker story later in this epic

**Given** the parent drags a ground row by its handle, or uses ⋮ → *Move up* / *Move down*
**When** the reorder is dropped
**Then** `editSubTrack` writes the whole reordered `ground` list with one `change_log` entry, ticks are kept, the position becomes the first leaf in the new order not ticked in this track, and the forecast, main-track schedule and today's tasks recompute with no stale tasks (FR-11, UX-DR-78)
**And** every drag has the non-drag equivalent, and handles and chevrons mirror in RTL (UX-DR-155, UX-DR-160, UX-DR-161)

**Given** the parent uses ⋮ → *Remove from {name}* on a ground entry
**When** it is confirmed
**Then** the entry is removed from `ground`, and its leaves that are unlearnt by any source and not held by another `holdsGround` sub-track return to the main track at their original position (FR-12, Story 2.2)
**And** a rejected reorder or remove rolls back with a snackbar (UX-DR-124)

**Given** the child
**When** the detail renders
**Then** it is read-only: no drag handles, no ⋮ edit, delete or remove, and copy carries no judgement (UX-DR-27, UX-DR-67)

**Given** a tablet ≥ 840dp, dark mode or a screen reader
**When** the hub and detail are shown
**Then** the hub list and detail sit in two panes, with the list keeping its selection and the detail updating in place (UX-DR-163, UX-DR-164). Dark tokens apply (UX-DR-165).
**And** tri-state checkboxes announce "complete" / "partially learnt, 3 of 9" / "not learnt" (UX-DR-157)

### Story 2.7: Ground picker and assigned ground greyed on the main track

As a parent,
I want to add a masechta, perek or single mishna to a sub-track whenever I learn what school or the rebbe is doing,
So that home stops scheduling it without the target jumping.

**Requirements:** FR-10, FR-11 (append), FR-15 (picker), FR-19 (unchanged-target consequence); NFR-20; AD-33, AD-34, AD-42, AD-44, AD-45; screens.md #08; UX-DR-19, UX-DR-30, UX-DR-54, UX-DR-63, UX-DR-73, UX-DR-79, UX-DR-92, UX-DR-93, UX-DR-125, UX-DR-126, UX-DR-127, UX-DR-150, UX-DR-157, UX-DR-160, UX-DR-164, UX-DR-165, UX-DR-167

**Acceptance Criteria:**

**Given** a sub-track detail (Story 2.6)
**When** the parent views it, including in its groundless state
**Then** *+ Add ground* is shown and opens the picker (UX-DR-54, UX-DR-122).

**Given** the parent taps *+ Add ground* on a sub-track detail
**When** the picker opens (full screen on phone, a right pane next to the detail on tablet)
**Then** it shows "Add ground to {name}", search, the *Available only* filter, the curriculum's ContentIndex tree at every level with tri-state rows and the "Complete · Partial · Empty" legend, and a sticky footer with *Reset changes* and a live "Add {n} {level-unit} to {name}" pill, plus the note "They'll leave the home schedule while {name} holds them." (screens.md #08, UX-DR-30)
**And** level names and counts come from the curriculum's ContentIndex, not Mishnayos-specific labels (`prd-deviations` #12)
**And** load failure shows `AppErrorView` with retry (UX-DR-126)

**Given** the tree
**When** the parent selects nodes
**Then** selecting a parent selects its descendants, nodes already in this sub-track are pre-checked and disabled, ground held by another non-ended sub-track stays selectable and is tagged "{name} · In use", and ground already learnt stays selectable and is tagged "Chazara" (UX-DR-79, UX-DR-92)
**And** *Available only* hides in-use and learnt nodes. If nothing is left it shows "Everything here is already assigned or learnt." (UX-DR-125)
**And** *Reset changes* clears only the pending selection

**Given** the parent confirms
**When** the selection is appended
**Then** the selected node entries are appended to the end of `ground` in tree order through `editSubTrack`, one `change_log` entry is written, entries already covered by an existing entry in this track are not duplicated, and no entry from another curriculum is accepted (FR-10, FR-11)
**And** the main track's schedule, today's tasks and daily target recompute on the same screen
**And** a rejected assignment rolls back with a snackbar (UX-DR-127)

**Given** School (10/wk, groundless, all Berachos unlearnt) and a deadline
**When** the parent adds Berachos perakim 1–3 through the picker
**Then** the daily target on screen is unchanged (FR-19 fixture, UJ-3 step 4)

**Given** a leaf is held by a `holdsGround` sub-track
**When** the main corpus progress and browse views render
**Then** the leaf stays visible but greyed, is not scheduled, and carries the holding sub-track's name as a tag (UX-DR-63, UX-DR-93)
**And** after the sub-track ends, its unlearnt returned leaves render normally and are scheduled per FR-12a

**Given** a calendar-program curriculum
**When** any entry point to the picker is reached
**Then** the picker is unavailable, because sub-tracks can't exist there (AD-45)

**Given** the child session (no parent PIN)
**When** any sub-track detail, row or Dashboard card renders
**Then** no *+ Add ground* entry point is shown and the picker route is not reachable; ground is read-only for the child (FR-10, FR-11)

**Given** a screen reader, dark mode or a tablet
**When** the picker is used
**Then** checkboxes announce tri-state values and selection, focus moves to the title on open and returns to the trigger on close (UX-DR-157, UX-DR-160), and dark and tablet compositions follow the #08 mocks (UX-DR-164, UX-DR-165)
**And** none of the mock's "sync across class benchmarks" behaviour exists. Overlap is never reconciled (UX-DR-167).

### Story 2.8: Sub-track lifecycle: add next year, end, delete and ended sub-tracks

As a parent,
I want to roll School into next year in one tap, and end or delete a sub-track safely,
So that each year is quick to set up and nothing a source didn't finish is lost.

**Requirements:** FR-7, FR-8 (delete), FR-12; AD-38, AD-45, AD-47; screens.md #04, #07; UX-DR-28, UX-DR-29, UX-DR-36, UX-DR-44, UX-DR-51, UX-DR-70, UX-DR-81, UX-DR-82, UX-DR-90, UX-DR-150, UX-DR-158

**Acceptance Criteria:**

**Given** a school-year sub-track for `academic_year` Y
**When** the parent taps *Add next year ({Y+1}–{Y+2 short})* on its detail
**Then** the school-year form opens prefilled with the same name, rate, weeks per year, `learns_on_shabbos`, and the edited start and end months, for `academic_year = Y + 1` with empty ground, and every field is editable before *Save sub-track* (FR-7, AD-45)
**And** saving creates a new sub-track (new ULID), and the source track is unchanged

**Given** year Y + 1 already has a non-ended school-year sub-track, or is past the picker range
**When** the detail renders
**Then** *Add next year* is an outlined pill that stays visible but disabled and is announced "disabled" (UX-DR-28, UX-DR-36, UX-DR-158)

**Given** the parent chooses ⋮ → *Delete track*
**When** the existing `showAppConfirmDialog` opens
**Then** it shows a warning icon and copy saying unfinished ground returns to home learning and the learning events stay in the lifetime record, with a destructive confirm and Cancel. Dismissing it equals Cancel. (UX-DR-29, UX-DR-81)
**And** on confirm `deleteSubTrack` writes `ended_at` + `end_reason = deleted`, the app returns to the hub, the schedule and target recompute, and a snackbar confirms
**And** no `learning_events` doc is touched, and events from that track keep the track's stored name as their source label (FR-8)

**Given** the parent chooses ⋮ → *End sub-track now* [ASSUMPTION: entry point]
**When** it is confirmed
**Then** `endSubTrack` writes `ended_at` + `end_reason = ended`, and the ground return follows Story 2.2

**Given** a sub-track that is ended (`ended_at` set) or whose `window_end` has passed
**When** the hub renders
**Then** it is absent from the active group and listed in a collapsed "Ended sub-tracks ({n})" group with muted rows, never labelled "Completed" (UX-DR-44, UX-DR-70, UX-DR-90)
**And** an ended row opens the detail read-only, with no edit, reorder, ground or delete actions, and it doesn't count toward any AD-45 limit (UX-DR-82)
**And** it is absent from Learn and the Dashboard

**Given** the window passes with no user action (for example, 1 Aug after a Sep–Jul window)
**When** the engine recomputes on the learner's civil today
**Then** the ground returns without any write (derived, AD-33), the main schedule and target recompute, and the hub moves the track to Ended

### Story 2.9: Learn tab sub-track rows with +1, and dashboard summary cards

As a child,
I want each of my outside sources as one row under today's tasks that I can tick with one tap,
So that recording school and rebbe learning takes seconds and never needs a menu or source picker.

**Requirements:** FR-1, FR-2 (+1, groundless), FR-4a (absence), FR-6a (hidden), FR-13; NFR-2 (tutor read-only), NFR-9, NFR-15; AD-31, AD-34, AD-36, AD-40, AD-50; screens.md #01, #03 (summary cards); UX-DR-16, UX-DR-17, UX-DR-25, UX-DR-46, UX-DR-49, UX-DR-53, UX-DR-54, UX-DR-66, UX-DR-67, UX-DR-71, UX-DR-77, UX-DR-85, UX-DR-87, UX-DR-88, UX-DR-101, UX-DR-89, UX-DR-90, UX-DR-104, UX-DR-105, UX-DR-106, UX-DR-107, UX-DR-114, UX-DR-115, UX-DR-116, UX-DR-148, UX-DR-154, UX-DR-156, UX-DR-157, UX-DR-158, UX-DR-161, UX-DR-164, UX-DR-165, UX-DR-166

**Acceptance Criteria:**

**Given** a learner with `onHome` sub-tracks on the curriculum in view
**When** the Learn tab renders
**Then** the main-track today list renders exactly as before (widget golden unchanged), and beneath it an "Also learning · {n} sub-tracks" section shows exactly one outlined row per `onHome` sub-track in hub order, however many masechtos its ground holds (FR-1, UX-DR-46, UX-DR-71)
**And** each row shows the name and "Next: {position}", then exactly *Up to…* (blue text button) and *+1* (blue filled pill), both ≥ 48dp, with no source, rate or pace badges (UX-DR-16, UX-DR-17)
**And** future-start, ended and window-passed sub-tracks have no row. With no `onHome` sub-tracks the section is absent and nothing invites creation (FR-4a, UX-DR-87, UX-DR-105)
**And** the same rows appear for child and parent sessions

**Given** the child taps *+1* on School
**When** `LearningCommands` records it through `CaptureGate`
**Then** one `learn` event is written with `ref` = School's position, `source` = School's ULID, `date_state = dated`, `learned_on` = civil today, no `stage` and no `pts_` entry (AD-50), and no source prompt is shown
**And** in the same frame the row shows the next leaf not ticked in School, the distinct count and masechta fill update, the streak is not extended by this event (Epic 1 AD-40) and no copy implies it counts less, and a siyum fires if a masechta became fully learnt (UX-DR-104)
**And** a "Recorded 1 · Undo" snackbar appears, and Undo voids the event (UX-DR-154)
**And** other tracks' positions don't change (FR-13)
**And** recording one leaf for a source takes 1 tap, within SM-4's median ≤ 4 taps per source captured (NFR-15)

**Given** a sub-track with no ground
**When** its row renders
**Then** the child sees "No ground yet" in place of the position, with *+1* and *Up to…* visible but disabled at 40% opacity and announced "disabled". The parent sees *Add ground*, which opens the ground picker (FR-2, UX-DR-88, UX-DR-36)
**And** its capacity still counts in the forecast (Story 2.3)

**Given** every leaf of a sub-track's ground is ticked in that track
**When** its row renders
**Then** it shows "All ground recorded" [ASSUMPTION copy] with both actions disabled, and the parent sees *Add ground*

**Given** the device is offline, or the write is attempted during a lock
**When** *+1* is tapped
**Then** offline capture works optimistically and syncs later (UX-DR-85). A write the `CaptureGate` refuses is not written.
**And** a learn event later found lock-stamped is kept, not counted (AD-36, `prd-deviations` #2). After sync the row reflects the engine's state, and a snackbar says "Kept, not counted — recorded during Shabbos" (UX-DR-107).

**Given** the section's data fails to load
**When** the Learn tab renders
**Then** the section shows `InlineAsyncError` with retry, and the main-track tasks are unaffected (UX-DR-106)

**Given** any role taps a row body
**When** it is tapped
**Then** the sub-track detail opens (UX-DR-53)

**Given** a learner with `onHome` sub-tracks
**When** the Dashboard renders for child or parent
**Then** a "Sub-tracks ({n})" section shows one summary card per `onHome` sub-track with name, "Next: …", "{ticked} ticked" and an `AnimatedProgressBar` of ticked ÷ (ticked + remaining path), with no sub-track-level status (UX-DR-25, UX-DR-49, UX-DR-77)
**And** a card opens the detail, *Manage* opens the hub for a parent and is absent for the child, the section is absent when there are no active sub-tracks (UX-DR-114), and a load error shows inline per section (UX-DR-115)

**Given** a tutor session viewing a learner
**When** sub-track rows, the Dashboard sub-track cards, the hub's sub-track group, the sub-track detail or the ground-picker entry points render
**Then** they are read-only: every sub-track write control (*+1*, *Up to…*, *Add ground*, *Add sub-track*, edit, reorder, remove, end, delete, *Add next year*) is visible but disabled (40% opacity, disabled semantics, announced "disabled"), with one note "Editing sub-tracks from a tutor device is coming soon" [ASSUMPTION copy], until a later epic enables tutor sub-track writes (UX-DR-36, UX-DR-158)
**And** main-track capture through `TutorWriteService` (Story 1.24) is unaffected, and no sub-track write is attempted from a tutor device.

**Given** platform text scaling at maximum, Hebrew locale, dark mode or tablet
**When** rows render
**Then** name and position stack above the actions without truncation, Hebrew marks never clip, semantics read "School, next Berachos 1:4" with actions "Record one mishna for School" / "Record up to, School", RTL mirrors, and the dark and tablet compositions follow #01 (UX-DR-156, UX-DR-157, UX-DR-161, UX-DR-164, UX-DR-165)

### Story 2.10: Up to… picker on sub-track rows and the main-track today list

As a child,
I want to tap where my class stopped and untick anything we skipped,
So that a whole session goes in with a couple of taps and only what I really learnt is recorded.

**Requirements:** FR-2 (up to…), FR-2a (sub-track rows and main-track list; the catch-up variant comes in a later epic), FR-3 (sub-track source in free tick), FR-4 (sub-track source in corrections); NFR-15; AD-31, AD-36, AD-50, AD-54; screens.md #02; UX-DR-18, UX-DR-47, UX-DR-72, UX-DR-108, UX-DR-109, UX-DR-110, UX-DR-148, UX-DR-154, UX-DR-157, UX-DR-160, UX-DR-163, UX-DR-164, UX-DR-165, UX-DR-166

**Acceptance Criteria:**

**Given** the child taps *Up to…* on the School row
**When** the picker opens (a rounded-top sheet on phone, a centred dialog of at most 480px on tablet)
**Then** it shows "School · up to…", "Tap the last mishna you learnt", and School's leaves in `expandGround` order from the current position through the end of its ground, loaded lazily, with Cancel and a "Record {n} mishnayos" button (n uses the curriculum's leaf unit) (UX-DR-18)
**And** there is no source badge or picker in the sheet (screens.md drift note)
**And** focus moves to the title, and closing returns focus to the *Up to…* button (UX-DR-160)

**Given** the picker is open
**When** the child taps a row
**Then** that row is the highlighted target, and every row from the position through it is *Included*. Any row can then be unticked (*Skipped*) or re-ticked, and the button count is live and counts only included rows (UX-DR-72)
**And** rows after the position that are already ticked in this track show as already recorded, are not selectable, and are never written twice

**Given** the child taps *Record {n} mishnayos*
**When** `LearningCommands` writes through `CaptureGate`
**Then** exactly one `dated` learn event per included leaf is written with the sub-track as source and `learned_on` = civil today, chunked at ≤ 450 writes per AD-54. Skipped leaves get no event, and the position becomes the first unticked leaf in track order (FR-2, FR-2a).
**And** the sheet closes, the row updates in the same frame, and "Recorded {n} · Undo" voids all n events (UX-DR-154)

**Given** the child taps Cancel, swipes down, or uses platform back
**When** the picker closes
**Then** nothing is recorded (UX-DR-166)

**Given** the main-track today list
**When** it renders
**Then** it offers *Up to…* in addition to ticking each task, and task generation is unchanged (FR-2a)
**And** its picker lists main-track leaves from the main-track position in `schedulableRefs` order, starting with today's new-learning tasks [ASSUMPTION: review/chazara tasks keep individual ticks only]
**And** confirm writes `source = main`, `dated`, `stage = firstStageOrder` events, each with its `pts_{eventId}` entry in the same chunk (AD-50), and the streak updates per AD-40

**Given** a groundless sub-track, or a track with no leaves left after its position
**When** *Up to…* is tapped
**Then** a groundless track never opens the picker (actions are disabled, Story 2.9), and an exhausted track shows "No more mishnayos in {name}'s ground." (UX-DR-108)

**Given** the list fails to load
**When** the picker shows
**Then** an inline error with retry appears inside the sheet, and *Record* is disabled (UX-DR-109)
**And** a later sync problem follows the Learn rollback snackbar treatment (UX-DR-110)

**Given** a screen reader, dark mode or a tablet
**When** the picker is used
**Then** each row announces included, skipped, next up or already recorded, the confirm label carries the live count (UX-DR-157), and the dark sheet and tablet dialog follow #02 (UX-DR-163, UX-DR-164, UX-DR-165)

**Given** a learner with `onHome` sub-tracks
**When** a free-tick batch or tick-to-here is confirmed in Browse (Story 1.11 confirm sheet)
**Then** the source radios list Home (default), each `onHome` sub-track of that curriculum by name, and Before tracking; choosing a sub-track writes `source` = its ULID, `dated`, no `stage` and no `pts_` entry (FR-3, UX-DR-20, AD-50)
**And** in Mishna history (Story 1.13), *Correct source* offers the same list, and the replacement follows the Story 1.7 `replace` rules (FR-4)
**And** on a tutor device the sub-track sources are not offered while tutor sub-track writes are read-only (Story 2.9).

**Given** UJ-1 (main tasks in the morning; at bedtime School *Up to…* → target → untick 2:1 → *Record 4 mishnayos*; Rebbe *+1*)
**When** it runs as an integration test
**Then** School reads "Next: Berachos 2:1", 4 School events and 1 Rebbe event exist, the distinct count rose by the new distinct leaves, and the streak reflects only the morning's main-track learning
**And** each source is captured in ≤ 4 taps (School: *Up to…*, target, untick, *Record* = 4; Rebbe: *+1* = 1), meeting SM-4 as median ≤ 4 taps per source captured (NFR-15, `prd-deviations` #15)

### Story 2.11: Parent on-track card, shortfall warnings and child encouragement

As a parent,
I want to see at a glance whether my son is on track for the deadline, and which source won't finish its ground,
So that I can act early, while he sees only encouragement.

**Requirements:** FR-18, FR-19 (display, zero target), FR-20, FR-21; NFR-9; AD-35, AD-36, AD-43, AD-44; screens.md #03, #01 (encouragement); UX-DR-6, UX-DR-7, UX-DR-22, UX-DR-23, UX-DR-24, UX-DR-48, UX-DR-67, UX-DR-68, UX-DR-69, UX-DR-75, UX-DR-76, UX-DR-94, UX-DR-95, UX-DR-96, UX-DR-97, UX-DR-98, UX-DR-111, UX-DR-112, UX-DR-113, UX-DR-150, UX-DR-157, UX-DR-164, UX-DR-165

**Acceptance Criteria:**

**Given** a parent session, a deadline, and ≥ 14 days of tracked history
**When** the Dashboard renders
**Then** the on-track card shows an icon plus text status "On track" (success) or "Behind pace" (amber), "Projected finish: {date} · deadline {date}" and "Daily target: {n} {leaf unit}/day", all read from `LearnerState` (Story 2.3) (UX-DR-23, UX-DR-24, UX-DR-75)
**And** status is announced as text, never by colour alone (UX-DR-157)

**Given** under 14 days of tracked history
**When** the parent views the card
**Then** it shows "Too early to tell" (neutral) with no projection or status (UX-DR-94, UX-DR-111)

**Given** no deadline goal
**When** the parent views the card
**Then** it shows only "Projected finish: {date}", with no status and no daily target, and no sub-track rate affects anything shown (FR-20, UX-DR-95)

**Given** `dailyTarget == 0` with a deadline
**When** the parent Dashboard or the child Learn today section renders
**Then** it shows "All covered — any extra learning is a bonus." (UX-DR-96)

**Given** a sub-track with shortfall > 0
**When** the parent views the Dashboard
**Then** one full-width amber shortfall card per such track sits directly under the on-track card, saying "{name} may not reach {last ground entry with shortfall} before {window end month}. About {shortfall} {leaf unit} will return to home learning." with *View {name} →* opening that sub-track's detail (UX-DR-22, UX-DR-76, UX-DR-68)
**And** the number equals the engine's FR-19 shortfall for that track, and the card disappears on the next recompute after shortfall reaches 0 (FR-21)

**Given** the child session (no parent PIN)
**When** any Dashboard, Learn or detail surface renders
**Then** no on-track card, "Behind pace", "off track", projection, shortfall card or shortfall count appears anywhere (NFR-9, UX-DR-48, UX-DR-97)
**And** the child sees "Today {done} of {target} done", warm forward-looking encouragement and the streak of the curriculum in view (UX-DR-67)
**And** a widget test sweeps every Epic 2 surface in child mode for the banned strings

**Given** a lock is in force
**When** the overlay lifts
**Then** the status shown afterwards was not changed by the locked days alone (frozen per Story 2.3), and it re-evaluates with any catch-up events (UX-DR-98)

**Given** the status data fails to load
**When** the card renders
**Then** it shows `InlineAsyncError` with retry (UX-DR-112). The surface is read-only, so there is no rejected-sync state (UX-DR-113).

**Given** dark mode or a tablet
**When** the Dashboard renders
**Then** the warning and success tokens use their dark values with ≥ 4.5:1 text contrast, and the tablet status row, shortfall card and summary grid follow #03 (UX-DR-6, UX-DR-7, UX-DR-164, UX-DR-165)

### Story 2.12: Sub-track analytics for SM-1, SM-2, SM-4 and SM-5

As the product owner,
I want child-safe analytics on capture, sub-track adoption, tap effort and forecast honesty,
So that we can tell whether sub-tracks deliver daily capture at a median of ≤ 4 taps per source captured and forecasts close to reality.

**Requirements:** NFR-12 (SM-1), NFR-13 (SM-2), NFR-15 (SM-4), NFR-16 (SM-5), NFR-17; AD-47; spine Deferred (success-metric aggregation is owned here); `prd-deviations` #15

**Acceptance Criteria:**

**Given** the existing `LearningAnalytics` emitter in `lib/features/learning/domain/commands/`
**When** a sub-track or main-track capture succeeds in `LearningCommands`
**Then** one `capture` event is emitted with enums and counts only: `curriculum_id`, `source_type` (`main` | `school_year` | `ongoing`), `gesture` (`plus_one` | `up_to` | `task_tick`), `event_count`, `skipped_count` and `taps` (the user taps that gesture took, from opening to confirm)
**And** no ref, name, date, free text or profile id is sent, and the per-install salted profile hash is a user property (AD-47)

**Given** a sub-track create, edit, ground add, reorder, remove, end, delete or *Add next year*
**When** the command succeeds
**Then** one `subtrack_lifecycle` event is emitted with `curriculum_id`, `type` and an `action` enum, plus counts (ground entries, leaves)

**Given** an explicit end, a delete or *Add next year*
**When** the command succeeds
**Then** one `subtrack_forecast_vs_actual` event is emitted with `type`, the capacity the engine forecast for the window when the track was created (stored nowhere; recomputed from the creation-time `change_log` entry), the actual distinct leaves ticked in the track within its window, and the window length in weeks (SM-5)

**Given** the new events
**When** CI runs
**Then** they are registered in `AnalyticsEvent`, and `tool/check_analytics_catalog.dart` passes
**And** the catalog entry records the aggregation for each metric: SM-1 = learner-days with ≥ 1 `capture` ÷ non-locked days over 4 weeks; SM-2 = hashed learners with ≥ 1 `subtrack_lifecycle` create and a sub-track `capture` in the last 14 days; SM-4 = median, over (learner-day, source) pairs with ≥ 1 capture, of Σ `taps` for that source's captures that day, target ≤ 4 (per source captured, not per full day); SM-5 = |forecast − actual| per track; events/day is never a target (NFR-17)

**Given** a tutor session
**When** analytics fire
**Then** nothing is emitted from this story's owner path for tutor writes. `TutorWriteService` reuses the same emitter (Epic 1 Story 1.24 for `capture`; a later epic extends this to `subtrack_lifecycle`) (AD-47).

**Given** this epic verifies the Story 1.9 `sub_tracks` whitelist and changes `writeWithChangeLog` validation (AD-45 sub-track limits, calendar-program rejection)
**When** the epic's app release is cut
**Then** the AD-54 gated CI deploy (`firebase deploy --only firestore:rules,firestore:indexes,functions`) runs with the rules and functions test jobs and must pass before the app release job; the app release fails if it did not.

## Epic 3: Erev and catch-up

On erev the learner sees what is planned for the locked days, with every control live. During the lock the existing unreadable overlay from Epic 1 covers the app. After shabbos or yom tov, one catch-up card per lock records that learning, dated to the locked days, in one tap or through *Adjust…*. A reminder notification fires once when the card becomes available, and a catch-up completed inside its window keeps the streak. Nothing in this epic pressures a child to log on a sacred day or to log learning that did not happen.

**FRs covered:** FR-24, FR-25 (with FR-6b consumed, FR-2a catch-up variant, FR-16 locked-day streak clause)
**NFRs:** NFR-14, NFR-18 (respects NFR-1, NFR-6–NFR-9)
**Depends on:** Epic 1 (`lockWindows`, `lockedDays`, `catchUpWindow`, `streakDay`, `CaptureGate`, `SacredTimeLockOverlay` on `lockWindows`, `LearningCommands` with `date_state = catch_up`, `LearningAnalytics`); Epic 2 (sub-tracks with stored `learns_on_shabbos`, `onHome`, home rows, Up-to picker with individual adjust).
**Binding decisions:** AD-35, AD-36, AD-37, AD-40, AD-41, AD-47, AD-49 (planner), AD-50, spine Consistency Conventions → Reminders; `prd-deviations.md` #2 and #10.

**Assumptions carried by this epic (UX left them open; confirm before dev):**
- A-1 Erev window start: the erev view appears from 00:00 learner-local on the civil day the lock starts (EXPERIENCE `[ASSUMPTION: start of window = the day of candle-lighting]`) and ends at `L.start`.
- A-2 Erev banner copy: "Shabbos Kodesh · שבת קודש" and "Shabbos begins at {time} — record what you can before then." (EXPERIENCE `[ASSUMPTION copy]`). Yom tov and combined labels ("Yom Tov", "Yom Tov & Shabbos", Yom Kippur) follow the same pattern and the existing overlay's day-type naming.
- A-3 A sub-track's planned amount per locked day on the catch-up card is its `rate_per_week ÷ 7`, rounded up, taken in order from its position (EXPERIENCE `[ASSUMPTION]`: "that track's planned amount for the lock").
- A-4 Pending cards stack oldest first (EXPERIENCE `[ASSUMPTION order]`), and their planned lists are laid out in sequence: a later card continues after the leaves an earlier pending card already plans.
- A-5 A card is complete once a Record action from it has written at least one counted `catch_up` event for that lock. This is derived from events, not stored locally, so every device on the profile agrees.
- A-6 Catch-up card, reminder and lock-stamped ("kept, not counted") copy is draft (`[ASSUMPTION copy]` in EXPERIENCE). Reminder copy is open. It must not mention the streak (NFR-18).

### Story 3.1: Erev planned view with live controls

As a child learner,
I want to see on erev what is planned for shabbos or yom tov, and still be able to record anything before the lock,
So that I can learn ahead or record what I learnt today before the app locks, without anything being frozen early.

**Requirements:** FR-24 (as amended by dev #10), FR-23 interaction (dev #2), AD-36, AD-41, AD-49 (planner); NFR-6, NFR-8; UX-DR-34, UX-DR-55, UX-DR-98, UX-DR-107, UX-DR-128, UX-DR-129, UX-DR-130, UX-DR-151 (erev step), UX-DR-156, UX-DR-159, UX-DR-161, UX-DR-164, UX-DR-165; screen #09

**Acceptance Criteria:**

**Given** a learner whose next lock window `L` (from `lockWindows`, learner's `time_zone` in force) starts today at 18:12 learner-local
**When** the Learn tab is opened at any time from the start of the erev window (A-1) until `L.start`
**Then** the tab shows, in order, the erev banner (blue-soft, `{rounded.card}`, English/Hebrew label per the Hebrew Terms setting, and the lock start time from `lockWindows`), today's main-track tasks unchanged, one "Planned for {day}" section per locked day of `L`, then the "Also learning" rows
**And** before the erev window and from `L.start` onward the banner and planned sections are absent.

**Given** the erev view is showing
**When** the planned sections render
**Then** each section's rows are exactly the planner's task list for that locked date (AD-49), evaluated live over the current `LearnerState`, including `reviewsDue` chazara tasks and, for calendar-program curricula, `programAssignments(date)`
**And** the view computes no quantity of its own, and there is no frozen snapshot: ticking a planned row recomputes every planned section and today's list on the same screen in under one second (NFR-5).

**Given** the erev view is showing
**When** the child ticks a planned row, taps +1, or uses *Up to…* on a planned section or a sub-track row
**Then** `LearningCommands` writes ordinary `dated` events with `learned_on` = today and `recorded_at` = now, with `pts_` attached to `source = main` events per AD-50
**And** the controls look and behave exactly like the live main-track and sub-track rows, with the standard undo snackbar (UX-DR-154).

**Given** a chained lock (diaspora yom tov on Thursday and Friday followed by shabbos)
**When** the erev view shows on Wednesday
**Then** there are three planned sections, one each for Thursday, Friday and Shabbos, laid out in sequence so no leaf appears in two sections
**And** no erev view appears on Thursday or Friday, because there is no unlocked time between the yom tov and shabbos.

**Given** the same calendar week for a learner with `in_israel = true`
**When** the erev view shows
**Then** the sections follow the Israel `lockedDays` (one-day yom tov), so a yom tov Thursday followed by shabbos gives a non-chained pattern with its own erev on Friday
**And** changing `in_israel` before `L.start` changes the sections live, while the settings in force at `L.start` decide the lock itself (AD-37).

**Given** the learner has no location, so the fail-closed fallback applies (Fri 12:00 to Sun 01:00 learner-local)
**When** the erev view shows on Friday morning
**Then** the banner shows the fallback start time (12:00), taken from the same `lockWindows` output that drives the overlay
**And** the banner never shows a later time than the overlay actually uses.

**Given** nothing is planned for any locked day (for example, no main-track study day and no reviews due)
**When** the erev view shows
**Then** the banner shows without any planned section (UX-DR-128).

**Given** the child has the Up-to picker open on erev
**When** `L.start` passes before he taps Record
**Then** `CaptureGate` refuses the write, no event is written, and the overlay covers the app with back navigation blocked
**And** after the lock nothing from the abandoned picker is replayed.

**Given** an owner device whose clock or offline queue produces an event whose `effectiveAt` falls inside `L`
**When** it syncs
**Then** the event is stored, not rejected (dev #2), the engine ignores it in every derived number, history labels it "kept, not counted — recorded during Shabbos/Yom Tov", and no undo is offered for it
**And** the Learn tab shows the snackbar "Some learning was kept, not counted — it was recorded during Shabbos." (UX-DR-107, copy draft).

**Given** the erev view data is loading or fails to load
**When** the Learn tab renders
**Then** the planned sections use the Learn inline `InlineAsyncError` with retry, and today's main-track tasks are unaffected (UX-DR-129).

**Given** a screen-reader user opens the Learn tab on erev
**When** focus moves past the app bar
**Then** the erev banner is the first focusable element and announces the lock start time (UX-DR-159)
**And** planned rows meet the 48dp target, scale text without clipping Hebrew, mirror in RTL, follow dark-mode tokens, and use the Learn tablet composition on tablets (there is no tablet or dark mock for #09).

### Story 3.2: Catch-up card availability, contents and stacking

As a child learner,
I want one catch-up card after each shabbos or yom tov that shows what was planned for those days and stays until the end of the next full weekday,
So that I can record my shabbos learning at a convenient time after the lock, without being rushed.

**Requirements:** FR-25, FR-6b, AD-35, AD-36, AD-40, AD-41; NFR-18; UX-DR-37 (card shell), UX-DR-57, UX-DR-100, UX-DR-131, UX-DR-132, UX-DR-151, UX-DR-167; screen #10

**Acceptance Criteria:**

**Given** a lock `L` has ended (`now ≥ L.end`)
**When** the domain layer derives pending cards from `lockedDays(L)` and `catchUpWindow(L)` in `lib/domain/learner_state/` (the only definitions, AD-40)
**Then** a card exists for `L` from `L.end` until the end of `catchUpWindow(L)`, unless it is already complete (A-5)
**And** no surface, scheduler or command computes locked days or the window any other way.

**Given** a regular shabbos lock ending Saturday night at tzeis + 10 min
**When** the learner opens the Learn tab on Saturday night or at any time on Sunday
**Then** the card sits at the top of the Learn tab with a calendar icon, the question "Shabbos · {n} mishnayos planned — learnt them all?", the caption "Available until the end of Sunday", *Yes, all of it* (primary pill) and *Adjust…* (outlined pill)
**And** at 00:00 Monday learner-local the card is gone.

**Given** the no-location fallback lock (Fri 12:00 to Sun 01:00)
**When** the card is derived
**Then** `lockedDays` is {Saturday} only, because Friday is the day the lock starts and Sunday is not `isAssurBemelacha`
**And** the window runs to the end of Monday, because Sunday contains a locked instant (00:00–01:00).

**Given** a diaspora two-day yom tov on Thursday and Friday chained into shabbos
**When** the lock ends Saturday night
**Then** one card covers three locked days (Thursday, Friday, Shabbos), titled with the combined day label (A-2)
**And** an Israel learner with the same dates gets `lockedDays` per their one-day yom tov.

**Given** an inconsistent setting history that would yield more than three consecutive locked days for one lock
**When** the card is derived
**Then** it covers no more than three, the three latest locked days (assumption, flagged as a gap)
**And** the derivation never throws or shows an empty card.

**Given** card A's window is still open and a new lock B begins before the first fully unlocked civil day after A (for example, shabbos then a yom tov starting Sunday evening)
**When** time passes through B
**Then** A's window pauses during B (it counts only non-locked time) and resumes after `B.end`
**And** after `B.end` both A and B are pending, stacked oldest first (A-4), each with its own window and caption, and B's planned lists continue after A's.

**Given** a card is pending
**When** its contents are built for each locked day D
**Then** per evaluated curriculum it lists the main-track planner task list for D (AD-49, the same function as Story 3.1), and for each sub-track where `onHome(s, D)` and `learns_on_shabbos` is true, its planned amount (A-3) from that track's position
**And** a sub-track with `learns_on_shabbos = false`, an ended sub-track, a future-start sub-track and a groundless sub-track never appear.

**Given** a parent turns `learns_on_shabbos` on or off for a sub-track while a card is pending
**When** the Learn tab rebuilds
**Then** the card's sub-track groups follow the current flag live.

**Given** nothing is planned on the main track for any locked day and no `onHome` sub-track is flagged
**When** the lock ends
**Then** no card is shown (UX-DR-131) and no streak or pressure copy appears in its place.

**Given** a card is pending
**When** a Record action from this card or from another device on the same profile writes counted `catch_up` events for `L`
**Then** the card disappears on every device once those events are in `LearnerState` (A-5)
**And** if those events are all voided (undo) while the window is open, the card returns.

**Given** the card fails to load its contents
**When** the Learn tab renders
**Then** the card shows an inline error with retry and stays available until its window ends (UX-DR-132).

**Given** the learner is viewed on a tutor device
**When** a lock has ended
**Then** this epic shows no catch-up card there, because the catch-up card is owner-only; tutor learning writes go online through `TutorWriteService` (Epic 1 Story 1.24), and no later epic adds a tutor catch-up card
**And** a multi-learner owner device shows each profile's own cards only when that profile is in view.

### Story 3.3: One-tap catch-up keeps the streak

As a child learner,
I want to tap *Yes, all of it* and have my shabbos learning recorded on the days I learnt it,
So that my record and streak are honest and intact with one tap.

**Requirements:** FR-25, FR-16 (locked-day clause, dev #13), FR-14, AD-31, AD-36, AD-40, AD-41, AD-47, AD-50, AD-54 (chunking, skew); NFR-1, NFR-14, NFR-15, NFR-17, NFR-18; UX-DR-37, UX-DR-133, UX-DR-151, UX-DR-154; screen #10

**Acceptance Criteria:**

**Given** a pending card for lock `L` with locked days D1..Dk (k ≤ 3)
**When** the child taps *Yes, all of it*
**Then** `LearningCommands` writes one `learn` event per listed leaf with `date_state = catch_up`, `learned_on` = the locked day the leaf is listed under, `source` = `main` or the sub-track ULID, `stage` on main-track events per the planner task, `recorded_at` = now, and `actor` per the session role
**And** every `source = main` event carries its `pts_{eventId}` entry in the same batch, chunked at ≤ 450 writes with each event and its `pts_` entry together (AD-50, AD-54).

**Given** the events from *Yes, all of it* are counted
**When** the engine recomputes
**Then** for each curriculum every Di that received a counted `source = main` `catch_up` event is a streak day under `streakDay`, so the streak runs unbroken across the lock
**And** sub-track `catch_up` events add to the learnt count, tri-state fill, siyum and projection on `learned_on`, but never keep the streak (FR-16).

**Given** a pending card
**When** the child records it at 23:59 on the last day of its window
**Then** the events count on their locked days for the streak
**And** a `catch_up` event whose `effectiveAt` falls after the window (for example, a stale screen confirmed at 00:01) is refused by `LearningCommands` with "This catch-up has ended — you can still tick learning in Browse." (copy draft). The card then disappears, and nothing is written as `catch_up`.

**Given** a card expired without being recorded
**When** the learner later ticks the same mishnayos through the corpus browser with a past date
**Then** they are `dated` events, which count for progress but never fill the locked-day streak gap (AD-40, dev #8)
**And** no screen, banner or notification tells the child that the streak was lost on a locked day (NFR-18).

**Given** the device is offline after the lock
**When** the child taps *Yes, all of it*
**Then** the events are written to the offline queue at once, the card disappears, and progress and streak update locally
**And** when the device syncs after the window has ended, the events still count, because `effectiveAt` (the tap time) is inside the window.

**Given** the child and a parent both record the same card on two offline devices of the same profile
**When** both sync
**Then** all events are kept (NFR-1), distinct-learnt progress counts each leaf once (FR-14), and points follow `earningEventIds` (earliest event only), so nothing is double-counted.

**Given** *Yes, all of it* succeeded
**When** the undo snackbar's Undo is tapped
**Then** every event of that action is voided in one action, the card returns while its window is open, and streak, points and progress recompute (UX-DR-154).

**Given** the write fails (for example, a validation failure or a rejected chunk)
**When** the error returns
**Then** the card stays, nothing partial remains counted, and the card shows "Couldn't save — try again before the card expires." (UX-DR-133, copy draft).

**Given** a catch-up record succeeds
**When** `LearningCommands` emits analytics through `LearningAnalytics`
**Then** exactly one `catchup_completed` event is sent per card action, with only enums and counts: `curriculum_id`, `mode` (`all` | `adjusted`), `locked_days_offered`, `locked_days_recorded`, `event_count`, `within_window` (true)
**And** `tool/check_analytics_catalog.dart` passes with the event registered in `AnalyticsEvent`, and no ref, name or date is in the payload (AD-47).

**Given** the on-track status was frozen during the lock (Story 2.3)
**When** the catch-up is recorded
**Then** the parent's status and projection recompute from the catch-up events counted on their locked days, and the child sees only encouragement (FR-18, NFR-9).

### Story 3.4: Adjust… per locked day with Up to… and individual ticks

As a child learner,
I want to adjust what I actually learnt on each locked day before recording,
So that the catch-up records only learning that really happened.

**Requirements:** FR-25, FR-2a (catch-up variant), FR-6b; NFR-15, NFR-18; UX-DR-18, UX-DR-37, UX-DR-47, UX-DR-72, UX-DR-108, UX-DR-109, UX-DR-155, UX-DR-156, UX-DR-157, UX-DR-160, UX-DR-161, UX-DR-163, UX-DR-164, UX-DR-165, UX-DR-166; screen #10

**Acceptance Criteria:**

**Given** a pending card
**When** the child taps *Adjust…*
**Then** the card expands in place (no new route) into one section per locked day (up to three), each with per-source groups ("Home · Main track", "{name} (learns on shabbos)"), every planned row ticked by default, and a *Record {n} mishnayos* pill whose count is live
**And** collapsing the panel discards the adjustments without writing anything.

**Given** the Adjust panel is open
**When** the child taps *Up to…* on a group
**Then** the shared Up-to picker (Epic 2) opens for that group and day, starting at its first planned leaf, and allows including through a later leaf of that track's order and individual untick/retick
**And** confirming returns the selection to the panel. It does not write until *Record*.

**Given** the child unticks Beitzah 3:3 in the Rebbe group on Shabbos and taps *Record 13 mishnayos*
**When** the write completes
**Then** exactly 13 `catch_up` events are written, each with `learned_on` = the day of the section it was ticked in, and none for Beitzah 3:3
**And** the sub-track position stays at Beitzah 3:3 (first unticked), and `catchup_completed` is emitted with `mode = adjusted`.

**Given** the child unticks every row of every section
**When** he looks at the Record pill
**Then** it is disabled with the count 0 and stays visible and announced as disabled
**And** the card stays pending (recording nothing is not a completion).

**Given** the same leaf would be included in two different day sections through *Up to…*
**When** the selection is applied
**Then** a leaf appears in at most one section, the earliest, so there are no duplicate events across days.

**Given** a flagged sub-track has no further leaves in its ground
**When** its group renders
**Then** it shows "No more mishnayos in this track's ground" (UX-DR-108), and *Up to…* is disabled.

**Given** the Adjust panel's data fails to load
**When** it renders
**Then** it shows inline retry and disables Record (UX-DR-109), and the card stays available.

**Given** a screen-reader or large-text user
**When** they use the Adjust panel
**Then** each row announces its ref and included/skipped state, sections announce their day, the Record label carries the live count, targets are ≥ 48dp, Hebrew marks never clip, layout mirrors in RTL, focus moves to the picker title on open and back to the *Up to…* trigger on close, and platform back dismisses the picker without recording
**And** on tablet the picker is a centered dialog and the card follows the #10 tablet composition. Dark mode follows the #10 dark mock tokens.

### Story 3.5: Catch-up reminder notification

As a child learner (and the parent who set up the device),
I want one gentle notification when the catch-up card becomes available,
So that I remember to record my shabbos learning before the window closes, without being nagged.

**Requirements:** FR-25 (reminder), AD-36 (notification suppression), AD-40, AD-41, spine Consistency Conventions → Reminders; NFR-6, NFR-14, NFR-18; UX-DR-100, UX-DR-151 (step 3)

**Acceptance Criteria:**

**Given** an owner device with one or more learner profiles active on it
**When** the app starts, resumes, or a profile's `learnerSettings` change
**Then** the single `CatchUpReminderScheduler` in `lib/features/sacred_time/` derives each profile's upcoming locks from `lockWindows` (settings in force) and schedules one local notification per profile per lock at `L.end`
**And** no other component schedules catch-up reminders, and the scheduler computes no window of its own.

**Given** a chained yom tov + shabbos lock
**When** reminders are scheduled
**Then** exactly one notification is scheduled for that profile, at the end of the continuous lock, and never one per locked day.

**Given** a scheduled reminder fires at `L.end`
**When** the card for `L` would be empty (Story 3.2 empty rule) or is already complete
**Then** no notification is shown
**And** otherwise exactly one notification is shown for that card, and it is never repeated, snoozed or re-sent before expiry.

**Given** stacked cards A and B (A paused across lock B)
**When** B ends
**Then** only B's reminder fires. A's reminder already fired at `A.end`, and none fires again when A resumes.

**Given** the device is a tutor device (tutor session or tutor account)
**When** the app runs
**Then** `CatchUpReminderScheduler` is never started and schedules nothing, even for learners the tutor can view.

**Given** a learner's settings change during the week (location, `time_zone` or `in_israel`)
**When** the scheduler reruns
**Then** pending reminders are cancelled and rescheduled to the new `lockWindows` output
**And** a profile removed from the device has its reminders cancelled.

**Given** the device is offline, rebooted, or the app was not opened during the lock
**When** `L.end` arrives
**Then** the reminder still fires from the local schedule (rescheduled on boot or app start). If the device was off at `L.end`, no late duplicate is sent after it boots.

**Given** notification permission is denied or not yet granted
**When** a lock ends
**Then** the card still appears normally, and the app does not prompt for permission during or because of the lock.

**Given** the reminder is shown
**When** the user reads it
**Then** its copy is neutral and forward-looking, for example "Shabbos is over — record what you learnt?" (A-6, copy open), never mentions the streak, losing anything or being behind, and carries no learner data beyond the profile's display name
**And** tapping it opens the Learn tab of that profile through the existing profile/PIN routing, with the card at the top.

**Given** the card is pending
**When** the streak-at-risk alert would fire for a curriculum whose only gap is a locked day still inside its catch-up window
**Then** that alert is suppressed, so the child gets one catch-up reminder, not a streak-pressure alert (NFR-18).

## Epic 4: Rebbe on their own phone, with parent history and undo

A tutor whom the parent has granted `can_edit_learning` (Epic 1 Story 1.25) keeps a talmid's sub-tracks, main track and deadline accurate from his own phone, using the same Manage tracks, sub-track and ground-picker screens the parent uses; his learning capture and correction already work from Epic 1 (Stories 1.23–1.24). He works online only, and every change goes through `TutorWriteService` → callable → `writeWithChangeLog`. He sees all his talmidim with their on-track status in one list. The parent sees every change (governed-entity changes and learning events) with who, what and when. The parent can undo any action field by field (an undo is final), gets a push when a tutor changes the goal or the main track, and can revoke access at any time.

**FRs covered:** FR-26, FR-27, FR-28, FR-29
**NFRs:** NFR-2, NFR-4 (parent/tutor surface), NFR-11 · **ARs:** AR-6 (tutor sub-track half), AR-11 (FR-29 half), AR-16, AR-18 (AR-20 is delivered in Epic 1 Story 1.25)
**Binding decisions:** AD-36 (tutor lock behaviour), AD-38 (change log, callable contract, undo), AD-39 (push), AD-46, AD-47, AD-53, AD-54 (perf gate, observability); `prd-deviations` #3, #7, #9.
**Depends on:** Epic 1 (`change_log` with `reverts_action_id`, owner governed writes, data-level undo primitives, `writeWithChangeLog`, `ownerOversizedGovernedWrite`, the 10 rerouted tutor callables, `tutorRecordLearning`/`tutorVoidLearning`/`tutorUnlearn` behind `TutorWriteService`, `updateTutorGrantPermissions` and the invite checkbox, rules, `LearnerStateEngine`, `CaptureGate`, `LearningAnalytics`). Epic 2 (sub-track UI, capture, ground picker, forecast and on-track surfaces for owners). Epic 3 (erev/catch-up; the catch-up card is not offered on tutor devices: the `CatchUpReminderScheduler` never runs there).
**Release precondition (bead, not a story):** the privacy-policy update disclosing parent-granted tutor read/edit access and the parent-visible change history (`learning-tracker-bpo`, NFR-11, AR-18, PRD §4.10) must be closed before this epic's app release ships. The GA4 under-13 check (`learning-tracker-h3f`) stays a precondition, as in Epic 1.

### Story 4.1: Tutor sub-track callable and sub-track learning source

As a tutor (rebbe),
I want server-checked calls that create and maintain my sub-track for a talmid and record learning against it,
So that every tutor sub-track change is authorized by the parent's grant and logged like the parent's own.

**Requirements:** FR-26 (sub-tracks), FR-28 (write side), NFR-4; AR-6 (tutor sub-track half); AD-38 (callable contract, entity mapping, idempotency), AD-45, AD-46, AD-47, AD-50, AD-52, AD-53, AD-54

**Acceptance Criteria:**

**Given** `writeWithChangeLog` and the Epic 2 sub-track validation fixtures (`test/fixtures/sub_track_limits/*.json`)
**When** this story lands
**Then** a new callable `tutorUpsertSubTrack` in `functions/src/tutor_learning.ts` covers the `subTrack` entity (create, edit any field, ground add/reorder/remove, *Add next year*, end, tombstone delete), writes only through `writeWithChangeLog` with no permission check of its own (AD-53), and is exported from `functions/src/index.ts`, covered by `make test-functions` and included in the gated deploy job
**And** `tutorRecordLearning` (Story 1.23) accepts a sub-track ULID as `source`
**And** `TutorWriteService` gains `createSubTrack`, `editSubTrack`, `endSubTrack` and `deleteSubTrack`, and emits the already-registered `subtrack_lifecycle` event through `LearningAnalytics` after success (AD-47); `tool/check_analytics_catalog.dart` passes.

**Given** a tutor with `can_edit_learning == true`, online
**When** he records "Up to Beitzah 3:4" on his Rebbe row from position 3:1 with 3:3 unticked
**Then** one `tutorRecordLearning` transaction writes `learn` events for 3:1, 3:2 and 3:4 only, each with `source` = the sub-track ULID, `date_state = dated`, server-derived tutor `actor` and server-stamped `recorded_at`, and no `pts_` entry (AD-50).

**Given** a caller with no active grant, `can_edit_learning` false or absent, or a grant for another profile
**When** `tutorUpsertSubTrack` is invoked
**Then** it fails with `permission-denied`, writes nothing, and logs `{entity, code}` with no learner data
**And** emulator tests cover these rejections plus an AD-52 whitelist violation, an AD-45 limit (a sixth active ongoing sub-track; a sub-track on a calendar-program curriculum) and idempotent replay of a create ULID, and every limit fixture agrees with the Dart suite.

**Given** the tutor and the parent edit different fields of the same sub-track, or the same field (e.g. `rate_per_week`), at about the same time
**When** both writes commit
**Then** different fields both keep their values, the same field takes the later server commit (LWW, NFR-4), and each write has its own `change_log` entry.

### Story 4.2: Tutor-mode track editing and sub-track capture

As a tutor (rebbe),
I want to open a talmid and use the same Manage tracks, sub-track forms, ground picker and main-track settings the parent uses,
So that I can keep my own track, his deadline and his main track correct without asking the parent to do it.

**Requirements:** FR-26, FR-28 (write side), NFR-2, NFR-4; UJ-2; AR-6 (tutor sub-track half); AD-36, AD-53; UX-DR-36, UX-DR-38, UX-DR-48, UX-DR-50, UX-DR-54, UX-DR-68, UX-DR-69 (tutor strings), UX-DR-75, UX-DR-83, UX-DR-85, UX-DR-88, UX-DR-97, UX-DR-101, UX-DR-120, UX-DR-149, UX-DR-158; dev #3; screens #04–#08, #11, #13

**Acceptance Criteria:**

**Given** the Epic 2 tutor-session read-only state (Story 2.9) and the Story 4.1 callables
**When** this story lands and a tutor with `can_edit_learning == true` is online
**Then** the sub-track write controls on tutor devices (*+1*, *Up to…*, *Add ground*, *Add sub-track*, edit, reorder, remove, end, delete, *Add next year*) are enabled and call `TutorWriteService`, and the "coming soon" note is removed
**And** the Browse free-tick source sheet and Mishna-history *Correct source* on a tutor device list the learner's `onHome` sub-tracks (Story 2.10), written through `TutorWriteService.recordLearning` / `replaceLearning`.

**Given** a tutor in tutor mode viewing a learner whose grant has `can_edit_learning == true`, online
**When** he opens Settings → Manage tracks
**Then** the tutor-mode bar reads "Tutor mode · {tutor name}" with *Switch* on every surface (UX-DR-38)
**And** he can create, edit, end and delete school-year and ongoing sub-tracks, use *Add next year*, add, reorder and remove ground, and edit the main track's order, study days, stages, scope and program and the deadline goal, using the Epic 2 and existing screens
**And** every save calls `TutorWriteService` (never `LearningCommands` or a direct Firestore write), and the change appears only after the callable succeeds.

**Given** the tutor saves a new ongoing "Rebbe" sub-track (5 per week) with no ground
**When** the callable succeeds
**Then** the hub and the learner's Learn tab show the groundless Rebbe row with *Add ground* for the tutor (UX-DR-88)
**And** after he adds Beitzah through the ground picker, the main track's schedule and daily target recompute on his device within one second (NFR-5).

**Given** the tutor saves a form or a ground change
**When** the callable is in flight
**Then** the primary action shows a progress state and is disabled, and form values are kept
**And** on failure the values are retained and the retryable error snackbar is shown (UX-DR-120); nothing is shown as saved.

**Given** a tutor whose grant has `can_edit_learning` false
**When** he opens the learner's Manage tracks, a sub-track, the ground picker entry points or a sub-track row
**Then** he can read what the grant's view permissions allow, every edit and capture control is visible but disabled (40% opacity, disabled semantics), and one note says "{learner}'s parent hasn't given you editing access".

**Given** the tutor device goes offline while a tutor surface is open
**When** connectivity is lost
**Then** every tutor write control on these surfaces (Save, ground actions, reorder, *+1*, *Up to…*) is disabled with "Online required" and re-enables when connectivity returns, with nothing queued.

**Given** the tutor views the learner's Dashboard
**When** it renders
**Then** he sees the on-track card, projection, daily target and shortfall warning that the parent sees (UX-DR-48, UX-DR-97)
**And** he does not see Change history or Undo for that learner (parent-only)
**And** when a lock starts for that learner, that learner's screens on the tutor device are covered (Story 1.24 behaviour).

### Story 4.3: My talmidim — every granted learner with on-track status

As a tutor (rebbe),
I want one list of all the talmidim whose parents gave me access, each with its status and my track's next position,
So that I can see everyone's standing at a glance and open any one of them.

**Requirements:** FR-29, FR-28 (list side), AR-11 (FR-29 half); AD-35, AD-36, AD-53, AD-54 perf gate; UX-DR-9, UX-DR-24, UX-DR-39, UX-DR-58, UX-DR-68, UX-DR-69, UX-DR-83, UX-DR-94, UX-DR-134, UX-DR-135, UX-DR-136, UX-DR-149, UX-DR-156, UX-DR-157, UX-DR-160, UX-DR-162, UX-DR-164, UX-DR-165; screen #11

**Acceptance Criteria:**

**Given** a signed-in tutor with three active grants and one revoked grant
**When** he opens My talmidim in tutor mode
**Then** exactly three talmid rows are shown, each an outlined card with initials avatar, name, status chip, a detail line ("Rebbe: next Beitzah 3:1"), and a chevron (UX-DR-39)
**And** the list ends with the info note "You see only learners whose parents gave you access."
**And** the list follows the live set of active grants (AD-53)

**Given** a talmid's `LearnerState`
**When** his row renders
**Then** the status chip shows *On track*, *Behind pace* or *Too early to tell* using the same engine output and rules as the on-track card (under 2 weeks of history → *Too early to tell*), as text and colour (UX-DR-24, UX-DR-94, UX-DR-157)
**And** a learner with no deadline shows no status chip, only the detail line (FR-20)

**Given** the tutor's sub-track for a talmid has no ground
**When** the row renders
**Then** it reads "Rebbe: no ground yet" with an *Add ground* action that deep-links to that learner's ground picker for that sub-track (UX-DR-83)
**And** *Add ground* is disabled if the grant lacks `can_edit_learning` or the device is offline

**Given** a talmid whose lock window is active
**When** the list renders
**Then** that row shows "Shabbos / Yom Tov" with no status, position or actions, and tapping it opens nothing
**And** the other rows stay live, and the tutor device's own overlay is not triggered by that learner (AD-36)

**Given** a talmid row
**When** the tutor taps it
**Then** the learner's context opens through the existing tutor PIN gate where one is configured (UX-DR-83)

**Given** the tutor has no active grants
**When** the list loads
**Then** it shows "No talmidim yet — a parent needs to give you access." (UX-DR-134)
**And** a load failure shows `AppErrorView` with retry (UX-DR-135)

**Given** 20 talmidim, each with 40,000 leaf events and 200 node events, on a mid-range tutor device within the 20 MiB cache, with a warm in-memory log
**When** the list is rendered and each row's status is computed
**Then** the engine runs per learner, only for rows that are on screen or about to scroll on, and rendering each learner's FR-29 row (status plus FR-19 target) takes under 1 s per learner at 20 learners × 40,000 events in the AD-54 benchmark (`test/benchmark/talmidim_list_benchmark_test.dart`), which runs in CI as a gate for this epic's release
**And** the cold first load is measured and recorded but not gated
**And** a learner whose engine load times out shows an inline retry on that row only, and logs a Crashlytics non-fatal with enums only

**Given** a tablet at ≥840dp
**When** My talmidim is open
**Then** the list (5 columns) sits beside the selected learner (7 columns), and the selection is kept as the list updates (UX-DR-162–164)

### Story 4.4: Revoking a tutor ends access at once and keeps his work

As a parent,
I want revoking a tutor to stop his access straight away while keeping every track and learning record he made,
So that I stay in control without losing my child's history.

**Requirements:** FR-28, FR-29; AD-38 (callable contract), AD-46, AD-53; UX-DR-65, UX-DR-83, UX-DR-136

**Acceptance Criteria:**

**Given** a parent on the existing Manage tutors screen
**When** they revoke a tutor and confirm in the existing dialog
**Then** the existing `revokeTutorGrant` flow runs unchanged (UX-DR-65)
**And** sub-tracks the tutor created, the ground he assigned, his `learning_events` and his `change_log` entries all remain unchanged and keep counting

**Given** the grant has been revoked
**When** the tutor's next callable for that learner arrives
**Then** `writeWithChangeLog` rejects it with `permission-denied` and writes nothing, because the grant is checked on every call (AD-53)
**And** this holds when the tutor device has not yet seen the revocation

**Given** the grant has been revoked
**When** the tutor's device next reads any of that learner's documents (`learning_events`, `sub_tracks`, `change_log`, governed docs, profile)
**Then** rules deny the read (rules emulator test per collection)

**Given** the tutor has the revoked learner open in a form, picker or Learn tab (revoked mid-session)
**When** the listener reports `permission-denied` or a write callable is rejected for revocation
**Then** the tutor sees "Access to {name} has ended." (UX-DR-136), any unsaved form input is discarded, and the app returns to My talmidim
**And** the learner's row is gone on the next update of the list, without a restart
**And** no data from that learner stays visible on the device

**Given** the tutor is offline when the parent revokes
**When** he reconnects
**Then** the learner disappears from My talmidim on that sync
**And** no write can have been made in between, because tutor writes are online-only

**Given** the parent revokes and later invites the same tutor again
**When** the new grant is accepted
**Then** the tutor's earlier tracks and events show again under the new grant, and `can_edit_learning` follows the new invite's checkbox (Story 1.25)

### Story 4.5: Parent Change history across tutors, parent and learning

As a parent,
I want one history of every change to my child's tracks, goals and learning, showing who did what and when,
So that I can see exactly what a rebbe (or anyone) changed and spot mistakes.

**Requirements:** FR-27, FR-4 (voided events visible to the parent), NFR-4; AD-36 (lock-ignored label), AD-38 (History), AD-39 (bell), AD-54 (no new indexes); UX-DR-40, UX-DR-59, UX-DR-69 (history strings), UX-DR-137, UX-DR-138, UX-DR-156, UX-DR-157, UX-DR-160, UX-DR-162–UX-DR-165; screen #12

**Acceptance Criteria:**

**Given** the account is in the parent role (PIN session unlocked)
**When** the parent opens Settings → Change history for a learner
**Then** a new parent-scoped timeline loads that covers the parent, the child and every tutor; it is not the per-grant `/tutor/audit-log`
**And** the screen is not reachable in the child role or from a tutor device (EXPERIENCE role matrix)

**Given** the learner has 250 `change_log` entries and 400 `learning_events`
**When** the history loads and the parent scrolls
**Then** both collections are read 100 at a time, newest first by `at` / `effectiveAt`, merged on the client, and the next page of each source is fetched only when the merged list reaches its end (AD-38)
**And** no new Firestore index is added (AD-54)
**And** `change_log` entries that share an `action_id` render as one row (e.g. "Remove track" with its sub-track tombstones)

**Given** a history row
**When** it renders
**Then** it shows the actor's avatar and display name, role (Parent / Child / Tutor), time, and a plain-language action built from the entity and the changed fields, e.g. "Rav Cohen · Tutor · 4:10 pm — Added ביצה פרק ד׳ (Beitzah perek 4) to Rebbe track" or "Rav Cohen changed the deadline · 3 Nov"
**And** rows are grouped under day headers in the learner's time zone (AD-41)
**And** learning-event rows show the source name at event time, the refs or range, and the date state; voided events and their voids are shown with who and when

**Given** an action A for which some `change_log` entry has `reverts_action_id == A`
**When** history renders on any device
**Then** A's row shows *Undone*, and the undo's own row reads "Reverted change: …" and offers no Undo.

**Given** an entry with `actor.role == tutor` whose entity is push-eligible under AD-39 (`goal`, `mainTrack`, `mainTrackOrder`, `mainTrackProgram`, `mainTrackStudyDays`)
**When** it renders
**Then** it carries the bell icon; sub-track, stage, scope and learner-settings entries never do

**Given** a learning event whose `effectiveAt` falls inside a lock window computed with the settings in force at that instant
**When** it renders
**Then** it is labelled "kept, not counted — recorded during Shabbos/Yom Tov" and offers no Undo (AD-36)

**Given** a parent and a tutor changed the same field at about the same time
**When** history renders
**Then** both entries are listed with their actors and times, and the entity's current value reflects the later server commit (NFR-4)

**Given** the filter chips All · Tutor · Parent · Learning
**When** the parent picks one
**Then** Tutor shows governed changes by `role == tutor`, Parent shows governed changes by parent or child, Learning shows learning-event rows of any actor, and All shows everything; the filter is applied on the client to the loaded pages and keeps loading pages until the view is full

**Given** the learner has no changes and no events
**When** history opens
**Then** it shows "No changes yet." (UX-DR-137)
**And** a load failure shows `AppErrorView` with retry (UX-DR-138)

**Given** a tablet at ≥840dp
**When** Change history is open
**Then** the timeline and the selected change's details are shown side by side (UX-DR-164)

### Story 4.6: Field-level undo from Change history

As a parent,
I want to undo any change from the history, with fields that were changed again since left untouched and listed,
So that I can reverse a tutor's (or my own) mistake without wiping out later work.

**Requirements:** FR-27, FR-4, NFR-4; AD-31 (undo of learn/void/unlearn), AD-37 (no undo of a seed entry), AD-38 (Undo, undo is final, Batching), AD-52 (`reverts_action_id`), AD-54 (Recovery); UX-DR-84, UX-DR-139, UX-DR-154

**Acceptance Criteria:**

**Given** a history row for an action whose fields still hold its `after` values
**When** the parent taps *Undo*
**Then** one new action is written through `LearningCommands` (owner path): for each member entry and each field whose current value equals `after[f]`, it writes `before[f]` with a new `change_log` entry per entity, all sharing a new `action_id`, each carrying `reverts_action_id` = the undone action's id, with `actor.role = parent`
**And** a new "Reverted change: …" row appears, the original row shows *Undone* on this device and every other (derived from `reverts_action_id`, nothing stored locally), and Undo is no longer offered on the original row

**Given** a "Reverted change: …" row (its entries carry `reverts_action_id`)
**When** it renders
**Then** no Undo is offered (an undo is final), and `LearningCommands` rejects an undo of that action if one is attempted

**Given** a tutor changed the deadline from 1 Jul to 1 Jun, and later changed it again to 15 Jun
**When** the parent undoes the first change
**Then** `target_date` is not written, the result lists "Deadline — changed since by Rav Cohen", and any other eligible fields of that action are still reverted
**And** if no field of the action is eligible, nothing is written, the original row is not marked *Undone*, and the snackbar says "Nothing to undo — changed since"

**Given** a tutor created a "Rebbe" sub-track (undo of a create)
**When** the parent undoes that create and the sub-track's `last_change_id` still equals the create entry's id
**Then** the sub-track gets `ended_at` and `end_reason = undo`, it leaves Learn and the hub's active group, its unfinished ground returns to the main track (FR-12), and its learning events remain

**Given** the tutor created the sub-track and then added ground to it
**When** the parent undoes the create first
**Then** it reports "changed since by Rav Cohen" and writes nothing
**And** once the ground addition has been undone, undoing the create succeeds

**Given** a tutor's learning capture of 3 events (one action)
**When** the parent undoes it
**Then** each event still counted is voided (undo of learn = void), and position, counts, siyum and target recompute
**And** voids written by an undo carry `reverts_action_id` (the undone capture's first event id), so the capture row shows *Undone* on every device and neither the row nor those voids offer Undo
**And** undoing a void writes a new learn copy carrying `original_recorded_at = effectiveAt(target)`, and undoing an `unlearn` voids the re-issued events and re-copies the voided ones (AD-31)

**Given** a `learnerSettings` entry whose `before` is all null (seed) or a lock-ignored learning event
**When** its row renders
**Then** no Undo is offered

**Given** an undo that touches more than 10 governed docs (e.g. reverting a long reorder)
**When** the parent taps *Undo*
**Then** it goes online-only through `ownerOversizedGovernedWrite` (`writeWithChangeLog`), is disabled offline with "Online required", and is otherwise identical to the owner path, including `reverts_action_id`

**Given** the parent is offline and the undo fits within one owner batch
**When** they tap *Undo*
**Then** it is queued per AD-8 and shows as applied locally
**And** if it is permanently rejected on sync, the row rolls back and the snackbar says the undo couldn't be saved, with Retry (UX-DR-139, AD-54 Recovery)

**Given** the parent undoes a tutor change while the tutor saves a new value for the same field at about the same time
**When** both commit
**Then** the later server commit wins for that field, both actions appear in history, and the later reading of the earlier row shows the field as "changed since"

### Story 4.7: Parent push when a tutor changes the goal or main track

As a parent,
I want a notification on my phone when a tutor changes the deadline or the main track, and not for routine sub-track edits,
So that I know straight away about changes that move my child's daily target, without being spammed or alerting my child.

**Requirements:** FR-27, AR-16; AD-39, AD-54 (observability); `prd-deviations` #9; UX-DR-40 (bell)

**Acceptance Criteria:**

**Given** `onChangeLogCreated` in a new `functions/src/notifications.ts`
**When** a `change_log` entry is created with `actor.role == tutor` and `entity ∈ {goal, mainTrack, mainTrackOrder, mainTrackProgram, mainTrackStudyDays}`
**Then** it sends one FCM message to every token in the owning account's `users/{uid}.fcm_tokens`
**And** the message names the tutor and the kind of change (e.g. "Rav Cohen changed Yehuda's deadline"), and tapping it opens that learner's Change history behind the parent PIN gate

**Given** a tutor action that writes several push-eligible entries sharing one `action_id` (e.g. add track: `mainTrack` + `mainTrackOrder`)
**When** the trigger fires for each entry
**Then** exactly one push is sent, for the push-eligible entry with the smallest id in that `action_id`, and the trigger is idempotent on retry

**Given** an entry by `role` parent or child, or a tutor entry for `subTrack`, `mainTrackStages`, `mainTrackScope` or `learnerSettings`
**When** it is created
**Then** no push is sent, and the entry still appears in history (`prd-deviations` #9)

**Given** a device where the parent unlocks the PIN session (`pin_flow_controller`)
**When** unlock succeeds and notification permission is granted
**Then** the device's FCM token is written to `fcm_tokens[installId] = {token, updated_at}`
**And** on PIN lock or timeout (`pin_guard`) that entry is deleted, so a device left in child role receives no parent push

**Given** a shared family device whose PIN session timed out offline
**When** a tutor change triggers a push before the token deletion has synced
**Then** the device suppresses the notification when it arrives while in child role, so the push never reaches the child

**Given** iOS
**When** registration runs
**Then** the APNs key and push capability are configured, `getAPNSToken()` is awaited before other messaging calls, and `requestPermission()` is called; on Android 13+ `requestPermission()` is called
**And** if permission is denied, no token is stored, nothing else changes, and history still works

**Given** an FCM send that fails with an unregistered or invalid token
**When** the trigger handles the response
**Then** that token is removed from `fcm_tokens`, and a structured log with the error code and no learner data is written (AD-54)

**Given** a tutor device that is also a parent account
**When** the tutor makes changes to a granted learner
**Then** pushes go only to the learner's owning account, never to the tutor's own tokens

**Given** this epic adds `tutorUpsertSubTrack`, the `tutorRecordLearning` sub-track source and the `onChangeLogCreated` trigger
**When** the epic's app release is cut
**Then** the AD-54 gated CI deploy (`firebase deploy --only firestore:rules,firestore:indexes,functions`) runs with the rules and functions test jobs and must pass before the app release job; the app release fails if it did not.

## Epic 5: Lifetime record and reports

The parent sees a lifetime record of everything the learner has learnt, in each curriculum and from every source. The record keeps going after the goal is reached. The parent also sees how fast each source moves and whether the learner is on track, and can export both reports as a PDF with correct Hebrew and share it. All report numbers come from the engine's `LearnerState` (AD-35, AD-48). No report computes totals of its own.

**FRs covered:** FR-31, FR-32 · **ARs:** AR-19 (AR-3 stack bump and AR-11 perf gate inherited from Epic 1) · **Depends on:** Epic 1 cutover release (engine, `effectiveAt`, velocity, FR-30 mishna history); Epic 2 (sub-tracks with `name`, `type`, `academic_year`, `ended_at`/`end_reason`; on-track status and shortfall)

**Scope rules applied to every story in this epic**

- **Per curriculum.** Each report covers one curriculum. The parent picks it with the curriculum switcher already used on the Progress tab. Lifetime totals include every curriculum that has events, including those whose `curriculum_tracks.state` is `retired` or `archived` (AD-35 "events of every curriculum still count for lifetime"). Velocity and on-track status appear only for evaluated curricula (active, not ended).
- **Units.** Every count label uses the curriculum's own leaf unit ("mishnayos", "dapim", and so on), as deviation #12 requires. "Mishnayos" in the ACs below stands for that unit.
- **What counts.** An event counts only if it is in `LearnerState.countedEventIds`. Voided events, void events and lock-ignored events are never counted (AD-31, AD-36).
- **Who sees it.** The reports are for the parent only: the parent-PIN session (spine Roles row; UX-DR-61). The child and the tutor get no entry point (EXPERIENCE role matrix `[ASSUMPTION]`, open question 11).

---

### Story 5.1: Report projection in the engine

As a parent,
I want every lifetime and per-source number to come from the same engine that drives the rest of the app,
So that the report never disagrees with the dashboard, the mishna history or the goal progress.

**Requirements:** FR-31, FR-32; AR-19; AD-35, AD-48, AD-31 (`effectiveAt`), AD-40 (`learned_on` counting), AD-34; NFR-5; AR-11 (perf gate)

**Acceptance Criteria:**

**Given** the `LearnerStateEngine` in `lib/domain/learner_state/`
**When** it runs for a profile
**Then** `LearnerState` exposes a per-curriculum `report` projection with: distinct leaves learnt; total learning events; per-source totals (events and distinct leaves) keyed by `source` (`main` or sub-track ULID); a roll-up of sub-track groups; per-source velocity; and the on-track status already computed for FR-18/FR-21
**And** the projection is pure: no Firestore, Riverpod or Flutter imports (`tool/check_dependency_direction.dart` passes)
**And** no widget, provider or PDF builder computes a report total, count or velocity outside the engine (AD-48; review checklist plus a test that the PDF builder takes only the projection as input)

**Given** a curriculum with counted `dated`, `catch_up` and `before_tracking` events
**When** the projection is computed
**Then** "distinct leaves learnt" equals the size of that curriculum's engine learnt set (the same number as FR-14 goal progress and the lifetime tree)
**And** "total learning events" equals the sum, over every leaf, of the FR-30 mishna-history count for that leaf. A `before_tracking` node event counts once for each leaf it covers via `expandGround` (see gap G-3)

**Given** an event that was later voided, or an event whose `effectiveAt` falls inside a lock window computed with the settings in force at that instant
**When** the projection is computed
**Then** it is excluded from every total, per-source total and velocity figure
**And** voiding an event and then undoing the void (re-copy with `original_recorded_at`) restores the event's contribution to the day of its `effectiveAt`

**Given** the learner's goal is complete (all corpus leaves learnt, or the deadline has passed)
**When** new events are recorded
**Then** total learning events and per-source totals keep growing, and distinct leaves stays at its maximum without being capped or reset (FR-31 "recording continues")

**Given** sub-tracks on the same curriculum whose `name` values match after trimming and case-folding (e.g. "School" 2024, "School" 2025, "school " 2026)
**When** the projection builds the roll-up
**Then** they form one group, whose total is the sum of its members' event and distinct-leaf counts
**And** each `school_year` member gives one year line keyed by `academic_year`, labelled "YYYY–YY" (e.g. 2024 → "2024–25")
**And** each `ongoing` member with the same name gives one line labelled by its window (see gap G-5)
**And** a group's distinct count is the union of its members' leaves, not the sum, so a leaf learnt in two years counts once in the group total

**Given** a sub-track that was deleted (`end_reason = deleted` or `track_deleted`) or ended
**When** the projection is computed
**Then** its events remain in every total, and its group and year line are still listed under its stored `name` (the tombstoned doc keeps `name`)
**And** the line is marked "Ended" (never "completed" while unfinished ground remains; UX-DR-70)

**Given** a sub-track that was renamed after events were recorded
**When** the projection builds the roll-up
**Then** all of that sub-track's events are grouped under its current `name`. Events are never split between the old and new names (spine stores no name history for the report to read; see gap G-4)

**Given** a learner with no sub-tracks
**When** the projection is computed
**Then** the per-source totals contain only Home (`main`) and, if present, the Before-tracking bucket, and the roll-up is empty

**Given** per-source velocity for source S in an evaluated curriculum
**When** it is computed
**Then** it counts, per civil day `learned_on`, the distinct leaves whose first counted `dated` or `catch_up` event **from source S** falls on that day (see gap G-1)
**And** `before_tracking` events never contribute (FR-32)
**And** a `catch_up` event counts on its `learned_on` (the locked day learnt), not the civil date of `recorded_at` (FR-32; AD-40)
**And** the span runs from tracking start through today, or through `ended_at` for an ended or deleted sub-track. Tracking start is the curriculum's `tracking_start_date`, or the sub-track's `window_start` when that is later. Velocity is given as leaves per week, to one decimal place
**And** a trailing-28-day figure for each source uses the same AD-35 window rule (28 days; all history between 14 and 27 days; none under 14 days → "Too early to tell")
**And** the all-sources velocity equals the AD-35 projection velocity exactly, so the report and the dashboard projection always agree

**Given** a perf fixture of one learner with 40,000 leaf events and 200 node events, spread over 6 curricula and 15 sub-tracks (8 of them sharing one name)
**When** the engine runs with the report projection on a mid-range device profile
**Then** the full `LearnerState`, including the projection, completes within the AR-11/NFR-5 budget (< 1 s), and the projection adds ≤ 150 ms over the baseline benchmark
**And** golden-number unit tests cover: an empty profile, a single source, multiple sources, a void and a re-copy, a lock-ignored event, a catch-up crossing a week boundary, a before-tracking node event, a renamed track, a deleted track, and a retired curriculum

---

### Story 5.2: Lifetime report screen

As a parent,
I want to open a lifetime report showing everything my child has learnt, from every source and across school years,
So that I see the whole record, not only progress toward the current goal.

**Requirements:** FR-31; UJ-6; screen #14; UX-DR-12, UX-DR-15, UX-DR-21, UX-DR-43, UX-DR-61, UX-DR-69, UX-DR-70, UX-DR-102, UX-DR-143, UX-DR-144, UX-DR-153, UX-DR-156, UX-DR-157, UX-DR-161, UX-DR-162, UX-DR-164, UX-DR-165; AD-48

**Acceptance Criteria:**

**Given** the parent-PIN session is unlocked
**When** the parent opens Progress → Lifetime (`/progress/lifetime`) → Report
**Then** the Lifetime report screen opens for the curriculum currently in view, with the sections Distinct, Learning events, By source and School years (UX-DR-43, UX-DR-61); later stories in this epic add the Per-source pace section and the *Export PDF* pill
**And** the totals read "Distinct · {n} {unit}" and "Learning events · {n}" in `headline-small` stat numerals (UX-DR-12, UX-DR-69)
**And** the word "Reviews" appears nowhere on the screen (UX-DR-70)

**Given** a child session (PIN locked) or a tutor session
**When** the Progress → Lifetime surface is shown
**Then** there is no Report entry, and deep-linking to the report route redirects to Lifetime without showing any report data

**Given** the learner has events from Home, two sub-tracks and before-tracking backfill
**When** the By source section renders
**Then** it shows one row per source with a display-only source chip (UX-DR-21) and that source's event count and distinct count
**And** before-tracking events appear in their own "Before tracking" row with the gold-soft badge treatment
**And** the per-source event counts sum to the Learning events total

**Given** three school-year sub-tracks named "School" (2024, 2025, 2026, the last one active) and one ongoing "Rebbe" track
**When** the School years section renders
**Then** it shows one collapsed row "School · {group total} {unit}", which expands to "2024–25 · 210 {unit}", "2025–26 · …" and "2026–27 · In progress · 180" (UX-DR-43)
**And** expanding and collapsing are keyboard- and screen-reader-operable, and announce the expanded state (UX-DR-157)

**Given** one of the "School" years was deleted
**When** the group is expanded
**Then** that year still appears with its counts, under "School", with an "Ended" marker, and its events stay in the totals

**Given** a sub-track renamed from "Cheder" to "School"
**When** the report renders
**Then** all its events appear under "School" only (Story 5.1 rule), with no row left behind for "Cheder"

**Given** a learner with no sub-tracks
**When** the report renders
**Then** By source shows Home (and Before tracking, if present), the School years section is hidden, and no prompt to create a sub-track is shown (UX-DR-87 spirit; UX-DR-66)

**Given** a learner with no counted events in this curriculum
**When** the report renders
**Then** it shows "Distinct · 0", Learning events 0 and hides the other sections (UX-DR-143)

**Given** the learner learns in more than one curriculum, including one that is `retired`
**When** the parent switches curriculum on the report
**Then** each curriculum shows only its own totals, groups and unit label, and the retired curriculum's lifetime totals stay available (no velocity is shown for it)

**Given** `LearnerState` is still loading (repositories paging events or `intentHistory`)
**When** the screen opens
**Then** it shows the existing `LoadingIndicator`, never partial totals
**And** on a load error it shows `AppErrorView` with retry (UX-DR-102, UX-DR-144)

**Given** the goal has been reached
**When** the parent opens the report and new learning is recorded afterwards
**Then** the report keeps updating live, and nothing on it implies the record has stopped

**Given** a tablet at ≥ 840 dp, dark mode, Hebrew locale, or 200% text scale
**When** the report renders
**Then** it uses the tablet composition from mockup #14, the dark token values, mirrored RTL chevrons and insets, and stacked layouts with no clipping of Hebrew marks (UX-DR-156, UX-DR-161, UX-DR-162, UX-DR-164, UX-DR-165)
**And** cards are flat with 1 px outlines and no shadows (UX-DR-15)

**Given** a profile at the perf-fixture size (Story 5.1)
**When** the report opens with `LearnerState` cached
**Then** the first frame with totals renders within 1 s, and expanding a group causes no recompute of the engine

---

### Story 5.3: Per-source velocity and on-track status

As a parent,
I want to see how fast each source is moving since tracking started, and whether my child is on track,
So that I can check each rate estimate against reality and act before the goal slips.

**Requirements:** FR-32; FR-18, FR-20, FR-21 (status reused, not recomputed); UJ-6; screen #14 (Per-source pace section); UX-DR-6, UX-DR-7, UX-DR-23, UX-DR-24, UX-DR-42, UX-DR-48, UX-DR-69, UX-DR-75, UX-DR-94, UX-DR-95, UX-DR-157; AD-35, AD-31, AD-40, AD-48

**Acceptance Criteria:**

**Given** an evaluated curriculum with Home and two active sub-tracks
**When** the Per-source pace section renders on the Lifetime report
**Then** it shows one row per source with a source chip, the measured velocity since tracking started in `headline-small` (e.g. "9.6 / week"), the trailing-window figure, and, for a sub-track, the caption "{rate_per_week} / week estimate" (UX-DR-42)
**And** the footnote reads "Before-tracking learning isn't counted in pace." (UX-DR-69)
**And** no "On pace" or "Steady" labels appear on the rows (UX-DR-42)

**Given** a source whose events include `before_tracking` entries
**When** velocity is shown
**Then** those entries do not change the velocity figure, and a test proves that adding 500 before-tracking events changes no velocity value

**Given** a catch-up event recorded on Sunday for a Shabbos `learned_on`
**When** velocity is shown
**Then** it counts on the Shabbos day, not Sunday, and a test proves this across a week boundary (Shabbos in week N, entry in week N+1)

**Given** a source with less than 14 days of tracked history
**When** the row renders
**Then** the trailing figure reads "Too early to tell" in neutral styling, while the since-tracking figure still shows (UX-DR-94)

**Given** an ended or deleted sub-track
**When** the section renders
**Then** that source's row shows its velocity over its own window, labelled "Ended", with no estimate comparison and no status

**Given** the main track has a deadline goal
**When** the On-track block renders above the per-source rows
**Then** it shows exactly the engine's status for this curriculum ("On track", "Behind pace" or "Too early to tell"), with the icon and text, the projected finish and the daily target (UX-DR-23, UX-DR-24)
**And** status is conveyed in text, not by colour alone (UX-DR-157). "On track" uses success green and "Behind pace" uses amber, as parent-only treatments (UX-DR-6, UX-DR-7)
**And** each sub-track with a positive shortfall shows the shortfall message under the on-track block (FR-21 wording)

**Given** no deadline goal
**When** the block renders
**Then** it shows the projected finish only, with no status chip (UX-DR-95)

**Given** a calendar-program curriculum (e.g. Daf Yomi)
**When** the section renders
**Then** status comes from the engine's calendar shortfall (assigned through today minus learnt), and there are no sub-track rows, because such curricula reject sub-tracks (deviation #12)

**Given** a retired or archived curriculum
**When** the parent views its report
**Then** the Per-source pace and On-track sections are hidden, and only the lifetime totals show

**Given** the report is viewed in the child session through any route
**When** the screen is resolved
**Then** no velocity, status or shortfall is ever rendered to the child (NFR-9; UX-DR-48)

**Given** the dashboard shows "Projected finish: {date}" for the curriculum
**When** the parent opens the report on the same `LearnerState`
**Then** the report shows the identical status, projected finish and daily target (a widget test compares both against one `LearnerState` fixture)

---

### Story 5.4: Export reports as PDF and share

As a parent,
I want to export the lifetime and per-source report as a PDF and send it through the system share sheet,
So that I can keep a permanent record or show the school and the rebbe.

**Requirements:** FR-31, FR-32; AR-19; AR-3 (pdf ^3.13.1, share_plus ^13.3.0); UJ-6; screen #14; UX-DR-11, UX-DR-43, UX-DR-145, UX-DR-153, UX-DR-166; AD-48

**Acceptance Criteria:**

**Given** the Lifetime report (Story 5.2) for a curriculum
**When** it renders for the parent
**Then** a primary *Export PDF* pill is shown (UX-DR-43), and it stays enabled for a learner with no counted events, exporting the same zero-state report.

**Given** the Lifetime report is showing for a curriculum
**When** the parent taps *Export PDF*
**Then** a PDF is generated on the device with the `pdf` package from the same `LearnerState` report projection the screen shows, with no network call
**And** the PDF contains: the learner's name, the curriculum, a generated-on date in the learner's time zone, Distinct, Learning events, By source, School years (every group fully expanded with per-year lines), Per-source pace with the before-tracking footnote, and the On-track block (for evaluated curricula)
**And** each number in the PDF equals the matching number on screen (a test renders both from one fixture and compares the extracted values)

**Given** the PDF is generated
**When** its fonts are inspected
**Then** Noto Sans Hebrew (from `assets/fonts/NotoSansHebrew-*.ttf`) and the Latin font are embedded subsets, and no text depends on a system font

**Given** Hebrew strings in the report (masechta names, sub-track names typed in Hebrew, Hebrew labels when the Hebrew Terms setting is on)
**When** they are written to the PDF
**Then** every nikud and ta'am code point (U+0591–U+05C7) is stripped first. A test extracts the PDF text and asserts that no code point in that range is present (AD-48)
**And** Hebrew runs are laid out right-to-left: a golden-image test of a mixed line ("בית ספר · 210 mishnayos") shows the correct glyph order, with the digits kept left-to-right
**And** when the Hebrew Terms setting is off, transliterated terms are used, as on screen (UX-DR-11)

**Given** a sub-track named only in Hebrew, a deleted sub-track, and a renamed sub-track
**When** the PDF is generated
**Then** each appears under the same group name and with the same "Ended" marker as on screen

**Given** a learner with no sub-tracks, or no events at all
**When** the PDF is generated
**Then** it renders the same reduced sections as the screen (UX-DR-143), with no empty tables or placeholder text

**Given** a large history (the Story 5.1 perf fixture, with School-year groups that produce more than one page)
**When** the PDF is generated
**Then** content flows across pages with repeated section headers and page numbers, and no row is split mid-line
**And** generation runs off the UI isolate. The *Export PDF* pill shows an in-progress state and is disabled until generation finishes, and the UI stays responsive (no frame over 100 ms while generating)
**And** generation finishes in under 3 s on a mid-range device

**Given** the PDF is ready
**When** sharing starts
**Then** the system share sheet opens through `share_plus` with the file named `learning-report-{learner}-{curriculum}-{yyyy-mm-dd}.pdf` and MIME type `application/pdf`
**And** on iPad the share sheet is anchored to the *Export PDF* button (`sharePositionOrigin`)
**And** dismissing the share sheet returns to the report with no error, and platform back behaves per UX-DR-166

**Given** generation or file write fails (generation error, storage full)
**When** the failure happens
**Then** a floating snackbar reads "Couldn't export the report — try again." with *Retry*. The report stays on screen, the temp file is deleted, and nothing partial is shared (UX-DR-145)

**Given** `LearnerState` is still loading or paging
**When** the parent views the report
**Then** *Export PDF* is disabled until inputs are complete, so a PDF never reflects partial data

**Given** the device is offline with all events cached
**When** the parent exports
**Then** the export succeeds from local data, and only the share target itself may need a connection

**Given** a child or tutor session
**When** any export entry point is resolved
**Then** none is available, and the export function rejects any call without an unlocked parent session

**Given** the `share_plus` dependency is still `^12.0.2` in `learning_tracker/pubspec.yaml`
**When** this story starts
**Then** the AR-3 bump to `share_plus ^13.3.0` and `pdf ^3.13.1` from Epic 1 has already landed. If not, this story is blocked, and the existing backup export (`data_export_import_providers.dart`) is regression-tested on the new `share_plus` API

---

**Open decisions referenced above (resolve before story creation)**

- **G-1:** The per-source velocity metric is not defined in the spine. These stories use "distinct leaves first learnt *by that source*". AD-35's all-sources velocity excludes leaves already learnt elsewhere, so the per-source figures can sum to more than the all-sources figure. EXPERIENCE open question 12 is still open.
- **G-2:** The window label differs. The UX says "Last 30 days", while AD-35 uses a trailing 28 days and FR-32 says "since tracking started". These stories show both "since tracking" and "last 28 days", following the spine.
- **G-3:** It is unspecified whether a `before_tracking` node event counts as one learning event or one per covered leaf. These stories count it once per covered leaf, to stay consistent with the FR-30 counts.
- **G-4:** UX-DR-21 asks for the name at event time, but AD-52 events carry no name and `intentHistory` excludes `subTrack`. These stories use the sub-track's current or tombstoned `name`.
- **G-5:** The name-matching rule (trim and case-fold) and how same-named ongoing tracks join a school-year group are assumptions.

## Linear

Team DNI, project `learning-tracker`. Each epic is a project milestone; each story is an issue, blocked by the previous story in its epic. 2.1 is blocked by 1.28 (the cutover release); 3.1, 4.1 and 5.1 are blocked by 2.12.

| Story | Issue |
| --- | --- |
| 1.1 | DNI-463 |
| 1.2 | DNI-464 |
| 1.3 | DNI-465 |
| 1.4 | DNI-466 |
| 1.5 | DNI-467 |
| 1.6 | DNI-468 |
| 1.7 | DNI-469 |
| 1.8 | DNI-470 |
| 1.9 | DNI-471 |
| 1.10 | DNI-472 |
| 1.11 | DNI-473 |
| 1.12 | DNI-474 |
| 1.13 | DNI-475 |
| 1.14 | DNI-476 |
| 1.15 | DNI-477 |
| 1.16 | DNI-478 |
| 1.17 | DNI-479 |
| 1.18 | DNI-480 |
| 1.19 | DNI-481 |
| 1.20 | DNI-482 |
| 1.21 | DNI-483 |
| 1.22 | DNI-484 |
| 1.23 | DNI-485 |
| 1.24 | DNI-486 |
| 1.25 | DNI-487 |
| 1.26 | DNI-488 |
| 1.27 | DNI-489 |
| 1.28 | DNI-490 |
| 1.29 | DNI-491 |
| 2.1 | DNI-492 |
| 2.2 | DNI-493 |
| 2.3 | DNI-494 |
| 2.4 | DNI-495 |
| 2.5 | DNI-496 |
| 2.6 | DNI-497 |
| 2.7 | DNI-498 |
| 2.8 | DNI-499 |
| 2.9 | DNI-500 |
| 2.10 | DNI-501 |
| 2.11 | DNI-502 |
| 2.12 | DNI-503 |
| 3.1 | DNI-504 |
| 3.2 | DNI-505 |
| 3.3 | DNI-506 |
| 3.4 | DNI-507 |
| 3.5 | DNI-508 |
| 4.1 | DNI-509 |
| 4.2 | DNI-510 |
| 4.3 | DNI-511 |
| 4.4 | DNI-512 |
| 4.5 | DNI-513 |
| 4.6 | DNI-514 |
| 4.7 | DNI-515 |
| 5.1 | DNI-516 |
| 5.2 | DNI-517 |
| 5.3 | DNI-518 |
| 5.4 | DNI-519 |
