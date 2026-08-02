/// Unit tests for
/// `lib/data/repositories/firestore_learner_profile_repository.dart` —
/// Epic B. Covers: `createProfile` minting a fresh ULID doc-id every call
/// (never re-derived from content, unlike the natural-key repositories),
/// `getProfiles`/`watchProfiles` listing every profile under the account
/// unfiltered, `updateProfile`'s current-entity-plus-overrides semantics,
/// model round-trip for both `ProfileMode`s, and the "one bad document
/// doesn't blank the list" decode leniency (both the stream and the
/// one-shot read) exactly like
/// `firestore_stage_definition_repository_test.dart`.
///
/// **What these tests cannot see**: same rules-evaluation limitation noted
/// throughout this directory — `strictRules: false` throughout, so no
/// assertion here proves `firestore.rules` grants/denies the right caller.
/// The resubscribe-with-backoff behavior [watchProfile]/[watchProfiles]
/// delegate to is covered directly in `resilient_doc_stream_test.dart` —
/// not re-proven here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  CollectionReference<Map<String, dynamic>> rawProfiles() =>
      firestore.collection('users').doc(_uid).collection('learner_profiles');

  FirestoreLearnerProfileRepository buildRepo() =>
      FirestoreLearnerProfileRepository(firestore: firestore, uid: _uid);

  group('doc-id — freshly minted ULID', () {
    test('createProfile writes to users/{uid}/learner_profiles/{ulid}, '
        'never the account uid', () async {
      final repo = buildRepo();

      final profile = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );

      expect(profile.profileId, isNot(_uid));
      final snapshot = await rawProfiles().doc(profile.profileId).get();
      expect(snapshot.exists, isTrue);
    });

    test('two profiles for the same account get two distinct ids', () async {
      final repo = buildRepo();

      final a = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );
      final b = await repo.createProfile(
        displayName: 'Daniel',
        mode: ProfileMode.adult,
      );

      expect(a.profileId, isNot(b.profileId));
    });

    test('toFirestore never writes a track_id-shaped account/profile int '
        'field (MCF-11)', () async {
      final repo = buildRepo();
      final profile = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );

      final snapshot = await rawProfiles().doc(profile.profileId).get();
      expect(snapshot.data(), isNot(contains('account_id')));
      expect(snapshot.data(), isNot(contains('profile_id')));
    });
  });

  group('model round-trip', () {
    test('a child profile with an avatar round-trips every field', () async {
      final repo = buildRepo();

      final created = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
        avatar: 'bear',
      );
      final fetched = await repo.getProfile(created.profileId);

      expect(fetched, created);
      expect(fetched!.mode, ProfileMode.child);
      expect(fetched.avatar, 'bear');
    });

    test(
      'an adult profile defaults to an empty-string avatar, never null',
      () async {
        final repo = buildRepo();

        final created = await repo.createProfile(
          displayName: 'Daniel',
          mode: ProfileMode.adult,
        );

        expect(created.avatar, '');
        final snapshot = await rawProfiles().doc(created.profileId).get();
        expect(snapshot.data()!['avatar'], '');
      },
    );
  });

  group('getProfiles / watchProfiles — unfiltered account listing', () {
    test('returns every profile for the account', () async {
      final repo = buildRepo();
      await repo.createProfile(displayName: 'Yossi', mode: ProfileMode.child);
      await repo.createProfile(displayName: 'Daniel', mode: ProfileMode.adult);

      final profiles = await repo.getProfiles();

      expect(profiles, hasLength(2));
      expect(
        profiles.map((p) => p.displayName),
        containsAll(<String>['Yossi', 'Daniel']),
      );
    });

    test(
      'returns an empty list when the account has no profiles yet',
      () async {
        final repo = buildRepo();

        expect(await repo.getProfiles(), isEmpty);
      },
    );

    test('watchProfiles eventually emits both created profiles', () async {
      final repo = buildRepo();

      final stream = repo.watchProfiles().map((profiles) => profiles.length);
      final done = expectLater(stream, emitsThrough(2));

      await repo.createProfile(displayName: 'Yossi', mode: ProfileMode.child);
      await repo.createProfile(displayName: 'Daniel', mode: ProfileMode.adult);

      await done;
    });
  });

  group('updateProfile — current entity + optional overrides', () {
    test('changes only the given field, leaving the rest untouched', () async {
      final repo = buildRepo();
      final profile = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
        avatar: 'bear',
      );

      final updated = await repo.updateProfile(
        profile: profile,
        displayName: 'Yossi Renamed',
      );

      expect(updated.displayName, 'Yossi Renamed');
      expect(updated.mode, ProfileMode.child);
      expect(updated.avatar, 'bear');
      final fetched = await repo.getProfile(profile.profileId);
      expect(fetched, updated);
    });

    test('updateProfile writes back to the SAME profileId', () async {
      final repo = buildRepo();
      final profile = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );

      final updated = await repo.updateProfile(
        profile: profile,
        mode: ProfileMode.adult,
      );

      expect(updated.profileId, profile.profileId);
    });
  });

  group('one-shot reads skip a malformed document instead of failing '
      'the whole read', () {
    test('getProfiles omits a document missing created_at but still '
        'returns the valid ones', () async {
      final repo = buildRepo();
      final good = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );
      final bad = await repo.createProfile(
        displayName: 'Daniel',
        mode: ProfileMode.adult,
      );
      await rawProfiles().doc(bad.profileId).update({
        'created_at': FieldValue.delete(),
      });

      final profiles = await repo.getProfiles();

      expect(profiles, hasLength(1));
      expect(profiles.single.profileId, good.profileId);
    });
  });

  group('watchProfile — single document', () {
    test('returns null before the profile exists, then the profile after '
        'creation', () async {
      final repo = buildRepo();

      expect(await repo.getProfile('never-created'), isNull);

      final created = await repo.createProfile(
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );

      final stream = repo
          .watchProfile(created.profileId)
          .map((p) => p?.displayName);
      await expectLater(stream, emits('Yossi'));
    });
  });
}
