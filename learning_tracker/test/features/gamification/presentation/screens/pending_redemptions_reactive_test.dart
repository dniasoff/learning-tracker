/// Regression test for pendingRedemptionsProvider staleness (DG-PND-05).
///
/// `pendingRedemptionsProvider` MUST NOT be a stale one-shot FutureProvider.
/// When a child creates a new redemption while the parent has the screen open,
/// the pending list must update LIVE without requiring navigation away and back
/// (i.e. the list is backed by a reactive stream, not a one-shot Future).
///
/// BEFORE the fix: `pendingRedemptionsProvider` calls
/// `db.pointsBalanceDao.getPendingRedemptions()` (one-shot). After a new
/// redemption row is inserted, the list stays stale until `ref.invalidate()`
/// is called.
///
/// AFTER the fix: `pendingRedemptionsProvider` is backed by
/// [PointsBalanceDao.watchPendingRedemptions] (a reactive Drift stream). Any
/// write to the `reward_redemptions` table causes the stream to emit the
/// updated list without requiring manual invalidation.
@Tags(['gamification', 'staleness'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../../../helpers/drift_memory.dart';

/// Helper: subscribes a listener to pendingRedemptionsProvider and
/// returns a list that accumulates emitted list values.
List<List<RewardRedemption>> _captureEmissions(ProviderContainer container) {
  final emissions = <List<RewardRedemption>>[];
  container.listen<AsyncValue<List<RewardRedemption>>>(
    pendingRedemptionsProvider,
    (_, next) {
      next.whenData(emissions.add);
    },
    fireImmediately: true,
  );
  return emissions;
}

/// Insert a pending-fulfilment row directly without debiting balance.
Future<void> _insertPendingRedemption(
  UserDatabase db, {
  required int profileId,
  String rewardTitle = 'Test Prize',
  int iconIndex = 0,
  int pointsCost = 50,
}) async {
  final now = DateTimeFactory.nowUtc();
  await db.into(db.rewardRedemptions).insert(
    RewardRedemptionsCompanion.insert(
      profileId: profileId,
      rewardTitle: rewardTitle,
      iconIndex: Value(iconIndex),
      pointsCost: pointsCost,
      status: const Value('pending_fulfilment'),
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  group(
    'pendingRedemptionsProvider — reactive stream (DG-PND-05)',
    () {
      test(
        'pendingRedemptionsProvider re-emits updated list when a new '
        'redemption is inserted WITHOUT explicit ref.invalidate() '
        '(must be stream-backed, not one-shot FutureProvider)',
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

          // Initial state: empty list.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(
            emissions.any((list) => list.isEmpty),
            isTrue,
            reason: 'initial emissions must include an empty list',
          );

          // Insert a pending redemption row directly (simulates child submitting
          // or a cloud-sync push landing a new row).
          await _insertPendingRedemption(
            db,
            profileId: 1,
            rewardTitle: 'Ice Cream',
            pointsCost: 40,
          );

          // Allow the reactive stream to propagate.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Without ref.invalidate(), the reactive provider must have emitted a
          // list containing the new row.
          final flatTitles = emissions.expand((list) => list).map(
            (r) => r.rewardTitle,
          );
          expect(
            flatTitles,
            contains('Ice Cream'),
            reason:
                'pendingRedemptionsProvider must emit the updated list '
                'reactively after a new redemption row is inserted — without '
                'requiring explicit ref.invalidate(). If this fails the '
                'provider is still a stale FutureProvider.',
          );
        },
      );

      test(
        'pendingRedemptionsProvider emits list minus fulfilled item '
        'reactively after fulfilRedemption WITHOUT explicit invalidation',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);
          await seedProfile(db);

          // Seed a pending row.
          await _insertPendingRedemption(
            db,
            profileId: 1,
            rewardTitle: 'Toy',
            pointsCost: 30,
          );

          final container = ProviderContainer(
            overrides: [
              userDatabaseProvider.overrideWithValue(db),
              activeProfileIdProvider.overrideWithValue(1),
            ],
          );
          addTearDown(container.dispose);

          final emissions = _captureEmissions(container);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Must initially have emitted the pending row.
          final allRows = emissions.expand((list) => list).toList();
          expect(
            allRows.any((r) => r.rewardTitle == 'Toy'),
            isTrue,
            reason: 'initial emission must contain the pending row',
          );
          final row = allRows.firstWhere((r) => r.rewardTitle == 'Toy');

          // Fulfil the redemption — list must shrink without invalidation.
          await db.pointsBalanceDao.fulfilRedemption(row.id);

          await Future<void>.delayed(const Duration(milliseconds: 50));

          // After fulfilment, an emission with an EMPTY list must have arrived.
          expect(
            emissions.any((list) => list.isEmpty),
            isTrue,
            reason:
                'pendingRedemptionsProvider must emit an empty list reactively '
                'after fulfilRedemption, without requiring explicit '
                'ref.invalidate().',
          );
        },
      );
    },
  );
}
