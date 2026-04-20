# Learning Tracker — Testing Quick Reference

**Last Updated:** 2026-02-08
**Related:** [Architecture Quick Reference](architecture-quick-reference.md) | [Project Context](../../_bmad/bmm/data/project-context-template.md)

---

## Testing Philosophy

**TDD First:** Write failing test → implement → refactor
**Coverage Targets:**
- `lib/core/`: ≥80% (critical infrastructure)
- `lib/features/*/domain/`: ≥80% (business logic)
- `lib/features/*/data/`: ≥70% (repository implementations)
- `lib/features/*/presentation/`: ≥60% (UI logic)

**CI Requirements:**
- All tests must pass before merge
- Coverage must not decrease
- Integration tests run on every PR

---

## Test Pyramid

```
        ┌─────────────┐
        │     E2E     │  (10% — Critical user flows)
        │  5-10 tests │
        └─────────────┘
       ┌───────────────┐
       │  Integration  │  (20% — Feature flows)
       │  20-30 tests  │
       └───────────────┘
      ┌─────────────────┐
      │   Widget Tests  │  (30% — UI components)
      │   50-75 tests   │
      └─────────────────┘
     ┌───────────────────┐
     │    Unit Tests     │  (40% — Business logic)
     │   100+ tests      │
     └───────────────────┘
```

---

## Unit Tests

### Testing Domain Models (@freezed)

**File:** `test/features/learning/domain/models/completion_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/models/completion.dart';

void main() {
  group('Completion', () {
    test('creates instance with required fields', () {
      final completion = Completion(
        id: 'test-id',
        curriculumId: CurriculumId.mishnayos,
        contentItemId: 'item-123',
        stageDefinitionId: 'stage-1',
        trackType: TrackType.personal,
        completedAt: DateTime.utc(2026, 1, 1),
        points: 10,
      );

      expect(completion.id, 'test-id');
      expect(completion.curriculumId, CurriculumId.mishnayos);
      expect(completion.points, 10);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Completion(...);
      final updated = original.copyWith(points: 20);

      expect(updated.points, 20);
      expect(updated.id, original.id); // Other fields unchanged
    });

    test('equality works correctly', () {
      final completion1 = Completion(id: 'same', ...);
      final completion2 = Completion(id: 'same', ...);
      final completion3 = Completion(id: 'different', ...);

      expect(completion1, completion2);
      expect(completion1, isNot(completion3));
    });
  });
}
```

### Testing Repositories (with Mocks)

**File:** `test/features/learning/data/repositories/completion_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';

@GenerateMocks([CompletionDao])
import 'completion_repository_test.mocks.dart';

void main() {
  late MockCompletionDao mockDao;
  late CompletionRepositoryImpl repository;

  setUp(() {
    mockDao = MockCompletionDao();
    repository = CompletionRepositoryImpl(dao: mockDao);
  });

  group('CompletionRepository', () {
    test('getCompletionById returns completion when found', () async {
      final expectedCompletion = Completion(id: 'test-123', ...);
      when(mockDao.getCompletionById('test-123'))
          .thenAnswer((_) async => expectedCompletion);

      final result = await repository.getCompletionById('test-123');

      expect(result, expectedCompletion);
      verify(mockDao.getCompletionById('test-123')).called(1);
    });

    test('getCompletionById returns null when not found (P2 nullable pattern)', () async {
      when(mockDao.getCompletionById('nonexistent'))
          .thenAnswer((_) async => null);

      final result = await repository.getCompletionById('nonexistent');

      expect(result, isNull);
    });

    test('createCompletion returns new completion with generated ID', () async {
      final newCompletion = Completion(id: 'generated-id', ...);
      when(mockDao.insertCompletion(any))
          .thenAnswer((_) async => newCompletion);

      final result = await repository.createCompletion(
        curriculumId: CurriculumId.mishnayos,
        contentItemId: 'item-123',
        stageDefinitionId: 'stage-1',
        trackType: TrackType.personal,
        points: 10,
      );

      expect(result.id, 'generated-id');
      verify(mockDao.insertCompletion(any)).called(1);
    });
  });
}
```

### Testing Services (Business Logic)

**File:** `test/features/scheduler/domain/services/scheduler_engine_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

@GenerateMocks([ContentRepository, CompletionRepository, StageRepository])
import 'scheduler_engine_test.mocks.dart';

void main() {
  late MockContentRepository mockContentRepo;
  late MockCompletionRepository mockCompletionRepo;
  late MockStageRepository mockStageRepo;
  late SchedulerEngine engine;

  setUp(() {
    mockContentRepo = MockContentRepository();
    mockCompletionRepo = MockCompletionRepository();
    mockStageRepo = MockStageRepository();
    engine = SchedulerEngine(
      contentRepo: mockContentRepo,
      completionRepo: mockCompletionRepo,
      stageRepo: mockStageRepo,
    );
  });

  group('SchedulerEngine', () {
    test('calculates correct daily task count when on pace', () async {
      // Setup: 100 items total, 50 completed, 50 days to goal, 50 days elapsed
      when(mockContentRepo.getLeafItemsForCurriculum(CurriculumId.mishnayos))
          .thenAnswer((_) async => List.generate(100, (i) => ContentItem(...)));
      when(mockCompletionRepo.getCompletionsForCurriculum(CurriculumId.mishnayos))
          .thenAnswer((_) async => List.generate(50, (i) => Completion(...)));

      final tasks = await engine.calculateDailyTasks(
        curriculumId: CurriculumId.mishnayos,
        goalDeadline: DateTime.now().add(Duration(days: 50)),
      );

      // Expected: 1 item per day (50 items / 50 days)
      expect(tasks.length, 1);
    });

    test('increases daily load when behind pace', () async {
      // Setup: 100 items total, 20 completed, 20 days to goal, 80 days elapsed (behind!)
      when(mockContentRepo.getLeafItemsForCurriculum(CurriculumId.mishnayos))
          .thenAnswer((_) async => List.generate(100, (i) => ContentItem(...)));
      when(mockCompletionRepo.getCompletionsForCurriculum(CurriculumId.mishnayos))
          .thenAnswer((_) async => List.generate(20, (i) => Completion(...)));

      final tasks = await engine.calculateDailyTasks(
        curriculumId: CurriculumId.mishnayos,
        goalDeadline: DateTime.now().add(Duration(days: 20)),
      );

      // Expected: 4 items per day (80 items / 20 days)
      expect(tasks.length, 4);
    });

    test('prioritizes overdue chazara over new learning', () async {
      // Setup: item completed 10 days ago, chazara due after 7 days (3 days overdue)
      final overdueItem = ContentItem(id: 'overdue', ...);
      final overdueCompletion = Completion(
        contentItemId: 'overdue',
        completedAt: DateTime.now().subtract(Duration(days: 10)),
        stageDefinitionId: 'learn',
        ...
      );
      final chazaraStage = StageDefinition(
        id: 'chazara-1',
        stageOrder: 2,
        delayDays: 7,
        ...
      );

      when(mockContentRepo.getContentItemById('overdue'))
          .thenAnswer((_) async => overdueItem);
      when(mockCompletionRepo.getCompletionsForContentItem('overdue'))
          .thenAnswer((_) async => [overdueCompletion]);
      when(mockStageRepo.getNextStageForItem('overdue'))
          .thenAnswer((_) async => chazaraStage);

      final tasks = await engine.calculateDailyTasks(
        curriculumId: CurriculumId.mishnayos,
        goalDeadline: DateTime.now().add(Duration(days: 100)),
      );

      // First task should be overdue chazara, marked as overdue
      expect(tasks.first.contentItemId, 'overdue');
      expect(tasks.first.isOverdue, true);
      expect(tasks.first.stage.id, 'chazara-1');
    });
  });
}
```

---

## Widget Tests

### Testing Stateless Widgets

**File:** `test/features/dashboard/presentation/widgets/curriculum_card_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/curriculum_card.dart';

void main() {
  Widget createWidgetUnderTest({required CurriculumSummary summary}) {
    return MaterialApp(
      home: Scaffold(
        body: CurriculumCard(summary: summary),
      ),
    );
  }

  group('CurriculumCard', () {
    testWidgets('displays curriculum name and completion percentage', (tester) async {
      final summary = CurriculumSummary(
        curriculumId: CurriculumId.mishnayos,
        name: 'Mishnayos',
        completedItems: 1890,
        totalItems: 4192,
        completionPercentage: 45.0,
      );

      await tester.pumpWidget(createWidgetUnderTest(summary: summary));

      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('1,890 / 4,192 items'), findsOneWidget);
    });

    testWidgets('shows green pace indicator when ahead', (tester) async {
      final summary = CurriculumSummary(
        ...,
        paceStatus: PaceStatus.ahead,
        daysAheadOrBehind: 23,
      );

      await tester.pumpWidget(createWidgetUnderTest(summary: summary));

      expect(find.text('23 days ahead'), findsOneWidget);

      // Find the pace indicator widget and verify color
      final paceIndicator = tester.widget<Container>(
        find.byKey(Key('pace-indicator'))
      );
      expect((paceIndicator.decoration as BoxDecoration).color, Colors.green);
    });

    testWidgets('taps card to navigate to curriculum detail', (tester) async {
      bool navigated = false;
      final summary = CurriculumSummary(...);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => GestureDetector(
              onTap: () => navigated = true,
              child: CurriculumCard(summary: summary),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CurriculumCard));
      await tester.pump();

      expect(navigated, true);
    });
  });
}
```

### Testing Stateful Widgets (with Riverpod)

**File:** `test/features/learning/presentation/screens/mark_completion_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:learning_tracker/features/learning/presentation/screens/mark_completion_screen.dart';

@GenerateMocks([CompletionRepository])
import 'mark_completion_screen_test.mocks.dart';

void main() {
  late MockCompletionRepository mockRepo;

  setUp(() {
    mockRepo = MockCompletionRepository();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        completionRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: MarkCompletionScreen(
          contentItem: ContentItem(id: 'item-123', name: 'Berachos 1:1', ...),
        ),
      ),
    );
  }

  group('MarkCompletionScreen', () {
    testWidgets('shows loading indicator during submission', (tester) async {
      when(mockRepo.createCompletion(any))
          .thenAnswer((_) async => Future.delayed(Duration(seconds: 2)));

      await tester.pumpWidget(createWidgetUnderTest());

      // Tap "Mark Complete" button
      await tester.tap(find.text('Mark Complete'));
      await tester.pump(); // Start async operation

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows success message after completion', (tester) async {
      when(mockRepo.createCompletion(any))
          .thenAnswer((_) async => Completion(id: 'new-123', ...));

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Mark Complete'));
      await tester.pump(); // Start async
      await tester.pumpAndSettle(); // Wait for completion

      expect(find.text('Great job!'), findsOneWidget);
      expect(find.text('+10 pts'), findsOneWidget);
    });

    testWidgets('shows error message on failure', (tester) async {
      when(mockRepo.createCompletion(any))
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Mark Complete'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Failed to mark completion'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
```

---

## Integration Tests

### Testing Complete Flows

**File:** `integration_test/learning_flow_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Learning Flow (E2E)', () {
    testWidgets('user can mark item complete and see it in history', (tester) async {
      // 1. Launch app
      app.main();
      await tester.pumpAndSettle();

      // 2. Sign in (assumes test user exists)
      await tester.enterText(find.byKey(Key('email-field')), 'test@example.com');
      await tester.enterText(find.byKey(Key('password-field')), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // 3. Navigate to Mishnayos curriculum
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      // 4. Expand Seder Zeraim
      await tester.tap(find.text('Seder Zeraim'));
      await tester.pumpAndSettle();

      // 5. Expand Berachos
      await tester.tap(find.text('Berachos'));
      await tester.pumpAndSettle();

      // 6. Tap on Berachos 1:1
      await tester.tap(find.text('Berachos 1:1'));
      await tester.pumpAndSettle();

      // 7. Mark as complete
      await tester.tap(find.text('Mark Complete'));
      await tester.pumpAndSettle();

      // 8. Verify success message
      expect(find.text('Great job!'), findsOneWidget);

      // 9. Navigate to completion history
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // 10. Verify item appears in history
      expect(find.text('Berachos 1:1'), findsOneWidget);
      expect(find.text('Learn'), findsOneWidget); // Stage
      expect(find.text('Personal'), findsOneWidget); // Track
    });

    testWidgets('marking same item twice shows error', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Sign in, navigate to item, mark complete (same as above)
      // ...

      // Try to mark the same item again
      await tester.tap(find.text('Mark Complete'));
      await tester.pumpAndSettle();

      // Should show duplicate error
      expect(find.text('This item is already completed for this stage'), findsOneWidget);
    });
  });

  group('Sync Flow (E2E)', () {
    testWidgets('completion syncs to Firestore', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Mark item complete
      // ...

      // Wait for sync indicator to show "Synced"
      await tester.pumpAndSettle(Duration(seconds: 3));
      expect(find.text('✓ Synced'), findsOneWidget);

      // TODO: Verify Firestore document exists (requires Firestore emulator)
    });
  });
}
```

---

## Database Tests (Drift)

### Testing DAOs

**File:** `test/core/database/daos/completion_dao_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase database;
  late CompletionDao dao;

  setUp(() {
    // Create in-memory database for testing
    database = AppDatabase(NativeDatabase.memory());
    dao = database.completionDao;
  });

  tearDown(() async {
    await database.close();
  });

  group('CompletionDao', () {
    test('insertCompletion adds new record', () async {
      final completion = CompletionsCompanion.insert(
        curriculumId: 'mishnayos',
        contentItemId: 'item-123',
        stageDefinitionId: 'stage-1',
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 1, 1),
        points: 10,
      );

      final id = await dao.insertCompletion(completion);

      expect(id, isNotNull);
      expect(id, isNot(0));
    });

    test('getCompletionById returns correct record', () async {
      final id = await dao.insertCompletion(CompletionsCompanion.insert(...));

      final result = await dao.getCompletionById(id);

      expect(result, isNotNull);
      expect(result!.id, id);
    });

    test('getCompletionsForCurriculum filters by curriculum_id', () async {
      await dao.insertCompletion(CompletionsCompanion.insert(curriculumId: 'mishnayos', ...));
      await dao.insertCompletion(CompletionsCompanion.insert(curriculumId: 'mishnayos', ...));
      await dao.insertCompletion(CompletionsCompanion.insert(curriculumId: 'bavli', ...));

      final mishnayosCompletions = await dao.getCompletionsForCurriculum('mishnayos');

      expect(mishnayosCompletions.length, 2);
      expect(mishnayosCompletions.every((c) => c.curriculumId == 'mishnayos'), true);
    });

    test('UNIQUE constraint prevents duplicate completions', () async {
      final completion = CompletionsCompanion.insert(
        curriculumId: 'mishnayos',
        contentItemId: 'item-123',
        stageDefinitionId: 'stage-1',
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 1, 1),
        points: 10,
      );

      await dao.insertCompletion(completion);

      // Try to insert same completion again
      expect(
        () => dao.insertCompletion(completion),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
```

---

## API Tests (Sefaria)

### Testing Adapters

**File:** `test/features/content/data/adapters/mishnayos_adapter_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:learning_tracker/features/content/data/adapters/mishnayos_adapter.dart';

@GenerateMocks([http.Client])
import 'mishnayos_adapter_test.mocks.dart';

void main() {
  late MockClient mockClient;
  late MishnayosAdapter adapter;

  setUp(() {
    mockClient = MockClient();
    adapter = MishnayosAdapter(client: mockClient);
  });

  group('MishnayosAdapter', () {
    test('fetchIndex returns parsed hierarchy', () async {
      // Mock API response
      when(mockClient.get(Uri.parse('https://www.sefaria.org/api/index/Mishnah')))
          .thenAnswer((_) async => http.Response('''
            {
              "contents": [
                {
                  "category": "Seder Zeraim",
                  "contents": [
                    {"title": "Berakhot", "heTitle": "ברכות"}
                  ]
                }
              ]
            }
          ''', 200));

      final result = await adapter.fetchIndex();

      expect(result.length, greaterThan(0));
      expect(result.first.level1, 'Seder Zeraim');
      expect(result.first.level2, 'Berakhot');
    });

    test('fetchIndex throws on API error', () async {
      when(mockClient.get(any))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      expect(
        () => adapter.fetchIndex(),
        throwsA(isA<ApiException>()),
      );
    });

    test('mapToContentItems creates correct hierarchy', () async {
      final sefariaData = {
        'contents': [
          {
            'category': 'Seder Zeraim',
            'contents': [
              {
                'title': 'Berakhot',
                'heTitle': 'ברכות',
                'contents': [
                  {
                    'title': 'Chapter 1',
                    'heTitle': 'פרק א',
                    'contents': ['1:1', '1:2', '1:3']
                  }
                ]
              }
            ]
          }
        ]
      };

      final items = adapter.mapToContentItems(sefariaData);

      // Should have: 1 seder + 1 masechta + 1 perek + 3 mishnayos = 6 items
      expect(items.length, 6);

      // Check seder
      final seder = items.firstWhere((i) => i.level1 == 'Seder Zeraim' && i.level2 == null);
      expect(seder.isLeaf, false);

      // Check leaf mishna
      final mishna = items.firstWhere((i) => i.level4 == '1:1');
      expect(mishna.isLeaf, true);
      expect(mishna.level1, 'Seder Zeraim');
      expect(mishna.level2, 'Berakhot');
      expect(mishna.level3, 'Chapter 1');
      expect(mishna.level4, '1:1');
    });
  });
}
```

---

## Performance Tests

### Testing Scheduler Performance

**File:** `test/features/scheduler/domain/services/scheduler_performance_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

void main() {
  group('Scheduler Performance', () {
    test('calculates daily tasks for 5,000 items in <500ms', () async {
      // Setup: Large dataset (Chumash = 5,845 verses)
      final largeContentSet = List.generate(
        5000,
        (i) => ContentItem(id: 'item-$i', ...),
      );
      final completions = List.generate(
        2000,
        (i) => Completion(contentItemId: 'item-$i', ...),
      );

      final engine = SchedulerEngine(...);

      final stopwatch = Stopwatch()..start();

      final tasks = await engine.calculateDailyTasks(
        curriculumId: CurriculumId.chumash,
        goalDeadline: DateTime.now().add(Duration(days: 365)),
      );

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(tasks, isNotEmpty);
    });

    test('dashboard aggregation for 10k completions in <200ms', () async {
      final completions = List.generate(
        10000,
        (i) => Completion(id: 'c-$i', ...),
      );

      final aggregator = CrossCurriculumAggregator(...);

      final stopwatch = Stopwatch()..start();

      final summary = await aggregator.getDashboardSummary();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
  });
}
```

---

## Testing Checklist

### For Each Epic

- [ ] **Unit Tests**
  - [ ] All domain models tested (@freezed equality, copyWith)
  - [ ] All repositories tested (mocked DAOs/APIs)
  - [ ] All services tested (business logic isolated)
  - [ ] All adapters tested (Sefaria API mapping)

- [ ] **Widget Tests**
  - [ ] All screens tested (initial state, loading, success, error)
  - [ ] All reusable widgets tested (props, interactions)
  - [ ] All Riverpod providers tested (with overrides)

- [ ] **Integration Tests**
  - [ ] Happy path flow (sign in → action → verify)
  - [ ] Error path flow (network failure, validation errors)
  - [ ] Edge cases (empty states, boundary conditions)

- [ ] **Database Tests**
  - [ ] All DAOs tested (CRUD operations)
  - [ ] Constraints tested (UNIQUE, FK violations)
  - [ ] Queries tested (filters, joins, ordering)

- [ ] **CI Passing**
  - [ ] All tests pass on CI
  - [ ] Coverage meets targets
  - [ ] No flaky tests

---

## Common Test Utilities

### Test Data Builders

**File:** `test/helpers/test_data_builders.dart`

```dart
class ContentItemBuilder {
  String id = 'default-id';
  CurriculumId curriculumId = CurriculumId.mishnayos;
  String? level1, level2, level3, level4;
  String displayNameEn = 'Default Item';
  String displayNameHe = 'ברירת מחדל';
  bool isLeaf = true;

  ContentItemBuilder withId(String id) {
    this.id = id;
    return this;
  }

  ContentItemBuilder withCurriculum(CurriculumId curriculumId) {
    this.curriculumId = curriculumId;
    return this;
  }

  ContentItemBuilder asMishna(String seder, String masechta, String perek, String mishna) {
    this.level1 = seder;
    this.level2 = masechta;
    this.level3 = perek;
    this.level4 = mishna;
    this.isLeaf = true;
    return this;
  }

  ContentItem build() {
    return ContentItem(
      id: id,
      curriculumId: curriculumId,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameEn: displayNameEn,
      displayNameHe: displayNameHe,
      sefariaRef: 'Mishnah $level2 $level3:$level4',
      sortOrder: 0,
      isLeaf: isLeaf,
    );
  }
}

// Usage in tests:
final mishna = ContentItemBuilder()
  .withId('test-123')
  .asMishna('Seder Zeraim', 'Berachos', '1', '1')
  .build();
```

---

## Mock Data

### Firebase Mock (for Integration Tests)

```bash
# Install Firebase emulator
npm install -g firebase-tools

# Start emulators
firebase emulators:start --only auth,firestore

# In test setup:
FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

### Sefaria API Mock (HTTP Interceptor)

**File:** `test/helpers/sefaria_mock_server.dart`

```dart
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

class SefariaMockServer {
  static void setupMocks(MockClient client) {
    when(client.get(Uri.parse('https://www.sefaria.org/api/index/Mishnah')))
        .thenAnswer((_) async => http.Response(_mishnayosIndexJson, 200));
  }

  static const _mishnayosIndexJson = '''
    {
      "contents": [
        {
          "category": "Seder Zeraim",
          "contents": [
            {"title": "Berakhot", "heTitle": "ברכות"}
          ]
        }
      ]
    }
  ''';
}
```

---

**Questions?** Check [Project Context](../../_bmad/bmm/data/project-context-template.md) for full coding standards including testing requirements.
