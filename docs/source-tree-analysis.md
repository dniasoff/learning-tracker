---
title: Source Tree Analysis
description: Annotated guide to the Learning Tracker source tree, directory structure, feature modules, and strategies for finding code.
date: 2026-07-13
---

# Source Tree Analysis

## Table of Contents

- [Overview](#overview)
- [Source Tree](#source-tree)
- [Entry Points](#entry-points)
- [Critical Directories](#critical-directories)
- [Feature Module Pattern](#feature-module-pattern)
- [Key File Locations](#key-file-locations)
- [Finding Things](#finding-things)

## Overview

The Learning Tracker is a Flutter application for tracking daily learning progress across Jewish religious curricula. The app supports multiple user modes (child, parent, tutor), gamification, smart scheduling, and cloud sync.

## Source Tree

```
learning_tracker/
├── lib/                          # Main application code — AUD-docs-16, re-verified 2026-07-13 (704 files, excl. .g.dart/.freezed.dart)
│   ├── core/                     # Cross-cutting infrastructure (245 files, excl. generated)
│   │   ├── constants/            # App constants, curriculum defaults, text config
│   │   ├── database/             # Drift SQLite ORM — AUD-docs-16, re-verified 2026-07-13 (101 files)
│   │   │   ├── daos/             # 24 User DB Data Access Objects (49 files incl. generated)
│   │   │   ├── tables/           # 27 table definitions (User DB + Content DB tables share this dir)
│   │   │   ├── seed/             # Learning program & test date seeds
│   │   │   ├── user/
│   │   │   │   ├── user_database.dart   # UserDatabase — schema v35 (there is no app_database.dart; the class was renamed)
│   │   │   │   └── user_database.g.dart
│   │   │   ├── content/           # ContentDatabase — schema v5
│   │   │   └── registry/          # DeviceRegistryDatabase — schema v1
│   │   ├── enums/                # CurriculumId, TrackType, UserMode
│   │   ├── exceptions/           # DuplicateCompletionException
│   │   ├── logging/              # AppLogger with sensitive data filtering
│   │   ├── navigation/           # auto_route config (40+ routes, 5 guards)
│   │   │   └── guards/           # Auth, Profile, Restore, ChildMode, Pin (parameterized by PinScope)
│   │   ├── network/              # ConnectivityService, DioProvider, Sefaria client
│   │   ├── preferences/          # TextDisplayPreferences
│   │   ├── providers/            # Core Riverpod providers (database, firebase, network)
│   │   ├── services/             # PinService, TrackService, DuplicatePrevention, Aggregators
│   │   ├── theme/                # Material 3 theme, bidirectional typography
│   │   ├── utils/                # DateUtils (UTC/P5), HebrewUtils, HebrewCalendarUtils
│   │   └── widgets/              # 11 reusable widgets
│   └── features/                 # Feature modules — AUD-docs-16, re-verified 2026-07-13, `ls lib/features/` (15 features: account, content_browsing, dashboard, gamification, learning, notifications, onboarding, profiles, progress, sacred_time, scheduler, settings, sync, tracks, tutoring)
│       ├── account/               # Firebase Auth, local-born accounts, hard-tier upgrade (35 files)
│       ├── content_browsing/     # Content hierarchy browsing (22 files)
│       ├── dashboard/            # Main dashboard (31 files)
│       ├── gamification/         # Points, streaks, rewards (45 files)
│       ├── learning/             # Core completion logic (33 files)
│       ├── notifications/        # Reminders, alerts, Shabbos mode (14 files)
│       ├── onboarding/           # Setup wizard flow, child/adult mode (29 files)
│       ├── profiles/             # Multi-profile management, parent-mode dashboard (40 files)
│       ├── progress/             # Charts, stats, Learning Journey (42 files)
│       ├── sacred_time/          # Shabbos/Yom Tov lock overlay, zmanim, city picker (20 files)
│       ├── scheduler/            # Smart scheduling engine (59 files) ★ Largest of the "flat" features
│       ├── settings/             # App settings, export/import (19 files)
│       ├── sync/                 # SyncWriteFacade / outbox push entry points — engine internals live in core/sync/ (10 files)
│       ├── tracks/               # Track management hub, setup/stages/order (formerly separate stages/track_setup/learning_order features) (67 files) ★ Most complex
│       └── tutoring/             # Cross-user tutor access — grants, tutor dashboard, write proxies (36 files)
├── test/                         # Test suite — AUD-docs-16, re-verified 2026-07-13 (865 files total)
│   ├── core/                     # Core infrastructure tests (198 files)
│   ├── features/                 # Feature-specific tests (472 files)
│   ├── story_acceptance/         # Epic-based acceptance tests (57 files, ~1000 tests)
│   ├── integration/              # Cross-feature integration tests (10 files)
│   ├── fixtures/                 # Test data factories
│   ├── helpers/                  # Test utilities (in-memory DB)
│   └── mocks/                    # Mocktail mock implementations
├── assets/                       # App assets
│   ├── content/hierarchy/        # 7 bundled curriculum JSON files
│   ├── fonts/                    # Noto Sans Hebrew (5 weights)
│   └── images/                   # Image assets
├── tool/                         # Dev scripts and utilities (13 files)
│   ├── seed_content.dart         # AUD-core-network-02: manual fallback, hits
│   │                             # the live public Sefaria API; NOT part of
│   │                             # `make seed` (see docs/seed-build.md)
│   ├── upload_to_firebase.*      # Firebase upload scripts
│   └── lib/sefaria/              # Per-curriculum Sefaria API fetchers used
│                                 # only by the seed_content.dart fallback above
├── integration_test/             # E2E tests on device/emulator
├── android/                      # Android platform code
├── pubspec.yaml                  # Dependencies
├── analysis_options.yaml         # Strict Dart analyzer rules
├── build.yaml                    # Code generation config
├── dart_test.yaml                # Test tag registration (14 epics, 67 stories)
├── firebase.json                 # Firebase project config
├── firestore.rules               # Security rules
└── Makefile                      # Build/test automation
```

## Entry Points

### main.dart

The application entry point initializes Firebase, creates the Drift database, sets up Riverpod's `ProviderScope` with overrides for the database and Firebase instances, then launches the app.

### AppShell (4-tab navigation)

The main scaffold uses a `BottomNavigationBar` with four tabs:

1. **Dashboard** - Daily learning overview and quick-complete actions
2. **Browse** - Content hierarchy navigation (curriculum > section > unit > item)
3. **Progress** - Charts, stats, streaks, and the Learning Journey timeline
4. **Settings** - App configuration, data export/import, profile management

Navigation is managed by `auto_route` with nested tab routing. Guards control access based on auth state, profile selection, user mode, and PIN verification.

## Critical Directories

### `lib/core/database/` (69 files)

The persistence layer is built on Drift (SQLite ORM) and split across **three databases** (Epic 19 + Epic 21 + Epic 25 schema-v1 rebuild):

**AUD-docs-16, re-verified 2026-07-13 via `tool/gen_arch_tables.dart`:**
- **User DB** — schema v35, 24 tables, 24 DAOs, read-write, per-account file.
- **Content DB** — schema v5, 4 tables (`TextCache`, `CalendarCycles`, `DailyContent`, `SeedMetadata`), read-only, bundled seed.
- **Device Registry DB** — schema v1, 2 tables (`DeviceAccounts`, `DeviceState`), workspace-level.

Key User DB tables include: `accounts`, `learner_profiles`, `completion_events`, `curriculum_tracks`, `stage_definitions`, `streak_events`, `learning_ledger`, `points_ledger`, `reward_redemptions`, `bookmarks`, `goals`, `outbox`. See `docs/architecture.md` §Database Schema for the full, generated table inventory (the `test_scores`/`xp_events`/`active_curricula` tables previously listed here don't exist in the current schema).

### `lib/features/learning/` (29 files) -- Most Complex

The heart of the app. This feature manages completion recording with strict append-only semantics, duplicate prevention, and cross-feature event propagation (gamification points, streak updates, schedule advancement). The `CompletionRepository` is the single write path for all learning completions.

### `lib/features/scheduler/` (34 files) -- Largest Feature

The smart scheduling engine generates daily learning assignments. It handles multiple scheduling strategies (sequential, cyclical, date-anchored), rest day logic, Shabbos/Yom Tov awareness, and catch-up scheduling. The engine is tightly integrated with the learning and progress features through core providers.

### `lib/core/navigation/guards/` (5 guards)

Route guards enforce the app's access control model:

- **AuthGuard** - Requires Firebase authentication
- **ProfileGuard** - Requires an active profile selection
- **RestoreGuard** - Handles data restoration flow
- **ChildModeGuard** - Restricts navigation in child mode
- **PinGuard** - PIN challenge parameterized by `PinScope` — `PinScope.parent(profileId)` for parent-mode screens, `PinScope.tutor(profileId)` for tutor-mode screens. A single guard class parameterized by scope, replacing the earlier per-mode guard classes.

### `test/story_acceptance/` (57 files, ~1000 tests — AUD-docs-16, re-verified 2026-07-13)

Story-based acceptance tests are organized by epic. Each file covers one epic and contains tests tagged by story ID (e.g., `@Tags(['epic-1', 'story-1.1'])`). These tests use in-memory Drift databases and exercise full feature flows without a running app.

## Feature Module Pattern

Each feature follows a consistent three-layer architecture:

```
feature_name/
├── data/                         # Implementation layer
│   ├── repositories/             # Repository implementations
│   └── services/                 # External service integrations
├── domain/                       # Business logic layer
│   ├── models/                   # Domain models (freezed)
│   ├── repositories/             # Repository interfaces (abstract classes)
│   └── services/                 # Domain service interfaces
└── presentation/                 # UI layer
    ├── providers/                # Riverpod providers (state management)
    ├── screens/                  # Full-page widgets
    └── widgets/                  # Feature-specific widgets
```

**Dependency rule:** Presentation depends on domain, domain is independent, data implements domain interfaces. Features never import directly from other features; all cross-feature communication goes through core providers.

## Key File Locations

| Purpose | Path |
|---|---|
| App entry point | `lib/main.dart` |
| Database definitions | `lib/core/database/user/user_database.dart` (User DB), `lib/core/database/content/content_database.dart` (Content DB), `lib/core/database/registry/device_registry_database.dart` (Registry DB) — AUD-docs-16, corrected 2026-07-13; `app_database.dart` no longer exists |
| Route configuration | `lib/app/router/app_router.dart` (`lib/core/navigation/app_router.dart` is a 2-line re-export shim to this canonical location) |
| Theme definition | `lib/core/theme/app_theme.dart` |
| Core providers | `lib/core/providers/` |
| Completion recording | `lib/features/learning/data/repositories/completion_repository_impl.dart` |
| Schedule generation | `lib/features/scheduler/domain/services/scheduler_engine.dart` |
| Gamification engine | `lib/features/gamification/domain/services/points_service.dart` |
| Onboarding wizard | `lib/features/onboarding/presentation/screens/onboarding_screen.dart` |
| Content hierarchy | `lib/features/content_browsing/presentation/screens/` |
| Test helpers | `test/helpers/` |
| Test fixtures | `test/fixtures/` |
| Acceptance tests | `test/story_acceptance/` |
| Makefile targets | `Makefile` |
| CI pipeline | `.github/workflows/ci.yml` |
| Build pipeline | `.github/workflows/build.yml` |

## Finding Things

### How to find a screen

All screens live in `lib/features/<feature>/presentation/screens/`. Each screen is a widget class ending in `Screen` (e.g., `DashboardScreen`, `SettingsScreen`). To find a specific screen:

```bash
# Search by screen name
grep -rl 'class.*Screen extends' lib/features/
```

Every screen is registered as a route in `lib/core/navigation/app_router.dart`. Look there for the mapping between route names and screen widgets.

### How to find a provider

Riverpod providers live in `lib/features/<feature>/presentation/providers/` for feature-specific providers, or in `lib/core/providers/` for shared core providers.

Providers generated by `riverpod_generator` are annotated with `@riverpod` in the source file, with the generated code in the corresponding `.g.dart` file.

```bash
# Search for a provider by name
grep -rl 'Provider' lib/features/*/presentation/providers/
grep -rl 'Provider' lib/core/providers/
```

### How to find a DAO

All DAOs live in `lib/core/database/daos/`. Each DAO file corresponds to a table (or a small cluster of related tables/views) and follows the naming convention `<entity>_dao.dart` (e.g., `completion_dao.dart`, `streak_event_dao.dart`). The generated query code is in the matching `.g.dart` file. (`dao_invariant_error.dart` also lives in this directory but is a shared error type, not a DAO — it is excluded from the count below.)

The 24 User DB DAOs are — AUD-docs-16, corrected 2026-07-13, sourced from the `daos: [...]` list in `lib/core/database/user/user_database.dart`:

- `active_curriculum_dao`, `bookmark_dao`, `completion_dao`, `completion_event_dao`
- `curriculum_scope_dao`, `daily_plan_dao`, `goal_dao`, `learning_ledger_dao`
- `learning_order_dao`, `outbox_dao`, `point_config_dao`, `points_balance_dao`
- `prior_completion_import_dao`, `profile_dao`, `profile_program_dao`, `sacred_window_dao`
- `stage_dao`, `streak_event_dao`, `study_day_config_dao`, `sync_kv_dao`
- `text_download_status_dao`, `track_dao`, `track_learning_order_dao`, `user_profile_dao`

### How to find a database table

Table definitions live in `lib/core/database/tables/`. Each file defines a single Drift table class. The naming convention is the plural entity name (e.g., `completion_events.dart`, `learner_profiles.dart`, `streak_events.dart`).

All tables are registered in `lib/core/database/user/user_database.dart` via the `@DriftDatabase(tables: [...])` annotation — AUD-docs-16, corrected 2026-07-13; there is no `app_database.dart` (see the Key File Locations table above).

### How to find a route or guard

Routes are declared in `lib/core/navigation/app_router.dart` using `auto_route` annotations. Guards live in `lib/core/navigation/guards/` with one file per guard.

To find which guard protects a given route, search for the guard class name in the router configuration:

```bash
grep -n 'guards:' lib/core/navigation/app_router.dart
```

### How to find a test for a feature

Tests mirror the source tree structure:

- **Unit/widget tests**: `test/features/<feature>/` and `test/core/`
- **Acceptance tests**: `test/story_acceptance/epic_<N>_test.dart`
- **Integration tests**: `test/integration/`

To run tests for a specific story, use `make test-story-X.Y`. To run all tests for an epic, use `make test-epic-N`.

### How to find a domain model

Domain models live in `lib/features/<feature>/domain/models/`. They use `freezed` for immutability and pattern matching. The generated code is in the corresponding `.freezed.dart` file.

### How to find where cross-feature communication happens

Features never import each other directly. Cross-feature data flows through providers in `lib/core/providers/`. Search there for the shared state that connects features:

```bash
ls lib/core/providers/
```
