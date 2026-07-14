import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/data_export_fixtures.dart';

void main() {
  group('validateAndPreview', () {
    late UserDatabase db;
    late DataExportImportService service;

    setUp(() {
      db = UserDatabase(NativeDatabase.memory());
      service = DataExportImportService(
        database: db,
        appVersionFetcher: () async => '1.0.0',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('parses valid JSON and returns correct counts', () {
      final jsonStr = json.encode(
        exportPayloadMap(
          completions: [
            {'id': 1},
            {'id': 2},
          ],
          goals: [
            {'id': 1},
          ],
        ),
      );

      final preview = service.validateAndPreview(jsonStr);

      expect(preview.completionCount, 2);
      expect(preview.goalCount, 1);
      expect(preview.stageCount, 0);
      expect(preview.streakCount, 0);
      expect(preview.totalRecords, 3);
      expect(preview.exportedAt, '2026-01-01T00:00:00.000Z');
      expect(preview.appVersion, '1.0.0');
    });

    test('throws FormatException for invalid JSON', () {
      expect(
        () => service.validateAndPreview('not json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Invalid JSON format',
          ),
        ),
      );
    });

    test('throws FormatException when formatVersion is missing', () {
      final data = exportPayloadMap()..remove('formatVersion');
      final jsonStr = json.encode(data);

      expect(
        () => service.validateAndPreview(jsonStr),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Missing formatVersion field',
          ),
        ),
      );
    });

    test('throws FormatException when a required section is missing', () {
      final data = {
        'formatVersion': '1',
        'completions': <dynamic>[],
        // missing 'goals' and others
      };

      expect(
        () => service.validateAndPreview(json.encode(data)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Missing required section'),
          ),
        ),
      );
    });

    test('throws FormatException when a section is not a list', () {
      final data = <String, dynamic>{
        ...exportPayloadMap(),
        'completions': 'not a list',
      };

      expect(
        () => service.validateAndPreview(json.encode(data)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must be a list'),
          ),
        ),
      );
    });

    test('totalRecords sums all section counts', () {
      final jsonStr = json.encode(
        exportPayloadMap(
          completions: [
            {'id': 1},
          ],
          goals: [
            {'id': 1},
          ],
          stageDefinitions: [
            {'id': 1},
          ],
          streaks: [
            {'id': 1},
          ],
          pointConfigs: [
            {'id': 1},
          ],
          bookmarks: [
            {'id': 1},
          ],
          learningOrder: [
            {'id': 1},
          ],
          curriculumTracks: [
            {'id': 1},
          ],
          userProfiles: [
            {'id': 1},
          ],
        ),
      );

      final preview = service.validateAndPreview(jsonStr);
      // 9 sections counted in ImportPreview.totalRecords, 1 record each.
      // `activeCurricula` is not part of the real schema (removed in v9,
      // AUD-t-settings-08) and is deliberately not part of the shared
      // exportPayloadMap fixture.
      expect(preview.totalRecords, 9);
    });
  });
}
