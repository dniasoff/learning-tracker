---
title: "Superseded: Epic 15 Multi-Profile & Learning Program Stories"
description: 14 original story files numbered 15.1–15.14. Work delivered via Epics 18 and 21 under different numbering.
status: superseded
superseded_by: Epics 18, 21
cut_on: 2026-04-19
---

# Superseded: Epic 15 — Multi-Profile & Learning Program System

## What was planned

Epic 15 was a design-phase epic titled **"Multi-Profile and Learning Program System"** with 14 stories drafted between late February and early March 2026. The stories lived in `_bmad-output/stories/story-15.1…story-15.14` but were never synced to Linear.

Original story set:

| # | Title |
|---|-------|
| 15.1 | Multi-profile data model |
| 15.2 | Profile picker & management UI |
| 15.3 | New curricula support |
| 15.4 | Learning program presets |
| 15.5 | Expanded stage scheduling |
| 15.6 | Learning process wizard |
| 15.7 | Enhanced bulk mark |
| 15.8 | Revised onboarding flow |
| 15.9 | Program management settings |
| 15.10 | Dirshu test tracking |
| 15.11 | Profile-scoped providers sync |
| 15.12 | AppBar FittedBox fix |
| 15.13 | Cloud content storage |
| 15.14 | Test suite health |

## What actually shipped

Epic 15 work **did ship** — the 131KB acceptance test file `test/story_acceptance/epic_15_multi_profile_test.dart` is the authoritative record. But the work was never Linear-tracked as an Epic 15 project; instead, it was delivered across:

- **Epic 18 — Onboarding & Track Management Overhaul** (DNI-128):
  - Profile management (15.1, 15.2, 15.11) — tests under 18.9, 18.10, 18.11, 18.12
  - Onboarding revision (15.6, 15.8) — tests under 18.1, 18.2, 18.6
  - Instant mark-complete (related to 15.7) — tests under 18.8
  - Hebrew terminology / track management (15.9) — tests under 18.3, 18.4, 18.5
  - Navigation cleanup — tests under 18.7

- **Epic 21 — Multi-Account Device** (DNI-238):
  - Per-account database isolation — 21.2 (related to 15.1 data model goal)
  - Account lifecycle, signout, deletion — 21.1, 21.3, 21.4, 21.9–21.16

- **Dirshu test tracking (15.10)** — shipped as the `test_tracking` feature module (domain-only services; no dedicated UI).
- **Cloud content storage (15.13)** — superseded by Epic 19's bundled seed database approach.
- **Test suite health (15.14)** — ongoing.

The Epic 15 tests are still run by `make test-epic-15` / CI.

## Why this file exists

The original story files are preserved under `docs/_archive/superseded/epic-15-stories/` for traceability. They should not be used for active planning — current epic and story status lives in `docs/linear-status.md` and `docs/status/sprint-status.yaml`.

## Implication for Linear

`docs/linear-status.md` previously reported Epic 15 as "no stories defined, 0/0". That wording is retired: Epic 15 is not tracked in Linear because its scope was absorbed into Epics 18 and 21.
