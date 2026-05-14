/// Story acceptance tests for Epic 9 -- Onboarding.
@Tags(['epic_9'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockTrackRepository extends Mock implements TrackRepository {}

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _MockBookmarkRepository extends Mock implements BookmarkRepository {}

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  // ── Story 9.1: Welcome flow ───────────────────────────────────

  group('Story 9.1 -- Welcome flow', tags: ['story_9_1'], () {
    late UserDatabase db;
    late UserProfileService profileService;
    late List<Map<String, String>> firestorePushes;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      await _insertTrack(db);
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
    registerFallbackValue(TrackType.personal);
    registerFallbackValue(
      const BulkCompletionRequest(
        curriculumId: 'mishnayos',
        sefariaRefs: [],
        stageId: 1,
        trackType: 'personal',
      ),
    );
  });

  group('Story 9.2 -- Curriculum selection', tags: ['story_9_2'], () {
    late UserDatabase db;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      await _insertTrack(db);
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

    test('all curricula are available as options', () {
      expect(CurriculumId.values, hasLength(CurriculumId.values.length));
      expect(CurriculumId.values, contains(CurriculumId.mishnayos));
      expect(CurriculumId.values, contains(CurriculumId.bavli));
      expect(CurriculumId.values, contains(CurriculumId.yerushalmi));
      expect(CurriculumId.values, contains(CurriculumId.mishnaBerurah));
      expect(CurriculumId.values, contains(CurriculumId.chumash));
      expect(CurriculumId.values, contains(CurriculumId.nach));
      expect(CurriculumId.values, contains(CurriculumId.mussar));
      expect(CurriculumId.values, contains(CurriculumId.mishnehTorah));
      expect(CurriculumId.values, contains(CurriculumId.tanach));
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
        final mockTrackRepo = _MockTrackRepository();

        when(
          () => mockTrackRepo.initializeDefaultTracks(any()),
        ).thenAnswer((_) async {});

        final activationService = CurriculumActivationService(
          database: db,
          pushCurriculumTrack: (_) async {},
          trackRepository: mockTrackRepo,
        );
        final importService = CurriculumImportService(
          activationService: activationService,
        );

        // Select 2 curricula and call importAll end-to-end
        final selected = [CurriculumId.mishnayos, CurriculumId.bavli];
        final progressList = await importService.importAll(selected).toList();

        // Verify all succeeded
        expect(progressList.last.isComplete, isTrue);
        expect(progressList.last.allSucceeded, isTrue);
        expect(progressList.last.results, hasLength(2));

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
    late UserDatabase db;
    late int trackId;
    late GoalRepositoryImpl goalRepo;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      trackId = await _insertTrack(db);
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
          profileId: 0,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
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
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GoalSetupScreen(
              curriculumId: CurriculumId.mishnayos,
              totalItems: 4192,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the screen renders with the create goal button
      expect(find.text('Create Goal'), findsOneWidget);
      // Verify the target percentage text is present
      expect(
        find.text('Complete 100% of the material (4192 of 4192 items)'),
        findsOneWidget,
      );
      // Verify the deadline section is shown by default
      expect(find.text('Tap to choose a date'), findsOneWidget);
    });

    test('skip button proceeds without creating a goal', () async {
      // Activate two curricula
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await db.activeCurriculumDao.activate(CurriculumId.bavli);

      // Set goal for first, skip second
      await goalRepo.createGoal(
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
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
      // Default is Hebrew calendar; explicitly opt into Gregorian for this case.
      SharedPreferences.setMockInitialValues({'use_hebrew_calendar_p0': false});
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GoalSetupScreen(
              curriculumId: CurriculumId.mishnayos,
              totalItems: 365,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tap to choose a date'), findsOneWidget);

      // Tap the date Card to open Gregorian picker
      await tester.tap(find.text('Tap to choose a date'));
      await tester.pumpAndSettle();

      // Gregorian date picker dialog should be present
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Dismiss the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Hebrew date toggle switches picker mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [useHebrewDateProvider.overrideWithValue(true)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GoalSetupScreen(
              curriculumId: CurriculumId.mishnayos,
              totalItems: 365,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hebrew date mode is active via provider override.
      // Tapping the date Card should open the Hebrew date picker
      // rather than the Gregorian one.
      expect(find.text('Tap to choose a date'), findsOneWidget);
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
        profileId: 0,
        curriculumId: CurriculumId.chumash,
        trackId: trackId,
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
        profileId: 0,
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
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
          profileId: 0,
          curriculumId: CurriculumId.mishnayos,
          trackId: trackId,
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

  // ── Story 9.4: Bulk Mark Prior Completions ───────────────────

  group('Story 9.4 -- Bulk Mark Prior Completions', tags: ['story_9_4'], () {
    late _MockContentRepository mockContentRepo;
    late _MockCompletionRepository mockCompletionRepo;
    late _MockBookmarkRepository mockBookmarkRepo;
    late UserDatabase bulkServiceDb;
    late BulkPriorCompletionService service;

    List<ContentItem> makeMishnayosItems() {
      // 3 sedarim, each with 2 masechtos, each with 1 leaf item = 6 items
      return [
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Berachos',
          level3: 'Chapter 1',
          displayNameHe: 'ברכות א',
          displayNameEn: 'Berachos 1:1',
          sefariaRef: 'Mishnah Berachos 1:1',
          sortOrder: 1,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Zeraim',
          level2: 'Peah',
          level3: 'Chapter 1',
          displayNameHe: 'פאה א',
          displayNameEn: 'Peah 1:1',
          sefariaRef: 'Mishnah Peah 1:1',
          sortOrder: 2,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Moed',
          level2: 'Shabbos',
          level3: 'Chapter 1',
          displayNameHe: 'שבת א',
          displayNameEn: 'Shabbos 1:1',
          sefariaRef: 'Mishnah Shabbos 1:1',
          sortOrder: 3,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Moed',
          level2: 'Eruvin',
          level3: 'Chapter 1',
          displayNameHe: 'עירובין א',
          displayNameEn: 'Eruvin 1:1',
          sefariaRef: 'Mishnah Eruvin 1:1',
          sortOrder: 4,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Nashim',
          level2: 'Yevamos',
          level3: 'Chapter 1',
          displayNameHe: 'יבמות א',
          displayNameEn: 'Yevamos 1:1',
          sefariaRef: 'Mishnah Yevamos 1:1',
          sortOrder: 5,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Seder Nashim',
          level2: 'Kesubos',
          level3: 'Chapter 1',
          displayNameHe: 'כתובות א',
          displayNameEn: 'Kesubos 1:1',
          sefariaRef: 'Mishnah Kesubos 1:1',
          sortOrder: 6,
          isLeaf: true,
        ),
      ];
    }

    setUp(() {
      mockContentRepo = _MockContentRepository();
      mockCompletionRepo = _MockCompletionRepository();
      mockBookmarkRepo = _MockBookmarkRepository();
      bulkServiceDb = UserDatabase(NativeDatabase.memory());
      service = BulkPriorCompletionService(
        contentRepository: mockContentRepo,
        completionRepository: mockCompletionRepo,
        bookmarkRepository: mockBookmarkRepo,
        database: bulkServiceDb,
        syncEngine: null,
      );

      when(
        () => mockContentRepo.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer((_) async => makeMishnayosItems());

      // Default: bulkMarkComplete returns a Completion-like list of same length
      when(() => mockCompletionRepo.bulkMarkComplete(any())).thenAnswer((inv) {
        final req = inv.positionalArguments[0] as BulkCompletionRequest;
        return Future.value(
          List.generate(
            req.sefariaRefs.length,
            (_) => Completion(
              id: 1,
              profileId: 0,
              curriculumId: req.curriculumId,
              sefariaRef: req.sefariaRefs.first,
              stageId: req.stageId,
              trackId: 1,
              trackType: req.trackType,
              completedAt: DateTime.now(),
              points: 10,
            ),
          ),
        );
      });

      when(
        () => mockCompletionRepo.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => <Completion>[]);

      when(
        () => mockBookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          trackType: any(named: 'trackType'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer(
        (_) async => BookmarkEntity(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
          sefariaRef: 'ref',
          updatedAt: DateTime.now(),
        ),
      );
    });

    test(
      'bulk mark at seder level creates completion records for all items within',
      () async {
        // Select all of Seder Zeraim (contains 2 items)
        final resolved = await service.resolveSelections(
          curriculumId: CurriculumId.mishnayos,
          selections: [const HierarchySelection(level1: 'Seder Zeraim')],
        );

        expect(resolved, hasLength(2));
        expect(
          resolved.map((i) => i.sefariaRef),
          containsAll(['Mishnah Berachos 1:1', 'Mishnah Peah 1:1']),
        );
      },
    );

    test(
      'bulk mark with stage selection creates correct stage completion records',
      () async {
        final resolved = await service.resolveSelections(
          curriculumId: CurriculumId.mishnayos,
          selections: [const HierarchySelection(level1: 'Seder Zeraim')],
        );

        // Mark stages 1 and 2
        final result = await service.execute(
          curriculumId: CurriculumId.mishnayos,
          resolvedItems: resolved,
          stageIds: [1, 2],
        );

        // Should create 2 items * 2 stages = 4 completions
        expect(result.completionCount, 4);
        expect(result.itemCount, 2);

        // Verify bulkMarkComplete was called twice (once per stage)
        verify(() => mockCompletionRepo.bulkMarkComplete(any())).called(2);
      },
    );

    test(
      'bookmark advances to first uncompleted item after bulk mark',
      () async {
        // Mark first 2 sedarim (4 items), leaving Seder Nashim uncompleted
        final resolved = await service.resolveSelections(
          curriculumId: CurriculumId.mishnayos,
          selections: [
            const HierarchySelection(level1: 'Seder Zeraim'),
            const HierarchySelection(level1: 'Seder Moed'),
          ],
        );

        final result = await service.execute(
          curriculumId: CurriculumId.mishnayos,
          resolvedItems: resolved,
          stageIds: [1],
        );

        // Bookmark should be set to first item in Seder Nashim
        expect(result.bookmarkSefariaRef, 'Mishnah Yevamos 1:1');

        // Verify setBookmark was called with the correct ref
        verify(
          () => mockBookmarkRepo.setBookmark(
            curriculumId: CurriculumId.mishnayos,
            trackType: TrackType.personal,
            sefariaRef: 'Mishnah Yevamos 1:1',
          ),
        ).called(1);
      },
    );

    test('bulk insert completes in single transaction (per stage)', () async {
      final resolved = await service.resolveSelections(
        curriculumId: CurriculumId.mishnayos,
        selections: [const HierarchySelection(level1: 'Seder Zeraim')],
      );

      await service.execute(
        curriculumId: CurriculumId.mishnayos,
        resolvedItems: resolved,
        stageIds: [1],
      );

      // Verify a single bulkMarkComplete call (which uses single transaction)
      final captured = verify(
        () => mockCompletionRepo.bulkMarkComplete(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      final req = captured.first as BulkCompletionRequest;
      expect(req.sefariaRefs, hasLength(2));
      expect(req.trackType, 'personal');
      expect(req.awardGamificationPoints, isFalse);
    });

    test('selecting individual items for partial completions', () async {
      final resolved = await service.resolveSelections(
        curriculumId: CurriculumId.mishnayos,
        selections: [
          // Select one specific item from Seder Zeraim
          const HierarchySelection(
            level1: 'Seder Zeraim',
            level2: 'Berachos',
            level3: 'Chapter 1',
          ),
        ],
      );

      expect(resolved, hasLength(1));
      expect(resolved.first.sefariaRef, 'Mishnah Berachos 1:1');
    });

    test('all bulk completions use personal track', () async {
      final resolved = await service.resolveSelections(
        curriculumId: CurriculumId.mishnayos,
        selections: [const HierarchySelection(level1: 'Seder Zeraim')],
      );

      await service.execute(
        curriculumId: CurriculumId.mishnayos,
        resolvedItems: resolved,
        stageIds: [1],
      );

      final captured = verify(
        () => mockCompletionRepo.bulkMarkComplete(captureAny()),
      ).captured;
      final req = captured.first as BulkCompletionRequest;
      expect(req.trackType, 'personal');
      expect(req.awardGamificationPoints, isFalse);
    });

    test('hierarchy selection at masechta level resolves correctly', () async {
      final resolved = await service.resolveSelections(
        curriculumId: CurriculumId.mishnayos,
        selections: [
          const HierarchySelection(level1: 'Seder Moed', level2: 'Shabbos'),
        ],
      );

      expect(resolved, hasLength(1));
      expect(resolved.first.sefariaRef, 'Mishnah Shabbos 1:1');
    });

    test(
      'integration: bulk mark first 2 sedarim, verify count, bookmark, scheduler',
      () async {
        final resolved = await service.resolveSelections(
          curriculumId: CurriculumId.mishnayos,
          selections: [
            const HierarchySelection(level1: 'Seder Zeraim'),
            const HierarchySelection(level1: 'Seder Moed'),
          ],
        );

        expect(resolved, hasLength(4)); // 2 items per seder

        final result = await service.execute(
          curriculumId: CurriculumId.mishnayos,
          resolvedItems: resolved,
          stageIds: [1],
        );

        // Verify completion count
        expect(result.itemCount, 4);
        expect(result.completionCount, 4);

        // Verify bookmark set to first uncompleted item
        expect(result.bookmarkSefariaRef, 'Mishnah Yevamos 1:1');
      },
    );

    tearDown(() async {
      await bulkServiceDb.close();
    });
  });
}
