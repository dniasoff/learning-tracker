@Tags(['story_15_13'])
library;

import 'package:learning_tracker/core/database/daos/content_download_status_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:learning_tracker/features/content_browsing/domain/services/content_version_check_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockCloudContentService extends Mock implements CloudContentService {}

class MockContentDownloadStatusDao extends Mock
    implements ContentDownloadStatusDao {}

void main() {
  late MockCloudContentService mockCloudService;
  late MockContentDownloadStatusDao mockStatusDao;
  late ContentVersionCheckService service;

  setUp(() {
    mockCloudService = MockCloudContentService();
    mockStatusDao = MockContentDownloadStatusDao();
    service = ContentVersionCheckService(
      cloudContentService: mockCloudService,
      contentDownloadStatusDao: mockStatusDao,
    );
  });

  group('ContentVersionCheckService', () {
    group('checkForUpdates', () {
      test('delegates to cloud service with local versions', () async {
        when(() => mockStatusDao.getAllDownloadedVersions())
            .thenAnswer((_) async => {'bavli': '1.0'});
        when(
          () => mockCloudService.checkForUpdates(
            any(),
            any(),
          ),
        ).thenAnswer((_) async => [CurriculumId.bavli]);

        final result = await service.checkForUpdates([CurriculumId.bavli]);

        expect(result, [CurriculumId.bavli]);
      });

      test('returns empty on exception', () async {
        when(() => mockStatusDao.getAllDownloadedVersions())
            .thenThrow(Exception('db error'));

        final result = await service.checkForUpdates([CurriculumId.bavli]);

        expect(result, isEmpty);
      });
    });

    group('getMissingContent', () {
      test('returns curricula not yet downloaded', () async {
        when(() => mockStatusDao.getDownloadedCurricula())
            .thenAnswer((_) async => ['bavli']);

        final result = await service.getMissingContent([
          CurriculumId.bavli,
          CurriculumId.mishnayos,
        ]);

        expect(result, [CurriculumId.mishnayos]);
      });

      test('returns empty when all downloaded', () async {
        when(() => mockStatusDao.getDownloadedCurricula())
            .thenAnswer((_) async => ['bavli', 'mishnayos']);

        final result = await service.getMissingContent([
          CurriculumId.bavli,
          CurriculumId.mishnayos,
        ]);

        expect(result, isEmpty);
      });

      test('returns all when nothing downloaded', () async {
        when(() => mockStatusDao.getDownloadedCurricula())
            .thenAnswer((_) async => <String>[]);

        final result = await service.getMissingContent([
          CurriculumId.bavli,
          CurriculumId.mishnayos,
        ]);

        expect(result, hasLength(2));
      });
    });
  });
}
