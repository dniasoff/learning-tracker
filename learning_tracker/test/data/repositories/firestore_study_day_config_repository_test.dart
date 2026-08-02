/// Unit tests for
/// `lib/data/repositories/firestore_study_day_config_repository.dart` —
/// Epic B. Covers: doc-id correctness, the composite-index query shape
/// (`curriculum_id` equality + `day_of_week` ordering), model round-trip,
/// the stream emitting on change, [FirestoreStudyDayConfigRepository
/// .initializeDefaults]' idempotency, and — the one capability this
/// collection has that the reference `stage_definitions` repository does
/// NOT (rules permit delete here) —
/// [FirestoreStudyDayConfigRepository.replaceAllForCurriculum]'s actual
/// delete-then-upsert semantics. Also the "one bad document doesn't blank
/// the list" decode leniency (both the stream AND the one-shot read).
///
/// **What these tests cannot see** (same limitation as
/// `firestore_stage_definition_repository_test.dart`):
/// `fake_cloud_firestore` does not enforce Firestore's composite-index
/// requirement at all — a query missing its index would run fine against
/// the fake and only fail in production. These tests prove the query
/// returns the CORRECT, correctly-ordered rows; they cannot prove the
/// index in `firestore.indexes.json` is the one that makes it work for
/// real. The resubscribe-with-backoff behavior
/// [FirestoreStudyDayConfigRepository.watchConfigsForCurriculum] delegates
/// to is covered directly in `resilient_doc_stream_test.dart`
/// (`resilientQueryStream` groups) — not re-proven here. `fake_cloud_
/// firestore` also delivers a `WriteBatch`'s writes to a listener as
/// several incremental snapshots rather than one combined update (real
/// Firestore applies a batch to the local cache atomically) — the stream
/// test below tolerates this instead of asserting an exact emission count.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  DocumentReference<Map<String, dynamic>> rawDoc({
    required CurriculumId curriculumId,
    required int dayOfWeek,
  }) => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('study_day_configs')
      .doc(
        DocIds.studyDayConfigDocId({
          'curriculum_id': curriculumId.storageKey,
          'day_of_week': dayOfWeek,
        }),
      );

  FirestoreStudyDayConfigRepository buildRepo() {
    return FirestoreStudyDayConfigRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  group('doc-id correctness', () {
    test('setDayConfig writes to {curriculumId}_{dayOfWeek} — the '
        'DocIds.studyDayConfigDocId formula', () async {
      final repo = buildRepo();

      await repo.setDayConfig(
        curriculumId: CurriculumId.mishnayos,
        dayOfWeek: 3,
        dayType: DayType.review,
      );

      final expectedId = DocIds.studyDayConfigDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'day_of_week': 3,
      });
      expect(expectedId, '${CurriculumId.mishnayos.storageKey}_3');
      final snapshot = await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        dayOfWeek: 3,
      ).get();
      expect(snapshot.exists, isTrue);
    });

    test('never writes a track_id field (AD-25 — no per-device track key '
        'for this collection)', () async {
      final repo = buildRepo();

      await repo.setDayConfig(
        curriculumId: CurriculumId.mishnayos,
        dayOfWeek: 1,
        dayType: DayType.study,
      );

      final snapshot = await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        dayOfWeek: 1,
      ).get();
      expect(snapshot.data(), isNot(contains('track_id')));
    });
  });

  group('composite-index query — getConfigsForCurriculum', () {
    test(
      'returns only the given curriculum\'s configs, ordered by dayOfWeek',
      () async {
        final repo = buildRepo();
        await repo.initializeDefaults(CurriculumId.mishnayos);
        await repo.initializeDefaults(CurriculumId.bavli);

        final configs = await repo.getConfigsForCurriculum(
          CurriculumId.mishnayos,
        );

        expect(configs, hasLength(7));
        expect(configs.map((c) => c.dayOfWeek), [1, 2, 3, 4, 5, 6, 7]);
      },
    );

    test(
      'returns an empty list when no configs exist for the curriculum',
      () async {
        final repo = buildRepo();

        final configs = await repo.getConfigsForCurriculum(CurriculumId.bavli);

        expect(configs, isEmpty);
      },
    );
  });

  group('model round-trip', () {
    test(
      'setDayConfig then getConfigsForCurriculum round-trips dayType',
      () async {
        final repo = buildRepo();

        await repo.setDayConfig(
          curriculumId: CurriculumId.chumash,
          dayOfWeek: 5,
          dayType: DayType.review,
        );

        final configs = await repo.getConfigsForCurriculum(
          CurriculumId.chumash,
        );
        expect(configs, hasLength(1));
        expect(configs.single.dayOfWeek, 5);
        expect(configs.single.dayType, DayType.review);
      },
    );

    test('setDayConfig on an existing day overwrites its dayType', () async {
      final repo = buildRepo();
      await repo.setDayConfig(
        curriculumId: CurriculumId.chumash,
        dayOfWeek: 2,
        dayType: DayType.study,
      );

      await repo.setDayConfig(
        curriculumId: CurriculumId.chumash,
        dayOfWeek: 2,
        dayType: DayType.review,
      );

      final configs = await repo.getConfigsForCurriculum(CurriculumId.chumash);
      expect(configs.single.dayType, DayType.review);
    });

    test('setDayConfig merges rather than replacing — a pre-existing field '
        'outside the client whitelist (e.g. a tutor-CF-stamped synced_at) '
        'survives a subsequent owner write', () async {
      final repo = buildRepo();
      await rawDoc(curriculumId: CurriculumId.chumash, dayOfWeek: 1).set({
        'curriculum_id': CurriculumId.chumash.storageKey,
        'day_of_week': 1,
        'day_type': DayType.study.storageKey,
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'synced_at': 'server-stamped-value',
      });

      await repo.setDayConfig(
        curriculumId: CurriculumId.chumash,
        dayOfWeek: 1,
        dayType: DayType.review,
      );

      final snapshot = await rawDoc(
        curriculumId: CurriculumId.chumash,
        dayOfWeek: 1,
      ).get();
      expect(snapshot.data()!['synced_at'], 'server-stamped-value');
      expect(snapshot.data()!['day_type'], DayType.review.storageKey);
    });
  });

  group('watchConfigsForCurriculum — stream emits on change', () {
    test('eventually emits all 7 default configs once written', () async {
      // Same fake-batching caveat as
      // firestore_stage_definition_repository_test.dart's stream test.
      final repo = buildRepo();

      final stream = repo
          .watchConfigsForCurriculum(CurriculumId.nach)
          .map((configs) => configs.length);
      final done = expectLater(stream, emitsThrough(7));

      await repo.initializeDefaults(CurriculumId.nach);

      await done;
    });
  });

  group('initializeDefaults — idempotent', () {
    test('seeds 7 days as DayType.study', () async {
      final repo = buildRepo();

      await repo.initializeDefaults(CurriculumId.mishnayos);

      final configs = await repo.getConfigsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(configs, hasLength(7));
      expect(configs.every((c) => c.dayType == DayType.study), isTrue);
    });

    test(
      'does nothing when configs already exist for the curriculum',
      () async {
        final repo = buildRepo();
        await repo.initializeDefaults(CurriculumId.mishnayos);
        await repo.setDayConfig(
          curriculumId: CurriculumId.mishnayos,
          dayOfWeek: 1,
          dayType: DayType.review,
        );

        await repo.initializeDefaults(CurriculumId.mishnayos);

        final configs = await repo.getConfigsForCurriculum(
          CurriculumId.mishnayos,
        );
        final day1 = configs.firstWhere((c) => c.dayOfWeek == 1);
        expect(
          day1.dayType,
          DayType.review,
          reason: 're-seeding must not clobber an existing customization',
        );
      },
    );
  });

  group('replaceAllForCurriculum — the capability stage_definitions/goals '
      'cannot offer (rules permit delete on this collection)', () {
    test('upserts every day in the new set', () async {
      final repo = buildRepo();

      await repo.replaceAllForCurriculum(
        curriculumId: CurriculumId.bavli,
        studyDays: {1: DayType.review, 3: DayType.study},
      );

      final configs = await repo.getConfigsForCurriculum(CurriculumId.bavli);
      expect(configs, hasLength(2));
      expect(configs.map((c) => c.dayOfWeek), [1, 3]);
      expect(configs.first.dayType, DayType.review);
    });

    test(
      'DELETES an existing day absent from the new set — the actual '
      'replace-all semantics rules deny for stage_definitions/goals',
      () async {
        final repo = buildRepo();
        await repo.initializeDefaults(CurriculumId.bavli); // seeds days 1-7

        await repo.replaceAllForCurriculum(
          curriculumId: CurriculumId.bavli,
          studyDays: {1: DayType.study, 2: DayType.study},
        );

        final configs = await repo.getConfigsForCurriculum(CurriculumId.bavli);
        expect(configs.map((c) => c.dayOfWeek), [1, 2]);
        for (final day in [3, 4, 5, 6, 7]) {
          final snapshot = await rawDoc(
            curriculumId: CurriculumId.bavli,
            dayOfWeek: day,
          ).get();
          expect(snapshot.exists, isFalse);
        }
      },
    );

    test('replacing with an empty map deletes every existing day', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.bavli);

      await repo.replaceAllForCurriculum(
        curriculumId: CurriculumId.bavli,
        studyDays: const {},
      );

      final configs = await repo.getConfigsForCurriculum(CurriculumId.bavli);
      expect(configs, isEmpty);
    });
  });

  group('studyDayConfigEntryFromFirestore — decode failures', () {
    test('throws FormatException when day_of_week is missing', () {
      expect(
        () => studyDayConfigEntryFromFirestore({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'day_type': DayType.study.storageKey,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when day_type is missing', () {
      expect(
        () => studyDayConfigEntryFromFirestore({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'day_of_week': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('propagates a StateError for an unrecognised day_type', () {
      expect(
        () => studyDayConfigEntryFromFirestore({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'day_of_week': 1,
          'day_type': 'not-a-real-day-type',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('one-shot reads skip a malformed document instead of failing '
      'the whole read', () {
    test('getConfigsForCurriculum omits a document missing day_type but '
        'still returns the valid ones', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.mishnayos);
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        dayOfWeek: 4,
      ).update({'day_type': FieldValue.delete()});

      final configs = await repo.getConfigsForCurriculum(
        CurriculumId.mishnayos,
      );

      expect(configs, hasLength(6));
      expect(configs.map((c) => c.dayOfWeek), isNot(contains(4)));
    });
  });
}
