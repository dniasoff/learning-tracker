# Stitch handoff prompts — Sub-tracks

Stitch project `17413877384063192963` · design system `assets/17614113141396314331` ("Learning Tracker (current app)").
Assembled from `.memlog.md` decisions, `extract-subtracks-requirements.md` (PRD FR IDs verbatim) and
`extract-current-ui.md`. Each screen is generated MOBILE first, then TABLET. English LTR. Protagonists
mirror PRD §2.3: Yehuda (10, learner), his father (parent), Rav Cohen (rebbe/tutor).

Shared preamble prepended to every prompt:

> Existing app "Learning Tracker" (Flutter, Material 3, flat, white outlined cards on cream canvas, royal-blue
> pill buttons, Plus Jakarta Sans). We are ADDING a "Sub-tracks" feature — keep the existing shell: centred
> app-bar title, profile-switcher context bar, rounded-top bottom nav with Dashboard · Learn · Progress · Settings.
> Content is Mishnayos (seder › masechta › perek › mishna); show Hebrew terms in Hebrew script where natural,
> e.g. "Berachos ברכות". Tri-state progress: complete green, partial amber with dash checkbox, empty muted grey.

## Home + ticking
1. **Learn tab — Yehuda (child view)** · FR-1, FR-2, FR-16, FR-18. Today's main-track tasks unchanged at top
   ("Today · Beitzah 2:3–2:6", checkboxes, "+1" ). Below, a "Also learning" section with one outlined row per
   active sub-track: "School — next: Berachos 1:4" and "Rebbe — next: Beitzah 3:1", each with a "+1" pill and an
   "Up to…" text button. Streak chip (coral) and "Today 3 of 4" encouragement at top. Never show "behind".
2. **"Up to…" bottom sheet** · FR-2, FR-2a. Sheet titled "School · up to…", list of the next mishnayos in track
   order (Berachos 1:4 … 2:2) each with a checkbox; tapping a later mishna ticks all before it; individual items
   can be unticked. Primary pill "Record 5 mishnayos". Source is implied — no source picker.
3. **Dashboard tab — father (parent view)** · FR-1, FR-18, FR-19, FR-21. On-track card: "On track · projected
   finish 14 Mar 2029" (green), daily target "3 mishnayos/day". Amber shortfall warning card: "School may not
   reach Berachos 3 before July — about 40 mishnayos will return to home learning." Sub-track summary cards with
   name, current position and a 6px progress bar.

## Sub-track setup
4. **Manage tracks hub** · FR-4a, FR-8. Existing hub; main track card "Mishnayos — whole Shas Mishnayos by
   Elul 5789", then "Sub-tracks" group: School 2026–27, Rebbe (ongoing). "Add sub-track" outlined pill.
5. **New school-year sub-track form** · FR-5. Fields: Name ("School"), Academic year picker (2026–27; used years
   disabled), Start month Sep / End month Jul, Mishnayos per week (10), Weeks per year (39, editable), toggle
   "Learns on shabbos / yom tov" (off). Primary "Save". Note: "You can add ground later."
6. **New ongoing sub-track form** · FR-6, FR-6a, FR-6b. Name ("Rebbe"), Mishnayos per week, toggle "Not
   learning during bein hazmanim" (adjusts weeks), Weeks per year, optional Start date, optional End date,
   "Learns on shabbos / yom tov" toggle. Helper "Up to 5 ongoing sub-tracks".
7. **Sub-track detail — School 2026–27** · FR-7, FR-9, FR-11. Header with window "Sep 2026 – Jul 2027", current
   position "Next: Berachos 1:4", ticked count, capacity bar "Capacity 390 · remaining path 350". Ordered ground
   list (Berachos perakim 1–3) with tri-state rows and drag handles. Actions: "Add ground", "Add next year".
8. **Ground picker** · FR-10, FR-15. Corpus tree seder › masechta › perek with tri-state checkboxes and
   Hebrew names; ground already on another sub-track shows a small "Rebbe" tag; already-learnt ground marked
   "chazara". Sticky footer "Add 3 perakim to School".

## Shabbos lock
9. **Shabbos planned / locked view** · FR-23, FR-24. Banner "Shabbos · capture opens after tzeis 8:12pm".
   Frozen planned list for the locked day, all controls visibly disabled (no tappable elements). On-track
   status shown as frozen.
10. **Catch-up card + Adjust…** · FR-25. Card "Shabbos · 14 mishnayos planned — learnt them all?" with pills
   "Yes, all of it" and "Adjust…". Adjust expands a per-day list with "up to…" and individual checkboxes;
   includes main track and only sub-tracks marked "learns on shabbos".

## Tutor + history
11. **Rav Cohen — talmidim list** · FR-26, FR-29. Tutor-mode amber indicator bar. List of learners with
   on-track status chips; tapping opens the learner.
12. **Change history (parent)** · FR-27. Timeline entries "Rav Cohen added Beitzah to Rebbe · Tue 4:10pm" with
   "Undo" text buttons; undo entries themselves recorded.
13. **Mishna history — Berachos 1:1** · FR-30. Event list: date or "before tracking", source chip
   (Home / School / Rebbe), count "5 times learnt". Chazara events labelled.
14. **Lifetime report** · FR-31, FR-32. Distinct mishnayos, total events, per-source totals, same-named school
   years grouped as expandable year rows, "Export PDF" pill.

Tablet variants (all 14, per decision): use the extra width for list-detail layouts — talmidim list | learner;
sub-track detail | ground picker; history list | event detail; forms centred max ~600px with a summary panel.
