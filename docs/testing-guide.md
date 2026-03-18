---
title: "Testing Guide"
description: "Comprehensive guide to writing, running, and maintaining tests in Learning Tracker"
date: 2026-03-18
---

# Testing Guide

## Table of Contents

- [Test Architecture](#test-architecture)
- [Test Organization](#test-organization)
- [How to Run Tests](#how-to-run-tests)
- [How to Write a Unit Test](#how-to-write-a-unit-test)
- [How to Write a Widget Test](#how-to-write-a-widget-test)
- [How to Write a Story Acceptance Test](#how-to-write-a-story-acceptance-test)
- [How to Write an Integration Test](#how-to-write-an-integration-test)
- [Test Infrastructure Details](#test-infrastructure-details)
- [Known Gotchas](#known-gotchas)

## Test Architecture

The project maintains 531+ tests across 167 files, structured as a test pyramid.

### Test Pyramid

| Layer       | Share | Purpose                                      |
|-------------|-------|----------------------------------------------|
| Unit        | 40%   | Verify individual functions, DAOs, services  |
| Widget      | 30%   | Validate UI rendering, interactions, themes  |
| Integration | 20%   | Confirm cross-service and cross-feature flows |
| E2E         | 10%   | Exercise full user journeys end-to-end       |

### Coverage Targets

| Layer        | Minimum Coverage |
|--------------|-----------------|
| core         | 80%             |
| domain       | 80%             |
| data         | 70%             |
| presentation | 60%             |

## Test Organization

### Directory Structure

Tests mirror the `lib/` source tree:

```text
test/
├── core/                       # Core module unit + widget tests
│   └── widgets/                # Widget tests for shared components
├── features/                   # Feature-level tests mirror lib/features/
│   ├── gamification/
│   ├── learning/
│   └── ...
├── story_acceptance/           # 15 files, 401 acceptance tests
│   ├── epic_01_foundation_test.dart
│   ├── epic_02_content_test.dart
│   └── ...epic_15_multi_profile_test.dart
├── fixtures/                   # Reusable test data factories
│   ├── content_fixtures.dart   # ContentItemFixtures
│   └── curriculum_fixtures.dart # CurriculumFixtures, StageFixtures, TrackTypeFixtures
├── helpers/                    # Shared test utilities
│   └── test_database.dart      # createTestDatabase (NativeDatabase.memory())
└── mocks/                      # Shared mocks (mocktail)
    ├── mock_repositories.dart  # MockAuthRepository, MockContentRepository
    └── mock_services.dart      # MockConnectivityService
```

### Story Acceptance Tests

Each epic has one file in `test/story_acceptance/`. Tags at the file level (`@Tags(['epic_N'])`) and group level (`tags: ['story_N_M']`) enable precise filtering. The `dart_test.yaml` file registers all tags (14 epic tags, 62 story tags) to prevent "unknown tag" warnings.

## How to Run Tests

### Make Targets

```bash
make test-story-X.Y        # Single story (e.g., make test-story-1.2)
make test-epic-N            # All stories in an epic (e.g., make test-epic-1)
make test-all-stories       # Full acceptance suite
make ci                     # analyze + format + all stories
```

### Flutter Test Commands

```bash
flutter test                # All unit + widget tests
flutter test test/path      # Specific test file
flutter test --tags story_1_2  # Tests matching a tag
```

### Recommended Workflow

1. Run `make test-story-X.Y` for the story under development. Fix until green.
2. Run `make test-epic-N` to confirm sibling stories still pass.
3. Run `make ci` (analyze + format + all stories) before committing.

## How to Write a Unit Test

Use the in-memory database pattern for fast, isolated tests with no disk I/O.

```dart
import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper: insert a completion record
  Future<int> insertCompletion({
    String ref = 'Mishnah Berachos 1.1',
    int stageId = 1,
    int points = 10,
  }) {
    return db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: ref,
        stageId: stageId,
        trackType: TrackType.personal.storageKey,
        completedAt: DateTime.now(),
        points: Value(points),
      ),
    );
  }

  group('CompletionDao', () {
    test('inserts and retrieves a completion', () async {
      // Arrange
      final id = await insertCompletion();

      // Act
      final all = await db.completionDao.getAllCompletions();

      // Assert
      expect(id, greaterThan(0));
      expect(all, hasLength(1));
    });

    test('returns empty list when no completions exist', () async {
      // Act
      final all = await db.completionDao.getAllCompletions();

      // Assert
      expect(all, isEmpty);
    });
  });
}
```

### Key Points

- Call `createTestDatabase()` in `setUp` to get a fresh in-memory Drift database.
- Always call `db.close()` in `tearDown` to release resources.
- Extract helper functions for repetitive insertions.
- Follow Arrange-Act-Assert in every test body.
- Use `mocktail` (not `mockito`) for all mocking:

```dart
import 'package:mocktail/mocktail.dart';

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  late MockContentRepository mockRepo;

  setUp(() {
    mockRepo = MockContentRepository();
  });

  test('returns content items', () async {
    // Arrange
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);

    // Act
    final result = await mockRepo.getAll();

    // Assert
    expect(result, isEmpty);
    verify(() => mockRepo.getAll()).called(1);
  });
}
```

## How to Write a Widget Test

Wrap the widget under test in `MaterialApp` and use `find` APIs to locate elements.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';

void main() {
  /// Helper: build the widget inside a MaterialApp shell
  Widget buildWidget({
    required int currentStreak,
    required int maxStreak,
    required UserMode userMode,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StreakWidget(
          currentStreak: currentStreak,
          maxStreak: maxStreak,
          userMode: userMode,
        ),
      ),
    );
  }

  group('StreakWidget', () {
    testWidgets('displays current and max streak', (tester) async {
      await tester.pumpWidget(
        buildWidget(currentStreak: 5, maxStreak: 10, userMode: UserMode.child),
      );

      expect(find.text('5 day streak!'), findsOneWidget);
      expect(find.text('Best: 10 days'), findsOneWidget);
    });

    testWidgets('shows Card in child mode', (tester) async {
      await tester.pumpWidget(
        buildWidget(currentStreak: 3, maxStreak: 7, userMode: UserMode.child),
      );
      await tester.pumpAndSettle(); // Wait for animations

      expect(find.byType(Card), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });
  });
}
```

### Testing with Riverpod Providers

Wrap the widget in a `ProviderScope` to override providers during testing:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

testWidgets('uses overridden provider value', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        someProvider.overrideWithValue(AsyncValue.data(mockData)),
      ],
      child: const MaterialApp(home: MyScreen()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Expected text'), findsOneWidget);
});
```

### Key Points

- Always wrap widgets in `MaterialApp` (and `Scaffold` if needed for Material ancestors).
- Call `tester.pumpAndSettle()` after actions that trigger animations or async rebuilds.
- Use `find.text()`, `find.byType()`, `find.byIcon()`, and `find.byKey()` to locate elements.
- Use `ProviderScope` with `overrides` for Riverpod provider testing.

## How to Write a Story Acceptance Test

Story acceptance tests live in `test/story_acceptance/epic_NN_*_test.dart`. Each file covers one epic.

### File-Level Tag

Add the `@Tags` annotation before the `library` directive:

```dart
/// Story acceptance tests for Epic 3 -- Learning Cycle.
@Tags(['epic_3'])
library;
```

### Group-Level Tags

Tag each story group:

```dart
void main() {
  group('Story 3.1 -- Mark a unit complete', tags: ['story_3_1'], () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('inserting a completion persists to the database', () async {
      final id = await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          trackType: TrackType.personal.storageKey,
          completedAt: DateTime.now(),
          points: const Value(10),
        ),
      );
      expect(id, greaterThan(0));
    });
  });
}
```

### Activating a Backlog Test

Backlog stories have a `skip:` parameter on their `group()`. To activate a story after implementation:

1. Remove the `skip:` parameter from the group.
2. Replace empty `() {}` test bodies with real assertions.
3. Run `make test-story-X.Y` to confirm the tests pass.

```dart
// Before (backlog):
group('Story 6.5 -- Smart scheduling', tags: ['story_6_5'], skip: 'Backlog', () {
  test('placeholder', () {});
});

// After (activated):
group('Story 6.5 -- Smart scheduling', tags: ['story_6_5'], () {
  test('calculates next review date from last completion', () async {
    // Real assertions here
  });
});
```

## How to Write an Integration Test

Integration tests verify interactions across multiple services or features using real database instances.

### When to Use Fakes vs Mocks

| Approach | Use When                                                    |
|----------|-------------------------------------------------------------|
| Mock     | Testing a single unit in isolation; verifying call patterns |
| Fake     | Testing cross-service logic with simplified implementations |
| Real DB  | Testing DAO interactions, query correctness, transactions   |

### Cross-Service Testing Pattern

```dart
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Completion + Streak integration', () {
    test('completing a unit updates the streak record', () async {
      // Insert a completion via CompletionDao
      await db.completionDao.insertCompletion(/* ... */);

      // Verify the streak was updated via StreakDao
      final streak = await db.streakDao.getCurrentStreak();
      expect(streak, isNotNull);
    });
  });
}
```

### Cross-Feature Interactions

Test scenarios where Feature A triggers behavior in Feature B:

- Completion in the learning feature triggers point calculation in the gamification feature.
- Onboarding curriculum selection populates the content browsing feature.
- Settings changes propagate to all dependent features.

Use a real in-memory database for these tests. Mock only external services (network, platform channels).

## Test Infrastructure Details

### In-Memory Drift Databases

All database tests use `NativeDatabase.memory()` via the `createTestDatabase()` helper:

- Fast execution with no disk I/O.
- Each test gets a fresh, isolated database instance.
- Full schema creation runs on every `setUp`, ensuring tests match the current schema.

```dart
// test/helpers/test_database.dart
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
```

### Mocktail for Null-Safe Mocking

The project uses `mocktail` (not `mockito`) for null-safe mocking without codegen:

```dart
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockContentRepository extends Mock implements ContentRepository {}
class MockConnectivityService extends Mock implements ConnectivityService {}
```

### Registering Fallback Values

For methods that accept complex types, register fallback values in `setUpAll`:

```dart
setUpAll(() {
  registerFallbackValue(CompletionsCompanion.insert(
    curriculumId: '',
    sefariaRef: '',
    stageId: 0,
    trackType: '',
    completedAt: DateTime(2020),
  ));
});
```

This prevents `MissingStubError` when mocktail verifies argument matchers like `any()`.

### Test Tags and Filtering

Tags enable selective test execution:

- **Epic tags**: `@Tags(['epic_1'])` at the file level.
- **Story tags**: `tags: ['story_1_2']` on individual groups.
- **Tag registration**: `dart_test.yaml` registers all 14 epic tags and 62 story tags.

Run tagged tests with:

```bash
flutter test --tags story_1_2    # Single story
flutter test --tags epic_1       # Entire epic
```

### Test Fixtures

Reusable factory classes provide consistent test data:

- **ContentItemFixtures**: Creates test `ContentItem` instances (mishna, daf) with sensible defaults.
- **CurriculumFixtures**: Provides `CurriculumId` values, storage keys, and lookup methods.
- **StageFixtures**: Defines stage IDs, names, and delay constants.
- **TrackTypeFixtures**: Provides track type string constants.

```dart
import '../fixtures/content_fixtures.dart';
import '../fixtures/curriculum_fixtures.dart';

final item = ContentItemFixtures.mishna(level3: '2', level4: '3');
final curriculum = CurriculumFixtures.defaultCurriculum;
final stageId = StageFixtures.learnStageId;
```

### Batch Insert Helper

For tests that need multiple records, use the `batchInsert` helper to wrap insertions in a transaction:

```dart
import '../helpers/test_database.dart';

await batchInsert(db, db.completions, [
  CompletionsCompanion.insert(/* ... */),
  CompletionsCompanion.insert(/* ... */),
]);
```

## Known Gotchas

### progress_providers.g.dart Is Manually Authored

The generated file `progress_providers.g.dart` is manually maintained because the Riverpod code generator does not handle `Map<K, V>` return types correctly. Do not delete or regenerate this file with `build_runner`.

### Regenerate After Model Changes

After modifying Drift tables, Freezed models, or Riverpod providers, regenerate generated files before running tests:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Failing to regenerate causes compile errors in tests that depend on generated code.

### registerFallbackValue in setUpAll

Some tests require `registerFallbackValue` calls in `setUpAll` for complex types used with `any()` matchers. If a test fails with `MissingStubError` or a type mismatch on `any()`, add the appropriate fallback registration.

### Tag Registration

All test tags must be registered in `dart_test.yaml`. Adding a new epic or story tag without registering it produces "unknown tag" warnings and may cause CI failures.
