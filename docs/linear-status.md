---
title: "Project Status (Linear)"
description: "Canonical epic and story status, reconciled against local sprint-status.yaml and linear-mapping.yaml."
date: 2026-04-19
---

# Project Status (Linear)

## Overview

- **Team:** DNI (Dniasoff)
- **Linear project:** learning-tracker
- **Status sources:**
  - Machine-readable: [`docs/status/sprint-status.yaml`](status/sprint-status.yaml) (updated 2026-04-15)
  - Linear ID mapping: [`docs/status/linear-mapping.yaml`](status/linear-mapping.yaml) (managed by `tool/linear-sync.sh`)
  - Detailed epic breakdowns: [`docs/planning/epics.md`](planning/epics.md)
- **Last reconciled:** 2026-04-19

This document is the narrative summary. `sprint-status.yaml` is the machine-readable source of truth — if the two disagree, trust the YAML.

## Epic summary

| Epic | Title | Stories | Status |
|---|---|---|---|
| 1 | Foundation & Infrastructure | 12 | Done |
| 2 | Content Import & Browsing | 5 | Done |
| 3 | Core Learning Cycle | 3 | Done |
| 4 | Multi-Track Learning | 3 | Done |
| 5 | Configurable Stages & Learning Order | 2 | Done |
| 6 | Smart Scheduler | 5 | Done |
| 7 | Dashboard & Progress | 3 | Done |
| 8 | Gamification & Engagement | 3 | Done |
| 9 | Onboarding Flow | 5 | Done |
| 10 | Parent Mode | 6 | Done |
| 11 | Tutor Mode | 4 | Done — **deprioritized**, see [archive](_archive/scrapped-ideas/tutor-mode-epic-11.md) |
| 12 | Notifications | 3 | Done |
| 13 | Cloud Sync | 3 | Done |
| 14 | Settings | 4 | Done |
| 15 | (Multi-Profile & Learning Program) | — | Absorbed into Epics 18 & 21 — see [archive](_archive/scrapped-ideas/epic-15-multi-profile-original-stories.md) |
| 16 | Onboarding-to-Dashboard Perfect Flow | 6 | Done |
| 17 | V1 Roadmap Phase 1: Foundation & Onboarding | 0 | Linear-tracked umbrella, no discrete stories |
| 18 | Onboarding & Track Management Overhaul | 12 | In progress (all 12 in review) |
| 19 | Offline-First Architecture & Two-Database Split | 13 | Done |
| 20 | Dashboard & Progress Redesign — Multi-Track Isolation | 12 | All 12 stories canceled 2026-04-15; UI redesign not yet re-scoped |
| 21 | Multi-Account Device — Account Switching, Session Management & Deletion | 16 | Done |
| 22 | Catch-up & Amnesty System | 22 planned | Backlog (design complete) |
| 23 | Offline-First Architecture v2 — Hard-Tier Auth Refactor | 0 | Done (completed 2026-04-15) |

## Epic details

### Epic 1 — Foundation & Infrastructure (DNI-5)
Flutter project init, Drift schema and DAOs, Firebase Auth + Firestore, Sefaria client, auto_route shell, Riverpod, Talker, CI/CD, sync engine foundation, theme, security infrastructure (bcrypt, secure storage), Hebrew calendar utilities. All 12 stories done.

### Epic 2 — Content Import & Browsing (DNI-6)
Sefaria content import pipeline, hierarchical browser, text display (Hebrew/English), curriculum activation, bundled-content JSON + dev seed script. 5 stories done. Epic 2 retrospective complete.

### Epic 3 — Core Learning Cycle (DNI-7)
Mark completion (single item), completion history & stage progression, bookmark management. 3 stories done. The completions table uses `sefariaRef` (String), not `content_item_id`.

### Epic 4 — Multi-Track Learning (DNI-8)
Track management, track assignment & duplicate prevention, track-specific progress views. 3 stories done. Retrospective: `docs/_archive/epic-qa-reports/epic-4-retrospective-2026-03-12.md`.

### Epic 5 — Configurable Stages & Learning Order (DNI-9)
Stage definition configuration, drag-and-drop learning order. 2 stories done.

### Epic 6 — Smart Scheduler (DNI-10)
Parametric scheduler engine, daily task generation, goal management (per-curriculum deadlines), pace tracking, cross-curriculum daily schedule composer. 5 stories done. Three schedule types: **delay**, **Friday/Shabbos Review**, **Shabbos Review**.

### Epic 7 — Dashboard & Progress (DNI-11)
Cross-curriculum dashboard, per-curriculum progress views, progress charts and statistics. 3 stories done.

### Epic 8 — Gamification & Engagement (DNI-12)
Points system, streak tracking, mystery rewards. 3 stories done.

### Epic 9 — Onboarding Flow (DNI-13)
Welcome & user mode selection, curriculum selection, per-curriculum goal setup, bulk mark prior completions, initial rewards setup (child mode). 5 stories done.

### Epic 10 — Parent Mode (DNI-14)
PIN setup & auth, parent dashboard, reward management CRUD, point value configuration, track management, parent analytics. 6 stories done.

### Epic 11 — Tutor Mode (DNI-15) — deprioritized
PIN setup & auth, tutor dashboard, completion history views, chazara due & progress views. 4 stories done — but the feature has been deprioritized as of 2026-04-19. Code remains functional; no new investment. See [`_archive/scrapped-ideas/tutor-mode-epic-11.md`](_archive/scrapped-ideas/tutor-mode-epic-11.md).

### Epic 12 — Notifications (DNI-16)
Daily learning reminders, streak protection alerts, reward milestone notifications. 3 stories done. Shabbos/Yom Tov quiet mode via kosher_dart zmanim.

### Epic 13 — Cloud Sync (DNI-17)
Push-on-write, pull-on-launch, foreground real-time listeners. 3 stories done.

### Epic 14 — Settings (DNI-18)
General settings, notification preferences, data export/import, account management. 4 stories done.

### Epic 15 — (was Multi-Profile & Learning Program)
No Linear epic. 14 design stories were drafted in early March; the work was absorbed by Epics 18 and 21 with different numbering. The original story files are archived under [`_archive/superseded/epic-15-stories/`](_archive/superseded/epic-15-stories/). See [`_archive/scrapped-ideas/epic-15-multi-profile-original-stories.md`](_archive/scrapped-ideas/epic-15-multi-profile-original-stories.md) for the mapping.

### Epic 16 — Onboarding-to-Dashboard Perfect Flow (DNI-128)
Pace-based goal mode, study day configuration, dashboard pace/progress integration, per-item review count display, onboarding goal & study day steps, dashboard polish. 6 stories done.

### Epic 17 — V1 Roadmap Phase 1 (DNI-154)
An umbrella epic with no discrete stories. Used as a roadmap placeholder.

### Epic 18 — Onboarding & Track Management Overhaul (DNI-128) — **in progress**
12 stories, all currently in review:
- 18.1 Extract reusable add-track flow
- 18.2 Slim global onboarding
- 18.3 Track management hub
- 18.4 Hebrew terms, chazara, curriculum names
- 18.5 Track editing from Settings
- 18.6 Child mode onboarding post-setup rewards
- 18.7 Navigation state cleanup
- 18.8 Instant mark complete
- 18.9 Prevent duplicate profile names
- 18.10 Add/delete profile from profile picker
- 18.11 Fix edit profile button in Settings
- 18.12 Delete account redirects to Welcome

Story specs: [`docs/stories/implementation/18-*.md`](stories/implementation/).

### Epic 19 — Offline-First Architecture & Two-Database Split (DNI-182) — **done**
13 stories delivered. Split the monolithic database into a read-only Content DB (bundled as `assets/seed.db.gz`, 4 tables) and a read-write User DB (22 tables, schema v15). Local calendar engine removes runtime dependency on Sefaria/Hebcal. Startup hardened to ~140ms with zero network calls.

> **Tech debt flag:** Stories 19.5 (local-first auth abstraction) and 19.7 (optional account creation in Settings) implement the anonymous-localUid auth model. That model has since been superseded by the hard-tier cloud-born/local-born design in [`planning/architecture-offline-v2.md`](planning/architecture-offline-v2.md). Epic 20 (b) is the refactor. Epic 19 all other stories (two-DB split, seed DB, calendar engine, startup hardening, SyncEngine conditional activation, content DB resilience, E2E testing) remain canonical.

### Epic 20 — Dashboard & Progress Redesign — Multi-Track Isolation (DNI-210) — **backlog**
12 stories, all backlog. Per-track scoping of DAOs, domain models, providers; per-track scheduler; dashboard stats row + unified task list; 4 track-card variants; recovery actions; redesigned progress and track-detail screens; charts with track filter; Learning Journey rework. Scenario specs: [`docs/scenarios/dashboard-redesign-set/`](scenarios/dashboard-redesign-set/).

### Epic 21 — Multi-Account Device — Account Switching, Session Management & Deletion (DNI-238) — **done**
16 stories delivered. Device account registry, per-account database isolation, session auto-resume and persistence, unified sign-up (email/password + Google), smart sign-in routing, account picker, sign-out to picker, multi-account upgrade, and the full deletion path (local, cloud, and cloud function). Story specs: [`docs/stories/implementation/21-*.md`](stories/implementation/).

### Epic 22 — Catch-up & Amnesty System (DNI-255) — **backlog, design complete**
22 stories planned across 14 groups covering rescope v2, amnesty primitive, pause mechanism, catch-up sheets (self-paced + program), review debt, multi-track triage, setup seeding, cycle boundary, and a notification rewrite. Scenario-level specs at [`docs/scenarios/evolution/`](scenarios/evolution/); scenarios at [`docs/planning/catchup-and-amnesty-scenarios.md`](planning/catchup-and-amnesty-scenarios.md).

### Epic 23 — Offline-First Architecture v2 — Hard-Tier Auth Refactor (DNI-223) — **done**
Completed 2026-04-15. Dropped `AppAuthState` sealed hierarchy, added `passwordHash` + `tier` columns, made signup mandatory at first launch, tier-gated SyncEngine. Originally filed as "Epic 20" — renamed to Epic 23 on 2026-04-19 to resolve the numbering collision with DNI-210 (Dashboard Redesign). Canonical design doc: [`planning/architecture-offline-v2.md`](planning/architecture-offline-v2.md).

## In review right now

From `sprint-status.yaml` (2026-04-15):

- All 12 stories of Epic 18.

Recent git history (last 40 commits) shows active theme, onboarding, notifications, parent-mode, and auth work — consistent with Epic 18 in review and Epic 21 recently completed.

## Upcoming work (ordered by priority)

1. **Epic 18 finalization** — bring the 12 in-review stories to done.
2. **Epic 20 — Dashboard & Progress Redesign** — 12 stories, per-track isolation. Unblocked now that Epic 23 (v2 auth refactor) has shipped.
3. **Epic 22 — Catch-up & Amnesty System** — 22 stories planned; ready to start breaking out.

## How to sync

```bash
# Refresh Linear ticket cache
./tool/linear-sync.sh

# Cache location
~/.local/share/linear-sync/dniasoff/learning-tracker/
```

Status YAML files live in [`docs/status/`](status/) and are managed by BMAD workflows. Do not hand-edit `linear-mapping.yaml`.
