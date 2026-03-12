import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:learning_tracker/core/constants/text_content_config.dart';
import 'package:learning_tracker/core/database/daos/text_cache_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/services/text_download_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTextCacheDao extends Mock implements TextCacheDao {}

class MockTextDownloadStatusDao extends Mock implements TextDownloadStatusDao {}

class MockHttpClient extends Mock implements http.Client {}

/// Builds a gzipped JSON response body containing [count] items.
List<int> _buildGzipBody(int count) {
  final items = List.generate(count, (i) {
    return {'ref': 'Ref.$i', 'he': 'Hebrew $i', 'en': 'English $i'};
  });
  final jsonString = jsonEncode({'items': items});
  return gzip.encode(utf8.encode(jsonString));
}

void main() {
  late MockTextCacheDao mockTextCacheDao;
  late MockTextDownloadStatusDao mockTextDownloadStatusDao;
  late MockHttpClient mockHttpClient;
  late TextDownloadService service;

  setUp(() {
    mockTextCacheDao = MockTextCacheDao();
    mockTextDownloadStatusDao = MockTextDownloadStatusDao();
    mockHttpClient = MockHttpClient();
    service = TextDownloadService(
      textCacheDao: mockTextCacheDao,
      textDownloadStatusDao: mockTextDownloadStatusDao,
      httpClient: mockHttpClient,
    );

    // Default stubs
    when(() => mockTextCacheDao.storeBatch(any())).thenAnswer((_) async {});
    when(
      () => mockTextDownloadStatusDao.markDownloaded(
        curriculumId: any(named: 'curriculumId'),
        itemCount: any(named: 'itemCount'),
        textVersion: any(named: 'textVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTextDownloadStatusDao.savePartialProgress(
        curriculumId: any(named: 'curriculumId'),
        storedItemCount: any(named: 'storedItemCount'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTextDownloadStatusDao.getPartialItemCount(any()),
    ).thenAnswer((_) async => null);
  });

  group('TextDownloadProgress', () {
    test('progress returns 0.0 for notStarted', () {
      const p = TextDownloadProgress(state: TextDownloadState.notStarted);
      expect(p.progress, 0.0);
    });

    test('progress returns ratio for storing state', () {
      const p = TextDownloadProgress(
        state: TextDownloadState.storing,
        itemsStored: 250,
        totalItems: 1000,
      );
      expect(p.progress, 0.25);
    });

    test('progress returns 0.0 for storing when totalItems is 0', () {
      const p = TextDownloadProgress(
        state: TextDownloadState.storing,
        totalItems: 0,
      );
      expect(p.progress, 0.0);
    });

    test('progress returns 1.0 for completed', () {
      const p = TextDownloadProgress(state: TextDownloadState.completed);
      expect(p.progress, 1.0);
    });

    test('progress returns 0.0 for failed', () {
      const p = TextDownloadProgress(state: TextDownloadState.failed);
      expect(p.progress, 0.0);
    });
  });

  group('TextDownloadService', () {
    group('isDownloaded', () {
      test('delegates to TextDownloadStatusDao', () async {
        when(
          () => mockTextDownloadStatusDao.isDownloaded('mishnayos'),
        ).thenAnswer((_) async => true);

        final result = await service.isDownloaded(CurriculumId.mishnayos);
        expect(result, isTrue);
        verify(
          () => mockTextDownloadStatusDao.isDownloaded('mishnayos'),
        ).called(1);
      });

      test('returns false when not downloaded', () async {
        when(
          () => mockTextDownloadStatusDao.isDownloaded('bavli'),
        ).thenAnswer((_) async => false);

        final result = await service.isDownloaded(CurriculumId.bavli);
        expect(result, isFalse);
      });
    });

    group('downloadCurriculum', () {
      test(
        'emits downloading, parsing, storing, completed on success',
        () async {
          final body = _buildGzipBody(3);
          final url = TextContentConfig.downloadUrl(
            CurriculumId.mishnayos.storageKey,
          );
          when(
            () => mockHttpClient.get(Uri.parse(url)),
          ).thenAnswer((_) async => http.Response.bytes(body, 200));

          final events = await service
              .downloadCurriculum(CurriculumId.mishnayos)
              .toList();

          final states = events.map((e) => e.state).toList();
          expect(states, [
            TextDownloadState.downloading,
            TextDownloadState.parsing,
            TextDownloadState.storing,
            TextDownloadState.completed,
          ]);
        },
      );

      test('completed event has correct itemsStored and totalItems', () async {
        final body = _buildGzipBody(10);
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response.bytes(body, 200));

        final events = await service
            .downloadCurriculum(CurriculumId.mishnayos)
            .toList();
        final completed = events.last;
        expect(completed.state, TextDownloadState.completed);
        expect(completed.itemsStored, 10);
        expect(completed.totalItems, 10);
      });

      test('emits failed on non-200 HTTP response', () async {
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        final events = await service
            .downloadCurriculum(CurriculumId.mishnayos)
            .toList();

        expect(events.last.state, TextDownloadState.failed);
        expect(events.last.error, contains('404'));
      });

      test('emits failed on HTTP exception', () async {
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenThrow(const SocketException('No internet'));

        final events = await service
            .downloadCurriculum(CurriculumId.mishnayos)
            .toList();

        expect(events.last.state, TextDownloadState.failed);
        expect(events.last.error, contains('SocketException'));
      });

      test('calls storeBatch with correct data', () async {
        final body = _buildGzipBody(2);
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response.bytes(body, 200));

        await service.downloadCurriculum(CurriculumId.mishnayos).toList();

        final captured = verify(
          () => mockTextCacheDao.storeBatch(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final batch =
            captured.first
                as List<
                  ({String sefariaRef, String hebrewText, String englishText})
                >;
        expect(batch, hasLength(2));
        expect(batch[0].sefariaRef, 'Ref.0');
        expect(batch[0].hebrewText, 'Hebrew 0');
        expect(batch[0].englishText, 'English 0');
        expect(batch[1].sefariaRef, 'Ref.1');
      });

      test('calls markDownloaded with correct params on completion', () async {
        final body = _buildGzipBody(5);
        final url = TextContentConfig.downloadUrl(
          CurriculumId.bavli.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response.bytes(body, 200));

        await service.downloadCurriculum(CurriculumId.bavli).toList();

        verify(
          () => mockTextDownloadStatusDao.markDownloaded(
            curriculumId: 'bavli',
            itemCount: 5,
            textVersion: TextContentConfig.textVersion,
          ),
        ).called(1);
      });

      test('batches items in groups of 500', () async {
        final body = _buildGzipBody(1200);
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response.bytes(body, 200));

        final events = await service
            .downloadCurriculum(CurriculumId.mishnayos)
            .toList();

        // 1200 items / 500 batch = 3 batches
        verify(() => mockTextCacheDao.storeBatch(any())).called(3);

        // 3 storing events + downloading + parsing + completed = 6
        expect(events, hasLength(6));
        final storingEvents = events
            .where((e) => e.state == TextDownloadState.storing)
            .toList();
        expect(storingEvents, hasLength(3));
        expect(storingEvents[0].itemsStored, 500);
        expect(storingEvents[1].itemsStored, 1000);
        expect(storingEvents[2].itemsStored, 1200);
      });

      test('saves partial progress after each batch', () async {
        final body = _buildGzipBody(600);
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response.bytes(body, 200));

        await service.downloadCurriculum(CurriculumId.mishnayos).toList();

        // 600 items = 2 batches, so 2 savePartialProgress calls
        verify(
          () => mockTextDownloadStatusDao.savePartialProgress(
            curriculumId: 'mishnayos',
            storedItemCount: 500,
          ),
        ).called(1);
        verify(
          () => mockTextDownloadStatusDao.savePartialProgress(
            curriculumId: 'mishnayos',
            storedItemCount: 600,
          ),
        ).called(1);
      });

      test('resumes from partial progress', () async {
        // Simulate 500 items already stored
        when(
          () => mockTextDownloadStatusDao.getPartialItemCount('mishnayos'),
        ).thenAnswer((_) async => 500);

        final body = _buildGzipBody(1000);
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response.bytes(body, 200));

        final events = await service
            .downloadCurriculum(CurriculumId.mishnayos)
            .toList();

        // Should only process 1 batch (items 500-999) since first 500 already done
        verify(() => mockTextCacheDao.storeBatch(any())).called(1);

        final storingEvents = events
            .where((e) => e.state == TextDownloadState.storing)
            .toList();
        expect(storingEvents, hasLength(1));
        expect(storingEvents.first.itemsStored, 1000);
      });

      test('emits failed when storeBatch throws', () async {
        final body = _buildGzipBody(3);
        final url = TextContentConfig.downloadUrl(
          CurriculumId.mishnayos.storageKey,
        );
        when(
          () => mockHttpClient.get(Uri.parse(url)),
        ).thenAnswer((_) async => http.Response.bytes(body, 200));
        when(
          () => mockTextCacheDao.storeBatch(any()),
        ).thenThrow(Exception('DB write failed'));

        final events = await service
            .downloadCurriculum(CurriculumId.mishnayos)
            .toList();

        expect(events.last.state, TextDownloadState.failed);
        expect(events.last.error, contains('DB write failed'));
      });

      test('uses correct download URL for each curriculum', () async {
        for (final curriculum in CurriculumId.values) {
          final body = _buildGzipBody(1);
          final expectedUrl = TextContentConfig.downloadUrl(
            curriculum.storageKey,
          );
          when(
            () => mockHttpClient.get(Uri.parse(expectedUrl)),
          ).thenAnswer((_) async => http.Response.bytes(body, 200));

          await service.downloadCurriculum(curriculum).toList();

          verify(() => mockHttpClient.get(Uri.parse(expectedUrl))).called(1);
        }
      });
    });
  });
}
