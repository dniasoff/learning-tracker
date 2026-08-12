/// T-49 regression coverage for the Firestore-native profile adapter.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) {
  return AccountFirebaseHandles(
    app: _MockFirebaseApp(),
    firestore: firestore,
    auth: _MockFirebaseAuth(),
    uid: 'uid-t49-adapter',
  );
}

void main() {
  // The old T-49 timing matrix gated activation writes performed around the
  // Drift insert and sync-resolution awaits. The current adapter's
  // createProfile path mints one ULID, writes one Firestore document, and
  // never writes activeProfileDocIdProvider; selection is owned exclusively
  // by SelectedProfileId.select(). Consequently there is no delayed
  // repository activation/write boundary left to interleave or race.
  test(
    'createProfile writes Firestore without changing active selection',
    () async {
      const uid = 'uid-t49-adapter';
      final firestore = createFakeFirestore(authenticatedUid: uid);
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
        ],
      );
      addTearDown(container.dispose);

      final created = await container
          .read(profileRepositoryProvider)
          .createProfile(displayName: 'New Learner', mode: ProfileMode.adult);

      expect(created.profileId, isNotEmpty);
      expect(container.read(activeProfileDocIdProvider), isNull);
      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(created.profileId)
          .get();
      expect(snapshot.exists, isTrue);
    },
  );

  test('seeded Firestore profile is read by the adapter', () async {
    const uid = 'uid-t49-seeded';
    const profileId = '01HT49SEEDEDPROFILE00000000';
    final firestore = createFakeFirestore(authenticatedUid: uid);
    await seedProfile(
      firestore,
      uid: uid,
      profileId: profileId,
      displayName: 'Seeded Learner',
    );
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => AccountFirebaseHandles(
            app: _MockFirebaseApp(),
            firestore: firestore,
            auth: _MockFirebaseAuth(),
            uid: uid,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final profiles = await container
        .read(profileRepositoryProvider)
        .getProfiles();
    expect(profiles.single.profileId, profileId);
    expect(profiles.single.displayName, 'Seeded Learner');
  });
}
