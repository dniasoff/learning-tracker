---
title: "Learning Tracker - Project Overview"
description: "Entry point for understanding the Learning Tracker project: a multi-curriculum Torah learning tracker built with Flutter and Dart."
date: 2026-04-19
---

# Learning Tracker - Project Overview

## How to use this document

Start here to learn about the tech stack, architecture, feature modules, and supported curricula. For the full doc index, see [`index.md`](./index.md). For a hands-on guide, see the [Developer Handbook](./developer-handbook.md).

## Executive summary

Learning Tracker is a multi-curriculum Torah learning tracker for Android, built with Flutter and Dart. It provides daily study management with smart scheduling, chazara (review) cycles, progress tracking, and gamification. The app supports two user modes: a gamified, parent-managed experience for children and a self-directed mode for adults.

The app covers nine Torah curricula sourced from Sefaria, with Hebrew and English display. Core capabilities include adaptive daily scheduling, multi-stage review cycles, offline-first data with cloud sync, and a lifetime learning ledger. A PIN-protected parent dashboard handles analytics and reward management.

**Codebase snapshot (AUD-docs-16, re-verified 2026-07-13):** 704 source files (`find lib -name '*.dart'`, excluding `.g.dart`/`.freezed.dart`), 865 test files, 15 feature modules.

## Tech stack

| Category | Technology | Version / Notes |
|---|---|---|
| Framework | Flutter | 3.38.6+ |
| Language | Dart | 3.10.8+ |
| State Management | Riverpod | 3.x with code generation |
| Navigation | auto_route | 11.x (type-safe, code generated) |
| Local DB | Drift (SQLite ORM) | Three databases: User DB (24 tables, schema v35) + Content DB (4 tables, read-only, v5) + Device Registry DB (2 tables, v1) — see `tool/gen_arch_tables.dart` / `docs/architecture.md` §Database Schema |
| Backend | Firebase | Auth + Cloud Firestore + Storage |
| Data Classes | Freezed | Immutable models |
| HTTP | dio | 5.9+ (Sefaria API, dev-time only) |
| Logging | Talker suite | — |
| Testing | mocktail, flutter_test | — |
| Calendar | kosher_dart | Hebrew date support |
| Security | flutter_secure_storage, bcrypt | PIN hashing |
| Charts | fl_chart | — |
| Notifications | flutter_local_notifications | Shabbos/Yom Tov quiet mode |
| Code Generation | build_runner | drift, auto_route, freezed, riverpod, json_serializable |

## Architecture overview

Feature-first Clean Architecture with 15 feature modules (AUD-docs-16, re-verified 2026-07-13). Each module has three layers:

```text
feature/
  data/          # Repositories, data sources, DTOs
  domain/        # Entities, use cases, repository interfaces
  presentation/  # Screens, widgets, providers
```

### Key architecture decisions

| ID | Decision |
|---|---|
| D1 | Generic 4-level content hierarchy (single table for all curricula) |
| D2 | Firebase Auth with email/password + Google Sign-In |
| D3 | Separate `stage_definitions` table with configurable review cycles |
| D4 | Hybrid push/pull sync with offline queue |
| D5 | User mode enum (child/adult) with feature flags |
| D7 | Separate `learning_order` table (content kept immutable) |
| D8 | Per-curriculum points + global streak |
| D-TWODB | Two databases: read-only Content DB + read-write User DB (Epic 19) |

### Patterns

- **Repository pattern** with nullable returns (P2)
- **Curriculum-scoped Riverpod family providers** (P3)
- **Flat Firestore collections** with deterministic IDs (P4)
- **UTC storage with local display** (P5)
- **Offline-first** with push-on-write, pull-on-launch, foreground listeners (D4)

## Feature modules

> **AUD-docs-16 regenerated 2026-07-13** — derived from `ls lib/features/`. The prior revision named 6 features that no longer exist under that name (`auth`→`account`; `learning_order`/`stages`/`track_setup`→folded into `tracks/`) and 2 that were removed outright (`test_tracking`, `tutor_mode`→renamed `tutoring`), while omitting `sacred_time`, `tutoring`, and `tracks`. See `docs/architecture.md` §Feature Modules for file counts and the dependency graph.

| Module | Description |
|---|---|
| **account** | Firebase Auth (email/password + Google Sign-In), local-born accounts, hard-tier upgrade flow |
| **content_browsing** | Browses and displays curriculum content from bundled Sefaria assets |
| **dashboard** | Main dashboard with daily tasks and cross-curriculum summaries |
| **gamification** | Per-curriculum points, global streak, mystery rewards |
| **learning** | Core learning flow with completion tracking and stage progression |
| **notifications** | Local notifications with Shabbos/Yom Tov quiet mode |
| **onboarding** | User setup (child/adult mode), curriculum selection, initial configuration |
| **profiles** | Multi-profile management, profile switching, parent-mode PIN-protected analytics and reward management |
| **progress** | Tracks and visualizes learning progress across curricula |
| **sacred_time** | Shabbos/Yom Tov lock overlay, zmanim-based start/end times, city picker |
| **scheduler** | Smart daily schedules with adaptive pacing and deadline tracking |
| **settings** | App preferences, data export/import, account settings |
| **sync** | `SyncWriteFacade`/outbox push entry points consumed by other features (sync engine internals live in `core/sync/`) |
| **tracks** | Track management hub, track setup/detail/editing, stage definitions (up to 10 stages), custom learning order |
| **tutoring** | Cross-user tutor access — invite/accept/revoke grant lifecycle, tutor dashboard, tutor write proxies (see `docs/api-contracts.md` §1.3) |

### Schedule types

- **Delay-based** — review after a configurable number of days.
- **Friday/Shabbos Review** — weekly consolidation layered on top of delay-based chazara.
- **Shabbos Review** — same, single review day.

## Supported curricula

Nine Torah curricula, all sourced from Sefaria. Content is bundled at build time and shipped in the APK — no runtime API calls.

| Curriculum | `CurriculumId` | Category | Items |
|---|---|---|---|
| **Mishnayos** | `mishnayos` | Oral Law | 4,192 mishnayos across 6 sedarim |
| **Gemara Bavli** | `bavli` | Oral Law | ~2,711 dapim, full Shas |
| **Gemara Yerushalmi** | `yerushalmi` | Oral Law | Full Talmud Yerushalmi |
| **Mishna Berurah** | `mishna_berurah` | Law Codes | 697 simanim |
| **Mishneh Torah** | `mishneh_torah` | Law Codes | Maimonides' 14-book code of Jewish law |
| **Chumash** | `chumash` | Biblical | 5,845 pesukim across the Five Books |
| **Nach** | `nach` | Biblical | Prophets + Writings |
| **Tanach** | `tanach` | Biblical | Full Hebrew Bible as a single curriculum |
| **Mussar** | `mussar` | Ethics | Multi-sefer library of mussar works |

Users activate only the curricula they need and scope each to specific sedarim, masechtos, or sefarim.

## Project status

**Re-verified 2026-07-13 (AUD-docs-16)** — sourced from [`docs/linear-status.md`](./linear-status.md), which is the canonical epic/story status document and the authoritative detail behind this summary (per-epic status, reasons for cancellation/supersession, story counts).

| Metric | Value |
|---|---|
| Epics delivered pre-rebuild (v1, Epics 1–7/16/19 pre-Linear + 21) | 1–14, 16, 19, 21 — several later superseded by the greenfield rebuild (their Linear tickets show Canceled once replaced; see linear-status.md) |
| Greenfield rebuild — Epics 24–27 | **Delivered** — 82 stories, completed 2026-05-14 |
| Epics Canceled outright (never shipped) | 17, 18, 20, 22, 23 |
| Total stories tracked in Linear | 194 |

## Links

| Document | Path |
|---|---|
| Documentation index | [`index.md`](./index.md) |
| Developer handbook | [`developer-handbook.md`](./developer-handbook.md) |
| Architecture (current state) | [`architecture.md`](./architecture.md) |
| Architecture (design intent) | [`planning/architecture-design.md`](./planning/architecture-design.md) |
| Data models | [`data-models.md`](./data-models.md) |
| Testing guide | [`testing-guide.md`](./testing-guide.md) |
| Linear status | [`linear-status.md`](./linear-status.md) |
| Parked ideas | [`_archive/README.md`](./_archive/README.md) |
