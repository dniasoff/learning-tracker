/// Extended round-trip tests for DataExportImportService covering entity
/// types not exercised in data_export_roundtrip_test.dart:
///   — curriculumScopes, profilePrograms, studyDayConfigs, completionEvents,
///     streakEvents, learningLedger, trackLearningOrder.
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

  setUp(() {
    db = inMemoryDb();
    service = DataExportImportService(
      database: db,
      appVersionFetcher: () async => '1.0.0',
    );
  });

  tearDown(() async {
    await db.close();
  });

  // Helper: insert a personal curriculum track and return its id.
  Future<int> _insertTrack({
    int profileId = 1,
    String curriculumId = 'mishnayos',
  }) =>
      db.into(db.curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackType: 'personal',
          isActive: const Value(true),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

  // ── exportData — curriculumScopes ─────────────────────────────────────────

  group('exportData — curriculumScopes', () {
    test('exports curriculum scopes', () async {
      final trackId = await _insertTrack();
      await db.into(db.curriculumScopes).insert(
        CurriculumScopesCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          scopeLevel: 1,
          scopeValue: 'Zeraim',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final scopes = data['curriculumScopes'] as List;

      expect(scopes, hasLength(1));
      expect(scopes.first['scopeValue'], 'Zeraim');
      expect(scopes.first['scopeLevel'], 1);
    });
  });

  // ── exportData — profilePrograms ──────────────────────────────────────────

  group('exportData — profilePrograms', () {
    test('exports profile program assignments', () async {
      await db.into(db.profilePrograms).insert(
        ProfileProgramsCompanion.insert(
          profileId: 1,
          curriculumType: 'mishnayos',
          programId: 42,
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final programs = data['profilePrograms'] as List;

      expect(programs, hasLength(1));
      expect(programs.first['programId'], 42);
      expect(programs.first['curriculumType'], 'mishnayos');
    });
  });

  // ── exportData — studyDayConfigs ──────────────────────────────────────────

  group('exportData — studyDayConfigs', () {
    test('exports study day config rows', () async {
      final trackId = await _insertTrack();
      await db.into(db.studyDayConfigs).insert(
        StudyDayConfigsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          dayOfWeek: 1,
          dayType: const Value('study'),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final configs = data['studyDayConfigs'] as List;

      expect(configs, hasLength(1));
      expect(configs.first['dayOfWeek'], 1);
      expect(configs.first['dayType'], 'study');
    });
  });

  // ── exportData — completionEvents ─────────────────────────────────────────

  group('exportData — completionEvents', () {
    test('exports completion event rows', () async {
      // Insert a stage first so stageId is a real FK.
      final trackId = await _insertTrack();
      final stageId = await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
      );

      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot.1',
          stageId: stageId,
          trackType: 'personal',
          eventTimestamp: DateTime.utc(2026, 1, 2),
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final events = data['completionEvents'] as List;

      expect(events, hasLength(1));
      expect(events.first['sefariaRef'], 'Berakhot.1');
    });
  });

  // ── exportData — streakEvents ─────────────────────────────────────────────

  group('exportData — streakEvents', () {
    test('exports streak event rows', () async {
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: 1,
          eventType: 'completion',
          dayUtc: DateTime.utc(2026, 1, 1),
          eventTimestamp: DateTime.utc(2026, 1, 1, 10),
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final events = data['streakEvents'] as List;

      expect(events, hasLength(1));
      expect(events.first['eventType'], 'completion');
    });
  });

  // ── exportData — learningLedger ───────────────────────────────────────────

  group('exportData — learningLedger', () {
    test('exports learning ledger entries', () async {
      await db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          completedAt: DateTime.utc(2026, 1, 1),
          completionNumber: 1,
          markedBy: 0,
        ),
      );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final ledger = data['learningLedger'] as List;

      expect(ledger, hasLength(1));
      expect(ledger.first['unitIdentifier'], 'Berakhot');
      expect(ledger.first['entryScope'], 'masechta');
    });
  });

  // ── importData — curriculumScopes ─────────────────────────────────────────

  group('importData — curriculumScopes', () {
    String _payload({required List<Map<String, dynamic>> scopes}) =>
        jsonEncode({
          'formatVersion': 'schemaV1',
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'appVersion': '1.0.0',
          'userProfiles': [],
          'learnerProfiles': [],
          'curriculumTracks': [
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
          'curriculumScopes': scopes,
          'profilePrograms': [],
          'stageDefinitions': [],
          'pointConfigs': [],
          'studyDayConfigs': [],
          'completions': [],
          'completionEvents': [],
          'dailyPlans': [],
          'learningLedger': [],
          'bookmarks': [],
          'learningOrder': [],
          'trackLearningOrder': [],
          'goals': [],
          'streaks': [],
          'streakEvents': [],
        });

    test('imports curriculum scopes', () async {
      await service.importData(
        _payload(
          scopes: [
            {
              'id': 1,
              'profileId': 1,
              'curriculumId': 'mishnayos',
              'trackId': 1,
              'scopeLevel': 2,
              'scopeValue': 'Nashim',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        ),
      );

      final scopes = await db.curriculumScopeDao.getScopesByTrack(1);
      expect(scopes, hasLength(1));
      expect(scopes.first.scopeValue, 'Nashim');
    });
  });

  // ── importData — studyDayConfigs ──────────────────────────────────────────

  group('importData — studyDayConfigs', () {
    String _payload() => jsonEncode({
      'formatVersion': 'schemaV1',
      'exportedAt': '2026-01-01T00:00:00.000Z',
      'appVersion': '1.0.0',
      'userProfiles': [],
      'learnerProfiles': [],
      'curriculumTracks': [
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
      'curriculumScopes': [],
      'profilePrograms': [],
      'stageDefinitions': [],
      'pointConfigs': [],
      'studyDayConfigs': [
        {
          'profileId': 1,
          'curriculumId': 'mishnayos',
          'trackId': 1,
          'dayOfWeek': 7,
          'dayType': 'study',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
      'completions': [],
      'completionEvents': [],
      'dailyPlans': [],
      'learningLedger': [],
      'bookmarks': [],
      'learningOrder': [],
      'trackLearningOrder': [],
      'goals': [],
      'streaks': [],
      'streakEvents': [],
    });

    test('imports study day configs', () async {
      await service.importData(_payload());

      final configs =
          await db.studyDayConfigDao.getConfigsByCurriculumAndProfile(
        'mishnayos',
        1,
      );
      expect(configs, hasLength(1));
      expect(configs.first.dayOfWeek, 7);
    });
  });

  // ── importData — streakEvents ─────────────────────────────────────────────

  group('importData — streakEvents', () {
    String _payload() => jsonEncode({
      'formatVersion': 'schemaV1',
      'exportedAt': '2026-01-01T00:00:00.000Z',
      'appVersion': '1.0.0',
      'userProfiles': [],
      'learnerProfiles': [],
      'curriculumTracks': [],
      'curriculumScopes': [],
      'profilePrograms': [],
      'stageDefinitions': [],
      'pointConfigs': [],
      'studyDayConfigs': [],
      'completions': [],
      'completionEvents': [],
      'dailyPlans': [],
      'learningLedger': [],
      'bookmarks': [],
      'learningOrder': [],
      'trackLearningOrder': [],
      'goals': [],
      'streaks': [],
      'streakEvents': [
        {
          'id': 1,
          'profileId': 1,
          'eventType': 'completion',
          'dayUtc': '2026-01-05T00:00:00.000Z',
          'eventTimestamp': '2026-01-05T10:00:00.000Z',
          'clientDeviceId': null,
          'createdAt': '2026-01-05T10:00:00.000Z',
        },
      ],
    });

    test('imports streak events', () async {
      await service.importData(_payload());

      final events = await db.streakEventDao.getEventsByProfile(1);
      expect(events, hasLength(1));
      expect(events.first.eventType, 'completion');
    });
  });

  // ── importData — learningLedger ───────────────────────────────────────────

  group('importData — learningLedger', () {
    String _payload() => jsonEncode({
      'formatVersion': 'schemaV1',
      'exportedAt': '2026-01-01T00:00:00.000Z',
      'appVersion': '1.0.0',
      'userProfiles': [],
      'learnerProfiles': [],
      'curriculumTracks': [],
      'curriculumScopes': [],
      'profilePrograms': [],
      'stageDefinitions': [],
      'pointConfigs': [],
      'studyDayConfigs': [],
      'completions': [],
      'completionEvents': [],
      'dailyPlans': [],
      'learningLedger': [
        {
          'id': 1,
          'profileId': 1,
          'ulid': '01HZ000000000000000000001',
          'curriculumId': 'mishnayos',
          'entryScope': 'masechta',
          'unitIdentifier': 'Berakhot',
          'unitDisplayNameHe': 'ברכות',
          'unitDisplayNameEn': 'Berakhot',
          'trackType': 'personal',
          'trackId': null,
          'completedAt': '2026-01-01T00:00:00.000Z',
          'completionNumber': 1,
          'markedBy': 0,
          'isManual': false,
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
      ],
      'bookmarks': [],
      'learningOrder': [],
      'trackLearningOrder': [],
      'goals': [],
      'streaks': [],
      'streakEvents': [],
    });

    test('imports learning ledger entries', () async {
      await service.importData(_payload());

      final entries = await db.learningLedgerDao.getEntriesByProfile(1);
      expect(entries, hasLength(1));
      expect(entries.first.unitIdentifier, 'Berakhot');
    });
  });

  // ── importData — trackLearningOrder ───────────────────────────────────────

  group('importData — trackLearningOrder', () {
    String _payload() => jsonEncode({
      'formatVersion': 'schemaV1',
      'exportedAt': '2026-01-01T00:00:00.000Z',
      'appVersion': '1.0.0',
      'userProfiles': [],
      'learnerProfiles': [],
      'curriculumTracks': [
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
      'curriculumScopes': [],
      'profilePrograms': [],
      'stageDefinitions': [],
      'pointConfigs': [],
      'studyDayConfigs': [],
      'completions': [],
      'completionEvents': [],
      'dailyPlans': [],
      'learningLedger': [],
      'bookmarks': [],
      'learningOrder': [],
      'trackLearningOrder': [
        {'id': 1, 'trackId': 1, 'sefariaRef': 'Berakhot', 'sortOrder': 0},
      ],
      'goals': [],
      'streaks': [],
      'streakEvents': [],
    });

    test('imports track learning order entries', () async {
      await service.importData(_payload());

      final orders = await db.trackLearningOrderDao.getByTrack(1);
      expect(orders, hasLength(1));
      expect(orders.first.sefariaRef, 'Berakhot');
    });
  });
}
