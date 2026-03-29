# Complete Offline-First Architecture — Analysis & Plan

**Date:** 2026-03-27
**Status:** Draft — Pending Review
**Author:** Mary (Business Analyst) with Daniel

---

## 1. Executive Summary

Learning Tracker must support users who **never connect to the internet** after initial install. This requires inverting the current architecture from "online with offline queue" to **local-first by default with transparent sync when internet happens to be available**.

### Core Principle

> The app works fully — every feature, every curriculum, every calendar program — without ever touching the network. Sync is a silent bonus, not a requirement.

### Key Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Default mode | Local-first (no account required) | Many users don't want internet access |
| Text content | Bundle all in APK | APK size is not a concern |
| Calendar programs | Compute locally (all 12) | Reverse-engineer cycles from Hebcal/Sefaria |
| Sync behavior | Transparent when internet available | No user action required to sync |
| Account creation | Optional, deferred | User may never create one |

---

## 2. Current State Assessment

### What Already Works Offline ✅

| Capability | How |
|-----------|-----|
| All writes are local-first | SQLite is source of truth (D4, NFR24) |
| Offline write queue | `sync_queue` table, 5 retries, exponential backoff |
| Curriculum hierarchy browsing | 7 JSON files bundled in `assets/content/hierarchy/` |
| Scheduler engine | Pure computation — zero network calls |
| Notifications | Fully local (`flutter_local_notifications`) |
| PIN auth | Device-local, bcrypt, `flutter_secure_storage` |
| Shabbos/Yom Tov quiet mode | Local zmanim via `kosher_dart` |

### Hard Blockers for Never-Online Users ❌

| # | Blocker | Impact | Severity |
|---|---------|--------|----------|
| B1 | **Firebase Auth is mandatory** | App stuck on sign-in screen. `AuthGuard` blocks all protected routes. No local-only profile path exists. | **Critical** |
| B2 | **Text content not bundled** | ~52,528 leaf items across 7 curricula fetched at runtime from GitHub Releases. Users can browse hierarchy but cannot read any text. | **Critical** |
| B3 | **Calendar programs 100% API-dependent** | Zero local cycle computation. "What's today's Daf Yomi?" requires live Sefaria/Hebcal call. | **Critical** |
| B4 | **`GoogleSignIn.initialize()` at startup** | Called in `main.dart` — may hang or fail without network. | **High** |
| B5 | **`ConnectivityService` DNS timeout** | 5-second DNS lookup to `dns.google` on every launch. Unnecessary delay in airplane mode. | **Medium** |

---

## 3. Target Architecture

### 3.1 Architecture Principle: Local-First, Sync-Optional, Two-Database Split

```
┌──────────────────────────────────────────────────────────────┐
│                        App Layer                              │
│   (All features work identically regardless of               │
│    network state or account existence)                       │
├──────────────────────────────────────────────────────────────┤
│                    Local Data Layer                            │
│                                                               │
│  ┌─────────────────────────┐  ┌────────────────────────────┐ │
│  │   Content DB (read-only) │  │   User DB (read-write)     │ │
│  │   content.db             │  │   learning_tracker.db      │ │
│  │                          │  │                            │ │
│  │  • TextCache (52K items) │  │  • Profiles, UserProfiles  │ │
│  │  • CalendarCycles (30K)  │  │  • Completions (append)    │ │
│  │  • LearningPrograms (9)  │  │  • LearningLedger (append) │ │
│  │  • SeedMetadata          │  │  • Bookmarks, Goals        │ │
│  │                          │  │  • Rewards, Streaks        │ │
│  │                          │  │  • Tracks, Scopes          │ │
│  │  Ships as seed.db.gz     │  │  • StageDefinitions        │ │
│  │  Replaced on app update  │  │  • PointConfigs            │ │
│  │  ZERO user data          │  │  • StudyDayConfigs         │ │
│  │                          │  │  • SyncQueue               │ │
│  │  Schema: v1              │  │                            │ │
│  │  No migrations needed —  │  │  Schema: v1                │ │
│  │  just replace the file   │  │  Drift migrations as usual │ │
│  └─────────────────────────┘  └────────────────────────────┘ │
│                                                               │
│  Cross-reference: User DB references Content DB via string   │
│  identifiers (sefariaRef, curriculumId, programId) — no      │
│  hard foreign keys, no cross-DB queries needed               │
├──────────────────────────────────────────────────────────────┤
│            Transparent Sync Layer (Optional)                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  SyncEngine (activates when online + user has account) │  │
│  │  • Syncs User DB data only — Content DB never synced   │  │
│  │  • Push-on-write (queued)                              │  │
│  │  • Pull-on-launch (if available)                       │  │
│  │  • Foreground listeners (if available)                 │  │
│  └────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────┤
│             Optional Account Layer                            │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Firebase Auth (user opts in when ready)               │  │
│  │  • Enables multi-device sync of User DB               │  │
│  │  • Enables cloud backup                               │  │
│  │  • Can be created at any time                         │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 Two-Database Split — Detailed Design

#### Why Two Databases?

| Concern | Single DB | Two DBs |
|---------|-----------|---------|
| Content update on app upgrade | Complex upsert/merge, risk of data loss | Delete & replace content.db — zero risk |
| Schema migration for content | Must migrate content tables alongside user tables | No migrations — just ship a new file |
| User data safety | Content + user data co-located, replace = danger | Content DB has ZERO user data, always safe to replace |
| Read performance | Mixed read-write workload | Content DB opened read-only — faster, no WAL overhead |
| Build pipeline | Must carefully merge seed data into existing DB | Seed tool outputs a standalone .db file, CI validates schema |

#### Content DB — `ContentDatabase` (Drift class)

**File:** `content.db` — opened **read-only**
**Schema version:** v1 (no migration infrastructure needed — file replacement is the upgrade path)
**Source:** Pre-built by `tool/seed_content_db.dart`, shipped compressed as `assets/seed.db.gz`

| Table | Rows (est.) | Purpose |
|-------|-------------|---------|
| **TextCache** | ~52,528 | All Sefaria text content (Hebrew + English), keyed by `sefariaRef` |
| **CalendarCycles** | ~30,684 | Date-keyed: `(program_id, date) → sefaria_ref` for 2024-2030 |
| **LearningPrograms** | 9 | Program presets (Daf Yomi, Mishnah Yomit, etc.) with stage/test config |
| **SeedMetadata** | 1 | Seed DB version, build date, content hash — for upgrade version comparison |

**Tables removed vs current architecture:**
- `ContentDownloadStatuses` — **eliminated**. All content is bundled; no download tracking needed.
- `TextDownloadStatuses` — **eliminated**. Same reason.
- `CalendarCache` — **replaced** by `CalendarCycles` table with pre-computed date-keyed data.
- `TestDates` — **not included in Content DB**. Dirshu test reminders are a separate feature; should be scoped in its own ticket if/when needed.

#### User DB — `UserDatabase` (Drift class)

**File:** `learning_tracker.db` — read-write
**Schema version:** v1 (fresh start — app not yet deployed)
**Migrations:** Standard Drift `onUpgrade` for future schema changes

| Table | Purpose |
|-------|---------|
| **Profiles** | Learner profiles (multi-profile per account) |
| **UserProfiles** | Account-level user info, Firebase UID |
| **Completions** | Append-only completion log |
| **LearningLedger** | Append-only lifetime learning record |
| **Bookmarks** | Current position per curriculum/track |
| **Goals** | Learning goals with deadlines |
| **LearningOrder** | Custom item ordering |
| **Rewards** | Gamification milestones |
| **RewardPools** | Reward pool collections |
| **RewardPoolItems** | Items within reward pools |
| **Streaks** | Learning streak tracking |
| **TestScores** | Logged test scores |
| **TestDates** | Dirshu test schedule (future feature — kept in User DB for now) |
| **ActiveCurricula** | Which curricula are active per profile |
| **CurriculumTracks** | Track activation (personal/school/tutor) |
| **CurriculumScopes** | Scope filters for curricula |
| **ProfilePrograms** | Profile ↔ program associations |
| **StageDefinitions** | Stage config per curriculum (user-customizable) |
| **PointConfigs** | Points per stage (user-customizable) |
| **StudyDayConfigs** | Day-of-week study schedule (user-customizable) |
| **SyncQueue** | Offline sync queue |

**Note on "mixed" tables:** `StageDefinitions`, `PointConfigs`, and `StudyDayConfigs` are seeded with defaults during onboarding (from hardcoded Dart constants, not from Content DB) but are user-customizable per profile. They live in User DB because user modifications must survive content updates.

#### Cross-Database References

User DB references Content DB via **string identifiers only** — no hard foreign keys, no JOINs:

| User DB Table | References | Content DB Lookup |
|---------------|-----------|-------------------|
| Completions | `sefariaRef` | → TextCache.sefariaRef |
| Bookmarks | `sefariaRef` | → TextCache.sefariaRef |
| LearningOrder | `sefariaRef` | → TextCache.sefariaRef |
| ProfilePrograms | `programId` | → LearningPrograms.id |
| ActiveCurricula | `curriculumId` | → hierarchy JSON (in-memory, unchanged) |

All lookups are **application-level** — query User DB, then separately query Content DB by ID. No SQL JOINs across databases. This is already the existing pattern.

#### Upgrade Flow

```
App update installed (new APK with new seed.db.gz)
  │
  ├─ Content DB upgrade:
  │   ├─ Read SeedMetadata.version from existing content.db
  │   ├─ Read bundled seed version from assets manifest
  │   ├─ If bundled > installed (or no content.db exists):
  │   │   ├─ Close existing content.db connection
  │   │   ├─ Delete old content.db file
  │   │   ├─ Decompress seed.db.gz → content.db (2-5 sec)
  │   │   └─ Open new content.db read-only
  │   └─ If same version: skip, use existing content.db
  │
  └─ User DB upgrade:
      ├─ Drift checks schemaVersion (v1 initially)
      ├─ If newer schema: run onUpgrade migrations
      └─ User data fully intact — Content DB change is invisible
```

**Key guarantee:** Deleting content.db can never lose user data. The two databases share no file, no tables, no state.

#### Riverpod Provider Setup

```
// Two database providers, both keepAlive
@Riverpod(keepAlive: true)
ContentDatabase contentDatabase(Ref ref) {
  // Opens read-only, from app's DB directory (copied from assets on first launch/upgrade)
}

@Riverpod(keepAlive: true)
UserDatabase userDatabase(Ref ref) {
  // Opens read-write, standard Drift lifecycle
}
```

DAOs and repositories depend on whichever database they need. Most features only touch one database. The few that need both (e.g., displaying text content with user progress) do two separate queries and combine results in the repository/service layer.

### 3.2 User Journey — Never-Online User

```
Install APK
  → First launch (no network needed)
  → Onboarding wizard: mode selection, study days, curriculum picks
  → Local profile created with generated UUID
  → All text content available (bundled)
  → All calendar programs computed locally
  → Full app experience — indefinitely, without internet
```

### 3.3 User Journey — Optional Sync User

```
Uses app locally for days/weeks/months
  → Decides to enable sync (or connects to Wi-Fi)
  → Settings: "Create Account" or "Sign In"
  → Firebase Auth creates account
  → Local profile UID migrated to Firebase UID
  → SyncEngine activates: pushes all local data to Firestore
  → From now on: transparent background sync when online
  → If internet lost: seamless fallback to local-only (no UX change)
```

---

## 4. Stream Breakdown

### Stream 1: Local-First Auth & Profile (CRITICAL PATH)

**Problem:** Firebase Auth gates the entire app. `AuthGuard` on every protected route. No way to use the app without signing in.

**Solution:**

1. **Local Profile System**
   - Generate stable UUID on first launch as `localUid`
   - Create profile in local SQLite without Firebase
   - All DAOs already use `profileId` scoping — this works unchanged
   - Store `localUid` in SharedPreferences for persistence

2. **Auth Abstraction Layer**
   - Create `AuthStateService` interface abstracting over Firebase and local auth
   - `LocalAuthState`: returns synthetic user with `localUid`, always "authenticated"
   - `FirebaseAuthState`: existing behavior, wraps `FirebaseAuth`
   - `AuthGuard` checks `AuthStateService` instead of `FirebaseAuth` directly

3. **Deferred Account Creation**
   - Add "Create Account" option in Settings (not onboarding)
   - On account creation: migrate `localUid` → Firebase UID across all tables
   - UID migration must be atomic (single transaction)
   - SyncEngine activates after migration, pushes full local state

4. **Startup Changes**
   - `Firebase.initializeApp()` — call only if network available, wrap in try/catch
   - `GoogleSignIn.initialize()` — defer until user actively chooses Google sign-in
   - App launches into onboarding or home screen directly (no sign-in wall)

**Affected Files:**
- `lib/features/auth/` — Auth repository, guards, providers
- `main.dart` — Startup sequence
- `lib/features/sync/` — SyncEngine activation logic
- `lib/core/routing/` — Route guards

**Risks:**
- UID migration complexity — must update all foreign key references atomically
- Firebase SDK may still phone home even if auth isn't used — may need build flavors

---

### Stream 2: Bundle All Text Content (CRITICAL PATH)

**Problem:** ~52,528 text items across 7 curricula downloaded at runtime from GitHub Releases. Zero text available to never-online users.

**Solution: Pre-Built SQLite Database**

Instead of bundling JSON and hydrating into SQLite at runtime, we **ship a pre-built SQLite database** in the APK. This eliminates the 30-90 second first-launch hydration entirely.

1. **Pre-Built Seed Database**
   - Build tool generates a complete SQLite `.db` file with the exact Drift schema
   - Contains all text content pre-inserted into `TextCache` table (~52,528 rows)
   - Contains all 12 calendar program cycle data (see Stream 3)
   - All `TextDownloadStatuses` rows pre-marked as "downloaded"
   - Database is compressed (gzip) in `assets/` — **estimated ~45-60 MB compressed**
   - Uncompressed on device: **~260-340 MB**

2. **First-Launch: File Copy (Not Hydration)**
   - On first launch, check if local database exists
   - If not: decompress and copy bundled `.db` to app's database directory
   - **Estimated time: 2-5 seconds** (file copy, not row-by-row insertion)
   - No progress screen needed — fast enough to feel seamless
   - Subsequent launches: database already in place, no action needed

3. **Build Pipeline**
   - `tool/seed_content_db.dart` — New build tool that:
     - Creates SQLite database matching Drift schema
     - Runs existing `seed_text_content.dart` logic to populate text tables
     - Runs `seed_calendar_cycles.dart` logic to populate calendar tables
     - Outputs `assets/seed.db.gz` (compressed)
   - CI/CD builds seed DB as part of release pipeline
   - Version tracking: seed DB version stored in metadata table, compared on app update

4. **App Update Handling**
   - Content DB is a **separate file** from User DB (see Section 3.2)
   - On app update: compare bundled seed version with installed content.db version
   - If newer: delete old content.db, decompress new seed.db.gz. No merge logic needed.
   - User data is in a completely separate database file — never at risk.

**Affected Files:**
- `assets/seed.db.gz` — Pre-built compressed Content DB
- `tool/seed_content_db.dart` — Build tool generating Content DB (replaces separate text/calendar seed tools)
- `lib/core/database/content_database.dart` — New Drift `ContentDatabase` class (read-only)
- `lib/core/database/user_database.dart` — Renamed/refactored from current `AppDatabase` (user data only)
- `lib/core/database/seed_manager.dart` — Handles seed DB decompression and version checking
- `lib/core/providers/database_provider.dart` — Two providers: `contentDatabase` + `userDatabase`
- `pubspec.yaml` — Declare seed DB asset

**Risks:**
- **Schema coupling:** Pre-built Content DB must match `ContentDatabase` Drift class. Mitigation: build tool imports Drift schema definitions directly; CI validates schema match.
- Storage — ~260-340 MB uncompressed in SQLite. Acceptable for modern devices.

---

### Stream 3: Local Calendar Cycle Computation (CRITICAL PATH)

**Problem:** All 12 calendar programs depend on Sefaria/Hebcal APIs. Zero local computation exists.

**Solution:**

1. **Local Calendar Engine**
   - New service: `LocalCalendarEngine`
   - For each program: known epoch date + ordered list of refs = deterministic cycle
   - Computation: `dayIndex = daysSince(epoch) % cycleLength` → lookup ref from ordered list

2. **Cycle Data — Reverse Engineering Approach**
   - Build a tool that queries Sefaria/Hebcal APIs for a full cycle of each program
   - Record the ordered sequence of refs for the complete cycle
   - Store in the **pre-built seed database** (see Stream 2) — `calendar_cycles` table
   - Each row contains: program ID, epoch date, day index, ref string

3. **12 Programs to Reverse-Engineer**

   | Program | Source | Cycle Length | Approach |
   |---------|--------|-------------|----------|
   | Daf Yomi | Sefaria | 2,711 daf | Query Sefaria calendar for full cycle from known epoch (2020-01-05) |
   | Mishna Yomit | Sefaria | ~2,088 mishnayos | Query Sefaria for cycle sequence |
   | Nach Yomi | Sefaria | ~929 chapters | Query Sefaria for cycle sequence |
   | Yerushalmi Yomi | Sefaria | ~1,554 daf | Query Sefaria for cycle sequence |
   | Daf a Week | Sefaria | 2,711 daf (weekly) | Same order as Daf Yomi, 1 per week |
   | Rambam 1 Chapter | Sefaria | ~985 chapters | Query Sefaria for cycle sequence |
   | Rambam 3 Chapters | Sefaria | ~339 days | Query Sefaria for cycle sequence |
   | Halakhah Yomit | Sefaria | Variable | Query Sefaria — may need special handling |
   | Tanakh Yomi | Sefaria | ~929 entries | Query Sefaria for cycle sequence |
   | Arukh HaShulchan Yomi | Sefaria | Variable | Query Sefaria — may need special handling |
   | Chofetz Chaim Daily | Hebcal | ~197 days | Query Hebcal for full cycle |
   | Kitzur SA Yomi | Hebcal | ~221 simanim | Query Hebcal for full cycle |

4. **Reverse-Engineering Tool**
   - Part of unified `tool/seed_content_db.dart` (see Stream 2)
   - For Sefaria programs: iterate day-by-day through `/calendars?year=Y&month=M&day=D` for full cycle
   - For Hebcal programs: iterate through `/hebcal?start=DATE&end=DATE` for full cycle
   - Output: rows in `calendar_cycles` table within the pre-built seed database
   - Rate limiting: 1-2 requests/second to respect API limits
   - One-time build step — cycles only change every several years

5. **Fallback Chain**
   ```
   LocalCalendarEngine.getToday(program)
     → Compute from bundled cycle data (always available)

   If online (optional enhancement):
     → Validate against API response
     → Log discrepancy if found (for cycle transition alerts)
   ```

6. **Cycle Transition Handling**
   - Most cycles restart at a known date
   - Bundle next cycle start dates as metadata
   - App can warn: "New Daf Yomi cycle starts [date] — update app for new cycle data"
   - For long cycles (7.5 years for Daf Yomi), this is rarely needed

**Affected Files:**
- `lib/core/services/local_calendar_engine.dart` — New service
- `lib/core/services/calendar_program_service.dart` — Use local engine as primary source
- `lib/core/providers/calendar_providers.dart` — Wire in local engine
- `tool/seed_content_db.dart` — Calendar cycle seeding integrated into unified seed tool (see Stream 2)

**Risks:**
- Some programs may have irregular cycles or mid-cycle adjustments. Mitigation: reverse-engineering a full cycle from the API will capture any irregularities.
- Cycle data becomes stale when a new cycle starts. Mitigation: bundle metadata for next cycle boundaries; prompt user to update app if approaching end of bundled data.

---

### Stream 4: Startup & Connectivity Hardening (INTEGRATION)

**Depends on:** Streams 1-3

**Changes:**

1. **`main.dart` Startup Sequence**
   ```
   Current:
     Firebase.initializeApp()       ← may fail offline
     GoogleSignIn.initialize()      ← may hang offline
     NotificationInit               ← already safe
     runApp()

   Target:
     NotificationInit               ← safe
     Check: has local profile?
       Yes → runApp() immediately (no Firebase needed)
       No  → runApp() → onboarding (no Firebase needed)
     Background: try Firebase.initializeApp() if online
     Background: activate SyncEngine if Firebase + account available
   ```

2. **ConnectivityService Optimization**
   - Check platform connectivity first (instant, no network call)
   - Only DNS-check if platform says "connected" (avoid false positives)
   - 2-second timeout instead of 5 seconds
   - Cache result for 30 seconds to avoid repeated checks

3. **SyncEngine Conditional Activation**
   - `SyncEngine` starts dormant by default
   - Activates only when: user has Firebase account AND network is available
   - Deactivates cleanly when network drops (no error states)
   - `SyncLifecycleObserver` checks both conditions before attaching listeners

4. **Offline Queue Behavior**
   - For local-only users (no account): queue is disabled entirely (no-op)
   - For account users offline: existing queue behavior unchanged
   - Dead-lettered items resurrected on next connectivity (remove 5-retry cap for permanent failures)

---

## 5. Content Size Estimates

| Content Type | Items | Notes |
|-------------|-------|-------|
| Hierarchy JSON (existing) | ~61,858 | Already bundled, loaded in-memory (~4 MB) |
| Text - Bavli | 5,471 | Pre-built in seed DB |
| Text - Mishnayos | 4,192 | Pre-built in seed DB |
| Text - Yerushalmi | 2,211 | Pre-built in seed DB |
| Text - Chumash | 5,846 | Pre-built in seed DB |
| Text - Mishna Berurah | 17,397 | Pre-built in seed DB |
| Text - Nach | 17,360 | Pre-built in seed DB |
| Text - Mussar | 51 | Pre-built in seed DB |
| Calendar cycles (12) | ~12,000 refs | Pre-built in seed DB |
| **Seed DB (compressed, in APK)** | | **~45-60 MB estimated** |
| **Seed DB (uncompressed, on device)** | | **~260-340 MB estimated** |

---

## 6. Implementation Sequence

```
Phase 1: Two-Database Split (Foundation)
  ├─ Split current AppDatabase into ContentDatabase + UserDatabase
  │   ├─ ContentDatabase: TextCache, CalendarCycles, LearningPrograms, SeedMetadata
  │   ├─ UserDatabase: all user/progress/sync tables (20 tables)
  │   ├─ Both start at schema v1 (clean slate, app not yet deployed)
  │   └─ Two Riverpod providers: contentDatabase + userDatabase
  ├─ SeedManager: decompress seed.db.gz → content.db on first launch/upgrade
  ├─ Update all DAOs and repositories to use correct database reference
  └─ Update all existing tests for two-database setup

Phase 2: Seed Database Build Tool + Content
  ├─ Build `tool/seed_content_db.dart`
  │   ├─ Creates ContentDatabase matching Drift schema
  │   ├─ Populates TextCache (~52,528 rows from Sefaria)
  │   ├─ Populates CalendarCycles (reverse-engineer 12 programs, date-keyed 2024-2030)
  │   ├─ Populates LearningPrograms (from existing seed data)
  │   └─ Outputs compressed `assets/seed.db.gz`
  ├─ CI step: validate seed DB schema matches ContentDatabase class
  ├─ LocalCalendarEngine service (reads CalendarCycles from Content DB)
  └─ Wire into CalendarProgramService as primary source

Phase 3: Local-First Auth & Startup (Streams 1 + 4)
  ├─ Local profile system + auth abstraction
  ├─ Remove sign-in wall
  ├─ Startup sequence hardening
  └─ SyncEngine conditional activation (syncs User DB only)

Phase 4: Integration & Polish
  ├─ End-to-end testing: fresh install → full use → no network
  ├─ App upgrade testing: new seed.db.gz → content replaced, user data intact
  ├─ Optional account creation flow in Settings
  ├─ UID migration (local → Firebase) in User DB
  ├─ Sync activation/deactivation UX
  └─ Offline indicator (subtle, non-intrusive)
```

---

## 7. Affected Requirements

### Updated NFRs

| NFR | Current | Proposed Update |
|-----|---------|----------------|
| NFR22 | Core features work without network | **All features work without network, including first launch** |
| NFR23 | Identical UX online/offline for core features | **Identical UX online/offline for ALL features** |
| NFR24 | SQLite as source of truth | Unchanged — reinforced |
| NEW | — | **App shall be fully functional without ever connecting to the internet after installation** |
| NEW | — | **Account creation shall be optional and deferrable** |
| NEW | — | **All curriculum text content shall be bundled with the application** |
| NEW | — | **All calendar program schedules shall be computable locally** |

### Updated FRs

| FR | Current | Proposed Update |
|----|---------|----------------|
| FR88 | Core features accessible offline | **All features accessible from first launch without network** |
| NEW | — | **System creates local profile on first launch without requiring authentication** |
| NEW | — | **System hydrates text cache from bundled assets on first launch** |
| NEW | — | **System computes daily calendar program assignments locally** |
| NEW | — | **User can optionally create account to enable cloud sync at any time** |
| NEW | — | **System transparently activates sync when account exists and network is available** |
| NEW | — | **System migrates local profile data to cloud account atomically on account creation** |

### Updated Architecture Decisions

| Decision | Current | Proposed Update |
|----------|---------|----------------|
| D2 (Auth) | Email/password + Google Sign-In required | **Local-first auth default. Firebase Auth optional for sync.** |
| D4 (Sync) | Hybrid push/pull with foreground listeners | **Sync layer is conditional — dormant without account, activates transparently when account + network exist. Syncs User DB only.** |
| NEW | — | **D-OFFLINE: All content (text, hierarchy, calendar cycles) bundled in APK. No runtime content fetching required.** |
| NEW | — | **D-TWODB: Application uses two separate SQLite databases. Content DB (read-only, pre-built, replaced on upgrade) and User DB (read-write, Drift-managed migrations). No hard foreign keys between databases — string identifiers only. Guarantees content updates can never cause user data loss.** |

---

## 8. Deep-Dive Research Findings (2026-03-29)

Comprehensive research was conducted across all streams. Detailed analysis documents are linked below. This section captures the key findings, resolved decisions, and remaining risks.

### Reference Documents

| Document | Location |
|----------|----------|
| Calendar Cycle Computation Analysis | `_bmad-output/planning-artifacts/calendar-cycle-computation-analysis.md` |
| Seed Database Build Tool Design | `_bmad-output/implementation-artifacts/seed-database-build-tool-design.md` |
| Local-First Auth Abstraction Layer | `_bmad-output/planning-artifacts/local-first-auth-abstraction-layer.md` |
| Two-Database Drift Architecture | `_bmad-output/planning-artifacts/two-database-drift-architecture.md` |

### 8.1 Critical Bugs Found in Current Calendar Registry

**Only 6 of 12 calendar programs work today.** The following bugs exist in `CalendarProgramRegistry` and `HebcalApiClient`:

| Bug | Impact | Fix |
|-----|--------|-----|
| `nach_yomi` configured as `apiSource: 'sefaria'` | Nach Yomi not available from Sefaria — never returns data | Change to `apiSource: 'hebcal'` with flag `nyomi=on` |
| `mishna_yomit` apiKey = `"Mishnah Yomit"` | Sefaria returns `"Daily Mishnah"` — key mismatch, no match | Change apiKey to `"Daily Mishnah"` |
| `rambam_1_chapter` apiKey = `"Daily Rambam 1 Chapter"` | Sefaria returns `"Daily Rambam"` — key mismatch | Change apiKey to `"Daily Rambam"` |
| `rambam_3_chapters` apiKey = `"Daily Rambam 3 Chapters"` | Sefaria returns `"Daily Rambam (3 Chapters)"` — key mismatch | Change apiKey to `"Daily Rambam (3 Chapters)"` |
| HebcalApiClient missing `dcc=on` flag | Chofetz Chaim Daily never fetched from Hebcal | Add `dcc=on` to query params |
| HebcalApiClient missing `dksa=on` flag | Kitzur SA Yomi never fetched from Hebcal | Add `dksa=on` to query params |
| Hebcal matching uses `item.title` instead of `item.category` | Wrong field for program identification | Match on `item.category` |

**Action:** Fix these bugs as a prerequisite story before Epic 19 calendar work.

### 8.2 Calendar Cycle Computation — Resolved

All 12 programs are deterministic and can be pre-computed, but **not all via simple modular arithmetic**:

| Complexity | Programs | Approach |
|-----------|----------|----------|
| Simple fixed cycle | Daf Yomi, Daf a Week, Nach Yomi | `daysSince(epoch) % cycleLength` works |
| Fixed but irregular | Mishna Yomit, Yerushalmi Yomi, Rambam 1/3, Tanakh Yomi | Some segments vary in length — capture full sequence |
| Hebrew calendar dependent | Chofetz Chaim, Kitzur SA | Cycle length varies by Hebrew year (leap years) |
| Variable segments | Halakhah Yomit, Arukh HaShulchan Yomi | Segment sizes vary — must capture exact sequence |

**Decision: Date-keyed flat table.** Instead of storing cycle offsets, store `(program_id, date) → sefaria_ref` for a date range (2024-2030). This handles ALL programs uniformly — no special-case math at query time. ~30,684 rows covering 7 years. Trivial query: `SELECT ref FROM calendar_cycles WHERE program_id = ? AND date = ?`.

**Seed tool runtime:** ~22 minutes (Sefaria: ~2,557 day-by-day requests at 2/sec; Hebcal: ~84 monthly batch requests).

**Cycle transition risk:** Daf Yomi Cycle 14 ends 2027-06-07 — highest risk boundary. Yerushalmi Yomi (first cycle ever) may end ~2027 with unknown Cycle 2 details. Both within the 2024-2030 seeding window.

### 8.3 Two-Database Architecture — Resolved

**Content DB tables (4 tables):**

| Table | Rows | Notes |
|-------|------|-------|
| TextCache | ~52,528 | All Sefaria text (Hebrew + English) |
| CalendarCycles | ~30,684 | Date-keyed: (program_id, date) → ref, covering 2024-2030 |
| LearningPrograms | 9 | Program presets with stage/test config |
| SeedMetadata | 1 | Version, build date, content hash |

**Note:** `TestDates` removed from Content DB — Dirshu test reminders are a separate feature that should be scoped in its own ticket if needed. `ContentDownloadStatuses` and `TextDownloadStatuses` eliminated entirely (not needed with bundled content). `CalendarCache` replaced by `CalendarCycles`.

**User DB tables (20 tables):** All user/progress/sync tables. Both databases start at schema v1.

**Drift code generation:** Works out of the box with two `@DriftDatabase` classes, no special configuration needed. ~94 files affected in the split, estimated ~13 hours implementation.

### 8.4 Auth Abstraction — Resolved

**Key decisions:**
- `UserProfiles.firebaseUid` becomes nullable; new `localUid` column (v4 UUID) added
- Sealed `AppAuthState` type (`LocalAuthState` / `CloudAuthState`) via Riverpod notifier
- `AuthGuard` replaced with `LocalAuthGuard` — reads local state synchronously, never hangs
- `Firebase.initializeApp()` deferred to background after `runApp()` — startup in ~140ms
- `GoogleSignIn.initialize()` fully deferred to first Google sign-in tap
- UID migration is simple: only `UserProfiles` has `firebaseUid` — all other tables chain through integer PKs

### 8.5 Sync & Onboarding — Resolved

**Key decisions:**
- SyncEngine takes `UserDatabase` (not `AppDatabase`) — Content DB never synced
- `syncEngineProvider` returns `null` for local-only users; callers guard with `?.`
- Offline queue **disabled** for local-only users; new `pushAllLocalData()` on account creation
- Onboarding removes `AccountCreationScreen` and `ModeSelectionScreen` from mandatory flow
- `AddTrackFlow` already works 100% offline — zero Firebase dependencies
- `RestoreGuard` skips entirely for unauthenticated users

### 8.6 Text Content Bundling — Resolved

**Key findings:**
- Existing `seed_text_content.dart` missing `nach` and `mussar` curricula — must be added
- Estimated seed DB: ~85-95 MB raw SQLite, **~22-30 MB gzipped** in APK
- Well within Play Store 150 MB APK limit
- Hebrew text stored with nikud; stripping done at display time (no change needed)
- `TextDownloadService` repurposed as optional `TextUpdateService` for delta updates (future)

### 8.7 Content Freshness Strategy

**Decision: App-store-only updates for initial release.** Re-run seed tool before each release. Future enhancement: optional delta updates using an overlay pattern (updates written to User DB TextCache, which takes precedence over Content DB on lookup).

---

## 9. Remaining Open Items

| # | Item | Owner | Priority | Notes |
|---|------|-------|----------|-------|
| 1 | Fix 7 calendar registry bugs | Dev | **Pre-Epic 19** | Blocks calendar seed tool validation |
| 2 | Exact compressed size of seed DB | Dev | During build | Run `seed_content_db.dart` and measure |
| 3 | Seed DB decompression time on low-end device | Dev | During integration | Benchmark on API 21 target |
| 4 | Firebase SDK lazy init behavior | Dev | During auth stream | Does SDK phone home even without sign-in? |
| 5 | Yerushalmi Yomi Cycle 2 details | Analyst | Before 2027 | First cycle ever — may need research when approaching end |
| 6 | Seed DB schema validation in CI | Dev | During build tool | `--validate-only` mode for PR checks |
| 7 | `ProfilePrograms.programId` cross-DB FK | Dev | During DB split | Consider adding `programName` text column as stable cross-DB key |

---

## 10. Success Criteria

- [ ] Fresh install on airplane-mode device → complete onboarding → full app use
- [ ] All 7 curricula: browse hierarchy + read Hebrew/English text — no network
- [ ] All 12 calendar programs show correct "today's learning" — no network
- [ ] User creates account weeks later → all local data syncs to cloud
- [ ] Second device signs in → pulls all data from first device
- [ ] Network drops mid-session → zero UX disruption
- [ ] App never shows loading spinners waiting for network responses in core flows
