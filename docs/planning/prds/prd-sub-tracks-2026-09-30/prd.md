---
title: "PRD: Sub-tracks — multi-source Mishnayos tracking"
status: final
created: 2026-09-30
updated: 2026-09-30
inputs:
  - docs/brainstorming/brainstorm-multi-source-mishnayos-tracking-2026-08-24/brainstorm.html
  - docs/brainstorming/brainstorm-multi-source-mishnayos-tracking-2026-08-24/.memlog.md
  - extract-brainstorm.md
  - extract-code-reality.md
  - extract-research.md
---

# PRD: Sub-tracks — multi-source Mishnayos tracking

*Working title — confirm.*

## 0. Document Purpose

This PRD specifies **sub-tracks**: a change to Learning Tracker that lets one learner's single goal draw on several sources of learning — home, school, and a rebbe — rather than one track alone. It is a standalone change PRD; the superseded product-level PRD (`docs/planning/prd.md`, v2) is not amended. The document builds on the 2026-08-24 design session (`docs/brainstorming/brainstorm-multi-source-mishnayos-tracking-2026-08-24/`) and decisions made with Daniel on 2026-09-30, which override that session where they differ (see `.memlog.md`). The §3 Glossary defines the vocabulary. Section 4 contains the features and globally numbered FRs. Unconfirmed inferences carry inline `[ASSUMPTION]` tags and are indexed in §9. The `addendum.md` covers technical context, including existing codebase capabilities.

## 1. Vision

A boy going for all of Mishnayos by his bar mitzvah does not learn along one line. He learns at home on a plan his father set; he learns a masechta with his rebbe; he learns whatever his school is doing this year. All three cover ground in the same corpus and all three should move him toward the same siyum. Today the app sees only the first, so it asks him for nearly twice the daily load he really needs — and tells him, every day, that he is behind when he is not.

Sub-tracks make the app believe the truth about his life. The home plan keeps working exactly as it does today. Beside it, each outside source becomes a sub-track: a named, ordered piece of ground with one current position and an honest estimate of how fast it moves. Ground given to a sub-track leaves the home plan; ground a sub-track does not finish comes back. The daily target counts what the other sources will realistically cover — no more, no less.

Above all, it stays effortless for the child. He ticks what he learnt — at the moment he learns it or at bedtime — from one screen, in one gesture per source, and immediately sees the number go up, the masechta fill in, the streak hold, the siyum arrive. His father sees at a glance whether he is on track. His rebbe keeps his own sub-track true from his own phone. And the app refuses to be written to on shabbos, then makes catching up afterwards a single tap.

## 2. Target User

### 2.1 Jobs To Be Done

- **Child learner (holds the phone):** record what I learnt with almost no effort, wherever I learnt it; see my progress grow so I want to keep going; celebrate a siyum.
- **Parent (configures):** set the goal once and have the app ask for exactly the daily amount that is really needed, given what school and rebbe will cover; know at a glance that he is on track; not be told he is failing when he is not.
- **Rebbe / tutor (own phone):** keep my part of each talmid's learning accurate — what we are learning, how fast, where we are — across several talmidim.
- **Family (contextual):** use the app in a way that respects shabbos and yom tov.

### 2.2 Non-Users (v1)

- Schools as institutions: no school accounts, no class rosters, no imports from school systems. School ground is entered informally by the parent.
- Learners without a single corpus goal fed by multiple sources — they are served by the app as it is today and see no change.

### 2.3 Key User Journeys

> Protagonist names (Yehuda, Rav Cohen) are illustrative stand-ins.

- **UJ-1. Yehuda ticks his whole day in one sitting.**
  - **Persona + context:** Yehuda, 10, going for all of Mishnayos by his bar mitzvah; he holds the phone. His father set up his tracks.
  - **Entry state:** already signed in on his own profile; home screen.
  - **Path:** In the morning he learns at home and ticks today's mishnayos from the main-track list (or +1). At school and with his rebbe he does not touch the app. At bedtime he opens the home screen: on the School row he taps *up to…* where the class stopped; on the Rebbe row, the same. No navigation, no source picker — the source is the row he ticked in.
  - **Climax:** the mishnayos count rises, the masechta fills in, his streak holds for the day (home learning), and a siyum fires if a masechta just completed.
  - **Resolution:** his father, glancing at the same app, sees "on track" for the bar mitzvah.
  - **Edge case:** he ticked the wrong place on the School row — he (or his father, or his rebbe) corrects it; the count and target recompute.

- **UJ-2. Rav Cohen keeps his sub-track true for several talmidim.**
  - **Persona + context:** Rav Cohen learns Beitzah with Yehuda twice a week and has several talmidim on the app. Yehuda's father granted him tutor access.
  - **Entry state:** signed in on his own phone; list of his talmidim.
  - **Path:** He opens Yehuda, adds a "Rebbe" sub-track — mishnayos per week, weeks per year, and Beitzah as its ground. Weeks later they move to a new masechta; he adds it. When Yehuda ticked the wrong place, he fixes it.
  - **Climax:** Yehuda's home target reflects the rebbe's contribution; Yehuda's Rebbe row shows the right position.
  - **Resolution:** he sees each talmid's standing in one list.

- **UJ-3. Yehuda's father sets up this school year — informally, in pieces.**
  - **Persona + context:** the school announces nothing formally; Yehuda mentions in October that they are doing Berachos, perakim 1–3.
  - **Entry state:** parent on the child's profile, sub-tracks section.
  - **Path:** In September he adds a school-year sub-track for Sep 2026 – Jul 2027: name "School", 10 mishnayos per week, 39 weeks. No ground yet — the home target already drops to count school's expected learning. In October he adds Berachos perakim 1–3 as its ground. Those perakim grey out on the main track and stop being scheduled; the home target does not move, because school is still expected to cover the same amount this year.
  - **Climax:** if school's rate cannot finish that ground by July, he sees "School will not finish Berachos by Jul 2027 — about 40 mishnayos come back to you."
  - **Resolution:** in July the sub-track ends; whatever school did not finish returns to its original place on the main track. He taps *Add next year* and the next year's School sub-track is created from this one in one tap.
  - **Edge case:** Rav Cohen's sub-track also holds Berachos. The two sub-tracks do not affect each other — each keeps its own position.

- **UJ-4. Friday afternoon to Sunday: shabbos without logging.**
  - **Persona + context:** Yehuda learns at home on shabbos, but the app must not be written to.
  - **Path:** On erev shabbos he sees what is planned for shabbos. From before candle-lighting the app is locked: he can open it and read the plan, but nothing can be tapped and the on-target indicator does not change. After shabbos — motzei shabbos or any time on Sunday — a catch-up card asks "Shabbos · 14 mishnayos planned — learnt them all?" He taps *Yes, all of it*, or *Adjust…*.
  - **Climax:** the ticks are dated to shabbos, not to when he tapped; his streak is intact.
  - **Resolution:** the same works for yom tov, including a three-day yom tov and shabbos.

- **UJ-5. First run: sub-tracks are mentioned, not set up.**
  - **Path:** A new family goes through onboarding and sets up the main track and goal as today. One screen mentions that school and rebbe sub-tracks can be added later from the menu; nothing about them is asked.
  - **Climax:** families who never need sub-tracks never see them again; families who do know where to find them.

- **UJ-6. One mishna, a whole life.**
  - **Path:** Yehuda taps Berachos 1:1 and sees every time he learnt it — before tracking, at home, again at school, again with his rebbe — with dates and sources. His father exports a lifetime report and a per-source report.
  - **Climax:** repeats never inflate progress toward the bar mitzvah but always enrich the record.

## 3. Glossary

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

## 4. Features

### 4.1 Effortless capture

**Description:** The child records learning from the home screen with no navigation. The main track keeps its current task list. Beneath it, each active sub-track is one row showing its name and current position, with *+1* and *up to…*. The source of every learning event is implied by where it was ticked. Capture happens at the moment of learning or in one bedtime sitting. Realizes UJ-1.

#### FR-1: Home-screen sub-track rows
The child can see every active sub-track as one row on the home screen, beneath the main track's tasks, showing the sub-track name and its current position. Realizes UJ-1.

**Consequences (testable):**
- Each active sub-track renders exactly one row regardless of how many masechtos its ground holds.
- The main track's today list renders exactly as before this change.
- Ended sub-tracks do not appear on the home screen.

#### FR-2: +1 and up to…
The child can record learning on a sub-track row with *+1* (the current position) or *up to…* (the current position through a chosen later mishna in that sub-track's order), in one gesture. Realizes UJ-1.

**Consequences (testable):**
- *up to…* creates one learning event per mishna from the current position to the chosen mishna inclusive, in the sub-track's order.
- After the gesture, the sub-track's current position is the next mishna in its order not yet ticked in that sub-track.
- Every event created carries the sub-track as its source without a prompt.
- A sub-track with no ground yet shows its row with a prompt for the parent or tutor to add ground; the child cannot tick on it until ground exists. Its capacity still counts in the forecast (FR-19).

#### FR-2a: Up to… with individual adjustment, everywhere
Wherever the child records a run of learning — a sub-track row, the main track's today list, or the catch-up card — he can tap *up to…* a mishna and then untick or tick individual mishnayos within the run before confirming.

**Consequences (testable):**
- The main track's today list offers *up to…* in addition to ticking each task, without changing how tasks are generated.
- Adjusting individual mishnayos before confirming creates events only for the mishnayos left ticked.

#### FR-3: Free tick and tick-to-here in the corpus browser
The child or parent can open the corpus browser and mark any node at any level as learnt, including *tick-to-here* (a mishna and everything before it in corpus order within its masechta), for out-of-schedule learning, jumping ahead, and backfill.

**Consequences (testable):**
- A batch of free ticks asks for the source once, defaulting to the main track (home).
- A batch can be marked *before tracking*; before-tracking events never count toward streaks or velocity.
- The event date defaults to today and is editable at capture.
- Free ticks count toward the streak only when their source is the main track and their date is the day being counted.

#### FR-4: Correct a mistake
The child, parent or tutor can undo or correct a learning event (wrong place, wrong source, wrong date). Realizes UJ-1 edge case.

**Consequences (testable):**
- A corrected or removed event no longer counts toward goal progress, streaks, or velocity.
- The daily target and positions recompute immediately.
- A correction voids the original event and, where needed, records a replacement; voided events are hidden from the child's lifetime record but remain visible, with who and when, in the parent's change history (FR-27).
- The child can re-date an event only within the catch-up window (FR-25); older corrections by the child are limited to removal.
- A correction never creates or restores a streak day for a date other than the one the child is correcting within the catch-up window.

### 4.2 Sub-tracks

**Description:** A sub-track represents one outside source. The parent or tutor creates it from a small form; everything about the source is entered where the source is created. School-year sub-tracks follow the academic year and are chained year to year; ongoing sub-tracks just run. Realizes UJ-2, UJ-3.

#### FR-4a: Sub-tracks are optional and found in the menu
Sub-tracks are an optional extra. They are created from the menu, never prompted for. Onboarding mentions that school and rebbe sub-tracks can be added, but does not set them up. Realizes UJ-5.

**Consequences (testable):**
- Onboarding contains one mention of sub-tracks with where to find them, and no sub-track fields or steps.
- The app never prompts a learner or parent to create a sub-track.
- A learner with no sub-tracks sees no sub-track section on the home screen.

#### FR-5: Create a school-year sub-track
The parent or tutor can create a school-year sub-track with: name; academic year from a picker (September–July by default; start and end months editable); mishnayos per week; weeks per year (pre-filled, editable). Realizes UJ-3.

**Consequences (testable):**
- The picker offers only academic years from the current one through the one containing the deadline (or, with no deadline, the current year and the next two).
- An academic year that already has a school-year sub-track cannot be chosen.
- Edited start/end months carry over to *Add next year* (FR-7); school-year windows may not overlap.
- Weeks per year is pre-filled at 39 and editable; the form has no exclusion checkboxes.
- A sub-track created for the current, part-elapsed academic year counts only the remaining weeks of its window `[ASSUMPTION: prorated by the fraction of the window remaining]`.

#### FR-6: Create an ongoing sub-track
The parent or tutor can create an ongoing sub-track with: name; mishnayos per week; a *not learning during bein hazmanim* option (unticked by default) that only adjusts the pre-filled weeks figure; optional start date (FR-6a); weeks per year (editable); optional end date. Realizes UJ-2.

**Consequences (testable):**
- At most five ongoing sub-tracks can be active at once; ended ones do not count toward the five.
- Toggling bein hazmanim changes the pre-filled weeks per year and nothing else; a user-edited value is never overwritten.

#### FR-6a: Future start
An ongoing sub-track may be given an optional start date in the future.

**Consequences (testable):**
- Before its start date it contributes to the forecast from its start date and does not appear on the home screen.

#### FR-6b: Learns on shabbos / yom tov
Any sub-track can be marked *learns on shabbos / yom tov* (default off).

**Consequences (testable):**
- Only marked sub-tracks appear on the catch-up card (FR-25).

#### FR-7: Add next year
The parent or tutor can create next year's school-year sub-track from an existing one in one action, copying name, rate and weeks, with every field editable before saving. Realizes UJ-3.

**Consequences (testable):**
- The new sub-track's window is the following academic year.
- Its ground starts empty.

#### FR-8: Edit and delete sub-tracks
The parent or tutor can edit any field of a sub-track and delete a sub-track. Realizes UJ-2.

**Consequences (testable):**
- Editing the rate estimate recomputes the daily target immediately.
- Deleting a sub-track returns its unfinished ground to the main track (FR-12); its learning events remain in the lifetime record.

#### FR-9: Sub-track detail
The child, parent or tutor can open a sub-track and see its ordered ground and tri-state progress across all its masechtos.

**Consequences (testable):**
- The detail shows the current position, the count of mishnayos ticked in this sub-track, and capacity vs remaining path (FR-19).
- Mishnayos learnt elsewhere render as learnt (tri-state) but do not move this sub-track's current position.

### 4.3 Ground

**Description:** Ground moves between the main track and sub-tracks at exactly two moments: when it is assigned to a sub-track, and when a sub-track ends. Otherwise tracks are independent. School ground is informal: a masechta or a few perakim, entered whenever the family learns what school is doing. Realizes UJ-3.

#### FR-10: Assign ground to a sub-track
The parent or tutor can add any masechta, perek or mishna to a sub-track at any time, incrementally. Realizes UJ-3.

**Consequences (testable):**
- Ground assigned to any sub-track is no longer scheduled by the main track and is shown greyed out there, so the child still sees the whole masechta.
- The same mishna may be assigned to more than one sub-track at once.
- A sub-track may be assigned ground that is already learnt; learning it there is chazara.
- Within one sub-track, a mishna appears at most once in its order.
- The main track holds each mishna at most once.

#### FR-11: Order ground within a sub-track
The parent or tutor can order a sub-track's ground; the sub-track has exactly one current position in that order.

**Consequences (testable):**
- Newly added ground is appended to the end of the sub-track's order by default and can be moved.
- Reordering never removes ticks; the current position becomes the first mishna in the new order not yet ticked in this sub-track.
- Reordering recomputes the forecast (FR-19).

#### FR-12: Return ground when a sub-track ends
When a sub-track ends — its school year finishes, its end date passes, or it is deleted — its unfinished ground returns to the main track. Realizes UJ-3.

**Consequences (testable):**
- Only mishnayos not learnt by any source return; learnt mishnayos stay learnt and are not rescheduled.
- Returned mishnayos re-enter the main track at their original position in its order, not appended.
- The main track's schedule and daily target recompute on return.
- Ground also assigned to another, still-active sub-track does not return to the main track until no active sub-track holds it.

#### FR-12a: One masechta at a time on the main track
The main track schedules from one masechta at a time. To learn another masechta concurrently, the parent or tutor adds a sub-track.

**Consequences (testable):**
- The main track never schedules mishnayos from two masechtos on the same day — except on the day one masechta finishes and the next begins, when that day's tasks may span both.
- Returned ground (FR-12) that lies before the main track's current masechta in its order is scheduled next, after the current masechta completes.

#### FR-13: Tracks are independent
Learning in one track never moves another track's current position.

**Consequences (testable):**
- Ticking Berachos 2:3 on the Rebbe sub-track leaves the School sub-track's current position unchanged, even if School's ground contains Berachos 2:3.
- The mishna is nonetheless *learnt* for goal progress, whichever track ticked it.

### 4.4 Progress and motivation

**Description:** What makes the child want to open the app tomorrow: a number going up, streaks, siyumim. What the parent wants: on-track at a glance. Realizes UJ-1, UJ-6.

#### FR-14: Goal progress counts distinct mishnayos
Goal progress is the count of distinct learnt mishnayos in the corpus, from all sources and all date states.

**Consequences (testable):**
- A second learning event for the same mishna (chazara) does not change goal progress.
- Before-tracking events count toward goal progress.

#### FR-15: Tri-state everywhere
Every corpus node renders empty (no descendant learnt), partial (some) or complete (all) — in the main corpus view, the corpus browser, the ground picker, and every sub-track detail.

**Consequences (testable):**
- A single learnt mishna renders its perek, masechta and seder partial.

#### FR-16: Streaks count home learning only
The streak is kept by main-track (home) learning. Sub-track learning never extends or keeps a streak. Realizes UJ-1, UJ-4.

**Consequences (testable):**
- A day with only sub-track events does not extend the streak, but sub-track learning is always celebrated in the count, masechta fill and siyum; no screen tells the child that school or rebbe learning "doesn't count".
- A day covered by a capture lock does not break the streak if its catch-up is completed within the catch-up window (FR-23).

#### FR-17: Siyum
A siyum celebration fires once when a masechta becomes fully learnt (distinct mishnayos), whichever source completed it.

**Consequences (testable):**
- Completing a masechta a second time (chazara) does not re-fire the siyum.
- A masechta completed entirely in a sub-track fires the siyum.

#### FR-18: On track at a glance
The parent can see from the home screen whether the learner is on track for the deadline, without opening a report. The child sees encouragement only. Realizes UJ-1.

**Consequences (testable):**
- *On track* = the projected finish date is on or before the deadline, where the projected finish date extrapolates observed velocity — distinct mishnayos newly learnt per day, all sources, excluding before-tracking events and chazara — over the trailing 4 weeks.
- The parent view shows the projected finish date (e.g. "at this pace: finishes Adar 5789").
- A single unusually large day does not flip the status from off track to on track unless the trailing-4-week projection crosses the deadline.
- The child's view never shows "behind" or "off track"; it shows today's progress against the daily target and the streak.
- With fewer than 2 weeks of tracked history, the parent sees "too early to tell" instead of a projection and status; from 2 to 4 weeks the projection uses all tracked history.

### 4.5 Forecast

**Description:** The daily target counts what the other sources will realistically cover. Every sub-track gets credit for its full capacity: entered ground has already left the main track, and capacity beyond the entered ground is expected to cover ground not yet entered — so entering ground bit by bit never makes the target jump. Ground a sub-track will not reach in time is counted back in now, rather than landing on the child when the sub-track ends. Realizes UJ-3, UJ-5.

#### FR-19: Daily target
With a deadline set, the main track's daily target is:

```
( main-track remaining
  − Σ over sub-tracks:  expected new ground
  + Σ over sub-tracks:  shortfall )
÷ days to deadline
```

For each active sub-track:
- *capacity* = rate estimate × active weeks left in its window before the deadline.
- *path* = the sub-track's ordered ground from its current position to the end — every mishna on it, learnt or not, because the sub-track must pass through all of them.
- *shortfall* = unlearnt mishnayos on the path beyond what capacity reaches. They will return to the main track when the sub-track ends (FR-12).
- *expected new ground* = max(0, capacity − path length). A sub-track that will finish its entered ground is expected to keep going onto ground not yet entered (a sub-track with no ground: its whole capacity).

*Main-track remaining* = mishnayos not learnt and not assigned to any active sub-track. *Days to deadline* counts the main track's existing study days (default: all seven).

**Consequences (testable):**
- The daily target is never negative; when sub-tracks are forecast to cover everything remaining, the target is 0 and the child sees "all covered — any extra learning is a bonus".
- Entering ground into a sub-track whose capacity exceeds its path does not change the daily target. (School at 10/week with no ground, then Berachos 1–3 added: target unchanged.)
- Shortfall counts only unlearnt mishnayos; time spent on already-learnt mishnayos on the path (chazara) is counted against capacity.
- A mishna counted as shortfall on one sub-track is not counted as shortfall again on another, and is not counted if another active sub-track holding it is forecast to reach it.
- Changing the main-track order, assigning or returning ground, editing a rate estimate, or recording learning recomputes the daily target.
- Two sub-tracks' expected new ground both count in full, even if their future learning overlaps — accepted consequence of track independence (FR-13).

#### FR-20: No deadline, no required rate
With no deadline, the app shows the projected finish date (FR-18 definition) and no daily target or on-track status.

**Consequences (testable):**
- No sub-track rate estimate affects anything shown when there is no deadline.

#### FR-21: Shortfall warning
When a sub-track has a shortfall, the parent sees a warning naming the sub-track, the ground, the window end and the approximate number of mishnayos that will come back. Realizes UJ-3.

**Consequences (testable):**
- The warning appears whenever shortfall > 0 and disappears when it returns to 0.
- The number shown equals the shortfall in FR-19.
- The child never sees the warning.

#### FR-22: *(withdrawn)*

### 4.6 Shabbos and yom tov

**Description:** The app cannot stop a phone being used on shabbos, but it refuses to record. Before the lock it shows what is planned; during the lock it is read-only; after it, catching up is one tap and dated honestly. Extends the existing zmanim-based shabbos/yom tov windows. Realizes UJ-4.

#### FR-23: Capture lock
From before candle-lighting until after tzeis on shabbos and yom tov, no write action is possible anywhere in the app; the app remains readable. The lock fails closed: a false lock is harmless, a false unlock is the failure that matters.

**Consequences (testable):**
- Every capture and edit control is disabled during the lock, on every device signed in to the learner's profile, including a tutor's.
- The lock starts 10 minutes before candle-lighting and ends 10 minutes after tzeis at the learner's location.
- Israel / chutz la'aretz is a per-learner setting, defaulted from location and changeable, and decides one- vs two-day yom tov; location decides zmanim.
- If zmanim cannot be determined (no location, no computed windows), the app locks conservatively from Friday 12:00 to Sunday 01:00 local device time (and the equivalent around yom tov) and prompts the parent to set a location.
- Where tzeis cannot be computed (high latitudes), the app uses a conservative fixed fallback and still fails closed.
- Writes queued offline are dated to when the child performed them; any write whose timestamp falls inside a lock window is rejected on sync.
- The on-track indicator does not change during the lock.

#### FR-24: Planned view
Before and during the lock, the learner sees what is planned for the locked day(s). The erev view and the locked view are the same screen.

**Consequences (testable):**
- The planned list is frozen when the lock begins and does not change until it ends.
- The locked view has no tappable controls.

#### FR-25: Catch-up card
After the lock ends, a catch-up card offers "learnt them all?" (one tap) or *Adjust…*, which opens the planned list with *up to…* and individual ticks (FR-2a), one list per locked day. Realizes UJ-4.

**Consequences (testable):**
- The card is available from the end of the lock until the end of the first full non-locked day after it (motzei shabbos through Sunday). If another lock begins before that day ends (yom tov running into shabbos), the window pauses and resumes after the next lock; pending cards stack.
- Events created from the card are dated to the locked day(s) they cover, with date state *catch-up dated*.
- It covers up to three consecutive locked days.
- A reminder notification fires when the card becomes available.
- The card covers the main track and every sub-track marked *learns on shabbos / yom tov* (FR-6b); each such sub-track appears with *up to…* for the locked day(s). Sub-tracks not so marked never appear on the card.

### 4.7 Tutor access

**Description:** A rebbe uses his own phone, sees all his talmidim, and can maintain a talmid's tracks. Builds on existing tutor access. Realizes UJ-2.

#### FR-26: Tutor edits
A tutor granted access to a learner can do everything the parent can do on that learner's tracks — the main track, the deadline, and all sub-tracks.

**Consequences (testable):**
- Every change made by a tutor is recorded with the tutor's identity and time (FR-27).
- A tutor sees only learners whose parent granted them access, and nothing about the family beyond that learner's learning.

#### FR-27: Change history and undo
The parent can see a history of every change made by a tutor to the learner's tracks, goal, and learning events, and undo any of them. Realizes UJ-2.

**Consequences (testable):**
- Each history entry shows who, what, and when (e.g. "Rav Cohen changed the deadline · 3 Nov").
- Undoing a tutor change restores the prior state and is itself recorded.
- The parent is notified when a tutor changes the deadline or the main track; sub-track changes appear in the history without notification.

#### FR-28: Revoking a tutor
The parent can revoke a tutor's access at any time.

**Consequences (testable):**
- Revocation removes the tutor's access immediately on next sync.
- Sub-tracks the tutor created, and every learning event, remain with the learner unchanged.

#### FR-29: Multi-talmid list
A tutor can see all learners who granted them access in one list with each one's on-track status, and open any one. Realizes UJ-2.

**Consequences (testable):**
- The list shows only learners with an active grant; a revoked learner disappears from it.

### 4.8 Lifetime record and reports

**Description:** Every learning event is kept for life. The goal is one milestone in a record that continues. Realizes UJ-6.

#### FR-30: Mishna history
The child or parent can tap any mishna and see every learning event for it: date (or *before tracking*), source, and count.

**Consequences (testable):**
- The count equals the number of non-voided learning events for that mishna.
- Events of deleted sub-tracks remain, labelled with the sub-track's name.

#### FR-31: Lifetime report
The parent can view and export a lifetime report of all learning, continuing after the goal is reached. Sub-tracks with the same name (e.g. one school across several years) roll up into one row, expandable by year.

**Consequences (testable):**
- The report includes distinct mishnayos learnt, total learning events, and totals per source.
- Recording continues after the goal is complete.

#### FR-32: Per-source report
The parent can view and export (PDF) velocity per source since tracking started, and on-track status.

**Consequences (testable):**
- Before-tracking events never appear in velocity.
- Catch-up-dated events count on the day learnt, not the day entered.

### 4.9 Cross-cutting: offline and concurrent edits

- All capture works offline and syncs later; learning events from different devices never overwrite one another.
- When a parent and a tutor edit the same sub-track or goal concurrently, the later change wins and both appear in the change history (FR-27).
- Recomputing the daily target after any change completes fast enough that the new number is visible on the same screen `[ASSUMPTION: under 1 second on a mid-range device]`.

### 4.10 Cross-cutting: children's data

- Learner data, including what tutors can see and change, follows the app's existing child-data rules (`docs/privacy-policy.md` §Children's Privacy, §Data Retention and Deletion): a parent creates the account; account deletion removes all associated data, including sub-tracks, learning events and change history.
- The privacy policy must be updated before release to disclose that a parent-granted tutor can view and edit the learner's learning data, and that tutor changes are recorded in a history visible to the parent.

## 5. Non-Goals (Explicit)

- No change to how the main track plans or generates tasks; one masechta at a time on the main track stays.
- No sub-goals or sub-track deadlines ("finish Moed before Pesach"). One deadline, on the main track.
- No school calendars, term dates, imports or per-country school logic. One weeks-per-year number per sub-track.
- No school accounts or school-side logging.
- Sub-tracks are optional and are never prompted or suggested to families.
- No cross-track position sync or dedupe; overlap between sub-tracks is allowed and not reconciled.
- No app-learned calendars, confidence intervals, or self-correcting rate suggestions in v1.

## 6. MVP Scope

### 6.1 In Scope
- Capture: home rows, +1, up to… with individual adjustment, free tick, tick-to-here, correction (FR-1–FR-4, FR-2a).
- Both sub-track types, add next year, edit/delete, detail (FR-5–FR-9).
- Optional sub-track availability and onboarding mention (FR-4a).
- Ground assignment, ordering, return, independence (FR-10–FR-13).
- One masechta at a time on the main track (FR-12a).
- Progress: distinct counting, tri-state, streak rule, siyum, on-track glance (FR-14–FR-18).
- Forecast: daily target, no-deadline projection, shortfall (FR-19–FR-21).
- Shabbos/yom tov lock, planned view, catch-up (FR-23–FR-25, FR-6b).
- Tutor edits, change history and undo, revocation, multi-talmid list (FR-26–FR-29).
- Lifetime record and reports (FR-30–FR-32).

### 6.2 Out of Scope for MVP
- Warm/cold chazara prompts — offered in the session, not adopted.
- Year-total estimate instead of rate × weeks — not adopted.
- Grouping a school's year-by-year sub-tracks into one row in the lifetime report — included in FR-31.
- `[NOTE FOR PM]` Delivery order (stages) is a planning decision for epics; the brainstorm's order was minors → sub-tracks → shabbos.

## 7. Success Metrics

**Primary**
- **SM-1: Daily capture.** Share of days on which the learner records any learning (home or sub-track) — target ≥ 80% of non-locked days over 4 weeks. Validates FR-1–FR-3 and FR-2a.
- **SM-2: Sub-track adoption.** Share of multi-source learners with ≥ 1 active sub-track that has events in the last 14 days. Validates FR-4a–FR-10.

**Secondary**
- **SM-3: Catch-up completion.** Share of locked days caught up within the catch-up window — target ≥ 90%. Validates FR-16 and FR-23–FR-25.
- **SM-4: Capture effort.** Median taps to record a full day's learning across all sources — target ≤ 4. Validates FR-2 and FR-2a.
- **SM-5: Forecast honesty.** Difference between forecast and actual distinct mishnayos learnt per source over a school year. Validates FR-19.

**Counter-metrics (do not optimize)**
- **SM-C1: Events per day.** Do not optimize — *up to…* and chazara make raw event counts easy to inflate. Counterbalances SM-1.
- **SM-C2: Streak length.** Do not optimize — streak pressure must never push a child to log on shabbos or to log learning that did not happen. Counterbalances SM-3.

## 8. Open Questions

None blocking. Non-blocking items are deferred in §8.1.

### 8.1 Deferred review findings (non-blocking)

| Finding | Owner | Revisit when |
|---|---|---|
| Rate estimates are never checked against observed per-source velocity (no "school is really running at 7/wk — update?") | PM | Per-source report (FR-32) shows estimate vs actual diverging > 25% for a month in real use |
| Proration arithmetic for part-elapsed windows and ongoing windows crossing the deadline | Architect | Architecture design of FR-19 |
| Siyum edge cases: masechta completed via backfill, via correction, or un-completed by a void | UX | UX spec for FR-17 |
| One-tap "Yes, all of it" makes over-reporting the easy path | PM | Parent feedback or SM-C1 anomaly after release |
| Exact corpus definition and mishna count (numbering edition) | Architect | Content DB mapping for FR-14 |
| Ground assigned to a future sub-track is unavailable to the main track until then | PM | First real report of blocked home learning |
| Rationale for the five-ongoing and one-school-per-year limits | PM | User requests exceeding either limit |
| Measurement method for SM-1–SM-5 (analytics events) | Architect | Analytics design before release |
| Existing users: prompt for study days / goals when first adding a sub-track | UX | UX spec for FR-5/FR-6 |

## 9. Assumptions Index

- §4.2 FR-5 — a sub-track created for the current, part-elapsed academic year uses only the remaining weeks of its window, prorated by the fraction of the window remaining.
- §4.9 FR-19 — daily-target recomputation completes in under one second on a mid-range device.
