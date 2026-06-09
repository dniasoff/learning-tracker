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
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  group('curriculumBreakdownProvider — rebuild after completionCommitted '
      '(DG-BRKD-01)', () {
    test('curriculumBreakdownProvider is invalidated (re-evaluated) after '
        'completionCommittedProvider increments', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
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

      // Allow the FutureProvider to react.
      await Future<void>.delayed(const Duration(milliseconds: 50));

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
