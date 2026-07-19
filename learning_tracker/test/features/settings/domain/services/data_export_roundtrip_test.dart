/// Round-trip tests for DataExportImportService that insert real data
/// before exporting, then call importData() — covering the serialization
/// closures in exportData() and the import parsing in importData().
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/data_export_fixtures.dart';
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
      // W3.28: trackType removed; state replaces isActive+deactivatedAt.
      expect(tracks.first['state'], 'active');
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

    test(
      'exports streak_events rows (streaks table dropped in W3.20)',
      () async {
        // W3.37: streak state is derived from streak_events; seed one event.
        final now = DateTime.utc(2026, 3, 20);
        await db.streakEventDao.appendEvent(
          StreakEventsCompanion.insert(
            profileId: 1,
            eventType: 'completion',
            dayUtc: now,
            eventTimestamp: now,
          ),
        );

        final data =
            jsonDecode(await service.exportData()) as Map<String, dynamic>;
        // streaks is always empty in W3.20+ — events are in streakEvents.
        final streaks = (data['streaks'] as List).cast<Map<String, dynamic>>();
        expect(streaks, isEmpty);

        final streakEvents = (data['streakEvents'] as List)
            .cast<Map<String, dynamic>>();
        expect(streakEvents, hasLength(1));
        expect(streakEvents.first['eventType'], 'completion');
      },
    );
  });

  // ── importData ────────────────────────────────────────────────────────────

  group('DataExportImportService.importData', () {
    /// Build a minimal valid import payload as a JSON string.
    ///
    /// Thin wrapper over the shared [exportPayloadMap] fixture
    /// (AUD-t-settings-08) restricted to the sections this file's tests
    /// populate.
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
    }) => jsonEncode(
      exportPayloadMap(
        userProfiles: userProfiles,
        learnerProfiles: learnerProfiles,
        curriculumTracks: curriculumTracks,
        stageDefinitions: stageDefinitions,
        pointConfigs: pointConfigs,
        completions: completions,
        bookmarks: bookmarks,
        learningOrder: learningOrder,
        goals: goals,
        streaks: streaks,
      ),
    );

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

      // AUD-settings-03: clears are scoped to the profiles/accounts present
      // in the payload — include profile 1 (seeded via seedProfile in
      // setUp) so it's in scope, with otherwise-empty data sections.
      await service.importData(
        buildImportJson(
          userProfiles: [userProfileMap()],
          learnerProfiles: [learnerProfileMap()],
        ),
      );

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, isEmpty);
    });

    test('importData imports curriculum tracks', () async {
      final payload = buildImportJson(
        curriculumTracks: [curriculumTrackMap(curriculumId: 'mishnayos')],
      );

      await service.importData(payload);

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, hasLength(1));
      expect(tracks.first.curriculumId, 'mishnayos');
    });

    test('importData imports goals', () async {
      // First import a track (goals have trackId FK).
      final payload = buildImportJson(
        userProfiles: [userProfileMap(displayName: 'Test')],
        learnerProfiles: [learnerProfileMap(displayName: 'Test')],
        curriculumTracks: [curriculumTrackMap(curriculumId: 'mishnayos')],
        goals: [goalMap(curriculumId: 'mishnayos', targetPercent: 100.0)],
      );

      await service.importData(payload);

      final goals = await db.goalDao.getGoalsByProfile(1);
      expect(goals, hasLength(1));
      expect(goals.first.curriculumId, 'mishnayos');
    });

    test('importData imports bookmarks', () async {
      // Insert a track first so the bookmark FK is valid.
      final trackPayload = buildImportJson(
        userProfiles: [userProfileMap(displayName: 'Test')],
        learnerProfiles: [learnerProfileMap(displayName: 'Test')],
        curriculumTracks: [curriculumTrackMap(curriculumId: 'mishnayos')],
        bookmarks: [
          bookmarkMap(curriculumId: 'mishnayos', sefariaRef: 'Berakhot.1.1'),
        ],
      );

      await service.importData(trackPayload);

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(1);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.sefariaRef, 'Berakhot.1.1');
    });

    test('importData imports learning order', () async {
      // W3.25: learning_order.profileId has FK → learner_profiles(id).
      // Payload must include a learnerProfile so the FK is satisfied after
      // the import clears all existing rows.
      final payload = buildImportJson(
        userProfiles: [userProfileMap(displayName: 'Test')],
        learnerProfiles: [learnerProfileMap(displayName: 'Test')],
        learningOrder: [
          learningOrderMap(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 0,
          ),
        ],
      );

      await service.importData(payload);

      final orders = await db.learningOrderDao.getAllLearningOrders();
      expect(orders, hasLength(1));
      expect(orders.first.sefariaRef, 'Berakhot');
    });

    test(
      'importData imports streak_events (streaks key ignored in W3.20+)',
      () async {
        // W3.20: `streaks` key is legacy — import reads from `streakEvents`.
        // W3.25: streak_events.profileId has FK → learner_profiles(id).
        // Payload must include a learnerProfile so the FK is satisfied.
        const ts = '2026-03-20T00:00:00.000Z';
        final payload = buildImportJson(
          userProfiles: [userProfileMap(displayName: 'Test')],
          learnerProfiles: [learnerProfileMap(displayName: 'Test')],
          // Legacy format — should be silently ignored.
          streaks: [legacyStreakMap()],
        );

        // Also build a payload that includes streakEvents.
        final payloadWithEvents = jsonEncode({
          ...jsonDecode(payload) as Map<String, dynamic>,
          'streakEvents': [
            streakEventMap(dayUtc: ts, eventTimestamp: ts, createdAt: ts),
          ],
        });

        await service.importData(payloadWithEvents);

        final events = await db.streakEventDao.getEventsByProfile(1);
        expect(events, hasLength(1));
        expect(events.first.eventType, 'completion');
      },
    );

    test('importData is a no-op on invalid JSON '
        '(throws ImportValidationException)', () async {
      expect(
        () => service.importData('not json'),
        throwsA(isA<ImportValidationException>()),
      );
    });

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
