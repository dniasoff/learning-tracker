import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockCurriculumActivationService extends Mock
    implements CurriculumActivationService {}

void main() {
  late MockContentRepository mockContentRepo;
  late MockCurriculumActivationService mockActivationService;
  late CurriculumImportService service;

  setUp(() {
    mockContentRepo = MockContentRepository();
    mockActivationService = MockCurriculumActivationService();
    service = CurriculumImportService(
      contentRepository: mockContentRepo,
      activationService: mockActivationService,
    );
  });

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  ContentItem _fakeItem(CurriculumId id) => ContentItem(
    curriculumId: id.storageKey,
    level1: 'L1',
    displayNameHe: 'test',
    displayNameEn: 'test',
    sefariaRef: 'test',
    sortOrder: 0,
    isLeaf: true,
  );

  group('CurriculumImportService', () {
    test('importAll yields progress for each curriculum', () async {
      final curricula = [CurriculumId.mishnayos, CurriculumId.bavli];

      when(
        () => mockContentRepo.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer((_) async => [_fakeItem(CurriculumId.mishnayos)]);
      when(
        () => mockContentRepo.getContentForCurriculum(CurriculumId.bavli),
      ).thenAnswer((_) async => [_fakeItem(CurriculumId.bavli)]);
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

      when(
        () => mockContentRepo.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenThrow(ContentLoadException('test error'));
      when(
        () => mockContentRepo.getContentForCurriculum(CurriculumId.bavli),
      ).thenAnswer((_) async => [_fakeItem(CurriculumId.bavli)]);
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
      when(
        () => mockContentRepo.getContentForCurriculum(CurriculumId.chumash),
      ).thenAnswer(
        (_) async => [
          _fakeItem(CurriculumId.chumash),
          _fakeItem(CurriculumId.chumash),
        ],
      );
      when(
        () => mockActivationService.activate(CurriculumId.chumash),
      ).thenAnswer((_) async {});

      final result = await service.importSingle(CurriculumId.chumash);

      expect(result.success, isTrue);
      expect(result.itemCount, 2);
      expect(result.curriculumId, CurriculumId.chumash);
    });

    test('importSingle returns failure on error', () async {
      when(
        () => mockContentRepo.getContentForCurriculum(CurriculumId.chumash),
      ).thenThrow(ContentLoadException('file not found'));

      final result = await service.importSingle(CurriculumId.chumash);

      expect(result.success, isFalse);
      expect(result.error, contains('file not found'));
    });

    test('importAll activates each curriculum in database', () async {
      final curricula = [CurriculumId.mishnayos, CurriculumId.bavli];

      when(
        () => mockContentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => [_fakeItem(CurriculumId.mishnayos)]);
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
      final progress = CurriculumImportProgress(
        current: 2,
        total: 5,
        currentCurriculum: CurriculumId.mishnayos,
        results: [],
      );
      expect(progress.fraction, closeTo(0.4, 0.001));
    });

    test('fraction handles zero total', () {
      final progress = CurriculumImportProgress(
        current: 0,
        total: 0,
        currentCurriculum: CurriculumId.mishnayos,
        results: [],
      );
      expect(progress.fraction, 0);
    });
  });
}
