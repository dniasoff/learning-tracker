/// Unit tests for
/// `lib/data/repositories/firestore_account_repository.dart` — Epic B.
/// Covers: `users/{uid}` doc-id correctness (the uid IS the doc-id, no
/// separate id formula), `createAccount`'s idempotent no-op-if-exists
/// behavior (never clobbers `created_at`), `updateAccount`'s
/// current-entity-plus-overrides semantics including the nullable-`email`
/// round-trip, the `profile/data` snapshot's fixed doc-id and open-ended
/// Map shape, and the stream emitting on change for both documents.
///
/// **What these tests cannot see** (same limitation noted throughout this
/// directory): `fake_cloud_firestore`'s rules companion cannot evaluate
/// `resource.data`/`request.resource`, so `strictRules: false` is used
/// throughout — this proves the repository targets the right documents
/// with the right shapes, not that `firestore.rules` itself grants/denies
/// the right callers. The resubscribe-with-backoff behavior
/// [FirestoreAccountRepository.watchAccount]/[watchProfileSnapshot]
/// delegate to is covered directly in `resilient_doc_stream_test.dart` —
/// not re-proven here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  DocumentReference<Map<String, dynamic>> rawAccountDoc() =>
      firestore.collection('users').doc(_uid);

  DocumentReference<Map<String, dynamic>> rawProfileSnapshotDoc() =>
      firestore.collection('users').doc(_uid).collection('profile').doc('data');

  FirestoreAccountRepository buildRepo() =>
      FirestoreAccountRepository(firestore: firestore, uid: _uid);

  group('doc-id correctness', () {
    test(
      'createAccount writes to users/{uid} — the uid is the doc-id',
      () async {
        final repo = buildRepo();

        await repo.createAccount(displayName: 'Daniel');

        final snapshot = await rawAccountDoc().get();
        expect(snapshot.exists, isTrue);
      },
    );

    test('updateProfileSnapshot writes to users/{uid}/profile/data', () async {
      final repo = buildRepo();

      await repo.updateProfileSnapshot({'name': 'Bob'});

      final snapshot = await rawProfileSnapshotDoc().get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['name'], 'Bob');
    });
  });

  group('createAccount — idempotent', () {
    test('returns the existing account and does not overwrite created_at '
        'on a second call', () async {
      final repo = buildRepo();
      final first = await repo.createAccount(displayName: 'Daniel');
      // Mutate created_at directly to prove a second createAccount call
      // does not touch it (it should short-circuit on the existing read).
      await rawAccountDoc().update({
        'created_at': DateTime.utc(2020, 1, 1).toIso8601String(),
      });

      final second = await repo.createAccount(displayName: 'A different name');

      expect(second.displayName, first.displayName);
      final snapshot = await rawAccountDoc().get();
      expect(
        snapshot.data()!['created_at'],
        DateTime.utc(2020, 1, 1).toIso8601String(),
      );
    });

    test('a fresh account round-trips through getAccount', () async {
      final repo = buildRepo();

      final created = await repo.createAccount(
        displayName: 'Daniel',
        email: 'daniel@example.com',
      );
      final fetched = await repo.getAccount();

      expect(fetched, created);
    });
  });

  group('updateAccount — current entity + optional overrides', () {
    test('changes only the given field, leaving the rest untouched', () async {
      final repo = buildRepo();
      final account = await repo.createAccount(
        displayName: 'Daniel',
        email: 'daniel@example.com',
      );

      final updated = await repo.updateAccount(
        account: account,
        displayName: 'Dani',
      );

      expect(updated.displayName, 'Dani');
      expect(updated.email, 'daniel@example.com');
      final fetched = await repo.getAccount();
      expect(fetched, updated);
    });

    test('the anonymous -> linked-credential upgrade sets email for the '
        'first time', () async {
      final repo = buildRepo();
      final account = await repo.createAccount(displayName: 'Anonymous');
      expect(account.email, isNull);

      final updated = await repo.updateAccount(
        account: account,
        email: 'daniel@example.com',
      );

      expect(updated.email, 'daniel@example.com');
    });
  });

  group('getAccount / getProfileSnapshot — absent document', () {
    test(
      'getAccount returns null before createAccount is ever called',
      () async {
        final repo = buildRepo();

        expect(await repo.getAccount(), isNull);
      },
    );

    test('getProfileSnapshot returns null before any write', () async {
      final repo = buildRepo();

      expect(await repo.getProfileSnapshot(), isNull);
    });
  });

  group('watchAccount / watchProfileSnapshot — stream emits on change', () {
    test('watchAccount eventually reflects a written display name', () async {
      final repo = buildRepo();

      final stream = repo.watchAccount().map((a) => a?.displayName);
      final done = expectLater(stream, emitsThrough('Daniel'));

      await repo.createAccount(displayName: 'Daniel');

      await done;
    });

    test('watchProfileSnapshot eventually reflects a written field', () async {
      final repo = buildRepo();

      final stream = repo.watchProfileSnapshot().map((d) => d?['name']);
      final done = expectLater(stream, emitsThrough('Bob'));

      await repo.updateProfileSnapshot({'name': 'Bob'});

      await done;
    });
  });
}
