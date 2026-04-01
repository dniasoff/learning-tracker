import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/services/text_download_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTextDownloadStatusDao extends Mock implements TextDownloadStatusDao {}

void main() {
  late MockTextDownloadStatusDao mockTextDownloadStatusDao;
  late TextDownloadService service;

  setUp(() {
    mockTextDownloadStatusDao = MockTextDownloadStatusDao();
    service = TextDownloadService(
      textDownloadStatusDao: mockTextDownloadStatusDao,
    );
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

    group('downloadCurriculum (deprecated — now yields completed)', () {
      test('emits completed immediately (content is pre-bundled)', () async {
        final events = await service
            .downloadCurriculum(CurriculumId.mishnayos)
            .toList();

        expect(events, hasLength(1));
        expect(events.first.state, TextDownloadState.completed);
      });
    });
  });
}
