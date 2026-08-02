/// Unit tests for
/// `lib/data/repositories/firestore_profile_program_repository.dart`.
/// Covers: doc-id correctness, round-trip, `profile_id` being written as
/// the String learner-profile ULID (never the Drift `int`), the
/// `SetOptions(merge: true)` field-clearing trap for `tracking_start_date`/
/// `tracking_start_ref` (see that file's class doc comment), delete
/// (`removeProgram`), and decode leniency (one-shot AND stream).
///
/// **What these tests cannot see** — same limitation documented at length in
/// `firestore_curriculum_scope_repository_test.dart` and
/// `test/firestore_fake_custom_functions_test.dart`: `fake_cloud_firestore`'s
/// rules companion cannot evaluate custom `function`s, so `strictRules:
/// true` cannot positively confirm "the owner can delete a profile_programs
/// document" — confirmed instead by reading `firestore.rules` directly
/// (`match /profile_programs/{curriculumId} { ... allow delete: if
/// isOwner(uid); }`, with the comment explaining `removeProfileProgramAssignment`
/// depends on it) and by the real emulator matrix
/// (`functions/test/firestore_rules.test.mjs`). All tests here run against
/// the default permissive fake. The resubscribe-with-backoff behavior
/// [FirestoreProfileProgramRepository.watchProgram]/[watchAllPrograms]
/// delegate to is covered directly in `resilient_doc_stream_test.dart` —
/// not re-proven here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';

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
      .collection('profile_programs');

  DocumentReference<Map<String, dynamic>> rawDoc(CurriculumId curriculumId) =>
      rawCollection().doc(curriculumId.storageKey);

  FirestoreProfileProgramRepository buildRepo() {
    return FirestoreProfileProgramRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  group('doc-id correctness', () {
    test('setProgram writes to users/{uid}/learner_profiles/{profileId}/'
        'profile_programs/{curriculumId} — the DocIds.profileProgramDocId '
        'formula', () async {
      final repo = buildRepo();

      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 3);

      final expectedId = DocIds.profileProgramDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
      });
      expect(expectedId, CurriculumId.mishnayos.storageKey);
      final snapshot = await rawDoc(CurriculumId.mishnayos).get();
      expect(snapshot.exists, isTrue);
    });

    test('two different curricula land on two different documents', () async {
      final repo = buildRepo();

      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);
      await repo.setProgram(curriculumId: CurriculumId.bavli, programId: 2);

      final a = await repo.getProgram(CurriculumId.mishnayos);
      final b = await repo.getProgram(CurriculumId.bavli);
      expect(a!.programId, 1);
      expect(b!.programId, 2);
    });
  });

  group('round-trip', () {
    test('getProgram returns null when no assignment exists yet', () async {
      final repo = buildRepo();

      final result = await repo.getProgram(CurriculumId.bavli);

      expect(result, isNull);
    });

    test('setProgram then getProgram round-trips every field', () async {
      final repo = buildRepo();

      final written = await repo.setProgram(
        curriculumId: CurriculumId.chumash,
        programId: 7,
        trackingStartDate: DateTime.utc(2026, 1, 1),
        trackingStartRef: 'Genesis.1.1',
      );
      final read = await repo.getProgram(CurriculumId.chumash);

      expect(read, isNotNull);
      expect(read!.curriculumId, CurriculumId.chumash);
      expect(read.programId, 7);
      expect(read.trackingStartDate, DateTime.utc(2026, 1, 1));
      expect(read.trackingStartRef, 'Genesis.1.1');
      expect(read.updatedAt, written.updatedAt);
    });

    test('setProgram with no tracking window omits both fields', () async {
      final repo = buildRepo();

      await repo.setProgram(curriculumId: CurriculumId.chumash, programId: 7);
      final read = await repo.getProgram(CurriculumId.chumash);

      expect(read!.trackingStartDate, isNull);
      expect(read.trackingStartRef, isNull);
    });

    test('setProgram on an existing assignment overwrites programId', () async {
      final repo = buildRepo();

      await repo.setProgram(curriculumId: CurriculumId.chumash, programId: 1);
      await repo.setProgram(curriculumId: CurriculumId.chumash, programId: 2);

      final read = await repo.getProgram(CurriculumId.chumash);
      expect(read!.programId, 2);
    });
  });

  group('profile_id is written as the String ULID, never a Drift int', () {
    test(
      'the raw document stores profile_id as the profileId String',
      () async {
        final repo = buildRepo();

        await repo.setProgram(
          curriculumId: CurriculumId.mishnayos,
          programId: 1,
        );

        final snapshot = await rawDoc(CurriculumId.mishnayos).get();
        expect(snapshot.data()!['profile_id'], _profileId);
        expect(snapshot.data()!['profile_id'], isA<String>());
      },
    );
  });

  group('SetOptions(merge: true) field-clearing trap — tracking_start_date/'
      'tracking_start_ref must be explicitly cleared, not merely omitted', () {
    test('switching from a program WITH a tracking window to one WITHOUT '
        'clears the stale tracking_start_date/tracking_start_ref rather '
        'than leaving them in place', () async {
      final repo = buildRepo();
      await repo.setProgram(
        curriculumId: CurriculumId.chumash,
        programId: 1,
        trackingStartDate: DateTime.utc(2026, 1, 1),
        trackingStartRef: 'Genesis.1.1',
      );

      await repo.setProgram(curriculumId: CurriculumId.chumash, programId: 2);

      final snapshot = await rawDoc(CurriculumId.chumash).get();
      expect(
        snapshot.data(),
        isNot(contains('tracking_start_date')),
        reason:
            'a bare merge-set omitting the key would have left the '
            'STALE 2026-01-01 value in place instead',
      );
      expect(snapshot.data(), isNot(contains('tracking_start_ref')));
      final read = await repo.getProgram(CurriculumId.chumash);
      expect(read!.trackingStartDate, isNull);
      expect(read.trackingStartRef, isNull);
    });
  });

  group('merge write preserves an out-of-band field', () {
    test('setProgram merges rather than replacing — a pre-existing field '
        'outside the client whitelist (e.g. a tutor-CF-stamped synced_at) '
        'survives a subsequent owner write', () async {
      final repo = buildRepo();
      await rawDoc(CurriculumId.chumash).set({
        'profile_id': _profileId,
        'curriculum_id': CurriculumId.chumash.storageKey,
        'program_id': 1,
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'synced_at': 'server-stamped-value',
      });

      await repo.setProgram(curriculumId: CurriculumId.chumash, programId: 2);

      final snapshot = await rawDoc(CurriculumId.chumash).get();
      expect(snapshot.data()!['synced_at'], 'server-stamped-value');
      expect(snapshot.data()!['program_id'], 2);
    });
  });

  group('removeProgram — real delete', () {
    test('deletes the document for the curriculum', () async {
      final repo = buildRepo();
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);

      await repo.removeProgram(CurriculumId.mishnayos);

      final snapshot = await rawDoc(CurriculumId.mishnayos).get();
      expect(snapshot.exists, isFalse);
      expect(await repo.getProgram(CurriculumId.mishnayos), isNull);
    });

    test('does not disturb a different curriculum\'s assignment', () async {
      final repo = buildRepo();
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);
      await repo.setProgram(curriculumId: CurriculumId.bavli, programId: 2);

      await repo.removeProgram(CurriculumId.mishnayos);

      expect(await repo.getProgram(CurriculumId.bavli), isNotNull);
    });
  });

  group('getAllPrograms / watchAllPrograms', () {
    test('getAllPrograms returns every curriculum\'s assignment', () async {
      final repo = buildRepo();
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);
      await repo.setProgram(curriculumId: CurriculumId.bavli, programId: 2);

      final all = await repo.getAllPrograms();

      expect(all, hasLength(2));
    });

    test(
      'watchProgram eventually emits the created and updated assignment',
      () async {
        final repo = buildRepo();

        final stream = repo
            .watchProgram(CurriculumId.nach)
            .map((p) => p?.programId);
        final done = expectLater(stream, emitsThrough(2));

        await repo.setProgram(curriculumId: CurriculumId.nach, programId: 1);
        await repo.setProgram(curriculumId: CurriculumId.nach, programId: 2);

        await done;
      },
    );
  });

  group('profileProgramFromFirestore — decode failures', () {
    test('throws ArgumentError for an unrecognised curriculum_id', () {
      expect(
        () => profileProgramFromFirestore({
          'curriculum_id': 'not-a-real-curriculum',
          'program_id': 1,
          'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when program_id is missing', () {
      expect(
        () => profileProgramFromFirestore({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('one-shot reads and the stream skip a malformed document instead '
      'of failing entirely', () {
    test('getAllPrograms omits a document missing program_id but still '
        'returns the valid ones', () async {
      final repo = buildRepo();
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);
      await repo.setProgram(curriculumId: CurriculumId.bavli, programId: 2);
      await rawDoc(
        CurriculumId.bavli,
      ).update({'program_id': FieldValue.delete()});

      final all = await repo.getAllPrograms();

      expect(all, hasLength(1));
      expect(all.single.curriculumId, CurriculumId.mishnayos);
    });

    test('watchAllPrograms skips a malformed document but keeps emitting '
        'the valid ones', () async {
      final repo = buildRepo();
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);

      final events = <int>[];
      final subscription = repo.watchAllPrograms().listen(
        (programs) => events.add(programs.length),
        // The decode failure below is forwarded via `addError`
        // (`resilientQueryStream`'s documented contract) alongside the
        // (empty) list emission — a real caller would surface this
        // out-of-band; this test only cares about the list side.
        onError: (_, _) {},
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await rawDoc(
        CurriculumId.mishnayos,
      ).update({'program_id': FieldValue.delete()});
      await pumpEventQueue();

      expect(events, isNotEmpty);
      expect(events.last, 0);
    });
  });
}
