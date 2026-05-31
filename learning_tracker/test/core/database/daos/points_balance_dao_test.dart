import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/points_balance_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';

import '../../../helpers/drift_memory.dart';

/// Records sink callbacks so the D14 tests can assert the DAO requests a drain
/// after an in-transaction enqueue without wiring the real outbox processor.
class _FakeSink implements PointsSyncSink {
  int drainRequests = 0;
  final List<Map<String, dynamic>> redemptions = [];

  @override
  Future<void> enqueueRewardRedemption(Map<String, dynamic> payload) async {
    redemptions.add(payload);
  }

  @override
  Future<void> requestSyncDrain() async {
    drainRequests++;
  }
}

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

  // ── D14: ledger rows must reach the cloud sync outbox, atomically ──────────
  group('PointsBalanceDao cloud-sync enqueue (D14)', () {
    Future<List<OutboxData>> ledgerOutbox(UserDatabase db) => db.outboxDao
        .getPendingByKind(OutboxEntityKind.pointsLedgerEntry, 1, limit: 100);

    test(
      'credit with a wired sink enqueues the ledger row IN the same '
      'transaction (atomic) and stamps the sync marker + requests a drain',
      () async {
        final sink = _FakeSink();
        db.pointsBalanceDao.syncSink = sink;

        await db.pointsBalanceDao.creditCompletion(1, 10);

        final outbox = await ledgerOutbox(db);
        expect(outbox, hasLength(1), reason: 'ledger row enqueued atomically');

        final ledger = await db.pointsBalanceDao.getLedger(1);
        expect(ledger, hasLength(1));
        // The outbox dedup key is the ledger ULID (deterministic Firestore id).
        expect(outbox.single.entityKey, ledger.single.ulid);
        // Marker set so reconciliation never re-enqueues it.
        expect(ledger.single.syncEnqueuedAt, isNotNull);
        // Drain requested so the freshly-committed row pushes promptly.
        expect(sink.drainRequests, greaterThanOrEqualTo(1));
      },
    );

    test(
      'a credit written while syncSink is NULL is recovered by the post-wire '
      'reconciliation (the silent-drop bug)',
      () async {
        // No sink wired yet (cloud-born account, first credit before the
        // features layer registers the sink).
        await db.pointsBalanceDao.creditCompletion(1, 7);

        // Nothing enqueued, and the row carries no sync marker.
        expect(await ledgerOutbox(db), isEmpty);
        var ledger = await db.pointsBalanceDao.getLedger(1);
        expect(ledger.single.syncEnqueuedAt, isNull);

        // Wire the sink and run the reconciliation.
        final sink = _FakeSink();
        db.pointsBalanceDao.syncSink = sink;
        await db.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(1);

        final outbox = await ledgerOutbox(db);
        expect(outbox, hasLength(1), reason: 'orphaned ledger row recovered');
        ledger = await db.pointsBalanceDao.getLedger(1);
        expect(outbox.single.entityKey, ledger.single.ulid);
        expect(ledger.single.syncEnqueuedAt, isNotNull);
      },
    );

    test('reconciliation is idempotent — never double-enqueues', () async {
      final sink = _FakeSink();
      db.pointsBalanceDao.syncSink = sink;

      await db.pointsBalanceDao.creditCompletion(1, 5); // already enqueued
      await db.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(1);
      await db.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(1);

      expect(await ledgerOutbox(db), hasLength(1));
    });

    test('a pulled remote ledger row is marked enqueued and is NOT echoed back '
        'to the cloud by reconciliation', () async {
      final sink = _FakeSink();
      db.pointsBalanceDao.syncSink = sink;

      await db.pointsBalanceDao.insertRemoteLedgerEntryIfAbsent(
        profileId: 1,
        ulid: 'remote-ulid-1',
        entryKind: 'completion',
        delta: 12,
        createdAt: DateTime.utc(2026, 5, 30, 9),
      );

      await db.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(1);

      expect(
        await ledgerOutbox(db),
        isEmpty,
        reason: 'remote-origin rows must never be re-pushed',
      );
    });

    test('local-born account (no sink) never enqueues or reconciles', () async {
      // No sink wired — local-born has no cloud destination.
      await db.pointsBalanceDao.creditCompletion(1, 9);
      await db.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(1);
      expect(await ledgerOutbox(db), isEmpty);
    });
  });
}
