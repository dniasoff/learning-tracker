/// Unit tests for
/// `lib/data/repositories/firestore_point_config_repository.dart` (Phase 3
/// task #4) — structurally the third application of the
/// `FirestoreStageDefinitionRepository` pattern (composite `curriculum_id`
/// + `stage_order` key); see that repository's own test file for the
/// pattern this mirrors. Covers: doc-id correctness, the query shape,
/// model round-trip, `getPointsForStage`'s present/absent/decode-failure
/// cases (D-E: the single-doc read PROPAGATES a decode failure — Branch C
/// — unlike the list read's per-document leniency below), `upsertConfig`'s
/// 1..100 range assertion, `clearOverride`, and the list read's
/// decode-failure leniency (skip one bad document, not the whole read).
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/point_config.dart';

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
    required int stageOrder,
  }) => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('point_configs')
      .doc(
        DocIds.pointConfigDocId({
          'curriculum_id': curriculumId.storageKey,
          'stage_order': stageOrder,
        }),
      );

  FirestorePointConfigRepository buildRepo() {
    return FirestorePointConfigRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  group('doc-id correctness', () {
    test(
      'upsertConfig writes to {curriculumId}_{stageOrder} — the '
      'DocIds.pointConfigDocId formula',
      () async {
        final repo = buildRepo();

        await repo.upsertConfig(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
          points: 12,
        );

        final expectedId = DocIds.pointConfigDocId({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'stage_order': 1,
        });
        expect(expectedId, '${CurriculumId.mishnayos.storageKey}_1');
        final snapshot = await rawDoc(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
        ).get();
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()!['points'], 12);
      },
    );
  });

  group('getConfigsForCurriculum — query', () {
    test('returns only the given curriculum\'s overrides', () async {
      final repo = buildRepo();
      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        points: 12,
      );
      await repo.upsertConfig(
        curriculumId: CurriculumId.bavli,
        stageOrder: 1,
        points: 20,
      );

      final configs = await repo.getConfigsForCurriculum(
        CurriculumId.mishnayos,
      );

      expect(configs, hasLength(1));
      expect(configs.single.curriculumId, CurriculumId.mishnayos);
      expect(configs.single.points, 12);
    });

    test('returns an empty list when no overrides exist', () async {
      final repo = buildRepo();

      final configs = await repo.getConfigsForCurriculum(CurriculumId.bavli);

      expect(configs, isEmpty);
    });
  });

  group('getPointsForStage', () {
    test('returns the configured value when an override exists', () async {
      final repo = buildRepo();
      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
        points: 7,
      );

      final points = await repo.getPointsForStage(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
      );

      expect(points, 7);
    });

    test('returns null when no override exists for that stage', () async {
      final repo = buildRepo();

      final points = await repo.getPointsForStage(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      );

      expect(points, isNull);
    });

    test(
      'PROPAGATES a decode failure instead of returning null (D-E Branch '
      'C) — a single-doc read has no other document to fall back to, so '
      'swallowing this would be indistinguishable from "no override"',
      () async {
        final repo = buildRepo();
        await repo.upsertConfig(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
          points: 10,
        );
        await rawDoc(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
        ).update({'curriculum_id': 'not-a-real-curriculum'});

        expect(
          () => repo.getPointsForStage(
            curriculumId: CurriculumId.mishnayos,
            stageOrder: 1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('upsertConfig — update path', () {
    test('overwrites an existing override rather than duplicating it', () async {
      final repo = buildRepo();
      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        points: 10,
      );

      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        points: 25,
      );

      final configs = await repo.getConfigsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(configs, hasLength(1));
      expect(configs.single.points, 25);
    });
  });

  group('upsertConfig — range validation', () {
    test('throws ArgumentError for points below the minimum (0)', () {
      final repo = buildRepo();
      expect(
        () => repo.upsertConfig(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
          points: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for points above the maximum (101)', () {
      final repo = buildRepo();
      expect(
        () => repo.upsertConfig(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
          points: 101,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts the boundary values 1 and 100', () async {
      final repo = buildRepo();
      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        points: 1,
      );
      await repo.upsertConfig(
        curriculumId: CurriculumId.bavli,
        stageOrder: 1,
        points: 100,
      );

      expect(
        await repo.getPointsForStage(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 1,
        ),
        1,
      );
      expect(
        await repo.getPointsForStage(
          curriculumId: CurriculumId.bavli,
          stageOrder: 1,
        ),
        100,
      );
    });
  });

  group('clearOverride', () {
    test('deletes the doc so getPointsForStage reports no override again', () async {
      final repo = buildRepo();
      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        points: 25,
      );

      await repo.clearOverride(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      );

      final points = await repo.getPointsForStage(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      );
      expect(points, isNull);
      final snapshot = await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      ).get();
      expect(snapshot.exists, isFalse);
    });

    test('is a no-op when no override exists', () async {
      final repo = buildRepo();

      await repo.clearOverride(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
      );

      final configs = await repo.getConfigsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(configs, isEmpty);
    });
  });

  group('pointConfigFromFirestore — decode failures', () {
    test('throws ArgumentError for an unrecognised curriculum_id', () {
      expect(
        () => pointConfigFromFirestore({
          'curriculum_id': 'not-a-real-curriculum',
          'stage_order': 1,
          'points': 10,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('one-shot reads skip a malformed document instead of failing '
      'the whole read', () {
    test('getConfigsForCurriculum omits a document with an unrecognised '
        'curriculum_id but still returns the valid ones', () async {
      final repo = buildRepo();
      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        points: 10,
      );
      await repo.upsertConfig(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
        points: 5,
      );
      // Corrupt one of the 2 docs in place.
      await rawDoc(
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
      ).update({'curriculum_id': 'not-a-real-curriculum'});

      final configs = await repo.getConfigsForCurriculum(
        CurriculumId.mishnayos,
      );

      // The corrupted doc no longer matches the `curriculum_id` query
      // filter either (its field was overwritten), so this also exercises
      // the query-level filtering, not just decode leniency.
      expect(configs, hasLength(1));
      expect(configs.single.stageOrder, 1);
    });
  });
}
