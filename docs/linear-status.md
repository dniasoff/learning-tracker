---
title: "Project Status (Linear)"
description: "Comprehensive project status derived from Linear ticket data for the learning-tracker project."
date: 2026-03-18
---

# Project Status (Linear)

## Table of Contents

- [Overview](#overview)
- [Epic Summary Table](#epic-summary-table)
- [Epic Details](#epic-details)
  - [Epic 1: Foundation and Infrastructure](#epic-1-foundation-and-infrastructure)
  - [Epic 2: Content Import and Browsing](#epic-2-content-import-and-browsing)
  - [Epic 3: Core Learning Cycle](#epic-3-core-learning-cycle)
  - [Epic 4: Multi-Track Learning](#epic-4-multi-track-learning)
  - [Epic 5: Configurable Stages and Learning Order](#epic-5-configurable-stages-and-learning-order)
  - [Epic 6: Smart Scheduler](#epic-6-smart-scheduler)
  - [Epic 7: Dashboard and Progress](#epic-7-dashboard-and-progress)
  - [Epic 8: Gamification and Engagement](#epic-8-gamification-and-engagement)
  - [Epic 9: Onboarding Flow](#epic-9-onboarding-flow)
  - [Epic 10: Parent Mode](#epic-10-parent-mode)
  - [Epic 11: Tutor Mode](#epic-11-tutor-mode)
  - [Epic 12: Notifications](#epic-12-notifications)
  - [Epic 13: Cloud Sync](#epic-13-cloud-sync)
  - [Epic 14: Settings](#epic-14-settings)
  - [Epic 15: Multi-Profile and Learning Program System](#epic-15-multi-profile-and-learning-program-system)
- [Items In Review](#items-in-review)
- [Upcoming Work](#upcoming-work)
- [How to Sync](#how-to-sync)

## Overview

- **Team:** DNI (Dniasoff)
- **Project:** learning-tracker
- **Last synced:** 2026-03-18
- **Total:** 15 epics, 89 stories
- **Status:** 86 Done, 3 In Review, 0 Blocked

## Epic Summary Table

| Epic | Title | Stories | Done | In Review |
|------|-------|---------|------|-----------|
| 1 | Foundation and Infrastructure | 12 | 12 | 0 |
| 2 | Content Import and Browsing | 6 | 6 | 0 |
| 3 | Core Learning Cycle | 3 | 3 | 0 |
| 4 | Multi-Track Learning | 3 | 3 | 0 |
| 5 | Configurable Stages and Learning Order | 2 | 2 | 0 |
| 6 | Smart Scheduler | 5 | 5 | 0 |
| 7 | Dashboard and Progress | 3 | 3 | 0 |
| 8 | Gamification and Engagement | 4 | 4 | 0 |
| 9 | Onboarding Flow | 5 | 5 | 0 |
| 10 | Parent Mode | 5 | 5 | 0 |
| 11 | Tutor Mode | 2 | 2 | 0 |
| 12 | Notifications | 4 | 4 | 0 |
| 13 | Cloud Sync | 4 | 4 | 0 |
| 14 | Settings | 3 | 0 | 3 |
| 15 | Multi-Profile and Learning Program System | 0 | 0 | 0 |

## Epic Details

### Epic 1: Foundation and Infrastructure

- **Tickets:** DNI-1 through DNI-12
- **Stories:** 12 | **Done:** 12 | **In Review:** 0

This epic covers the full project bootstrap: Flutter project initialization, Drift database schema and DAOs, Firebase Auth and Firestore integration, the Sefaria API client, navigation shell with auto_route, Riverpod state management, Talker logging, CI/CD and testing infrastructure, sync engine foundation, theme and core UI, security infrastructure (bcrypt, secure storage), and Hebrew calendar utilities.

**Key architecture decisions:**

- Drift serves as the local-first database layer with typed DAOs for each domain.
- Riverpod provides dependency injection and reactive state management throughout the app.
- auto_route handles declarative navigation with a shell-based layout.
- Talker centralizes structured logging for debugging and diagnostics.
- Security infrastructure uses bcrypt for PIN hashing and flutter_secure_storage for sensitive data.

### Epic 2: Content Import and Browsing

- **Tickets:** DNI-75 through DNI-80
- **Stories:** 6 | **Done:** 6 | **In Review:** 0

This epic covers the Sefaria content import pipeline, content hierarchy browsing, text display (Hebrew/English), and curriculum activation.

**Key architecture decisions:**

- DNI-79 introduces a major architectural shift from runtime import to dev-time bundled JSON assets. Content is now pre-processed at build time and shipped as local assets, eliminating runtime dependency on external APIs.
- DNI-80 adds one-time text download with a nikud (vowelization) toggle, allowing users to choose pointed or unpointed Hebrew text.

### Epic 3: Core Learning Cycle

- **Tickets:** DNI-81 through DNI-83
- **Stories:** 3 | **Done:** 3 | **In Review:** 0

This epic covers marking completion per-stage per-track, the completion log and history, and bookmark management.

**Key architecture decisions:**

- The completions table uses `sefariaRef` (String) as its key rather than `content_item_id`, enabling direct linkage to canonical Sefaria references regardless of local content structure.

### Epic 4: Multi-Track Learning

- **Tickets:** DNI-84 through DNI-86
- **Stories:** 3 | **Done:** 3 | **In Review:** 0

This epic covers support for concurrent learning tracks, allowing users to study multiple curricula simultaneously with independent progress tracking per track.

### Epic 5: Configurable Stages and Learning Order

- **Tickets:** DNI-87 through DNI-88
- **Stories:** 2 | **Done:** 2 | **In Review:** 0

This epic covers configurable learning stages and customizable learning order, letting users and administrators define which stages apply to each curriculum and in what sequence content is presented.

### Epic 6: Smart Scheduler

- **Tickets:** DNI-89 through DNI-93
- **Stories:** 5 | **Done:** 5 | **In Review:** 0

This epic covers the parametric scheduler engine, daily task generation, goal management, pace tracking, and the cross-curriculum daily schedule composer.

**Key architecture decisions:**

- The scheduler supports three schedule types: **delay** (fixed interval between reviews), **weekly** (recurring on specific days), and **rolling** (continuous progression through material).
- The cross-curriculum composer merges tasks from all active tracks into a single prioritized daily schedule.

### Epic 7: Dashboard and Progress

- **Tickets:** DNI-94 through DNI-96
- **Stories:** 3 | **Done:** 3 | **In Review:** 0

This epic covers the main dashboard, progress visualization, and streak/statistics displays, providing users with an at-a-glance view of their learning activity and achievements.

### Epic 8: Gamification and Engagement

- **Tickets:** DNI-97 through DNI-100
- **Stories:** 4 | **Done:** 4 | **In Review:** 0

This epic covers achievement badges, streak rewards, milestone celebrations, and engagement mechanics that motivate consistent learning habits.

### Epic 9: Onboarding Flow

- **Tickets:** DNI-101 through DNI-104, DNI-108
- **Stories:** 5 | **Done:** 5 | **In Review:** 0

This epic covers the first-run onboarding experience, including account creation, curriculum selection, initial schedule configuration, and guided app introduction.

### Epic 10: Parent Mode

- **Tickets:** DNI-109 through DNI-113
- **Stories:** 5 | **Done:** 5 | **In Review:** 0

This epic covers the parent dashboard, child progress monitoring, PIN-protected access, notification preferences for parents, and parental controls for managing the learning experience.

### Epic 11: Tutor Mode

- **Tickets:** DNI-114 through DNI-115
- **Stories:** 2 | **Done:** 2 | **In Review:** 0

This epic covers tutor-facing views for monitoring student progress and a lightweight interface for tutors to review assigned material and track student completion.

### Epic 12: Notifications

- **Tickets:** DNI-116 through DNI-119
- **Stories:** 4 | **Done:** 4 | **In Review:** 0

This epic covers local push notifications for daily reminders, streak-at-risk alerts, milestone celebrations, and configurable notification preferences.

### Epic 13: Cloud Sync

- **Tickets:** DNI-120 through DNI-123
- **Stories:** 4 | **Done:** 4 | **In Review:** 0

This epic covers push-on-write with offline queuing, pull-on-launch merge, real-time foreground listeners, and new device data restore.

**Key architecture decisions:**

- The sync engine uses a hybrid push/pull model (per design document D4): writes push immediately when online and queue locally when offline; reads pull on app launch and merge with local state; real-time listeners keep the foreground session current.
- New device restore reconstructs the full local database from the cloud source of truth.

### Epic 14: Settings

- **Tickets:** DNI-105 through DNI-107
- **Stories:** 3 | **Done:** 0 | **In Review:** 3

This epic covers general settings and user profile, data export and import, and account management. All three stories are currently in review.

### Epic 15: Multi-Profile and Learning Program System

- **Tickets:** None defined
- **Stories:** 0 | **Done:** 0 | **In Review:** 0

This epic covers multi-profile support and the learning program system. No stories are defined yet; this represents the next phase of development.

## Items In Review

- **DNI-105** (14.1): General Settings and User Profile
- **DNI-106** (14.2): Data Export and Import
- **DNI-107** (14.3): Account Management

## Upcoming Work

- **Epic 15:** Multi-Profile and Learning Program System (no stories defined yet)
- **Roadmap items:** iOS support, tutor/school companion app, additional curricula

## How to Sync

```bash
# Sync Linear tickets to local cache
./tool/linear-sync.sh
# Cache location: ~/.local/share/linear-sync/dniasoff/learning-tracker/
```
