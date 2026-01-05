# Coding Standards - Mishnayos Tracker

**Status:** CAST-IRON RULES - Violations block PRs
**Audience:** AI agents and developers

---

## CRITICAL VIOLATIONS (PR Blockers)

### 1. State Management - Use AsyncValue, Not Custom State
```dart
// FORBIDDEN - Custom loading/error state classes
@freezed class DataState { Loading(), Success(data), Error(error) }

// REQUIRED - Riverpod AsyncValue
@riverpod
Future<Data> data(Ref ref) async => fetchData();
// AsyncValue.loading/data/error handled automatically
```

### 2. DateTime - MUST Use UTC
```dart
// FORBIDDEN - Local timezone
final now = DateTime.now();

// REQUIRED - Always UTC
final now = DateTime.now().toUtc();
```

### 3. Immutability - NEVER Mutate State
```dart
// FORBIDDEN - Direct mutation
myList.add(item);
entity.field = newValue;

// REQUIRED - Immutable patterns with freezed
final updated = entity.copyWith(field: newValue);
final newList = [...myList, item];
```

### 4. Database Writes - MUST Use Transactions
```dart
// FORBIDDEN - No transaction
await db.insert(completion);
await db.update(progress);

// REQUIRED - Atomic transaction
await db.transaction(() async {
  await db.insert(completion);
  await db.update(progress);
});
```

### 5. Feature Isolation - NEVER Import Between Features
```dart
// FORBIDDEN - Direct feature imports
import '../../mishna_browsing/data/repositories/mishna_repository.dart';

// REQUIRED - Use core providers
final repo = ref.watch(mishnaRepositoryProvider); // from core/providers
```

### 6. Generated Files - NEVER Commit
Files matching these patterns MUST be in `.gitignore`:
- `*.g.dart`
- `*.freezed.dart`
- `*.gr.dart`

### 7. Hardcoded Secrets
```dart
// FORBIDDEN - Hardcoded credentials
const apiKey = 'sk_live_abc123';
const dbUrl = 'postgresql://user:pass@host/db';

// REQUIRED - Environment configuration
// Use --dart-define-from-file=config/dev.json
final apiKey = const String.fromEnvironment('API_KEY');
```

### 8. Completion Immutability - APPEND-ONLY
Once a Mishna stage is marked complete, it is **locked forever**. No deletions, no unmarking.

---

## Security - Secrets Management - ZERO TOLERANCE

**FORBIDDEN - NEVER commit to repository:**
- Firebase config files with real credentials
- API keys, tokens, secrets
- `config/dev.json`, `config/prod.json`

**REQUIRED patterns:**
```bash
# config/dev.json.example (safe to commit)
{
  "FIREBASE_PROJECT_ID": "your-project-id",
  "FIREBASE_API_KEY": "your-api-key"
}

# Actual config files in .gitignore
config/dev.json
config/prod.json
```

```dart
// Access via --dart-define-from-file
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
```

**PIN Security:**
- NEVER store PINs in plain text
- ALWAYS use bcrypt hashing via flutter_secure_storage
- Parent PIN !== Tutor PIN (separate storage keys)

---

## Clean Code Policy - ZERO TOLERANCE

**FORBIDDEN patterns - delete, don't mark:**
- `@deprecated` annotations, `// Legacy`, `// TODO: remove`
- Fallback logic for old formats
- Dual-format support
- Re-exports "for compatibility"

**Rule:** One format only. Migrate data, update code, delete old code.

---

## Clean Code Principles (Robert Martin)

### The Boy Scout Rule
**Leave code cleaner than you found it.**

When touching a file for any reason:
- Fix one small thing (rename unclear variable, extract method, add type)
- Don't mix cleanup with feature work in same commit
- Small improvements compound over time

### Meaningful Names

**Intention-Revealing Names:**
```dart
// BAD - What does d mean?
int d; // elapsed time in days

// GOOD - Name reveals intent
int elapsedDays;
int daysSinceCreation;
int fileAgeInDays;
```

**Avoid Disinformation:**
```dart
// BAD - It's not actually a List
Map<String, Mishna> mishnaList;

// GOOD - Accurate name
Map<String, Mishna> mishnasByRef;
Set<int> completedMishnaIds;
```

**Pronounceable & Searchable Names:**
```dart
// BAD - Unpronounceable, unsearchable
int mshCnt;
DateTime genymdhms;

// GOOD - Clear and searchable
int mishnaCount;
DateTime generatedTimestamp;
```

**Class Names:** Nouns or noun phrases (`Mishna`, `CompletionTracker`, `SyncManager`)
**Method Names:** Verbs or verb phrases (`getMishna()`, `markComplete()`, `calculateProgress()`)

### Functions - Small & Focused

**Do One Thing:**
```dart
// BAD - Does multiple things
Future<void> processCompletion(int mishnaId) async {
  final mishna = await getMishna(mishnaId);
  await markComplete(mishna);
  await updateProgress();
  await syncToCloud();
  await sendNotification();
  await updateStreak();
}

// GOOD - Single responsibility, calls focused functions
Future<void> processCompletion(int mishnaId) async {
  await _recordCompletion(mishnaId);
  await _updateDerivedState(mishnaId);
  await _notifyUser();
}
```

**Function Size Guidelines:**
- Ideal: 5-10 lines
- Maximum: 25 lines (extract if longer)
- One level of abstraction per function

**Single Level of Abstraction Principle (SLAP):**
```dart
// BAD - Mixed abstraction levels
Future<void> syncProgress() async {
  final completions = await db.select(mishnaCompletions).get();
  final json = jsonEncode(completions.map((c) => c.toJson()).toList());
  final response = await http.post(Uri.parse(url), body: json);
  if (response.statusCode == 200) {
    await prefs.setString('lastSync', DateTime.now().toIso8601String());
  }
}

// GOOD - Consistent abstraction level
Future<void> syncProgress() async {
  final completions = await _getLocalCompletions();
  await _uploadToCloud(completions);
  await _recordSyncTimestamp();
}
```

**Command-Query Separation:**
```dart
// BAD - Query with side effect
bool markCompleteAndCheckStreak(int mishnaId) {
  _completions.add(mishnaId);  // Command (modifies state)
  return _streak > 7;          // Query (returns value)
}

// GOOD - Separated
void markComplete(int mishnaId) => _completions.add(mishnaId);
bool hasWeekStreak() => _streak > 7;
```

### Comments - Why, Not What

**Good Comments:**
```dart
// Sefaria API returns perek as 1-indexed but we store 0-indexed
final storedPerek = sefariaPerek - 1;

// Hebrew calendar day starts at sunset, so we adjust by 6 hours
// to align with civil midnight for display purposes
final adjustedDate = hebrewDate.subtract(Duration(hours: 6));

/// Calculates optimal daily Mishnayos count to reach bar mitzvah goal.
/// Uses remaining days and accounts for Shabbos/Yom Tov rest days.
int calculateDailyTarget(DateTime barMitzvahDate) { ... }
```

**Bad Comments (Delete These):**
```dart
// BAD - Restates the code
i++; // increment i

// BAD - Obvious from name
/// Gets the mishna
Mishna getMishna(int id) { ... }

// BAD - Commented-out code (use git history)
// final oldValue = calculateOldWay();

// BAD - TODO without action
// TODO: fix this later
```

### Error Handling

**Don't Return Null - Use Optionals or Throw:**
```dart
// BAD - Caller must check null
Mishna? getMishna(int id) {
  return _mishnas[id];  // Returns null if not found
}

// GOOD - Explicit optional with freezed
@freezed
class MishnaResult with _$MishnaResult {
  const factory MishnaResult.found(Mishna mishna) = _Found;
  const factory MishnaResult.notFound() = _NotFound;
}

// GOOD - Throw for exceptional cases
Mishna getMishnaOrThrow(int id) {
  final mishna = _mishnas[id];
  if (mishna == null) throw MishnaNotFoundException(id);
  return mishna;
}
```

**Don't Pass Null:**
```dart
// BAD - Null parameter
void updateProgress(int? mishnaId) {
  if (mishnaId == null) return;  // Defensive check everywhere
  ...
}

// GOOD - Required parameter, validate at boundaries
void updateProgress(int mishnaId) { ... }
```

**Fail Fast:**
```dart
// Validate at entry points, not deep in call stack
Future<void> markComplete(int mishnaId, int stage) async {
  // Validate immediately
  if (mishnaId < 1 || mishnaId > 4192) {
    throw ArgumentError('Invalid mishnaId: $mishnaId');
  }
  if (stage < 1 || stage > 3) {
    throw ArgumentError('Invalid stage: $stage');
  }

  // Proceed with confidence
  await _repository.recordCompletion(mishnaId, stage);
}
```

### DRY - Don't Repeat Yourself

**Extract Common Patterns:**
```dart
// BAD - Duplicated validation
void createTrack(String name) {
  if (name.isEmpty) throw ArgumentError('Name required');
  if (name.length > 50) throw ArgumentError('Name too long');
  ...
}

void renameTrack(String name) {
  if (name.isEmpty) throw ArgumentError('Name required');
  if (name.length > 50) throw ArgumentError('Name too long');
  ...
}

// GOOD - Single source of truth
String _validateTrackName(String name) {
  if (name.isEmpty) throw ArgumentError('Name required');
  if (name.length > 50) throw ArgumentError('Name too long');
  return name.trim();
}

void createTrack(String name) {
  final validName = _validateTrackName(name);
  ...
}
```

**But Avoid Premature Abstraction:**
- Wait for 3 occurrences before extracting (Rule of Three)
- Duplication is better than wrong abstraction

---

## Extreme Programming (XP) Practices

### Test-Driven Development (TDD)

**Red-Green-Refactor Cycle:**
1. **Red:** Write a failing test first
2. **Green:** Write minimal code to pass
3. **Refactor:** Clean up while tests pass

```dart
// Step 1: RED - Write failing test
test('calculates daily target for 100 remaining days', () {
  final calculator = SchedulerCalculator();
  final remaining = 1000; // Mishnayos remaining
  final days = 100;

  final target = calculator.dailyTarget(remaining, days);

  expect(target, 10); // 1000 / 100 = 10
});

// Step 2: GREEN - Minimal implementation
int dailyTarget(int remaining, int days) => remaining ~/ days;

// Step 3: REFACTOR - Handle edge cases, improve naming
int dailyTarget(int remainingMishnayos, int remainingDays) {
  if (remainingDays <= 0) return remainingMishnayos;
  return (remainingMishnayos / remainingDays).ceil();
}
```

**FIRST Principles for Tests:**
- **F**ast: Tests run in milliseconds
- **I**ndependent: No test depends on another
- **R**epeatable: Same result every time
- **S**elf-validating: Pass or fail, no manual checking
- **T**imely: Written before or with production code

### Simple Design (Four Rules)

Kent Beck's Four Rules of Simple Design (in priority order):

1. **Passes all tests** - Code works correctly
2. **Reveals intention** - Code is readable and clear
3. **No duplication** - DRY principle applied
4. **Fewest elements** - No unnecessary complexity

```dart
// Passes tests + Reveals intention + No duplication + Minimal
class CompletionTracker {
  final List<Completion> _completions;

  bool isComplete(int mishnaId, int stage) =>
    _completions.any((c) => c.mishnaId == mishnaId && c.stage == stage);

  int completedCount(int stage) =>
    _completions.where((c) => c.stage == stage).length;
}
```

### Continuous Integration

**Integrate frequently:**
- Commit to main branch at least daily
- All tests must pass before commit
- Build and test automatically on every push

**Keep the build green:**
- Never commit on a broken build
- Fix broken builds immediately (highest priority)
- Run full test suite locally before pushing

### Refactoring

**Refactor continuously, not in big batches:**
```dart
// During feature work, improve as you go:
// 1. Rename unclear variable
// 2. Extract method
// 3. Remove dead code
// 4. Simplify conditional
```

**Safe refactoring rules:**
- Only refactor when tests pass
- Make one change at a time
- Run tests after each change
- Commit working refactors separately from features

### Collective Code Ownership

- Any developer can modify any code
- No "owner" approval needed for changes
- Consistent style enables shared ownership (hence these standards)

### YAGNI - You Aren't Gonna Need It

**Don't build for hypothetical futures:**
```dart
// BAD - Over-engineered for "future" needs
abstract class BaseRepository<T, ID> {
  Future<T?> findById(ID id);
  Future<List<T>> findAll();
  Future<void> save(T entity);
  Future<void> delete(ID id);
  Future<List<T>> findBySpec(Specification<T> spec);
  Future<Page<T>> findPaged(Pageable pageable);
  // ... 20 more methods "we might need"
}

// GOOD - Build what you need now
class MishnaRepository {
  Future<Mishna?> getMishna(int id) => ...;
  Future<List<Mishna>> getMishnasByPerek(String masechta, int perek) => ...;
}
```

**Add features when needed, not "just in case":**
- Multi-language support? Add when there's a second language
- Plugin system? Add when there's a second plugin
- Configuration options? Add when someone asks

---

## Architecture Standards

### Clean Architecture Layers
```
lib/
├── features/
│   ├── mishna_browsing/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   └── repositories/
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── widgets/
│   │       └── providers/
│   └── [other features...]
└── core/
    ├── database/          # drift database configuration
    ├── navigation/        # auto_route AppRouter
    ├── logging/           # talker configuration
    ├── theme/             # Material Design 3 theme + RTL
    ├── auth/              # PIN authentication, Firebase
    ├── network/           # dio HTTP client, Sefaria API
    ├── providers/         # Riverpod core providers
    ├── utils/             # Shared utilities
    └── constants/         # App-wide constants
```

### Dependency Rule (CRITICAL)
- Presentation -> Domain (via use cases)
- Data -> Domain (implements repository interfaces)
- Domain -> No dependencies (pure business logic)

---

## Naming Conventions (MANDATORY)

| Context | Convention | Example |
|---------|-----------|---------|
| SQL (drift tables) | snake_case | `mishna_completions`, `completed_at` |
| Dart files | snake_case | `mishna_repository.dart` |
| Dart classes | PascalCase | `MishnaRepository`, `CompletionTracker` |
| Dart functions/methods | camelCase | `getMishna()`, `markComplete()` |
| Dart variables | camelCase | `mishnaId`, `completedAt` |
| Constants (compile-time) | SCREAMING_SNAKE_CASE | `MAX_DAILY_TASKS` |
| Constants (runtime) | lowerCamelCase | `appVersion` |
| Private members | Leading underscore | `_database`, `_syncManager` |
| JSON/Firestore fields | camelCase | `mishnaId`, `completedAt` |
| Route paths | kebab-case | `/mishna-browsing`, `/parent-mode` |
| Route parameters | camelCase | `:mishnaId`, `:trackId` |
| Riverpod providers | noun-based camelCase | `mishnaRepository` -> `mishnaRepositoryProvider` |

---

## Riverpod State Management

### Provider Pattern (REQUIRED)
```dart
// ALWAYS use riverpod_generator with @riverpod annotation
@riverpod
Future<List<Mishna>> mishnaList(Ref ref) async {
  final repo = ref.watch(mishnaRepositoryProvider);
  return repo.getAllMishnas();
}

// UI usage
class MishnaListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mishnas = ref.watch(mishnaListProvider);

    return mishnas.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error: $e'),
      data: (data) => ListView.builder(...),
    );
  }
}
```

### Rules
- Use `ref.watch()` for reading state
- Use `ref.read()` for mutations (event handlers)
- Invalidate after mutations: `ref.invalidate(affectedProvider)`
- NEVER create custom Loading/Success/Error freezed classes

---

## drift Database Standards

### Table Definition Pattern
```dart
// Table naming: snake_case plural (generates SQL table name)
class MishnaCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mishnaId => integer()();  // Generates SQL: mishna_id
  DateTimeColumn get completedAt => dateTime()();  // UTC ONLY
  IntColumn get stage => integer()();
  TextColumn get trackId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Query Patterns
```dart
// Reactive stream for UI updates
Stream<List<MishnaCompletion>> watchCompletions() {
  return (select(mishnaCompletions)
    ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
    .watch();
}

// Single query
Future<MishnaCompletion?> getCompletion(int mishnaId) {
  return (select(mishnaCompletions)
    ..where((t) => t.mishnaId.equals(mishnaId)))
    .getSingleOrNull();
}

// ALWAYS use transactions for writes
Future<void> markComplete(int mishnaId, int stage) {
  return transaction(() async {
    await into(mishnaCompletions).insert(
      MishnaCompletionsCompanion.insert(
        mishnaId: mishnaId,
        stage: stage,
        completedAt: DateTime.now().toUtc(),  // UTC!
      ),
    );
    // Update related tables in same transaction
  });
}
```

---

## freezed Immutable Data Classes

### Entity Pattern (REQUIRED)
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mishna.freezed.dart';
part 'mishna.g.dart';

@freezed
class Mishna with _$Mishna {
  const factory Mishna({
    required int id,
    required String seder,
    required String masechta,
    required int perek,
    required int mishnaNumber,
    required String hebrewText,
    String? englishText,
  }) = _Mishna;

  factory Mishna.fromJson(Map<String, dynamic> json) => _$MishnaFromJson(json);
}
```

### Update Pattern
```dart
// ALWAYS use copyWith for updates
final updated = mishna.copyWith(englishText: newTranslation);

// NEVER mutate
mishna.englishText = newTranslation; // FORBIDDEN
```

---

## auto_route Navigation

### Route Configuration
```dart
@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: HomeRoute.page, initial: true),
    AutoRoute(page: MishnaBrowsingRoute.page, path: '/mishna-browsing'),
    AutoRoute(
      page: ParentModeRoute.page,
      path: '/parent-mode',
      guards: [ParentPinGuard()],  // PIN protection
    ),
  ];
}
```

### Navigation Usage
```dart
// Type-safe navigation - compile errors prevent runtime bugs
context.router.push(const MishnaBrowsingRoute());
context.router.push(MishnaDetailRoute(mishnaId: 42));
```

---

## Testing Standards

### Test Structure (Mirror lib/)
```
test/
├── features/
│   ├── mishna_browsing/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── mishna_repository_test.dart
│   │   └── domain/
│   │       └── entities/
│   │           └── mishna_test.dart
├── mocks/
│   └── mock_repositories.dart
└── fixtures/
    └── mishna_fixtures.dart
```

### Mocking with mocktail (REQUIRED)
```dart
import 'package:mocktail/mocktail.dart';

class MockMishnaRepository extends Mock implements MishnaRepository {}

void main() {
  late MockMishnaRepository mockRepo;

  setUp(() {
    mockRepo = MockMishnaRepository();
  });

  test('should return mishna list', () async {
    // Arrange
    when(() => mockRepo.getAllMishnas()).thenAnswer(
      (_) async => [testMishna],
    );

    // Act
    final result = await mockRepo.getAllMishnas();

    // Assert
    expect(result, [testMishna]);
    verify(() => mockRepo.getAllMishnas()).called(1);
  });
}
```

### Riverpod Testing
```dart
void main() {
  test('provider returns data', () async {
    final container = ProviderContainer(
      overrides: [
        mishnaRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);

    when(() => mockRepo.getAllMishnas()).thenAnswer(
      (_) async => [testMishna],
    );

    final result = await container.read(mishnaListProvider.future);
    expect(result, [testMishna]);
  });
}
```

### drift Database Testing
```dart
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());  // In-memory for tests
  });

  tearDown(() => db.close());

  test('insert completion stores UTC datetime', () async {
    final now = DateTime.now().toUtc();

    await db.markComplete(1, 1, now);

    final result = await db.getCompletion(1);
    expect(result?.completedAt.isUtc, isTrue);
  });
}
```

### Coverage Requirements
- 80%+ coverage on domain layer (use cases, entities)
- 70%+ coverage on data layer (repositories)
- Widget tests for critical UI flows
- Run: `flutter test --coverage`

---

## Code Quality Rules

### File Organization
- One class per file (except small related enums)
- Keep files under 300 lines
- Target line length: 80 characters

### Import Order
```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter
import 'package:flutter/material.dart';

// 3. External packages
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

// 4. Internal packages (absolute)
import 'package:mishnayos_tracker/core/providers/providers.dart';

// 5. Relative imports (same feature)
import '../domain/entities/mishna.dart';
```

### Complexity Management
- Functions under 50 lines, ideally under 25
- Cyclomatic complexity max: 10
- Max nesting: 3-4 levels
- Use early returns to reduce nesting

### Performance
- Use `const` constructors wherever possible
- Large lists: Use `ListView.builder`, not `ListView` with all items
- Profile with Flutter DevTools before optimizing

---

## Development Workflow

### Commands
```bash
# Run app
flutter run --dart-define-from-file=config/dev.json

# Code generation (CRITICAL - after ANY annotated file changes)
dart run build_runner build --delete-conflicting-outputs

# Watch mode during development
dart run build_runner watch --delete-conflicting-outputs

# Tests
flutter test
flutter test --coverage

# Code quality
dart format .
flutter analyze
```

### Pre-Commit Checklist
```bash
dart format .                    # Format code
flutter analyze                  # Check for issues
flutter test                     # Run tests
# Verify build_runner output is up-to-date
dart run build_runner build --delete-conflicting-outputs
```

---

## Git Standards

**Branches:** `feature/<name>` | `fix/<desc>` | `chore/<task>`

**Commits (Conventional):**
```
<type>(<scope>): <description>

feat: add mishna browsing screen
fix: resolve sync conflict on completion
test: add coverage for scheduler logic
refactor: extract progress calculation to use case
chore: update drift to 2.30.0
```

---

## PR Checklist

### Security (MANDATORY)
- [ ] **No secrets committed:** No API keys, tokens, config files with credentials
- [ ] **PIN storage:** Uses bcrypt hashing via flutter_secure_storage
- [ ] **Firebase rules:** Prevents cross-user data access
- [ ] **Input validation:** All inputs validated before processing

### Code Quality
- [ ] AsyncValue for async state (no custom Loading/Error classes)
- [ ] DateTime stored as UTC
- [ ] Immutable state (freezed copyWith, no mutations)
- [ ] Database writes in transactions
- [ ] No cross-feature imports
- [ ] Generated files not committed
- [ ] Naming conventions followed
- [ ] Code formatted (`dart format .`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] Tests passing (`flutter test`)
- [ ] Coverage requirements met (80%+ domain, 70%+ data)

### Clean Code (Robert Martin)
- [ ] Names are intention-revealing (no `d`, `temp`, `data2`)
- [ ] Functions do one thing and are small (< 25 lines)
- [ ] Single level of abstraction per function
- [ ] Comments explain "why", not "what"
- [ ] No commented-out code (use git history)
- [ ] No null parameters or return values where avoidable
- [ ] DRY - no duplicate logic
- [ ] Boy Scout Rule applied (left code cleaner)

### XP Practices
- [ ] Tests written first or alongside code (TDD)
- [ ] FIRST principles: Fast, Independent, Repeatable, Self-validating, Timely
- [ ] Simple design (passes tests, reveals intention, no duplication, minimal)
- [ ] YAGNI - no speculative features
- [ ] Refactoring done in small, tested steps

### Architecture
- [ ] Clean architecture layers respected
- [ ] Feature-first organization
- [ ] Dependency rule followed (inner layers don't depend on outer)

---

## Quick Reference Checklists

### Dart/Flutter
1. Null-safe code (no `dynamic` unless necessary)
2. `async`/`await`, not `.then()` chains
3. Use `late` sparingly
4. `const` constructors wherever possible

### Riverpod
1. `@riverpod` annotation for all providers
2. `ref.watch()` for reads, `ref.read()` for mutations
3. `ref.invalidate()` after mutations
4. AsyncValue for all async operations

### drift
1. snake_case for SQL (tables, columns)
2. Transactions for all writes
3. UTC DateTime storage
4. `watch()` queries for reactive streams

### freezed
1. `@freezed` for all entities/DTOs
2. `copyWith` for updates
3. Include `fromJson`/`toJson` for Firestore
4. Generated files not committed

### Testing
1. Mirror lib/ structure in test/
2. mocktail for mocking (not mockito)
3. ProviderContainer for Riverpod tests
4. In-memory database for drift tests
5. Arrange-Act-Assert pattern

### Clean Code (Robert Martin)
1. Intention-revealing names
2. Functions do ONE thing (< 25 lines)
3. Single level of abstraction (SLAP)
4. Command-Query Separation
5. Comments explain WHY, not WHAT
6. No null params/returns where avoidable
7. Fail fast - validate at boundaries
8. DRY - Rule of Three before extracting
9. Boy Scout Rule - leave cleaner

### XP Practices
1. TDD: Red -> Green -> Refactor
2. FIRST tests: Fast, Independent, Repeatable, Self-validating, Timely
3. Simple Design: Tests pass, reveals intent, no duplication, minimal
4. YAGNI: Build for now, not hypotheticals
5. Continuous Integration: Commit daily, green builds
6. Refactor continuously in small steps

---

## Edge Cases to Handle

### Empty States
- Empty Mishna list (first launch before sync)
- Zero completions (new user)
- No tracks configured (onboarding incomplete)

### Hebrew Text
- RTL layout with Directionality widget
- Mixed Hebrew/English BiDi handling
- Nikud (vowel points) rendering
- Hebrew dates via kosher_dart (not manual)

### Offline-First
- App starts offline (Firestore unavailable)
- Sync interrupted (resumable checkpoints)
- Sefaria API down (use cached text)

### Multi-Track
- Same Mishna cannot be in multiple tracks
- Personal track cannot be deleted
- Track deletion handles orphaned bookmarks
