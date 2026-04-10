---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'evolved'
completedAt: '2026-02-08'
evolvedAt: '2026-03-27'
evolution: 'offline-first'
inputDocuments:
  - '_bmad-output/planning-artifacts/product-brief-learning-tracker-2026-01-03.md'
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/epics.md'
  - '_bmad-output/project-context.md'
  - '_bmad-output/implementation-artifacts/tech-spec-learning-tracker-v1-complete.md'
  - '_bmad-output/implementation-artifacts/1-1-initialize-flutter-project-with-architecture-foundations.md'
  - '_bmad-output/planning-artifacts/architecture-v1-2026-01-04.md'
workflowType: 'architecture'
project_name: 'learning-tracker'
user_name: 'Daniel'
date: '2026-02-08'
previousEdition: '_bmad-output/planning-artifacts/architecture-v1-2026-01-04.md'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Revised Scope: "Learning Tracker" (formerly "Learning Tracker")

The user's Revised Requirements Framework fundamentally transforms this project from a single-curriculum bar mitzvah tracker into a configurable multi-curriculum Torah learning platform for children AND adults. Key scope changes:

- **Name:** Learning Tracker → Learning Tracker
- **Curricula:** Single (Mishnayos) → Multi (Mishnayos, Gemara Bavli, Yerushalmi, Mishna Berurah, Chumash via Sefaria)
- **Users:** Child-only → Child mode + Adult mode
- **Learning stages:** Hardcoded 3-stage → Configurable N-stage with user-defined timing
- **Content hierarchy:** Single → Distinct model per curriculum type
- **Tracks:** Global multi-track → Multi-track per curriculum (personal/school/tutor within each)
- **Goals/deadlines:** Single bar mitzvah date → Per-curriculum configurable goals
- **Parent mode:** Always available → Optional, child accounts only
- **Tutor mode:** Child accounts only → Optional for any user
- **Dashboard:** Single curriculum → Cross-curriculum aggregation
- **Learning order:** Fixed → Drag-and-drop configurable per curriculum
- **Data sync:** Backup only → Multi-device sync with account-based auth

### Requirements Overview

**Functional Requirements:**

The v1 PRD defines 84 functional requirements across 14 categories (FR1-FR84) and 47 non-functional requirements (NFR1-NFR47). The Revised Requirements Framework expands and transforms these significantly:

**Content & Curriculum (replaces FR1-FR4):**
- Multi-curriculum support: Mishnayos, Gemara Bavli, Yerushalmi, Mishna Berurah, Chumash (via Sefaria API)
- Distinct content hierarchy per curriculum type:
  - Mishnayos: seder → masechta → perek → mishna (4,192 items)
  - Gemara Bavli: masechta → daf → amud
  - Gemara Yerushalmi: masechta → daf → halacha
  - Mishna Berurah: siman → seif → seif katan
  - Chumash: sefer → parsha → perek → pasuk
- Each curriculum is independently browseable with Hebrew + English text from Sefaria
- Curriculum types are configurable and extensible

**Learning Stages (replaces FR10-FR16):**
- Configurable N-stage learning cycle per curriculum (not hardcoded 3-stage)
- Default stages: learn → chazara 1 (+1 day) → chazara 2 (+7 days)
- Users can customize stage count and timing intervals per curriculum
- Immutability and append-only completion log principles carry forward
- Automatic chazara scheduling based on configurable timing rules

**Multi-Track Per Curriculum (replaces FR5-FR9):**
- Personal/school/tutor tracks apply within each curriculum independently
- Personal track mandatory per curriculum with AI-driven scheduling
- School and tutor tracks optional per curriculum
- Track bookmarks maintained per-curriculum-per-track
- Duplicate prevention within each curriculum's track system

**Smart Scheduling (replaces FR17-FR21):**
- Per-curriculum scheduler instances with configurable parameters
- Parametric algorithm adapting to N stages and configurable timing
- Per-curriculum goals and deadlines (not just bar mitzvah date)
- Adaptive pacing per curriculum based on individual progress
- Cross-curriculum daily recommendation aggregation

**User Modes (new requirement):**
- Child mode: Full gamification, parent oversight available, age-appropriate presentation
- Adult mode: Self-directed, minimal gamification, no parent mode available
- Tutor mode: Optional for any user type (not just child accounts)
- Parent mode: Available only for child accounts

**Progress & Dashboard (replaces FR22-FR29):**
- Cross-curriculum dashboard showing all active curricula
- Per-curriculum progress views with curriculum-appropriate hierarchy
- Aggregate statistics across curricula
- Per-curriculum pace status and projected completion dates

**Gamification (replaces FR30-FR39):**
- Points and streaks apply differentially based on user mode
- Child mode: Full gamification with mystery rewards, streak tracking, animations
- Adult mode: Minimal gamification (progress tracking, optional streaks)
- Per-curriculum progress visualization

**Learning Order (new requirement):**
- Drag-and-drop learning order configuration per curriculum
- User-defined sequence for units within each curriculum level

**Multi-Device Sync (replaces FR64-FR71 sync portions):**
- Account-based authentication (replaces Anonymous Auth) for multi-device identity
- Real-time Firestore listeners for cross-device change propagation
- Additive merge for append-only data (completion logs) - no conflicts possible
- Last-write-wins with UTC timestamps for mutable data (bookmarks, settings)
- New-device onboarding: restore full state from Firestore
- Offline operation unchanged - queue local changes, sync when reconnected

**Non-Functional Requirements:**

Critical NFRs from v1 that carry forward with increased scope:

- **Performance (NFR1-NFR10):** Unchanged targets but now applied across potentially 5+ curricula of data. Sub-100ms queries must hold with larger datasets.
- **Reliability & Data Integrity (NFR11-NFR21):** Zero data loss requirement now spans multiple curricula. Transaction safety more complex with per-curriculum isolation.
- **Offline Capability (NFR22-NFR27):** Same offline-first architecture, but first-launch sync now potentially much larger (multiple curricula).
- **Security (NFR28-NFR35):** PIN model unchanged per-device. Firestore rules need per-curriculum scoping. Account-based auth replaces anonymous auth.
- **Integration (NFR36-NFR44):** Sefaria API surface expands from Mishnayos-only to 5+ text types with different API endpoints and response formats.

**Scale & Complexity:**

- Primary domain: Mobile app (edtech)
- Complexity level: **Medium-High** (up from Medium)
- Estimated architectural components:
  - Presentation Layer: 25-35 screens/views (multi-curriculum browsing, per-curriculum dashboards, mode selection, curriculum management, drag-and-drop configuration)
  - Domain Layer: 12-15 core business logic services (curriculum engine, parametric scheduler, multi-mode tracker, cross-curriculum aggregator, configurable stage manager)
  - Data Layer: 3 persistence mechanisms (SQLite via drift, Firebase Cloud Firestore, flutter_secure_storage) with polymorphic content models
  - Integration Layer: Expanded Sefaria API (5+ text type endpoints), kosher_dart calendar
- Data architecture:
  - ~4,200+ items per curriculum (varies by type)
  - Multiplicative completion records (items x stages x curricula)
  - Per-curriculum track state, bookmarks, goals
  - Configurable stage definitions per curriculum
  - Cross-curriculum aggregated statistics

### Technical Constraints & Dependencies

**Platform Constraints (unchanged from v1):**
- Flutter/Dart framework, Android-only deployment for v1.0
- Minimum Android API 21, target latest stable
- Mid-range device performance targets
- Direct APK distribution for v1.0

**External Dependencies (expanded):**
- **Firebase:** Account-based Authentication (email/password or Google Sign-In), Cloud Firestore with per-curriculum collections and multi-device sync
- **Sefaria API:** Expanded from Mishnayos endpoint to Bavli, Yerushalmi, Mishna Berurah, Chumash endpoints - each with different response structures
- **kosher_dart:** Hebrew calendar for deadline tracking across curricula
- **Flutter packages:** Same core stack (drift, auto_route, riverpod, freezed, dio, talker)

**New Architectural Constraints:**
- Polymorphic content models: Each curriculum type has a distinct hierarchy that must be modeled independently while sharing a common interface for tracking/scheduling
- Configurable stage system: Stage count, timing intervals, and labels must be stored as configuration, not hardcoded
- Conditional feature rendering: UI must adapt based on user mode (child vs adult) without separate codebases
- Per-curriculum isolation: Goals, deadlines, schedulers, tracks, and progress must be fully isolated per curriculum while supporting cross-curriculum aggregation
- Multi-device consistency: Real-time sync with conflict resolution for concurrent edits across devices

**Data Integrity Constraints (expanded from v1):**
- Immutability enforcement per-curriculum-per-stage
- Append-only completion log per curriculum
- Multi-track uniqueness per curriculum (not global)
- Transaction atomicity for cross-table curriculum operations
- Curriculum deletion safety: Handle orphaned progress data
- Multi-device merge safety: Additive merge for completions, timestamp-based for mutable state

### What Survives from v1 Architecture

**Unchanged (carry forward directly):**
- Flutter/Dart framework choice and Android-only v1.0 target
- Offline-first with SQLite (drift) as local source of truth
- Clean architecture with feature-first organization
- Type-safe code generation stack (drift, auto_route, freezed, riverpod_generator, build_runner)
- Talker logging framework with dio/riverpod integrations
- Mocktail for testing (no codegen)
- PIN-based parent/tutor mode security (flutter_secure_storage, bcrypt)
- Hebrew calendar support (kosher_dart)
- RTL support, Material Design 3
- All naming conventions (SQL snake_case, Dart PascalCase/camelCase, routes kebab-case)
- Testing patterns, code quality rules, development workflow
- Core NFR targets (performance, reliability, offline capability)

**Needs fundamental rework:**
- Database schema: Mishnayos-specific tables → curriculum registry + polymorphic content tables
- Content models: Single `Mishnas` table → distinct hierarchies per curriculum type
- Scheduler algorithm: Hardcoded 3-stage math → parametric N-stage model per curriculum
- Feature modules: Expanded for curriculum management, multi-curriculum dashboard, configurable stages
- Onboarding: Multi-mode selection (child vs adult), curriculum selection, per-curriculum goal setting
- Authentication: Anonymous Auth → account-based auth for multi-device
- Sync strategy: Backup-only → bidirectional multi-device sync with real-time listeners
- App identity: Package name and branding from "mishnayos" to "learning-tracker"

### Cross-Cutting Concerns Identified

**1. Curriculum Abstraction Layer (NEW)**
- Generic curriculum interface with type-specific implementations
- Content hierarchy varies per curriculum type
- Sefaria API integration differs per curriculum
- Common tracking/scheduling interface regardless of curriculum
- Must be extensible for future curriculum types without schema changes

**2. Configurable Stage Engine (NEW)**
- Stage definitions stored as structured configuration per curriculum
- Scheduling algorithm parameterized by stage count and timing rules
- Default configurations per curriculum type with user overrides
- Stage progression enforcement respects per-curriculum configuration

**3. User Mode System (NEW)**
- Child vs Adult mode affects feature visibility, gamification level, access controls
- Mode selection at account creation, potentially switchable
- Parent mode availability conditional on child mode
- Tutor mode available regardless of user mode

**4. Multi-Device Data Synchronization (evolved from v1)**
- SQLite is local source of truth per device; Firestore is shared source of truth across devices
- Account-based authentication for multi-device identity
- Real-time Firestore listeners for cross-device change propagation
- Additive merge for append-only data (completion logs) - no conflicts possible
- Last-write-wins with UTC timestamps for mutable data (bookmarks, settings)
- New-device onboarding: restore full state from Firestore
- Offline operation unchanged - queue local changes, sync when reconnected

**5. Offline-First Architecture (unchanged)**
- Same design principles as v1
- Larger potential dataset if multiple curricula active

**6. State Management (evolved from v1)**
- Riverpod-based reactive state (unchanged)
- Multi-curriculum state coordination adds complexity
- Cross-curriculum dashboard requires aggregate providers
- Per-curriculum providers scoped by curriculum ID

**7. Security & Access Control (evolved)**
- Account-based authentication (replaces anonymous auth)
- PIN-based mode authentication per device (not synced)
- Role-based permissions (parent, tutor, child/adult)
- Mode availability differs by account type

**8. Performance Optimization (heightened importance)**
- Database queries must remain sub-100ms with multi-curriculum data
- ListView performance with potentially larger content sets
- Scheduler computation across multiple curricula must remain sub-500ms
- Cross-curriculum dashboard aggregation performance

**9. Hebrew Calendar & Internationalization (unchanged)**
- Hebrew date display, RTL layout, bidirectional text
- Per-curriculum deadlines may use Hebrew or English dates

**10. Sefaria API Expansion (evolved from v1)**
- Multiple API endpoints for different text types
- Different response schemas per curriculum
- Response normalization into common format for storage
- Graceful per-curriculum fallback on API failure

## Starter Template Evaluation

### Primary Technology Domain

**Mobile app (Android)** based on project requirements analysis. Flutter/Dart cross-platform framework with Android-only deployment for v1.0, targeting mid-range devices (API 21+). Unchanged from v1.

### Existing Technical Preferences (from project-context.md and v1 architecture)

- Framework: Flutter/Dart (latest stable)
- Platform: Android, API 21+, Kotlin native code
- State management: Riverpod + riverpod_generator (code generation)
- Database: drift (SQLite ORM) with drift_flutter for platform setup
- Navigation: auto_route (type-safe, code generated)
- Data classes: freezed (immutable, code generated)
- HTTP: dio (interceptors, retry logic)
- Logging: talker suite (talker_flutter, talker_dio_logger, talker_riverpod_logger)
- Testing: mocktail (null-safe, no codegen)
- Backend: Firebase (auth, Cloud Firestore)
- Code generation: Unified build_runner for all codegen packages

### Starter Options Considered

**1. Official Flutter CLI (`flutter create`)** - SELECTED
- Clean, minimal foundation with full architectural control
- Android-only targeting via `--platforms=android`
- No unwanted scaffolding to remove
- Always current with latest Flutter SDK
- Best for projects with well-defined architecture requirements

**2. Very Good CLI (`very_good create flutter_app`)**
- Uses BLoC state management (not Riverpod) - would require replacing
- Multi-platform scaffolding (iOS, web, Windows) would need stripping
- Internationalization setup not needed (Hebrew content via Sefaria, not Flutter i18n)
- Rejected: too opinionated in wrong directions

**3. Community Boilerplates (Riverpod + Firebase + Clean Architecture)**
- Not maintained as CLI tools; varying quality
- Opinionated patterns may conflict with specific architecture
- Rejected: maintenance and quality concerns

### Selected Starter: Official Flutter CLI

**Rationale for Selection (v2 - even stronger than v1):**

1. **Architecture is heavily custom:** The polymorphic curriculum engine, configurable stage system, and multi-device sync are unique to this project. No template provides this.
2. **Android-only v1.0:** `--platforms=android` creates exactly what we need without multi-platform scaffolding to remove.
3. **Full control over dependency versions:** We manage specific versions of drift, auto_route, riverpod, freezed - no conflicts with starter opinions.
4. **Maintenance guarantee:** Official Flutter tooling is always current with the latest SDK.

**Initialization Command:**

```bash
flutter create \
  --org com.jcom.torah \
  --platforms=android \
  --android-language kotlin \
  learning_tracker
```

**Command Explanation:**
- `--org com.jcom.torah`: Sets Android package to `com.jcom.torah.learning_tracker`
- `--platforms=android`: Android-only project (excludes iOS, web, desktop)
- `--android-language kotlin`: Kotlin for Android native code
- `learning_tracker`: Project name (snake_case convention)

**Changes from v1:**
- Org: `com.niasoff.mishnayos` → `com.jcom.torah` (broader domain, professional)
- Project name: `mishnayos_tracker` → `learning_tracker` (multi-curriculum scope)

### Architectural Decisions Provided by Starter

**Language & Runtime:**
- Dart SDK 3.9.0 (null-safe, latest stable)
- Flutter SDK 3.38.6 (stable channel)
- Kotlin for Android native platform code
- Minimum Android API 21 (Lollipop)

**Build Tooling:**
- Gradle (Android build system)
- Hot reload enabled for rapid development
- R8/ProGuard pre-configured for release optimization
- Asset bundling via `pubspec.yaml`

**Testing Framework:**
- `flutter_test` package included
- Widget testing framework provided
- Integration testing available via `integration_test` package (add separately)

**Code Quality:**
- Basic `analysis_options.yaml` with recommended rules (will be enhanced)
- `dart format` for auto-formatting
- `dart analyze` for static analysis

**Development Experience:**
- Hot reload/restart with sub-second state preservation
- Flutter DevTools (debugging, profiling, widget inspector)
- Platform channels ready for native Android integration

### Current Dependency Versions (verified Feb 2026)

| Package | v1 Version | Current (Feb 2026) | Change |
|---|---|---|---|
| Flutter SDK | 3.38.1+ | **3.38.6** | Patch |
| Dart SDK | ^3.7.0 | **3.9.0** | Minor |
| drift | ^2.30.0 | **^2.31.0** | Minor |
| drift_dev | ^2.30.0 | **^2.31.0** | Minor |
| drift_flutter | (not in v1) | **^2.31.0** | **NEW** |
| auto_route | ^9.3.0+1 | **^11.1.0** | **Major** |
| auto_route_generator | ^9.3.0 | **^10.4.0** | **Major** |
| flutter_riverpod | ^3.1.0 | **^3.2.1** | Minor |
| riverpod_generator | ^4.0.0 | **^4.0.3** | Patch |
| freezed | ^3.2.3 | **^3.2.5** | Patch |
| dio | ^5.9.0 | **^5.9.1** | Patch |
| talker | ~4.x-5.x | **^5.1.13** | Updated |
| mocktail | latest | **^1.0.4** | Stable |

### Version Migration Notes

**auto_route 9.x → 11.x (MAJOR - requires attention):**
- Major version jump may include breaking API changes
- Route guard APIs may have changed
- Core `@AutoRouterConfig` annotation pattern likely similar
- Must verify 11.x API patterns before implementation
- v1 Story 1.1 references 9.3.0 patterns - **obsolete, needs rewrite**

**drift_flutter (NEW dependency):**
- Added per party mode recommendation
- Replaces manual `sqlite3_flutter_libs` setup
- Handles native SQLite library loading automatically across platforms
- Simplifies drift platform initialization

### Post-Initialization Setup Required

1. Create clean architecture folders (feature-first with expanded feature set)
2. Add all dependencies to `pubspec.yaml` with current versions
3. Configure `build.yaml` for build_runner (drift, auto_route, freezed, riverpod_generator)
4. Set up `analysis_options.yaml` with strict Flutter linting
5. Create `.gitignore` with generated file patterns
6. Create config templates (`config/dev.json.example`, `config/prod.json.example`)
7. Set up Material Design 3 theme with RTL support for Hebrew
8. Configure Talker logging with dio/riverpod integrations

**Note:** v1 Story 1.1 is obsolete due to renamed project, updated versions (especially auto_route 11.x), new org name, and expanded feature module structure. A new Story 1.1 must be written for Learning Tracker before implementation begins.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- D1: Content modeling strategy (polymorphic curriculum support)
- D2: Authentication method (multi-device identity)
- D3: Stage storage architecture (configurable N-stage engine)
- D4: Sync architecture (multi-device data consistency)

**Important Decisions (Shape Architecture):**
- D5: User mode implementation (child vs adult feature gating)
- D6: Sefaria API integration pattern (multi-curriculum content fetching)
- D7: Learning order storage (user customization vs content immutability)
- D8: Gamification scoping (per-curriculum vs global reward system)

**Deferred Decisions (Post-MVP):**
- Curriculum marketplace / user-contributed curricula
- Advanced analytics / learning insights engine
- Social features (shared progress, group learning)
- Push notification optimization strategies

### D1: Content Modeling — Shared Table with Generic Hierarchy

**Decision:** Option C — Single `content_items` table with generic `level_1`/`level_2`/`level_3`/`level_4` columns + `curriculum_hierarchy_config` mapping table.

**Rationale:** Balances query simplicity (single table, single index strategy) with curriculum flexibility. A mapping table defines what each level means per curriculum (e.g., for Mishnayos: level_1=seder, level_2=masechta, level_3=perek, level_4=mishna; for Gemara Bavli: level_1=masechta, level_2=daf, level_3=amud, level_4=null).

**Schema Sketch:**
```sql
content_items (
  id INTEGER PRIMARY KEY,
  curriculum_id TEXT NOT NULL,  -- 'mishnayos', 'bavli', etc.
  level_1 TEXT NOT NULL,        -- generic hierarchy
  level_2 TEXT,
  level_3 TEXT,
  level_4 TEXT,
  display_name_he TEXT,
  display_name_en TEXT,
  sefaria_ref TEXT,             -- Sefaria API reference string
  sort_order INTEGER NOT NULL,
  UNIQUE(curriculum_id, level_1, level_2, level_3, level_4)
)

curriculum_hierarchy_config (
  curriculum_id TEXT PRIMARY KEY,
  level_1_label TEXT NOT NULL,  -- e.g., 'seder', 'masechta', 'siman'
  level_2_label TEXT NOT NULL,
  level_3_label TEXT,
  level_4_label TEXT,
  max_levels INTEGER NOT NULL   -- 3 or 4
)
```

**Affects:** Content browsing, progress tracking, Sefaria import, scheduler, dashboard aggregation.
**Provided by Starter:** No.

### D2: Authentication — Email/Password + Google Sign-In

**Decision:** Firebase Authentication with both email/password AND Google Sign-In providers.

**Rationale:** Email/password covers users without Google accounts (common in Orthodox communities). Google Sign-In provides frictionless onboarding for those who prefer it. Both methods produce the same Firebase UID, enabling seamless multi-device sync regardless of sign-in method. Firebase handles the complexity — the app just sees a single authenticated user.

**Implementation Notes:**
- firebase_auth + google_sign_in packages
- Sign-in screen offers both options
- Existing anonymous accounts (if any from testing) can be linked
- Firebase UID is the user identity key in Firestore

**Affects:** Onboarding flow, Firestore security rules, multi-device sync, user profile management.
**Provided by Starter:** No.

### D3: Stage Storage — Separate Relational Table

**Decision:** Option B — Separate `stage_definitions` table with per-curriculum configurable stages.

**Rationale:** Clean separation of stage configuration from content data. Stages are curriculum-specific metadata, not content attributes. A separate table allows users to add/remove/reorder stages per curriculum without touching content data. Default configurations seeded per curriculum type.

**Schema Sketch:**
```sql
stage_definitions (
  id INTEGER PRIMARY KEY,
  curriculum_id TEXT NOT NULL,
  stage_order INTEGER NOT NULL,   -- 1, 2, 3, ...
  stage_name TEXT NOT NULL,        -- 'learn', 'chazara 1', 'chazara 2'
  delay_days INTEGER NOT NULL,     -- 0 for learn, 1, 7, etc.
  is_default BOOLEAN DEFAULT true, -- system default vs user-customized
  UNIQUE(curriculum_id, stage_order)
)
```

**Default Stages (all curricula):**
1. Learn (0 days delay)
2. Chazara 1 (+1 day)
3. Chazara 2 (+7 days)

Users can customize per curriculum (add stages, change timing, rename).

**Affects:** Scheduler algorithm, completion tracking, progress calculation, stage configuration UI.
**Provided by Starter:** No.

### D4: Sync Architecture — Hybrid Push/Pull with Foreground Listeners

**Decision:** Option C — Push-on-write + pull-on-launch + foreground-only real-time Firestore listeners.

**Rationale:** Balances battery life with multi-device freshness. When the app is in the foreground, real-time listeners catch changes from other devices immediately. When backgrounded, listeners detach (saving battery). On next launch, a pull-sync catches anything missed. Push-on-write ensures local changes reach Firestore promptly.

**Sync Flow:**
1. **App launch:** Pull latest from Firestore, merge with local SQLite
2. **Foreground:** Real-time Firestore listeners active for cross-device changes
3. **Local write:** Write to SQLite first (source of truth), then push to Firestore
4. **Background:** Listeners detach, no battery drain
5. **Return to foreground:** Re-attach listeners, pull any missed changes
6. **Offline:** Queue writes locally, push when connectivity returns

**Conflict Resolution:**
- Completion logs: Additive merge (append-only, no conflicts possible)
- Bookmarks/settings: Last-write-wins with UTC timestamps
- Stage definitions: Last-write-wins with UTC timestamps

**Affects:** All data write paths, app lifecycle management, battery optimization, Firestore billing.
**Provided by Starter:** No.

### D5: User Mode — Profile Field with Feature Flags

**Decision:** Option A — Simple enum field on user profile (child/adult) that controls feature flag visibility.

**Rationale:** Simplest implementation that meets requirements. Mode is a profile attribute, not a type hierarchy. A `UserMode` enum (child, adult) stored in the user profile controls which features are visible/active. No separate user classes or complex type hierarchies needed.

**Feature Gating:**
- `child` mode: Full gamification, parent mode available, age-appropriate language
- `adult` mode: Minimal gamification (progress only, optional streaks), no parent mode, self-directed

**Implementation:** Simple `if (userMode == UserMode.child)` checks in presentation layer. No architectural complexity.

**Affects:** Onboarding flow, gamification system, parent mode availability, UI presentation.
**Provided by Starter:** No.

### D6: Bundled Content — Pre-Packaged at Build Time

**Decision:** All curriculum content (hierarchy and text in all available languages) is bundled with the app at build time. No runtime downloading or API fetching for content.

**Rationale:** Eliminates first-launch download delays, removes network dependency for content, and ensures offline-first works from the very first app open. Content is pre-processed from Sefaria during the build pipeline and shipped as bundled JSON assets. Content updates (corrections, new translations) ship with app updates.

**Build-Time Pipeline:**
- Sefaria content is fetched and processed during build/CI into bundled JSON assets per curriculum
- Each curriculum's hierarchy and text are stored as structured JSON in `assets/content/`
- On first launch, bundled JSON is loaded into SQLite for efficient querying

**Bundled Curricula:**
- Mishnayos — seder → masechta → perek → mishna
- Bavli — masechta → daf → amud
- Yerushalmi — masechta → daf → halacha
- Mishna Berurah — siman → seif → seif katan
- Chumash — sefer → parsha → perek → pasuk
- (And any additional curricula added to V1 scope)

**Affects:** First-launch experience (instant, no waiting), app bundle size, content update strategy, offline capability.
**Provided by Starter:** No.

### D7: Learning Order — Separate Table

**Decision:** Option B — Separate `learning_order` table for user-defined ordering, keeping content data immutable.

**Rationale:** Keeps Sefaria-sourced content data immutable (never modify imported content). User customizations (drag-and-drop reordering) stored in a separate table. Supports resetting to default order by simply deleting learning_order rows.

**Schema Sketch:**
```sql
learning_order (
  id INTEGER PRIMARY KEY,
  curriculum_id TEXT NOT NULL,
  content_item_id INTEGER NOT NULL,
  user_sort_order INTEGER NOT NULL,
  UNIQUE(curriculum_id, content_item_id),
  FOREIGN KEY (content_item_id) REFERENCES content_items(id)
)
```

**Behavior:**
- If no `learning_order` row exists for an item, use `content_items.sort_order` (Sefaria default)
- Drag-and-drop creates/updates `learning_order` rows
- "Reset to default" deletes all `learning_order` rows for that curriculum

**Affects:** Scheduler algorithm (must check learning_order before content_items.sort_order), browsing UI, drag-and-drop feature.
**Provided by Starter:** No.

### D8: Gamification — Per-Curriculum Points + Global Streak

**Decision:** Option B — Points accumulate per curriculum (curriculum-specific rewards), streak is global ("did you learn anything today").

**Rationale:** Points per curriculum allow curriculum-specific milestones and rewards (e.g., "completed 100 mishnayos" vs "completed 10 daf"). Streak is intentionally global — the question is "did you learn today?" not "did you learn this specific curriculum today?" This encourages daily learning habit regardless of which curriculum the user engages with.

**Implementation Notes:**
- `points` column on completion records, scoped by curriculum_id
- `daily_streak` tracked at user level (any curriculum completion counts)
- Child mode: Full gamification UI (animations, mystery rewards, streak celebrations)
- Adult mode: Optional streak display, no point animations, progress-focused

**Affects:** Completion tracking, dashboard display, reward system, notification content.
**Provided by Starter:** No.

### Decision Impact Analysis

**Implementation Sequence:**
1. D2 (Authentication) — Must exist before any data can sync
2. D1 (Content Modeling) — Foundation for all content-related features
3. D3 (Stage Storage) — Required before completion tracking
4. D4 (Sync Architecture) — Required before multi-device works
5. D5 (User Mode) — Can be added after core functionality
6. D6 (Sefaria Adapters) — Required for content population
7. D7 (Learning Order) — Enhancement on top of content browsing
8. D8 (Gamification) — Enhancement on top of completion tracking

**Cross-Component Dependencies:**
- D1 (Content) + D3 (Stages) + D7 (Order) form the core data model — all three tables are queried together by the scheduler
- D2 (Auth) + D4 (Sync) are tightly coupled — auth provides the UID that scopes all Firestore data
- D5 (User Mode) + D8 (Gamification) are presentation-layer decisions that read from the same completion data
- D6 (Sefaria Adapters) populates D1 (Content) — adapter output must match content_items schema exactly

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:** 6 areas where AI agents could make different choices, beyond the 120+ rules already in project-context.md. These patterns supplement (never contradict) project-context.md.

### P1: Curriculum ID Format — snake_case Strings with Explicit Enum Mapping

**Pattern:** Short snake_case strings used consistently across SQLite, Firestore, and Dart code.

**Canonical IDs:**
| Curriculum | Storage Key |
|---|---|
| Mishnayos | `mishnayos` |
| Gemara Bavli | `bavli` |
| Gemara Yerushalmi | `yerushalmi` |
| Mishna Berurah | `mishna_berurah` |
| Chumash | `chumash` |

**Dart Enum with Explicit Storage Mapping:**
```dart
enum CurriculumId {
  mishnayos('mishnayos'),
  bavli('bavli'),
  yerushalmi('yerushalmi'),
  mishnaBerurah('mishna_berurah'),
  chumash('chumash');

  const CurriculumId(this.storageKey);
  final String storageKey; // used in SQL, Firestore, routes
}
```

**Usage:**
- SQL columns: `curriculum_id TEXT` stores `.storageKey` values
- Firestore fields: `curriculumId: 'mishna_berurah'` (field name camelCase per project-context, value snake_case)
- Dart code: Always use `.storageKey` for persistence, never `.name`
- Route parameters: `/curriculum/:curriculumId` with value `mishna_berurah`

**Anti-Pattern:** Never use `.name` for storage (produces `mishnaBerurah` not `mishna_berurah`). Never use display names as IDs. Never use UPPER_SNAKE as stored values.

### P2: Repository "Not Found" Pattern — Nullable Returns

**Pattern:** Repository methods return `T?` when a single item may not exist. List queries always return `List<T>` (empty list for no results). Exceptions are reserved for infrastructure failures.

**Rules:**
- Single-item lookups: return `T?` (null = not found)
- List queries: return `List<T>` (empty list = none found, never null)
- Invalid curriculum ID on list query: return empty list, not exception
- Infrastructure failures (DB closed, network error): let exceptions bubble to AsyncValue.error

**Examples:**
```dart
// Single item: nullable
Future<ContentItem?> getContentItem(int id);
Future<StageDefinition?> getStageForCurriculum(String curriculumId, int order);

// List: always non-null, empty for no results
Future<List<ContentItem>> getAllForCurriculum(String curriculumId);
Stream<List<Completion>> watchCompletions(String curriculumId);
```

**Anti-Pattern:** Never throw domain exceptions for expected "not found" results. Never return null for list queries.

### P3: Provider Granularity — Family Providers for Curriculum Scoping

**Pattern:** Use Riverpod family providers for all curriculum-scoped data. The `curriculumId` parameter is the scoping key.

**Examples:**
```dart
@riverpod
Future<List<ContentItem>> contentItems(Ref ref, String curriculumId) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getAllForCurriculum(curriculumId);
}

@riverpod
Stream<List<Completion>> completions(Ref ref, String curriculumId) {
  final repo = ref.watch(completionRepositoryProvider);
  return repo.watchForCurriculum(curriculumId);
}
```

**Provider Lifecycle Rules:**
- Any provider that returns curriculum-specific data MUST take `curriculumId` as a family parameter
- Global providers (user profile, streak, cross-curriculum dashboard) do NOT take this parameter
- Active curriculum list maintained by a non-family `activeCurriculaProvider`
- When a curriculum is deactivated, explicitly `ref.invalidate()` all family providers for that `curriculumId`

**Anti-Pattern:** Never create a single provider that internally filters by a curriculum ID stored in some other state. Always pass it explicitly.

### P4: Firestore Collection Structure — Flat with Deterministic Document IDs

**Pattern:** Single flat collection per data type under user document, with `curriculumId` field for filtering and deterministic document IDs for idempotent sync.

**Structure:**
```
users/{uid}/
  profile                                    (single document)
  completions/{autoId}                       (append-only, auto-generated ID)
  bookmarks/{curriculumId}_{trackType}       (deterministic: 'mishnayos_personal')
  settings/{curriculumId}                    (deterministic: 'mishnayos')
  streak                                     (single document)
```

**Document ID Rules:**
- **Completions:** Auto-generated (append-only, never updated, additive merge)
- **Bookmarks:** `{curriculumId}_{trackType}` — deterministic so two devices update the same document
- **Settings:** `{curriculumId}` — one settings doc per curriculum (stage defs, learning order, goals)
- **Profile & Streak:** Single named documents

**Firestore Index Requirements:**
- `completions`: composite index on `(curriculumId, completedAt)`
- `bookmarks`: composite index on `(curriculumId, trackType)`

**Anti-Pattern:** Never use auto-generated IDs for mutable documents (causes duplicates on multi-device sync). Never nest curriculum data as subcollections.

### P5: Date/Time Storage — All UTC, Local Timezone for Streak Day Boundary

**Pattern:** Every timestamp and date stored as UTC in both SQLite and Firestore. Conversion to local time happens exclusively in the presentation layer. Streak day boundary uses the user's local calendar date.

**Rules:**
- SQLite `DateTime` columns: Always `DateTime.utc()` — never `DateTime.now()`
- Firestore: Use `Timestamp.now()` (already UTC) or `Timestamp.fromDate(dateTime.toUtc())`
- Goal dates: Stored as UTC midnight (`2026-03-15T00:00:00Z`), displayed as local date
- Hebrew dates: Computed from UTC date using kosher_dart at display time — never stored

**Streak Day Boundary:**
- Streak "day" = user's local calendar date derived from UTC completion timestamp
- `completionUtc.toLocal().date` determines which day the completion counts for
- A user in New York learning at 11pm EST gets credit for today (local), not tomorrow (UTC)
- Device timezone used for local conversion (no stored timezone needed — streak is per-device consistent, synced as last-write-wins)

**Anti-Pattern:** Never store local time. Never store Hebrew date strings. Never compute streak day boundaries using UTC dates directly.

### P6: Cross-Curriculum Operations — Core Layer Service

**Pattern:** Cross-curriculum aggregation lives in `lib/core/services/`, not in any feature module. Feature modules expose domain interfaces; the core aggregator composes them.

**Structure:**
```
lib/core/services/
  cross_curriculum_aggregator.dart  — dashboard stats, global streak
  daily_schedule_composer.dart      — merges per-curriculum schedules into daily plan
```

**Rules:**
- Feature modules NEVER import from other feature modules (per project-context.md)
- Core aggregators depend on domain-layer repository interfaces, not data-layer implementations
- Dashboard providers in `lib/features/dashboard/` use core aggregators via Riverpod
- Each feature module registers its repository provider in core; aggregator consumes them

**Anti-Pattern:** Never put cross-curriculum logic inside a single curriculum's feature module. Never have `features/mishnayos/` import from `features/bavli/`.

### Enforcement Guidelines

**All AI Agents MUST:**
1. Check project-context.md FIRST for existing rules before making any implementation choice
2. Use `CurriculumId.storageKey` for all persistence — never `.name`
3. Return `T?` for single-item not-found, `List<T>` (empty) for list queries
4. Use family providers with `curriculumId` parameter for any curriculum-scoped data
5. Invalidate family providers when curriculum deactivated
6. Use deterministic Firestore document IDs for mutable data (`{curriculumId}_{trackType}`)
7. Store ALL dates/times as UTC — convert in presentation only
8. Use local timezone for streak day boundary (`completionUtc.toLocal().date`)
9. Place cross-curriculum logic in `lib/core/services/`, never in feature modules

**Pattern Verification:**
- Code review checklist should verify P1-P6 compliance
- Any new curriculum added must follow the snake_case storage key pattern
- Any new provider returning curriculum data must be a family provider
- Any new Firestore document for mutable data must have a deterministic ID

## Project Structure & Boundaries

### Epic-to-Feature Module Mapping

| v1 Epic | v2 Feature Module | Key Change |
|---|---|---|
| Epic 1: Project Foundation | `core/` (database, config) | Polymorphic content tables, multi-curriculum |
| Epic 2: Core Learning | `learning/` | N-stage per curriculum, not hardcoded 3-stage |
| Epic 3: Multi-Track | `learning/` (merged) | Tracks per curriculum, not global |
| Epic 4: Smart Scheduler | `scheduler/` | Per-curriculum scheduler instances |
| Epic 5: Gamification | `gamification/` | Per-curriculum points + global streak |
| Epic 6: Parent Mode | `parent_mode/` | Available only for child accounts |
| Epic 7: Tutor Mode | `tutor_mode/` | Available for any user |
| Epic 8: Onboarding | `onboarding/` | Mode selection, curriculum selection, per-curriculum goals |
| Epic 9: Progress | `progress/` | Per-curriculum views |
| Epic 10: Notifications | `notifications/` | Per-curriculum reminders |
| Epic 11: Cloud Sync | `sync/` | Multi-device sync (not backup-only) |
| NEW: Auth | `auth/` | Email/password + Google Sign-In |
| NEW: Dashboard | `dashboard/` | Cross-curriculum aggregation |
| NEW: Content Browsing | `content_browsing/` | Multi-curriculum hierarchy browsing |
| NEW: Settings | `settings/` | Stage config, learning order, user prefs |

### Complete Project Directory Structure

```
learning_tracker/
├── .gitignore
├── .github/
│   └── hooks/
│       └── pre-commit                 # dart format + analyze
├── analysis_options.yaml
├── build.yaml                         # build_runner config (drift, auto_route, freezed, riverpod_generator)
├── config/
│   ├── dev.json.example
│   └── prod.json.example
├── pubspec.yaml
├── pubspec.lock
│
├── android/                           # Android platform (Kotlin)
│
├── lib/
│   ├── main.dart                      # App entry point
│   ├── app.dart                       # MaterialApp + AutoRouter setup
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   └── curriculum_defaults.dart  # Default stage definitions per curriculum
│   │   │
│   │   ├── database/
│   │   │   ├── app_database.dart      # @DriftDatabase definition
│   │   │   ├── tables/
│   │   │   │   ├── content_items.dart
│   │   │   │   ├── curriculum_hierarchy_config.dart
│   │   │   │   ├── stage_definitions.dart
│   │   │   │   ├── completions.dart
│   │   │   │   ├── bookmarks.dart
│   │   │   │   ├── learning_order.dart
│   │   │   │   └── user_profiles.dart
│   │   │   └── daos/
│   │   │       ├── content_dao.dart
│   │   │       ├── completion_dao.dart
│   │   │       ├── stage_dao.dart
│   │   │       ├── bookmark_dao.dart
│   │   │       ├── learning_order_dao.dart
│   │   │       └── user_profile_dao.dart
│   │   │
│   │   ├── enums/
│   │   │   ├── curriculum_id.dart     # CurriculumId enum with storageKey
│   │   │   ├── user_mode.dart         # UserMode (child, adult)
│   │   │   └── track_type.dart        # TrackType (personal, school, tutor)
│   │   │
│   │   ├── logging/
│   │   │   └── logger.dart            # Talker singleton + observers
│   │   │
│   │   ├── navigation/
│   │   │   ├── app_router.dart        # @AutoRouterConfig
│   │   │   └── guards/
│   │   │       ├── auth_guard.dart
│   │   │       ├── parent_pin_guard.dart
│   │   │       └── tutor_pin_guard.dart
│   │   │
│   │   ├── network/
│   │   │   ├── dio_client.dart        # Dio instance + interceptors
│   │   │   ├── connectivity_service.dart
│   │   │   └── sefaria/
│   │   │       ├── sefaria_api.dart           # Base Sefaria client
│   │   │       ├── curriculum_content_fetcher.dart  # Abstract interface
│   │   │       ├── mishna_fetcher.dart
│   │   │       ├── bavli_fetcher.dart
│   │   │       ├── yerushalmi_fetcher.dart
│   │   │       ├── mishna_berurah_fetcher.dart
│   │   │       └── chumash_fetcher.dart
│   │   │
│   │   ├── providers/
│   │   │   ├── database_provider.dart
│   │   │   ├── dio_provider.dart
│   │   │   ├── firebase_providers.dart  # Auth, Firestore instances
│   │   │   └── connectivity_provider.dart
│   │   │
│   │   ├── services/
│   │   │   ├── cross_curriculum_aggregator.dart  # Dashboard stats, global streak
│   │   │   └── daily_schedule_composer.dart      # Merges per-curriculum schedules
│   │   │
│   │   ├── theme/
│   │   │   ├── app_theme.dart         # Material 3 theme
│   │   │   └── text_styles.dart       # RTL-aware text styles
│   │   │
│   │   └── utils/
│   │       ├── date_utils.dart        # UTC helpers, local date conversion
│   │       └── hebrew_calendar_utils.dart  # kosher_dart wrappers
│   │
│   └── features/
│       ├── auth/
│       │   ├── data/
│       │   │   ├── repositories/
│       │   │   │   └── auth_repository_impl.dart
│       │   │   └── data_sources/
│       │   │       └── firebase_auth_data_source.dart
│       │   ├── domain/
│       │   │   ├── models/
│       │   │   │   └── user_profile.dart          # @freezed
│       │   │   └── repositories/
│       │   │       └── auth_repository.dart        # Abstract
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── auth_provider.dart
│       │       └── screens/
│       │           └── sign_in_screen.dart
│       │
│       ├── onboarding/
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       └── onboarding_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── models/
│       │   │   │   └── onboarding_state.dart      # @freezed
│       │   │   └── repositories/
│       │   │       └── onboarding_repository.dart
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── onboarding_provider.dart
│       │       └── screens/
│       │           ├── mode_selection_screen.dart     # child vs adult
│       │           ├── curriculum_selection_screen.dart
│       │           ├── goal_setup_screen.dart         # per-curriculum goals
│       │           └── bulk_mark_screen.dart           # prior completions
│       │
│       ├── content_browsing/
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       └── content_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── models/
│       │   │   │   ├── content_item.dart           # @freezed
│       │   │   │   └── hierarchy_level.dart        # @freezed
│       │   │   └── repositories/
│       │   │       └── content_repository.dart
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── content_browsing_provider.dart  # Family(curriculumId)
│       │       ├── screens/
│       │       │   ├── curriculum_list_screen.dart
│       │       │   └── content_hierarchy_screen.dart   # Generic for any level
│       │       └── widgets/
│       │           ├── content_list_tile.dart
│       │           └── hierarchy_breadcrumb.dart
│       │
│       ├── learning/
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       ├── completion_repository_impl.dart
│       │   │       └── bookmark_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── models/
│       │   │   │   ├── completion.dart             # @freezed
│       │   │   │   ├── bookmark.dart               # @freezed
│       │   │   │   └── stage_definition.dart       # @freezed
│       │   │   └── repositories/
│       │   │       ├── completion_repository.dart
│       │   │       └── bookmark_repository.dart
│       │   └── presentation/
│       │       ├── providers/
│       │       │   ├── completion_provider.dart     # Family(curriculumId)
│       │       │   └── track_provider.dart          # Family(curriculumId)
│       │       ├── screens/
│       │       │   └── learning_screen.dart         # Mark completion UI
│       │       └── widgets/
│       │           ├── stage_progress_indicator.dart
│       │           └── track_selector.dart
│       │
│       ├── scheduler/
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       └── schedule_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── models/
│       │   │   │   ├── daily_task.dart             # @freezed
│       │   │   │   └── schedule_config.dart        # @freezed
│       │   │   ├── repositories/
│       │   │   │   └── schedule_repository.dart
│       │   │   └── services/
│       │   │       └── scheduler_engine.dart       # Parametric N-stage algorithm
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── schedule_provider.dart       # Family(curriculumId)
│       │       ├── screens/
│       │       │   └── daily_tasks_screen.dart
│       │       └── widgets/
│       │           └── task_card.dart
│       │
│       ├── dashboard/
│       │   ├── domain/
│       │   │   └── models/
│       │   │       └── dashboard_stats.dart        # @freezed
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── dashboard_provider.dart      # Uses core aggregator
│       │       ├── screens/
│       │       │   └── dashboard_screen.dart
│       │       └── widgets/
│       │           ├── curriculum_summary_card.dart
│       │           └── streak_widget.dart
│       │
│       ├── progress/
│       │   ├── domain/
│       │   │   └── models/
│       │   │       └── progress_stats.dart         # @freezed
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── progress_provider.dart       # Family(curriculumId)
│       │       ├── screens/
│       │       │   └── progress_screen.dart
│       │       └── widgets/
│       │           ├── progress_chart.dart
│       │           └── level_breakdown.dart
│       │
│       ├── gamification/
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       ├── points_repository_impl.dart
│       │   │       └── streak_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── models/
│       │   │   │   ├── points_summary.dart         # @freezed
│       │   │   │   ├── streak_data.dart            # @freezed
│       │   │   │   └── reward.dart                 # @freezed
│       │   │   └── repositories/
│       │   │       ├── points_repository.dart
│       │   │       └── streak_repository.dart
│       │   └── presentation/
│       │       ├── providers/
│       │       │   ├── points_provider.dart         # Family(curriculumId)
│       │       │   └── streak_provider.dart         # Global (not family)
│       │       └── widgets/
│       │           ├── points_popup.dart
│       │           ├── streak_counter.dart
│       │           └── reward_progress_bar.dart
│       │
│       ├── parent_mode/
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       └── reward_repository_impl.dart
│       │   ├── domain/
│       │   │   └── repositories/
│       │   │       └── reward_repository.dart
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── parent_mode_provider.dart
│       │       └── screens/
│       │           ├── parent_dashboard_screen.dart
│       │           └── reward_management_screen.dart
│       │
│       ├── tutor_mode/
│       │   └── presentation/
│       │       ├── providers/
│       │       │   └── tutor_mode_provider.dart
│       │       └── screens/
│       │           └── tutor_dashboard_screen.dart
│       │
│       ├── notifications/
│       │   ├── data/
│       │   │   └── notification_service.dart
│       │   └── presentation/
│       │       └── providers/
│       │           └── notification_provider.dart
│       │
│       ├── settings/
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       ├── stage_config_repository_impl.dart
│       │   │       └── learning_order_repository_impl.dart
│       │   ├── domain/
│       │   │   └── repositories/
│       │   │       ├── stage_config_repository.dart
│       │   │       └── learning_order_repository.dart
│       │   └── presentation/
│       │       ├── providers/
│       │       │   ├── stage_config_provider.dart    # Family(curriculumId)
│       │       │   └── learning_order_provider.dart  # Family(curriculumId)
│       │       └── screens/
│       │           ├── settings_screen.dart
│       │           ├── stage_editor_screen.dart
│       │           └── learning_order_screen.dart     # Drag-and-drop
│       │
│       └── sync/
│           ├── data/
│           │   ├── sync_engine.dart              # Push/pull/listener orchestration
│           │   ├── firestore_data_source.dart     # Firestore read/write
│           │   └── offline_queue.dart             # Queued writes for offline
│           ├── domain/
│           │   └── models/
│           │       └── sync_status.dart           # @freezed
│           └── presentation/
│               └── providers/
│                   └── sync_provider.dart
│
├── test/
│   ├── mocks/
│   │   ├── mock_repositories.dart    # Shared mocktail mocks
│   │   └── mock_services.dart
│   ├── fixtures/
│   │   ├── content_fixtures.dart     # Reusable test data factories
│   │   ├── completion_fixtures.dart
│   │   └── curriculum_fixtures.dart
│   ├── core/
│   │   ├── database/
│   │   │   ├── daos/                  # DAO unit tests
│   │   │   └── tables/               # Schema validation tests
│   │   ├── network/
│   │   │   └── sefaria/              # Fetcher unit tests
│   │   └── services/
│   │       ├── cross_curriculum_aggregator_test.dart
│   │       └── daily_schedule_composer_test.dart
│   └── features/                      # Mirrors lib/features/ exactly
│       ├── auth/
│       ├── learning/
│       ├── scheduler/
│       └── ...
│
├── integration_test/
│   ├── onboarding_flow_test.dart
│   ├── learning_cycle_test.dart
│   └── sync_test.dart
│
└── assets/
    └── fonts/                         # Hebrew fonts if needed
```

### Architectural Boundaries

**Layer Dependencies (strict):**
```
Presentation → Domain (via repositories/models)
Data → Domain (implements repository interfaces)
Domain → Nothing (pure business logic, no Flutter imports)
```

**Feature Module Boundaries:**
- Features NEVER import from other features
- Cross-feature communication via core providers only
- Each feature's `domain/repositories/` defines the abstract interface
- Each feature's `data/repositories/` implements it

**Core vs Feature Boundary:**
- `lib/core/` = shared infrastructure (DB, network, navigation, theme, logging, cross-cutting services)
- `lib/features/` = business feature modules with clean architecture layers
- Core services CAN depend on feature domain interfaces (e.g., aggregator reads from completion repository interface)
- Features CAN depend on core, but NEVER on other features

### Integration Points

**External Integrations:**
| Service | Location | Pattern |
|---|---|---|
| Firebase Auth | `core/providers/firebase_providers.dart` | Provider-injected |
| Firestore | `features/sync/data/firestore_data_source.dart` | Single data source |
| Sefaria API | `core/network/sefaria/*_fetcher.dart` | Per-curriculum adapters |
| kosher_dart | `core/utils/hebrew_calendar_utils.dart` | Utility wrapper |
| Secure Storage | `core/providers/` | Provider-injected |

**Data Flow:**
```
Sefaria API → CurriculumContentFetcher → content_items table (SQLite)
User Action → Presentation → Domain → Data → SQLite → Sync Engine → Firestore
Other Device → Firestore → Sync Engine → SQLite → Riverpod invalidation → UI
```

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:** All 8 architectural decisions (D1-D8) are mutually consistent. Technology versions verified (Flutter 3.38.6, Dart 3.9, drift 2.31, auto_route 11.1, riverpod 3.2.1). No conflicting dependency requirements.

**Pattern Consistency:** P1-P6 implementation patterns support all architectural decisions. CurriculumId storage keys (P1) used consistently across D1 schema, P4 Firestore structure, and P3 family providers.

**Structure Alignment:** 15 feature modules map cleanly to all epics and new requirements. Layer boundaries (presentation -> domain -> data) respected throughout.

### Requirements Coverage

**Epic Coverage:** All 11 v1 epics + 4 new feature areas have designated modules.

**FR Coverage:** 84 FRs covered. Clarifications:
- FR70/FR71 (export/import): Lives in `settings/presentation/screens/export_import_screen.dart`
- FR57 (learning order in onboarding): Onboarding navigates to settings learning order screen

**NFR Coverage:** All 47 NFRs architecturally supported through technology choices and patterns.

### Implementation Readiness

**Scheduler Cross-Feature Access Pattern:** The `scheduler_engine.dart` needs data from content, completion, stage, and learning_order repositories. It consumes these through core-registered abstract repository providers — never importing from feature modules directly.

### Architecture Completeness Checklist

- [x] Project context thoroughly analyzed (Step 2)
- [x] Scale and complexity assessed (Medium-High)
- [x] Technical constraints identified (Flutter, Android, offline-first)
- [x] Cross-cutting concerns mapped (10 concerns)
- [x] Critical decisions documented with versions (D1-D8)
- [x] Technology stack fully specified (Feb 2026 versions)
- [x] Integration patterns defined (Sefaria adapters, Firebase sync)
- [x] Performance considerations addressed (sub-100ms queries, foreground listeners)
- [x] Naming conventions established (P1 + project-context.md)
- [x] Structure patterns defined (clean architecture, feature-first)
- [x] Communication patterns specified (family providers, core aggregators)
- [x] Process patterns documented (nullable returns, UTC dates, deterministic IDs)
- [x] Complete directory structure defined (15 feature modules)
- [x] Component boundaries established (features never import features)
- [x] Integration points mapped (Firebase, Sefaria, kosher_dart)
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Key Strengths:**
- Clean separation of curriculum-specific vs cross-curriculum concerns
- Polymorphic content model scales to new curricula without schema changes
- Configurable stage engine avoids hardcoded business rules
- Hybrid sync balances battery life with multi-device freshness
- 120+ existing project-context rules + 6 new patterns = comprehensive agent guidance

**Areas for Future Enhancement:**
- Database migration versioning strategy (defer until first migration needed)
- Push notification optimization (deferred post-MVP)
- Advanced analytics/insights engine (deferred post-MVP)

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns (P1-P6) consistently across all components
- Respect project structure and feature module boundaries
- Refer to this document + project-context.md for all architectural questions

**First Implementation Priority:**
```bash
flutter create \
  --org com.jcom.torah \
  --platforms=android \
  --android-language kotlin \
  learning_tracker
```

**Note:** v1 Story 1.1 is obsolete. A new Story 1.1 must be written for Learning Tracker covering project initialization with v2 architecture, updated dependencies (especially auto_route 11.x, drift_flutter), new org name (`com.jcom.torah`), and expanded 15-feature module structure.

---

## Offline-First Architecture Evolution (2026-03-27)

### Context

This section evolves the V1 architecture to support users who never connect to the internet after initial APK installation. Local-first is the default mode. Cloud sync is a transparent, optional layer that activates only when the user has a Firebase account.

### Driving Requirements

| ID | Requirement |
|---|---|
| NFR22-v2 | All features work without network, including first launch |
| NFR23-v2 | Identical UX online/offline for ALL features |
| FR-NEW-1 | System creates local profile on first launch without authentication |
| FR-NEW-2 | System hydrates text cache from bundled assets in background |
| FR-NEW-3 | System computes daily calendar program assignments locally |
| FR-NEW-4 | User can optionally create account to enable cloud sync |
| FR-NEW-5 | System transparently activates sync when Firebase account exists |

### Decision Evolutions

#### D2-v2: Local-First Auth with Cached Firebase (SUPERSEDED by D2-v3)

> ⚠️ **SUPERSEDED (2026-04-10).** This decision has been replaced by D2-v3 below. D2-v2 is preserved here for historical context only — do not use it as a source for new implementation work. Production code currently still reflects D2-v2 (sealed `AppAuthState`, `LocalAuthGuard`, anonymous `localUid`). The refactor to D2-v3 is tracked as a separate Linear epic; see `offline-first-architecture-v2-2026-04-10.md` §6 "What This Supersedes" for the full list of concepts to be removed.

**Supersedes:** D2 (Firebase Auth mandatory)

**Decision (historical):** Auth abstraction layer with local-first default and optional Firebase.

**Architecture (historical):**
- `AuthStateService` interface with two implementations:
  - `LocalAuthState`: generates stable UUID, persists in SharedPreferences, always returns "authenticated"
  - `FirebaseAuthState`: existing Firebase behavior, caches auth state locally
- `AuthGuard` checks `AuthStateService`, never `FirebaseAuth` directly
- First launch online → Firebase Auth, cache locally
- First launch offline → Local UUID, full app access immediately
- No migration path: account creation is greenfield (sync starts fresh)

#### D2-v3: Hard-Tier Auth Model (Cloud-Born vs Local-Born)

**Supersedes:** D2-v2
**Canonical doc:** `_bmad-output/planning-artifacts/offline-first-architecture-v2-2026-04-10.md`

**Decision:** Every user has a real account with email + password. Tier is set at signup by network state and is immutable.

- **Cloud-born (90%):** Signed up with internet. Firebase Auth + Firestore sync. Session persists locally indefinitely so offline use works for weeks without re-auth.
- **Local-born (10%):** Signed up without internet. argon2id password hash stored in SQLite. No backup, no recovery, no multi-device. Clear "no backup" warning at signup and persistent badge in profile area.
- **Tier is immutable.** Upgrade (local → cloud) is one-way and explicit, via a guided UX flow with email-collision merge handling (see v2 doc §4.3).
- **Rationale for superseding v2:** The v2 abstraction layer (sealed auth state, `LocalAuthGuard`, UID migration) created ~800 lines of parallel auth infrastructure to hide a distinction that users didn't benefit from. v3 collapses to one auth concept with two storage backends — simpler code, clearer mental model, matches Yafet's and other stakeholders' expectations of a sign-in screen.

**Sync Activation Rule:**
- Cloud-born user: SyncEngine active. Queues offline writes, flushes on reconnect. Identical to existing D4 behavior.
- Local-born user: SyncEngine dormant. No queuing, no push, no pull. Tier gate, not connectivity gate.

**Conflict Resolution (new in v3):** Per-data-type strategy. LWW for profile settings. Merge-forward (union / max) for progress markers. Append-only event log for streaks and XP, reduced to state on each device. See v2 doc §4.1 for full rules.

**Affects:** Auth feature module, route guards, sync engine, startup sequence, onboarding flow, UserProfiles schema (drop `localUid`, add `passwordHash` for local-born).

#### D4-v2: Conditional Sync

**Supersedes:** D4 (Hybrid push/pull always active)

**Decision:** Sync layer activates conditionally based on account type, not connectivity.

**Rules:**
- `SyncEngine.isActive` = `AuthStateService.isFirebaseUser`
- Firebase users: full D4 behavior (push-on-write, pull-on-launch, foreground listeners, offline queue)
- Local users: SyncEngine is a no-op — all method calls return immediately
- Account creation: sync starts fresh from that moment forward
- `SyncLifecycleObserver`: checks `isActive` before attaching/detaching listeners

**Affects:** SyncEngine, SyncLifecycleObserver, OfflineQueue, FirestoreDataSource.

#### D6-v2: Fully Bundled Content with Background Hydration

**Supersedes:** D6 (Bundled hierarchy only, text downloaded at runtime)

**Decision:** Bundle ALL content — hierarchy JSON and text JSON — in the APK. Text hydrates into SQLite in background.

**Bundle Contents:**

| Asset | Format | Est. Size |
|---|---|---|
| Hierarchy (7 curricula) | JSON | ~4 MB |
| Text — Bavli (5,471 items) | gzipped JSON | ~15-20 MB |
| Text — Mishnayos (4,192) | gzipped JSON | ~3-5 MB |
| Text — Yerushalmi (2,211) | gzipped JSON | ~8-10 MB |
| Text — Chumash (5,846) | gzipped JSON | ~2-3 MB |
| Text — Mishna Berurah (17,397) | gzipped JSON | ~10-15 MB |
| Text — Nach (17,360) | gzipped JSON | ~5-8 MB |
| Text — Mussar (51) | gzipped JSON | <1 MB |
| Calendar cycles (12 programs) | JSON | <1 MB |
| **Total APK increase** | | **~45-60 MB** |

**Hydration Strategy:**
- First launch: app immediately usable (hierarchy in memory)
- Background isolate decompresses text into TextCache SQLite table
- Batch inserts: 500 items/batch with checkpoint after each (resumable)
- If user reads text before hydration reaches it: load from bundled asset directly as fallback
- `TextDownloadStatuses` marks each curriculum hydrated on completion
- Subsequent launches: skip (already done)
- Fully transparent — no UI indication needed

**Affects:** APK size, pubspec.yaml assets, TextDownloadService, TextCacheRepository (fallback path), build pipeline.

### New Decisions

#### D9: Local Calendar Engine — Precomputed Lookup Tables

**Decision:** All 12 calendar programs computed locally from bundled cycle data. No API dependency.

**Architecture:**
- Bundle JSON per program: `assets/content/calendars/{program}_cycle.json`
- Format: `{ "epoch": "YYYY-MM-DD", "refs": ["ref1", "ref2", ...] }`
- `LocalCalendarEngine` service: `dayIndex = daysSince(epoch) % refs.length` → direct array lookup
- `CalendarProgramService` uses `LocalCalendarEngine` as primary source
- Online validation: when connected, optionally check API and log discrepancies (never override local result)

**Programs:**
1. Daf Yomi
2. Mishna Yomit
3. Nach Yomi
4. Yerushalmi Yomi
5. Daf a Week
6. Rambam 1 Chapter
7. Rambam 3 Chapters
8. Halakhah Yomit
9. Tanakh Yomi
10. Arukh HaShulchan Yomi
11. Chofetz Chaim Daily
12. Kitzur Shulchan Aruch Yomi

**Cycle Transitions:**
- Each cycle JSON includes `nextCycleStart` metadata
- App warns user to update if approaching end of bundled cycle data

**Build Tool:** `tool/seed_calendar_cycles.dart`
- Queries Sefaria/Hebcal APIs day-by-day across full cycle
- Rate limited: 1-2 requests/second
- Output: JSON cycle files
- One-time build step, re-run only at cycle boundaries

**Affects:** CalendarProgramService, calendar providers, build pipeline, pubspec.yaml assets.

#### D10: Lazy Firebase Initialization

**Decision:** Firebase SDK initializes only when user explicitly creates an account or signs in. Zero Firebase code runs for local-only users.

**Startup Sequence:**
```
main() →
  WidgetsFlutterBinding.ensureInitialized()
  NotificationInitializer.initialize()        [local, safe]
  Check SharedPreferences for profile state
    → Local profile exists      → runApp() immediately
    → Firebase profile cached   → Firebase.initializeApp() then runApp()
    → No profile                → runApp() → onboarding (no Firebase)
  Background: start text hydration if not complete
```

**Firebase Guard Rule:**
- All Firebase call sites check `AuthStateService.isFirebaseUser`
- `GoogleSignIn.initialize()` deferred to sign-in screen
- `ConnectivityService`: platform check first (instant), DNS only if platform reports connected, 2-second timeout (down from 5)

**Affects:** main.dart, all Firebase providers, ConnectivityService, GoogleSignIn initialization.

### New Patterns

#### P7: Auth Abstraction — AuthStateService Interface

**Pattern:** All auth checks go through `AuthStateService`, never `FirebaseAuth` directly. This applies to guards, providers, and services.

**Interface:**
```dart
abstract class AuthStateService {
  bool get isAuthenticated;    // true for both local and Firebase users
  bool get isFirebaseUser;     // true only for Firebase-backed users
  String get uid;              // local UUID or Firebase UID
  Future<void> signOut();
  Stream<bool> authStateChanges();
}
```

**Rules:**
- `AuthGuard` calls `authStateService.isAuthenticated`
- `SyncEngine` checks `authStateService.isFirebaseUser`
- No code outside `auth/data/` should import `firebase_auth` directly
- Providers expose `AuthStateService`, not `FirebaseAuth`

**Anti-Pattern:** Never check `FirebaseAuth.instance.currentUser` outside the auth data layer. Never assume a user has a Firebase account.

#### P8: Sync Activation Gate

**Pattern:** SyncEngine exposes an `isActive` property driven by account type. All sync operations early-return when inactive.

**Rules:**
```dart
class SyncEngine {
  bool get isActive => _authStateService.isFirebaseUser;

  Future<void> pushCompletion(Completion c) async {
    if (!isActive) return;  // no-op for local users
    // existing push logic...
  }
}
```

- Every public SyncEngine method checks `isActive` first
- OfflineQueue disabled when `!isActive` (no writes to sync_queue)
- SyncLifecycleObserver skips listener attach/detach when `!isActive`
- When user creates Firebase account: `isActive` flips to true, SyncEngine begins fresh sync from that moment

**Anti-Pattern:** Never queue sync operations for local-only users. Never check connectivity as a proxy for sync activation.

### Updated Structural Changes

**New files:**
- `lib/core/services/local_calendar_engine.dart`
- `lib/features/auth/domain/services/auth_state_service.dart`
- `lib/features/auth/data/services/local_auth_state.dart`
- `lib/features/auth/data/services/firebase_auth_state.dart`
- `assets/content/text/*.json.gz` (7 files)
- `assets/content/calendars/*.json` (12 files)
- `tool/seed_calendar_cycles.dart`

**Modified files:**
- `main.dart` — new startup sequence
- `lib/core/navigation/guards/auth_guard.dart` — use AuthStateService
- `lib/features/sync/data/sync_engine.dart` — activation gate
- `lib/features/sync/data/offline_queue.dart` — conditional activation
- `lib/core/network/connectivity_service.dart` — faster timeout
- `lib/core/providers/firebase_providers.dart` — lazy init
- `lib/features/content_browsing/data/services/text_download_service.dart` — hydration-from-assets path
- `lib/core/services/calendar_program_service.dart` — local engine primary
- `pubspec.yaml` — new assets

### Implementation Sequence

1. **Auth abstraction** (D2-v2, D10, P7) — unblocks everything
2. **Bundled text + hydration** (D6-v2) — parallel with #3
3. **Local calendar engine** (D9) — parallel with #2
4. **Sync conditionalization** (D4-v2, P8) — after #1
5. **Integration testing** — airplane mode: install → onboard → full use

### Success Criteria

- [ ] Fresh install on airplane-mode device → complete onboarding → full app use
- [ ] All 7 curricula: browse hierarchy + read Hebrew/English text — no network
- [ ] All 12 calendar programs show correct "today's learning" — no network
- [ ] User creates account weeks later → sync begins fresh from that point
- [ ] Second device signs in → pulls data from Firestore
- [ ] Network drops mid-session → zero UX disruption
- [ ] App never shows loading spinners waiting for network in core flows
- [ ] Firebase-backed users: existing sync behavior unchanged
- [ ] Local-only users: zero Firebase SDK activity
