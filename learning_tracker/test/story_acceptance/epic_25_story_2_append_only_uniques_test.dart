/// Story acceptance tests for Firestore append-only identities (DNI-323).
@Tags(['epic_25', 'story_25_2'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:test/test.dart';

import '../helpers/firestore_fixtures.dart';

const _uid = 'uid_story_25_2';
const _profileA = '01J00000000000000000000004';
const _profileB = '01J00000000000000000000005';

void main() {
  group('AC1 — completion natural-key document identity', () {
    test('same completion key resolves to one Firestore document', () async {
      final firestore = FakeFirebaseFirestore();
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileA,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageId: 1,
        trackType: 'personal',
      );
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileA,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageId: 1,
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 5, 13, 11),
      );

      final repository = FirestoreCompletionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileA,
      );
      final rows = await repository.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(rows, hasLength(1));
    });
  });

  // AC2 (streak-event identity) and AC3 (learning-ledger identity) are
  // retired with their collections (DNI-479, R5/R6): learning is one
  // `learning_events` append per capture, keyed by its own ULID.

  group('AC5/AC6 — append-only retries preserve one logical row', () {
    test('completion retry returns one row through the repository', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCompletionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileA,
      );
      final first = await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileA,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah Berakhot 2:1',
      );
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileA,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah Berakhot 2:1',
        completedAt: DateTime.utc(2026, 5, 13, 11),
      );
      final rows = await repository.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(first, isNotEmpty);
      expect(rows, hasLength(1));
    });

    test('same content key remains independent across profile paths', () async {
      final firestore = FakeFirebaseFirestore();
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileA,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah Berakhot 1:1',
      );
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileB,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah Berakhot 1:1',
      );

      final first = await FirestoreCompletionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileA,
      ).getCompletionsForCurriculum(CurriculumId.mishnayos);
      final second = await FirestoreCompletionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileB,
      ).getCompletionsForCurriculum(CurriculumId.mishnayos);
      expect(first, hasLength(1));
      expect(second, hasLength(1));
    });
  });
}
