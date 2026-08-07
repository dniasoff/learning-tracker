/// Unit tests for
/// `lib/data/repositories/firestore_learner_profile_repository.dart` —
/// Epic B. Covers: `ensureProfile` writing to the caller-supplied
/// `profileId` (P2-2: this repository no longer mints one itself — see the
/// class doc comment, "Doc-id" — so these tests supply distinct literal
/// ids rather than asserting on minting behavior); `ensureProfile` always
/// writing the CALLER-SUPPLIED `created_at` (P2-15 — this repository no
/// longer reads the document to decide whether `created_at` is safe to
/// send, see [FirestoreLearnerProfileRepository.ensureProfile]'s own doc
/// comment for why a read-based decision was the defect, not the fix);
/// `getProfiles`/`watchProfiles` listing every profile under the account
/// unfiltered; `updateProfile`'s current-entity-plus-overrides semantics;
/// model round-trip for both `ProfileMode`s; and the "one bad document
/// doesn't blank the list" decode leniency (both the stream and the
/// one-shot read) exactly like `firestore_stage_definition_repository_test.dart`.
///
/// **What these tests cannot see**: same rules-evaluation limitation noted
/// throughout this directory — `strictRules: false` throughout, so no
/// assertion here proves `firestore.rules` grants/denies the right caller.
/// The resubscribe-with-backoff behavior [watchProfile]/[watchProfiles]
/// delegate to is covered directly in `resilient_doc_stream_test.dart` —
/// not re-proven here. **`fake_cloud_firestore` also has no cache/offline
/// semantics** (no `Source.serverAndCache` vs `Source.server` distinction,
/// no `metadata.isFromCache`), so no test in this file can reproduce the
/// specific cache-miss scenario the old read-based `created_at` decision
/// was vulnerable to — that scenario is a DEFERRED VERIFICATION, not
/// something this file claims to cover. What this file proves instead is
/// stronger for a unit test: that the write no longer depends on ANY
/// Firestore read at all, by seeding a document with a deliberately WRONG
/// stored `created_at` and confirming the write still uses the caller's
/// value regardless (see "the caller-supplied value wins, always").
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

/// A fixed, arbitrary "creation instant" for tests that don't care about
/// the specific value — mirrors how a real caller always has one already
/// (the Drift row's own `createdAt` column), never "now" at call time.
final _createdAt = DateTime.utc(2024, 3, 1, 12);

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
        createdAt: _createdAt,
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
        createdAt: _createdAt,
      );
      final b = await repo.ensureProfile(
        profileId: 'ulid-daniel',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
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
        createdAt: _createdAt,
      );
      await repo.ensureProfile(
        profileId: 'ulid-devorah',
        displayName: 'Devorah',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
      );

      final docs = (await rawProfiles().get()).docs;
      expect(docs, hasLength(1));
    });

    test('a fresh document DOES get a created_at on its first write', () async {
      final repo = buildRepo();

      await repo.ensureProfile(
        profileId: 'ulid-fresh',
        displayName: 'Fresh',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
      );

      final snapshot = await rawProfiles().doc('ulid-fresh').get();
      expect(snapshot.data(), contains('created_at'));
      // getProfile round-trips it — LearnerProfileEntity.fromFirestore
      // throws when created_at is missing (see that method's doc comment),
      // so a successful read here is itself proof the field is present.
      expect((await repo.getProfile('ulid-fresh'))?.createdAt, isNotNull);
    });

    test('P2-15: calling ensureProfile AGAIN for an EXISTING id with the SAME '
        'caller-supplied created_at persists that value unchanged — this is '
        'the actual shape every production caller uses '
        '(FirestoreProfileRepositoryAdapter always passes model.createdAt, '
        'the Drift row\'s own immutable creation timestamp, which never '
        'changes between activations), so the write is idempotent by '
        'construction rather than by an internal read-and-decide', () async {
      final repo = buildRepo();

      final first = await repo.ensureProfile(
        profileId: 'ulid-heal-target',
        displayName: 'Original Name',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
      );

      final healed = await repo.ensureProfile(
        profileId: 'ulid-heal-target',
        displayName: 'Original Name',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
      );

      expect(healed.createdAt, first.createdAt);
      final snapshot = await rawProfiles().doc('ulid-heal-target').get();
      expect(
        DateTime.parse(snapshot.data()!['created_at'] as String).toUtc(),
        _createdAt,
      );
    });

    test('P2-15: the caller-supplied created_at wins even when the STORED '
        'document already disagrees — proof that the write no longer '
        'depends on any Firestore read to decide created_at (the actual '
        'defect: the old decision came from (await ref.get()).data(), which '
        'a stale/offline cache can get wrong; this repository no longer '
        'reads at all, so no cache state — real or simulated here — can '
        'produce a wrong write). fake_cloud_firestore has no cache/offline '
        'semantics to actually go stale, so this seeds a document whose '
        'stored created_at is simply WRONG relative to what the caller now '
        'supplies, which is the only way to distinguish "derived from a '
        'read" from "always the caller\'s value" in this harness.', () async {
      final repo = buildRepo();
      final wrongStoredCreatedAt = DateTime.utc(1999, 1, 1);
      final correctCallerCreatedAt = DateTime.utc(2024, 6, 15);

      await rawProfiles().doc('ulid-caller-truth').set({
        'display_name': 'Stale',
        'mode': 'adult',
        'avatar': '',
        'created_at': wrongStoredCreatedAt.toIso8601String(),
        'updated_at': wrongStoredCreatedAt.toIso8601String(),
      });

      final result = await repo.ensureProfile(
        profileId: 'ulid-caller-truth',
        displayName: 'Fresh Activation',
        mode: ProfileMode.adult,
        createdAt: correctCallerCreatedAt,
      );

      expect(result.createdAt, correctCallerCreatedAt);
      final snapshot = await rawProfiles().doc('ulid-caller-truth').get();
      expect(
        DateTime.parse(snapshot.data()!['created_at'] as String).toUtc(),
        correctCallerCreatedAt,
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
          createdAt: _createdAt,
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
        createdAt: _createdAt,
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
        createdAt: _createdAt,
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
          createdAt: _createdAt,
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
        createdAt: _createdAt,
      );
      await repo.ensureProfile(
        profileId: 'ulid-daniel',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
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
        createdAt: _createdAt,
      );
      await repo.ensureProfile(
        profileId: 'ulid-daniel',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
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
        createdAt: _createdAt,
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
        createdAt: _createdAt,
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
        createdAt: _createdAt,
      );
      final bad = await repo.ensureProfile(
        profileId: 'ulid-bad',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
        createdAt: _createdAt,
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
        createdAt: _createdAt,
      );

      final stream = repo
          .watchProfile(created.profileId)
          .map((p) => p?.displayName);
      await expectLater(stream, emits('Yossi'));
    });
  });
}
