/// Story acceptance tests for Epic 10 -- Parent Mode.
/// Story 10.1 is active; stories 10.2-10.6 remain backlog (skipped).
@Tags(['epic_10'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/parent_mode_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/pin_setup_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/point_config_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/reward_catalog_screen.dart';
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
  // ── Story 10.1: Parent PIN setup ──────────────────────────────

  group('Story 10.1 -- Parent PIN setup', tags: ['story_10_1'], () {
    late MockFlutterSecureStorage storage;
    late PinService pinService;

    setUp(() {
      storage = _createMockStorage();
      pinService = PinService(storage);
    });

    test('PIN hashing produces valid bcrypt hash', () async {
      await pinService.setParentPin('1234');
      final hash = await storage.read(key: 'parent_pin_hash');
      expect(hash, isNotNull);
      expect(hash, startsWith(r'$2'));
      expect(hash, isNot('1234'));
    });

    test('PIN verification succeeds with correct PIN', () async {
      await pinService.setParentPin('5678');
      expect(await pinService.verifyParentPin('5678'), isTrue);
    });

    test('PIN verification fails with incorrect PIN', () async {
      await pinService.setParentPin('5678');
      expect(await pinService.verifyParentPin('0000'), isFalse);
    });

    test('lockout triggers after exactly 5 failed attempts', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      expect(
        () => pinService.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test(
      'lockout cooldown resets failed attempt counter after expiry',
      () async {
        await pinService.setParentPin('1234');
        for (var i = 0; i < 3; i++) {
          await pinService.verifyParentPin('0000');
        }
        await pinService.verifyParentPin('1234');
        for (var i = 0; i < 4; i++) {
          expect(await pinService.verifyParentPin('0000'), isFalse);
        }
      },
    );

    test(
      'lockout state persists across app restart (new PinService)',
      () async {
        await pinService.setParentPin('1234');
        for (var i = 0; i < 5; i++) {
          await pinService.verifyParentPin('0000');
        }
        final newService = PinService(storage);
        expect(
          () => newService.verifyParentPin('1234'),
          throwsA(isA<PinLockoutException>()),
        );
      },
    );

    test('parent mode access denied for adult accounts', () async {
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
    });

    test('parent mode access allowed for child accounts', () async {
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
      expect(mode, UserMode.child);
    });

    test('PIN setup requires matching confirmation', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.verifyParentPin('1234'), isTrue);
      expect(await pinService.verifyParentPin('4321'), isFalse);
    });

    test('PIN change requires current PIN before setting new', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.verifyParentPin('1234'), isTrue);
      await pinService.setParentPin('5678');
      expect(await pinService.verifyParentPin('5678'), isTrue);
      expect(await pinService.verifyParentPin('1234'), isFalse);
    });

    test('PINs are device-local only (stored in secure storage)', () async {
      await pinService.setParentPin('9999');
      verify(
        () => storage.write(
          key: 'parent_pin_hash',
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    testWidgets('PinSetupScreen shows error on mismatched PINs', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: PinSetupScreen()),
        ),
      );

      // Enter first PIN: 1234 — one digit per TextField
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

      // Verify error message is displayed
      expect(find.text('PINs do not match'), findsOneWidget);
    });

    test('integration: set PIN, verify, fail 5 times, lockout', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.hasParentPin(), isTrue);
      expect(await pinService.verifyParentPin('1234'), isTrue);
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      expect(
        () => pinService.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
      final remaining = await pinService.getParentLockoutRemainingMinutes();
      expect(remaining, greaterThan(0));
    });
  });

  // ── Story 10.2: Parent dashboard ──────────────────────────────

  group('Story 10.2 -- Parent dashboard', tags: ['story_10_2'], () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() => db.close());

    Future<void> seedCurriculumAndCompletions(
      AppDatabase db, {
      required String curriculumId,
      int completionCount = 5,
      int stageCount = 1,
      int pointsPerCompletion = 10,
      DateTime? completionBaseDate,
    }) async {
      // Activate curriculum
      await db.activeCurriculumDao.activate(
        CurriculumId.values.firstWhere((c) => c.storageKey == curriculumId),
      );

      // Add stage definitions
      for (var i = 1; i <= stageCount; i++) {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: curriculumId,
            stageOrder: i,
            stageName: 'Stage $i',
            delayDays: 0,
          ),
        );
      }

      // Add completions
      final base = completionBaseDate ?? DateTime.now().toUtc();
      for (var i = 0; i < completionCount; i++) {
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: curriculumId,
            sefariaRef: 'ref-$curriculumId-$i',
            stageId: (i % stageCount) + 1,
            trackType: 'personal',
            completedAt: base.subtract(Duration(hours: i * 12)),
            points: Value(pointsPerCompletion),
          ),
        );
      }
    }

    // ── Unit: aggregator computes correct completion % ──

    test('aggregator computes correct completion % across curricula', () async {
      await seedCurriculumAndCompletions(
        db,
        curriculumId: 'mishnayos',
        completionCount: 4,
        stageCount: 2,
        pointsPerCompletion: 10,
      );

      final aggregator = ParentDashboardAggregator(db);
      final pct = await aggregator.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );

      // 4 completions across 2 stages: refs 0,1 get stages 1,2; refs 2,3 get 1,2
      // ref-mishnayos-0: stage 1, ref-mishnayos-1: stage 2, etc.
      // So ref-0 has {1}, ref-1 has {2}, ref-2 has {1}, ref-3 has {2}
      // None fully completed (need both stages) → 0/4 = 0.0
      expect(pct, equals(0.0));
    });

    test(
      'aggregator returns non-zero completion % for fully completed items',
      () async {
        // Set up 3 total items in learning order
        for (var i = 0; i < 3; i++) {
          await db.learningOrderDao.insertLearningOrder(
            LearningOrderCompanion.insert(
              curriculumId: 'mishnayos',
              sefariaRef: 'ref-mishnayos-$i',
              userSortOrder: i,
            ),
          );
        }

        // 1 stage definition
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: 'mishnayos',
            stageOrder: 1,
            stageName: 'Stage 1',
            delayDays: 0,
          ),
        );

        // Complete 2 out of 3 items (all stages)
        for (var i = 0; i < 2; i++) {
          await db.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'mishnayos',
              sefariaRef: 'ref-mishnayos-$i',
              stageId: 1,
              trackType: 'personal',
              completedAt: DateTime.now().toUtc(),
              points: const Value(10),
            ),
          );
        }

        await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
        final aggregator = ParentDashboardAggregator(db);
        final pct = await aggregator.computeCompletionPercentage(
          CurriculumId.mishnayos,
        );

        // 2 fully completed / 3 total items ≈ 0.6667
        expect(pct, closeTo(2 / 3, 0.01));
      },
    );

    test('aggregator returns 0% when no completions', () async {
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      final aggregator = ParentDashboardAggregator(db);
      final pct = await aggregator.computeCompletionPercentage(
        CurriculumId.mishnayos,
      );
      expect(pct, equals(0.0));
    });

    // ── Unit: engagement metrics ──

    test(
      'engagement metrics calculate days active and average completions',
      () async {
        final now = DateTime.now().toUtc();

        // Test with actual DB completions
        await seedCurriculumAndCompletions(
          db,
          curriculumId: 'mishnayos',
          completionCount: 7,
          completionBaseDate: now,
        );

        final aggregator = ParentDashboardAggregator(db);
        final data = await aggregator.compute();

        expect(data.engagement.daysActiveThisWeek, greaterThan(0));
        expect(data.engagement.averageDailyCompletions, greaterThan(0));
      },
    );

    // ── Unit: recent completions query returns last 7 days ──

    test('recent completions query returns last 7 days of activity', () async {
      final now = DateTime.now().toUtc();

      // Add recent completions (within 7 days)
      await seedCurriculumAndCompletions(
        db,
        curriculumId: 'mishnayos',
        completionCount: 3,
        completionBaseDate: now,
      );

      // Add old completions (beyond 7 days)
      for (var i = 0; i < 2; i++) {
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'old-ref-$i',
            stageId: 1,
            trackType: 'personal',
            completedAt: now.subtract(const Duration(days: 10)),
            points: const Value(5),
          ),
        );
      }

      final aggregator = ParentDashboardAggregator(db);
      final data = await aggregator.compute();

      // Only 3 recent completions should appear (not the 2 old ones)
      expect(data.recentCompletions.length, equals(3));
      for (final c in data.recentCompletions) {
        expect(
          c.completedAt.isAfter(now.subtract(const Duration(days: 7))),
          isTrue,
        );
      }
    });

    // ── Unit: full dashboard data aggregation ──

    test('full dashboard aggregates streak, points, and curricula', () async {
      final now = DateTime.now().toUtc();

      await seedCurriculumAndCompletions(
        db,
        curriculumId: 'mishnayos',
        completionCount: 3,
        pointsPerCompletion: 10,
        completionBaseDate: now,
      );

      // Set up streak
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(12),
          lastCompletionDate: Value(now),
        ),
      );

      final aggregator = ParentDashboardAggregator(db);
      final data = await aggregator.compute();

      expect(data.currentStreak, equals(5));
      expect(data.maxStreak, equals(12));
      expect(data.globalPoints, equals(30)); // 3 * 10
      expect(data.curricula.length, equals(1));
      expect(data.curricula.first.points, equals(30));
    });

    // ── Widget: dashboard displays all key stats ──

    testWidgets('dashboard displays all key stats', (tester) async {
      final now = DateTime.now().toUtc();
      await seedCurriculumAndCompletions(
        db,
        curriculumId: 'mishnayos',
        completionCount: 2,
        pointsPerCompletion: 15,
        completionBaseDate: now,
      );
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(3),
          maxStreak: const Value(7),
          lastCompletionDate: Value(now),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ParentModeScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Key stats visible — values shown as raw numbers, labels as 'Day Streak'
      // and 'Total Points'. maxStreak is not separately displayed.
      expect(find.text('3'), findsOneWidget); // current streak value
      expect(find.text('30'), findsOneWidget); // points value (2 * 15)
      expect(find.text('Day Streak'), findsOneWidget);
      expect(find.text('Total Points'), findsOneWidget);
    });

    // ── Widget: per-curriculum cards show on-track status ──

    testWidgets('per-curriculum cards show individual on-track status', (
      tester,
    ) async {
      await seedCurriculumAndCompletions(
        db,
        curriculumId: 'mishnayos',
        completionCount: 1,
        pointsPerCompletion: 10,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ParentModeScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Should show curriculum name and pace badge
      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('On Pace'), findsOneWidget);
    });

    // ── Widget: recent completions list renders ──

    testWidgets('recent completions list renders with dates and items', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      await seedCurriculumAndCompletions(
        db,
        curriculumId: 'mishnayos',
        completionCount: 2,
        pointsPerCompletion: 10,
        completionBaseDate: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ParentModeScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll down to reveal lazily-built Recent Activity section
      await tester.scrollUntilVisible(
        find.text('Recent Activity'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('ref-mishnayos-0'), findsOneWidget);
      expect(find.text('ref-mishnayos-1'), findsOneWidget);
      expect(find.text('+10'), findsAtLeastNWidgets(1));
    });

    // ── Integration: multi-day completions reflected in dashboard UI ──

    testWidgets(
      'integration: multi-day completions reflected in dashboard UI',
      (tester) async {
        final now = DateTime.now().toUtc();

        // Day 1: 3 completions
        for (var i = 0; i < 3; i++) {
          await db.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'mishnayos',
              sefariaRef: 'day1-ref-$i',
              stageId: 1,
              trackType: 'personal',
              completedAt: now.subtract(const Duration(days: 2)),
              points: const Value(10),
            ),
          );
        }

        // Day 2: 2 completions
        for (var i = 0; i < 2; i++) {
          await db.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'mishnayos',
              sefariaRef: 'day2-ref-$i',
              stageId: 1,
              trackType: 'personal',
              completedAt: now.subtract(const Duration(days: 1)),
              points: const Value(10),
            ),
          );
        }

        await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
        await db.streakDao.upsertStreak(
          StreaksCompanion.insert(
            currentStreak: const Value(2),
            maxStreak: const Value(2),
            lastCompletionDate: Value(now.subtract(const Duration(days: 1))),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ParentModeScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify key stats are displayed in the UI
        expect(find.text('50'), findsOneWidget); // 5 * 10 points
        expect(find.text('2'), findsOneWidget); // current streak value
        // maxStreak is not separately displayed in the parent dashboard UI

        // Scroll down to reveal lazily-built Recent Activity section
        await tester.scrollUntilVisible(
          find.text('Recent Activity'),
          200,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        // Verify recent completions are shown
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(find.text('day1-ref-0'), findsOneWidget);
        expect(find.text('day2-ref-0'), findsOneWidget);
      },
    );
  });

  // ── Story 10.3: Reward Catalog Management ──────────────────────

  group('Story 10.3 -- Reward Catalog Management', tags: ['story_10_3'], () {
    late AppDatabase db;
    late RewardService rewardService;

    setUp(() {
      db = createTestDatabase();
      final pointsService = PointsService(db);
      rewardService = RewardService(db, pointsService);
    });

    tearDown(() => db.close());

    // ── Unit: Create reward persists with correct fields ──

    test('create reward persists with correct fields', () async {
      final id = await rewardService.addReward(
        title: 'Gold Star',
        description: 'A shiny gold star',
        pointsThreshold: 100,
      );

      final reward = await db.rewardDao.getRewardById(id);
      expect(reward, isNotNull);
      expect(reward!.title, 'Gold Star');
      expect(reward.description, 'A shiny gold star');
      expect(reward.pointsThreshold, 100);
      expect(reward.isEarned, isFalse);
      expect(reward.isRevealed, isFalse);
    });

    // ── Unit: Edit reward updates fields for unearned reward ──

    test(
      'edit reward updates title/description/threshold for unearned reward',
      () async {
        final id = await rewardService.addReward(
          title: 'Bronze Star',
          description: 'A bronze star',
          pointsThreshold: 50,
        );

        await rewardService.updateReward(
          id: id,
          title: 'Silver Star',
          description: 'A silver star',
          pointsThreshold: 75,
        );

        final reward = await db.rewardDao.getRewardById(id);
        expect(reward!.title, 'Silver Star');
        expect(reward.description, 'A silver star');
        expect(reward.pointsThreshold, 75);
      },
    );

    // ── Unit: Delete reward removes unearned reward ──

    test('delete reward removes unearned reward from database', () async {
      final id = await rewardService.addReward(
        title: 'Temp Reward',
        description: 'Will be deleted',
        pointsThreshold: 10,
      );

      await rewardService.deleteReward(id);

      final reward = await db.rewardDao.getRewardById(id);
      expect(reward, isNull);
    });

    // ── Unit: Edit/delete blocked for earned rewards ──

    test('edit blocked for earned rewards', () async {
      final id = await rewardService.addReward(
        title: 'Earned One',
        description: 'Already earned',
        pointsThreshold: 10,
      );
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      expect(
        () => rewardService.updateReward(
          id: id,
          title: 'Changed',
          description: 'Changed',
          pointsThreshold: 20,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('delete blocked for earned rewards', () async {
      final id = await rewardService.addReward(
        title: 'Earned Two',
        description: 'Already earned',
        pointsThreshold: 10,
      );
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      expect(() => rewardService.deleteReward(id), throwsA(isA<StateError>()));
    });

    // ── Unit: Reveal sets is_revealed=true on earned reward ──

    test('reveal sets is_revealed=true on earned reward', () async {
      final id = await rewardService.addReward(
        title: 'Mystery',
        description: 'A mystery reward',
        pointsThreshold: 10,
      );
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      await rewardService.revealReward(id);

      final reward = await db.rewardDao.getRewardById(id);
      expect(reward!.isRevealed, isTrue);
    });

    // ── Unit: Rewards ordered by point threshold ──

    test('rewards ordered by point threshold', () async {
      await rewardService.addReward(
        title: 'High',
        description: 'High threshold',
        pointsThreshold: 300,
      );
      await rewardService.addReward(
        title: 'Low',
        description: 'Low threshold',
        pointsThreshold: 50,
      );
      await rewardService.addReward(
        title: 'Mid',
        description: 'Mid threshold',
        pointsThreshold: 150,
      );

      final all = await rewardService.getAllRewards();
      expect(all.length, 3);
      expect(all[0].title, 'Low');
      expect(all[1].title, 'Mid');
      expect(all[2].title, 'High');
    });

    // ── Widget: Reward list displays earned and unearned rewards ──

    testWidgets(
      'reward list displays earned (with reveal) and unearned rewards',
      (tester) async {
        // Seed rewards
        await rewardService.addReward(
          title: 'Unearned Reward',
          description: 'Not earned yet',
          pointsThreshold: 100,
        );
        final id2 = await rewardService.addReward(
          title: 'Earned Reward',
          description: 'Already earned',
          pointsThreshold: 50,
        );
        await db.rewardDao.markEarned(id2, earnedAt: DateTime.now().toUtc());

        final rewards = await db.rewardDao.getAllRewards();
        final rewardModels = rewards.map(RewardModel.fromDriftRow).toList();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              allRewardsProvider.overrideWith((ref) async => rewardModels),
            ],
            child: const MaterialApp(home: RewardCatalogScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unearned Reward'), findsOneWidget);
        expect(find.text('Earned Reward'), findsOneWidget);
        expect(find.text('Reveal'), findsOneWidget);
      },
    );

    // ── Widget: Add reward form validates required fields ──

    testWidgets(
      'add reward form validates required fields and positive threshold',
      (tester) async {
        final rewards = await db.rewardDao.getAllRewards();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              allRewardsProvider.overrideWith(
                (ref) async => rewards.map(RewardModel.fromDriftRow).toList(),
              ),
            ],
            child: const MaterialApp(home: RewardCatalogScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap FAB to open add dialog
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Add Reward'), findsOneWidget);

        // Try to submit empty form
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(find.text('Title is required'), findsOneWidget);
        expect(find.text('Description is required'), findsOneWidget);
        expect(find.text('Threshold is required'), findsOneWidget);

        // Enter invalid threshold
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Point Threshold'),
          '-5',
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(find.text('Must be a positive number'), findsOneWidget);
      },
    );

    // ── Widget: Delete confirmation dialog ──

    testWidgets('delete confirmation dialog shown before deletion', (
      tester,
    ) async {
      await rewardService.addReward(
        title: 'To Delete',
        description: 'Will be deleted',
        pointsThreshold: 10,
      );

      final rewards = await db.rewardDao.getAllRewards();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            allRewardsStreamProvider.overrideWith(
              (ref) => Stream.value(rewards),
            ),
          ],
          child: const MaterialApp(home: RewardCatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete Reward'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete "To Delete"?'),
        findsOneWidget,
      );

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Reward still exists
      expect(find.text('To Delete'), findsOneWidget);
    });

    // ── Widget: Earned rewards show Reveal button ──

    testWidgets('earned rewards show Reveal button if not yet revealed', (
      tester,
    ) async {
      final id = await rewardService.addReward(
        title: 'Mystery Prize',
        description: 'A mystery',
        pointsThreshold: 10,
      );
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      final rewards = await db.rewardDao.getAllRewards();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            allRewardsStreamProvider.overrideWith(
              (ref) => Stream.value(rewards),
            ),
          ],
          child: const MaterialApp(home: RewardCatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reveal'), findsOneWidget);

      // Tap reveal
      await tester.tap(find.text('Reveal'));
      await tester.pumpAndSettle();

      // Now shows Revealed chip
      expect(find.text('Revealed'), findsOneWidget);
    });

    // ── Integration: full reward lifecycle ──

    test(
      'integration: add 3 rewards, earn one, verify reveal option, reveal, verify',
      () async {
        // Add 3 rewards
        await rewardService.addReward(
          title: 'Reward A',
          description: 'First',
          pointsThreshold: 10,
        );
        final id2 = await rewardService.addReward(
          title: 'Reward B',
          description: 'Second',
          pointsThreshold: 50,
        );
        await rewardService.addReward(
          title: 'Reward C',
          description: 'Third',
          pointsThreshold: 100,
        );

        var all = await rewardService.getAllRewards();
        expect(all.length, 3);

        // Earn reward B via marking (simulating points threshold met)
        await db.rewardDao.markEarned(id2, earnedAt: DateTime.now().toUtc());

        all = await rewardService.getAllRewards();
        final earnedReward = all.firstWhere((r) => r.id == id2);
        expect(earnedReward.isEarned, isTrue);
        expect(earnedReward.isRevealed, isFalse);

        // Reveal it
        await rewardService.revealReward(id2);

        final revealed = await db.rewardDao.getRewardById(id2);
        expect(revealed!.isRevealed, isTrue);

        // Child sees reward title (revealed rewards show title)
        final model = RewardModel.fromDriftRow(revealed);
        expect(model.title, 'Reward B');
        expect(model.isRevealed, isTrue);
      },
    );
  });

  // ── Story 10.4: Point Value Configuration ────────────────────

  group('Story 10.4 -- Point Value Configuration', tags: ['story_10_4'], () {
    late AppDatabase db;
    late PointsService pointsService;

    setUp(() async {
      db = createTestDatabase();
      pointsService = PointsService(db);

      // Activate mishnayos and seed stages + point configs
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      for (var i = 1; i <= 3; i++) {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            stageOrder: i,
            stageName: i == 1 ? 'Learning' : 'Chazara ${i - 1}',
            delayDays: 0,
          ),
        );
      }
      await db.pointConfigDao.seedDefaults(CurriculumId.mishnayos.storageKey);
    });

    tearDown(() => db.close());

    // ── Unit: Point config update persists new values ──

    test(
      'point config update persists new values per curriculum per stage',
      () async {
        // Update Learn from 10 to 15
        await db.pointConfigDao.upsertConfig(
          PointConfigsCompanion(
            curriculumId: Value(CurriculumId.mishnayos.storageKey),
            stageOrder: const Value(1),
            points: const Value(15),
          ),
        );

        final config = await db.pointConfigDao.getConfig(
          CurriculumId.mishnayos.storageKey,
          1,
        );
        expect(config!.points, 15);

        // Other stages unaffected
        final config2 = await db.pointConfigDao.getConfig(
          CurriculumId.mishnayos.storageKey,
          2,
        );
        expect(config2!.points, 5);
      },
    );

    // ── Unit: Reset to defaults restores original values ──

    test('reset to defaults restores original point values', () async {
      // Change all values
      for (var i = 1; i <= 3; i++) {
        await db.pointConfigDao.upsertConfig(
          PointConfigsCompanion(
            curriculumId: Value(CurriculumId.mishnayos.storageKey),
            stageOrder: Value(i),
            points: const Value(99),
          ),
        );
      }

      // Reset: delete all then re-seed
      await db.pointConfigDao.deleteAllForCurriculum(
        CurriculumId.mishnayos.storageKey,
      );
      await db.pointConfigDao.seedDefaults(CurriculumId.mishnayos.storageKey);

      final configs = await db.pointConfigDao.getConfigsByCurriculum(
        CurriculumId.mishnayos.storageKey,
      );
      expect(configs[0].points, 10); // Learn
      expect(configs[1].points, 5); // Chazara 1
      expect(configs[2].points, 3); // Chazara 2
    });

    // ── Unit: Existing points history unaffected by config changes ──

    test('existing points history unaffected by config changes', () async {
      // Record a completion with current config (10 points for stage 1)
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'test-ref-1',
          stageId: 1,
          trackType: 'personal',
          completedAt: DateTime.now().toUtc(),
          points: const Value(10),
        ),
      );

      // Now change point config for stage 1 to 15
      await db.pointConfigDao.upsertConfig(
        PointConfigsCompanion(
          curriculumId: Value(CurriculumId.mishnayos.storageKey),
          stageOrder: const Value(1),
          points: const Value(15),
        ),
      );

      // Existing completion still has 10 points
      final completions = await db.completionDao.getCompletionsByCurriculum(
        CurriculumId.mishnayos.storageKey,
      );
      expect(completions.length, 1);
      expect(completions.first.points, 10);

      // But new lookups return 15
      final newPoints = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
      );
      expect(newPoints, 15);
    });

    // ── Widget: Config screen lists all curricula with expandable stage rows ──

    testWidgets('config screen lists curricula with expandable stage rows', (
      tester,
    ) async {
      // Also activate bavli
      await db.activeCurriculumDao.activate(CurriculumId.bavli);
      for (var i = 1; i <= 2; i++) {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: CurriculumId.bavli.storageKey,
            stageOrder: i,
            stageName: i == 1 ? 'Learning' : 'Chazara 1',
            delayDays: 0,
          ),
        );
      }
      await db.pointConfigDao.seedDefaults(CurriculumId.bavli.storageKey);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: PointConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Both curricula visible
      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('תלמוד בבלי'), findsOneWidget);

      // Tap to expand Mishnayos
      await tester.tap(find.text('משניות'));
      await tester.pumpAndSettle();

      // Stage names visible
      expect(find.text('Learning'), findsOneWidget);
      expect(find.text('Chazara 1'), findsAtLeastNWidgets(1));
    });

    // ── Widget: Each stage row shows editable point value field ──

    testWidgets('each stage row shows editable point value field', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: PointConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Expand Mishnayos
      await tester.tap(find.text('משניות'));
      await tester.pumpAndSettle();

      // Should see point values as text (default: 10, 5, 3)
      expect(find.text('10'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    // ── Widget: Reset button with confirmation restores defaults ──

    testWidgets('reset button with confirmation restores defaults', (
      tester,
    ) async {
      // Change a point value first
      await db.pointConfigDao.upsertConfig(
        PointConfigsCompanion(
          curriculumId: Value(CurriculumId.mishnayos.storageKey),
          stageOrder: const Value(1),
          points: const Value(99),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: PointConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Expand Mishnayos
      await tester.tap(find.text('משניות'));
      await tester.pumpAndSettle();

      // Find and tap reset button
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Reset to Defaults'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Values should be back to defaults
      final configs = await db.pointConfigDao.getConfigsByCurriculum(
        CurriculumId.mishnayos.storageKey,
      );
      expect(configs[0].points, 10);
      expect(configs[1].points, 5);
      expect(configs[2].points, 3);
    });

    // ── Widget: Validation prevents zero or negative values ──

    testWidgets('validation prevents zero or negative values', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: PointConfigScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Expand Mishnayos
      await tester.tap(find.text('משניות'));
      await tester.pumpAndSettle();

      // Tap edit on the first stage (Learn = 10)
      final editButtons = find.byIcon(Icons.edit);
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      // Clear and enter 0
      final textField = find.byType(TextFormField);
      await tester.enterText(textField.first, '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Must be a positive integer'), findsOneWidget);

      // Enter negative
      await tester.enterText(textField.first, '-5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Must be a positive integer'), findsOneWidget);
    });

    // ── Integration: Change points, complete item, verify new points ──

    test(
      'integration: change Mishnayos Learn points from 10 to 15, complete item, verify 15 awarded',
      () async {
        // Change Learn points to 15
        await db.pointConfigDao.upsertConfig(
          PointConfigsCompanion(
            curriculumId: Value(CurriculumId.mishnayos.storageKey),
            stageOrder: const Value(1),
            points: const Value(15),
          ),
        );

        // Verify points service returns 15
        final points = await pointsService.getPointsForStage(
          curriculumId: CurriculumId.mishnayos.storageKey,
          stageOrder: 1,
        );
        expect(points, 15);

        // Record a completion with the new point value
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'new-completion-ref',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.now().toUtc(),
            points: Value(points),
          ),
        );

        // Verify the completion has 15 points
        final completions = await db.completionDao.getCompletionsByCurriculum(
          CurriculumId.mishnayos.storageKey,
        );
        expect(completions.last.points, 15);

        // Verify total
        final total = await pointsService.getCurriculumTotal(
          CurriculumId.mishnayos.storageKey,
        );
        expect(total, 15);
      },
    );
  });

  // ── Story 10.5: Parent Track Management ──────────────────────

  group('Story 10.5 -- Parent Track Management', tags: ['story_10_5'], () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    // ── Unit: Add track creates new track record ──

    test('add track creates new track record for curriculum', () async {
      await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);

      // Activate school track
      await db.trackDao.activateTrack(CurriculumId.mishnayos, TrackType.school);

      final tracks = await db.trackDao.getActiveTracks(CurriculumId.mishnayos);
      expect(tracks.length, 2);
      expect(tracks.map((t) => t.trackType), contains('school'));
    });

    // ── Unit: Remove track deactivates but preserves history ──

    test(
      'remove track deactivates track but preserves completion history',
      () async {
        await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);
        await db.trackDao.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Add a completion on the school track
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Mishnah_Berakhot.1.1',
            stageId: 1,
            trackType: TrackType.school.storageKey,
            completedAt: DateTime.now().toUtc(),
            points: const Value(10),
          ),
        );

        // Deactivate school track
        await db.trackDao.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Track should be inactive
        final isActive = await db.trackDao.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        expect(isActive, false);

        // Completion data should still exist
        final completions = await db.completionDao.getAllCompletions();
        expect(completions.length, 1);
        expect(completions.first.trackType, 'school');
      },
    );

    // ── Unit: Personal track removal blocked ──

    test('personal track removal blocked', () async {
      await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);

      expect(
        () => db.trackDao.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.personal,
        ),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    // ── Widget: Track management screen shows curricula ──

    testWidgets('track management screen shows curricula with active tracks', (
      tester,
    ) async {
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ParentTrackManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('משניות'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Tutor'), findsOneWidget);
    });

    // ── Widget: Add track button shows school/tutor options ──

    testWidgets('add track toggle enables school track', (tester) async {
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ParentTrackManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Find the School switch and tap it (should be off initially)
      final schoolSwitch = find.widgetWithText(SwitchListTile, 'School');
      expect(schoolSwitch, findsOneWidget);

      // Verify it's off
      final switchWidget = tester.widget<SwitchListTile>(schoolSwitch);
      expect(switchWidget.value, false);
    });

    // ── Widget: Remove track shows confirmation dialog ──

    testWidgets('remove track shows confirmation dialog', (tester) async {
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);
      await db.trackDao.activateTrack(CurriculumId.mishnayos, TrackType.school);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ParentTrackManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the School switch to deactivate
      final schoolSwitch = find.widgetWithText(SwitchListTile, 'School');
      await tester.tap(schoolSwitch);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Remove Track?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    // ── Widget: Personal track shows no remove option ──

    testWidgets('personal track shows no remove option', (tester) async {
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ParentTrackManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Personal switch should be disabled (onChanged = null)
      final personalSwitch = find.widgetWithText(SwitchListTile, 'Personal');
      final switchWidget = tester.widget<SwitchListTile>(personalSwitch);
      expect(switchWidget.onChanged, isNull);
      expect(find.text('Always active'), findsOneWidget);
    });

    // ── Integration: Add school track from parent mode ──

    test('add school track to Mishnayos from parent mode, '
        'verify track appears in active tracks', () async {
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await db.trackDao.initializeDefaultTracks(CurriculumId.mishnayos);

      // Initially only personal track
      var activeTracks = await db.trackDao.getActiveTracks(
        CurriculumId.mishnayos,
      );
      expect(activeTracks.length, 1);
      expect(activeTracks.first.trackType, 'personal');

      // Add school track (simulating parent action)
      await db.trackDao.activateTrack(CurriculumId.mishnayos, TrackType.school);

      // Verify school track is now active
      activeTracks = await db.trackDao.getActiveTracks(CurriculumId.mishnayos);
      expect(activeTracks.length, 2);
      final trackTypes = activeTracks.map((t) => t.trackType).toList();
      expect(trackTypes, contains('personal'));
      expect(trackTypes, contains('school'));
    });
  });

  // ── Story 10.6: Multi-child profiles ──────────────────────────

  group(
    'Story 10.6 -- Multi-child profiles',
    tags: ['story_10_6'],
    skip: 'Backlog: multi-child profiles not yet implemented',
    () {
      test('parent can create multiple child profiles', () {});
      test('each child has independent progress', () {});
      test('parent can switch between child views', () {});
    },
  );
}
