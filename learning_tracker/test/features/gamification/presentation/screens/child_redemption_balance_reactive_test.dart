@Tags(['gamification', 'staleness'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'child-balance-reactive-uid';
const _profileId = '01J00000000000000000000017';

void main() {
  test(
    'balance provider re-reads the Firestore ledger after a commit signal',
    () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);
      final repository = FirestorePointsLedgerRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      final container = ProviderContainer(
        overrides: [
          firestorePointsLedgerRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        childRedemptionBalanceProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(await container.read(childRedemptionBalanceProvider.future), 0);

      await repository.append(
        ulid: '01J00000000000000000000018',
        entryKind: 'parent_add',
        delta: 100,
        createdAt: DateTime.utc(2026, 1, 1),
        source: CompletionSource.live,
      );
      container.read(completionCommittedProvider.notifier).increment();
      await pumpEventQueue();

      expect(await container.read(childRedemptionBalanceProvider.future), 100);
    },
  );
}
