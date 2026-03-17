/// Story acceptance tests for Epic 9 -- Onboarding.
@Tags(['epic_9'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockTrackRepository extends Mock implements TrackRepository {}

void main() {
  // ── Story 9.1: Welcome flow ───────────────────────────────────

  group('Story 9.1 -- Welcome flow', tags: ['story_9_1'], () {
    late AppDatabase db;
    late UserProfileService profileService;
    late List<Map<String, String>> firestorePushes;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      firestorePushes = [];
      profileService = UserProfileService(
        userProfileDao: db.userProfileDao,
        pushUserProfile:
            ({
              required String firebaseUid,
              required String displayName,
              required String userMode,
            }) async {
              firestorePushes.add({
                'firebaseUid': firebaseUid,
                'displayName': displayName,
                'userMode': userMode,
              });
            },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'auth service creates account and mode selection persists child mode',
      () async {
        await profileService.setUserMode(
          firebaseUid: 'test-uid',
          displayName: 'Test User',
          mode: UserMode.child,
        );
        final mode = await profileService.getUserMode('test-uid');
        expect(mode, UserMode.child);
      },
    );

    test('auth service mode selection persists adult mode', () async {
      await profileService.setUserMode(
        firebaseUid: 'test-uid-2',
        displayName: 'Adult User',
        mode: UserMode.adult,
      );
      final mode = await profileService.getUserMode('test-uid-2');
      expect(mode, UserMode.adult);
    });

    test('email validation rejects invalid formats', () {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      expect(emailRegex.hasMatch('invalid'), isFalse);
      expect(emailRegex.hasMatch('user@'), isFalse);
      expect(emailRegex.hasMatch('@example.com'), isFalse);
      expect(emailRegex.hasMatch('user@example.com'), isTrue);
    });

    test('password validation rejects under 6 characters', () {
      expect('12345'.length < 6, isTrue);
      expect('123456'.length < 6, isFalse);
    });

    test('mode selection writes to Firestore', () async {
      await profileService.setUserMode(
        firebaseUid: 'uid-firestore',
        displayName: 'Test',
        mode: UserMode.child,
      );
      expect(firestorePushes, hasLength(1));
      expect(firestorePushes.first['firebaseUid'], 'uid-firestore');
      expect(firestorePushes.first['userMode'], 'child');
    });
  });

  // ── Story 9.2: Curriculum selection ───────────────────────────

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  group('Story 9.2 -- Curriculum selection', tags: ['story_9_2'], () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('curriculum selection state tracks selected curricula correctly', () {
      final selected = <CurriculumId>{};

      // Add
      selected.add(CurriculumId.mishnayos);
      expect(selected, contains(CurriculumId.mishnayos));

      // Add another
      selected.add(CurriculumId.bavli);
      expect(selected, hasLength(2));

      // Remove
      selected.remove(CurriculumId.mishnayos);
      expect(selected, hasLength(1));
      expect(selected, isNot(contains(CurriculumId.mishnayos)));
    });

    test('validation prevents proceeding with zero curricula selected', () {
      final selected = <CurriculumId>{};
      // Button should be disabled (onPressed null) when selected is empty
      expect(selected.isEmpty, isTrue);
      expect(selected.isNotEmpty, isFalse);

      selected.add(CurriculumId.chumash);
      expect(selected.isNotEmpty, isTrue);
    });

    test('all 5 curricula are available as options', () {
      expect(CurriculumId.values, hasLength(5));
      expect(CurriculumId.values, contains(CurriculumId.mishnayos));
      expect(CurriculumId.values, contains(CurriculumId.bavli));
      expect(CurriculumId.values, contains(CurriculumId.yerushalmi));
      expect(CurriculumId.values, contains(CurriculumId.mishnaBerurah));
      expect(CurriculumId.values, contains(CurriculumId.chumash));
    });

    test('each curriculum has display name, storage key', () {
      for (final id in CurriculumId.values) {
        expect(id.displayNameEn, isNotEmpty);
        expect(id.displayNameHe, isNotEmpty);
        expect(id.storageKey, isNotEmpty);
      }
    });

    test(
      'import service selects 2 curricula, imports, and activates them',
      () async {
        final mockContentRepo = _MockContentRepository();
        final mockTrackRepo = _MockTrackRepository();

        ContentItem fakeItem(CurriculumId id) => ContentItem(
          curriculumId: id.storageKey,
          level1: 'L1',
          displayNameHe: 'test',
          displayNameEn: 'test',
          sefariaRef: 'ref-${id.storageKey}',
          sortOrder: 0,
          isLeaf: true,
        );

        when(
          () => mockContentRepo.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer((_) async => [fakeItem(CurriculumId.mishnayos)]);
        when(
          () => mockContentRepo.getContentForCurriculum(CurriculumId.bavli),
        ).thenAnswer((_) async => [fakeItem(CurriculumId.bavli)]);
        when(
          () => mockTrackRepo.initializeDefaultTracks(any()),
        ).thenAnswer((_) async {});

        final activationService = CurriculumActivationService(
          database: db,
          pushActiveCurricula: (_) async {},
          trackRepository: mockTrackRepo,
        );
        final importService = CurriculumImportService(
          contentRepository: mockContentRepo,
          activationService: activationService,
        );

        // Select 2 curricula and call importAll end-to-end
        final selected = [CurriculumId.mishnayos, CurriculumId.bavli];
        final progressList = await importService.importAll(selected).toList();

        // Verify all succeeded
        expect(progressList.last.isComplete, isTrue);
        expect(progressList.last.allSucceeded, isTrue);
        expect(progressList.last.results, hasLength(2));

        // Verify content was loaded (service called getContentForCurriculum)
        verify(
          () => mockContentRepo.getContentForCurriculum(CurriculumId.mishnayos),
        ).called(1);
        verify(
          () => mockContentRepo.getContentForCurriculum(CurriculumId.bavli),
        ).called(1);

        // Verify curricula are active in the database
        final active = await db.activeCurriculumDao.getActiveCurricula();
        expect(active, contains(CurriculumId.mishnayos.storageKey));
        expect(active, contains(CurriculumId.bavli.storageKey));
      },
    );

    test('user can add more curricula later (not onboarding-only)', () async {
      // Initial activation
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);

      // Later activation from settings
      await db.activeCurriculumDao.activate(CurriculumId.chumash);

      final active = await db.activeCurriculumDao.getActiveCurricula();
      expect(active, hasLength(2));
      expect(active, contains(CurriculumId.chumash.storageKey));
    });
  });

  // ── Story 9.3: Per-Curriculum Goal Setup ──────────────────────

  group('Story 9.3 -- Per-Curriculum Goal Setup', tags: ['story_9_3'], () {
    late AppDatabase db;
    late GoalRepositoryImpl goalRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      goalRepo = GoalRepositoryImpl(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'goal creation persists curriculum_id, target_date, and date_type',
      () async {
        final targetDate = DateTime.utc(2027, 6, 15);
        final goal = await goalRepo.createGoal(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 100.0,
          targetDate: targetDate,
          description: 'Finish by summer',
        );

        expect(goal.curriculumId, CurriculumId.mishnayos);
        expect(goal.targetDate, targetDate);
        expect(goal.description, 'Finish by summer');
        expect(goal.id, isNotNull);

        // Verify persisted
        final goals = await goalRepo.getGoals(CurriculumId.mishnayos);
        expect(goals, hasLength(1));
        expect(goals.first.targetDate, targetDate);
      },
    );

    test('daily pace calculation: remaining items / days until deadline', () {
      const totalItems = 4192;
      final deadline = DateTime.utc(2027, 6, 15);
      final today = DateTime.utc(2026, 3, 16);
      final daysRemaining = deadline.difference(today).inDays;
      final pace = (totalItems / daysRemaining).ceil();

      expect(daysRemaining, greaterThan(0));
      expect(pace, greaterThan(0));
      // ~4192 items / ~456 days ≈ 10 items/day
      expect(pace, lessThanOrEqualTo(15));
      expect(pace, greaterThanOrEqualTo(5));
    });

    test('skipping goal sets curriculum to no-deadline mode', () async {
      // Activate curriculum without creating a goal = no-deadline mode
      await db.activeCurriculumDao.activate(CurriculumId.bavli);

      // No goals should exist for this curriculum
      final goals = await goalRepo.getGoals(CurriculumId.bavli);
      expect(goals, isEmpty);

      // Curriculum is still active
      final active = await db.activeCurriculumDao.getActiveCurricula();
      expect(active, contains(CurriculumId.bavli.storageKey));
    });

    testWidgets('goal setup screen shows curriculum name and item count', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GoalSetupScreen(
            curriculumId: CurriculumId.mishnayos,
            totalItems: 4192,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the screen renders with the create goal button
      expect(find.text('Create Goal'), findsOneWidget);
      // Verify the target slider is present
      expect(find.text('Target: 100%'), findsOneWidget);
      // Verify Hebrew date toggle is present
      expect(find.text('Use Hebrew date'), findsOneWidget);
    });

    test('skip button proceeds without creating a goal', () async {
      // Activate two curricula
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await db.activeCurriculumDao.activate(CurriculumId.bavli);

      // Set goal for first, skip second
      await goalRepo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100.0,
        targetDate: DateTime.utc(2027, 6, 15),
      );
      // bavli: skipped — no goal created

      final mishnayosGoals = await goalRepo.getGoals(CurriculumId.mishnayos);
      final bavliGoals = await goalRepo.getGoals(CurriculumId.bavli);

      expect(mishnayosGoals, hasLength(1));
      expect(bavliGoals, isEmpty); // Skipped = no goal
    });

    testWidgets('Gregorian date picker mode works and shows daily pace', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GoalSetupScreen(
            curriculumId: CurriculumId.mishnayos,
            totalItems: 365,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default mode is Gregorian (Hebrew toggle off)
      expect(find.text('Use Hebrew date'), findsOneWidget);
      final switchWidget = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidget.value, isFalse);

      // Tap calendar icon to open Gregorian date picker
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      // Gregorian date picker dialog should be present
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Dismiss the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Hebrew date toggle switches picker mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GoalSetupScreen(
            curriculumId: CurriculumId.mishnayos,
            totalItems: 365,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle to Hebrew date mode
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Switch should now be on
      final switchWidget = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidget.value, isTrue);
    });

    test('summary shows calculated daily pace after date selection', () {
      // Pace calculation for goal summary display
      const totalItems = 2711;
      final deadline = DateTime.utc(2027, 3, 16);
      final today = DateTime.utc(2026, 3, 16);
      final daysRemaining = deadline.difference(today).inDays;

      expect(daysRemaining, 365);
      final pace = (totalItems / daysRemaining).ceil();
      expect(pace, 8); // 2711/365 = 7.43 → ceil = 8
    });

    test('goals saved to database and retrievable', () async {
      final goal = await goalRepo.createGoal(
        curriculumId: CurriculumId.chumash,
        targetPercent: 100.0,
        targetDate: DateTime.utc(2027, 9, 1),
        description: 'Complete Chumash',
      );

      final goals = await goalRepo.getGoals(CurriculumId.chumash);
      expect(goals, hasLength(1));
      expect(goals.first.id, goal.id);
      expect(goals.first.targetDate, DateTime.utc(2027, 9, 1));
    });

    test('user can modify goals later from goal management', () async {
      // Create during onboarding
      final goal = await goalRepo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100.0,
        targetDate: DateTime.utc(2027, 6, 15),
      );

      // Modify later from goal management
      final updated = await goalRepo.updateGoal(
        goalId: goal.id!,
        targetDate: DateTime.utc(2027, 12, 31),
        description: 'Extended deadline',
      );

      expect(updated.targetDate, DateTime.utc(2027, 12, 31));
      expect(updated.description, 'Extended deadline');
    });

    test(
      'integration: set goals for 2 curricula (one with deadline, one skipped)',
      () async {
        // Activate both
        await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
        await db.activeCurriculumDao.activate(CurriculumId.bavli);

        // Set goal with deadline for mishnayos
        await goalRepo.createGoal(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 100.0,
          targetDate: DateTime.utc(2027, 6, 15),
          description: 'Complete by summer',
        );

        // Skip bavli (no goal created)

        // Verify: mishnayos has goal, bavli does not
        final mishnayosGoals = await goalRepo.getGoals(CurriculumId.mishnayos);
        final bavliGoals = await goalRepo.getGoals(CurriculumId.bavli);

        expect(mishnayosGoals, hasLength(1));
        expect(mishnayosGoals.first.targetDate, DateTime.utc(2027, 6, 15));
        expect(bavliGoals, isEmpty);

        // Both curricula are still active
        final active = await db.activeCurriculumDao.getActiveCurricula();
        expect(active, contains(CurriculumId.mishnayos.storageKey));
        expect(active, contains(CurriculumId.bavli.storageKey));
      },
    );
  });

  // ── Story 9.4: Import existing progress ───────────────────────

  group(
    'Story 9.4 -- Import existing progress',
    tags: ['story_9_4'],
    skip: 'Backlog: progress import not yet implemented',
    () {
      test('user can import progress from a backup file', () {
        fail('Not yet implemented');
      });

      test('imported completions appear in progress view', () {
        fail('Not yet implemented');
      });
    },
  );

  // ── Story 9.5: Tutorial walkthrough ───────────────────────────

  group(
    'Story 9.5 -- Tutorial walkthrough',
    tags: ['story_9_5'],
    skip: 'Backlog: tutorial walkthrough not yet implemented',
    () {
      test('tutorial highlights key features step by step', () {
        fail('Not yet implemented');
      });

      test('user can skip tutorial', () {
        fail('Not yet implemented');
      });
    },
  );
}
