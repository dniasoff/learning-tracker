/// Unit tests for [RewardRedemptionMerger]: pulled redemptions upsert with
/// later `updated_at` winning (LWW), plus the redeem->decline convergence
/// loop (which also exercises [PointsLedgerMerger] for the refund entry —
/// see lib/core/sync/merge/points_ledger_merger.dart's own mirrored test
/// for that merger's dedicated coverage).
///
/// AG-5 (AUD-app-05): split out of the former
/// test/core/sync/merge/points_sync_merger_test.dart (AUD-app-05) so this
/// file mirrors lib/core/sync/merge/reward_redemption_merger.dart 1:1.
/// PointsLedgerMerger's tests moved to
/// test/core/sync/merge/points_ledger_merger_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/points_ledger_merger.dart';
import 'package:learning_tracker/core/sync/merge/reward_redemption_merger.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('RewardRedemptionMerger', () {
    test(
      'pulled redemption is upserted; later updated_at wins (LWW)',
      () async {
        final db = createTestDatabase();
        await seedProfile(db);
        final profileId = (await db.select(db.learnerProfiles).get()).first.id;
        final merger = RewardRedemptionMerger(db);

        // Pending state pulled first.
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'REDEEM_01',
              'profile_id': profileId,
              'reward_title': 'Ice cream',
              'icon_index': 2,
              'points_cost': 20,
              'status': 'pending_fulfilment',
              'created_at': DateTime.utc(2026, 1, 1, 10).toIso8601String(),
              'updated_at': DateTime.utc(2026, 1, 1, 10).toIso8601String(),
            },
          ],
        );

        var rows = await db.pointsBalanceDao.getAllRedemptions(profileId);
        expect(rows, hasLength(1));
        expect(rows.first.status, 'pending_fulfilment');

        // Parent device fulfilled — newer updated_at wins.
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'REDEEM_01',
              'profile_id': profileId,
              'reward_title': 'Ice cream',
              'icon_index': 2,
              'points_cost': 20,
              'status': 'fulfilled',
              'created_at': DateTime.utc(2026, 1, 1, 10).toIso8601String(),
              'updated_at': DateTime.utc(2026, 1, 1, 11).toIso8601String(),
            },
          ],
        );

        rows = await db.pointsBalanceDao.getAllRedemptions(profileId);
        expect(rows, hasLength(1));
        expect(rows.first.status, 'fulfilled');

        // A stale pending re-pull (older updated_at) must NOT overwrite.
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'REDEEM_01',
              'profile_id': profileId,
              'reward_title': 'Ice cream',
              'icon_index': 2,
              'points_cost': 20,
              'status': 'pending_fulfilment',
              'created_at': DateTime.utc(2026, 1, 1, 10).toIso8601String(),
              'updated_at': DateTime.utc(2026, 1, 1, 10).toIso8601String(),
            },
          ],
        );

        rows = await db.pointsBalanceDao.getAllRedemptions(profileId);
        expect(rows.first.status, 'fulfilled');
      },
    );
  });

  group('redeem→decline loop converges across devices', () {
    test(
      'child debit + parent decline refund re-derive the balance to original',
      () async {
        final db = createTestDatabase();
        await seedProfile(db);
        final profileId = (await db.select(db.learnerProfiles).get()).first.id;
        final ledgerMerger = PointsLedgerMerger(db);
        final redemptionMerger = RewardRedemptionMerger(db);

        // Child device A: +30 earned, then redeem (-20 debit) → balance 10.
        await ledgerMerger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'CREDIT_30',
              'profile_id': profileId,
              'entry_kind': 'completion',
              'delta': 30,
              'created_at': DateTime.utc(2026, 1, 1, 8).toIso8601String(),
            },
            {
              'ulid': 'DEBIT_20',
              'profile_id': profileId,
              'entry_kind': 'redemption_debit',
              'delta': -20,
              'redemption_ulid': 'REDEEM_X',
              'created_at': DateTime.utc(2026, 1, 1, 9).toIso8601String(),
            },
          ],
        );
        await redemptionMerger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'REDEEM_X',
              'profile_id': profileId,
              'reward_title': 'Toy',
              'icon_index': 0,
              'points_cost': 20,
              'status': 'pending_fulfilment',
              'created_at': DateTime.utc(2026, 1, 1, 9).toIso8601String(),
              'updated_at': DateTime.utc(2026, 1, 1, 9).toIso8601String(),
            },
          ],
        );
        expect(await db.pointsBalanceDao.getBalance(profileId), 10);

        // Parent device B declines → status declined + refund ledger entry.
        await redemptionMerger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'REDEEM_X',
              'profile_id': profileId,
              'reward_title': 'Toy',
              'icon_index': 0,
              'points_cost': 20,
              'status': 'declined',
              'created_at': DateTime.utc(2026, 1, 1, 9).toIso8601String(),
              'updated_at': DateTime.utc(2026, 1, 1, 12).toIso8601String(),
            },
          ],
        );
        await ledgerMerger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'REFUND_20',
              'profile_id': profileId,
              'entry_kind': 'redemption_refund',
              'delta': 20,
              'redemption_ulid': 'REDEEM_X',
              'created_at': DateTime.utc(2026, 1, 1, 12).toIso8601String(),
            },
          ],
        );

        // Balance back to 30; redemption is terminal declined.
        expect(await db.pointsBalanceDao.getBalance(profileId), 30);
        final rows = await db.pointsBalanceDao.getAllRedemptions(profileId);
        expect(rows.single.status, 'declined');
      },
    );
  });
}
