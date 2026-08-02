/// Unit tests for
/// `lib/data/repositories/firestore_curriculum_scope_repository.dart`.
/// Covers: doc-id correctness (`DocIds.curriculumScopeDocId` — see that
/// function's doc comment in `lib/data/firestore/doc_ids.dart` for why it
/// has no live-gateway golden counterpart, unlike most `DocIds` formulas),
/// round-trip, decode leniency (one-shot reads AND the stream), merge-write
/// preserving an out-of-band tutor-CF field, `setScopes`' clear-then-insert
/// replace (both the single-atomic-batch common path and the
/// more-than-500-combined-ops chunked path), and `clearScopes`/delete.
///
/// **What these tests cannot see** (same limitation documented in
/// `firestore_bookmark_repository_test.dart` and, at length, in
/// `test/firestore_fake_custom_functions_test.dart`):
///
/// 1. `fake_cloud_firestore`'s rules companion cannot evaluate custom
///    `function`s (`isOwner(uid)` etc.) at all — `strictRules: true` denies
///    EVERY write, including the true owner's, so it cannot positively
///    confirm "the owner can delete a curriculum_scopes document." That is
///    confirmed instead by reading `firestore.rules` directly (`match
///    /curriculum_scopes/{scopeId} { ... allow delete: if isOwner(uid); }`)
///    and by the real, dynamically-verified emulator matrix
///    (`functions/test/firestore_rules.test.mjs`). All tests here therefore
///    run against the default permissive fake (`strictRules: false`).
/// 2. `fake_cloud_firestore` does not enforce any Firestore-side batch-size
///    or write-throughput limit, so the ">500 combined ops" test below only
///    proves [FirestoreCurriculumScopeRepository.setScopes] produces the
///    CORRECT end state across multiple internal `WriteBatch`es — it cannot
///    prove true cross-batch atomicity (or the lack of it) the way a partial
///    mid-sequence failure against real Firestore would.
/// 3. The resubscribe-with-backoff behavior [FirestoreCurriculumScopeRepository.
///    watchScopes] delegates to (`resilientQueryStream`) is covered directly
///    in `resilient_doc_stream_test.dart` — not re-proven here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_scope.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  CollectionReference<Map<String, dynamic>> rawCollection() => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('curriculum_scopes');

  DocumentReference<Map<String, dynamic>> rawDoc({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required String scopeValue,
  }) => rawCollection().doc(
    DocIds.curriculumScopeDocId({
      'curriculum_id': curriculumId.storageKey,
      'scope_level': scopeLevel,
      'scope_value': scopeValue,
    }),
  );

  FirestoreCurriculumScopeRepository buildRepo() {
    return FirestoreCurriculumScopeRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  group('doc-id correctness', () {
    test('insertScopes writes to {curriculumId}_{scopeLevel}_{scopeValue} — '
        'the DocIds.curriculumScopeDocId formula', () async {
      final repo = buildRepo();

      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [(level: 1, value: 'Seder Zeraim')],
      );

      final expectedId = DocIds.curriculumScopeDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'scope_level': 1,
        'scope_value': 'Seder Zeraim',
      });
      expect(expectedId, 'mishnayos_1_Seder%20Zeraim');
      final snapshot = await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValue: 'Seder Zeraim',
      ).get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['scope_value'], 'Seder Zeraim');
    });

    test(
      'a scope value containing "_" and "/" round-trips through the '
      'percent-encoded doc-id without colliding with another scope',
      () async {
        final repo = buildRepo();

        await repo.insertScopes(
          curriculumId: CurriculumId.bavli,
          scopes: [
            (level: 2, value: 'Berachos_2/3'),
            (level: 2, value: 'Berachos 2 3'),
          ],
        );

        final values = await repo.getScopeValues(CurriculumId.bavli);
        expect(values, containsAll(<String>['Berachos_2/3', 'Berachos 2 3']));
      },
    );
  });

  group('round-trip', () {
    test('getScopes returns an empty list when none exist', () async {
      final repo = buildRepo();

      final scopes = await repo.getScopes(CurriculumId.mishnayos);

      expect(scopes, isEmpty);
    });

    test('insertScopes then getScopes round-trips level + value + '
        'curriculumId', () async {
      final repo = buildRepo();

      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [
          (level: 1, value: 'Seder Zeraim'),
          (level: 1, value: 'Seder Moed'),
        ],
      );
      final scopes = await repo.getScopes(CurriculumId.mishnayos);

      expect(scopes, hasLength(2));
      expect(
        scopes.every((s) => s.curriculumId == CurriculumId.mishnayos),
        isTrue,
      );
      expect(
        scopes.map((s) => s.scopeValue),
        containsAll(<String>['Seder Zeraim', 'Seder Moed']),
      );
      expect(scopes.every((s) => s.scopeLevel == 1), isTrue);
    });

    test(
      'getScopes only returns scopes for the requested curriculum',
      () async {
        final repo = buildRepo();
        await repo.insertScopes(
          curriculumId: CurriculumId.mishnayos,
          scopes: [(level: 1, value: 'Seder Zeraim')],
        );
        await repo.insertScopes(
          curriculumId: CurriculumId.bavli,
          scopes: [(level: 1, value: 'Seder Nezikin')],
        );

        final mishnayosScopes = await repo.getScopes(CurriculumId.mishnayos);

        expect(mishnayosScopes, hasLength(1));
        expect(mishnayosScopes.single.scopeValue, 'Seder Zeraim');
      },
    );

    test(
      'getScopeValues / getScopeLevel / hasScopes convenience readers',
      () async {
        final repo = buildRepo();
        expect(await repo.hasScopes(CurriculumId.mishnayos), isFalse);
        expect(await repo.getScopeLevel(CurriculumId.mishnayos), isNull);

        await repo.insertScopes(
          curriculumId: CurriculumId.mishnayos,
          scopes: [(level: 2, value: 'Berachos')],
        );

        expect(await repo.hasScopes(CurriculumId.mishnayos), isTrue);
        expect(await repo.getScopeLevel(CurriculumId.mishnayos), 2);
        expect(await repo.getScopeValues(CurriculumId.mishnayos), ['Berachos']);
      },
    );

    test('getAllScopes returns scopes across every curriculum', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [(level: 1, value: 'Seder Zeraim')],
      );
      await repo.insertScopes(
        curriculumId: CurriculumId.bavli,
        scopes: [(level: 1, value: 'Seder Nezikin')],
      );

      final all = await repo.getAllScopes();

      expect(all, hasLength(2));
    });
  });

  group('merge write preserves an out-of-band field', () {
    test('insertScopes merges rather than replacing — a pre-existing field '
        'outside the client shape (e.g. a tutor-CF-stamped synced_at) '
        'survives a subsequent owner write to the SAME doc-id', () async {
      final repo = buildRepo();
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValue: 'Seder Zeraim',
      ).set({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'scope_level': 1,
        'scope_value': 'Seder Zeraim',
        'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'synced_at': 'server-stamped-value',
      });

      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [(level: 1, value: 'Seder Zeraim')],
      );

      final snapshot = await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValue: 'Seder Zeraim',
      ).get();
      expect(snapshot.data()!['synced_at'], 'server-stamped-value');
    });
  });

  group('setScopes — clear-then-insert replace', () {
    test('replaces the existing scope set with a new one', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [
          (level: 1, value: 'Seder Zeraim'),
          (level: 1, value: 'Seder Moed'),
        ],
      );

      await repo.setScopes(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Seder Nashim'],
      );

      final scopes = await repo.getScopes(CurriculumId.mishnayos);
      expect(scopes, hasLength(1));
      expect(scopes.single.scopeValue, 'Seder Nashim');
    });

    test('an empty scopeValues list clears all scopes for the curriculum '
        '(= track the entire curriculum)', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [(level: 1, value: 'Seder Zeraim')],
      );

      await repo.setScopes(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: [],
      );

      expect(await repo.getScopes(CurriculumId.mishnayos), isEmpty);
    });

    test('does not disturb a different curriculum\'s scopes', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.bavli,
        scopes: [(level: 1, value: 'Seder Nezikin')],
      );

      await repo.setScopes(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValues: ['Seder Zeraim'],
      );

      final bavliScopes = await repo.getScopes(CurriculumId.bavli);
      expect(bavliScopes, hasLength(1));
      expect(bavliScopes.single.scopeValue, 'Seder Nezikin');
    });

    test(
      'more than 500 combined delete+insert operations still lands the '
      'correct end state via the chunked (non-single-batch) path — see the '
      'class doc comment\'s atomicity caveat for what this does NOT prove',
      () async {
        final repo = buildRepo();
        final initial = [
          for (var i = 0; i < 300; i++) (level: 1, value: 'old-$i'),
        ];
        await repo.insertScopes(
          curriculumId: CurriculumId.mishnayos,
          scopes: initial,
        );
        // 300 deletes + 300 inserts = 600 combined ops > 500-op batch cap.
        final replacement = [for (var i = 0; i < 300; i++) 'new-$i'];

        await repo.setScopes(
          curriculumId: CurriculumId.mishnayos,
          scopeLevel: 1,
          scopeValues: replacement,
        );

        final scopes = await repo.getScopes(CurriculumId.mishnayos);
        expect(scopes, hasLength(300));
        expect(scopes.every((s) => s.scopeValue.startsWith('new-')), isTrue);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('clearScopes', () {
    test('deletes every scope document for the curriculum', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [
          (level: 1, value: 'Seder Zeraim'),
          (level: 1, value: 'Seder Moed'),
        ],
      );

      await repo.clearScopes(CurriculumId.mishnayos);

      expect(await repo.getScopes(CurriculumId.mishnayos), isEmpty);
      final rawSnapshot = await rawCollection().get();
      expect(rawSnapshot.docs, isEmpty);
    });
  });

  group('curriculumScopeFromFirestore — decode failures', () {
    test('throws ArgumentError for an unrecognised curriculum_id', () {
      expect(
        () => curriculumScopeFromFirestore({
          'curriculum_id': 'not-a-real-curriculum',
          'scope_level': 1,
          'scope_value': 'x',
          'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when scope_value is missing', () {
      expect(
        () => curriculumScopeFromFirestore({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'scope_level': 1,
          'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('one-shot reads skip a malformed document instead of failing '
      'the whole read', () {
    test('getScopes omits a document missing scope_value but still '
        'returns the valid ones', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [
          (level: 1, value: 'Seder Zeraim'),
          (level: 1, value: 'Seder Moed'),
        ],
      );
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValue: 'Seder Moed',
      ).update({'scope_value': FieldValue.delete()});

      final scopes = await repo.getScopes(CurriculumId.mishnayos);

      expect(scopes, hasLength(1));
      expect(scopes.single.scopeValue, 'Seder Zeraim');
    });

    test('getAllScopes has the same leniency', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [(level: 1, value: 'Seder Zeraim')],
      );
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        scopeLevel: 1,
        scopeValue: 'Seder Zeraim',
      ).update({'scope_value': FieldValue.delete()});

      expect(await repo.getAllScopes(), isEmpty);
    });
  });

  group('watchScopes — stream emits on change', () {
    test('eventually emits the inserted scopes', () async {
      final repo = buildRepo();

      final stream = repo
          .watchScopes(CurriculumId.nach)
          .map((scopes) => scopes.length);
      final done = expectLater(stream, emitsThrough(2));

      await repo.insertScopes(
        curriculumId: CurriculumId.nach,
        scopes: [(level: 1, value: 'a'), (level: 1, value: 'b')],
      );

      await done;
    });

    test('skips a malformed document but keeps emitting the valid ones '
        '(one-bad-document-does-not-blank-the-list, stream side)', () async {
      final repo = buildRepo();
      await repo.insertScopes(
        curriculumId: CurriculumId.nach,
        scopes: [(level: 1, value: 'good')],
      );

      final events = <int>[];
      final subscription = repo
          .watchScopes(CurriculumId.nach)
          .listen(
            (scopes) => events.add(scopes.length),
            // The decode failure below is forwarded via `addError`
            // (`resilientQueryStream`'s documented contract) alongside the
            // (empty) list emission — a real caller would surface this
            // out-of-band; this test only cares about the list side.
            onError: (_, _) {},
          );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await rawDoc(
        curriculumId: CurriculumId.nach,
        scopeLevel: 1,
        scopeValue: 'good',
      ).update({'scope_value': FieldValue.delete()});
      await pumpEventQueue();

      expect(events, isNotEmpty);
      expect(events.last, 0);
    });
  });
}
