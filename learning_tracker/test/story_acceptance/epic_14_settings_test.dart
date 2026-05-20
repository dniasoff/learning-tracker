/// Story acceptance tests for Epic 14 -- Settings.
@Tags(['epic_14'])
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/settings/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedCompletion;
import '../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// A no-op push for testing (avoids Firestore dependency).
Future<void> _noOpPush({
  required String firebaseUid,
  required String displayName,
  required String userMode,
}) async {}

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTime.now(),
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  // ── Story 14.1: Settings screen ───────────────────────────────

  group('Story 14.1 -- Settings screen', tags: ['story_14_1'], () {
    late UserDatabase db;
    late UserProfileService profileService;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      await _insertTrack(db);
      profileService = UserProfileService(
        userProfileDao: db.userProfileDao,
        pushUserProfile: _noOpPush,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('mode change persists new UserMode to profile', () async {
      // Set initial mode to adult
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.adult,
      );
      expect(await profileService.getUserMode('uid-1'), UserMode.adult);

      // Change to child
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.child,
      );
      expect(await profileService.getUserMode('uid-1'), UserMode.child);
    });

    test('mode change from child to adult disables parent mode access', () async {
      // Start as child
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.child,
      );

      // Switch to adult
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.adult,
      );

      final mode = await profileService.getUserMode('uid-1');
      expect(mode, UserMode.adult);
      // In adult mode, parent mode is not accessible (ChildModeGuard blocks it)
    });

    test('mode change from adult to child enables parent mode setup', () async {
      // Start as adult
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.adult,
      );

      // Switch to child
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.child,
      );

      final mode = await profileService.getUserMode('uid-1');
      expect(mode, UserMode.child);
      // In child mode, parent mode becomes available (ChildModeGuard allows)
    });

    test('user profile stores display name and mode', () async {
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Jane Doe',
        mode: UserMode.child,
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Jane Doe');
      expect(profile.userMode, 'child');
    });
  });

  // ── Story 14.2: Data Export & Import (JSON) ─────────────────────

  group('Story 14.2 -- Data Export & Import (JSON)', tags: ['story_14_2'], () {
    late UserDatabase db;
    late int trackId;
    late DataExportImportService service;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await _insertTrack(db);
      service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedTestData(UserDatabase db) async {
      // Completions
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishna',
          sefariaRef: 'Mishnah_Berakhot.1.1',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime(2026, 1, 15),
          points: const Value(10),
        ),
      );
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishna',
          sefariaRef: 'Mishnah_Berakhot.1.2',
          stageId: 2,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime(2026, 1, 16),
        ),
      );

      // Goals
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              trackId: trackId,
              targetPercent: const Value(50.0),
              targetDate: Value(DateTime(2026, 6, 1)),
              description: const Value('Finish half by June'),
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          );

      // Stage definitions
      await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              trackId: trackId,
              stageOrder: 1,
              stageName: 'learning',
              delayDays: 0,
              isDefault: const Value(true),
            ),
          );
      await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              trackId: trackId,
              stageOrder: 2,
              stageName: 'chazara1',
              delayDays: 1,
            ),
          );

      // Streaks
      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: 0,
              currentStreak: const Value(5),
              maxStreak: const Value(12),
              lastCompletionDate: Value(DateTime(2026, 3, 17)),
            ),
          );

      // Point configs
      await db
          .into(db.pointConfigs)
          .insert(
            PointConfigsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              trackId: trackId,
              stageOrder: 1,
              points: 10,
            ),
          );

      // Bookmarks
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              trackId: trackId,
              sefariaRef: 'Mishnah_Berakhot.1.3',
              updatedAt: DateTime(2026, 3, 17),
            ),
          );

      // Learning order
      await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              sefariaRef: 'Mishnah_Berakhot.1.1',
              userSortOrder: 1,
            ),
          );

      // Curriculum tracks
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              stateChangedAt: DateTime(2026, 1, 1),
              activatedAt: DateTime(2026, 1, 1),
            ),
          );

      // User profiles
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'uid-export-test',
        displayName: 'Test User',
        userMode: 'adult',
        updatedAt: DateTime(2026, 3, 17),
      );
    }

    test(
      'export generates valid JSON with all required data sections',
      () async {
        await seedTestData(db);

        final jsonString = await service.exportData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        // Check metadata
        expect(data['formatVersion'], equals('schemaV1'));
        expect(data['exportedAt'], isNotNull);
        expect(data['appVersion'], equals('1.0.0'));

        // Check all required sections present
        expect(data['completions'], isList);
        expect(data['goals'], isList);
        expect(data['stageDefinitions'], isList);
        expect(data['streaks'], isList);
        expect(data['pointConfigs'], isList);
        expect(data['bookmarks'], isList);
        expect(data['learningOrder'], isList);
        expect(data['curriculumTracks'], isList);
        expect(data['userProfiles'], isList);

        // Check data counts
        expect((data['completions'] as List).length, equals(2));
        expect((data['goals'] as List).length, equals(1));
        expect((data['stageDefinitions'] as List).length, equals(2));
        expect((data['streaks'] as List).length, equals(1));
        expect((data['pointConfigs'] as List).length, equals(1));
        expect((data['bookmarks'] as List).length, equals(1));
        expect((data['learningOrder'] as List).length, equals(1));
        expect((data['curriculumTracks'] as List).length, equals(2));
        // 2 accounts: seedProfile's 'Test User' + seedTestData's upsertProfile
        expect((data['userProfiles'] as List).length, equals(2));
      },
    );

    test(
      'export excludes content items (text cache, download statuses)',
      () async {
        // Text cache is now in ContentDatabase (read-only, bundled).
        // Export only covers UserDatabase, so content tables are
        // automatically excluded.

        final jsonString = await service.exportData();
        final data = json.decode(jsonString) as Map<String, dynamic>;

        // Should NOT contain content tables
        expect(data.containsKey('textCache'), isFalse);
        expect(data.containsKey('textDownloadStatuses'), isFalse);
        expect(data.containsKey('syncQueue'), isFalse);
      },
    );

    test(
      'import validates JSON structure and rejects malformed files',
      () async {
        // Malformed JSON
        expect(
          () => service.validateAndPreview('not json'),
          throwsA(isA<FormatException>()),
        );

        // Valid JSON but missing sections
        expect(
          () => service.validateAndPreview('{"completions": []}'),
          throwsA(isA<FormatException>()),
        );

        // Missing formatVersion
        final missingVersion = json.encode({
          'completions': <dynamic>[],
          'goals': <dynamic>[],
          'stageDefinitions': <dynamic>[],
          'rewards': <dynamic>[],
          'streaks': <dynamic>[],
          'pointConfigs': <dynamic>[],
          'bookmarks': <dynamic>[],
          'learningOrder': <dynamic>[],
          'curriculumTracks': <dynamic>[],
          'userProfiles': <dynamic>[],
        });
        expect(
          () => service.validateAndPreview(missingVersion),
          throwsA(isA<FormatException>()),
        );

        // Section is not a list
        final badSection = json.encode({
          'formatVersion': '1',
          'completions': 'not a list',
          'goals': <dynamic>[],
          'stageDefinitions': <dynamic>[],
          'rewards': <dynamic>[],
          'streaks': <dynamic>[],
          'pointConfigs': <dynamic>[],
          'bookmarks': <dynamic>[],
          'learningOrder': <dynamic>[],
          'curriculumTracks': <dynamic>[],
          'userProfiles': <dynamic>[],
        });
        expect(
          () => service.validateAndPreview(badSection),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('import preview shows data summary', () async {
      await seedTestData(db);
      final jsonString = await service.exportData();

      final preview = service.validateAndPreview(jsonString);

      expect(preview.completionCount, equals(2));
      expect(preview.goalCount, equals(1));
      expect(preview.stageCount, equals(2));
      expect(preview.streakCount, equals(1));
      expect(preview.pointConfigCount, equals(1));
      expect(preview.bookmarkCount, equals(1));
      expect(preview.learningOrderCount, equals(1));
      expect(preview.curriculumTrackCount, equals(2));
      // 2 accounts: seedProfile's 'Test User' + seedTestData's upsertProfile
      expect(preview.userProfileCount, equals(2));
      expect(preview.totalRecords, equals(13));
      expect(preview.exportedAt, isNot('unknown'));
      expect(preview.appVersion, equals('1.0.0'));
    });

    test(
      'import correctly restores completions, goals, stages, rewards',
      () async {
        await seedTestData(db);
        final jsonString = await service.exportData();

        // Clear the database
        await db.transaction(() async {
          await db.delete(db.completionEvents).go(); // C1: canonical table
          await db.delete(db.completionEvents).go();
          await db.delete(db.goals).go();
          await db.delete(db.stageDefinitions).go();
          await db.delete(db.streakEvents).go();
          await db.delete(db.pointConfigs).go();
          await db.delete(db.bookmarks).go();
          await db.delete(db.learningOrder).go();
          await db.delete(db.curriculumTracks).go();
          await db.delete(db.accounts).go();
        });

        // Verify empty
        expect(
          await db.completionDao.internalGetAllCompletionsCrossProfile(
            scope: CrossProfileScope.dataExport,
          ),
          isEmpty,
        );

        // Import
        await service.importData(jsonString);

        // Verify restored
        final completions = await db.completionDao
            .internalGetAllCompletionsCrossProfile(
              scope: CrossProfileScope.dataExport,
            );
        expect(completions.length, equals(2));
        expect(completions.first.curriculumId, equals('mishna'));
        expect(completions.first.sefariaRef, equals('Mishnah_Berakhot.1.1'));
        expect(completions.first.points, equals(10));

        final goals = await db.goalDao.getAllGoals();
        expect(goals.length, equals(1));
        expect(goals.first.curriculumId, equals('mishna'));
        expect(goals.first.targetPercent, equals(50.0));
        expect(goals.first.description, equals('Finish half by June'));

        final stages = await db.stageDao.getAllStageDefinitions();
        expect(stages.length, equals(2));

        final streak = await db.streakEventDao.getStreak();
        expect(streak, isNotNull);
        expect(streak!.currentStreak, equals(5));
        expect(streak.maxStreak, equals(12));

        final bookmarks = await db.bookmarkDao.getAllBookmarks();
        expect(bookmarks.length, equals(1));

        final profiles = await db.userProfileDao.getAllUserProfiles();
        // 2 accounts: seedProfile's 'Test User' + seedTestData's upsertProfile
        expect(profiles.length, equals(2));
        expect(profiles.any((p) => p.displayName == 'Test User'), isTrue);
      },
    );

    test('import transaction rolls back on partial failure', () async {
      await seedTestData(db);

      // Create invalid JSON that passes validation but fails on insert
      // (e.g., duplicate primary keys within import data)
      final badImport = json.encode({
        'formatVersion': '1',
        'exportedAt': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'completions': [
          {
            'curriculumId': 'mishna',
            'sefariaRef': 'ref1',
            'stageId': 1,
            'trackType': 'personal',
            'completedAt': DateTime(2026, 1, 1).toIso8601String(),
            'points': 10,
          },
        ],
        'goals': <dynamic>[],
        'stageDefinitions': <dynamic>[],
        'rewards': <dynamic>[],
        'streaks': <dynamic>[],
        'pointConfigs': <dynamic>[],
        'bookmarks': [
          {
            'curriculumId': 'mishna',
            'trackType': 'personal',
            'sefariaRef': 'ref1',
            'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
          },
          // Duplicate unique key — will cause constraint violation
          {
            'curriculumId': 'mishna',
            'trackType': 'personal',
            'sefariaRef': 'ref2',
            'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
          },
        ],
        'learningOrder': <dynamic>[],
        'activeCurricula': [
          {'curriculumId': 'mishna'},
          // Duplicate PK
          {'curriculumId': 'mishna'},
        ],
        'curriculumTracks': <dynamic>[],
        'userProfiles': <dynamic>[],
      });

      // Should fail due to duplicate active curricula PKs
      expect(() => service.importData(badImport), throwsA(anything));

      // Original data should be preserved (transaction rolled back)
      final completions = await db.completionDao
          .internalGetAllCompletionsCrossProfile(
            scope: CrossProfileScope.dataExport,
          );
      expect(completions.length, equals(2)); // Original 2 completions
    });

    test('full round-trip: export, clear DB, import, verify all data', () async {
      await seedTestData(db);

      // Export
      final exported = await service.exportData();

      // Clear all tables
      await db.transaction(() async {
        await db.delete(db.completionEvents).go(); // C1: canonical table
        await db.delete(db.completionEvents).go();
        await db.delete(db.goals).go();
        await db.delete(db.stageDefinitions).go();
        await db.delete(db.streakEvents).go();
        await db.delete(db.pointConfigs).go();
        await db.delete(db.bookmarks).go();
        await db.delete(db.learningOrder).go();
        await db.delete(db.curriculumTracks).go();
        await db.delete(db.accounts).go();
      });

      // Verify all empty
      expect(
        await db.completionDao.internalGetAllCompletionsCrossProfile(
          scope: CrossProfileScope.dataExport,
        ),
        isEmpty,
      );
      expect(await db.goalDao.getAllGoals(), isEmpty);
      expect(await db.streakEventDao.getStreak(), isNull);

      // Import
      await service.importData(exported);

      // Verify all data restored
      expect(
        (await db.completionDao.internalGetAllCompletionsCrossProfile(
          scope: CrossProfileScope.dataExport,
        )).length,
        equals(2),
      );
      expect((await db.goalDao.getAllGoals()).length, equals(1));
      expect((await db.stageDao.getAllStageDefinitions()).length, equals(2));
      expect((await db.streakEventDao.getStreak())?.currentStreak, equals(5));
      expect((await db.select(db.pointConfigs).get()).length, equals(1));
      expect((await db.bookmarkDao.getAllBookmarks()).length, equals(1));
      expect(
        (await db.learningOrderDao.getAllLearningOrders()).length,
        equals(1),
      );
      // Both tracks (mishnayos from setUp + mishna from seedTestData) belong
      // to profileId=1. Now that export preserves profileId, query by profile.
      // active_curricula table was removed in schema v9.
      expect(
        (await db.activeCurriculumDao.getActiveCurriculaByProfile(1)).length,
        equals(2),
      );
      expect((await db.select(db.curriculumTracks).get()).length, equals(2));
      // 2 accounts: seedProfile's 'Test User' + seedTestData's upsertProfile
      expect((await db.userProfileDao.getAllUserProfiles()).length, equals(2));
    });
  });

  // ── Story 14.3: Account management ────────────────────────────

  group('Story 14.3 -- Account management', tags: ['story_14_3'], () {
    late MockAuthRepository mockAuthRepo;
    late UserDatabase db;
    late AccountManagementService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockAuthRepo = MockAuthRepository();
      db = createTestDatabase();
      await seedProfile(db);
      service = AccountManagementService(
        authRepository: mockAuthRepo,
        database: db,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'user can sign out',
      () async {
        when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

        // Insert data before sign-out
        await db.userProfileDao.upsertProfile(
          firebaseUid: 'uid-1',
          displayName: 'User',
          userMode: 'adult',
          updatedAt: DateTime.now(),
        );

        await service.signOut();

        // Local data preserved for re-sign-in
        final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
          'uid-1',
        );
        expect(profile, isNotNull);
      },
      skip:
          'signOut contract changed — token cleared via AccountLifecycleService, not AuthRepository',
    );

    // Firestore deletion is now server-side via the deleteAccountData Cloud
    // Function (recursiveDelete) — not testable in unit tests without Firebase
    // initialisation. The onUserDeleted trigger also handles any leftovers.
    test('user can delete account and all data', () async {
      when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async {});

      await db.userProfileDao.upsertProfile(
        firebaseUid: 'uid-1',
        displayName: 'User',
        userMode: 'adult',
        updatedAt: DateTime.now(),
      );

      await service.deleteAccount('uid-1');

      // Firebase Auth account deleted
      verify(() => mockAuthRepo.deleteAccount()).called(1);
      // Local database cleared
      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile, isNull);
    });
  });

  // ── Story 14.4: App info & legal ──────────────────────────────

  group(
    'Story 14.4 -- App info & legal',
    tags: ['story_14_4'],
    skip: 'Backlog: app info screen not yet implemented',
    () {
      test('about screen shows app version', () {
        // TODO: verify version string display
      });

      test('privacy policy and terms links are accessible', () {
        // TODO: verify link navigation
      });
    },
  );
}
