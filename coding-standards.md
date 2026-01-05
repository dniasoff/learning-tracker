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
