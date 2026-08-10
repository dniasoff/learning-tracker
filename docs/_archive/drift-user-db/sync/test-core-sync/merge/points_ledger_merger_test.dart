/// Unit tests for [PointsLedgerMerger]: pulled ledger entries insert by
/// ULID (INSERT-OR-IGNORE) and the local balance is re-derived from the
/// merged ledger.
///
/// AG-5 (AUD-app-05): split out of the former
/// test/core/sync/merge/points_sync_merger_test.dart (AUD-app-05) so this
/// file mirrors lib/core/sync/merge/points_ledger_merger.dart 1:1.
/// RewardRedemptionMerger's tests moved to
/// test/core/sync/merge/reward_redemption_merger_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/points_ledger_merger.dart';

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
}
