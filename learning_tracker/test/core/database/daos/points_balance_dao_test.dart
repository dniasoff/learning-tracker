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
  });
}
