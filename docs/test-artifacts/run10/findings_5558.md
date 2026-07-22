# Run-10 — emulator-5558 (API 31, Android 12): Dashboard, progress, charts

**Findings: 1 × P1 (APP, reproduced 2/2). 0 × P0.** Light mode only per assignment.
Two already-known issues reconfirmed and deliberately **not** double-counted.

> Filed by the coordinator on the auditor's behalf — its harness returns findings as text
> rather than writing files. Content is the auditor's, verbatim in substance.
> Screenshots session-local under the scratchpad (`run10_5558/`), not checked in.

## Headline: the Lifetime Knowledge denominator is 70,033 — and always was

Measured on **both** builds: the pre-Part-B install (last updated 16:27) **and** a
post-Part-B build containing `5db8634c`. **70,033 on both. 93,395 was never observed.**

This corrects a coordinator claim made earlier in the run. **R8 Part B is a
memory/caching fix, not a miscount fix** — the displayed total was already correct, so the
device evidence shows Part B introduced **no regression**, rather than showing it repaired
a user-visible defect.

Seed used: 4 live completions (1 Talmud daf = 2 leaf refs — Amud Aleph + Bet, confirmed
intentional — plus 3 Mishnayos) → Lifetime 5. Then a bulk-mark of the entire Masechet Peah
(69 items / 207 records) → Lifetime 74, Siyumim 1 (after restart; see F1).

## F1 — P1 (APP, reproduced 2/2): bulk-mark does not invalidate the summary/header aggregates

After a confirmed bulk-mark of Peah, **fresh** navigation (not cached screens) to every one
of these still showed pre-bulk-mark numbers verbatim (5 / 0 / 0.1%):

- Dashboard "Lifetime" tile
- Progress tab "Lifetime" and "Siyumim" tiles
- per-track "Lifetime: X%" line
- Lifetime Knowledge **top summary card**

Meanwhile, **on the same screen**, the per-curriculum breakdown rows *below* that stale
header were already correct (72 of 4,192 = 1.7%), and Recent Activity → All Time was
already correct (74). Siyumim & Milestones showed "No siyumim yet" despite a completed
masechta.

`am force-stop` + relaunch instantly corrected **every** stale surface — proving the data
was written correctly all along and only certain providers failed to react.

**Contrast that makes it a bug, not intent:** live single "Mark complete" taps updated
Dashboard / Progress / Recent Activity immediately all session (verified by nav-away/back
*and* background/foreground). The bulk path fails to invalidate the *same* summary
providers the live path does. The in-app confirm dialog explicitly promises immediate
effect — *"They'll appear in Lifetime Knowledge and may unlock siyumim"* — so the asymmetry
contradicts a documented promise.

**Severity P1, not P0:** no data loss, no permanently wrong value, self-heals on restart —
but it hits most primary screens simultaneously and tells the user their work vanished.

### ✅ FIXED AND DEVICE-CONFIRMED (build `77977737`)

Re-verified on 5558 by the same auditor who characterised it. Strongest evidence: **Track
Detail — the exact screen that was stuck stale — landed on "Track progress: 0.1% Lifetime:
10.3%" live, same session, zero restart.** Manage Tracks went 2.9% → 4.7% immediately after
a bulk-mark. Siyumim & Milestones no longer reads "No siyumim yet" and populated 1 → 6.
Monotonic sequences across six masechtot (Lifetime 74→127→204→293→394→434) confirm no data
loss despite three further environment-class device deaths mid-run.

Also confirmed on the same build: all six siyumim render **"Previously learned"** rather
than "Jan 1, 2000" (the sentinel-date fix), independently corroborated on 5554 for a
different data set.

**Live single-mark path:** the 5558 auditor could not re-exercise it on this build and
honestly labelled it *inferred, not observed*. Closed directly by the 5554 auditor on the
**same build** — a reader mark auto-advanced correctly with Daily Tasks 5→4 and Dashboard
"Today Due" 5→4, guest-clean. Two devices, complementary coverage.

**Independently corroborated by code analysis** (see the coordinator's separate finding):
the live path calls `ref.read(completionCommittedProvider.notifier).increment()`
(`text_display_screen.dart:704`) — the single signal these providers watch — and the bulk
path never does. `bulk_mark_screen.dart` `_executeBulkMark()` invalidates only a
hand-picked list that omits `lifetimeTotalsAcrossAllCurriculaProvider`,
`trackDualProgressMetricsProvider` and `journeyViewModelProvider`. Device evidence and code
evidence arrived independently and agree.

## Reconfirmed, deliberately not re-reported as new

Found `docs/test-artifacts/run10/progress-percentage-divergence.md` already on disk and
cross-referenced rather than duplicating it:
- **"Jan 1, 2000" siyum date** — reproduced live (Peah siyum shows exactly that date).
- **Percentage divergence** — same shape the existing analysis already explains.

## Ruled out — not findings

- Daf-Beis counting as 2 leaf refs (Amud Aleph + Bet) — intentional.
- Cumulative Progress showing a single dot before more data — expected.
- Siyumim empty state — correct.
- "Track learning only" vs "All sources" toggle showing identical numbers — correct, given
  no lifetime-only imports existed.

## Reactivity summary

- **Live completions:** fully reactive (nav-away/back and background/foreground both confirmed).
- **Bulk-mark:** reactive for Recent Activity and the per-curriculum breakdown; **not**
  reactive for summary/header tiles until restart (F1).

## Environment

emulator-5558 died **7 times**, always mid-interaction under host load 28–36 on 24 cores.
**All confirmed ENVIRONMENT** — the auditor grepped the entire session's
`/tmp/logcat_5558.log` (the host-side mirror that survives device death) for the
guest-failure patterns scoped to our package and found **zero matches for the whole
session**. Recovered per protocol each time; no data loss across restarts. Near-simultaneous
restart timestamps on 5556/5562/5564 confirm the pattern was fleet-wide, not device-specific.

## Coverage

Dashboard (all cards, hero, carousel, stats) · Progress tab (stats, Recent Activity incl.
All Time / weekly / cumulative chart, Siyumim & Milestones, Lifetime Knowledge incl.
drill-down and both filters) · bulk-mark flow.
