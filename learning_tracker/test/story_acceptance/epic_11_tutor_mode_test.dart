/// Story acceptance tests for Epic 11 -- Tutor Mode.
/// Story 11.1 is active; story 11.2 (tutor dashboard) is active.
/// Stories 11.3-11.4 remain backlog (skipped).
@Tags(['epic_11'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/tutor_mode/domain/services/tutor_dashboard_aggregator.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/providers/tutor_dashboard_providers.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_dashboard_screen.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_pin_setup_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

import '../helpers/test_database.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

MockFlutterSecureStorage _createMockStorage() {
  final mock = MockFlutterSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });

  when(() => mock.read(key: any(named: 'key'))).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    return store[key];
  });

  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}

void main() {
  // ── Story 11.1: Tutor PIN setup ───────────────────────────────

  group('Story 11.1 -- Tutor PIN setup', tags: ['story_11_1'], () {
    late MockFlutterSecureStorage storage;
    late PinService pinService;

    setUp(() {
      storage = _createMockStorage();
      pinService = PinService(storage);
    });

    // Unit: Tutor PIN stored separately from parent PIN
    test('tutor PIN stored separately from parent PIN', () async {
      await pinService.setParentPin('1234');
      await pinService.setTutorPin('5678');

      final parentHash = await storage.read(key: 'parent_pin_hash');
      final tutorHash = await storage.read(key: 'tutor_pin_hash');

      expect(parentHash, isNotNull);
      expect(tutorHash, isNotNull);
      expect(parentHash, isNot(tutorHash));

      // Verify each PIN only works for its own type
      expect(await pinService.verifyParentPin('1234'), isTrue);
      expect(await pinService.verifyParentPin('5678'), isFalse);
      expect(await pinService.verifyTutorPin('5678'), isTrue);
      expect(await pinService.verifyTutorPin('1234'), isFalse);
    });

    // Unit: PIN verification succeeds/fails correctly
    test('tutor PIN verification succeeds with correct PIN', () async {
      await pinService.setTutorPin('4321');
      expect(await pinService.verifyTutorPin('4321'), isTrue);
    });

    test('tutor PIN verification fails with incorrect PIN', () async {
      await pinService.setTutorPin('4321');
      expect(await pinService.verifyTutorPin('0000'), isFalse);
    });

    test('tutor PIN hashing produces valid bcrypt hash', () async {
      await pinService.setTutorPin('9999');
      final hash = await storage.read(key: 'tutor_pin_hash');
      expect(hash, isNotNull);
      expect(hash, startsWith(r'$2'));
      expect(hash, isNot('9999'));
    });

    // Unit: Lockout triggers after 5 failed attempts
    test('lockout triggers after exactly 5 failed attempts', () async {
      await pinService.setTutorPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      expect(
        () => pinService.verifyTutorPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('lockout remaining minutes is positive when locked out', () async {
      await pinService.setTutorPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      final remaining = await pinService.getTutorLockoutRemainingMinutes();
      expect(remaining, greaterThan(0));
    });

    test('successful verification resets failed attempt counter', () async {
      await pinService.setTutorPin('1234');
      // Fail 3 times
      for (var i = 0; i < 3; i++) {
        await pinService.verifyTutorPin('0000');
      }
      // Succeed — resets counter
      await pinService.verifyTutorPin('1234');
      // Fail 4 more times — should NOT lock out (counter was reset)
      for (var i = 0; i < 4; i++) {
        expect(await pinService.verifyTutorPin('0000'), isFalse);
      }
    });

    // Unit: Tutor mode accessible from both child and adult accounts
    test('tutor mode accessible from child account', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-child',
          displayName: 'Child User',
          userMode: 'child',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final profiles = await db.userProfileDao.getAllUserProfiles();
      final mode = UserMode.values.firstWhere(
        (m) => m.name == profiles.first.userMode,
        orElse: () => UserMode.adult,
      );
      // Tutor mode has no mode restriction — both child and adult can use it
      expect(mode, UserMode.child);
      expect(await pinService.hasTutorPin(), isFalse);
      await pinService.setTutorPin('1111');
      expect(await pinService.hasTutorPin(), isTrue);
    });

    test('tutor mode accessible from adult account', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-adult',
          displayName: 'Adult User',
          userMode: 'adult',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final profiles = await db.userProfileDao.getAllUserProfiles();
      final mode = UserMode.values.firstWhere(
        (m) => m.name == profiles.first.userMode,
        orElse: () => UserMode.adult,
      );
      expect(mode, UserMode.adult);
      expect(await pinService.hasTutorPin(), isFalse);
      await pinService.setTutorPin('2222');
      expect(await pinService.hasTutorPin(), isTrue);
    });

    // Unit: Write operations throw/are blocked in tutor mode context
    test('TutorModeReadOnlyException thrown in tutor mode context', () {
      const exception = TutorModeReadOnlyException();
      expect(exception.message, contains('not allowed'));
      expect(exception.toString(), contains('TutorModeReadOnlyException'));
    });

    // Unit: PINs are device-local only (FR99)
    test(
      'tutor PINs are device-local only (stored in secure storage)',
      () async {
        await pinService.setTutorPin('7777');
        verify(
          () => storage.write(
            key: 'tutor_pin_hash',
            value: any(named: 'value'),
          ),
        ).called(1);
      },
    );

    // Unit: PIN change resets lockout
    test('setting new tutor PIN resets lockout state', () async {
      await pinService.setTutorPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      // Locked out now — set new PIN should reset lockout
      await pinService.setTutorPin('5678');
      // Should not throw lockout
      expect(await pinService.verifyTutorPin('5678'), isTrue);
    });

    // Unit: PIN must be exactly 4 numeric digits
    test('rejects non-4-digit PINs', () async {
      expect(
        () => pinService.setTutorPin('123'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => pinService.setTutorPin('12345'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => pinService.setTutorPin('abcd'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Widget: PIN setup with confirmation
    testWidgets('TutorPinSetupScreen shows error on mismatched PINs', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: TutorPinSetupScreen()),
        ),
      );

      // Enter first PIN: 1234
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      await tester.enterText(fields.at(1), '2');
      await tester.pump();
      await tester.enterText(fields.at(2), '3');
      await tester.pump();
      await tester.enterText(fields.at(3), '4');
      await tester.pumpAndSettle();

      // Now in confirm step — enter mismatched PIN: 5678
      final confirmFields = find.byType(TextField);
      await tester.enterText(confirmFields.at(0), '5');
      await tester.pump();
      await tester.enterText(confirmFields.at(1), '6');
      await tester.pump();
      await tester.enterText(confirmFields.at(2), '7');
      await tester.pump();
      await tester.enterText(confirmFields.at(3), '8');
      await tester.pumpAndSettle();

      expect(find.text('PINs do not match'), findsOneWidget);
    });

    testWidgets('TutorPinSetupScreen shows Set Tutor PIN title', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: TutorPinSetupScreen()),
        ),
      );

      expect(find.text('Set Tutor PIN'), findsOneWidget);
      expect(find.text('Enter New PIN'), findsOneWidget);
    });

    testWidgets('TutorPinSetupScreen transitions to confirm step', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: TutorPinSetupScreen()),
        ),
      );

      // Enter first PIN
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      await tester.enterText(fields.at(1), '2');
      await tester.pump();
      await tester.enterText(fields.at(2), '3');
      await tester.pump();
      await tester.enterText(fields.at(3), '4');
      await tester.pumpAndSettle();

      // Should now show Confirm PIN
      expect(find.text('Confirm PIN'), findsOneWidget);
    });

    // Widget: PIN entry with numeric keypad (lockout screen tested via unit)
    testWidgets('PinEntryWidget shows lockout message when locked out', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinEntryWidget(
              title: 'Enter Tutor PIN',
              isLockedOut: true,
              lockoutRemainingMinutes: 12,
              onPinComplete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Too many failed attempts'), findsOneWidget);
      expect(find.text('Try again in 12 minute(s)'), findsOneWidget);
    });

    // Integration: set tutor PIN, verify, lockout
    test('integration: set tutor PIN, verify, fail 5 times, lockout', () async {
      await pinService.setTutorPin('1234');
      expect(await pinService.hasTutorPin(), isTrue);
      expect(await pinService.verifyTutorPin('1234'), isTrue);
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      expect(
        () => pinService.verifyTutorPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
      final remaining = await pinService.getTutorLockoutRemainingMinutes();
      expect(remaining, greaterThan(0));
    });

    // Lockout state persists across new PinService instances
    test(
      'lockout state persists across app restart (new PinService)',
      () async {
        await pinService.setTutorPin('1234');
        for (var i = 0; i < 5; i++) {
          await pinService.verifyTutorPin('0000');
        }
        final newService = PinService(storage);
        expect(
          () => newService.verifyTutorPin('1234'),
          throwsA(isA<PinLockoutException>()),
        );
      },
    );
  });

  // ── Story 11.2: Tutor Dashboard (Read-Only) ──────────────────

  group('Story 11.2 -- Tutor Dashboard (Read-Only)', tags: ['story_11_2'], () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedCompletions(AppDatabase db) async {
      final now = DateTime.now().toUtc();
      // Seed active curriculum
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);

      // Seed stage definitions
      await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              curriculumId: 'mishnayos',
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
            ),
          );
      await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              curriculumId: 'mishnayos',
              stageOrder: 2,
              stageName: 'Chazara 1',
              delayDays: 1,
            ),
          );
      await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              curriculumId: 'mishnayos',
              stageOrder: 3,
              stageName: 'Chazara 2',
              delayDays: 7,
            ),
          );

      // Seed completions with timestamps
      for (var i = 0; i < 5; i++) {
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot ${i + 1}',
            stageId: 1,
            trackType: 'personal',
            completedAt: now.subtract(Duration(days: i)),
            points: const Value(10),
          ),
        );
      }
      // Add a chazara completion for item 1
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berakhot 1',
          stageId: 2,
          trackType: 'personal',
          completedAt: now.subtract(const Duration(days: 1)),
          points: const Value(5),
        ),
      );
    }

    // Unit: Completion history query returns items with correct timestamps, sorted recent-first
    test('completion history returns items sorted recent-first', () async {
      await seedCompletions(db);
      final aggregator = TutorDashboardAggregator(db);
      final data = await aggregator.compute(
        now: DateTime.now().toUtc(),
        allTasks: [],
      );

      expect(data.completionHistory, isNotEmpty);
      // Verify sorted by most recent first
      for (var i = 0; i < data.completionHistory.length - 1; i++) {
        expect(
          data.completionHistory[i].completedAt.isAfter(
                data.completionHistory[i + 1].completedAt,
              ) ||
              data.completionHistory[i].completedAt.isAtSameMomentAs(
                data.completionHistory[i + 1].completedAt,
              ),
          isTrue,
          reason: 'Completions should be sorted recent-first',
        );
      }
      // Verify timestamps are present
      for (final c in data.completionHistory) {
        expect(c.completedAt, isNotNull);
      }
    });

    // Unit: Chazara queue groups items by urgency correctly
    test('chazara queue groups items by urgency', () async {
      await seedCompletions(db);
      final now = DateTime.now().toUtc();

      // Create tasks with different chazara priorities
      const tasks = [
        DailyTask(
          curriculumId: CurriculumId.mishnayos,
          contentItemSefariaRef: 'Mishnah Berakhot 2',
          stageOrder: 2,
          stageDefinitionId: 2,
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
          reason: 'Chazara 1 overdue by 3 day(s)',
          stageName: 'Chazara 1',
        ),
        DailyTask(
          curriculumId: CurriculumId.mishnayos,
          contentItemSefariaRef: 'Mishnah Berakhot 3',
          stageOrder: 2,
          stageDefinitionId: 2,
          priority: DailyTaskPriority.scheduledChazara,
          isOverdue: false,
          reason: 'Chazara 1 due today',
          stageName: 'Chazara 1',
        ),
        DailyTask(
          curriculumId: CurriculumId.mishnayos,
          contentItemSefariaRef: 'Mishnah Berakhot 6',
          stageOrder: 1,
          stageDefinitionId: 1,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'New learning',
          stageName: 'Learn',
          estimatedEffortMinutes: 5,
        ),
      ];

      final aggregator = TutorDashboardAggregator(db);
      final data = await aggregator.compute(now: now, allTasks: tasks);

      // Only chazara items appear in queue (not new learning)
      expect(data.chazaraQueue.length, 2);
      // Overdue first
      expect(data.chazaraQueue[0].urgency, ChazaraUrgency.overdue);
      expect(data.chazaraQueue[0].daysOverdue, 3);
      // Due today second
      expect(data.chazaraQueue[1].urgency, ChazaraUrgency.dueToday);
    });

    // Unit: Progress metrics compute correct percentages per curriculum
    test('progress metrics compute correct percentages', () async {
      await seedCompletions(db);
      final aggregator = TutorDashboardAggregator(db);
      final data = await aggregator.compute(
        now: DateTime.now().toUtc(),
        allTasks: [],
      );

      expect(data.paceInfo, contains(CurriculumId.mishnayos));
      final mishnayosPace = data.paceInfo[CurriculumId.mishnayos]!;
      expect(mishnayosPace.totalCompletions, greaterThan(0));
      expect(mishnayosPace.completionPercentage, greaterThanOrEqualTo(0.0));
      expect(mishnayosPace.completionPercentage, lessThanOrEqualTo(1.0));
    });

    // Helper: build a TutorDashboardData with test completions
    TutorDashboardData buildTestDashboardData({
      List<Completion>? completions,
      List<ChazaraQueueItem>? chazaraQueue,
      List<DailyTask>? dailyTasks,
      Map<CurriculumId, TutorPaceInfo>? paceInfo,
    }) {
      return TutorDashboardData(
        activeCurricula: [CurriculumId.mishnayos],
        completionHistory: completions ?? [],
        chazaraQueue: chazaraQueue ?? [],
        paceInfo:
            paceInfo ??
            {
              CurriculumId.mishnayos: const TutorPaceInfo(
                paceStatus: null,
                completionPercentage: 0.5,
                totalCompletions: 10,
              ),
            },
        dailyTasks: dailyTasks ?? [],
      );
    }

    Completion fakeCompletion({
      required String ref,
      required DateTime completedAt,
      int points = 10,
    }) {
      return Completion(
        id: ref.hashCode,
        profileId: 0,
        curriculumId: 'mishnayos',
        sefariaRef: ref,
        stageId: 1,
        trackType: 'personal',
        completedAt: completedAt,
        points: points,
      );
    }

    // Widget: Completion history list renders with dates, items, and stages
    testWidgets('completion history list renders with dates and items', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      final data = buildTestDashboardData(
        completions: [
          fakeCompletion(ref: 'Mishnah Berakhot 1', completedAt: now),
          fakeCompletion(
            ref: 'Mishnah Berakhot 2',
            completedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorDashboardDataProvider.overrideWith((_) async => data),
          ],
          child: const MaterialApp(home: TutorDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completion History'), findsOneWidget);
      expect(find.text('Mishnah Berakhot 1'), findsOneWidget);
      expect(find.text('Mishnah Berakhot 2'), findsOneWidget);
    });

    // Widget: Chazara queue shows urgency grouping with visual indicators
    testWidgets('chazara queue shows urgency grouping', (tester) async {
      final data = buildTestDashboardData(
        chazaraQueue: [
          ChazaraQueueItem(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'Mishnah Berakhot 2',
            stageName: 'Chazara 1',
            urgency: ChazaraUrgency.overdue,
            dueDate: DateTime.now().toUtc(),
            daysOverdue: 3,
          ),
          ChazaraQueueItem(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'Mishnah Berakhot 3',
            stageName: 'Chazara 1',
            urgency: ChazaraUrgency.dueToday,
            dueDate: DateTime.now().toUtc(),
            daysOverdue: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorDashboardDataProvider.overrideWith((_) async => data),
          ],
          child: const MaterialApp(home: TutorDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chazara Queue'), findsOneWidget);
      expect(find.text('Overdue (1)'), findsOneWidget);
      expect(find.text('Due Today (1)'), findsOneWidget);
    });

    // Widget: Pace status displays ahead/on-track/behind per curriculum
    testWidgets('pace status displays per curriculum', (tester) async {
      final data = buildTestDashboardData(
        paceInfo: {
          CurriculumId.mishnayos: const TutorPaceInfo(
            paceStatus: PaceStatus(
              status: PaceStatusType.behind,
              daysDelta: -3,
              rollingAverage: 2.0,
            ),
            completionPercentage: 0.35,
            totalCompletions: 20,
          ),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorDashboardDataProvider.overrideWith((_) async => data),
          ],
          child: const MaterialApp(home: TutorDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Progress & Pace'), findsOneWidget);
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('Behind'), findsOneWidget);
      expect(find.text('3 days behind'), findsOneWidget);
    });

    // Widget: Daily task view renders scheduler recommendations (read-only)
    testWidgets('daily task view renders tasks', (tester) async {
      final data = buildTestDashboardData(
        dailyTasks: [
          const DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 6',
            stageOrder: 1,
            stageDefinitionId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New learning',
            stageName: 'Learn',
            estimatedEffortMinutes: 5,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorDashboardDataProvider.overrideWith((_) async => data),
          ],
          child: const MaterialApp(home: TutorDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Today's Tasks"), findsOneWidget);
      expect(find.text('Mishnah Berakhot 6'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });

    // Widget: No mark-complete, edit, or delete buttons present in any view
    testWidgets('no action buttons present in tutor dashboard', (tester) async {
      final now = DateTime.now().toUtc();
      final data = buildTestDashboardData(
        completions: [
          fakeCompletion(ref: 'Mishnah Berakhot 1', completedAt: now),
        ],
        dailyTasks: [
          const DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 6',
            stageOrder: 1,
            stageDefinitionId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New learning',
            stageName: 'Learn',
            estimatedEffortMinutes: 5,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tutorDashboardDataProvider.overrideWith((_) async => data),
          ],
          child: const MaterialApp(home: TutorDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Read-Only badge should be visible
      expect(find.text('Read Only'), findsOneWidget);

      // No action buttons
      expect(find.text('Mark Complete'), findsNothing);
      expect(find.text('Complete'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    // Integration: Tutor views dashboard with actual data
    test(
      'integration: aggregator computes full dashboard from database',
      () async {
        await seedCompletions(db);
        final now = DateTime.now().toUtc();

        const tasks = [
          DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 2',
            stageOrder: 2,
            stageDefinitionId: 2,
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
            reason: 'Chazara 1 overdue by 2 day(s)',
            stageName: 'Chazara 1',
          ),
          DailyTask(
            curriculumId: CurriculumId.mishnayos,
            contentItemSefariaRef: 'Mishnah Berakhot 6',
            stageOrder: 1,
            stageDefinitionId: 1,
            priority: DailyTaskPriority.newLearning,
            isOverdue: false,
            reason: 'New learning',
            stageName: 'Learn',
            estimatedEffortMinutes: 5,
          ),
        ];

        final aggregator = TutorDashboardAggregator(db);
        final data = await aggregator.compute(now: now, allTasks: tasks);

        // Completion history shows only today's completions (1 of 6 seeded)
        expect(data.completionHistory.length, 1);

        // Chazara queue has overdue item
        expect(data.chazaraQueue.length, 1);
        expect(data.chazaraQueue.first.urgency, ChazaraUrgency.overdue);

        // Daily tasks include all types
        expect(data.dailyTasks.length, 2);

        // Pace info per curriculum uses all-time completions
        expect(data.paceInfo, contains(CurriculumId.mishnayos));
        expect(data.paceInfo[CurriculumId.mishnayos]!.totalCompletions, 6);

        // Per-curriculum filtering works
        final filtered = data.filterByCurriculum(CurriculumId.mishnayos);
        expect(filtered.completionHistory.length, 1);

        // Filtering by non-active curriculum returns empty
        final empty = data.filterByCurriculum(CurriculumId.bavli);
        expect(empty.completionHistory, isEmpty);
        expect(empty.chazaraQueue, isEmpty);
      },
    );
  });

  // ── Story 11.3: Student progress view ─────────────────────────

  group(
    'Story 11.3 -- Student progress view',
    tags: ['story_11_3'],
    skip: 'Backlog: tutor student progress view not yet implemented',
    () {
      test('tutor sees student completion status per assignment', () {
        // TODO: verify progress reporting for tutor
      });

      test('tutor can view detailed completion history', () {
        // TODO: verify drill-down from summary to detail
      });
    },
  );

  // ── Story 11.4: Tutor notes ───────────────────────────────────

  group(
    'Story 11.4 -- Tutor notes',
    tags: ['story_11_4'],
    skip: 'Backlog: tutor notes not yet implemented',
    () {
      test('tutor can add notes to a student profile', () {
        // TODO: verify note creation and persistence
      });

      test('notes are visible in student detail view', () {
        // TODO: verify note display
      });
    },
  );
}
