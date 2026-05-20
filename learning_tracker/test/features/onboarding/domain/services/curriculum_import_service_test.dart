import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockCurriculumActivationService extends Mock
    implements CurriculumActivationService {}

void main() {
  late MockCurriculumActivationService mockActivationService;
  late CurriculumImportService service;

  setUp(() {
    mockActivationService = MockCurriculumActivationService();
    service = CurriculumImportService(activationService: mockActivationService);
  });

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  group('CurriculumImportService', () {
    test('importAll yields progress for each curriculum', () async {
      final curricula = [CurriculumId.mishnayos, CurriculumId.bavli];

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
        () => mockActivationService.activate(CurriculumId.mishnayos),
      ).thenThrow(Exception('activation error'));
      when(
        () => mockActivationService.activate(CurriculumId.bavli),
      ).thenAnswer((_) async {});

      final progressList = await service.importAll(curricula).toList();

      expect(progressList, hasLength(2));
      expect(progressList[0].results[0].success, isFalse);
      expect(progressList[1].results[1].success, isTrue);
      expect(progressList[1].failures, hasLength(1));
      expect(progressList[1].failures[0].curriculumId, CurriculumId.mishnayos);
    });

    test('importSingle returns success', () async {
      when(
        () => mockActivationService.activate(CurriculumId.chumash),
      ).thenAnswer((_) async {});

      final result = await service.importSingle(CurriculumId.chumash);

      expect(result.success, isTrue);
      expect(result.curriculumId, CurriculumId.chumash);
    });

    test('importSingle returns failure on error', () async {
      when(
        () => mockActivationService.activate(CurriculumId.chumash),
      ).thenThrow(Exception('activation error'));

      final result = await service.importSingle(CurriculumId.chumash);

      expect(result.success, isFalse);
    });

    test('importAll activates each curriculum in database', () async {
      final curricula = [CurriculumId.mishnayos, CurriculumId.bavli];

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
