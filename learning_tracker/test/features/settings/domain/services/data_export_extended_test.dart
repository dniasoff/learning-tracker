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

  // Helper: insert a personal curriculum track and return its id.
  Future<int> insertTrack({
    int profileId = 1,
    String curriculumId = 'mishnayos',
  }) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

  // ── exportData — curriculumScopes ─────────────────────────────────────────

  group('exportData — curriculumScopes', () {
    test('exports curriculum scopes', () async {
      final trackId = await insertTrack();
      await db
          .into(db.curriculumScopes)
          .insert(
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
      final scopes = (data['curriculumScopes'] as List)
          .cast<Map<String, dynamic>>();

      expect(scopes, hasLength(1));
      expect(scopes.first['scopeValue'], 'Zeraim');
      expect(scopes.first['scopeLevel'], 1);
    });
  });

  // ── exportData — profilePrograms ──────────────────────────────────────────

  group('exportData — profilePrograms', () {
    test('exports profile program assignments', () async {
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: 1,
              curriculumType: 'mishnayos',
              programId: 42,
            ),
          );

      final data =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final programs = (data['profilePrograms'] as List)
          .cast<Map<String, dynamic>>();

      expect(programs, hasLength(1));
      expect(programs.first['programId'], 42);
      expect(programs.first['curriculumType'], 'mishnayos');
    });
  });

  // ── exportData — studyDayConfigs ──────────────────────────────────────────

  group('exportData — studyDayConfigs', () {
    test('exports study day config rows', () async {
      final trackId = await insertTrack();
      await db
          .into(db.studyDayConfigs)
          .insert(
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
      final configs = (data['studyDayConfigs'] as List)
          .cast<Map<String, dynamic>>();

      expect(configs, hasLength(1));
      expect(configs.first['dayOfWeek'], 1);
      expect(configs.first['dayType'], 'study');
    });
  });

  // ── exportData — completionEvents ─────────────────────────────────────────

  group('exportData — completionEvents', () {
    test('exports completion event rows', () async {
      // Insert a stage first so stageId is a real FK.
      final trackId = await insertTrack();
      final stageId = await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
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
      final events = (data['completionEvents'] as List)
          .cast<Map<String, dynamic>>();

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
      final events = (data['streakEvents'] as List)
          .cast<Map<String, dynamic>>();

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
      final ledger = (data['learningLedger'] as List)
          .cast<Map<String, dynamic>>();

      expect(ledger, hasLength(1));
      expect(ledger.first['unitIdentifier'], 'Berakhot');
      expect(ledger.first['entryScope'], 'masechta');
    });
  });

  // ── importData — curriculumScopes ─────────────────────────────────────────

  group('importData — curriculumScopes', () {
    String payload({required List<Map<String, dynamic>> scopes}) => jsonEncode(
      exportPayloadMap(
        userProfiles: [userProfileMap(displayName: 'Test')],
        learnerProfiles: [learnerProfileMap(displayName: 'Test')],
        curriculumTracks: [curriculumTrackMap(curriculumId: 'mishnayos')],
        curriculumScopes: scopes,
      ),
    );

    test('imports curriculum scopes', () async {
      await service.importData(
        payload(
          scopes: [
            curriculumScopeMap(
              curriculumId: 'mishnayos',
              scopeLevel: 2,
              scopeValue: 'Nashim',
            ),
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
    String payload() => jsonEncode(
      exportPayloadMap(
        curriculumTracks: [curriculumTrackMap(curriculumId: 'mishnayos')],
        studyDayConfigs: [
          studyDayConfigMap(curriculumId: 'mishnayos', dayOfWeek: 7),
        ],
      ),
    );

    test('imports study day configs', () async {
      await service.importData(payload());

      final configs = await db.studyDayConfigDao
          .getConfigsByCurriculumAndProfile('mishnayos', 1);
      expect(configs, hasLength(1));
      expect(configs.first.dayOfWeek, 7);
    });
  });

  // ── importData — streakEvents ─────────────────────────────────────────────

  group('importData — streakEvents', () {
    String payload() => jsonEncode(
      exportPayloadMap(
        userProfiles: [userProfileMap(displayName: 'Test')],
        learnerProfiles: [learnerProfileMap(displayName: 'Test')],
        streakEvents: [streakEventMap()],
      ),
    );

    test('imports streak events', () async {
      await service.importData(payload());

      final events = await db.streakEventDao.getEventsByProfile(1);
      expect(events, hasLength(1));
      expect(events.first.eventType, 'completion');
    });
  });

  // ── importData — learningLedger ───────────────────────────────────────────

  group('importData — learningLedger', () {
    String payload() => jsonEncode(
      exportPayloadMap(
        userProfiles: [userProfileMap(displayName: 'Test')],
        learnerProfiles: [learnerProfileMap(displayName: 'Test')],
        learningLedger: [
          learningLedgerMap(curriculumId: 'mishnayos', trackId: null),
        ],
      ),
    );

    test('imports learning ledger entries', () async {
      await service.importData(payload());

      final entries = await db.learningLedgerDao.getEntriesByProfile(1);
      expect(entries, hasLength(1));
      expect(entries.first.unitIdentifier, 'Berakhot');
    });
  });

  // ── importData — trackLearningOrder ───────────────────────────────────────

  group('importData — trackLearningOrder', () {
    String payload() => jsonEncode(
      exportPayloadMap(
        userProfiles: [userProfileMap()],
        learnerProfiles: [learnerProfileMap(displayName: 'Test Profile')],
        curriculumTracks: [curriculumTrackMap(curriculumId: 'mishnayos')],
        trackLearningOrder: [trackLearningOrderMap()],
      ),
    );

    test('imports track learning order entries', () async {
      await service.importData(payload());

      final orders = await db.trackLearningOrderDao.getByTrack(1, 1);
      expect(orders, hasLength(1));
      expect(orders.first.sefariaRef, 'Berakhot');
    });
  });
}
