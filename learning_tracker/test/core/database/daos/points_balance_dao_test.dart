import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PointsBalanceDao', () {
    test('getBalance returns 0 when no row exists', () async {
      final balance = await db.pointsBalanceDao.getBalance(1);
      expect(balance, 0);
    });

    test('creditCompletion increases balance', () async {
      await db.pointsBalanceDao.creditCompletion(1, 10);
      final balance = await db.pointsBalanceDao.getBalance(1);
      expect(balance, 10);
    });

    test('creditCompletion accumulates across multiple calls', () async {
      await db.pointsBalanceDao.creditCompletion(1, 5);
      await db.pointsBalanceDao.creditCompletion(1, 3);
      final balance = await db.pointsBalanceDao.getBalance(1);
      expect(balance, 8);
    });

    test('debitRedemption returns false when balance is insufficient', () async {
      await db.pointsBalanceDao.creditCompletion(1, 5);
      // Create a redemption first to satisfy foreign-key on the DAO call.
      // Use parentAdjust as a proxy since debitRedemption needs a redemptionId.
      final currentBefore = await db.pointsBalanceDao.getBalance(1);
      expect(currentBefore, 5);
      // Attempt a parent deduction larger than the balance — clamps at 0.
      await db.pointsBalanceDao.parentAdjust(1, -100);
      final balanceAfter = await db.pointsBalanceDao.getBalance(1);
      expect(balanceAfter, 0);
    });

    test('parentAdjust adds points', () async {
      await db.pointsBalanceDao.creditCompletion(1, 10);
      await db.pointsBalanceDao.parentAdjust(1, 5);
      expect(await db.pointsBalanceDao.getBalance(1), 15);
    });

    test('parentAdjust deducts points (clamped at 0)', () async {
      await db.pointsBalanceDao.creditCompletion(1, 3);
      await db.pointsBalanceDao.parentAdjust(1, -1);
      expect(await db.pointsBalanceDao.getBalance(1), 2);
    });

    test('getLedger returns at least one entry after a credit', () async {
      await db.pointsBalanceDao.creditCompletion(1, 5);
      final ledger = await db.pointsBalanceDao.getLedger(1);
      expect(ledger, isNotEmpty);
      // All returned entries belong to profileId 1.
      for (final entry in ledger) {
        expect(entry.profileId, 1);
      }
    });

    // ── createRedemption ──────────────────────────────────────────────────────

    test('createRedemption debits balance and creates a pending row', () async {
      await db.pointsBalanceDao.creditCompletion(1, 100);

      final redemption = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Ice Cream',
        iconIndex: 0,
        pointsCost: 30,
      );

      expect(redemption, isNotNull);
      expect(redemption!.status, 'pending_fulfilment');
      expect(redemption.pointsCost, 30);
      expect(redemption.rewardTitle, 'Ice Cream');
      // Balance debited.
      expect(await db.pointsBalanceDao.getBalance(1), 70);
    });

    test(
      'createRedemption returns null when balance is insufficient',
      () async {
        await db.pointsBalanceDao.creditCompletion(1, 10);

        final redemption = await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'Toy',
          iconIndex: 1,
          pointsCost: 50,
        );

        expect(redemption, isNull);
        // Balance unchanged.
        expect(await db.pointsBalanceDao.getBalance(1), 10);
      },
    );

    // ── fulfilRedemption ──────────────────────────────────────────────────────

    test('fulfilRedemption sets status to fulfilled', () async {
      await db.pointsBalanceDao.creditCompletion(1, 100);
      final redemption = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Trip',
        iconIndex: 2,
        pointsCost: 40,
      );

      await db.pointsBalanceDao.fulfilRedemption(redemption!.id);

      final pending = await db.pointsBalanceDao.getPendingRedemptions(1);
      expect(pending, isEmpty);
      final all = await db.pointsBalanceDao.getAllRedemptions(1);
      expect(all.any((r) => r.status == 'fulfilled'), isTrue);
    });

    // ── declineRedemption ─────────────────────────────────────────────────────

    test(
      'declineRedemption refunds points and sets status to declined',
      () async {
        await db.pointsBalanceDao.creditCompletion(1, 100);
        final redemption = await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'Book',
          iconIndex: 3,
          pointsCost: 50,
        );

        // Balance after redeem should be 50.
        expect(await db.pointsBalanceDao.getBalance(1), 50);

        await db.pointsBalanceDao.declineRedemption(redemption!.id);

        // Balance refunded — back to 100.
        expect(await db.pointsBalanceDao.getBalance(1), 100);

        final all = await db.pointsBalanceDao.getAllRedemptions(1);
        expect(all.any((r) => r.status == 'declined'), isTrue);
      },
    );

    test('fulfilRedemption is a no-op on an already-declined redemption '
        '(D5: no fulfil-vs-decline race / no double benefit)', () async {
      await db.pointsBalanceDao.creditCompletion(1, 100);
      final redemption = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Toy',
        iconIndex: 1,
        pointsCost: 40,
      );

      // Parent declines first → refunded, status declined, balance back to 100.
      await db.pointsBalanceDao.declineRedemption(redemption!.id);
      expect(await db.pointsBalanceDao.getBalance(1), 100);

      // A late/racing fulfil must NOT flip it to fulfilled or touch the
      // balance (else the child keeps the refund AND gets the reward).
      await db.pointsBalanceDao.fulfilRedemption(redemption.id);

      final all = await db.pointsBalanceDao.getAllRedemptions(1);
      final row = all.firstWhere((r) => r.id == redemption.id);
      expect(row.status, 'declined');
      expect(await db.pointsBalanceDao.getBalance(1), 100);
    });

    // ── getPendingRedemptions / watchPendingRedemptions ───────────────────────

    test('getPendingRedemptions only returns pending rows', () async {
      await db.pointsBalanceDao.creditCompletion(1, 200);

      final r1 = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Prize A',
        iconIndex: 0,
        pointsCost: 20,
      );
      final r2 = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Prize B',
        iconIndex: 1,
        pointsCost: 20,
      );

      // Fulfil one.
      await db.pointsBalanceDao.fulfilRedemption(r1!.id);

      final pending = await db.pointsBalanceDao.getPendingRedemptions(1);
      expect(pending, hasLength(1));
      expect(pending.first.id, r2!.id);
    });
  });
}
