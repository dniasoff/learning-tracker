---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/two-database-drift-architecture.md
  - _bmad-output/planning-artifacts/offline-first-architecture-v2-2026-04-10.md
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
- D2-v3: Hard-tier auth (cloud-born vs local-born), tier set at signup by network state and immutable. Every user has an email+password account; local-born uses argon2id hash in SQLite. Supersedes the prior "optional UUID, Firebase optional" model. See `offline-first-architecture-v2-2026-04-10.md`.
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

> ⚠️ **Partial supersede by Epic 20.** Epic 19 stories 19.5 (local-first auth abstraction) and 19.7 (optional account creation in Settings) implement the prior "anonymous localUid + optional deferred account" model, which was superseded on 2026-04-10 by the hard-tier auth model in `offline-first-architecture-v2-2026-04-10.md`. Those two stories must not ship in their current form. Epic 20 (below) replaces them. All other Epic 19 stories — two-database split, seed DB, calendar engine, startup hardening, SyncEngine conditional activation, content DB resilience, E2E testing — remain valid and canonical.

### Epic 20: Offline-First Architecture v2 — Hard-Tier Auth Refactor

Refactor auth to the hard-tier cloud-born / local-born model per `offline-first-architecture-v2-2026-04-10.md`. Every user has a real account; tier is set at signup by network state and is immutable. Supersedes the March 2026 anonymous-localUid architecture and the Epic 19 stories 19.5 and 19.7.

**Linear:** [Epic 20: Offline-First Architecture v2 — Hard-Tier Auth Refactor](https://linear.app/dniasoff/project/epic-20-offline-first-architecture-v2-hard-tier-auth-refactor-d9ed0690d244)
**Gates:** Epic 19 shipping in its current form
**Scope:** Auth domain (drop `AppAuthState` sealed hierarchy), DB schema (drop `localUid`, add `passwordHash` + `tier`), onboarding (mandatory signup at first launch), settings (guided upgrade flow per v2 §4.3), sync engine (tier-gated activation, conflict resolution per v2 §4.1 with event-log streaks/XP), ~15 production files + 6 test files affected
**Canonical doc:** `_bmad-output/planning-artifacts/offline-first-architecture-v2-2026-04-10.md`

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
