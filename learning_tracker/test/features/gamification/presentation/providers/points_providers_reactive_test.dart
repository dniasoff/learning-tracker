@Tags(['gamification', 'staleness'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'points-reactive-uid';
const _profileId = '01J00000000000000000000015';

void main() {
  test(
    'globalPointsProvider re-reads the Firestore ledger after a commit signal',
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
        globalPointsProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(await container.read(globalPointsProvider.future), 0);

      await repository.append(
        ulid: '01J00000000000000000000016',
        entryKind: 'parent_add',
        delta: 50,
        createdAt: DateTime.utc(2026, 1, 1),
        source: CompletionSource.live,
      );
      // This is the same production signal emitted after a successful
      // Firestore completion/ledger write. No provider invalidation is used.
      container.read(completionCommittedProvider.notifier).increment();
      await pumpEventQueue();

      expect(await container.read(globalPointsProvider.future), 50);
    },
  );
}
