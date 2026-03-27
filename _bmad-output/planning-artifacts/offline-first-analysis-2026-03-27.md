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

### 3.1 Architecture Principle: Local-First, Sync-Optional

```
┌─────────────────────────────────────────────────┐
│                   App Layer                       │
│  (All features work identically regardless of    │
│   network state or account existence)            │
├─────────────────────────────────────────────────┤
│               Local Data Layer                    │
│  ┌───────────┐ ┌──────────┐ ┌────────────────┐  │
│  │  SQLite   │ │  Text    │ │  Calendar      │  │
│  │  (Drift)  │ │  Cache   │ │  Engine        │  │
│  │  Source   │ │  Bundled │ │  Local Compute │  │
│  │  of Truth │ │  + Cache │ │                │  │
│  └───────────┘ └──────────┘ └────────────────┘  │
├─────────────────────────────────────────────────┤
│          Transparent Sync Layer (Optional)        │
│  ┌──────────────────────────────────────────┐    │
│  │  SyncEngine (activates when online +     │    │
│  │  user has account — otherwise dormant)   │    │
│  │  • Push-on-write (queued)                │    │
│  │  • Pull-on-launch (if available)         │    │
│  │  • Foreground listeners (if available)   │    │
│  └──────────────────────────────────────────┘    │
├─────────────────────────────────────────────────┤
│           Optional Account Layer                  │
│  ┌──────────────────────────────────────────┐    │
│  │  Firebase Auth (user opts in when ready) │    │
│  │  • Enables multi-device sync             │    │
│  │  • Enables cloud backup                  │    │
│  │  • Can be created at any time            │    │
│  └──────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

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

**Solution:**

1. **Bundle Text Assets**
   - Add gzipped text JSON files to `assets/content/text/`
   - One file per curriculum (same format as GitHub Releases downloads):
     - `bavli_text.json.gz` (~15-20 MB)
     - `mishnayos_text.json.gz` (~3-5 MB)
     - `yerushalmi_text.json.gz` (~8-10 MB)
     - `chumash_text.json.gz` (~2-3 MB)
     - `mishna_berurah_text.json.gz` (~10-15 MB)
     - `nach_text.json.gz` (~5-8 MB)
     - `mussar_text.json.gz` (<1 MB)
   - **Total estimated APK increase: ~45-60 MB**

2. **First-Launch Hydration**
   - On first launch, decompress and load bundled text into `TextCache` table
   - Use existing batch insert logic (500 items/batch with checkpoints)
   - Mark all curricula as "downloaded" in `TextDownloadStatuses`
   - Show progress indicator during hydration ("Preparing your library...")
   - Hydration is one-time — subsequent launches skip this step

3. **Hydration Performance Estimate**
   - ~52,528 items at 500/batch = ~105 batches
   - Each batch: decompress + parse + insert transaction
   - Estimated time: 30-90 seconds on mid-range device
   - Must be interruptible and resumable (checkpoint after each batch)

4. **Build Pipeline Update**
   - `tool/seed_text_content.dart` output copied to `assets/content/text/`
   - CI/CD includes text content in APK build
   - Version tracking for future content updates

**Affected Files:**
- `assets/content/text/` — New directory with gzipped text JSON
- `lib/features/content_browsing/data/services/text_download_service.dart` — Add hydration-from-assets path
- `lib/core/database/daos/text_cache_dao.dart` — Batch insert (existing)
- `pubspec.yaml` — Declare new assets

**Risks:**
- First-launch time — 30-90 second hydration could feel slow. Mitigation: show engaging progress UI, allow partial use during hydration.
- Storage — ~200-400 MB uncompressed in SQLite. Acceptable for modern devices.

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
   - Store as bundled JSON asset: `assets/content/calendars/{program}_cycle.json`
   - Each file contains: `{ epoch: "YYYY-MM-DD", refs: ["ref1", "ref2", ...] }`

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
   - New build tool: `tool/seed_calendar_cycles.dart`
   - For Sefaria programs: iterate day-by-day through `/calendars?year=Y&month=M&day=D` for full cycle
   - For Hebcal programs: iterate through `/hebcal?start=DATE&end=DATE` for full cycle
   - Output: JSON cycle files with epoch + ordered ref sequence
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
- `assets/content/calendars/` — New directory with cycle JSON files
- `tool/seed_calendar_cycles.dart` — New build tool
- `pubspec.yaml` — Declare calendar assets

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

| Content Type | Items | Compressed | Uncompressed (SQLite) |
|-------------|-------|------------|----------------------|
| Hierarchy JSON (existing) | ~61,858 | ~4 MB | In-memory |
| Text - Bavli | 5,471 | ~15-20 MB | ~80-100 MB |
| Text - Mishnayos | 4,192 | ~3-5 MB | ~20-30 MB |
| Text - Yerushalmi | 2,211 | ~8-10 MB | ~40-50 MB |
| Text - Chumash | 5,846 | ~2-3 MB | ~15-20 MB |
| Text - Mishna Berurah | 17,397 | ~10-15 MB | ~60-80 MB |
| Text - Nach | 17,360 | ~5-8 MB | ~40-50 MB |
| Text - Mussar | 51 | <1 MB | <1 MB |
| Calendar cycles (12) | ~12,000 refs | <1 MB | <1 MB |
| **Total APK increase** | | **~45-60 MB** | |
| **Total device storage** | | | **~260-340 MB** |

---

## 6. Implementation Sequence

```
Phase 1: Foundation (Streams 1 + 4 startup)
  ├─ Local profile system + auth abstraction
  ├─ Remove sign-in wall
  ├─ Startup sequence hardening
  └─ SyncEngine conditional activation

Phase 2: Content (Stream 2) — can parallel with Phase 1 tooling
  ├─ Verify text seed tooling produces correct output
  ├─ Bundle text assets in APK
  ├─ First-launch hydration service
  └─ Progress UI for hydration

Phase 3: Calendar (Stream 3) — can parallel with Phase 2
  ├─ Build reverse-engineering tool
  ├─ Run tool to capture all 12 program cycles
  ├─ Validate cycle data for accuracy
  ├─ LocalCalendarEngine service
  └─ Wire into CalendarProgramService as primary source

Phase 4: Integration & Polish
  ├─ End-to-end testing: fresh install → full use → no network
  ├─ Optional account creation flow in Settings
  ├─ UID migration (local → Firebase) atomic transaction
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
| D4 (Sync) | Hybrid push/pull with foreground listeners | **Sync layer is conditional — dormant without account, activates transparently when account + network exist** |
| NEW | — | **D-OFFLINE: All content (text, hierarchy, calendar cycles) bundled in APK. No runtime content fetching required.** |

---

## 8. Open Items for Further Investigation

| # | Item | Owner | Notes |
|---|------|-------|-------|
| 1 | Exact compressed size of each curriculum's text content | Dev | Run `seed_text_content.dart` and measure output |
| 2 | First-launch hydration time on low-end Android device | Dev | Benchmark with API 21 target device |
| 3 | Firebase SDK network behavior when auth unused | Dev | Does SDK phone home even without sign-in? May need build flavor or lazy init |
| 4 | Irregular calendar cycles (Halakhah Yomit, Arukh HaShulchan) | Analyst | Reverse-engineer and verify for edge cases |
| 5 | UID migration transaction scope | Dev | Audit all tables with profileId/uid foreign keys |
| 6 | Play Store APK size limits | Dev | Current limit ~150 MB for APK, unlimited for AAB with asset packs |
| 7 | Cycle transition dates for all 12 programs | Analyst | Document when each current cycle ends |

---

## 9. Success Criteria

- [ ] Fresh install on airplane-mode device → complete onboarding → full app use
- [ ] All 7 curricula: browse hierarchy + read Hebrew/English text — no network
- [ ] All 12 calendar programs show correct "today's learning" — no network
- [ ] User creates account weeks later → all local data syncs to cloud
- [ ] Second device signs in → pulls all data from first device
- [ ] Network drops mid-session → zero UX disruption
- [ ] App never shows loading spinners waiting for network responses in core flows
