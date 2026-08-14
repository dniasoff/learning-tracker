/// Unit tests for
/// `lib/data/repositories/firestore_stage_definition_repository.dart` — the
/// SECOND reference Firestore repository (Epic B), chosen to exercise the
/// composite-index query workflow `FirestoreBookmarkRepository` never
/// touches. Covers: doc-id correctness, the composite-index query shape,
/// model round-trip, the stream emitting on change, the "one bad document
/// doesn't blank the list" behavior (both the stream AND the one-shot
/// reads), completion existence checks, and
/// `resetToDefaults`' documented can't-actually-delete limitation.
///
/// **What these tests cannot see** (same limitation as
/// `firestore_bookmark_repository_test.dart`): `fake_cloud_firestore`
/// does not enforce Firestore's composite-index requirement at all — a
/// query missing its index would run fine against the fake and only fail
/// in production. These tests prove the query returns the CORRECT,
/// correctly-ordered rows; they cannot prove the index in
/// `firestore.indexes.json` is the one that makes it work for real. The
/// resubscribe-with-backoff behavior `watchStagesForCurriculum` delegates
/// to is covered directly in `resilient_doc_stream_test.dart`
/// (`resilientQueryStream` groups) — not re-proven here. Also:
/// `fake_cloud_firestore` delivers a `WriteBatch`'s writes to a listener as
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
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_fixtures.dart';

const _uid = 'uid-1';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  DocumentReference<Map<String, dynamic>> rawDoc({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('stage_definitions')
      .doc(
        DocIds.stageDefinitionDocId({
          'curriculum_id': curriculumId.storageKey,
          'stage_order': stageOrder,
        }),
      );

  FirestoreStageDefinitionRepository buildRepo() {
    return FirestoreStageDefinitionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  group('doc-id correctness', () {
    test(
      'initializeDefaults writes the 3 defaults at '
      '{curriculumId}_{stageOrder} — the DocIds.stageDefinitionDocId formula',
      () async {
        final repo = buildRepo();

        await repo.initializeDefaults(CurriculumId.mishnayos);

        for (final order in [1, 2, 3]) {
          final expectedId = DocIds.stageDefinitionDocId({
            'curriculum_id': CurriculumId.mishnayos.storageKey,
            'stage_order': order,
          });
          expect(expectedId, '${CurriculumId.mishnayos.storageKey}_$order');
          final snapshot = await rawDoc(
            curriculumId: CurriculumId.mishnayos,
            stageOrder: order,
          ).get();
          expect(snapshot.exists, isTrue);
        }
      },
    );

    test('never writes a track_id field (AD-25 — no per-device track key '
        'for this collection)', () async {
      final repo = buildRepo();

      await repo.initializeDefaults(CurriculumId.mishnayos);

      final snapshot = await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      ).get();
      expect(snapshot.data(), isNot(contains('track_id')));
    });
  });

  group('composite-index query — getStagesForCurriculum', () {
    test(
      'returns only the given curriculum\'s stages, ordered by stage_order',
      () async {
        final repo = buildRepo();
        await repo.initializeDefaults(CurriculumId.mishnayos);
        await repo.initializeDefaults(CurriculumId.bavli);

        final stages = await repo.getStagesForCurriculum(
          CurriculumId.mishnayos,
        );

        expect(stages, hasLength(3));
        expect(stages.map((s) => s.stageOrder), [1, 2, 3]);
        expect(
          stages.every((s) => s.curriculumId == CurriculumId.mishnayos),
          isTrue,
        );
      },
    );

    test(
      'returns an empty list when no stages exist for the curriculum',
      () async {
        final repo = buildRepo();

        final stages = await repo.getStagesForCurriculum(CurriculumId.bavli);

        expect(stages, isEmpty);
      },
    );
  });

  group('model round-trip', () {
    test('a delay-schedule stage round-trips every field', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.mishnayos);

      final stages = await repo.getStagesForCurriculum(CurriculumId.mishnayos);
      final learn = stages.firstWhere((s) => s.stageOrder == 1);

      expect(learn.curriculumId, CurriculumId.mishnayos);
      expect(learn.scheduleType, ScheduleType.delay);
      expect(learn.delayDays, 0);
      expect(learn.isDefault, isTrue);
      expect(learn.id, kFirestoreUnmappedStageId);
    });

    test('a weekly-schedule stage round-trips daysOfWeek', () async {
      const custom = StageDefinition(
        id: kFirestoreUnmappedStageId,
        curriculumId: CurriculumId.bavli,
        stageOrder: 4,
        stageName: 'Weekly review',
        delayDays: 0,
        isDefault: false,
        scheduleType: ScheduleType.weekly,
        daysOfWeek: [1, 4],
      );
      await rawDoc(
        curriculumId: CurriculumId.bavli,
        stageOrder: 4,
      ).set(custom.toFirestore(updatedAt: DateTime.utc(2026, 1, 1)));
      final repo = buildRepo();

      final stages = await repo.getStagesForCurriculum(CurriculumId.bavli);

      expect(stages, hasLength(1));
      expect(stages.single.scheduleType, ScheduleType.weekly);
      expect(stages.single.daysOfWeek, [1, 4]);
    });

    test('a rolling-schedule stage round-trips rollingWindowSize', () async {
      const custom = StageDefinition(
        id: kFirestoreUnmappedStageId,
        curriculumId: CurriculumId.bavli,
        stageOrder: 5,
        stageName: 'Rolling review',
        delayDays: 0,
        isDefault: false,
        scheduleType: ScheduleType.rolling,
        rollingWindowSize: 7,
      );
      await rawDoc(
        curriculumId: CurriculumId.bavli,
        stageOrder: 5,
      ).set(custom.toFirestore(updatedAt: DateTime.utc(2026, 1, 1)));
      final repo = buildRepo();

      final stages = await repo.getStagesForCurriculum(CurriculumId.bavli);

      expect(stages, hasLength(1));
      expect(stages.single.scheduleType, ScheduleType.rolling);
      expect(stages.single.rollingWindowSize, 7);
    });
  });

  group('stageDefinitionFromFirestore — decode failures', () {
    test('throws ArgumentError for an unrecognised curriculum_id', () {
      expect(
        () => stageDefinitionFromFirestore({
          'curriculum_id': 'not-a-real-curriculum',
          'stage_order': 1,
          'stage_name': 'x',
          'schedule_type': 'delay',
          'delay_days': 0,
          'is_default': false,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws FormatException when schedule_type is missing', () {
      expect(
        () => stageDefinitionFromFirestore({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'stage_order': 1,
          'stage_name': 'x',
          'is_default': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('one-shot reads skip a malformed document instead of failing '
      'the whole read', () {
    test('getStagesForCurriculum omits a document missing schedule_type '
        'but still returns the valid ones', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.mishnayos);
      // Corrupt one of the 3 default docs in place.
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
      ).update({'schedule_type': FieldValue.delete()});

      final stages = await repo.getStagesForCurriculum(CurriculumId.mishnayos);

      expect(stages, hasLength(2));
      expect(stages.map((s) => s.stageOrder), [1, 3]);
    });

    test('getAllStageDefinitions has the same leniency', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.mishnayos);
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      ).update({'schedule_type': FieldValue.delete()});

      final stages = await repo.getAllStageDefinitions();

      expect(stages, hasLength(2));
    });
  });

  group('watchStagesForCurriculum — stream emits on change', () {
    test('eventually emits all 3 default stages once written', () async {
      // `fake_cloud_firestore` delivers a WriteBatch's writes to a listener
      // as several incremental snapshots rather than one combined update
      // (unlike real Firestore, where a batch commit's local-cache
      // application is atomic) — a known fake limitation, not a behavior
      // this test should pin. `emitsThrough` consumes and ignores whatever
      // intermediate counts the fake produces and only requires the
      // terminal state (3) to eventually appear.
      final repo = buildRepo();

      final stream = repo
          .watchStagesForCurriculum(CurriculumId.nach)
          .map((stages) => stages.length);
      final done = expectLater(stream, emitsThrough(3));

      await repo.initializeDefaults(CurriculumId.nach);

      await done;
    });
  });

  group('initializeDefaults — idempotent', () {
    test('does nothing when stages already exist for the curriculum', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.mishnayos);
      // Mutate a default stage so a re-seed would be observable.
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      ).update({'stage_name': 'Customized'});

      await repo.initializeDefaults(CurriculumId.mishnayos);

      final stages = await repo.getStagesForCurriculum(CurriculumId.mishnayos);
      final learn = stages.firstWhere((s) => s.stageOrder == 1);
      expect(learn.stageName, 'Customized');
    });
  });

  group('resetToDefaults — documented can\'t-actually-delete limitation', () {
    test('overwrites the 3 default doc-ids back to default content', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.mishnayos);
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      ).update({'stage_name': 'Customized'});

      await repo.resetToDefaults(CurriculumId.mishnayos);

      final stages = await repo.getStagesForCurriculum(CurriculumId.mishnayos);
      final learn = stages.firstWhere((s) => s.stageOrder == 1);
      expect(learn.stageName, isNot('Customized'));
    });

    test('does NOT remove a 4th custom stage beyond the 3 defaults — '
        'firestore.rules denies delete on this collection entirely', () async {
      final repo = buildRepo();
      await repo.initializeDefaults(CurriculumId.mishnayos);
      const extra = StageDefinition(
        id: kFirestoreUnmappedStageId,
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 4,
        stageName: 'Custom extra stage',
        delayDays: 14,
        isDefault: false,
      );
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 4,
      ).set(extra.toFirestore(updatedAt: DateTime.utc(2026, 1, 1)));

      await repo.resetToDefaults(CurriculumId.mishnayos);

      final stages = await repo.getStagesForCurriculum(CurriculumId.mishnayos);
      expect(
        stages.map((s) => s.stageOrder),
        containsAll(<int>[1, 2, 3, 4]),
        reason: 'the 4th stage survives — this repository cannot delete',
      );
    });
  });

  group('hasCompletionsForStage', () {
    test('detects active and absent stage-order completions', () async {
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileId,
        stageId: 1,
      );
      final repo = buildRepo();

      expect(await repo.hasCompletionsForStage(1), isTrue);
      expect(await repo.hasCompletionsForStage(2), isFalse);
    });

    test('throws when a matching completion cannot be decoded', () async {
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('completions')
          .doc('malformed')
          .set({'stage_id': 1});
      final repo = buildRepo();

      expect(
        () => repo.hasCompletionsForStage(1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
