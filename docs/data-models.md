---
title: "Data Models & Database Schema"
description: "Complete reference for all Drift/SQLite tables, Firestore collections, DAO operations, sync strategies, and querying patterns in the Learning Tracker application."
date: 2026-03-18
---

# Data Models & Database Schema

**Database:** Drift (SQLite ORM)
**Schema Version:** 15
**Tables:** 22
**DAOs:** 22

---

## Table of Contents

- [How to Read This Document](#how-to-read-this-document)
- [Design Principles](#design-principles)
- [ER Diagram](#er-diagram)
- [Local Tables (Drift/SQLite)](#local-tables-driftsqlite)
  - [Account-Level Tables](#account-level-tables)
  - [Profile-Scoped Tables](#profile-scoped-tables)
  - [System Tables](#system-tables)
  - [Program Tables](#program-tables)
- [DAO Operations](#dao-operations)
- [Querying Patterns](#querying-patterns)
- [Firestore Collections](#firestore-collections)
- [Sync & Conflict Resolution](#sync--conflict-resolution)
- [Migration History](#migration-history)

---

## How to Read This Document

The table definitions use the following notation conventions:

| Notation | Meaning |
|---|---|
| **PK** | Primary key. Uniquely identifies a row. Composite PKs use multiple columns marked PK. |
| **FK** | Foreign key. References a row in another table. |
| **UK** | Unique key. Enforces uniqueness, alone or as part of a composite unique constraint. |
| **PK, FK** or **PK_FK** | Column serves as both part of the primary key and a foreign key. |
| **Nullable** | Column allows null values. All other columns require a value. |
| **Append-only** | Table only permits inserts. Updates and deletes are prohibited to preserve full history. |
| **LWW** | Last-write-wins merge strategy for sync conflict resolution. |

---

## Design Principles

| Principle | Description |
|---|---|
| **Profile scoping** | Most tables key on `profileId`, enabling multiple learners per account (max 10 profiles). |
| **Append-only tables** | `completions` and `learning_ledger` never update or delete rows, preserving full history and ensuring data integrity. |
| **Last-write-wins (LWW) merge** | Bookmarks, goals, rewards, and settings resolve sync conflicts by timestamp comparison. |
| **UTC timestamps** | All temporal values store in UTC to avoid timezone ambiguity. |
| **sefariaRef as content FK** | Content references use Sefaria string identifiers rather than auto-increment IDs, aligning with the external content source. |

---

## ER Diagram

```mermaid
erDiagram
    user_profiles ||--o{ profiles : "has up to 10"
    profiles ||--o{ active_curricula : "activates"
    profiles ||--o{ curriculum_tracks : "configures"
    profiles ||--o{ completions : "records"
    profiles ||--o{ bookmarks : "saves"
    profiles ||--o{ learning_order : "orders"
    profiles ||--o{ stage_definitions : "defines"
    profiles ||--o{ goals : "sets"
    profiles ||--o{ rewards : "earns"
    profiles ||--o{ streaks : "maintains"
    profiles ||--o{ point_configs : "configures"
    profiles ||--o{ learning_ledger : "logs"
    profiles ||--o{ curriculum_scopes : "scopes"
    profiles ||--o{ profile_programs : "enrolls in"
    profiles ||--o{ test_scores : "achieves"
    learning_programs ||--o{ profile_programs : "assigned via"
    learning_programs ||--o{ test_dates : "schedules"
    test_dates ||--o{ test_scores : "scored by"

    user_profiles {
        int id PK
        string firebaseUid UK
        string displayName
        string userMode
    }

    profiles {
        int id PK
        int accountId FK
        string displayName
        string mode "child | adult"
        int avatarIndex
        datetime createdAt
        datetime updatedAt
    }

    active_curricula {
        int profileId PK_FK
        string curriculumId PK
        datetime activatedAt
    }

    curriculum_tracks {
        int profileId PK_FK
        string curriculumId PK
        string trackType PK
        bool isActive
        datetime activatedAt
        datetime deactivatedAt
    }

    completions {
        int profileId FK
        string curriculumId
        string sefariaRef FK
        string stageId
        string trackType
        datetime completedAt "UTC"
        int points
    }

    bookmarks {
        int profileId FK
        string curriculumId UK
        string trackType UK
        string sefariaRef
        datetime updatedAt
    }

    learning_order {
        int profileId FK
        string curriculumId UK
        string sefariaRef UK
        int userSortOrder
    }

    stage_definitions {
        int profileId FK
        string curriculumId UK
        int stageOrder UK
        string stageName
        int delayDays
        string scheduleType "delay | weekly | rolling"
        string daysOfWeek "JSON"
        int rollingWindowSize
    }

    goals {
        int profileId FK
        string curriculumId
        int targetPercent
        date targetDate
        string description
        string dateType "gregorian | hebrew"
    }

    rewards {
        int profileId FK
        string title
        string description
        int pointsThreshold
        bool isRevealed
        bool isEarned
        datetime earnedAt
        string curriculumId "nullable (global)"
    }

    streaks {
        int profileId FK
        int currentStreak
        int maxStreak
        date lastCompletionDate
    }

    point_configs {
        int profileId FK
        string curriculumId UK
        int stageOrder UK
        int points "gt 0"
    }

    learning_ledger {
        int profileId FK
        string curriculumId
        string unitType
        string unitIdentifier
        string unitDisplayNameHe
        string unitDisplayNameEn
        string trackType
        string trackId
        datetime completedAt
        int completionNumber
        string markedBy
        bool isManual
    }

    curriculum_scopes {
        int profileId FK
        string curriculumId UK
        string scopeLevel UK
        string scopeValue UK
        datetime createdAt
    }

    learning_programs {
        int id PK
        string name UK
        string displayName
        string description
        string curriculumType
        bool isActive
        string stagesConfig "JSON"
        bool hasTests
        string testConfig "JSON"
    }

    profile_programs {
        int profileId PK_FK
        string curriculumType PK
        int programId FK
    }

    test_dates {
        int id PK
        int programId FK
        date testDate
        string materialDescription
    }

    test_scores {
        int id PK
        int profileId FK
        int programId FK
        int testDateId "nullable FK"
        float scorePercentage
        string notes
    }

    sync_queue {
        int id PK
        string operationType
        string payload "JSON"
        datetime queuedAt
        int retryCount
        string lastError
    }

    text_cache {
        string sefariaRef PK
        string hebrewText
        string englishText
        datetime fetchedAt
    }

    text_download_statuses {
        string curriculumId PK
        int itemCount
        string textVersion
        datetime downloadedAt
        int storedItemCount
    }

    content_download_statuses {
        string curriculumId PK
        string languageCode PK
        string contentVersion
        int itemCount
        datetime downloadedAt
    }
```

---

## Local Tables (Drift/SQLite)

### Account-Level Tables

#### `user_profiles`

Account-level user record linked to Firebase Authentication.

| Column | Type | Constraints |
|---|---|---|
| `id` | `int` | Primary key |
| `firebaseUid` | `String` | Unique |
| `displayName` | `String` | |
| `userMode` | `String` | |

#### `profiles`

Individual learner profiles within an account. Maximum 10 per account.

| Column | Type | Constraints |
|---|---|---|
| `id` | `int` | Primary key |
| `accountId` | `int` | FK |
| `displayName` | `String` | |
| `mode` | `String` | `child` or `adult` |
| `avatarIndex` | `int` | |
| `createdAt` | `DateTime` | |
| `updatedAt` | `DateTime` | |

---

### Profile-Scoped Tables

All tables in this section key on `profileId` and represent per-learner data.

#### `active_curricula`

Tracks which curricula a profile has activated. At least one must remain active at all times.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | PK, FK |
| `curriculumId` | `String` | PK |
| `activatedAt` | `DateTime` | |

#### `curriculum_tracks`

Track activation state per curriculum. The personal track cannot deactivate.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | PK, FK |
| `curriculumId` | `String` | PK |
| `trackType` | `String` | PK |
| `isActive` | `bool` | |
| `activatedAt` | `DateTime` | |
| `deactivatedAt` | `DateTime` | Nullable |

#### `completions`

**Append-only.** Records every learning completion event. The system permits no updates or deletes.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | |
| `sefariaRef` | `String` | Content FK |
| `stageId` | `String` | |
| `trackType` | `String` | |
| `completedAt` | `DateTime` | UTC |
| `points` | `int` | |

**Dedup key:** `(curriculumId, sefariaRef, stageId, trackType, completedAt)`

#### `bookmarks`

Current reading position per curriculum and track. Uses last-write-wins merge for sync.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | Unique with profileId, trackType |
| `trackType` | `String` | Unique with profileId, curriculumId |
| `sefariaRef` | `String` | |
| `updatedAt` | `DateTime` | |

#### `learning_order`

User-defined sort order for content within a curriculum.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | Unique with profileId, sefariaRef |
| `sefariaRef` | `String` | Unique with profileId, curriculumId |
| `userSortOrder` | `int` | |

#### `stage_definitions`

Configurable learning stages per curriculum. Maximum 10 stages per curriculum.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | Unique with profileId, stageOrder |
| `stageOrder` | `int` | Unique with profileId, curriculumId |
| `stageName` | `String` | |
| `delayDays` | `int` | |
| `scheduleType` | `String` | `delay`, `weekly`, or `rolling` |
| `daysOfWeek` | `String` | JSON array |
| `rollingWindowSize` | `int` | |

#### `goals`

Learning targets with optional Hebrew calendar date support.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | |
| `targetPercent` | `int` | |
| `targetDate` | `DateTime` | |
| `description` | `String` | |
| `dateType` | `String` | `gregorian` or `hebrew` |

#### `rewards`

Gamification rewards. Can apply globally (null `curriculumId`) or to a specific curriculum.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `title` | `String` | |
| `description` | `String` | |
| `pointsThreshold` | `int` | |
| `isRevealed` | `bool` | |
| `isEarned` | `bool` | |
| `earnedAt` | `DateTime` | Nullable |
| `curriculumId` | `String` | Nullable (global if null) |

#### `streaks`

Daily learning streak tracking per profile.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `currentStreak` | `int` | |
| `maxStreak` | `int` | |
| `lastCompletionDate` | `DateTime` | |

#### `point_configs`

Configurable point values per stage. Defaults: Learn = 10, Chazara 1 = 5, Chazara 2 = 3.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | Unique with profileId, stageOrder |
| `stageOrder` | `int` | Unique with profileId, curriculumId |
| `points` | `int` | Must be > 0 |

#### `learning_ledger`

**Append-only.** Detailed audit log of all learning activity with display names and manual-entry tracking.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | |
| `unitType` | `String` | |
| `unitIdentifier` | `String` | |
| `unitDisplayNameHe` | `String` | |
| `unitDisplayNameEn` | `String` | |
| `trackType` | `String` | |
| `trackId` | `String` | |
| `completedAt` | `DateTime` | |
| `completionNumber` | `int` | |
| `markedBy` | `String` | |
| `isManual` | `bool` | |

#### `curriculum_scopes`

Defines the scope boundaries for a curriculum per profile.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `curriculumId` | `String` | Unique with profileId, scopeLevel, scopeValue |
| `scopeLevel` | `String` | Unique with profileId, curriculumId, scopeValue |
| `scopeValue` | `String` | Unique with profileId, curriculumId, scopeLevel |
| `createdAt` | `DateTime` | |

#### `profile_programs`

Links a profile to a learning program per curriculum type.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | PK, FK |
| `curriculumType` | `String` | PK, unique with profileId |
| `programId` | `int` | FK to `learning_programs` |

#### `test_scores`

Records assessment results per profile.

| Column | Type | Constraints |
|---|---|---|
| `profileId` | `int` | FK |
| `programId` | `int` | FK |
| `testDateId` | `int` | Nullable FK to `test_dates` |
| `scorePercentage` | `double` | |
| `notes` | `String` | |

---

### System Tables

These tables serve infrastructure purposes and do not scope to a profile.

#### `sync_queue`

FIFO offline operation queue with retry tracking.

| Column | Type | Constraints |
|---|---|---|
| `operationType` | `String` | |
| `payload` | `String` | JSON |
| `queuedAt` | `DateTime` | |
| `retryCount` | `int` | |
| `lastError` | `String` | |

#### `text_cache`

Local cache of fetched Sefaria text content.

| Column | Type | Constraints |
|---|---|---|
| `sefariaRef` | `String` | Primary key |
| `hebrewText` | `String` | |
| `englishText` | `String` | |
| `fetchedAt` | `DateTime` | |

#### `text_download_statuses`

Tracks bulk text download state per curriculum.

| Column | Type | Constraints |
|---|---|---|
| `curriculumId` | `String` | Primary key |
| `itemCount` | `int` | |
| `textVersion` | `String` | |
| `downloadedAt` | `DateTime` | |
| `storedItemCount` | `int` | |

#### `content_download_statuses`

Tracks content download state per curriculum and language.

| Column | Type | Constraints |
|---|---|---|
| `curriculumId` | `String` | PK |
| `languageCode` | `String` | PK |
| `contentVersion` | `String` | |
| `itemCount` | `int` | |
| `downloadedAt` | `DateTime` | |

---

### Program Tables

#### `learning_programs`

Immutable preset program definitions. The system does not modify these at runtime.

| Column | Type | Constraints |
|---|---|---|
| `id` | `int` | Primary key |
| `name` | `String` | Unique |
| `displayName` | `String` | |
| `description` | `String` | |
| `curriculumType` | `String` | |
| `isActive` | `bool` | |
| `stagesConfig` | `String` | JSON |
| `hasTests` | `bool` | |
| `testConfig` | `String` | JSON |

#### `test_dates`

Scheduled assessment dates for a program.

| Column | Type | Constraints |
|---|---|---|
| `id` | `int` | Primary key |
| `programId` | `int` | FK to `learning_programs` |
| `testDate` | `DateTime` | |
| `materialDescription` | `String` | |

---

## DAO Operations

Each table has a corresponding DAO. The table below summarizes the key behavioral patterns.

| DAO | Pattern | Key Operations |
|---|---|---|
| `CompletionDao` | **Append-only** | Insert with dedup check, aggregate counts, track breakdown queries. No update or delete. |
| `LearningLedgerDao` | **Append-only** | Insert, grouped queries by curriculum/track/date, completion counting. No update or delete. |
| `BookmarkDao` | **Upsert (LWW)** | Insert or update bookmark position. Last-write-wins merge on sync. |
| `StageDao` | **Replace-all (LWW)** | Transactional replace of all stages for a curriculum. Last-write-wins on sync. |
| `GoalDao` | **Upsert (LWW)** | Insert or update goal. Last-write-wins merge on sync. |
| `RewardDao` | **Upsert (LWW)** | Insert or update reward. Most-progress-wins tiebreaker in addition to LWW. |
| `StreakDao` | **Upsert** | Create-if-not-exists, update on activity. |
| `ProfileDao` | **CRUD + watch** | Full CRUD with reactive stream. Enforces max 10 profiles per account. |
| `TrackDao` | **Activate/deactivate** | Toggle track state. Personal track cannot deactivate. Initialize defaults on curriculum activation. |
| `ActiveCurriculumDao` | **Activate/deactivate** | TOCTOU-safe transactional activation and deactivation. Enforces minimum 1 active. |
| `SyncQueueDao` | **FIFO queue** | Enqueue, dequeue, retry tracking with error capture. |
| All others | **Standard CRUD** | Basic create, read, update, delete operations. |

---

## Querying Patterns

### Profile-Scoped Queries

Every query against profile-scoped tables filters by `profileId`. This ensures strict data isolation between learners within the same account.

```dart
// All profile-scoped DAOs accept profileId as the first parameter
final completions = await completionDao.getCompletions(profileId);
final bookmarks = await bookmarkDao.getBookmarks(profileId);
```

### Completion Dedup Key

The completions table uses a composite dedup key to prevent duplicate entries:

```
(curriculumId, sefariaRef, stageId, trackType, completedAt)
```

The insert operation checks this key before writing. If a matching row exists, the DAO skips the insert silently.

### Bookmark Lookups

Bookmark queries use the `(profileId, curriculumId, trackType)` triple to locate the current reading position:

```dart
// Retrieve the bookmark for a specific curriculum and track
final bookmark = await bookmarkDao.getBookmark(
  profileId,
  curriculumId,
  trackType,
);
```

### Stream/Watch Queries for Reactive UI

Drift provides reactive query streams that emit new results whenever underlying data changes. Use `watch` variants for any UI that must stay current:

```dart
// Stream of all active curricula — UI rebuilds automatically on change
final stream = activeCurriculumDao.watchActiveCurricula(profileId);

// Stream of profiles — drives the profile picker
final profiles = profileDao.watchProfiles(accountId);
```

Riverpod `StreamProvider` instances wrap these Drift streams to integrate with the widget tree.

---

## Firestore Collections

Remote data organizes under profile-scoped paths within each authenticated user document.

```
users/{uid}/
  profile/data                                          # Account-level profile
  profiles/{profileId}/
    completions/{autoId}                                # Append-only
    bookmarks/{curriculumId}_{trackType}                # LWW merge
    settings/{curriculumId}                             # LWW merge
    goals/{id}                                          # LWW merge
    rewards/{id}                                        # LWW merge
    streak/data                                         # Single document
    active_curricula/data                               # Active curriculum state
```

| Collection | Merge Strategy | Notes |
|---|---|---|
| `completions` | Append-only | Each completion creates a new document with an auto-generated ID. |
| `bookmarks` | Last-write-wins | Document ID encodes curriculum and track: `{curriculumId}_{trackType}`. |
| `settings` | Last-write-wins | Per-curriculum configuration (stages, point configs). |
| `goals` | Last-write-wins | |
| `rewards` | Last-write-wins | |
| `streak` | Single document | One `data` document per profile. |
| `active_curricula` | Single document | One `data` document per profile. |
| `profile/data` | Account-level | Not nested under `profiles/`. Stores account-wide settings. |

---

## Sync & Conflict Resolution

The app operates offline-first with eventual consistency via Firestore sync.

1. **Local writes** apply immediately to the Drift database.
2. **Outbound sync** enqueues operations in `sync_queue` (FIFO) with automatic retry.
3. **Inbound sync** applies remote changes using the merge strategy for each table:
   - **Append-only** (completions, ledger): the system inserts remote records if they pass dedup.
   - **LWW** (bookmarks, goals, rewards, settings): the record with the latest timestamp wins.
   - **Most-progress-wins** (rewards): if timestamps tie, the more-progressed state persists (e.g., `isEarned` beats `isRevealed`).
4. **TOCTOU safety**: `active_curricula` mutations run inside transactions to prevent race conditions when activating or deactivating curricula.

---

## Migration History

The schema stands at **v15** with incremental migrations from v1. Each migration runs sequentially on app startup when the local database version falls behind the current schema version.

| Version Range | Summary |
|---|---|
| v1 -- v3 | Core tables: `user_profiles`, `profiles`, `completions`, `bookmarks`, `sync_queue` |
| v4 -- v6 | Learning features: `stage_definitions`, `goals`, `rewards`, `streaks`, `point_configs` |
| v7 -- v9 | Content management: `text_cache`, `text_download_statuses`, `learning_order` |
| v10 -- v12 | Multi-track support: `curriculum_tracks`, `active_curricula`, `curriculum_scopes` |
| v13 -- v14 | Programs and assessments: `learning_programs`, `profile_programs`, `test_dates`, `test_scores` |
| v15 | Audit trail: `learning_ledger`, `content_download_statuses` |

Drift handles migrations automatically via its `MigrationStrategy`. The app never drops tables or performs destructive migrations -- each version only adds tables, columns, or indexes.
