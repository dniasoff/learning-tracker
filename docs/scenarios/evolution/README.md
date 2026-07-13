> **OBSOLETE — superseded 2026-05-19.** The catch-up & amnesty design has been assessed as over-scoped and is **not being implemented**. The overdue/recovery model is being refactored under a simpler approach — see `docs/planning/overdue-refactor-architecture.md`. Retained for historical reference only.

---
title: "Evolution Scenarios — Catch-up & Amnesty (Epic 22)"
description: Scenario and spec set for Epic 22 — recovery from out-of-sync states, rescope, amnesty, pause, and multi-track triage.
date: 2026-04-19
epic: 22
linear: https://linear.app/dniasoff/issue/DNI-255
status: superseded
---

# Evolution Scenarios — Catch-up & Amnesty (Epic 22)

> ⚠️ **Status — 2026-04-19 (superseded 2026-05-19, see banner above):** Every file under `docs/scenarios/evolution/` was a design artifact for **Epic 22** (DNI-255) — Catch-up & Amnesty System. Epic 22 is **Canceled** in Linear (all 22 stories Canceled); the design was assessed as over-scoped and is not being implemented. Data primitives referenced in these docs were **never implemented** in code:
>
> - `item_amnesty` table
> - `track_action_log` table
> - `paceResetDate` column on `curriculum_tracks`
> - `cycle_tag` field
> - Pause state (distinct from Archive)
>
> These docs are retained for historical reference only. Do not treat any of them as an implementation-ready spec or as documentation of existing behavior — see `docs/planning/overdue-refactor-architecture.md` for the current approach.

## Structure

- **`scenarios/`** — user-facing scenario outlines (what the learner sees and does). 9 files, one per surface.
- **`specs/`** — technical specifications (data flow, state machine, engineering detail). 9 files matching the scenarios 1:1.

## File map

| # | Surface | Scenario | Spec |
|---|---------|----------|------|
| 01 | Catch-up Sheet (self-paced) | [`scenarios/01-catchup-sheet.md`](scenarios/01-catchup-sheet.md) | [`specs/01-catchup-sheet-spec.md`](specs/01-catchup-sheet-spec.md) |
| 02 | Triage Sheet (multi-track) | [`scenarios/02-triage-sheet.md`](scenarios/02-triage-sheet.md) | [`specs/02-triage-sheet-spec.md`](specs/02-triage-sheet-spec.md) |
| 03 | Pause Control | [`scenarios/03-pause-control.md`](scenarios/03-pause-control.md) | [`specs/03-pause-control-spec.md`](specs/03-pause-control-spec.md) |
| 04 | Review Debt View | [`scenarios/04-review-debt-view.md`](scenarios/04-review-debt-view.md) | [`specs/04-review-debt-view-spec.md`](specs/04-review-debt-view-spec.md) |
| 05 | Learning Journey View | [`scenarios/05-learning-journey-view.md`](scenarios/05-learning-journey-view.md) | [`specs/05-learning-journey-view-spec.md`](specs/05-learning-journey-view-spec.md) |
| 06 | Amnesty History | [`scenarios/06-amnesty-history.md`](scenarios/06-amnesty-history.md) | [`specs/06-amnesty-history-spec.md`](specs/06-amnesty-history-spec.md) |
| 07 | Setup Seeding Flow | [`scenarios/07-setup-seeding-flow.md`](scenarios/07-setup-seeding-flow.md) | [`specs/07-setup-seeding-flow-spec.md`](specs/07-setup-seeding-flow-spec.md) |
| 08 | Returning Learner Onboarding | [`scenarios/08-returning-learner-onboarding.md`](scenarios/08-returning-learner-onboarding.md) | [`specs/08-returning-learner-spec.md`](specs/08-returning-learner-spec.md) |
| 09 | Cycle Boundary Welcome | [`scenarios/09-cycle-boundary-welcome.md`](scenarios/09-cycle-boundary-welcome.md) | [`specs/09-cycle-boundary-welcome-spec.md`](specs/09-cycle-boundary-welcome-spec.md) |

## Related documents

- **Catch-up & Amnesty design doc** — [`../../planning/catchup-and-amnesty-scenarios.md`](../../planning/catchup-and-amnesty-scenarios.md)
- **Linear epic** — [DNI-255 — Epic 22: Catch-up & Amnesty System](https://linear.app/dniasoff/issue/DNI-255)
- **Epic status summary** — [`../../linear-status.md`](../../linear-status.md#epic-22--catch-up--amnesty-system-dni-255)
