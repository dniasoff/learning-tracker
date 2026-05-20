/// Round-trip tests for DataExportImportService that insert real data
/// before exporting, then call importData() — covering the serialization
/// closures in exportData() and the import parsing in importData().
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late DataExportImportService service;

  setUp(() async {
    db = inMemoryDb();
    service = DataExportImportService(
      database: db,
      appVersionFetcher: () async => '1.0.0',
    );
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── exportData with real data ─────────────────────────────────────────────

  group('DataExportImportService.exportData — with data', () {
    test('exports curriculum track with all fields serialized', () async {
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final tracks = (data['curriculumTracks'] as List)
          .cast<Map<String, dynamic>>();

      expect(tracks, hasLength(1));
      expect(tracks.first['curriculumId'], 'mishnayos');
      expect(tracks.first['trackType'], 'personal');
      expect(tracks.first['isActive'], isTrue);
    });

    test('exports goal with all fields serialized', () async {
      // Need a track first.
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final goals = (data['goals'] as List).cast<Map<String, dynamic>>();

      expect(goals, hasLength(1));
      expect(goals.first['curriculumId'], 'mishnayos');
      expect(goals.first['profileId'], 1);
    });

    test('exports bookmark rows', () async {
      // Insert a track first (bookmark requires trackId).
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          sefariaRef: 'Berakhot.1.1',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final bookmarks = (data['bookmarks'] as List)
          .cast<Map<String, dynamic>>();

      expect(bookmarks, hasLength(1));
      expect(bookmarks.first['sefariaRef'], 'Berakhot.1.1');
    });

    test('exports learning order rows', () async {
      await db.learningOrderDao.insertLearningOrder(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final learningOrder = (data['learningOrder'] as List)
          .cast<Map<String, dynamic>>();

      expect(learningOrder, hasLength(1));
      expect(learningOrder.first['sefariaRef'], 'Berakhot');
    });

    test('exports streak rows', () async {
      await db.streakEventDao.upsertStreakByProfile(
        1,
        const StreakEventsCompanion(
          currentStreak: Value(5),
          maxStreak: Value(10),
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final streaks = (data['streaks'] as List).cast<Map<String, dynamic>>();

      expect(streaks, hasLength(1));
      expect(streaks.first['currentStreak'], 5);
      expect(streaks.first['maxStreak'], 10);
    });
  });

  // ── importData ────────────────────────────────────────────────────────────

  group('DataExportImportService.importData', () {
    /// Build a minimal valid import payload.
    String buildImportJson({
      List<Map<String, dynamic>> userProfiles = const [],
      List<Map<String, dynamic>> learnerProfiles = const [],
      List<Map<String, dynamic>> curriculumTracks = const [],
      List<Map<String, dynamic>> goals = const [],
      List<Map<String, dynamic>> completions = const [],
      List<Map<String, dynamic>> stageDefinitions = const [],
      List<Map<String, dynamic>> streaks = const [],
      List<Map<String, dynamic>> pointConfigs = const [],
      List<Map<String, dynamic>> bookmarks = const [],
      List<Map<String, dynamic>> learningOrder = const [],
    }) {
      return jsonEncode({
        'formatVersion': 'schemaV1',
        'exportedAt': '2026-01-01T00:00:00.000Z',
        'appVersion': '1.0.0',
        'userProfiles': userProfiles,
        'learnerProfiles': learnerProfiles,
        'curriculumTracks': curriculumTracks,
        'curriculumScopes': <dynamic>[],
        'profilePrograms': <dynamic>[],
        'stageDefinitions': stageDefinitions,
        'pointConfigs': pointConfigs,
        'studyDayConfigs': <dynamic>[],
        'completions': completions,
        'completionEvents': <dynamic>[],
        'dailyPlans': <dynamic>[],
        'learningLedger': <dynamic>[],
        'bookmarks': bookmarks,
        'learningOrder': learningOrder,
        'trackLearningOrder': <dynamic>[],
        'goals': goals,
        'streaks': streaks,
        'streakEvents': <dynamic>[],
      });
    }

    test('importData on empty payload clears DB and leaves it empty', () async {
      // Pre-insert a track so DB is not empty.
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await service.importData(buildImportJson());

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, isEmpty);
    });

    test('importData imports curriculum tracks', () async {
      final payload = buildImportJson(
        curriculumTracks: [
          {
            'id': 1,
            'profileId': 1,
            'curriculumId': 'mishnayos',
            'trackType': 'personal',
            'isActive': true,
            'activatedAt': '2026-01-01T00:00:00.000Z',
            'deactivatedAt': null,
            'paceResetDate': null,
            'deletedAt': null,
          },
        ],
      );

      await service.importData(payload);

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, hasLength(1));
      expect(tracks.first.curriculumId, 'mishnayos');
    });

    test('importData imports goals', () async {
      // First import a track (goals have trackId FK).
      final payload = buildImportJson(
        userProfiles: [
          {
            'id': 1,
            'displayName': 'Test',
            'tier': 'localBorn',
            'userMode': 'adult',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        learnerProfiles: [
          {
            'id': 1,
            'accountId': 1,
            'displayName': 'Test',
            'mode': 'adult',
            'avatarIndex': 0,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        curriculumTracks: [
          {
            'id': 1,
            'profileId': 1,
            'curriculumId': 'mishnayos',
            'trackType': 'personal',
            'isActive': true,
            'activatedAt': '2026-01-01T00:00:00.000Z',
            'deactivatedAt': null,
            'paceResetDate': null,
            'deletedAt': null,
          },
        ],
        goals: [
          {
            'id': 1,
            'profileId': 1,
            'curriculumId': 'mishnayos',
            'trackId': 1,
            'targetPercent': 100.0,
            'targetDate': null,
            'description': '',
            'dateType': 'gregorian',
            'goalType': 'deadline',
            'paceValue': null,
            'pacePeriod': null,
            'paceGranularity': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      );

      await service.importData(payload);

      final goals = await db.goalDao.getGoalsByProfile(1);
      expect(goals, hasLength(1));
      expect(goals.first.curriculumId, 'mishnayos');
    });

    test('importData imports bookmarks', () async {
      // Insert a track first so the bookmark FK is valid.
      final trackPayload = buildImportJson(
        userProfiles: [
          {
            'id': 1,
            'displayName': 'Test',
            'tier': 'localBorn',
            'userMode': 'adult',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        learnerProfiles: [
          {
            'id': 1,
            'accountId': 1,
            'displayName': 'Test',
            'mode': 'adult',
            'avatarIndex': 0,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        curriculumTracks: [
          {
            'id': 1,
            'profileId': 1,
            'curriculumId': 'mishnayos',
            'trackType': 'personal',
            'isActive': true,
            'activatedAt': '2026-01-01T00:00:00.000Z',
            'deactivatedAt': null,
            'paceResetDate': null,
            'deletedAt': null,
          },
        ],
        bookmarks: [
          {
            'id': 1,
            'profileId': 1,
            'curriculumId': 'mishnayos',
            'trackId': 1,
            'sefariaRef': 'Berakhot.1.1',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      );

      await service.importData(trackPayload);

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(1);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.sefariaRef, 'Berakhot.1.1');
    });

    test('importData imports learning order', () async {
      final payload = buildImportJson(
        learningOrder: [
          {
            'id': 1,
            'profileId': 1,
            'curriculumId': 'mishnayos',
            'sefariaRef': 'Berakhot',
            'userSortOrder': 0,
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      );

      await service.importData(payload);

      final orders = await db.learningOrderDao.getAllLearningOrders();
      expect(orders, hasLength(1));
      expect(orders.first.sefariaRef, 'Berakhot');
    });

    test('importData imports streaks', () async {
      final payload = buildImportJson(
        streaks: [
          {
            'id': 1,
            'profileId': 1,
            'currentStreak': 7,
            'maxStreak': 14,
            'lastCompletionDate': null,
            'graceUsedDate': null,
            'gracePeriodDays': 1,
          },
        ],
      );

      await service.importData(payload);

      final streak = await db.streakEventDao.getStreakByProfile(1);
      expect(streak, isNotNull);
      expect(streak!.currentStreak, 7);
      expect(streak.maxStreak, 14);
    });

    test(
      'importData is a no-op on invalid JSON (throws FormatException)',
      () async {
        expect(() => service.importData('not json'), throwsA(isA<Exception>()));
      },
    );

    test('round-trip: exportData → importData preserves track count', () async {
      // Insert a track.
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final jsonStr = await service.exportData();

      // Import into a fresh DB.
      final db2 = inMemoryDb();
      addTearDown(() => db2.close());
      final service2 = DataExportImportService(
        database: db2,
        appVersionFetcher: () async => '1.0.0',
      );

      await service2.importData(jsonStr);

      final tracks = await db2.trackDao.getAllForProfile(1);
      expect(tracks, hasLength(1));
      expect(tracks.first.curriculumId, 'mishnayos');
    });
  });
}
