@Tags(['story_15_13'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:test/test.dart';

void main() {
  late CloudContentService service;
  // The blob the injected fetcher returns; each test sets it before acting.
  Uint8List? blob;

  setUp(() {
    blob = null;
    service = CloudContentService(fetchBlob: (_) async => blob);
  });

  group('CloudContentService', () {
    group('downloadHierarchy', () {
      test('parses valid JSON blob into items and config', () async {
        final payload = {
          'hierarchyConfig': {
            'curriculumId': 'bavli',
            'levelLabels': ['Masechta', 'Daf', 'Amud'],
            'totalItems': 1,
          },
          'items': [
            {
              'curriculumId': 'bavli',
              'level1': 'Berakhot',
              'level2': '2a',
              'level3': null,
              'level4': null,
              'displayNameHe': 'ברכות ב.',
              'displayNameEn': 'Berakhot 2a',
              'sefariaRef': 'Berakhot 2a',
              'sortOrder': 0,
              'isLeaf': true,
            },
          ],
        };
        blob = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

        final result = await service.downloadHierarchy(
          curriculum: CurriculumId.bavli,
          languageCode: 'he',
        );

        expect(result.items, hasLength(1));
        expect(result.items.first.sefariaRef, 'Berakhot 2a');
        expect(result.config.curriculumId, 'bavli');
        expect(result.config.levelLabels, ['Masechta', 'Daf', 'Amud']);
      });

      test('throws on null data', () async {
        blob = null;

        expect(
          () => service.downloadHierarchy(
            curriculum: CurriculumId.bavli,
            languageCode: 'he',
          ),
          throwsA(isA<ContentDownloadException>()),
        );
      });
    });

    group('downloadTextChunk', () {
      test('parses text chunk items', () async {
        final payload = {
          'items': [
            {'ref': 'Berakhot.1', 'he': 'Hebrew text', 'en': 'English text'},
          ],
        };
        blob = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

        final result = await service.downloadTextChunk(
          curriculum: CurriculumId.bavli,
          languageCode: 'he',
          chunkKey: 'Berakhot',
        );

        expect(result, hasLength(1));
        expect(result.first.ref, 'Berakhot.1');
        expect(result.first.he, 'Hebrew text');
      });
    });

    group('checkForUpdates', () {
      test('returns curricula with different versions', () async {
        final manifest = {
          'schemaVersion': 1,
          'updatedAt': '2026-01-01',
          'curricula': {
            'bavli': {
              'hierarchy': {
                'version': '2.0',
                'languages': <String>['he', 'en'],
                'totalItems': 100,
              },
              'text': {
                'version': '1.0',
                'languages': <String>['he'],
                'chunks': <String, dynamic>{},
              },
            },
          },
        };
        blob = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));

        final updates = await service.checkForUpdates(
          activeCurricula: [CurriculumId.bavli],
          localVersions: {'bavli': '1.0'},
        );

        expect(updates, [CurriculumId.bavli]);
      });

      test('returns empty when versions match', () async {
        final manifest = {
          'schemaVersion': 1,
          'updatedAt': '2026-01-01',
          'curricula': {
            'bavli': {
              'hierarchy': {
                'version': '1.0',
                'languages': <String>['he'],
                'totalItems': 100,
              },
              'text': {
                'version': '1.0',
                'languages': <String>['he'],
                'chunks': <String, dynamic>{},
              },
            },
          },
        };
        blob = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));

        final updates = await service.checkForUpdates(
          activeCurricula: [CurriculumId.bavli],
          localVersions: {'bavli': '1.0'},
        );

        expect(updates, isEmpty);
      });
    });

    // ── AUD-content_browsing-09 (EH-4) — typed catch regression ──────────
    //
    // getManifest's and checkForUpdates's catch clauses were bare `catch
    // (e)`, so a programming-error Error subtype (StateError, TypeError,
    // ...) escaping the fetchBlob call was folded into the same "no
    // updates available" outcome as an ordinary, ignorable failure —
    // indistinguishable from "already up to date". Narrowed to `on
    // Exception catch (e)` so an Error subtype now propagates instead.
    group('checkForUpdates — EH-4 typed catch (AUD-content_browsing-09)', () {
      test('a StateError thrown by fetchBlob propagates out of '
          'checkForUpdates — it is NOT swallowed into an empty list', () async {
        final throwingService = CloudContentService(
          fetchBlob: (_) async => throw StateError('boom: fetchBlob bug'),
        );

        // RED (pre-fix, bare `catch (e)` in both getManifest and
        // checkForUpdates): the StateError is caught twice — once inside
        // getManifest (logged, rethrown), then again inside
        // checkForUpdates (logged, swallowed) — so this call resolves to
        // `[]` instead of throwing; `throwsA(isA<StateError>())` fails
        // with "Expected: throws an instance of StateError / Actual: []".
        // GREEN (post-fix, `on Exception catch (e)` in both): StateError
        // is not an Exception, so neither catch clause fires — it
        // propagates all the way out of checkForUpdates.
        await expectLater(
          () => throwingService.checkForUpdates(
            activeCurricula: [CurriculumId.bavli],
            localVersions: {'bavli': '1.0'},
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('an ordinary Exception thrown by fetchBlob is still swallowed into '
          'an empty list — unchanged by the EH-4 narrowing', () async {
        final throwingService = CloudContentService(
          fetchBlob: (_) async => throw const FormatException('network hiccup'),
        );

        final updates = await throwingService.checkForUpdates(
          activeCurricula: [CurriculumId.bavli],
          localVersions: {'bavli': '1.0'},
        );

        expect(updates, isEmpty);
      });
    });
  });

  group('ContentDownloadProgress', () {
    test('progress is 0 when not downloading', () {
      const p = ContentDownloadProgress(state: ContentDownloadState.notStarted);
      expect(p.progress, 0.0);
    });

    test('progress is 1 when completed', () {
      const p = ContentDownloadProgress(state: ContentDownloadState.completed);
      expect(p.progress, 1.0);
    });

    test('progress reflects bytes transferred during download', () {
      const p = ContentDownloadProgress(
        state: ContentDownloadState.downloading,
        bytesTransferred: 50,
        totalBytes: 100,
      );
      expect(p.progress, 0.5);
    });
  });

  group('ContentManifest', () {
    test('fromJson handles empty data gracefully', () {
      final manifest = ContentManifest.fromJson(<String, dynamic>{});
      expect(manifest.schemaVersion, 1);
      expect(manifest.curricula, isEmpty);
    });

    test('fromJson parses complete data', () {
      final manifest = ContentManifest.fromJson({
        'schemaVersion': 2,
        'updatedAt': '2026-01-01',
        'curricula': {
          'bavli': {
            'hierarchy': {
              'version': '2.1',
              'languages': ['he', 'en', 'fr'],
              'totalItems': 5000,
            },
            'text': {
              'version': '1.0',
              'languages': ['he'],
              'chunks': <String, dynamic>{},
            },
          },
        },
      });
      expect(manifest.schemaVersion, 2);
      expect(manifest.curricula['bavli']!.hierarchy.version, '2.1');
      expect(manifest.curricula['bavli']!.hierarchy.languages, [
        'he',
        'en',
        'fr',
      ]);
    });
  });
}
