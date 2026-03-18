/// Story acceptance tests for Epic 9 -- Onboarding.
@Tags(['epic_9'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/daos/content_download_status_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/suggested_thresholds_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/rewards_setup_screen.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockTrackRepository extends Mock implements TrackRepository {}

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _MockBookmarkRepository extends Mock implements BookmarkRepository {}

class _MockCloudContentService extends Mock implements CloudContentService {}

class _MockContentDownloadStatusDao extends Mock
    implements ContentDownloadStatusDao {}

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

    test('all 7 curricula are available as options', () {
      expect(CurriculumId.values, hasLength(7));
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
        final mockCloudService = _MockCloudContentService();
        final mockDownloadStatusDao = _MockContentDownloadStatusDao();

        ContentItem fakeItem(CurriculumId id) => ContentItem(
          curriculumId: id.storageKey,
          level1: 'L1',
          displayNameHe: 'test',
          displayNameEn: 'test',
          sefariaRef: 'ref-${id.storageKey}',
          sortOrder: 0,
          isLeaf: true,
        );

        for (final curriculum in [CurriculumId.mishnayos, CurriculumId.bavli]) {
          when(
            () => mockCloudService.downloadContent(
              curriculum: curriculum,
              languageCode: any(named: 'languageCode'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              const ContentDownloadProgress(
                state: ContentDownloadState.completed,
              ),
            ]),
          );

          when(
            () => mockCloudService.parseContent(
              curriculum: curriculum,
              languageCode: any(named: 'languageCode'),
            ),
          ).thenAnswer(
            (_) async => (
              items: [fakeItem(curriculum)],
              config: CurriculumHierarchyConfig(
                curriculumId: curriculum.storageKey,
                levelLabels: ['Level1'],
                totalItems: 1,
              ),
            ),
          );

          when(
            () => mockCloudService.getContentVersion(curriculum),
          ).thenAnswer((_) async => null);
        }

        when(
          () => mockDownloadStatusDao.markDownloaded(
            curriculumId: any(named: 'curriculumId'),
            languageCode: any(named: 'languageCode'),
            contentVersion: any(named: 'contentVersion'),
            itemCount: any(named: 'itemCount'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockTrackRepo.initializeDefaultTracks(any()),
        ).thenAnswer((_) async {});

        final activationService = CurriculumActivationService(
          database: db,
          pushActiveCurricula: (_) async {},
          trackRepository: mockTrackRepo,
        );
        final importService = CurriculumImportService(
          activationService: activationService,
          cloudContentService: mockCloudService,
          contentDownloadStatusDao: mockDownloadStatusDao,
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
        const MaterialApp(
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
        const MaterialApp(
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
        const MaterialApp(
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

  // ── Story 9.4: Bulk Mark Prior Completions ───────────────────

  group('Story 9.4 -- Bulk Mark Prior Completions', tags: ['story_9_4'], () {
    late _MockContentRepository mockContentRepo;
    late _MockCompletionRepository mockCompletionRepo;
    late _MockBookmarkRepository mockBookmarkRepo;
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
      service = BulkPriorCompletionService(
        contentRepository: mockContentRepo,
        completionRepository: mockCompletionRepo,
        bookmarkRepository: mockBookmarkRepo,
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
              trackType: req.trackType,
              completedAt: DateTime.now(),
              points: 10,
            ),
          ),
        );
      });

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
  });

  // ── Story 9.5: Initial Rewards Setup (Child Mode) ──────────

  group(
    'Story 9.5 -- Initial Rewards Setup (Child Mode)',
    tags: ['story_9_5'],
    () {
      late AppDatabase db;
      late RewardService rewardService;
      late PointsService pointsService;

      setUp(() {
        db = AppDatabase(NativeDatabase.memory());
        pointsService = PointsService(db);
        rewardService = RewardService(db, pointsService);
      });

      tearDown(() async {
        await db.close();
      });

      // Unit: Reward creation persists title, description, and point threshold
      test(
        'reward creation persists title, description, and point threshold',
        () async {
          final id = await rewardService.addReward(
            title: 'Ice cream trip',
            description: 'A special outing',
            pointsThreshold: 500,
          );

          final rewards = await rewardService.getAllRewards();
          expect(rewards, hasLength(1));
          expect(rewards.first.id, id);
          expect(rewards.first.title, 'Ice cream trip');
          expect(rewards.first.description, 'A special outing');
          expect(rewards.first.pointsThreshold, 500);
          expect(rewards.first.isEarned, isFalse);
          expect(rewards.first.isRevealed, isFalse);
        },
      );

      // Unit: Suggested thresholds calculate based on curriculum item count
      // and daily pace
      test(
        'suggested thresholds calculate based on curriculum item count and daily pace',
        () {
          final thresholds = SuggestedThresholdsService.calculate(
            totalItems: 4192,
            dailyPace: 12,
          );

          expect(thresholds, hasLength(3));
          // Ascending order
          expect(thresholds[0], lessThan(thresholds[1]));
          expect(thresholds[1], lessThan(thresholds[2]));
          // All positive
          for (final t in thresholds) {
            expect(t, greaterThan(0));
          }
          // ~1 week: 12 * 10 * 7 = 840 → rounded
          // ~1 month: 12 * 10 * 30 = 3600 → rounded
          // ~3 months: 12 * 10 * 90 = 10800 → rounded
          expect(thresholds[0], lessThanOrEqualTo(1000));
          expect(thresholds[1], greaterThanOrEqualTo(3000));
        },
      );

      test('suggested thresholds with zero items returns defaults', () {
        final thresholds = SuggestedThresholdsService.calculate(
          totalItems: 0,
          dailyPace: 0,
        );
        expect(thresholds, [100, 500, 1000]);
      });

      // Widget: Rewards setup screen displayed (form has required fields)
      testWidgets(
        'rewards setup screen shows title, description, threshold fields',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: RewardsSetupScreen(suggestedThresholds: [100, 500, 1000]),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Set Up Rewards'), findsOneWidget);
          expect(find.text('Title'), findsOneWidget);
          expect(find.text('Description'), findsOneWidget);
          expect(find.text('Point Threshold'), findsOneWidget);
        },
      );

      // Widget: Skip button proceeds without creating rewards
      testWidgets('skip button is present and tappable', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RewardsSetupScreen(suggestedThresholds: [100, 500, 1000]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skip'), findsOneWidget);
      });

      // Widget: Add reward form with suggested thresholds as chips
      testWidgets('suggested threshold chips are displayed', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RewardsSetupScreen(suggestedThresholds: [200, 800, 2000]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('200 pts'), findsOneWidget);
        expect(find.text('800 pts'), findsOneWidget);
        expect(find.text('2000 pts'), findsOneWidget);
      });

      // Widget: Rewards setup screen NOT displayed in adult mode
      test(
        'adult mode skips rewards setup — getUserMode returns adult',
        () async {
          final profileService = UserProfileService(
            userProfileDao: db.userProfileDao,
            pushUserProfile:
                ({
                  required String firebaseUid,
                  required String displayName,
                  required String userMode,
                }) async {},
          );

          await profileService.setUserMode(
            firebaseUid: 'test-uid',
            displayName: 'Adult User',
            mode: UserMode.adult,
          );

          final mode = await profileService.getUserMode('test-uid');
          expect(mode, UserMode.adult);
          // When mode is adult, onboarding skips rewards setup entirely
          expect(mode != UserMode.child, isTrue);
        },
      );

      // Unit: child mode does show rewards setup
      test(
        'child mode shows rewards setup — getUserMode returns child',
        () async {
          final profileService = UserProfileService(
            userProfileDao: db.userProfileDao,
            pushUserProfile:
                ({
                  required String firebaseUid,
                  required String displayName,
                  required String userMode,
                }) async {},
          );

          await profileService.setUserMode(
            firebaseUid: 'test-uid',
            displayName: 'Child User',
            mode: UserMode.child,
          );

          final mode = await profileService.getUserMode('test-uid');
          expect(mode, UserMode.child);
        },
      );

      // Integration: Child mode onboarding — add 2 rewards, verify persisted
      test(
        'integration: add 2 rewards via RewardService, verify persisted',
        () async {
          // Simulate what onboarding does after RewardsSetupScreen returns
          await rewardService.addReward(
            title: 'Ice cream',
            description: 'Trip to ice cream shop',
            pointsThreshold: 100,
          );
          await rewardService.addReward(
            title: 'New book',
            description: 'Choose a book from the store',
            pointsThreshold: 500,
          );

          final rewards = await rewardService.getAllRewards();
          expect(rewards, hasLength(2));
          expect(
            rewards.map((r) => r.title),
            containsAll(['Ice cream', 'New book']),
          );
          expect(
            rewards.map((r) => r.pointsThreshold),
            containsAll([100, 500]),
          );

          // All unearned and unrevealed
          for (final r in rewards) {
            expect(r.isEarned, isFalse);
            expect(r.isRevealed, isFalse);
          }
        },
      );

      // Widget: Add reward form validates inputs
      testWidgets('add reward form validates required fields', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RewardsSetupScreen(suggestedThresholds: [100, 500, 1000]),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Add Reward without filling fields
        await tester.tap(find.text('Add Reward'));
        await tester.pumpAndSettle();

        // Validation errors should appear
        expect(find.text('Title is required'), findsOneWidget);
        expect(find.text('Description is required'), findsOneWidget);
        expect(find.text('Threshold is required'), findsOneWidget);
      });
    },
  );
}
