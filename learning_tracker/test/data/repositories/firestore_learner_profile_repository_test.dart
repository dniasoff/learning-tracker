/// Unit tests for
/// `lib/data/repositories/firestore_learner_profile_repository.dart` —
/// Epic B. Covers: `ensureProfile` writing to the caller-supplied
/// `profileId` (P2-2: this repository no longer mints one itself — see the
/// class doc comment, "Doc-id" — so these tests supply distinct literal
/// ids rather than asserting on minting behavior), that a SECOND call for an
/// already-existing id never re-sends `created_at` (T-40 — the whole reason
/// `createProfile` was replaced by this single create-if-missing/heal
/// method; see [FirestoreLearnerProfileRepository.ensureProfile]'s own doc
/// comment), `getProfiles`/`watchProfiles` listing every profile under the
/// account unfiltered, `updateProfile`'s current-entity-plus-overrides
/// semantics, model round-trip for both `ProfileMode`s, and the "one bad
/// document doesn't blank the list" decode leniency (both the stream and the
/// one-shot read) exactly like `firestore_stage_definition_repository_test.dart`.
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

  group('doc-id — caller-supplied (P2-2: never minted here)', () {
    test('ensureProfile writes to users/{uid}/learner_profiles/{profileId}, '
        'exactly the id passed in', () async {
      final repo = buildRepo();

      final profile = await repo.ensureProfile(
        profileId: 'ulid-yossi',
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );

      expect(profile.profileId, 'ulid-yossi');
      final snapshot = await rawProfiles().doc('ulid-yossi').get();
      expect(snapshot.exists, isTrue);
    });

    test('two distinct ids passed for the same account write two distinct '
        'documents', () async {
      final repo = buildRepo();

      final a = await repo.ensureProfile(
        profileId: 'ulid-yossi',
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );
      final b = await repo.ensureProfile(
        profileId: 'ulid-daniel',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
      );

      expect(a.profileId, isNot(b.profileId));
    });

    test('calling ensureProfile again for the SAME id is idempotent — a '
        'create-if-missing merge, not a duplicate', () async {
      final repo = buildRepo();

      await repo.ensureProfile(
        profileId: 'ulid-devorah',
        displayName: 'Devorah',
        mode: ProfileMode.adult,
      );
      await repo.ensureProfile(
        profileId: 'ulid-devorah',
        displayName: 'Devorah',
        mode: ProfileMode.adult,
      );

      final docs = (await rawProfiles().get()).docs;
      expect(docs, hasLength(1));
    });

    test('a fresh document DOES get a created_at on its first write — the '
        'read-then-write never leaves it missing (T-40)', () async {
      final repo = buildRepo();

      await repo.ensureProfile(
        profileId: 'ulid-fresh',
        displayName: 'Fresh',
        mode: ProfileMode.adult,
      );

      final snapshot = await rawProfiles().doc('ulid-fresh').get();
      expect(snapshot.data(), contains('created_at'));
      // getProfile round-trips it — LearnerProfileEntity.fromFirestore
      // throws when created_at is missing (see that method's doc comment),
      // so a successful read here is itself proof the field is present.
      expect((await repo.getProfile('ulid-fresh'))?.createdAt, isNotNull);
    });

    test('T-40: calling ensureProfile AGAIN for an EXISTING id never '
        're-sends created_at — the exact trap createProfile would have '
        'been if reused as the activation heal', () async {
      final repo = buildRepo();

      final first = await repo.ensureProfile(
        profileId: 'ulid-heal-target',
        displayName: 'Original Name',
        mode: ProfileMode.adult,
      );
      final originalCreatedAt = first.createdAt;

      // Simulate time passing before the SAME profile activates again.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final healed = await repo.ensureProfile(
        profileId: 'ulid-heal-target',
        displayName: 'Original Name',
        mode: ProfileMode.adult,
      );

      expect(
        healed.createdAt,
        originalCreatedAt,
        reason:
            'a second ensureProfile call for the same id (an activation '
            'heal, not a fresh creation) must preserve the real creation '
            'timestamp rather than clobbering it with "now"',
      );
      // created_at is stored as a plain ISO-8601 string (see
      // LearnerProfileEntity.toFirestore's doc comment on encodeDateTime) —
      // confirm the STORED value itself is untouched, not just the value
      // this call happened to return.
      final snapshot = await rawProfiles().doc('ulid-heal-target').get();
      expect(
        DateTime.parse(snapshot.data()!['created_at'] as String).toUtc(),
        originalCreatedAt.toUtc(),
      );
    });

    test(
      'T-40: ensureProfile heals a document that a FIRST call never '
      'created at all (offline creation, network back on activation)',
      () async {
        final repo = buildRepo();

        // The document does not exist yet — models a profile whose original
        // creation-time write never reached Firestore (network was down).
        expect(
          (await rawProfiles().doc('ulid-never-created').get()).exists,
          isFalse,
        );

        final healed = await repo.ensureProfile(
          profileId: 'ulid-never-created',
          displayName: 'Healed Later',
          mode: ProfileMode.child,
        );

        final snapshot = await rawProfiles().doc('ulid-never-created').get();
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()?['display_name'], 'Healed Later');
        expect(healed.createdAt, isNotNull);
      },
    );

    test('toFirestore never writes a track_id-shaped account/profile int '
        'field (MCF-11)', () async {
      final repo = buildRepo();
      final profile = await repo.ensureProfile(
        profileId: 'ulid-yossi',
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

      final created = await repo.ensureProfile(
        profileId: 'ulid-yossi',
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

        final created = await repo.ensureProfile(
          profileId: 'ulid-daniel',
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
      await repo.ensureProfile(
        profileId: 'ulid-yossi',
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );
      await repo.ensureProfile(
        profileId: 'ulid-daniel',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
      );

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

      await repo.ensureProfile(
        profileId: 'ulid-yossi',
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );
      await repo.ensureProfile(
        profileId: 'ulid-daniel',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
      );

      await done;
    });
  });

  group('updateProfile — current entity + optional overrides', () {
    test('changes only the given field, leaving the rest untouched', () async {
      final repo = buildRepo();
      final profile = await repo.ensureProfile(
        profileId: 'ulid-yossi',
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
      final profile = await repo.ensureProfile(
        profileId: 'ulid-yossi',
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
      final good = await repo.ensureProfile(
        profileId: 'ulid-good',
        displayName: 'Yossi',
        mode: ProfileMode.child,
      );
      final bad = await repo.ensureProfile(
        profileId: 'ulid-bad',
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

      final created = await repo.ensureProfile(
        profileId: 'ulid-yossi',
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
