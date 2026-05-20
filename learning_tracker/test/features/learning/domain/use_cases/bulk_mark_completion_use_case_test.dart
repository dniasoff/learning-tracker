/// B1 three-tier credit policy — BulkMarkCompletionUseCase regression tests.
///
/// Verifies that [BulkMarkCompletionUseCase] correctly gates the engagement
/// tier (streak + points) based on [CompletionSource], matching the B1 policy
/// enforced by its single-item sibling [MarkCompletionUseCase].
///
/// These are mock-repository tests — no DB required, so they are fast and
/// deterministic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart';
import 'package:mocktail/mocktail.dart';

// ── Mock repository ───────────────────────────────────────────────────────────

class _MockCompletionRepository extends Mock implements CompletionRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// A minimal [BulkCompletionRequest] for testing — content doesn't matter.
BulkCompletionRequest _request({bool awardGamificationPoints = true}) =>
    BulkCompletionRequest(
      curriculumId: 'mishna',
      sefariaRefs: const ['Berakhot.1.1'],
      stageId: 1,
      trackType: 'personal',
      awardGamificationPoints: awardGamificationPoints,
    );

void main() {
  setUpAll(() {
    // mocktail requires a fallback value for any() / captureAny() matchers on
    // custom types. Register a minimal instance here.
    registerFallbackValue(
      const BulkCompletionRequest(
        curriculumId: 'fallback',
        sefariaRefs: [],
        stageId: 0,
        trackType: 'personal',
      ),
    );
  });

  late _MockCompletionRepository repository;
  late BulkMarkCompletionUseCase useCase;

  setUp(() {
    repository = _MockCompletionRepository();
    useCase = BulkMarkCompletionUseCase(repository);

    // Stub bulkMarkComplete to capture the request passed to it.
    when(
      () => repository.bulkMarkComplete(any()),
    ).thenAnswer((_) async => const <Completion>[]);
  });

  // ── C2: Default source is bulkInTrack — engagement NOT credited ─────────────

  group('C2 — BulkMarkCompletionUseCase B1 engagement gate', () {
    test(
      'default source (bulkInTrack) passes awardGamificationPoints = false',
      () async {
        await useCase(_request());

        final captured =
            verify(
                  () => repository.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        expect(
          captured.awardGamificationPoints,
          isFalse,
          reason:
              'bulkInTrack (default) must suppress engagement — '
              'B1 policy violation if this is true',
        );
      },
    );

    test(
      'explicit bulkInTrack source passes awardGamificationPoints = false',
      () async {
        await useCase(_request(), source: CompletionSource.bulkInTrack);

        final captured =
            verify(
                  () => repository.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        expect(captured.awardGamificationPoints, isFalse);
      },
    );

    test(
      'lifetimeOnly source passes awardGamificationPoints = false',
      () async {
        await useCase(_request(), source: CompletionSource.lifetimeOnly);

        final captured =
            verify(
                  () => repository.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        expect(
          captured.awardGamificationPoints,
          isFalse,
          reason: 'lifetimeOnly must also suppress engagement',
        );
      },
    );

    test('live source passes awardGamificationPoints = true', () async {
      await useCase(_request(), source: CompletionSource.live);

      final captured =
          verify(
                () => repository.bulkMarkComplete(captureAny()),
              ).captured.single
              as BulkCompletionRequest;

      expect(
        captured.awardGamificationPoints,
        isTrue,
        reason: 'live source must credit engagement',
      );
    });

    test(
      'request fields other than awardGamificationPoints are preserved',
      () async {
        const inputRequest = BulkCompletionRequest(
          curriculumId: 'talmud',
          sefariaRefs: ['Shabbat.2a', 'Shabbat.2b'],
          stageId: 3,
          trackType: 'review',
          profileId: 42,
        );

        await useCase(inputRequest, source: CompletionSource.bulkInTrack);

        final captured =
            verify(
                  () => repository.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        expect(captured.curriculumId, 'talmud');
        expect(captured.sefariaRefs, ['Shabbat.2a', 'Shabbat.2b']);
        expect(captured.stageId, 3);
        expect(captured.trackType, 'review');
        expect(captured.profileId, 42);
        // engagement gate overridden by source
        expect(captured.awardGamificationPoints, isFalse);
      },
    );

    // Structural invariant: the use case default must NEVER credit engagement.
    // This is the core C2 regression guard.
    test('structural invariant: default source never credits engagement', () {
      // If CompletionSource.bulkInTrack ever becomes creditsEngagement = true,
      // this test will catch it immediately.
      expect(
        CompletionSource.bulkInTrack.creditsEngagement,
        isFalse,
        reason:
            'bulkInTrack MUST NOT credit engagement — '
            'BulkMarkCompletionUseCase default depends on this',
      );
    });
  });
}
