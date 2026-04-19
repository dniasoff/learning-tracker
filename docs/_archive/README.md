---
title: Documentation Archive
description: Index of parked, superseded, or scrapped documentation. Nothing here is active.
date: 2026-04-19
---

# Documentation Archive

This folder is a **graveyard, not a reference**. Everything here is one of:

- **Scrapped** — ideas considered during planning and not pursued.
- **Superseded** — docs replaced by newer, canonical versions elsewhere.
- **Historical QA** — epic-specific checklists and reports kept for audit only.
- **Tooling notes** — stale harness/agent instructions.

Do not treat any file under `_archive/` as current project state. If you find yourself needing information from here, check the active docs first (`docs/index.md`) and promote back only with explicit approval.

## Contents

### scrapped-ideas/

Concepts that were mentioned during planning and then cut from scope. Preserved so their history is legible and the same ideas don't silently re-enter the product.

- [`school-and-tutor-tracks.md`](scrapped-ideas/school-and-tutor-tracks.md) — Three-track model (Personal + School + Tutor). Shipped in code; parent-mode can activate school/tutor tracks. **Deprioritized** from v1 onboarding and roadmap 2026-04-19.
- [`tutor-mode-epic-11.md`](scrapped-ideas/tutor-mode-epic-11.md) — Epic 11 Tutor Mode (PIN-protected in-app tutor dashboard). Fully wired in code (routes, guards, screens). **Deprioritized** from roadmap 2026-04-19.
- [`tutor-companion-app.md`](scrapped-ideas/tutor-companion-app.md) — Standalone companion app for tutors/schools. Cut from roadmap 2026-04-19.
- [`epic-15-multi-profile-original-stories.md`](scrapped-ideas/epic-15-multi-profile-original-stories.md) — 14 design stories numbered 15.1–15.14. Work shipped (131KB acceptance test file exists) but was never Linear-tracked under Epic 15. Original story files archived below.

### superseded/

Docs replaced by newer canonical versions still present under `docs/planning/`.

- [`architecture-v1-2026-01-04.md`](superseded/architecture-v1-2026-01-04.md) — Initial architecture. Replaced by `docs/planning/architecture.md` (2026-04-14) and `docs/planning/architecture-offline-v2.md` (2026-04-10).
- [`ux-design-specification-2026-02-11.md`](superseded/ux-design-specification-2026-02-11.md) — Broad UX spec pre-dating the upgrade-flow and dashboard-redesign work. Scenario-specific specs under `docs/scenarios/` are canonical.
- [`development-handoff-2026-02-11.md`](superseded/development-handoff-2026-02-11.md) — One-time handoff to development. Subsumed by the developer handbook.
- [`component-specifications-2026-02-11.md`](superseded/component-specifications-2026-02-11.md) — Early component catalogue. Replaced by `docs/component-inventory.md`.
- [`product-brief-2026-01-03.md`](superseded/product-brief-2026-01-03.md) — Original product brief. PRD (`docs/planning/prd.md`) is the active reference.
- `epic-15-stories/` — 14 story files from the original Multi-Profile epic. Work delivered under Epics 18 and 21.

### epic-qa-reports/

Per-epic QA artifacts kept for retrospective audit only.

- [`epic-1-qa-report.md`](epic-qa-reports/epic-1-qa-report.md)
- [`QA_CHECKLIST_DNI32.md`](epic-qa-reports/QA_CHECKLIST_DNI32.md) — Epic 2 content-import QA from early project.

### tooling-notes/

Stale harness and tooling instructions. None of these tools are active on this repo.

- [`AGENTS.md`](tooling-notes/AGENTS.md) — Instructions for the obsolete `bd` (beads) issue tracker.
- [`VALIDATION_NOTES.md`](tooling-notes/VALIDATION_NOTES.md) — Ad-hoc validation checklist.
- [`app_flow.md`](tooling-notes/app_flow.md) — Early app-flow diagram notes.
- `app_architecture.eraserdiagram` — Eraser diagram source; architecture is documented in `docs/architecture.md` and `docs/planning/architecture.md`.

## Why archive instead of delete?

Keeping old context in one clearly-labelled place lets readers answer "why was this decided?" without cluttering the active doc set. If an archived idea becomes relevant again, promote a fresh version — don't re-activate the old file.
