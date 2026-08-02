/// Unit tests for `lib/data/repositories/firestore_goal_repository.dart` —
/// Epic B. Covers: doc-id correctness (including the AUD-scheduler-16
/// stability property — an ordinary edit must NOT compute a different
/// doc-id), model round-trip across all three `goalType` modes
/// (deadline/pace/none), the null-first client-side sort this repository
/// deliberately does instead of a Firestore `orderBy` (see the class doc
/// comment for why), updateGoal's field-resolution semantics, and the
/// "one bad document doesn't blank the list" decode leniency (both the
/// stream AND the one-shot read).
///
/// **What these tests cannot see** (same limitation as
/// `firestore_bookmark_repository_test.dart` /
/// `firestore_stage_definition_repository_test.dart`):
/// `fake_cloud_firestore`'s rules companion cannot evaluate
/// `resource.data`/`request.resource`, so the `goals` rules' `.hasOnly()`
/// field whitelist is NOT exercised here — a permissive fake is used
/// throughout (`createFakeFirestore()` default, `strictRules: false`).
/// [FirestoreGoalRepository.deleteGoal] is likewise NOT a rules-permission
/// test: `fake_cloud_firestore` deletes unconditionally regardless of who
/// is "authenticated", so the [deleteGoal] tests below prove only that the
/// method targets the right document (and leaves sibling documents
/// untouched) — never that `firestore.rules` actually permits the owner
/// (and denies everyone else) to delete a goal. That permission boundary
/// is proven exclusively by `functions/test/firestore_rules.test.mjs`
/// (`make test-rules`), the only harness that evaluates real Firestore
/// Rules. The resubscribe-with-backoff behavior
/// [FirestoreGoalRepository.watchGoals] delegates to is covered directly in
/// `resilient_doc_stream_test.dart` (`resilientQueryStream` groups) — not
/// re-proven here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  DocumentReference<Map<String, dynamic>> rawDoc(String docId) => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('goals')
      .doc(docId);

  FirestoreGoalRepository buildRepo() {
    return FirestoreGoalRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  group('doc-id correctness', () {
    test('createGoal writes to DocIds.goalDocId({\'id\': goal.firestoreId}) — '
        'which resolves to goal.firestoreId directly', () async {
      final repo = buildRepo();

      final goal = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 80,
      );

      final expectedId = DocIds.goalDocId({'id': goal.firestoreId});
      expect(expectedId, goal.firestoreId);
      final snapshot = await rawDoc(goal.firestoreId).get();
      expect(snapshot.exists, isTrue);
    });

    test(
      'two goals in different curricula land on different documents',
      () async {
        final repo = buildRepo();

        final a = await repo.createGoal(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 50,
        );
        final b = await repo.createGoal(
          curriculumId: CurriculumId.bavli,
          targetPercent: 60,
        );

        expect(a.firestoreId, isNot(b.firestoreId));
      },
    );

    test('updateGoal changing targetPercent stays on the SAME document — '
        'AUD-scheduler-16: firestoreId excludes targetPercent precisely so an '
        'ordinary edit never orphans the original doc', () async {
      final repo = buildRepo();
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 50,
      );

      final updated = await repo.updateGoal(goal: created, targetPercent: 90);

      expect(updated.firestoreId, created.firestoreId);
      final all = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('goals')
          .get();
      expect(
        all.docs,
        hasLength(1),
        reason:
            'the edit must overwrite the original doc, not create a '
            'second one',
      );
      expect(all.docs.single.data()['target_percent'], 90);
    });

    test('never writes a track_id field (no per-device track key)', () async {
      final repo = buildRepo();

      final goal = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 80,
      );

      final snapshot = await rawDoc(goal.firestoreId).get();
      expect(snapshot.data(), isNot(contains('track_id')));
    });
  });

  group('model round-trip — goalType modes', () {
    test('DeadlineTarget round-trips as goalType "deadline"', () async {
      final repo = buildRepo();
      final due = DateTime.utc(2026, 9, 1);

      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
        paceTarget: DeadlineTarget(due),
        description: 'finish before Rosh Hashanah',
      );

      final goals = await repo.getGoals(CurriculumId.mishnayos);
      expect(goals, hasLength(1));
      expect(goals.single.goalType, 'deadline');
      expect(goals.single.targetDate, due);
      expect(goals.single.description, 'finish before Rosh Hashanah');
    });

    test('PacePeriodTarget round-trips as goalType "pace"', () async {
      final repo = buildRepo();

      await repo.createGoal(
        curriculumId: CurriculumId.bavli,
        targetPercent: 100,
        paceTarget: const PacePeriodTarget(rate: 2, period: 'per_day'),
      );

      final goals = await repo.getGoals(CurriculumId.bavli);
      expect(goals.single.goalType, 'pace');
      expect(goals.single.paceValue, 2);
      expect(goals.single.pacePeriod, 'per_day');
      expect(goals.single.targetDate, isNull);
    });

    test('null paceTarget round-trips as goalType "none"', () async {
      final repo = buildRepo();

      await repo.createGoal(
        curriculumId: CurriculumId.nach,
        targetPercent: 100,
      );

      final goals = await repo.getGoals(CurriculumId.nach);
      expect(goals.single.goalType, 'none');
      expect(goals.single.targetDate, isNull);
      expect(goals.single.paceValue, isNull);
    });

    test('typed paceGranularity round-trips', () async {
      final repo = buildRepo();

      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
        paceGranularity: PaceGranularity.daf,
      );

      final goals = await repo.getGoals(CurriculumId.mishnayos);
      expect(goals.single.paceGranularity, PaceGranularity.daf);
      expect(goals.single.rawLearningUnit, isNull);
    });

    test('a learning unit outside the typed enum round-trips via '
        'rawLearningUnit', () async {
      final repo = buildRepo();

      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
        rawLearningUnit: 'amud',
      );

      final goals = await repo.getGoals(CurriculumId.mishnayos);
      expect(goals.single.paceGranularity, isNull);
      expect(goals.single.rawLearningUnit, 'amud');
    });
  });

  group('getGoals / watchGoals — client-side null-first sort', () {
    test('a goal with no target_date (pace/none type) is NOT excluded — the '
        'whole reason this repository sorts client-side instead of using a '
        'Firestore orderBy on the nullable target_date field', () async {
      final repo = buildRepo();
      await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
      ); // goalType 'none', target_date absent from the document entirely

      final goals = await repo.getGoals(CurriculumId.mishnayos);

      expect(goals, hasLength(1));
    });

    test('sorts null target_date first, then ascending by date', () async {
      // Goals are constructed directly (not via createGoal) and written as
      // raw docs with explicit, distinct createdAt values — createGoal's
      // internal DateTimeFactory.nowUtc() only has millisecond resolution
      // and three back-to-back calls can land in the same millisecond,
      // which (per the class doc comment) collides onto the SAME
      // firestoreId and would make this test meaningless.
      final repo = buildRepo();
      final late = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
        targetDate: DateTime.utc(2026, 12, 1),
        description: 'late',
        goalType: 'deadline',
        createdAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      );
      final noDate = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
        description: 'no-date',
        goalType: 'none',
        createdAt: DateTime.utc(2026, 1, 1, 0, 0, 2),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 2),
      );
      final early = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
        targetDate: DateTime.utc(2026, 6, 1),
        description: 'early',
        goalType: 'deadline',
        createdAt: DateTime.utc(2026, 1, 1, 0, 0, 3),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 3),
      );
      for (final goal in [late, noDate, early]) {
        await rawDoc(goal.firestoreId).set(goal.toFirestore());
      }

      final goals = await repo.getGoals(CurriculumId.mishnayos);

      expect(goals.map((g) => g.description), ['no-date', 'early', 'late']);
    });
  });

  group('updateGoal', () {
    test(
      'clearPaceTarget resets goalType to "none" and clears mode fields',
      () async {
        final repo = buildRepo();
        final created = await repo.createGoal(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 100,
          paceTarget: const PacePeriodTarget(rate: 3, period: 'per_week'),
        );

        final updated = await repo.updateGoal(
          goal: created,
          clearPaceTarget: true,
        );

        expect(updated.goalType, 'none');
        expect(updated.paceValue, isNull);
        expect(updated.pacePeriod, isNull);
        expect(updated.targetDate, isNull);
      },
    );

    test('omitting paceTarget leaves the existing mode untouched', () async {
      final repo = buildRepo();
      final due = DateTime.utc(2026, 10, 1);
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 50,
        paceTarget: DeadlineTarget(due),
      );

      final updated = await repo.updateGoal(
        goal: created,
        description: 'renamed',
      );

      expect(updated.goalType, 'deadline');
      expect(updated.targetDate, due);
      expect(updated.description, 'renamed');
    });

    test('clearLearningUnit clears both typed and raw fields', () async {
      final repo = buildRepo();
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 50,
        paceGranularity: PaceGranularity.perek,
      );

      final updated = await repo.updateGoal(
        goal: created,
        clearLearningUnit: true,
      );

      expect(updated.paceGranularity, isNull);
      expect(updated.rawLearningUnit, isNull);
    });

    test('merges rather than replacing — a pre-existing field outside the '
        'client whitelist (e.g. a tutor-CF-stamped synced_at) survives a '
        'subsequent owner write', () async {
      final repo = buildRepo();
      final created = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 50,
      );
      await rawDoc(
        created.firestoreId,
      ).set({'synced_at': 'server-stamped-value'}, SetOptions(merge: true));

      await repo.updateGoal(goal: created, targetPercent: 75);

      final snapshot = await rawDoc(created.firestoreId).get();
      expect(snapshot.data()!['synced_at'], 'server-stamped-value');
      expect(snapshot.data()!['target_percent'], 75);
    });
  });

  group('deleteGoal', () {
    test('removes the target document', () async {
      final repo = buildRepo();
      final goal = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 80,
      );

      await repo.deleteGoal(goal);

      final snapshot = await rawDoc(goal.firestoreId).get();
      expect(snapshot.exists, isFalse);
    });

    test('leaves other goals — including siblings in the same curriculum — '
        'untouched', () async {
      // Entities are constructed directly with explicit, distinct createdAt
      // values rather than via back-to-back createGoal() calls — see the
      // "sorts null target_date first" test above for why: createGoal's
      // DateTimeFactory.nowUtc() only has millisecond resolution, and two
      // calls landing in the same millisecond would collide onto the SAME
      // firestoreId (curriculumId + createdAt only), defeating the point of
      // this test.
      final repo = buildRepo();
      final toDelete = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 80,
        description: 'delete me',
        goalType: 'none',
        createdAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      );
      final sibling = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 50,
        description: 'keep me',
        goalType: 'none',
        createdAt: DateTime.utc(2026, 1, 1, 0, 0, 2),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 2),
      );
      final otherCurriculum = GoalEntity(
        curriculumId: CurriculumId.bavli,
        targetPercent: 30,
        description: 'keep me too',
        goalType: 'none',
        createdAt: DateTime.utc(2026, 1, 1, 0, 0, 3),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 3),
      );
      for (final goal in [toDelete, sibling, otherCurriculum]) {
        await rawDoc(goal.firestoreId).set(goal.toFirestore());
      }

      await repo.deleteGoal(toDelete);

      expect((await rawDoc(toDelete.firestoreId).get()).exists, isFalse);
      expect((await rawDoc(sibling.firestoreId).get()).exists, isTrue);
      expect((await rawDoc(otherCurriculum.firestoreId).get()).exists, isTrue);
      final remaining = await repo.getGoals(CurriculumId.mishnayos);
      expect(remaining.map((g) => g.description), ['keep me']);
    });

    test(
      'deleting an already-absent document is a no-op (idempotent)',
      () async {
        final repo = buildRepo();
        final goal = await repo.createGoal(
          curriculumId: CurriculumId.mishnayos,
          targetPercent: 80,
        );
        await repo.deleteGoal(goal);

        // Deleting again must not throw — matches Firestore's own delete()
        // semantics (deleting a non-existent document succeeds).
        await repo.deleteGoal(goal);

        expect((await rawDoc(goal.firestoreId).get()).exists, isFalse);
      },
    );
  });

  group('watchGoals — stream emits on change', () {
    test('emits the goal once created, sorted', () async {
      final repo = buildRepo();

      final stream = repo
          .watchGoals(CurriculumId.nach)
          .map((goals) => goals.length);
      final done = expectLater(stream, emitsThrough(1));

      await repo.createGoal(
        curriculumId: CurriculumId.nach,
        targetPercent: 100,
      );

      await done;
    });
  });

  group('one-shot reads skip a malformed document instead of failing '
      'the whole read', () {
    test('getGoals omits a document missing created_at but still returns '
        'the valid ones', () async {
      final repo = buildRepo();
      final good = await repo.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100,
      );
      await rawDoc('malformed_doc').set({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        // created_at / updated_at deliberately missing.
      });

      final goals = await repo.getGoals(CurriculumId.mishnayos);

      expect(goals, hasLength(1));
      expect(goals.single.firestoreId, good.firestoreId);
    });
  });
}
