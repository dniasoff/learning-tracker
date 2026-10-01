# Sub-tracks PRD reconciliation

Compared `DESIGN.md` and `EXPERIENCE.md` with the Sub-tracks PRD and addendum. “MISSING” means no corresponding landing is specified in that spine; a neighboring general component is not treated as coverage of an unstated rule. FR-22 is withdrawn in the PRD.

## FR coverage

| FR | EXPERIENCE.md landing | DESIGN.md component / landing |
|---|---|---|
| FR-1 | Information Architecture; Component Patterns → Sub-track row | Sub-track row [DESIGN.md:379] |
| FR-2 | Information Architecture; Component Patterns → +1 button, Up-to picker | +1 button; Up-to… button; Up-to picker [DESIGN.md:380-382] |
| FR-2a | Information Architecture; Component Patterns → Up-to picker; Shabbos & Yom Tov → Catch-up card | Up-to picker; Catch-up card [DESIGN.md:382,396] |
| FR-3 | Information Architecture → Corpus browser; Interaction Primitives → Tick-to-here | Tri-state row; corpus-browser component/surface MISSING [DESIGN.md:383] |
| FR-4 | Information Architecture → Change history, Mishna history; Interaction Primitives → Undo/Correct | History event row; Change-history entry [DESIGN.md:399-400] |
| FR-4a | Information Architecture → Onboarding mention; Roles & Visibility; State Patterns → No sub-tracks; Key Flows → UJ-5 | MISSING (no onboarding component) |
| FR-5 | Information Architecture → New/edit school-year sub-track; Component Patterns → Sub-track form, Academic-year picker | Sub-track form; Academic-year picker [DESIGN.md:392-393] |
| FR-6 | Information Architecture → New/edit ongoing sub-track; Component Patterns → Sub-track form | Sub-track form [DESIGN.md:392] |
| FR-6a | Information Architecture → New/edit ongoing sub-track; Component Patterns → Sub-track row; State Patterns → Future-start sub-track | Sub-track form (no separate future-start component) [DESIGN.md:392] |
| FR-6b | Information Architecture → New/edit ongoing sub-track; Shabbos & Yom Tov; Catch-up card | Sub-track form; Catch-up card [DESIGN.md:392,396] |
| FR-7 | Component Patterns → Add next year; UJ-3 | Add next year is described in EXPERIENCE; DESIGN component MISSING |
| FR-8 | Information Architecture → New/edit; Component Patterns → Sub-track form, Delete sub-track | Sub-track form; delete component MISSING [DESIGN.md:392] |
| FR-9 | Information Architecture → Sub-track detail; Component Patterns → Capacity bar, Ground row | Capacity bar; Ground row [DESIGN.md:389-390] |
| FR-10 | Information Architecture → Ground picker, Main corpus view; Component Patterns → Ground picker | Ground picker; Tri-state row [DESIGN.md:383,391] |
| FR-11 | Component Patterns → Ground row; Interaction Primitives → Drag reorder | Ground row [DESIGN.md:390] |
| FR-12 | Component Patterns → Ground row, Delete sub-track; State Patterns → Ended sub-track | Ground row; Ended sub-tracks group [DESIGN.md:390,402] |
| FR-12a | Information Architecture → Main corpus view; Component Patterns → +1 button | MISSING (one-masechta scheduling rule has no component) |
| FR-13 | Component Patterns → +1 button, Tri-state row; State Patterns → Overlapping ground; UJ-3 edge | Ground row; Tri-state row [DESIGN.md:383,390] |
| FR-14 | Component Patterns → Tri-state row, History event row; State Patterns → Partial/complete/empty | Tri-state row; History event row [DESIGN.md:383,400] |
| FR-15 | Component Patterns → Tri-state row; State Patterns → Partial/complete/empty | Tri-state row [DESIGN.md:383] |
| FR-16 | Component Patterns → +1 button; Shabbos & Yom Tov; UJ-1/UJ-4 | +1 button; Catch-up card; existing streak chip [DESIGN.md:377,380,396] |
| FR-17 | Component Patterns → +1 button; State Patterns → Siyum | Existing siyum celebration [DESIGN.md:377] |
| FR-18 | Information Architecture → Dashboard on-track card; Roles & Visibility; Component Patterns → On-track card | On-track card [DESIGN.md:386] |
| FR-19 | Information Architecture → Dashboard; Component Patterns → On-track card, Capacity bar; State Patterns → Zero target/Shortfall | On-track card; Capacity bar [DESIGN.md:386,389] |
| FR-20 | Component Patterns → On-track card; State Patterns → No deadline | On-track card [DESIGN.md:386] |
| FR-21 | Information Architecture → Dashboard shortfall warning; Component Patterns → Shortfall warning card | Shortfall warning card [DESIGN.md:385] |
| FR-22 | Withdrawn in PRD; no required spine landing | Withdrawn in PRD; no required component |
| FR-23 | Information Architecture → Planned view; Shabbos & Yom Tov; State Patterns → Locked | Lock banner; Locked control [DESIGN.md:394-395] |
| FR-24 | Information Architecture → Planned view; Shabbos & Yom Tov → Erev and locked / Readable, not tappable | Locked control; planned-list component not named [DESIGN.md:395] |
| FR-25 | Information Architecture → Catch-up card; Component Patterns; Shabbos & Yom Tov | Catch-up card [DESIGN.md:396] |
| FR-26 | Information Architecture → My talmidim; Roles & Visibility; Component Patterns → Talmid row | Tutor-mode bar; Talmid row [DESIGN.md:397-398] |
| FR-27 | Information Architecture → Change history; Component Patterns → Change-history entry; Interaction Primitives → Undo | Change-history entry [DESIGN.md:399] |
| FR-28 | Information Architecture → Revoke tutor; Component Patterns → Talmid row; State Patterns → Tutor access revoked | Talmid row; revoke component MISSING [DESIGN.md:398] |
| FR-29 | Information Architecture → My talmidim; Component Patterns → Status chip, Talmid row | Status chip; Talmid row [DESIGN.md:387-398] |
| FR-30 | Information Architecture → Mishna history; Component Patterns → Source chip, History event row | Source chip; History event row [DESIGN.md:384,400] |
| FR-31 | Information Architecture → Lifetime report; Component Patterns → School-year group row | School-year group row [DESIGN.md:401] |
| FR-32 | Information Architecture → Lifetime report; Voice and Tone; Open Questions → Per-source report metric | Per-source report appears in tablet layout; named component MISSING [DESIGN.md:363] |

FR source ranges: PRD FR-1–FR-4 [prd.md:119-160]; FR-4a–FR-9 [prd.md:166-222]; FR-10–FR-13 [prd.md:228-267]; FR-14–FR-18 [prd.md:273-308]; FR-19–FR-22 [prd.md:314-354]; FR-23–FR-25 [prd.md:360-387]; FR-26–FR-29 [prd.md:393-419]; FR-30–FR-32 [prd.md:425-444]. Experience's own FR-to-surface index is [EXPERIENCE.md:41-61].

## Journeys

All six experience-spine titles match the PRD titles verbatim. “Steps faithful” compares the spine flow to the PRD journey path and associated requirements, with copy/detail drift noted separately.

| Journey | Title match | Protagonist match | Steps faithful? / drift |
|---|---|---|---|
| UJ-1 | Yes | Yehuda appears in both; spine calls him a child on his own profile, while PRD specifies age 10 and bar-mitzvah goal. | Yes. Spine expands the bedtime up-to sequence and adds individual unticking per FR-2a; this detail is consistent with the requirement. [prd.md:48-54; EXPERIENCE.md:245-255] |
| UJ-2 | Yes | Rav Cohen appears in both. | Yes. Spine separates creating the ongoing track from adding ground weeks later; PRD describes creating it with ground, while FR-2 permits a groundless track and later ground assignment. [prd.md:56-61; EXPERIENCE.md:257-266] |
| UJ-3 | Yes | Yehuda’s father appears in both. | Mostly. September/October setup, unchanged target when entered ground is within capacity, return of unfinished ground, and next-year copy align. Warning copy differs: PRD says “will not finish” and “come back to you”; spine says “may not reach” and “return to home learning.” [prd.md:63-69; EXPERIENCE.md:268-277] |
| UJ-4 | Yes | Yehuda appears in both. | Yes. Spine specifies the 10-minute-before-candle-lighting start and per-day adjustment; these agree with FR-23/25. [prd.md:71-75; EXPERIENCE.md:279-287] |
| UJ-5 | Yes | PRD does not name a protagonist; spine assigns Yehuda’s father. | Yes. The one onboarding mention and no setup prompt match; “Settings → Manage tracks” makes the PRD’s “menu” destination specific. [prd.md:77-79; EXPERIENCE.md:289-294] |
| UJ-6 | Yes | Yehuda and his father appear in both (spine explicitly labels both protagonists). | Yes. Spine supplies concrete event examples and report sections for the PRD’s history, lifetime report, and per-source report path. [prd.md:81-83; EXPERIENCE.md:296-302] |

## Glossary terminology drift

- **Reviews** labels “1,876 events logged” in the lifetime-report copy, while the PRD glossary calls each record a **learning event** and defines **Chazara** as a repeat event. “Reviews” can be read more narrowly as repeats, but the spine uses it for total events. [prd.md:96-100; EXPERIENCE.md:117]
- **Capacity vs Path** and **Remaining path / Total capacity** are UI labels rather than glossary terms; they use the PRD’s capacity/path concepts. The separate child visibility difference is recorded below as a direct FR-9 conflict. [prd.md:105-107,217-222; EXPERIENCE.md:142]
- **“Ended sub-tracks”** is used for tracks whose window ended; PRD §3 has no separate “ended” glossary entry, but FR-12 uses “ends” for a school year finishing, an end date passing, or deletion. The spine’s “Completed” exclusion is a label choice, not a changed lifecycle definition. [prd.md:91-93,246-253; EXPERIENCE.md:124]

## Contradictions and copy drift

- **Catch-up reminder timing:** PRD: “A reminder notification fires when the card becomes available.” [prd.md:379-387] Experience: “A reminder fires before it expires.” [EXPERIENCE.md:208-212] The timing statements differ.
- **Child sub-track detail:** PRD: “The child, parent or tutor can open a sub-track” and “The detail shows … capacity vs remaining path.” [prd.md:217-222] Experience: “For the child, [ASSUMPTION] the capacity bar is hidden.” [EXPERIENCE.md:142] The child-detail requirement and the spine visibility rule conflict.
- **UJ-3 shortfall certainty/copy:** PRD: “School will not finish Berachos by Jul 2027 — about 40 mishnayos come back to you.” [prd.md:63-68] Experience: “School may not reach Berachos perek 3 before July. About 40 mishnayos will return to home learning.” [EXPERIENCE.md:106,274] The spine softens the certainty and changes the consequence wording; its copy note calls the mock string canonical. [EXPERIENCE.md:106]

No other direct conflicts with a stated FR were identified in the reviewed spines. Items the spine itself marks as assumptions/open questions are not counted as conflicts solely because they are unresolved. Examples include tutor visibility of shortfall and lifetime reports, lock-overlay scope, and child access to detail. [EXPERIENCE.md:74,82,308-318]

## Dropped qualitative PRD intent

- No clear omission found for the central qualitative intent: the PRD’s single shared goal across home, school, and rebbe learning, with distinct progress and siyum, is reflected in the row/source model, all-source tri-state/progress, and siyum behavior. [prd.md:24-28; EXPERIENCE.md:132-137,188]
- No clear omission found for the PRD’s child-first, low-effort capture and non-shaming tone: the spines specify row-level capture, warm child copy, encouragement rather than judgment, and no child-facing behind/shortfall language. [prd.md:28,34-35; EXPERIENCE.md:85-91,133-135]
- No clear omission found for honoring Shabbos/yom tov while retaining catch-up: the planned read-only view, lock, dated catch-up, and streak handling are specified. [prd.md:28,37; EXPERIENCE.md:201-213]
- The PRD’s explicit non-user promise that single-source learners “see no change” is represented as an absent Learn section and no Dashboard summary cards when there are no sub-tracks. [prd.md:39-42; EXPERIENCE.md:141,164]
- The PRD’s emphasis on the home screen “without opening a report” is less literal in the spine: parent status is placed on the Dashboard tab. The spine does not equate Dashboard and “home screen” explicitly. [prd.md:300-307; EXPERIENCE.md:45,138]

## Addendum cross-check

- The addendum makes the FR-19 arithmetic explicit: main-track remaining excludes active assigned ground; expected new ground is capacity beyond path; shortfall is deduplicated where another active track can reach the mishna; and the denominator uses main-track study days. The experience spine describes the capacity bar and shortfall states but does not restate these calculation rules. [addendum.md:32-35; EXPERIENCE.md:138-145,174-175]
- The addendum says to recompute plans/backlogs after relevant changes and preserve offline events without overwrite; the experience spine specifies recomputation after listed actions, offline capture, and merge without overwrite. No conflict identified. [addendum.md:17-30; EXPERIENCE.md:182-184]
