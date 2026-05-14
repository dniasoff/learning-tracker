/// Tests for DataExportImportService.importData() and related round-trip
/// behaviour.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  group('DataExportImportService.importData — round-trip empty DB', () {
    test('export→import on empty DB leaves DB empty again', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final jsonStr = await service.exportData();
      // Should not throw.
      await service.importData(jsonStr);

      // After round-trip, DB is still empty.
      final tracks = await db.select(db.curriculumTracks).get();
      expect(tracks, isEmpty);
    });

    test('importData throws FormatException on malformed JSON', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      expect(
        () => service.importData('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('importData throws FormatException when formatVersion missing',
        () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final payload = jsonEncode({
        'exportedAt': '2026-01-01T00:00:00Z',
        'appVersion': '1.0.0',
        'userProfiles': <dynamic>[],
        'curriculumTracks': <dynamic>[],
        'stageDefinitions': <dynamic>[],
        'completions': <dynamic>[],
        'goals': <dynamic>[],
        'bookmarks': <dynamic>[],
        'learningOrder': <dynamic>[],
        'streaks': <dynamic>[],
        'pointConfigs': <dynamic>[],
      });

      expect(
        () => service.importData(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('importData throws FormatException when required section missing',
        () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      // Missing 'completions' section.
      final payload = jsonEncode({
        'formatVersion': 'schemaV1',
        'exportedAt': '2026-01-01T00:00:00Z',
        'appVersion': '1.0.0',
        'userProfiles': <dynamic>[],
        'curriculumTracks': <dynamic>[],
        'stageDefinitions': <dynamic>[],
        'goals': <dynamic>[],
        'bookmarks': <dynamic>[],
        'learningOrder': <dynamic>[],
        'streaks': <dynamic>[],
        'pointConfigs': <dynamic>[],
      });

      expect(
        () => service.importData(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('DataExportImportService.importData — with data', () {
    test('import clears existing data before inserting new data', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      // Build a minimal valid payload with one user profile (no FK deps).
      final payload = jsonEncode({
        'formatVersion': 'schemaV1',
        'exportedAt': '2026-01-01T00:00:00Z',
        'appVersion': '1.0.0',
        'userProfiles': [
          {
            'id': 1,
            'profileId': 1,
            'displayName': 'Test User',
            'tier': 'localBorn',
            'userMode': 'adult',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          }
        ],
        'learnerProfiles': <dynamic>[],
        'curriculumTracks': <dynamic>[],
        'curriculumScopes': <dynamic>[],
        'profilePrograms': <dynamic>[],
        'stageDefinitions': <dynamic>[],
        'pointConfigs': <dynamic>[],
        'studyDayConfigs': <dynamic>[],
        'completions': <dynamic>[],
        'completionEvents': <dynamic>[],
        'dailyPlans': <dynamic>[],
        'learningLedger': <dynamic>[],
        'bookmarks': <dynamic>[],
        'learningOrder': <dynamic>[],
        'trackLearningOrder': <dynamic>[],
        'goals': <dynamic>[],
        'streaks': <dynamic>[],
        'streakEvents': <dynamic>[],
      });

      await service.importData(payload);

      // The account should have been inserted.
      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1));
      expect(accounts.first.displayName, 'Test User');
    });

    test('second importData wipes data from first import', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      Map<String, dynamic> buildPayload(String displayName) => {
            'formatVersion': 'schemaV1',
            'exportedAt': '2026-01-01T00:00:00Z',
            'appVersion': '1.0.0',
            'userProfiles': [
              {
                'id': 1,
                'profileId': 1,
                'displayName': displayName,
                'tier': 'localBorn',
                'userMode': 'adult',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'updatedAt': '2026-01-01T00:00:00.000Z',
              }
            ],
            'learnerProfiles': <dynamic>[],
            'curriculumTracks': <dynamic>[],
            'curriculumScopes': <dynamic>[],
            'profilePrograms': <dynamic>[],
            'stageDefinitions': <dynamic>[],
            'pointConfigs': <dynamic>[],
            'studyDayConfigs': <dynamic>[],
            'completions': <dynamic>[],
            'completionEvents': <dynamic>[],
            'dailyPlans': <dynamic>[],
            'learningLedger': <dynamic>[],
            'bookmarks': <dynamic>[],
            'learningOrder': <dynamic>[],
            'trackLearningOrder': <dynamic>[],
            'goals': <dynamic>[],
            'streaks': <dynamic>[],
            'streakEvents': <dynamic>[],
          };

      await service.importData(jsonEncode(buildPayload('First')));
      await service.importData(jsonEncode(buildPayload('Second')));

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1));
      expect(accounts.first.displayName, 'Second');
    });

    test('export→import→export produces structurally identical JSON', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final firstExport = await service.exportData();
      await service.importData(firstExport);
      final secondExport = await service.exportData();

      final first = jsonDecode(firstExport) as Map<String, dynamic>;
      final second = jsonDecode(secondExport) as Map<String, dynamic>;

      // Same set of required list sections and same lengths.
      for (final key in [
        'userProfiles',
        'curriculumTracks',
        'stageDefinitions',
        'completions',
        'goals',
        'bookmarks',
        'learningOrder',
        'streaks',
      ]) {
        expect(
          (second[key] as List).length,
          (first[key] as List).length,
          reason: 'length mismatch for $key',
        );
      }
    });
  });

  group('DataExportImportService.validateAndPreview — error cases', () {
    test('throws FormatException when a section is not a list', () {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final bad = jsonEncode({
        'formatVersion': 'schemaV1',
        'exportedAt': '2026-01-01T00:00:00Z',
        'appVersion': '1.0.0',
        'userProfiles': 'not-a-list', // wrong type
        'curriculumTracks': <dynamic>[],
        'stageDefinitions': <dynamic>[],
        'completions': <dynamic>[],
        'goals': <dynamic>[],
        'bookmarks': <dynamic>[],
        'learningOrder': <dynamic>[],
        'streaks': <dynamic>[],
        'pointConfigs': <dynamic>[],
      });

      expect(
        () => service.validateAndPreview(bad),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for completely invalid JSON', () {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      expect(
        () => service.validateAndPreview('{bad json'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
