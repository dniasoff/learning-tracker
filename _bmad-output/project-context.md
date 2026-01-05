---
project_name: 'mishnayos-tracker'
user_name: 'Daniel'
date: '2026-01-04'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'code_quality_rules', 'workflow_rules', 'critical_rules']
status: 'complete'
rule_count: 120+
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

**Framework & Language:**
- Flutter (latest stable channel)
- Dart SDK (null-safe, latest stable)
- Android: Kotlin, API 21+ minimum

**Core Dependencies:**
- drift ^2.30.0 + drift_dev ^2.30.0 (SQLite ORM, type-safe queries)
- auto_route ^9.3.0 + auto_route_generator ^9.3.0 (type-safe navigation)
- flutter_riverpod + riverpod_generator (state management & DI)
- freezed ^3.2.3 + freezed_annotation (immutable data classes)
- dio ^5.9.0 (HTTP client)
- talker ~4.x-5.x + talker_flutter + talker_dio_logger + talker_riverpod_logger (logging)
- mocktail (testing mocks, null-safe)
- json_serializable (JSON serialization)
- build_runner (unified code generation)

**Backend & Integration:**
- Firebase: firebase_core, firebase_auth (Anonymous), cloud_firestore
- flutter_secure_storage (PIN encryption)
- flutter_local_notifications (reminders)
- connectivity_plus (network detection)
- kosher_dart (Hebrew calendar)

**Critical Version Rules:**
- ⚠️ ALWAYS use latest stable versions - research each dependency before adding
- All code generation packages use unified build_runner
- Talker integrations must match core talker version
- Use `--dart-define-from-file` for environment config (no package needed)

## Critical Implementation Rules

### Language-Specific Rules (Dart/Flutter)

**Null-Safety & Type Safety:**
- ✅ ALWAYS enable null-safety (Dart SDK is null-safe)
- ✅ NEVER use `dynamic` unless absolutely necessary - prefer specific types
- ✅ Use `late` keyword sparingly - only when initialization cannot happen in constructor
- ⚠️ Code generation provides compile-time type safety - let it catch errors early

**Code Generation Workflow:**
- ⚠️ CRITICAL: Run `dart run build_runner build --delete-conflicting-outputs` after any changes to:
  - drift table definitions
  - auto_route annotations
  - freezed models
  - riverpod_generator providers
  - json_serializable classes
- ✅ NEVER commit generated files (*.g.dart, *.freezed.dart, *.gr.dart)
- ✅ Always add generated files to .gitignore

**File & Code Naming:**
- Files: snake_case (e.g., `mishna_repository.dart`, `completion_tracker.dart`)
- Classes: PascalCase (e.g., `MishnaRepository`, `CompletionTracker`)
- Functions/Methods: camelCase (e.g., `getMishna()`, `markComplete()`)
- Variables: camelCase (e.g., `mishnaId`, `completedAt`)
- Constants: lowerCamelCase for runtime, SCREAMING_SNAKE_CASE for compile-time
- Private members: Leading underscore (e.g., `_database`, `_syncManager`)

**Import Conventions:**
- ✅ Use relative imports within the same feature module
- ✅ Use package imports for cross-feature dependencies
- ✅ Group imports: Dart SDK → Flutter → External packages → Internal packages → Relative
- ⚠️ NEVER import implementation files from other features - use domain interfaces

**Async/Await Patterns:**
- ✅ ALWAYS use async/await, not .then() chains
- ✅ Use Future<T> for single async operations
- ✅ Use Stream<T> for reactive data (especially with drift)
- ⚠️ Riverpod handles async state - return Future/Stream directly, not AsyncValue manually

**Error Handling:**
- ✅ Use try-catch blocks for expected errors
- ✅ Let unexpected errors bubble up to Riverpod AsyncValue.error
- ✅ Log all errors with talker before rethrowing
- ⚠️ NEVER show technical error messages to users - transform in presentation layer

### Framework-Specific Rules (Flutter Ecosystem)

**Clean Architecture Layers:**
- ⚠️ CRITICAL: Follow dependency rule - inner layers NEVER depend on outer layers
  - Presentation → Domain (via use cases)
  - Data → Domain (implements repository interfaces)
  - Domain → No dependencies (pure business logic)
- ✅ Feature-first structure: `lib/features/<feature>/{data,domain,presentation}`
- ✅ Shared code in `lib/core/` only
- ⚠️ NEVER import between feature modules - use core providers

**Riverpod State Management:**
- ✅ ALWAYS use riverpod_generator with @riverpod annotation
- ✅ Provider naming: noun-based camelCase (generates `...Provider` suffix)
  - Function: `mishnaRepository` → Generated: `mishnaRepositoryProvider`
- ✅ Use AsyncValue for ALL async operations - no custom loading/error states
- ✅ UI watches with `ref.watch()`, mutations with `ref.read()`
- ✅ Invalidate providers after mutations: `ref.invalidate(affectedProvider)`
- ⚠️ NEVER create custom freezed state classes (Loading/Success/Error) - use AsyncValue

**drift Database Patterns:**
- ✅ Table naming: snake_case plural (SQL: `mishna_completions`)
- ✅ Column naming: snake_case (SQL: `mishna_id`, `completed_at`)
- ✅ Dart accessors: auto-generated camelCase (`mishnaCompletion.mishnaId`)
- ⚠️ ALWAYS use transactions for write operations
- ✅ Use `watch()` queries for reactive streams with Riverpod
- ✅ Foreign keys: `references(TableName, #columnName)`
- ⚠️ DateTime columns ALWAYS store UTC - never local time

**auto_route Navigation:**
- ✅ Route paths: kebab-case (`/mishna-browsing`, `/parent-mode`)
- ✅ Route parameters: camelCase (`:mishnaId`, `:trackId`)
- ✅ Use @AutoRouterConfig annotation on AppRouter class
- ✅ Guards for PIN-protected routes (parent/tutor modes)
- ⚠️ Type-safe navigation - compile errors prevent runtime navigation bugs

**freezed Immutable Data:**
- ✅ ALWAYS use @freezed for domain entities and DTOs
- ✅ Use `const factory` pattern for constructors
- ✅ Add `fromJson`/`toJson` for Firestore DTOs
- ✅ Use `copyWith` for immutable updates - NEVER mutate state
- ⚠️ Generated files in same directory as source

**Material Design 3 & UI:**
- ✅ Use Material 3 components (Material You)
- ✅ RTL support for Hebrew text - use Directionality widget
- ✅ Bidirectional text handling for mixed Hebrew/English
- ✅ 60fps rendering requirement - profile with Flutter DevTools
- ⚠️ Target mid-range devices, not flagship-only features

**Firebase Integration:**
- ✅ Anonymous Authentication for v1.0 (single-family use)
- ✅ Firestore collections: camelCase (`mishnaCompletions`)
- ✅ Firestore fields: camelCase (`mishnaId`, `completedAt`)
- ✅ Timestamps: Use Firestore Timestamp type (UTC)
- ⚠️ SQLite is source of truth - Firestore is backup only
- ⚠️ Sync only after local write succeeds

### Testing Rules

**Test Structure & Organization:**
- ⚠️ CRITICAL: Mirror lib/ structure in test/ folder exactly
  - `lib/features/mishna_browsing/data/repositories/mishna_repository.dart`
  - `test/features/mishna_browsing/data/repositories/mishna_repository_test.dart`
- ✅ Test file naming: `<source_file_name>_test.dart`
- ✅ Group tests logically with `group()`, individual tests with `test()`
- ✅ Arrange-Act-Assert pattern for clarity

**Mocking with mocktail:**
- ✅ ALWAYS use mocktail - NEVER use mockito (no code generation needed)
- ✅ Create mocks in `test/mocks/` for reuse across test files
- ✅ Mock interfaces, not implementations
- ✅ Use `when()` for stubbing, `verify()` for assertions
- ⚠️ NEVER mock freezed classes - create real instances (cheap, immutable)

**Riverpod Testing Patterns:**
- ✅ Use ProviderContainer for unit tests
- ✅ Override providers with mocks: `container.overrideWith(...)`
- ✅ Test provider state transitions (loading → data → error)
- ✅ Test AsyncValue states with `.when()` handlers
- ✅ Dispose containers after tests: `addTearDown(() => container.dispose())`

**drift Database Testing:**
- ✅ Use in-memory database for tests: `NativeDatabase.memory()`
- ✅ Create fresh database instance for each test
- ✅ Seed test data in setUp()
- ✅ Test transactions rollback on errors
- ⚠️ Test UTC timezone handling explicitly

**Test Fixtures:**
- ✅ Create reusable test fixtures in `test/fixtures/`
- ✅ Use factories for creating test data
- ✅ freezed models: Use real instances, not mocks
- ⚠️ Fixtures should cover edge cases (empty lists, null fields, boundary values)

**Coverage Requirements:**
- ⚠️ CRITICAL: 80%+ coverage on domain layer (use cases, entities)
- ✅ 70%+ coverage on data layer (repositories, data sources)
- ✅ Widget tests for critical UI flows
- ✅ Integration tests for end-to-end scenarios
- ⚠️ Run `flutter test --coverage` to verify

**Widget Testing:**
- ✅ Wrap widgets with ProviderScope for Riverpod access
- ✅ Use `pumpWidget()` for initial render, `pump()` for updates
- ✅ Test loading states, error states, and success states
- ✅ Use `find.byType()`, `find.text()`, `find.byKey()` for queries
- ✅ Test RTL layout for Hebrew text rendering

**Integration Testing:**
- ✅ Place in `test/integration_test/` directory
- ✅ Test complete flows (mark complete → update progress → sync)
- ✅ Use real database (in-memory), mock external APIs (Sefaria, Firebase)
- ⚠️ Test offline-first scenarios explicitly

### Code Quality & Style Rules

**Linting & Formatting:**
- ✅ Configure `analysis_options.yaml` with strict Flutter lints
- ✅ Use `flutter analyze` before committing
- ✅ Use `dart format .` to auto-format all code
- ⚠️ NEVER disable linter rules without documented justification
- ✅ Target line length: 80 characters (Flutter standard)

**Code Organization:**
- ✅ One class per file (except for small related classes like enums)
- ✅ File location matches class name: `MishnaRepository` → `mishna_repository.dart`
- ✅ Order: imports → part statements → class definition
- ✅ Class member order: static → instance fields → constructors → methods
- ⚠️ Keep files under 300 lines - extract if larger

**Naming Conventions Summary:**
- SQL (drift): snake_case (`mishna_completions`, `completed_at`)
- Dart files: snake_case (`mishna_repository.dart`)
- Dart classes: PascalCase (`MishnaRepository`)
- Dart functions/methods: camelCase (`getMishna()`)
- Dart variables: camelCase (`mishnaId`)
- JSON/Firestore: camelCase (`mishnaId`, `completedAt`)
- Routes: kebab-case (`/mishna-browsing`)
- Providers: noun-based camelCase (`mishnaRepository`)

**Documentation Requirements:**
- ✅ Document public APIs with /// dartdoc comments
- ✅ Document complex business logic with inline comments
- ⚠️ NEVER document obvious code - let code speak for itself
- ✅ Document "why", not "what" - code shows what it does
- ✅ Update comments when changing code

**Complexity Management:**
- ✅ Functions: Keep under 50 lines, ideally under 25
- ✅ Cyclomatic complexity: Max 10 (use linter to enforce)
- ✅ Extract helper methods for readability
- ⚠️ Avoid deep nesting (max 3-4 levels)
- ✅ Use early returns to reduce nesting

**Performance Considerations:**
- ✅ Use `const` constructors wherever possible (reduces rebuilds)
- ✅ Avoid rebuilding widgets unnecessarily - use const widgets
- ✅ Profile with Flutter DevTools before optimizing
- ⚠️ Don't premature optimize - measure first
- ✅ Large lists: Use ListView.builder, not ListView with all items

**Security Best Practices:**
- ⚠️ NEVER hardcode secrets, API keys, or credentials
- ✅ Use `--dart-define-from-file` for configuration
- ✅ Store PINs with bcrypt hashing via flutter_secure_storage
- ✅ Validate all user input before processing
- ⚠️ Sanitize data before storing in database or sending to API

**Immutability Enforcement:**
- ⚠️ CRITICAL: NEVER mutate state directly
- ✅ ALWAYS use freezed for data classes
- ✅ Use copyWith for updates, not direct assignment
- ✅ Collections: Use immutable patterns or List.unmodifiable()
- ⚠️ This is critical for Riverpod state management correctness

### Development Workflow Rules

**Project Initialization (First Implementation):**
- ⚠️ CRITICAL: Use exact command from architecture:
  ```bash
  flutter create \
    --org com.niasoff.mishnayos \
    --platforms=android \
    --android-language kotlin \
    mishnayos_tracker
  ```
- ✅ Immediately set up `pubspec.yaml` with all dependencies
- ✅ Configure `build.yaml` for build_runner
- ✅ Create `.gitignore` with generated files (*.g.dart, *.freezed.dart, *.gr.dart)
- ✅ Set up `analysis_options.yaml` with strict Flutter lints
- ✅ Create `config/dev.json` and `config/prod.json` templates

**Development Commands:**
- Run app: `flutter run --dart-define-from-file=config/dev.json`
- Code generation: `dart run build_runner build --delete-conflicting-outputs`
- Watch mode (dev): `dart run build_runner watch --delete-conflicting-outputs`
- Run tests: `flutter test`
- Test coverage: `flutter test --coverage`
- Format code: `dart format .`
- Analyze: `flutter analyze`
- Build APK: `flutter build apk --release --dart-define-from-file=config/prod.json`

**Git Workflow:**
- ⚠️ NEVER commit generated files (*.g.dart, *.freezed.dart, *.gr.dart)
- ✅ Run `dart format .` before committing
- ✅ Run `flutter analyze` before committing
- ✅ Run `flutter test` before committing
- ✅ Ensure build_runner generated files are up-to-date
- ⚠️ Each commit should be focused on a single feature or fix

**Branch Naming:**
- Features: `feature/<feature-name>` (e.g., `feature/mishna-browsing`)
- Bugs: `fix/<bug-description>` (e.g., `fix/completion-sync-error`)
- Chores: `chore/<task-name>` (e.g., `chore/update-dependencies`)

**Commit Message Format:**
- Use conventional commits format:
  - `feat: add mishna browsing screen`
  - `fix: resolve sync conflict on completion`
  - `test: add coverage for scheduler logic`
  - `refactor: extract progress calculation to use case`
  - `chore: update drift to 2.30.0`

**Pull Request Requirements:**
- ✅ All tests passing
- ✅ Code formatted and analyzed
- ✅ Generated files up-to-date
- ✅ Coverage meets requirements (80%+ domain)
- ✅ No linter warnings

**Environment Configuration:**
- Development: `config/dev.json` (development Firebase project)
- Production: `config/prod.json` (production Firebase project)
- ⚠️ NEVER commit actual config files with secrets to git
- ✅ Provide `.example` templates for config structure
- ✅ Use `--dart-define-from-file` flag for all runs

**Code Generation Workflow:**
- ⚠️ CRITICAL: Run after ANY changes to annotated files
- ✅ Use watch mode during active development
- ✅ Commit source files only, not generated files
- ✅ CI should verify generated files match source

### Critical Don't-Miss Rules

**Anti-Patterns to AVOID:**

❌ **NEVER create custom loading/error state classes:**
```dart
// BAD - Custom state with freezed
@freezed class DataState { Loading(), Success(data), Error(error) }

// GOOD - Use AsyncValue
@riverpod Future<Data> data(...) async { return fetchData(); }
```

❌ **NEVER mutate state directly:**
```dart
// BAD - Direct mutation
myList.add(item);
entity.field = newValue;

// GOOD - Immutable with freezed
final updated = entity.copyWith(field: newValue);
final newList = [...myList, item];
```

❌ **NEVER mix naming conventions:**
```dart
// BAD - Inconsistent naming
class MishnaCompletions extends Table {
  IntColumn get MishnaID => integer()(); // Wrong: PascalCase in SQL
}

// GOOD - Consistent snake_case for SQL
class MishnaCompletions extends Table {
  IntColumn get mishnaId => integer()(); // Generates SQL: mishna_id
}
```

❌ **NEVER store DateTime as local time:**
```dart
// BAD - Local timezone
final now = DateTime.now(); // Local time!
await db.insert(completion.copyWith(completedAt: now));

// GOOD - Always UTC
final now = DateTime.now().toUtc(); // UTC!
await db.insert(completion.copyWith(completedAt: now));
```

❌ **NEVER skip transactions for writes:**
```dart
// BAD - No transaction
await db.insert(completion);
await db.update(progress);

// GOOD - Atomic transaction
await db.transaction(() async {
  await db.insert(completion);
  await db.update(progress);
});
```

❌ **NEVER import between feature modules:**
```dart
// BAD - Direct feature imports
import '../../mishna_browsing/data/repositories/mishna_repository.dart';

// GOOD - Use core providers
final repo = ref.watch(mishnaRepositoryProvider); // from core/providers
```

**Edge Cases to Handle:**

⚠️ **Empty State Handling:**
- Empty Mishna list (first launch before sync)
- Zero completions (new user)
- No tracks configured (onboarding incomplete)
- Empty Hebrew calendar calculations (invalid dates)

⚠️ **Hebrew Text Rendering:**
- Mixed Hebrew/English text needs BiDi handling
- RTL layout must work on all screen sizes
- Nikud (vowel points) must render correctly
- Hebrew dates must use kosher_dart, not manual calculations

⚠️ **Offline-First Scenarios:**
- App starts offline (no Firebase access)
- Sync interrupted mid-operation (resumable checkpoints)
- Firestore unavailable (SQLite continues working)
- Sefaria API down (use cached text)

⚠️ **Completion Immutability:**
- Once marked complete, NEVER allow unmarking
- Stage progression is one-way only (learn → chazara1 → chazara2)
- Append-only log - no deletions allowed
- Transactions prevent partial writes

⚠️ **Multi-Track Edge Cases:**
- Prevent same Mishna in multiple tracks (system validation)
- Track deletion must handle orphaned bookmarks
- Personal track cannot be deleted (system requirement)
- School/tutor tracks are optional (validate existence)

**Security Gotchas:**

⚠️ **PIN Security:**
- NEVER store PINs in plain text
- ALWAYS use bcrypt hashing
- Implement lockout after 5 failed attempts
- Parent PIN !== Tutor PIN (separate storage)

⚠️ **Firebase Security:**
- Anonymous auth scopes data to device in v1.0
- Firestore rules MUST prevent cross-user access
- NEVER trust client-side validation only
- Timestamps must use serverTimestamp for consistency

⚠️ **Configuration Secrets:**
- NEVER commit config/dev.json or config/prod.json
- Use --dart-define-from-file, not plain .env files
- Provide .example templates without secrets
- Firebase config is public but still should use define files

**Performance Gotchas:**

⚠️ **ListView Performance:**
- 4,192 Mishnayos requires ListView.builder (not ListView)
- Use const widgets wherever possible
- Avoid rebuilding entire lists on single item change
- Profile scrolling performance on mid-range devices

⚠️ **Database Query Performance:**
- Index frequently queried columns (mishna_id, completed_at, track_id)
- Use watch() queries sparingly (they rebuild on every change)
- Batch inserts in transactions for first-launch sync
- Limit query results when appropriate

⚠️ **Code Generation Performance:**
- Build runner can be slow with many annotations
- Use watch mode during development
- Don't run build_runner in CI unnecessarily
- Clean build/ folder if generation fails

**Data Integrity Gotchas:**

⚠️ **Sync Conflict Resolution:**
- Last-write-wins requires UTC timestamp comparison
- Local SQLite wins on conflict (source of truth)
- Firestore is backup, not authoritative
- Exponential backoff prevents sync storms

⚠️ **Zero Data Loss Requirement (NFR11):**
- EVERY write must use transactions
- EVERY error must be logged with talker
- EVERY sync must be resumable with checkpoints
- State must persist through reboots (test this!)

⚠️ **Immutability Violations:**
- Completion log is append-only (no updates/deletes)
- Once stage marked complete, it's locked forever
- Validation must happen BEFORE transaction commit
- Use drift's @Check() constraints where possible

---

## Usage Guidelines

**For AI Agents:**

- Read this file BEFORE implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Consult architecture.md for additional context
- Update this file if new critical patterns emerge

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time
- Add new gotchas discovered during implementation

**Last Updated:** 2026-01-04
