---
title: "Learning Tracker — Documentation Index"
description: "Entry point for every doc in this repository. Read-in-order path for new contributors."
date: 2026-04-19
---

# Learning Tracker — Documentation Index

All project documentation lives under `docs/`. Nothing canonical lives outside it.

## Read in this order

1. **[Project Overview](project-overview.md)** — 5 min. What the app is, the tech stack, feature modules, curricula, project status.
2. **[Developer Handbook](developer-handbook.md)** — 30 min. Domain concepts (Chazara, Tracks, Programs), architecture mental models, setup, Make targets, testing, coding standards, troubleshooting.
3. **[Architecture](architecture.md)** — Current-state architecture generated from code. Reference while writing a feature.
4. **[Data Models](data-models.md)** — Three-database schema (User DB 24 tables, Content DB 4 tables, Device Registry DB 2 tables — AUD-docs-16, re-verified 2026-07-13), ER diagram, DAO operations, Firestore collections.
5. **[Testing Guide](testing-guide.md)** — Test architecture, fixtures, mocks, gotchas.
6. **[Project Status](linear-status.md)** — Current epic and story status.

For domain-specific deep dives, see the flows and planning sections below.

## Reference docs

- [Project Overview](project-overview.md)
- [Developer Handbook](developer-handbook.md)
- [Architecture (current state)](architecture.md)
- [Coding Standards](coding-standards.md)
- [App Check Enforcement Status](appcheck-enforcement.md) — PV-6 enforcement record
- [Data Models](data-models.md)
- [Component Inventory](component-inventory.md)
- [Source Tree Analysis](source-tree-analysis.md)
- [Testing Guide](testing-guide.md)
- [Privacy Policy](privacy-policy.md)
- [Firestore Rewrite Map](firestore-rewrite-map.md) — active migration map and greenfield/no-backfill contract

## Planning and design (`planning/`)

Active planning artifacts — the design intent and the rationale behind the current code.

- [PRD](planning/prd.md)
- [Architecture — Design Intent](planning/architecture-design.md) — comprehensive design-level doc
- [Architecture Quick Reference](planning/architecture-quick-reference.md)
- [Firestore Finish-Line Plan](planning/firestore-finish-line-plan.md) — live migration execution plan
- [Overdue System — Refactor Architecture](planning/overdue-refactor-architecture.md) — target design for the overdue/scheduler refactor (2026-05-19)
- [Epics](planning/epics.md) — detailed epic + story breakdowns
- [Calendar Cycle Computation Analysis](planning/calendar-cycle-analysis.md)
- [Catch-up & Amnesty Scenarios](planning/catchup-and-amnesty-scenarios.md) — **superseded 2026-05-19** by [Overdue System — Refactor Architecture](planning/overdue-refactor-architecture.md)
- [Upgrade Flow — UX Spec](planning/ux-upgrade-flow-spec.md) — **partially superseded 2026-07-13** (local-born password-verify step; see in-file banner)
- [Upgrade Flow — Visual Design](planning/ux-upgrade-flow-visual.md) — **partially superseded 2026-07-13** (W-02 password-verify screen; see in-file banner)
- [UX Patterns Quick Reference](planning/ux-patterns-quick-reference.md)
- [Testing Quick Reference](planning/testing-quick-reference.md) — **superseded 2026-07-13** by [Testing Guide](testing-guide.md) and [Test Options](test-options.md)
- [Research](planning/research/)

## Flows (`flows/`)

Feature-flow documentation — how a specific user flow works end-to-end.

- [Add Track Flow](flows/add-track-flow.md)
- [Dashboard Redesign Analysis](flows/dashboard-redesign-analysis.md)

## Scenarios (`scenarios/`)

UX scenario specifications driving upcoming epics.

- [Evolution Set](scenarios/evolution/) — **superseded 2026-05-19**; catch-up/amnesty design replaced by [Overdue System — Refactor Architecture](planning/overdue-refactor-architecture.md)
- [Stitch Prompts](scenarios/stitch-prompts/) — AI-generated UI design prompts

## Stories (`stories/`)

Story-level implementation specs, produced before each story is coded.

- [Implementation Artifacts](stories/implementation/) — one file per shipped or in-flight story (Epics 1, 16, 18, 19, 21)

## Status (`status/`)

Machine-readable project status files, managed by BMAD workflows.

- [`sprint-status.yaml`](status/sprint-status.yaml) — authoritative per-epic/per-story status for Epics ≤21; for Epics 24–27, see [Project Status (Linear)](linear-status.md)
- [`linear-mapping.yaml`](status/linear-mapping.yaml) — Linear ticket ID mapping
- [`bmm-workflow-status.yaml`](status/bmm-workflow-status.yaml) — BMAD workflow state
- [`wds-workflow-status.yaml`](status/wds-workflow-status.yaml) — WDS workflow state

## QA (`qa/`)

- [Testing methodology and per-epic test plans](qa/legacy/)

## Archive (`_archive/`)

Parked, superseded, and historical material. Not active reference.

- [Archive README](_archive/README.md) — index of everything here and why
- Scrapped ideas: [School/Tutor tracks](_archive/scrapped-ideas/school-and-tutor-tracks.md), [Tutor Mode (parked)](_archive/scrapped-ideas/tutor-mode-epic-11.md), [Tutor Companion App](_archive/scrapped-ideas/tutor-companion-app.md), [Epic 15 originals](_archive/scrapped-ideas/epic-15-multi-profile-original-stories.md)
- Superseded: original architecture v1, early UX spec, early component spec, January product brief
- Historical QA: epic-1 QA report, Epic 2 QA checklist, Epic 4 retrospective, DNI-122 coverage report
- Tooling notes: AGENTS, VALIDATION_NOTES, app_flow, project-scan

## Outside `docs/`

- [`README.md`](../README.md) — the repo's public front page (features, install, contribute).
- [`CLAUDE.md`](../CLAUDE.md) — pointer for AI agents; they should come to this index.
- [`LICENSE`](../LICENSE) — MIT.

## Getting started

```bash
git clone https://github.com/dniasoff/learning-tracker.git
cd learning-tracker/learning_tracker
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run

# Tests
make ci                    # full local CI
make test-story-X.Y        # individual story
make test-epic-N           # all stories in an epic
```

See the [Developer Handbook](developer-handbook.md) for the full setup and workflow.
