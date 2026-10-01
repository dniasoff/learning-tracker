/// Unit tests for `learner_state_repository_providers.dart` (DNI-464 T8):
/// repositories are built only from `activeAccountFirebaseProvider`'s
/// handle, and the scope only from the shared active account/profile seam.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/learner_state_fixtures.dart';

class _MockApp extends Mock implements FirebaseApp {}

class _MockAuth extends Mock implements FirebaseAuth {}

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) =>
    AccountFirebaseHandles(
      app: _MockApp(),
      firestore: firestore,
      auth: _MockAuth(),
      uid: 'path-uid',
    );

void main() {
  test(
    'no active account → every provider resolves null (not ready)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(learningEventRepositoryProvider.future),
        isNull,
      );
      expect(await container.read(subTrackRepositoryProvider.future), isNull);
      expect(await container.read(activeLearnerScopeProvider.future), isNull);
    },
  );

  test('active account → repositories over that account\'s Firestore handle; '
      'scope still null until a profile is active', () async {
    final firestore = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => _handles(firestore),
        ),
      ],
    );
    addTearDown(container.dispose);

    final events = await container.read(learningEventRepositoryProvider.future);
    final subTracks = await container.read(subTrackRepositoryProvider.future);
    expect(events, isA<FirestoreLearningEventRepository>());
    expect(subTracks, isA<FirestoreSubTrackRepository>());
    expect(await container.read(activeLearnerScopeProvider.future), isNull);

    // The repository writes through the SAME handle.
    final scope = LearnerScope(ownerUid: 'path-uid', profileId: profileUlid);
    await events!.create(scope, datedLearn());
    final doc = await firestore
        .doc(
          'users/path-uid/learner_profiles/$profileUlid/learning_events/$ulidA',
        )
        .get();
    expect(doc.exists, isTrue);
  });

  test('active account + profile → scope from the shared seam', () async {
    final firestore = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => _handles(firestore),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeProfileDocIdProvider.notifier).set(profileUlid);

    final scope = await container.read(activeLearnerScopeProvider.future);
    expect(scope, LearnerScope(ownerUid: 'path-uid', profileId: profileUlid));
  });

  test('a non-ULID active profile id is an error, not an empty read', () async {
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => _handles(FakeFirebaseFirestore()),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeProfileDocIdProvider.notifier).set('42');
    await expectLater(
      container.read(activeLearnerScopeProvider.future),
      throwsFormatException,
    );
  });
}
