import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

void main() {
  /// Build a minimal valid export JSON string.
  String buildValidJson({
    List<Map<String, dynamic>> completions = const [],
    List<Map<String, dynamic>> goals = const [],
    List<Map<String, dynamic>> stageDefinitions = const [],
    List<Map<String, dynamic>> rewards = const [],
    List<Map<String, dynamic>> streaks = const [],
    List<Map<String, dynamic>> pointConfigs = const [],
    List<Map<String, dynamic>> bookmarks = const [],
    List<Map<String, dynamic>> learningOrder = const [],
    List<Map<String, dynamic>> activeCurricula = const [],
    List<Map<String, dynamic>> curriculumTracks = const [],
    List<Map<String, dynamic>> userProfiles = const [],
  }) {
    return json.encode({
      'formatVersion': '1',
      'exportedAt': '2026-01-01T00:00:00.000Z',
      'appVersion': '1.0.0',
      'completions': completions,
      'goals': goals,
      'stageDefinitions': stageDefinitions,
      'rewards': rewards,
      'streaks': streaks,
      'pointConfigs': pointConfigs,
      'bookmarks': bookmarks,
      'learningOrder': learningOrder,
      'activeCurricula': activeCurricula,
      'curriculumTracks': curriculumTracks,
      'userProfiles': userProfiles,
    });
  }

  group('validateAndPreview', () {
    late AppDatabase db;
    late DataExportImportService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = DataExportImportService(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('parses valid JSON and returns correct counts', () {
      final jsonStr = buildValidJson(
        completions: [
          {'id': 1},
          {'id': 2},
        ],
        goals: [
          {'id': 1},
        ],
        rewards: [
          {'id': 1},
          {'id': 2},
          {'id': 3},
        ],
      );

      final preview = service.validateAndPreview(jsonStr);

      expect(preview.completionCount, 2);
      expect(preview.goalCount, 1);
      expect(preview.rewardCount, 3);
      expect(preview.stageCount, 0);
      expect(preview.streakCount, 0);
      expect(preview.totalRecords, 6);
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
      final jsonStr = json.encode({
        'completions': <dynamic>[],
        'goals': <dynamic>[],
        'stageDefinitions': <dynamic>[],
        'rewards': <dynamic>[],
        'streaks': <dynamic>[],
        'pointConfigs': <dynamic>[],
        'bookmarks': <dynamic>[],
        'learningOrder': <dynamic>[],
        'activeCurricula': <dynamic>[],
        'curriculumTracks': <dynamic>[],
        'userProfiles': <dynamic>[],
      });

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
      final data = {
        'formatVersion': '1',
        'completions': 'not a list',
        'goals': <dynamic>[],
        'stageDefinitions': <dynamic>[],
        'rewards': <dynamic>[],
        'streaks': <dynamic>[],
        'pointConfigs': <dynamic>[],
        'bookmarks': <dynamic>[],
        'learningOrder': <dynamic>[],
        'activeCurricula': <dynamic>[],
        'curriculumTracks': <dynamic>[],
        'userProfiles': <dynamic>[],
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
      final jsonStr = buildValidJson(
        completions: [
          {'id': 1},
        ],
        goals: [
          {'id': 1},
        ],
        stageDefinitions: [
          {'id': 1},
        ],
        rewards: [
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
        activeCurricula: [
          {'id': 1},
        ],
        curriculumTracks: [
          {'id': 1},
        ],
        userProfiles: [
          {'id': 1},
        ],
      );

      final preview = service.validateAndPreview(jsonStr);
      expect(preview.totalRecords, 11);
    });
  });
}
