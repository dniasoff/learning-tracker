# Learning Tracker — Architecture Quick Reference

**Last Updated:** 2026-04-19
**Full Details:** [architecture.md](../architecture.md) | [Architecture Design (intent)](architecture-design.md) | [Offline-First v2 (auth)](architecture-offline-v2.md) | [Two-Database Architecture](two-database-architecture.md) | [PRD (historical)](prd.md)

> ⚠️ **Historical context:** Sections dated earlier than 2026-04-15 describe earlier phases of the project. Where they conflict with current code, trust the current-state docs linked above.

---

## Project Overview

**Learning Tracker** is a multi-curriculum Torah learning app (Flutter/Dart, Android) supporting:

- **9 Curricula:** Mishnayos, Gemara Bavli, Gemara Yerushalmi, Mishna Berurah, Mishneh Torah, Chumash, Nach, Tanach, Mussar (content bundled as `assets/db/content.db.gz`, not fetched at runtime)
- **User Modes:** Child (gamified, parent-managed) and Adult (self-directed, no gamification)
- **Track types:** `personal` (default), `school`, `tutor` (latter two activated by parents via parent-mode)
- **User tiers (Epic 23):** `cloudBorn` (email+password+Firebase sync), `localBorn` (email+argon2id, local-only, no sync)
- **Core Features:** Multi-stage learning (configurable stages per track), per-track scheduling, three-database offline-first architecture, multi-account device support (up to 5 accounts)

**Tech Stack:** Flutter 3.38.6+ / Dart 3.10.8+, Drift (three databases), auto_route 11.x, Riverpod 3.x, freezed, dio (dev-time only), Talker, Firebase Auth + Firestore (tier-gated), kosher_dart, flutter_secure_storage, bcrypt, argon2

**Package:** `com.jcom.torah.learning_tracker`

---

## Architecture Decisions (D1-D8)

### D1: Content Modeling — Generic Hierarchy Table
**Problem:** 5 curricula with different structures (Mishnayos = Seder→Masechta→Perek→Mishna, Chumash = Torah→Sefer→Parsha→Pasuk)
**Solution:** Single `content_items` table with 4 flexible hierarchy levels (level_1-4), curriculum_id discriminator
**Schema:**
```sql
content_items (
  id, curriculum_id, level_1, level_2, level_3, level_4,
  display_name_he, display_name_en, sefaria_ref, sort_order, is_leaf,
  UNIQUE(curriculum_id, level_1, level_2, level_3, level_4)
)
curriculum_hierarchy_config (
  curriculum_id PK, level_1_label, level_2_label, level_3_label, level_4_label, max_levels
)
```

### D2: Authentication — Firebase Auth (Email/Password + Google Sign-In)
**Why:** Multi-device sync requires account-based auth (not anonymous)
**Providers:** Email/password (primary), Google Sign-In (convenience)
**Security:** Parent PIN (bcrypt, device-local) for child mode; tutor PIN separate

### D3: Stage Storage — Separate Relational Table
**Problem:** Users customize stages per curriculum (e.g., Learn + 3 chazara vs. Learn + 5 chazara)
**Solution:** `stage_definitions` table with curriculum_id, stage_order, stage_name, delay_days
**Default:** Learn (0 days), Chazara 1 (+1 day), Chazara 2 (+7 days)

### D4: Sync Architecture — Hybrid Push/Pull + Foreground Listeners
**Write:** Push-on-write to Firestore (async, offline queue if disconnected)
**Read:** Pull-on-launch + foreground real-time listeners (detach on background for battery)
**Conflict Resolution:** Completions = additive merge (append-only), Settings/Bookmarks = last-write-wins (UTC timestamps)

### D5: User Mode — Profile Enum with Feature Flags
**Modes:** `UserMode.child` (gamification, parent PIN required) | `UserMode.adult` (self-directed, optional gamification)
**Storage:** `user_profiles.user_mode` field, synced to Firestore
**Feature Gating:** Simple `if (userMode == UserMode.child)` checks in presentation layer

### D6: Sefaria API Integration — Per-Curriculum Adapter Pattern
**Base:** `SefariaClient` (dio-based HTTP client)
**Adapters:** `MishnayosAdapter`, `BavliAdapter`, `YerushalmiAdapter`, `MishnaBerurahAdapter`, `ChumashAdapter`
**Each adapter:** Knows Sefaria index structure, maps to 4-level hierarchy, handles pagination

### D7: Learning Order — Separate Table, Content Immutable
**Problem:** Users want to reorder masechtos (e.g., learn Berachos → Shabbos → Eruvin vs. natural order)
**Solution:** `learning_order` table with `user_sort_order` per content_item; content table never modified
**Fallback:** If no `learning_order` entry exists, use `content_items.sort_order` (natural order)

### D8: Gamification Scoping — Per-Curriculum Points + Global Streak
**Points:** Accumulated per curriculum (not global) — `SUM(points) WHERE curriculum_id=?`
**Streak:** Global across all curricula — "did you learn anything today?" (any completion counts)
**Why:** Per-curriculum points enable curriculum-specific rewards; global streak encourages breadth

---

## Implementation Patterns (P1-P6)

### P1: CurriculumId Format — Snake_Case Storage Keys
**Enum:**
```dart
enum CurriculumId {
  mishnayos('mishnayos', 'Mishnayos'),
  bavli('bavli', 'Gemara Bavli'),
  yerushalmi('yerushalmi', 'Talmud Yerushalmi'),
  mishna_berurah('mishna_berurah', 'Mishna Berurah'),
  chumash('chumash', 'Chumash');

  final String storageKey; // Used in DB/Firestore
  final String displayName;
}
```
**Rule:** Always use `curriculumId.storageKey` for DB/Firestore columns

### P2: Nullable Returns — Repository Pattern
**Single-item queries:** Return `T?` (e.g., `Future<ContentItem?> getContentItemById(String id)`)
**List queries:** Return `List<T>` (empty list if no results, never null)
**Why:** Dart null-safety best practice; forces callers to handle missing data

### P3: Family Providers — Curriculum-Scoped Riverpod
**Pattern:**
```dart
final contentRepositoryProvider = Provider.family<ContentRepository, CurriculumId>((ref, curriculumId) {
  return ContentRepositoryImpl(curriculumId: curriculumId);
});
```
**Usage:** `ref.watch(contentRepositoryProvider(CurriculumId.mishnayos))`
**Why:** Per-curriculum state isolation; prevents cross-curriculum data leaks

### P4: Firestore Structure — Flat Collections with Deterministic IDs
**Collections:**
- `users/{uid}/profile` (single doc per user)
- `completions/{autoId}` (append-only, auto-generated IDs)
- `bookmarks/{curriculumId}_{trackType}` (deterministic ID for last-write-wins)
- `settings/{curriculumId}` (stage definitions, learning order, goals)
- `streak` (single doc per user: current_count, max_count, last_active_date)

**Security:** Firestore rules enforce user can only read/write their own `users/{uid}/*` subcollections

### P5: UTC Dates — Store UTC, Display Local
**Storage:** All timestamps in DB/Firestore as UTC (`DateTime.now().toUtc()`)
**Display:** Convert to local timezone in UI (`completionUtc.toLocal()`)
**Day Boundaries:** For streak calculation, use local date: `completionUtc.toLocal().date`
**Why:** Timezone-agnostic storage; prevents DST bugs; supports multi-timezone users

### P6: Cross-Curriculum Core Services — Shared Logic in lib/core/services/
**Services:**
- `DailyScheduleComposer` — Merges per-curriculum daily tasks into single prioritized list
- `CrossCurriculumAggregator` — Dashboard stats across all active curricula

**Rule:** Core services live in `lib/core/services/`, depend on abstract repository interfaces (not direct feature imports)
**Why:** Prevents circular dependencies; enables testing with mocks

---

## Project Structure

```
lib/
├── core/
│   ├── database/          # Drift database, DAOs
│   ├── providers/         # Firebase, database, core providers
│   ├── services/          # DailyScheduleComposer, CrossCurriculumAggregator (P6)
│   ├── theme/            # Material 3 theme, design tokens
│   ├── routing/          # auto_route 11.x navigation
│   └── utils/            # Logging (Talker), error handling, Hebrew dates (kosher_dart)
├── features/
│   ├── auth/             # Sign-in, sign-up, account management (D2)
│   ├── content/          # Content import (D6), browsing, search
│   ├── learning/         # Mark completion, history, bookmarks (D1, D3)
│   ├── tracks/           # Multi-track management (personal/school/tutor)
│   ├── stages/           # Stage configuration (D3)
│   ├── learning_order/   # Drag-and-drop reordering (D7)
│   ├── scheduler/        # Smart scheduler, daily tasks, goals
│   ├── dashboard/        # Home screen, cross-curriculum overview (P6)
│   ├── progress/         # Charts, statistics, per-curriculum views
│   ├── gamification/     # Points, streaks, rewards (D8)
│   ├── onboarding/       # Welcome, mode selection, initial setup (D5)
│   ├── parent_mode/      # Parent dashboard, reward mgmt, PIN auth (D2, D5)
│   ├── tutor_mode/       # Tutor dashboard, read-only views (D5)
│   ├── notifications/    # Daily reminders, streak alerts, reward notifications
│   ├── sync/             # Cloud sync (D4), push/pull/listeners
│   └── settings/         # App preferences, notification config, data export
└── main.dart
```

**Each feature module:**
```
features/<feature>/
├── domain/
│   ├── models/         # @freezed data classes
│   ├── repositories/   # Abstract interfaces
│   └── services/       # Feature-specific business logic
├── data/
│   ├── repositories/   # Concrete implementations (drift, Firestore)
│   └── datasources/    # DAOs, API clients (D6)
└── presentation/
    ├── providers/      # Riverpod providers (P3 family pattern)
    ├── screens/        # Routable screens (auto_route)
    └── widgets/        # Reusable UI components
```

---

## Key Data Models

### CurriculumId (P1)
```dart
enum CurriculumId {
  mishnayos, bavli, yerushalmi, mishna_berurah, chumash
}
```

### UserMode (D5)
```dart
enum UserMode { child, adult }
```

### TrackType
```dart
enum TrackType { personal, school, tutor }
```

### ContentItem (D1)
```dart
@freezed
class ContentItem {
  String id;
  CurriculumId curriculumId;
  String? level1, level2, level3, level4; // Nullable for hierarchy flexibility
  String displayNameHe, displayNameEn;
  String sefariaRef;
  int sortOrder;
  bool isLeaf; // True for trackable items (mishna, daf), false for containers (seder, masechta)
}
```

### Completion (D3)
```dart
@freezed
class Completion {
  String id;
  CurriculumId curriculumId;
  String sefariaRef;          // ⚠️ Changed from contentItemId in Epic 3 — use sefariaRef everywhere
  String stageDefinitionId;   // FK to stage_definitions
  TrackType trackType;
  DateTime completedAt;       // UTC per P5
  int points;
}
```

### StageDefinition (D3)
```dart
@freezed
class StageDefinition {
  String id;
  CurriculumId curriculumId;
  int stageOrder; // 1, 2, 3... (Learn=1, Chazara1=2, etc.)
  String stageName;
  int delayDays; // 0 for Learn, 1 for Chazara1, 7 for Chazara2, etc.
  bool isDefault; // True for system defaults, false for user customizations
}
```

### LearningOrder (D7)
```dart
@freezed
class LearningOrder {
  String id;
  CurriculumId curriculumId;
  String contentItemId;
  int userSortOrder; // Overrides content_items.sort_order
}
```

---

## Common Queries

### Get Next Unlearned Item (for Bookmark)
```dart
// For a given curriculum + track + stage, find the first incomplete item in learning order
final nextItem = await db.select(db.contentItems)
  .join([
    leftOuterJoin(db.learningOrder, db.learningOrder.contentItemId.equalsExp(db.contentItems.id)),
    leftOuterJoin(db.completions, db.completions.contentItemId.equalsExp(db.contentItems.id)
      & db.completions.stageDefinitionId.equals(stageId)
      & db.completions.trackType.equals(trackType))
  ])
  .where(db.contentItems.curriculumId.equals(curriculumId.storageKey)
    & db.contentItems.isLeaf.equals(true)
    & db.completions.id.isNull()) // Not completed
  .orderBy([
    OrderingTerm(expression: coalesce([db.learningOrder.userSortOrder, db.contentItems.sortOrder]))
  ])
  .getSingleOrNull(); // P2: nullable return
```

### Calculate Pace (Scheduler)
```dart
// Pace = (items completed / items expected by today)
final totalItems = await (db.select(db.contentItems)
  ..where((t) => t.curriculumId.equals(curriculumId.storageKey) & t.isLeaf.equals(true))
).get().then((items) => items.length);

final daysElapsed = DateTime.now().difference(goalStartDate).inDays;
final itemsExpected = (totalItems * daysElapsed / goalTotalDays).round();

final itemsCompleted = await (db.select(db.completions)
  ..where((t) => t.curriculumId.equals(curriculumId.storageKey)
    & t.stageDefinitionId.equals(learnStageId))
).get().then((completions) => completions.length);

final pace = itemsCompleted / itemsExpected; // >1.0 = ahead, <1.0 = behind
```

### Check Streak Status (D8, P5)
```dart
// Global streak: any curriculum completion counts
final today = DateTime.now().toLocal().date; // P5: local date
final yesterday = today.subtract(Duration(days: 1));

final hasCompletionToday = await (db.select(db.completions)
  ..where((t) => t.completedAt.date.equals(today)) // Custom date extraction
).get().then((list) => list.isNotEmpty);

final hasCompletionYesterday = await (db.select(db.completions)
  ..where((t) => t.completedAt.date.equals(yesterday))
).get().then((list) => list.isNotEmpty);

// If hasCompletionToday: streak continues
// If !hasCompletionToday && hasCompletionYesterday: streak at risk
// If !hasCompletionToday && !hasCompletionYesterday: streak broken
```

---

## Epic 1 Critical Deliverables

**Epic 1 = ALL plumbing.** All subsequent epics are pure feature coding with zero setup friction.

**Must deliver:**
1. Drift database with all tables (D1, D3, D7) + DAOs following P2
2. Firebase Auth + Firestore integration (D2) with security rules (P4)
3. Sefaria API client + base adapter pattern (D6) — at least MishnayosAdapter implemented
4. auto_route 11.x navigation with ParentPinGuard, TutorPinGuard, AuthGuard
5. Riverpod provider architecture (P3 family pattern established)
6. Sync engine foundation (D4): push-on-write, pull-on-launch stubs (Epic 13 completes)
7. Talker logging, error handling, crash reporting wired
8. CI/CD pipeline: GitHub Actions with build + test
9. flutter_secure_storage for PIN (bcrypt hashing)
10. kosher_dart integrated for Hebrew date utilities
11. Theme system (Material 3, light mode only for v1)
12. All dependencies at Feb 2026 versions in `pubspec.yaml`

**Post-Epic-1 State:** `flutter run` shows a functional app shell with Firebase sign-in, theme applied, navigation working, and database migrations run. No features implemented yet, but zero infra work remains.

---

## Testing Strategy (Epic 1)

- **Unit Tests:** All DAOs, repositories, services, adapters
- **Widget Tests:** Navigation guards, theme application
- **Integration Tests:** Firebase Auth flow, database migrations, Sefaria API roundtrip (mishnayos index fetch)
- **CI:** Run on every PR, block merge if failing

**Coverage Target:** >80% for core/, >60% for features/ (Epic 1 establishes testing patterns)

---

## Coding Standards (120+ Rules)

See [project-context.md](../../_bmad/bmm/data/project-context-template.md) for full 120+ rules. Key highlights:

- **TDD First:** Write failing test → implement → refactor
- **No premature optimization:** Simple first, measure, then optimize
- **Repository pattern:** All data access through abstract interfaces (P2, P6)
- **Immutable models:** @freezed for all domain models
- **Provider scoping:** Use family providers for curriculum-scoped state (P3)
- **Error handling:** Never swallow exceptions; log via Talker; user-facing errors via Result<T, E> pattern
- **Naming:** `camelCase` for Dart, `snake_case` for DB/Firestore (P1)

---

## Known Toolchain Limitations

### riverpod_generator + `Map<K,V>` Return Types
**Problem:** `riverpod_generator` / `build_runner` cannot generate `.g.dart` files for providers that return `Map<K, V>` types (e.g., `Map<TrackType, int>`). The generated file is simply not created, causing cascade compile errors in every class that imports it.

**Pattern:** When a provider must return a `Map`, manually author the `.g.dart` file using the Riverpod 3 class structure. Do **not** run `build_runner` targeting that file — it will not produce output and will not overwrite a manually created file.

**Affected providers (as of Epic 4):**
- `progress_providers.g.dart` — manually authored, contains `getTrackBreakdown` provider returning `Map<TrackType, int>`

**Rule for future epics:** If a new provider returns `Map<K, V>`, create the `.g.dart` file manually from the start. Do not wait for build_runner to fail.

---

## Entering Each Epic — Codebase State Briefs

### Entering Epic 5: Configurable Stages & Learning Order (2026-03-12)

**Schema version at the time of this section (Epic 5):** 2. For the current schema version, see [`architecture.md`](../architecture.md) — the DB has since been split and the User DB is now at v15 (Epic 19).

**Critical field change from Epic 3:**
> `completions` table uses `sefaria_ref` (String), NOT `content_item_id`. Any query, service, or exception that references completions must use `sefariaRef` in Dart and `sefaria_ref` in SQL/Drift.

**Canonical track implementation:**
> Use `TrackRepository` (DB-backed, in `features/tracks/data/`). Do NOT create a `TrackService` or any in-memory track abstraction. `TrackRepository` is injected via `trackRepositoryProvider`.

**Track initialization:**
> `CurriculumActivationService.activate()` calls `trackRepository.initializeDefaultTracks(curriculum)` — personal track is set up automatically on curriculum activation. No manual setup needed.

**Track colors:**
> Defined in `app_theme.dart` (personal=blue, school=green, tutor=orange). Never hardcode track colors in feature code — always read from theme.

**Manual provider files:**
> `features/progress/presentation/providers/progress_providers.g.dart` is manually authored (riverpod_generator limitation — see Toolchain section above). Do not run build_runner targeting this file.

**Active Firestore sync TODO:**
> Track activation state (curriculum_tracks table) is NOT yet synced to Firestore. Marked for Epic 13. Do not add Firestore sync for tracks in Epic 5 — it is intentionally deferred.

**Test baseline entering Epic 5:** 671 passing tests.

---

## Anti-Patterns to Avoid

❌ **Hardcoded 3-stage assumption** — stages are user-configurable per D3
❌ **Global points accumulation** — points are per-curriculum per D8
❌ **Curriculum-specific hardcoding** — use CurriculumId enum + adapters (D6)
❌ **Feature module imports in core/** — violates P6 (use abstract interfaces)
❌ **Local-time storage** — always store UTC per P5
❌ **Direct Firebase writes from presentation** — go through repositories (D4)
❌ **Anonymous auth** — requires account per D2 (multi-device sync)

---

## Quick Start: Implementing a New Story

1. **Read the "Entering Epic N" section** above for the current epic's codebase state brief — schema changes, canonical implementations, known pitfalls.
2. **Search before you build** — `grep -r "ClassName" lib/` for every new abstraction. If it exists, wire it. Don't create a parallel implementation.
3. **Read architecture.md** section for relevant decisions (D1-D8) and patterns (P1-P6)
4. **Write failing tests** for domain models, repository interface, service logic
3. **Implement data layer** (DAO, repository impl) following P2
4. **Implement domain layer** (models, services) with @freezed, immutability
5. **Implement presentation layer** (providers, screens, widgets) using P3 family pattern
6. **Wire navigation** (auto_route) with guards if needed
7. **Add sync** (Epic 13) if data needs cloud persistence (D4, P4)
8. **Test end-to-end** in integration test
9. **Update this reference** if new patterns emerge

---

**Questions?** Check [architecture.md](architecture.md) for full rationale, or ask in Linear issue comments.
