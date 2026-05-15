---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/two-database-drift-architecture.md
  - _bmad-output/planning-artifacts/architecture-offline-v2.md
  - _bmad-output/planning-artifacts/calendar-cycle-computation-analysis.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
---

# learning-tracker - Epic 19 Breakdown

## Overview

This document provides the complete epic and story breakdown for Epic 19: Offline-First Architecture & Two-Database Split, decomposing the requirements from the PRD, Architecture, and planning artifacts into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR88: Users access all core features without network connectivity (offline-first)
- FR89: System pushes local writes to Firestore asynchronously (queued if offline)
- FR93: System retries failed syncs with exponential backoff
- FR99: PINs are device-local only (never synced)
- FR106: System calculates Hebrew calendar dates using kosher_dart
- FR18: System syncs completions to Firestore via push-on-write
- FR26: System syncs stage definitions to Firestore per curriculum

### Non-Functional Requirements

- NFR8: Background sync operations minimize battery drain (<2% daily)
- NFR14: App state survives device restarts without loss of unsynchronized data
- NFR19: Sync retries with exponential backoff (max 5 retries)
- NFR20: Sync conflicts: additive for completions, last-write-wins for mutable
- NFR23: Offline operation identical UX to online for core features
- NFR25: Background sync battery-efficient, non-blocking
- NFR26: Network restoration triggers sync automatically
- NFR27: Sync respects Android battery saver mode

### Additional Requirements

- D-TWODB: Two separate SQLite databases — Content DB (read-only, 4 tables) + User DB (read-write, 20+ tables)
- D-OFFLINE: All content bundled in APK (~52K items + 30K calendar rows)
- D2-v3: Hard-tier auth (cloud-born vs local-born), tier set at signup by network state and immutable. Every user has an email+password account; local-born uses argon2id hash in SQLite. Supersedes the prior "optional UUID, Firebase optional" model. See `architecture-offline-v2.md`.
- D4-v3: SyncEngine activation gated by tier (`tier == cloudBorn`), not connectivity. Conflict resolution is per-data-type: LWW for settings, merge-forward for progress, append-only event log for streaks/XP.
- Seed DB: `tool/seed_content_db.dart` builds pre-built Content DB, ships as `assets/seed.db.gz`
- Content DB upgrade: Compare SeedMetadata.version, atomic file replacement on app update
- Calendar bugs: 7 bugs in CalendarProgramRegistry — 6 of 12 programs broken
- Startup hardening: Target ~140ms to usable app, zero network calls at startup
- Cross-DB references: String identifiers only, no hard FKs, application-level lookups
- Content DB resilience: Handle corruption, missing files, stale cross-DB references
- APK size management: Measure and budget seed DB size

### UX Design Requirements

- UX-DR1: App must launch to usable state without hanging on network calls — Firebase init is background/deferred, no startup spinners waiting on network
- UX-DR2: Content unavailable states must show graceful fallbacks (ref string + message), not blank screens
- UX-DR3-v2: Signup is mandatory at first launch. Tier (cloud-born vs local-born) is auto-determined by network state at signup. Local-born signup requires explicit "no backup" acknowledgment. Upgrade (local → cloud) is available later via Settings with a guided merge flow.
- UX-DR4: Offline indicator — subtle top banner for cloud-born users temporarily offline. Persistent "no backup" badge in profile area for local-born users (always visible).
- UX-DR5: First-launch decompression shows brief loading indicator (< 5 sec)

### FR Coverage Map

- FR88 → Stories 19.1-19.6, 19.11 (offline-first across all features)
- FR89 → Story 19.8 (SyncEngine conditional activation)
- FR93 → Story 19.8 (retry logic in SyncEngine)
- FR99 → Unchanged (PINs already device-local)
- FR106 → Story 19.4 (Local Calendar Engine)
- FR18 → Story 19.8, 19.9 (sync completions)
- FR26 → Story 19.8, 19.9 (sync stage definitions)
- NFR23 → Stories 19.2-19.6, 19.12 (identical offline UX)
- NFR25 → Story 19.8 (battery-efficient sync)
- NFR26 → Story 19.8 (auto-sync on network restore)

## Epic List

### Epic 19: Offline-First Architecture & Two-Database Split (DNI-182)

Invert the app from "online with offline queue" to local-first by default with transparent sync when internet is available. Every feature works fully without network after installation.

**FRs covered:** FR88, FR89, FR93, FR99, FR106, FR18, FR26
**NFRs covered:** NFR8, NFR14, NFR19, NFR20, NFR23, NFR25, NFR26, NFR27

> ⚠️ **Partial supersede by Epic 23 (DNI-223, originally filed as "Epic 20" and renamed 2026-04-19).** Epic 19 stories 19.5 (local-first auth abstraction) and 19.7 (optional account creation in Settings) implement the prior "anonymous localUid + optional deferred account" model, which was superseded on 2026-04-10 by the hard-tier auth model in `architecture-offline-v2.md`. Those two stories did not ship in their original form. Epic 23 replaced them. All other Epic 19 stories — two-database split, seed DB, calendar engine, startup hardening, SyncEngine conditional activation, content DB resilience, E2E testing — remain valid and canonical.

### Epic 23: Offline-First Architecture v2 — Hard-Tier Auth Refactor (DNI-223)

> **Status:** Done — completed 2026-04-15. Originally filed in Linear as "Epic 20"; renamed to Epic 23 on 2026-04-19 to resolve the DNI-210 / DNI-223 epic-number collision.

Refactored auth to the hard-tier cloud-born / local-born model per `architecture-offline-v2.md`. Every user has a real email+password account; tier is set at signup by network state and is immutable. Supersedes the March 2026 anonymous-localUid architecture and the Epic 19 stories 19.5 and 19.7.

**Linear:** [DNI-223 — Epic 23: Offline-First Architecture v2 — Hard-Tier Auth Refactor](https://linear.app/dniasoff/issue/DNI-223)
**Gates (now resolved):** Was gating Epic 19 shipping in its original form
**Scope delivered:** Auth domain (dropped `AppAuthState` sealed hierarchy), DB schema (dropped `localUid`, added `passwordHash` + `tier`), onboarding (mandatory signup at first launch), settings (guided upgrade flow per v2 §4.3 — `UpgradeToCloudRoute`), sync engine (tier-gated activation, conflict resolution per v2 §4.1 with event-log streaks/XP)
**Canonical doc:** [`docs/planning/architecture-offline-v2.md`](architecture-offline-v2.md)

---

## Epic 19: Offline-First Architecture & Two-Database Split

Goal: The app works fully — every feature, every curriculum, every calendar program — without ever touching the network. Sync is a silent bonus, not a requirement.

### Story 19.1: Fix Calendar Registry Bugs (DNI-183)

As a developer,
I want all 12 calendar programs correctly configured in the registry,
So that the seed tool can validate cycle data and all programs work for users.

**Acceptance Criteria:**

**Given** `nach_yomi` is configured with `apiSource: 'sefaria'`
**When** the calendar service tries to fetch Nach Yomi data
**Then** it fails because Sefaria doesn't have Nach Yomi
**And** the fix changes `apiSource` to `'hebcal'` with flag `nyomi=on`

**Given** `mishna_yomit` has `apiKey: 'Mishnah Yomit'`
**When** matching against Sefaria's `title.en: 'Daily Mishnah'`
**Then** it never matches
**And** the fix updates `apiKey` to `'Daily Mishnah'`

**Given** Hebcal client is missing `dcc=on` and `dksa=on` flags
**When** fetching Chofetz Chaim and Kitzur SA programs
**Then** zero data is returned
**And** the fix adds the missing flags to the Hebcal request

**Priority:** Urgent | **Blocks:** 19.3, 19.4

---

### Story 19.2: Two-Database Split (DNI-184)

As a developer,
I want the monolithic AppDatabase split into ContentDatabase (read-only) and UserDatabase (read-write),
So that content can be replaced safely on app updates without risking user data.

**Acceptance Criteria:**

**Given** the current monolithic AppDatabase with 26 tables
**When** the split is complete
**Then** ContentDatabase has 4 tables (TextCache, CalendarCycles, LearningPrograms, SeedMetadata)
**And** UserDatabase has ~21 tables (all user/progress/sync tables)
**And** both databases open with separate `.sqlite` files
**And** all DAOs reference the correct database type
**And** SeedManager handles first-launch extraction and version-based replacement
**And** cross-DB lookups handle missing refs gracefully

**Priority:** Urgent | **Blocks:** 19.2b, 19.3, 19.4, 19.5, 19.8

---

### Story 19.2b: Content DB Runtime Upgrade Flow (DNI-208)

As a user who updates the app,
I want the Content DB to seamlessly upgrade to the latest bundled version,
So that I always have the most current text content and calendar data.

**Acceptance Criteria:**

**Given** the app is updated with a newer `seed.db.gz`
**When** the app launches
**Then** SeedManager detects the version mismatch
**And** atomically replaces the old content.db with the new version
**And** completes in < 5 seconds

**Given** the app is killed during decompression
**When** the app next launches
**Then** it detects the `.bak` file and rolls back
**And** retries the upgrade from scratch

**Given** the seed asset is corrupted
**When** decompression fails
**Then** the app falls back to the existing content.db (if available)
**And** shows a user-facing error if no content.db exists

**Priority:** High | **Requires:** 19.2 | **Blocks:** 19.4

---

### Story 19.3: Seed Database Build Tool (DNI-185)

As a developer,
I want a CLI tool that builds the pre-built Content DB,
So that all text content and calendar data ships in the APK.

**Acceptance Criteria:**

**Given** the seed tool runs
**When** it completes
**Then** `seed.db.gz` contains ~52,528 TextCache rows (Hebrew + English)
**And** ~30,684 CalendarCycles rows (12 programs, 2024-2030)
**And** 9 LearningPrograms rows
**And** SeedMetadata with version, build date, content hash
**And** compressed size is < 80MB
**And** `--validate-only` mode works for CI
**And** `--size-report` outputs table-level size breakdown

**Priority:** High | **Requires:** 19.1, 19.2

---

### Story 19.4: Local Calendar Engine (DNI-193)

As a user,
I want all 12 calendar programs to work without internet,
So that I can see today's learning assignment offline.

**Acceptance Criteria:**

**Given** the Content DB has CalendarCycles data
**When** a user queries any of the 12 calendar programs
**Then** `LocalCalendarEngine` returns the correct ref from the local table
**And** no API calls are made
**And** the result matches what Sefaria/Hebcal would return

**Priority:** High | **Requires:** 19.2b, 19.3

---

### Story 19.5: Local-First Auth Abstraction Layer (DNI-186)

As a user,
I want to use the app immediately without creating an account,
So that I can start learning without internet or sign-in barriers.

**Acceptance Criteria:**

**Given** a fresh install with no network
**When** the user launches the app
**Then** a local UUID is generated and stored
**And** the app goes directly to onboarding (no sign-in wall)
**And** `AuthStateNotifier` emits `LocalAuthState` synchronously

**Given** an existing Firebase user from dev/testing
**When** the schema migration runs
**Then** `firebaseUid` is copied to `localUid`, `hasAccount` set to true
**And** the migration is atomic (single transaction)

**Given** Firebase SDK is not ready on startup
**When** user has `hasAccount == true` but `currentUser` is null
**Then** app emits `LocalAuthState` gracefully
**And** SyncEngine stays dormant

**Priority:** Urgent | **Requires:** 19.2 | **Blocks:** 19.6, 19.7, 19.8

---

### Story 19.6: Startup Sequence Hardening (DNI-187)

As a user,
I want the app to start instantly regardless of network state,
So that I never wait for network checks or Firebase initialization.

**Acceptance Criteria:**

**Given** the app launches in airplane mode
**When** startup completes
**Then** the app is usable in ~140ms
**And** zero network calls are made
**And** `Firebase.initializeApp()` is deferred and wrapped in try/catch
**And** `GoogleSignIn.initialize()` is deferred until user chooses Google sign-in
**And** `ConnectivityService` DNS timeout is eliminated from startup path

**Priority:** High | **Requires:** 19.5

---

### Story 19.7: Optional Account Creation in Settings (DNI-188)

As a user,
I want to optionally create an account from Settings,
So that I can enable multi-device sync and cloud backup when I'm ready.

**Acceptance Criteria:**

**Given** a local-only user
**When** they navigate to Settings and tap "Create Account"
**Then** they can create a Firebase account (magic link auth)
**And** local data is migrated: `localUid` preserved, `firebaseUid` set, `hasAccount = true`
**And** SyncEngine activates and pushes all local data to Firestore

**Priority:** High | **Requires:** 19.5, Epic 18 (DNI-164, DNI-165)

---

### Story 19.8: SyncEngine Conditional Activation (DNI-189)

As a user with an account,
I want sync to activate transparently when I have internet,
So that my data is backed up without me thinking about it.

**Acceptance Criteria:**

**Given** a local-only user (no account)
**When** SyncEngine is checked
**Then** it is not instantiated, offline queue is disabled, status is `SyncStatus.localOnly`

**Given** a user with account but no internet
**When** SyncEngine is checked
**Then** it is instantiated but dormant, writes are queued, status is `SyncStatus.offline`

**Given** a user with account and internet
**When** SyncEngine is checked
**Then** full sync is active: push-on-write, pull-on-launch, foreground listeners

**Priority:** High | **Requires:** 19.5

---

### Story 19.9: Multi-Device Sync & Efficient Real-Time Sync (DNI-190)

As a user with multiple devices,
I want all my learning data synced across devices in real-time,
So that I can switch between phone and tablet seamlessly.

**Acceptance Criteria:**

**Given** Device A has local data and creates an account
**When** Device B signs in with the same account
**Then** `pullOnLaunch()` fetches all data from Firestore
**And** both devices show identical data

**Given** a user marks an item complete on Device A
**When** Device B has foreground listener active
**Then** the completion appears on Device B within seconds

**Priority:** High | **Requires:** 19.8

---

### Story 19.10: Navigation & State Cleanup (DNI-191)

As a developer,
I want dead code, deprecated screens, and orphaned providers removed,
So that the codebase is clean after the offline-first overhaul.

**Acceptance Criteria:**

**Given** the offline-first architecture is complete
**When** cleanup runs
**Then** `ModeSelectionScreen` and old `AccountCreationScreen` are removed
**And** orphaned providers and stale SharedPreferences keys are cleaned
**And** route guards are updated to use `LocalAuthGuard`
**And** no dead imports or unused files remain

**Priority:** Low | **Requires:** 19.5, 19.7

---

### Story 19.11: End-to-End Offline Integration Testing (DNI-192)

As a QA engineer,
I want comprehensive integration tests for offline-first functionality,
So that I can verify the entire architecture works end-to-end.

**Acceptance Criteria:**

**Given** a fresh install on airplane-mode device
**When** the user completes onboarding and uses all features
**Then** all 7 curricula browsable with Hebrew/English text offline
**And** all 12 calendar programs show correct daily learning offline
**And** no loading spinners waiting for network in core flows
**And** app never crashes or shows error due to missing network

**Priority:** High | **Requires:** All previous stories

---

### Story 19.12: Content DB Resilience & Error Recovery (DNI-209)

As a user,
I want the app to automatically recover from Content DB errors,
So that I never lose access to my learning progress.

**Acceptance Criteria:**

**Given** the Content DB is corrupted
**When** a query fails
**Then** `PRAGMA integrity_check` runs
**And** the app re-extracts from bundled seed automatically
**And** recovery is silent to the user

**Given** a user has completions referencing content not in current Content DB
**When** they view their progress history
**Then** they see the ref string + "Content unavailable" (not a crash or blank screen)

**Given** the Content DB file is missing
**When** the app launches
**Then** it automatically re-extracts from bundled seed (no crash)

**Priority:** Medium | **Requires:** 19.2, 19.2b

---

## Dependency Graph

```
DNI-183 (19.1 Calendar Bugs)
    │
    ▼
DNI-184 (19.2 Two-DB Split) ──────────────────┐
    │                                           │
    ├──► DNI-208 (19.2b Content DB Upgrade)     │
    │        │                                  │
    │        ▼                                  │
    ├──► DNI-185 (19.3 Seed Tool) ──► DNI-193 (19.4 Local Calendar)
    │
    ├──► DNI-186 (19.5 Local Auth)
    │        │
    │        ├──► DNI-187 (19.6 Startup Hardening)
    │        │
    │        ├──► DNI-188 (19.7 Account Creation)
    │        │
    │        └──► DNI-189 (19.8 SyncEngine)
    │                 │
    │                 └──► DNI-190 (19.9 Multi-Device Sync)
    │
    ├──► DNI-209 (19.12 Resilience)
    │
    ├──► DNI-191 (19.10 Nav Cleanup)
    │
    └──► DNI-192 (19.11 E2E Testing)
```

## Summary

| # | Story | DNI | Priority | Status |
|---|-------|-----|----------|--------|
| 19.1 | Fix Calendar Registry Bugs | DNI-183 | Urgent | Backlog |
| 19.2 | Two-Database Split | DNI-184 | Urgent | Backlog |
| 19.2b | Content DB Runtime Upgrade Flow | DNI-208 | High | Backlog |
| 19.3 | Seed Database Build Tool | DNI-185 | High | Backlog |
| 19.4 | Local Calendar Engine | DNI-193 | High | Backlog |
| 19.5 | Local-First Auth Abstraction Layer | DNI-186 | Urgent | Backlog |
| 19.6 | Startup Sequence Hardening | DNI-187 | High | Backlog |
| 19.7 | Optional Account Creation (Magic Link) | DNI-188 | High | Backlog |
| 19.8 | SyncEngine Conditional Activation | DNI-189 | High | Backlog |
| 19.9 | Multi-Device Sync | DNI-190 | High | Backlog |
| 19.10 | Navigation & State Cleanup | DNI-191 | Low | Backlog |
| 19.11 | E2E Offline Integration Testing | DNI-192 | High | Backlog |
| 19.12 | Content DB Resilience & Error Recovery | DNI-209 | Medium | Backlog |

**Total: 13 stories (11 existing + 2 new)**

> ⚠️ **The auto-generated section below is stale as of 2026-04-19.** Last sync was before the DNI-223 rename from "Epic 20" → "Epic 23" and before Epic 20's 12 stories (DNI-211–DNI-222) were canceled. Re-run `tool/linear-sync.sh sync` to refresh. Until then, trust [`docs/linear-status.md`](../linear-status.md) for current epic status.

<!-- AUTO:EPIC-LIST-START -->
## Epic List

> **This section is a read-only copy of data from Linear, auto-generated by `tool/linear-sync.sh`.** Do not edit — changes will be overwritten on next sync. To modify stories, update them in Linear and run `tool/linear-sync.sh sync`.

### Epic 1 — Foundation & Infrastructure (DNI-5, 12 stories)

- **DNI-19** — [1.1] Initialize Flutter Project & Directory Structure *(Done)*
- **DNI-20** — [1.2] Drift Database Schema & DAOs *(Done)*
- **DNI-21** — [1.3] Firebase Integration (Auth + Firestore) *(Done)*
- **DNI-22** — [1.4] Sefaria API Client & Curriculum Content Fetchers *(Done)*
- **DNI-23** — [1.5] Navigation Shell & Routing *(Done)*
- **DNI-24** — [1.6] Core State Management & Provider Infrastructure *(Done)*
- **DNI-25** — [1.7] Logging & Observability *(Done)*
- **DNI-26** — [1.8] CI/CD & Testing Infrastructure *(Done)*
- **DNI-27** — [1.9] Sync Engine Foundation *(Done)*
- **DNI-28** — [1.10] Theme & Core UI Components *(Done)*
- **DNI-29** — [1.11] Security Infrastructure *(Done)*
- **DNI-30** — [1.12] Hebrew Calendar & Date Utilities *(Done)*

### Epic 2 — Content Import & Browsing (DNI-6, 6 stories)

- **DNI-31** — [2.1] Sefaria Content Import Pipeline *(Done)*
- **DNI-32** — [2.2] Content Hierarchy Browsing *(Done)*
- **DNI-33** — [2.3] Content Text Display *(Done)*
- **DNI-34** — [2.4] Curriculum Activation & Management *(Done)*
- **DNI-79** — [2.5]: Bundled Content JSON & Dev Seed Script *(Done)*
- **DNI-80** — [2.6] Bundled Text Content & Nikud Toggle *(Done)*

### Epic 3 — Core Learning Cycle (DNI-7, 3 stories)

- **DNI-35** — [3.1] Mark Completion (Per-Stage, Per-Track) *(Done)*
- **DNI-36** — [3.2] Completion Log & History *(Done)*
- **DNI-37** — [3.3] Bookmark Management *(Done)*

### Epic 4 — Multi-Track Learning (DNI-8, 3 stories)

- **DNI-38** — [4.1] Track Management *(Done)*
- **DNI-39** — [4.2] Track Assignment & Duplicate Prevention *(Done)*
- **DNI-40** — [4.3] Track-Specific Progress Views *(Done)*

### Epic 5 — Configurable Stages & Learning Order (DNI-9, 2 stories)

- **DNI-41** — [5.1] Stage Definition Configuration *(Done)*
- **DNI-42** — [5.2] Drag-and-Drop Learning Order *(Done)*

### Epic 6 — Smart Scheduler (DNI-10, 5 stories)

- **DNI-43** — [6.1] Parametric Scheduler Engine *(Done)*
- **DNI-44** — [6.2] Daily Task Generation & Display *(Done)*
- **DNI-45** — [6.3] Goal Management (Per-Curriculum Deadlines) *(Done)*
- **DNI-46** — [6.4] Pace Tracking *(Done)*
- **DNI-47** — [6.5] Cross-Curriculum Daily Schedule Composer *(Done)*

### Epic 7 — Dashboard & Progress (DNI-11, 3 stories)

- **DNI-48** — [7.1] Cross-Curriculum Dashboard *(Done)*
- **DNI-49** — [7.2] Per-Curriculum Progress Views *(Done)*
- **DNI-50** — [7.3] Progress Charts & Statistics *(Done)*

### Epic 8 — Gamification & Engagement (DNI-12, 7 stories)

- **DNI-51** — 8.1: Points System *(Canceled)*
- **DNI-52** — 8.2: Streak Tracking *(Canceled)*
- **DNI-53** — 8.3: Mystery Rewards System *(Canceled)*
- **DNI-81** — [8.1] Per-Curriculum Points System *(Done)*
- **DNI-82** — [8.2] Global Streak Tracking *(Done)*
- **DNI-83** — [8.3] Mystery Rewards System *(Done)*
- **DNI-84** — [8.4] Completion Feedback & Animations *(Done)*

### Epic 9 — Onboarding Flow (DNI-13, 10 stories)

- **DNI-54** — 9.1: Welcome & User Mode Selection *(Canceled)*
- **DNI-55** — 9.2: Curriculum Selection *(Canceled)*
- **DNI-56** — 9.3: Per-Curriculum Goal Setup *(Canceled)*
- **DNI-57** — 9.4: Bulk Mark Prior Completions *(Canceled)*
- **DNI-58** — 9.5: Initial Rewards Setup (Child Mode) *(Canceled)*
- **DNI-85** — [9.1] Account Creation & Mode Selection *(Done)*
- **DNI-86** — [9.2] Curriculum Selection & Content Import *(Done)*
- **DNI-87** — [9.3] Per-Curriculum Goal Setup *(Done)*
- **DNI-88** — [9.4] Bulk Mark Prior Completions *(Done)*
- **DNI-89** — [9.5] Initial Rewards Setup (Child Mode) *(Done)*

### Epic 10 — Parent Mode (DNI-14, 11 stories)

- **DNI-59** — 10.1: Parent PIN Setup & Authentication *(Canceled)*
- **DNI-60** — 10.2: Parent Dashboard *(Canceled)*
- **DNI-61** — 10.3: Reward Management (CRUD) *(Canceled)*
- **DNI-62** — 10.4: Point Value Configuration *(Canceled)*
- **DNI-63** — 10.5: Track Management (Parent) *(Canceled)*
- **DNI-64** — 10.6: Parent Analytics & Progress Views *(Canceled)*
- **DNI-90** — [10.1] Parent PIN Setup & Authentication *(Done)*
- **DNI-91** — [10.2] Parent Dashboard & Analytics *(Done)*
- **DNI-92** — [10.3] Reward Catalog Management *(Done)*
- **DNI-93** — [10.4] Point Value Configuration *(Done)*
- **DNI-94** — [10.5] Parent Track Management *(Done)*

### Epic 11 — Tutor Mode (DNI-15, 6 stories)

- **DNI-65** — 11.1: Tutor PIN Setup & Authentication *(Canceled)*
- **DNI-66** — 11.2: Tutor Dashboard *(Canceled)*
- **DNI-67** — 11.3: Completion History Views (Tutor) *(Canceled)*
- **DNI-68** — 11.4: Chazara Due & Progress Views (Tutor) *(Canceled)*
- **DNI-95** — [11.1] Tutor PIN Setup & Authentication *(Done)*
- **DNI-96** — [11.2] Tutor Dashboard (Read-Only) *(Done)*

### Epic 12 — Notifications (DNI-16, 7 stories)

- **DNI-100** — [12.4] Notification Preferences & Shabbos Mode *(Done)*
- **DNI-69** — 12.1: Daily Learning Reminders *(Canceled)*
- **DNI-70** — 12.2: Streak Protection Alerts *(Canceled)*
- **DNI-71** — 12.3: Reward Milestone Notifications *(Canceled)*
- **DNI-97** — [12.1] Daily Learning Reminders *(Done)*
- **DNI-98** — [12.2] Streak Protection Alerts *(Done)*
- **DNI-99** — [12.3] Reward Milestone Notifications *(Done)*

### Epic 13 — Cloud Sync (DNI-17, 7 stories)

- **DNI-101** — [13.1] Push-on-Write with Offline Queuing *(Done)*
- **DNI-102** — [13.2] Pull-on-Launch Merge *(Done)*
- **DNI-103** — [13.3] Real-Time Foreground Listeners *(Done)*
- **DNI-104** — [13.4] New Device Data Restore *(Done)*
- **DNI-72** — 13.1: Push-on-Write Sync *(Canceled)*
- **DNI-73** — 13.2: Pull-on-Launch Sync *(Canceled)*
- **DNI-74** — 13.3: Foreground Real-Time Listeners *(Canceled)*

### Epic 14 — Settings (DNI-18, 6 stories)

- **DNI-105** — [14.1] General Settings & User Profile *(Done)*
- **DNI-107** — [14.3] Account Management *(Done)*
- **DNI-75** — 14.1: General Settings *(Canceled)*
- **DNI-76** — 14.2: Notification Preferences *(Canceled)*
- **DNI-77** — 14.3: Data Export & Import *(Canceled)*
- **DNI-78** — 14.4: Account Management *(Canceled)*

### Epic 15 — Multi-Profile & Learning Program System (DNI-108, 12 stories)

- **DNI-109** — 15.1: Multi-Profile Data Model & Migration *(Done)*
- **DNI-110** — 15.2: Profile Picker & Management UI *(Done)*
- **DNI-112** — 15.4: Learning Program Preset Model & Seed Data *(Done)*
- **DNI-113** — 15.5: Expanded Stage Scheduling Model *(Done)*
- **DNI-114** — 15.6: Learning Process Wizard *(Done)*
- **DNI-116** — 15.8: Revised Onboarding Flow *(Done)*
- **DNI-117** — 15.9: Program Management in Settings *(Done)*
- **DNI-119** — 15.11: Profile-Scoped Providers & Sync *(Done)*
- **DNI-120** — 15.12: UI Polish — AppBar FittedBox & Title Handling *(Done)*
- **DNI-123** — 15.15: Curriculum Scope Selection (Seder/Masechta/Sefer) *(Done)*
- **DNI-124** — 15.16: Lifetime Learning Ledger — Data Model & Completion Logic *(Done)*
- **DNI-125** — 15.17: My Learning Journey Screen *(Done)*

### Epic 18 — Onboarding & Track Management Overhaul (DNI-128, 25 stories)

- **DNI-111** — 18.15: New Curricula Support (Nach, Mussar, Halacha) *(Done)*
- **DNI-115** — 18.16: Enhanced Bulk Mark Tool *(Done)*
- **DNI-118** — 18.17: Dirshu Test Tracking *(Done)*
- **DNI-122** — 18.18: Test Suite Health — Fix Failures & Harden *(Done)*
- **DNI-129** — 16.1: Pace-Based Goal Mode *(Done)*
- **DNI-130** — 16.2: Study Day Configuration *(Done)*
- **DNI-131** — 16.3: Dashboard Pace & Progress Integration *(Done)*
- **DNI-132** — 16.4: Per-Item Review Count Display *(Done)*
- **DNI-133** — 16.5: Onboarding Goal & Study Day Steps *(Done)*
- **DNI-134** — 16.6: Dashboard Design & Experience Polish *(Done)*
- **DNI-164** — 18.13: Create Account Screen Layout Fix *(Done)*
- **DNI-165** — 18.14: Magic Link Authentication (Remove Password Fields) *(Done)*
- **DNI-169** — 18.4: Hebrew Terms for Chazara & Curriculum Names *(Done)*
- **DNI-170** — 18.5: Track Editing from Settings *(Done)*
- **DNI-171** — 18.6: Child Mode Onboarding & Post-Setup Rewards *(Done)*
- **DNI-172** — 18.7: Navigation, State Cleanup & Deprecated Screen Removal *(Done)*
- **DNI-173** — 18.8: Instant Mark Complete (Performance Fix) *(Done)*
- **DNI-174** — 18.9: Prevent Duplicate Profile Names *(Done)*
- **DNI-175** — 18.10: Add & Delete Profile from Profile Picker *(Done)*
- **DNI-177** — 18.11: Fix Edit Profile Button on Settings Screen *(Done)*
- **DNI-178** — 18.12: Delete Account Redirects to Welcome Instead of Sign-In *(Done)*
- **DNI-179** — 18.2: User Onboarding — Profile + Language Only *(Done)*
- **DNI-180** — 18.1: Add Track Flow — 8 Screens, One Concept Each *(Done)*
- **DNI-181** — 18.3: Wire Add Track Flow into All Entry Points *(Done)*
- **DNI-194** — 18.8: Program-Aware AddTrackFlow — Skip/Auto-Fill Steps Based on Program Metadata *(Duplicate)*

### Epic 17 — V1 Roadmap Phase 1: Foundation & Onboarding (DNI-154, 8 stories)

- **DNI-155** — 17.1: Sefaria & Hebcal Calendar API Clients *(Canceled)*
- **DNI-156** — 17.2: Calendar Program Registry (API + Local Presets) *(Canceled)*
- **DNI-157** — 17.3: Per-Child Reward Model Fix *(Canceled)*
- **DNI-159** — 17.5: Onboarding Entry Rework ("Add myself / Add child / Skip") *(Canceled)*
- **DNI-160** — 17.6: Onboarding Path A — Calendar Program Join Flow *(Canceled)*
- **DNI-161** — 17.7: Start Tracking From + Two-Use-Case Bulk Mark *(Canceled)*
- **DNI-162** — 17.8: Dashboard — Streak Recovery, Calendar Status, Reward Progress *(Canceled)*
- **DNI-163** — 17.9: Hebrew UI Translation Pass *(Canceled)*

### Epic 19 — Offline-First Architecture & Two-Database Split (DNI-182, 12 stories)

- **DNI-183** — 19.1: Fix Calendar Registry Bugs (7 bugs) *(Done)*
- **DNI-184** — 19.2: Two-Database Split (ContentDatabase + UserDatabase) *(Done)*
- **DNI-185** — 19.3: Seed Database Build Tool *(Done)*
- **DNI-186** — 19.5: Local-First Auth Abstraction Layer *(Done)*
- **DNI-187** — 19.6: Startup Sequence Hardening *(Done)*
- **DNI-188** — 19.7: Optional Account Creation in Settings (Magic Link Auth) *(Done)*
- **DNI-189** — 19.8: SyncEngine Conditional Activation *(Done)*
- **DNI-190** — 19.9: Multi-Device Sync & Efficient Real-Time Sync *(Done)*
- **DNI-191** — 19.10: Navigation & State Cleanup *(Done)*
- **DNI-192** — 19.11: End-to-End Offline Integration Testing *(Done)*
- **DNI-193** — 19.4: Local Calendar Engine *(Done)*
- **DNI-209** — 19.12: Content DB Resilience & Error Recovery *(Done)*

### Epic 20 — Dashboard & Progress Redesign — Multi-Track, Per-Track Isolation (DNI-210, 12 stories)

- **DNI-211** — 20.1: Schema Definition — trackId on 7 Config Tables + paceResetDate *(Canceled)*
- **DNI-212** — 20.2: Track-Scoped DAOs — Add trackId Filters to All Queries *(Canceled)*
- **DNI-213** — 20.3: TrackProgress Domain Models — Variant-Aware Progress Types *(Canceled)*
- **DNI-214** — 20.4: Track-Scoped Providers — Replace Curriculum-Scoped with Per-Track *(Canceled)*
- **DNI-215** — 20.5: Per-Track Scheduler — Scheduler Runs Per-Track, Tasks Carry trackId *(Canceled)*
- **DNI-216** — 20.6: Program Calendar Mock — CalendarPosition Model + Mock Provider *(Canceled)*
- **DNI-217** — 20.7: Dashboard — Stats Row & Unified Task List *(Canceled)*
- **DNI-218** — 20.8: Dashboard — Track Cards (4 Variants) *(Canceled)*
- **DNI-219** — 20.9: Dashboard — Recovery Actions (Jump to Today, Reset Pace) *(Canceled)*
- **DNI-220** — 20.10: Progress Screen & Track Detail Redesign *(Canceled)*
- **DNI-221** — 20.11: Charts & Completion History — Track Filter *(Canceled)*
- **DNI-222** — 20.12: Learning Journey — Curriculum View with Learned/Reviewed Counts *(Canceled)*

### Epic 23 — Offline-First Architecture v2 — Hard-Tier Auth Refactor (DNI-223, 14 stories)

- **DNI-224** — 20.1: argon2id Parameter Benchmark (Spike) *(Done)*
- **DNI-225** — 20.2: Upgrade Flow UX Spec (Visual Design & Open Questions) *(Done)*
- **DNI-226** — 20.3: User DB Schema Migration — Drop localUid, Add passwordHash + tier *(Done)*
- **DNI-227** — 20.4: Local Auth Service with argon2id *(Done)*
- **DNI-228** — 20.5: Unified AuthState & Guard Collapse *(Done)*
- **DNI-229** — 20.6: Mandatory Signup at First Launch (Onboarding Rewrite) *(Done)*
- **DNI-230** — 20.7: Local-Born Signup Screen with No-Backup Warning *(Done)*
- **DNI-231** — 20.8: Offline Mode UX Surfaces — Top Banner + No-Backup Badge *(Done)*
- **DNI-232** — 20.9: Local → Cloud Upgrade Flow (Settings) *(Done)*
- **DNI-233** — 20.10: SyncEngine Tier-Gated Activation *(Done)*
- **DNI-234** — 20.11: Conflict Resolution — Event Log for Streaks & XP *(Done)*
- **DNI-235** — 20.12: Conflict Resolution — Merge Rules (LWW + Merge-Forward) *(Done)*
- **DNI-236** — 20.13: v2 Auth Model Test Rewrites + E2E Verification *(Done)*
- **DNI-237** — 20.14: Cleanup — Remove Orphaned v1 Auth References *(Done)*

### Epic 21 — Multi-Account Device — Account Switching, Session Management & Deletion (DNI-238, 16 stories)

- **DNI-239** — 21.1: Device Account Registry *(Done)*
- **DNI-240** — 21.2: Per-Account Database Isolation & ActiveUserDatabaseProvider *(Done)*
- **DNI-241** — 21.3: Session Auto-Resume on App Startup *(Done)*
- **DNI-242** — 21.4: Session Persistence — SharedPreferences Last-Active Tracking *(Done)*
- **DNI-243** — 21.5: Unified Sign-Up Page — Email/Password Path *(Done)*
- **DNI-244** — 21.6: Unified Sign-Up Page — Google Sign-In Path *(Done)*
- **DNI-245** — 21.7: Unified Sign-In Page — Smart Credential Routing *(Done)*
- **DNI-246** — 21.8: Unified Sign-In Page — Google Sign-In Path *(Done)*
- **DNI-247** — 21.9: Account Picker Screen *(Done)*
- **DNI-248** — 21.10: Sign-Out Routes to Account Picker *(Done)*
- **DNI-249** — 21.11: Add Account from Picker (Respects 5-Account Cap) *(Done)*
- **DNI-250** — 21.12: Local → Cloud Upgrade in Multi-Account Context *(Done)*
- **DNI-251** — 21.13: Remove Cloud-Born Account from Device *(Done)*
- **DNI-252** — 21.14: Delete Local-Born Account *(Done)*
- **DNI-253** — 21.15: Delete Cloud-Born Account (Full Wipe) *(Done)*
- **DNI-254** — 21.16: Firebase Cloud Function — Server-Side Deletion Cleanup *(Done)*

### Epic 22 — Catch-up & Amnesty System (DNI-255, 22 stories)

- **DNI-256** — 22.1: item_amnesty Table + DAO *(Canceled)*
- **DNI-257** — 22.2: curriculum_tracks Per-Track Settings + Pause Columns *(Canceled)*
- **DNI-258** — 22.3: TrackDebt Computed Struct + Scenario Detection *(Canceled)*
- **DNI-259** — 22.4: track_action_log Table + DAO *(Canceled)*
- **DNI-260** — 22.5: Rescope Service Wrapper *(Canceled)*
- **DNI-261** — 22.6: Amnesty Primitive — Create, Revoke, Undo *(Canceled)*
- **DNI-262** — 22.7: Amnesty History View *(Canceled)*
- **DNI-263** — 22.8: Pause Track State + PausePicker *(Canceled)*
- **DNI-264** — 22.9: Pause Auto-Resume + PauseResumeCard *(Canceled)*
- **DNI-265** — 22.10: Catch-up Sheet — Self-Paced Variants (S1, S2, S3) *(Canceled)*
- **DNI-266** — 22.11: Catch-up Sheet — Program Variant (S4) *(Canceled)*
- **DNI-267** — 22.12: Review Debt View (S6, S7) *(Canceled)*
- **DNI-268** — 22.13: Learning Journey Structural View (S8) *(Canceled)*
- **DNI-269** — 22.14: Triage Sheet (S9, S11) *(Canceled)*
- **DNI-270** — 22.15: Returning Learner Onboarding (S9) *(Canceled)*
- **DNI-271** — 22.16: Cross-Credit Opt-In (S12) *(Canceled)*
- **DNI-272** — 22.17: Siyum Cleanup Card (S13) *(Canceled)*
- **DNI-273** — 22.18: Setup Seeding — Program Launch Day (S14) *(Canceled)*
- **DNI-274** — 22.19: Setup Seeding — Personal Track Retrofit (S15) *(Canceled)*
- **DNI-275** — 22.20: Cycle-Boundary Welcome Flow *(Canceled)*
- **DNI-276** — 22.21: Notification System Rewrite — Pause-Based Silence *(Canceled)*
- **DNI-277** — 22.22: Track Settings Panel — Recovery Configuration *(Canceled)*

### Epic 23 — Manual QA Verification (DNI-278, 18 stories)

- **DNI-279** — 23.2: Set Up Testing Environments *(Canceled)*
- **DNI-280** — 23.1: Read QA Methodology & Product Overview *(Canceled)*
- **DNI-281** — 23.3: Test Auth & Accounts *(Canceled)*
- **DNI-282** — 23.4: Test Onboarding Flow *(Canceled)*
- **DNI-283** — 23.6: Test Multi-Track Learning *(Canceled)*
- **DNI-284** — 23.5: Test Learning & Completions (CRITICAL) *(Canceled)*
- **DNI-285** — 23.7: Test Configurable Stages & Learning Order *(Canceled)*
- **DNI-286** — 23.8: Test Scheduler & Goals *(Canceled)*
- **DNI-287** — 23.9: Test Dashboard & Progress *(Canceled)*
- **DNI-288** — 23.10: Test Content Browsing & Search *(Canceled)*
- **DNI-289** — 23.11: Test Gamification *(Canceled)*
- **DNI-290** — 23.12: Test Parent Mode *(Canceled)*
- **DNI-291** — 23.13: Test Tutor Mode *(Canceled)*
- **DNI-292** — 23.14: Test Notifications *(Canceled)*
- **DNI-293** — 23.15: Test Settings *(Canceled)*
- **DNI-294** — 23.17: Test Profiles *(Canceled)*
- **DNI-295** — 23.16: Test Sync & Offline *(Canceled)*
- **DNI-296** — 23.18: Test Catch-up & Amnesty System (BLOCKED) *(Canceled)*

### Epic 24 — Firestore Sync Schema & Multi-Device Data Restoration (DNI-297, 10 stories)

- **DNI-298** — 24.1: Firestore Document Schema & Collection Design *(Canceled)*
- **DNI-299** — 24.2: Profile & Account Document Sync *(Canceled)*
- **DNI-300** — 24.3: Track Setup Collections Sync (6 tables) *(Canceled)*
- **DNI-301** — 24.4: Learning Configuration Sync (4 tables) *(Canceled)*
- **DNI-302** — 24.5: Completions & Learning Ledger Sync — Append-Only (2 tables) *(Canceled)*
- **DNI-303** — 24.6: Gamification State Sync — Streaks & XP Events (3 tables) *(Canceled)*
- **DNI-304** — 24.7: Rewards & Pools Sync (3 tables) *(Canceled)*
- **DNI-305** — 24.8: Test Scores & Account Settings Sync (1 table + account doc) *(Canceled)*
- **DNI-306** — 24.9: New Device Full Restore (Pull-on-Launch) *(Canceled)*
- **DNI-307** — 24.10: Local-Born Upgrade Push & Ongoing Sync Engine *(Canceled)*

### Epic 24 — Stop-the-Bleeding (Phase 0) (DNI-312, 8 stories)

- **DNI-310** — 24.7: Sync curriculum track activation to Firestore *(Done)*
- **DNI-311** — 24.8: Sync learning order to Firestore *(Done)*
- **DNI-316** — 24.1: Per-collection Firestore rules with field validators and emulator test job *(Done)*
- **DNI-317** — 24.2: Soft-delete tracks; stop cascading into append-only tables *(Done)*
- **DNI-318** — 24.3: Centralize sign-out through AuthRepository *(Done)*
- **DNI-319** — 24.4: Wire Crashlytics in main.dart before any other init *(Done)*
- **DNI-320** — 24.5: Migrate sync_engine and OfflineQueue to AppLogger; rewrite PII redactor *(Done)*
- **DNI-321** — 24.6: Multi-profile leak band-aid via cross-profile scope assertions *(Done)*

### Epic 25 — Schema + Core Foundation (Phases 1 + 2) (DNI-313, 22 stories)

- **DNI-322** — 25.1: Schema-v1 user DB skeleton (renamed tables, profileId PKs, no defaults, FKs) *(Done)*
- **DNI-323** — 25.2: Append-only event tables with composite-natural-key UNIQUEs *(Done)*
- **DNI-324** — 25.3: Composite indexes on hot-path queries *(Done)*
- **DNI-325** — 25.4: Firestore v1 collection layout and per-collection rules *(Done)*
- **DNI-326** — 25.5: Outbox table and OutboxProcessor scaffolding *(Done)*
- **DNI-327** — 25.6: Schema-check tool to enforce profileId-in-PK and composite-index invariants *(Done)*
- **DNI-328** — 25.7: core/preferences/ — six ProfileScopedPreference primitives *(Done)*
- **DNI-329** — 25.8: core/content/ContentIndex — indexed lookup for 9 curricula + ProgramRefResolver *(Done)*
- **DNI-330** — 25.9: core/labels/ rebuild — three new modes, ContentIndex consumer, static API deleted *(Done)*
- **DNI-331** — 25.10: core/time/LocalDayClock — single time provider *(Done)*
- **DNI-332** — 25.11: core/auth/AuthRepository — sole Firebase Auth consumer *(Done)*
- **DNI-333** — 25.12: SyncEngine decomposition Part 1 — FirestoreGateway, PushPipeline, PullPipeline *(Done)*
- **DNI-334** — 25.13: SyncEngine decomposition Part 2 — MergeRouter and sealed EntityMerger strategies *(Done)*
- **DNI-335** — 25.14: SyncEngine decomposition Part 3 — ListenerSupervisor and LifecycleObserver *(Done)*
- **DNI-336** — 25.15: core/learning/CompletionWriter — single transactional commit path *(Done)*
- **DNI-337** — 25.16: core/streak/ — event log + reducer + round-trip sync *(Done)*
- **DNI-338** — 25.17: core/database/BaseDao&lt;T&gt; and TrackScope; delete cross-profile DAO methods *(Done)*
- **DNI-339** — 25.18: core/navigation/ — typed auto_route + PinScope-parameterized guard *(Done)*
- **DNI-340** — 25.19: core/logging/ — finalize structured AppLogger and migrate remaining production logs *(Done)*
- **DNI-341** — 25.20: MaterialApp locale auto-detection + Noto Sans Hebrew bundling + direction-aware CurriculumLabel + real dark theme *(Done)*
- **DNI-342** — 25.21: Multi-account threading — replace eight hardcoded currentAccountId = 1 sites + offline indicator preservation *(Done)*
- **DNI-343** — 25.22: Wipe-install cutover end-to-end verification *(Done)*

### Epic 26 — Feature Rebuilds + Cleanups (Phases 3 + 4) (DNI-314, 35 stories)

- **DNI-308** — 26.34: Delete deprecated TextDownloadService *(Canceled)*
- **DNI-309** — 26.35: Remove promoteToCloud / demoteToLocal auth shims *(Canceled)*
- **DNI-344** — 26.1: Scheduler strategy pattern — SchedulerInput → SchedulerAnalysis → TaskAssembly *(Done)*
- **DNI-345** — 26.2: Fix dashboardPaceStatusProvider with real total-items math *(Done)*
- **DNI-346** — 26.3: Scheduler classification + chazara-load + isStudyDay + day-1 rolling-window fixes *(Done)*
- **DNI-347** — 26.4: GoalEntity replaces GoalFormResult; sealed PaceTarget; typed PaceGranularity *(Done)*
- **DNI-348** — 26.5: Extract 20 private classes from dashboard_screen.dart into widgets/ *(Done)*
- **DNI-349** — 26.6: TrackCard + 5 subcomponents + TrackCardViewModel *(Done)*
- **DNI-350** — 26.7: dashboardModelProvider composition; centralized after-track-change invalidation *(Done)*
- **DNI-351** — 26.8: Delete TrackProgressVariant and supporting dead code *(Done)*
- **DNI-352** — 26.9: AddTrackController state machine + AddTrackFlowScreen shell *(Done)*
- **DNI-353** — 26.10: Decompose AddTrackFlow steps into per-step files *(Done)*
- **DNI-354** — 26.11: OnboardingController + OnboardingStep list pattern *(Done)*
- **DNI-355** — 26.12: ProfileCreationUseCase (one transactional) *(Done)*
- **DNI-356** — 26.13: Reader purity — pure render, CompletionWriter, completionCommittedProvider *(Done)*
- **DNI-357** — 26.14: ContentTree indexed lookup replaces 4-level _currentLevel ladders *(Done)*
- **DNI-358** — 26.15: CompositeCurriculumStrategy + transactional saveOrder + parent-control at repository *(Done)*
- **DNI-359** — 26.16: Tappable Progress overview stats + StatCard primitive *(Done)*
- **DNI-360** — 26.17: StreakCalendar honors startDate/endDate; StreakHistoryScreen created *(Done)*
- **DNI-361** — 26.18: Lifetime providers split — per-curriculum lazy family + collapsed summaries *(Done)*
- **DNI-362** — 26.19: UnitCompletion model + achievementsOverviewProvider autoDispose *(Done)*
- **DNI-363** — 26.20: PreferenceListTile + PreferenceSegmentedTile primitives *(Done)*
- **DNI-364** — 26.21: PinFlowController + PinFlowScreen + PinFlowMode (3 PIN screens → 1) *(Done)*
- **DNI-365** — 26.22: Shared TrackManagementBody + curriculum-minimum-1 guard *(Done)*
- **DNI-366** — 26.23: Data export rewrite — all 23 tables, profileId on every row, no PII, round-trip test *(Done)*
- **DNI-367** — 26.24: Sacred-time-aware notifications — rolling 14-day batch + fire-time check + SacredWindow persistence *(Done)*
- **DNI-368** — 26.25: SacredTimeLockOverlay scoped to post-auth shell *(Done)*
- **DNI-369** — 26.26: Stage repository as only path; full params; transactional reorder + Learn-at-1 guard *(Done)*
- **DNI-370** — 26.27: Bulk-mark-prior streak abstention at all stages *(Done)*
- **DNI-371** — 26.28: Label bypass elimination — 17 files + TrackType + Calendar/LearningProgram + locale-named locals *(Done)*
- **DNI-372** — 26.29: Hardcoded strings → ARB extraction *(Done)*
- **DNI-373** — 26.30: Hebrew ARB translation completion *(Done)*
- **DNI-374** — 26.31: RTL widget audit — direction-aware variants across ~80–100 sites *(Done)*
- **DNI-375** — 26.32: Naming sweep — unit→3 names, Profiles→Accounts/LearnerProfiles, Gregorian→English, notification taxonomy *(Done)*
- **DNI-376** — 26.33: Dead code purge — ≥10 000 LOC across reducers, services, tables, widgets, ARB keys, themes, network modules *(Done)*

### Epic 27 — Discipline & Closure (Phases 5 + 6 + 7) (DNI-315, 17 stories)

- **DNI-127** — 27.17: CI/CD — Play Store deployment pipeline *(Canceled)*
- **DNI-377** — 27.1: Test infrastructure — fake_cloud_firestore, golden scaffolding, real-Drift in-memory helper *(Done)*
- **DNI-378** — 27.2: Unit test suite for pure functions *(Done)*
- **DNI-379** — 27.3: DAO and repository test suite using real in-memory Drift *(Done)*
- **DNI-380** — 27.4: Widget + golden test suite (canonical screens) with Hebrew variants *(Done)*
- **DNI-381** — 27.5: Integration test — bulk_mark_prior_does_not_credit_streak (any stage) *(Done)*
- **DNI-382** — 27.6: Integration tests — streak_reducer_reconciles + cloud_restore_preserves_streak *(Done)*
- **DNI-383** — 27.7: Integration tests — multi_profile_isolation + track_card_canonical_layout *(Done)*
- **DNI-384** — 27.8: Integration tests — firestore_rules (emulator) + offline_completion_flushes *(Done)*
- **DNI-385** — 27.9: Integration tests — pin_lockout_cycle + log_redaction + bookmark_advance_atomic *(Done)*
- **DNI-386** — 27.10: Custom lints Part 1 — no-curriculum-display-name-bypass, no-feature-cross-import *(Done)*
- **DNI-387** — 27.11: Custom lints Part 2 — no-firebase-outside-core, no-raw-talker, RTL discipline *(Done)*
- **DNI-388** — 27.12: CI matrix — analyze, format, audit, lint, test, coverage-floor, firestore-rules, golden, arb-parity *(Done)*
- **DNI-389** — 27.13: `make audit` Makefile target + tool/arb_parity_check.dart *(Done)*
- **DNI-390** — 27.14: 12 analytics events wired + Crashlytics user ID set everywhere *(Done)*
- **DNI-391** — 27.15: `docs/architecture.md` rewrite to match rebuild reality *(Done)*
- **DNI-392** — 27.16: CLAUDE.md and docs/coding-standards.md updated with layering rules and enforcement greps *(Done)*
<!-- AUTO:EPIC-LIST-END -->
