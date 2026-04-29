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
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/pin_setup_screen.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/point_config_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

/// Taller logical surface so scroll-heavy Point Settings fits in tests.
void _pointConfigLargeSurface(WidgetTester tester) {
  final view = tester.view;
  view.physicalSize = const Size(800, 1600);
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

/// Point config screen under l10n + DB, with sync off (no Firebase in tests).
Widget _pointConfigTestApp(UserDatabase db, Widget child) => ProviderScope(
  overrides: [
    userDatabaseProvider.overrideWithValue(db),
    syncEngineProvider.overrideWithValue(null),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  ),
);

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
      await _insertTrack(db);
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          email: 'adult@test.local',
          firebaseUid: const Value('uid-adult'),
          tier: 'cloudBorn',
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
      await _insertTrack(db);
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          email: 'child@test.local',
          firebaseUid: const Value('uid-child'),
          tier: 'cloudBorn',
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
    late UserDatabase db;
    late int trackId;

    setUp(() async {
      db = createTestDatabase();
      trackId = await _insertTrack(db);
    });

    tearDown(() => db.close());

    Future<void> seedCurriculumAndCompletions(
      UserDatabase db, {
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
            trackId: trackId,
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
            trackId: trackId,
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
            trackId: trackId,
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
              trackId: trackId,
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
            trackId: trackId,
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
  });

  // ── Story 10.4: Point Value Configuration ────────────────────

  group('Story 10.4 -- Point Value Configuration', tags: ['story_10_4'], () {
    const testProfileId = 0;
    late UserDatabase db;
    late int trackId;
    late PointsService pointsService;

    setUp(() async {
      db = createTestDatabase();
      trackId = await _insertTrack(db);
      pointsService = PointsService(db, profileId: testProfileId);

      // Activate mishnayos and seed stages + point configs
      await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
      for (var i = 1; i <= 3; i++) {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            stageOrder: i,
            stageName: i == 1 ? 'Learning' : 'Chazara ${i - 1}',
            delayDays: 0,
          ),
        );
      }
      await db.pointConfigDao.seedDefaults(
        CurriculumId.mishnayos.storageKey,
        trackId,
        profileId: testProfileId,
      );
    });

    tearDown(() => db.close());

    // ── Unit: Point config update persists new values ──

    test(
      'point config update persists new values per curriculum per stage',
      () async {
        // Update Learn from 10 to 15
        await db.pointConfigDao.upsertConfig(
          PointConfigsCompanion(
            profileId: const Value(testProfileId),
            curriculumId: Value(CurriculumId.mishnayos.storageKey),
            trackId: Value(trackId),
            stageOrder: const Value(1),
            points: const Value(15),
          ),
        );

        final config = await db.pointConfigDao.getConfig(
          CurriculumId.mishnayos.storageKey,
          1,
          profileId: testProfileId,
          trackId: trackId,
        );
        expect(config!.points, 15);

        // Other stages unaffected
        final config2 = await db.pointConfigDao.getConfig(
          CurriculumId.mishnayos.storageKey,
          2,
          profileId: testProfileId,
          trackId: trackId,
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
            profileId: const Value(testProfileId),
            curriculumId: Value(CurriculumId.mishnayos.storageKey),
            trackId: Value(trackId),
            stageOrder: Value(i),
            points: const Value(99),
          ),
        );
      }

      // Reset: delete all then re-seed
      await db.pointConfigDao.deleteAllForCurriculum(
        CurriculumId.mishnayos.storageKey,
        profileId: testProfileId,
      );
      await db.pointConfigDao.seedDefaults(
        CurriculumId.mishnayos.storageKey,
        trackId,
        profileId: testProfileId,
      );

      final configs = await db.pointConfigDao.getConfigsByCurriculum(
        CurriculumId.mishnayos.storageKey,
        profileId: testProfileId,
        trackId: trackId,
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
          trackId: trackId,
          completedAt: DateTime.now().toUtc(),
          points: const Value(10),
        ),
      );

      // Now change point config for stage 1 to 15
      await db.pointConfigDao.upsertConfig(
        PointConfigsCompanion(
          profileId: const Value(testProfileId),
          curriculumId: Value(CurriculumId.mishnayos.storageKey),
          trackId: Value(trackId),
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
        trackId: trackId,
      );
      expect(newPoints, 15);
    });

    // ── Widget: Config screen lists all curricula with expandable stage rows ──

    testWidgets('config screen lists active curricula with primary stage points', (
      tester,
    ) async {
      _pointConfigLargeSurface(tester);
      // Second active track (Bavli) with its own stages and point configs
      await db.activeCurriculumDao.activate(CurriculumId.bavli);
      final bavliTrackRow = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              curriculumId: CurriculumId.bavli.storageKey,
              trackType: 'personal',
              activatedAt: DateTime.now(),
            ),
          );
      final bavliTrackId = bavliTrackRow.id;
      for (var i = 1; i <= 2; i++) {
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: CurriculumId.bavli.storageKey,
            trackId: bavliTrackId,
            stageOrder: i,
            stageName: i == 1 ? 'Learning' : 'Chazara 1',
            delayDays: 0,
          ),
        );
      }
      await db.pointConfigDao.seedDefaults(
        CurriculumId.bavli.storageKey,
        bavliTrackId,
        profileId: testProfileId,
      );

      await tester.pumpWidget(
        _pointConfigTestApp(db, const PointConfigScreen()),
      );
      await tester.pumpAndSettle();

      // Both curricula visible (English titles + Hebrew subtitles).
      expect(find.text('Mishnayos', skipOffstage: false), findsOneWidget);
      expect(
        find.textContaining('תלמוד בבלי', skipOffstage: false),
        findsOneWidget,
      );

      // Primary (lowest stage order) label and default learn points (10).
      expect(find.textContaining('Learning', skipOffstage: false), findsWidgets);
      expect(find.text('10', skipOffstage: false), findsWidgets);
    });

    // ── Widget: Primary stepper shows learn-stage points ──

    testWidgets('primary stepper shows learn-stage point value', (
      tester,
    ) async {
      _pointConfigLargeSurface(tester);
      await tester.pumpWidget(
        _pointConfigTestApp(db, const PointConfigScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('10', skipOffstage: false), findsWidgets);
    });

    // ── Widget: Primary points cannot go below 1 ──

    testWidgets('primary stepper does not go below 1', (tester) async {
      _pointConfigLargeSurface(tester);
      await tester.pumpWidget(
        _pointConfigTestApp(db, const PointConfigScreen()),
      );
      await tester.pumpAndSettle();

      final minus = find.byIcon(Icons.remove, skipOffstage: false);
      for (var i = 0; i < 15; i++) {
        await tester.tap(minus.first);
        await tester.pumpAndSettle();
      }
      expect(find.text('1', skipOffstage: false), findsWidgets);
    });

    // ── Integration: Change points, complete item, verify new points ──

    test(
      'integration: change Mishnayos Learn points from 10 to 15, complete item, verify 15 awarded',
      () async {
        // Change Learn points to 15
        await db.pointConfigDao.upsertConfig(
          PointConfigsCompanion(
            profileId: const Value(testProfileId),
            curriculumId: Value(CurriculumId.mishnayos.storageKey),
            trackId: Value(trackId),
            stageOrder: const Value(1),
            points: const Value(15),
          ),
        );

        // Verify points service returns 15
        final points = await pointsService.getPointsForStage(
          curriculumId: CurriculumId.mishnayos.storageKey,
          stageOrder: 1,
          trackId: trackId,
        );
        expect(points, 15);

        // Record a completion with the new point value
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'new-completion-ref',
            stageId: 1,
            trackType: 'personal',
            trackId: trackId,
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
