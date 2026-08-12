/// Regression test for curriculumBreakdownProvider staleness (DG-BRKD-01).
///
/// `curriculumBreakdownProvider` MUST be re-evaluated after a completion is
/// committed (i.e., when `completionCommittedProvider` increments). If the
/// provider does NOT watch `completionCommittedProvider`, the per-curriculum
/// chip breakdown in [PointsDisplayWidget] stays STALE after a completion —
/// the total counter (globalPointsProvider) updates reactively but the
/// curriculum chips don't.
///
/// BEFORE the fix: `curriculumBreakdownProvider` does not watch
/// `completionCommittedProvider`. After an increment the provider stays cached
/// and is NOT invalidated.
///
/// AFTER the fix: `curriculumBreakdownProvider` watches
/// `completionCommittedProvider` (same as `achievementsOverviewProvider` and
/// `dashboardCompletionPercentageProvider`), causing a fresh re-read of the
/// per-curriculum completion sums whenever a completion is committed.
@Tags(['gamification', 'staleness'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _AlwaysEligible implements CurriculumRewardEligibility {
  @override
  Future<bool> isEligible(CurriculumId curriculumId) async => true;
}

class _ZeroBalance implements PointsBalanceReader {
  @override
  Future<int> getBalance() async => 0;
}

void main() {
  group('curriculumBreakdownProvider — rebuild after completionCommitted '
      '(DG-BRKD-01)', () {
    test('curriculumBreakdownProvider is invalidated (re-evaluated) after '
        'completionCommittedProvider increments', () async {
      final repository = _MockCompletionRepository();
      when(
        () => repository.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => const []);

      final container = ProviderContainer(
        overrides: [
          completionRepositoryProvider.overrideWithValue(repository),
          pointsServiceProvider.overrideWithValue(
            PointsService(
              eligibility: _AlwaysEligible(),
              balanceReader: _ZeroBalance(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Subscribe to the provider to ensure it's alive.
      final loadingStates = <bool>[];
      container.listen<AsyncValue<Object?>>(curriculumBreakdownProvider, (
        _,
        next,
      ) {
        loadingStates.add(next is AsyncLoading);
      }, fireImmediately: true);

      // Wait for initial load to complete.
      await container.read(curriculumBreakdownProvider.future);

      // Capture the count of loading transitions before the increment.
      final loadingCountBefore = loadingStates.where((v) => v).length;

      // Increment completionCommittedProvider.
      container.read(completionCommittedProvider.notifier).increment();

      // Allow the FutureProvider to react — deterministically drain the
      // microtask queue (TQ-6 / AUD-t-gamification-01: no wall-clock waits
      // in hermetic tests) instead of racing a fixed-millisecond sleep.
      await pumpEventQueue();

      // After the increment, the provider must have entered loading state
      // again (re-evaluated). The loading count must have increased.
      final loadingCountAfter = loadingStates.where((v) => v).length;

      expect(
        loadingCountAfter,
        greaterThan(loadingCountBefore),
        reason:
            'curriculumBreakdownProvider must be re-evaluated (enter '
            'AsyncLoading) after completionCommittedProvider increments. '
            'If this fails the provider is missing the '
            'ref.watch(completionCommittedProvider) dependency — the '
            'breakdown chips stay stale after a completion is committed.',
      );
    });
  });
}
