---
title: "Project Status (Linear)"
description: "Canonical epic and story status, reconciled against local sprint-status.yaml."
date: 2026-07-13
---

# Project Status (Linear)

## Overview

- **Team:** DNI (Dniasoff)
- **Linear project:** learning-tracker
- **Status source:** [`docs/status/sprint-status.yaml`](status/sprint-status.yaml) (synced 2026-05-13) for Epics ≤21 — the YAML has no rows for Epics 24–27 at all (last touched 2026-04-15, before those epics existed); for that range this doc is reconciled directly against Linear instead (see AUD-docs-21 note under Epic 25 below).
- **Last reconciled:** 2026-07-13 (AUD-docs-21 — Epics 24–27 re-verified directly against Linear; previously wrongly shown "All Backlog" despite completing 2026-05-14)
- **Totals:** 18 epics · 194 stories tracked in Linear

This document is the narrative summary. `sprint-status.yaml` is the machine-readable source of truth for the epics it covers (≤21) — if the two disagree there, trust the YAML. It has no rows at all for Epics 24–27 (AUD-docs-21); for that range, Linear itself is the source of truth.

## Project phase

The v1 build (Epics 1–23) was completed and shipped to internal testers. Most of those epics are now **Canceled** in Linear, meaning their scope was superseded by the **Greenfield Rebuild** (Epics 24–27). The rebuild carried greenfield permission: wipe-install boundary, new DB schema, Firebase reset acceptable.

All stories prior to Epic 24 (DNI-312) that were not already Done are now **Canceled**. **The Greenfield Rebuild (Epics 24–27, 82 stories) is Done — all four epics completed 2026-05-14**, the day after they were created in Linear (verified directly against Linear 2026-07-13; this doc previously read "All Backlog" for two months). There is no active surface tracked in Linear as of this reconciliation.

## Epic summary

| Linear ID | Epic | Stories | Status |
|---|---|---|---|
| — | 1 — Foundation & Infrastructure | — | Delivered (pre-Linear) |
| — | 2 — Content Import & Browsing | — | Delivered (pre-Linear) |
| — | 3 — Core Learning Cycle | — | Delivered (pre-Linear) |
| — | 4 — Multi-Track Learning | — | Delivered (pre-Linear) |
| — | 5 — Configurable Stages & Learning Order | — | Delivered (pre-Linear) |
| — | 6 — Smart Scheduler | — | Delivered (pre-Linear) |
| — | 7 — Dashboard & Progress | — | Delivered (pre-Linear) |
| DNI-12 | 8 — Gamification & Engagement | 3 | Canceled |
| DNI-13 | 9 — Onboarding Flow | 5 | Canceled |
| DNI-14 | 10 — Parent Mode | 6 | Canceled |
| DNI-15 | 11 — Tutor Mode | 4 | Canceled |
| DNI-16 | 12 — Notifications | 3 | Canceled |
| DNI-17 | 13 — Cloud Sync | 3 | Canceled |
| DNI-18 | 14 — Settings | 4 | Canceled |
| — | 15 — Multi-Profile & Learning Program | — | Absorbed into Epics 18 & 21 |
| — | 16 — Onboarding-to-Dashboard Perfect Flow | — | Delivered (pre-Linear) |
| DNI-154 | 17 — V1 Roadmap Phase 1 (umbrella) | 8 | Canceled |
| DNI-128 | 18 — Onboarding & Track Management Overhaul | 8 | Canceled (all stories Canceled) |
| — | 19 — Offline-First Architecture & Two-Database Split | — | Delivered (pre-Linear) |
| DNI-210 | 20 — Dashboard & Progress Redesign — Multi-Track Isolation | 12 | Todo (all 12 Canceled) |
| DNI-238 | 21 — Multi-Account Device — Account Switching, Session Management & Deletion | 0 | Backlog |
| DNI-255 | 22 — Catch-up & Amnesty System | 22 | Canceled (all stories Canceled) |
| DNI-278 | 23 — Manual QA Verification | 18 | Canceled (all stories Canceled) |
| DNI-297 | 24 — Firestore Sync Schema & Multi-Device Data Restoration *(superseded)* | 10 | Canceled (all stories Canceled) |
| DNI-312 | 24 — Stop-the-Bleeding (Phase 0) | 8 | Done (all 8 stories Done) |
| DNI-313 | 25 — Schema + Core Foundation (Phases 1 + 2) | 22 | Done (all 22 stories Done) |
| DNI-314 | 26 — Feature Rebuilds + Cleanups (Phases 3 + 4) | 35 | Done (33 Done, 2 Canceled) |
| DNI-315 | 27 — Discipline & Closure (Phases 5 + 6 + 7) | 17 | Done (16 Done, 1 Canceled) |

> Epics 1–7, 16, and 19 were delivered before Linear ticket tracking was in place. Their Linear IDs were never created; status is inferred from git history and the old epic docs.

## Active work

No open stories tracked in Linear as of 2026-07-13. The greenfield rebuild epics (24–27, 82 stories) all completed 2026-05-14; all pre-E24 stories are Canceled or Done.

## Rebuild completion (formerly "Upcoming work") — all four epics Done 2026-05-14

1. **Epic 24 — Stop-the-Bleeding (Phase 0) (DNI-312)** — 8 stories, all Done. Critical fixes under the existing schema; shipped first to close data-loss / security holes before the schema wipe. See [`planning/epics-greenfield-rebuild.md`](planning/epics-greenfield-rebuild.md).
2. **Epic 25 — Schema + Core Foundation (DNI-313)** — 22 stories, all Done. Wipe-install boundary; local DB v1, Firestore v1, ten rebuilt core subsystems, Hebrew UI infrastructure.
3. **Epic 26 — Feature Rebuilds + Cleanups (DNI-314)** — 35 stories, 33 Done + 2 Canceled (26.34, 26.35). Eight feature areas reorganized to consume the new core; label/ARB/naming/dead-code sweep.
4. **Epic 27 — Discipline & Closure (DNI-315)** — 17 stories, 16 Done + 1 Canceled (27.17, Play Store CI/CD). Test pyramid, CI gates, observability, docs reconciliation.

## Canceled / superseded

The following epics are **Canceled** in Linear because their scope was either delivered and superseded by the rebuild, or deprioritized:

| Epic | Reason |
|---|---|
| 8 — Gamification & Engagement | Delivered v1; rebuild rewrites this area |
| 9 — Onboarding Flow | Delivered v1; rebuild replaces with new Add Track flow |
| 10 — Parent Mode | Delivered v1; rebuild supersedes |
| 11 — Tutor Mode | Deprioritized; code functional but no new investment |
| 12 — Notifications | Delivered v1; rebuild includes notification system rewrite (E27) |
| 13 — Cloud Sync | Delivered v1; rebuild replaces SyncEngine architecture (E25) |
| 14 — Settings | Delivered v1; rebuild supersedes |
| 17 — V1 Roadmap Phase 1 | Umbrella epic; no discrete stories; closed |
| 18 — Onboarding & Track Management Overhaul | Superseded by E24–E26; all stories now Canceled |
| 20 — Dashboard & Progress Redesign | All 12 stories Canceled; redesign scope reabsorbed into E26 |

Epic 24 (DNI-297) — *Firestore Sync Schema & Multi-Device Data Restoration* — is the **old** Epic 24 created before the greenfield rebuild was scoped. All 10 stories are now **Canceled**; scope is absorbed by E25 (Firestore v1 collection layout) and E26 (sync engine decomposition).

## Epic details — Greenfield Rebuild (Epics 24–27)

Design doc: [`docs/planning/epics-greenfield-rebuild.md`](planning/epics-greenfield-rebuild.md)

### Epic 24 — Stop-the-Bleeding (Phase 0) (DNI-312) — **Done** (completed 2026-05-14)

Critical fixes under the existing schema. No new architecture. Shipped first to close data-loss / security holes before the wipe-install boundary in E25. All 8 stories Done (verified against Linear).

| ID | Story | Status |
|---|---|---|
| DNI-316 | 24.1: Per-collection Firestore rules with field validators and emulator test job | Done |
| DNI-317 | 24.2: Soft-delete tracks; stop cascading into append-only tables | Done |
| DNI-318 | 24.3: Centralize sign-out through AuthRepository | Done |
| DNI-319 | 24.4: Wire Crashlytics in main.dart before any other init | Done |
| DNI-320 | 24.5: Migrate sync_engine and OfflineQueue to AppLogger; rewrite PII redactor | Done |
| DNI-321 | 24.6: Multi-profile leak band-aid via cross-profile scope assertions | Done |
| DNI-310 | 24.7: Sync curriculum track activation to Firestore | Done |
| DNI-311 | 24.8: Sync learning order to Firestore | Done |

> **AUD-docs-21 correction (2026-07-13):** the three sections below previously claimed Epics 25–27 were "All Backlog" — checked directly against Linear (not `sprint-status.yaml`, which stops at Epic 21 and has no rows for 24–27 at all; the "Status source" line above does not apply to this range). All 74 stories across Epics 25–27 completed **2026-05-14**, the day after each epic was created — `test/story_acceptance/epic_2[567]_*.dart` (31 files) corroborates this: 30/31 carry no `skip:` marker (the one exception, `epic_27_story_4_widget_golden_test.dart` / Story 27.4, has a partial `skip:`). Re-check via `mcp__linear__list_issues` with `parentId: DNI-313/314/315` before trusting either this doc or the YAML for this epic range.

### Epic 25 — Schema + Core Foundation (Phases 1 + 2) (DNI-313) — **Done** (completed 2026-05-14)

Wipe-install boundary. Local DB v1, Firestore v1, ten rebuilt core subsystems. Hebrew UI core infrastructure.

22 stories: 25.1–25.22. **All 22 Done** (verified against Linear). Highlights:
- **25.1**: Schema-v1 user DB skeleton (renamed tables, profileId PKs, no defaults, FKs)
- **25.4**: Firestore v1 collection layout and per-collection rules
- **25.5**: Outbox table and OutboxProcessor scaffolding
- **25.11**: core/auth/AuthRepository — sole Firebase Auth consumer
- **25.12–25.14**: SyncEngine decomposition (FirestoreGateway, PushPipeline, PullPipeline, MergeRouter, ListenerSupervisor)
- **25.15**: core/learning/CompletionWriter — single transactional commit path
- **25.20**: MaterialApp locale auto-detection + Noto Sans Hebrew bundling + direction-aware CurriculumLabel + real dark theme
- **25.22**: Wipe-install cutover end-to-end verification

### Epic 26 — Feature Rebuilds + Cleanups (Phases 3 + 4) (DNI-314) — **Done** (completed 2026-05-14)

35 stories: **33 Done, 2 Canceled** (verified against Linear). Eight feature areas reorganized to consume the new core. Label/ARB/naming/dead-code sweep. RTL audit.

Selected highlights:
- **26.1–26.4**: Scheduler strategy pattern, pace math fix, classification fixes, GoalEntity refactor
- **26.5–26.8**: Dashboard decomposition (20 widgets extracted, TrackCard, dashboardModelProvider, TrackProgressVariant deleted)
- **26.9–26.12**: AddTrackController state machine, OnboardingController, ProfileCreationUseCase
- **26.13–26.16**: Reader purity, ContentTree lookup, CompositeCurriculumStrategy, Tappable Progress stats
- **26.33**: Dead code purge — ≥10,000 LOC across reducers, services, tables, widgets, ARB keys, themes, network modules
- **26.34**: Delete deprecated TextDownloadService — **Canceled**
- **26.35**: Remove promoteToCloud / demoteToLocal auth shims — **Canceled**

### Epic 27 — Discipline & Closure (Phases 5 + 6 + 7) (DNI-315) — **Done** (completed 2026-05-14)

17 stories: **16 Done, 1 Canceled** (verified against Linear). Test pyramid, CI gates, observability, docs.

| ID | Story | Status |
|---|---|---|
| DNI-377 | 27.1: Test infrastructure — fake_cloud_firestore, golden scaffolding, real-Drift in-memory helper | Done |
| DNI-378–DNI-385 | 27.2–27.9: Unit, DAO, widget/golden, integration test suites | Done |
| DNI-386, DNI-387 | 27.10–27.11: Custom lints Parts 1 & 2 | Done |
| DNI-388, DNI-389 | 27.12–27.13: CI matrix + make audit target | Done |
| DNI-390 | 27.14: 12 analytics events + Crashlytics user ID | Done |
| DNI-391 | 27.15: docs/architecture.md rewrite | Done |
| DNI-392 | 27.16: CLAUDE.md / coding-standards.md layering rules | Done |
| DNI-127 | 27.17: CI/CD — Play Store deployment pipeline | Canceled |

## Canceled — pre-rebuild epics

### Epic 22 — Catch-up & Amnesty System (DNI-255)

22 stories, all **Canceled**. Design was complete but scope is superseded by the greenfield rebuild.

### Epic 23 — Manual QA Verification (DNI-278)

18 stories, all **Canceled**. Superseded; QA will be re-scoped against the rebuilt app (see E27).

## Orphaned stories

6 stories have `epic: none` — all Canceled. No action required.

| ID | Title | Status |
|---|---|---|
| DNI-106 | 14.2: Data Export & Import (JSON) | Canceled |
| DNI-121 | 15.13: Cloud Content Storage & Multilingual Fetch | Canceled |
| DNI-166 | 18.1: Extract Reusable Add Track Flow (הוספת מסלול) | Canceled |
| DNI-167 | 18.2: Slim Global Onboarding (Global Settings Only) | Canceled |
| DNI-168 | 18.3: Track Management Hub (ניהול מסלולים) | Canceled |
| DNI-176 | 18.11: Replace "Browse Curricula" with "Add Track" on Empty States | Canceled |

## How to sync

```bash
# Refresh Linear ticket cache
./tool/linear-sync.sh sync

# Cache location
~/.local/share/linear-sync/dniasoff/learning-tracker/
```

The YAML cache at `docs/status/sprint-status.yaml` is managed by `tool/linear-sync.sh`. Do not hand-edit `linear-mapping.yaml`.
