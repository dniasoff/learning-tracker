# UX requirements extraction: Sub-tracks

Sources: PRD `docs/planning/prds/prd-sub-tracks-2026-09-30/prd.md`; addendum and all `extract-*.md`, `reconcile-*.md`, `review-*.md`, `.memlog.md` in that folder; brainstorm `docs/brainstorming/brainstorm-multi-source-mishnayos-tracking-2026-08-24/brainstorm.html` and its `.memlog.md`. Citations below name the source and section; brainstorm memlog entries use E-numbers as indexed in `extract-brainstorm.md` §Ref convention.

## 1. Glossary (verbatim PRD definitions)

Source for every definition: PRD §3 Glossary.

- **Corpus** — the full ordered body of learning for the goal: all Mishnayos (6 sedarim, 63 masechtos, ~4,192 mishnayos). Hierarchy: seder → masechta → perek → mishna.
- **Ground** — any set of corpus nodes (masechta, perek or mishna) assigned to a track.
- **Main track** — the one goal-bearing, planned track. Has a plan, produces scheduled tasks, carries the deadline, and learns one masechta at a time; learning another masechta concurrently means adding a sub-track. Its behavior is unchanged by this PRD except that its schedulable ground shrinks and grows as ground moves to and from sub-tracks.
- **Sub-track** — an unplanned track representing one outside source of learning. Has a name, an ordered ground (possibly empty), exactly one current position, a rate estimate, and a window. Produces a position, not tasks. Two types: school-year and ongoing.
- **School-year sub-track** — a sub-track whose window is one academic year: September to July by default, with editable start and end months. At most one per academic year.
- **Ongoing sub-track** — a sub-track with an open window and an optional end date. At most five active at once.
- **Window** — the period during which a sub-track is active and contributes to the forecast.
- **Rate estimate** — a sub-track's *mishnayos per week* × *weeks per year*. Used only for the forecast.
- **Current position** — the next mishna in a track's own order not yet ticked *in that track*. Every track has exactly one. Learning of the same mishna in another track does not move it (FR-13).
- **Learning event** — one record that a mishna was learnt: mishna, date learnt, source, date state. Append-only.
- **Source** — where the learning happened: the main track (home) or a named sub-track. Implied by where it was ticked.
- **Date state** — one of *dated* (learnt on the recorded day), *catch-up dated* (entered after shabbos/yom tov, dated to the day learnt), *before tracking* (learnt before the learner started using the app; carries no date).
- **Learnt** — a mishna with at least one learning event from any source. Goal progress counts distinct learnt mishnayos.
- **Chazara** — any learning event for an already-learnt mishna. Enriches the lifetime record; never advances the goal.
- **Deadline** — the target date of the goal that covers the whole corpus, owned by the main track. Other goals the learner may have are unaffected by this PRD and do not drive the forecast.
- **On track** — the projected finish date (trailing-4-week velocity, all sources, excluding before-tracking) is on or before the deadline. Parent-facing only.
- **Projected finish date** — the date the goal completes if observed velocity over the trailing 4 weeks continues.
- **Daily target** — the number of mishnayos per day the main track asks for, from the forecast (§4.5).
- **Shortfall** — unlearnt ground on a sub-track's path that its rate estimate will not reach before its window ends; it will return to the main track.
- **Capacity** — a sub-track's rate estimate × active weeks left in its window before the deadline.
- **Expected new ground** — capacity beyond a sub-track's entered ground; the sub-track is expected to keep going onto ground not yet entered.
- **Capture lock** — the shabbos/yom tov state in which the app is readable but no write is possible.
- **Catch-up card** — the post-lock prompt to record learning done during the lock.
- **Tutor** — a person (e.g. a rebbe) granted access to a learner by the parent, using their own device.
- **Learns on shabbos / yom tov** — a sub-track setting, off by default, that includes that source's learning on the catch-up card after a lock.

## 2. Users, personas, journeys, scenarios

Sources: PRD §§2.1–2.3; PRD §4.7 FR-26–29; PRD §4.8 FR-30–32.

- **Child learner (holds the phone):** records learning with almost no effort, sees progress grow, and celebrates a siyum.
- **Parent (configures):** sets the goal; wants the daily amount to account for school/rebbe coverage, an at-a-glance on-track status, and no false “failing” indication.
- **Rebbe / tutor (own phone):** maintains learning for multiple talmidim; sees only learners whose parents granted access.
- **Family:** wants app behavior that respects shabbos and yom tov.
- **Yehuda, 10** (illustrative stand-in), child learner; his father configures the tracks. **Rav Cohen** (illustrative stand-in), Yehuda’s rebbe/tutor. Protagonist names are illustrative (PRD §2.3; §8.1).

**Journeys / scenarios (PRD §2.3):**

- **UJ-1 — Yehuda ticks his whole day in one sitting.** Signed in on his profile/home screen, he records home learning on the main-track list (or +1) in the morning. At bedtime, without navigation or a source picker, he uses *up to…* on the School and Rebbe rows. Count, masechta fill, home streak, and a newly completed masechta’s siyum update; his father sees “on track.” If he ticks the wrong place, he or his father/rebbe corrects it and count/target recompute.
- **UJ-2 — Rav Cohen keeps his sub-track true for several talmidim.** With parent-granted tutor access, he opens Yehuda, adds a Rebbe sub-track with rate and Beitzah ground, later adds a masechta and fixes a wrong tick. Yehuda’s target and Rebbe position reflect changes; Rav Cohen sees each talmid’s standing in one list.
- **UJ-3 — Yehuda’s father sets up this school year informally, in pieces.** Adds a School sub-track for Sep 2026–Jul 2027, 10 mishnayos/week, 39 weeks, initially without ground. In October, adds Berachos perakim 1–3; they grey out on the main track and stop being scheduled. If school cannot finish them, parent sees a shortfall warning. At year end unfinished ground returns to its original main-track place; *Add next year* creates the following sub-track in one tap. Overlapping ground on Rebbe stays independent.
- **UJ-4 — Friday afternoon to Sunday: shabbos without logging.** Before candle-lighting, learner sees the planned day. During the lock the app is readable but controls are untappable and on-track is frozen. After shabbos, a card asks “Shabbos · 14 mishnayos planned — learnt them all?” with *Yes, all of it* or *Adjust…*. Events date to shabbos; a caught-up lock day preserves streak. Same principle covers yom tov, including chained three-day yom tov/shabbos.
- **UJ-5 — First run: sub-tracks are mentioned, not set up.** Onboarding sets up the main track as today and mentions where school/rebbe sub-tracks can be added later. It asks for no sub-track setup. Families who do not need them do not see them again.
- **UJ-6 — One mishna, a whole life.** Yehuda opens Berachos 1:1 to see every learning event, dates and sources, including before tracking and repeats at home/school/rebbe. Father exports lifetime and per-source reports. Repeats do not inflate goal progress but remain in the record.

## 3. Functional requirements with user-visible behavior

Sources: PRD §4.1–§4.10 (IDs retained verbatim); PRD §6 for inclusion; addendum §2–3 for forecast terminology.

- **FR-1 — Home-screen sub-track rows:** one row per active sub-track below unchanged main-track tasks, showing name and current position; ended tracks and, if none exist, no sub-track section. A groundless row prompts parent/tutor to add ground; child cannot tick it.
- **FR-2 — +1 and up to…:** one gesture records current position or current-through-selected-later mishna in track order; source comes from row with no prompt; position advances to next not yet ticked in that track. Groundless tracks cannot be ticked.
- **FR-2a — Up to… with individual adjustment, everywhere:** runs on sub-track row, main-track today list and catch-up; learner can tick/untick individual mishnayos before confirming; only those left ticked create events. Main tasks remain generated as before.
- **FR-3 — Free tick and tick-to-here in corpus browser:** child/parent can mark any corpus node at any level, including a mishna and everything before it in corpus order within its masechta. Batch asks source once (default main/home); can mark *before tracking*; event date defaults today and is editable at capture. Before-tracking affects no streak/velocity; free ticks count toward streak only for main/home and the counted day.
- **FR-4 — Correct a mistake:** child, parent, or tutor can undo/correct wrong place, source, or date. Progress/streak/velocity and positions/target recompute; correction voids original and may replace it. Child can re-date only within catch-up window; older child corrections limited to removal. Parent history retains who/when; voided events hidden from child. Correction does not create/restore a streak day outside the eligible correction window.
- **FR-4a — Sub-tracks are optional and found in the menu:** onboarding has one mention and location; no setup steps; app never prompts creation; learner with no sub-tracks sees no home section.
- **FR-5 — Create a school-year sub-track:** form fields: name, academic year picker (Sep–Jul default, editable start/end months), mishnayos/week, weeks/year (prefilled 39, editable). Picker spans current through deadline year, or current plus next two with no deadline; used years unavailable; school-year windows cannot overlap; no exclusion checkboxes. Current part-elapsed year assumes remaining-window proration.
- **FR-6 — Create an ongoing sub-track:** name, mishnayos/week, optional “not learning during bein hazmanim” (off by default; changes prefilled weeks only), optional start date, editable weeks/year, optional end date. Maximum five active ongoing tracks. User-edited weeks are never overwritten by toggling the option.
- **FR-6a — Future start:** future start date means forecast contribution begins at that date; row is absent from home until then.
- **FR-6b — Learns on shabbos / yom tov:** per-sub-track flag, default off; only flagged tracks appear in catch-up.
- **FR-7 — Add next year:** create following academic year from existing School track in one action, copying name/rate/weeks; fields editable before save; ground starts empty; edited academic-year boundaries carry over.
- **FR-8 — Edit and delete sub-tracks:** parent/tutor can edit any field or delete. Rate edits recompute daily target. Delete returns unfinished ground and keeps events in lifetime record.
- **FR-9 — Sub-track detail:** child/parent/tutor sees ordered ground and tri-state progress across masechtos, current position, ticked count, capacity vs remaining path. Learning elsewhere appears learnt but does not move this track’s position.
- **FR-10 — Assign ground to a sub-track:** parent/tutor can incrementally assign any masechta, perek or mishna. Assigned content remains visible but greyed/unscheduled on main track. Same mishna can belong to multiple sub-tracks; already-learnt ground may be assigned (chazara); no duplicates within a sub-track or within main track.
- **FR-11 — Order ground within a sub-track:** parent/tutor can order it. New ground appends by default and can be moved; reordering preserves ticks and resets position to first item not yet ticked in that track; forecast recomputes.
- **FR-12 — Return ground when a sub-track ends:** school-year end, end date, or deletion returns only ground not learnt by any source, at its original main-track position. Learnt ground is not rescheduled. If another active sub-track holds it, it remains out of main schedule until none do. Schedule and target recompute.
- **FR-12a — One masechta at a time on the main track:** main schedule stays one masechta at a time (boundary-day exception when one completes and next begins). A second concurrent masechta requires a sub-track. Returned earlier ground queues after current masechta completes.
- **FR-13 — Tracks are independent:** learning in one track does not move another track’s position; same mishna counts as learnt for goal regardless of source.
- **FR-14 — Goal progress counts distinct mishnayos:** all sources/date states count; repeats do not add progress; before-tracking does.
- **FR-15 — Tri-state everywhere:** corpus nodes display empty/partial/complete in main corpus view, corpus browser, ground picker and each sub-track detail. One learnt mishna makes parent perek/masechta/seder partial. Visual mapping for partial is not specified in PRD.
- **FR-16 — Streaks count home learning only:** main/home events maintain streak; sub-track-only day does not, but all sources count in progress/fill/siyum and no screen says outside-source learning “doesn’t count.” A lock day does not break streak if caught up in window.
- **FR-17 — Siyum:** fires once when distinct learned mishnayos complete a masechta, from any source; chazara does not re-fire; entirely sub-track completion fires it.
- **FR-18 — On track at a glance:** parent sees status and projected finish date on home; fewer than 2 weeks history shows “too early to tell”; 2–4 weeks uses all tracked history; a single large day cannot flip status unless trailing-4-week projection crosses deadline. Child sees encouragement, today vs target and streak; never “behind/off track.”
- **FR-19 — Daily target:** when deadline exists, target derives from main remaining less expected new ground plus shortfall, divided by main-track study days to deadline (default all seven). Capacity uses rate × active weeks in window before deadline; path is ordered ground from current position; shortfall is unlearnt path beyond capacity; expected new ground is capacity beyond entered path. Target floors at zero and displays “all covered — any extra learning is a bonus.” Ground entry that stays within capacity does not jump target; changes and learning recompute it. Duplicate shortfalls are avoided, but overlapping expected new ground counts in full.
- **FR-20 — No deadline, no required rate:** show projected finish date, no daily target or on-track status; sub-track rate estimates do not affect displayed values.
- **FR-21 — Shortfall warning:** parent sees named track, ground, window end and approximate mishnayos returning when shortfall > 0; it disappears when shortfall returns to 0. Child never sees it.
- **FR-22 — withdrawn.** No active functional behavior (PRD §4.5; PRD .memlog finalization entry; see idea status §5).
- **FR-23 — Capture lock:** from 10 minutes before candle-lighting to 10 minutes after tzeis at learner location, all capture/edit controls disabled on every signed-in device (including tutor); app remains readable, lock fails closed, and on-track does not change. Learner-level Israel/chutz-la’aretz controls one/two-day yom tov and is editable/defaulted from location. If zmanim/location unavailable, conservative local-time fallback locks and prompts parent for location; high-latitude tzeis uses conservative fallback. Offline writes timestamped during lock are rejected at sync.
- **FR-24 — Planned view:** before/during lock, learner sees frozen planned list for locked day(s); erev and locked views are the same; locked view has no tappable controls.
- **FR-25 — Catch-up card:** after lock, “learnt them all?” one-tap or *Adjust…* with per-locked-day list and up-to/individual adjustments. Available through first full nonlocked day; pauses across another lock and pending cards stack; events date to locked days and state *catch-up dated*. Up to 3 consecutive days; reminder fires. Includes main track and marked sub-tracks only.
- **FR-26 — Tutor edits:** parent-granted tutor may do everything parent can on learner’s main track, deadline and sub-tracks. Tutor edits attributed by identity/time; tutor sees only granted learners and nothing else about family.
- **FR-27 — Change history and undo:** parent sees history of tutor changes to tracks, goal and learning events; entries show who/what/when. Parent can undo, which itself is recorded. Notify parent on tutor deadline/main-track edits; sub-track edits appear without notification.
- **FR-28 — Revoking a tutor:** parent revokes at any time; access ends on next sync; tutor-created tracks and events remain unchanged.
- **FR-29 — Multi-talmid list:** tutor sees list of learners with active grants and each on-track status; can open a learner; revoked learners disappear.
- **FR-30 — Mishna history:** child/parent opens any mishna for date or *before tracking*, source and event count. Count excludes voided events; deleted-track events remain labeled with track name.
- **FR-31 — Lifetime report:** parent views/exports lifelong report, continuing after goal; same-named sub-tracks roll up into expandable year rows. Report includes distinct mishnayos, total events, and per-source totals.
- **FR-32 — Per-source report:** parent views/exports PDF velocity since tracking and on-track status. Before-tracking excluded from velocity; catch-up events counted on learning day.

**Other visible behavior without FR IDs:** capture works offline and syncs later; events from devices do not overwrite each other. Concurrent parent/tutor edit to same track/goal is later-change-wins and both changes appear in history. Daily-target recompute is assumed under 1 second on mid-range device (PRD §4.9). Parent account deletion removes associated sub-tracks/events/history; privacy policy must disclose tutor view/edit and parent-visible change history (PRD §4.10).

## 4. User-visible states and edge cases

Sources: PRD §§2.3, 3, 4.1–4.10, 8–9; addendum §1–3; extract-code-reality.md §§1–9; reconcile-code-reality.md “Gaps”; review-adversarial-general.md “Scope honesty” and “Done-ness clarity”; reconcile-brainstorm.md “Gaps”.

- **Empty:** no sub-tracks means no sub-track home section (FR-4a); new sub-track can have empty ground and shows add-ground prompt, no child capture (FR-2); new next-year track has empty ground (FR-7); no learnt descendants = empty tri-state (FR-15).
- **Partial / complete:** partial and complete cascade to ancestors; exact empty/grey/checked appearance from brainstorm is not fixed in PRD (§4.4 FR-15; reconcile-brainstorm “Gaps”).
- **Progress / overlap:** progress counts distinct mishna across all sources; repeated learning is chazara in history. Tracks can overlap ground and each maintains own independent position. Ground learnt elsewhere renders learnt in details without advancing this track (FR-9, 13–17).
- **Ground moves:** assigned ground leaves schedule but remains greyed on main track; deletion/end returns only unfinished ground at original order; overlap in an active track delays return (FR-10–12).
- **Capacity / target:** full capacity credited; expected ground can exist before entry; shortfall warning is parent-only; zero target says extra learning is bonus; no deadline removes required target/status (FR-18–21).
- **School/year boundaries:** only one school track per academic year; picker restricted by current/deadline (or current+2 absent deadline); current part-elapsed window prorating is an assumption; edited start/end months carry forward and windows cannot overlap (FR-5, 7; §9).
- **Ongoing timing:** max five active; future-start hidden from home until start but forecast begins at start; optional end date; ended ones do not use limit (FR-6/6a).
- **Shabbos/yom tov:** capture and edits unavailable but reading/planned list available; status frozen. Chained locks pause catch-up availability; cards stack; up to three locked days represented; only enabled sources appear. Missing zmanim/location and high latitude invoke conservative fallback; location prompt goes to parent; offline lock-window writes rejected on sync (FR-23–25).
- **Correction/history:** correction removes impact and may replace; child date corrections limited to catch-up window, older child change is removal only; parent can undo tutor changes and history retains actor/time. Deleting track does not erase events (FR-4, 8, 27, 30).
- **Offline/concurrency:** event records from devices merge without overwrite; concurrent parent/tutor changes use later-change-wins and both are in history (§4.9). Recompute latency has assumption <1s.
- **Existing data / migration:** current implementation has setup bulk marks with UTC `2000-01-01` sentinel and `bulkBaseline`, excluded from velocity; PRD maps that concept to *before tracking*. Addendum says verify no tap-dated setup backfill exists before planning migration. No migration behavior for existing users is specified. Existing app permits multiple goals per curriculum; PRD’s single whole-corpus deadline expectation has no migration/selection flow (addendum §1 “Goals”; reconcile-code-reality “Gaps”; review-adversarial-general “Scope honesty”). Existing study-day settings already inform scheduler; compatibility with target denominator and changed main-track policy remains a brownfield issue (review-adversarial-general “Scope honesty”).
- **Unspecified edge cases called out in review/reconcile:** catch-up *Adjust…* per-day allocation; initial event-date edit is not explicit despite brainstorm idea; no-deadline daily task sizing; lock opt-in / exact writes excluded; assigning current in-progress ground and return behind current position; velocity/report target definition; uncertainty about school-year locale; points for sub-track ticks. These remain unspecified in PRD (reconcile-brainstorm “Gaps”; review-adversarial-general “Done-ness clarity,” “Scope honesty,” “Downstream usability”).

## 5. Explicit brainstorm UX ideas and disposition

Status key: **ADOPTED IN PRD** = requirement present; **DEFERRED** = explicitly parked/out of MVP or revisit condition; **REJECTED** = explicitly removed/withdrawn; **UNMENTIONED** = brainstorm/reconcile identifies it but PRD does not decide or specify it. Each item cites brainstorm section and PRD/reconcile status evidence.

| Brainstorm UX idea | Status | PRD / reconcile disposition |
|---|---|---|
| One learner goal fed by Home, Rebbe, and School over the same Mishnayos corpus; estimates reduce home target. | ADOPTED IN PRD | PRD §§1, 3, 4.5 FR-19; brainstorm “The app assumed a straight line”; extract-brainstorm §1–2. |
| Grey/partial/checked cascading progress across seder > masechta > perek > mishna. | ADOPTED IN PRD | PRD §4.4 FR-15 adopts tri-state; exact grey visual mapping is UNMENTIONED (reconcile-brainstorm “Gaps”). Brainstorm “1 · The grey box, cascading.” |
| Reorder recomputes backlog/today rather than leaving stale tasks. | ADOPTED IN PRD | PRD §§1, 4.3, 4.5 FR-19; extract-brainstorm §2 decision 1; brainstorm “The plan is derived. The events are the only stored facts.” |
| Browse/free-tick any corpus node; tick-to-here; source once per batch, default home; before-tracking backfill. | ADOPTED IN PRD | PRD §4.1 FR-3; before-tracking semantics in §§3, 4.4, 4.8. Initial event-date edit and distinct default source for before-tracking remain UNMENTIONED (reconcile-brainstorm “Gaps”). Brainstorm “Three surfaces, and nothing else new.” |
| Append-only event history; distinct goal progress; repeats recorded as chazara, not collision prompt. | ADOPTED IN PRD | PRD §§3, 4.4 FR-14/17, 4.8 FR-30–32; extract-brainstorm §2 decisions 2–3. Brainstorm “Chazara, not collision” and “4 · One mishna, a whole life.” |
| Per-source measured velocity and PDF report; parent can assess whether on target. | ADOPTED IN PRD | PRD §4.8 FR-32. Metric/window details queried in reconcile-brainstorm “Gaps”; PRD defines on-track projection in FR-18 but does not define report’s exact on/off-target metric. |
| Keep each source’s rate/settings on its own sub-track form; ground assignment removes it from home schedule. | ADOPTED IN PRD | PRD §§4.2–4.3 FR-5–10; extract-brainstorm §2 decisions 15, 20–21. Drag gesture from corpus browser is UNMENTIONED (reconcile-brainstorm “Gaps”). |
| School-year and ongoing types; school picker, weeks/year, ongoing bein hazmanim prefill, optional end date; one/year and max five. | ADOPTED IN PRD | PRD §4.2 FR-5–7. Deleted year numbering and school exclusion fields; see rejected rows below. Brainstorm “Three surfaces…”; extract-brainstorm §2 decisions 12–18. |
| “Add next year” clones school track settings; future sub-tracks contribute before start. | ADOPTED IN PRD | PRD §4.2 FR-6a/7; extract-brainstorm §2 decisions 24–25. |
| One ordered position per track; one home row per sub-track with +1 / up to…; sub-track detail shows ordered progress. | ADOPTED IN PRD | PRD §§4.1–4.3 FR-1/2/9/11/13. Brainstorm “Every open front, in one place”; extract-brainstorm §2 decisions 19, 27. |
| Main tasks remain unchanged; separate mixed home screen with tasks first, sub-track rows below. | ADOPTED IN PRD | PRD §4.1 FR-1 and §4.2 FR-4a; PRD §5; brainstorm “The reversal that saved the codebase”; extract-brainstorm §2 decision 27. |
| Capacity forecast, shortfall return warning, and target floor at zero. | ADOPTED IN PRD | PRD §4.5 FR-19/21; extract-brainstorm §2 decisions 21–22; brainstorm “The rate validates the carve-out.” |
| Detect unplanned gaps between school-year contributions and ask if year is finished/unplanned. | REJECTED | PRD §4.5 FR-22 is withdrawn; PRD §2.3 UJ-5 / FR-4a says optional and never prompts. PRD `.memlog.md` final decision withdraws gap detection. Brainstorm “Gap detection along the timeline”; extract-brainstorm §2 decision 23. |
| Self-correct rate estimate from observed source velocity (“update?”). | DEFERRED | PRD §8.1: revisit if FR-32 shows estimate/actual diverging >25% for a month. Reconcile-brainstorm says this proposal is otherwise absent. Brainstorm “Not a technique. A conversation” / “Open, parked…”; extract-brainstorm §2 decision 34 context. |
| Warm/cold chazara prompt. | DEFERRED | PRD §6.2 says offered but not adopted; brainstorm “Open, parked, and deliberately not built.” |
| Annual-total estimate instead of rate × weeks/year. | DEFERRED | PRD §6.2 says not adopted; brainstorm “Open, parked…” says offered late, not taken. |
| App-inferred calendars, confidence intervals, and calendar learning; per-scope deadlines. | DEFERRED | PRD §5 rejects in v1/no-goals; §8.1 gives no revisit except rate/calendar accuracy context; brainstorm “Open, parked…” and PRD §5. |
| Yom-tov exclusion checkbox; school exclusion checkboxes; main-track excluded days. | REJECTED | PRD FR-5/6 and §5: school has no exclusions; ongoing only bein hazmanim prefill; main track study-day denominator remains as existing setting (FR-19). Brainstorm “Calendars touch nothing but a sub-track’s weeks”; extract-brainstorm §2 decisions 9–10/14. |
| Multiple masechtos concurrently on main track. | REJECTED | Reversed in PRD §3 and FR-12a; PRD §5 keeps one-at-a-time; extract-brainstorm §2 decision 8. Brainstorm “The reversal that saved the codebase.” |
| Separate current pointer/row per masechta, or unified main/sub-track row design. | REJECTED | PRD FR-1 has one row per sub-track, FR-11/13 one position; main today tasks stay as before. Earlier models explicitly withdrawn in extract-brainstorm §2 decisions 19 and 27. Brainstorm “Where the coach was wrong.” |
| Estimates on main-track goal settings; free tick as a source; multi-option collision prompts. | REJECTED | PRD FR-2/3 source from row or choose once; chazara is event; estimates are per-sub-track (§4.2). Brainstorm “The double-count landmine” and “Chazara, not collision”; extract-brainstorm §2 decisions 3, 5, 15. |
| Streak-safe shabbos/yom tov read-only lock, planned list, post-lock catch-up, backdated events, reminder. | ADOPTED IN PRD | PRD §§4.4 FR-16, 4.6 FR-23–25. Catch-up Adjust detail is UNMENTIONED (reconcile-brainstorm “Gaps”); brainstorm “Four small pieces” and “Why the dating is not cosmetic.” |
| Exact erev/locked view parity and frozen-status explanation copy. | ADOPTED IN PRD | Shared erev/locked planned screen and frozen status behavior are in PRD FR-24 and FR-23. Exact explanatory copy is UNMENTIONED (reconcile-brainstorm “Gaps”). Brainstorm “Shabbos locked view.” |
| Parent/tutor access, multi-talmid list, audit/undo; child-held phone for capture. | ADOPTED IN PRD | PRD §§2.1–2.3, 4.7 FR-26–29; child data and history in §4.10. Research suggestion of parent sign-off is UNMENTIONED (reconcile-research “Gaps”). |
| Group same-named school years into one expandable lifetime-report row. | ADOPTED IN PRD | PRD §4.8 FR-31; brainstorm “Open, parked…” originally asks whether grouping needed; decision recorded in PRD `.memlog.md` and reconcile-memlog #43 area. |
| “As simple as possible” as governing principle; family identity/experience statement. | UNMENTIONED | Reconcile-brainstorm “Gaps” says the governing principle and qualitative family identity are not explicit. Vision includes ease but does not state this principle. Brainstorm “Three scope locks and a governing principle”; “Shabbos changed genre.” |
| Stated staged build order (minors → sub-tracks → shabbos). | DEFERRED | PRD §6.2 says delivery order is planning decision for epics; reconcile-brainstorm marks ignore-with-reason. Brainstorm “What actually gets built, in order.” |
| Existing-data migration for historical/backfill event dates and goal/study-day settings. | UNMENTIONED | Addendum §1 asks to verify no tap-dated production backfill; review-adversarial-general “Scope honesty” flags migration/goal/study-day collision. No migration UI or path specified. |

## 6. Non-goals and out-of-scope items

Sources: PRD §2.2, §5, §6.2, §8.1; brainstorm “Open, parked, and deliberately not built”; reconcile-brainstorm.

- Schools are not users/institutions in v1: no school accounts, class rosters, school-system imports; parent enters school ground informally.
- Learners without one corpus goal contributed to by multiple sources see the current app unchanged.
- No change to main-track task planning/generation; one masechta at a time.
- No sub-goals or sub-track deadlines; the main track alone owns the one whole-corpus deadline.
- No school calendars, term dates, imports, or per-country school logic; one weeks/year estimate per sub-track.
- No school-side accounts/logging.
- Sub-tracks remain optional; never prompted or suggested for setup. Onboarding mention only.
- No cross-track position sync or dedupe; overlapping ground is allowed and not reconciled.
- No app-learned calendars, confidence intervals, or self-correcting rate suggestions in v1.
- Warm/cold chazara prompts and year-total estimate are out of MVP (PRD §6.2).
- Gap detection is withdrawn (FR-22); no school-year coverage prompt.
- Build/delivery stage order is planning, not a product constraint (PRD §6.2).
- PRD does not amend the superseded product-level PRD (PRD §0).

## 7. Open questions and assumptions with UX impact

Sources: PRD §§4.2, 4.9, 8–9; review-adversarial-general “Findings”; reconcile-brainstorm “Gaps”; reconcile-code-reality “Gaps”.

**Open questions / deferred findings in PRD §8.1:**

- Per-source rate is not automatically checked against measured velocity; revisit if estimate and actual diverge >25% for a month (PM; FR-32).
- Proration math for partially elapsed windows and ongoing windows crossing deadline (Architect; FR-19).
- Siyum on backfill, correction, or void/un-completion (UX; FR-17).
- One-tap “Yes, all of it” risks making over-reporting easy; revisit parent feedback or SM-C1 anomaly (PM; FR-25).
- Exact corpus definition / mishna count and numbering edition (Architect; FR-14).
- Future sub-track ground is unavailable to main track until its start (PM; revisit on report of blocked home learning).
- Rationale for five ongoing and one school/year limits (PM; revisit if users exceed limits).
- Analytics measurement method for SM-1–SM-5 (Architect; before release).
- Whether existing users should be prompted for study days/goals when first adding sub-track (UX; FR-5/6).
- PRD §8 says none blocking; the above are deferred/non-blocking.

**Tagged assumptions in PRD:**

- Current part-elapsed academic-year sub-track counts only remaining window, prorated by remaining fraction (FR-5; indexed §9).
- Daily-target recomputation under one second on a mid-range device (§4.9; indexed §9).

**Additional UX-affecting uncertainties recorded by review/reconciliation (not resolved as PRD assumptions):**

- Initial event date editability and how an unspecified before-tracking source/default is selected; PRD only defaults free-tick source to home and supports date correction (reconcile-brainstorm “Gaps”).
- Exact partial-state visual treatment (empty/grey/checked); PRD specifies semantic tri-state only (reconcile-brainstorm “Gaps”).
- Catch-up *Adjust…* per-day interaction/allocation across multiple lock days (reconcile-brainstorm “Gaps”; review-adversarial-general “Done-ness clarity”).
- Lock opt-in for users who do not keep shabbos, exact boundary actions exempted, and which location governs tutor device (review-adversarial-general “Done-ness clarity” / “Scope honesty”).
- No-deadline task sizing and on/off-target report’s exact metric/window (reconcile-brainstorm “Gaps”).
- Assigning ground from the in-progress masechta and whether returned earlier ground waits for current masechta; review says FR-12a partially addresses return scheduling, but assignment boundary remains unspecified (review-adversarial-general “Done-ness clarity”).
- Public child-data consent/retention/export details and account-deletion semantics beyond existing policy reference; review-adversarial-general “Scope honesty” flags them.
- Existing-user migration/selection for multiple goals, study-day settings and any tap-dated backfill; PRD/addendum do not define a flow (reconcile-code-reality “Gaps”; review-adversarial-general “Scope honesty”).
- Points for sub-track ticks and how new FRs replace/extend existing bulk-mark and tutor-list surfaces (review-adversarial-general “Downstream usability”).
