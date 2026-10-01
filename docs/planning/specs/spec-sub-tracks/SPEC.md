---
id: SPEC-sub-tracks
companions:
  - ../../prds/prd-sub-tracks-2026-09-30/prd.md
  - ../../prds/prd-sub-tracks-2026-09-30/addendum.md
  - ../../architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md
  - prd-deviations.md
  - screens.md
sources: []
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Sub-tracks and the learning-event stack

## Why

**A pain to solve.** A learner working toward one whole-corpus goal with a deadline (for example, all of Mishnayos by a chosen date) learns from several sources: home, school and a rebbe. The app only knows the home track, so it roughly doubles the daily target and tells the child every day that he is behind. Sub-tracks model each outside source honestly so the target counts only what the other sources won't cover. Capture stays effortless for a child, and the app refuses writes on shabbos and yom tov. To make this possible, one append-only `learning_events` log replaces `completions`, `learning_ledger` and `streak_events` for **every** curriculum (AD-49).

## Capabilities

FR numbers refer to the PRD companion and AD numbers to the spine companion. Reference mockups for each screen are listed in `screens.md`. Their testable consequences are part of each `success`. Where the two disagree, `prd-deviations.md` decides.

- **CAP-1** — Effortless capture
  - **intent:** The child records learning from the home screen in one gesture per source: *+1* and *up to…* on each active sub-track row, *up to…* on the main-track list, individual tick and untick before confirming, and free tick or tick-to-here in the corpus browser. The source is implied by where he ticks.
  - **success:** FR-1, FR-2, FR-2a and FR-3 consequences pass. The main-track today list renders exactly as before. A full day across all sources takes ≤ 4 taps (SM-4).
- **CAP-2** — Correct a mistake
  - **intent:** The child, parent or tutor can void or replace a wrong learning event, and every derived number recomputes.
  - **success:** FR-4 consequences pass under AD-31, AD-38 and AD-45. A void targets only a `learn` event. The child re-dates only within the catch-up window. A correction never creates a streak day.
- **CAP-3** — Optional sub-track lifecycle
  - **intent:** A parent or tutor can create school-year and ongoing sub-tracks from the menu, with an optional future start and a *learns on shabbos / yom tov* flag. They can also add next year, edit, delete and open the detail view. Sub-tracks are available on any curriculum except one whose main track follows a calendar program. Nothing prompts families to create one. If the main track has no deadline, the sub-track form says so inline and links to setting one, because without a deadline a sub-track can't lower the daily target.
  - **success:** FR-4a and FR-5 through FR-9 consequences pass. The AD-45 limits (≤ 5 active-or-future ongoing sub-tracks, one school-year sub-track per academic year, no overlapping windows) are enforced by one fixture suite run in both Dart and TypeScript.
- **CAP-4** — Ground moves only on assignment and on end
  - **intent:** A parent or tutor can assign ordered ground to a sub-track, which removes it from the main track's schedule. Its unfinished ground returns to its original position in the main track when the sub-track ends. Tracks never move one another's positions, and the main track schedules one masechta at a time.
  - **success:** FR-10 through FR-13 and FR-12a consequences pass. Positions are derived, never stored (AD-33). All surfaces use one `expandGround` and one set of `holdsGround`, `inForecast` and `onHome` predicates (AD-34).
- **CAP-5** — Progress and motivation
  - **intent:** The learner sees a distinct-mishnayos count, tri-state fill on every corpus node, a streak kept by home learning, and a siyum once per masechta. Points are earned only by main-track learning that newly makes a ref learnt or carries a scheduled review stage.
  - **success:** FR-14 through FR-17 consequences pass. A siyum fires whenever a masechta in the learner's corpus becomes fully learnt, including by backfill or correction. A void that un-completes it takes the siyum away, and re-completion celebrates again (`prd-deviations.md` #11). The streak is kept per curriculum and follows AD-40's `streakDay`, so a backdated tick cannot repair a broken streak. Points follow AD-50: one `pts_{eventId}` per earning event, and the balance counts only events the engine still counts.
- **CAP-6** — On-track at a glance
  - **intent:** The parent sees on-track status and a projected finish date. With no deadline they see the projection only. The child only ever sees encouragement.
  - **success:** FR-18 and FR-20 consequences pass. The projection uses trailing-4-week velocity of distinct newly learnt mishnayos. The parent sees "too early to tell" under 2 weeks of history. The child view never shows "behind" or "off track".
- **CAP-7** — Honest daily target and shortfall
  - **intent:** The main-track daily target credits every sub-track's full capacity, adds back the shortfall that sub-tracks won't reach, and warns the parent about that shortfall.
  - **success:** FR-19 and FR-21 consequences pass using the addendum §3 and AD-44 arithmetic: floored capacity, `ceil` target clamped at ≥ 0, and each mishna counted as shortfall at most once. There is one deadline goal per curriculum, at `goals/{curriculumId}_deadline` (AD-43). Entering ground whose path fits within capacity leaves the target unchanged.
- **CAP-8** — Fail-closed capture lock
  - **intent:** From 10 minutes before candle-lighting until 10 minutes after tzeis on shabbos and yom tov, the app is neither readable nor usable on any device for the learner; the existing full-screen lock overlay covers it. On erev, before the lock, the learner sees what is planned for the locked days, with live controls.
  - **success:** FR-23 and FR-24 consequences pass, as amended by AD-36, AD-37 and `prd-deviations.md` #10. Every write passes the single `CaptureGate`. The lock is computed in the learner's IANA time zone using the settings in force at the time. It falls back to a closed lock when location is unknown or at high latitudes. The engine ignores any event recorded inside a lock.
- **CAP-9** — Catch-up after a lock
  - **intent:** After a lock ends, one card per lock records the locked days' learning in one tap (or via *Adjust…*), dated to the locked days. It covers the main track and every sub-track flagged *learns on shabbos*, and a reminder notification fires when the card becomes available.
  - **success:** FR-25 and FR-6b consequences pass. `lockedDays` and `catchUpWindow` are each defined once (AD-40). A catch-up completed within its window keeps the streak.
- **CAP-10** — Tutor on their own device
  - **intent:** A rebbe granted access can maintain a talmid's main track, deadline and sub-tracks from their own phone. They see all their talmidim with on-track status, and lose access as soon as the parent revokes the grant.
  - **success:** FR-26, FR-28 and FR-29 consequences pass under AD-53: one `can_edit_learning` permission, online-only writes, and the grant re-checked on every callable. The multi-talmid list meets the AD-54 performance gate.
- **CAP-11** — Change history and undo
  - **intent:** The parent sees who changed what and when for every governed entity and learning event, can undo any change field by field, and gets a push when a tutor changes the goal or the main track.
  - **success:** FR-27 consequences pass under AD-38 and AD-39. A client can't bypass the owner rule, and every tutor callable writes through `writeWithChangeLog`. Undo restores only the fields that haven't changed since. All legacy goal and track writers are rerouted in the same release (AD-38, AD-54).
- **CAP-12** — Lifetime record and reports
  - **intent:** The child or parent can see every event for any mishna, and the parent can export a lifetime report and a per-source velocity report as PDFs.
  - **success:** FR-30 through FR-32 consequences pass. Reports are built only from `LearnerState` and render unpointed Hebrew (AD-48). Same-named sub-tracks roll up into one row.
- **CAP-13** — One learning store, app-wide
  - **intent:** Every curriculum's progress, positions, calendar assignments, reviews due, streak, siyumim, points and planner input come from `learning_events` and stored intent through one pure `LearnerStateEngine`.
  - **success:** After the cutover release, `completions`, `learning_ledger`, `streak_events`, `bookmarks` and `learning_order` receive zero writes, and `tool/check_retired_symbols.dart` passes in CI and their repositories and rules are removed. Every consumer in the spine's Retirement Inventory is rewired or deleted. The planner computes no quantity of its own (AD-49).

## Constraints

- `learning_events` is append-only and is the only record of learning for every curriculum. Old stores are retired without data migration (AD-31, AD-49, parent AD-13).
- Every derived number comes from one pure engine, with no server-side summary. Positions, the schedulable set and ground return are never persisted (AD-33, AD-35).
- Owner devices write only through `LearningCommands` and tutor devices only through `TutorWriteService` → `writeWithChangeLog`. No other write path exists (spine Consistency Conventions).
- A lock failure fails closed. Firestore rules never reject a queued write from a supported client, so writes made during a lock are excluded when the engine derives state (AD-36, parent AD-30).
- Tutor writes are online-only. Owner capture works fully offline (AD-53).
- Firestore field names are exactly those in the spine's Storage Schema table (AD-52).
- Epic 1 is the learning-event cutover (AD-49): engine and command layer, then rules and callables, then the Retirement Inventory groups R1–R16, then the cutover release. No sub-track story starts before that release ships.
- Named-app Auth wiring (parent AD-1 and AD-24) must be in place before any epic that ships a new repository.
- Rules, indexes and functions are deployed by a gated CI step before the app release that depends on them. Batches are sized by the Firestore Rules access-call budget; governed changes too large for one offline batch go online through `writeWithChangeLog` (AD-54).
- Performance: recompute takes < 1 s per learner at 20 learners × (40,000 leaf events + 200 node events) on a tutor device within the 20 MiB cache (AD-54).
- Children's data: analytics carry only enums and counts. Two items are release preconditions: the GA4 under-13 legal check (AD-47) and a privacy-policy update disclosing tutor access and change history (PRD §4.10).
- Stack: the FlutterFire packages move together as one bump, and the Dart SDK minimum is ^3.12.0 (spine Stack table).

## Non-goals

- No change to how the main track plans or lays out tasks beyond its schedulable set shrinking and growing. It still learns one masechta at a time.
- No sub-goals or sub-track deadlines. There is one deadline, on the main track.
- No school calendars, term dates, imports, school accounts or per-country school logic.
- The app never prompts or suggests sub-tracks.
- No cross-track position syncing or deduplication. Overlapping ground is allowed and not reconciled.
- In v1: no app-learned calendars, confidence intervals or rate suggestions.
- No data migration from the old stores, no staging Firebase project, and no server-side learner summaries.

## Success signal

- Take a learner with a main-track deadline plus School and Rebbe sub-tracks. They record a full day in ≤ 4 taps. Their daily target matches the FR-19 fixtures, including an unchanged target after ground is entered. A write attempted during a shabbos lock on any device doesn't count, and a one-tap catch-up keeps the streak.
- Across the whole app, every curriculum's progress, streak, siyum and points read from `learning_events`, while `completions`, `learning_ledger` and `streak_events` receive no writes.
- Post-release targets: SM-1 ≥ 80% of non-locked days captured, and SM-3 ≥ 90% of locked days caught up.

## Assumptions

- Where the spine deliberately differs from the PRD, the spine wins (`prd-deviations.md`). This follows Daniel's architecture decisions on 2026-09-30, and bead `learning-tracker-5ul` tracks the PRD amendment.
- Lifetime-report grouping of same-named sub-tracks is in scope. FR-31 overrides the contradictory line in PRD §6.2.
- The spec lives in `docs/planning/specs/`, not `_bmad-output/`, because repo CLAUDE.md sends BMAD outputs to `docs/`.
