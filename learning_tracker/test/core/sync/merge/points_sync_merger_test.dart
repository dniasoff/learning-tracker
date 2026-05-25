/// WS9 Wave-B (C#2) — cross-device convergence tests for the points spend
/// economy sync wiring.
///
/// Proves the redeem→fulfil→decline loop works across two devices:
///   - append-only `points_ledger` entries merge by ULID (INSERT-OR-IGNORE)
///     and the local balance is re-derived from the merged ledger,
///   - `reward_redemptions` merge LWW by `updated_at`,
///   - a decline's refund ledger entry re-credits the derived balance.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/points_ledger_merger.dart';
import 'package:learning_tracker/core/sync/merge/reward_redemption_merger.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('PointsLedgerMerger', () {
    test(
      'pulled ledger entries are inserted by ULID and balance is re-derived',
      () async {
        final db = createTestDatabase();
        await seedProfile(db);
        final profileId = (await db.select(db.learnerProfiles).get()).first.id;

        final merger = PointsLedgerMerger(db);

        // Device A earned +50 then redeemed -20 → balance 30.
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'ulid': 'LEDGER_CREDIT_01',
              'profile_id': profileId,
              'entry_kind': 'completion',
              'delta': 50,
              'created_at': DateTime.utc(2026, 1, 1, 9).toIso8601String(),
            },
            {
              'ulid': 'LEDGER_DEBIT_01',
              'profile_id': profileId,
              'entry_kind': 'redemption_debit',
              'delta': -20,
              'created_at': DateTime.utc(2026, 1, 1, 10).toIso8601String(),
            },
          ],
        );

        expect(await db.pointsBalanceDao.getBalance(profileId), 30);
        expect(await db.pointsBalanceDao.getLedger(profileId), hasLength(2));
      },
    );

    test(
      're-merging the same ULIDs is idempotent (no double-credit)',
      () async {
        final db = createTestDatabase();
        await seedProfile(db);
        final profileId = (await db.select(db.learnerProfiles).get()).first.id;
        final merger = PointsLedgerMerger(db);

        final rows = [
          {
            'ulid': 'LEDGER_CREDIT_01',
            'profile_id': profileId,
            'entry_kind': 'completion',
            'delta': 50,
            'created_at': DateTime.utc(2026, 1, 1, 9).toIso8601String(),
          },
        ];

        await merger.merge(profileId: profileId, rows: rows);
        await merger.merge(profileId: profileId, rows: rows); // duplicate pull

        expect(await db.pointsBalanceDao.getBalance(profileId), 50);
        expect(await db.pointsBalanceDao.getLedger(profileId), hasLength(1));
      },
    );

    test('balance clamps at 0 even if debits exceed credits', () async {
      final db = createTestDatabase();
      await seedProfile(db);
      final profileId = (await db.select(db.learnerProfiles).get()).first.id;
      final merger = PointsLedgerMerger(db);

      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'ulid': 'A',
            'profile_id': profileId,
            'entry_kind': 'completion',
            'delta': 10,
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
          {
            'ulid': 'B',
            'profile_id': profileId,
            'entry_kind': 'parent_deduct',
            'delta': -30,
            'created_at': DateTime.utc(2026, 1, 2).toIso8601String(),
          },
        ],
      );

      expect(await db.pointsBalanceDao.getBalance(profileId), 0);
    });
  });

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
