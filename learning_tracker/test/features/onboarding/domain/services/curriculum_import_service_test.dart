import 'package:learning_tracker/core/database/daos/content_download_status_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockCurriculumActivationService extends Mock
    implements CurriculumActivationService {}

class MockCloudContentService extends Mock implements CloudContentService {}

class MockContentDownloadStatusDao extends Mock
    implements ContentDownloadStatusDao {}

void main() {
  late MockCurriculumActivationService mockActivationService;
  late MockCloudContentService mockCloudContentService;
  late MockContentDownloadStatusDao mockContentDownloadStatusDao;
  late CurriculumImportService service;

  setUp(() {
    mockActivationService = MockCurriculumActivationService();
    mockCloudContentService = MockCloudContentService();
    mockContentDownloadStatusDao = MockContentDownloadStatusDao();
    service = CurriculumImportService(
      activationService: mockActivationService,
      cloudContentService: mockCloudContentService,
      contentDownloadStatusDao: mockContentDownloadStatusDao,
    );
  });

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  ContentItem fakeItem(CurriculumId id) => ContentItem(
    curriculumId: id.storageKey,
    level1: 'L1',
    displayNameHe: 'test',
    displayNameEn: 'test',
    sefariaRef: 'test',
    sortOrder: 0,
    isLeaf: true,
  );

  void stubCloudDownload(CurriculumId curriculum) {
    when(
      () => mockCloudContentService.downloadContent(
        curriculum: curriculum,
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        const ContentDownloadProgress(
          state: ContentDownloadState.completed,
        ),
      ]),
    );

    when(
      () => mockCloudContentService.parseContent(
        curriculum: curriculum,
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer(
      (_) async => (
        items: [fakeItem(curriculum)],
        config: CurriculumHierarchyConfig(
          curriculumId: curriculum.storageKey,
          levelLabels: ['Level1'],
          totalItems: 1,
        ),
      ),
    );

    when(
      () => mockCloudContentService.getContentVersion(curriculum),
    ).thenAnswer((_) async => null);

    when(
      () => mockContentDownloadStatusDao.markDownloaded(
        curriculumId: any(named: 'curriculumId'),
        languageCode: any(named: 'languageCode'),
        contentVersion: any(named: 'contentVersion'),
        itemCount: any(named: 'itemCount'),
      ),
    ).thenAnswer((_) async {});
  }

  void stubCloudDownloadFailure(CurriculumId curriculum) {
    when(
      () => mockCloudContentService.downloadContent(
        curriculum: curriculum,
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        const ContentDownloadProgress(
          state: ContentDownloadState.failed,
          error: 'test error',
        ),
      ]),
    );
  }

  group('CurriculumImportService', () {
    test('importAll yields progress for each curriculum', () async {
      final curricula = [CurriculumId.mishnayos, CurriculumId.bavli];

      for (final c in curricula) {
        stubCloudDownload(c);
      }
      when(
        () => mockActivationService.activate(any()),
      ).thenAnswer((_) async {});

      final progressList = await service.importAll(curricula).toList();

      expect(progressList, hasLength(2));
      expect(progressList[0].current, 1);
      expect(progressList[0].total, 2);
      expect(progressList[1].current, 2);
      expect(progressList[1].total, 2);
      expect(progressList[1].isComplete, isTrue);
      expect(progressList[1].allSucceeded, isTrue);
    });

    test('importAll reports failures without stopping', () async {
      final curricula = [CurriculumId.mishnayos, CurriculumId.bavli];

      stubCloudDownloadFailure(CurriculumId.mishnayos);
      stubCloudDownload(CurriculumId.bavli);
      when(
        () => mockActivationService.activate(any()),
      ).thenAnswer((_) async {});

      final progressList = await service.importAll(curricula).toList();

      expect(progressList, hasLength(2));
      expect(progressList[0].results[0].success, isFalse);
      expect(progressList[1].results[1].success, isTrue);
      expect(progressList[1].failures, hasLength(1));
      expect(progressList[1].failures[0].curriculumId, CurriculumId.mishnayos);
    });

    test('importSingle returns success with item count', () async {
      stubCloudDownload(CurriculumId.chumash);
      when(
        () => mockActivationService.activate(CurriculumId.chumash),
      ).thenAnswer((_) async {});

      final result = await service.importSingle(CurriculumId.chumash);

      expect(result.success, isTrue);
      expect(result.itemCount, 1);
      expect(result.curriculumId, CurriculumId.chumash);
    });

    test('importSingle returns failure on error', () async {
      stubCloudDownloadFailure(CurriculumId.chumash);

      final result = await service.importSingle(CurriculumId.chumash);

      expect(result.success, isFalse);
    });

    test('importAll activates each curriculum in database', () async {
      final curricula = [CurriculumId.mishnayos, CurriculumId.bavli];

      for (final c in curricula) {
        stubCloudDownload(c);
      }
      when(
        () => mockActivationService.activate(any()),
      ).thenAnswer((_) async {});

      await service.importAll(curricula).toList();

      verify(
        () => mockActivationService.activate(CurriculumId.mishnayos),
      ).called(1);
      verify(
        () => mockActivationService.activate(CurriculumId.bavli),
      ).called(1);
    });

    test('empty curriculum list yields no progress', () async {
      final progressList = await service.importAll([]).toList();
      expect(progressList, isEmpty);
    });
  });

  group('CurriculumImportProgress', () {
    test('fraction computes correctly', () {
      const progress = CurriculumImportProgress(
        current: 2,
        total: 5,
        currentCurriculum: CurriculumId.mishnayos,
        results: [],
      );
      expect(progress.fraction, closeTo(0.4, 0.001));
    });

    test('fraction handles zero total', () {
      const progress = CurriculumImportProgress(
        current: 0,
        total: 0,
        currentCurriculum: CurriculumId.mishnayos,
        results: [],
      );
      expect(progress.fraction, 0);
    });
  });
}
