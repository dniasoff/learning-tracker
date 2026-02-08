# Learning Tracker

A multi-curriculum Torah learning tracker for Android. Track progress across Mishnayos, Gemara Bavli, Yerushalmi, Mishna Berurah, and Chumash with configurable review cycles, intelligent scheduling, and multi-device sync.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Curricula](#curricula)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Planning Artifacts](#planning-artifacts)

## Overview

Learning Tracker helps Torah learners (children and adults) maintain consistent daily learning across one or more curricula. The app transforms large-scale learning goals into achievable daily habits through:

- **Configurable N-stage learning cycles** (learn + chazara stages with user-defined timing)
- **Per-curriculum adaptive scheduling** that adjusts to individual pace and deadlines
- **Multi-track support** (personal, school, tutor) per curriculum
- **Cross-curriculum dashboard** with unified daily task planning
- **Account-based multi-device sync** with offline-first operation
- **Child and adult modes** with appropriate engagement levels

## Features

### Multi-Curriculum Content

All content sourced from [Sefaria](https://www.sefaria.org/) API with Hebrew and English text display. Activate and deactivate curricula at any time without losing progress.

### Configurable Learning Stages

Default: learn > chazara 1 (+1 day) > chazara 2 (+7 days). Customize stage count, names, and timing intervals independently per curriculum.

### Smart Scheduler

Per-curriculum parametric scheduling engine. Calculates optimal daily load based on goal deadlines and remaining items. Cross-curriculum composer aggregates all schedules into a unified daily plan.

### Multi-Track Learning

Personal track (mandatory, AI-driven) plus optional school and tutor tracks per curriculum. Each track maintains its own bookmark. Duplicate prevention within each curriculum.

### Per-Curriculum Goals

Set completion deadlines using Gregorian or Hebrew calendar. Multiple goals per curriculum. Pace tracking with projected completion dates. No-deadline mode for self-paced learners.

### Drag-and-Drop Learning Order

Customize the sequence of learning units within each curriculum. Default follows natural Sefaria order.

### Child + Adult Modes

- **Child mode:** Full gamification (points, streak celebrations, mystery rewards), parent mode available
- **Adult mode:** Streamlined progress tracking, optional engagement features, self-managed

### Parent Mode (Child Accounts)

PIN-protected. Reward catalog management, analytics dashboard, point value configuration, track management.

### Tutor Mode (Any Account)

PIN-protected, read-only. Completion history, chazara queue, progress breakdowns.

### Multi-Device Sync

Email/password + Google Sign-In. Push-on-write, pull-on-launch, foreground real-time listeners. Offline queue with persistent retry.

### Gamification

Per-curriculum points, global streak tracking, mystery rewards system. Scaled appropriately by user mode.

## Curricula

| Curriculum | Hierarchy | Items |
|---|---|---|
| Mishnayos | seder > masechta > perek > mishna | 4,192 |
| Gemara Bavli | masechta > daf > amud | ~2,711 |
| Gemara Yerushalmi | masechta > daf > halacha | varies |
| Mishna Berurah | siman > seif > seif katan | 697 simanim |
| Chumash | sefer > parsha > perek > pasuk | 5,845 |

All content is stored in a generic `content_items` table with `level_1` through `level_4` columns. A `curriculum_hierarchy_config` table maps level labels per curriculum.

## Architecture

**Platform:** Flutter/Dart, Android only (API 21+)

**Architecture pattern:** Clean architecture with feature-first organization (15 feature modules).

**Key architectural decisions:**

| ID | Decision | Summary |
|---|---|---|
| D1 | Content Modeling | Shared table with generic hierarchy levels |
| D2 | Authentication | Email/password + Google Sign-In via Firebase Auth |
| D3 | Stage Storage | Separate `stage_definitions` table per curriculum |
| D4 | Sync Architecture | Hybrid push/pull with foreground Firestore listeners |
| D5 | User Mode | Profile field enum (child/adult) with feature flags |
| D6 | Sefaria Integration | Per-curriculum adapter pattern with common interface |
| D7 | Learning Order | Separate table (content immutable, order customizable) |
| D8 | Gamification Scope | Per-curriculum points + global streak |

**Key patterns:**

| ID | Pattern | Rule |
|---|---|---|
| P1 | Curriculum ID | `CurriculumId.storageKey` (snake_case) for all persistence |
| P2 | Not Found | `T?` for single items, `List<T>` (empty) for lists |
| P3 | Provider Granularity | Family providers with `curriculumId` for scoped data |
| P4 | Firestore Structure | Flat collections, deterministic IDs for mutable data |
| P5 | Date/Time | All UTC storage, local timezone for streak day boundary |
| P6 | Cross-Curriculum | Core layer services for aggregation (never cross-feature imports) |

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter 3.38.6 / Dart 3.9.0 |
| Database | drift ^2.31.0 (SQLite ORM) + drift_flutter |
| State Management | flutter_riverpod ^3.2.1 + riverpod_generator ^4.0.3 |
| Navigation | auto_route ^11.1.0 |
| Data Classes | freezed ^3.2.5 |
| HTTP | dio ^5.9.1 |
| Auth | firebase_auth + google_sign_in |
| Cloud DB | cloud_firestore |
| Logging | talker ^5.1.13 suite |
| Testing | mocktail ^1.0.4 |
| Calendar | kosher_dart |
| Security | flutter_secure_storage + bcrypt |
| Code Generation | build_runner (drift, auto_route, freezed, riverpod) |

## Project Structure

```
learning_tracker/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/        # App constants, curriculum defaults
│   │   ├── database/         # Drift schema, tables, DAOs
│   │   ├── enums/            # CurriculumId, UserMode, TrackType
│   │   ├── logging/          # Talker singleton + observers
│   │   ├── navigation/       # auto_route config + guards
│   │   ├── network/          # Dio client, Sefaria fetchers
│   │   ├── providers/        # Database, dio, Firebase, connectivity
│   │   ├── services/         # Cross-curriculum aggregator, schedule composer
│   │   ├── theme/            # Material 3 theme, RTL text styles
│   │   └── utils/            # Date utils, Hebrew calendar utils
│   └── features/
│       ├── auth/             # Email/password + Google Sign-In
│       ├── onboarding/       # Mode selection, curriculum, goals, bulk mark
│       ├── content_browsing/ # Hierarchy browsing, text display
│       ├── learning/         # Mark completion, bookmarks, tracks
│       ├── scheduler/        # Per-curriculum scheduling engine
│       ├── dashboard/        # Cross-curriculum home screen
│       ├── progress/         # Per-curriculum progress views, charts
│       ├── gamification/     # Points, streaks, rewards
│       ├── parent_mode/      # Parent dashboard, reward management
│       ├── tutor_mode/       # Read-only tutor dashboard
│       ├── notifications/    # Local notification scheduling
│       ├── settings/         # Stage config, learning order, preferences
│       └── sync/             # Sync engine, Firestore data source, offline queue
├── test/
│   ├── mocks/                # Shared mocktail mocks
│   ├── fixtures/             # Reusable test data factories
│   ├── core/                 # Core infrastructure tests
│   └── features/             # Feature module tests
├── integration_test/         # End-to-end tests
└── assets/
    └── fonts/                # Hebrew fonts
```

## Getting Started

### Prerequisites

- Flutter SDK 3.38.6+ (stable channel)
- Android SDK (API 21+)
- Android device or emulator

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd learning_tracker

# Install dependencies
flutter pub get

# Run code generation
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Testing

```bash
# Run unit tests
flutter test

# Run static analysis
dart analyze

# Check formatting
dart format --set-exit-if-changed .
```

## Developer Quick References

**Start here for implementation guidance:**

📚 **[Architecture Quick Reference](_bmad-output/planning-artifacts/architecture-quick-reference.md)** — Explains all D1-D8 decisions, P1-P6 patterns, project structure, key data models, and common queries. AI-friendly and concise.

🎨 **[UX Patterns Quick Reference](_bmad-output/planning-artifacts/ux-patterns-quick-reference.md)** — User modes, navigation patterns, components, design system, color scheme, typography, animations, and accessibility guidelines.

🧪 **[Testing Quick Reference](_bmad-output/planning-artifacts/testing-quick-reference.md)** — Unit/widget/integration test patterns, TDD workflow, mock utilities, and testing checklist.

## Planning Artifacts

Detailed planning documents are in `_bmad-output/planning-artifacts/`:

| Document | Description |
|---|---|
| `product-brief-*.md` | Product vision, target users, success metrics, MVP scope |
| `prd.md` | Full product requirements (113 FRs, 47 NFRs) |
| `architecture.md` | Full architectural decisions (D1-D8), patterns (P1-P6), complete project structure (1,261 lines) |
| `architecture-quick-reference.md` | ⭐ Condensed architecture guide for developers (AI-friendly) |
| `ux-patterns-quick-reference.md` | ⭐ UX patterns and design system reference |
| `testing-quick-reference.md` | ⭐ Testing patterns and TDD workflow |
| `ux-design-specification.md` | Complete UX design specification |

### Epic Summary

| Epic | Stories | Scope |
|---|---|---|
| 1. Foundation & Infrastructure | 12 | All plumbing (CI/CD, auth, DB, sync, nav, theme) |
| 2. Content Import & Browsing | 4 | Sefaria import, hierarchy browsing, text display |
| 3. Core Learning Cycle | 3 | Mark completion, history, bookmarks |
| 4. Multi-Track Learning | 3 | Track management, assignment, progress |
| 5. Configurable Stages & Order | 2 | Stage editor, drag-and-drop learning order |
| 6. Smart Scheduler | 5 | Per-curriculum scheduling, goals, pace tracking |
| 7. Dashboard & Progress | 3 | Cross-curriculum dashboard, charts |
| 8. Gamification | 3 | Points, streaks, mystery rewards |
| 9. Onboarding | 5 | Mode selection, curriculum setup, bulk mark |
| 10. Parent Mode | 6 | Parent dashboard, rewards, analytics |
| 11. Tutor Mode | 4 | Read-only tutor dashboard |
| 12. Notifications | 3 | Reminders, streak alerts, reward notifications |
| 13. Cloud Sync | 3 | Push/pull sync, real-time listeners |
| 14. Settings | 4 | Preferences, data export, account management |
| **Total** | **60** | |

## Attribution

Torah text content provided by [Sefaria](https://www.sefaria.org/).
