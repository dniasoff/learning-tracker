---
title: Source Tree Analysis
description: Annotated guide to the Learning Tracker source tree, directory structure, feature modules, and strategies for finding code.
date: 2026-03-18
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
├── lib/                          # Main application code (366 files)
│   ├── core/                     # Cross-cutting infrastructure (121 files)
│   │   ├── constants/            # App constants, curriculum defaults, text config
│   │   ├── database/             # Drift SQLite ORM (69 files)
│   │   │   ├── daos/             # 22 Data Access Objects (44 files incl. generated)
│   │   │   ├── tables/           # 22 table definitions
│   │   │   ├── seed/             # Learning program & test date seeds
│   │   │   ├── app_database.dart # Main database class (schema v15)
│   │   │   └── app_database.g.dart
│   │   ├── enums/                # CurriculumId, TrackType, UserMode
│   │   ├── exceptions/           # DuplicateCompletionException
│   │   ├── logging/              # AppLogger with sensitive data filtering
│   │   ├── navigation/           # auto_route config (40+ routes, 7 guards)
│   │   │   └── guards/           # Auth, Profile, Restore, ChildMode, ParentPin, TutorPin
│   │   ├── network/              # ConnectivityService, DioProvider, Sefaria client
│   │   ├── preferences/          # TextDisplayPreferences
│   │   ├── providers/            # Core Riverpod providers (database, firebase, network)
│   │   ├── services/             # PinService, TrackService, DuplicatePrevention, Aggregators
│   │   ├── theme/                # Material 3 theme, bidirectional typography
│   │   ├── utils/                # DateUtils (UTC/P5), HebrewUtils, HebrewCalendarUtils
│   │   └── widgets/              # 11 reusable widgets
│   └── features/                 # Feature modules (18 features: auth, content_browsing, dashboard, gamification, learning, learning_order, notifications, onboarding, parent_mode, profiles, progress, scheduler, settings, stages, sync, test_tracking, track_setup, tutor_mode)
│       ├── auth/                 # Firebase Auth (5 files)
│       ├── content_browsing/     # Content hierarchy browsing (18 files)
│       ├── dashboard/            # Main dashboard (6 files)
│       ├── gamification/         # Points, streaks, rewards (12 files)
│       ├── learning/             # Core completion logic (29 files) ★ Most complex
│       ├── learning_order/       # Drag-and-drop reordering (9 files)
│       ├── notifications/        # Reminders, alerts, Shabbos mode (10 files)
│       ├── onboarding/           # Setup wizard flow (15 files)
│       ├── parent_mode/          # Parent dashboard & controls (16 files)
│       ├── profiles/             # Multi-profile management (11 files)
│       ├── progress/             # Charts, stats, Learning Journey (28 files)
│       ├── scheduler/            # Smart scheduling engine (34 files) ★ Largest
│       ├── settings/             # App settings, export/import (15 files)
│       ├── stages/               # Stage configuration (9 files)
│       ├── sync/                 # Cloud sync engine (14 files)
│       ├── test_tracking/        # Test scores & reminders (2 files)
│       └── tutor_mode/           # Read-only tutor dashboard (10 files)
├── test/                         # Test suite (182 files)
│   ├── core/                     # Core infrastructure tests (47 files)
│   ├── features/                 # Feature-specific tests (100 files)
│   ├── story_acceptance/         # Epic-based acceptance tests (15 files, 401 tests)
│   ├── integration/              # Cross-feature integration tests (2 files)
│   ├── fixtures/                 # Test data factories
│   ├── helpers/                  # Test utilities (in-memory DB)
│   └── mocks/                    # Mocktail mock implementations
├── assets/                       # App assets
│   ├── content/hierarchy/        # 7 bundled curriculum JSON files
│   ├── fonts/                    # Noto Sans Hebrew (5 weights)
│   └── images/                   # Image assets
├── tool/                         # Dev scripts and utilities (13 files)
│   ├── seed_content.dart         # Content seeding
│   ├── upload_to_firebase.*      # Firebase upload scripts
│   └── lib/sefaria/              # Per-curriculum Sefaria API fetchers
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

The persistence layer is built on Drift (SQLite ORM) and split across **three databases** (Epic 19 + Epic 21):

- **User DB** — schema v4, 23 tables, 20 DAOs, read-write, per-account file.
- **Content DB** — schema v3, 3 tables (`text_cache`, `calendar_cycles`, `seed_metadata`), read-only, bundled seed.
- **Device Registry DB** — schema v1, 2 tables (`device_accounts`, `device_state`), workspace-level.

Key User DB tables include: `user_profiles`, `profiles`, `completions`, `curriculum_tracks`, `active_curricula`, `streaks`, `streak_events`, `xp_events`, `rewards`, `bookmarks`, `goals`, `test_scores`. See `docs/data-models.md` for the full table inventory.

### `lib/features/learning/` (29 files) -- Most Complex

The heart of the app. This feature manages completion recording with strict append-only semantics, duplicate prevention, and cross-feature event propagation (gamification points, streak updates, schedule advancement). The `CompletionRepository` is the single write path for all learning completions.

### `lib/features/scheduler/` (34 files) -- Largest Feature

The smart scheduling engine generates daily learning assignments. It handles multiple scheduling strategies (sequential, cyclical, date-anchored), rest day logic, Shabbos/Yom Tov awareness, and catch-up scheduling. The engine is tightly integrated with the learning and progress features through core providers.

### `lib/core/navigation/guards/` (7 guards)

Route guards enforce the app's access control model:

- **AuthGuard** - Requires Firebase authentication
- **ProfileGuard** - Requires an active profile selection
- **RestoreGuard** - Handles data restoration flow
- **ChildModeGuard** - Restricts navigation in child mode
- **ParentPinGuard** - Requires parent PIN for sensitive screens
- **TutorPinGuard** - Requires tutor PIN for tutor access
- **PinGuard** - Shared base guard for PIN verification logic

### `test/story_acceptance/` (15 files, 401 tests)

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
| Database definition | `lib/core/database/app_database.dart` |
| Route configuration | `lib/core/navigation/app_router.dart` |
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

All DAOs live in `lib/core/database/daos/`. Each DAO file corresponds to a table and follows the naming convention `<entity>_dao.dart` (e.g., `completion_dao.dart`, `streak_dao.dart`). The generated query code is in the matching `.g.dart` file.

The 20 User DB DAOs are:

- `active_curriculum_dao`, `bookmark_dao`, `completion_dao`, `content_download_status_dao`
- `curriculum_scope_dao`, `goal_dao`, `learning_ledger_dao`, `learning_order_dao`
- `learning_program_dao`, `point_config_dao`, `profile_dao`, `profile_program_dao`
- `reward_dao`, `stage_dao`, `streak_dao`, `sync_queue_dao`
- `test_date_dao`, `test_score_dao`, `text_cache_dao`, `text_download_status_dao`
- `track_dao`, `user_profile_dao`

### How to find a database table

Table definitions live in `lib/core/database/tables/`. Each file defines a single Drift table class. The naming convention is the plural entity name (e.g., `completions.dart`, `profiles.dart`, `streaks.dart`).

All tables are registered in `lib/core/database/app_database.dart` via the `@DriftDatabase(tables: [...])` annotation.

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
