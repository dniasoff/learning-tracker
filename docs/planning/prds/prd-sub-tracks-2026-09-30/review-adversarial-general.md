---
title: "Adversarial review: PRD Sub-tracks"
reviewed: prd.md (draft, 2026-09-30), with addendum.md, .memlog.md, extract-code-reality.md as context
method: bmad-review-adversarial-general
date: 2026-09-30
---

# Adversarial review: PRD Sub-tracks

**Verdict:** Not ready for epics. The forecast formula FR-19 gives wrong targets for the exact journey it was written for (UJ-3). The shabbos lock is specified without a fail-closed rule, even though the current code fails open. Tutor rights are too broad to ship publicly for children's data.

**Counts:** Critical 4 · High 11 · Medium 12 · Low 7 (34 total)

---

## Critical

### C1. Adding ground in pieces removes the sub-track's rate credit, so the daily target jumps up (FR-19, UJ-3, FR-10)
- **Location:** §4.5 FR-19 formula; UJ-3 path ("No ground yet ... In October he adds Berachos perakim 1–3").
- **Problem:** FR-19 has two cases. A ground-less sub-track lowers the load by `rate × weeks left`. A sub-track with ground lowers it only by the ground's size, because that ground has already left the main track. In UJ-3 School is 10/week × 39 weeks, which is about 350 mishnayos of credit. When the father adds Berachos 1–3 (about 16 mishnayos), the credit falls from about 350 to 16, and the home target rises by about 330 ÷ days-to-deadline overnight. This happens even though nothing about school's real throughput changed. Every later "informal, in pieces" addition swings the target again. The shortfall term (`max(0, ground − capacity)`) quietly throws away all unused capacity. The PRD's own consequence ("Assigning ground never lowers the target by more than that ground's size") is true. It hides the real issue, which is that assigning ground *raises* the target by as much as the whole remaining capacity.
- **Fix:** Model a sub-track as capacity that is used up by ground. Per sub-track, `contribution = min(capacity, assigned unlearnt ground) + max(0, capacity − assigned ground walk-length)`. The second term is the unassigned residual, treated like the ground-less case. Shortfall = `max(0, walk-length − capacity)`. Add a testable consequence: "Assigning ground a sub-track can finish within its window never changes the daily target."

### C2. Shortfall counts only unlearnt ground, but the sub-track's position walks through learnt ground too (FR-19, FR-10, FR-2, FR-13)
- **Location:** FR-19 definition of *shortfall* ("unlearnt assigned ground − rate × active weeks"); FR-10 ("may be assigned ground that is already learnt; learning it there is chazara"); FR-2/FR-13 (position = next mishna not ticked *in that sub-track*).
- **Problem:** The rate is how many mishnayos the source moves per week *along its own order*. FR-13 makes each sub-track walk every mishna in its ground, including ground learnt at home, before tracking, or by another sub-track. Chazara uses up rate. Example: 100 mishnayos of ground, 60 already learnt, capacity 50. FR-19 gives shortfall = max(0, 40 − 50) = 0. In reality the class covers 50 in order and learns about 20 new ones, so about 20 return in July that the forecast never warned about. Overlap makes it worse. When Rebbe learns a mishna that School also holds, School's "unlearnt ground" shrinks but School still has to walk over it. So every tick elsewhere makes School's shortfall look smaller. The app will say "on track" and then drop a pile of returned ground on the child in July. That is the failure the Vision promises to avoid.
- **Fix:** Compute shortfall from the *walk* instead: the mishnayos from the sub-track's current position to the end of its order, learnt or not. Count as covered only the unlearnt mishnayos that fall within the first `capacity` positions of that walk. Add a consequence with the 100/60/50 example as a test vector.

### C3. The capture lock has no fail-closed rule, and the current code fails open (FR-23, addendum §1 `sacred_time`, addendum §2)
- **Location:** FR-23; addendum row `sacred_time` ("a current lock state is provided *when windows are available*"); addendum §2 ("bias toward remaining locked if lock state cannot be established"), which is not in the PRD.
- **Problem:** The only fail-closed statement is an implementation note in the addendum. The PRD's testable consequences do not require it, and the existing provider gives no lock when there is no location or no computed windows. Other fail-open paths:
  - (a) Location is not set, or location permission is denied.
  - (b) Location is stored per device in SharedPreferences, "global across profiles". So a tutor's or parent's device locks by *its own* location, not the learner's. FR-23 says "learner's location", which the code cannot supply.
  - (c) The six-month window cache runs out while the device is offline or the app has not been opened for a long time.
  - (d) The device clock or time zone is wrong or manually changed.
  - (e) `kosher_dart` returns null for tzeis at high latitudes in summer.
  - (f) Enforcement is client-side only, so an old app build, a web client or a tutor device writes freely. Firestore rules do nothing.
  - (g) Offline writes queued on shabbos by a device that believes it is a weekday sync without any check.
- **Fix:** Add FR-level consequences:
  - When the lock state cannot be established, capture is locked on Friday and erev yom tov afternoons, with a visible "set your location" fix.
  - The lock is computed for the *learner's* stored location and minhag (Israel/chutz), not the device's.
  - Tutor and parent writes to a learner are locked by the learner's window.
  - Events whose timestamp or `completedAt` falls inside the learner's window are rejected server-side, except catch-up events.
  - Every one of (a)–(g) is listed as a test case.

### C4. Tutor "everything" rights plus no consent model is a child-data liability for public release (FR-26, FR-27, FR-4, FR-28–30)
- **Location:** FR-26 ("everything the parent can do ... main track, the deadline, and all sub-tracks"); FR-27; addendum row "Tutor grants" ("No tutor-account attribution on completions").
- **Problem:** A third-party adult gets full read access to a minor's complete lifetime record and per-source performance. They also get write access to the deadline, the main track, other tutors' sub-tracks and learning events (FR-4 lets a tutor "correct" or void the child's ticks).
  - Nothing says the parent is notified of tutor changes, can see an audit trail, or can undo them.
  - Nothing limits a tutor to his own sub-track.
  - Nothing covers what happens to his sub-tracks and attributed events after revocation.
  - Nothing says how a grant is issued or accepted (invite link? code? expiry?), which leaves room for phishing or a hijacked grant.
  - "Every change attributed to that tutor" is untestable today, because attribution does not exist.
  - Public release with child users brings COPPA / GDPR-K / app-store Kids-category obligations: verifiable parental consent, data minimisation, deletion rights, and no third-party analytics. §7 metrics need analytics on children. None of this is in scope, non-goals or open questions.
- **Fix:**
  - Split tutor rights into *own sub-tracks* (default) and *full* (an explicit parent opt-in, with a warning).
  - Add FRs for: parent-visible audit log with undo; parent notification on deadline or main-track change; grant issuance and acceptance with expiry.
  - Define what revocation does with the tutor's sub-tracks: they stay owned by the parent and keep contributing, or are ended with their ground returned. Pick one.
  - Add a child-data section: consent, retention, export, erasure (reconcile with "every learning event is kept for life"), and analytics limits.

---

## High

### H1. Overlapping ground double-counts the add-back and loads the target with ground the main track may not schedule (FR-19, FR-12, FR-10)
- **Location:** FR-19 `Σ shortfall` summed per sub-track; FR-12 last consequence; FR-10 "same mishna may be assigned to more than one sub-track".
- **Problem:** If Berachos 2 is in both School and Rebbe and both are short, it is added back twice. If School will finish it but Rebbe won't, Rebbe's shortfall still adds it back. It is never learnt at home, and it will not return (FR-12) while School holds it. Even without overlap, the shortfall is added to today's target while the main track is forbidden to schedule that ground until the window ends. Near the end of the corpus, when main-track remaining is 0, the target asks for mishnayos the main track has nothing to schedule. The consequence "No mishna contributes to the reduction twice" only guards the reduction side, not the add-back.
- **Fix:** Compute the add-back over the *union* of assigned ground. A mishna counts toward the add-back only if no active sub-track's walk is forecast to cover it in time. Add a consequence: "No mishna contributes to the add-back more than once." Define what the main track shows when the target is greater than 0 and no schedulable ground is left, for example by offering early return of shortfall ground.

### H2. The glossary's "current position" contradicts FR-2 and FR-13 (§3, FR-2, FR-13)
- **Location:** §3 "Current position — the next *unlearnt* mishna in a track's own order. Every track has exactly one."; FR-2 "next mishna ... not yet ticked *in that sub-track*".
- **Problem:** "Unlearnt" is the goal-level definition (learnt anywhere). Under it, a Rebbe tick moves School's position, which violates FR-13. An implementer who follows the glossary will build the opposite of FR-13. For the main track, the meaning after sub-track or free-tick learning is also unclear.
- **Fix:** Define position per track type. Sub-track: the first mishna in its order with no event whose source is that sub-track. Main track: the first mishna in its order not learnt by any source (confirm this). Add a main-track test to FR-13.

### H3. "On track" is circular, and "discard stale backlog" contradicts "main track unchanged" (FR-18, FR-19, §5)
- **Location:** FR-18 assumption ("≥ the amount the forecast required by today"); FR-19 consequence ("recording learning recomputes the daily target, discarding any stale backlog"); §5 "No change to how the main track plans or generates tasks"; addendum reorder amnesty.
- **Problem:** If every tick and every day recomputes from the current remaining load, "what the forecast required by today" is always exactly met by definition. A learner who does nothing for a month never shows "behind"; his target just creeps up quietly. That fails the parent JTBD ("know at a glance"). Discarding backlog on every tick also changes current main-track behaviour (overdue items, amnesty), which §5 and FR-1 ("renders exactly as before") say will not change.
- **Fix:** Anchor on-track to a baseline curve fixed when the plan was last set (deadline, ground or rate changes). Compare distinct learnt mishnayos to that curve. Add a rule for which events rebase the curve. State explicitly which existing overdue and backlog behaviour changes, and update §5 and FR-1.

### H4. The catch-up window breaks streaks in real calendars (FR-16, FR-25)
- **Location:** FR-25 ("from the end of the lock until the end of the following day"; "up to three consecutive locked days"); FR-16; .memlog ("the day after, plus one further day"), which already disagrees with FR-25.
- **Problem:**
  - Yom tov ending Thursday night (chutz la'aretz) gives a "following day" of Friday, which is cut off by the next lock. The card has a few busy erev-shabbos hours, and by motzei shabbos the yom tov card has expired.
  - Pesach and Sukkos in chutz la'aretz with shabbos next to a yom tov day produce lock sequences separated by less than a day, so cards overlap or queue.
  - Israel's single day of yom tov next to shabbos needs its own test.
  - A child who forgets on Sunday loses a streak for learning he did, which is a failure framing for a clerical miss.
  - The .memlog says "plus one further day"; the PRD says only the following day.
  - Sub-track shabbos learning is caught up through a date-editable row that FR-2 does not define.
- **Fix:** Make the window "until the end of the first full non-locked day after the lock, plus one more day", pausing through any lock in between. Let pending cards stack. Add test vectors for: RH Thu–Fri + shabbos; YT Wed–Thu (chutz) + shabbos; YT Thu (Israel) + shabbos; Pesach first days in both locales. Reconcile with the memlog. Specify date editing on sub-track rows as an FR.

### H5. Israel vs chutz is a person's status, not a location, and travel and time zones are unaddressed (FR-23)
- **Location:** FR-23 "follows the learner's location and Israel / chutz la'aretz setting".
- **Problem:** A ben chutz la'aretz visiting Israel keeps two days, and an Israeli abroad keeps one. So "follows location" gives the wrong lock and wrong catch-up days for exactly the families who travel for yom tov. Unspecified: whether location is GPS or manual; what happens when the time zone changes mid-shabbos on a flight; which date line and time zone define "the day learnt" for events, streaks and days-to-deadline. A tutor in Yerushalayim ticks for a talmid in London using which date?
- **Fix:** Split *zmanim location* (where you are now) from *minhag* (Israel or chutz, a profile field). Define the day boundary: the learner's local civil midnight, or say explicitly that it is not sunset. All event dates come from the learner's time zone, not the device's. Add travel test cases.

### H6. No floor, cap or infeasibility state on the daily target (FR-19, FR-18, §2.1)
- **Location:** FR-19 formula.
- **Problem:** Ground-less credit can be larger than main-track remaining, which gives a negative target. Late ground assignment, shortfall add-back or an approaching deadline can push a 10-year-old's target to 25+/day with no "this deadline is no longer realistic" state. Both results are shown to the child, and the second is pressure framed as failure.
- **Fix:** Clamp the target at 0 and show "home plan complete if others deliver". Set a parent-configured ceiling, above which the parent (not the child) sees an infeasibility prompt offering to move the deadline, add help, or accept. Add consequences for both.

### H7. The home-only streak tells the child his rebbe and school learning "doesn't count" (FR-16, UJ-1, SM-1)
- **Location:** FR-16; UJ-1 "streak holds for the day (home learning)"; SM-1 counts any learning.
- **Problem:** A sick day, a trip, or a day spent only with the rebbe breaks the streak even though the child learnt. The motivation system then ranks sources, which contradicts the Vision ("all three should move him toward the same siyum"). Also, bedtime logging after midnight dates the ticks to the next day and breaks the streak unless H5's day boundary handles late-night capture. There is no grace or freeze, and nothing specifies how a broken streak is presented.
- **Fix:** Either count any-source learning toward the streak, or give the child a one-tap "learnt with rebbe today" that keeps it. Add a streak grace or freeze. Add a bedtime rule, for example that ticks before 04:00 default to the previous day. Add an FR on how a broken streak is presented: neutral, no loss animation, no notification.

### H8. Rate estimates are never checked against the per-source velocity the app already computes (FR-19, FR-21, FR-30, §5, SM-5)
- **Location:** §5 "no self-correcting rate suggestions"; FR-30 computes per-source velocity; SM-5 measures forecast error but nothing acts on it.
- **Problem:** The whole forecast depends on a parent guessing "10 per week" for a school that announces nothing. A school doing 4/week goes unnoticed until July's return dump. Showing estimated vs observed side by side is cheap and does not require the parked auto-correction.
- **Fix:** Add a warning to FR-21, parent-only, with no automatic change: "School: estimated 10/wk, observed 4/wk over 6 weeks. Update estimate?"

### H9. Revocation and multi-tutor conflicts are unspecified (FR-26, FR-8)
- **Location:** FR-26 "Revoking the grant removes all of the tutor's access immediately."
- **Problem:** "Immediately" is untestable while Firestore offline persistence holds cached data and queued writes on the tutor's phone. When they sync after revocation, are they rejected? The PRD does not say what happens to the revoked tutor's sub-tracks. Left alone, they keep lowering the child's target with nobody maintaining them. Two tutors, and a tutor versus the parent, can edit or delete each other's sub-tracks or change the deadline with no conflict rule.
- **Fix:** Consequences:
  - Server rules reject writes from a revoked grant, including queued ones.
  - Cached tutor data is cleared on next launch.
  - On revocation the parent is asked, for each tutor-created sub-track: keep, end, or delete.
  - Tutors cannot delete sub-tracks they did not create unless they have "full" rights (see C4).

### H10. Offline and multi-device conflicts are not addressed (FR-2, FR-8, FR-11, FR-12)
- **Location:** §4.1–4.3; no NFR section at all.
- **Problem:**
  - *up to…* from a stale position on an offline tablet creates a batch starting at an old position, producing duplicate "chazara" events that inflate per-source velocity.
  - A tick on a sub-track row that another device deleted leaves events whose source does not exist.
  - Ground order changed on the rebbe's phone while the child ticks offline makes "up to…" ambiguous.
  - Parent and tutor editing the rate at the same time is last-write-wins without notice.
- **Fix:** Add an NFR block:
  - Events carry the position they were created against, and duplicate ranges are merged on sync.
  - Events against a deleted sub-track are kept and attributed to "deleted: School 2026–27".
  - Ground-order edits are versioned, and the client re-resolves *up to…* against the version it displayed.
  - State the offline-first expectations explicitly.

### H11. Corrections are silent and unbounded, which undermines the append-only record and invites gaming (FR-4)
- **Location:** FR-4 assumption ("the lifetime record does not show voided events"); glossary "Append-only".
- **Problem:** The child can void, re-date or re-source any event, so he can backdate to fill a streak gap or move school learning to "home" to keep a streak. The parent sees no trace. The tutor can void the child's ticks. "Voided and hidden" contradicts the "append-only" promise unless it is defined carefully.
- **Fix:** Keep voids as events that are hidden from the child's view but visible in a parent audit view with who and when. Limit re-dating by the child to the catch-up window. Make re-sourcing into "home" outside the same day require parent approval, or have it not affect the streak.

---

## Medium

### M1. Returned ground at its "original position" conflicts with "one masechta at a time" (FR-12, §5)
- **Location:** FR-12 "re-enter the main track at their original position in its order".
- **Problem:** If the main track has moved past that point, the home pointer (next unlearnt in order) jumps back mid-masechta. The child's list switches from Shabbos to Berachos 3 overnight, which breaks one-masechta-at-a-time and the continuity of today's list.
- **Fix:** State the rule: either returned ground is scheduled after the current masechta finishes, or the pointer jumps and the parent is notified. Add a test.

### M2. Proration and ongoing-window arithmetic are undefined (FR-5, FR-6, FR-19, addendum §3)
- **Problem:**
  - "Fraction of window remaining" × weeks is linear. School weeks cluster, and Tishrei and Pesach are off, so a sub-track created in Nisan is over-credited.
  - For ongoing sub-tracks with no end date, "weeks per year" across a partial-year span up to the deadline is not defined.
  - "Active weeks left in window before deadline" when the deadline falls mid-window is not defined.
  - Rounding (fractional mishnayos) and whether today is counted in days-to-deadline are not stated.
- **Fix:** Give the exact formula with two worked examples each for school-year and ongoing, plus rounding and inclusive/exclusive rules.

### M3. A hard-coded Sep–Jul academic year does not fit the stated public release (FR-5, §3)
- **Problem:** Israeli schools run Sep–Jun, Southern Hemisphere schools differ, and some chadarim follow Elul–Tammuz. "July" has no end day, so the FR-12 return day is undefined. "At most one per academic year" blocks switching schools mid-year and a morning-cheder-plus-evening-program setup.
- **Fix:** Make the window editable, pre-filled Sep 1–Jul 31. Allow ending one school-year sub-track and starting another within a year. Define the exact end instant (end of day, learner's time zone, and what happens if it falls during a lock).

### M4. Velocity is ambiguous between events and distinct new mishnayos (FR-20, FR-30)
- **Problem:** If chazara and *up to…* events count toward velocity, the no-deadline projection is inflated. SM-C1 acknowledges the inflation risk but FR-20 does not guard against it.
- **Fix:** Define velocity for projection as distinct newly-learnt mishnayos per day. Keep per-source event rate as a separate, labelled metric.

### M5. Siyum edge cases (FR-17, FR-3)
- **Problem:**
  - A before-tracking backfill of 40 masechtos fires 40 siyumim at onboarding.
  - Undo followed by re-tick: does "once" mean once ever?
  - A siyum completed by a tutor's correction fires on the tutor's device.
  - A siyum from a shabbos catch-up fires on Sunday with shabbos dating.
- **Fix:** Before-tracking completions record the siyum silently, with a one-time summary. "Once" means once ever per masechta per learner. The celebration shows on the learner's next open.

### M6. The one-tap "Yes, all of it" makes false logging the easy path, and the planned view can drift (FR-25, FR-24, SM-C2)
- **Problem:** Streak pressure plus a one-tap "all of it" is the logging-what-didn't-happen risk that SM-C2 names but no FR mitigates. What the card asks may also differ from what FR-24 showed on erev shabbos, if a sub-track ends or a tutor edits during the lock.
- **Fix:** Snapshot the planned view at lock start and base the card on that snapshot. Give equal weight to "Yes", "Some" and "Not this time", with non-punitive copy. Define *Adjust…* (currently open question 4, but it is MVP).

### M7. Lock scope and timing are untestable as written (FR-23, FR-25)
- **Problem:**
  - "Errs early ... late" has no minutes. Candle-lighting offsets vary by community (18/20/40 min).
  - "No write action anywhere" does not say whether it covers background sync, analytics, token refresh or notification scheduling.
  - The motzei-shabbos reminder fires around 22:30 in summer, well after a 10-year-old's bedtime.
- **Fix:** Specify offsets (for example, lock at candle-lighting minus N, unlock at tzeis plus M, with a configurable minhag). State that user-initiated writes are blocked and give a policy for automatic writes. Give the reminder a "not after hh:mm, else next morning" rule.

### M8. Gap detection pushes parents to invent estimates (FR-22)
- **Problem:** The only way to silence the question is "finished" or adding a speculative year with a rate. A speculative rate lowers today's target now and loads the child later. "Finished suppresses later years" is a permanent assumption that breaks when a child changes school.
- **Fix:** Add "Not planned yet (assume none)" as a first-class answer with no reduction. Make "finished" editable later and scope it to the choice made.

### M9. The corpus is not defined precisely enough for "all Mishnayos" (§3, FR-14)
- **Problem:** "~4,192" is approximate. Editions differ on Avos perek 6, Bikkurim perek 4 and perek/mishna splits. Goal completion, the final siyum and the forecast all depend on an exact count.
- **Fix:** Name the canonical edition and numbering, and state the exact count as a test fixture.

### M10. Success metrics are untestable or inconsistent (§7)
- **Problem:**
  - SM-4 (≤4 taps for a full day) is unreachable in UJ-1: main-track ticks, plus *up to…* on School (tap, pick, confirm), plus the same on Rebbe, is at least 6.
  - The SM-2 denominator ("multi-source learners") is undefined.
  - SM-5 has no target.
  - All the metrics require telemetry on children (see C4).
- **Fix:** Recount SM-4 against the designed flow. Define the cohorts. Set an SM-5 threshold. Declare the telemetry approach and whether it is on-device only.

### M11. Migration and existing users are hand-waved (§2.2, addendum Goals row)
- **Problem:** Existing profiles can have several goals per curriculum and pace-based goals. The PRD requires exactly one deadline and does not say how existing data is converted. The code has study-day settings (excluded days) while §5 says there are none. "See no change" is not a testable consequence.
- **Fix:** Add a migration FR: which goal becomes the deadline, what happens to pace goals and study-day settings, and a regression test that single-source users' targets are unchanged.

### M12. Free-tick defaulting to "home" misattributes learning and games the streak (FR-3, FR-16)
- **Problem:** A backfill of school learning defaults to home. That keeps streaks and corrupts per-source reports.
- **Fix:** No default source for batches larger than N or dated in the past. Free-tick events do not affect the streak unless they are same-day home events.

---

## Low

### L1. Ground assigned to a future sub-track blocks home learning of it for years (FR-10, FR-6)
- **Problem:** Ground assigned to a sub-track that starts in two years is greyed out on the main track now.
- **Fix:** Only active sub-tracks remove ground from scheduling. Otherwise, warn the parent.

### L2. The five-sub-track limit and one-school-per-year rule are arbitrary and unexplained (FR-5, FR-6)
- **Fix:** Give the rationale, or remove the limits.

### L3. Reports after deleting a sub-track (FR-8, FR-30)
- **Problem:** The PRD does not say how per-source reports label events whose sub-track was deleted.
- **Fix:** Keep sub-track records as tombstones. Never hard-delete them.

### L4. FRs without testable consequences
- **Problem:** FR-9, FR-11, FR-20, FR-24, FR-27, FR-28 and FR-29 have none.
- **Fix:** Add at least one testable consequence each (for example, FR-11: reordering does not change events and moves the position to the first un-ticked mishna in the new order).

### L5. Deadline definition (FR-19)
- **Problem:** The bar mitzvah date is a Hebrew date (Adar I/II, and the born-at-night rule). The PRD does not say whether it is entered as Hebrew or civil, or whether the deadline day counts in days-to-deadline.
- **Fix:** Define both.

### L6. Two FR-19 consequences are untestable
- **Problem:** For ground-less sub-tracks, "No mishna contributes to the reduction twice" is untestable because the capacity is abstract. The FR-19 assumption openly accepts double credit for two overlapping ground-less sub-tracks, which contradicts that consequence.
- **Fix:** Reword the consequence to cover grounded sub-tracks only. List the accepted double credit as a known risk with an SM-5 check.

### L7. Open questions block the MVP (§8, §9)
- **Problem:** Q4 (what *Adjust…* does for three days) and Q5 are MVP behaviour, not open questions. The working title and stand-in names are fine but should be resolved before handoff.
- **Fix:** Resolve Q4 and Q5 before epics.
