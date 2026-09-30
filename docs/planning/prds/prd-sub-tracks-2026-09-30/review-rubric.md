# PRD Quality Review — PRD: Sub-tracks — multi-source Mishnayos tracking

## Overall verdict
This is a PRD with a real thesis: make the daily target honest about what school and a rebbe will cover, without adding effort for the child. The decisions from the 2026-09-30 session are recorded as decisions, and the Non-Goals and rejected alternatives are unusually candid. What is at risk is the forecast arithmetic and the launch surface. FR-19, as written, *raises* the home target when a family enters partial school ground (the informal usage UJ-3 describes). "On track" has no stable reference once the backlog is discarded on every recompute. For a public release, the PRD is silent on child data, non-functional bounds, lock opt-in, and migration of existing goals and study-day settings. Done-ness is thin: 8 of 30 FRs have no testable consequence.

## Decision-readiness — adequate
Most choices are stated plainly and carry what was given up. Examples: "Streaks count home learning only" (FR-16), "Tracks are independent" (FR-13) with the overlap consequence accepted in the FR-19 assumption, "one masechta at a time on the main track stays" (§5), and a tutor who "can do everything the parent can do" including the deadline (FR-26). The addendum's §4 rejected-alternatives list gives the reason for each alternative. The Open Questions in §8 are genuinely open, though OQ-5 only repeats the FR-2 assumption.

The weak spot is the forecast. FR-19 was confirmed by Daniel as an equation, but its behavioral consequences were not surfaced. The main one works against the Vision's promise that the target "counts what the other sources will realistically cover": capacity a grounded sub-track has beyond its assigned ground simply disappears. FR-18's definition of "on track" also does not survive FR-19's rule that recompute discards "any stale backlog".

### Findings
- **critical** Assigning partial ground raises the home target (§4.5 FR-19; UJ-3). A ground-less School sub-track at 10/week × 39 weeks reduces the load by about 390. In October the parent adds "Berachos perakim 1–3", roughly 20 mishnayos. From then on School's reduction is capped at that ground, because grounded sub-tracks subtract nothing and only add back their shortfall, so the home target jumps. Informal, incremental ground entry is exactly the pattern §4.3 prescribes ("a masechta or a few perakim, entered whenever the family learns"), so every ground entry penalises the child. UJ-3's climax, "the home target now reflects exactly what school holds", hides this. The FR-19 consequence "never lowers the daily target by more than that ground's size" tests only one direction. *Fix:* decide explicitly whether the capacity beyond the ground (rate × weeks − ground) still counts as a ground-less contribution. Add a consequence bounding how far assigning ground may *raise* the target, and add a `[NOTE FOR PM]` if Daniel keeps the current behavior.
- **high** "On track" has no fixed reference (§4.4 FR-18; §4.5 FR-19; FR-23). FR-18 assumes "distinct learnt ≥ the amount the forecast required by today". FR-19, however, recomputes the target from what remains and discards backlog, so any required-to-date figure is re-derived each day and the learner is never measurably behind. FR-23 also promises the indicator "never shows 'behind' for a locked day", which assumes "behind" is well defined. *Fix:* define on-track against a stable baseline (for example a trailing-window pace vs the current target, or the target snapshot at start of day) and state what makes it flip.
- **medium** The forecast systematically overstates contribution when a sub-track holds learnt ground (§4.5 FR-19; FR-10). FR-10 allows "ground that is already learnt; learning it there is chazara". The shortfall formula still assumes the sub-track's whole rate lands on *unlearnt* ground, and a ground-less sub-track's rate × weeks is counted as new distinct mishnayos. Brainstorm D10 and D11 flagged this "silently falls behind" failure, and the PRD neither resolves it nor accepts it. *Fix:* choose ordered-distance or unlearnt-count for shortfall, and record the optimism of the ground-less mode as an accepted limitation or an `[ASSUMPTION]`.

## Substance over theater — strong
There is no furniture here. The Vision is specific to this product: a bar-mitzvah siyum, three sources, a child told "every day, that he is behind when he is not", and it could not be swapped into another PRD. The personas are three real roles plus a contextual "Family" JTBD, and each one drives FRs: the child drives FR-1/2, the parent FR-5/18/21, the rebbe FR-26/27, and the family FR-23. No innovation or differentiation section was added for show. The one NFR-flavored item, the lock window, is product-specific. The counter-metrics (SM-C1, SM-C2) reflect real reasoning about this product, especially SM-C2's point that "streak pressure must never push a child to log on shabbos".

## Strategic coherence — adequate
The thesis is stated in §1: "make the app believe the truth about his life". It is carried through the forecast (§4.5), the effortless capture (§4.1), and the refusal to call the learner behind when he is not. Features follow the thesis rather than ease of build, and the counter-metrics are named. The gap is that the MVP scope in §6.1 is simply FR-1 through FR-30. It sets no scope logic for a public release, and the brainstorm's staging (minors → sub-tracks → shabbos) is pushed into a `[NOTE FOR PM]`. The metrics also do not validate the thesis well.

### Findings
- **medium** The metrics measure capture, not honesty (§7). SM-1 and SM-4 measure effort. SM-5, the only metric tied to the thesis ("forecast honesty"), has no target and no measurement method. SM-2 has no target, and its denominator, "multi-source learners", is undefined: nothing in the product marks a learner as multi-source. The PRD also never says whether the app has analytics instrumentation at all, even though these are share-of-learners metrics across public users. *Fix:* give SM-5 a threshold (for example, forecast within ±15% of actual distinct mishnayos per source per school year), define the SM-2 cohort, and name the instrumentation source or state that it has to be built.
- **medium** The MVP is the whole design (§6.1). Every FR is in scope, and the staging decision is deferred. Because the stakes include public release, the PRD should state its MVP kind: problem-solving (the honest target) or experience (effortless capture). It should also say what could ship first, for example sub-tracks and the forecast without reports (FR-29/30) or without the lock. *Fix:* name the MVP kind and mark FR-29, FR-30 and FR-22 as cut candidates if timelines slip.

## Done-ness clarity — thin
The strongest FRs (FR-2, FR-10, FR-12, FR-13, FR-19, FR-25) have crisp, testable consequences. Eight FRs have none at all: FR-9, FR-11, FR-20, FR-21, FR-24, FR-27, FR-28 and FR-29. FR-11 matters most among them, because ordering and the single current position are the core of the sub-track model. The lock, which carries the highest reputational risk in a public Jewish app, is specified with adjectives rather than bounds.

### Findings
- **high** Eight FRs lack testable consequences (§4.2 FR-9, FR-11; §4.5 FR-20, FR-21; §4.6 FR-24; §4.7 FR-27; §4.8 FR-28, FR-29). FR-11 does not say:
  - what the default order is when ground is added incrementally (corpus order? append?);
  - where newly added ground lands relative to the current position;
  - whether reordering moves the position.

  FR-20 does not define the velocity window (all-time or trailing), which brainstorm D21 raised. FR-21 does not say when the warning appears or how it is dismissed. FR-29 does not name an export format, while FR-30 says PDF. *Fix:* add at least one verifiable consequence per FR, starting with FR-11's ordering rules and FR-20's velocity window.
- **high** The capture lock is unbounded and underspecified (§4.6 FR-23). Four gaps:
  - "The window errs early to lock and late to unlock" gives no minutes.
  - There is no requirement for behavior when location or lock state cannot be established. The addendum §2 says "bias toward remaining locked", but that is an implementation note, not an FR.
  - "No write action is possible anywhere in the app" leaves scope unclear: settings, sign-out, account deletion, and a tutor on his own phone.
  - The window "follows the learner's location", but the addendum §1 notes that location is "global across profiles" per device. So which location governs a rebbe in another city editing a talmid?

  *Fix:* state margins in minutes, make fail-locked an FR consequence, list which writes are blocked, and resolve whose zmanim govern a tutor device.
- **medium** FR-19 edge cases are undefined (§4.5 FR-19). Four cases have no stated behavior:
  - a negative numerator, when sub-tracks cover more than remains (is the target clamped at 0?);
  - a deadline that is today or has passed;
  - an ongoing sub-track with no end date (does its window run to the deadline?);
  - a future-start sub-track's window, which FR-6 introduces only through an assumption.

  *Fix:* add consequences for each case.
- **medium** Event dates are unstated for normal capture (§4.1 FR-2, FR-3; §4.6 FR-25). FR-2 and FR-3 never say what date an event carries or whether it can be edited. The FR-25 assumption says sub-track catch-up happens "from the sub-track rows with the date editable", but FR-2 defines no date control. Bedtime capture after midnight (UJ-1) is also undefined. *Fix:* add a date consequence to FR-2 and FR-3 (defaults to today, editable back N days), or remove "date editable" from the FR-25 assumption.
- **medium** "Original position" is ambiguous on return (§4.3 FR-12). Returned mishnayos re-enter "at their original position in its order". If that position lies behind the main track's current masechta, the PRD does not say whether the main track jumps back (§5 keeps "one masechta at a time") or whether the returned mishnayos queue after the current masechta. Brainstorm D14 also asked about assigning ground from the main track's *current* masechta mid-way; FR-10 is silent on it. *Fix:* add a consequence for returned ground that sits before the current position, and one for assigning ground from the in-progress masechta.
- **low** "Recompute immediately" has no bound (FR-4, FR-8). Offline bedtime capture and tutor edits from another device make "immediately" ambiguous. *Fix:* state it as "on the next render after the write is applied locally", or give a latency bound.

## Scope honesty — adequate
The Non-Goals in §5 do real work: no sub-deadlines, no school calendars, no cross-track dedupe, no excluded days. Assumptions are tagged inline and indexed. The open-items density is moderate: 5 Open Questions, about 12 assumptions and 1 NOTE FOR PM. That is acceptable for a draft but heavy for green-light-to-build. The real honesty gap is what the PRD does not mention at all. The memlog records the stakes as "launch-level rigor (multi-locale shabbos, child data, edge cases)", yet the PRD has no non-functional or privacy section, and several brownfield collisions are not acknowledged.

### Findings
- **high** Public-release requirements for child data, privacy and NFRs are missing (whole PRD; memlog stakes decision). The protagonist is a 10-year-old who holds the phone, and FR-26 gives a non-family tutor full edit rights over the minor's data, including the deadline. The PRD says nothing about consent, what a tutor can see, data retention for a "lifetime record", data export/deletion, or offline behavior for bedtime capture. *Fix:* add an NFR / Trust section covering child-data handling, tutor visibility limits, offline capture and sync-conflict rules (child and tutor editing at once), and performance bounds for recompute. Alternatively, mark each item as `[NON-GOAL for MVP]` with a reason.
- **high** Brownfield collisions are unacknowledged (§3 "Main track … behavior is unchanged"; §5; addendum §1 Goals and Derived-schedule rows). Three conflicts:
  - The existing scheduler uses study-day settings. FR-19 counts "every day (no excluded days)", and §5 says "No excluded days on the main track". That changes behavior for existing users who configured study days, which contradicts "behavior is unchanged".
  - Goals currently allow several per curriculum, but the PRD needs exactly one deadline-bearing goal.
  - The tap-dated backfill migration (brainstorm D23) survives only as "verify" in the addendum.

  *Fix:* add a Migration / Existing-users subsection with FRs, or explicit `[NOTE FOR PM]` callouts, for study-day settings, multiple goals and backfill dating.
- **medium** Curriculum scope is unstated (§2.2, §3 Corpus). The Glossary fixes the corpus to Mishnayos, but the app is multi-curriculum (addendum: `curriculum_tracks/{curriculumId}`). §2.2's "learners without a single corpus goal fed by multiple sources" suggests the feature is generic. *Fix:* add a Non-Goal or scope line: sub-tracks are Mishnayos-only in v1, or they apply to any curriculum.
- **medium** Lock opt-in is undecided (§4.6). FR-23 makes the lock universal ("no write action is possible anywhere"). For a public release, the PRD should say whether users who do not keep shabbos, or who have no location set, can disable it, and how it relates to the existing `sacred_time` preference. *Fix:* state it as a decision.
- **medium** The fixed Sep–Jul window is country logic that is not labelled as such (§3 School-year sub-track; §5 "No … per-country school logic"). A rigid September–July year is itself one country's calendar. Israeli, southern-hemisphere and Elul–Tammuz schools do not fit it (brainstorm D20). This may be the right call for v1, but it is presented as neutral. *Fix:* add a Non-Goal line naming the limitation for public users, or a `[NOTE FOR PM]`.

## Downstream usability — adequate
A Glossary is present and mostly used consistently. FR IDs run 1–30 with no gaps, UJ IDs run 1–6, and SM IDs run 1–5 plus C1–C2. The addendum maps capabilities to FRs cleanly, and each FR group opens with a description that stands alone. One Glossary definition contradicts the FRs on the model's central concept, and several domain terms that appear in FRs are not in the Glossary. This is a chain-top PRD (UX → architecture → stories), so both points matter.

### Findings
- **high** The Glossary's "Current position" contradicts FR-2 and FR-13 (§3; §4.1 FR-2; §4.3 FR-13). The Glossary defines it as "the next unlearnt mishna in a track's own order", and "Learnt" is defined as learnt by *any* source. Under that definition, a tick on the Rebbe sub-track would advance School's position. FR-2 ("next mishna … not yet ticked *in that sub-track*") and FR-13 ("never moves another track's current position") say the opposite. Story writers will pull the Glossary. *Fix:* redefine it as "the next mishna in the track's own order not yet ticked in that track".
- **low** Terms used in FRs are missing from the Glossary: *academic year*, *bein hazmanim*, *velocity*, *on track*, *free tick*, *tick-to-here*, *talmid*, *tzeis*, *chutz la'aretz*. Public-release contributors will not all know the Hebrew terms. *Fix:* add them to §3.
- **low** "Shortfall" drifts between the Glossary and FR-19. The Glossary says "before its window ends", while FR-19 says "active weeks left in window *before deadline*". *Fix:* align the Glossary with FR-19.

## Shape fit — adequate
The shape is right for a consumer, multi-role feature: UJs with named protagonists carry load, and the capability-spec FRs follow from them. The brownfield framing is handled mainly in the addendum, which has accurate file references drawn from `extract-code-reality.md`. However, the PRD body does not separate new behavior from changes to existing behavior.

### Findings
- **medium** New and changed existing behavior are not distinguished in the FRs (§4.1 FR-3; §4.4 FR-16; §4.7 FR-27). The code already has streaks *and points*, and bulk marks get "no streak or points" per the code-reality extract. The PRD redefines streaks (FR-16) but never says whether sub-track ticks earn points. FR-27's multi-talmid list extends the existing `tutored_children_section`, and FR-3's free tick overlaps the existing bulk-mark screen, yet both read as net-new. *Fix:* tag each FR as New or Changed, add a points rule next to FR-16, and name the existing surfaces FR-3 and FR-27 replace or extend.

## Mechanical notes
- **IDs:** FR-1–30, UJ-1–6 and SM-1–5/C1–C2 are contiguous and unique. The ranges cited in §6.1 resolve. Several FRs cite no UJ (FR-3, FR-9, FR-11, FR-13–15, FR-17, FR-23, FR-26–30). This is acceptable, but tracing would be easier with citations.
- **Assumptions roundtrip:** all inline `[ASSUMPTION]` tags appear in §9. The FR-22 inline tag is a bare `[ASSUMPTION]` with no text, so the claim lives only in the preceding sentence and the index.
- **Open Questions:** OQ-5 duplicates the FR-2 assumption and could be removed or merged. The memlog records "7 open questions"; the PRD has 5. Confirm that the two dropped questions were resolved and not lost.
- **UJ structure:** UJ-4, UJ-5 and UJ-6 omit the Persona/context and Entry-state fields that UJ-1–3 use. The protagonist is inferable but not stated inline.
- **Leftovers:** "*Working title — confirm.*" (line 16) and the protagonist stand-in assumption are still open.
- **Inputs:** the front matter cites `brainstorm.html`. The untracked file in that folder is `brainstorm.pdf`, so check that the path resolves.
