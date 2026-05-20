// Extra coverage for DataExportImportService — exportData with populated tables.
// The baseline test only covers validateAndPreview; the serialization lambdas
// for curriculumScopes, profilePrograms, studyDayConfigs, completionEvents,
// and dailyPlans are hit only when the corresponding tables contain rows.
import 'dart:convert';

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
      appVersionFetcher: () async => '2.0.0',
    );
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper — insert a track
  // ---------------------------------------------------------------------------

  Future<int> insertTrack({
    int profileId = 1,
    String curriculumId = 'bavli',
    String trackType = 'personal',
  }) {
    return db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  // Convenience: decode JSON then fetch a typed list section.
  List<Map<String, dynamic>> section(Map<String, dynamic> decoded, String key) {
    return (decoded[key] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // exportData — empty database
  // ---------------------------------------------------------------------------

  group('DataExportImportService.exportData — empty database', () {
    test('returns valid JSON with all expected top-level keys', () async {
      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      expect(decoded['formatVersion'], isNotNull);
      expect(decoded['exportedAt'], isNotNull);
      expect(decoded['appVersion'], '2.0.0');
      expect(decoded['completions'], isA<List<dynamic>>());
      expect(decoded['goals'], isA<List<dynamic>>());
      expect(decoded['curriculumTracks'], isA<List<dynamic>>());
    });

    test('all list sections are empty when database is empty', () async {
      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      for (final key in <String>[
        'completions',
        'goals',
        'stageDefinitions',
        'streaks',
        'curriculumTracks',
        // 'learnerProfiles' and 'userProfiles' are seeded by setUp; skip them.
      ]) {
        expect(
          decoded[key] as List<dynamic>,
          isEmpty,
          reason: '$key should be empty',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // exportData — with curriculum scopes (covers lines 225-233)
  // ---------------------------------------------------------------------------

  group('DataExportImportService.exportData — curriculumScopes', () {
    test('serializes curriculum scope rows', () async {
      final trackId = await insertTrack();
      await db
          .into(db.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackId: trackId,
              scopeLevel: 1,
              scopeValue: 'Berakhot',
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final scopes = section(decoded, 'curriculumScopes');
      expect(scopes, hasLength(1));
      expect(scopes.first['scopeValue'], 'Berakhot');
      expect(scopes.first['scopeLevel'], 1);
    });
  });

  // ---------------------------------------------------------------------------
  // exportData — with profile programs (covers lines 239-246)
  // ---------------------------------------------------------------------------

  group('DataExportImportService.exportData — profilePrograms', () {
    test('serializes profile program rows', () async {
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: 1,
              curriculumType: 'bavli',
              programId: 42,
            ),
          );

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final programs = section(decoded, 'profilePrograms');
      expect(programs, hasLength(1));
      expect(programs.first['programId'], 42);
      expect(programs.first['curriculumType'], 'bavli');
    });
  });

  // ---------------------------------------------------------------------------
  // exportData — with study day configs (covers lines 283-290)
  // ---------------------------------------------------------------------------

  group('DataExportImportService.exportData — studyDayConfigs', () {
    test('serializes study day config rows', () async {
      final trackId = await insertTrack();
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId,
        dayOfWeek: 1,
        dayType: 'study',
      );

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final configs = section(decoded, 'studyDayConfigs');
      expect(configs, hasLength(1));
      expect(configs.first['dayOfWeek'], 1);
      expect(configs.first['dayType'], 'study');
    });
  });

  // ---------------------------------------------------------------------------
  // exportData — with completion events (covers lines 312-322)
  // ---------------------------------------------------------------------------

  group('DataExportImportService.exportData — completionEvents', () {
    test('serializes completion event rows', () async {
      final ts = DateTime.utc(2026, 3, 1);
      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: ts,
            ),
          );

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final events = section(decoded, 'completionEvents');
      expect(events, hasLength(1));
      expect(events.first['sefariaRef'], 'Berakhot.2a');
      expect(events.first['stageId'], 1);
    });
  });

  // ---------------------------------------------------------------------------
  // exportData — with daily plans (covers lines 327-344)
  // ---------------------------------------------------------------------------

  group('DataExportImportService.exportData — dailyPlans', () {
    test('serializes daily plan rows', () async {
      final trackId = await insertTrack();
      final now = DateTime.utc(2026, 5, 1);
      await db.dailyPlanDao.insertEntries([
        DailyPlansCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          planDate: now,
          sefariaRef: 'Berakhot.2a',
          stageOrder: 1,
          stageDefinitionId: 1,
          trackId: Value(trackId),
          priority: 'normal',
          createdAt: now,
        ),
      ]);

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final plans = section(decoded, 'dailyPlans');
      expect(plans, hasLength(1));
      expect(plans.first['sefariaRef'], 'Berakhot.2a');
      expect(plans.first['priority'], 'normal');
      expect(plans.first['trackId'], trackId);
    });
  });

  // ---------------------------------------------------------------------------
  // exportData — round-trip: exported JSON passes validateAndPreview
  // ---------------------------------------------------------------------------

  group('DataExportImportService — export/import round-trip', () {
    test('exported JSON passes validateAndPreview', () async {
      final trackId = await insertTrack();
      final now = DateTime.utc(2026, 1, 1);
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final raw = await service.exportData();
      final preview = service.validateAndPreview(raw);
      expect(preview.goalCount, 1);
      expect(preview.appVersion, '2.0.0');
    });
  });
}
