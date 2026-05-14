/// Extended tests for DataExportImportService focusing on exportData().
///
/// The existing test file only covers validateAndPreview(). These tests
/// exercise the exportData() path which does DB reads + JSON serialisation.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  group('DataExportImportService.exportData', () {
    test('returns valid JSON with required top-level keys', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '2.0.0',
      );

      final jsonStr = await service.exportData();

      expect(jsonStr, isNotEmpty);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Top-level keys
      expect(data.containsKey('formatVersion'), isTrue);
      expect(data.containsKey('exportedAt'), isTrue);
      expect(data.containsKey('appVersion'), isTrue);

      // Required sections
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
        expect(data.containsKey(key), isTrue, reason: 'missing key: $key');
      }
    });

    test('appVersion matches the fetcher value', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '3.5.2',
      );

      final data = jsonDecode(await service.exportData()) as Map<String, dynamic>;
      expect(data['appVersion'], '3.5.2');
    });

    test('exports empty sections when the database is empty', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final data = jsonDecode(await service.exportData()) as Map<String, dynamic>;

      expect((data['userProfiles'] as List), isEmpty);
      expect((data['completions'] as List), isEmpty);
      expect((data['goals'] as List), isEmpty);
      expect((data['streaks'] as List), isEmpty);
      expect((data['curriculumTracks'] as List), isEmpty);
      expect((data['stageDefinitions'] as List), isEmpty);
    });

    test('exported JSON can be decoded by validateAndPreview', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final jsonStr = await service.exportData();

      // validateAndPreview should not throw
      expect(() => service.validateAndPreview(jsonStr), returnsNormally);
    });

    test('formatVersion is "schemaV1"', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final data = jsonDecode(await service.exportData()) as Map<String, dynamic>;
      expect(data['formatVersion'], 'schemaV1');
    });

    test('exportedAt is a parseable ISO-8601 datetime', () async {
      final db = inMemoryDb();
      addTearDown(() => db.close());

      final service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );

      final data = jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final exportedAt = data['exportedAt'] as String;
      expect(DateTime.tryParse(exportedAt), isNotNull);
    });
  });

  group('ImportPreview', () {
    test('totalRecords sums all individual counts', () {
      final preview = ImportPreview(
        completionCount: 10,
        goalCount: 2,
        stageCount: 3,
        streakCount: 1,
        pointConfigCount: 4,
        bookmarkCount: 5,
        learningOrderCount: 6,
        curriculumTrackCount: 7,
        userProfileCount: 8,
        exportedAt: '2026-01-01T00:00:00Z',
        appVersion: '1.0.0',
      );

      expect(preview.totalRecords, 46);
    });

    test('totalRecords is 0 when all counts are 0', () {
      const preview = ImportPreview(
        completionCount: 0,
        goalCount: 0,
        stageCount: 0,
        streakCount: 0,
        pointConfigCount: 0,
        bookmarkCount: 0,
        learningOrderCount: 0,
        curriculumTrackCount: 0,
        userProfileCount: 0,
        exportedAt: 'unknown',
        appVersion: 'unknown',
      );

      expect(preview.totalRecords, 0);
    });
  });
}
