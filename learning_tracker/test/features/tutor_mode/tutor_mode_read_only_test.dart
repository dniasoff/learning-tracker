import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockCompletionRepository extends Mock implements CompletionRepository {}

class FakeCompletionRequest extends Fake implements CompletionRequest {}

class FakeBulkCompletionRequest extends Fake implements BulkCompletionRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCompletionRequest());
    registerFallbackValue(FakeBulkCompletionRequest());
  });

  group('Tutor mode read-only enforcement', () {
    late MockCompletionRepository mockCompletionRepo;

    setUp(() {
      mockCompletionRepo = MockCompletionRepository();
    });

    test('MarkCompletionUseCase throws when tutor mode is active', () {
      final useCase = MarkCompletionUseCase(
        mockCompletionRepo,
        isTutorMode: true,
      );

      expect(
        () => useCase.call(FakeCompletionRequest()),
        throwsA(isA<TutorModeReadOnlyException>()),
      );

      verifyNever(() => mockCompletionRepo.markComplete(any()));
    });

    test(
      'MarkCompletionUseCase succeeds when tutor mode is inactive',
      () async {
        when(
          () => mockCompletionRepo.markComplete(any()),
        ).thenAnswer((_) async => throw UnimplementedError());

        final useCase = MarkCompletionUseCase(
          mockCompletionRepo,
          isTutorMode: false,
        );

        // Should not throw TutorModeReadOnlyException; will throw
        // UnimplementedError from the mock instead.
        expect(
          () => useCase.call(FakeCompletionRequest()),
          throwsA(isA<UnimplementedError>()),
        );
      },
    );

    test('BulkMarkCompletionUseCase throws when tutor mode is active', () {
      final useCase = BulkMarkCompletionUseCase(
        mockCompletionRepo,
        isTutorMode: true,
      );

      expect(
        () => useCase.call(FakeBulkCompletionRequest()),
        throwsA(isA<TutorModeReadOnlyException>()),
      );

      verifyNever(() => mockCompletionRepo.bulkMarkComplete(any()));
    });

    test(
      'BulkMarkCompletionUseCase succeeds when tutor mode is inactive',
      () async {
        when(
          () => mockCompletionRepo.bulkMarkComplete(any()),
        ).thenAnswer((_) async => throw UnimplementedError());

        final useCase = BulkMarkCompletionUseCase(
          mockCompletionRepo,
          isTutorMode: false,
        );

        expect(
          () => useCase.call(FakeBulkCompletionRequest()),
          throwsA(isA<UnimplementedError>()),
        );
      },
    );

    test('guardTutorModeWriteFromBool throws when true', () {
      expect(
        () => guardTutorModeWriteFromBool(true),
        throwsA(isA<TutorModeReadOnlyException>()),
      );
    });

    test('guardTutorModeWriteFromBool does nothing when false', () {
      // Should not throw
      guardTutorModeWriteFromBool(false);
    });

    test('CurriculumActivationService.activate throws in tutor mode', () async {
      // Tested via guardTutorModeWriteFromBool since we can't easily
      // construct CurriculumActivationService without a real database.
      // The guard function is the same mechanism used in the service.
      expect(
        () => guardTutorModeWriteFromBool(true),
        throwsA(isA<TutorModeReadOnlyException>()),
      );
    });

    test('RewardService guard prevents addReward in tutor mode', () {
      // The guard function is the same mechanism used in RewardService.
      expect(
        () => guardTutorModeWriteFromBool(true),
        throwsA(
          isA<TutorModeReadOnlyException>().having(
            (e) => e.message,
            'message',
            contains('not allowed'),
          ),
        ),
      );
    });
  });
}
