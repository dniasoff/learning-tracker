# Brainstorm extract: multi-source Mishnayos tracking ("sub-tracks")

Sources:
- `docs/brainstorming/brainstorm-multi-source-mishnayos-tracking-2026-08-24/.memlog.md`: 161 entries, session of 24–25 Aug 2026.
- `brainstorm.html` in the same folder: the polished write-up.

**Ref convention:** `E<n>` is the n-th entry in the memlog, so `E1` is file line 9 and `E<n>` is file line `n+8`. Actors: "user" is Daniel and "coach" is the analyst. `HTML` means the write-up.

---

## 1. Problem & context

- **Who:** Daniel, a parent, set the app up for his son on 24 Aug 2026. The son's goal is to finish all of Mishnayos (6 sedarim, 63 masechtos, about 4,192 mishnayos) by his bar mitzvah. The first run went well (E2, HTML hero).
- **Problem:** the app assumes one curriculum, one track, one plan and one goal. In practice, one corpus is fed by three sources (E3):
  - **Home:** self-study. It carries the goal and is scheduled.
  - **Rebbe:** his own masechta, with no goal, learnt as-and-when.
  - **School:** its own set, with no goal, learnt as-and-when.
  - All three add up to the same completion.
- **Why it matters (the bar-mitzvah scenario):** the app ignores the school and rebbe contribution. It therefore asks for about 3.8 mishnayos/day at home. The honest figure is about 2.2/day.
  - Illustrative figures: about 4,192 mishnayos over 3 years to the bar mitzvah.
  - School is estimated at 10/wk × 39 wk and rebbe at 5/wk × 44 wk, together about 1,830 over 3 years (E90).
  - A related problem: things covered elsewhere get scheduled at home (E4, reservation).
  - Capture has to be frictionless for learning that has no schedule. The user asked for this three times (E6, E109, HTML).
- **Secondary problems raised as "minors":**
  - There is no partial-completion display (E8).
  - A reorder leaves a stale backlog (E12).
  - Other programmes' output cannot be entered (E15).
  - There is no per-source velocity report or PDF (E16, E17).
  - Backfill on setup day distorts velocity. This is a live bug (E82).

## 2. Final settled decisions (final state only)

1. **Derived plan.** Backlog and today's schedule are computed from corpus + sequence + events + goal date and are never stored. A reorder, missed days and sub-track coverage all have one effect: recompute (E13, E14, E54 item 5).
2. **Completions are an append-only event log** of mishna + date + source. Goal progress counts DISTINCT mishnayos. The lifetime record counts ALL events (E61, E62, E64). *Reversal:* this replaced the coach's "completions are a set" (E57, E61).
3. **Chazara, not collision.** Re-learning ground that was already learnt is recorded as another event. There is no dedupe and no dialog (E63). *Reversal:* this replaces the collision-resolution policy of E5 (cut in E55).
4. **Source attribution.** Every event carries a source (personal / a named sub-track / before-tracking). It is implied by the screen or row where he ticked, with no dropdown (E22, E85, E86).
5. **A source describes WHO or WHERE, never HOW.** Out-of-schedule learning at home is PERSONAL. Backfill uses a "before tracking / unknown" source. The free-tick screen asks for the source once per batch, defaulting to personal (E133, E134). *Reversal:* the user proposed a dedicated "free-tick" source (E131), and the coach split it this way. The user did not re-contest.
6. **Exactly one deadline, on the main track.** There are no sub-goals or per-scope deadlines, ever (E48, E50).
7. **No deadline means no required rate.** Without a deadline the app solves for a finish DATE from observed velocity (E40, E41, E42).
8. **The main track is structurally untouched.** It stays a single sequence, one masechta at a time, with the existing planner and task generation. Two masechtos on the main track must be impossible (E118, E125, E126). *Reversal:* the user had said "yes, multi-masechta at home" (E109) and then reversed it (E125).
9. **Main-track denominator = every day from now to the deadline.** No days are excluded, because he learns at home on shabbos (E67, E68).
10. **Calendar concepts apply ONLY to the sub-track weeks-per-year estimate.** They are not a scheduling feature (E35, E37, E68).
11. **Sub-tracks have no goal and no deadline, but they do have progress** (E49, E101).
12. **Two sub-track types:** SCHOOL YEAR (Sep–Jul, exactly one year) and ONGOING (E135, E136, E137). *Reversal:* this replaced the single generic type (E91, E129).
13. **Final school-year form:** name + academic-year picker + mishnayos/week + weeks/year (pre-filled at about 39, editable). It has no exclusion checkboxes (E127, E142, E143).
14. **Final ongoing form:** name + mishnayos/week + a "bein hazmanim" checkbox (which only adjusts the pre-filled weeks figure) + weeks/year (editable) + an optional end date (E141, E143, E144). *Reversal:* the yom-tov checkbox was dropped (E141). The "average across the year" wording was replaced by an explicit weeks/year field (E142).
15. **Estimates live on the sub-track form, at creation** (E91, E92). *Reversal:* the coach had proposed putting them in the main-track goal settings (E51), and withdrew it (E92).
16. **Limits:** one school sub-track per academic year, from now until the goal, and up to FIVE other (ongoing) sub-tracks (E146).
17. **No year numbering.** A school sub-track is identified by its academic period (e.g. Sep 2027 – Jul 2028). The "which school year is he in" setting is deleted (E147, E148).
18. **The picker enforces the limit.** It lists only academic years between today and the deadline and greys out years already added (E149).
19. **Each track has exactly ONE current position.** A sub-track holding several masechtos is ordered like the main track (E150, E151, E153). *Reversal:* per-masechta rows with independent pointers were withdrawn (E102, E151).
20. **Assigning ground to a sub-track is optional, phase-2 onboarding.** He drags a masechta, perek or mishna into a sub-track and it disappears from the main track (E95).
21. **Contribution formula, forward-only:** `contribution = min(rate × active weeks inside window and before deadline, assigned ground remaining)`, summed over sub-tracks. The past counts as fact and the future as estimate (E93, E96, E97, E107).
22. **Over-commit warning.** When assigned ground exceeds what the rate can finish by the deadline, the shortfall returns to the main track (E98).
23. **Gap detection** for uncovered periods up to the deadline (E116, E117). It is scoped to school-year sub-tracks only (E138).
24. **"Add next year"** clones the previous school-year sub-track and shifts its window. The rate stays editable (E115, E138).
25. **Future sub-tracks are legal.** They contribute to the forecast before they have any ticks (E106).
26. **Capture has two surfaces:**
    - A fast path on the row: "+1" and "up to…" (tick-to-here).
    - A free path: browse the corpus and tick anything at any level. This covers backfill, jumping ahead and out-of-order learning (E58, E59, E111).
    - Backfill is NOT a separate flow (E58, which closes E11).
27. **Mixed home screen:** today's main-track tasks sit on top, rendered exactly as now. Beneath them is ONE row per sub-track showing its position, +1 and up to… (E120, E152). Each sub-track is its own section (E145). *Reversal:* the unified "one kind of row" design was withdrawn (E110, E119).
28. **Tri-state (empty / grey / checked) cascades** at every level of seder > masechta > perek > mishna (E8, E9).
29. **Reorder discards backlog and today's schedule** and replaces them with a freshly computed estimate (E12).
30. **Event dating:** the date defaults to now and is editable. Events carry the day learnt, not the day tapped. Three date states: dated, motzei-backdated and before-tracking (E81, E72, E83). Before-tracking events count toward the goal and the lifetime record but never toward velocity (E83, E140).
31. **Shabbos mode:** the app is NOT clickable on shabbos and, by extension, yom tov. Capture is locked, but the app stays read-only viewable. He catches up afterwards (E75, E79). *Reversal:* this replaced the coach's "self-healing, no special logic" (E69, E70).
32. **The locked screen is the same screen as the "shabbos target shown before shabbos" requirement:** a read-only list of what is planned (E76).
33. **Reports:** per-source velocity since he started, on or off target, PDF export, and the lifetime record (times learnt per mishna, with dates, plus a lifetime report) (E16, E17, E54 item 6, E60).
34. **Governing principle: as simple as possible,** applied retroactively (E53).
35. **Build order:**
    - Stage 1, the minors: grey box, reorder-recompute, free tick with tick-to-here, event dating.
    - Stage 2: sub-tracks.
    - Stage 3: shabbos mode (E160).

Total: **35 settled decisions**.

## 3. Capabilities by stage (candidate requirements)

### Stage 1: minors
- **S1-1** Every node (seder, masechta, perek, mishna) renders as one of three states:
  - empty when no descendant has been learnt;
  - grey when some but not all have;
  - checked when all have.
  - A single learnt mishna greys its perek, masechta and seder (E8, E9; HTML mechanism 1).
- **S1-2** Changing the main-track sequence immediately discards the current backlog and today's schedule and replaces them with values computed fresh from the remaining ground (E12).
- **S1-3** When ground is learnt out of sequence, the remaining pool shrinks and the next computed target reflects it, with no special handling (E56, E57).
- **S1-4** The user can browse the whole corpus and mark any node at any level as learnt, regardless of schedule or sequence (E56, E58).
- **S1-5** Tick-to-here: one gesture marks a chosen mishna and everything before it in order as learnt (E111, E112). A whole masechta can be backfilled with a single "up to here" tap.
- **S1-6** Every event records the date learnt. The date defaults to now and is editable (E81).
- **S1-7** Backfilled events are stored as "before tracking" (E83, E140). They advance goal progress and appear in the lifetime record, but they are excluded from every velocity and forecast-rate calculation.

### Stage 2: sub-tracks
- **S2-1** The user can create a school-year sub-track (E143, E149):
  - name;
  - academic year (Sep–Jul) chosen from a picker;
  - mishnayos/week;
  - weeks/year, pre-filled at about 39 and editable.
  - The picker offers only academic years from the current one up to the deadline year. Years already used are greyed or not selectable.
- **S2-2** At most one school-year sub-track per academic year (E146).
- **S2-3** The user can create an ongoing sub-track (E141, E143, E146):
  - name;
  - mishnayos/week;
  - an optional bein-hazmanim checkbox that only adjusts the pre-filled weeks figure;
  - weeks/year, editable;
  - an optional end date.
  - Maximum of 5 ongoing sub-tracks.
- **S2-4** "Add next year" creates a school-year sub-track for the following academic year, copying name, rate and weeks. Every field stays editable (E115).
- **S2-5** Sub-tracks can be dated in the future. They contribute to the forecast before any ticks exist (E106).
- **S2-6** Ground can be assigned to a sub-track:
  - The user drags any masechta, perek or mishna into it, at any time, incrementally (E95).
  - Assigned ground is no longer scheduled by the main track.
  - The ground picker reuses the corpus browser (E99).
- **S2-7** Each sub-track's assigned ground has a user-defined order and exactly one current position (E150).
- **S2-8** On the home screen, each sub-track row shows its name and its current position, with "+1" and "up to…" (E152, E111, HTML mock). Events logged there are stamped with that sub-track as source, with no extra prompt (E85).
- **S2-9** Opening a sub-track shows its own section: the ordered list and tri-state progress across all its masechtos (E145, E152, E103).
- **S2-10** Free-tick batches ask for the source once, defaulting to personal (E134).
- **S2-11** When a deadline is set, the daily main target follows the equation in section 4. When no deadline is set, the app shows a projected finish date from observed velocity (E41, E42).
- **S2-12** Over-commit warning (E98). Example message: "School will not finish Masechta Shabbos by 12 Sivan – 40 mishnayos come back to you". The shortfall is added back into the main target.
- **S2-13** Gap detection (E116, E138). Example message: "Sep 2028 – Jul 2029: no school sub-track. Finished, or not yet planned?"
- **S2-14** Per-source velocity report since tracking started (excluding before-tracking events), with an on/off-target status and PDF export (E16, E17, E54).
- **S2-15** Lifetime record (E60, E61, E65):
  - Tapping any mishna shows how many times it has been learnt, with dates and sources.
  - There is a lifetime report.
  - The record continues after the goal is reached.
- **S2-16** (Coach idea, not explicitly confirmed by the user) Progressive disclosure: sub-track estimate inputs stay hidden until a deadline exists (E43). See D4.

### Stage 3: shabbos
- **S3-1** From candle-lighting (erring early) until after tzeis (erring late), with a margin, on shabbos and yom tov (E75, E77):
  - No write action is possible.
  - The app remains viewable in read-only mode.
- **S3-2** The locked view lists the learning planned for the shabbos or yom tov (e.g. "Planned for shabbos: 14 mishnayos") and has no tappable controls (E76; HTML mock).
- **S3-3** During the lock the on/off-target indicator is frozen. "Behind" is never shown for a day that cannot be logged (E71 item 2).
- **S3-4** After the lock ends, a catch-up card offers two choices (E71 item 3, E73):
  - "N planned, learnt them all?", which confirms all of them with one tap;
  - "Adjust…".
  - It covers up to 3 consecutive un-loggable days (yom tov + shabbos).
- **S3-5** Catch-up events are dated to the day learnt, not to motzei (E71 item 4, E72).
- **S3-6** A motzei reminder notification fires when the catch-up card becomes available (E78).
- **S3-7** A one-time location / Israel-vs-chutz-la'aretz setting drives the lock window and one-day vs two-day yom tov (E77, E29).

## 4. Daily-target equation & forecast rules

- **Equation (E36, E93, E107; HTML):**
  `daily_main_target = (remaining − Σ_subtracks min(rate × active weeks inside [window ∩ now..deadline], assigned ground remaining)) / days_to_deadline`
  - **remaining** = corpus minus distinct mishnayos learnt to date by any source, including before-tracking (E93, E64).
  - **days_to_deadline** = every calendar day, with no exclusions (E67).
  - **Forward-only:** past sub-track ticks are already inside "remaining", so only future weeks are estimated (E93).
  - **Two modes, no switch:**
    - With ground assigned, the rate predicts WHEN the ground completes and the contribution is capped at that ground.
    - With no ground, it is pure quantity (E96, E97).
- **Over-commit** means rate × remaining active weeks < assigned ground remaining. The app warns and the shortfall returns to the main track's load (E98). The effect of not guarding it: the target is too low and he silently falls behind (E117).
- **Under-commit (gap)** means a period up to the deadline with no covering school-year sub-track. The app surfaces it as a question, not an error (E116, E138). The effect of not guarding it: the target is too high.
- **No-deadline mode:** there is no required rate. The app projects a finish date from actual observed velocity, which already includes sub-track ticks. No estimates are needed (E40–E42).
- **Weeks pre-fill:**
  - School: about 39, editable (E143).
  - Ongoing: the bein-hazmanim checkbox only changes the pre-filled number, e.g. 44 in the HTML mock (E144).
  - Earlier, the count was derived from yom tov + bein hazmanim via kosher_dart (E45, E52). The yom-tov part was later deleted (E141). See D7.
- **Backfill and date states:** dated (normal), motzei-backdated (catch-up, dated to the actual day) and before-tracking (in the goal and lifetime record, never in velocity: "opening balance, not income") (E83, E140).
- **Freeze:** the on/off-target indicator is frozen during shabbos or yom tov (E71).

## 5. Screens / UX agreed

- **School-year sub-track form (E143, E149; HTML mock):**
  - Name (free text);
  - Academic year picker: Sep–Jul periods from now to the deadline, with years already added greyed;
  - Mishnayos per week;
  - Weeks per year (pre-filled about 39, editable);
  - Buttons: [Add] and [Add next year].
  - No exclusion checkboxes.
- **Ongoing sub-track form (E143; HTML mock):**
  - Name;
  - Mishnayos per week;
  - "Not learning during: ☐ Bein hazmanim", which pre-fills weeks;
  - Weeks per year (editable);
  - End date (optional);
  - [Add].
- **Ground assignment:** drag from the corpus browser into a sub-track (E95, E99).
- **Home screen (E120, E152; HTML mock):**
  - Top: "Today · main track" with the daily target (e.g. "2.2 / day") and today's tasks exactly as now.
  - Below: a "Sub-tracks" section with one row per sub-track (e.g. "Rebbe — Beitzah 2:6 — [+1] [up to…]").
  - No navigation is needed to tick sub-track learning.
- **Sub-track section:** its own section holding the ordered ground and tri-state progress (E145, E152).
- **Corpus browser / free-tick:** tri-state tree, tick any level, tick-to-here, source asked once per batch with personal as default (E58, E134).
- **Lifetime record:** tap a mishna to see its count and history (E60).
- **Shabbos locked view:** "Shabbos · locked". Contents:
  - the planned list (e.g. Shabbos 7:2–7:4, 8:1–8:7, 9:1–9:4, 14 in total);
  - the frozen status ("On target. This reading will not change until motzei shabbos.");
  - nothing tappable (E76; HTML).
- **Motzei catch-up card:** "Shabbos · 14 mishnayos planned — Learnt them all?", with [Yes, all of it] and [Adjust…]. It carries the note "Ticks are dated to shabbos, not to now" (E71; HTML). "Adjust…" is not designed (see D17).
- **Erev view:** shows the shabbos target before the lock (E71 item 1). This is the same content as the locked view.

## 6. Out of scope / parked / rejected

| Item | Status | Reason / ref |
|---|---|---|
| App-inferred calendars (learning the rhythm from velocity) | Parked | Simplicity. Revisit only if manual estimates prove too inaccurate (E33, E39, E55) |
| Confidence intervals / widening bands | Cut / parked | Simplicity (E39, E55) |
| Streak-safety logic (there are no streaks) | Cut / parked | Simplicity (E39, E55, E69) |
| Per-scope / sub-track deadlines ("finish Moed before Pesach") | Rejected | One deadline only (E48, E50, E55) |
| Multi-option collision policy (re-learn / auto-credit / review) | Rejected | Replaced by chazara-as-event (E5, E55, E63) |
| Warm/cold chazara prompt | Offered, optional, not adopted | Simplicity (E66) |
| Year-total estimate instead of rate × weeks | Offered, not adopted | (E130) |
| Hardcoded / imported school calendars, term dates, per-country logic | Rejected | Every school differs (E28, E32, E37, E38) |
| Calendar exclusions on the main track | Rejected | He learns every day, including shabbos (E67, E68) |
| Yom-tov exclusion checkbox | Deleted | User trim (E141) |
| Exclusion checkboxes on the school type | Deleted | Holidays are already in the school figure, so applying them would double-discount (E127, E128) |
| Multiple masechtos on the main track | Rejected (reversal) | Keeps the planner untouched (E125, E126) |
| Per-masechta rows with independent pointers | Withdrawn | One current position per track (E151) |
| Unified main/sub-track row UI | Withdrawn | A plan produces tasks; no plan produces a position (E119) |
| Estimates in the main-track goal settings | Withdrawn | User mental model (E92) |
| "Year 11" numbering and a "current school year" setting | Deleted | Varies by country (E147, E148) |
| "Free tick" as a source | Rejected | A source is who/where, not how (E133) |
| Completions as a set | Withdrawn | Lifetime record (E61) |
| A separate backfill flow | Dropped | Same surface as free tick (E58) |
| Shabbos "self-healing, no special logic" | Rejected | User pushback (E70) |
| Arbitrary date windows for school sub-tracks | Rejected | Fixed Sep–Jul (E135) |
| Main-track rework of any kind | Out of scope | (E126, E160) |

## 7. Open questions still unresolved

1. **Fragmented history (E108).** One school split into several year sub-tracks shows as several rows in the lifetime report. Is grouping needed? (Open in the HTML too.)
2. **Rebbe non-active weeks (E47).** Does he learn with his rebbe through bein hazmanim and yom tov? This is a user fact. The checkbox exists (HTML lists it as open).
3. **Before-tracking date (E83).** Should it be "no date, or an approximate one"? Never decided.
4. **Self-correcting rate proposal (E21).** Example: "school is really running at 7.2/wk – update?". It is neither adopted into the simplest version (E54) nor explicitly cut, and the HTML omits it.
5. **Progressive disclosure (E43, coach idea).** Were rate/weeks fields hidden until a deadline exists? This conflicts with the final forms, which always contain the rate (see D4).
6. **Status of the E71 pieces.** The E71 "four pieces" and the E77 zmanim margins are coach ideas. The user confirmed only the lock plus catch-up (E75). The indicator freeze and the erev view were never explicitly confirmed.
7. The gaps raised under section 8 (D-items), which the PRD must resolve.

## 8. Discrepancies, gaps & ambiguities (review)

**Log vs HTML**
- **D1. The HTML omits the backfill-source decision (E134).**
  - The HTML models backfill only as a *date state*, "before tracking".
  - The log also makes it a *source*, "before tracking / unknown", and adds "ask the source once per batch, default personal".
  - Two representations of the same fact (source = before-tracking and date = before-tracking) must be reconciled in the PRD.
  - E133 says "a source is who/where, never how". A "before-tracking" source is about *when*, so it arguably violates the rule it was derived under.
- **D2. The HTML principle "06 Build in the order that needs no configuration" conflicts with the deliverable.**
  - The principle comes from E42: stage 1 = attribution + actual velocity + projected date.
  - The HTML deliverable and E160 put attribution, reports and the no-deadline projection in **stage 2**, and stage 1 = the minors.
  - A zero-config projection that "already contains school and rebbe" requires school and rebbe ticks, i.e. sub-tracks. So the E42 build order cannot ship before sub-tracks exist.
- **D3. Gap detection scope.** The HTML says "any period … with no covering sub-track". E138 restricts it to school-year sub-tracks. The HTML also does not say how a "Finished" answer is persisted, i.e. whether the prompt ever stops for years after school stops teaching Mishnayos (E104).
- **D4. Progressive disclosure (E43, HTML principle 06) vs the final forms.**
  - The final forms (E143, HTML mocks) show rate and weeks unconditionally.
  - It is undefined whether sub-tracks can be created without a deadline, and what the school-year picker offers when there is no deadline. "Years between today and the deadline" has no upper bound in that case.
- **D5. Coach ideas presented as settled.** The HTML presents shabbos pieces (S3-3, S3-6, S3-7, the E77 margins) as agreed. The user confirmed only the lock plus catch-up (E75).
- **D6. Unsourced lines and figures in the HTML.**
  - "a boy told to do 3.8 when 2.2 is the truth is being told, every day, that he is failing" is not in the log. It is rhetorical, but it contradicts the footer claim that every word derives from the log.
  - Backfill size is given as "~500" (E82), "~600" (E140) and "several hundred" (HTML).
  - The timeline figures (12/wk in 2027, nothing in 2028) are illustrative and not from the log.
- **D7. Source of the "~39 weeks" pre-fill.**
  - It came from deriving yom tov + bein hazmanim via kosher_dart (E45, E52).
  - Later, school got no checkboxes (E127) and yom tov was deleted (E141). "~39" is now a constant of unexplained origin.
  - For the ongoing type, the baseline and the size of the bein-hazmanim adjustment are unspecified. E.g. 52 → 44 in the mock, so bein hazmanim = 8 weeks?
  - The HTML still says "Yom tov and bein hazmanim exist solely to make a sub-track's throughput estimate honest" (principle 04), which is stale after E141.
- **D8. Active FROM dropped silently from the ongoing type.**
  - E105 gave sub-tracks active FROM and UNTIL. The final ongoing form (E143) has only an optional end date.
  - So a future rebbe or summer-shiur track cannot start later, which contradicts "future sub-tracks are legal" (E106) for the ongoing type.
- **D9. Lifetime record ordering.** The HTML and E160 put the lifetime record in stage 2, but the event log (with dates and sources) it depends on is a stage-1 prerequisite for event dating. "Motzei-backdated" is listed in stage 1 but only arises in stage 3.

**Contradictions and ambiguities inside the design**
- **D10. Rate-only mode overstates contribution (chazara vs the equation).**
  - With no ground assigned, the equation counts rate × weeks as new *distinct* mishnayos.
  - But school or rebbe learning ground already learnt is chazara and does not advance the goal (E64).
  - So the no-ground mode is systematically optimistic. Its target is too low: the same "silently falls behind" failure the design guards against.
- **D11. "Ground left" is ambiguous.**
  - It could mean unlearnt (by anyone) mishnayos in the assigned ground, or the ordered distance from the sub-track's current position to the end.
  - If assigned ground contains mishnayos already learnt at home or via backfill, the sub-track will spend its rate re-learning them.
  - Completion time (the over-commit test) follows the ordered distance. Contribution to the goal follows the distinct-unlearnt count. The two differ, and the PRD must pick one for each purpose.
- **D12. A ground-less sub-track has no position.**
  - Ground is optional (E95), but "+1 / up to…" needs a current position within an ordered sequence (E150).
  - A sub-track created with only rate and weeks (the default form) has nothing to tick against on the home screen.
  - Undefined: must ground be assigned before capture works? Does a ground-less row open the free-tick browser?
- **D13. Over-commit "comes back to you" is numeric only.**
  - The shortfall is added to the main target. The specific ground stays assigned to the sub-track, so the main planner, which is a single sequence, has nothing concrete to schedule for those 40 mishnayos.
  - This is also undefined: when a school-year sub-track ends with ground unfinished, does its ground return to the main sequence, carry into the "next year" clone, or stay orphaned?
- **D14. Ground ownership rules are missing.**
  - Can a mishna be assigned to two sub-tracks?
  - Can ground be dragged out of the main track's *current* masechta mid-way?
  - Can a sub-track take ground that is already fully learnt?
  - Does dragging change the main sequence, and so trigger reorder-recompute (S1-2)?
- **D15. Tick-to-here semantics.**
  - What is "everything before it"? In the track's order from the current position, or in corpus order (free-tick browser)?
  - Does it create new events for already-learnt mishnayos in range? Those would be chazara events and could inflate the lifetime counts.
  - How is a tick-to-here that is really backfill (setup-day use, E112) distinguished from today's learning, for date state and source? On a sub-track row, the source and the date would default to "this sub-track, now".
- **D16. No undo or correction is defined** for an append-only log. Mistaken ticks, a wrong source or a wrong date need an edit or void path. Only "date editable" is stated (E81).
- **D17. Motzei catch-up scope.**
  - "Planned" covers main-track tasks only. Sub-track learning on shabbos (e.g. a rebbe shiur on shabbos) has no catch-up path.
  - "Adjust…" is undesigned, including per-day allocation across a 3-day yom tov.
  - It is unstated whether the indicator shows "behind" if catch-up is skipped.
- **D18. Yom tov and the denominator.** E67 answers only for shabbos. Whether he learns at home on yom tov (so there are no excluded days) is inferred, not stated.
- **D19. No-deadline mode vs the existing planner.** The main track "keeps generating tasks as today" (E118). But with no deadline "there is no required rate" (E40). The PRD must confirm how today's planner sizes daily tasks without a deadline, and what "today's freshly computed estimate" (E12) means in that case.
- **D20. School window rigidity and gaps.**
  - The school year is fixed at Sep–Jul (E135). Earlier, E123 and E124 had auto-filled dates that were *editable* and noted country variance (Aug–Jun, Elul–Tammuz). The final design is rigid.
  - Behaviour for the current, part-elapsed school year is unspecified: how are the remaining active weeks prorated when today is 30 Sep, or mid-year?
  - The Aug gap between school years must not trigger gap detection.
- **D21. "On/off target" is undefined as a metric.** It could mean actual total pace vs the required daily target, or actual per-source velocity vs its estimate. The report needs a definition. It also needs a definition of "velocity window" (all-time since start vs trailing) for the no-deadline projected date.
- **D22. Limit semantics.** Does "max 5 ongoing" mean concurrently active, or ever created, i.e. do ended ones count? What about past school years, e.g. history for a year that ended before tracking started?
- **D23. Existing data migration.** The live bug (E82): setup-day backfill is already stored with tap dates. The PRD needs a requirement to reclassify or migrate existing completions to "before tracking" and "personal".

## 9. Technical-how (architecture addendum, not PRD)

- Derived-not-stored plan and backlog, plus the recompute engine triggered by any input change (E13, E14, E126).
- Event-log schema: mishna, date, source, date-state. Append-only; distinct-count vs event-count queries (E61, E62, E83).
- Source column populated implicitly from the capture context (E85, E86).
- Tri-state cascade computation and rendering; a shared tree component reused by the corpus browser, the ground picker, sub-track progress and backfill (E9, E99, E103, E112).
- Forward-only contribution calculation, window ∩ deadline intersection, active-week proration, and min() capping (E93, E97, E107).
- Sub-track model: ordered ground, current pointer, type discriminator, window, rate, weeks. Main track and sub-tracks share the ordering and position abstraction (E153).
- kosher_dart: zmanim for the lock window (candle-lighting / tzeis plus margins), Israel vs chutz la'aretz yom tov, and optionally the weeks pre-fill (E23, E29, E45, E77).
- flutter_local_notifications for the motzei reminder (E78).
- Write-lock enforcement at the capture layer while reads stay enabled; "fail locked" bias (E77, E79).
- Clone-and-shift implementation; the picker computing eligible academic years (E115, E149).
- PDF generation for reports (E17).
- Migration of existing completions to the event log with a before-tracking state (D23).
