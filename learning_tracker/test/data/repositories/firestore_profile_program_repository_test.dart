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
import '../../helpers/firestore_governed_writer.dart';
import '../../helpers/retired_inventory.dart';

const _uid = 'uid-1';
const _profileId = governedTestProfileId;
const _programRepository =
    'lib/data/repositories/firestore_profile_program_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreGovernedWriter writer;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    writer = FirestoreGovernedWriter(firestore, uid: _uid);
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
      writer: writer,
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
      // AD-52 shapes: program_id is a string, the start a civil date;
      // the governed timestamps are retired (R16).
      final raw = (await rawDoc(CurriculumId.chumash).get()).data()!;
      expect(raw['program_id'], '7');
      expect(raw['tracking_start_date'], '2026-01-01');
      for (final key in retiredKeysOf(_programRepository)) {
        expect(raw.keys, isNot(contains(key)), reason: key);
      }
      expect(written.programId, 7);
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

  group('governed writes (AD-38, DNI-476)', () {
    test('setProgram is one logged mainTrackProgram change carrying '
        'curriculum_id and last_change_id; no profile_id', () async {
      final repo = buildRepo();

      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);

      final entry = (await writer.lastEntries()).single;
      expect(entry.entity.storage, 'mainTrackProgram');
      expect(entry.entityId, 'mishnayos');
      final raw = (await rawDoc(CurriculumId.mishnayos).get()).data()!;
      expect(raw['last_change_id'], entry.id);
      expect(raw['curriculum_id'], 'mishnayos');
      expect(raw.keys, isNot(contains('profile_id')));
    });
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
        snapshot.data()!['tracking_start_date'],
        isNull,
        reason:
            'an omitted key would have left the STALE 2026-01-01 value in '
            'place; the governed patch clears it with an explicit null',
      );
      expect(snapshot.data()!['tracking_start_ref'], isNull);
      final read = await repo.getProgram(CurriculumId.chumash);
      expect(read!.trackingStartDate, isNull);
      expect(read.trackingStartRef, isNull);
    });
  });

  group('merge write preserves an out-of-band field', () {
    test('setProgram merges rather than replacing — a pre-existing field '
        'outside the client whitelist (e.g. a legacy retired stamp) survives '
        'a subsequent owner write', () async {
      final repo = buildRepo();
      final legacy = legacyKeys(
        retiredKeysOf(_programRepository),
        value: 'server-stamped-value',
      );
      await rawDoc(CurriculumId.chumash).set({
        'profile_id': _profileId,
        'curriculum_id': CurriculumId.chumash.storageKey,
        'program_id': 1,
        ...legacy,
      });

      await repo.setProgram(curriculumId: CurriculumId.chumash, programId: 2);

      final snapshot = await rawDoc(CurriculumId.chumash).get();
      expect(
        snapshot.data(),
        containsPair(legacy.keys.last, 'server-stamped-value'),
      );
      expect(snapshot.data()!['program_id'], '2');
    });
  });

  group('removeProgram — a tombstone, never a delete', () {
    test('sets ended_at through a logged change; reads skip it', () async {
      final repo = buildRepo();
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);

      await repo.removeProgram(CurriculumId.mishnayos);

      final snapshot = await rawDoc(CurriculumId.mishnayos).get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['ended_at'], isA<Timestamp>());
      expect(await repo.getProgram(CurriculumId.mishnayos), isNull);
      expect(await repo.getAllPrograms(), isEmpty);
      final entry = (await writer.lastEntries()).single;
      expect(entry.after.keys, ['profile_programs/mishnayos.ended_at']);
    });

    test('is a no-op when there is no live assignment', () async {
      final repo = buildRepo();
      await repo.removeProgram(CurriculumId.mishnayos);
      expect(writer.actions, isEmpty);
    });

    test('setProgram after removal revives the same doc', () async {
      final repo = buildRepo();
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 1);
      await repo.removeProgram(CurriculumId.mishnayos);
      await repo.setProgram(curriculumId: CurriculumId.mishnayos, programId: 4);

      final read = await repo.getProgram(CurriculumId.mishnayos);
      expect(read!.programId, 4);
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
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when program_id is missing', () {
      expect(
        () => profileProgramFromFirestore({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
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
