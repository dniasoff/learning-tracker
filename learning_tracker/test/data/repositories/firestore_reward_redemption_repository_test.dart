/// Unit tests for
/// `lib/data/repositories/firestore_reward_redemption_repository.dart`
/// (Phase 3 task #15). Covers: the insufficient-balance null contract,
/// the balance-debit + redemption-doc-creation pair on a successful
/// create, doc-id correctness, fulfil (status-only, no balance change),
/// decline (refund via a `redemption_refund` ledger entry + status
/// change), the missing-document guard on decline, and the pending-only
/// query/stream.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_redemption_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_redemption.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  FirestoreRewardRedemptionRepository buildRepo() {
    return FirestoreRewardRedemptionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  FirestorePointsLedgerRepository buildLedger() {
    return FirestorePointsLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  Future<void> creditBalance(int amount, {required DateTime at}) async {
    await buildLedger().append(
      entryKind: 'parent_add',
      delta: amount,
      createdAt: at,
    );
  }

  group('createRedemption — insufficient balance', () {
    test('returns null and writes nothing when balance < cost', () async {
      final repo = buildRepo();
      await creditBalance(5, at: DateTime.utc(2026, 1, 1));

      final result = await repo.createRedemption(
        rewardTitle: 'Ice cream',
        iconIndex: 2,
        pointsCost: 10,
      );

      expect(result, isNull);
      final pending = await repo.getPendingRedemptions();
      expect(pending, isEmpty);
      final ledger = await buildLedger().getLedger();
      expect(ledger, hasLength(1), reason: 'only the setup credit, no debit');
    });
  });

  group('createRedemption — sufficient balance', () {
    test('debits the balance and creates a pending redemption', () async {
      final repo = buildRepo();
      await creditBalance(20, at: DateTime.utc(2026, 1, 1));

      final result = await repo.createRedemption(
        rewardTitle: 'Ice cream',
        iconIndex: 2,
        pointsCost: 15,
      );

      expect(result, isNotNull);
      expect(result!.rewardTitle, 'Ice cream');
      expect(result.iconIndex, 2);
      expect(result.pointsCost, 15);
      expect(result.status, RewardRedemptionStatus.pendingFulfilment);

      final balance = await buildLedger().getBalance();
      expect(balance, 5, reason: '20 credited - 15 debited');

      final ledger = await buildLedger().getLedger();
      final debit = ledger.firstWhere((e) => e.entryKind == 'redemption_debit');
      expect(debit.delta, -15);
      expect(debit.redemptionUlid, result.ulid);
    });

    test(
      'doc-id is the redemption ulid — DocIds.rewardRedemptionDocId',
      () async {
        final repo = buildRepo();
        await creditBalance(20, at: DateTime.utc(2026, 1, 1));

        final result = await repo.createRedemption(
          rewardTitle: 'Ice cream',
          iconIndex: 0,
          pointsCost: 10,
        );

        final expectedId = DocIds.rewardRedemptionDocId({'ulid': result!.ulid});
        final snapshot = await firestore
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId)
            .collection('reward_redemptions')
            .doc(expectedId)
            .get();
        expect(snapshot.exists, isTrue);
      },
    );
  });

  group('getPendingRedemptions / watchPendingRedemptions', () {
    test('only returns pending_fulfilment redemptions', () async {
      final repo = buildRepo();
      await creditBalance(100, at: DateTime.utc(2026, 1, 1));
      final pending = await repo.createRedemption(
        rewardTitle: 'Pending toy',
        iconIndex: 0,
        pointsCost: 10,
      );
      final toFulfil = await repo.createRedemption(
        rewardTitle: 'Fulfilled toy',
        iconIndex: 0,
        pointsCost: 10,
      );
      await repo.fulfilRedemption(toFulfil!.ulid);

      final results = await repo.getPendingRedemptions();

      expect(results, hasLength(1));
      expect(results.single.ulid, pending!.ulid);
    });

    test(
      'watchPendingRedemptions eventually emits a newly-created request',
      () async {
        final repo = buildRepo();
        await creditBalance(100, at: DateTime.utc(2026, 1, 1));

        final stream = repo.watchPendingRedemptions().map(
          (list) => list.length,
        );
        final done = expectLater(stream, emitsThrough(1));

        await repo.createRedemption(
          rewardTitle: 'Toy',
          iconIndex: 0,
          pointsCost: 10,
        );

        await done;
      },
    );
  });

  group('fulfilRedemption', () {
    test(
      'marks the redemption fulfilled without touching the balance',
      () async {
        final repo = buildRepo();
        await creditBalance(100, at: DateTime.utc(2026, 1, 1));
        final created = await repo.createRedemption(
          rewardTitle: 'Toy',
          iconIndex: 0,
          pointsCost: 30,
        );
        final balanceBefore = await buildLedger().getBalance();

        await repo.fulfilRedemption(created!.ulid);

        final pending = await repo.getPendingRedemptions();
        expect(pending, isEmpty);
        final balanceAfter = await buildLedger().getBalance();
        expect(balanceAfter, balanceBefore);
      },
    );
  });

  group('declineRedemption', () {
    test(
      'refunds the points and clears the redemption from the pending list',
      () async {
        final repo = buildRepo();
        await creditBalance(100, at: DateTime.utc(2026, 1, 1));
        final created = await repo.createRedemption(
          rewardTitle: 'Toy',
          iconIndex: 0,
          pointsCost: 30,
        );
        final balanceAfterDebit = await buildLedger().getBalance();
        expect(balanceAfterDebit, 70);

        await repo.declineRedemption(created!.ulid);

        final balanceAfterRefund = await buildLedger().getBalance();
        expect(
          balanceAfterRefund,
          100,
          reason: 'the 30-point debit is refunded',
        );
        final pending = await repo.getPendingRedemptions();
        expect(pending, isEmpty);

        final ledger = await buildLedger().getLedger();
        final refund = ledger.firstWhere(
          (e) => e.entryKind == 'redemption_refund',
        );
        expect(refund.delta, 30);
        expect(refund.redemptionUlid, created.ulid);
      },
    );

    test('throws StateError when the redemption document does not exist', () {
      final repo = buildRepo();

      expect(
        () => repo.declineRedemption('nonexistent-ulid'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
