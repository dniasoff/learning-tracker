---
title: "Testing Guide"
description: "Comprehensive guide to writing, running, and maintaining tests in Learning Tracker"
date: 2026-07-13
---

# Testing Guide

> **For a current overview of all test *layers/options* (what each covers, how to
> run it, what it does NOT cover), see [test-options.md](test-options.md).** This
> guide focuses on *how to write* tests; some counts/sections below predate later
> layers (contract test, emulator rules, headless E2E waves, on-device driver).

## Table of Contents

- [Test Architecture](#test-architecture)
- [Test Organization](#test-organization)
- [How to Run Tests](#how-to-run-tests)
- [How to Write a Unit Test](#how-to-write-a-unit-test)
- [How to Write a Widget Test](#how-to-write-a-widget-test)
- [How to Write a Story Acceptance Test](#how-to-write-a-story-acceptance-test)
- [How to Write an Integration Test](#how-to-write-an-integration-test)
- [Test Infrastructure Details](#test-infrastructure-details)
- [Accessing On-Device Emulators (WSL2 ↔ Windows Host)](#accessing-on-device-emulators-wsl2--windows-host)
- [Known Gotchas](#known-gotchas)

## Test Architecture

The project maintains roughly 10,000 tests (`test()`/`testWidgets()` calls) across
`test/**`, structured as a test pyramid — see [test-options.md](test-options.md)
for the current authoritative count and per-layer breakdown.

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
├── story_acceptance/           # one file per epic — see dart_test.yaml for the current tag list
│   ├── epic_01_foundation_test.dart
│   ├── epic_02_content_test.dart
│   └── ...epic_27_*_test.dart
├── fixtures/                   # Reusable test data factories
│   ├── content_fixtures.dart   # ContentItemFixtures
│   └── curriculum_fixtures.dart # CurriculumFixtures, StageFixtures
├── helpers/                    # Shared test utilities
│   └── test_database.dart      # createTestDatabase -> UserDatabase (NativeDatabase.memory())
└── mocks/                      # Shared mocks (mocktail)
    ├── mock_repositories.dart  # MockAuthRepository, MockContentRepository
    └── mock_services.dart      # MockConnectivityService
```

### Story Acceptance Tests

Each epic has one file in `test/story_acceptance/`. Tags at the file level (`@Tags(['epic_N'])`) and group level (`tags: ['story_N_M']`) enable precise filtering. The `dart_test.yaml` file registers all tags (20 epic tags, 97 story tags) to prevent "unknown tag" warnings.

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
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db); // creates accounts(id=1) + learner_profiles(id=1)
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper: commit a completion via the single write path.
  Future<int> insertCompletion({
    String ref = 'Mishnah Berachos 1.1',
    int stageId = 1,
    int points = 10,
  }) async {
    final result = await CompletionWriter(db).commit(
      CompletionCommand(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: ref,
        stageId: stageId,
        trackType: 'personal',
        trackId: 1,
        completedAt: DateTime.now(),
        points: points,
      ),
    );
    return result.completion.id;
  }

  group('CompletionDao', () {
    test('inserts and retrieves a completion', () async {
      // Arrange
      final id = await insertCompletion();

      // Act
      final all = await db.completionDao.getCompletionsByProfile(1);

      // Assert
      expect(id, greaterThan(0));
      expect(all, hasLength(1));
    });

    test('returns empty list when no completions exist', () async {
      // Act
      final all = await db.completionDao.getCompletionsByProfile(1);

      // Assert
      expect(all, isEmpty);
    });
  });
}
```

### Key Points

- Call `createTestDatabase()` in `setUp` to get a fresh in-memory `UserDatabase`,
  then `await seedProfile(db)` to satisfy the `learner_profiles` foreign key that
  `completion_events` (and most other tables) require.
- Always call `db.close()` in `tearDown` to release resources.
- Write completions through `CompletionWriter.commit()` / `commitBatch()` —
  `CompletionDao`'s write methods were removed; it is read-only, backed by the
  `completions_view` Drift view over `completion_events`.
- Extract helper functions for repetitive insertions.
- Follow Arrange-Act-Assert in every test body.
- Use `mocktail` (not `mockito`) for all mocking:

```dart
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  late MockContentRepository mockRepo;

  setUp(() {
    mockRepo = MockContentRepository();
  });

  test('returns content items', () async {
    // Arrange
    when(
      () => mockRepo.getContentForCurriculum(CurriculumId.mishnayos),
    ).thenAnswer((_) async => []);

    // Act
    final result = await mockRepo.getContentForCurriculum(
      CurriculumId.mishnayos,
    );

    // Assert
    expect(result, isEmpty);
    verify(
      () => mockRepo.getContentForCurriculum(CurriculumId.mishnayos),
    ).called(1);
  });
}
```

## How to Write a Widget Test

Wrap the widget under test in `MaterialApp` and use `find` APIs to locate elements.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  /// Helper: build the widget inside a MaterialApp shell with localizations
  /// wired up (StreakWidget reads AppLocalizations.of(context)).
  Widget buildWidget({
    required int currentStreak,
    required int maxStreak,
    required ProfileMode userMode,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
        buildWidget(
          currentStreak: 5,
          maxStreak: 10,
          userMode: ProfileMode.child,
        ),
      );

      expect(find.text('5 day streak!'), findsOneWidget);
      expect(find.text('Best: 10 days'), findsOneWidget);
    });

    testWidgets('shows Card in child mode', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          currentStreak: 3,
          maxStreak: 7,
          userMode: ProfileMode.child,
        ),
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
- Wire `AppLocalizations.delegate` (plus the `Global*Localizations` delegates) into
  `MaterialApp.localizationsDelegates` whenever the widget under test reads
  `AppLocalizations.of(context)` — most screens/widgets do; omitting this throws
  at pump time, not just at the assertion.
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

Tag each story group. Imports: `UserDatabase` + `createTestDatabase`/`seedProfile`
as in the Unit Test example above, plus `CompletionWriter` and `CompletionCommand`.

```dart
void main() {
  group('Story 3.1 -- Mark a unit complete', tags: ['story_3_1'], () {
    late UserDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db); // creates accounts(id=1) + learner_profiles(id=1)
    });

    tearDown(() async {
      await db.close();
    });

    test('inserting a completion persists to the database', () async {
      final result = await CompletionWriter(db).commit(
        CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          trackType: 'personal',
          trackId: 1,
          completedAt: DateTime.now(),
          points: 10,
        ),
      );
      expect(result.completion.id, greaterThan(0));
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
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db); // creates accounts(id=1) + learner_profiles(id=1)
  });

  tearDown(() async {
    await db.close();
  });

  group('Completion + Streak integration', () {
    test('completing a unit updates the streak record', () async {
      final now = DateTime.now();

      // Insert a completion via CompletionWriter (the single write path;
      // CompletionDao's write methods were removed).
      await CompletionWriter(db).commit(
        CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          trackType: 'personal',
          trackId: 1,
          completedAt: now,
          points: 10,
        ),
      );

      // Tee a streak_events row for the same local day -- in the running app
      // this is done by CompletionRepositoryImpl's streak tee; teed directly
      // here to keep the example focused on the DAO read/write pattern.
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: 1,
          eventType: 'completion',
          dayUtc: DateTime.utc(now.year, now.month, now.day),
          eventTimestamp: now,
        ),
      );

      // Verify the streak was updated via StreakService.
      final streak = await StreakService(db, profileId: 1).getStreak();
      expect(streak.currentStreak, greaterThan(0));
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
- Most tables carry a `learner_profiles` foreign key, so call `await seedProfile(db)`
  right after `createTestDatabase()` in any test that writes completions, streaks,
  goals, etc.

```dart
// test/helpers/test_database.dart
UserDatabase createTestDatabase() {
  return UserDatabase(NativeDatabase.memory());
}
```

### Mocktail for Null-Safe Mocking

The project uses `mocktail` (not `mockito`) for null-safe mocking without codegen:

```dart
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockContentRepository extends Mock implements ContentRepository {}
// ConnectivityService was renamed to ConnectivityGateway (W5.20).
class MockConnectivityService extends Mock implements ConnectivityGateway {}
```

### Registering Fallback Values

For methods that accept complex types, register fallback values in `setUpAll`:

```dart
setUpAll(() {
  registerFallbackValue(CompletionEventsCompanion.insert(
    profileId: 0,
    curriculumId: '',
    sefariaRef: '',
    stageId: 0,
    trackType: '',
    eventTimestamp: DateTime(2020),
  ));
});
```

This prevents `MissingStubError` when mocktail verifies argument matchers like `any()`.

### Test Tags and Filtering

Tags enable selective test execution:

- **Epic tags**: `@Tags(['epic_1'])` at the file level.
- **Story tags**: `tags: ['story_1_2']` on individual groups.
- **Tag registration**: `dart_test.yaml` registers all 20 epic tags and 97 story tags.

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

await batchInsert(db, db.completionEvents, [
  CompletionEventsCompanion.insert(
    profileId: 1,
    curriculumId: CurriculumId.mishnayos.storageKey,
    sefariaRef: 'Mishnah Berachos 1.1',
    stageId: 1,
    trackType: 'personal',
    eventTimestamp: DateTime.now(),
  ),
  CompletionEventsCompanion.insert(
    profileId: 1,
    curriculumId: CurriculumId.mishnayos.storageKey,
    sefariaRef: 'Mishnah Berachos 1.2',
    stageId: 1,
    trackType: 'personal',
    eventTimestamp: DateTime.now(),
  ),
]);
```

## Accessing On-Device Emulators (WSL2 ↔ Windows Host)

> Lessons learned standing up the layer-9 on-device farm (see
> [test-options.md](test-options.md) layer 9). In this dev setup the Android
> **emulators run on the Windows host** and WSL2 drives them through the Windows
> `adb.exe` via WSL interop. The Linux `adb` server **cannot** reach the
> Windows-bound emulator ports — that is the single biggest gotcha.

### Topology

- The Android SDK is the Windows SDK surfaced into WSL: `~/Android/Sdk` is a
  symlink to `/mnt/c/Users/<user>/AppData/Local/Android/Sdk`.
- `~/Android/Sdk/platform-tools/adb` is a **shell shim** that `exec`s `adb.exe`.
  Because of it, `adb`, `flutter`, and `tool/device_e2e/driver.py` all work
  **unmodified** from WSL — each ends up talking to the Windows ADB server the
  emulators registered with on startup. Keep that shim first on `PATH`.

### The five AVDs (fixed ports → stable serials)

| AVD | Serial | Console port | Android |
|---|---|---|---|
| `lt_api28_pixel2` | `emulator-5554` | 5554 | 9 (API 28) |
| `lt_api29_pixel3` | `emulator-5556` | 5556 | 10 (API 29) |
| `lt_api31_pixel5` | `emulator-5558` | 5558 | 12 (API 31) |
| `lt_api34_pixel7` | `emulator-5560` | 5560 | 14 (API 34) |
| `lt_api36_tablet` | `emulator-5562` | 5562 | 16 (API 36) |

### Start emulators

From **Windows PowerShell** (preferred — headless, GPU host):

```powershell
.\tool\emulators-start.ps1                                         # all 5
.\tool\emulators-start.ps1 -Avds lt_api34_pixel7,lt_api36_tablet   # subset
.\tool\emulators-start.ps1 -WipeData                               # cold boot
```

Or **directly from WSL** via interop (one process per AVD; `cd /mnt/c` first to
avoid the harmless UNC-cwd warning):

```bash
cd /mnt/c
EMU=~/Android/Sdk/emulator/emulator.exe
nohup "$EMU" -avd lt_api34_pixel7 -port 5560 \
  -no-window -no-audio -no-snapshot-save -gpu host >/tmp/emu_5560.log 2>&1 &
```

`-no-window` is headless; `-no-snapshot-save` keeps installed apps but does not
persist transient user state.

### Connect, verify, wait for boot

```bash
tool/adb-connect-wsl.sh                                  # per-device status + flutter devices
adb devices                                              # uses the shim → Windows adb.exe
adb -s emulator-5560 shell getprop sys.boot_completed    # == 1 when fully booted
```

### Driving the app

- `tool/device_e2e/driver.py` works as-is. When driving **multiple devices in
  parallel**, give each its own artifact dir so screenshots don't collide:

  ```python
  Device("emulator-5560", artifact_dir="/tmp/device_e2e/5560")
  ```

- **Screenshots over interop work** — use `exec-out` (not `shell`) so the PNG
  bytes are not CRLF-mangled:

  ```bash
  adb -s emulator-5560 exec-out screencap -p > shot.png   # valid PNG
  ```

### Gotchas

- **Use the Windows adb, not the Linux one.** If `adb devices` is empty while the
  emulators are clearly up, you are talking to the wrong ADB server — put the
  shim (or `adb.exe`) first on `PATH`.
- `-no-snapshot-save` leaves each device with **whatever app state it had last
  run**, which drifts between devices. Normalize before a session with
  `adb -s <serial> shell am force-stop <pkg>` (keeps data) or `pm clear <pkg>`
  (wipes to first-run).
- `adb install -r -d <apk>` **preserves** seeded profiles/data when pushing a
  new build; a reinstall after a signing-key change wipes them.
- The fastest route to a populated app with **no cloud** is the offline account:
  `AppIntro → Signup → "Create Offline Account" → Onboarding → Dashboard`. The
  default seeded Parent PIN is `2580`.
- Cloud (Firestore) verification additionally needs the install's **App Check
  debug token** registered — see `tool/device_e2e/README.md`.

## Known Gotchas

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
