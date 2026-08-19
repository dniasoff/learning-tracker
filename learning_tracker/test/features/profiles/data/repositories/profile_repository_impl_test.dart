/// Firestore-native tests for the profile repository adapter.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ReadinessNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setReady() => state = true;
}

final _readinessProvider = NotifierProvider<_ReadinessNotifier, bool>(
  _ReadinessNotifier.new,
);

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore, String uid) {
  return AccountFirebaseHandles(
    app: _MockFirebaseApp(),
    firestore: firestore,
    auth: _MockFirebaseAuth(),
    uid: uid,
  );
}

ProviderContainer _container(FakeFirebaseFirestore firestore, String uid) {
  return ProviderContainer(
    overrides: [
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => _handles(firestore, uid),
      ),
    ],
  );
}

void main() {
  group('FirestoreProfileRepositoryAdapter', () {
    test('creates and reads a profile by its ULID', () async {
      const uid = 'uid-profile-repository';
      final firestore = createFakeFirestore(authenticatedUid: uid);
      final container = _container(firestore, uid);
      addTearDown(container.dispose);
      final repo = container.read(profileRepositoryProvider);

      final created = await repo.createProfile(
        displayName: 'Test User',
        mode: ProfileMode.adult,
      );

      expect(created.profileId, isNotEmpty);
      expect(created.displayName, 'Test User');
      expect(created.mode, ProfileMode.adult);
      expect(await repo.getProfileById(created.profileId), created);
      expect(await repo.countProfiles(), 1);
    });

    test('reads seeded profiles and enforces duplicate names', () async {
      const uid = 'uid-profile-seeded';
      const profileId = '01HTESTPROFILE00000000000000';
      final firestore = createFakeFirestore(authenticatedUid: uid);
      await seedProfile(
        firestore,
        uid: uid,
        profileId: profileId,
        displayName: 'Existing Learner',
        mode: ProfileMode.child,
      );
      final container = _container(firestore, uid);
      addTearDown(container.dispose);
      final repo = container.read(profileRepositoryProvider);

      final profiles = await repo.getProfiles();
      expect(profiles.single.profileId, profileId);
      expect(profiles.single.mode, ProfileMode.child);
      expect(
        () => repo.createProfile(
          displayName: ' existing learner ',
          mode: ProfileMode.adult,
        ),
        throwsA(isA<DuplicateProfileNameException>()),
      );
    });

    test('enforces the ten-profile account limit', () async {
      const uid = 'uid-profile-limit';
      final firestore = createFakeFirestore(authenticatedUid: uid);
      for (var i = 0; i < 10; i++) {
        await seedProfile(
          firestore,
          uid: uid,
          profileId: '01HLIMITPROFILE${i.toString().padLeft(2, '0')}000000',
          displayName: 'Profile $i',
        );
      }
      final container = _container(firestore, uid);
      addTearDown(container.dispose);

      expect(
        () => container
            .read(profileRepositoryProvider)
            .createProfile(displayName: 'Profile 10', mode: ProfileMode.adult),
        throwsA(isA<MaxProfilesExceededException>()),
      );
    });

    test('updates a seeded profile and rejects a missing profile', () async {
      const uid = 'uid-profile-update';
      const profileId = '01HTESTUPDATEPROFILE00000000';
      final firestore = createFakeFirestore(authenticatedUid: uid);
      await seedProfile(
        firestore,
        uid: uid,
        profileId: profileId,
        displayName: 'Before',
        mode: ProfileMode.child,
      );
      final container = _container(firestore, uid);
      addTearDown(container.dispose);
      final repo = container.read(profileRepositoryProvider);

      final updated = await repo.updateProfile(
        profileId: profileId,
        displayName: 'After',
        mode: ProfileMode.adult,
        avatar: 'avatar-2',
      );
      expect(updated.displayName, 'After');
      expect(updated.mode, ProfileMode.adult);
      expect(updated.avatar, 'avatar-2');

      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileId)
          .get();
      expect(snapshot.data(), containsPair('display_name', 'After'));
      expect(snapshot.data(), containsPair('mode', 'adult'));
      expect(snapshot.data(), containsPair('avatar', 'avatar-2'));
      expect(snapshot.data(), contains('created_at'));
      expect(snapshot.data(), contains('updated_at'));
      expect(
        () => repo.updateProfile(
          profileId: '01HMISSINGPROFILE00000000000',
          displayName: 'Missing',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects duplicate names during update', () async {
      const uid = 'uid-profile-update-duplicate';
      const firstId = '01HUPDATEFIRSTPROFILE0000000';
      const secondId = '01HUPDATESECONDPROFILE000000';
      final firestore = createFakeFirestore(authenticatedUid: uid);
      await seedProfile(
        firestore,
        uid: uid,
        profileId: firstId,
        displayName: 'First',
      );
      await seedProfile(
        firestore,
        uid: uid,
        profileId: secondId,
        displayName: 'Second',
      );
      final container = _container(firestore, uid);
      addTearDown(container.dispose);
      final repo = container.read(profileRepositoryProvider);

      expect(
        () => repo.updateProfile(profileId: secondId, displayName: ' first '),
        throwsA(isA<DuplicateProfileNameException>()),
      );
    });

    test('reports not-ready state without an active account', () async {
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(profileRepositoryProvider).getProfiles(),
        throwsA(isA<ProfileRepositoryNotReadyException>()),
      );
    });

    test('watchProfiles recovers when the account becomes ready', () async {
      const uid = 'uid-profile-watch-recovery';
      const profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA';
      final firestore = createFakeFirestore(authenticatedUid: uid);
      await seedProfile(
        firestore,
        uid: uid,
        profileId: profileId,
        displayName: 'Ready Learner',
      );
      final container = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          firestoreLearnerProfileRepositoryProvider.overrideWith((ref) async {
            if (!ref.watch(_readinessProvider)) return null;
            return FirestoreLearnerProfileRepository(
              firestore: firestore,
              uid: uid,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final profilesFuture = container
          .read(profileRepositoryProvider)
          .watchProfiles()
          .first;
      await Future<void>.delayed(Duration.zero);
      container.read(_readinessProvider.notifier).setReady();

      final profiles = await profilesFuture.timeout(const Duration(seconds: 1));
      expect(profiles.single.displayName, 'Ready Learner');
    });
  });
}
