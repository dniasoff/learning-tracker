@Tags(['needs_flutter', 'gamification', 'l1'])
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_redemption_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_redemption.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/pump_app.dart';

const _uid = 'parent-redemptions-uid';
const _profileId = '01J0000000000000000000001A';

RewardRedemptionEntity _redemption(
  String title, {
  String ulid = '01J0000000000000000000001B',
}) => RewardRedemptionEntity(
  ulid: ulid,
  rewardTitle: title,
  iconIndex: 0,
  pointsCost: 50,
  status: RewardRedemptionStatus.pendingFulfilment,
  createdAt: DateTime.utc(2026),
);

Future<(FakeFirebaseFirestore, FirestoreRewardRedemptionRepository)>
_realHarness() async {
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  final repository = FirestoreRewardRedemptionRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );
  return (firestore, repository);
}

Future<void> _seed(
  FakeFirebaseFirestore firestore,
  RewardRedemptionEntity redemption,
) async {
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('reward_redemptions')
      .doc(redemption.ulid)
      .set(redemption.toFirestore());
}

Future<void> _pump(
  WidgetTester tester,
  Stream<List<RewardRedemptionEntity>> stream,
) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: [pendingRedemptionsProvider.overrideWith((ref) => stream)],
      child: const ParentPendingRedemptionsScreen(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the empty state from an empty Firestore stream', (
    tester,
  ) async {
    await _pump(tester, Stream.value(const []));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pending Prizes'), findsOneWidget);
    expect(find.text('No pending prize requests.'), findsOneWidget);
  });

  testWidgets('renders pending reward title and cost', (tester) async {
    await _pump(tester, Stream.value([_redemption('New Toy')]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('New Toy'), findsOneWidget);
    expect(find.textContaining('50'), findsOneWidget);
    expect(find.text('Fulfil'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('fulfil updates the Firestore redemption and removes the card', (
    tester,
  ) async {
    final (firestore, repository) = await _realHarness();
    final redemption = _redemption('Fulfil Me');
    await _seed(firestore, redemption);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          firestoreRewardRedemptionRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
        child: const ParentPendingRedemptionsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Fulfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final stored = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('reward_redemptions')
        .doc(redemption.ulid)
        .get();
    expect(stored.data()?['status'], RewardRedemptionStatus.fulfilled);
    expect(find.text('Fulfil Me'), findsNothing);
    expect(find.text('No pending prize requests.'), findsOneWidget);
  });

  testWidgets('decline refunds points and removes the card', (tester) async {
    final (firestore, repository) = await _realHarness();
    final redemption = _redemption(
      'Decline Me',
      ulid: '01J0000000000000000000001C',
    );
    await _seed(firestore, redemption);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          firestoreRewardRedemptionRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
        child: const ParentPendingRedemptionsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Decline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final stored = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('reward_redemptions')
        .doc(redemption.ulid)
        .get();
    expect(stored.data()?['status'], RewardRedemptionStatus.declined);
    final ledger = FirestorePointsLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    expect((await ledger.getLedger()).single.delta, 50);
    expect(find.text('Decline Me'), findsNothing);
    expect(find.text('No pending prize requests.'), findsOneWidget);
  });

  testWidgets('shows loading while the Firestore stream has not emitted', (
    tester,
  ) async {
    final controller = StreamController<List<RewardRedemptionEntity>>();
    addTearDown(controller.close);
    await _pump(tester, controller.stream);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
