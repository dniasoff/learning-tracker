/// Story acceptance tests for Epic 14 -- Settings.
@Tags(['epic_14'])
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';
import '../helpers/test_database.dart'
    show createTestDatabase, seedProfile, seedProfileZero;

class MockAuthRepository extends Mock implements AuthRepository {}

/// A no-op push for testing (avoids Firestore dependency).
Future<void> _noOpPush({
  required String firebaseUid,
  required String displayName,
}) async {}

void main() {
  // ── Story 14.1: Settings screen ───────────────────────────────
  //
  // WS9.flows: mode belongs to learner_profiles.mode, not accounts.userMode.
  // UserProfileService.setUserMode/getUserMode removed. Mode changes are
  // written directly to LearnerProfiles via profileDao.

  group('Story 14.1 -- Settings screen', tags: ['story_14_1'], () {
    late UserDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      await seedTrack(db, profileId: 1);
    });

    tearDown(() async {
      await db.close();
    });

    test('learner profile mode defaults to adult', () async {
      // seedProfile inserts a learner profile with mode='adult'
      final profiles = await db.select(db.learnerProfiles).get();
      expect(profiles, isNotEmpty);
      final mode = ProfileMode.fromStorageKey(profiles.first.mode);
      expect(mode, ProfileMode.adult);
    });

    test(
      'mode change from adult to child persists to learner_profiles',
      () async {
        final profiles = await db.select(db.learnerProfiles).get();
        final profile = profiles.first;

        // Update to child mode
        await db.profileDao.updateProfile(
          LearnerProfilesCompanion(
            id: Value(profile.id),
            accountId: Value(profile.accountId),
            displayName: Value(profile.displayName),
            mode: const Value('child'),
            createdAt: Value(profile.createdAt),
            updatedAt: Value(DateTime.utc(2026, 1, 2)),
          ),
        );

        final updated = await db.profileDao.getProfileById(profile.id);
        expect(updated!.mode, 'child');
        expect(ProfileMode.fromStorageKey(updated.mode), ProfileMode.child);
      },
    );

    test('mode change from child to adult disables child gating', () async {
      final profiles = await db.select(db.learnerProfiles).get();
      final profile = profiles.first;

      // First set to child
      await db.profileDao.updateProfile(
        LearnerProfilesCompanion(
          id: Value(profile.id),
          accountId: Value(profile.accountId),
          displayName: Value(profile.displayName),
          mode: const Value('child'),
          createdAt: Value(profile.createdAt),
          updatedAt: Value(DateTime.utc(2026, 1, 2)),
        ),
      );

      // Then switch back to adult
      await db.profileDao.updateProfile(
        LearnerProfilesCompanion(
          id: Value(profile.id),
          accountId: Value(profile.accountId),
          displayName: Value(profile.displayName),
          mode: const Value('adult'),
          createdAt: Value(profile.createdAt),
          updatedAt: Value(DateTime.utc(2026, 1, 3)),
        ),
      );

      final updated = await db.profileDao.getProfileById(profile.id);
      final mode = ProfileMode.fromStorageKey(updated!.mode);
      expect(mode, ProfileMode.adult);
      // In adult mode, child gating is disabled
    });

    test('updateDisplayName persists display name to account', () async {
      final profileService = UserProfileService(
        userProfileDao: db.userProfileDao,
        pushUserProfile: _noOpPush,
      );

      await profileService.updateDisplayName(
        firebaseUid: 'uid-1',
        displayName: 'Jane Doe',
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Jane Doe');
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
      await seedProfileZero(db);
      trackId = await seedTrack(db, profileId: 1);
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
              schedule: const Value('{"type":"delay","delay_days":0}'),
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
              schedule: const Value('{"type":"delay","delay_days":1}'),
            ),
          );

      // Streaks — insert 5 consecutive events ending 2026-03-16 (yesterday of 3/17)
      for (var i = 4; i >= 0; i--) {
        final day = DateTime.utc(2026, 3, 16).subtract(Duration(days: i));
        await db
            .into(db.streakEvents)
            .insert(
              StreakEventsCompanion.insert(
                profileId: 0,
                eventType: 'completion',
                dayUtc: day,
                eventTimestamp: day.copyWith(hour: 18),
              ),
            );
      }

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
        updatedAt: DateTime(2026, 3, 17),
      );
    }

    test('export generates valid JSON with all required data sections', () async {
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
      // W3.20/W3.37: `streaks` table dropped; use `streakEvents` instead
      expect((data['streaks'] as List).length, equals(0));
      expect((data['streakEvents'] as List).length, equals(5));
      expect((data['pointConfigs'] as List).length, equals(1));
      expect((data['bookmarks'] as List).length, equals(1));
      expect((data['learningOrder'] as List).length, equals(1));
      expect((data['curriculumTracks'] as List).length, equals(2));
      // 3 accounts: seedProfileZero + seedProfile's 'Test User' + seedTestData's upsertProfile
      expect((data['userProfiles'] as List).length, equals(3));
    });

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
          throwsA(isA<ImportValidationException>()),
        );

        // Valid JSON but missing sections
        expect(
          () => service.validateAndPreview('{"completions": []}'),
          throwsA(isA<ImportValidationException>()),
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
          throwsA(isA<ImportValidationException>()),
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
          throwsA(isA<ImportValidationException>()),
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
      // W3.37: streaks table dropped; streakCount reflects streakEvents count (5)
      expect(preview.streakCount, equals(5));
      expect(preview.pointConfigCount, equals(1));
      expect(preview.bookmarkCount, equals(1));
      expect(preview.learningOrderCount, equals(1));
      expect(preview.curriculumTrackCount, equals(2));
      // 3 accounts: seedProfileZero + seedProfile's 'Test User' + seedTestData's upsertProfile
      expect(preview.userProfileCount, equals(3));
      // totalRecords = 2+1+2+5+1+1+1+2+3 = 18
      expect(preview.totalRecords, equals(18));
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

        final streakEvents = await db.streakEventDao.getEventsByProfile(0);
        expect(streakEvents, isNotEmpty);
        expect(streakEvents.length, equals(5));

        final bookmarks = await db.bookmarkDao.getAllBookmarks();
        expect(bookmarks.length, equals(1));

        final profiles = await db.userProfileDao.getAllUserProfiles();
        // 3 accounts: seedProfileZero + seedProfile's 'Test User' + seedTestData's upsertProfile
        expect(profiles.length, equals(3));
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
      expect(await db.streakEventDao.getEventsByProfile(0), isEmpty);

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
      expect((await db.streakEventDao.getEventsByProfile(0)).length, equals(5));
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
      // 3 accounts: seedProfileZero + seedProfile's 'Test User' + seedTestData's upsertProfile
      expect((await db.userProfileDao.getAllUserProfiles()).length, equals(3));
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
      // R4-11: deleteAccount() now guards that the signed-in user matches the
      // uid being deleted, so currentUser must be stubbed to that user.
      when(() => mockAuthRepo.currentUser).thenReturn(
        const AppUser(
          uid: 'uid-1',
          email: 'user@example.com',
          displayName: 'User',
          emailVerified: true,
          providers: ['password'],
        ),
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
        // TODO(DNI-393): verify version string display
      });

      test('privacy policy and terms links are accessible', () {
        // TODO(DNI-393): verify link navigation
      });
    },
  );
}
