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
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart';
import 'package:mocktail/mocktail.dart';

// ── Mock repository ───────────────────────────────────────────────────────────

class _MockCompletionOrchestrator extends Mock
    implements CompletionOrchestrator {}

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

  late _MockCompletionOrchestrator orchestrator;
  late BulkMarkCompletionUseCase useCase;

  setUp(() {
    orchestrator = _MockCompletionOrchestrator();
    useCase = BulkMarkCompletionUseCase(orchestrator);

    // Stub bulkMarkComplete to capture the request passed to it.
    when(
      () => orchestrator.bulkMarkComplete(any()),
    ).thenAnswer((_) async => const <CompletionEntity>[]);
  });

  // ── C2: Default source is bulkInTrack — engagement NOT credited ─────────────

  group('C2 — BulkMarkCompletionUseCase B1 engagement gate', () {
    test(
      'default source (bulkInTrack) passes awardGamificationPoints = false',
      () async {
        await useCase(_request());

        final captured =
            verify(
                  () => orchestrator.bulkMarkComplete(captureAny()),
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
                  () => orchestrator.bulkMarkComplete(captureAny()),
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
                  () => orchestrator.bulkMarkComplete(captureAny()),
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
                () => orchestrator.bulkMarkComplete(captureAny()),
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
        );

        await useCase(inputRequest, source: CompletionSource.bulkInTrack);

        final captured =
            verify(
                  () => orchestrator.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        expect(captured.curriculumId, 'talmud');
        expect(captured.sefariaRefs, ['Shabbat.2a', 'Shabbat.2b']);
        expect(captured.stageId, 3);
        expect(captured.trackType, 'review');
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

  // ── C3: Sentinel date enforcement for non-live sources ───────────────────────
  //
  // For bulkInTrack and lifetimeOnly, completedAt MUST be the sentinel
  // DateTime.utc(2000, 1, 1) so stored rows fall below any streak/pace
  // filter threshold. The use case is the enforcement point — no caller
  // can accidentally write DateTime.now() for a prior-mark row.

  group('C3 — sentinel date enforcement', () {
    final sentinel = DateTime.utc(2000, 1, 1);

    BulkCompletionRequest requestWithoutDate() => const BulkCompletionRequest(
      curriculumId: 'mishna',
      sefariaRefs: ['Berakhot.1.1'],
      stageId: 1,
      trackType: 'personal',
      // completedAt intentionally omitted — use case must supply sentinel
    );

    test(
      'bulkInTrack (default) enforces sentinel date when completedAt is null',
      () async {
        await useCase(requestWithoutDate());

        final captured =
            verify(
                  () => orchestrator.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        expect(
          captured.completedAt,
          equals(sentinel),
          reason:
              'bulkInTrack completions must store DateTime.utc(2000,1,1) '
              'so they fall below streak/pace filter thresholds',
        );
      },
    );

    test('explicit bulkInTrack source enforces sentinel date', () async {
      await useCase(requestWithoutDate(), source: CompletionSource.bulkInTrack);

      final captured =
          verify(
                () => orchestrator.bulkMarkComplete(captureAny()),
              ).captured.single
              as BulkCompletionRequest;

      expect(captured.completedAt, equals(sentinel));
    });

    test('lifetimeOnly source enforces sentinel date', () async {
      await useCase(
        requestWithoutDate(),
        source: CompletionSource.lifetimeOnly,
      );

      final captured =
          verify(
                () => orchestrator.bulkMarkComplete(captureAny()),
              ).captured.single
              as BulkCompletionRequest;

      expect(
        captured.completedAt,
        equals(sentinel),
        reason:
            'lifetimeOnly also suppresses engagement — '
            'must use sentinel to avoid contaminating streak math',
      );
    });

    test(
      'live source passes completedAt through as null (repo uses nowUtc)',
      () async {
        await useCase(requestWithoutDate(), source: CompletionSource.live);

        final captured =
            verify(
                  () => orchestrator.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        // For live source the use case does NOT override completedAt —
        // the repository defaults null → DateTime.now() at write time.
        expect(
          captured.completedAt,
          isNull,
          reason:
              'live source must not force the sentinel — '
              'it should write a real timestamp',
        );
      },
    );

    test(
      'live source with explicit completedAt preserves caller value',
      () async {
        final explicitDate = DateTime.utc(2026, 5, 20, 10, 0, 0);
        final requestWithDate = BulkCompletionRequest(
          curriculumId: 'mishna',
          sefariaRefs: const ['Berakhot.1.1'],
          stageId: 1,
          trackType: 'personal',
          completedAt: explicitDate,
        );

        await useCase(requestWithDate, source: CompletionSource.live);

        final captured =
            verify(
                  () => orchestrator.bulkMarkComplete(captureAny()),
                ).captured.single
                as BulkCompletionRequest;

        expect(
          captured.completedAt,
          equals(explicitDate),
          reason: 'live source must not override explicit completedAt',
        );
      },
    );
  });
}
