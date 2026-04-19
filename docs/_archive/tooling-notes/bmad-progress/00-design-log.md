# Design Log — Learning Tracker

## Backlog

- [x] Dashboard track card variants (Program Calendar, Deadline, Velocity, Momentum)
- [x] Dashboard composition (header, stats row, task list, card section)
- [x] Progress screen per-track views
- [x] Track detail screen redesign
- [x] Restart/recovery actions UX (Jump to today, Reset pace — documented in card specs + track detail)

## Current

| Task | Scenario | Page | Started |
|------|----------|------|---------|
| Catch-up & Amnesty UX scoping | 9 surfaces from scenarios doc | All new surfaces | 2026-04-13 |

## Design Loop Status

| Date | Scenario | Page | Status | Notes |
|------|----------|------|--------|-------|
| 2026-04-13 | Catch-up & Amnesty | Catch-up Sheet | specify | S2/S3/S4 — 595-line spec, 3 variants, all design decisions resolved |
| 2026-04-13 | Catch-up & Amnesty | Triage Sheet | specify | S9/S11 — 609-line spec, PageView sequence, bulk actions, 20 acceptance criteria |
| 2026-04-13 | Catch-up & Amnesty | Pause Control | specify | 536-line spec, PausePicker + ResumeCard + dashboard muting |
| 2026-04-13 | Catch-up & Amnesty | Review Debt View | specify | S6/S7 — 566-line spec, swipe-to-amnesty, severity detection, 33 acceptance criteria |
| 2026-04-13 | Catch-up & Amnesty | Learning Journey View | specify | S8 — 504-line spec, adaptive grid/ribbon, 5 fill states with accessible patterns |
| 2026-04-13 | Catch-up & Amnesty | Amnesty History | specify | 477-line spec, unforgive, cycle sections, 24 acceptance criteria |
| 2026-04-13 | Catch-up & Amnesty | Setup Seeding Flow | specify | S14/S15 — 777-line spec (largest), S14+S15 variants, 31 acceptance criteria |
| 2026-04-13 | Catch-up & Amnesty | Returning Learner | specify | S9 — 540-line spec, WelcomeVariant enum, dormancy+pause-return, 26 acceptance criteria |
| 2026-04-13 | Catch-up & Amnesty | Cycle Boundary Welcome | specify | 455-line spec, active+non-participant variants, 17 acceptance criteria |
| 2026-04-01 | Dashboard Redesign | Dashboard | specify | Main page spec + 4 card variant specs written |
| 2026-04-01 | Dashboard Redesign | Progress | specify | Progress screen spec with sub-screens (charts, journey, history) |
| 2026-04-01 | Dashboard Redesign | Track Detail | specify | Track detail screen spec with variant-specific progress, settings, recovery actions |

## Log

- **2026-04-13** — Full design specification complete for all 9 new surfaces. 5,059 lines of spec across 9 files in `evolution/specs/`. All open design decisions resolved. 206 total acceptance criteria. Shared components identified: PauseOfferPrompt, swipe-to-amnesty+snackbar, LifetimeProgressSummary, AmnestyHistoryScreen. Ready for implementation.
- **2026-04-13** — UX scoping complete for all 9 new surfaces from the Catch-up & Amnesty scenarios doc. Scenario files written to `evolution/scenarios/01-09`.
- **2026-04-01** — Dashboard & Progress redesign analysis complete. All 7 design questions resolved. Track isolation decided. 4 card variants identified. Restart/recovery scenarios documented. Full page audit done.
- **2026-04-01** — Dashboard page spec written (01-dashboard.md). 4 card variant specs written: Program Calendar (02), Deadline (03), Velocity (04), Momentum (05). Covers layout, content, states, recovery actions, child/adult modes, data sources, tone guide.
