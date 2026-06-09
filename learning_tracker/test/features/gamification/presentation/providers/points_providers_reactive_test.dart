/// Regression tests for points-provider staleness (DG-DASH-02 / D2/D9).
///
/// `globalPointsProvider` must NOT be a stale one-shot FutureProvider. After
/// a redemption debit (or any balance mutation) the provider must emit the
/// updated balance without requiring a pull-to-refresh.
///
/// The test drives the provider via a [ProviderContainer] and asserts that a
/// subsequent creditCompletion / createRedemption causes the provider to
/// re-emit the new value — i.e. it must be backed by a reactive stream, NOT
/// a one-shot Future.
///
/// BEFORE the fix: `globalPointsProvider` calls `service.getGlobalTotal()`
/// (one-shot `getBalance`). After a credit the provider keeps the stale value
/// until explicitly invalidated.
///
/// AFTER the fix: `globalPointsProvider` is backed by a StreamProvider
/// (watchBalance). The container sees the updated value without invalidation.
@Tags(['gamification', 'staleness'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../../../helpers/drift_memory.dart';

/// Helper: subscribes a listener to the globalPointsProvider stream and
/// returns a list that accumulates emitted values. Caller disposes of the
/// [ProviderContainer] themselves.
List<int> _captureEmissions(ProviderContainer container) {
  final emissions = <int>[];
  container.listen<AsyncValue<int>>(
    globalPointsProvider,
    (_, next) {
      next.whenData(emissions.add);
    },
    fireImmediately: true,
  );
  return emissions;
}

void main() {
  group('globalPointsProvider — reactive stream (DG-DASH-02 / D2/D9)', () {
    test(
      'globalPointsProvider re-emits updated balance after creditCompletion '
      'WITHOUT explicit invalidation (must be stream-backed, not one-shot)',
      () async {
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

        // Initial balance is 0 — first emission.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(emissions, contains(0), reason: 'initial balance must be 0');

        // Credit 50 points — this mutates PointsBalance in the DB.
        await db.pointsBalanceDao.creditCompletion(1, 50);

        // Allow the reactive stream to propagate.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Without invalidation, the reactive provider must have emitted 50.
        expect(
          emissions,
          contains(50),
          reason:
              'globalPointsProvider must emit the new balance reactively '
              'after creditCompletion — not require explicit invalidation. '
              'If this fails the provider is still a stale FutureProvider.',
        );
      },
    );

    test(
      'globalPointsProvider re-emits updated balance after createRedemption '
      'debit WITHOUT explicit invalidation',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        // Start with 100 points.
        await db.pointsBalanceDao.creditCompletion(1, 100);

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWithValue(1),
          ],
        );
        addTearDown(container.dispose);

        final emissions = _captureEmissions(container);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(emissions, contains(100));

        // Debit 40 points via a redemption.
        await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'Ice Cream',
          iconIndex: 0,
          pointsCost: 40,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Provider must have emitted 60, not remain stale at 100.
        expect(
          emissions,
          contains(60),
          reason:
              'globalPointsProvider must emit debited balance (60) after '
              'createRedemption without requiring invalidation.',
        );
      },
    );
  });

  group(
    'globalPointsProvider — reactive stream after parent decline refund',
    () {
      test(
        'globalPointsProvider re-emits updated balance after declineRedemption '
        'refund WITHOUT explicit invalidation (DG-PND-02)',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);
          await seedProfile(db);

          await db.pointsBalanceDao.creditCompletion(1, 100);
          final redemption = await db.pointsBalanceDao.createRedemption(
            profileId: 1,
            rewardTitle: 'Toy',
            iconIndex: 0,
            pointsCost: 40,
          );
          expect(redemption, isNotNull);
          // Balance is now 60 after debit.

          final container = ProviderContainer(
            overrides: [
              userDatabaseProvider.overrideWithValue(db),
              activeProfileIdProvider.overrideWithValue(1),
            ],
          );
          addTearDown(container.dispose);

          final emissions = _captureEmissions(container);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(emissions, contains(60), reason: 'balance should be 60 after debit');

          // Parent declines → refund 40 → balance back to 100.
          await db.pointsBalanceDao.declineRedemption(redemption!.id);

          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(
            emissions,
            contains(100),
            reason:
                'globalPointsProvider must emit the refunded balance (100) '
                'without requiring explicit invalidation.',
          );
        },
      );
    },
  );
}
