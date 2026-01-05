# Mishnayos Tracker

A personalized Android learning application designed to help track progress through completing all 4,192 Mishnayos of Shas by bar mitzvah.

## Overview

Mishnayos Tracker is a mobile application that transforms the ambitious goal of learning the entire Shas Mishnayos into an achievable, gamified journey. Built specifically for a 3-year learning timeline leading up to a bar mitzvah, the app provides intelligent daily recommendations, multi-context learning organization, and motivational features to keep young learners engaged and on track.

## Purpose

Help Yisroel Meir complete all 4,192 Mishnayos by his bar mitzvah on December 7, 2028 (19 Kislev 5789), with:
- **Smart scheduling** that adapts to his pace
- **Multi-track learning** for personal, school, and tutor contexts
- **Gamification** with points, streaks, and mystery rewards
- **3-stage learning cycle** (learning → chazara 1 → chazara 2)
- **Offline-first** design for uninterrupted learning
- **Parent and tutor modes** for monitoring and support

## Key Features

### Core Learning
- **Complete Mishna database**: All 4,192 Mishnayos organized by seder/masechta/perek
- **Bilingual text**: Hebrew (RTL) and English translation from Sefaria API
- **Hierarchical browsing**: Navigate by seder → masechta → perek → individual Mishna
- **3-stage completion tracking**: Learning, Chazara 1 (next day), Chazara 2 (7 days later)
- **Immutable progress log**: Append-only completion records with timestamps

### Smart Scheduling
- **Adaptive daily recommendations**: Calculates optimal task count based on bar mitzvah deadline
- **Automatic chazara scheduling**: Tracks when reviews are due
- **Pace monitoring**: Shows days ahead/behind schedule with projected completion date
- **Overload prevention**: Balances new learning with review pile-up

### Multi-Track Learning
- **Personal track** (mandatory): Self-paced learning with smart recommendations
- **School track** (optional): Separate context for school-based learning
- **Tutor track** (optional): Independent context for tutoring sessions
- **Independent bookmarks**: Each track maintains its own "where I'm up to" position
- **Duplicate prevention**: Each Mishna can only be assigned to one track

### Gamification & Engagement
- **Points system**: Configurable points for each completion stage (default: 10/5/5)
- **Streak tracking**: Consecutive days of app usage with longest streak achievement
- **Mystery rewards**: Parent-configured surprises unlocked at point thresholds
- **Progress visualization**: Charts and breakdowns by seder, masechta, perek
- **Completion animations**: Satisfying feedback for each accomplishment

### Parent Mode (PIN-protected)
- **Reward management**: Create, edit, reveal mystery rewards
- **Bulk operations**: Mark entire masechtos as complete during onboarding
- **Analytics dashboard**: Quick overview of progress, pace, and streaks
- **Settings control**: Configure point values, manage tracks
- **Progress monitoring**: View complete completion history

### Tutor Mode (PIN-protected, view-only)
- **Progress visibility**: View all completion data and statistics
- **Chazara queue**: See which Mishnayos are due for review
- **Completion log**: Timestamped history of all learning activity
- **No editing capability**: Read-only access for accountability

### Offline-First Architecture
- **Full offline operation**: All core features work without network
- **SQLite local database**: Source of truth, not cloud
- **Background sync**: Delta sync to Firebase when online
- **Resumable first-launch**: Downloads all 4,192 Mishnayos with checkpoint recovery
- **Conflict resolution**: Last-write-wins using UTC timestamps

### Notifications
- **Daily learning reminders**: Configurable time (default 7:00 PM)
- **Streak protection**: Alert at 9:00 PM if no app usage for streaks 5+ days
- **Reward milestones**: Instant notification when mystery reward unlocked
- **Parent notifications**: Alert parents when rewards are earned

## Tech Stack

### Framework & Platform
- **Flutter** (Android-only for v1.0)
- **Minimum Android API 21** (Lollipop)
- **Kotlin** for native code
- **Material Design 3** with RTL support

### State Management & Architecture
- **Riverpod** with code generation for state management and dependency injection
- **Clean Architecture** (presentation/domain/data layers)
- **Feature-first** folder structure

### Database & Persistence
- **SQLite** with drift ORM for local storage
- **Firebase Cloud Firestore** for cloud backup
- **flutter_secure_storage** for encrypted PIN storage

### External Integrations
- **Sefaria API**: Mishna text (Hebrew + English)
- **kosher_dart**: Hebrew calendar calculations
- **Firebase Anonymous Auth**: User identification for cloud sync

### Code Generation & Type Safety
- **build_runner**: Code generation orchestration
- **freezed**: Immutable data models
- **json_serializable**: JSON serialization
- **auto_route**: Type-safe navigation
- **riverpod_generator**: Provider code generation

### Networking & Logging
- **dio**: HTTP client with retry logic
- **talker**: Comprehensive logging framework with in-app viewer
- **connectivity_plus**: Network state monitoring

### Testing
- **mocktail**: Unit testing framework
- **80%+ test coverage** requirement on business logic

## Project Status

**Phase 3: Solutioning - Complete ✅**

The project has completed comprehensive planning with:
- ✅ Product Requirements Document (PRD)
- ✅ Technical Architecture Document
- ✅ Epic and Story Breakdown (11 epics, 63 stories)
- ✅ All 84 functional requirements mapped to implementation stories

**Next Phase: Implementation (Phase 4)**

Ready to begin development with implementation-ready stories.

## Documentation

### Planning Artifacts
Located in `_bmad-output/planning-artifacts/`:

- **`prd.md`**: Complete Product Requirements Document
- **`architecture.md`**: Technical architecture and design decisions
- **`epics.md`**: Full epic and story breakdown with acceptance criteria

### Requirements Coverage
- **84 Functional Requirements** covering all user-facing features
- **47 Non-Functional Requirements** for performance, reliability, security
- **Complete FR-to-Story mapping** for traceability

## Development Approach

### Epic Delivery Sequence
1. **Project Foundation & Data Infrastructure** (6 stories)
2. **Core Learning Cycle & Progress Tracking** (6 stories)
3. **Multi-Track Learning Management** (5 stories)
4. **Smart Scheduler & Daily Recommendations** (5 stories)
5. **Gamification & Engagement System** (5 stories)
6. **Parent Mode & Reward Management** (8 stories)
7. **Tutor Mode & Progress Visibility** (5 stories)
8. **Onboarding & Initial Setup** (5 stories)
9. **Progress Visualization & Analytics** (5 stories)
10. **Notification & Reminder System** (6 stories)
11. **Cloud Sync & Data Management** (7 stories)

Each epic delivers standalone user value and enables subsequent epics without requiring future work.

### Story Structure
Every story includes:
- User value statement (As a/I want/So that)
- Detailed acceptance criteria (Given/When/Then format)
- Technical implementation details
- Non-functional requirement references
- No forward dependencies

## Key Design Principles

### Offline-First
- Local SQLite database is the source of truth
- All core features work without connectivity
- Background sync to Firebase when online
- No blocking on network operations

### Immutable Progress
- Completion log is append-only
- Once marked complete, stages cannot be unmarked
- Complete audit trail with UTC timestamps
- Zero data loss guarantee over 3-year usage period

### 3-Year Reliability
- 99.9%+ crash-free rate requirement
- Data integrity through device reboots and crashes
- Graceful error handling throughout
- Comprehensive logging for debugging

### Performance Targets
- App startup: < 2 seconds
- Database queries: < 100ms
- User actions: < 200ms response time
- 60fps UI rendering
- < 2% daily battery impact from background sync

### Security & Privacy
- Encrypted PIN storage using platform keystore
- Role-based access control (parent full access, tutor view-only)
- Firestore security rules preventing unauthorized access
- HTTPS/TLS for all cloud communication

## Getting Started

*Implementation has not yet begun. This section will be updated once the project structure is initialized.*

## License

Private project for personal use.

## Acknowledgments

- **Mishna text** provided by [Sefaria](https://www.sefaria.org)
- **Hebrew calendar** calculations using kosher_dart library
- **Planning and architecture** developed with Claude Code

---

**Project Timeline**: January 2026 - December 2028 (Bar Mitzvah: 19 Kislev 5789 / December 7, 2028)

**Current Phase**: Ready for Implementation 🚀
