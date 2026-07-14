/// Regression test for childRedemptionBalanceProvider staleness
/// (DG-RDMP-01).
///
/// `childRedemptionBalanceProvider` MUST NOT be a stale one-shot FutureProvider.
/// After a parent adjusts the child's balance (or after a redemption debit),
/// the ChildRedemptionScreen's balance card must update LIVE without requiring
/// a pull-to-refresh or explicit `ref.invalidate`.
///
/// BEFORE the fix: `childRedemptionBalanceProvider` calls
/// `db.pointsBalanceDao.getBalance()` (one-shot). After a credit the provider
/// keeps the stale value until explicitly invalidated.
///
/// AFTER the fix: `childRedemptionBalanceProvider` is backed by a
/// StreamProvider (watchBalance). Any write to the PointsBalance row causes
/// the stream to emit the new value immediately.
@Tags(['gamification', 'staleness'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../../../helpers/drift_memory.dart';

/// Helper: subscribes a listener to the childRedemptionBalanceProvider and
/// returns a list that accumulates emitted values.
List<int> _captureEmissions(ProviderContainer container) {
  final emissions = <int>[];
  container.listen<AsyncValue<int>>(childRedemptionBalanceProvider, (_, next) {
    next.whenData(emissions.add);
  }, fireImmediately: true);
  return emissions;
}

void main() {
  group('childRedemptionBalanceProvider — reactive stream (DG-RDMP-01)', () {
    test('childRedemptionBalanceProvider re-emits updated balance after '
        'parentAdjust WITHOUT explicit invalidation (must be stream-backed, '
        'not one-shot FutureProvider)', () async {
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

      final emissions = _captureEmissions(container);

      // Initial balance is 0. Deterministically drain the microtask queue
      // (TQ-6 / AUD-t-gamification-07) instead of racing a fixed-millisecond
      // sleep against Drift's watch stream.
      await pumpEventQueue();
      expect(emissions, contains(0), reason: 'initial balance must be 0');

      // Parent awards 100 points.
      await db.pointsBalanceDao.creditCompletion(1, 100);

      // Allow the reactive stream to propagate.
      await pumpEventQueue();

      // Without explicit invalidation, the reactive provider must emit 100.
      expect(
        emissions,
        contains(100),
        reason:
            'childRedemptionBalanceProvider must emit the new balance '
            'reactively after creditCompletion — not require explicit '
            'invalidation. If this fails the provider is still a stale '
            'FutureProvider.',
      );
    });

    test('childRedemptionBalanceProvider re-emits debited balance after '
        'createRedemption WITHOUT explicit invalidation', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      // Start with 80 points.
      await db.pointsBalanceDao.creditCompletion(1, 80);

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
        ],
      );
      addTearDown(container.dispose);

      final emissions = _captureEmissions(container);
      // Deterministically drain the microtask queue (TQ-6 /
      // AUD-t-gamification-07) instead of racing a fixed-millisecond sleep
      // against Drift's watch stream.
      await pumpEventQueue();
      expect(emissions, contains(80));

      // Debit 30 via a redemption.
      await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Toy',
        iconIndex: 0,
        pointsCost: 30,
      );

      await pumpEventQueue();

      // Must have emitted 50 (80 - 30) without invalidation.
      expect(
        emissions,
        contains(50),
        reason:
            'childRedemptionBalanceProvider must emit debited balance (50) '
            'after createRedemption without requiring invalidation.',
      );
    });
  });
}
