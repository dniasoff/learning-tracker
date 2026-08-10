import 'package:drift/drift.dart' show Value;
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

    test('parentAdjust clamps balance at 0 when the deduction exceeds the '
        'current balance (AUD-t-cross-70: this is the only test that drives '
        'the floor-clamp path — parentAdjust deducts points (clamped at 0) '
        'above never deducts more than the balance holds)', () async {
      await db.pointsBalanceDao.creditCompletion(1, 5);
      final currentBefore = await db.pointsBalanceDao.getBalance(1);
      expect(currentBefore, 5);
      // Deduction (100) far exceeds the balance (5) — must clamp at 0
      // rather than going negative.
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

    // ── watchBalance — reactive stream (DG-DASH-02 iter-1 re-verify) ──────────

    test(
      'watchBalance emits updated balance reactively after creditCompletion '
      'without requiring an explicit invalidation '
      '(iter-1 re-verify: dashboard balance stream must stay live)',
      () async {
        // Register the matcher BEFORE the mutating calls and let it wait for
        // the actual emissions — deterministic, no fixed-millisecond sleep
        // racing the reactive query stream (TQ-6; matches
        // profile_dao_test.dart's watchProfilesByAccount pattern).
        expect(
          db.pointsBalanceDao.watchBalance(1),
          emitsInOrder([
            0, // initial emission: no balance row yet
            50, // after creditCompletion(1, 50) — no explicit invalidation
            70, // after a second creditCompletion(1, 20)
          ]),
        );

        // Yield one event-loop turn (no fixed-millisecond wait — TQ-6) so the
        // stream's initial query fetch is dispatched before the write, the
        // same ordering guard profile_dao_test.dart's watchProfilesByAccount
        // test uses ahead of its own mutating call.
        await Future<void>.delayed(Duration.zero);

        // Credit points — watchBalance must emit the new value without any
        // manual ref.invalidate() call. If this hangs, the provider is a
        // one-shot FutureProvider (stale dashboard balance, D2 regression).
        await db.pointsBalanceDao.creditCompletion(1, 50);

        // Second credit — stream must emit again.
        await db.pointsBalanceDao.creditCompletion(1, 20);
      },
    );

    test(
      'watchBalance emits updated balance reactively after declineRedemption '
      'refund — dashboard balance stays live without pull-to-refresh',
      () async {
        await db.pointsBalanceDao.creditCompletion(1, 100);
        final redemption = await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'Book',
          iconIndex: 0,
          pointsCost: 40,
        );
        // Balance is 60 after debit.
        expect(await db.pointsBalanceDao.getBalance(1), 60);

        // Register the matcher BEFORE the mutating decline call and let it
        // wait for the actual emissions — deterministic, no fixed-millisecond
        // sleep racing the reactive query stream (TQ-6; matches
        // profile_dao_test.dart's watchProfilesByAccount pattern).
        expect(
          db.pointsBalanceDao.watchBalance(1),
          emitsInOrder([
            60, // initial emission must include the post-debit balance
            100, // after declineRedemption refund — no explicit invalidation
          ]),
        );

        // Yield one event-loop turn (no fixed-millisecond wait — TQ-6) so
        // the stream's initial query fetch is dispatched before the write.
        await Future<void>.delayed(Duration.zero);

        // Decline → refund 40 → balance becomes 100. If this hangs, the
        // stream failed to emit 100 without explicit invalidation.
        await db.pointsBalanceDao.declineRedemption(redemption!.id);
      },
    );

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

    test('declineRedemption is a no-op when called a second time '
        '(idempotency: no double-refund on sequential decline calls)', () async {
      await db.pointsBalanceDao.creditCompletion(1, 100);
      final redemption = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Candy',
        iconIndex: 0,
        pointsCost: 30,
      );

      // Balance after redeem: 100 - 30 = 70.
      expect(await db.pointsBalanceDao.getBalance(1), 70);

      // First decline: refund 30 → balance back to 100.
      await db.pointsBalanceDao.declineRedemption(redemption!.id);
      expect(await db.pointsBalanceDao.getBalance(1), 100);

      // Second decline: the idempotency guard reads status='declined' and
      // must return early — balance must NOT be credited a second time.
      await db.pointsBalanceDao.declineRedemption(redemption.id);

      expect(
        await db.pointsBalanceDao.getBalance(1),
        100,
        reason:
            'second declineRedemption must be a no-op: '
            'balance must not be credited again after status is already declined',
      );

      final all = await db.pointsBalanceDao.getAllRedemptions(1);
      final row = all.firstWhere((r) => r.id == redemption.id);
      expect(row.status, 'declined');

      final ledger = await db.pointsBalanceDao.getLedger(1);
      // Ledger must have exactly 3 entries: completion_credit, redemption_debit,
      // and ONE redemption_refund — NOT two refunds.
      final refunds = ledger.where((e) => e.entryKind == 'redemption_refund');
      expect(
        refunds,
        hasLength(1),
        reason: 'only one refund entry must exist — double-refund would show 2',
      );
    });

    test('fulfilRedemption is a no-op when called a second time '
        '(idempotency: status stays fulfilled, balance unchanged)', () async {
      await db.pointsBalanceDao.creditCompletion(1, 100);
      final redemption = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Book',
        iconIndex: 1,
        pointsCost: 40,
      );

      // Balance after redeem: 100 - 40 = 60.
      expect(await db.pointsBalanceDao.getBalance(1), 60);

      // First fulfil: status → fulfilled, balance unchanged (no ledger effect).
      await db.pointsBalanceDao.fulfilRedemption(redemption!.id);

      final balanceAfterFirst = await db.pointsBalanceDao.getBalance(1);
      expect(balanceAfterFirst, 60);

      // Second fulfil: must be a no-op.
      await db.pointsBalanceDao.fulfilRedemption(redemption.id);

      expect(
        await db.pointsBalanceDao.getBalance(1),
        60,
        reason:
            'second fulfilRedemption must not change balance (fulfil has no '
            'ledger effect, but the guard must still fire to prevent a '
            'status overwrite race)',
      );

      final all = await db.pointsBalanceDao.getAllRedemptions(1);
      final row = all.firstWhere((r) => r.id == redemption.id);
      expect(row.status, 'fulfilled');
    });

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

  group('PointsBalanceDao concurrent merge race (AUD-core-database-03)', () {
    test('two concurrent insertRemoteLedgerEntryIfAbsent calls for the same '
        'ulid collapse to exactly one row and one balance credit', () async {
      // Simulates two interleaved merge() calls racing to insert the same
      // pulled remote ledger entry (e.g. a retried tutored pull racing the
      // original, or a future parallelized merge). Before the
      // UNIQUE(profileId, ulid) index, the DAO's SELECT-then-INSERT had a
      // TOCTOU window: both calls could see `existing == null` and both
      // insert, double-crediting the balance.
      final results = await Future.wait([
        db.pointsBalanceDao.insertRemoteLedgerEntryIfAbsent(
          profileId: 1,
          ulid: 'race-ulid-1',
          entryKind: 'completion',
          delta: 10,
          createdAt: DateTime.utc(2026, 5, 30, 9),
        ),
        db.pointsBalanceDao.insertRemoteLedgerEntryIfAbsent(
          profileId: 1,
          ulid: 'race-ulid-1',
          entryKind: 'completion',
          delta: 10,
          createdAt: DateTime.utc(2026, 5, 30, 9),
        ),
      ]);

      // Exactly one of the two racing calls actually inserted a row.
      expect(
        results.where((inserted) => inserted).length,
        1,
        reason: 'exactly one of the two racing inserts should win',
      );

      final ledger = await db.pointsBalanceDao.getLedger(1);
      expect(
        ledger,
        hasLength(1),
        reason: 'duplicate ulid inserts must collapse to a single row',
      );

      await db.pointsBalanceDao.reDeriveBalanceFromLedger(1);
      final balance = await db.pointsBalanceDao.getBalance(1);
      expect(
        balance,
        10,
        reason: 'balance must reflect exactly one credit, not two',
      );
    });
  });

  group('PointsLedger.redemptionId FK (AUD-core-database-09)', () {
    test(
      'inserting a PointsLedger row with a bogus redemptionId fails',
      () async {
        // No reward_redemptions row with id 999999 exists on this profile
        // (or at all) — before schema v35 this comment-only "FK" let the
        // insert through silently.
        await expectLater(
          db
              .into(db.pointsLedger)
              .insert(
                PointsLedgerCompanion.insert(
                  profileId: 1,
                  entryKind: 'redemption_debit',
                  delta: -5,
                  redemptionId: const Value(999999),
                  createdAt: DateTime.utc(2026, 7, 12),
                ),
              ),
          throwsException,
          reason:
              'redemptionId now carries a real FK to reward_redemptions.id '
              '— a bogus id must be rejected at the DB layer',
        );
      },
    );

    test(
      'inserting a PointsLedger row with a real redemptionId succeeds',
      () async {
        final redemption = await db.pointsBalanceDao.createRedemption(
          profileId: 1,
          rewardTitle: 'Ice cream',
          iconIndex: 0,
          pointsCost: 0,
        );
        expect(redemption, isNotNull);

        // Confirms the FK does not reject legitimate references — only
        // bogus ones — matching production usage in
        // PointsBalanceDao.createRedemption/declineRedemption.
        final id = await db
            .into(db.pointsLedger)
            .insert(
              PointsLedgerCompanion.insert(
                profileId: 1,
                entryKind: 'redemption_debit',
                delta: -5,
                redemptionId: Value(redemption!.id),
                createdAt: DateTime.utc(2026, 7, 12),
              ),
            );
        expect(id, greaterThan(0));
      },
    );
  });
}
