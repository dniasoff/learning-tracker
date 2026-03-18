---
title: "Learning Tracker - Project Overview"
description: "Entry point for understanding the Learning Tracker project: a multi-curriculum Torah learning tracker built with Flutter and Dart."
date: 2026-03-18
---

# Learning Tracker - Project Overview

## How to Use This Document

This document serves as the entry point for understanding the Learning Tracker project. Start here to learn about the tech stack, architecture, feature modules, and supported curricula. For navigating all project documentation, visit the [Documentation Index](./index.md).

## Table of Contents

- [Executive Summary](#executive-summary)
- [Tech Stack](#tech-stack)
- [Architecture Overview](#architecture-overview)
- [Feature Modules](#feature-modules)
- [Supported Curricula](#supported-curricula)
- [Project Status](#project-status)
- [Links to Other Docs](#links-to-other-docs)

## Executive Summary

Learning Tracker is a multi-curriculum Torah learning tracker for Android, built with Flutter and Dart. It provides daily study management with smart scheduling, chazara (review) cycles, progress tracking, and gamification. The app supports two user modes: a gamified, parent-managed experience for children and a self-directed mode for adults.

The app covers nine Torah curricula sourced from Sefaria, with Hebrew and English display. Core capabilities include adaptive daily scheduling, multi-stage review cycles, offline-first data with cloud sync, and a lifetime learning ledger. Parent and tutor modes offer PIN-protected dashboards for analytics and reward management.

**Codebase:** ~366 source files, 182 test files, 17 feature modules.

## Tech Stack

| Category | Technology | Version / Notes |
|---|---|---|
| Framework | Flutter | 3.29.4+ |
| Language | Dart | 3.10.8+ |
| State Management | Riverpod | 3.x with code generation |
| Navigation | auto_route | 11.x (type-safe, code generated) |
| Database | Drift (SQLite ORM) | 2.31+, 22 tables |
| Backend | Firebase | Auth + Cloud Firestore + Firebase Storage |
| Data Classes | Freezed | Immutable models |
| HTTP | dio | 5.9+ (Sefaria API) |
| Logging | Talker suite | -- |
| Testing | mocktail, flutter_test | -- |
| Calendar | kosher_dart | Hebrew date support |
| Security | flutter_secure_storage, bcrypt | PIN hashing |
| Charts | fl_chart | -- |
| Notifications | flutter_local_notifications | Shabbos/Yom Tov quiet mode |
| Code Generation | build_runner | drift, auto_route, freezed, riverpod, json_serializable |

## Architecture Overview

The project follows **feature-first Clean Architecture** with 17 feature modules. Each module organizes code into three layers:

```text
feature/
  data/          # Repositories, data sources, DTOs
  domain/        # Entities, use cases, repository interfaces
  presentation/  # Screens, widgets, providers
```

### Key Architecture Decisions

| ID | Decision |
|---|---|
| D1 | Generic 4-level content hierarchy (single table for all curricula) |
| D2 | Firebase Auth with email/password + Google Sign-In |
| D3 | Separate `stage_definitions` table with configurable review cycles |
| D4 | Hybrid push/pull sync with offline queue |
| D5 | User mode enum (child/adult) with feature flags |
| D7 | Separate `learning_order` table (content kept immutable) |
| D8 | Per-curriculum points + global streak |

### Architecture Patterns

- **Repository pattern** with nullable returns (P2)
- **Curriculum-scoped Riverpod family providers** (P3)
- **UTC storage with local display** (P5)
- **Offline-first** with push-on-write, pull-on-launch, and foreground listeners (D4)

## Feature Modules

The app organizes its functionality into 17 feature modules:

| Module | Description |
|---|---|
| **auth** | Handles Firebase Auth (email/password + Google Sign-In) |
| **content_browsing** | Browses and displays curriculum content from Sefaria (Hebrew/English) |
| **dashboard** | Presents the main dashboard with daily tasks and curriculum summaries |
| **gamification** | Manages per-curriculum points, global streak, and mystery rewards |
| **learning** | Drives the core learning flow with completion tracking and stage progression |
| **learning_order** | Controls the sequence and ordering of learning items per curriculum |
| **notifications** | Delivers local notifications with Shabbos/Yom Tov quiet mode |
| **onboarding** | Guides user setup, curriculum selection, and initial configuration |
| **parent_mode** | Provides a PIN-protected analytics and reward management dashboard for parents |
| **profiles** | Supports multi-profile management (up to 10 learner profiles per account) |
| **progress** | Tracks and visualizes learning progress across curricula |
| **scheduler** | Generates smart daily schedules with adaptive pacing and deadline tracking |
| **settings** | Manages app preferences, data export/import, and account settings |
| **stages** | Defines and configures multi-stage review cycles (Learn, Chazara 1, Chazara 2, up to 10 stages) |
| **sync** | Handles offline queue, cloud sync (push/pull), and conflict resolution |
| **test_tracking** | Tracks test results and performance analytics |
| **tutor_mode** | Provides a PIN-protected read-only dashboard for tutors |

### Schedule Types

The scheduler supports three modes:

- **Delay-based** -- review after a configurable number of days
- **Weekly** -- review on specific days of the week
- **Rolling window** -- review within a sliding time window

## Supported Curricula

Nine Torah curricula are supported, all sourced from Sefaria. The following table shows each curriculum and its approximate item count:

| Curriculum | Items |
|---|---|
| **Mishnayos** | 4,192 mishnayos across 6 sedarim |
| **Gemara Bavli** | ~2,711 dapim, full Shas |
| **Gemara Yerushalmi** | Full Talmud Yerushalmi |
| **Mishna Berurah** | 697 simanim |
| **Chumash** | 5,845 pesukim across all 5 chumashim |
| **Nach** | Full Tanach |
| **Mussar** | Multi-sefer library of mussar works |
| **Halacha** | Halachic works |
| **Torah** | Torah text |

All curricula support Hebrew and English display via the Sefaria API. Users activate only the curricula they need and scope each one to specific sedarim, masechtos, or sefarim.

## Project Status

**As of 2026-03-18** (from Linear):

| Metric | Value |
|---|---|
| Total Epics | 15 |
| Total Stories | 89 |
| Done | 86 |
| In Review | 3 (Epic 14: Settings) |
| Not Started | Epic 15: Multi-Profile (no stories yet) |

Overall completion: **~97% of defined stories**.

## Links to Other Docs

For a complete listing, visit the [Documentation Index](./index.md).

| Document | Path |
|---|---|
| Product Brief | [Product Brief](./A-Product-Brief) |
| Trigger Map | [Trigger Map](./B-Trigger-Map) |
| Platform Requirements | [Platform Requirements](./C-Platform-Requirements) |
| Scenarios | [Scenarios](./C-Scenarios) |
| Design System | [Design System](./D-Design-System) |
| PRD | [PRD](./E-PRD) |
| Testing | [Testing](./F-Testing) |
| Product Development | [Product Development](./G-Product-Development) |
