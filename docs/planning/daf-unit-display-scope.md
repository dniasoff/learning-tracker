# Scope: Daf as the learning & display unit for Talmud (amud → daf)

**Status:** Scoped, product decisions made (2026-06-14). Phase 1 in progress.
**Origin:** DSWEEP finding — a daf-paced Bavli track shows "Items remaining 5349" in
*amudim*. For Talmud the unit a learner thinks in is the **daf**.

## Product model (decided with Daniel)

The unit hierarchy has TWO levels that must each be honored:

- **Amud = the atomic / common unit.** **Lifetime & cross-track aggregates stay in amudim.**
  Rationale: lifetime spans *all* tracks; a learner may have a daf track AND an amud track.
  Mixing "dapim" and "amudim" in one aggregate is confusing and unsustainable, so the
  aggregate uses the common denominator — the amud (1 daf = 2 amudim). **No change to
  lifetime counts** (they already show leaf = amud).
- **Daf = the track unit for a daf track.** A daf track *presents, paces, counts, and is
  marked-done in dapim*. When showing "what to learn", show **one daf**, not two amudim —
  combine them. **The daf is the unit of marking**: marking a daf done completes both
  amudim in one action. A structurally single-amud daf is **still one daf** (never present
  or count a lone amud to the user in a daf track).

**Breadth:** Bavli only (the only amud-leaf curriculum). Other curricula keep their natural
leaf unit. Yerushalmi's mislabeled "daf" (it's modeled Perek→Halacha) is a **separate**
content/label fix, out of scope.

## Current state (verified in code)

Storage is **amud-atomic** and stays that way (no migration):
- Completion = one `completion_events` row per amud leaf — `completion_writer.dart`.
- Bavli hierarchy L1=Masechta, L2=Daf, **L3=Amud=leaf** — `bavli.json`.

The **learn/mark flow is currently amud-atomic** (this is the gap, not display-only):
- Scheduler batches a daf's amudim into one *day* BUT emits **two separate `DailyTask`s**
  (2a, 2b) — `scheduler_engine.dart:268-308`.
- Dashboard/learning list shows **2 task cards per daf**; tapping opens a single amud —
  `active_track_card.dart`, `learning_screen.dart`, `daily_task_card.dart`.
- Reader shows **one amud**, prev/next steps **amud-by-amud**, mark-complete commits a
  **single** amud — `text_display_screen.dart:564-596,~56,~86`; `adjacentContentRefsProvider`.
- All Bavli dapim currently have 2 amudim; single-amud handling is forward-compatible
  (`coarseUnitKey` already groups a coarse unit with any leaf count).

Already daf-correct (reuse): scheduler **paces** in dafim; program dashboard "today" pill
collapses to daf (`collapseAmudToDaf`); `scopedCoarseUnitCountProvider` = distinct daf count;
add-track wizard pace step (daf default, projected finish in daf); all **percentages**.

## Phased plan (by risk)

### Phase 1 — track "Items remaining" in the pace unit (display; LOW risk) ← SHIPPED
Honors "track shows daf, lifetime stays amudim". Infra already exists.
- **S1** Track-detail **Items remaining** → the goal's pace unit (daf for a daf-paced Bavli
  track), mirroring the already-daf "Est. finish" via `scopedCoarseUnitCountProvider`.
  `track_detail_screen.dart`. (Generic: follows the goal's granularity, so it's coherent
  with the estimate on the same card; lifetime is separate and stays amudim.)
- **Required pace** for a *pace* goal already shows the user's stated daf value
  ("7 · Per week") — no change. Only the **actual-velocity** number is still amud/day →
  folded into Phase 2 (needs the amud→daf ratio + a "{n} daf/day" label).
- **S3 Lifetime/progress** — **explicitly unchanged** (stays amudim, the common unit).
- Tests: items-remaining-in-daf for a daf-paced track; stays leaf for fine/other tracks.

### Phase 2 — daf-atomic daily task, marking & pace velocity (core flow; MED-HIGH risk)
"Present one daf, mark the daf." Also: **actual-pace velocity** → daf/day (× coarse/leaf
ratio) with a "{n} daf/day" label for a daf track (`track_info_card.dart`).

- **✅ 2a (shipped) — daf-atomic MARKING.** On a coarse-paced track (daf/perek/seif) the
  reader's mark-complete now completes the WHOLE coarse unit in one action (both amudim of a
  daf), via `coarseUnitLeafRefs` + marking each leaf through the existing use case (per-amud
  rows/points/siyum/sync unchanged; idempotent). "Next task" skips the whole daf
  (`_nextDailyTaskAfterRefs`). Gated by `goal.paceGranularity` being coarse. +helper tests.
- **✅ 2c (shipped) — actual/required pace velocity in daf/day** (`track_info_card.dart`),
  via the coarse÷leaf ratio + ARB `trackInfoDafPerDay`.
- **2b (next) — one card per daf.** Group the day's same-daf amud tasks into a single card
  (count "1 today", not 2). Presentation-only. (Today the day still lists individual amud
  cards — 2a, 2b — though marking either completes the whole daf.)

### ON-DEVICE VERIFICATION (2026-06-14, emulator-5556, daf-paced Bavli track)
Phases 1 + 2a + 2c all PASS:
- Items remaining = **2684** (dapim, not ~5422 amudim). ✓ (Phase 1)
- Actual pace = **"1.0 daf/day"** (not "items/day"); Required = "7 · Per week". ✓ (2c)
- One "Mark complete" on Berakhot 2a → BOTH amudim done, reader advanced to **Berakhot 3**
  (next daf, skipped 2b); daily task count dropped 3→1. ✓ (2a daf-atomic)
- No crash/regression. ✓

### NEW finding (during verification) — Edit-Goal screen shows amudim for a daf track
The **Edit Goal** form's unit toggle defaults to **עמודים/amudim** ("5349 of 5349 items")
for a daf-paced track, instead of pre-selecting **דף/daf** + the daf count. Track Detail
(items + pace) correctly shows daf, so this is an Edit-Goal display-consistency bug — the
form doesn't reflect the saved `goal.paceGranularity`. Folded into the remaining work
(small: pre-select the saved granularity + show the matching count in the edit form).

### REMAINING (next increments)
- 2b — one daf card in the daily list (presentation grouping).
- Edit-Goal unit pre-selection (the new finding above).
- Phase 3 — reader presents/navigates by daf for a daf track (gated so free browsing stays
  amud-by-amud).
- Scheduler emits **one DailyTask per daf** carrying both amud refs (or a daf-keyed task),
  for daf-granularity tracks — `scheduler_engine.dart`, `daily_task.dart`.
- Mark-complete on a daf task commits **both amudim atomically** via
  `completion_writer.commitBatch` — `mark_completion_use_case.dart`, the dashboard/reader
  mark handlers. (Single-amud daf → commits its one amud, still "the daf".)
- Dashboard/learning list shows **one card per daf**.
- Heavy test + on-device verification (core learning flow).

### Phase 3 — reader presents/navigates by daf (MED risk) ← after Phase 2
- For a daf track the reader shows the daf (both amudim) with a single "mark daf complete";
  prev/next steps **daf-by-daf** — `text_display_screen.dart`, `adjacentContentRefsProvider`
  (needs track-granularity context, since the reader is also used for free browsing where
  amud nav stays correct).

## Risks / notes
- No storage migration (completion stays amud-level; daf is an aggregation/UX construct).
- Reader is shared by daily-learning AND free browsing — daf nav must be gated to daf-track
  learning context, not applied to browsing.
- Test churn: Phase 1 ≈ a few count/label tests; Phase 2/3 touch scheduler + completion +
  reader (larger).

## Effort
Phase 1 ≈ small (mostly wiring existing infra). Phase 2 ≈ a focused wave (scheduler + batch
completion + list UI). Phase 3 ≈ medium (reader). Phases 2–3 each warrant their own
implement→ci→on-device-verify cycle.
