---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
workflowComplete: true
completedAt: '2026-01-05'
---

# mishnayos-tracker - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for mishnayos-tracker, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

**Learning Content & Structure:**
- FR1: System can provide complete database of 4,192 Mishnayos organized by seder/masechta/perek structure
- FR2: Users can browse Mishnayos content hierarchically (seder → masechta → perek → individual Mishna)
- FR3: Users can view Mishna text in both Hebrew and English
- FR4: System can attribute content to Sefaria API source

**Multi-Track Learning Management:**
- FR5: Users can manage up to 3 learning tracks (personal, school, tutor) with personal track mandatory
- FR6: Users can add or remove optional tracks (school/tutor) as circumstances change
- FR7: System can maintain separate "where he's up to" bookmark for each active track
- FR8: System can prevent a single Mishna from being assigned to multiple tracks simultaneously
- FR9: Users can designate which track a Mishna belongs to when marking progress

**3-Stage Learning Cycle:**
- FR10: Users can mark a Mishna as completed for learning stage (stage 1)
- FR11: Users can mark a Mishna as completed for chazara 1 (review stage 2)
- FR12: Users can mark a Mishna as completed for chazara 2 (review stage 3)
- FR13: System can enforce immutability - once a stage is marked complete, it cannot be unmarked
- FR14: System can maintain append-only completion log with timestamps for all stage completions
- FR15: System can track which Mishnayos are due for chazara 1 (next day after learning)
- FR16: System can track which Mishnayos are due for chazara 2 (7 days after chazara 1)

**Smart Scheduling & Recommendations (Personal Track Only):**
- FR17: System can generate daily recommendations for personal track showing new learning and chazara tasks
- FR18: System can calculate optimal daily task count based on bar mitzvah deadline and current progress
- FR19: System can adapt recommendations when user falls behind or accelerates ahead of pace
- FR20: System can balance new learning with chazara pile-up to prevent overload
- FR21: System can automatically schedule chazara tasks based on completion timestamps

**Progress Tracking & Visualization:**
- FR22: Users can view overall progress as percentage of 4,192 Mishnayos completed
- FR23: Users can view progress broken down by seder
- FR24: Users can view progress broken down by masechta
- FR25: Users can view progress broken down by perek
- FR26: Users can view which track contributed each completion
- FR27: Users can see current pace status (days ahead/on-pace/behind target)
- FR28: Users can see projected completion date based on current pace
- FR29: Users can view completion history over time

**Gamification & Motivation System:**
- FR30: System can award points for completing learning stages (configurable, default 10 points)
- FR31: System can award points for completing chazara 1 (configurable, default 5 points)
- FR32: System can award points for completing chazara 2 (configurable, default 5 points)
- FR33: Users can track total points accumulated over time
- FR34: Users can view points earned over time via charting
- FR35: System can track consecutive days of app usage (streak counter)
- FR36: Users can view current streak length and maximum streak achieved
- FR37: System can display mystery rewards with progress bars showing points needed
- FR38: System can notify when mystery reward point threshold is reached
- FR39: Parents can reveal mystery reward details when earned

**Parent Mode Capabilities:**
- FR40: Parents can access PIN-protected parent mode (4-digit PIN)
- FR41: Parents can manage mystery reward catalog (add/edit/delete rewards with point thresholds)
- FR42: Parents can bulk mark entire masechtas as already completed during initial onboarding
- FR43: Parents can configure point values for each learning stage
- FR44: Parents can add or remove optional tracks (school/tutor)
- FR45: Parents can view analytics dashboard showing on-track status, completion percentage, and streak
- FR46: Parents can view all completion history and progress data

**Tutor Mode Capabilities:**
- FR47: Tutor can access PIN-protected tutor mode with separate PIN from parent mode
- FR48: Tutor can view (but not modify) all completion data and progress
- FR49: Tutor can see completion log with timestamps showing what was completed and when
- FR50: Tutor can see which Mishnayos are due for chazara
- FR51: Tutor can view on-track status and overall progress metrics
- FR52: Tutor can view progress breakdowns by seder/masechta

**Onboarding & Setup:**
- FR53: Users can complete initial app setup including bar mitzvah date configuration
- FR54: Users can set personalized user information (name, bar mitzvah date in Hebrew calendar)
- FR55: Parents can configure initial mystery rewards during setup
- FR56: Parents can bulk mark prior completed masechtas during onboarding
- FR57: Users can configure learning order preferences for masechtos

**Notification & Reminders:**
- FR58: Users can receive daily learning reminder notifications at configurable time (default 7:00 PM)
- FR59: Users can receive streak protection alert if no app usage by 9:00 PM
- FR60: Users can receive instant notification when mystery reward is earned
- FR61: Users can enable/disable notification types independently
- FR62: Users can configure notification times
- FR63: Parents can receive reward milestone notifications

**Offline & Data Management:**
- FR64: Users can access all core features without network connectivity (offline-first)
- FR65: System can perform first-launch sync to download all 4,192 Mishnayos from Firebase to local database
- FR66: System can perform background delta sync of local completions to Firebase when online
- FR67: System can resume interrupted first-launch sync from checkpoint
- FR68: System can resolve sync conflicts using last-write-wins with UTC timestamps
- FR69: System can retry failed syncs with exponential backoff
- FR70: Users can export progress data to JSON for backup
- FR71: Users can import progress data from JSON backup file

**Security & Access Control:**
- FR72: System can encrypt and securely store parent PIN using secure storage
- FR73: System can encrypt and securely store tutor PIN using secure storage
- FR74: System can authenticate parent mode access via 4-digit PIN
- FR75: System can authenticate tutor mode access via separate 4-digit PIN
- FR76: System can enforce view-only permissions for tutor mode (no edit capabilities)

**Calendar & Date Management:**
- FR77: System can calculate Hebrew calendar dates using kosher_dart library
- FR78: System can track bar mitzvah deadline (19 Kislev, 5789 / December 7, 2028)
- FR79: System can calculate days remaining until bar mitzvah
- FR80: System can use Hebrew calendar for scheduling and display purposes

**Completion Animations & Feedback:**
- FR81: Users can see satisfying completion animations when marking stages complete
- FR82: Users can see points popup immediately when earning points
- FR83: Users can see progress bars fill incrementally with each completion
- FR84: Users can see streak counter increment with daily usage

### Non-Functional Requirements

**Performance - Response Time:**
- NFR1: App startup must complete to usable state within 2 seconds on mid-range Android devices
- NFR2: Smart scheduler calculations must complete within 500ms for daily recommendations
- NFR3: Database queries must return results within 100ms even with thousands of completion records
- NFR4: User actions (mark complete, navigate, view progress) must respond within 200ms

**Performance - Rendering:**
- NFR5: UI must maintain 60fps during scrolling, animations, and transitions on mid-range Android devices
- NFR6: Progress bar animations must render smoothly without frame drops
- NFR7: List scrolling (Mishna browsing) must maintain consistent 60fps performance

**Performance - Resource Efficiency:**
- NFR8: Background sync operations must minimize battery drain (< 2% daily battery impact)
- NFR9: App memory footprint must not exceed 150MB during normal operation
- NFR10: First-launch sync must complete within 5 minutes on typical mobile network connection

**Reliability & Data Integrity - Data Persistence:**
- NFR11: Zero data loss over 3-year usage period - all completion data must be preserved
- NFR12: Completion log must maintain integrity through device reboots, crashes, and low-memory situations
- NFR13: SQLite transactions must use automatic rollback on failure to prevent partial writes
- NFR14: App state must survive device restarts without loss of unsynchronized data

**Reliability & Data Integrity - Crash Resilience:**
- NFR15: Crash-free rate must exceed 99.9% over the 3-year period
- NFR16: All errors must be handled gracefully with user-friendly error messages
- NFR17: Network errors must not cause app crashes or data corruption

**Reliability & Data Integrity - Sync Reliability:**
- NFR18: First-launch sync must be resumable from checkpoint if interrupted
- NFR19: Background sync must retry failed operations with exponential backoff (max 5 retries)
- NFR20: Sync conflicts must resolve using last-write-wins with UTC timestamps
- NFR21: Firebase quota limits must be monitored with graceful degradation if exceeded

**Offline Capability - Core Functionality:**
- NFR22: All essential features (browse, mark complete, view progress, smart scheduler) must work without network connectivity
- NFR23: Offline operation must provide identical user experience to online operation for core features
- NFR24: Local database must serve as source of truth, not Firebase

**Offline Capability - Sync Behavior:**
- NFR25: Background sync must operate battery-efficiently without blocking user actions
- NFR26: Network state changes must trigger sync automatically when connectivity restored
- NFR27: Sync must respect Android battery saver mode and defer non-critical operations

**Security & Privacy - Authentication:**
- NFR28: Parent PIN must be encrypted using flutter_secure_storage with bcrypt hashing
- NFR29: Tutor PIN must be encrypted separately from parent PIN using secure storage
- NFR30: PIN authentication must lockout after 5 failed attempts with 30-second timeout

**Security & Privacy - Data Protection:**
- NFR31: All Firebase communication must use HTTPS/TLS encryption
- NFR32: Firestore security rules must prevent unauthorized access to user data
- NFR33: Local data must be stored in app-private directory inaccessible to other apps

**Security & Privacy - Access Control:**
- NFR34: Tutor mode must enforce view-only access preventing data modification
- NFR35: Parent mode must be the only mode with data modification capabilities (beyond child marking completions)

**Integration & Compatibility - External APIs:**
- NFR36: Sefaria API integration must handle API failures gracefully with cached fallback
- NFR37: Hebrew calendar calculations (kosher_dart) must be verified against authoritative sources (Hebcal.com)
- NFR38: Firebase operations must handle network timeouts gracefully (15-second timeout with retry)

**Integration & Compatibility - Platform Compatibility:**
- NFR39: App must support Android API 21+ (Android 5.0 Lollipop and above)
- NFR40: App must function correctly on screen sizes from 5" phones to 10" tablets
- NFR41: App must support both portrait and landscape orientations

**Integration & Compatibility - Hebrew Language Support:**
- NFR42: Hebrew text must render correctly with RTL (right-to-left) layout
- NFR43: Bidirectional text (Hebrew + English) must display properly
- NFR44: Hebrew fonts must be included and render clearly on all supported devices

**Accessibility (Baseline) - Material Design 3 Compliance:**
- NFR45: Touch targets must meet minimum 48dp size requirement
- NFR46: Color contrast ratios must meet WCAG AA standards (4.5:1 for normal text, 3:1 for large text)
- NFR47: UI must provide semantic structure for future screen reader support

### Additional Requirements

**Starter Template from Architecture:**
- Official Flutter CLI (`flutter create --org com.niasoff.mishnayos --platforms=android --android-language kotlin mishnayos_tracker`)
- Flutter/Dart framework with Android-only deployment for v1.0
- Minimum Android API 21 (Lollipop), target latest stable
- Kotlin for native Android code

**Infrastructure & Deployment:**
- Firebase project with Anonymous Authentication
- Cloud Firestore database with security rules
- SQLite local database (drift ORM)
- Encrypted secure storage (flutter_secure_storage) for PINs
- Local notifications (flutter_local_notifications)
- Direct APK distribution (no Play Store for v1.0)

**Integration Requirements:**
- Sefaria API client for Mishna text retrieval (Hebrew + English)
- kosher_dart library for Hebrew calendar calculations
- Firebase Cloud Firestore for cloud sync and backup
- Connectivity monitoring (connectivity_plus)
- HTTP client with retry logic (dio)

**Data Migration & Setup:**
- Pre-seed database with all 4,192 Mishnayos from Sefaria API
- First-launch sync with resumable checkpoints
- Bulk masechta marking capability for initial onboarding
- JSON export/import for data backup/restore

**Monitoring & Logging:**
- Talker logging framework with in-app log viewer
- Automatic HTTP request/response logging (talker_dio_logger)
- Riverpod state change logging (talker_riverpod_logger)
- Error tracking with stack traces
- Production-ready error reporting

**API & Communication:**
- RESTful API integration with Sefaria
- Firestore realtime sync with conflict resolution
- Background sync with exponential backoff retry
- Network-agnostic operation for core features
- Graceful API failure handling with cached fallback

**Security Implementation:**
- bcrypt PIN hashing with flutter_secure_storage
- Platform-specific keystore (Android Keystore)
- Firestore security rules preventing unauthorized access
- HTTPS/TLS for all Firebase communication
- Role-based access control (parent full access, tutor view-only)

**Code Architecture Requirements:**
- Clean architecture (presentation/domain/data layers)
- Feature-first folder structure
- Riverpod state management with code generation
- Immutable data models with freezed
- Type-safe navigation with auto_route
- Type-safe database queries with drift
- 80%+ test coverage on business logic

**Development & Build:**
- build_runner for code generation (drift, freezed, auto_route, riverpod_generator)
- Environment configuration via --dart-define-from-file
- GitHub Actions CI/CD pipeline
- Mocktail for unit testing
- Material Design 3 theming
- Hebrew RTL layout support

### FR Coverage Map

**Epic 1: Project Foundation & Data Infrastructure**
- FR1: Complete database of 4,192 Mishnayos
- FR4: Sefaria API attribution
- FR65: First-launch sync from Firebase to SQLite
- FR77: Hebrew calendar calculations (kosher_dart)
- FR78: Track bar mitzvah deadline
- FR79: Calculate days remaining
- FR80: Hebrew calendar for scheduling/display

**Epic 2: Core Learning Cycle & Progress Tracking**
- FR2: Browse Mishnayos hierarchically
- FR3: View Hebrew and English text
- FR10: Mark Mishna complete (learning stage)
- FR11: Mark complete (chazara 1)
- FR12: Mark complete (chazara 2)
- FR13: Enforce immutability
- FR14: Append-only completion log
- FR22: View overall progress percentage
- FR81: Completion animations
- FR82: Points popup
- FR83: Progress bars fill

**Epic 3: Multi-Track Learning Management**
- FR5: Manage up to 3 tracks (personal/school/tutor)
- FR6: Add/remove optional tracks
- FR7: Maintain bookmark per track
- FR8: Prevent duplicate assignments
- FR9: Designate track when marking progress
- FR26: View which track contributed completion

**Epic 4: Smart Scheduler & Daily Recommendations**
- FR15: Track Mishnayos due for chazara 1
- FR16: Track Mishnayos due for chazara 2
- FR17: Generate daily recommendations
- FR18: Calculate optimal daily task count
- FR19: Adapt recommendations based on pace
- FR20: Balance new learning with chazara
- FR21: Automatically schedule chazara tasks
- FR27: Current pace status
- FR28: Projected completion date
- FR29: Completion history over time

**Epic 5: Gamification & Engagement System**
- FR30: Award points for learning (configurable)
- FR31: Award points for chazara 1
- FR32: Award points for chazara 2
- FR33: Track total points
- FR34: View points earned over time
- FR35: Track consecutive days (streak)
- FR36: View current and max streak
- FR84: Streak counter increment

**Epic 6: Parent Mode & Reward Management**
- FR37: Display mystery rewards with progress bars
- FR38: Notify when reward threshold reached
- FR39: Parents reveal mystery rewards
- FR40: PIN-protected parent mode
- FR41: Manage reward catalog (add/edit/delete)
- FR42: Bulk mark masechtas as complete
- FR43: Configure point values
- FR44: Add/remove optional tracks
- FR45: View analytics dashboard
- FR46: View all completion history
- FR55: Configure initial rewards during setup
- FR56: Bulk mark prior completed masechtas
- FR72: Encrypt/store parent PIN
- FR74: Authenticate parent mode

**Epic 7: Tutor Mode & Progress Visibility**
- FR47: PIN-protected tutor mode
- FR48: View-only access to all data
- FR49: See completion log with timestamps
- FR50: See Mishnayos due for chazara
- FR51: View on-track status and metrics
- FR52: View progress by seder/masechta
- FR73: Encrypt/store tutor PIN
- FR75: Authenticate tutor mode
- FR76: Enforce view-only permissions

**Epic 8: Onboarding & Initial Setup**
- FR53: Complete initial app setup
- FR54: Set personalized user information
- FR57: Configure learning order preferences

**Epic 9: Progress Visualization & Analytics**
- FR23: View progress by seder
- FR24: View progress by masechta
- FR25: View progress by perek
- FR29: View completion history over time (enhanced views)

**Epic 10: Notification & Reminder System**
- FR58: Daily learning reminder notifications
- FR59: Streak protection alert
- FR60: Instant reward earned notification
- FR61: Enable/disable notification types
- FR62: Configure notification times
- FR63: Parents receive reward milestone notifications

**Epic 11: Cloud Sync & Data Management**
- FR64: Offline-first operation (core features work offline)
- FR66: Background delta sync to Firebase
- FR67: Resume interrupted sync from checkpoint
- FR68: Resolve sync conflicts (last-write-wins)
- FR69: Retry failed syncs (exponential backoff)
- FR70: Export progress data to JSON
- FR71: Import progress data from JSON

## Epic List

### Epic 1: Project Foundation & Data Infrastructure
Initialize Flutter project with complete Mishnayos database, Firebase configuration, drift local database, and Hebrew calendar support. Users can browse all 4,192 Mishnayos organized by seder/masechta/perek, view Hebrew and English text, and system tracks bar mitzvah deadline with Hebrew calendar calculations.

**FRs covered:** FR1, FR4, FR65, FR77, FR78, FR79, FR80
**Architecture requirements:** Flutter CLI initialization, Firebase Anonymous Auth, Cloud Firestore setup, SQLite (drift) database, kosher_dart library, Sefaria API integration, all 4,192 Mishnayos pre-seeded

### Epic 2: Core Learning Cycle & Progress Tracking
Yisroel Meir can mark Mishnayos as complete through the 3-stage learning cycle (learning → chazara 1 → chazara 2) with immutable completion tracking and see his overall progress with satisfying animations and feedback.

**FRs covered:** FR2, FR3, FR10, FR11, FR12, FR13, FR14, FR22, FR81, FR82, FR83

### Epic 3: Multi-Track Learning Management
Users can organize learning across personal, school, and tutor contexts with independent bookmarks for each track, preventing duplicate assignments while maintaining unified progress toward the 4,192 completion goal.

**FRs covered:** FR5, FR6, FR7, FR8, FR9, FR26

### Epic 4: Smart Scheduler & Daily Recommendations
Yisroel Meir receives intelligent daily task recommendations (personal track only) that adapt to his pace, automatically schedule chazara tasks, and keep him on track for his bar mitzvah deadline while balancing new learning with review pile-up.

**FRs covered:** FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR27, FR28, FR29

### Epic 5: Gamification & Engagement System
Yisroel Meir earns points for each completion stage and builds streaks for consecutive daily usage, providing motivation and visible progress tracking that makes learning addictive and rewarding.

**FRs covered:** FR30, FR31, FR32, FR33, FR34, FR35, FR36, FR84

### Epic 6: Parent Mode & Reward Management
Parents can configure mystery rewards, manage track settings, bulk mark completed masechtas, and monitor progress through PIN-protected access with analytics dashboard showing on-track status and completion metrics.

**FRs covered:** FR37, FR38, FR39, FR40, FR41, FR42, FR43, FR44, FR45, FR46, FR55, FR56, FR72, FR74

### Epic 7: Tutor Mode & Progress Visibility
Tutor can view all progress and completion data (but not modify) through separate PIN-protected access, seeing completion logs, chazara queues, and progress breakdowns to align teaching sessions effectively.

**FRs covered:** FR47, FR48, FR49, FR50, FR51, FR52, FR73, FR75, FR76

### Epic 8: Onboarding & Initial Setup
New users complete personalized first-time setup including bar mitzvah date configuration, name entry, and learning order preferences, creating a tailored experience for their 3-year journey.

**FRs covered:** FR53, FR54, FR57

### Epic 9: Progress Visualization & Analytics
Users can visualize progress across multiple dimensions (by seder, masechta, perek) with enhanced charts and historical trends, providing comprehensive insights into learning patterns over time.

**FRs covered:** FR23, FR24, FR25, FR29

### Epic 10: Notification & Reminder System
Users receive timely local notifications including daily learning reminders, streak protection alerts, and instant reward milestone notifications, with independent control over notification types and timing.

**FRs covered:** FR58, FR59, FR60, FR61, FR62, FR63

### Epic 11: Cloud Sync & Data Management
Progress is automatically backed up to Firebase Cloud Firestore with background delta sync, conflict resolution, and exponential backoff retry, plus data export/import capabilities for manual backup and device transfer.

**FRs covered:** FR64, FR66, FR67, FR68, FR69, FR70, FR71

## Epic 1: Project Foundation & Data Infrastructure

Initialize Flutter project with complete Mishnayos database, Firebase configuration, drift local database, and Hebrew calendar support. Users can browse all 4,192 Mishnayos organized by seder/masechta/perek, view Hebrew and English text, and system tracks bar mitzvah deadline with Hebrew calendar calculations.

### Story 1.1: Initialize Flutter Project with Architecture Foundations

As a developer,
I want the Flutter project initialized with all architectural foundations (clean architecture structure, state management, navigation, logging),
So that the codebase follows the defined architecture patterns and is ready for feature development.

**Acceptance Criteria:**

**Given** the project initialization command from architecture document
**When** I run `flutter create --org com.niasoff.mishnayos --platforms=android --android-language kotlin mishnayos_tracker`
**Then** the Flutter project is created with Android-only configuration and Kotlin native code

**And** the feature-first folder structure is created with all core directories (database, navigation, logging, theme, auth, network, utils, constants, providers)

**And** `pubspec.yaml` includes all required dependencies with specified versions (drift, auto_route, riverpod, freezed, dio, talker, firebase, kosher_dart, etc.)

**And** `build.yaml` is configured for build_runner code generation

**And** `analysis_options.yaml` is configured with strict linting rules

**And** `.gitignore` includes generated files (*.g.dart, *.freezed.dart, *.gr.dart)

**And** `config/dev.json` and `config/prod.json` template files are created

**And** Material Design 3 theme is configured with RTL support for Hebrew

**And** Talker logging is configured in providers

**And** the project builds successfully with `flutter run`

### Story 1.2: Set Up Database Schema for Mishnayos

As a developer,
I want the drift database schema created with tables for Mishnayos structure (sedarim, masechtot, perakim, mishnayos),
So that the app can store and query the complete hierarchical structure of all 4,192 Mishnayos.

**Acceptance Criteria:**

**Given** the drift ORM is configured in the project
**When** I define the database tables in `lib/core/database/tables/`
**Then** the following drift tables are created with proper schema

**And** `sedarim` table exists with columns: id, name_hebrew, name_english, display_order

**And** `masechtot` table exists with columns: id, seder_id (FK), name_hebrew, name_english, display_order, total_perakim

**And** `perakim` table exists with columns: id, masechta_id (FK), perek_number, total_mishnayos

**And** `mishnayos` table exists with columns: id, perek_id (FK), mishna_number, text_hebrew, text_english, sefaria_ref

**And** `AppDatabase` class is defined with @DriftDatabase annotation

**And** database provider is created using riverpod_generator

**And** indexes are created for foreign keys (seder_id, masechta_id, perek_id)

**And** `dart run build_runner build` generates database code successfully

**And** the app initializes SQLite database on startup without errors

### Story 1.3: Integrate Sefaria API Client

As a developer,
I want a configured dio HTTP client for Sefaria API integration with error handling and logging,
So that the app can fetch Mishna text data from Sefaria with proper retry logic and graceful failure handling.

**Acceptance Criteria:**

**Given** dio package is configured in the project
**When** I create the Sefaria API client in `lib/features/mishna_browsing/data/data_sources/sefaria_api_client.dart`
**Then** a dio instance is configured with base URL `https://www.sefaria.org/api/`

**And** talker_dio_logger is integrated for automatic request/response logging

**And** interceptor is configured for error handling with exponential backoff retry

**And** timeout is set to 15 seconds with automatic retry on network failure

**And** API client has method `Future<MishnaTextDto> fetchMishnaText(String sefariaRef)` that returns Hebrew and English text

**And** API failures are caught and transformed into user-friendly error messages

**And** freezed DTO model `MishnaTextDto` is created for API response mapping with json_serializable

**And** network errors result in graceful degradation without app crashes

**And** successful API call returns parsed MishnaTextDto with Hebrew and English text fields

### Story 1.4: Seed Database with 4,192 Mishnayos

As a developer,
I want the database pre-seeded with all 4,192 Mishnayos from Sefaria API during first-launch sync,
So that users have immediate access to the complete Mishnayos structure offline.

**Acceptance Criteria:**

**Given** the Sefaria API client and database schema are configured
**When** the app launches for the first time
**Then** the first-launch sync process begins automatically

**And** all 6 sedarim are inserted into the sedarim table (Zeraim, Moed, Nashim, Nezikin, Kodashim, Taharot)

**And** all 63 masechtot are inserted into the masechtot table with correct seder associations

**And** all perakim are inserted with correct masechta associations

**And** all 4,192 Mishnayos are fetched from Sefaria API and inserted with Hebrew text, English text, and Sefaria reference

**And** sync progress is tracked with checkpoints in `sync_checkpoints` table

**And** if sync is interrupted, it resumes from the last checkpoint on next launch

**And** sync completion is stored in local state to prevent re-seeding

**And** sync completes within 5 minutes on typical mobile network connection (NFR10)

**And** user sees progress indicator during sync with percentage complete

**And** after sync completion, all 4,192 Mishnayos are queryable from SQLite database

### Story 1.5: Implement Hebrew Calendar Integration

As a developer,
I want kosher_dart library integrated for Hebrew calendar calculations,
So that the system can track the bar mitzvah deadline and calculate days remaining using the Hebrew calendar.

**Acceptance Criteria:**

**Given** kosher_dart package is added to dependencies
**When** I create Hebrew calendar helper in `lib/core/utils/helpers/hebrew_calendar_helper.dart`
**Then** helper class wraps kosher_dart functionality with app-specific methods

**And** method `JewishDate getBarMitzvahDate()` returns 19 Kislev 5789

**And** method `DateTime getBarMitzvahGregorianDate()` returns December 7, 2028

**And** method `int getDaysUntilBarMitzvah(DateTime currentDate)` calculates days remaining accurately

**And** method `String formatHebrewDate(DateTime gregorianDate)` returns formatted Hebrew date string

**And** method `JewishDate toJewishDate(DateTime gregorianDate)` converts Gregorian to Hebrew calendar

**And** Hebrew calendar calculations are verified against Hebcal.com authoritative source (NFR37)

**And** all DateTime values are stored in UTC throughout the system

**And** bar mitzvah deadline constant (19 Kislev 5789 / December 7, 2028) is stored in `lib/core/constants/app_constants.dart`

### Story 1.6: Configure Firebase and Cloud Firestore

As a developer,
I want Firebase Anonymous Authentication and Cloud Firestore configured,
So that the app can backup data to the cloud and support future multi-device sync.

**Acceptance Criteria:**

**Given** Firebase packages (firebase_core, firebase_auth, cloud_firestore) are in dependencies
**When** I configure Firebase in the app initialization
**Then** Firebase is initialized in `main.dart` before app startup using `Firebase.initializeApp()`

**And** environment-specific Firebase configuration is loaded from `config/dev.json` or `config/prod.json` using `--dart-define-from-file`

**And** Firebase Anonymous Authentication is configured and creates anonymous user on first launch

**And** Cloud Firestore is initialized with offline persistence enabled

**And** Firestore security rules are deployed preventing unauthorized access (data scoped by anonymous user ID)

**And** Firestore collections structure is defined: `users/{userId}/mishnaCompletions`, `users/{userId}/userSettings`, `users/{userId}/syncCheckpoints`

**And** Firebase initialization errors are caught and logged via talker

**And** app gracefully handles Firebase quota limit exceeded scenarios (NFR21)

**And** all Firebase communication uses HTTPS/TLS encryption (NFR31)

**And** successful Firebase initialization allows app to proceed to main screen

## Epic 2: Core Learning Cycle & Progress Tracking

Yisroel Meir can mark Mishnayos as complete through the 3-stage learning cycle (learning → chazara 1 → chazara 2) with immutable completion tracking and see his overall progress with satisfying animations and feedback.

### Story 2.1: Create Completion Tracking Database Schema

As a developer,
I want drift database tables for tracking completions through the 3-stage learning cycle,
So that the system can store immutable completion records with timestamps.

**Acceptance Criteria:**

**Given** the core database schema exists from Epic 1
**When** I define completion tracking tables
**Then** `completions` table is created with columns:
- id (integer, primary key, autoIncrement)
- mishna_id (integer, foreign key to mishnayos, not null)
- learning_stage (text, values: 'learning', 'chazara_1', 'chazara_2', not null)
- completed_at (datetime, UTC, not null)
- track_id (text, values: 'personal', 'school', 'tutor', not null)
- points_awarded (integer, not null)
- is_locked (boolean, default true, not null)

**And** `completions` table uses append-only architecture (no update/delete operations allowed)

**And** index is created on completions(mishna_id, learning_stage) for fast lookups

**And** index is created on completions(completed_at) for chronological queries

**And** freezed domain entity `CompletionLog` is created in domain layer

**And** completion repository interface is defined in domain layer

**And** completion repository implementation is created in data layer using drift DAO

**And** all database writes use transactions with automatic rollback on failure (NFR13)

### Story 2.2: Implement Hierarchical Mishna Browsing

As a user,
I want to browse Mishnayos hierarchically by seder → masechta → perek → individual Mishna,
So that I can navigate the complete structure and find specific Mishnayos to learn.

**Acceptance Criteria:**

**Given** the database is seeded with all 4,192 Mishnayos
**When** I open the Mishna browsing screen
**Then** I see a list of all 6 sedarim with Hebrew and English names

**And** when I tap a seder, I see all masechtot within that seder

**And** when I tap a masechta, I see all perakim within that masechta

**And** when I tap a perek, I see all Mishnayos within that perek

**And** each Mishna displays its number (e.g., "Mishna 3")

**And** list scrolling maintains 60fps performance (NFR7)

**And** navigation uses auto_route with type-safe routing

**And** back navigation works correctly at each level

**And** current navigation path is displayed (breadcrumb: Seder > Masechta > Perek)

**And** Material Design 3 components are used throughout

### Story 2.3: Display Mishna Text with Hebrew and English

As a user,
I want to view individual Mishna text in both Hebrew and English with proper RTL layout,
So that I can read and study each Mishna in my preferred language.

**Acceptance Criteria:**

**Given** I have navigated to a specific Mishna
**When** I view the Mishna detail screen
**Then** the Hebrew text is displayed with RTL (right-to-left) layout

**And** the English text is displayed with LTR (left-to-right) layout

**And** both Hebrew and English text are visible simultaneously (bilingual view)

**And** Hebrew font renders clearly on all supported Android devices (NFR44)

**And** bidirectional text (mixed Hebrew and English) displays correctly (NFR43)

**And** Sefaria attribution is displayed at the bottom: "Text provided by Sefaria.org"

**And** text is scrollable if content exceeds screen height

**And** text size is readable and meets WCAG AA contrast standards (NFR46)

**And** screen loads and displays text within 200ms (NFR4)

### Story 2.4: Mark Mishna Complete for Learning Stage

As a user,
I want to mark a Mishna as complete for the learning stage (stage 1),
So that I can track which Mishnayos I have learned for the first time.

**Acceptance Criteria:**

**Given** I am viewing a Mishna that has not been completed for learning stage
**When** I tap the "Mark as Learned" button
**Then** a completion record is created with learning_stage='learning', completed_at=current UTC timestamp, track_id='personal'

**And** points are awarded (default 10 points) and stored in completion record

**And** completion record is_locked is set to true (immutable)

**And** satisfying completion animation plays (checkmark animation)

**And** points popup appears showing "+10 points"

**And** the completion is immediately saved to SQLite database within a transaction

**And** the "Mark as Learned" button changes to "Completed ✓" and is disabled

**And** background sync queues the completion for Firebase upload (non-blocking)

**And** completion log entry includes UTC timestamp for scheduling chazara 1 (next day)

**And** UI updates within 200ms of button press (NFR4)

**And** once marked complete, the stage cannot be unmarked (FR13)

### Story 2.5: Mark Mishna Complete for Chazara 1 and Chazara 2

As a user,
I want to mark a Mishna as complete for chazara 1 (stage 2) and chazara 2 (stage 3),
So that I can track my review progress through the complete 3-stage learning cycle.

**Acceptance Criteria:**

**Given** a Mishna has been completed for learning stage
**When** I tap "Mark Chazara 1 Complete" button
**Then** a second completion record is created with learning_stage='chazara_1', completed_at=UTC, track_id='personal'

**And** 5 points are awarded for chazara 1 completion

**And** completion animation plays and "+5 points" popup appears

**And** chazara 2 is automatically scheduled for 7 days after chazara 1 completion

**And** the button changes to "Chazara 1 Complete ✓" and is disabled

**Given** a Mishna has been completed for chazara 1
**When** I tap "Mark Chazara 2 Complete" button
**Then** a third completion record is created with learning_stage='chazara_2', completed_at=UTC, track_id='personal'

**And** 5 points are awarded for chazara 2 completion

**And** completion animation plays and "+5 points" popup appears

**And** all three stages are now marked complete (learning, chazara 1, chazara 2)

**And** Mishna shows "Fully Complete ✓✓✓" status

**And** all completion records remain immutable and locked (FR13)

**And** completion log maintains integrity through device reboots (NFR12)

### Story 2.6: Display Overall Progress Percentage

As a user,
I want to see my overall progress as a percentage of 4,192 Mishnayos completed,
So that I can track how much of Shas I have learned.

**Acceptance Criteria:**

**Given** I have completed various Mishnayos across different stages
**When** I view the progress dashboard
**Then** overall progress percentage is calculated as (unique Mishnayos with learning stage complete / 4,192) × 100

**And** progress is displayed prominently: "X% Complete (Y of 4,192 Mishnayos)"

**And** progress bar visually shows completion percentage

**And** progress bar fills incrementally with each new completion (FR83)

**And** separate percentages are shown for each stage:
  - Learning stage: X% (Y of 4,192)
  - Chazara 1: X% (Y of 4,192)
  - Chazara 2: X% (Y of 4,192)

**And** progress calculations use database queries completing within 100ms (NFR3)

**And** progress updates immediately after marking a Mishna complete

**And** progress persists correctly through app restarts

**And** progress data is accurate even with thousands of completion records (NFR3)

## Epic 3: Multi-Track Learning Management

Users can organize learning across personal, school, and tutor contexts with independent bookmarks for each track, preventing duplicate assignments while maintaining unified progress toward the 4,192 completion goal.

### Story 3.1: Create Track Management Database Schema

As a developer,
I want database tables for managing multiple learning tracks with bookmarks,
So that the system can support personal, school, and tutor tracks with independent progress.

**Acceptance Criteria:**

**Given** the completion tracking schema exists from Epic 2
**When** I define track management tables
**Then** `tracks` table is created with columns:
- id (text, primary key, values: 'personal', 'school', 'tutor')
- is_active (boolean, not null)
- created_at (datetime, UTC, not null)

**And** `track_bookmarks` table is created with columns:
- id (integer, primary key, autoIncrement)
- track_id (text, foreign key to tracks, not null)
- current_mishna_id (integer, foreign key to mishnayos, nullable)
- updated_at (datetime, UTC, not null)

**And** `mishna_track_assignments` table is created with columns:
- id (integer, primary key, autoIncrement)
- mishna_id (integer, foreign key to mishnayos, not null)
- track_id (text, foreign key to tracks, not null)
- assigned_at (datetime, UTC, not null)

**And** unique constraint exists on mishna_track_assignments(mishna_id) to prevent duplicate assignments (FR8)

**And** personal track is mandatory and inserted by default with is_active=true

**And** school and tutor tracks are optional and created when activated

**And** freezed entities created for Track, TrackBookmark, MishnaTrackAssignment

### Story 3.2: Add and Remove Optional Tracks

As a user,
I want to add or remove school and tutor tracks as my learning circumstances change,
So that I can organize my learning across different contexts.

**Acceptance Criteria:**

**Given** only the personal track is active by default
**When** I navigate to track management settings
**Then** I see a list of available tracks: Personal (mandatory), School (optional), Tutor (optional)

**And** personal track is marked as "Active" and cannot be removed

**And** school track shows "Add School Track" button if not active

**When** I tap "Add School Track"
**Then** school track is inserted into tracks table with is_active=true

**And** success message displays: "School track added"

**And** school track appears in track selection throughout the app

**Given** school track is active
**When** I tap "Remove School Track"
**Then** confirmation dialog appears: "Remove school track? This will unassign all Mishnayos from this track."

**When** I confirm removal
**Then** school track is_active is set to false

**And** all mishna_track_assignments with track_id='school' are deleted

**And** track bookmark for school is deleted

**And** Mishnayos previously assigned to school track become available for reassignment

**And** same add/remove functionality works for tutor track

### Story 3.3: Maintain Independent Bookmarks per Track

As a user,
I want each active track to maintain an independent "where I'm up to" bookmark,
So that I can resume learning from the correct position in each context.

**Acceptance Criteria:**

**Given** multiple tracks are active (personal, school, tutor)
**When** I mark a Mishna as complete for a specific track
**Then** that track's bookmark is automatically updated to the next Mishna in sequence

**And** bookmark is stored in track_bookmarks table with current_mishna_id and updated_at timestamp

**Given** I open the app
**When** I select "Continue Learning" for personal track
**Then** I am navigated to the Mishna indicated by the personal track bookmark

**And** if no bookmark exists, I start at the first Mishna of the configured learning order

**Given** I have separate bookmarks for personal and school tracks
**When** I switch between tracks
**Then** each track remembers its independent position

**And** personal track bookmark: Masechta Berachos, Perek 3, Mishna 5

**And** school track bookmark: Masechta Shabbos, Perek 1, Mishna 2

**And** bookmarks persist correctly through app restarts

**And** bookmark queries complete within 100ms (NFR3)

### Story 3.4: Prevent Duplicate Mishna Assignments Across Tracks

As a user,
I want the system to prevent assigning the same Mishna to multiple tracks,
So that I don't accidentally double-count Mishnayos toward my 4,192 completion goal.

**Acceptance Criteria:**

**Given** I am marking a Mishna as complete
**When** I select which track to assign it to
**Then** I only see tracks that don't already have this Mishna assigned

**Given** Mishna #1234 is assigned to personal track
**When** I attempt to assign Mishna #1234 to school track
**Then** error message displays: "This Mishna is already assigned to Personal track. Unassign it first to reassign."

**And** the assignment is blocked at the database level by unique constraint

**Given** I want to reassign a Mishna from one track to another
**When** I unassign Mishna #1234 from personal track
**Then** the mishna_track_assignments record is deleted

**And** Mishna #1234 becomes available for assignment to school or tutor track

**And** all completion records for that Mishna remain immutable (history preserved)

**And** duplicate prevention works correctly even under concurrent operations

**And** database constraint prevents duplicate assignments at all times (FR8)

### Story 3.5: Designate Track When Marking Progress

As a user,
I want to designate which track a Mishna belongs to when marking it complete,
So that my progress is properly attributed to the correct learning context.

**Acceptance Criteria:**

**Given** I have multiple active tracks (personal, school, tutor)
**When** I mark a Mishna as complete for learning stage
**Then** I am prompted: "Which track is this for?" with options for all active tracks

**And** I select "Personal" track

**Then** completion record is created with track_id='personal'

**And** mishna_track_assignment record is created linking this Mishna to personal track

**And** personal track bookmark advances to the next Mishna

**Given** I have only personal track active
**When** I mark a Mishna complete
**Then** it is automatically assigned to personal track without prompting

**Given** I am viewing progress statistics
**When** I view a completed Mishna
**Then** the track attribution is displayed: "Completed via Personal track on [date]" (FR26)

**And** progress breakdowns show completions by track:
  - Personal: 150 Mishnayos
  - School: 75 Mishnayos
  - Tutor: 25 Mishnayos
  - Total: 250 Mishnayos

## Epic 4: Smart Scheduler & Daily Recommendations

Yisroel Meir receives intelligent daily task recommendations (personal track only) that adapt to his pace, automatically schedule chazara tasks, and keep him on track for his bar mitzvah deadline while balancing new learning with review pile-up.

### Story 4.1: Track Mishnayos Due for Chazara

As a developer,
I want the system to track which Mishnayos are due for chazara 1 (next day) and chazara 2 (7 days later),
So that the scheduler can include review tasks in daily recommendations.

**Acceptance Criteria:**

**Given** a Mishna was completed for learning stage on date D
**When** the system calculates due dates
**Then** chazara 1 is due on date D+1 (next day)

**And** chazara 1 due date is stored/calculated based on completed_at timestamp from learning stage completion

**Given** a Mishna was completed for chazara 1 on date C1
**When** the system calculates chazara 2 due date
**Then** chazara 2 is due on date C1+7 (7 days after chazara 1)

**And** repository method `Future<List<Mishna>> getMishnayosDueForChazara1(DateTime asOfDate)` returns all Mishnayos where learning stage completed_at is <= asOfDate - 1 day AND chazara 1 not yet complete

**And** repository method `Future<List<Mishna>> getMishnayosDueForChazara2(DateTime asOfDate)` returns all Mishnayos where chazara 1 completed_at is <= asOfDate - 7 days AND chazara 2 not yet complete

**And** due date calculations use UTC timestamps consistently

**And** queries for due Mishnayos complete within 100ms even with thousands of completions (NFR3)

**And** overdue Mishnayos (past due date) are included in results

### Story 4.2: Calculate Optimal Daily Task Count

As a developer,
I want the scheduler to calculate optimal daily task count based on bar mitzvah deadline and current progress,
So that Yisroel Meir stays on pace to complete all 4,192 Mishnayos by December 7, 2028.

**Acceptance Criteria:**

**Given** the bar mitzvah date is December 7, 2028 (19 Kislev 5789)
**When** the scheduler calculates daily task count
**Then** days remaining is calculated from current date to bar mitzvah date

**And** Mishnayos remaining = 4,192 - (Mishnayos where learning stage complete)

**And** base daily task count = ceil(Mishnayos remaining / days remaining)

**And** calculation accounts for the 3-stage cycle: each Mishna requires learning + chazara 1 + chazara 2

**And** scheduler adjusts for chazara pile-up: if chazara tasks exceed capacity, reduce new learning tasks

**And** minimum daily task count is 1 (never recommends 0 tasks)

**And** maximum daily task count is capped at 20 to prevent overload

**And** calculation completes within 500ms (NFR2)

**Given** Yisroel Meir is ahead of pace (completed more than expected)
**When** scheduler recalculates
**Then** daily task count decreases to maintain steady progress without overwork

**Given** Yisroel Meir is behind pace
**When** scheduler recalculates
**Then** daily task count increases to catch up to deadline

### Story 4.3: Generate Daily Recommendations for Personal Track

As a user,
I want to see daily task recommendations showing new learning and chazara tasks for my personal track,
So that I know exactly what to learn today to stay on track.

**Acceptance Criteria:**

**Given** I open the app on any given day
**When** the dashboard loads
**Then** I see "Today's Tasks" section with recommended tasks for personal track only

**And** recommendations include:
  - X new Mishnayos to learn (learning stage)
  - Y Mishnayos for chazara 1 (due today or overdue)
  - Z Mishnayos for chazara 2 (due today or overdue)

**And** total task count = X + Y + Z equals the calculated optimal daily count

**And** new learning tasks start from personal track bookmark position

**And** chazara tasks are sorted by due date (oldest first)

**And** each task displays: Mishna reference, track attribution, stage type, due date (if applicable)

**And** tapping a task navigates to that Mishna's detail screen

**And** recommendations regenerate daily at midnight or when app opens on new day

**And** recommendations are for personal track only (school and tutor tracks are manual) per FR17

**And** scheduler calculation completes within 500ms (NFR2)

### Story 4.4: Adapt Recommendations Based on Pace

As a user,
I want the daily recommendations to automatically adapt when I fall behind or accelerate ahead,
So that the scheduler keeps me on track for my bar mitzvah deadline.

**Acceptance Criteria:**

**Given** I have been completing more than the recommended daily tasks
**When** the scheduler recalculates the next day
**Then** recommended daily task count decreases slightly to prevent burnout

**And** pace status shows "You're X days ahead of schedule!"

**Given** I have been completing fewer than the recommended daily tasks
**When** the scheduler recalculates
**Then** recommended daily task count increases to help me catch up

**And** pace status shows "You're X days behind schedule. Let's catch up!"

**Given** I haven't used the app for several days
**When** I open the app again
**Then** chazara pile-up is detected (many overdue chazara tasks)

**And** scheduler balances new learning vs. chazara: if chazara tasks > 50% of capacity, reduce new learning

**And** I see message: "You have Y overdue reviews. Let's focus on catching up!"

**And** adaptive algorithm prevents overwhelming task counts (max 20 tasks/day)

**And** pace calculations update in real-time as I complete tasks throughout the day

**And** projected completion date adjusts based on current pace (FR28)

### Story 4.5: Display Current Pace Status and Projected Completion

As a user,
I want to see my current pace status (days ahead/on-pace/behind) and projected completion date,
So that I can understand if I'm on track to complete Shas by my bar mitzvah.

**Acceptance Criteria:**

**Given** I am viewing the progress dashboard
**When** the pace calculator runs
**Then** I see pace status indicator with one of three states:
  - "On Pace ✓" (within ±3 days of target)
  - "X Days Ahead 🎉" (ahead by >3 days)
  - "X Days Behind ⚠️" (behind by >3 days)

**And** projected completion date is calculated based on current average daily completion rate

**And** projected date is compared to bar mitzvah deadline (December 7, 2028)

**And** if projected date < deadline: "At your current pace, you'll finish by [projected date]" (green)

**And** if projected date > deadline: "At your current pace, you'll finish by [projected date]. Let's pick up the pace!" (red)

**And** pace status updates immediately after completing tasks

**And** completion history over time is displayed as a line chart showing daily completions (FR29)

**And** trend line shows whether pace is improving or declining

**And** all calculations complete within 500ms (NFR2)

## Epic 5: Gamification & Engagement System

Yisroel Meir earns points for each completion stage and builds streaks for consecutive daily usage, providing motivation and visible progress tracking that makes learning addictive and rewarding.

### Story 5.1: Award Points for Completion Stages

As a user,
I want to earn points for completing each stage (learning, chazara 1, chazara 2),
So that I feel rewarded for my progress and motivated to continue.

**Acceptance Criteria:**

**Given** default point values are configured (learning=10, chazara1=5, chazara2=5)
**When** I mark a Mishna complete for learning stage
**Then** 10 points are awarded and stored in the completion record

**And** points popup animation appears immediately showing "+10 points"

**When** I mark a Mishna complete for chazara 1
**Then** 5 points are awarded

**And** points popup shows "+5 points"

**When** I mark a Mishna complete for chazara 2
**Then** 5 points are awarded

**And** points popup shows "+5 points"

**And** total points across all completions = (learning completions × 10) + (chazara1 completions × 5) + (chazara2 completions × 5)

**And** points are stored immutably in each completion record

**And** points total is calculated in real-time by summing all completion.points_awarded

**And** points total displays on dashboard: "Total Points: 1,250"

**And** points popup animation is satisfying and completes within 200ms (NFR4)

### Story 5.2: Track and Display Total Points

As a user,
I want to see my total accumulated points and points earned over time,
So that I can track my learning effort and see my progress grow.

**Acceptance Criteria:**

**Given** I have completed various Mishnayos earning points
**When** I view the progress dashboard
**Then** total points are displayed prominently: "1,250 Points Earned"

**And** points breakdown by stage is shown:
  - Learning: 500 points (50 Mishnayos × 10)
  - Chazara 1: 375 points (75 Mishnayos × 5)
  - Chazara 2: 375 points (75 Mishnayos × 5)

**And** points earned over time chart displays with X-axis=date, Y-axis=cumulative points

**And** chart shows upward trend as points accumulate over weeks/months

**And** I can view points earned in different time ranges (week, month, all time)

**And** points calculation query completes within 100ms (NFR3)

**And** points total persists correctly through app restarts

**And** points are never lost or decremented (append-only, immutable)

### Story 5.3: Track Consecutive Days Streak

As a user,
I want to see my current streak of consecutive days I've used the app,
So that I feel motivated to maintain my daily learning habit.

**Acceptance Criteria:**

**Given** I open the app and complete at least one task each day
**When** I view the dashboard
**Then** current streak is displayed: "Current Streak: 7 Days 🔥"

**And** streak counter increments by 1 for each consecutive day with app usage

**And** "app usage" is defined as: opening the app and completing at least one Mishna stage

**Given** I use the app on Day 1, Day 2, Day 3 consecutively
**When** I open on Day 3
**Then** streak shows "3 Days"

**Given** I skip a day (no app usage on Day 4)
**When** I open the app on Day 5
**Then** streak resets to "1 Day"

**And** previous streak is saved as "Longest Streak: 3 Days"

**And** longest streak achieved is displayed alongside current streak

**And** streak persists correctly through app restarts

**And** streak calculation is based on local device timezone

**And** streak counter increments with daily usage (FR84)

### Story 5.4: Display Streak Protection Notifications

As a user,
I want to receive a notification if I haven't opened the app by 9 PM and I have an active streak,
So that I don't accidentally break a valuable multi-week/month streak.

**Acceptance Criteria:**

**Given** I have an active streak of 5+ days
**When** the time reaches 9:00 PM local time
**And** I haven't opened the app today
**Then** a local notification is triggered: "Don't break your 5-day streak! 🔥"

**And** tapping the notification opens the app to the daily tasks screen

**Given** I have already used the app today
**When** 9:00 PM arrives
**Then** no streak protection notification is sent

**Given** my current streak is 0 or 1 day
**When** 9:00 PM arrives
**Then** no streak protection notification is sent (only protects streaks 5+ days)

**And** streak protection notification can be disabled independently in settings

**And** notification respects Android 13+ runtime permissions (graceful degradation if permission denied)

**And** notification scheduling uses flutter_local_notifications

### Story 5.5: View Maximum Streak Achieved

As a user,
I want to see my longest streak ever achieved,
So that I can celebrate my best performance and aim to beat my record.

**Acceptance Criteria:**

**Given** I have had various streaks over time
**When** I view the gamification/stats screen
**Then** I see "Longest Streak: 23 Days 🏆"

**And** longest streak is calculated from historical app usage data

**And** if current streak exceeds previous longest, longest streak updates automatically

**Given** my current streak is 25 days and previous longest was 23 days
**When** the dashboard updates
**Then** longest streak now shows "25 Days"

**And** congratulations message appears: "New record! You beat your longest streak! 🎉"

**And** both current streak and longest streak are prominently displayed side-by-side

**And** streak data persists permanently through app restarts and device changes

## Epic 6: Parent Mode & Reward Management

Parents can configure mystery rewards, manage track settings, bulk mark completed masechtas, and monitor progress through PIN-protected access with analytics dashboard showing on-track status and completion metrics.

### Story 6.1: Implement PIN-Protected Parent Mode

As a parent,
I want to access parent mode with a secure 4-digit PIN,
So that I can manage settings and rewards without Yisroel Meir accessing these controls.

**Acceptance Criteria:**

**Given** the app is installed for the first time
**When** I navigate to parent mode
**Then** I am prompted to create a 4-digit parent PIN

**And** PIN entry screen has numeric keypad (0-9)

**And** PIN is hashed using bcrypt before storage

**And** hashed PIN is stored in flutter_secure_storage using Android Keystore (NFR28)

**Given** I enter and confirm my 4-digit PIN (e.g., 1234)
**When** I save the PIN
**Then** PIN is encrypted and stored securely

**And** success message displays: "Parent PIN created successfully"

**Given** parent PIN is already set
**When** I tap "Parent Mode" button
**Then** PIN entry screen appears: "Enter Parent PIN"

**When** I enter the correct PIN
**Then** I am granted access to parent mode dashboard

**When** I enter incorrect PIN
**Then** error message: "Incorrect PIN. Try again."

**And** after 5 failed attempts, PIN entry is locked for 30 seconds (NFR30)

**And** lockout message displays: "Too many attempts. Try again in 30 seconds."

### Story 6.2: Create Mystery Rewards Catalog

As a parent,
I want to add, edit, and delete mystery rewards with point thresholds,
So that I can motivate Yisroel Meir with surprises he can earn through learning.

**Acceptance Criteria:**

**Given** I am in parent mode
**When** I navigate to "Reward Catalog"
**Then** I see a list of all configured mystery rewards sorted by point threshold

**And** "Add Reward" button is available

**When** I tap "Add Reward"
**Then** reward form appears with fields:
  - Title (text, shown to child, e.g., "Mystery Reward #1")
  - Description (text, hidden until earned, e.g., "Trip to arcade")
  - Point Threshold (number, e.g., 1000)

**When** I fill in the form and tap "Save"
**Then** reward is inserted into `rewards` table with columns: id, title, description, point_threshold, is_revealed, created_at

**And** reward appears in catalog list

**And** success message: "Reward added successfully"

**Given** a reward exists in the catalog
**When** I tap "Edit" on the reward
**Then** I can modify title, description, or point threshold

**When** I tap "Delete" on a reward
**Then** confirmation dialog appears: "Delete this reward?"

**When** I confirm deletion
**Then** reward is removed from catalog

**And** if already earned by child, it remains in their earned rewards history

### Story 6.3: Display Mystery Rewards to Child with Progress

As a user,
I want to see mystery rewards with progress bars showing how many points I need,
So that I'm motivated to keep earning points toward the next surprise.

**Acceptance Criteria:**

**Given** parents have configured mystery rewards
**When** I view the rewards screen (child view)
**Then** I see a list of mystery rewards sorted by point threshold (lowest first)

**And** each unrevealed reward displays:
  - "Mystery Reward #1" (title only, description hidden)
  - Point threshold: "1,000 points"
  - Progress bar showing current points / threshold points
  - "500 / 1,000 points (50%)"

**And** rewards I haven't earned yet show locked icon 🔒

**And** progress bar fills visually as I earn more points (FR83)

**Given** my total points reach the reward threshold
**When** I cross 1,000 points
**Then** instant notification appears: "Mystery reward unlocked! Ask your parents to reveal it." (FR38, FR60)

**And** reward icon changes from locked 🔒 to unlocked 🎁

**And** reward remains unrevealed (description still hidden) until parent reveals it

**And** notification is sent to parents: "Yisroel Meir earned Mystery Reward #1!" (FR63)

### Story 6.4: Reveal Mystery Rewards When Earned

As a parent,
I want to reveal mystery reward details when Yisroel Meir earns them,
So that I can surprise him with what he's earned through his hard work.

**Acceptance Criteria:**

**Given** Yisroel Meir has earned a mystery reward (points >= threshold)
**When** I receive the notification "Yisroel Meir earned Mystery Reward #1!"
**Then** I open parent mode and navigate to "Earned Rewards"

**And** I see reward listed with status "Ready to Reveal"

**When** I tap "Reveal Reward"
**Then** I see the full description: "Trip to the arcade"

**And** I call Yisroel Meir over and tap "Show to Child"

**Then** reward reveal animation plays (celebratory animation)

**And** full reward description is displayed to child: "You earned: Trip to the arcade! 🎉"

**And** reward is_revealed flag is set to true in database

**And** reward moves to "Revealed Rewards" list

**And** Yisroel Meir can view revealed rewards anytime in his rewards history

### Story 6.5: Bulk Mark Masechtas as Complete

As a parent,
I want to bulk mark entire masechtas as already completed during initial onboarding,
So that I can quickly set up prior progress without marking each Mishna individually.

**Acceptance Criteria:**

**Given** I am in parent mode during initial setup
**When** I navigate to "Bulk Mark Completed"
**Then** I see a list of all 63 masechtos organized by seder

**And** each masechta has a checkbox

**When** I select "Masechta Berachos" and tap "Mark as Completed"
**Then** confirmation dialog appears: "This will mark all X Mishnayos in Berachos as completed for learning stage. Continue?"

**When** I confirm
**Then** completion records are created for all Mishnayos in Berachos with:
  - learning_stage='learning'
  - completed_at=current UTC timestamp
  - track_id='personal'
  - points_awarded=10 per Mishna

**And** all completion records are created within a single database transaction

**And** bulk operation completes within reasonable time (< 5 seconds for large masechta)

**And** success message: "Berachos marked complete (X Mishnayos)"

**And** progress percentage updates to reflect new completions

**And** points total increases by (X Mishnayos × 10 points)

**And** I can bulk mark multiple masechtos in a single session

### Story 6.6: View Parent Analytics Dashboard

As a parent,
I want to view an analytics dashboard showing on-track status, completion percentage, and streak,
So that I can monitor Yisroel Meir's progress with minimal time investment.

**Acceptance Criteria:**

**Given** I am in parent mode
**When** I view the analytics dashboard
**Then** I see key metrics displayed prominently:
  - Overall completion: "15% (630 of 4,192 Mishnayos)"
  - Current streak: "12 days"
  - Pace status: "3 days ahead of schedule ✓"
  - Total points: "6,300 points"
  - Projected completion: "November 15, 2028 (3 weeks before bar mitzvah)"

**And** completion breakdown by stage:
  - Learning: 630 Mishnayos (15%)
  - Chazara 1: 420 Mishnayos (67% of learned)
  - Chazara 2: 210 Mishnayos (33% of learned)

**And** completion breakdown by track:
  - Personal: 450 Mishnayos
  - School: 150 Mishnayos
  - Tutor: 30 Mishnayos

**And** line chart showing completions over time (last 30 days)

**And** all analytics load and render within 2 seconds (NFR1)

**And** dashboard is read-only (view only, no editing)

**And** I can access this dashboard in < 30 seconds for quick check-ins

### Story 6.7: Configure Point Values for Each Stage

As a parent,
I want to configure custom point values for learning, chazara 1, and chazara 2,
So that I can adjust the reward structure based on what motivates Yisroel Meir.

**Acceptance Criteria:**

**Given** I am in parent mode settings
**When** I navigate to "Points Configuration"
**Then** I see current point values:
  - Learning stage: 10 points (default)
  - Chazara 1: 5 points (default)
  - Chazara 2: 5 points (default)

**And** each value has an editable number field

**When** I change "Learning stage" to 15 points
**And** I tap "Save Changes"
**Then** new point value is stored in app settings

**And** all future completions use the new point values

**And** previously awarded points remain unchanged (historical data is immutable)

**And** confirmation message: "Point values updated. New completions will use these values."

**And** I can reset to defaults: "Reset to Default Values" button restores 10/5/5

**And** point values must be positive integers between 1 and 100

**And** validation error if I enter invalid values: "Point values must be between 1 and 100"

### Story 6.8: Parent Mode Track Management

As a parent,
I want to add or remove optional tracks (school/tutor) from parent mode,
So that I can manage Yisroel Meir's multi-context learning setup.

**Acceptance Criteria:**

**Given** I am in parent mode
**When** I navigate to "Track Management"
**Then** I see the same track management interface as Epic 3 Story 3.2

**And** I can add school track with "Add School Track" button

**And** I can remove school track with confirmation dialog

**And** I can add tutor track with "Add Tutor Track" button

**And** I can remove tutor track with confirmation dialog

**And** personal track cannot be removed (mandatory)

**And** all track management functionality from Epic 3 is accessible here

**And** changes take effect immediately throughout the app

## Epic 7: Tutor Mode & Progress Visibility

Tutor can view all progress and completion data (but not modify) through separate PIN-protected access, seeing completion logs, chazara queues, and progress breakdowns to align teaching sessions effectively.

### Story 7.1: Implement PIN-Protected Tutor Mode

As a tutor,
I want to access tutor mode with a separate 4-digit PIN from the parent PIN,
So that I can view Yisroel Meir's progress without editing capabilities.

**Acceptance Criteria:**

**Given** parents have set up the app
**When** parents navigate to "Tutor Access Setup" in parent mode
**Then** they can create a tutor PIN separate from parent PIN

**And** tutor PIN is hashed with bcrypt and stored separately from parent PIN in flutter_secure_storage (NFR29)

**Given** tutor PIN is configured
**When** tutor taps "Tutor Mode" button on main screen
**Then** PIN entry screen appears: "Enter Tutor PIN"

**When** tutor enters correct PIN
**Then** tutor is granted access to tutor mode dashboard (view-only)

**When** tutor enters incorrect PIN
**Then** error message: "Incorrect PIN. Try again."

**And** after 5 failed attempts, locked for 30 seconds (NFR30)

**And** tutor PIN is completely separate from parent PIN (can be different values)

**And** tutor mode has NO edit capabilities (FR76, NFR34)

**And** all buttons for editing, adding, or deleting are hidden in tutor mode

### Story 7.2: View Completion Log with Timestamps

As a tutor,
I want to see the completion log showing what Yisroel Meir completed and when,
So that I can understand his recent learning progress.

**Acceptance Criteria:**

**Given** I am in tutor mode
**When** I view "Completion Log"
**Then** I see a chronological list of all completions sorted by most recent first

**And** each entry displays:
  - Mishna reference (e.g., "Berachos 1:1")
  - Stage completed (Learning / Chazara 1 / Chazara 2)
  - Track (Personal / School / Tutor)
  - Completion date and time (formatted in local timezone)
  - Points awarded

**And** I can filter by date range (last 7 days, last 30 days, all time)

**And** I can filter by track (personal, school, tutor)

**And** I can filter by stage (learning, chazara 1, chazara 2)

**And** log displays up to 100 recent entries with pagination for more

**And** query completes within 100ms even with thousands of records (NFR3)

**And** all data is read-only (no edit buttons visible)

### Story 7.3: View Mishnayos Due for Chazara

As a tutor,
I want to see which Mishnayos are due for chazara 1 and chazara 2,
So that I can focus teaching sessions on review material.

**Acceptance Criteria:**

**Given** I am in tutor mode
**When** I navigate to "Chazara Queue"
**Then** I see two lists:
  - "Due for Chazara 1" (Mishnayos learned but not yet reviewed)
  - "Due for Chazara 2" (Mishnayos with chazara 1 complete but not chazara 2)

**And** each list shows Mishna reference, due date, and days overdue (if applicable)

**And** lists are sorted by due date (oldest/most overdue first)

**And** color coding:
  - Green: Due today
  - Yellow: 1-3 days overdue
  - Red: 4+ days overdue

**And** total count is displayed: "15 Mishnayos due for Chazara 1"

**And** I can tap a Mishna to view its full text (read-only)

**And** no "Mark Complete" buttons are visible (view-only mode)

**And** query completes within 100ms (NFR3)

### Story 7.4: View Progress Breakdowns by Seder and Masechta

As a tutor,
I want to view progress breakdowns by seder and masechta,
So that I can identify which areas need more focus during teaching.

**Acceptance Criteria:**

**Given** I am in tutor mode
**When** I view "Progress Overview"
**Then** I see overall completion percentage: "15% (630 of 4,192)"

**And** progress breakdown by seder:
  - Zeraim: 25% complete
  - Moed: 18% complete
  - Nashim: 10% complete
  - Nezikin: 5% complete
  - Kodashim: 2% complete
  - Taharot: 0% complete

**And** I can tap a seder to see masechta breakdown within that seder

**And** masechta breakdown shows:
  - Masechta name
  - Total Mishnayos in masechta
  - Completed Mishnayos
  - Completion percentage
  - Stage breakdown (how many learning, chazara 1, chazara 2 complete)

**And** visual progress bars for each masechta

**And** all data is read-only with no edit capabilities

**And** page loads within 2 seconds (NFR1)

### Story 7.5: View On-Track Status and Overall Metrics

As a tutor,
I want to see on-track status and overall progress metrics,
So that I can assess if Yisroel Meir is on pace for his bar mitzvah deadline.

**Acceptance Criteria:**

**Given** I am in tutor mode
**When** I view the dashboard
**Then** I see the same metrics as parent analytics dashboard:
  - Pace status: "3 days ahead of schedule ✓"
  - Current streak: "12 days"
  - Total points: "6,300"
  - Projected completion date: "November 15, 2028"

**And** completion breakdown by track (personal, school, tutor)

**And** line chart showing completions over time

**And** all analytics are read-only (no configuration or editing)

**And** no access to reward catalog (parent-only feature)

**And** no access to bulk operations (parent-only feature)

**And** no access to settings or configuration (view-only)

**And** dashboard loads within 2 seconds (NFR1)

## Epic 8: Onboarding & Initial Setup

New users complete personalized first-time setup including bar mitzvah date configuration, name entry, and learning order preferences, creating a tailored experience for their 3-year journey.

### Story 8.1: Create Onboarding Flow with Welcome Screen

As a new user,
I want to see a welcoming onboarding flow when I first open the app,
So that I understand what the app is for and feel excited to start.

**Acceptance Criteria:**

**Given** the app is opened for the first time (no user data exists)
**When** the app launches
**Then** welcome screen is displayed with:
  - App name: "Mishnayos Tracker"
  - Tagline: "Complete Shas Mishnayos by Your Bar Mitzvah"
  - Welcome message: "Let's set up your personal learning journey!"
  - "Get Started" button

**And** Material Design 3 design with Hebrew-friendly RTL support

**When** I tap "Get Started"
**Then** I proceed to personalization screen (Story 8.2)

**And** onboarding flow only appears once (first launch)

**And** after setup completion, onboarding is marked complete in local storage

**And** future app launches skip onboarding and go directly to dashboard

### Story 8.2: Personalize with Name and Bar Mitzvah Date

As a new user,
I want to enter my name and bar mitzvah date during setup,
So that the app is personalized for my specific journey.

**Acceptance Criteria:**

**Given** I am on the personalization screen in onboarding
**When** the screen loads
**Then** I see form fields:
  - "Your Name" (text input, placeholder: "Yisroel Meir")
  - "Bar Mitzvah Date" (date picker)

**And** Hebrew calendar date picker is available using kosher_dart integration

**And** I can select date in Hebrew calendar (e.g., "19 Kislev 5789")

**And** Gregorian equivalent is shown (e.g., "December 7, 2028")

**When** I enter name "Yisroel Meir Niasoff"
**And** I select bar mitzvah date "19 Kislev 5789"
**And** I tap "Next"
**Then** personalization is saved to user_settings table

**And** validation ensures name is not empty

**And** validation ensures bar mitzvah date is in the future

**And** error messages display if validation fails

**And** I proceed to learning order configuration (Story 8.3)

### Story 8.3: Configure Learning Order Preferences

As a new user,
I want to configure the order in which I'll learn masechtos,
So that the app's recommendations follow my preferred learning sequence.

**Acceptance Criteria:**

**Given** I am on the learning order screen in onboarding
**When** the screen loads
**Then** I see options for learning order:
  - "Standard Order" (Zeraim → Moed → Nashim → Nezikin → Kodashim → Taharot)
  - "Custom Order" (drag-and-drop to reorder sedarim)

**And** default is "Standard Order" pre-selected

**When** I select "Standard Order" and tap "Next"
**Then** learning order is saved as default sequence

**Given** I select "Custom Order"
**When** I drag "Moed" to first position
**Then** learning order is updated: Moed → Zeraim → Nashim → Nezikin → Kodashim → Taharot

**And** personal track bookmark will start from first Mishna of first seder in custom order

**And** I can reorder all 6 sedarim by dragging

**When** I tap "Next"
**Then** custom order is saved to user_settings

**And** I proceed to parent PIN setup (Story 8.4)

### Story 8.4: Set Up Parent PIN During Onboarding

As a parent,
I want to create the parent PIN during initial setup,
So that parent mode is secured from the start.

**Acceptance Criteria:**

**Given** I am on the parent PIN setup screen in onboarding
**When** the screen loads
**Then** I see message: "Create a 4-digit PIN for parent access"

**And** numeric keypad (0-9) is displayed

**When** I enter 4 digits (e.g., 1-2-3-4)
**Then** PIN entry masks digits as dots (••••)

**And** "Confirm PIN" screen appears

**When** I re-enter the same PIN
**Then** PIN is hashed with bcrypt and stored in flutter_secure_storage

**And** success message: "Parent PIN created successfully"

**When** I enter a different PIN on confirmation
**Then** error message: "PINs don't match. Try again."

**And** I am returned to initial PIN entry

**When** PIN is successfully created
**Then** I proceed to final setup screen (Story 8.5)

### Story 8.5: Complete Onboarding and Navigate to Dashboard

As a user,
I want to complete onboarding and see my personalized dashboard,
So that I can immediately start using the app.

**Acceptance Criteria:**

**Given** I have completed all onboarding steps (name, date, learning order, parent PIN)
**When** I reach the completion screen
**Then** I see congratulatory message: "You're all set, Yisroel Meir! Let's start your journey to complete Shas Mishnayos."

**And** summary of configuration:
  - Name: Yisroel Meir Niasoff
  - Bar Mitzvah: 19 Kislev 5789 (December 7, 2028)
  - Days until bar mitzvah: X days
  - Learning order: Standard / Custom

**When** I tap "Start Learning"
**Then** onboarding is marked complete in local storage

**And** I am navigated to the main dashboard

**And** dashboard displays personalized greeting: "Welcome, Yisroel Meir!"

**And** "Today's Tasks" section shows initial daily recommendations

**And** progress shows 0% (no completions yet)

**And** all app features are now accessible

**And** future app launches go directly to dashboard, bypassing onboarding

## Epic 9: Progress Visualization & Analytics

Users can visualize progress across multiple dimensions (by seder, masechta, perek) with enhanced charts and historical trends, providing comprehensive insights into learning patterns over time.

### Story 9.1: Display Progress Breakdown by Seder

As a user,
I want to see my progress broken down by seder,
So that I can understand which sections of Shas I've completed.

**Acceptance Criteria:**

**Given** I have completed Mishnayos across various sedarim
**When** I navigate to "Progress by Seder"
**Then** I see all 6 sedarim listed with progress for each:
  - Zeraim: 120/653 Mishnayos (18%)
  - Moed: 95/391 Mishnayos (24%)
  - Nashim: 45/315 Mishnayos (14%)
  - Nezikin: 30/685 Mishnayos (4%)
  - Kodashim: 10/578 Mishnayos (2%)
  - Taharot: 0/1570 Mishnayos (0%)

**And** visual progress bar for each seder showing completion percentage

**And** total across all sedarim: 300/4,192 (7%)

**And** I can tap a seder to drill down to masechta breakdown

**And** progress bars are color-coded (green for high completion, yellow for medium, gray for low)

**And** query completes within 100ms (NFR3)

### Story 9.2: Display Progress Breakdown by Masechta

As a user,
I want to see my progress broken down by masechta within each seder,
So that I can track completion of individual tractates.

**Acceptance Criteria:**

**Given** I tapped "Seder Zeraim" from the seder breakdown
**When** the masechta breakdown loads
**Then** I see all masechtos within Zeraim with their progress:
  - Berachos: 45/57 Mishnayos (79%)
  - Peah: 12/75 Mishnayos (16%)
  - Demai: 0/73 Mishnayos (0%)
  - [... all masechtos in Zeraim]

**And** progress bar for each masechta

**And** masechtos are sorted by completion percentage (highest first) with option to sort alphabetically

**And** completed masechtos (100%) are highlighted with checkmark ✓

**And** I can tap a masechta to drill down to perek breakdown

**And** breadcrumb navigation shows: "Zeraim > Masechtos"

**And** back button returns to seder breakdown

### Story 9.3: Display Progress Breakdown by Perek

As a user,
I want to see my progress broken down by perek within each masechta,
So that I can track completion at the chapter level.

**Acceptance Criteria:**

**Given** I tapped "Masechta Berachos" from the masechta breakdown
**When** the perek breakdown loads
**Then** I see all perakim within Berachos with their progress:
  - Perek 1: 5/5 Mishnayos (100%) ✓
  - Perek 2: 8/8 Mishnayos (100%) ✓
  - Perek 3: 6/6 Mishnayos (100%) ✓
  - Perek 4: 7/7 Mishnayos (100%) ✓
  - Perek 5: 5/5 Mishnayos (100%) ✓
  - Perek 6: 8/8 Mishnayos (100%) ✓
  - Perek 7: 4/5 Mishnayos (80%)
  - Perek 8: 2/8 Mishnayos (25%)
  - Perek 9: 0/5 Mishnayos (0%)

**And** progress bar for each perek

**And** completed perakim (100%) are marked with checkmark ✓

**And** I can tap a perek to view individual Mishnayos within it

**And** breadcrumb shows: "Zeraim > Berachos > Perakim"

**And** back navigation works correctly

### Story 9.4: Display Completion History Over Time with Charts

As a user,
I want to see my completion history over time with charts and trends,
So that I can visualize my learning patterns and momentum.

**Acceptance Criteria:**

**Given** I have completed Mishnayos over weeks and months
**When** I navigate to "Completion History"
**Then** I see a line chart with:
  - X-axis: Date (daily increments)
  - Y-axis: Cumulative completions

**And** chart shows upward trend as completions accumulate over time

**And** I can select time ranges: 7 days, 30 days, 90 days, all time

**And** daily completion count is shown as bar chart beneath line chart

**And** I can see peak days (days with most completions) highlighted

**And** average daily completions displayed: "Average: 12 Mishnayos/day"

**And** chart is interactive: tap a date to see detailed completions for that day

**And** chart renders smoothly at 60fps (NFR5)

**And** chart data loads within 500ms (NFR2)

### Story 9.5: Display Points Earned Over Time Chart

As a user,
I want to see a chart of points earned over time,
So that I can visualize my learning effort and see my points grow.

**Acceptance Criteria:**

**Given** I have earned points through completions
**When** I navigate to "Points History"
**Then** I see a line chart showing cumulative points over time

**And** X-axis: Date, Y-axis: Total points

**And** chart shows steady upward trend

**And** I can select time ranges: 7 days, 30 days, 90 days, all time

**And** daily points earned shown as bar chart: how many points earned each day

**And** breakdown by stage:
  - Learning stage points (stacked bar, darker color)
  - Chazara 1 points (stacked bar, medium color)
  - Chazara 2 points (stacked bar, lighter color)

**And** milestone markers on chart when mystery rewards are earned

**And** chart is interactive and renders at 60fps (NFR5)

**And** points projection line shows: "At current pace, you'll reach 10,000 points by [date]"

## Epic 10: Notification & Reminder System

Users receive timely local notifications including daily learning reminders, streak protection alerts, and instant reward milestone notifications, with independent control over notification types and timing.

### Story 10.1: Configure Daily Learning Reminder Notification

As a user,
I want to receive a daily reminder notification at a configurable time,
So that I'm reminded to learn and maintain my daily habit.

**Acceptance Criteria:**

**Given** the app is installed and onboarding is complete
**When** I navigate to "Notification Settings"
**Then** I see "Daily Learning Reminder" toggle (enabled by default)

**And** default notification time is 7:00 PM local time

**And** I can tap "Notification Time" to open time picker

**When** I select a new time (e.g., 6:00 PM)
**And** I tap "Save"
**Then** daily reminder is scheduled for 6:00 PM using flutter_local_notifications

**And** confirmation message: "Daily reminder set for 6:00 PM"

**Given** it's 6:00 PM and I haven't used the app today
**When** the scheduled time arrives
**Then** local notification is triggered with:
  - Title: "Time to learn!"
  - Body: "You have X tasks today. Let's keep your streak going!"
  - Sound and vibration (if enabled)

**And** tapping notification opens app to daily tasks screen

**And** notification respects Android 13+ runtime permission (graceful degradation if denied)

### Story 10.2: Implement Streak Protection Alert

As a user,
I want to receive a notification at 9 PM if I haven't used the app and I have an active streak,
So that I don't accidentally break a valuable streak.

**Acceptance Criteria:**

**Given** I have an active streak of 5+ days
**And** I haven't opened the app today
**When** the time reaches 9:00 PM local time
**Then** streak protection notification is triggered:
  - Title: "Don't break your streak! 🔥"
  - Body: "You have a 7-day streak. Open the app to keep it going!"

**And** tapping notification opens app to daily tasks screen

**Given** I already used the app today (completed at least one task)
**When** 9:00 PM arrives
**Then** no streak protection notification is sent

**Given** my streak is 0-4 days
**When** 9:00 PM arrives
**Then** no streak protection notification is sent (only protects 5+ day streaks)

**And** streak protection can be disabled independently in notification settings

**And** notification works correctly even if app is closed/killed

### Story 10.3: Send Instant Reward Milestone Notification

As a user,
I want to receive an instant notification when I earn a mystery reward,
So that I know immediately when I've hit a milestone and can ask my parents to reveal it.

**Acceptance Criteria:**

**Given** I have 995 points and a mystery reward threshold is 1,000 points
**When** I complete a Mishna and cross 1,000 points
**Then** instant notification is triggered immediately:
  - Title: "Mystery Reward Unlocked! 🎁"
  - Body: "You earned a mystery reward! Ask your parents to reveal it."

**And** notification is sent in real-time (within 1 second of crossing threshold)

**And** tapping notification opens app to rewards screen showing unlocked reward

**And** notification includes sound and vibration for excitement

**And** if multiple rewards are earned simultaneously (unlikely but possible), separate notification for each

**And** notification persists in notification tray until tapped or dismissed

### Story 10.4: Send Parent Notification for Reward Milestones

As a parent,
I want to receive a notification when Yisroel Meir earns a mystery reward,
So that I know when it's time to reveal the surprise.

**Acceptance Criteria:**

**Given** Yisroel Meir crosses a reward point threshold
**When** the reward milestone notification is triggered
**Then** a separate parent notification is sent:
  - Title: "Reward Earned!"
  - Body: "Yisroel Meir earned Mystery Reward #1. Open parent mode to reveal."

**And** tapping notification opens app with parent PIN prompt

**And** after PIN entry, navigates to "Earned Rewards" screen in parent mode

**And** parent can see which reward was earned and tap to reveal

**And** notification is sent to same device (v1.0 is single-device)

**And** parent notification setting can be toggled independently in parent mode settings

### Story 10.5: Enable/Disable Notification Types Independently

As a user,
I want to independently enable or disable each notification type,
So that I can control which notifications I receive.

**Acceptance Criteria:**

**Given** I am in "Notification Settings"
**When** the screen loads
**Then** I see toggles for each notification type:
  - Daily Learning Reminder (default: ON)
  - Streak Protection Alert (default: ON)
  - Reward Milestone Notifications (default: ON)

**And** each toggle can be independently enabled/disabled

**When** I disable "Daily Learning Reminder"
**Then** daily 7 PM notification is cancelled and won't trigger

**And** other notification types continue to work normally

**When** I disable "Streak Protection Alert"
**Then** 9 PM streak protection is cancelled

**And** daily reminder and reward notifications still work

**And** toggle states persist through app restarts

**And** notification settings are stored in user_settings table

**And** all notifications gracefully handle missing Android notification permission (show in-app message instead)

### Story 10.6: Configure Notification Times

As a user,
I want to configure the times for daily reminder and streak protection notifications,
So that they align with my daily schedule.

**Acceptance Criteria:**

**Given** I am in "Notification Settings"
**When** I view notification time settings
**Then** I see:
  - "Daily Reminder Time" (default: 7:00 PM)
  - "Streak Protection Time" (default: 9:00 PM)

**And** each has a time picker

**When** I tap "Daily Reminder Time"
**Then** time picker opens with current value selected

**When** I select 5:30 PM and tap "Save"
**Then** daily reminder is rescheduled for 5:30 PM

**And** success message: "Daily reminder updated to 5:30 PM"

**When** I tap "Streak Protection Time"
**And** I select 8:00 PM
**Then** streak protection is rescheduled for 8:00 PM

**And** validation ensures streak protection time is after daily reminder time

**And** error message if invalid: "Streak protection must be later than daily reminder"

**And** notification times persist through app restarts

**And** timezone changes are handled correctly (notifications adjust to local time)

## Epic 11: Cloud Sync & Data Management

Progress is automatically backed up to Firebase Cloud Firestore with background delta sync, conflict resolution, and exponential backoff retry, plus data export/import capabilities for manual backup and device transfer.

### Story 11.1: Implement Background Delta Sync to Firebase

As a developer,
I want background delta sync that uploads local completions to Firebase when online,
So that progress is automatically backed up to the cloud without blocking the user.

**Acceptance Criteria:**

**Given** the app is online and user has completed new Mishnayos
**When** background sync runs (triggered automatically every 5 minutes or on network state change)
**Then** all completion records with sync_status='pending' are uploaded to Firestore

**And** sync operates battery-efficiently without blocking user actions (NFR25)

**And** completion records are uploaded to `users/{userId}/mishnaCompletions/{completionId}` collection

**And** after successful upload, local record sync_status is updated to 'synced'

**And** sync uses exponential backoff retry on failure (max 5 retries) (NFR19)

**And** retry delays: 5s, 10s, 20s, 40s, 80s

**And** network errors don't cause app crashes (NFR17)

**And** sync runs in background without UI blocking

**And** sync respects Android battery saver mode (defers non-critical sync) (NFR27)

**And** Firebase quota limits are monitored with graceful degradation if exceeded (NFR21)

### Story 11.2: Resume Interrupted Sync from Checkpoint

As a user,
I want sync to resume from the last checkpoint if it's interrupted,
So that I don't lose progress if network fails during first-launch sync.

**Acceptance Criteria:**

**Given** first-launch sync is in progress seeding 4,192 Mishnayos
**When** network connection is lost at Mishna #2,000
**Then** current progress is saved to sync_checkpoints table with checkpoint_position=2000

**And** sync gracefully stops without errors

**Given** sync was interrupted at checkpoint 2,000
**When** network connection is restored and app relaunches
**Then** sync resumes from Mishna #2,001 (not starting over from #1)

**And** progress indicator shows: "Resuming sync: 48% complete (2,000/4,192)"

**And** sync continues until all 4,192 Mishnayos are downloaded

**And** checkpoint is updated every 100 Mishnayos during sync

**And** sync completion is marked in sync_checkpoints table with status='complete'

**And** subsequent app launches skip first-launch sync

**And** resume capability works for first-launch sync (NFR18)

### Story 11.3: Resolve Sync Conflicts with Last-Write-Wins

As a developer,
I want sync conflicts resolved using last-write-wins with UTC timestamps,
So that the most recent data is preserved when conflicts occur.

**Acceptance Criteria:**

**Given** a completion record exists locally with completed_at=2026-01-05T10:00:00Z
**And** the same completion record exists in Firestore with completed_at=2026-01-05T10:05:00Z (5 minutes later)
**When** sync runs and detects a conflict
**Then** the Firestore version (later timestamp) overwrites the local version

**And** conflict resolution uses UTC timestamps for comparison (NFR20)

**Given** local version has later timestamp than Firestore
**When** sync runs
**Then** local version is uploaded to Firestore, overwriting the older cloud version

**And** all DateTime comparisons use UTC (no timezone issues)

**And** conflict resolution logs are written via talker for debugging

**And** user data integrity is maintained (no data loss during conflict resolution)

**And** immutable completion records can't be modified, only latest version is kept

### Story 11.4: Retry Failed Syncs with Exponential Backoff

As a developer,
I want failed sync operations to retry with exponential backoff,
So that temporary network issues don't permanently prevent cloud backup.

**Acceptance Criteria:**

**Given** a sync operation fails due to network timeout
**When** the sync manager detects the failure
**Then** first retry is scheduled for 5 seconds later

**And** if first retry fails, second retry is scheduled for 10 seconds later

**And** if second retry fails, third retry is scheduled for 20 seconds later

**And** retry delays follow exponential backoff: 5s, 10s, 20s, 40s, 80s

**And** maximum of 5 retry attempts (NFR19)

**And** after 5 failed retries, sync is marked as failed and logged via talker

**And** failed sync can be retried manually via "Retry Sync" button in settings

**And** exponential backoff prevents network flooding

**And** successful retry on any attempt stops further retries and marks record as synced

**And** battery impact is minimized (< 2% daily) (NFR8)

### Story 11.5: Export Progress Data to JSON

As a user,
I want to export my progress data to a JSON file,
So that I can create a manual backup and transfer data to a new device if needed.

**Acceptance Criteria:**

**Given** I have completed various Mishnayos with progress data
**When** I navigate to "Data Management" in settings
**And** I tap "Export Data"
**Then** all local data is exported to JSON file including:
  - User settings (name, bar mitzvah date, etc.)
  - All completion records (completions table)
  - Track configuration (tracks, track_bookmarks, mishna_track_assignments)
  - Points and streak data
  - Reward catalog and earned rewards

**And** JSON file is named: `mishnayos_tracker_backup_YYYY-MM-DD.json`

**And** file is saved to device Downloads folder

**And** success message: "Data exported to Downloads/mishnayos_tracker_backup_2026-01-05.json"

**And** exported JSON is well-formatted and human-readable

**And** sensitive data (PINs) are NOT included in export (security)

**And** export completes within 10 seconds even with thousands of records

### Story 11.6: Import Progress Data from JSON

As a user,
I want to import progress data from a JSON backup file,
So that I can restore my data on a new device or recover from data loss.

**Acceptance Criteria:**

**Given** I have a JSON backup file from export
**When** I navigate to "Data Management" in settings
**And** I tap "Import Data"
**Then** file picker opens allowing me to select a JSON backup file

**When** I select a valid backup file
**Then** confirmation dialog appears: "This will replace all current data. Continue?"

**When** I confirm
**Then** all data from JSON is imported into local database:
  - User settings restored
  - Completion records restored
  - Track configuration restored
  - Points and streaks recalculated from imported data

**And** import operation uses database transaction (all-or-nothing) (NFR13)

**And** if import fails, rollback occurs and original data is preserved

**And** success message: "Data imported successfully. X Mishnayos restored."

**And** app restarts or refreshes to show imported data

**And** after import, background sync uploads imported data to Firebase

**And** validation ensures JSON file is correctly formatted before import

**And** error message if invalid file: "Invalid backup file format"

### Story 11.7: Automatic Network State Monitoring

As a developer,
I want network state changes to trigger sync automatically when connectivity is restored,
So that data is backed up as soon as possible without user intervention.

**Acceptance Criteria:**

**Given** the app is offline and user completes several Mishnayos
**When** network connectivity is restored
**Then** connectivity_plus detects the state change

**And** background sync is automatically triggered within 5 seconds

**And** pending completions are uploaded to Firebase

**And** sync status indicator shows "Syncing..." briefly

**And** after successful sync, indicator shows "✓ Synced"

**Given** network is lost during active sync
**When** connectivity is lost
**Then** sync pauses gracefully and saves checkpoint

**And** no app crashes or data corruption (NFR17)

**And** user continues working offline seamlessly

**And** when network returns, sync resumes from checkpoint

**And** network state monitoring respects battery saver mode (NFR27)
