/// Regression coverage for the Firestore-backed track adapter.
///
/// The former version of this test imported the deleted Drift `UserDatabase`
/// and `TrackRepositoryImpl`. Track identity is now [CurriculumId] (AD-25),
/// and the adapter resolves the active Firestore profile through Riverpod.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  const uid = 'uid-1';
  // Valid 26-character Crockford ULID (AD-24).
  const profileDocId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

  FirestoreTrackRepositoryAdapter buildAdapter(
    ProviderContainer container,
  ) {
    final adapterProvider = Provider<FirestoreTrackRepositoryAdapter>(
      (ref) => FirestoreTrackRepositoryAdapter(ref: ref),
    );
    return container.read(adapterProvider);
  }

  AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
    return AccountFirebaseHandles(
      app: MockFirebaseApp(),
      firestore: firestore,
      auth: MockFirebaseAuthHandle(),
      uid: uid,
    );
  }

  group('TrackRepository (one track per curriculum)', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late TrackRepository repository;

    setUp(() {
      firestore = createFakeFirestore(authenticatedUid: uid);
      container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => handles(firestore),
          ),
        ],
      );
      container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
      repository = buildAdapter(container);
    });

    tearDown(() => container.dispose());

    Future<int> activeCount(CurriculumId curriculumId) async {
      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileDocId)
          .collection('curriculum_tracks')
          .doc(curriculumId.storageKey)
          .get();
      return snapshot.exists &&
              snapshot.data()?['state'] == 'active'
          ? 1
          : 0;
    }

    group('initializeDefaultTracks', () {
      test('creates a single active track for a new curriculum', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        expect(await activeCount(CurriculumId.mishnayos), 1);
      });

      test('does nothing if a track already exists', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        expect(await activeCount(CurriculumId.mishnayos), 1);
      });
    });

    group('per-curriculum isolation', () {
      test('initialization is per-curriculum', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.bavli);

        expect(await activeCount(CurriculumId.mishnayos), 1);
        expect(await activeCount(CurriculumId.bavli), 1);
      });
    });
  });
}
