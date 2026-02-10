---
title: 'Learning Tracker - Complete v1.0 Implementation'
slug: 'mishnayos-tracker-v1-complete'
created: '2026-01-03'
updated: '2026-01-03 (3 BLOCKING issues resolved: N1-Mishna count, N2-Immutability, N3-Scheduler math)'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4, 'adversarial-review-1', 'adversarial-review-2', 'blocking-issues-resolved']
tech_stack:
  - Flutter/Dart (latest stable)
  - Material Design 3
  - Riverpod 2.0+ (state management)
  - drift + drift_dev + sqlite3_flutter_libs (SQLite)
  - firebase_core + firebase_auth + cloud_firestore
  - flutter_secure_storage (encrypted PIN storage)
  - connectivity_plus (network state detection)
  - kosher_dart (Hebrew calendar)
  - bcrypt (PIN hashing)
  - http (Sefaria API seeding)
  - flutter_local_notifications (daily reminders)
files_to_modify:
  - All new files (greenfield project)
code_patterns:
  - Feature-first organization (features/tracking, features/scheduler, etc.)
  - Layered architecture (data/domain/application/presentation per feature)
  - Riverpod providers for state management
  - Drift type-safe database with generated DAOs
  - Offline-first with background delta sync
test_patterns:
  - Unit tests with flutter_test
  - Widget tests for UI components
  - Integration tests with integration_test package
  - Mock repositories with mockito
---

# Tech-Spec: Learning Tracker - Complete v1.0 Implementation

**Created:** 2026-01-03

## Overview

### Problem Statement

Build a complete Android app from scratch to help Yisroel Meir Niasoff (10 years old) complete all Mishnayos of Shas (exact count: 4,192 Mishnayos per standard Sefaria count) by his bar mitzvah on 19 Kislev, 5789 (December 7, 2028). Currently there is no tracking system, leading to inconsistent learning, no visible progress, and an overwhelming goal that feels impossible. The app must track the complete 3-stage learning cycle (initial learning + chazara next day + chazara 2 after 7 days), provide intelligent daily scheduling that adapts to his pace, visualize progress to make 4,192 feel achievable, maintain motivation through balanced gamification, and support parent/tutor oversight - all while establishing a daily habit that lasts the entire 3-year journey.

### Solution

Full-stack Flutter/Firebase Android application with offline-first architecture:

**Core Tracking System:**
- Pre-seeded Firebase Firestore database containing all 4,192 Mishnayos with text from Sefaria API
- Firebase Anonymous Authentication with Firestore security rules restricting access
- SQLite local database synced on startup for offline-first operation
- 3-stage learning cycle tracking with immutable progress enforced via completion log pattern
- Delta sync with last-write-wins conflict resolution using UTC timestamps
- Resumable first-launch sync with checkpoint tracking

**Intelligence & Visualization:**
- Smart adaptive scheduler with mathematically validated algorithm accounting for 9-day learning pipeline (day 1: learn, day 2: chazara1, day 9: chazara2)
- Daily recommendations balance new learning with chazara queue to complete all 4,192 Mishnayos × 3 stages = 12,576 total completions by bar mitzvah
- Multi-view progress dashboard with Hebrew calendar integration (19 Kislev, 5789 primary)
- Automatic chazara scheduling using Gregorian calendar days with UTC storage

**Engagement & Access:**
- Balanced gamification system (points, mystery rewards, Gregorian calendar streak tracking)
- Encrypted PIN-protected parent mode using flutter_secure_storage (reward management, analytics)
- Separate encrypted PIN-protected tutor mode (view-only progress tracking)
- Local scheduled notifications for daily learning reminders (no cloud messaging)

**Personalization:**
- Hardcoded for Yisroel Meir Niasoff with his specific bar mitzvah date
- Hebrew calendar throughout app
- Built as father-son project for this specific journey

### Scope

**In Scope:**

Implementation broken into 4 phases covering all v1.0 features:

**Phase 1 - Foundation (Project Setup & Database):**
- Flutter project initialization with proper structure
- Database schema design (SQLite + Firestore)
- Core domain models (Mishna, LearningProgress, etc.)
- Admin seeding script (Sefaria → Firebase)
- Basic app shell and navigation framework
- Firebase project setup

**Phase 2 - Core Tracking (Learning Cycle):**
- 3-stage learning cycle implementation
- First-launch bulk sync (Firebase → SQLite)
- Mishna browsing and text display
- Mark completion UI and logic
- Immutable progress enforcement
- Basic delta sync (SQLite ↔ Firebase)

**Phase 3 - Intelligence Layer (Scheduler & Progress):**
- Smart adaptive scheduler algorithm
- Daily recommendation engine
- Chazara auto-scheduling and queue management
- Progress dashboard (multiple views)
- Hebrew calendar integration
- On-track status calculations

**Phase 4 - Engagement & Access (Gamification & Modes):**
- Points and rewards system
- Streak tracking
- Parent mode (PIN, reward management, analytics)
- Tutor mode (PIN, view-only)
- Push notifications
- Completion animations and feedback
- Final polish and testing

**Out of Scope:**
- Multi-user support for other families (v1.0 is single-user, hardcoded)
- iOS version (Android only)
- Hebrew language UI (English interface with Hebrew content)
- Social features, leaderboards, community sharing
- Audio playback of Mishnayos
- Study notes or annotations
- Sefaria content versioning or update mechanism
- Advanced analytics beyond basic parent dashboard

## Context for Development

### Codebase Patterns

**Greenfield Project - Feature-First Architecture with Layered Design**

This is a brand new Flutter project following Riverpod best practices with feature-first organization and clean architecture layers.

**Project Structure:**
```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart        # Hardcoded: Yisroel Meir, bar mitzvah date
│   │   ├── point_values.dart         # Points per learning stage
│   │   └── shas_structure.dart       # 6 sedarim, masechtos, counts
│   ├── database/
│   │   ├── drift_database.dart       # Drift database definition
│   │   ├── drift_database.g.dart     # Generated code
│   │   └── tables/                   # Drift table definitions
│   ├── models/
│   │   ├── mishna.dart
│   │   ├── learning_progress.dart
│   │   ├── reward.dart
│   │   └── daily_recommendation.dart
│   └── utils/
│       ├── hebrew_date_utils.dart
│       └── sync_manager.dart
│
├── features/
│   ├── tracking/                     # 3-stage learning cycle
│   │   ├── data/                     # Repositories, data sources
│   │   ├── domain/                   # Entities, use cases
│   │   ├── application/              # Riverpod providers
│   │   └── presentation/             # Screens, widgets
│   ├── scheduler/                    # Smart daily recommendations
│   ├── progress/                     # Dashboard & visualizations
│   ├── rewards/                      # Points & gamification
│   ├── parent_mode/                  # PIN-protected parent features
│   └── tutor_mode/                   # PIN-protected tutor view
│
├── services/
│   ├── firebase_service.dart         # Firestore sync
│   ├── sefaria_service.dart          # Admin seeding only
│   ├── notification_service.dart     # Push notifications
│   └── auth_service.dart             # Firebase Auth
│
└── main.dart
```

**Key Patterns:**
- **Feature Isolation:** Each feature is self-contained with its own data/domain/application/presentation layers
- **Riverpod Providers:** State management via providers, avoiding BuildContext dependency
- **Type-Safe Database:** Drift generates type-safe DAOs from table definitions
- **Offline-First:** All operations hit SQLite first, background sync to Firebase
- **Immutability:** Once learning stages marked complete, they're locked (business rule)

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `_bmad-output/planning-artifacts/product-brief-mishnayos-tracker-2026-01-03.md` | Complete product vision and user requirements |

### Technical Decisions

**Architecture:**
- **Offline-First:** SQLite is source of truth for daily usage, Firebase is cloud backup/sync
- **Pre-seeded Content:** All 4,192 Mishnayos downloaded from Sefaria API once, stored in Firebase before app launch
- **Delta Sync with Conflict Resolution:** Last-write-wins using UTC timestamps (lastModified field)
  - When syncing to Firebase, include lastModified timestamp
  - When receiving from Firebase, compare timestamps: if Firebase > SQLite, Firebase wins
  - Transaction boundaries prevent partial updates
- **Content Versioning:** Mishnas table includes contentVersion field (default: 1) to allow future corrections
- **Exact Count:** 4,192 Mishnayos total across all masechtos (verified against Sefaria index)

**Authentication & Security (F2):**
- **Firebase Anonymous Authentication:** App uses `signInAnonymously()` on first launch to create unique user ID
- **Firestore Security Rules:**
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      // Only authenticated users can read/write their own data
      match /{collection}/{document} {
        allow read, write: if request.auth != null;
      }
      // Mishnas collection is read-only for all auth users (pre-seeded content)
      match /mishnas/{mishna} {
        allow read: if request.auth != null;
        allow write: if false; // Prevent modification of content
      }
    }
  }
  ```
- **Admin Seeding:** Uses Firebase Admin SDK with service account credentials (not anonymous auth)
- **User Data Isolation:** All collections scoped by Firebase Auth UID (future multi-user support)

**State Management:**
- Riverpod 2.0+ for reactive state management
- Feature-specific providers (TrackingNotifier, SchedulerNotifier, ProgressNotifier, etc.)
- StreamProvider for real-time database updates
- FutureProvider for async initialization
- Error boundaries with AsyncError handling

**Database Schema (Drift SQLite + Firestore Mirror):**

**SQLite Tables:**
```dart
// mishnas - All 4,192 Mishnayos with text (F4)
@DataClassName('MishnaEntity')
class Mishnas extends Table {
  TextColumn get id => text()();                    // "berachos_1_1"
  TextColumn get seder => text()();                 // "Zeraim"
  IntColumn get sederOrder => integer()();          // 1-6
  TextColumn get masechta => text()();              // "Berachos"
  IntColumn get masechtaOrder => integer()();       // Order within seder
  IntColumn get perek => integer()();               // Chapter number
  IntColumn get mishnaNumber => integer()();        // Mishna number
  TextColumn get hebrewText => text()();            // From Sefaria
  TextColumn get englishText => text()();           // From Sefaria
  IntColumn get contentVersion => integer().withDefault(Constant(1))();  // F27 - versioning
  @override
  Set<Column> get primaryKey => {id};
}

// learning_progress - Tracks current state and scheduling (F1, F7)
@DataClassName('LearningProgressEntity')
class LearningProgress extends Table {
  TextColumn get mishnaId => text()();

  // Scheduled dates (mutable, used for algorithm calculations)
  DateTimeColumn get chazara1ScheduledDate => dateTime().nullable()();  // UTC, Gregorian day boundary
  DateTimeColumn get chazara2ScheduledDate => dateTime().nullable()();  // UTC, Gregorian day boundary

  BoolColumn get isSynced => boolean().withDefault(Constant(false))();
  DateTimeColumn get lastModified => dateTime()();  // UTC timestamp for conflict resolution (F1)

  @override
  Set<Column> get primaryKey => {mishnaId};
}

// completion_log - Immutable append-only record of all completions (F9)
// Database-level immutability: INSERT-only table, NO UPDATE or DELETE queries allowed
@DataClassName('CompletionLogEntity')
class CompletionLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mishnaId => text()();
  TextColumn get stage => text()();  // "learning", "chazara1", or "chazara2"
  DateTimeColumn get completedAt => dateTime()();  // UTC timestamp when marked complete

  BoolColumn get isSynced => boolean().withDefault(Constant(false))();
  DateTimeColumn get lastModified => dateTime()();  // UTC timestamp for conflict resolution

  @override
  Set<Column> get primaryKey => {id};

  // Prevent duplicate completions: unique constraint on (mishnaId, stage)
  @override
  List<Set<Column>> get uniqueKeys => [
    {mishnaId, stage}
  ];
}

// rewards - Parent-configured mystery rewards
@DataClassName('RewardEntity')
class Rewards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get pointsRequired => integer()();
  BoolColumn get isEarned => boolean().withDefault(Constant(false))();
  DateTimeColumn get earnedDate => dateTime().nullable()();
  BoolColumn get isRevealed => boolean().withDefault(Constant(false))();
  IntColumn get displayOrder => integer()();
}

// user_stats - Streak, points, etc.
@DataClassName('UserStatsEntity')
class UserStats extends Table {
  IntColumn get id => integer().withDefault(Constant(1))();  // Single row
  IntColumn get totalPoints => integer().withDefault(Constant(0))();
  IntColumn get currentStreak => integer().withDefault(Constant(0))();
  DateTimeColumn get lastLearningDate => dateTime().nullable()();
  IntColumn get longestStreak => integer().withDefault(Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// daily_recommendations - Scheduler output
@DataClassName('DailyRecommendationEntity')
class DailyRecommendations extends Table {
  DateTimeColumn get date => dateTime()();         // Hebrew date as Gregorian
  IntColumn get newLearningCount => integer()();
  IntColumn get chazara1Count => integer()();
  IntColumn get chazara2Count => integer()();
  TextColumn get status => text()();               // 'pending', 'in_progress', 'complete'
  @override
  Set<Column> get primaryKey => {date};
}

// app_config - Settings, PINs, etc.
@DataClassName('AppConfigEntity')
class AppConfig extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}
```

**Firestore Collections (mirrors SQLite structure):**
- `/mishnas/{mishna_id}` - Static content (read-only for app users)
- `/users/{uid}/learning_progress/{mishna_id}` - User-scoped tracking data (scheduled dates only)
- `/users/{uid}/completion_log/{completion_id}` - User-scoped immutable completion records
- `/users/{uid}/rewards/{reward_id}` - User-scoped rewards
- `/users/{uid}/user_stats/main` - User-scoped statistics
- `/users/{uid}/app_config/{key}` - User-scoped settings (excluding PINs)

**Scheduler Algorithm (F3):**

**Mathematical Model:**
- Total Mishnayos: 4,192
- Total stage completions needed: 4,192 × 3 = 12,576
- Timeline: 2026-01-03 to 2028-12-07 = 1,070 days
- Minimum pipeline duration: 9 days (day 1: learn, day 2: chazara1, day 9: chazara2)

**Pipeline Lag Calculation:**
- **Warmup period:** Days 1-9 (can't complete chazara2 until day 9)
  - Days 1-1: Only new learning possible (0 chazara1, 0 chazara2)
  - Days 2-8: New learning + chazara1 possible (0 chazara2)
  - Day 9+: All three stages operational (steady state)
- **Cooldown period:** Last 8 days (final new learning needs 8 more days for chazara2)
  - If last new learning happens on day 1,062, chazara2 completes on day 1,070
  - No new learning can start after day 1,062 and still finish by deadline

**Steady-State Daily Rate:**
```
Total stage completions = 12,576
Warmup period = 9 days
Cooldown period = 8 days
Usable days for new learning = 1,070 - 9 - 8 = 1,053 days
Daily rate = 12,576 / 1,053 = 11.94 ≈ 12 completions/day

Typical daily mix (during steady state, days 9-1,062):
- New learning: 4 Mishnayos/day
- Chazara 1: 4 Mishnayos/day (from yesterday's learning)
- Chazara 2: 4 Mishnayos/day (from 7 days ago chazara1)
= 12 total stage completions/day
```

**Adaptive Pacing:**
```
daysRemaining = barMitzvahDate - today

// Query completion_log to determine what's been completed
learningCompleted = SELECT DISTINCT mishnaId FROM completion_log WHERE stage = 'learning'
chazara1Completed = SELECT DISTINCT mishnaId FROM completion_log WHERE stage = 'chazara1'
chazara2Completed = SELECT DISTINCT mishnaId FROM completion_log WHERE stage = 'chazara2'

learningRemaining = 4192 - count(learningCompleted)

// Chazara due: completed previous stage but not current stage, and scheduled date has arrived
chazara1Due = count(
  SELECT lp.mishnaId
  FROM learning_progress lp
  WHERE lp.mishnaId IN learningCompleted
    AND lp.mishnaId NOT IN chazara1Completed
    AND lp.chazara1ScheduledDate <= today
)

chazara2Due = count(
  SELECT lp.mishnaId
  FROM learning_progress lp
  WHERE lp.mishnaId IN chazara1Completed
    AND lp.mishnaId NOT IN chazara2Completed
    AND lp.chazara2ScheduledDate <= today
)

recommendedNewLearning = ceil(learningRemaining / daysRemaining)
recommendedChazara1 = min(chazara1Due, daysRemaining availability)
recommendedChazara2 = min(chazara2Due, daysRemaining availability)

// Prevent chazara pile-up from overwhelming user
if (chazara1Due + chazara2Due > 10) {
  recommendedNewLearning = max(2, recommendedNewLearning - 2)  // Reduce new learning
}

// Ensure minimum progress
if (recommendedNewLearning + recommendedChazara1 + recommendedChazara2 < 8) {
  recommendedNewLearning = 4  // Minimum baseline
}

// Edge case guards (F3)
if (daysRemaining <= 0 || learningRemaining < 0) {
  // Deadline passed or already complete
  recommendedNewLearning = 0
}
```

**Chazara Scheduling Rules (F7):**
- **Calendar System:** Gregorian calendar days (midnight to midnight in device local time)
- **Storage:** All DateTime fields stored as UTC in database
- **Scheduling Logic:**
  ```
  When learning marked complete on date D (any time of day):
    chazara1ScheduledDate = UTC midnight of (D + 1 day)

  When chazara1 marked complete on date C1:
    chazara2ScheduledDate = UTC midnight of (C1 + 7 days)

  Example: Learn completed 2026-01-03 23:59 → chazara1 scheduled 2026-01-04 00:00 UTC
  ```
- **Timezone Handling:** Dates convert to local timezone for display only; comparisons always in UTC
- **Hebrew Calendar:** Used for display and bar mitzvah countdown, NOT for scheduling logic

**Resumable First-Launch Sync (F5):**
- **Checkpoint Tracking:** Store last successfully synced mishna_id in SharedPreferences key `sync_checkpoint`
- **Progress Indicator:** Show "Downloading X of 4,192 Mishnayos..." with progress bar
- **Chunked Download:** Batch Firestore queries in groups of 500 documents
- **Failure Recovery:**
  ```
  if (syncInterrupted) {
    lastSyncedId = SharedPreferences.getString('sync_checkpoint')
    resumeFromId = lastSyncedId ?? firstMishnaId
    continueDownload(resumeFromId)
  }
  ```
- **Completion Marker:** Set `has_fully_synced = true` only after ALL 4,192 Mishnayos downloaded
- **Retry Logic:** On failure, show "Retry" button; auto-retry after 5 seconds with exponential backoff

**Network Retry Strategy (F6):**
- **Package:** `connectivity_plus` for network state detection
- **Exponential Backoff:**
  ```
  attempt = 0
  maxRetries = 5
  baseDelay = 5 seconds

  while (attempt < maxRetries) {
    try {
      syncToFirebase()
      break  // Success
    } catch (e) {
      attempt++
      delay = baseDelay * (2 ^ attempt)  // 5s, 10s, 20s, 40s, 80s
      await Future.delayed(Duration(seconds: delay))
    }
  }
  ```
- **Network State Monitoring:**
  ```
  connectivity_plus.onConnectivityChanged.listen((result) {
    if (result != ConnectivityResult.none && hasPendingSync) {
      triggerBackgroundSync()
    }
  })
  ```
- **Firestore Rate Limits:** Free tier = 50k reads/day, 20k writes/day
  - Single user daily sync: ~10 writes/day (well within limits)
  - First launch: 4,192 reads (within daily limit)

**PIN Security (F8):**
- **Storage:** flutter_secure_storage (uses Android Keystore, hardware-backed encryption)
- **Never Sync PINs:** PINs are device-local only, NOT stored in Firestore or app_config table
- **Hashing:** PINs stored as bcrypt hashes, never plaintext
- **Implementation:**
  ```dart
  // Store PIN (first-time setup)
  final hashedPin = bcrypt.hashpw(plainPin, bcrypt.gensalt());
  await secureStorage.write(key: 'parent_pin_hash', value: hashedPin);

  // Verify PIN (login)
  final storedHash = await secureStorage.read(key: 'parent_pin_hash');
  final isValid = bcrypt.checkpw(enteredPin, storedHash);
  ```
- **Separate Keys:** `parent_pin_hash` and `tutor_pin_hash` stored independently

**Schema Migration Strategy (F10):**
- **Drift Schema Versioning:**
  ```dart
  @DriftDatabase(tables: [...], schemaVersion: 1)
  class AppDatabase extends _$AppDatabase {
    @override
    MigrationStrategy get migration => MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();  // v1 initial schema
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will go here
        // Example: v1 → v2 might add a new field like displayOrder to Rewards table
        if (from == 1 && to == 2) {
          // await m.addColumn(rewards, rewards.someNewField);
        }
      },
    );
  }
  ```
- **Firestore Migrations:** Add schema_version field to documents; handle version mismatch gracefully
- **Backward Compatibility:** Ensure old app versions can read (but not write) new schema
- **Testing:** Write migration tests in `test/database/migrations_test.dart`

**Data Flow:**
1. **Pre-seed (Admin):** Sefaria API → Firebase Firestore (one-time, 4,192 Mishnayos with rate limiting)
2. **First Launch:**
   - Firebase Anonymous Auth (signInAnonymously)
   - Resumable Firebase → SQLite sync (chunked, checkpointed)
   - Initialize empty learning_progress records
3. **Daily Use:** All CRUD operations on SQLite (offline-capable)
4. **Background Sync:**
   - Delta sync changed records (isSynced=false) SQLite → Firebase when online
   - Conflict resolution via lastModified timestamps
   - Network retry with exponential backoff
5. **New Device:**
   - Firebase Auth login (restore anonymous UID)
   - Full data restore Firebase → SQLite
   - Conflict detection if old device still in use

**Hebrew Calendar:**
- **Package:** `kosher_dart` (pub.dev/packages/kosher_dart)
- Provides JewishDate, JewishCalendar classes
- Hebrew date formatting in Hebrew and transliterated formats
- Gregorian ↔ Hebrew conversions
- Primary display: 19 Kislev, 5789
- Bar mitzvah countdown in Hebrew calendar

**Sefaria API Integration (F11, F12, F25):**
- **Endpoint:** `https://www.sefaria.org/api/texts/{reference}`
- **Response Structure:** JSON with `text` (English) and `he` (Hebrew) arrays
- **Path:** `Mishnah/{Seder}/{Masechta}` structure
- **Usage:** Admin seeding script only (not runtime API calls)
- **License:** CC-BY-SA - Attribution REQUIRED
  - Display in app: "Text powered by Sefaria.org" on Mishna detail screen
  - Credits in About screen with link to Sefaria
- **Rate Limiting (F11):**
  - Max 10 requests/second in seeding script
  - Exponential backoff on HTTP 429 responses
  - Checkpoint file tracks successfully uploaded Mishnayos (resumable)
- **Error Handling (F12):**
  ```dart
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // Validate structure
      if (!json.containsKey('he') || !json.containsKey('text')) {
        log('Missing text fields for $mishnaId');
        hebrewText = '[Missing from Sefaria]';
        englishText = '[Missing from Sefaria]';
      } else {
        hebrewText = json['he'] ?? '';
        englishText = json['text'] ?? '';
      }
    }
  } catch (e) {
    log('Sefaria API error: $e');
    // Store placeholder, flag for manual review
  }
  ```

**Hebrew Calendar (F13, F15):**
- **Package:** `kosher_dart` (pub.dev/packages/kosher_dart)
- **Validation:** Cross-check calculations against Hebcal.com for accuracy
- **Date Display:** Primary format = "19 Kislev 5789" (numeric, not transliterated)
- **Countdown:** Use Hebrew calendar for bar mitzvah countdown (days until 19 Kislev 5789)
- **Streak Tracking:** Uses Gregorian calendar days (NOT Hebrew) for simplicity and consistency
  - Documented clearly in app: "Daily streak tracks consecutive calendar days"
  - Hebrew day (sunset to sunset) NOT used to avoid complexity
- **Timezone:** All date calculations assume device local timezone, store as UTC

**Testing Strategy (F19):**

**Scope Definition:**
- **Business Logic (80%+ coverage required):**
  - `features/*/domain/usecases/*.dart` - ALL use cases
  - `features/scheduler/` - Complete scheduler algorithm with edge cases
  - `core/utils/hebrew_date_utils.dart` - All Hebrew date functions
  - `features/rewards/` - Points calculation, streak logic
  - `core/utils/sync_manager.dart` - Sync and conflict resolution logic

- **UI Code (Widget tests for critical components):**
  - Completion buttons (visibility based on stage)
  - Progress widgets (seder visualization)
  - PIN entry screens
  - Today's tasks screen

- **Integration Tests (End-to-end critical paths):**
  - Mark learning complete → verify chazara1 scheduled next day
  - Mark chazara1 complete → verify chazara2 scheduled 7 days later
  - Offline: mark complete → go online → verify synced to Firebase
  - First launch sync: download all 4,192 → verify SQLite populated

**Coverage Enforcement:**
- Run `flutter test --coverage` on every commit
- Fail CI/CD build if business logic coverage < 80%
- Generate HTML reports: `genhtml coverage/lcov.info -o coverage/html`

**Critical Test Cases (must be included):**
1. Scheduler with 0 Mishnayos complete (day 1 recommendations)
2. Scheduler at 50% complete (adaptive pacing)
3. Scheduler with chazara pile-up > 10 (reduces new learning)
4. Scheduler 1 week before bar mitzvah (catch-up mode)
5. Immutability: attempt to unmark completed stage (should fail)
6. Sync conflict: SQLite timestamp < Firebase timestamp (Firebase wins)
7. Resumable sync: interrupt at Mishna 2,000, resume from checkpoint
8. Hebrew date: Convert 19 Kislev 5789 → Gregorian Dec 7, 2028
9. Streak: Learn today after yesterday (increment), after 2 days ago (reset to 1)
10. PIN verification: correct PIN (success), wrong PIN (failure)

**Additional Technical Details:**

**Points & Rewards Balance (F14):**
- Default point values: Learning=10, Chazara1=5, Chazara2=5
- Total possible points: 4,192 × 20 = 83,840 points over 3 years
- **Reward Guidance for Parents:**
  - Recommend 5-10 major rewards total (every ~8,000-15,000 points)
  - Examples: 10k points (after ~500 Mishnayos), 25k points, 50k points, 75k points, completion bonus
  - Parent mode shows warning if rewards too dense (>15 rewards) or too sparse (<3 rewards)
- **Configurability:** Point values stored in app_config table, adjustable via parent mode
- **No Mishna difficulty weighting:** All Mishnayos worth same points (v1.0 simplicity)

**Firestore Usage Analysis (F16):**
- **Free Tier Limits:** 50k reads/day, 20k writes/day, 1 GB storage, 10 GB/month bandwidth
- **Estimated Usage (single user):**
  - First launch: 4,192 reads (mishnas collection) = 8.4% of daily limit
  - Daily sync: ~10-15 writes (learning_progress, user_stats, rewards) = 0.05% of daily limit
  - Storage: ~4,192 mishnas × 500 bytes avg = ~2 MB (0.2% of 1 GB limit)
- **Multi-user Scaling (future v2.0):**
  - 100 users: 1,500 writes/day (7.5% of limit) - still well within free tier
  - 1,000 users: 15,000 writes/day (75% of limit) - approaching quota
- **Quota Exceeded Handling:** Graceful degradation to offline-only mode with user notification

**Notification Strategy (F17):**
- **Local Notifications ONLY:** Use `flutter_local_notifications` for scheduled daily reminders
- **NO Firebase Cloud Messaging:** Remove `firebase_messaging` dependency (not needed for local notifications)
- **Implementation:**
  - Schedule daily notification at configured time (default 7:00 PM)
  - Notification payload: "Time to learn your Mishnayos! Keep your streak alive 🔥"
  - Android battery optimization: Request "ignore battery optimization" permission for reliable delivery
- **Configuration:** Parent mode allows changing notification time and message

**Error Handling & Crash Reporting (F18):**
- **Global Error Handlers:**
  ```dart
  void main() {
    FlutterError.onError = (details) {
      log('Flutter Error: ${details.exception}');
      // Consider Firebase Crashlytics in future
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      log('Platform Error: $error');
      return true;
    };

    runZonedGuarded(() => runApp(MyApp()), (error, stack) {
      log('Zoned Error: $error');
    });
  }
  ```
- **Database Transaction Rollback:** All Drift writes wrapped in transactions with automatic rollback on error
- **Network Error UI:** User-friendly messages ("Can't reach the cloud right now, your progress is saved locally")
- **Future:** Add Firebase Crashlytics for remote error monitoring (even for single-user, helps debugging)

**Multi-Device & Device Replacement (F20):**
- **Current Implementation (v1.0):**
  - Single active device assumed (10-year-old has one phone)
  - Device replacement: Manual data export (JSON) → import on new device
  - No simultaneous multi-device support
- **Device Migration Flow:**
  1. Parent mode → "Backup & Restore" → "Export Data" → Save JSON file
  2. Install app on new device
  3. Onboarding → "Restore from Backup" → Select JSON file
  4. All data imported, old device can be wiped
- **Firebase Auth UID:** Anonymous UID stored locally; re-authenticating on new device creates new UID (no automatic restore)
- **Future v2.0:** Implement proper multi-device sync with Firebase Auth email/password login

**Additional LOW Priority Items:**

**Hardcoded Values (F21):**
- Store in app_config table instead of constants files: bar mitzvah date, point values
- Allows parent mode adjustment without code changes
- Default values set during first-launch onboarding

**Accessibility (F22):**
- Semantic labels for screen readers (Semantic widget wrappers)
- Minimum touch target size: 48dp (Material Design 3 standard)
- Color contrast: WCAG AA compliant (4.5:1 for text)
- Dynamic font sizing support (MediaQuery.textScaleFactor)
- Test with TalkBack enabled

**App Icon & Branding (F23):**
- App icon: 1024×1024px, Torah/book/checkmark imagery, age-appropriate
- Splash screen: App name + "For Yisroel Meir Niasoff" + loading indicator
- Color scheme: Respectful blues/greens (not frivolous)

**Timezone Documentation (F24):**
- **Convention:** ALL DateTime fields stored as UTC in SQLite
- **Display:** Convert to local timezone only when rendering UI
- **Comparisons:** Always compare UTC timestamps
- **Edge Case:** User travels across timezones → dates remain consistent (UTC-based)

**Content Versioning (F27):**
- Mishnas table includes `contentVersion` field (default: 1)
- Parent mode: "Report Error" button on Mishna detail screen → flags for manual review
- Future: Manual refresh individual Mishna text from Sefaria API (parent mode feature)

**Performance Throughout Development (F26):**
- **Phase 1:** Define database indexes upfront (mishnaId, sederOrder, masechtaOrder)
- **Phase 2:** Lazy-load Mishna text in browser (don't load all 4,192 at once)
- **Phase 3:** Profile scheduler algorithm complexity (should be O(n) where n=4,192)
- **Phase 4:** Continuous profiling with Flutter DevTools, not just end-of-phase optimization

## Implementation Plan

### Overview

This comprehensive implementation is organized into 4 sequential phases. Each phase builds upon the previous one, delivering a complete working app by the end of Phase 4.

**Timeline:** Complete all phases before beginning development to ensure architectural consistency and proper dependencies.

---

### PHASE 1: Foundation (Project Setup & Database)

**Goal:** Establish project structure, database schema, and admin seeding capability

#### Tasks

- [ ] **Task 1.1: Initialize Flutter Project**
  - File: Command line
  - Action: Run `flutter create mishnayos_tracker --org com.niasoff --platforms android`
  - Action: Set up git repository and initial commit
  - Notes: Use package name `com.niasoff.mishnayos_tracker`

- [ ] **Task 1.2: Configure pubspec.yaml**
  - File: `pubspec.yaml`
  - Action: Add all dependencies from "Dependencies" section with specified versions
  - Action: Configure Flutter SDK constraints (>=3.0.0)
  - Notes: Include both dependencies and dev_dependencies

- [ ] **Task 1.3: Create Project Folder Structure**
  - Files: Create directories
  - Action: Create `lib/core/`, `lib/features/`, `lib/services/` directories
  - Action: Create feature subdirectories (tracking, scheduler, progress, rewards, parent_mode, tutor_mode)
  - Action: Create layer subdirectories within each feature (data, domain, application, presentation)
  - Notes: Follow structure documented in "Codebase Patterns"

- [ ] **Task 1.4: Define App Constants**
  - File: `lib/core/constants/app_constants.dart`
  - Action: Define `userName = "Yisroel Meir Niasoff"`
  - Action: Define `barMitzvahDate` as JewishDate(5789, HebrewMonth.KISLEV, 19)
  - Action: Define `barMitzvahDateGregorian = DateTime(2028, 12, 7)`
  - Notes: Hardcoded for v1.0, will be configurable in v2.0

- [ ] **Task 1.5: Define Point Values**
  - File: `lib/core/constants/point_values.dart`
  - Action: Define `learningPoints = 10`
  - Action: Define `chazara1Points = 5`
  - Action: Define `chazara2Points = 5`
  - Notes: Parent-configurable later via AppConfig table

- [ ] **Task 1.6: Define Shas Structure**
  - File: `lib/core/constants/shas_structure.dart`
  - Action: Define 6 sedarim with order numbers
  - Action: Define all masechtos with seder assignment and order
  - Action: Include accurate Mishna counts per masechta
  - Notes: Research exact Mishna counts from Sefaria or authoritative source

- [ ] **Task 1.7: Create Drift Database Schema - Tables**
  - File: `lib/core/database/tables/mishnas_table.dart`
  - Action: Define Mishnas table with all columns from schema
  - File: `lib/core/database/tables/learning_progress_table.dart`
  - Action: Define LearningProgress table (scheduled dates only, no completion flags)
  - File: `lib/core/database/tables/completion_log_table.dart`
  - Action: Define CompletionLog table (append-only, immutable records of all completions)
  - Action: Add unique constraint on (mishnaId, stage) to prevent duplicate completions
  - File: `lib/core/database/tables/rewards_table.dart`
  - Action: Define Rewards table
  - File: `lib/core/database/tables/user_stats_table.dart`
  - Action: Define UserStats table
  - File: `lib/core/database/tables/daily_recommendations_table.dart`
  - Action: Define DailyRecommendations table
  - File: `lib/core/database/tables/app_config_table.dart`
  - Action: Define AppConfig table
  - Notes: Follow exact schema documented in "Technical Decisions"

- [ ] **Task 1.8: Create Drift Database Definition**
  - File: `lib/core/database/drift_database.dart`
  - Action: Create @DriftDatabase annotation with all tables
  - Action: Define database class extending _$AppDatabase
  - Action: Implement schema version (schemaVersion = 1)
  - Action: Add migration strategy (no migrations needed for v1)
  - Notes: Will generate drift_database.g.dart via build_runner

- [ ] **Task 1.9: Generate Drift Code**
  - File: Command line
  - Action: Run `flutter pub run build_runner build --delete-conflicting-outputs`
  - Action: Verify drift_database.g.dart is generated
  - Notes: DAOs and queries will be auto-generated

- [ ] **Task 1.10: Create Domain Models**
  - File: `lib/core/models/mishna.dart`
  - Action: Create Mishna model class matching MishnaEntity structure
  - File: `lib/core/models/learning_progress.dart`
  - Action: Create LearningProgress model
  - File: `lib/core/models/reward.dart`
  - Action: Create Reward model
  - File: `lib/core/models/daily_recommendation.dart`
  - Action: Create DailyRecommendation model
  - Notes: Add factory constructors for entity conversions

- [ ] **Task 1.11: Set Up Firebase Project**
  - Action: Create Firebase project in console (https://console.firebase.google.com)
  - Action: Register Android app with package name `com.niasoff.mishnayos_tracker`
  - Action: Download `google-services.json` to `android/app/`
  - Action: Configure FlutterFire CLI: `flutterfire configure`
  - Notes: Enable Authentication, Firestore, and Cloud Messaging in Firebase console

- [ ] **Task 1.12: Initialize Firebase in App**
  - File: `lib/main.dart`
  - Action: Add Firebase initialization in main() before runApp()
  - Action: Use `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
  - Notes: Wrap main in async

- [ ] **Task 1.13: Create Firestore Data Models**
  - File: `lib/services/firebase_service.dart`
  - Action: Define Firestore collection references
  - Action: Create helper methods for entity-to-map conversions
  - Notes: Collections: mishnas, learning_progress, rewards, user_stats, app_config

- [ ] **Task 1.14: Create Admin Seeding Script**
  - File: `scripts/seed_sefaria_to_firebase.dart`
  - Action: Create standalone Dart script
  - Action: Implement Sefaria API fetching for all masechtos
  - Action: Parse JSON response (text and he arrays)
  - Action: Upload to Firestore /mishnas collection
  - Action: Add progress logging
  - Notes: Run once before app launch to populate Firebase

- [ ] **Task 1.15: Execute Admin Seeding**
  - File: Command line
  - Action: Run `dart scripts/seed_sefaria_to_firebase.dart`
  - Action: Verify exactly 4,192 documents created in Firestore (no approximation)
  - Action: Spot-check Hebrew and English text accuracy
  - Notes: This is a one-time operation

- [ ] **Task 1.16: Create Basic App Shell**
  - File: `lib/main.dart`
  - Action: Set up MaterialApp with Material Design 3
  - Action: Define initial route to splash/loading screen
  - File: `lib/features/splash/presentation/screens/splash_screen.dart`
  - Action: Create splash screen showing "Learning Tracker for Yisroel Meir"
  - Notes: Basic navigation setup, will expand in later phases

---

### PHASE 2: Core Tracking (Learning Cycle)

**Goal:** Implement 3-stage learning cycle, Mishna browsing, and basic Firebase sync

#### Tasks

- [ ] **Task 2.1: Create Tracking Data Layer**
  - File: `lib/features/tracking/data/data_sources/local_tracking_data_source.dart`
  - Action: Implement methods to INSERT into completion_log table (immutable, append-only)
  - Action: Implement methods to query completion_log for completion status
  - Action: Implement methods to update learning_progress scheduled dates
  - File: `lib/features/tracking/data/data_sources/remote_tracking_data_source.dart`
  - Action: Implement Firestore writes for /completion_log and /learning_progress collections
  - File: `lib/features/tracking/data/repositories/tracking_repository_impl.dart`
  - Action: Combine local and remote data sources with offline-first logic
  - Notes: All writes go to SQLite first (INSERT to completion_log, UPDATE scheduled dates), then background sync to Firestore

- [ ] **Task 2.2: Create Tracking Domain Layer**
  - File: `lib/features/tracking/domain/entities/learning_stage.dart`
  - Action: Define enum LearningStage { learning, chazara1, chazara2 }
  - File: `lib/features/tracking/domain/usecases/mark_complete_usecase.dart`
  - Action: Implement business logic for marking stage complete
  - Action: INSERT new record into completion_log (mishnaId, stage, completedAt)
  - Action: UPDATE learning_progress to set scheduled date for next stage
  - Action: Enforce immutability via unique constraint (mishnaId, stage) - duplicate insert will throw error
  - Notes: Chazara 1 scheduled for next day, Chazara 2 scheduled 7 days after Chazara 1 completes

- [ ] **Task 2.3: Create Tracking Riverpod Providers**
  - File: `lib/features/tracking/application/providers/tracking_provider.dart`
  - Action: Create StateNotifierProvider for tracking state
  - Action: Expose methods: markLearningComplete, markChazara1Complete, markChazara2Complete
  - Action: Stream learning progress updates from SQLite
  - Notes: Use StreamProvider to reactively update UI

- [ ] **Task 2.4: Create First-Launch Sync Service**
  - File: `lib/core/utils/sync_manager.dart`
  - Action: Implement method `syncFirebaseToSQLite()`
  - Action: Download all /mishnas documents from Firestore
  - Action: Batch insert into local SQLite mishnas table
  - Action: Initialize empty learning_progress records for all Mishnayos
  - Action: Show progress indicator during sync
  - Notes: Check SharedPreferences flag 'has_synced' to run only once

- [ ] **Task 2.5: Trigger First-Launch Sync**
  - File: `lib/features/splash/presentation/screens/splash_screen.dart`
  - Action: Check 'has_synced' flag on splash screen
  - Action: If false, show loading UI and call syncFirebaseToSQLite()
  - Action: Update 'has_synced' flag after completion
  - Action: Navigate to home screen after sync
  - Notes: Estimated sync time: 10-30 seconds for 4,192 records

- [ ] **Task 2.6: Create Mishna Browser UI**
  - File: `lib/features/tracking/presentation/screens/browse_screen.dart`
  - Action: Create hierarchical navigation (Seder → Masechta → Perek → Mishna)
  - Action: Display list of sedarim on initial screen
  - Action: Drill down to masechtos, then perakim, then individual Mishnayos
  - File: `lib/features/tracking/presentation/widgets/mishna_card.dart`
  - Action: Display Mishna with Hebrew text, English text
  - Action: Show learning stage indicators (✓ for complete, • for pending)
  - Notes: Material Design 3 components (ListTile, Card, etc.)

- [ ] **Task 2.7: Create Mishna Detail Screen**
  - File: `lib/features/tracking/presentation/screens/mishna_detail_screen.dart`
  - Action: Display full Mishna text (Hebrew primary, English collapsible)
  - Action: Show current stage status
  - Action: Display completion buttons based on current stage
  - Notes: Scrollable for long Mishnayos

- [ ] **Task 2.8: Implement Completion UI**
  - File: `lib/features/tracking/presentation/widgets/completion_button.dart`
  - Action: Create button "Mark Learning Complete" (visible if no completion_log entry for stage='learning')
  - Action: Create button "Mark Chazara 1 Complete" (visible if learning complete, no chazara1 completion_log entry)
  - Action: Create button "Mark Chazara 2 Complete" (visible if chazara1 complete, no chazara2 completion_log entry)
  - Action: Disable all buttons if all stages complete (immutable via completion_log)
  - Action: Show confirmation dialog before marking complete
  - Notes: Material Design 3 ElevatedButton with appropriate styling

- [ ] **Task 2.9: Implement Mark Complete Logic**
  - File: `lib/features/tracking/domain/usecases/mark_complete_usecase.dart`
  - Action: On mark complete, INSERT new record into completion_log (mishnaId, stage, completedAt=now, isSynced=false)
  - Action: Calculate and UPDATE scheduled date for next stage in learning_progress
  - Action: Handle unique constraint violation (prevents duplicate completions, immutability enforced)
  - Action: Show success feedback (snackbar or animation)
  - Notes: Chazara 1 scheduled = completion date + 1 day, Chazara 2 scheduled = chazara1 completion + 7 days

- [ ] **Task 2.10: Implement Background Delta Sync**
  - File: `lib/core/utils/sync_manager.dart`
  - Action: Create method `syncChangesToFirebase()`
  - Action: Query completion_log where isSynced = false (immutable records to sync)
  - Action: Query learning_progress where isSynced = false (scheduled date updates to sync)
  - Action: Batch update Firestore with changed records (/completion_log and /learning_progress collections)
  - Action: Set isSynced = true after successful sync
  - Action: Handle network errors gracefully (retry logic with exponential backoff)
  - Notes: Run on app startup and after each completion

- [ ] **Task 2.11: Create Sync Status Indicator**
  - File: `lib/features/tracking/presentation/widgets/sync_status_widget.dart`
  - Action: Display sync status icon (cloud synced, syncing, offline)
  - Action: Show last sync timestamp
  - Notes: Non-blocking UI element in app bar

- [ ] **Task 2.12: Implement Today's Tasks Screen**
  - File: `lib/features/tracking/presentation/screens/today_screen.dart`
  - Action: Query Mishnayos with learning stage pending (no completion)
  - Action: Query Mishnayos where chazara1ScheduledDate = today
  - Action: Query Mishnayos where chazara2ScheduledDate = today
  - Action: Display grouped lists: "New Learning", "Chazara 1 Today", "Chazara 2 Today"
  - Action: Tap Mishna to navigate to detail screen
  - Notes: This is the main daily entry point for users

---

### PHASE 3: Intelligence Layer (Scheduler & Progress)

**Goal:** Smart scheduler, daily recommendations, progress dashboard, Hebrew calendar integration

#### Tasks

- [ ] **Task 3.1: Implement Hebrew Date Utilities**
  - File: `lib/core/utils/hebrew_date_utils.dart`
  - Action: Create helper methods using kosher_dart package
  - Action: Method: `getHebrewDate(DateTime gregorian) → JewishDate`
  - Action: Method: `formatHebrewDate(JewishDate) → String` (e.g., "19 Kislev 5789")
  - Action: Method: `daysUntilBarMitzvah() → int`
  - Action: Method: `progressionToBarMitzvah() → double` (0.0 to 1.0)
  - Notes: Bar mitzvah date hardcoded in app_constants.dart

- [ ] **Task 3.2: Create Scheduler Algorithm - Daily Calculation**
  - File: `lib/features/scheduler/domain/usecases/calculate_daily_recommendations.dart`
  - Action: Calculate days remaining until bar mitzvah
  - Action: Count total Mishnayos not yet started (learning incomplete)
  - Action: Count total Mishnayos needing chazara 1 (learning complete, chazara1 incomplete or scheduled today/past)
  - Action: Count total Mishnayos needing chazara 2 (chazara1 complete, chazara2 incomplete or scheduled today/past)
  - Action: Calculate optimal daily mix to finish all stages by bar mitzvah
  - Action: Return DailyRecommendation(newLearningCount, chazara1Count, chazara2Count)
  - Notes: Algorithm should balance new learning with chazara pile-up

- [ ] **Task 3.3: Implement Adaptive Pacing Logic**
  - File: `lib/features/scheduler/domain/usecases/calculate_daily_recommendations.dart`
  - Action: If behind pace (projected completion > bar mitzvah), increase daily counts
  - Action: If ahead of pace, allow buffer and reduce daily counts
  - Action: If chazara queue exceeds threshold, temporarily reduce new learning
  - Action: Ensure minimum viable daily count (e.g., 3 total minimum)
  - Notes: Prevent overwhelming the user with catch-up recommendations

- [ ] **Task 3.4: Create Scheduler Riverpod Provider**
  - File: `lib/features/scheduler/application/providers/scheduler_provider.dart`
  - Action: Create FutureProvider for daily recommendations
  - Action: Refresh recommendations daily at app startup
  - Action: Expose method to manually recalculate recommendations
  - Notes: Cache today's recommendation to avoid repeated calculations

- [ ] **Task 3.5: Update Today's Tasks Screen with Recommendations**
  - File: `lib/features/tracking/presentation/screens/today_screen.dart`
  - Action: Display daily recommendation at top: "Today: 4 new learning + 3 chazara 1 + 2 chazara 2"
  - Action: Highlight recommended count vs completed count
  - Action: Show progress bar for today's completion
  - Notes: Visual encouragement to complete daily goal

- [ ] **Task 3.6: Create Progress Data Layer**
  - File: `lib/features/progress/data/repositories/progress_repository_impl.dart`
  - Action: Query total Mishnayos count (must equal exactly 4,192)
  - Action: Query completed learning count
  - Action: Query completed chazara1 count
  - Action: Query completed chazara2 count
  - Action: Calculate percentage complete overall
  - Action: Calculate percentage complete by seder
  - Action: Calculate percentage complete by masechta
  - Notes: Aggregate queries on learning_progress table

- [ ] **Task 3.7: Create Progress Domain Layer**
  - File: `lib/features/progress/domain/entities/progress_stats.dart`
  - Action: Define ProgressStats entity with all calculated metrics
  - File: `lib/features/progress/domain/usecases/calculate_on_track_status.dart`
  - Action: Calculate expected completion percentage based on time elapsed
  - Action: Compare actual vs expected
  - Action: Return OnTrackStatus enum { ahead, onPace, behind }
  - Notes: Time elapsed = (today - start date) / (bar mitzvah - start date)

- [ ] **Task 3.8: Create Progress Riverpod Provider**
  - File: `lib/features/progress/application/providers/progress_provider.dart`
  - Action: Create StreamProvider for real-time progress updates
  - Action: Refresh progress after each completion
  - Notes: Reactively updates dashboard when user marks Mishnayos complete

- [ ] **Task 3.9: Create Progress Dashboard Screen**
  - File: `lib/features/progress/presentation/screens/dashboard_screen.dart`
  - Action: Display overall completion percentage (large circular progress indicator)
  - Action: Display on-track status with color coding (green=ahead, yellow=on pace, red=behind)
  - Action: Display days until bar mitzvah (Hebrew date countdown)
  - Action: Display current streak
  - Action: Display total points earned
  - Notes: Hero section with key metrics

- [ ] **Task 3.10: Create Seder Progress Widget**
  - File: `lib/features/progress/presentation/widgets/seder_progress_widget.dart`
  - Action: Display 6 sedarim as horizontal segments
  - Action: Each segment shows completion percentage
  - Action: Color-code by completion level (gray=not started, blue=in progress, green=complete)
  - Action: Tap seder to drill down to masechta view
  - Notes: Visual representation of Shas structure

- [ ] **Task 3.11: Create Masechta Progress List**
  - File: `lib/features/progress/presentation/widgets/masechta_progress_list.dart`
  - Action: List all masechtos within selected seder
  - Action: Show completion percentage per masechta
  - Action: Show completed Mishnayos count / total count
  - Notes: Sortable by name or completion percentage

- [ ] **Task 3.12: Create Points Over Time Chart**
  - File: `lib/features/progress/presentation/widgets/points_chart_widget.dart`
  - Action: Display line chart of cumulative points over time
  - Action: Show weekly or monthly view toggle
  - Notes: Use fl_chart package (add to dependencies if needed)

---

### PHASE 4: Engagement & Access (Gamification & Modes)

**Goal:** Points, rewards, streak tracking, parent/tutor modes, notifications, polish

#### Tasks

- [ ] **Task 4.1: Implement Points Calculation**
  - File: `lib/features/rewards/domain/usecases/calculate_points_usecase.dart`
  - Action: On mark learning complete, award learningPoints (10)
  - Action: On mark chazara1 complete, award chazara1Points (5)
  - Action: On mark chazara2 complete, award chazara2Points (5)
  - Action: Update user_stats.totalPoints in SQLite
  - Notes: Points are cumulative and never decrease

- [ ] **Task 4.2: Implement Streak Tracking**
  - File: `lib/features/rewards/domain/usecases/update_streak_usecase.dart`
  - Action: On any completion, check user_stats.lastLearningDate
  - Action: If lastLearningDate = yesterday, increment currentStreak
  - Action: If lastLearningDate = today, no change (already counted)
  - Action: If lastLearningDate < yesterday, reset currentStreak to 1
  - Action: Update longestStreak if currentStreak exceeds it
  - Action: Set lastLearningDate = today
  - Notes: Hebrew dates or Gregorian dates? Clarify with user if needed (assuming Gregorian for simplicity)

- [ ] **Task 4.3: Create Rewards Data Layer**
  - File: `lib/features/rewards/data/repositories/rewards_repository_impl.dart`
  - Action: CRUD operations on rewards table
  - Action: Query next unearn reward sorted by pointsRequired
  - Action: Check if user has earned new rewards based on totalPoints
  - Notes: Rewards are parent-configured

- [ ] **Task 4.4: Create Rewards Riverpod Provider**
  - File: `lib/features/rewards/application/providers/rewards_provider.dart`
  - Action: StreamProvider for rewards list
  - Action: Method to check and award newly earned rewards
  - Action: Notify user when reward earned (but keep mystery)
  - Notes: Parent configures rewards via parent mode

- [ ] **Task 4.5: Create Rewards Display Widget**
  - File: `lib/features/rewards/presentation/widgets/rewards_widget.dart`
  - Action: Display progress bar to next mystery reward
  - Action: Show points needed: "??? points until next surprise!"
  - Action: Don't reveal reward title/description until earned
  - Notes: Mystery element maintains anticipation

- [ ] **Task 4.6: Create Reward Earned Dialog**
  - File: `lib/features/rewards/presentation/widgets/reward_earned_dialog.dart`
  - Action: Show celebratory dialog when reward earned
  - Action: Display reward title and description
  - Action: Mark reward as revealed in database
  - Action: Confetti or celebration animation
  - Notes: Satisfying moment of achievement

- [ ] **Task 4.7: Create Parent Mode PIN Entry**
  - File: `lib/features/parent_mode/presentation/screens/pin_entry_screen.dart`
  - Action: Numeric PIN entry UI (4-6 digits)
  - Action: Validate PIN against app_config table (key='parent_pin')
  - Action: On success, navigate to parent dashboard
  - Action: On failure, show error and retry
  - Notes: Initial PIN setup during first-launch flow

- [ ] **Task 4.8: Create Parent Dashboard**
  - File: `lib/features/parent_mode/presentation/screens/parent_dashboard_screen.dart`
  - Action: Display overall completion percentage
  - Action: Display on-track status
  - Action: Display current streak and total points
  - Action: Button to manage rewards
  - Action: Button to view detailed analytics
  - Action: Button to configure settings (point values, learning order)
  - Notes: Minimal time investment, quick glance dashboard

- [ ] **Task 4.9: Create Reward Management Screen**
  - File: `lib/features/parent_mode/presentation/screens/reward_management_screen.dart`
  - Action: List all rewards (earned and unearned)
  - Action: Add new reward (title, description, points required)
  - Action: Edit existing reward
  - Action: Delete reward (if not yet earned)
  - Action: Reorder rewards (display order)
  - Notes: Parent can add rewards as child progresses

- [ ] **Task 4.10: Create Analytics Screen**
  - File: `lib/features/parent_mode/presentation/screens/analytics_screen.dart`
  - Action: Display detailed progress metrics
  - Action: Show completion breakdown by seder/masechta
  - Action: Show daily completion history (calendar view)
  - Action: Show projected completion date
  - Action: Export data option (CSV or JSON)
  - Notes: In-depth visibility for parent monitoring

- [ ] **Task 4.11: Create Tutor Mode PIN Entry**
  - File: `lib/features/tutor_mode/presentation/screens/tutor_pin_entry_screen.dart`
  - Action: Separate PIN entry (validate against key='tutor_pin')
  - Action: Navigate to tutor dashboard on success
  - Notes: Different PIN than parent mode

- [ ] **Task 4.12: Create Tutor Dashboard (View-Only)**
  - File: `lib/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart`
  - Action: Display overall progress (read-only)
  - Action: Show which Mishnayos completed by stage
  - Action: Show what's due for chazara today
  - Action: No edit capabilities (view-only)
  - Notes: Helps tutor align teaching sessions

- [ ] **Task 4.13: Implement Push Notifications**
  - File: `lib/services/notification_service.dart`
  - Action: Initialize Firebase Cloud Messaging
  - Action: Request notification permissions on first launch
  - Action: Schedule daily reminder notification at configured time
  - Action: Use flutter_local_notifications for local scheduling
  - Notes: Default reminder time: 7:00 PM (configurable in parent mode)

- [ ] **Task 4.14: Create Notification Settings**
  - File: `lib/features/parent_mode/presentation/screens/settings_screen.dart`
  - Action: Toggle notifications on/off
  - Action: Configure notification time (time picker)
  - Action: Configure notification message
  - Notes: Stored in app_config table

- [ ] **Task 4.15: Implement Completion Animations**
  - File: `lib/features/tracking/presentation/widgets/completion_animation_widget.dart`
  - Action: Create checkmark animation when marking complete
  - Action: Play success sound (optional, subtle)
  - Action: Show points earned popup
  - Notes: Satisfying feedback for completing tasks

- [ ] **Task 4.16: Create Navigation Structure**
  - File: `lib/main.dart`
  - Action: Set up bottom navigation bar (Home, Browse, Progress, More)
  - Action: Define routes for all screens
  - Action: Implement deep linking (if needed)
  - Notes: Material Design 3 NavigationBar widget

- [ ] **Task 4.17: Implement App Theme**
  - File: `lib/core/theme/app_theme.dart`
  - Action: Define Material Design 3 color scheme
  - Action: Define typography (respectful, age-appropriate)
  - Action: Define component themes (buttons, cards, etc.)
  - Notes: Professional but engaging for 10-year-old

- [ ] **Task 4.18: Add Sefaria Attribution**
  - File: `lib/features/tracking/presentation/screens/mishna_detail_screen.dart`
  - Action: Display small footer: "Text powered by Sefaria.org"
  - Action: Link to Sefaria (optional, opens in browser)
  - Notes: Required attribution for using Sefaria content

- [ ] **Task 4.19: Implement Error Handling**
  - File: `lib/core/utils/error_handler.dart`
  - Action: Global error handler for uncaught exceptions
  - Action: User-friendly error messages
  - Action: Retry logic for network failures
  - Notes: Prevent app crashes and data loss

- [ ] **Task 4.20: Create Onboarding Flow**
  - File: `lib/features/onboarding/presentation/screens/onboarding_screen.dart`
  - Action: Welcome screen introducing app purpose
  - Action: Set parent PIN
  - Action: Set tutor PIN (optional, can skip)
  - Action: Configure notification preferences
  - Action: Explain 3-stage learning cycle
  - Notes: First-time user experience

- [ ] **Task 4.21: Implement Data Backup/Restore**
  - File: `lib/features/parent_mode/presentation/screens/backup_screen.dart`
  - Action: Export all data to JSON file
  - Action: Import data from JSON file (restore)
  - Action: Store backup in device storage or cloud
  - Notes: Safety net for data recovery

- [ ] **Task 4.22: Add About Screen**
  - File: `lib/features/more/presentation/screens/about_screen.dart`
  - Action: Display app version
  - Action: Display "Built by Daniel for Yisroel Meir Niasoff"
  - Action: Credits (Sefaria, Flutter, packages used)
  - Action: Privacy policy link (if needed for Play Store)
  - Notes: Personal touch for father-son project

- [ ] **Task 4.23: Write Unit Tests**
  - File: `test/features/scheduler/calculate_daily_recommendations_test.dart`
  - Action: Test daily recommendation algorithm with various scenarios
  - File: `test/features/tracking/mark_complete_usecase_test.dart`
  - Action: Test immutability enforcement, chazara scheduling
  - File: `test/features/rewards/streak_tracking_test.dart`
  - Action: Test streak increment, reset, longest streak logic
  - File: `test/core/utils/hebrew_date_utils_test.dart`
  - Action: Test Hebrew date conversions and calculations
  - Notes: Aim for 80%+ code coverage on business logic

- [ ] **Task 4.24: Write Widget Tests**
  - File: `test/features/tracking/widgets/completion_button_test.dart`
  - Action: Test button visibility based on stage status
  - Action: Test button tap triggers correct action
  - File: `test/features/progress/widgets/seder_progress_widget_test.dart`
  - Action: Test rendering of progress segments
  - Notes: Widget tests for critical UI components

- [ ] **Task 4.25: Write Integration Tests**
  - File: `integration_test/mark_complete_flow_test.dart`
  - Action: End-to-end test: mark learning complete → verify chazara1 scheduled → mark chazara1 complete → verify chazara2 scheduled
  - File: `integration_test/sync_flow_test.dart`
  - Action: Test first-launch sync and delta sync flows
  - Notes: Validate critical user journeys

- [ ] **Task 4.26: Perform Manual Testing**
  - Action: Test on real Android device (not just emulator)
  - Action: Test offline mode (airplane mode, then reconnect)
  - Action: Test data persistence across app restarts
  - Action: Test notification delivery
  - Action: Test parent/tutor PIN access
  - Notes: Real-world usage scenarios

- [ ] **Task 4.27: Optimize Performance**
  - Action: Profile app with Flutter DevTools
  - Action: Optimize database queries (add indexes if needed)
  - Action: Lazy-load Mishna text (don't load all 4,192 at once)
  - Action: Reduce widget rebuilds with const constructors
  - Notes: Ensure smooth 60fps performance

- [ ] **Task 4.28: Prepare for Release**
  - File: `android/app/build.gradle`
  - Action: Configure app signing for release build
  - Action: Set version number (1.0.0)
  - Action: Generate app icon and splash screen
  - File: `android/app/src/main/AndroidManifest.xml`
  - Action: Configure permissions and metadata
  - Notes: Ready for installation on Yisroel Meir's device

---

### Acceptance Criteria

**Phase 1: Foundation**

- [ ] AC 1.1: Given Flutter project initialized, when running `flutter pub get`, then all dependencies resolve without errors
- [ ] AC 1.2: Given Drift schema defined, when running build_runner, then drift_database.g.dart generates successfully
- [ ] AC 1.3: Given admin seeding script executed, when checking Firestore console, then exactly 4,192 Mishna documents exist in /mishnas collection
- [ ] AC 1.4: Given Firebase configured, when launching app, then Firebase initializes without errors
- [ ] AC 1.5: Given folder structure created, when navigating project, then all feature directories exist with correct layer subdirectories

**Phase 2: Core Tracking**

- [ ] AC 2.1: Given first app launch, when sync executes, then all 4,192 Mishnayos are downloaded to SQLite within 30 seconds
- [ ] AC 2.2: Given Mishna browsing screen, when navigating hierarchy, then user can drill down from Seder → Masechta → Perek → individual Mishna
- [ ] AC 2.3: Given Mishna detail screen, when marking learning complete, then new record is INSERTED into completion_log (mishnaId, stage='learning', completedAt=now), and chazara1ScheduledDate is set to tomorrow in learning_progress
- [ ] AC 2.4: Given learning stage complete, when attempting to mark again, then button is disabled (unique constraint on completion_log prevents duplicate inserts for same mishnaId+stage)
- [ ] AC 2.5: Given chazara1 marked complete, when completion is saved, then new record is INSERTED into completion_log (mishnaId, stage='chazara1', completedAt=now), and chazara2ScheduledDate is set to 7 days from now in learning_progress
- [ ] AC 2.6: Given offline mode (no network), when marking Mishna complete, then change persists in SQLite and isSynced flag is false
- [ ] AC 2.7: Given network restored, when background sync runs, then changed records sync to Firestore and isSynced flag becomes true
- [ ] AC 2.8: Given today's tasks screen, when opening, then Mishnayos due for chazara today are displayed in appropriate sections

**Phase 3: Intelligence Layer**

- [ ] AC 3.1: Given Hebrew date utilities, when calling daysUntilBarMitzvah(), then correct number of days to 19 Kislev 5789 is returned
- [ ] AC 3.2: Given scheduler algorithm, when calculating daily recommendations, then newLearningCount + chazara1Count + chazara2Count results in on-time completion if followed daily
- [ ] AC 3.3: Given user behind pace, when recalculating recommendations, then daily counts increase to catch up
- [ ] AC 3.4: Given chazara pile-up exceeds threshold, when calculating recommendations, then newLearningCount decreases to prioritize chazara
- [ ] AC 3.5: Given progress dashboard, when viewing overall completion, then percentage accurately reflects (completed stages / total stages) across all Mishnayos
- [ ] AC 3.6: Given on-track status calculation, when user is 10% complete after 10% of time elapsed, then status shows "On Pace"
- [ ] AC 3.7: Given seder progress widget, when tapping a seder, then masechta list for that seder is displayed
- [ ] AC 3.8: Given points chart, when viewing, then cumulative points over time are plotted correctly

**Phase 4: Engagement & Access**

- [ ] AC 4.1: Given marking Mishna complete, when completion executes, then totalPoints increases by configured point value (10 for learning, 5 for chazara)
- [ ] AC 4.2: Given learning today after learning yesterday, when streak updates, then currentStreak increments by 1
- [ ] AC 4.3: Given learning today after missing yesterday, when streak updates, then currentStreak resets to 1
- [ ] AC 4.4: Given totalPoints reaches reward threshold, when checking rewards, then reward is marked as earned and user sees earned notification
- [ ] AC 4.5: Given parent PIN entry screen, when entering correct PIN, then parent dashboard is accessible
- [ ] AC 4.6: Given parent PIN entry screen, when entering incorrect PIN, then error message displays and dashboard remains locked
- [ ] AC 4.7: Given reward management screen, when parent adds new reward, then reward appears in rewards list and syncs to Firestore
- [ ] AC 4.8: Given tutor PIN entry, when entering correct tutor PIN, then tutor dashboard (view-only) is accessible
- [ ] AC 4.9: Given tutor dashboard, when viewing, then no edit/delete actions are available (read-only constraint enforced)
- [ ] AC 4.10: Given notification service enabled, when configured time arrives, then local notification displays with reminder message
- [ ] AC 4.11: Given completion animation, when marking Mishna complete, then checkmark animation plays and points popup shows
- [ ] AC 4.12: Given bottom navigation, when tapping each tab, then correct screen displays (Home, Browse, Progress, More)
- [ ] AC 4.13: Given data backup, when exporting to JSON, then file contains all mishnas, learning_progress, rewards, and user_stats data
- [ ] AC 4.14: Given data restore, when importing JSON file, then all data is restored to SQLite and syncs to Firestore
- [ ] AC 4.15: Given unit tests, when running `flutter test`, then all tests pass with 80%+ code coverage on business logic
- [ ] AC 4.16: Given integration test for mark complete flow, when running test, then end-to-end flow executes without errors
- [ ] AC 4.17: Given app on real Android device, when testing offline, then all core features work (mark complete, browse, view progress)
- [ ] AC 4.18: Given release build, when installing on device, then app launches successfully and performs smoothly (60fps)

## Additional Context

### Dependencies

**Flutter Packages (pubspec.yaml):**

**Core Dependencies:**
- `flutter` - Flutter SDK
- `flutter_riverpod: ^2.5.0` - Riverpod 2.0+ state management
- `drift: ^2.14.0` - Type-safe SQLite database
- `sqlite3_flutter_libs: ^0.5.0` - SQLite3 bundled with app
- `path_provider: ^2.1.0` - File paths for database
- `path: ^1.8.3` - Path manipulation

**Firebase:**
- `firebase_core: ^2.24.0` - Firebase initialization
- `firebase_auth: ^4.15.0` - Anonymous authentication
- `cloud_firestore: ^4.13.0` - Cloud database sync

**Hebrew Calendar:**
- `kosher_dart: ^0.3.0` - Hebrew calendar calculations and formatting

**API & Networking:**
- `http: ^1.1.0` - HTTP client for Sefaria API seeding
- `connectivity_plus: ^5.0.0` - Network state detection for sync triggers (F6)

**Security & Storage:**
- `flutter_secure_storage: ^9.0.0` - Encrypted PIN storage using Android Keystore (F8)
- `bcrypt: ^1.1.3` - PIN hashing for secure storage (F8)
- `shared_preferences: ^2.2.0` - Local storage for sync checkpoints and flags

**UI/UX:**
- `flutter_local_notifications: ^16.3.0` - Local scheduled notifications (F17)
- `intl: ^0.18.0` - Internationalization and date formatting

**Dev Dependencies:**
- `build_runner: ^2.4.0` - Code generation
- `drift_dev: ^2.14.0` - Drift code generator
- `flutter_test` - Testing framework
- `mockito: ^5.4.0` - Mocking for tests
- `integration_test` - Integration testing
- `flutter_lints: ^3.0.0` - Linting rules

**External Services:**
- **Firebase:** Anonymous Authentication, Firestore (Free tier sufficient for single user)
  - Usage: 4,192 reads on first launch, ~10-15 writes/day
  - Quota: Well within free tier (50k reads/day, 20k writes/day)
- **Sefaria API:** https://developers.sefaria.org (CC-BY-SA, free, one-time seeding)
  - Attribution required in app
- **Google Play Store:** Future v2.0 public release distribution

### Testing Strategy

**Unit Tests:**
- Smart scheduler algorithm (daily recommendations, adaptive pacing)
- Progress calculations (percentage complete, on-track status)
- Chazara queue management
- Points/rewards logic
- Hebrew date conversions

**Widget Tests:**
- Completion tick UI
- Progress dashboard components
- Parent/tutor PIN entry
- Reward displays

**Integration Tests:**
- End-to-end: mark Mishna complete → chazara auto-scheduled
- First launch sync (Firebase → SQLite)
- Delta sync (SQLite ↔ Firebase)
- Parent mode reward management flow
- Tutor mode view-only access

### Notes

**User Context:**
- Primary user: Yisroel Meir Niasoff, 10 years old, tech-savvy
- Bar mitzvah: 19 Kislev, 5789 (December 7, 2028)
- Learning style: flexible timing, short sessions, needs visible progress
- Motivation: loves numbers going up, mystery rewards, streak tracking

**Design Philosophy:**
- Make 4,192 feel achievable, not overwhelming
- Respectful of Torah learning (not frivolous)
- Age-appropriate engagement for 10-year-old
- Hands-off parent approach (child owns his journey)
- Satisfying completion feedback (animations, sounds)

**Critical Success Factors:**
- Week 1: Daily usage without prompting
- Month 1: Daily habit established (5-6 days/week)
- Month 3: Sustained engagement, on-track for deadline
- Ultimate: Complete all Mishnayos with full chazara by 19 Kislev, 5789

**High-Risk Items (Pre-Mortem Analysis):**

1. **Scheduler Algorithm Complexity**
   - Risk: Algorithm may not accurately balance new learning vs chazara pile-up
   - Mitigation: Write comprehensive unit tests with edge cases, validate with real-world scenarios

2. **First-Launch Sync Performance**
   - Risk: Downloading 4,192 Mishna records may take too long or fail on slow networks
   - Mitigation: Implement batch downloading, progress indicator, retry logic, and offline fallback

3. **Immutability Enforcement**
   - Risk: User accidentally marking incomplete or bugs allowing re-marking
   - Mitigation: Database-level constraints, thorough testing of edge cases, clear UI feedback

4. **Hebrew Calendar Accuracy**
   - Risk: Incorrect bar mitzvah countdown or date calculations
   - Mitigation: Validate kosher_dart package accuracy, cross-check with authoritative sources

5. **Data Loss on Device Failure**
   - Risk: User loses all progress if device is lost/broken before Firebase sync
   - Mitigation: Aggressive background sync, parent backup/restore feature, Firebase as safety net

6. **Notification Reliability**
   - Risk: Android battery optimization may prevent daily reminder notifications
   - Mitigation: Test on multiple Android versions, implement wake locks if needed, user education

7. **Motivation Sustainability**
   - Risk: User loses interest after initial excitement (week 2-4 drop-off)
   - Mitigation: Streak tracking, mystery rewards, parent monitoring dashboard to intervene early

**Known Limitations:**

- **v1.0 Single-User:** Hardcoded for Yisroel Meir, not configurable for other users
- **Android Only:** No iOS support in v1.0
- **English UI:** Interface in English only, content in Hebrew/English
- **Manual Masechta Order:** Parent must manually configure learning sequence
- **No Audio:** Text-only, no audio playback of Mishnayos
- **Limited Analytics:** Basic dashboard only, no advanced data export/visualization

**Future Considerations (Out of Scope for v1.0):**

- **v2.0 Multi-User:** Generalize app for public Play Store release
- **Customizable Goals:** Support different learning goals beyond bar mitzvah
- **Hebrew UI:** Localize interface to Hebrew language
- **Audio Integration:** Add Mishna audio playback for auditory learners
- **Social Features:** Optional sharing of achievements with family/friends
- **Advanced Analytics:** Data export, trend analysis, predictive completion forecasting

**Implementation Notes:**

- **Phase Dependency:** Each phase builds on the previous; cannot skip phases
- **Testing Throughout:** Write tests alongside implementation, not after
- **Iterative Refinement:** UI/UX will evolve based on Yisroel Meir's feedback during development
- **Performance First:** Optimize for smooth 60fps on mid-range Android devices
- **Offline Priority:** All core features must work offline (mark complete, browse, view progress)
- **Data Integrity:** Never lose user progress - aggressive sync, backup, error handling

**Development Environment:**

- **IDE:** VS Code or Android Studio with Flutter/Dart plugins
- **Emulator:** Android emulator (API 30+) for initial testing
- **Physical Device:** Real Android device for final testing and performance validation
- **Firebase Console:** Web-based management for Firestore, Auth, Cloud Messaging
- **Version Control:** Git repository initialized from Task 1.1

**Deployment Strategy:**

- **v1.0 Release:** Direct APK installation on Yisroel Meir's device (no Play Store initially)
- **Beta Testing:** Family testing for 1-2 weeks before full rollout
- **v2.0 Release:** If v1.0 successful, prepare for public Play Store release with multi-user support
