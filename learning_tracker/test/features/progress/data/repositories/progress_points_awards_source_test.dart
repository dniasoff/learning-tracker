// Mirror test for
// `lib/features/progress/data/repositories/progress_points_awards_source.dart`
// (DNI-474: event-linked points awards for the recent-activity chart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/points_ledger_entry.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_points_awards_source.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

const _uid = 'progress-points-awards-user';
const _profileId = '01J00000000000000000000016';

void main() {
  test('keeps completion rows that name their learn event', () async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = FirestorePointsLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    final award = PointsLedgerEntry.forAward(
      PointsAward(eventId: 'evt1', amount: 7, createdAt: DateTime.utc(2026)),
    );
    await firestore
        .doc(
          'users/$_uid/learner_profiles/$_profileId/points_ledger/${award.ulid}',
        )
        .set(award.toFirestore());
    await repository.append(
      entryKind: 'parent_add',
      delta: 50,
      createdAt: DateTime.utc(2026),
    );
    final container = ProviderContainer.test(
      overrides: [
        firestorePointsLedgerRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );

    final rows = await readFuture(
      container,
      progressPointsAwardsProvider.future,
    );

    expect(rows, [
      const PointsLedgerRow(id: 'pts_evt1', amount: 7, eventId: 'evt1'),
    ]);
  });

  test('no active learner has no awards', () async {
    final container = ProviderContainer.test(
      overrides: [
        firestorePointsLedgerRepositoryProvider.overrideWith(
          (ref) async => null,
        ),
      ],
    );
    expect(
      await readFuture(container, progressPointsAwardsProvider.future),
      isEmpty,
    );
  });
}
